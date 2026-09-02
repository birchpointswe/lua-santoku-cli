local env = {
  name = "santoku-cli",
  version = "2.10.1-1",
  variable_prefix = "TK_CLI",
  license = "MIT",
  public = true,
  dependencies = {
    "lua == 5.1",
    "santoku >= 2.0.0, < 3.0.0",
    "santoku-fs >= 2.0.0, < 3.0.0",
    "santoku-template >= 2.0.0, < 3.0.0",
    "santoku-bundle >= 2.0.0, < 3.0.0",
    "santoku-system >= 2.0.0, < 3.0.0",
    "santoku-test-runner >= 2.0.3, < 3.0.0",
    "santoku-make >= 5.0.0, < 6.0.0",
    "argparse >= 0.7.1-1",
  },
}

env.homepage = "https://github.com/birchpointswe/lua-" .. env.name
env.tarball = env.name .. "-" .. env.version .. ".tar.gz"
env.download = env.homepage .. "/releases/download/" .. env.version .. "/" .. env.tarball

return { env = env }
