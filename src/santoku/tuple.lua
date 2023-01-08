








local M = {}

M.tuple = function (...)
  return M.tuplew(M.tupleh(nil, 0, select('#', ...), ...))
end



M.append = function (a, ...)
  local nxt, nnxt = M.tupleh(nil, 0, select("#", ...), ...)
  local ret, nret = M.tupleh(nxt, nnxt, select("#", a()), a())
  return M.tuplew(ret, nret)
end

M.tupleh = function (nxt, m, n, first, ...)
  nxt = nxt or function () end
  if n == 0 then
    return function ()
      return nxt()
    end, m
  elseif n == 1 then
    return function()
      return first, nxt()
    end, m + 1
  else
    local rest, m0 = M.tupleh(nxt, m, n - 1, ...)
    return function()
      return first, rest()
    end, m0 + 1
  end
end

M.tuplew = function (t, n)
  return setmetatable({ n = n }, {
    __index = M,
    __call = t
  })
end

M.len = function (tup)
  return tup.n
end

M.sel = function (tup, i)
  return M.tuple(select(i, tup()))
end

M.head = function (tup)
  return (tup())
end

M.get = function (tup, i)
  return tup:sel(i):head()
end



M.equals = function (a, ...)
  local tups = M.tuple(...)
  for i = 1, tups:len() do
    if tups:get(i):len() ~= a:len() then
      return false
    end
  end
  for i = 1, tups:len() do
    for j = 1, a:len() do
      if tups:get(i):get(j) ~= a:get(j) then
        return false
      end
    end
  end
  return true
end

return setmetatable({}, {
  __index = M,
  __call = function (_, ...)
    return M.tuple(...)
  end
})
