local lib = require("neotest.lib")
local nio = require("nio")
local Job = require("plenary.job")

--- Finds either an executable file named `gradlew` in any parent directory of
--- the project or falls back to a binary called `gradle` that must be available
--- in the users PATH.
---
--- @param project_directory string
--- @return string - absolute path to wrapper of binary name
local function get_gradle_executable(project_directory)
  local gradle_wrapper_folder = lib.files.match_root_pattern("gradlew")(project_directory)

  if gradle_wrapper_folder ~= nil then
    return gradle_wrapper_folder .. lib.files.sep .. "gradlew"
  else
    return "gradle"
  end
end

--- Runs the given Gradle executable in the respective project directory to
--- query the `testResultsDir` property. Has to do some plain text parsing of
--- the Gradle command output. The child folder named `test` is always added to
--- this path.
--- Is empty if directory could not be determined.
---
--- @param gradle_executable string
--- @param project_directory string
--- @return string - absolute path of test results directory
local function get_test_results_directory(gradle_executable, project_directory, gradle_task)
  local command = {
    gradle_executable,
    "--project-dir",
    project_directory,
    "properties",
    "--property",
    "testResultsDir",
  }
  local _, output = lib.process.run(command, { stdout = true })
  local output_lines = vim.split(output.stdout or "", "\n")

  for _, line in pairs(output_lines) do
    if line:match("testResultsDir: ") then
      return line:gsub("testResultsDir: ", "") .. lib.files.sep .. gradle_task
    end
  end

  return ""
end

--- Takes a NeoTest tree object and iterates over its positions. For each position
--- it traverses up the tree to find the respective namespace that can be
--- used to filter the tests on execution. The namespace is usually the parent
--- test class.
---
--- @param tree table - see neotest.Tree
--- @return  table[] - list of neotest.Position of `type = "namespace"`
local function get_namespaces_of_tree(tree)
  local namespaces = {}

  for _, position in tree:iter() do
    if position.type == "namespace" then
      table.insert(namespaces, position)
    end
  end

  return namespaces
end

--- Constructs the additional arguments for the test command to filter the
--- correct tests that should run.
--- Therefore it uses (and possibly repeats) the Gradle test command
--- option `--tests` with the full locator. The locators consist of the
--- package path, plus optional class names and test function name. This value is
--- already attached/pre-calculated to the nodes `id` property in the tree.
--- The position argument defines what the user intended to execute, which can
--- also be a whole file. In that case the paths are unknown and must be
--- collected by some additional logic.
---
--- @param tree table - see neotest.Tree
--- @param position table - see neotest.Position
--- @return string[] - list of strings for arguments
local function get_test_filter_arguments(tree, position)
  local arguments = {}

  if position.type == "test" or position.type == "namespace" then
    vim.list_extend(arguments, { "--tests", position.id })
  elseif position.type == "file" then
    local namespaces = get_namespaces_of_tree(tree)

    for _, namespace in pairs(namespaces) do
      vim.list_extend(arguments, { "--tests", "'" .. namespace.id .. "'" })
    end
  end

  return arguments
end

--- Determines the appropriate Gradle task based on the file path.
--- If the file path contains `src/test`, it uses `test`.
--- If the file path contains `src/integrationTest`, it uses `integrationTest`.
---
--- @param file_path string
--- @return string - the Gradle task to use
local function get_gradle_task(file_path)
  if file_path:match("src" .. lib.files.sep .. "test") then
    return "test"
  elseif file_path:match("src" .. lib.files.sep .. "integrationTest") then
    return "integrationTest"
  else
    -- Default to 'test' if neither condition is met
    return "test"
  end
end

--- @param command string
--- @param args string[]
--- @return nio.control.Event
local function launch_debug_test(command, args)
  vim.notify("Running debug test", vim.log.levels.INFO)

  local test_command_started_listening = nio.control.event()
  local terminated_command_event = nio.control.event()

  local stderr = {}
  local job = Job:new({
    command = command,
    args = args,
    on_stderr = function(_, data)
      stderr[#stderr + 1] = data
    end,
    on_stdout = function(_, data)
      if string.find(data, "Listening") then
        test_command_started_listening.set()
      end
    end,
    on_exit = function(_, _)
      terminated_command_event.set()
    end,
  })
  job:start()
  test_command_started_listening.wait()

  return terminated_command_event
end

--- @param args neotest.RunArgs
--- @return nil | neotest.RunSpec | neotest.RunSpec[]
return function(arguments)
  local position = arguments.tree:data()
  local project_directory = lib.files.match_root_pattern("build.gradle", "build.gradle.kts")(position.path)
  local gradle_executable = get_gradle_executable(project_directory)
  local gradle_task = get_gradle_task(position.path)

  local command_args = { "--project-dir", project_directory, gradle_task }
  vim.list_extend(command_args, get_test_filter_arguments(arguments.tree, position))

  local context = {
    test_results_directory = get_test_results_directory(gradle_executable, project_directory, gradle_task),
  }

  if arguments.strategy == "dap" then
    table.insert(command_args, "--debug-jvm")
    local tce = launch_debug_test(gradle_executable, command_args)
    context.terminated_command_event = tce
    context.strategy = "dap"

    return {
      context = context,
      strategy = {
        type = "java",
        request = "attach",
        name = "Debug (Attach) - Local",
        hostName = "127.0.0.1",
        port = 5005,
      },
    }
  else
    return {
      command = gradle_executable .. " " .. table.concat(command_args, " "),
      context = context,
    }
  end
end
