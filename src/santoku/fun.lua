local tbl = require("santoku.table")

local M = {}








M.narg = function (...)
  local idx = tbl.pack(...)
  return function (fn, ...)
    local bound = tbl.pack(...)
    return function (...)
      local args0 = bound:append(...)
      args0:bubble(idx:unpack())
      return fn(args0:unpack())
    end
  end
end



M.nret = function (...)
  local idx = tbl.pack(...)
  return function (...)
    local args = tbl.pack(...)
    local rets = tbl.pack()
    for i = 1, idx:len() do
      local nret = args[idx[i]]
      rets = rets:append(nret)
    end
    return rets:unpack()
  end
end

M.compose = function (...)
  local fns = tbl.pack(...)
  return function(...)
    local vs = tbl.pack(...)
    for i = fns:len(), 1, -1 do
      local fn = fns[i]
      assert(type(fn) == "function")
      vs = tbl.pack(fn(vs:unpack()))
    end
    return vs:unpack()
  end
end

M.id = function (...)
  return ...
end

M.const = function (...)
  local args = tbl.pack(...)
  return function ()
    return args:unpack()
  end
end

M.maybe = function (a, f, g)
  f = f or M.id
  g = g or M.const(a)
  if a then
    return f(a)
  else
    return g()
  end
end

M.choose = function (a, b, c)
  if a then
    return b
  else
    return c
  end
end

return M
