local gen = require("santoku.gen")

local M = {}

M.matcher = function (pat)
  assert(type(pat) == "string")
  return function (str)
    assert(type(str) == "string")
    return gen.gennil(str:gmatch(pat))
  end
end

M.match = function (str, pat)
  assert(type(str) == "string")
  assert(type(pat) == "string")
  return M.matcher(pat)(str)
end

















M.splitter = function (pat, opts)
  opts = opts or {}
  local delim = opts.delim or false
  return function (str)
    return gen.genco(function (co)
      local n = 0
      local ls = 0
      local stop = false
      while not stop do
        local s, e = str:find(pat, n)
        stop = s == nil
        if stop then
          s = #str + 1
        end
        if delim == true then
          co.yield(str:sub(n, s - 1))
          if not stop then
            co.yield(str:sub(s, e))
          end
        elseif delim == "left" then
          co.yield(str:sub(n, e))
        elseif delim == "right" then
          co.yield(str:sub(ls, s - 1))
        else
          co.yield(str:sub(n, s - 1))
        end
        if stop then
          break
        else
          ls = s
          n = e + 1
        end
      end
    end)
  end
end

M.split = function (str, pat, opts)
  return M.splitter(pat, opts)(str)
end


M.escape = function (s)
  return (s:gsub("[%(%)%.%%+%-%*%?%[%]%^%$]", "%%%1"))
end


M.unescape = function (s)
  return (s:gsub("%%([%(%)%.%%+%-%*%?%[%]%^%$])", "%1"))
end

M.printf = function (s, ...)
  return io.write(s:format(...))
end



M.printi = function (s, t)
  return print(M.interp(s, t))
end





M.interp = function (s, t)
  M.unimplemented("interp")
end





M.indent = function (s, opts)
  M.unimplemented("indent")
end







M.trim = function (s, opts)
  M.unimplemented("trim")
end

return M
