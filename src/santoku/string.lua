local M = {}


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
