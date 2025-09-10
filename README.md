# santoku-cli

A command line interface to the santoku lua library providing tools for template
processing, bundling executables, running tests, and managing Lua library/web
projects.

## Overview

The `toku` command provides several subcommands for different development tasks:

- **`template`** - Process template files with Lua code interpolation
- **`bundle`** - Create standalone executables from Lua scripts
- **`lua`** - Enhanced Lua interpreter with profiling and tracing
- **`test`** - Test runner with pattern matching
- **`lib`** - Manage Lua library projects
- **`web`** - Manage Lua web projects with OpenResty

## Commands

### `toku template`

Process template files with embedded Lua code. For complete template syntax
documentation, see
[lua-santoku-template](https://github.com/treadwelllane/lua-santoku-template).

| Option | Arguments | Description |
|--------|-----------|-------------|
| `-f`, `--file` | `FILE` | Input template file (use "-" for stdin) |
| `-d`, `--directory` | `DIR` | Input directory of templates |
| `-o`, `--output` | `PATH` | Output file or directory (required) |
| `-c`, `--config` | `FILE` | Configuration file with environment variables |
| `-M`, `--deps` | | Generate make dependency files (.d) |
| `-t`, `--trim` | `PREFIX` | Remove prefix from directory paths in output |

### `toku bundle`

Create standalone executables from Lua scripts by bundling dependencies and
compiling to native code. For complete bundling documentation, see
[lua-santoku-bundle](https://github.com/treadwelllane/lua-santoku-bundle).

| Option | Arguments | Description |
|--------|-----------|-------------|
| `--input` | `FILE` | Input Lua file (required) |
| `--output-directory` | `DIR` | Output directory (required) |
| `--output-prefix` | `PREFIX` | Prefix for output files |
| `--path` | `PATH` | LUA_PATH for module resolution |
| `--cpath` | `CPATH` | LUA_CPATH for C module resolution |
| `--env` | `KEY VALUE` | Set runtime environment variables |
| `--mod` | `MODULE` | Load modules during startup |
| `--flags` | `FLAGS` | Compiler command-line flags |
| `--cc` | `COMPILER` | Set the C compiler |
| `--luac` | `COMMAND` | Custom luac command |
| `--luac-off` | | Disable luac compilation step |
| `--xxd` | `COMMAND` | Custom xxd command for binary data |
| `--ignore` | `MODULE` | Skip bundling specific modules |
| `--deps` | | Generate make dependency file |
| `--deps-target` | `TARGET` | Override dependency target name |
| `--close` / `--no-close` | | Control lua_close() behavior |

### `toku lua`

Run Lua code with enhanced capabilities including profiling, tracing, and auto-serialization.

| Option | Arguments | Description |
|--------|-----------|-------------|
| `--file` | `FILE` | Lua file to execute |
| `--string` | `STRING` | Lua string to execute |
| `--profile` | | Enable profiling |
| `--trace` | | Enable source tracing |
| `--serialize` | | Auto-serialize output |
| `--lua` | `INTERPRETER` | Specify custom interpreter |

### `toku test`

Run test suites with pattern matching and various output options.

| Option | Arguments | Description |
|--------|-----------|-------------|
| `--match` | `PATTERN` | Run tests matching pattern |
| `--stop` | | Stop on first error |
| `--interp` | `INTERPRETER` | Use custom interpreter |

### `toku lib`

Manage Lua library projects.

| Subcommand | Description |
|------------|-------------|
| `init` | Initialize new library project |
| `test` | Run tests |
| `release` | Release the library |
| `install` | Install locally |

#### lib options

| Option | Arguments | Description |
|--------|-----------|-------------|
| `--dir` | `DIR` | Build directory |
| `--env` | `ENV` | Environment name |
| `--config` | `FILE` | Configuration file |
| `--coverage` | | Enable coverage reporting |
| `--profile` | | Performance profiling |
| `--trace` | | Source tracing |
| `--skip-check` | | Skip luacheck linting |
| `--single` | `TEST` | Run single test file |

### `toku web`

Manage OpenResty-based web applications.

| Subcommand | Description |
|------------|-------------|
| `init` | Initialize new web project |
| `start` | Start development server |
| `build` | Build the application |
| `stop` | Stop the server |
| `test` | Run web tests |

#### web options

| Option | Arguments | Description |
|--------|-----------|-------------|
| `--dir` | `DIR` | Build directory |
| `--env` | `ENV` | Environment name |
| `--config` | `FILE` | Configuration file |
| `--coverage` | | Enable coverage reporting |
| `--profile` | | Performance profiling |
| `--trace` | | Source tracing |
| `--skip-check` | | Skip luacheck linting |
| `--single` | `TEST` | Run single test file |
| `--openresty-dir` | `DIR` | OpenResty installation directory |
| `--background` | | Run server in background |
| `--test` | | Use test environment |

## Global Options

| Option | Arguments | Description |
|--------|-----------|-------------|
| `--verbosity` | `LEVEL` | Set verbosity level (0-1) |

## Environment Variables

The CLI respects several environment variables:

- `OPENRESTY_DIR` - Default OpenResty installation directory for web projects
- `LUA` - Lua interpreter to use
- Various build-related variables (CC, CFLAGS, etc.)

## License

Copyright 2025 Birch Point SWE

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
