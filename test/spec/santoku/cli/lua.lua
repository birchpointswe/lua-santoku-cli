local env = require("santoku.env")

if env.var("TK_CLI_WASM", nil) == "1" then
  print("Skipping test when TK_CLI_WASM is 1")
  return
end

local test = require("santoku.test")

local validate = require("santoku.validate")
local eq = validate.isequal

local err = require("santoku.error")
local assert = err.assert

local fs = require("santoku.fs")
local sys = require("santoku.system")
local sh = sys.sh

local lua = env.var("LUA")

local function toku (...)
  return sh({ lua, "bin/toku.lua", "lua", "--lua", lua, ... })()
end

test("lua", function ()

  local script = fs.tmpname()
  fs.writefile(script, "local arr = require('santoku.array') print(#arg .. ':' .. arr.concat(arg, ','))")

  test("passes arguments after a positional script", function ()
    assert(eq("2:a,b", toku(script, "a", "b")))
  end)

  test("passes positionals as arguments with --file", function ()
    assert(eq("2:a,b", toku("--file", script, "a", "b")))
  end)

  test("passes dash arguments after --", function ()
    assert(eq("2:-x,b", toku("--", script, "-x", "b")))
  end)

  test("runs a script with no arguments", function ()
    assert(eq("0:", toku(script)))
  end)

  test("rejects arguments with --string", function ()
    assert(eq(false, (err.pcall(toku, "--string", "print(1)", "a"))))
  end)

  fs.rm(script)

end)
