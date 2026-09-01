if os.getenv("TK_CLI_WASM") == "1" then
  print("Skipping test when TK_CLI_WASM is 1")
  return
end

local test = require("santoku.test")

local validate = require("santoku.validate")
local eq = validate.isequal

local err = require("santoku.error")
local assert = err.assert
local pcall = err.pcall

local env = require("santoku.env")
local var = env.var

local fs = require("santoku.fs")
local sys = require("santoku.system")

local setup = require("santoku.cli.setup")

test("setup", function ()

  test("paths respect XDG_DATA_HOME", function ()
    local old = os.getenv("XDG_DATA_HOME")
    sys.setenv("XDG_DATA_HOME", "/scratch/data")
    local p = setup.paths()
    sys.setenv("XDG_DATA_HOME", old or "")
    assert(eq("/scratch/data/toku", p.root))
    assert(eq("/scratch/data/toku/lua/bin/lua", p.lua_exe))
    assert(eq("/scratch/data/toku/luarocks/bin/luarocks", p.luarocks_exe))
    assert(eq("/scratch/data/toku/rocks/bin/toku", p.toku_exe))
    assert(eq("/scratch/data/toku/luarocks/etc/luarocks/config-5.1.lua", p.luarocks_cfg))
    assert(eq("/scratch/data/toku/src", p.src))
  end)

  test("paths default to ~/.local/share when XDG_DATA_HOME is unset", function ()
    local old = os.getenv("XDG_DATA_HOME")
    sys.setenv("XDG_DATA_HOME", "")
    local p = setup.paths()
    sys.setenv("XDG_DATA_HOME", old or "")
    assert(eq(fs.join(var("HOME"), ".local", "share", "toku"), p.root))
  end)

  test("path_string lists the managed bin dirs in shadowing order", function ()
    local p = setup.paths("/scratch/data/toku")
    assert(eq(
      "/scratch/data/toku/rocks/bin:/scratch/data/toku/luarocks/bin:/scratch/data/toku/lua/bin",
      setup.path_string(p)))
  end)

  test("lua_path and lua_cpath point into the managed rocks tree", function ()
    local p = setup.paths("/scratch/data/toku")
    assert(eq(
      "/scratch/data/toku/rocks/share/lua/5.1/?.lua;" ..
      "/scratch/data/toku/rocks/share/lua/5.1/?/init.lua",
      setup.lua_path(p)))
    assert(eq("/scratch/data/toku/rocks/lib/lua/5.1/?.so", setup.lua_cpath(p)))
  end)

  test("activate is a no-op when the managed tree is absent", function ()
    local before = os.getenv("PATH")
    assert(eq(nil, setup.activate("/nonexistent/scratch/toku")))
    assert(eq(before, os.getenv("PATH")))
  end)

  test("uninstall refuses unexpected roots", function ()
    local ok = pcall(setup.uninstall, { root = "/nonexistent/scratch/other" })
    assert(eq(false, ok))
  end)

  test("bootstrap.sh pins match the module pins", function ()
    local script = fs.readfile("res/bootstrap.sh")
    for _, spec in pairs(setup.pins) do
      assert(string.find(script, spec.version, 1, true) ~= nil)
      assert(string.find(script, spec.url, 1, true) ~= nil)
      assert(string.find(script, spec.sha256, 1, true) ~= nil)
    end
  end)

  if os.getenv("TK_CLI_TEST_SETUP") == "1" then

    test("provisions, doctors, and uninstalls a scratch tree", function ()
      local root = fs.join(var("HOME"), "tmp", "toku-setup-spec", "toku")
      sys.execute({ "rm", "-rf", "--", fs.dirname(root) })
      setup.run({ root = root, version = "spec" })
      assert(eq(true, fs.isfile(fs.join(root, "lua", "bin", "lua"))))
      assert(eq(true, fs.isfile(fs.join(root, "lua", "bin", "luac"))))
      assert(eq(true, fs.isfile(fs.join(root, "luarocks", "bin", "luarocks"))))
      assert(eq(true, fs.isfile(fs.join(root, "rocks", "bin", "toku"))))
      local m = fs.runfile(fs.join(root, "manifest.lua"))
      assert(eq(setup.pins.lua.version, m.lua))
      assert(eq(setup.pins.luarocks.version, m.luarocks))
      assert(eq("spec", m.cli))
      assert(eq(0, setup.doctor({ root = root })))
      setup.run({ root = root, version = "spec" })
      setup.uninstall({ root = root })
      assert(eq(false, fs.exists(root)))
      sys.execute({ "rm", "-rf", "--", fs.dirname(root) })
    end)

  else
    print("Skipping setup provisioning test (set TK_CLI_TEST_SETUP=1 to enable)")
  end

end)
