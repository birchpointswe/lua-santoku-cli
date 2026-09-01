<p align="center">
  <img src="https://santoku.dev/logo-santoku-cli.png" height="64" alt="santoku-cli">
</p>

# santoku-cli

`toku`, the command line front end for the santoku project framework. It drives
santoku-make to build, test, install, and release Lua libraries, executables, and web
apps, and it exposes the templating, bundling, and interpreter utilities standalone.

## Install

With a luarocks that targets lua 5.1 (or a 5.1-compatible luajit):

```sh
luarocks install santoku-cli
toku setup --use-system
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

## Setup

toku requires a one-time `toku setup` before any command that needs lua or
luarocks (`toku lua`, `toku luarocks`, and the project commands that drive
builds). Until then those commands error and name the setup commands to run.
There are two modes, recorded in a manifest at `~/.local/share/toku` that
toku resolves through on every run:

```sh
toku setup
toku setup --use-system
toku setup --path
toku setup --upgrade
toku setup --repair
toku setup --uninstall
```

- `toku setup` provisions the managed tree (or completes a partial one); it
  is safe to re-run.
- `--use-system` records the system `lua`, `luarocks`, and `luac` instead
  of provisioning. It verifies before recording: the interpreter must
  report Lua 5.1 (a 5.1-compatible luajit is accepted) and luarocks must
  target lua 5.1, otherwise it fails with a precise diagnostic. For luac it
  prefers `luac5.1` and accepts `luac` only when `-v` reports 5.1; a luajit
  system may have no lua 5.1 luac at all (luajit uses `luajit -b`), in
  which case none is recorded and `toku luac` and
  `toku bundle --luac-default` error with instructions instead of silently
  using a mismatched luac. The resolved absolute paths and detected
  versions go into the manifest.
- `--path` prints the managed bin directories, colon-joined.
- `--upgrade` rebuilds lua and luarocks at the currently pinned versions and
  reinstalls santoku-cli, keeping the installed rocks tree.
- `--repair` (alias `--force`) recovers a half-built or broken managed tree
  the same way.
- `--uninstall` removes `~/.local/share/toku` entirely, leaving the machine
  as found.

In managed mode, toku prepends the managed bin directories to `PATH` inside
its own process, so every `lua` and `luarocks` invocation made by
toku-driven builds uses the managed pair. In system mode there is no
prepend; `toku lua` and `toku luarocks` use the absolute paths recorded in
the manifest, and builds use your PATH as-is. Nothing outside the toku
process is changed in either mode: no symlinks, no shell rc edits.

To use the managed pair from your shell as well, wire it up yourself:

```sh
export PATH="$(toku setup --path):$PATH"
```

or symlink the binaries you want from the directories `toku setup --path`
prints into a directory of your choosing. toku never does this for you.

`toku lua` runs the resolved lua (in managed mode with the managed rocks
tree on its package path). `toku luarocks ...` and `toku luac ...` pass
through to the resolved luarocks and luac. `toku bundle --luac-default`
compiles bytecode with the resolved luac rather than whatever `luac` is on
PATH, so a system 5.4 luac can never corrupt a bundle.

## Doctor

`toku doctor` reports the mode (managed, system, or not set up) and which
lua and luarocks are actually in effect. In managed mode it checks the
tree's health and version drift against the pinned versions. In system mode
it re-probes the recorded binaries and flags drift: a recorded lua or luac
that now reports a different version (say a distro upgrade to 5.4), a
luarocks that no longer targets 5.1, missing binaries, or a shell `PATH`
that resolves luarocks somewhere other than the recorded path. A recorded
absence of luac is reported but is not an error. It also reports your shell
`PATH` wiring and build prerequisites, and exits nonzero when a problem is
found.

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

test("run a lua string through an explicit interpreter", function ()
  assert(eq("2", run(toku .. " lua --lua " .. var("LUA") .. " --string 'print(1 + 1)'")))
end)
```
