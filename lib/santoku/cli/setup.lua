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
local startswith = str.startswith

local sfind = string.find
local smatch = string.match
local sgmatch = string.gmatch
local tconcat = table.concat
local tsort = table.sort
local getenv = os.getenv

local pins = {
  lua = { version = "5.1.5" },
  luarocks = { version = "3.13.0" },
}

local script_url = "https://santoku.dev/setup-toku.sh"

local not_set_up =
  "toku is not set up: download " .. script_url ..
  ", read it, then run it (managed lua 5.1 toolchain), or run: toku setup --use-system"

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

local function platform ()
  local ok, out = pcall(firstline, { "uname", "-s" })
  if ok and out and out ~= "" then
    return out
  end
  return "Linux"
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

local function write_manifest (p, t)
  fs.mkdirp(p.root)
  local keys = {}
  for k in pairs(t) do
    keys[#keys + 1] = k
  end
  tsort(keys)
  local out = { "return {\n" }
  for i = 1, #keys do
    out[#out + 1] = format("  %s = %q,\n", keys[i], t[keys[i]])
  end
  out[#out + 1] = "}\n"
  fs.writefile(p.manifest, tconcat(out))
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
  if m.mode == "system" and m.lua_exe and m.luarocks_exe then
    return { mode = "system", lua_exe = m.lua_exe, luarocks_exe = m.luarocks_exe,
      manifest = m, paths = p }
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
    if r.mode == "managed" then
      return error("managed toolchain is incomplete, run: toku setup --repair")
    end
    return error("recorded system lua or luarocks no longer exists, run: toku setup --use-system",
      r.lua_exe, r.luarocks_exe)
  end
  return r
end

local function ensure_luac (r)
  if r.mode == "managed" then
    if exists_file(r.paths.luac_exe) then
      return r.paths.luac_exe
    end
    return error("managed luac is missing, run: toku setup --repair")
  end
  local m = r.manifest
  if not m.luac_exe then
    return error("no lua 5.1 luac recorded (luajit systems often have none)",
      "install a lua 5.1 luac and re-run: toku setup --use-system, " ..
      "or provision the managed toolchain with " .. script_url)
  end
  if not exists_file(m.luac_exe) then
    return error("recorded system luac no longer exists, run: toku setup --use-system",
      m.luac_exe)
  end
  return m.luac_exe
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

local function probe_luarocks_target (exe)
  local ok, out = pcall(firstline, { exe, "config", "lua_version" })
  if ok and out then
    return (smatch(out, "^%s*(%S+)"))
  end
end

local function probe_luac (exe)
  local ok, out = pcall(firstline, { exe, "-v" })
  if not ok or not out then
    return nil
  end
  return smatch(out, "Lua (%d[%d%.]*%d)") or smatch(out, "(%d[%d%.]*%d)")
end

local function is_51 (v)
  return v == "5.1" or (v ~= nil and startswith(v, "5.1."))
end

local function detect_lua (exe)
  local ver, jitv = probe_lua(exe)
  if not ver or ver == "" then
    return error("lua interpreter did not run", exe)
  end
  if ver ~= "Lua 5.1" then
    return error("interpreter is not lua 5.1 compatible: " .. ver, exe,
      "santoku requires lua 5.1 (or a 5.1-compatible luajit), " ..
      "provision a managed 5.1 with " .. script_url)
  end
  return ver, jitv
end

local function detect_luac (explicit, path)
  if explicit then
    local exe = fs.absolute(explicit)
    local v = probe_luac(exe)
    if not is_51(v) then
      return error("luac is not lua 5.1: " .. (v or "did not run"), exe,
        "santoku bytecode requires a lua 5.1 luac")
    end
    return exe, v
  end
  for _, name in ipairs({ "luac5.1", "luac" }) do
    local exe = which(name, path)
    if exe then
      local v = probe_luac(exe)
      if is_51(v) then
        return fs.absolute(exe), v
      end
    end
  end
  return nil
end

local function detect_luarocks (exe)
  local version = probe_luarocks(exe)
  if not version then
    return error("luarocks did not run", exe)
  end
  local target = probe_luarocks_target(exe)
  if not target then
    return error("could not determine which lua version luarocks targets", exe,
      "santoku requires a luarocks targeting lua 5.1")
  end
  if target ~= "5.1" then
    return error("luarocks targets lua " .. target .. ", not 5.1", exe,
      "santoku rocks pin lua == 5.1 and cannot install with this luarocks, " ..
      "provision a managed pair with " .. script_url)
  end
  return version, target
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

local function use_system (opts)
  opts = opts or {}
  local p = paths(opts.root)
  local lua_exe = opts.lua or which("lua", opts.path) or which("lua5.1", opts.path) or
    which("luajit", opts.path)
  if not lua_exe then
    return error("no lua interpreter found on PATH (tried lua, lua5.1, luajit)",
      "install lua 5.1 or provision a managed 5.1 with " .. script_url)
  end
  lua_exe = fs.absolute(lua_exe)
  local ver, jitv = detect_lua(lua_exe)
  local luarocks_exe = opts.luarocks or which("luarocks", opts.path) or
    which("luarocks-5.1", opts.path)
  if not luarocks_exe then
    return error("no luarocks found on PATH (tried luarocks, luarocks-5.1)",
      "install a luarocks targeting lua 5.1 or provision a managed pair with " .. script_url)
  end
  luarocks_exe = fs.absolute(luarocks_exe)
  local lr_version, lr_target = detect_luarocks(luarocks_exe)
  local luac_exe, luac_version = detect_luac(opts.luac, opts.path)
  write_manifest(p, {
    mode = "system",
    lua_exe = lua_exe,
    lua_version = ver,
    lua_jit = jitv,
    luac_exe = luac_exe,
    luac_version = luac_version,
    luarocks_exe = luarocks_exe,
    luarocks_version = lr_version,
    luarocks_lua_version = lr_target,
    cli = opts.version or "unknown",
    platform = platform(),
    created = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  })
  printf("[setup]\tusing system toolchain\n")
  printf("[setup]\tlua: %s (%s%s)\n", lua_exe, ver, jitv and (", " .. jitv) or "")
  printf("[setup]\tluarocks: %s (%s, targets lua %s)\n", luarocks_exe, lr_version, lr_target)
  if luac_exe then
    printf("[setup]\tluac: %s (%s)\n", luac_exe, luac_version)
  else
    printf("[setup]\tluac: none found for lua 5.1 (luajit systems often have none), " ..
      "toku luac and toku bundle --luac-default will be unavailable\n")
  end
  printf("[setup]\trecorded in %s\n", p.manifest)
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
  if not r or r.mode ~= "managed" then
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

local function doctor_system (p, m, shellpath, prob)
  printf("  recorded lua: %s (%s%s)\n", m.lua_exe or "?", m.lua_version or "?",
    m.lua_jit and (", " .. m.lua_jit) or "")
  if not m.lua_exe or not exists_file(m.lua_exe) then
    printf("  lua on disk: missing\n")
    prob("recorded system lua no longer exists, run: toku setup --use-system")
  else
    local v = probe_lua(m.lua_exe)
    if not v or v == "" then
      printf("  lua on disk: broken (does not run)\n")
      prob("recorded system lua does not run, run: toku setup --use-system")
    elseif v ~= m.lua_version then
      printf("  lua on disk: reports %s (recorded %s)\n", v, m.lua_version or "?")
      prob("system lua drifted from the recorded version, " ..
        "run: toku setup --use-system to re-verify, " ..
        "or provision a managed 5.1 with " .. script_url)
    else
      printf("  lua on disk: matches (%s)\n", v)
    end
  end
  printf("  recorded luarocks: %s (%s, targets lua %s)\n",
    m.luarocks_exe or "?", m.luarocks_version or "?", m.luarocks_lua_version or "?")
  if not m.luarocks_exe or not exists_file(m.luarocks_exe) then
    printf("  luarocks on disk: missing\n")
    prob("recorded system luarocks no longer exists, run: toku setup --use-system")
  else
    local v = probe_luarocks(m.luarocks_exe)
    local target = probe_luarocks_target(m.luarocks_exe)
    if not v then
      printf("  luarocks on disk: broken (does not run)\n")
      prob("recorded system luarocks does not run, run: toku setup --use-system")
    elseif target ~= "5.1" then
      printf("  luarocks on disk: %s, targets lua %s\n", v, target or "unknown")
      prob("system luarocks now targets lua " .. (target or "unknown") ..
        ", santoku requires 5.1, provision a managed pair with " .. script_url)
    elseif v ~= m.luarocks_version then
      printf("  luarocks on disk: %s targeting lua 5.1 (recorded %s)\n",
        v, m.luarocks_version or "?")
    else
      printf("  luarocks on disk: matches (%s, lua 5.1)\n", v)
    end
  end
  if m.luac_exe then
    printf("  recorded luac: %s (%s)\n", m.luac_exe, m.luac_version or "?")
    if not exists_file(m.luac_exe) then
      printf("  luac on disk: missing\n")
      prob("recorded system luac no longer exists, run: toku setup --use-system")
    else
      local v = probe_luac(m.luac_exe)
      if not v then
        printf("  luac on disk: broken (does not run)\n")
        prob("recorded system luac does not run, run: toku setup --use-system")
      elseif not is_51(v) then
        printf("  luac on disk: reports %s (recorded %s)\n", v, m.luac_version or "?")
        prob("system luac now reports " .. v .. ", not 5.1, run: toku setup --use-system")
      elseif v ~= m.luac_version then
        printf("  luac on disk: reports %s (recorded %s)\n", v, m.luac_version or "?")
        prob("system luac drifted from the recorded version, run: toku setup --use-system")
      else
        printf("  luac on disk: matches (%s)\n", v)
      end
    end
  else
    printf("  recorded luac: none (luajit systems often have none, " ..
      "toku luac and toku bundle --luac-default are unavailable)\n")
  end
  local shell_lua = which("lua", shellpath)
  if shell_lua == m.lua_exe then
    printf("  shell lua: %s (matches recorded)\n", shell_lua)
  else
    printf("  shell lua: %s (recorded %s)\n", shell_lua or "none on PATH", m.lua_exe or "?")
  end
  local shell_luarocks = which("luarocks", shellpath)
  if shell_luarocks == m.luarocks_exe then
    printf("  shell luarocks: %s (matches recorded)\n", shell_luarocks)
  else
    printf("  shell luarocks: %s (recorded %s)\n",
      shell_luarocks or "none on PATH", m.luarocks_exe or "?")
    prob("shell PATH resolves luarocks to " .. (shell_luarocks or "nothing") ..
      " but the manifest recorded " .. (m.luarocks_exe or "?") ..
      ", toku-driven builds use PATH, run: toku setup --use-system to re-record")
  end
  if fs.isdir(p.lua) or fs.isdir(p.luarocks) then
    printf("  note: a managed toolchain also exists at %s (inactive in system mode)\n", p.root)
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
  elseif m and m.mode == "system" then
    printf("  mode: system\n")
    doctor_system(p, m, shellpath, prob)
  elseif m then
    printf("  mode: unknown (stale manifest)\n")
    prob("manifest has no valid mode, provision with " .. script_url ..
      " or run: toku setup --use-system")
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
  use_system = use_system,
  uninstall = uninstall,
  doctor = doctor,
}
