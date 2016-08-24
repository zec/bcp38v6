#!/usr/bin/lua

local intf = os.getenv('INTERFACE')

function map(t, f)
  local m = {}
  for k,v in ipairs(t) do
    m[k] = f(v)
  end

  return m
end

-- not a side-effect-free append!
function append(a, b)
  local n = #a
  for k,v in ipairs(b) do
    n = n + 1
    a[n] = v
  end
  return a
end

-- takes a table of arguments and returns a shell-escaped string
function sh_escape(t)
  return table.concat(
    map(t,
        function(s) return "'" .. string.gsub(s, "'+",
          function(x) return '\'"' .. x .. '"\'' end) .. "'" end),
    ' ')
end

-- runs one command
function sh(cmd)
  return os.execute(sh_escape(cmd))
  -- print(sh_escape(cmd))
  -- return 0
end

-- runs many commands in one shellout
function multi_sh(cmds)
  if #cmds <= 0 then return 0 end

  local c = table.concat(map(cmds, sh_escape), ' && ')
  return os.execute(c)
  -- print(c)
  -- return 0
end

-- uses UCI conventions for Boolean values
local uci_bmap = {
  ['0'] = false, ['no'] = false, ['off'] = false, ['false'] = false,
    ['disabled'] = false,
  ['1'] = true,  ['yes'] = true, ['on'] = true,   ['true'] = true,
    ['enabled'] = true
}
function to_bool(val, default_value)
  if val == nil then return default_value end

  val = uci_bmap[val]
  if val == nil then return default_value end
  return val
end

require 'uci'
local c = uci.cursor()

local intf_found, include_delegated, allow_multicast, wlist, blist
    = false, false, false, {}, {}
c:foreach('bcp38v6', 'filter', function(section)
  if section.interface == intf and to_bool(section.enabled, true) then
    intf_found = true
    include_delegated = include_delegated or to_bool(section.include_delegated, true)
    allow_multicast = allow_multicast or to_bool(section.allow_multicast, true)
    if type(section.whitelist) == 'table' then
      for k,v in ipairs(section.whitelist) do table.insert(wlist, v) end
    end
    if type(section.blacklist) == 'table' then
      for k,v in ipairs(section.blacklist) do table.insert(blist, v) end
    end
  end
end)

if not intf_found then
  os.exit(0)
end

if include_delegated then
  require 'ubus'
  local ub = ubus.connect()

  local x = ub:call('network.interface.' .. intf, 'status', {})
  if type(x) == 'table' and type(x['ipv6-prefix']) == 'table' then
    for k,v in ipairs(x['ipv6-prefix']) do
      table.insert(wlist, v.address .. '/' .. v.mask)
    end
  end
end

local tbls = map({'stage', 'out', 'in'},
                 function(s) return 'bcp38v6-' .. s .. '-' .. intf end)
sh({'ipset', 'flush', tbls[1]})
multi_sh(append(
  map(wlist, function(x) return {'ipset', 'add', tbls[1], x} end),
  map(blist, function(x) return {'ipset', 'add', tbls[1], x, 'nomatch'} end)
))
sh({'ipset', 'swap', tbls[1], tbls[2]})

if allow_multicast then
  table.insert(wlist, 'ff00::/8') -- perhaps limit to global-scope (ffxe::)?
end
sh({'ipset', 'flush', tbls[1]})
multi_sh(append(
  map(wlist, function(x) return {'ipset', 'add', tbls[1], x} end),
  map(blist, function(x) return {'ipset', 'add', tbls[1], x, 'nomatch'} end)
))
sh({'ipset', 'swap', tbls[1], tbls[3]})

sh({'ipset', 'flush', tbls[1]})
