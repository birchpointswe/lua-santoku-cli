





















local vec = require("santoku.vector")
local fun = require("santoku.fun")
local compat = require("santoku.compat")
local op = require("santoku.op")

local M = {}


M.isgen = function (t)
  if type(t) ~= "table" then
    return false
  end
  return (getmetatable(t) or {}).__index == M
end








M.gen = function (step, stop)
  assert(compat.iscallable(step))
  stop = stop or compat.noop
  assert(compat.iscallable(stop))
  return setmetatable({
    pvals = nil,
    gvals = nil,
    vals = nil,
    done = false,
    step = function (gen, ...)
      if gen.done then
        return false
      else
        gen.done = not step(gen, ...)
        return not gen.done
      end
    end,
    stop = function (gen, ...)
      if gen.done then
        return false
      else
        gen.done = true
        return stop(gen, ...)
      end
    end
  }, {
    __index = M,
  })
end

M.iter = function (iter)
  local val
  return  M.gen(function (gen)
    val = iter()
    if val == nil then
      return gen:stop()
    else
      return gen:yield(val)
    end
  end)
end

M.yield = function (gen, ...)
  if gen.done then
    return false
  else
    if gen.vals == gen.pvals then
      gen.vals = gen.gvals
    end
    if not gen.vals then
      gen.gvals = vec(...)
      gen.vals = gen.gvals
    else
      gen.vals:overlay(...)
    end
    return true
  end
end

M.pass = function (gen, pvals)
  assert(M.isgen(pvals))
  if gen.done then
    return false
  else
    gen.vals = pvals.vals
    return true
  end
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
  return M.nvalues(vec(...))
end

M.values = function (t)
  assert(type(t) == "table")
  return M.pairs(t):map(fun.nret(2))
end

M.keys = function (t)
  assert(type(t) == "table")
  return M.pairs(t):map(fun.nret(1))
end

M.nvalues = function (t)
  assert(type(t) == "table")
  assert(type(t.n) == "number" and t.n >= 0)
  local i = 0
  return M.gen(function (gen)
    i = i + 1
    if i > t.n then
      return gen:stop()
    else
      return gen:yield(t[i])
    end
  end)
end

M.ivalues = function (t)
  assert(type(t) == "table")
  return M.ipairs(t):map(fun.nret(2))
end

M.ikeys = function (t)
  assert(type(t) == "table")
  return M.ipairs(t):map(fun.nret(1))
end

M.map = function (gen0, fn)
  assert(M.isgen(gen0))
  fn = fn or compat.id
  assert(compat.iscallable(fn))
  return M.gen(function (gen1)
    if gen0:step() then
      gen0.vals:apply(fn)
      return gen1:pass(gen0)
    else
      return gen1:stop()
    end
  end)
end

M.reduce = function (gen, acc, ...)
  assert(M.isgen(gen))
  assert(compat.iscallable(acc))
  local val = vec(...)
  if val.n == 0 then
    val:copy(gen.vals)
  end
  while gen:step() do
    val:extend(gen.vals)
    val:overlay(acc(val:unpack()))
  end
  return val:unpack()
end

M.filter = function (gen0, fn)
  assert(M.isgen(gen0))
  fn = fn or compat.id
  assert(compat.iscallable(fn))
  return M.gen(function (gen1)
    while gen0:step() do
      if gen0.vals:span(fn) then
        return gen1:pass(gen0)
      end
    end
    return gen1:stop()
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

M.take = function (gen0, n)
  assert(M.isgen(gen0))
  assert(n == nil or (type(n) == "number" and n >= 0))
  if n == nil then


    return gen0
  else
    return M.gen(function (gen1)
      if n == 0 then
        return gen1:stop()
      elseif not gen0:step() then
        return gen1:stop()
      else
        n = n - 1
        return gen1:pass(gen0)
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

M.each = function (gen, fn)
  assert(M.isgen(gen))
  fn = fn or compat.noop
  assert(compat.iscallable(fn))
  while gen:step() do
    gen.vals:span(fn)
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

M.chunk = function (gen0, n)
  assert(M.isgen(gen0))
  return M.gen(function (gen1)
    if gen0.done then
      return gen1:stop()
    else
      return gen1:yield(gen0:take(n):vec())
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
  while gen:step() do end
end



M.vec = function (gen, v)
  assert(M.isgen(gen))
  v = v or vec()
  assert(vec.isvec(v))
  return gen:reduce(function (a, ...)
    if select("#", ...) <= 1 then
      return a:append(...)
    else
      return a:append(vec(...))
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
  local hasval = false
  if gen:step() then
    hasval = true
  end
  while gen:step() do end
  if hasval then
    return gen.vals:unpack()
  else
    return
  end
end

M.tail = function (gen)
  assert(M.isgen(gen))
  gen()
  return gen
end

return setmetatable(M, {
  __call = function (_, ...)
    return M.gen(...)
  end
})
