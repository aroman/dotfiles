--!nonstrict

local lib = require("./lib.luau")

local maxTitle = 28

local function truncate(text)
  if utf8.len(text) <= maxTitle then
    return text
  end
  -- Byte offset where character #maxTitle starts, so the cut never splits
  -- a multibyte character; with the ellipsis that is maxTitle characters.
  return string.sub(text, 1, utf8.offset(text, maxTitle) - 1) .. "…"
end

local function render()
  local meeting = noctalia.state.get("meeting")
  if not meeting or lib.isDismissed(meeting) then
    barWidget.setVisible(false)
    return
  end

  local untilStart = meeting.startMs - noctalia.nowMs()
  local color = untilStart <= 0 and "tertiary" or (untilStart <= 5 * 60 * 1000 and "primary" or "on_surface")

  barWidget.setVisible(true)
  barWidget.setGlyph(meeting.joinURI and "video" or "calendar-event")
  barWidget.setGlyphColor(color)
  barWidget.setText(truncate(meeting.title) .. " · " .. lib.status(meeting))
  barWidget.setTooltip(meeting.title .. "\n" .. lib.span(meeting))
end

-- The countdown moves even when the meeting doesn't; re-render from state.
function update()
  render()
end

noctalia.state.watch("meeting", render)
noctalia.state.watch("dismissed", render)
-- Countdowns are in whole minutes; 15 s keeps them within a quarter-minute.
noctalia.setUpdateInterval(15000)
render()
