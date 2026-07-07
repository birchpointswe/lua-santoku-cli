local err = require("santoku.error")
local error = err.error
local argparse = require("argparse")
local bundle = require("santoku.bundle")
local project = require("santoku.make.project")
local runtests = require("santoku.test.runner")
local env = require("santoku.env")
local sys = require("santoku.system")
local arr = require("santoku.array")
local inherit = require("santoku.inherit")
local pushindex = inherit.pushindex

local str = require("santoku.string")
local ssub = str.sub
local ssplits = str.splits
local startswith = str.startswith

local fs = require("santoku.fs")
local runfile = fs.runfile
local mode = fs.mode
local mkdirp = fs.mkdirp
local files = fs.files
local writefile = fs.writefile
local dirname = fs.dirname
local basename = fs.basename
local cwd = fs.cwd
local stdin = io.stdin
local stdout = io.stdout

local template = require("santoku.template")
local renderfile = template.renderfile
local serialize_deps = template.serialize_deps

local mustache = require("santoku.mustache")

local parser = argparse()
  :name("toku")
  :description("A command line interface to the santoku lua library")
  :epilog("<% return name %> <% return version %>")

parser
  :command_target("command")
  :option("--verbosity", "Verbosity", nil, tonumber, 1, "0-1")

local clua = parser
  :command("lua", "Run the lua interpreter on a file")

clua
  :option("--lua", "Specify the lua interpreter")
  :count("0-1")

clua
  :option("--serialize", "Replace global print with an auto-serializing wrapper.")
  :args(0)
  :count("?")

clua
  :option("--profile", "Run the profiler")
  :args(0)
  :count("?")

clua
  :option("--trace", "Run the tracer")
  :args(0)
  :count("?")

clua:mutex(
  clua
    :option("--string", "Run the provided lua string")
    :args(1)
    :count("?"),
  clua
    :option("--file", "Run the provided lua file")
    :args(1)
    :count("?"))

local cbundle = parser
  :command("bundle", "Create standalone executables")

cbundle
  :option("--env", "Set an environment variable that applies only at runtime")
  :args(2)
  :count("*")

cbundle
  :option("--mod", "Load a module during startup")
  :args(1)
  :count("*")

cbundle
  :option("--flags", "Set compile command-line flags")
  :args(1)
  :count("*")

cbundle:mutex(
  cbundle
    :option("--luac", "Set luac command string")
    :args(1)
    :count("0-1"),
  cbundle
    :flag("--luac-off", "Disable the luac step")
    :count("0-1"),
  cbundle
    :flag("--luac-default", "Use the default luac command (e.g. luac -s -o %output %input)")
    :count("0-1"))

cbundle
  :option("--xxd", "Set xxd command string (e.g. xxd -i -n data)")
  :count("0-1")

cbundle
  :option("--cc", "Set the compiler")
  :count("0-1")

cbundle
  :option("--ignore", "Ignore bundling a module")
  :args(1)
  :count("*")

cbundle
  :flag("--no-close", "Don't call lua_close(...)")
  :count("0-1")

cbundle
  :flag("--close", "Call lua_close(...)")
  :count("0-1")

cbundle
  :option("--input", "Input file")
  :args(1)
  :count(1)

cbundle
  :flag("--deps", "Generate a make .d file")
  :count("0-1")

cbundle
  :option("--deps-target", "Override dependency target file")
  :args(1)
  :count("0-1")

cbundle
  :option("--output-directory", "Output directory")
  :args(1)
  :count(1)

cbundle
  :option("--output-prefix", "Output name prefix")
  :args(1)
  :count("0-1")

cbundle
  :option("--path", "LUA_PATH")
  :args(1)
  :count(1)

cbundle
  :option("--cpath", "LUA_CPATH")
  :args(1)
  :count(1)

local ctemplate = parser
  :command("template", "Process templates")

ctemplate:mutex(

  ctemplate
    :option("-f --file", "Input file")
    :args(1)
    :count("0-1"),

  ctemplate
    :option("-d --directory", "Input directory")
    :args(1)
    :count("0-1"))

ctemplate
  :option("-o --output", "Output file or directory")
  :args(1)
  :count(1)

ctemplate
  :flag("-M --deps", "Generate a make .d file")
  :count("0-1")

ctemplate
  :option("-t --trim", "Prefix to remove from directory prefix before output (only used when -d is provided)")
  :args(1)
  :count("?")

ctemplate
  :option("-c --config", "A configuration file")
  :args(1)
  :count("0-1")

local cmustache = parser
  :command("mustache", "Process mustache templates")

cmustache:mutex(
  cmustache
    :option("-f --file", "Input file")
    :args(1)
    :count("0-1"),
  cmustache
    :option("-d --directory", "Input directory")
    :args(1)
    :count("0-1"))

