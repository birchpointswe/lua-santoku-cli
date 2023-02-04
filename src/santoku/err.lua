local tup = require("santoku.tuple")
local compat = require("santoku.compat")
local co = require("santoku.co")





















local M = {}

M.unimplemented = function (msg)
  M.error("Unimplemented", msg)
end

M.error = function (...)
  error(table.concat({ ... }, ": "), 2)
end

M.pwrapper = function (co, ...)
  local errs = tup(...)
  local wrapper = {
    err = function (...)
      return M.pwrapper(co, ...)
    end,
    exists = function (val, ...)
      if val ~= nil then
        return val, ...
      else
        return errs(function (...)
          return co.yield(...)
        end, ...)
      end
    end,






    okexists = function (ok, val, ...)
      if ok and val ~= nil then
        return val, ...
      else
        return errs(function (...)
          return co.yield(...)
        end, ...)
      end
    end,
    ok = function (ok, ...)
      if ok then
        return ...
      else
        return errs(function (...)
          return co.yield(...)
        end, ...)
      end
    end
  }
  return setmetatable(wrapper, {
    __call = function (_, ...)
      return wrapper.ok(...)
    end
  })
end









M.pwrap = function (run, onErr)
  onErr = onErr or function (...)
    return false, ...
  end
  local co = co()
  local cor = co.create(function ()
    return run(M.pwrapper(co))
  end)
  local ret
  local nxt = tup()
  while true do
    ret = nxt(function (...)
      return tup(co.resume(cor, select(2, ...)))
    end)
    local status = co.status(cor)
    if status == "dead" then
      break
    elseif status == "suspended" then
      nxt = ret(function (...)
        return tup(onErr(select(2, ...)))
      end)
      if not nxt(compat.id) then
        ret = nxt
        break
      end
    end
  end
  return ret(compat.id)
end

return M
