local fs = require("santoku.fs")
local vec = require("santoku.vector")
local fun = require("santoku.fun")
local op = require("santoku.op")

describe("santoku.fs", function ()

































































  describe("files", function ()

    it("should list directory files", function ()
      local files = vec(
        "test/spec/santoku/fs/a/a.txt",
        "test/spec/santoku/fs/b/a.txt",
        "test/spec/santoku/fs/a/b.txt",
        "test/spec/santoku/fs/b/b.txt")
      local i = 0
      fs.files("test/spec/santoku/fs", { recurse = true })
        :each(function (ok, fp, mode)
          assert(ok)
          assert(files:find(fun.narg()(op.eq, fp)))
          assert(mode == "file")
          i = i + 1
        end)
        assert(i == 4)
    end)

  end)















end)
