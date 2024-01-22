

local argparse = require("argparse")
local inherit = require("santoku.inherit")
local gen = require("santoku.gen")
local vec = require("santoku.vector")
local str = require("santoku.string")
local testrunner = require("santoku.test.runner")
local err = require("santoku.err")
local fs = require("santoku.fs")
local tpl = require("santoku.template")
local tbl = require("santoku.table")
local bundle = require("santoku.bundle")
local make = require("santoku.make.project")

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
  :count("*")

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
  :default(os.getenv("OPENRESTY_DIR"))

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


local function write_deps (check, deps, input, output, configs)
  local depsfile = output .. ".d"
  local out = gen.chain(
      gen.pack(output, ": "),
      gen.ivals(configs):interleave(" "),
      gen.pack(" "),
      gen.ivals(deps):interleave(" "),
      gen.pack("\n", depsfile, ": ", input, "\n"))
    :vec()
    :concat()
  check(fs.writefile(depsfile, out))
end


local function process_file (check, conf, input, output, deps, configs)
  local data = check(fs.readfile(input == "-" and io.stdin or input))
  local tmpl, out
  local action = tpl.get_action(input, conf)
  if action == "template" then
    tmpl = check(tpl(data, conf))
    out = check(tmpl(conf.env))
  elseif action == "copy" then
    out = data
  else
    return
  end
  check(fs.mkdirp(fs.dirname(output)))
  check(fs.writefile(output == "-" and io.stdout or output, out))
  if deps and tmpl then
    write_deps(check, tmpl.deps, input, output, configs)
  end
end


local function process_files (check, conf, trim, input, mode, output, deps, configs)
  if mode == "directory" then
    fs.files(input, { recurse = true })
      :map(check)
      :each(function (fp, mode)
        process_files(check, conf, trim, fp, mode, output, deps, configs)
      end)
  elseif mode == "file" then
    local trimlen = trim and string.len(trim)
    local outfile = input
    if trim and outfile:sub(0, trimlen) == trim then
      outfile = outfile:sub(trimlen + 1)
    end
    output = fs.join(output, outfile)
    process_file(check, conf, input, output, deps, configs)
  else
    error("Unexpected mode: " .. mode .. " for file: " .. input)
  end
end


local function get_config (check, configs)
  local lenv = inherit.pushindex({}, _G)
  local cfg = tbl.merge({}, gen.ivals(configs):map(function (config)
    return check(fs.loadfile(config, lenv))() or {}
  end):vec():unpack())
  cfg.env = inherit.pushindex(cfg.env or {}, _G)
  return cfg
end

err.check(err.pwrap(function (check)

  if args.command == "template" then

    local conf = get_config(check, args.config)
    if args.directory then
      check(fs.mkdirp(args.output))
      local mode = check(fs.mode(args.directory))
      process_files(check, conf, args.trim, args.directory, mode, args.output, args.deps, args.config)
    elseif args.file then
      process_file(check, conf, args.file, args.output, args.deps, args.config)
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

    local flags = args.flags and gen.ivals(args.flags)
      :map(str.split):map(gen.ivals):flatten()
      :filter(function (s)
        return not str.isempty(s)
      end):vec() or vec()

    local close = nil

    if args.close then
      close = true
    elseif args.no_close then
      close = false
    end

    check(bundle(args.input, args.output_directory, {
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
    }))

  elseif args.command == "test" then

    check(testrunner.run(args.files, args))

  elseif args.command == "lib" and args.init then

    check(make.create_lib())

  elseif args.command == "web" and args.init then

    check(make.create_web())

  elseif args.command == "lib" then

    local m = check(make.init({
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
    }))

    if args.test and args.iterate then
      check(m:iterate())
    elseif args.test and not args.iterate then
      check(m:test())
    elseif args.release then
      check(m:release())
    elseif args.install then
      check(m:install())
    else
      check(false, "invalid command")
    end

  elseif args.command == "web" then

    local m = check(make.init({
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
    }))

    if args.build then
      check(m:build({ test = args.test }))
    elseif args.start then
      check(m:start({ test = args.test }))
    elseif args.stop then
      check(m:stop())
    elseif args.test and args.iterate then
      check(m:iterate())
    elseif args.test and not args.iterate then
      check(m:test())
    else
      check(false, "invalid command")
    end

  else
    check(false, "invalid command")
  end

end))
