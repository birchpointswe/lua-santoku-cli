local fs = require("lfs")






























local M = {}

M.co = require("santoku.co")

M.unimplemented = function (msg)
  local message = "Unimplemented"
  if msg then
    message = message .. ": " .. msg
  end
  error(message, 2)
end

M.error = function (...)
  error(table.concat({ ... }, ": "), 2)
end






M.extendarg = function (...)
  return table.unpack(M.extend({}, ...))
end

M.eq = function (a, b) return a == b end
M.neq = function (a, b) return a ~= b end
M["and"] = function (a, b) return a and b end
M["or"] = function (a, b) return a or b end
M.lt = function (a, b) return a < b end
M.gt = function (a, b) return a > b end
M.lte = function (a, b) return a <= b end
M.gte = function (a, b) return a >= b end
M.add = function (a, b) return a + b end
M.sub = function (a, b) return a - b end
M.mul = function (a, b) return a * b end
M.div = function (a, b) return a / b end
M.mod = function (a, b) return a % b end
M["not"] = function (a) return not a end
M.neg = function (a) return -a end
M.exp = function (a, b) return a ^ b end
M.len = function (a) return #a end
M.cat = function (a, b) return a .. b end

M.narg = function (...)
  local idx = table.pack(...)
  return function (fn)
    return function (...)
      local args0 = table.pack(...)
      local args1 = {}
      for _, v in ipairs(idx) do
        table.insert(args1, args0[v])
      end
      return fn(table.unpack(args1))
    end
  end
end

M.nret = function (...)
  local idx = table.pack(...)
  return function (...)
    local args = table.pack(...)
    local rets = {}
    for _, v in ipairs(idx) do
      table.insert(rets, args[v])
    end
    return table.unpack(rets)
  end
end

M.interpreter = function (args)
  if arg == nil then
    return nil
  end
  local i_min = 0
  while arg[i_min] do
    i_min = i_min - 1
  end
  i_min = i_min + 1
  local ret = {}
  for i = i_min, 0 do
    table.insert(ret, arg[i])
  end
  if args then
    for i = 1, #arg do
      table.insert(ret, arg[i])
    end
  end
  return ret
end

M.id = function (...)
  return ...
end

M.const = function (...)
  local val = table.pack(...)
  local coroutine = M.co()
  return M.gen(coroutine.wrap(function ()
    while true do
      coroutine.yield(table.unpack(val))
    end
  end))
end

M.compose = function (...)
  local args = table.pack(...)
  return M.ivals(args)
    :reduce(function(f, g)
      return function(...)
        return f(g(...))
      end
    end)
end


M.lens = function (...)
  local keys = table.pack(...)
  return function (fn)
    fn = fn or M.id
    return function(t)
      if keys.n == 0 then
        return t, fn(t)
      else
        local t0 = t
        for i = 1, keys.n - 1 do
          t0 = t0[keys[i]]
        end
        local val = fn(t0[keys[keys.n]])
        t0[keys[keys.n]] = val
        return t, val
      end
    end
  end
end

M.getter = function (...)
  return M.compose(M.nret(2), M.lens(...)())
end

M.get = function (t, keys)
  return M.getter(table.unpack(keys))(t)
end

M.setter = function (...)
  local args = table.pack(...)
  return function (v)
    return M.lens(table.unpack(args))(M.const(v))
  end
end

M.set = function (t, keys, ...)
  return M.setter(table.unpack(keys))(...)(t)
end

M.maybe = function (a, f, g)
  f = f or M.id
  g = g or M.const(nil)
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

M.iter = function (tbl, iter)
  tbl = tbl or {}
  local coroutine = M.co()
  return M.gen(coroutine.wrap(function ()
    local g, p, s = iter(tbl)
    while true do
      local vs = table.pack(g(p, s))
      s = vs[1]
      if s == nil then
        break
      else
        coroutine.yield(table.unpack(vs))
      end
    end
  end))
end

M.ipairs = function(t)
  return M.iter(t, ipairs)
end

M.pairs = function(t)
  return M.iter(t, pairs)
end

M.vals = function (t)
  return M.map(M.pairs(t), M.nret(2))
end

M.keys = function (t)
  return M.map(M.pairs(t), M.nret(1))
end

