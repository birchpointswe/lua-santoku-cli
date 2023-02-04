






local gen = require("santoku.gen")
local vec = require("santoku.vector")

describe("santoku.gen", function ()

  describe("gen", function ()

    it("should create an iterator", function ()

      local idx = 0

      local gen = gen(function (gen)
        idx = idx + 1
        if idx > 3 then
          return gen:stop()
        else
          return gen:yield(idx)
        end
      end)

      assert(not gen.done)

      assert(gen:step())
      assert(gen.vals:get(1) == 1)

      assert(gen:step())
      assert(gen.vals:get(1) == 2)

      assert(gen:step())
      assert(gen.vals:get(1) == 3)

      assert(not gen.done)
      assert(not gen:step())
      assert(gen.done)

    end)

  end)

  describe("iter", function ()

    it("should wrap a nil-returning function as a generator", function ()

      local n = 0
      local iter = function ()
        n = n + 1
        if n > 2 then
          return nil
        else
          return n
        end
      end

      local gen = gen.iter(iter)

      assert(not gen.done)

      assert(gen:step())
      assert(gen.vals:get(1) == 1)

      assert(gen:step())
      assert(gen.vals:get(1) == 2)

      assert(not gen.done)
      assert(not gen:step())
      assert(gen.done)

    end)

  end)












































































































































































  describe("map", function ()

    it("maps over a generator", function ()

      local gen = gen.args(1, 2):map(function (a)
        return a * 2
      end)

      assert(gen:step())
      assert.equals(2, gen.vals:get(1))

      assert(gen:step())
      assert.equals(4, gen.vals:get(1))

      assert(not gen:step())
      assert(gen.done)

    end)

  end)














































  describe("take", function ()

    it("takes n items from a generator", function ()

      local v

      v = gen.args(1, 2, 3, 4):vec()
      assert(v.n == 4)
      assert(v[1] == 1)
      assert(v[2] == 2)
      assert(v[3] == 3)
      assert(v[4] == 4)

      v = gen.args(1, 2, 3, 4):take(2):vec()
      assert(v.n == 2)
      assert(v[1] == 1)
      assert(v[2] == 2)

    end)

  end)

























































































































































































































































































end)
