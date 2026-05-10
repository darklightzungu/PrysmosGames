-- GameManager.lua
-- Route Rage World — ServerScript (place in ServerScriptService)
-- Manages world-builder, starter-suburbs, spawn-pads, hazard-props, shortcuts

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")
local RunService        = game:GetService("RunService")

local WorldConfig = require(script.Parent:WaitForChild("WorldConfig"))

-- ── DataStore ────────────────────────────────────────────────────────────────
local gameDataStore = DataStoreService:GetDataStore("GameData_v1")

-- ── Remotes setup ────────────────────────────────────────────────────────────
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function getOrCreate(name, class)
	local obj = remotes:FindFirstChild(name)
	if not obj then
		obj = Instance.new(class)
		obj.Name = name
		obj.Parent = remotes
	end
	return obj
end

-- One remote per mechanic
local worldBuilderEvent  = getOrCreate("WorldBuilder",    "RemoteEvent")
local starterSuburbsEvent= getOrCreate("StarterSuburbs",  "RemoteEvent")
local spawnPadsEvent     = getOrCreate("SpawnPads",       "RemoteEvent")
local hazardPropsEvent   = getOrCreate("HazardProps",     "RemoteEvent")
local shortcutsEvent     = getOrCreate("Shortcuts",       "RemoteEvent")

-- Utility broadcast
local function fireAll(event, ...)
	for _, p in ipairs(Players:GetPlayers()) do
		event:FireClient(p, ...)
	end
end

-- ── Game state ───────────────────────────────────────────────────────────────
local State = {
	phase           = "Waiting",   -- Waiting | Active | Intermission
	playerData      = {},          -- [userId] -> persistent data table
	activePads      = {},          -- [padId]  -> { owner, cooldownUntil }
	activeHazards   = {},          -- [hazardId] -> { isActive, resetAt }
	unlockedShortcuts = {},        -- [userId]  -> list of unlocked shortcut ids
	placedObjects   = {},          -- [userId]  -> list of placed world objects
}

local MIN_PLAYERS = WorldConfig.MinPlayers or 2

-- ── Default player data ───────────────────────────────────────────────────────
local function defaultPlayerData()
	return {
		coins        = 0,
		buildTokens  = 10,          -- currency for world-builder
		suburb       = "Default",   -- current suburb assignment
		kills        = 0,
		deaths       = 0,
		shortcuts    = {},          -- unlocked shortcut ids
		placedObjects= {},          -- serialised placed objects
	}
end

-- ── DataStore: load ───────────────────────────────────────────────────────────
local function loadPlayerData(player)
	local uid = player.UserId
	local ok, result = pcall(function()
		return gameDataStore:GetAsync(tostring(uid))
	end)
	if ok and result then
		-- Merge saved data over defaults so new fields are always present
		local data = defaultPlayerData()
		for k, v in pairs(result) do
			data[k] = v
		end
		State.playerData[uid] = data
	else
		if not ok then
			warn("[GameManager] LoadPlayerData failed for", player.Name, ":", result)
		end
		State.playerData[uid] = defaultPlayerData()
	end
	return State.playerData[uid]
end

-- ── DataStore: save ───────────────────────────────────────────────────────────
local function savePlayerData(player)
	local uid  = player.UserId
	local data = State.playerData[uid]
	if not data then return end

	local ok, err = pcall(function()
		gameDataStore:SetAsync(tostring(uid), data)
	end)
	if not ok then
		warn("[GameManager] SavePlayerData failed for", player.Name, ":", err)
	end
end

-- ── Spawn helpers ─────────────────────────────────────────────────────────────
local function getDefaultSpawnCFrame()
	-- WorldConfig.DefaultArea should expose a SpawnPoint CFrame or Vector3
	local area = WorldConfig.DefaultArea
	if area and area.SpawnPoint then
		return CFrame.new(area.SpawnPoint)
	end
	return CFrame.new(0, 5, 0) -- fallback origin
