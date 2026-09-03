local err = require("santoku.error")
local error = err.error
local assert = err.assert
local pcall = err.pcall

local fs = require("santoku.fs")
local sys = require("santoku.system")
local env = require("santoku.env")

local str = require("santoku.string")
local printf = str.printf
local format = str.format

local sfind = string.find
local smatch = string.match
local sgmatch = string.gmatch
local tconcat = table.concat
local getenv = os.getenv

local pins = {
  lua = { version = "5.1.5" },
  luarocks = { version = "3.13.0" },
}

local script_url = "https://santoku.dev/setup-toku.sh"

local not_set_up =
  "toku is not set up: download " .. script_url ..
  ", read it, then run it (managed lua 5.1 toolchain)"

local function data_home ()
  local xdg = getenv("XDG_DATA_HOME")
  if xdg and xdg ~= "" then
    return xdg
  end
  return fs.join(env.var("HOME"), ".local", "share")
end

local function paths (root)
  root = root or fs.join(data_home(), "toku")
  local p = { root = root }
  p.lua = fs.join(root, "lua")
  p.luarocks = fs.join(root, "luarocks")
  p.rocks = fs.join(root, "rocks")
  p.src = fs.join(root, "src")
  p.lua_bin = fs.join(p.lua, "bin")
  p.luarocks_bin = fs.join(p.luarocks, "bin")
  p.rocks_bin = fs.join(p.rocks, "bin")
  p.lua_exe = fs.join(p.lua_bin, "lua")
  p.luac_exe = fs.join(p.lua_bin, "luac")
  p.luarocks_exe = fs.join(p.luarocks_bin, "luarocks")
  p.toku_exe = fs.join(p.rocks_bin, "toku")
  p.luarocks_cfg = fs.join(p.luarocks, "etc", "luarocks", "config-5.1.lua")
  p.manifest = fs.join(root, "manifest.lua")
  p.script = fs.join(root, "setup-toku.sh")
  return p
end

local function path_string (p)
  p = p or paths()
  return tconcat({ p.rocks_bin, p.luarocks_bin, p.lua_bin }, ":")
end

local function lua_path (p)
  p = p or paths()
  local d = fs.join(p.rocks, "share", "lua", "5.1")
  return fs.join(d, "?.lua") .. ";" .. fs.join(d, "?", "init.lua")
end

local function lua_cpath (p)
  p = p or paths()
  return fs.join(p.rocks, "lib", "lua", "5.1", "?.so")
end

local function exists_file (fp)
  local ok, is = pcall(fs.isfile, fp)
  return ok and is or false
end

local function which (name, path)
  path = path or getenv("PATH") or ""
  for dir in sgmatch(path, "[^:]+") do
    local fp = fs.join(dir, name)
    if exists_file(fp) then
      return fp
    end
  end
end

local function firstline (cmd)
  local first
  for line in sys.sh(cmd) do
    first = first or line
  end
  return first
end

