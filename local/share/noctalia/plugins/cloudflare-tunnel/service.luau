--!nonstrict

local busy = false

local function normalizeStatus(value)
  value = (value or ""):match("^%s*(.-)%s*$")
  if value == "connected" or value == "starting" then
    return value
  end
  return "disconnected"
end

local function refresh()
  if busy then
    return
  end

  busy = true
  noctalia.runAsync("cloudflare-tunnel status", function(result)
    busy = false
    if result.exitCode == 0 then
      noctalia.state.set("cloudflare.status", normalizeStatus(result.stdout))
    else
      noctalia.state.set("cloudflare.status", "disconnected")
    end
  end, 3000)
end

local function runAction(action)
  if busy then
    return
  end

  busy = true
  noctalia.state.set("cloudflare.status", action == "start" and "starting" or "disconnected")
  noctalia.runAsync("cloudflare-tunnel " .. action, function(result)
    busy = false
    if result.exitCode ~= 0 then
      noctalia.notifyError("Cloudflare Tunnel", result.stderr ~= "" and result.stderr or "Action failed")
    end
    refresh()
  end, 10000)
end

noctalia.state.set("cloudflare.status", "disconnected")
noctalia.state.watch("cloudflare.action", function(action)
  if action == "start" or action == "stop" then
    runAction(action)
  elseif action == "refresh" then
    refresh()
  end
end)

noctalia.setUpdateInterval(5000)

function update()
  refresh()
end

refresh()