end

local function spawnAtDefaultArea(player)
	local char = player.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = getDefaultSpawnCFrame()
		end
	end
end

-- ── Spawn Pads mechanic ───────────────────────────────────────────────────────
local PAD_COOLDOWN = WorldConfig.SpawnPadCooldown or 5  -- seconds

local function registerSpawnPad(padId, owner)
	State.activePads[padId] = { owner = owner, cooldownUntil = 0 }
	spawnPadsEvent:FireClient(owner, "Registered", padId)
end

local function useSpawnPad(player, padId)
	local pad = State.activePads[padId]
	if not pad then return false end
	if os.clock() < pad.cooldownUntil then
		spawnPadsEvent:FireClient(player, "Cooldown", padId, math.ceil(pad.cooldownUntil - os.clock()))
		return false
	end
	pad.cooldownUntil = os.clock() + PAD_COOLDOWN
	-- Teleport player to the pad's world position
	local padConfig = WorldConfig.SpawnPads and WorldConfig.SpawnPads[padId]
	if padConfig and padConfig.Position then
		local char = player.Character
		if char then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = CFrame.new(padConfig.Position)
			end
		end
	end
	spawnPadsEvent:FireClient(player, "Used", padId)
	return true
end

-- ── Hazard Props mechanic ─────────────────────────────────────────────────────
local HAZARD_RESET_TIME = WorldConfig.HazardResetTime or 10

local function initHazards()
	local hazardList = WorldConfig.HazardProps or {}
	for _, h in ipairs(hazardList) do
		State.activeHazards[h.id] = { isActive = true, resetAt = 0 }
	end
end

local function triggerHazard(hazardId, triggeringPlayer)
	local hazard = State.activeHazards[hazardId]
	if not hazard or not hazard.isActive then return end
	hazard.isActive = false
	hazard.resetAt  = os.clock() + HAZARD_RESET_TIME
	-- Notify all clients so they can play effects
	fireAll(hazardPropsEvent, "Triggered", hazardId)
	-- Schedule hazard reset
	task.delay(HAZARD_RESET_TIME, function()
		if State.activeHazards[hazardId] then
			State.activeHazards[hazardId].isActive = true
			fireAll(hazardPropsEvent, "Reset", hazardId)
		end
	end)
end

-- ── Shortcuts mechanic ────────────────────────────────────────────────────────
local SHORTCUT_COST = WorldConfig.ShortcutCost or 50  -- coins

local function unlockShortcut(player, shortcutId)
	local uid  = player.UserId
	local data = State.playerData[uid]
	if not data then return false end

	-- Check already unlocked
	for _, id in ipairs(data.shortcuts) do
		if id == shortcutId then
			shortcutsEvent:FireClient(player, "AlreadyUnlocked", shortcutId)
			return false
		end
	end

	if data.coins < SHORTCUT_COST then
		shortcutsEvent:FireClient(player, "InsufficientFunds", shortcutId)
		return false
	end

	data.coins = data.coins - SHORTCUT_COST
	table.insert(data.shortcuts, shortcutId)
	shortcutsEvent:FireClient(player, "Unlocked", shortcutId)
	return true
end

local function sendShortcutsToPlayer(player)
	local uid  = player.UserId
	local data = State.playerData[uid]
	if data then
		shortcutsEvent:FireClient(player, "Init", data.shortcuts)
	end
end

-- ── World-Builder mechanic ────────────────────────────────────────────────────
local MAX_PLACED = WorldConfig.MaxPlacedObjects or 20

