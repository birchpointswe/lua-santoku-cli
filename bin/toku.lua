

local argparse = require("argparse")
local inherit = require("santoku.inherit")
local gen = require("santoku.gen")
local vec = require("santoku.vector")
local str = require("santoku.string")
local test = require("santoku.test")
local err = require("santoku.err")
local fs = require("santoku.fs")
local tpl = require("santoku.template")
local tbl = require("santoku.table")
local bundle = require("santoku.bundle")

local parser = argparse()
  :name("toku")
  :description("A command lind interface to the santoku lua library")

local cbundle = parser
  :command("bundle", "create standalone executables")

cbundle
  :option("--env", "set an environment variable that applies only at runtime")
  :args(2)
  :count("*")

cbundle
  :option("--mod", "load a module during startup")
  :args(1)
  :count("*")

cbundle
  :option("--flags", "set compile command-line flags")
  :args(1)
  :count("*")

cbundle:mutex(
  cbundle
    :option("--luac", "set luac command string")
    :args(1)
    :count("0-1"),
  cbundle
    :flag("--luac-off", "disable the luac stop")
    :count("0-1"),
  cbundle
    :flag("--luac-default", "use the default luac command (e.g. luac -s -o %output %input)")
    :count("0-1"))

cbundle
  :option("--xxd", "set xxd command string (e.g. xxd -i -n data)")
  :count("0-1")

cbundle
  :option("--cc", "set the compiler")
  :count("0-1")

cbundle
  :option("--ignore", "ignore bundling a module")
  :args(1)
  :count("*")

cbundle
  :flag("--no-close", "don't call lua_close(...)")
  :count("0-1")

cbundle
  :option("--input", "input file")
  :args(1)
  :count(1)

cbundle
  :flag("--deps", "generate a make .d file")
  :count("0-1")

cbundle
  :option("--deps-target", "override dependency target file")
  :args(1)
  :count("0-1")

cbundle
  :option("--output-directory", "output directory")
  :args(1)
  :count(1)

cbundle
  :option("--output-prefix", "output name prefix")
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
  :command("template", "process templates")

ctemplate:mutex(

  ctemplate
    :option("-f --file", "input file")
    :args(1)
    :count("0-1"),

  ctemplate
    :option("-d --directory", "input directory")
    :args(1)
    :count("0-1"))

ctemplate
  :option("-o --output", "output file or directory")
  :args(1)
  :count(1)

ctemplate
  :flag("-M --deps", "generate a make .d file")
  :count("0-1")

ctemplate
  :option("-t --trim", "prefix to remove from directory prefix before output (only used when -d is provided)")
  :args(1)
  :count("?")

ctemplate
  :option("-c --config", "a configuration file")
  :args(1)
  :count("*")

local ctest = parser
  :command("test", "run tests")

ctest
  :option("-m --match", "only load the matching files")
  :args(1)
  :count("0-1")

ctest
  :flag("-s --stop", "stop after the first error")
  :count("0-1")

ctest
  :option("-i --interp", "run files with <interp> instead of via lua dofile")
  :args(1)
  :count("0-1")

ctest
  :argument("files")
  :args("*")

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
  if tpl._should_include(fs.extension(input), input, conf) then
    tmpl = check(tpl(data, conf))
    out = check(tmpl(conf.env))
  else
    out = data
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

assert(err.pwrap(function (check)

  if args.template then
    local conf = get_config(check, args.config)
    if args.directory then
      check(fs.mkdirp(args.output))
      gen.ivals(args.input):each(function (i)
        local mode = check(fs.attr(i, "mode"))
        process_files(check, conf, args.trim, i, mode, args.output, args.deps, args.config)
      end)
    elseif args.file then
      process_file(check, conf, args.file, args.output, args.deps, args.config)
    else
      parser:error("either -f --file or -d --directory must be provided")
    end
  elseif args.bundle then

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
      close = not args.noclose,
      luac = luac,
      xxd = args.xxd
    }))
  elseif args.test then
    check(test.runfiles(args.files, args.interp, args.match, args.stop))
  else

    error("This is a bug")
  end

end, err.error))
