-- PlayerData.lua — minimal session store for Huntrix builds
local PlayerData = {}
local session = {}
function PlayerData.get(player)
  return session[player.UserId] or { stars = 0, checkpoint = 1 }
end
function PlayerData.set(player, data)
  session[player.UserId] = data
end
return PlayerData
