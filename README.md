# santoku-cli

`toku`, the command-line front end for the santoku project framework. It drives
[santoku-make](../lua-santoku-make/README.md) to build, test, install, and release
Lua projects (libraries, bin executables, and web apps), and it exposes a few
standalone utilities that wrap other santoku libraries.

Documentation and runnable examples: [santoku.dev](https://santoku.dev), under the
`santoku-cli` tab.

This README is a usage guide, not an API reference. For the project model (the
`make*.lua` descriptor, the build lifecycle, project types, variants, and worked
examples) see the [santoku-make guide](../lua-santoku-make/doc/usage.md); `toku` is
the command surface over it.

## Project commands

These operate on a project in the current directory (a `make.lua` or
`make.common.lua`). They share `--dir` (build root, default `build`), `--env`
(profile/sub-directory, default `default`, selecting `make.<env>.lua`), and
`--config` (explicit descriptor path).

| Command | What it does |
|---------|--------------|
| `toku init` | Scaffold a new project (`--name` or `--here`, `--web` for a web project). |
| `toku build` | Render templates and compile. `--test` builds the test environment. |
| `toku test` | Build the test env and run the suite + `luacheck`. Key flags: `--match <lua-pattern>` (keep only spec files whose path matches), `--single`, `--stop`, `--iterate` (re-run on change), `--skip-check`, `--profile`, `--trace`, `--wasm`. With positional files it runs them directly instead of the project. |
| `toku install` | `luarocks make` the built rock. `--bundled` instead bundles `bin/` into standalone executables (`--prefix`, `--bundle-cc`, `--bundle-flags`, ...); `--skip-tests` to skip the test gate; `--wasm` for a WASM bundle. |
| `toku pack` | Build the rockspec + source tarball without publishing (public lib projects). |
| `toku release` | `pack`, then tag, push, create a GitHub release, and upload to luarocks (public lib projects). `--skip-tests` to skip the gate. |
| `toku exec ...` | Run a command with the project's `LUA_PATH`/`LUA_CPATH` set. |
| `toku clean` | Remove build artifacts. `--all` (whole build dir), `--deps` (installed modules), `--dry-run`. |
| `toku start` / `toku stop` | Start/stop the dev server (web projects; OpenResty). `--fg` runs in the foreground, `--test` uses the test env. |

Project discovery, profile selection, and the build directory layout
(`build/<env>/{build,test}`) are described in the make guide. Web-specific test
flags (`--client`, `--server`, `--root`, `--show-logs`) and `--openresty-dir` also
apply where relevant.

## Utility commands

These do not require a project; each wraps the same-named library. See those repos
for the full semantics.

- `toku template` ([santoku-template](../lua-santoku-template/README.md)): render
  `<% %>` Lua templates. `-f`/`-d` input, `-o` output, `-c` config, `-M` for `.d`
  deps, `-t` to trim a path prefix.
- `toku bundle` ([santoku-bundle](../lua-santoku-bundle/README.md)): bundle a Lua
  entry point and its dependencies into a standalone C executable. `--input`,
  `--output-directory`, `--path`/`--cpath`, `--cc`, `--flags`, `--mod`, `--ignore`,
  and the `--luac*` controls.
- `toku lua`: run a Lua interpreter (`--file` or `--string`) with optional
  `--profile`, `--trace`, `--serialize`, and `--lua` to pick the interpreter.

`--verbosity` is a global flag.

## Typical workflow

```sh
toku init --name my-lib          # scaffold (--web for a web app)
# edit lib/, test/spec/, declare deps in make.lua
toku test --iterate              # develop, re-running tests on change
toku install                     # install locally via luarocks
toku release                     # public libs: tag + GitHub release + luarocks upload
```

For a web app the inner loop is `toku build --test`, `toku start --test`, `toku
test`, `toku stop`.

## Dependencies

`toku` pulls in santoku-make (the framework), santoku-template (templating),
santoku-bundle (executable bundling), santoku-test-runner (the test runner),
santoku-fs/santoku-system (file and process glue), and argparse (argument
parsing).

## Building / testing

This repo uses the `toku` harness (it builds itself). The entry point is
`bin/toku.tk.lua`. Run the suite through `toku`.

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
