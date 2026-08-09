--!nonstrict

local status = noctalia.state.get("cloudflare.status") or "disconnected"

local function render()
  local connected = status == "connected"
  local starting = status == "starting"
  local description = connected and "Tunnel is connected"
    or (starting and "Tunnel is connecting…" or "Tunnel is disconnected")

  panel.render(ui.column({ gap = 16 }, {
    ui.row({ align = "center", gap = 10 }, {
      ui.glyph({ name = connected and "broadcast" or "broadcast-off", color = connected and "tertiary" or "on_surface" }),
      ui.label({ text = "Cloudflare Tunnel", fontSize = 16, fontWeight = "bold", flexGrow = 1 }),
      ui.button({ glyph = "close", variant = "ghost", onClick = "onClose" }),
    }),
    ui.label({ text = description, color = "on_surface_variant" }),
    ui.button({
      text = connected and "Disconnect" or "Connect",
      variant = connected and "destructive" or "primary",
      enabled = not starting,
      onClick = "onToggle",
    }),
  }))
end

noctalia.state.watch("cloudflare.status", function(value)
  status = value or "disconnected"
  render()
end)

function onOpen(_context)
  noctalia.state.set("cloudflare.action", "refresh")
  render()
end

function onToggle()
  noctalia.state.set("cloudflare.action", status == "connected" and "stop" or "start")
  panel.close()
end

function onClose()
  panel.close()
end