cmustache
  :option("-o --output", "Output file or directory")
  :args(1)
  :count(1)

cmustache
  :option("-t --trim", "Prefix to remove from directory prefix before output")
  :args(1)
  :count("?")

cmustache
  :option("-c --config", "A configuration file")
  :args(1)
  :count("0-1")

local cinit = parser
  :command("init", "Initialize a new project")

cinit:mutex(
  cinit:option("--name", "Project name"):count("0-1"),
  cinit:flag("--here", "Initialize in current directory, using directory name as project name"))
cinit:option("--dir", "Project directory"):count("0-1")
cinit:flag("--web", "Initialize a web project (default: library project)")

local cinstall = parser
  :command("install", "Install the project")

cinstall:option("--dir", "Top-level build directory"):count("0-1")
cinstall:option("--env", "Environment and build sub-directory"):count("0-1")
cinstall:option("--config", "Config file to use"):count("0-1")
cinstall:option("--luarocks-config", "Luarocks config file to use"):count("0-1")
cinstall:flag("--skip-tests", "Skip tests")
cinstall:flag("--bundled", "Bundle executables from bin/ to standalone")
cinstall:option("--prefix", "Install prefix for bundled executables"):count("0-1")
cinstall:option("--bundle-cc", "Compiler for bundling"):count("0-1")
cinstall:option("--bundle-flags", "Compiler flags for bundling"):count("0-1")
cinstall:option("--bundle-mods", "Modules to preload (comma-separated)"):count("0-1")
cinstall:option("--bundle-ignores", "Modules to ignore (comma-separated)"):count("0-1")
cinstall:flag("--wasm", "Bundle to WASM")

local crelease = parser
  :command("release", "Release the project")

crelease:option("--dir", "Top-level build directory"):count("0-1")
crelease:option("--env", "Environment and build sub-directory"):count("0-1")
crelease:option("--config", "Config file to use"):count("0-1")
crelease:flag("--skip-tests", "Skip tests")

local cpack = parser
  :command("pack", "Build rockspec and tarball without releasing")

cpack:option("--dir", "Top-level build directory"):count("0-1")
cpack:option("--env", "Environment and build sub-directory"):count("0-1")
cpack:option("--config", "Config file to use"):count("0-1")
cpack:flag("--skip-tests", "Skip tests")

local cexec = parser
  :command("exec", "Execute a command in the build environment")

cexec:option("--dir", "Top-level build directory"):count("0-1")
cexec:option("--env", "Environment and build sub-directory"):count("0-1")
cexec:option("--config", "Config file to use"):count("0-1")
cexec:argument("args", "Arguments"):args("*")

local cbuild = parser
  :command("build", "Build the project")

cbuild:option("--dir", "Top-level build directory"):count("0-1")
cbuild:option("--env", "Environment and build sub-directory"):count("0-1")
cbuild:option("--config", "Config file to use"):count("0-1")
cbuild:flag("--test", "Build the test environment")
cbuild:option("--openresty-dir", "Openresty installation directory"):count("0-1")

local cstart = parser
  :command("start", "Start the server")

cstart:option("--dir", "Top-level build directory"):count("0-1")
cstart:option("--env", "Environment and build sub-directory"):count("0-1")
cstart:option("--config", "Config file to use"):count("0-1")
cstart:flag("--fg", "Run in foreground (exec to openresty)")
cstart:flag("--test", "Start the test environment")
cstart:option("--openresty-dir", "Openresty installation directory"):count("0-1")

local cstop = parser
  :command("stop", "Stop the server")

cstop:option("--dir", "Top-level build directory"):count("0-1")
cstop:option("--env", "Environment and build sub-directory"):count("0-1")
cstop:option("--config", "Config file to use"):count("0-1")
cstop:option("--openresty-dir", "Openresty installation directory"):count("0-1")

local cclean = parser
  :command("clean", "Clean build artifacts")

cclean:option("--env", "Environment to clean (default: 'default', or all with --all)"):count("0-1")
cclean:option("--config", "Config file to use"):count("0-1")
cclean:flag("--all", "Remove entire build directory")
cclean:flag("--deps", "Remove dependencies (lua_modules)")
cclean:flag("--wasm", "Remove only WASM compiled artifacts (web projects)")
cclean:flag("--client", "Only clean client (web projects)")
cclean:flag("--server", "Only clean server (web projects)")
cclean:flag("--dry-run", "Show what would be removed without removing")

local ctest = parser
  :command("test", "Run tests")

ctest
  :option("-m --match", "Only load the matching files")
  :args(1)
  :count("0-1")

ctest
  :flag("-s --stop", "Stop after the first error")
  :count("0-1")

