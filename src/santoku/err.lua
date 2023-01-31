local vec = require("santoku.vector")
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
  local errs = vec(...)
  local args = vec()
  local nargs = 0
  local wrapper = {
    err = function (...)
      return M.pwrapper(co, ...)
    end,
    exists = function (val, ...)
      if val ~= nil then
        return val, ...
      else
        args:trunc():append(...)
        errs:trunc(errs.n - nargs):extend(args)
        nargs = args.n
        return co.yield(errs:unpack())
      end
    end,






    okexists = function (ok, val, ...)
      if ok and val ~= nil then
        return val, ...
      else
        args:trunc():append(...)
        errs:trunc(errs.n - nargs):extend(args)
        nargs = args.n
        return co.yield(errs:unpack())
      end
    end,
    ok = function (ok, ...)
      if ok then
        return ...
      else
        args:trunc():append(...)
        errs:trunc(errs.n - nargs):extend(args)
        nargs = args.n
        return co.yield(errs:unpack())
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
  local co = co.make()
  local cor = co.create(function ()
    return run(M.pwrapper(co))
  end)
  local ret = vec()
  local nxt = vec()
  while true do
    ret:trunc():append(co.resume(cor, nxt:unpack(2)))
    local status = co.status(cor)
    if status == "dead" then
      break
    elseif status == "suspended" then
      nxt:trunc():append(onErr(ret:unpack(2)))
      if not nxt[1] then
        ret = nxt
        break
      end
    end
  end
  return ret:unpack()
end

return M
