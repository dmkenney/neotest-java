# Neotest Java

[Neotest](https://github.com/nvim-neotest/neotest) adapter for Java projects using [Maven](https://maven.apache.org/) or [Gradle](https://gradle.org/).

This uses the same technique as IntelliJ for running tests. It runs the Maven/Gradle `test` command if the test class/method is within the _test_ directory, and runs the `integrationTest` command if the test class/method is within the _integrationTest_ directory.

Test reports must be output in XML.

## Installation

Requires:

- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- [jdtls](https://github.com/nvim-java/nvim-java-test)
- [java-debug-adapter](https://github.com/microsoft/java-debug)

[vim-plug](https://github.com/junegunn/vim-plug):

```lua
Plug "dmkenney/neotest-java"
```

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  { "dmkenney/neotest-java" },
}
```

## Configuration

```lua
require("neotest").setup({
    adapters = {
        require("neotest-java"),
    },
})
```

## Supported Features

- Tests can be run in debug mode
- Supports running different tasks based on the directory the test file resides in
- Diagnostics for failed tests

## TODOs

- Stream results back to Neotest - show test results as they occur, not wait until all are complete before showing
- Support Maven
- Don't run tests marked with @Disabled
- Add configuration options - specifically for setting which Maven/Gradle tasks should run for which directories.
- Add logging

## Contributing

Please raise a PR if you are interested in adding new functionality or fixing any bugs. If you are unsure of how this plugin works please read the Writing adapters section of the Neotest README.
