
























local tbl = require("santoku.table")
local fun = require("santoku.fun")
local op = require("santoku.op")
local co = require("santoku.co")

local M = {}



M.END = {}
M.GEN = {}








M.genco = function (fn, ...)
  assert(type(fn) == "function")
  local co = co.make()
  local cor = co.create(fn)
  local idx = 0
  local val = tbl.pack(co.resume(cor, co, ...))
  if not val[1] then
    error(val[2])
  end
  local gen = {
    tag = M.GEN,
    idx = function ()
      return idx
    end,
    done = function ()
      return co.status(cor) == "dead"
    end
  }
  return setmetatable(gen, {
    __index = M,
    __call = function (...)
      if gen:done() then
        return
      end
      local nval = tbl.pack(co.resume(cor, ...))
      if not nval[1] then
        error(nval[2])
      else
        local ret = val
        val = nval
        idx = idx + 1
        return select(2, ret:unpack())
      end
    end
  })
end



M.gensent = function (fn, sent, ...)
  assert(type(fn) == "function")
  local idx = 0
  local val = tbl.pack(fn(...))
  local gen = {
    tag = M.GEN,
    idx = function ()
      return idx
    end,
    done = function ()


      return val:unpack() == sent
    end
  }
  return setmetatable(gen, {
    __index = M,
    __call = function (...)
      if gen:done() then
        return
      end
      local nval = tbl.pack(fn(...))
      local ret = val
      val = nval
      idx = idx + 1
      return ret:unpack()
    end
  })
end

M.gennil = function (fn, ...)
  return M.gensent(fn, nil, ...)
end





M.genend = function (fn, ...)
  return M.gensent(fn, M.END, ...)
end



M.genzero = function ()
end

M.ipairs = function(t)
  assert(type(t) == "table")
  return M.genco(function (co)
    for k, v in ipairs(t) do
      co.yield(k, v)
    end
  end)
end

M.pairs = function(t)
  assert(type(t) == "table")
  return M.genco(function (co)
    for k, v in pairs(t) do
      co.yield(k, v)
    end
  end)
end

M.args = function (...)
  local args = tbl.pack(...)
  return M.genco(function (co)
    args:each(co.yield)
  end)
end

M.vals = function (t)
  assert(type(t) == "table")
  return M.pairs(t):map(fun.nret(2))
end

M.keys = function (t)
  assert(type(t) == "table")
  return M.pairs(t):map(fun.nret(1))
end

M.ivals = function (t)
  assert(type(t) == "table")
  return M.ipairs(t):map(fun.nret(2))
end

M.ikeys = function (t)
  assert(type(t) == "table")
  return M.ipairs(t):map(fun.nret(1))
end

M.mapper = function (fn, ...)
  fn = fn or fun.id
  local args = tbl.pack(...)
  return function (gen)
    return M.genco(function (co)
      while not gen:done() do
        local val = tbl.pack(gen())
        co.yield(fn(val:extend(args):unpack()))
      end
    end)
  end
end

M.map = function (gen, fn, ...)
  return M.mapper(fn, ...)(gen)
end

M.reducer = function (acc, ...)
  assert(type(acc) == "function")
  local val = tbl.pack(...)
  return function (gen)
    assert(type(gen) == "table")
    assert(gen.tag == M.GEN)
    if gen:done() then
      return val:unpack()
    elseif val:len() == 0 then
      val = tbl.pack(gen())
    end
    while not gen:done() do
      val = tbl.pack(acc(val:append(gen()):unpack()))
    end
    return val:unpack()
  end
end

M.reduce = function (gen, acc, ...)
  return M.reducer(acc, ...)(gen)
end

M.filterer = function (fn, ...)
  fn = fn or fun.id
  assert(type(fn) == "function")
  local args = tbl.pack(...)
  return function (gen)
    return M.genco(function (co)
      while not gen:done() do
        local val = tbl.pack(gen())
        if fn(val:extend(args):unpack()) then
          co.yield(val:unpack())
        end
      end
    end)
  end
end

M.filter = function (gen, fn, ...)
  return M.filterer(fn, ...)(gen)
end

M.zipper = function (opts)
  local mode = (opts or {}).mode or "first"
  assert(mode == "first" or mode == "longest")
  return function (...)
    local gens = tbl.pack(...)
    return M.genco(function (co)
      while true do
        local nb = 0
        local ret = tbl.pack()
        for i = 1, gens:len() do
          local gen = gens[i]
          if not gen:done() then
            nb = nb + 1
            ret = ret:append(tbl.pack(gen()))
          elseif i == 1 and mode == "first" then
            return
          else
            ret = ret:append(tbl.pack())
          end
        end
        if nb == 0 then
          break
        else
          co.yield(ret:unpack())
        end
      end
    end)
  end
end

M.zip = function (...)
  return M.zipper()(...)
end

M.taker = function (n)
  assert(n == nil or type(n) == "number")
  return function (gen)
    assert(type(gen) == "table")
    assert(gen.tag == M.GEN)
    if n == nil then
      return gen
    else
      return M.genco(function (co)
        while n > 0 and not gen:done() do
          co.yield(gen())
          n = n - 1
        end
      end)
    end
  end
end

M.take = function (gen, n)
  return M.taker(n)(gen)
end

M.finder = function (...)
  local args = tbl.pack(...)
  return function (gen)
    return gen:filter(args:unpack()):head()
  end
end

M.find = function (gen, ...)
  return M.finder(...)(gen)
end

M.picker = function (n)
  return function (gen)
    return gen:slice(n, 1):head()
  end
end

M.pick = function (gen, n)
  return M.picker(n)(gen)
end

M.slicer = function (start, num)
  start = start or 1
  return function (gen)
    gen:take(start - 1):collect()
    return gen:take(num)
  end
end

M.slice = function (gen, start, num)
  return M.slicer(start, num)(gen)
end

M.eacher = function (fn)
  return function (gen)
    while not gen:done() do
      fn(gen())
    end
  end
end

M.each = function (gen, fn)
  return M.eacher(fn)(gen)
end

M.tabulator = function (keys, opts)
  local rest = (opts or {}).rest
  return function (genVals)
    local t = M.ivals(keys)
      :zip(genVals)
      :reduce(function (a, k, v)
        a[k[1]] = v[1]
        return a
      end, {})
    if rest then
      t[rest] = genVals:collect()
    end
    return t
  end
end

M.tabulate = function (gen, keys, opts)
  return M.tabulator(keys, opts)(gen)
end

M.chain = function (...)
  return M.flatten(M.args(...))
end

M.flatten = function (gengen)
  assert(type(gengen) == "table")
  assert(gengen.tag == M.GEN)
  return M.genco(function (co)
    M.each(gengen, M.eacher(co.yield))
  end)
end

M.any = M.finder()



M.all = function (gen)
  return gen:reduce(function (a, n)
    return a and n
  end, true)
end

M.none = fun.compose(op["not"], M.any)



M.collect = function (gen)
  return gen:reduce(function (a, ...)
    if select("#", ...) <= 1 then
      return tbl.append(a, ...)
    else
      return tbl.append(a, { ... })
    end
  end, {})
end










M.equals = function (...)
  local vals = M.zipper({ mode = "longest" })(...):map(tbl.equals):all()
  return vals and M.args(...):map(M.done):all()
end

M.max = function (gen, ...)
  return gen:reduce(function(a, b)
    if a > b then
      return a
    else
      return b
    end
  end, ...)
end

M.head = function (gen)
  return gen()
end

M.tail = function (gen)
  gen()
  return gen
end

M.done = function (gen)
  return gen:done()
end

return M
