--!nonstrict

-- Opened by clicking the bar widget; Esc or an outside click closes it.
-- Every button carries a key and an explicit glyph: the reconciler reuses
-- controls by position and doesn't clear a glyph that a later render omits.
local lib = require("./lib.luau")

local isOpen = false

local function button(key, text, glyph, variant, size, onClick)
  return ui.button({
    key = key,
    text = text,
    glyph = glyph,
    variant = variant,
    controlSize = size,
    flexGrow = 1,
    onClick = onClick,
  })
end

local function openGranola(variant, size)
  return button("granola", "Open in Granola", "notes", variant, size, "onOpenGranola")
end

local function render()
  if not isOpen then
    return
  end
  local meeting = noctalia.state.get("meeting")
  if not meeting then
    panel.render(ui.column({ gap = 12 }, {
      ui.label({ key = "empty", text = "No more meetings today", color = "on_surface_variant" }),
      openGranola("primary", "md"),
    }))
    return
  end

  local dismiss = button("dismiss", "Dismiss", "eye-off", "ghost", "sm", "onDismiss")
  local primary, secondary
  if meeting.joinURI then
    primary = button("join", "Join " .. (meeting.joinApp or "call"), "video", "primary", "lg", "onJoin")
    secondary = { openGranola("ghost", "sm"), dismiss }
  else
    primary = openGranola("primary", "lg")
    secondary = { dismiss }
  end

  local started = lib.started(meeting)
  local status = lib.status(meeting)
  local heading = started and (meeting.endMs and ("Now · " .. status) or "Now") or ("Starts " .. status)

  -- flexGrow fills the fixed-height panel so the spacer can absorb the slack
  -- a one-line title leaves, keeping the actions pinned to the bottom.
  panel.render(ui.column({ gap = 4, flexGrow = 1 }, {
    ui.label({
      key = "status",
      text = string.upper(heading),
      fontSize = 11,
      fontWeight = "bold",
      color = started and "tertiary" or "primary",
    }),
    ui.label({ key = "title", text = meeting.title, fontSize = 17, fontWeight = "bold", maxLines = 2 }),
    ui.label({
      key = "details",
      text = lib.span(meeting) .. (meeting.joinApp and ("  ·  " .. meeting.joinApp) or ""),
      fontSize = 13,
      color = "on_surface_variant",
    }),
    ui.spacer({ key = "spacer", flexGrow = 1 }),
    ui.column({ key = "actions", gap = 6 }, {
      primary,
      ui.row({ key = "secondary", gap = 6 }, secondary),
    }),
  }))
end

function onOpen(_context)
  isOpen = true
  render()
end

function onClose()
  isOpen = false
end

-- Keeps the countdown moving while the panel stays open.
function update()
  render()
end

noctalia.state.watch("meeting", render)
noctalia.setUpdateInterval(15000)

-- Through xdg-open so the usual link routing applies (a Zoom link lands in
-- the browser, which hands off to the Zoom client if one is installed).
function onJoin()
  noctalia.runAsync({ "xdg-open", noctalia.state.get("meeting").joinURI })
  panel.close()
end

function onOpenGranola()
  noctalia.runAsync({ "granola" })
  panel.close()
end

function onDismiss()
  lib.dismiss(noctalia.state.get("meeting"))
  panel.close()
end
