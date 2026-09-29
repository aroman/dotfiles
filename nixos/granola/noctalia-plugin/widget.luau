--!nonstrict

-- Granola (patched by ../patch_app.py) writes this whenever its "Show upcoming
-- meetings in menu bar" item would update on macOS: every minute and on each
-- calendar change. Times are epoch ms.
local runtimeDir = noctalia.getenv("XDG_RUNTIME_DIR") or "/tmp"
local path = runtimeDir .. "/granola/next-meeting.json"

-- Granola rewrites the file every minute while it runs, so anything older
-- means it quit (or the toggle's off) and the meeting may be stale.
local staleAfterMs = 3 * 60 * 1000
local maxTitle = 28

local function duration(ms)
  local minutes = math.max(0, math.floor(ms / 60000))
  local hours = math.floor(minutes / 60)
  minutes = minutes % 60
  if hours == 0 then
    return minutes .. "m"
  elseif minutes == 0 then
    return hours .. "h"
  end
  return hours .. "h " .. minutes .. "m"
end

local function clockTime(ms)
  return noctalia.formatTime(noctalia.timeFormat(), math.floor(ms / 1000))
end

local function truncate(text)
  if utf8.len(text) <= maxTitle then
    return text
  end
  -- Byte offset where character #maxTitle starts, so the cut never splits
  -- a multibyte character; with the ellipsis that is maxTitle characters.
  return string.sub(text, 1, utf8.offset(text, maxTitle) - 1) .. "…"
end

local function render(meeting)
  local now = noctalia.nowMs()
  if meeting == nil or meeting.title == nil or meeting.startMs == nil
    or now - (meeting.updatedAt or 0) > staleAfterMs
    or (meeting.endMs ~= nil and meeting.endMs <= now) then
    barWidget.setVisible(false)
    return
  end

  local title = truncate(meeting.title)
  local untilStart = meeting.startMs - now
  local text, color
  if untilStart > 0 then
    text = title .. " · in " .. duration(untilStart)
    color = untilStart <= 5 * 60 * 1000 and "primary" or "on_surface"
  else
    text = meeting.endMs and (title .. " · " .. duration(meeting.endMs - now) .. " left") or (title .. " · now")
    color = "tertiary"
  end

  barWidget.setVisible(true)
  barWidget.setGlyph("calendar-event")
  barWidget.setGlyphColor(color)
  barWidget.setText(text)
  local span = clockTime(meeting.startMs) .. (meeting.endMs and ("–" .. clockTime(meeting.endMs)) or "")
  barWidget.setTooltip(meeting.title .. "\n" .. span)
end

function update()
  noctalia.readFileAsync(path, function(contents)
    local ok, meeting = pcall(noctalia.json.decode, contents or "")
    render(ok and type(meeting) == "table" and meeting or nil)
  end)
end

barWidget.setVisible(false)
-- Countdowns are in whole minutes; 15 s keeps them within a quarter-minute.
noctalia.setUpdateInterval(15000)
update()
