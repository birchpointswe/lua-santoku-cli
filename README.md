<p align="center">
  <img src="https://santoku.dev/logo-santoku-cli.png" height="64" alt="santoku-cli">
</p>

# santoku-cli

`toku`, the command line front end for the santoku project framework. It drives
santoku-make to build, test, install, and release Lua libraries, executables, and web
apps, and it exposes the templating, bundling, and interpreter utilities standalone.

## Install

```sh
luarocks install santoku-cli
```

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
[`test/spec/santoku/cli/template.lua`](test/spec/santoku/cli/template.lua).

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