ctest
  :option("-i --interp", "Run files with <interp> instead of via lua dofile")
  :args(1)
  :count("0-1")

ctest
  :argument("files")
  :args("*")


ctest:option("--dir", "Top-level build directory"):count("0-1")
ctest:option("--env", "Environment and build sub-directory"):count("0-1")
ctest:option("--config", "Config file to use"):count("0-1")
ctest:flag("--iterate", "Iteratively run tests")
ctest:flag("--wasm", "Run in WASM mode")
ctest:flag("--profile", "Report the performance profile")
ctest:flag("--trace", "Enable source tracing")
ctest:flag("--skip-check", "Skip luacheck")
ctest:option("--single", "Run a single test"):count("0-1")
ctest:option("--lua", "Specify the lua interpreter"):count("0-1")
ctest:option("--lua-path-extra", "Specify extra lua path dirs"):count("0-1")
ctest:option("--lua-cpath-extra", "Specify extra lua cpath dirs"):count("0-1")
ctest:option("--openresty-dir", "Openresty installation directory"):count("0-1")
ctest:flag("--root", "Run root-level tests only (web projects)")
ctest:flag("--client", "Run client tests only (web projects)")
ctest:flag("--server", "Run server tests only (web projects)")
ctest:flag("--show-logs", "Show server access/error logs during tests (web projects)")

local args = parser:parse()

local function template_file (conf, input, output, write_deps, config)
  local deps = {}
  conf.env = conf.env or {}
  conf.env.readfile = function (fp) deps[fp] = true; return fs.readfile(fp) end
  local out = renderfile(input == "-" and stdin or input, conf.env)
  mkdirp(dirname(output))
  writefile(output == "-" and stdout or output, out)
  if write_deps and output ~= "-" then
    if config then deps[config] = true end
    writefile(output .. ".d", serialize_deps(input, output, deps))
  end
end

