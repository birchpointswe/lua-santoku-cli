local env = {
  name = "santoku-cli",
  version = "0.0.324-1",
  variable_prefix = "TK_CLI",
  license = "MIT",
  public = true,
  dependencies = {
    "lua >= 5.1",
    "santoku >= 0.0.310-1",
    "santoku-fs >= 0.0.41-1",
    "santoku-template >= 0.0.34-1",
    "santoku-bundle >= 0.0.39-1",
    "santoku-system >= 0.0.61-1",
    "santoku-test-runner >= 0.0.25-1",
    "santoku-make >= 0.0.178-1",
    "santoku-mustache >= 0.0.14-1",
    "argparse >= 0.7.1-1",
  },
}

env.homepage = "https://github.com/treadwelllane/lua-" .. env.name
env.tarball = env.name .. "-" .. env.version .. ".tar.gz"
env.download = env.homepage .. "/releases/download/" .. env.version .. "/" .. env.tarball

return {
  env = env
}
