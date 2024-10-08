local env = {

  name = "santoku-cli",
  version = "0.0.232-1",
  variable_prefix = "TK_CLI",
  license = "MIT",
  public = true,

  dependencies = {
    "lua >= 5.1",
    "santoku >= 0.0.212-1",
    "santoku-fs >= 0.0.32-1",
    "santoku-template >= 0.0.26-1",
    "santoku-bundle >= 0.0.30-1",
    "santoku-system >= 0.0.27-1",
    "santoku-test-runner >= 0.0.23-1",
    "santoku-make >= 0.0.88-1",
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
  type = "lib",
  env = env
}
