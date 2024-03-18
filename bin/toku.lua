local err = require("santoku.error")
local error = err.error

local argparse = require("argparse")
local bundle = require("santoku.bundle")
local project = require("santoku.make.project")
local runtests = require("santoku.test.runner")

local env = require("santoku.env")
local var = env.var

local arr = require("santoku.array")
local push = arr.push
local extend = arr.extend

local inherit = require("santoku.inherit")
local pushindex = inherit.pushindex

local str = require("santoku.string")
local ssub = str.sub
local ssplits = str.splits
local startswith = str.startswith

local iter = require("santoku.iter")
local collect = iter.collect
local map = iter.map
local filter = iter.filter
local flatten = iter.flatten
local ivals = iter.ivals

local fs = require("santoku.fs")
local runfile = fs.runfile
local mode = fs.mode
local mkdirp = fs.mkdirp
local files = fs.files
local writefile = fs.writefile
local dirname = fs.dirname
local stdin = io.stdin
local stdout = io.stdout

local template = require("santoku.template")
local renderfile = template.renderfile
local serialize_deps = template.serialize_deps

local parser = argparse()
  :name("toku")
  :description("A command lind interface to the santoku lua library")

parser:command_target("command")

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

local function add_cmake_dir_args (cmd)
  cmd:option("--dir", "Top-level build directory"):count("0-1")
  cmd:option("--env", "Environment and build sub-directory"):count("0-1")
  cmd:option("--config", "Config file to use"):count("0-1")
end

local clib = parser:command("lib", "Manage lua library projects")
local cweb = parser:command("web", "Manage lua web projects")

add_cmake_dir_args(clib)
add_cmake_dir_args(cweb)

cweb
  :option("--openresty-dir", "Openresty installation directory")
  :default(var("OPENRESTY_DIR", nil))

clib:command("init", "Initialize a new library project")
cweb:command("init", "Initialize a new web project")

local clib_test = clib:command("test", "Run project tests")
local cweb_test = cweb:command("test", "Run project tests")

clib_test:flag("--iterate", "Iteratively run tests")
cweb_test:flag("--iterate", "Iteratively run tests")

clib_test:flag("--wasm", "Run in WASM mode")

clib_test:flag("--profile", "Report the performance profile")
cweb_test:flag("--profile", "Report the performance profile")

clib_test:flag("--skip-coverage", "Skip coverage reporting")
cweb_test:flag("--skip-coverage", "Skip coverage reporting")

clib_test:flag("--sanitize", "Enable sanitizers")

clib_test:option("--single", "Run a single test"):count("0-1")
cweb_test:option("--single", "Run a single test"):count("0-1")

clib_test:option("--lua", "Specify the lua interpreter"):count("0-1")
clib_test:option("--lua-path-extra", "Specify extra lua path dirs"):count("0-1")
clib_test:option("--lua-cpath-extra", "Specify extra lua cpath dirs"):count("0-1")

local clib_release = clib:command("release", "Release the library")
local clib_install = clib:command("install", "Install the library")

clib_release:flag("--skip-tests", "Skip tests")
clib_install:flag("--skip-tests", "Skip tests")

clib_install:option("--luarocks-config", "Luarocks config file to use"):count("0-1")

local cweb_start = cweb:command("start", "Start the server")

cweb_start:flag("--background", "Run in background")
cweb_start:flag("--test", "Start the test environment")

local cweb_build = cweb:command("build", "Build the server")
cweb_build:flag("--test", "Build the test environment")

cweb:command("stop", "Start the server")

local args = parser:parse()

local function template_file (conf, input, output, write_deps, config)
  local out, deps = renderfile(input == "-" and stdin or input, conf.env)
  mkdirp(dirname(output))
  writefile(output == "-" and stdout or output, out)
  if write_deps and deps and output ~= "-" then
    writefile(output .. ".d", serialize_deps(input, output, push(extend({}, deps), config)))
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

elseif args.command == "bundle" then

  local luac = nil

  if args.luac then
    luac = args.luac
  elseif args.luac_off then
    luac = false
  elseif args.luac_default then
    luac = true
  end

  local flags = collect(map(ssub, flatten(map(ssplits, ivals(args.flags)))))

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

  args.interp = collect(map(ssub, filter(function (_, s, e)
    return e >= s
  end, ssplits(args.interp, "%s+"))))

  runtests(args.files, args)

elseif args.command == "lib" and args.init then

  project.create_lib()

elseif args.command == "web" and args.init then

  project.create_web()

elseif args.command == "lib" then

  local m = project.init({
    dir = args.dir,
    env = args.env,
    lua = args.lua,
    lua_path_extra = args.lua_path_extra,
    lua_cpath_extra = args.lua_cpath_extra,
    config = args.config,
    luarocks_config = args.luarocks_config,
    iterate = args.iterate,
    skip_coverage = args.skip_coverage,
    skip_tests = args.skip_tests,
    wasm = args.wasm,
    sanitize = args.sanitize,
    profile = args.profile,
    single = args.single,
  })

  if args.test and args.iterate then
    m.iterate()
  elseif args.test and not args.iterate then
    m.test()
  elseif args.release then
    m.release()
  elseif args.install then
    m.install()
  else
    error("invalid command", args.command)
  end

elseif args.command == "web" then

  local m = project.init({
    dir = args.dir,
    env = args.env,
    config = args.config,
    luarocks_config = args.luarocks_config,
    background = args.background,
    test = args.test,
    iterate = args.iterate,
    skip_coverage = args.skip_coverage or args.start,
    skip_tests = args.skip_tests,
    profile = args.profile,
    single = args.single,
    openresty_dir = args.openresty_dir,
  })

  if args.build then
    m.build({ test = args.test })
  elseif args.start then
    m.start({ test = args.test })
  elseif args.stop then
    m.stop()
  elseif args.test and args.iterate then
    m.iterate()
  elseif args.test and not args.iterate then
    m.test()
  else
    error("invalid command")
  end

else
  error("invalid command")
end
