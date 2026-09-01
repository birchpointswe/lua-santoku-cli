<p align="center">
  <img src="https://santoku.dev/logo-santoku-cli.png" height="64" alt="santoku-cli">
</p>

# santoku-cli

`toku`, the command line front end for the santoku project framework. It drives
santoku-make to build, test, install, and release Lua libraries, executables, and web
apps, and it exposes the templating, bundling, and interpreter utilities standalone.

## Install

With a luarocks that targets lua 5.1 (or luajit):

```sh
luarocks install santoku-cli
```

Santoku rocks pin `lua == 5.1`, so on distros whose luarocks targets a newer
lua (Arch, Fedora, current Homebrew) the install above fails. Use the
bootstrap script instead. It builds a private lua 5.1 and luarocks from
sha256-pinned sources into `~/.local/share/toku` (respecting
`XDG_DATA_HOME`) and installs santoku-cli there, touching nothing else on
your system:

```sh
git clone https://github.com/birchpointswe/lua-santoku-cli
sh lua-santoku-cli/res/bootstrap.sh
~/.local/share/toku/rocks/bin/toku doctor
```

Prerequisites: `cc`, `make`, `tar`, `unzip`, `curl` or `wget`, and a sha256
tool (`sha256sum`, `shasum`, or `openssl`).

## Managed toolchain

`toku setup` provisions (or verifies) the same managed tree from a working
toku:

```sh
toku setup
toku setup --path
toku setup --upgrade
toku setup --repair
toku setup --uninstall
```

- `toku setup` builds anything missing and is safe to re-run.
- `--path` prints the managed bin directories, colon-joined.
- `--upgrade` rebuilds lua and luarocks at the currently pinned versions and
  reinstalls santoku-cli, keeping the installed rocks tree.
- `--repair` (alias `--force`) recovers a half-built or broken tree the same
  way.
- `--uninstall` removes `~/.local/share/toku` entirely, leaving the machine
  as found.

While the managed tree exists, toku prepends its bin directories to `PATH`
inside its own process, so every `lua` and `luarocks` invocation made by
toku-driven builds uses the managed pair. Nothing outside the toku process
is changed: no symlinks, no shell rc edits.

To use the managed pair from your shell as well, wire it up yourself:

```sh
export PATH="$(toku setup --path):$PATH"
```

or symlink the binaries you want from the directories `toku setup --path`
prints into a directory of your choosing. toku never does this for you.

`toku lua` runs the managed lua when it exists (with the managed rocks tree
on its package path) and falls back to the current interpreter otherwise.
`toku luarocks ...` passes through to the managed luarocks.

## Doctor

`toku doctor` reports which lua and luarocks are actually in effect: the
managed tree's health, version drift against the pinned versions, what your
shell `PATH` resolves for `lua` and `luarocks`, whether the managed bin
directories are wired into your `PATH`, and whether the build prerequisites
are present. It exits nonzero when the managed tree exists but is broken.

## Example

```sh
toku init --name my-lib
toku test --iterate
toku install
toku release
```

Every project command reads a `make.lua` descriptor in the current directory and writes
into `build/<env>/`, so builds, test trees, and release artifacts never collide.

## Documentation

Runnable examples and the full API: [santoku.dev](https://santoku.dev/#santoku-cli).

For agents and LLM tooling: [llms.txt](https://santoku.dev/llms.txt) for the index,
[llms-full.txt](https://santoku.dev/llms-full.txt) for every documented example.

## Tests

The tests are the spec. For the exhaustive surface, read them:
[`test/spec/santoku/cli/template.lua`](test/spec/santoku/cli/template.lua),
[`test/spec/santoku/cli/setup.lua`](test/spec/santoku/cli/setup.lua).

The setup provisioning test builds the full managed toolchain into a scratch
prefix under `~/tmp` and is gated behind `TK_CLI_TEST_SETUP=1` since it
downloads sources and takes minutes.

## License

MIT, see [LICENSE](LICENSE).

## More examples

```lua
if os.getenv("TK_CLI_WASM") == "1" then
  print("Skipping test when TK_CLI_WASM is 1")
  return
end

local test = require("santoku.test")

local err = require("santoku.error")
local assert = err.assert

local validate = require("santoku.validate")
local eq = validate.isequal

local env = require("santoku.env")
local var = env.var

local sys = require("santoku.system")
local sh = sys.sh

local toku = var("LUA") .. " -l luacov bin/toku.lua"

local function run (cmd)
  return sh({ "sh", "-c", cmd })()
end

test("render a lua template from stdin to stdout", function ()
  assert(eq("hello", run(
    "echo '<% return \"hello\" %>' | " .. toku .. " template -f - -o -")))
end)

test("a config file supplies the names a template can see", function ()
  assert(eq("12", run(
    "echo '<% return a .. c %>' | " ..
    toku .. " template -f - -o - -c test/res/tmpl.cfg0.lua")))
end)

test("run a lua string through the configured interpreter", function ()
  assert(eq("2", run(toku .. " lua --string 'print(1 + 1)'")))
end)
```
