-- Drive combine-stream's on-demand inputs without changing other apps' nodes.
-- Full node properties and their changes are needed: registry-only matching
-- misses role changes, and targeting names can select a different app stream.
local nodes = ObjectManager { Interest { type = "node" } }
local metadata = ObjectManager {
  Interest { type = "metadata", Constraint { "metadata.name", "=", "default" } },
}
local prefix = "combine.on-demand-stream."
local currentMetadata, currentSource
local captured = {}

-- Forwarded mixes and Granola's own output could duplicate playback or feed
-- excluded music/movie audio back into the capture.
local function eligible(p)
  return p["media.class"] == "Stream/Output/Audio"
    and p["media.role"] ~= "Music" and p["media.role"] ~= "Movie"
    and p["media.category"] ~= "Monitor"
    and p["node.virtual"] ~= "true"
    and p["application.name"] ~= "Granola"
end

local function reconcile()
  local md = metadata:lookup {}
  local source = nodes:lookup {
    Constraint { "node.name", "=", "granola_meeting_audio" },
  }
  local sourceId = source and source["bound-id"]

  if md ~= currentMetadata or sourceId ~= currentSource then
    if md and md == currentMetadata and currentSource then
      for serial in pairs(captured) do
        md:set(currentSource, prefix .. serial, nil, nil)
      end
    end
    currentMetadata, currentSource, captured = md, sourceId, {}
    if md and sourceId then
      -- Adopt existing keys if the policy is reloaded while PipeWire stays up.
      for _, key in md:iterate(sourceId) do
        local serial = key:match("^combine%.on%-demand%-stream%.(%d+)$")
        if serial then captured[serial] = true end
      end
    end
  end
  if not md or not sourceId then return end

  local wanted = {}
  for node in nodes:iterate() do
    local p = node.properties
    if eligible(p) then wanted[p["object.serial"]] = true end
  end
  for serial in pairs(captured) do
    if not wanted[serial] then md:set(sourceId, prefix .. serial, nil, nil) end
  end
  for serial in pairs(wanted) do
    if not captured[serial] then
      md:set(sourceId, prefix .. serial, "Spa:String:JSON",
        Json.Object { ["target.object"] = serial }:to_string())
    end
  end
  -- Include pending metadata writes so rapid role changes cancel an input
  -- even before its creation has made a round trip through the server.
  captured = wanted
end

nodes:connect("object-added", function(_, node)
  node:connect("notify::properties", reconcile)
  reconcile()
end)
nodes:connect("object-removed", reconcile)
metadata:connect("objects-changed", reconcile)
nodes:activate()
metadata:activate()
