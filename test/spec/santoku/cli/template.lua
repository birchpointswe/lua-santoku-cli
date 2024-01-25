if os.getenv("TK_CLI_WASM") == "1" then
  print("Skipping test when TK_CLI_WASM is 1")
  return
end

local test = require("santoku.test")
local sys = require("santoku.system")
local check = require("santoku.check")

test("santoku-cli", function ()

  test("template", function ()

    test("should allow stdin/stdout processing", function ()
      local toku = os.getenv("LUA") .. " -l luacov bin/toku.lua"
      local cmd = "echo '<% return \"hello\" %>' | " ..
      toku .. " template -f - -o -"
      local ok, gen = sys.sh("sh", "-c", cmd)
      assert(ok == true, gen)
      assert(gen:map(check):co():head() == "hello")
    end)

    test("should support multiple configs", function ()
      local toku = os.getenv("LUA") .. " -l luacov bin/toku.lua"
      local cmd = "echo '<% return a %> <% return b %> <% return c %>' | " ..
      toku .. " template -c test/res/tmpl.cfg0.lua -c test/res/tmpl.cfg1.lua -f - -o -"
      local ok, gen = sys.sh("sh", "-c", cmd)
      assert(ok == true, gen)
      assert(gen:map(check):co():head() == "1 2 3")
    end)

  end)

end)
