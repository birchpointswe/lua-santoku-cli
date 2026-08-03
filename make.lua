local env = {
  name = "santoku-cli",
  version = "1.0.1-1",
  variable_prefix = "TK_CLI",
  license = "MIT",
  public = true,
  dependencies = {
    "lua == 5.1",
    "santoku >= 1.0.0, < 2.0.0",
    "santoku-fs >= 1.0.0, < 2.0.0",
    "santoku-template >= 1.0.0, < 2.0.0",
    "santoku-bundle >= 1.0.0, < 2.0.0",
    "santoku-system >= 1.0.0, < 2.0.0",
    "santoku-test-runner >= 1.0.0, < 2.0.0",
    "santoku-make >= 1.0.2, < 2.0.0",
    "santoku-mustache >= 1.0.0, < 2.0.0",
    "argparse >= 0.7.1-1",
  },
}

env.homepage = "https://github.com/birchpointswe/lua-" .. env.name
env.tarball = env.name .. "-" .. env.version .. ".tar.gz"
env.download = env.homepage .. "/releases/download/" .. env.version .. "/" .. env.tarball

return { env = env }
