





















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

M.gen = function (fn)
  return setmetatable({}, {
    __index = M,
    __call = function (_, ret, ...)
      fn(ret, ...)
    end
  })
end

M.each = function (gen, fn, ...)
  assert(M.isgen(gen))
  fn = fn or fun.noop
  assert(compat.iscallable(fn))
  gen(fn, ...)
end

M.map = function (gen, fn, ...)
  assert(M.isgen(gen))
  fn = fn or fun.id
  assert(compat.iscallable(fn))
  return M.gen(function (ret, ...)
    assert(compat.iscallable(ret))
    gen(function (...)
      ret(fn(...))
    end, ...)
  end, ...)
end



M.vec = function (gen, v)
  assert(M.isgen(gen))
  v = v or vec()
  assert(vec.isvec(v))
  gen:each(function (...)
    if select("#", ...) <= 1 then
      v:append(...)
    else
      v:append({ ... })
    end
  end)
  return v
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

M.reduce = function (gen, acc, ...)
  assert(M.isgen(gen))
  assert(compat.iscallable(acc))
  local val = vec(...)
  if gen:done() then
    return val:unpack()
  elseif val.n == 0 then
    val = vec(gen())
  end
  while not gen:done() do
    val = vec(acc(val:append(gen()):unpack()))
  end
  return val:unpack()
end

M.filter = function (gen, fn, ...)
  assert(M.isgen(gen))
  fn = fn or compat.id
  assert(compat.iscallable(fn))
  return M.gen(function (ret, ...)
    assert(compat.iscallable(ret))
    gen:each(function(...)
      if fn(...) then
        ret(...)
      end
    end, ...)
  end, ...)
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

























M.pick = function (gen, n)
  assert(M.isgen(gen))
  return gen:slice(n, 1):head()
end

M.slice = function (gen, start, num)
  assert(M.isgen(gen))
  gen:take((start or 1) - 1):discard()
  return gen:take(num)
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
  assert(type(n) == "number" and n > 0)
  return M.gen(function (ret)
    assert(compat.iscallable(ret))
    local m = n
    local chunk = vec()
    gen:each(function (...)
      if m == 0 then
        ret(chunk)
        m = n
        chunk = vec()
      end



      if select("#", ...) > 1 then
        chunk:append(vec(...))
      else
        chunk:append((select(1, ...)))
      end
      m = m - 1
    end)
    if chunk.n > 0 then
      ret(chunk)
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
  gen:each()
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































return M
