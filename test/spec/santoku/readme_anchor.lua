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
