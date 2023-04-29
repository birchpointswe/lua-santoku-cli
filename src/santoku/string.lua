








local vec = require("santoku.vector")





local M = {}














M.match = function (str, pat)
  assert(type(pat) == "string")
  assert(type(str) == "string")
  local t = vec()
  for tok in str:gmatch(pat) do
    t:append(tok)
  end
  return t
end




















M.split = function (str, pat, opts)
  opts = opts or {}
  local delim = opts.delim or false
  local n = 1
  local ls = 1
  local stop = false
  local ret = vec()
  while not stop do
    local s, e = str:find(pat, n)
    stop = s == nil
    if stop then
      s = #str + 1
    end
    if delim == true then
      ret:append(str:sub(n, s - 1))
      if not stop then
        ret:append(str:sub(s, e))
      end
    elseif delim == "left" then
      ret:append(str:sub(n, e))
    elseif delim == "right" then
      ret:append(str:sub(ls, s - 1))
    else
      ret:append(str:sub(n, s - 1))
    end
    if stop then
      break
    else
      ls = s
      n = e + 1
    end
  end
  return ret
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
  return table.concat(M.split(s, "%%%w*", {
    delim = true
  }):map(function (s)
    local v = s:match("%%(%w*)")
    if v ~= nil then
      return t[v]
    else
      return s
    end
  end))
end






M.indent = function (s, opts)
  M.unimplemented("indent")
end







M.trim = function (s, opts)
  local left = "%s*"
  local right = "%s*"
  if opts == nil then
    -- luacheck: ignore

  elseif type(opts) == "string" then
    left = opts
    right = opts
  elseif type(opts) == "table" then
    left = opts.left or left
    right = opts.right or right
  else
    error("unexpected options argument: " .. type(opts))
  end
  if left ~= false then
    s = s:replace("^" .. left, "")
  end
  if right ~= false then
    s = s:replace(right  .. "$", "")
  end
  return s
end

M.isempty = function (s)
  if s:match("^%s*$") then
    return true
  else 
    return false
  end
end

M.endswith = function (str, pat)
  if str:match(pat .. "$") then
    return true
  else
    return false
  end
end

M.startswith = function (str, pat)
  if str:match("^" .. pat) then
    return true
  else
    return false
  end
end



M.commonprefix = function (...)
  local strList = { ... }
  local shortest, prefix, first = math.huge, ""
  for _, str in pairs(strList) do
    if str:len() < shortest then shortest = str:len() end
  end
  for strPos = 1, shortest do
    if strList[1] then
      first = strList[1]:sub(strPos, strPos)
    else
      return prefix
    end
    for listPos = 2, #strList do
      if strList[listPos]:sub(strPos, strPos) ~= first then
        return prefix
      end
    end
    prefix = prefix .. first
  end
  return prefix
end

return M