M.ivals = function (t)
  return M.map(M.ipairs(t), M.nret(2))
end

M.ikeys = function (t)
  return M.map(M.ipairs(t), M.nret(1))
end






M.gen = function (gen)
  return setmetatable({}, {
    __index = M,
    __call = gen,
  })
end

M.caller = function (...)
  local args = table.pack(...)
  return function (f)
    return f(table.unpack(args))
  end
end

M.call = function (f, ...)
  return M.caller(...)(f)
end

M.matcher = function (pat)
  return function (str)
    return M.gen(str:gmatch(pat))
  end
end

M.match = function (str, pat)
  return M.matcher(pat)(str)
end

M.reducer = function (acc, ...)
  local val1 = table.pack(...)
  return function (gen)
    if val1.n == 0 then
      val1 = table.pack(gen())
    end
    if val1.n == 0 then
      return nil
    end
    while true do
      local val2 = table.pack(gen())
      if val2.n == 0 then
        return table.unpack(val1)
      else
        val1 = table.pack(acc(M.extendarg(val1, val2)))
      end
    end
  end
end

M.reduce = function (gen, acc, ...)
  return M.reducer(acc, ...)(gen)
end

M.taker = function (n)
  return function (gen)
    local coroutine = M.co()
    return M.gen(coroutine.wrap(function ()
      while n > 0 do
        coroutine.yield(gen())
        n = n - 1
      end
    end))
  end
end

M.take = function (gen, n)
  return M.taker(n)(gen)
end

M.max = function (gen, def)
  return M.reduce(gen, function(a, b)
    if a > b then
      return a
    else
      return b
    end
  end, def)
end

M.flatten = function (gengen)
  local coroutine = M.co()
  return M.gen(coroutine.wrap(function ()
    while true do
      local gen = gengen()
      if gen == nil then
        break
      end
      while true do
        local val = table.pack(gen())
        if val.n == 0 then
          break
        end
        coroutine.yield(table.unpack(val))
      end
    end
  end))
end

M.collect = function (gen)
  return M.reduce(gen, function (a, ...)
    local vals = table.pack(...)
    if vals.n <= 1 then
      return M.append(a, vals[1])
    else




      return M.append(a, { ... })
    end
  end, {})
end

M.assigner = function (...)
  local args = table.pack(...)
  return function (t0)
    for _, t1 in ipairs(args) do
      for k, v in pairs(t1) do
        t0[k] = v
      end
    end
    return t0
  end
end

M.assign = function (t0, ...)
  return M.assigner(...)(t0)
end

M.extender = function (...)
  local args = table.pack(...)
  return function (a)
    for _, t in ipairs(args) do
      for _, v in ipairs(t) do
        table.insert(a, v)
      end
    end
    return a
  end
end

M.extend = function (a, ...)
  return M.extender(...)(a)
end

M.appender = function (...)
  local args = table.pack(...)
  return function (a)
    return M.extend(a, args)
  end
end

M.append = function (a, ...)
  return M.appender(...)(a)
end

M.filterer = function (fn, ...)
  local args = table.pack(...)
  return function (gen)
    local coroutine = M.co()
    return M.gen(coroutine.wrap(function ()
      while true do
        local val = table.pack(gen())
        if val.n == 0 then
          break
        end
        if fn(M.extendarg(val, args)) then
          coroutine.yield(table.unpack(val))
        end
      end
    end))
  end
end

M.filter = function (gen, fn, ...)
  return M.filterer(fn, ...)(gen)
end

M.mapper = function (fn, ...)
  local args = table.pack(...)
  return function (gen)
    local coroutine = M.co()
    return M.gen(coroutine.wrap(function ()
      while true do
        local vals = table.pack(gen())
        if vals.n == 0 then
          break
        else
          coroutine.yield(fn(M.extendarg(vals, args)))
        end
      end
    end))
  end
end

M.map = function (gen, fn, ...)
  return M.mapper(fn, ...)(gen)
end










