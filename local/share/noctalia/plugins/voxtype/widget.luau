--!nonstrict

local states = {
  idle = { visible = false, glyph = "microphone-2-off", color = "on_surface" },
  streaming = { visible = true, glyph = "microphone-2", color = "tertiary" },
  recording = { visible = true, glyph = "microphone-2", color = "tertiary" },
  transcribing = { visible = true, glyph = "loader", color = "primary" },
  stopped = { visible = true, glyph = "microphone-2-off", color = "error" },
}

local function render(status)
  if type(status) ~= "table" then
    return
  end

  local state = states[status.class] or states[status.alt]
  if state == nil then
    return
  end

  barWidget.setVisible(state.visible)
  barWidget.setGlyph(state.glyph)
  barWidget.setGlyphColor(state.color)
  barWidget.setText("")
  barWidget.setTooltip(type(status.tooltip) == "string" and status.tooltip or "Voxtype")
end

local function onStatusLine(line)
  local ok, status = pcall(noctalia.json.decode, line)
  if ok then
    render(status)
  end
end

barWidget.setVisible(false)

if not noctalia.commandExists("voxtype") then
  barWidget.setVisible(true)
  barWidget.setGlyph("microphone-off")
  barWidget.setGlyphColor("error")
  barWidget.setTooltip("Voxtype is unavailable")
else
  local command = "voxtype status --follow --format json"
  local retryLoop = 'P=$PPID; while kill -0 "$P" 2>/dev/null; do '
    .. command .. "; sleep 2; done"
  if not noctalia.runStream(retryLoop, onStatusLine) then
    barWidget.setVisible(true)
    barWidget.setGlyph("microphone-off")
    barWidget.setGlyphColor("error")
    barWidget.setTooltip("Voxtype status stream failed")
  end
end
