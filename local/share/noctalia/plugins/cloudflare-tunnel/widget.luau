--!nonstrict

local status = noctalia.state.get("cloudflare.status") or "disconnected"

local function render()
  local connected = status == "connected"
  barWidget.setGlyph(connected and "broadcast" or "broadcast-off")
  barWidget.setGlyphColor(status == "starting" and "primary" or (connected and "tertiary" or "on_surface"))

  if status == "starting" then
    barWidget.setTooltip("Cloudflare Tunnel: connecting")
  elseif connected then
    barWidget.setTooltip("Cloudflare Tunnel: connected")
  else
    barWidget.setTooltip("Cloudflare Tunnel: disconnected")
  end
end

noctalia.state.watch("cloudflare.status", function(value)
  status = value or "disconnected"
  render()
end)

function update()
  render()
end
