-- Run: lua test_route_audio.lua route_audio.lua. No audio server is accessed.
local managers = {}
function Interest(spec) return spec end
function Constraint(spec) return spec end
function ObjectManager()
  local om = { objects = {}, handlers = {} }
  function om:connect(event, callback) self.handlers[event] = callback end
  function om:activate() end
  function om:iterate()
    local i = 0
    return function() i = i + 1; return self.objects[i] end
  end
  function om:lookup(spec)
    for object in self:iterate() do
      local matches = true
      for _, constraint in ipairs(spec) do
        matches = matches and object.properties[constraint[1]] == constraint[3]
      end
      if matches then return object end
    end
  end
  function om:add(object)
    table.insert(self.objects, object)
    if self.handlers["object-added"] then self.handlers["object-added"](self, object) end
    if self.handlers["objects-changed"] then self.handlers["objects-changed"](self) end
  end
  function om:remove(object)
    for i, candidate in ipairs(self.objects) do
      if candidate == object then table.remove(self.objects, i); break end
    end
    if self.handlers["object-removed"] then self.handlers["object-removed"](self, object) end
    if self.handlers["objects-changed"] then self.handlers["objects-changed"](self) end
  end
  table.insert(managers, om)
  return om
end
Json = { Object = function(properties)
  return { to_string = function()
    return string.format('{"target.object":"%s"}', properties["target.object"])
  end }
end }

local function node(serial, properties)
  properties["object.serial"] = tostring(serial)
  local n = { properties = properties, ["bound-id"] = serial, handlers = {} }
  function n:connect(event, callback) self.handlers[event] = callback end
  function n:update(key, value)
    self.properties[key] = value
    self.handlers["notify::properties"](self)
  end
  return n
end
local function metadata()
  local md = { properties = {}, entries = {}, writes = {}, pending = {} }
  function md:apply(subject, key, value)
    self.entries[subject] = self.entries[subject] or {}
    self.entries[subject][key] = value
  end
  function md:set(subject, key, valueType, value)
    table.insert(self.writes, { subject, key, valueType, value })
    if self.delay then table.insert(self.pending, { subject, key, value })
    else self:apply(subject, key, value) end
  end
  function md:flush()
    for _, write in ipairs(self.pending) do self:apply(write[1], write[2], write[3]) end
    self.pending = {}
  end
  function md:iterate(subject)
    local key
    return function()
      key = next(self.entries[subject] or {}, key)
      if key then return subject, key, "Spa:String:JSON", self.entries[subject][key] end
    end
  end
  return md
end

dofile(assert(arg[1], "pass route_audio.lua"))
local nodes, metadatas = managers[1], managers[2]
local prefix = "combine.on-demand-stream."
local md = metadata()
md:apply(20, prefix .. "999", "{}") -- A stale input from a previous policy instance.
metadatas:add(md)
local source = node(20, { ["node.name"] = "granola_meeting_audio" })
nodes:add(source)
assert(md.entries[20][prefix .. "999"] == nil)

local function playback(serial, role, extra)
  local p = { ["media.class"] = "Stream/Output/Audio", ["media.role"] = role,
    ["node.name"] = "shared-name", ["media.category"] = "Playback" }
  for key, value in pairs(extra or {}) do p[key] = value end
  local n = node(serial, p)
  nodes:add(n)
  return n
end
local call = playback(100, nil)
local music = playback(101, "Music")
playback(102, "Movie")
playback(103, "BackgroundMusic")
playback(104, "Game")
playback(105, nil, { ["node.virtual"] = "true" })
playback(106, nil, { ["media.category"] = "Monitor" })
playback(107, nil, { ["application.name"] = "Granola" })
assert(md.entries[20][prefix .. "100"] == '{"target.object":"100"}')
for _, serial in ipairs { 103, 104 } do assert(md.entries[20][prefix .. serial]) end
for _, serial in ipairs { 101, 102, 105, 106, 107 } do
  assert(md.entries[20][prefix .. serial] == nil)
end
assert(call.properties["node.name"] == "shared-name")
assert(music.properties["media.category"] == "Playback")

call:update("media.role", "Music")
assert(md.entries[20][prefix .. "100"] == nil)
call:update("media.role", "Communication")
assert(md.entries[20][prefix .. "100"])
local writes = #md.writes
call:update("media.name", "changed title")
assert(#md.writes == writes)
-- The metadata proxy won't see writes until a server round trip completes.
md.delay = true
call:update("media.role", "Movie")
call:update("media.role", nil)
call:update("media.role", "Music")
md:flush()
md.delay = false
assert(md.entries[20][prefix .. "100"] == nil)
music:update("media.role", nil)
assert(md.entries[20][prefix .. "101"])
nodes:remove(music)
assert(md.entries[20][prefix .. "101"] == nil)

nodes:remove(source)
assert(next(md.entries[20]) == nil)
nodes:add(node(30, { ["node.name"] = "granola_meeting_audio" }))
assert(md.entries[30][prefix .. "103"] and md.entries[30][prefix .. "104"])
metadatas:remove(md)
local replacement = metadata()
metadatas:add(replacement)
assert(replacement.entries[30][prefix .. "103"])
print("routing policy: passed (roles, changes, exact targets, pending writes, source/metadata lifecycle)")
