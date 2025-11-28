local env = {

  name = "santoku-cli",
  version = "0.0.287-1",
  variable_prefix = "TK_CLI",
  license = "MIT",
  public = true,

  dependencies = {
    "lua >= 5.1",
    "santoku >= 0.0.297-1",
    "santoku-fs >= 0.0.34-1",
    "santoku-template >= 0.0.31-1",
    "santoku-bundle >= 0.0.34-1",
    "santoku-system >= 0.0.56-1",
    "santoku-test-runner >= 0.0.23-1",
    "santoku-make >= 0.0.135-1",
    "argparse >= 0.7.1-1",
  },

  test = {
    dependencies = {
      "luacov >= 0.15.0-1",
    },
  }

}

env.homepage = "https://github.com/treadwelllane/lua-" .. env.name
env.tarball = env.name .. "-" .. env.version .. ".tar.gz"
env.download = env.homepage .. "/releases/download/" .. env.version .. "/" .. env.tarball

return {
  env = env
}