local function missing_tools ()
  local missing = {}
  for _, t in ipairs({ "cc", "make", "tar", "unzip" }) do
    if not which(t) then
      missing[#missing + 1] = t
    end
  end
  if not (which("curl") or which("wget")) then
    missing[#missing + 1] = "curl or wget"
  end
  if not (which("sha256sum") or which("shasum") or which("openssl")) then
    missing[#missing + 1] = "sha256sum, shasum, or openssl"
  end
  return missing
end

local function script_pins (fp)
  local ok, src = pcall(fs.readfile, fp)
  if not ok or type(src) ~= "string" then
    return nil, nil
  end
  local lv = smatch(src, "^LUA_VERSION=(%S+)") or smatch(src, "\nLUA_VERSION=(%S+)")
  local rv = smatch(src, "^LUAROCKS_VERSION=(%S+)") or smatch(src, "\nLUAROCKS_VERSION=(%S+)")
  return lv, rv
end

local function read_manifest (p)
  if not fs.isfile(p.manifest) then
    return nil
  end
  local ok, m = pcall(fs.runfile, p.manifest)
  if ok and type(m) == "table" then
    return m
  end
  return nil
end

local function resolved (opts)
  opts = opts or {}
  local p = paths(opts.root)
  local m = read_manifest(p)
  if not m then
    return nil
  end
  if m.mode == "managed" then
    return { mode = "managed", lua_exe = p.lua_exe, luarocks_exe = p.luarocks_exe,
      manifest = m, paths = p }
  end
  return nil
end

local function ensure (opts)
  local r = resolved(opts)
  if not r then
    return error(not_set_up)
  end
  if not exists_file(r.lua_exe) or not exists_file(r.luarocks_exe) then
    return error("managed toolchain is incomplete, run: toku setup --repair")
  end
  return r
end

local function ensure_luac (r)
  if exists_file(r.paths.luac_exe) then
    return r.paths.luac_exe
  end
  return error("managed luac is missing, run: toku setup --repair")
end

local lua_probe_src =
  [[io.write(_VERSION .. "\t" .. tostring((rawget(_G, "jit") or {}).version or ""))]]

local function probe_lua (exe)
  local ok, out = pcall(firstline, { exe, "-e", lua_probe_src })
  if not ok or not out then
    return nil
  end
  local ver, jitv = smatch(out, "^([^\t]*)\t?(.*)$")
  if jitv == "" then
    jitv = nil
  end
  return ver, jitv
end

local function probe_luarocks (exe)
  local ok, out = pcall(firstline, { exe, "--version" })
  if not ok or not out then
    return nil
  end
  return smatch(out, "(%d[%d%.]*%d)") or out
end

local function probe_luac (exe)
  local ok, out = pcall(firstline, { exe, "-v" })
  if not ok or not out then
    return nil
  end
  return smatch(out, "Lua (%d[%d%.]*%d)") or smatch(out, "(%d[%d%.]*%d)")
end

local function run (opts)
  opts = opts or {}
  local p = paths(opts.root)
  assert(not smatch(p.root, "%s"), "managed root contains whitespace", p.root)
  if not exists_file(p.script) then
    return error("no provisioning script at " .. p.script,
      "download " .. script_url .. ", read it, then run it")
  end
  local lv, rv = script_pins(p.script)
  if lv ~= pins.lua.version or rv ~= pins.luarocks.version then
    return error(format(
      "stored setup-toku.sh provisions lua %s and luarocks %s, " ..
      "but this santoku-cli pins lua %s and luarocks %s",
      lv or "?", rv or "?", pins.lua.version, pins.luarocks.version),
      "download the current " .. script_url .. ", read it, then run it")
  end
  local cmd = { "sh", p.script, "--root", p.root }
  if opts.upgrade or opts.repair then
    cmd[#cmd + 1] = "--rebuild"
  end
  printf("[setup]\tdelegating to %s\n", p.script)
  sys.execute(cmd)
end

local function uninstall (opts)
  opts = opts or {}
  local p = paths(opts.root)
  assert(fs.basename(p.root) == "toku", "refusing to remove unexpected root", p.root)
  if not fs.exists(p.root) then
    printf("[setup]\tnothing to remove at %s\n", p.root)
    return
  end
  sys.execute({ "rm", "-rf", "--", p.root })
  printf("[setup]\tremoved %s\n", p.root)
end

local function activate (root)
  local r = resolved({ root = root })
  if not r then
    return nil
  end
  local p = r.paths
  if not exists_file(p.lua_exe) or not exists_file(p.luarocks_exe) then
    return nil
  end
  local cur = getenv("PATH") or ""
  local out = {}
  for _, d in ipairs({ p.rocks_bin, p.luarocks_bin, p.lua_bin }) do
    if not sfind(":" .. cur .. ":", ":" .. d .. ":", 1, true) then
      out[#out + 1] = d
    end
  end
  if #out > 0 then
    out[#out + 1] = cur
    sys.setenv("PATH", tconcat(out, ":"))
  end
  return getenv("PATH")
end

local function doctor_managed (p, m, shellpath, prob)
  printf("  pinned versions: lua %s, luarocks %s\n", pins.lua.version, pins.luarocks.version)
  printf("  manifest: lua %s, luarocks %s, cli %s, built %s (%s)\n",
    m.lua or "?", m.luarocks or "?", m.cli or "?", m.created or "?", m.platform or "?")
  if m.lua ~= pins.lua.version or m.luarocks ~= pins.luarocks.version then
    prob("manifest versions differ from pinned versions, run: toku setup --upgrade")
  end
  if exists_file(p.script) then
    local lv, rv = script_pins(p.script)
    if lv == pins.lua.version and rv == pins.luarocks.version then
      printf("  stored setup-toku.sh: %s (pins match)\n", p.script)
    else
      printf("  stored setup-toku.sh: %s (pins lua %s, luarocks %s)\n",
        p.script, lv or "?", rv or "?")
      prob("stored setup-toku.sh pins differ from this santoku-cli's, " ..
        "download the current " .. script_url .. ", read it, then run it")
    end
  else
    printf("  stored setup-toku.sh: missing\n")
    prob("managed tree carries no setup-toku.sh, so --repair and --upgrade cannot run, " ..
      "download " .. script_url .. ", read it, then run it")
  end
  if exists_file(p.lua_exe) then
    local v = probe_lua(p.lua_exe)
    if v then
      printf("  managed lua: %s (%s)\n", p.lua_exe, v)
    else
      printf("  managed lua: %s (broken)\n", p.lua_exe)
      prob("managed lua exists but does not run, run: toku setup --repair")
    end
  else
    printf("  managed lua: missing\n")
    prob("managed lua missing, run: toku setup --repair")
  end
  if exists_file(p.luac_exe) then
    local v = probe_luac(p.luac_exe)
    if v then
      printf("  managed luac: %s (%s)\n", p.luac_exe, v)
    else
      printf("  managed luac: %s (broken)\n", p.luac_exe)
      prob("managed luac exists but does not run, run: toku setup --repair")
    end
  else
    printf("  managed luac: missing\n")
    prob("managed luac missing, run: toku setup --repair")
  end
  if exists_file(p.luarocks_exe) then
    local v = probe_luarocks(p.luarocks_exe)
    if v then
      printf("  managed luarocks: %s (%s)\n", p.luarocks_exe, v)
    else
      printf("  managed luarocks: %s (broken)\n", p.luarocks_exe)
      prob("managed luarocks exists but does not run, run: toku setup --repair")
    end
  else
    printf("  managed luarocks: missing\n")
    prob("managed luarocks missing, run: toku setup --repair")
  end
  if exists_file(p.toku_exe) then
    printf("  managed toku: %s\n", p.toku_exe)
  else
    printf("  managed toku: missing\n")
    prob("santoku-cli is not installed in the managed tree, run: toku setup")
  end
  if exists_file(p.lua_exe) and exists_file(p.luarocks_exe) then
    printf("  in-process PATH prepend: active (toku-driven builds use the managed pair)\n")
  else
    printf("  in-process PATH prepend: inactive (managed pair incomplete)\n")
  end
  for _, name in ipairs({ "lua", "luarocks" }) do
    local fp = which(name, shellpath)
    local managed = name == "lua" and p.lua_exe or p.luarocks_exe
    if not fp then
      printf("  shell %s: none on PATH\n", name)
    elseif fp == managed then
      printf("  shell %s: %s (managed)\n", name, fp)
    else
      printf("  shell %s: %s (not managed)\n", name, fp)
    end
  end
  local wired = true
  for _, d in ipairs({ p.rocks_bin, p.luarocks_bin, p.lua_bin }) do
    if not sfind(":" .. shellpath .. ":", ":" .. d .. ":", 1, true) then
      wired = false
    end
  end
  if wired then
    printf("  shell PATH wiring: managed bin dirs are on your PATH\n")
  else
    printf("  shell PATH wiring: not wired (optional), to opt in:\n")
    printf("    export PATH=\"%s:$PATH\"\n", path_string(p))
  end
end

local function web_parts ()
  if not (fs.exists("make.lua") or fs.exists("make.common.lua")) then
    return false, false
  end
  return fs.isdir("client"), fs.isdir("server")
end

local function missing_web_tools (client, server)
  local missing = {}
  if client then
    for _, t in ipairs({ "emcc", "emmake", "node" }) do
      if not which(t) then
        missing[#missing + 1] = t
      end
    end
  end
  if server then
    if not which("openresty") then
      missing[#missing + 1] = "openresty"
    end
    local ord = getenv("OPENRESTY_DIR")
    if not ord or ord == "" then
      missing[#missing + 1] = "OPENRESTY_DIR (env var, the install prefix not the binary)"
    elseif not fs.isdir(ord) then
      missing[#missing + 1] = "OPENRESTY_DIR points at " .. ord .. ", which is not a directory"
    end
  end
  return missing
end

local function doctor (opts)
  opts = opts or {}
  local p = paths(opts.root)
  local shellpath = opts.path or getenv("PATH") or ""
  local probs = {}
  local function prob (s)
    probs[#probs + 1] = s
  end
  printf("toku doctor\n")
  if opts.argv0 then
    printf("  running toku: %s\n", opts.argv0)
  end
  printf("  root: %s (%s)\n", p.root, fs.isdir(p.root) and "present" or "absent")
  local m = read_manifest(p)
  if m and m.mode == "managed" then
    printf("  mode: managed\n")
    doctor_managed(p, m, shellpath, prob)
  elseif m then
    printf("  mode: unknown (stale manifest)\n")
    prob("manifest has no valid mode, provision with " .. script_url)
  elseif fs.isdir(p.root) then
    printf("  mode: not set up (root exists without a manifest)\n")
    prob("root exists without a manifest (half-built tree), run: toku setup --repair")
  else
    printf("  mode: not set up\n")
  end
  local missing = missing_tools()
  if #missing > 0 then
    printf("  build prerequisites: missing %s\n", tconcat(missing, ", "))
  else
    printf("  build prerequisites: ok\n")
  end
  local wclient, wserver = web_parts()
  if wclient or wserver then
    local half = wclient and wserver and "client and server"
      or wclient and "client only" or "server only"
    local wmissing = missing_web_tools(wclient, wserver)
    if #wmissing > 0 then
      printf("  web prerequisites (%s): missing %s\n", half, tconcat(wmissing, ", "))
      prob("this is a web project and its toolchain is incomplete; without these the "
        .. "build fails one tool at a time. See the web getting-started tab at "
        .. "https://santoku.dev")
    else
      printf("  web prerequisites (%s): ok\n", half)
    end
  end
  if #probs > 0 then
    printf("problems:\n")
    for i = 1, #probs do
      printf("  %s\n", probs[i])
    end
  elseif not m then
    printf("%s\n", not_set_up)
    return 1
  else
    printf("no problems found\n")
  end
  return #probs
end

return {
  pins = pins,
  script_url = script_url,
  paths = paths,
  path_string = path_string,
  lua_path = lua_path,
  lua_cpath = lua_cpath,
  resolved = resolved,
  ensure = ensure,
  ensure_luac = ensure_luac,
  activate = activate,
  run = run,
  uninstall = uninstall,
  doctor = doctor,
}
