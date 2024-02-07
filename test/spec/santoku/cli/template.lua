if os.getenv("TK_CLI_WASM") == "1" then
  print("Skipping test when TK_CLI_WASM is 1")
  return
end

local test = require("santoku.test")

local validate = require("santoku.validate")
local eq = validate.isequal

local err = require("santoku.error")
local assert = err.assert

local env = require("santoku.env")
local var = env.var

local iter = require("santoku.iter")
local first = iter.first

local sys = require("santoku.system")
local sh = sys.sh

test("template", function ()

  test("should allow stdin/stdout processing", function ()
    local toku = var("LUA") .. " -l luacov bin/toku.lua"
    local cmd = "echo '<% return \"hello\" %>' | " ..
    toku .. " template -f - -o -"
    print(err.pcall(function ()
    assert(eq("hello", first(sh({ "sh", "-c", cmd }))))
    end))
  end)

end)
