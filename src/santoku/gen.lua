





















local vec = require("santoku.vector")
local err = require("santoku.err")
local fun = require("santoku.fun")
local compat = require("santoku.compat")
local op = require("santoku.op")
local co = require("santoku.co")
local tup = require("santoku.tuple")

local M = {}



M.END = {}


M.isgen = function (t)
  if type(t) ~= "table" then
    return false
  end
  return (getmetatable(t) or {}).__index == M
end








M.genco = function (fn, ...)
  assert(compat.iscallable(fn))
  local co = co()
  local cor = co.create(fn)
  local idx = 0
  local ret
  local nxt = tup(co.resume(cor, co, ...))
  local ok, err = nxt() 
  if not ok then
    error(err)
  end
  local gen = {

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
      ret = nxt
      nxt = tup(co.resume(cor, ...))
      ok, err = nxt()
      if not ok then
        error(err)
      else
        idx = idx + 1
        return select(2, ret())
      end
    end
  })
end



M.gensent = function (fn, sent, ...)
  assert(compat.iscallable(fn))
  local idx = 0
  local ret
  local nxt = tup(fn(...))
  local v = nxt() 
  local gen = {
    idx = function ()
      return idx
    end,
    done = function ()
      return v == sent
    end
  }
  return setmetatable(gen, {
    __index = M,
    __call = function (...)
      if gen:done() then
        return
      end
      idx = idx + 1
      ret = nxt
      nxt = tup(fn(...))
      v = nxt()
      return ret()
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
  err.unimplemented("genzero")
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
  local args = vec(...)
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

M.map = function (gen, fn, ...)
  assert(M.isgen(gen))
  fn = fn or fun.id
  local args = vec(...)
  return M.genco(function (co)
    while not gen:done() do
      local val = vec(gen())
      co.yield(fn(val:extend(args):unpack()))
    end
  end)
end

M.reduce = function (gen, acc, ...)
  assert(M.isgen(gen))
  assert(compat.iscallable(acc))
  local val = vec(...)
  if gen:done() then
    return val:unpack()
  elseif val.n == 0 then
    val:append(gen())
  end
  while not gen:done() do
    val:append(gen())
    val:appendo(1, acc(val:unpack()))
  end
  return val:unpack()
end

M.filter = function (gen, fn, ...)
  assert(M.isgen(gen))
  fn = fn or compat.id
  assert(compat.iscallable(fn))
  local args = vec(...)
  return M.genco(function (co)
    while not gen:done() do
      local val = vec(gen())
      if fn(val:extend(args):unpack()) then
        co.yield(val:unpack())
      end
    end
  end)
end

M.zip = function (opts, ...)
  local gens
  if M.isgen(opts) then
    gens = vec(opts, ...)
    opts = {}
  else
    gens = vec(...)
  end
  local mode = opts.mode or "first"
  assert(mode == "first" or mode == "longest")
  return M.genco(function (co)
    while true do
      local nb = 0
      local ret = vec()
      for i = 1, gens.n do
        local gen = gens[i]
        if not gen:done() then
          nb = nb + 1
          local val = vec(gen())
          ret = ret:append(val)
        elseif i == 1 and mode == "first" then
          return
        else
          ret = ret:append(vec())
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

M.take = function (gen, n)
  assert(M.isgen(gen))
  assert(n == nil or type(n) == "number")
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

M.find = function (gen, ...)
  assert(M.isgen(gen))
  return gen:filter(...):head()
end

M.pick = function (gen, n)
  assert(M.isgen(gen))
  return gen:slice(n, 1):head()
end

M.slice = function (gen, start, num)
  assert(M.isgen(gen))
  gen:take((start or 1) - 1):discard()
  return gen:take(num)
end

M.each = function (gen, fn, ...)
  assert(M.isgen(gen))
  local val = vec()
  while not gen:done() do
    val:appendo(1, gen()):append(...)
    fn(val:unpack())
  end
end

M.tabulate = function (gen, opts, ...)
  assert(M.isgen(gen))
  local keys
  if type(opts) == "table" then
    keys = M.args(...)
  else
    keys = M.args(opts, ...)
    opts = {}
  end
  local rest = opts.rest
  local t = keys:zip(gen):reduce(function (a, k, v)
    a[k[1]] = v[1]
    return a
  end, {})
  if rest then
    t[rest] = gen:vec()
  end
  return t
end

M.chain = function (...)
  return M.flatten(M.args(...))
end

M.paster = function (gen, ...)
  local args = vec(...)
  return gen:map(function (...)
    return vec(...):extend(args):unpack()
  end)
end

M.pastel = function (gen, ...)
  local args = vec(...)
  return gen:map(function (...)
    return vec():extend(args):append(...):unpack()
  end)
end

M.empty = function ()
  return M.gennil(function () return end)
end

M.flatten = function (gengen)
  assert(M.isgen(gengen))
  return M.genco(function (co)
    gengen:each(function (gen)
      gen:each(co.yield)
    end)
  end)
end

M.chunk = function (gen, n)
  assert(M.isgen(gen))
  return M.genco(function (co)
    while not gen:done() do
      co.yield(gen:take(n):vec())
    end
  end)
end




M.unlazy = function (gen, n)
  assert(M.isgen(gen))
  return M.genco(function (co)
    gen:take(n):vec():each(co.yield)
  end)
end

M.discard = function (gen)
  assert(M.isgen(gen))
  while not gen:done() do
    gen()
  end
end



M.vec = function (gen, v)
  assert(M.isgen(gen))
  v = v or vec()
  assert(vec.isvec(v))
  return gen:reduce(function (a, ...)
    if select("#", ...) <= 1 then
      return a:append(...)
    else
      return a:append({ ... })
    end
  end, v)
end










M.equals = function (...)
  local vals = M.zip({ mode = "longest" }, ...):map(vec.equals):all()
  return vals and M.args(...):map(M.done):all()
end



M.all = function (gen)
  assert(M.isgen(gen))
  return gen:reduce(function (a, n)
    return a and n
  end, true)
end

M.none = fun.compose(op["not"], M.find)

M.max = function (gen, ...)
  assert(M.isgen(gen))
  return gen:reduce(function(a, b)
    if a > b then
      return a
    else
      return b
    end
  end, ...)
end

M.head = function (gen)
  assert(M.isgen(gen))
  return gen()
end


M.last = function (gen)
  assert(M.isgen(gen))
  local last = vec()
  while not gen:done() do
    last = vec(gen())
  end
  return last:unpack()
end

M.tail = function (gen)
  assert(M.isgen(gen))
  gen()
  return gen
end

M.done = function (gen)
  assert(M.isgen(gen))
  return gen:done()
end

return M