local function placeObject(player, objectType, cframe)
	local uid  = player.UserId
	local data = State.playerData[uid]
	if not data then return false end

	if #data.placedObjects >= MAX_PLACED then
		worldBuilderEvent:FireClient(player, "LimitReached")
		return false
	end
	if data.buildTokens <= 0 then
		worldBuilderEvent:FireClient(player, "NoTokens")
		return false
	end

	data.buildTokens = data.buildTokens - 1
	local entry = { objectType = objectType, cf = cframe }
	table.insert(data.placedObjects, entry)
	-- Track in session state too
	State.placedObjects[uid] = data.placedObjects

	worldBuilderEvent:FireClient(player, "PlacedConfirm", objectType, cframe)
	-- Notify others so they can render the object
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			worldBuilderEvent:FireClient(p, "RemotePlaced", player.UserId, objectType, cframe)
		end
	end
	return true
end

local function removeObject(player, index)
	local uid  = player.UserId
	local data = State.playerData[uid]
	if not data then return end
	if not data.placedObjects[index] then return end

	table.remove(data.placedObjects, index)
	data.buildTokens = math.min(data.buildTokens + 1, MAX_PLACED) -- refund token
	State.placedObjects[uid] = data.placedObjects
	worldBuilderEvent:FireClient(player, "RemovedConfirm", index)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			worldBuilderEvent:FireClient(p, "RemoteRemoved", player.UserId, index)
		end
	end
end

-- ── Starter Suburbs mechanic ──────────────────────────────────────────────────
local SUBURBS = WorldConfig.StarterSuburbs or { "Willowdale", "Oakridge", "Mapleton" }

local function assignSuburb(player)
	local uid  = player.UserId
	local data = State.playerData[uid]
	if not data then return end
	if data.suburb == "Default" then
		-- Cycle assignment so suburbs fill evenly
		local idx = (uid % #SUBURBS) + 1
		data.suburb = SUBURBS[idx]
	end
	starterSuburbsEvent:FireClient(player, "Assigned", data.suburb)
end

local function getSuburbSpawnCFrame(suburbName)
	if WorldConfig.Suburbs and WorldConfig.Suburbs[suburbName] then
		return CFrame.new(WorldConfig.Suburbs[suburbName].SpawnPoint)
	end
	return getDefaultSpawnCFrame()
end

-- ── Kill/Death tracking ───────────────────────────────────────────────────────
local function onCharacterAdded(player, char)
	local humanoid = char:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		local uid  = player.UserId
		local data = State.playerData[uid]
		if data then
			data.deaths = data.deaths + 1
		end

		-- Credit kill to attacker (combat scripts set creator tag)
		local tag = humanoid:FindFirstChild("creator")
		if tag and tag.Value and tag.Value ~= player then
			local attacker     = tag.Value
			local attackerData = State.playerData[attacker.UserId]
			if attackerData then
				attackerData.kills  = attackerData.kills + 1
				attackerData.coins  = attackerData.coins + (WorldConfig.KillReward or 10)
			end
		end

		-- Respawn to suburb spawn during Active phase
		if State.phase == "Active" then
			task.delay(WorldConfig.RespawnDelay or 3, function()
				if player and player.Parent then
					player:LoadCharacter()
				end
			end)
		end
	end)
end

-- ── Remote listeners ──────────────────────────────────────────────────────────

-- World-builder: client requests place/remove
worldBuilderEvent.OnServerEvent:Connect(function(player, action, ...)
	if action == "Place" then
		local objectType, cframe = ...
		placeObject(player, objectType, cframe)
	elseif action == "Remove" then
		local index = ...
		removeObject(player, index)
	end
end)

-- Spawn pads: client requests use
spawnPadsEvent.OnServerEvent:Connect(function(player, action, padId)
	if action == "Use" then
		useSpawnPad(player, padId)
	end
end)

-- Hazard props: client reports trigger (validated server-side)
hazardPropsEvent.OnServerEvent:Connect(function(player, action, hazardId)
	if action == "Trigger" then
		triggerHazard(hazardId, player)
	end
end)

-- Shortcuts: client requests unlock
shortcutsEvent.OnServerEvent:Connect(function(player, action, shortcutId)
	if action == "Unlock" then
		unlockShortcut(player, shortcutId)
	end
end)

