local tup = require("santoku.tuple")

local M = {}

local function pipe (final, ok, args, fns)
  local fn = fns()
  if not ok or not fn then
    return final(ok, args())
  else
    return fn(args(function (ok, ...)
      return pipe(final, ok, tup(...), tup(select(2, fns())))
    end))
  end
end





M.pipe = function (...)
  local n = tup.len(...)
  local final = tup.sel(n, ...)
  local fns = tup(tup.take(n - 1, ...))
  return function (...)
    return pipe(final, true, tup(...), fns)
  end
end

return M
