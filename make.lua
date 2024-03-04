local env = {

  name = "santoku-cli",
  version = "0.0.167-2",
  variable_prefix = "TK_CLI",
  license = "MIT",
  public = true,

  dependencies = {
    "lua >= 5.1",
    "santoku == 0.0.159-1",
    "santoku-fs == 0.0.13-1",
    "santoku-template == 0.0.10-1",
    "santoku-bundle == 0.0.19-2",
    "santoku-system == 0.0.11-1",
    "santoku-test-runner == 0.0.11-1",
    "santoku-make == 0.0.31-1",
    "argparse == 0.7.1-1",
  },

  test = {
    dependencies = {
      "santoku-test == 0.0.6-1",
      "luacov == 0.15.0-1",
    },
  }

}

env.homepage = "https://github.com/treadwelllane/lua-" .. env.name
env.tarball = env.name .. "-" .. env.version .. ".tar.gz"
env.download = env.homepage .. "/releases/download/" .. env.version .. "/" .. env.tarball

return {
  type = "lib",
  env = env,
  rules = {
    copy = {
      "test/spec/santoku/cli/template.lua"
    }
  },
}