local function template_files (conf, trim, input, mode, output, deps, config)
  if mode == "directory" then
    for fp in files(input, true) do
      template_files(conf, trim, fp, mode, output, deps, config)
    end
  elseif mode == "file" then
    local outfile = input
    if trim and startswith(outfile, trim) then
      outfile = ssub(outfile, #trim + 1)
    end
    output = fs.join(output, outfile)
    template_file(conf, input, output, deps, config)
  else
    error("Unexpected mode", mode, "for file", input)
  end
end

if args.command == "template" then

  local run_env = pushindex({}, _G)
  local conf = args.config and runfile(args.config, run_env) or {}

  if args.directory then
    mkdirp(args.output)
    local md = mode(args.directory)
    template_files(conf, args.trim, args.directory, md, args.output, args.deps, args.config)
  elseif args.file then
    template_file(conf, args.file, args.output, args.deps, args.config)
  else
    parser:error("either -f --file or -d --directory must be provided")
  end

elseif args.command == "mustache" then

  local run_env = pushindex({}, _G)
  local conf = args.config and runfile(args.config, run_env) or {}

  local function mustache_file(input, output)
    local content = input == "-" and stdin:read("*a") or fs.readfile(input)
    local out = mustache(content, conf)
    mkdirp(dirname(output))
    writefile(output == "-" and stdout or output, out)
  end

  local function mustache_files(trim, input, md, output)
    if md == "directory" then
      for fp in files(input, true) do
        mustache_files(trim, fp, md, output)
      end
    elseif md == "file" then
      local outfile = input
      if trim and startswith(outfile, trim) then
        outfile = ssub(outfile, #trim + 1)
      end
      output = fs.join(output, outfile)
      mustache_file(input, output)
    else
      error("Unexpected mode", md, "for file", input)
    end
  end

  if args.directory then
    mkdirp(args.output)
    local md = mode(args.directory)
    mustache_files(args.trim, args.directory, md, args.output)
  elseif args.file then
    mustache_file(args.file, args.output)
  else
    parser:error("either -f --file or -d --directory must be provided")
  end

elseif args.command == "bundle" then

  local luac = nil

  if args.luac then
    luac = args.luac
  elseif args.luac_off then
    luac = false
  elseif args.luac_default then
    luac = true
  end

  local flags = {}
  for _, flag in ipairs(args.flags) do
    local parts = ssplits(flag, "%s+")
    for i = 1, #parts do
      if parts[i] ~= "" then
        flags[#flags + 1] = parts[i]
      end
    end
  end

  local close = args.close or args.no_close or nil

  bundle(args.input, args.output_directory, {
    env = args.env,
    mods = args.mod,
    flags = flags,
    path = args.path,
    cpath = args.cpath,
    deps = args.deps,
    depstarget = args.deps_target,
    ignores = args.ignore,
    outprefix = args.output_prefix,
    cc = args.cc,
    close = close,
    luac = luac,
    xxd = args.xxd
  })

elseif args.command == "test" then

  if #args.files > 0 then

    if args.interp then
      local parts = ssplits(args.interp, "%s+")
      local interp = {}
      for i = 1, #parts do
        if parts[i] ~= "" then
          interp[#interp + 1] = parts[i]
        end
      end
      args.interp = interp
    end
    runtests(args.files, args)
  else

    local m = project.init({
      dir = args.dir,
      env = args.env,
      lua = args.lua,
      lua_path_extra = args.lua_path_extra,
      lua_cpath_extra = args.lua_cpath_extra,
      config = args.config,
      iterate = args.iterate,
      skip_check = args.skip_check,
      wasm = args.wasm,
      profile = args.profile,
      trace = args.trace,
      single = args.single,
      openresty_dir = args.openresty_dir,
      verbosity = args.verbosity,
      test_root = args.root,
      test_client = args.client,
      test_server = args.server,
      show_logs = args.show_logs,
    })
    if args.iterate then
      m.iterate()
    else
      m.test()
    end
  end

elseif args.command == "init" then

  local name, dir
  if args.here then
    name = basename(cwd())
    dir = "."
  else
    if not args.name then
      parser:error("either --name or --here must be provided")
    end
    name = args.name
    dir = args.dir
  end

  if args.web then
    project.create_web({
      name = name,
      dir = dir,
    })
  else
    project.create_lib({
      name = name,
      dir = dir,
    })
  end

elseif args.command == "install" then

  local m = project.init({
    dir = args.dir,
    env = args.env,
    config = args.config,
    luarocks_config = args.luarocks_config,
    skip_tests = args.skip_tests,
    verbosity = args.verbosity,
  })

  m.install({
    bundled = args.bundled,
    prefix = args.prefix,
    bundle_cc = args.bundle_cc,
    bundle_flags = args.bundle_flags,
    bundle_mods = args.bundle_mods,
    bundle_ignores = args.bundle_ignores,
    wasm = args.wasm,
  })

elseif args.command == "release" then

  local m = project.init({
    dir = args.dir,
    env = args.env,
    config = args.config,
    skip_tests = args.skip_tests,
    verbosity = args.verbosity,
  })

  if m.release then
    m.release()
  else
    io.stderr:write("Release not available (public != true in make.lua)\n")
  end

elseif args.command == "pack" then

  local m = project.init({
    dir = args.dir,
    env = args.env,
    config = args.config,
    skip_tests = args.skip_tests,
    verbosity = args.verbosity,
  })

  if m.pack then
    m.pack()
  else
    io.stderr:write("Pack not available for this project type\n")
  end

elseif args.command == "exec" then

  local m = project.init({
    dir = args.dir,
    env = args.env,
    config = args.config,
    verbosity = args.verbosity,
  })

  m.exec(args.args)

elseif args.command == "build" then

  local m = project.init({
    dir = args.dir,
    env = args.env,
    config = args.config,
    openresty_dir = args.openresty_dir,
    verbosity = args.verbosity,
  })

  m.build({ test = args.test })

elseif args.command == "start" then

  local m = project.init({
    dir = args.dir,
    env = args.env,
    config = args.config,
    openresty_dir = args.openresty_dir,
    verbosity = args.verbosity,
  })

  m.start({ test = args.test, fg = args.fg })

elseif args.command == "stop" then

  local m = project.init({
    dir = args.dir,
    env = args.env,
    config = args.config,
    openresty_dir = args.openresty_dir,
    verbosity = args.verbosity,
  })

  m.stop()

elseif args.command == "clean" then

  local m = project.init({
    env = args.env or "default",
    config = args.config,
    verbosity = args.verbosity,
  })

  local removed = m.clean({
    all = args.all,
    deps = args.deps,
    wasm = args.wasm,
    client = args.client,
    server = args.server,
    dry_run = args.dry_run,
    env = args.env,
  })

  if args.dry_run then
    io.stdout:write("Would remove:\n")
  else
    io.stdout:write("Removed:\n")
  end
  if removed and #removed > 0 then
    for _, fp in ipairs(removed) do
      io.stdout:write("  " .. fp .. "\n")
    end
  else
    io.stdout:write("  (nothing to clean)\n")
  end

elseif args.command == "lua" then

  local cmd = { args.lua or env.interpreter()[1] }

  if args.profile then
    arr.push(cmd, "-l", "santoku.profiler")
  end

  if args.trace then
    arr.push(cmd, "-l", "santoku.tracer")
  end

  if args.serialize then
    arr.push(cmd, "-l", "santoku.autoserialize")
  end

  if args.string then
    arr.push(cmd, "-e", args.string)
  elseif args.file then
    arr.push(cmd, args.file)
  end

  sys.execute(cmd)

else
  error("invalid command")
end
