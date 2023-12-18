local env = {

  name = "santoku-cli",
  version = "0.0.129-1",
  variable_prefix = "TK_CLI",
  license = "MIT",
  public = true,

  dependencies = {
    "lua >= 5.1",
    "santoku >= 0.0.148-1",
    "santoku-fs >= 0.0.7-1",
    "santoku-template >= 0.0.4-1",
    "santoku-bundle >= 0.0.11-1",
    "santoku-system >= 0.0.3-1",
    "santoku-test-runner >= 0.0.5-1",
    "argparse >= 0.7.1-1",
  },

  test_dependencies = {
    "santoku-test >= 0.0.4-1",
    "luacov >= 0.15.0-1",
  },

}

env.homepage = "https://github.com/treadwelllane/lua-" .. env.name
env.tarball = env.name .. "-" .. env.version .. ".tar.gz"
env.download = env.homepage .. "/releases/download/" .. env.version .. "/" .. env.tarball

return {
  env = env,
  excludes = {
    "test/spec/santoku/cli/template.lua"
  },
}
