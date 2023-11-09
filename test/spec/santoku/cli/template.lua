local assert = require("luassert")
local test = require("santoku.test")
local sys = require("santoku.system")
local err = require("santoku.err")

test("santoku-cli", function ()

  test("template", function ()

    test("should allow stdin/stdout processing", function ()
      local toku = os.getenv("LUA") .. " -l luacov bin/toku.lua"
      local cmd = "echo '<% return \"hello\" %>' | " .. toku .. " template -f - -o -"
      local ok, gen = sys.sh("sh", "-c", cmd)
      assert.equals(true, ok, gen)
      assert.equals("hello", gen:map(err.check):co():head())
    end)

  end)

end)
