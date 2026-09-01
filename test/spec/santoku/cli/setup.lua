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

local function fake (dir, name, body)
  local fp = fs.join(dir, name)
  fs.mkdirp(dir)
  fs.writefile(fp, body)
  sys.execute({ "chmod", "+x", fp })
  return fp
end

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
    assert(eq("/scratch/data/toku/setup-toku.sh", p.script))
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

  test("resolved and ensure treat an absent manifest as not set up", function ()
    assert(eq(nil, setup.resolved({ root = "/nonexistent/scratch/toku" })))
    local ok = pcall(setup.ensure, { root = "/nonexistent/scratch/toku" })
    assert(eq(false, ok))
  end)

  test("activate is a no-op when there is no manifest", function ()
    local before = os.getenv("PATH")
    assert(eq(nil, setup.activate("/nonexistent/scratch/toku")))
    assert(eq(before, os.getenv("PATH")))
  end)

  test("uninstall refuses unexpected roots", function ()
    local ok = pcall(setup.uninstall, { root = "/nonexistent/scratch/other" })
    assert(eq(false, ok))
  end)

  test("run errors without a stored setup-toku.sh", function ()
    local ok, e, hint = pcall(setup.run, { root = "/nonexistent/scratch/toku" })
    assert(eq(false, ok))
    assert(string.find(tostring(e), "provisioning script", 1, true) ~= nil)
    assert(string.find(tostring(hint), "santoku.dev/setup-toku.sh", 1, true) ~= nil)
  end)

  test("delegation", function ()

    local dir = fs.join(var("HOME"), "tmp", "toku-setup-delegate-spec")
    local root = fs.join(dir, "toku")

    local function stored (body)
      sys.execute({ "rm", "-rf", "--", dir })
      fs.mkdirp(root)
      local fp = fs.join(root, "setup-toku.sh")
      fs.writefile(fp, body)
      sys.execute({ "chmod", "+x", fp })
      return fp
    end

    test("run refuses a stored script with drifted pins", function ()
      stored("#!/bin/sh\nLUA_VERSION=9.9.9\nLUAROCKS_VERSION=8.8.8\nexit 1\n")
      local ok, e = pcall(setup.run, { root = root })
      assert(eq(false, ok))
      assert(string.find(tostring(e), "9.9.9", 1, true) ~= nil)
      assert(string.find(tostring(e), setup.pins.lua.version, 1, true) ~= nil)
    end)

    test("run execs the stored script with --root, adding --rebuild for repair and upgrade", function ()
      local log = fs.join(root, "args.log")
      stored("#!/bin/sh\n" ..
        "LUA_VERSION=" .. setup.pins.lua.version .. "\n" ..
        "LUAROCKS_VERSION=" .. setup.pins.luarocks.version .. "\n" ..
        "printf '%s\\n' \"$@\" > " .. log .. "\n")
      setup.run({ root = root })
      assert(eq("--root\n" .. root .. "\n", fs.readfile(log)))
      setup.run({ root = root, repair = true })
      assert(eq("--root\n" .. root .. "\n--rebuild\n", fs.readfile(log)))
      setup.run({ root = root, upgrade = true })
      assert(eq("--root\n" .. root .. "\n--rebuild\n", fs.readfile(log)))
    end)

    sys.execute({ "rm", "-rf", "--", dir })

  end)

  test("use-system", function ()

    local dir = fs.join(var("HOME"), "tmp", "toku-use-system-spec")
    local bindir = fs.join(dir, "bin")
    local root = fs.join(dir, "toku")
    sys.execute({ "rm", "-rf", "--", dir })

    test("rejects a non-5.1 interpreter", function ()
      local bad = fake(bindir, "lua54", "#!/bin/sh\nprintf 'Lua 5.4'\n")
      local ok, e = pcall(setup.use_system, { root = root, lua = bad })
      assert(eq(false, ok))
      assert(string.find(tostring(e), "5.1", 1, true) ~= nil)
      assert(eq(false, fs.exists(fs.join(root, "manifest.lua"))))
    end)

    test("rejects a luarocks that does not target 5.1", function ()
      local flua = fake(bindir, "lua", "#!/bin/sh\nprintf 'Lua 5.1'\n")
      local bad = fake(bindir, "luarocks54",
        "#!/bin/sh\nif [ \"$1\" = \"--version\" ]; then\n" ..
        "  printf 'fake-luarocks 3.11.1\\n'\nelse\n  printf '5.4\\n'\nfi\n")
      local ok, e = pcall(setup.use_system, { root = root, lua = flua, luarocks = bad })
      assert(eq(false, ok))
      assert(string.find(tostring(e), "5.1", 1, true) ~= nil)
      assert(eq(false, fs.exists(fs.join(root, "manifest.lua"))))
    end)

    test("rejects a luac that is not 5.1", function ()
      local flua = fake(bindir, "lua", "#!/bin/sh\nprintf 'Lua 5.1'\n")
      local flr = fake(bindir, "luarocks_ok",
        "#!/bin/sh\nif [ \"$1\" = \"--version\" ]; then\n" ..
        "  printf 'fake-luarocks 3.11.1\\n'\nelse\n  printf '5.1\\n'\nfi\n")
      local bad = fake(bindir, "luac54",
        "#!/bin/sh\nprintf 'Lua 5.4.8  Copyright (C) 1994-2024 Lua.org, PUC-Rio\\n'\n")
      local ok, e = pcall(setup.use_system,
        { root = root, lua = flua, luarocks = flr, luac = bad })
      assert(eq(false, ok))
      assert(string.find(tostring(e), "5.1", 1, true) ~= nil)
      assert(eq(false, fs.exists(fs.join(root, "manifest.lua"))))
    end)

    test("records a verified system trio and resolves through it", function ()
      local flua = fake(bindir, "lua",
        "#!/bin/sh\nprintf 'Lua 5.1\\tLuaJIT 2.1.0-fake'\n")
      local flr = fake(bindir, "luarocks",
        "#!/bin/sh\nif [ \"$1\" = \"--version\" ]; then\n" ..
        "  printf 'fake-luarocks 3.11.1\\n'\nelse\n  printf '5.1\\n'\nfi\n")
      local fluac = fake(bindir, "luac",
        "#!/bin/sh\nprintf 'Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio\\n'\n")
      setup.use_system({ root = root, lua = flua, luarocks = flr, luac = fluac,
        version = "spec" })
      local m = fs.runfile(fs.join(root, "manifest.lua"))
      assert(eq("system", m.mode))
      assert(eq(flua, m.lua_exe))
      assert(eq("Lua 5.1", m.lua_version))
      assert(eq("LuaJIT 2.1.0-fake", m.lua_jit))
      assert(eq(fluac, m.luac_exe))
      assert(eq("5.1.5", m.luac_version))
      assert(eq(flr, m.luarocks_exe))
      assert(eq("3.11.1", m.luarocks_version))
      assert(eq("5.1", m.luarocks_lua_version))
      assert(eq("spec", m.cli))
      local r = setup.ensure({ root = root })
      assert(eq("system", r.mode))
      assert(eq(flua, r.lua_exe))
      assert(eq(flr, r.luarocks_exe))
      assert(eq(fluac, setup.ensure_luac(r)))
      local before = os.getenv("PATH")
      assert(eq(nil, setup.activate(root)))
      assert(eq(before, os.getenv("PATH")))
      assert(eq(0, setup.doctor({
        root = root,
        path = bindir .. ":" .. (os.getenv("PATH") or ""),
      })))
    end)

    test("records no luac when none matches and ensure_luac errors", function ()
      local emptydir = fs.join(dir, "empty")
      fs.mkdirp(emptydir)
      setup.use_system({ root = root,
        lua = fs.join(bindir, "lua"),
        luarocks = fs.join(bindir, "luarocks"),
        path = emptydir,
        version = "spec" })
      local m = fs.runfile(fs.join(root, "manifest.lua"))
      assert(eq("system", m.mode))
      assert(eq(nil, m.luac_exe))
      assert(eq(nil, m.luac_version))
      local r = setup.ensure({ root = root })
      local ok, e = pcall(setup.ensure_luac, r)
      assert(eq(false, ok))
      assert(string.find(tostring(e), "luac", 1, true) ~= nil)
      assert(eq(0, setup.doctor({
        root = root,
        path = bindir .. ":" .. (os.getenv("PATH") or ""),
      })))
    end)

    test("doctor flags a system pair that drifted", function ()
      fake(bindir, "lua", "#!/bin/sh\nprintf 'Lua 5.4'\n")
      assert(setup.doctor({
        root = root,
        path = bindir .. ":" .. (os.getenv("PATH") or ""),
      }) > 0)
    end)

    sys.execute({ "rm", "-rf", "--", dir })

  end)

end)
