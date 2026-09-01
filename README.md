<p align="center">
  <img src="https://santoku.dev/logo-santoku-cli.png" height="64" alt="santoku-cli">
</p>

# santoku-cli

`toku`, the command line front end for the santoku project framework. It drives
santoku-make to build, test, install, and release Lua libraries, executables, and web
apps, and it exposes the templating, bundling, and interpreter utilities standalone.

## Install

Install instructions live at [santoku.dev](https://santoku.dev/#install).
The sanctioned path is `setup-toku.sh`, served by the site: download it,
read it, then run it. It builds a pinned lua 5.1 and luarocks from
sha256-verified sources into `~/.local/share/toku` (honouring
`XDG_DATA_HOME`), installs santoku-cli there, and writes nothing else.

## Setup

toku requires a one-time setup before any command that needs lua or
luarocks (`toku lua`, `toku luarocks`, and the project commands that drive
builds). Until then those commands error and name the steps to run. There
are two modes, recorded in a manifest at `~/.local/share/toku` that toku
resolves through on every run: managed, provisioned by `setup-toku.sh`
from [santoku.dev](https://santoku.dev/#install), and system, recorded by
`toku setup --use-system`.

`setup-toku.sh` is the only provisioner. When it provisions, it stores a
copy of itself at `~/.local/share/toku/setup-toku.sh`, so the managed tree
always carries the script that built it. The `toku setup` subcommand is
maintenance around that:

```sh
toku setup
toku setup --use-system
toku setup --path
toku setup --upgrade
toku setup --repair
toku setup --uninstall
```

- `toku setup` re-runs the stored `setup-toku.sh` to complete a partial
  managed tree; it is safe to re-run. If the stored copy is missing, or
  its pinned versions differ from this santoku-cli's, it errors and points
  you back at https://santoku.dev/setup-toku.sh.
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
- `--upgrade` runs the stored `setup-toku.sh` with `--rebuild`: lua and
  luarocks are rebuilt at the pinned versions and santoku-cli is
  reinstalled, keeping the installed rocks tree.
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

The setup tests cover path resolution, system-toolchain verification, and
the delegation from `toku setup --repair` and `--upgrade` to the stored
`setup-toku.sh`; provisioning itself lives in that script and is exercised
by running it.

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