M.zipper = function (opts)
  local fn = (opts or {}).fn or M.id
  local mode = (opts or {}).mode or "first"
  return function (...)
    local gens = table.pack(...)
    local coroutine = M.co()
    local nb = 0
    return M.gen(coroutine.wrap(function ()
      while true do
        local vals = {}
        local nils = 0
        for i, gen in ipairs(gens) do
          local val = table.pack(gen())
          if val.n == 0 then
            gens[i] = M.const(nil)
            nils = nils + 1
            vals[i] = val
            if mode == "first" then
              break
            end
          else
            vals[i] = val
          end
        end
        nb = nb + 1
        if type(mode) == "number" and nb > mode then
          break
        elseif mode == "first" and vals[1].n == 0 then
          break
        elseif mode == "shortest" and nils > 0 then
          break
        elseif gens.n == nils then
          break
        else
          coroutine.yield(fn(M.extendarg(table.unpack(vals))))
        end
      end
    end))
  end
end

M.zip = function (...)
  return M.zipper()(...)
end


M.aller = function (fn, ...)
  fn = fn or M.id
  local args = table.pack(...)
  return function (gen)
    return M.reduce(gen, function (a, ...)
      return a and fn(M.extendarg(args, table.pack(...)))
    end)
  end
end

M.all = function (gen, ...)
  return M.aller(...)(gen)
end

M.tabulator = function (keys, opts)
  local rest = (opts or {}).rest
  return function (genVals)
    local t = M.ivals(keys)
      :zip(genVals)
      :reduce(function (a, k, v)
        a[k] = v
        return a
      end, {})
    if rest then
      t[rest] = genVals:collect()
    end
    return t
  end
end

M.tabulate = function (gen, keys, opts)
  return M.tabulator(keys, opts)(gen)
end

M.finder = function (...)
  local args = table.pack(...)
  return function (gen)
    return gen:filter(table.unpack(args)):head()
  end
end

M.find = function (gen, ...)
  return M.finder(...)(gen)
end

M.chain = function (...)
  local gens = table.pack(...)
  local coroutine = M.co()
  return M.gen(coroutine.wrap(function ()
    for _, gen in ipairs(gens) do
      for v in gen do
        coroutine.yield(v)
      end
    end
  end))
end

M.equals = function (...)
  return M.zipper({
    fn = function (a, ...)
      local rest = table.pack(...)
      for _, v in ipairs(rest) do
        if a ~= v then
          return false
        end
      end
      return true
    end,
    mode = "longest"
  })(...):all()
end

















M.splitter = function (pat, opts)
  opts = opts or {}
  local delim = opts.delim or false
  return function (str)
    local coroutine = M.co()
    return M.gen(coroutine.wrap(function ()
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
          coroutine.yield(str:sub(n, s - 1))
          if not stop then
            coroutine.yield(str:sub(s, e))
          end
        elseif delim == "left" then
          coroutine.yield(str:sub(n, e))
        elseif delim == "right" then
          coroutine.yield(str:sub(ls, s - 1))
        else
          coroutine.yield(str:sub(n, s - 1))
        end
        if stop then
          break
        else
          ls = s
          n = e + 1
        end
      end
    end))
  end
end

M.split = function (str, pat, opts)
  return M.splitter(pat, opts)(str)
end

M.slicer = function (start, num)
  start = start or 1
  return function (gen)
    local coroutine = M.co()
    return M.gen(coroutine.wrap(function ()
      local val
      while start > 1 do
        val = gen()
        if val == nil then
          return
        end
        start = start - 1
      end
      while num == nil or num > 0 do
        coroutine.yield(gen())
        if num ~= nil then
          num = num - 1
        end
      end
    end))
  end
end

M.slice = function (gen, start, num)
  return M.slicer(start, num)(gen)
end

M.head = function (gen)
  return gen()
end

M.picker = function (n)
  return function (gen)
    return M.slice(gen, n, 1):head()
  end
end

M.pick = function (gen, n)
  return M.picker(n, gen)
end

M.mkdirp = function (dir)
  local p0 = nil
  for p1 in dir:gmatch("([^" .. M.pathdelim .. "]+)/?") do
    if p0 then
      p1 = M.join(p0, p1)
    end
    p0 = p1
    local ok, err, code = fs.mkdir(p1)
    if not ok and code ~= 17 then
      return ok, err, code
    end
  end
  return true
end

M.exists = function (fp)
  local mode, err, code = fs.attributes(fp, "mode")
  if mode == nil and code == 2 then
    return true, false
  elseif mode ~= nil then
    return true, true
  else
    return false, err, code
  end
end

