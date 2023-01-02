package = "santoku"
version = "dev-1"
rockspec_format = "3.0"
source = {
   url = "git+ssh://git@github.com/broma0/lua-examples.git"
}
description = {
   homepage = "https://broma0.github.io/lua-santoku",
   license = "MIT"
}
-- TODO: Expand supported versions
dependencies = {
  "lua == 5.1",
  "luafilesystem == 1.8.0-1"
}
build = {
   type = "builtin",
   modules = {
      ["santoku"] = "santoku.lua",
      ["santoku.co"] = "co.lua"
   }
}