-- ── PlayerAdded / PlayerRemoving ──────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	local data = loadPlayerData(player)

	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
		-- Spawn at suburb if assigned, else default area
		task.wait() -- wait one frame for character to fully load
		if data.suburb and data.suburb ~= "Default" then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = getSuburbSpawnCFrame(data.suburb)
			end
		else
			spawnAtDefaultArea(player)
		end
	end)

	-- Initialise session state
	State.placedObjects[player.UserId]     = data.placedObjects
	State.unlockedShortcuts[player.UserId] = data.shortcuts

	-- Load character then send initial data
	player:LoadCharacter()
	assignSuburb(player)
	sendShortcutsToPlayer(player)

	-- Restore placed objects for this player to all others
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			for idx, obj in ipairs(data.placedObjects) do
				worldBuilderEvent:FireClient(p, "RemotePlaced", player.UserId, obj.objectType, obj.cf)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
	-- Clean up session state
	State.playerData[player.UserId]        = nil
	State.placedObjects[player.UserId]     = nil
	State.unlockedShortcuts[player.UserId] = nil
	-- Notify others that player's placed objects are gone
	fireAll(worldBuilderEvent, "PlayerLeft", player.UserId)
end)

-- Save all players on server close (handles forced shutdown)
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player)
	end
end)

-- ── Round loop ────────────────────────────────────────────────────────────────
local function startRound()
	State.phase = "Active"
	initHazards()
	-- Reset build tokens for all connected players
	for _, player in ipairs(Players:GetPlayers()) do
		local data = State.playerData[player.UserId]
		if data then
			data.buildTokens = WorldConfig.BuildTokensPerRound or 10
		end
		worldBuilderEvent:FireClient(player, "RoundStart")
	end
end

local function endRound()
	State.phase = "Intermission"
	fireAll(worldBuilderEvent, "RoundEnd")
	task.wait(WorldConfig.IntermissionDuration or 10)
end

local function gameLoop()
	while true do
		State.phase = "Waiting"
		-- Wait until minimum players are present
		repeat task.wait(2) until #Players:GetPlayers() >= MIN_PLAYERS

		startRound()

		-- Countdown timer broadcast
		local roundEnd = os.clock() + (WorldConfig.RoundDuration or 180)
		while os.clock() < roundEnd do
			local timeLeft = math.ceil(roundEnd - os.clock())
			for _, p in ipairs(Players:GetPlayers()) do
				-- Reuse shortcuts event channel for timer; extend remotes if desired
				shortcutsEvent:FireClient(p, "Timer", timeLeft)
			end
			task.wait(1)
		end

		endRound()
	end
end

task.spawn(gameLoop)

-- ── Public API ────────────────────────────────────────────────────────────────
local GameManager = {}

function GameManager.GetPlayerData(player)
	return State.playerData[player.UserId]
end

function GameManager.AddCoins(player, amount)
	local data = State.playerData[player.UserId]
	if data then
		data.coins = data.coins + amount
	end
end

function GameManager.GetPhase()
	return State.phase
end

function GameManager.RegisterSpawnPad(padId, owner)
	registerSpawnPad(padId, owner)
end

function GameManager.TriggerHazard(hazardId, player)
	triggerHazard(hazardId, player)
end

function GameManager.UnlockShortcut(player, shortcutId)
	return unlockShortcut(player, shortcutId)
end

function GameManager.PlaceObject(player, objectType, cframe)
	return placeObject(player, objectType, cframe)
end

function GameManager.RemoveObject(player, index)
	removeObject(player, index)
end

function GameManager.AssignSuburb(player, suburbName)
	local uid  = player.UserId
	local data = State.playerData[uid]
	if data then
		data.suburb = suburbName
		starterSuburbsEvent:FireClient(player, "Assigned", suburbName)
	end
end

return GameManager