M.dir = function (dir)
  local ok, entries, state = pcall(fs.dir, dir)
  if not ok then
    return false, entries, state
  else
    local coroutine = M.co()
    return true, M.gen(coroutine.wrap(function ()
      while true do
        local ent, state = entries(state)
        if ent == nil then
          break
        end
        coroutine.yield(ent)
      end
    end))
  end
end

M.each = function (gen, fn)
  while true do
    local vals = table.pack(gen())
    if vals.n == 0 then
      break
    else
      fn(table.unpack(vals))
    end
  end
end

M.walk = function (dir, opts)
  local prune = (opts or {}).prune or M.const(false)
  local prunekeep = (opts or {}).prunekeep or false
  local coroutine = M.co()
  return M.gen(coroutine.wrap(function()
    local ok, entries = M.dir(dir)
    if not ok then
      coroutine.yield(false, entries)
    else
      for it in entries do
        if it ~= M.dirparent and it ~= M.dirthis then
          it = M.join(dir, it)
          local attr, err, code = fs.attributes(it)
          if not attr then
            coroutine.yield(false, err, code)
          elseif attr.mode == "directory" then
            if not prune(it, attr) then
              coroutine.yield(true, it, attr)
              for ok0, it0, attr0 in M.walk(it, opts) do
                coroutine.yield(ok0, it0, attr0)
              end
            elseif prunekeep then
              coroutine.yield(true, it, attr)
            end
          else
            coroutine.yield(true, it, attr)
          end
        end
      end
    end
  end))
end

M.lines = function (fp)
  local ok, iter, cd = pcall(io.lines, fp)
  if ok then
    return true, M.gen(iter)
  else
    return false, iter, cd
  end
end

M.files = function (dir, opts)
  local recurse = (opts or {}).recurse
  local walkopts = {}
  if not recurse then
    walkopts.prune = function (it, attr)
      return attr.mode == "directory"
    end
  end
  return M.walk(dir, walkopts)
end

M.dirs = function (dir)
  local recurse = (opts or {}).recurse
  local walkopts = { prunekeep = true }
  if not recurse then
    walkopts.prune = function (it, attr)
      return attr.mode == "directory"
    end
  end
  return M.walk(dir, walkopts)
    :filter(function (ok, it, attr)
      return not ok or attr.mode == "directory"
    end)
end






M.pathdelim = "/"
M.pathroot = "/"
M.dirparent = ".."
M.dirthis = "."

M.basename = function (fp)
  if fp == M.pathroot then
    return fp
  elseif fp:sub(-1) == M.pathdelim then
    fp = fp:sub(0, -2)
  end
  return string.match(fp, "[^" .. M.pathdelim .. "]*$")
end

M.dirname = function (fp)
  M.unimplemented("dirname")
end

M.join = function (...)
  return M.joinwith(M.pathdelim, ...)
end

M.joinwith = function (d, ...)
  d = M.escape(d)
  local pat = string.format("(%s)+", d)
  return table.concat((table.pack(...)), d)
    :gsub(pat, d)
end

M.splitexts = function (fp)
  local parts = M.split(fp, M.pathdelim, { delim = "left" }):collect()
  local last = M.split(parts[#parts], "%.", { delim = "right" }):collect()
  if last[1] == "" then
    last = M.ivals(last):slice(2):collect()
  end
  return {
    exts = M.vals(last):slice(2):collect(),
    name = table.concat(M.chain(
      M.ivals(parts):slice(0, #parts - 1),
      M.ivals(last):slice(0, 1))
        :collect())
  }
end

M.pwrapper = function (coroutine, ...)
  local errs = table.pack(...)
  local wrapper = {
    err = function (...)
      return M.pwrapper(coroutine, ...)
    end,
    exists = function (val, ...)
      local args = table.pack(...)
      if val ~= nil then
        return val, ...
      else
        return coroutine.yield(M.extendarg(errs, args))
      end
    end,
    ok = function (ok, ...)
      local args = table.pack(...)
      if ok then
        return ...
      else
        return coroutine.yield(M.extendarg(errs, args))
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
  local coroutine = M.co()
  local err = table.pack(coroutine.wrap(function ()
    run(M.pwrapper(coroutine))
  end)())
  if err.n ~= 0 then
    return onErr(table.unpack(err))
  end
end

return M
