-- PlayerData.lua — session + Delivery Bucks
local Players = game:GetService("Players")

local DEFAULT = {
	deliveryBucks = 0,
	highScore = 0,
	runsCompleted = 0,
}

local session = {}

local PlayerData = {}

function PlayerData.load(player)
	session[player.UserId] = table.clone(DEFAULT)
	return session[player.UserId]
end

function PlayerData.get(player)
	return session[player.UserId] or PlayerData.load(player)
end

function PlayerData.addBucks(player, amount)
	local data = PlayerData.get(player)
	data.deliveryBucks += amount
	return data.deliveryBucks
end

Players.PlayerRemoving:Connect(function(player)
	session[player.UserId] = nil
end)

return PlayerData
