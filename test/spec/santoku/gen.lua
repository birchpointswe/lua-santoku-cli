






local gen = require("santoku.gen")
local vec = require("santoku.vector")

describe("santoku.gen", function ()

  describe("gen", function ()

    it("should create a generator", function ()

      local vals = gen(function (yield)
        yield(1)
        yield(2)
      end)

      local called = 0
      vals:index():each(function (idx, i)
        called = called + 1
        assert(idx == i)
      end)

      assert(called == 2)

    end)

    it("shouldnt call the callback if empty", function ()

      local vals = gen()

      local called = 0

      vals:each(function ()
        called = called + 1
      end)

      assert(called == 0)

    end)

  end)

  describe("vec", function ()

    it("collects generator returns into a vec", function ()

      local vals = gen(function (yield)
        yield(1, 2, 3)
        yield(4, 5, 6)
      end):vec()

      local expected = vec(vec(1, 2, 3), vec(4, 5, 6))

      assert.same(expected, vals)

    end)

  end)

  describe("args", function ()

    it("iterates over arguments", function ()

      local v = gen.args(1, 2, 3, 4):vec()

      assert.same(v, { 1, 2, 3, 4, n = 4 })

    end)

    it("handles arg nils", function ()

      local v = gen.args(1, nil, 2, nil, nil):vec()

      assert.same(v, { 1, nil, 2, nil, nil, n = 5 })

    end)

  end)

  describe("map", function ()

    it("maps over a generator", function ()

      local vals = gen.args(1, 2):map(function (a)
        return a * 2
      end):vec()

      assert.same(vals, { 2, 4, n = 2 })

    end)

  end)

  describe("reduce", function ()

    it("reduces a generator", function ()
      local vals = gen.args(1, 2, 3):reduce(function (a, n)
        return a + n
      end)
      assert.same(vals, 6)
    end)

  end)

  describe("filter", function ()

    it("filters a generator", function ()

      local vals = gen
        .args(1, 2, 3, 4, 5, 6)
        :filter(function (n)
          return (n % 2) == 0
        end)
        :vec()

      assert.same(vals, vec(2, 4, 6))

    end)

  end)

  describe("chunk", function ()

    it("takes n items from a generator", function ()
      local vals = gen.args(1, 2, 3):chunk(2):vec()
      assert.same(vals, vec(vec(1, 2), vec(3)))
    end)

  end)







































































































































































































































































































































































































end)
