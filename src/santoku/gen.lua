
























local vec = require("santoku.vector")
local err = require("santoku.err")
local fun = require("santoku.fun")
local compat = require("santoku.compat")
local op = require("santoku.op")
local co = require("santoku.co")

local M = {}


M.isgen = function (t)
  if type(t) ~= "table" then
    return false
  end
  return (getmetatable(t) or {}).__index == M
end








M.gen = function (run, ...)
  run = run or compat.noop
  assert(compat.iscallable(run))
  local args = vec(...)
  return setmetatable({
      run = function (yield, ...)
        yield = yield or compat.noop
        assert(compat.iscallable(yield))
        return run(yield, args:append(...):unpack())
      end
  }, {
    __index = M,
  })
end

M.iter = function (fn)
  return M.gen(function (yield)
    local val
    while true do
      val = fn()
      if val ~= nil then
        yield(val)
      else
        break
      end
    end
  end)
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
  return M.gen(function (yield, ...)
    for i = 1, select("#", ...) do
      yield((select(i, ...)))
    end
  end, ...)
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

M.index = function (gen)
  assert(M.isgen(gen))
  local idx = 0
  return M.gen(function (each)
    return gen:each(function (...)
      idx = idx + 1
      return each(idx, ...)
    end)
  end)
end

M.map = function (gen, fn)
  assert(M.isgen(gen))
  fn = fn or fun.id
  return M.gen(function (yield)
    return gen:each(function (...)
      return yield(fn(...))
    end)
  end)
end

M.reduce = function (gen, acc, ...)
  assert(M.isgen(gen))
  assert(compat.iscallable(acc))
  local ready = false
  local val = vec(...)
  gen:each(function (...)
    if not ready and val.n == 0 then
      ready = true
      return val:append(...)
    elseif not ready then
      ready = true
    end
    return val:overlay(acc(val:append(...):unpack()))
  end)
  return val:unpack()
end

M.filter = function (gen, fn)
  assert(M.isgen(gen))
  fn = fn or compat.id
  assert(compat.iscallable(fn))
  return M.gen(function (yield)
    return gen:each(function (...)
      if fn(...) then
        return yield(...)
      end
    end)
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
  fn = fn or compat.noop
  assert(compat.iscallable(fn))
  return gen.run(fn, ...)
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
  local chunk = vec()
  return M.gen(function (yield)
    gen:each(function(...)
      if chunk.n >= n then
        yield(chunk)
        chunk = vec(...)
      else
        chunk:append(...)
      end
    end)
    if chunk.n > 0 then
      yield(chunk)
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
  return gen:each()
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







M.last = function (gen)
  assert(M.isgen(gen))
  local last = vec()
  gen:each(function (...)
    last:overlay(...)
  end)
  return last:unpack()
end









return setmetatable({}, {
  __index = M,
  __call = function (_, ...)
    return M.gen(...)
  end
})
