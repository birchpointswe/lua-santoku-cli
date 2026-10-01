-- SPDX-License-Identifier: MIT
-- SPDX-FileCopyrightText: 2023 Birch Point SWE
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
local str = require("santoku.string")
local arr = require("santoku.array")
local sys = require("santoku.system")

local lua = env.var("LUA")
local toku_bin = fs.absolute("bin/toku.lua")
local dir = fs.absolute("test/res/license")

local function quote (s)
  return "'" .. str.gsub(s, "'", "'\\''") .. "'"
end

local function toku (...)
  local cmd = { "cd", quote(dir), "&&", quote(lua), quote(toku_bin), "license" }
  for _, a in ipairs({ ... }) do
    arr.push(cmd, quote(a))
  end
  local out, errs, status = {}, {}, nil
  for ev, _, a, b in sys.pread({ "sh", "-c", arr.concat(cmd, " "), stderr = true }) do
    if ev == "stdout" then
      arr.push(out, a)
    elseif ev == "stderr" then
      arr.push(errs, a)
    elseif ev == "exit" then
      status = b
    end
  end
  return status, arr.concat(out), arr.concat(errs)
end

local function git (...)
  sys.execute({ "git", "-C", dir, "-c", "core.hooksPath=/nonexistent", "-c", "init.defaultBranch=master", ... })
end

local function fixture (make_lua)
  sys.execute({ "rm", "-rf", dir })
  fs.mkdirp(dir)
  fs.writefile(fs.join(dir, "make.lua"), make_lua)
  fs.writefile(fs.join(dir, "a.lua"), "return 1\n")
  git("init", "-q")
  git("add", "-A")
  git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--no-verify",
    "--date=2023-05-01T12:00:00", "-m", "x")
end

test("license", function ()

  test("a copyright alone writes the all-rights-reserved LICENSE and passes --check", function ()
    fixture("return { env = { name = \"x\", copyright = \"Acme\" } }\n")
    local status, out, errs = toku()
    assert(eq(0, status), errs)
    assert(eq("Copyright 2023 Acme. All rights reserved.\n", fs.readfile(fs.join(dir, "LICENSE"))))
    assert(str.find(out, "LICENSE written for 2023 Acme", 1, true), out)
    assert(str.find(errs, "license is not set", 1, true), errs)
    local cstatus, _, cerrs = toku("--check")
    assert(eq(0, cstatus), cerrs)
  end)

  test("--check fails and names each file missing a header", function ()
    fixture("return { env = { name = \"x\", copyright = \"Acme\" } }\n")
    fs.writefile(fs.join(dir, "LICENSE"), "MIT License\n\nCopyright (c) 2023 Acme\n")
    local status, _, errs = toku("--check", "--license", "MIT")
    assert(eq(1, status), errs)
    assert(str.find(errs, "toku license: a.lua: missing header", 1, true), errs)
  end)

  test("--check reads make.lua's vendored entries", function ()
    fixture("return { env = { name = \"x\", copyright = \"Acme\", vendored = {\n"
      .. "  { name = \"Lib\", version = \"1.0\", license = \"MIT\", path = \"ghost/*\" } } } }\n")
    fs.writefile(fs.join(dir, "LICENSE"), "Copyright 2023 Acme. All rights reserved.\n")
    local status, _, errs = toku("--check")
    assert(eq(1, status), errs)
    assert(str.find(errs, "toku license: vendored Lib: ghost/* matches no tracked file", 1, true), errs)
  end)

  test("no make.lua and no flags warns and writes nothing", function ()
    fixture("return {}\n")
    fs.rm(fs.join(dir, "make.lua"))
    local status, _, errs = toku()
    assert(eq(0, status), errs)
    assert(eq(false, fs.exists(fs.join(dir, "LICENSE"))))
    assert(str.find(errs, "copyright is not set", 1, true), errs)
  end)

  sys.execute({ "rm", "-rf", dir })

end)
