local template = require("santoku.template")
local fs = require("santoku.fs")

describe("template", function ()

























































  it("should support multiple templates (again)", function ()
    local ok, getconfig = fs.loadfile("test/lib/spec/santoku/template/config.lua")
    assert(ok, getconfig)
    local config = getconfig()
    local ok, data = fs.readfile("test/lib/spec/santoku/template/index.html")
    assert(ok, data)
    local ok, tpl = template(data, config)
    assert(ok, tpl)
    local ok, str = tpl()
    assert(ok, str)
  end)

end)
