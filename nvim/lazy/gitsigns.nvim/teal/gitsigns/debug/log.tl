local M = {
  debug_mode = false,
  verbose = false,
  messages: {string} = {},
}

local function getvarvalue(name: string, lvl: integer): any
  lvl = lvl + 1
  local value: any
  local found: boolean

  -- try local variables
  local i = 1
  while true do
    local n, v = debug.getlocal(lvl as function, i) as (string, any)
    if not n then break end
    if n == name then
      value = v
      found = true
    end
    i = i + 1
  end
  if found then return value end

  -- try upvalues
  local func = debug.getinfo(lvl).func as function
  i = 1
  while true do
    local n, v = debug.getupvalue(func, i) as (string, any)
    if not n then break end
    if n == name then return v end
    i = i + 1
  end

  -- not found; get global
  return getfenv(func)[name]
end

local function get_context(lvl: integer): table
  lvl = lvl + 1
  local ret: table = {}
  ret.name = getvarvalue('__FUNC__', lvl) as string
  if not ret.name then
    local name0 = debug.getinfo(lvl, 'n').name or ''
    ret.name = name0:gsub('(.*)%d+$', '%1')
  end
  ret.bufnr = getvarvalue('bufnr', lvl)
    or getvarvalue('_bufnr', lvl)
    or getvarvalue('cbuf', lvl)
    or getvarvalue('buf', lvl)

  return ret
end

-- If called in a callback then make sure the callback defines a __FUNC__
-- variable which can be used to identify the name of the function.
local function cprint(obj: any, lvl: integer)
  lvl = lvl + 1
  local msg = obj is string and obj or vim.inspect(obj)
  local ctx = get_context(lvl)
  local msg2: string
  if ctx.bufnr then
    msg2 = string.format('%s(%s): %s', ctx.name, ctx.bufnr, msg)
  else
    msg2 = string.format('%s: %s', ctx.name, msg)
  end
  table.insert(M.messages, msg2)
end

function M.dprint(obj: any)
  if not M.debug_mode then return end
  cprint(obj, 2)
end

function M.dprintf(obj: string, ...:any)
  if not M.debug_mode then return end
  cprint(obj:format(...), 2)
end

function M.vprint(obj: any)
  if not (M.debug_mode and M.verbose) then return end
  cprint(obj, 2)
end

function M.vprintf(obj: string, ...:any)
  if not (M.debug_mode and M.verbose) then return end
  cprint(obj:format(...), 2)
end

local function eprint(msg: string, level: integer)
  local info = debug.getinfo(level+2, 'Sl')
  if info then
    msg = string.format('(ERROR) %s(%d): %s', info.short_src, info.currentline, msg)
  end
  M.messages[#M.messages+1] = msg
  if M.debug_mode then
    error(msg)
  end
end

function M.eprint(msg: string)
  eprint(msg, 1)
end

function M.eprintf(fmt: string, ...:any)
  eprint(fmt:format(...), 1)
end

return M
