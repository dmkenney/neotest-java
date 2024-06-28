local lib = require("neotest.lib")
local Adapter = {}

Adapter.name = "gradle-test"

--- Find the project root directory given a current directory to work from.
--- Should no root be found, the adapter can still be used in a non-project context if a test file matches.
--- @async
--- @param dir string @Directory to treat as cwd
--- @return string | nil @Absolute root dir of test suite
Adapter.root = lib.files.match_root_pattern("build.gradle", "build.gradle.kts")

--- @async
--- @param file_path string
--- @return boolean
function Adapter.is_test_file(file_path)
  local test_file_patterns = { "Test.java$", "IT.java$", "IntegrationTest.java$" }
  for _, pattern in pairs(test_file_patterns) do
    if file_path:match(pattern) then
      return true
    end
  end

  return false
end

--- Given a file path, parse all the tests within it.
--- @async
--- @param file_path string Absolute file path
--- @return neotest.Tree | nil
function Adapter.discover_positions(path)
  local query = [[
    ;; class_with_name_ending_in_test
    (
      (class_declaration name: (identifier) @namespace.name)
      (#match? @namespace.name "(Test|IT|IntegrationTest)$")
    ) @namespace.definition

    ;; method_with_test_marker
    (
      (method_declaration
        (modifiers (marker_annotation name: (identifier) @test_marker.identifier))
        name: (identifier) @test.name
      )
      (#eq? @test_marker.identifier "Test")
    ) @test.definition

    ;; method_with_test_marker_and_display_name_annotation
    (
      (method_declaration
        (modifiers (marker_annotation name: (identifier) @test_marker.identifier)
          (annotation
            name: (identifier) @display_name.identifier
            arguments: (annotation_argument_list (string_literal (string_fragment) @display_name.value))
          )
        )
        name: (identifier) @test.name
      )
      (#eq? @test_marker.identifier "Test")
      (#eq? @display_name.identifier "DisplayName")
    ) @test.definition
  ]]

  return lib.treesitter.parse_positions(path, query, {
    build_position = 'require("neotest-gradle.hooks.discover_positions.build_position")',
    position_id = 'require("neotest-gradle.hooks.discover_positions.build_position_identifier")',
  })
end

--- @param args neotest.RunArgs
--- @return nil | neotest.RunSpec | neotest.RunSpec[]
Adapter.build_spec = require("neotest-gradle.hooks.build_run_specification")

--- @async
--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param tree neotest.Tree
--- @return table<string, neotest.Result>
Adapter.results = require("neotest-gradle.hooks.collect_results")

return Adapter
