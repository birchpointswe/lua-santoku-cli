local co = require("santoku.co")

local function tuple ()
  local co = co()
  local function helper (...)
    co.yield(...)
    return helper(co.yield(...))
  end
  local cor = co.create(helper)
  return function (...)
    return select(2, co.resume(cor, ...))
  end
end


return function (...)
  local active = tuple()
  local inactive = tuple()
  active(...)
  return {

    set = function (...)
      inactive(active())
      active(...)
      return inactive()
    end,

    get = function (i)
      active, inactive = inactive, active
      return select(i or 1, active(inactive()))
    end
  }
end
