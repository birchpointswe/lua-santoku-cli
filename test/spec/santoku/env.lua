local env = require("santoku.env")

describe("utils", function ()

  describe("interpreter", function ()






    it("should return the interpreter", function ()
      local min = 0
      local i = 0
      while true do
        i = i - 1
        if arg[i] ~= nil then
          min = i
        else
          break
        end
      end
      local vals = env.interpreter(true)
      local j = 1
      for i = min, #vals do
        assert.equals(vals[j], arg[i])
        j = j + 1
      end
    end)

  end)

end)
