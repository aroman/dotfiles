--!nonstrict

-- Formatting and dismissal helpers shared by the widget and panel. The
-- meeting itself comes from service.luau through noctalia.state.
local M = {}

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

function M.started(meeting)
  return meeting.startMs <= noctalia.nowMs()
end

-- "in 5m", "12m left" or "now".
function M.status(meeting)
  local now = noctalia.nowMs()
  if meeting.startMs > now then
    return "in " .. duration(meeting.startMs - now)
  end
  return meeting.endMs and (duration(meeting.endMs - now) .. " left") or "now"
end

-- "10:00–10:30".
function M.span(meeting)
  return clockTime(meeting.startMs) .. (meeting.endMs and ("–" .. clockTime(meeting.endMs)) or "")
end

-- Dismissing hides the widget for that one meeting; the next one shows again.
-- service.luau persists the "dismissed" state.
local function key(meeting)
  return meeting.id or meeting.title
end

function M.isDismissed(meeting)
  return noctalia.state.get("dismissed") == key(meeting)
end

function M.dismiss(meeting)
  noctalia.state.set("dismissed", key(meeting))
end

return M
