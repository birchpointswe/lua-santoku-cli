local assert = require("luassert")
local test = require("santoku.test")
local sys = require("santoku.system")
local err = require("santoku.err")

test("santoku-cli", function ()

  test("template", function ()

    test("should allow stdin/stdout processing", function ()
      local toku = os.getenv("LUA") .. " -l luacov bin/toku.lua"
      local cmd = "echo '<% return \"hello\" %>' | " ..
        toku .. " template -f - -o -"
      local ok, gen = sys.sh("sh", "-c", cmd)
      assert.equals(true, ok, gen)
      assert.equals("hello", gen:map(err.check):co():head())
    end)

    test("should support multiple configs", function ()
      local toku = os.getenv("LUA") .. " -l luacov bin/toku.lua"
      local cmd = "echo '<% return a %> <% return b %> <% return c %>' | " ..
        toku .. " template -c res/tmpl.cfg0.lua -c res/tmpl.cfg1.lua -f - -o -"
      local ok, gen = sys.sh("sh", "-c", cmd)
      assert.equals(true, ok, gen)
      assert.equals("1 2 3", gen:map(err.check):co():head())
    end)

  end)

end)
