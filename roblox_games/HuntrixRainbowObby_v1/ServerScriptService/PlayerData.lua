-- PlayerData.lua — session persistence for Huntrix Rainbow Obby
-- ServerScriptService ModuleScript

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local STORE_KEY = "HuntrixRainbowObby_v1"
local store = DataStoreService:GetDataStore(STORE_KEY)

local DEFAULT = {
	stars = 0,
	checkpoint = 1,
	carpetUses = 0,
}

local session = {}

local function merge(saved)
	local data = table.clone(DEFAULT)
	if saved then
		for k, v in pairs(saved) do
			data[k] = v
		end
	end
	return data
end

local PlayerData = {}

function PlayerData.load(player)
	local key = tostring(player.UserId)
	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)
	session[player.UserId] = ok and merge(result) or table.clone(DEFAULT)
	return session[player.UserId]
end

function PlayerData.get(player)
	return session[player.UserId] or PlayerData.load(player)
end

function PlayerData.save(player)
	local key = tostring(player.UserId)
	local data = session[player.UserId]
	if not data then
		return
	end
	pcall(function()
		store:SetAsync(key, data)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	PlayerData.save(player)
	session[player.UserId] = nil
end)

return PlayerData
