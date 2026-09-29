--!nonstrict

-- Owns the plugin's state; the widget and panel only watch it.
--   "meeting"    the upcoming or ongoing meeting, or false for none
--   "dismissed"  id of the meeting the user dismissed (persisted)

-- Granola (patched by ../patch_app.py) writes this whenever its "Show upcoming
-- meetings in menu bar" item would update on macOS: every minute and on each
-- calendar change.
local path = (noctalia.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/granola/next-meeting.json"

-- Liveness comes from the pid in the file; this only guards against a Granola
-- that is running but hung (it rewrites the file every minute).
local staleAfterMs = 3 * 60 * 1000

local dismissedFile = (noctalia.pluginDataDir() or "/tmp") .. "/dismissed"
noctalia.state.set("dismissed", noctalia.readFile(dismissedFile) or "")
noctalia.state.watch("dismissed", function(id)
  noctalia.writeFile(dismissedFile, id or "")
end)

local function publish(meeting)
  noctalia.state.set("meeting", meeting or false)
end

function update()
  noctalia.readFileAsync(path, function(contents)
    local ok, meeting = pcall(noctalia.json.decode, contents or "")
    local now = noctalia.nowMs()
    if not ok or type(meeting) ~= "table" or meeting.title == nil or meeting.startMs == nil
      or meeting.pid == nil or now - (meeting.updatedAt or 0) > staleAfterMs
      or (meeting.endMs ~= nil and meeting.endMs <= now) then
      publish(nil)
      return
    end
    -- Quitting or crashing leaves the file behind; the pid tells.
    noctalia.readFileAsync("/proc/" .. math.floor(meeting.pid) .. "/cmdline", function(cmdline)
      publish(cmdline ~= nil and string.find(cmdline, "granola", 1, true) and meeting or nil)
    end)
  end)
end

noctalia.setUpdateInterval(15000)
update()
