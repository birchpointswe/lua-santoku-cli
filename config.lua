local _ENV = {}

name = "santoku-cli"
version = "0.0.98-1"
variable_prefix = "TK_CLI"

license = "MIT"

luacov_include = {
  "^%./santoku.*"
}

dependencies = {
  "lua >= 5.1",
  "santoku >= 0.0.98-1",
  "luafilesystem >= 1.8.0-1",
}

test_dependencies = {
  "luacov >= 0.15.0",
  "luacheck >= 1.1.0-1",
  "inspect >= 3.1.3-0",
  "luassert >= 1.9.0-1",
}

homepage = "https://github.com/treadwelllane/lua-" .. name
tarball = name .. "-" .. version .. ".tar.gz"
download = homepage .. "/releases/download/" .. version .. "/" .. tarball

return {
  env = _ENV,
  excludes = {
    "test/spec/santoku/cli/template.lua"
  },
}
