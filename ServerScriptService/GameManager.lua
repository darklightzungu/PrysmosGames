-- GameManager.lua
-- Route Rage — ServerScript for round & game state (action / combat / health / vehicle)
-- Place in: ServerScriptService

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")
local RunService        = game:GetService("RunService")

local WorldConfig = require(script.Parent:WaitForChild("WorldConfig"))

-- ── DataStore ────────────────────────────────────────────────────────────────
local gameDataStore = DataStoreService:GetDataStore("GameData_v1")

-- ── Remotes folder ───────────────────────────────────────────────────────────
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name   = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function getOrCreate(name, class)
	local obj = remotes:FindFirstChild(name)
	if not obj then
		obj        = Instance.new(class)
		obj.Name   = name
		obj.Parent = remotes
	end
	return obj
end

-- Combat remotes
local dealDamage      = getOrCreate("DealDamage",      "RemoteEvent")  -- server: apply damage
local updateKills     = getOrCreate("UpdateKills",      "RemoteEvent")  -- server→client: kill count
local notifyDeath     = getOrCreate("NotifyDeath",      "RemoteEvent")  -- server→client: you died

-- Health remotes
local updateHealth    = getOrCreate("UpdateHealth",     "RemoteEvent")  -- server→client: current HP
local requestHeal     = getOrCreate("RequestHeal",      "RemoteEvent")  -- client→server: use health pack
local syncHealthPacks = getOrCreate("SyncHealthPacks",  "RemoteEvent")  -- server→client: pack positions

-- Vehicle remotes
local requestVehicle  = getOrCreate("RequestVehicle",   "RemoteEvent")  -- client→server: enter vehicle
local ejectVehicle    = getOrCreate("EjectVehicle",     "RemoteEvent")  -- client→server: exit vehicle
local updateVehicle   = getOrCreate("UpdateVehicle",    "RemoteEvent")  -- server→client: vehicle state

-- General
local updateTimer     = getOrCreate("UpdateTimer",      "RemoteEvent")  -- server→client: round timer

-- ── Game state ───────────────────────────────────────────────────────────────
local State = {
	phase       = "Waiting",   -- Waiting | Intermission | Active
	killCounts  = {},          -- [userId] = kills
	roundEndsAt = 0,
	vehicles    = {},          -- [vehicleModel] = { driver = player | nil, health = number }
	healthPacks = {},          -- [packModel] = { available = bool, respawnAt = number }
}

local MIN_PLAYERS  = WorldConfig.MinPlayers or 2
local VEHICLE_HP   = WorldConfig.VehicleHealth   or 200
local PACK_AMOUNT  = WorldConfig.HealthPackAmount or 50
local PACK_RESPAWN = WorldConfig.HealthPackRespawn or 20  -- seconds

-- ── Default player data structure ────────────────────────────────────────────
local function defaultData()
	return {
		kills    = 0,
		deaths   = 0,
		currency = 0,
	}
end

-- ── Per-player live session data ──────────────────────────────────────────────
local sessionData = {}   -- [userId] = merged persistent + live data

-- ── Save & load helpers ───────────────────────────────────────────────────────
local function loadPlayerData(player)
	local userId = player.UserId
	local data   = defaultData()

	local ok, result = pcall(function()
		return gameDataStore:GetAsync("player_" .. userId)
	end)

	if ok and result then
		-- Merge saved fields; keep defaults for any missing keys
		for k, v in pairs(result) do
			data[k] = v
		end
	elseif not ok then
		warn("[GameManager] DataStore load failed for", player.Name, ":", result)
	end

	sessionData[userId] = data
	State.killCounts[userId] = data.kills  -- carry kills for display (reset on round start)
	return data
end

local function savePlayerData(player)
	local userId = player.UserId
	local data   = sessionData[userId]
	if not data then return end

	local ok, err = pcall(function()
		gameDataStore:SetAsync("player_" .. userId, data)
	end)

	if not ok then
		warn("[GameManager] DataStore save failed for", player.Name, ":", err)
	end
end

-- ── Vehicle helpers ───────────────────────────────────────────────────────────
local function initVehicles()
	-- Expects WorldConfig.Vehicles = { { model = Instance, spawnCFrame = CFrame }, ... }
	if not WorldConfig.Vehicles then return end
	for _, vConfig in ipairs(WorldConfig.Vehicles) do
		local model = vConfig.model
		if model and model:IsA("Model") then
			State.vehicles[model] = {
				driver  = nil,
				health  = VEHICLE_HP,
				spawnCF = vConfig.spawnCFrame,
			}
		end
	end
end

local function respawnVehicle(model)
	local vData = State.vehicles[model]
	if not vData then return end
	vData.driver = nil
	vData.health = VEHICLE_HP
	-- Teleport model back to spawn position
	local root = model:FindFirstChild("PrimaryPart") or model.PrimaryPart
	if root and vData.spawnCF then
		model:SetPrimaryPartCFrame(vData.spawnCF)
	end
	model.Parent = workspace
	-- Notify all clients of fresh vehicle state
	for _, p in ipairs(Players:GetPlayers()) do
		updateVehicle:FireClient(p, model, { driver = nil, health = VEHICLE_HP })
	end
end

local function applyVehicleDamage(model, amount)
	local vData = State.vehicles[model]
	if not vData then return end
	vData.health = math.max(0, vData.health - amount)

	-- Eject driver if vehicle destroyed
	if vData.health <= 0 and vData.driver then
		ejectVehicle:FireClient(vData.driver, model, "destroyed")
		vData.driver = nil
		-- Respawn vehicle after delay
		task.delay(WorldConfig.VehicleRespawnTime or 15, function()
			respawnVehicle(model)
		end)
	else
		-- Sync health to all clients
		for _, p in ipairs(Players:GetPlayers()) do
			updateVehicle:FireClient(p, model, { driver = vData.driver, health = vData.health })
		end
	end
end

-- ── Health pack helpers ───────────────────────────────────────────────────────
local function initHealthPacks()
	-- Expects WorldConfig.HealthPacks = { Instance (Part/Model), ... }
	if not WorldConfig.HealthPacks then return end
	for _, pack in ipairs(WorldConfig.HealthPacks) do
		State.healthPacks[pack] = { available = true, respawnAt = 0 }
	end
	-- Tell joining clients where packs are
end

local function useHealthPack(player, pack)
	local packData = State.healthPacks[pack]
	if not packData or not packData.available then return false end

	local char      = player.Character
	local humanoid  = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	-- Heal the player
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + PACK_AMOUNT)
	updateHealth:FireClient(player, humanoid.Health, humanoid.MaxHealth)

	-- Disable pack visually
	packData.available = false
	packData.respawnAt = os.clock() + PACK_RESPAWN
	if pack:IsA("BasePart") or pack:IsA("Model") then
		pack.Parent = nil  -- hide from workspace temporarily
	end

	-- Respawn pack after cooldown
	task.delay(PACK_RESPAWN, function()
		if State.healthPacks[pack] then
			State.healthPacks[pack].available = true
			pack.Parent = workspace
			-- Sync pack list to all clients
			for _, p in ipairs(Players:GetPlayers()) do
				syncHealthPacks:FireClient(p, pack, true)
			end
		end
	end)
	return true
end

-- ── Combat helpers ────────────────────────────────────────────────────────────
local DAMAGE_COOLDOWN = {}  -- simple rate-limit [userId] = lastHitTime

local function applyCombatDamage(attacker, victimChar, amount)
	if not victimChar then return end
	local humanoid = victimChar:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- Rate-limit: one hit per 0.1 s per attacker to prevent spam
	local uid = attacker.UserId
	local now = os.clock()
	if (DAMAGE_COOLDOWN[uid] or 0) + 0.1 > now then return end
	DAMAGE_COOLDOWN[uid] = now

	-- Tag victim with creator so death handler can award kill
	local tag = humanoid:FindFirstChild("creator") or Instance.new("ObjectValue")
	tag.Name   = "creator"
	tag.Value  = attacker
	tag.Parent = humanoid
	game:GetService("Debris"):AddItem(tag, 3)  -- auto-clean tag

	humanoid:TakeDamage(amount)

	-- Sync health to the victim
	local victim = Players:GetPlayerFromCharacter(victimChar)
	if victim then
		updateHealth:FireClient(victim, humanoid.Health, humanoid.MaxHealth)
	end
end

-- ── Character lifecycle ───────────────────────────────────────────────────────
local function spawnAtDefault(player)
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local area    = WorldConfig.DefaultArea
	local spawns  = area and area.spawnPoints
	if spawns and #spawns > 0 then
		root.CFrame = CFrame.new(spawns[math.random(#spawns)])
	end
end

local function onCharacterAdded(player, char)
	local humanoid = char:WaitForChild("Humanoid")

	-- Immediately broadcast starting health
	updateHealth:FireClient(player, humanoid.Health, humanoid.MaxHealth)

	humanoid.Died:Connect(function()
		local uid  = player.UserId
		local data = sessionData[uid]
		if data then data.deaths = (data.deaths or 0) + 1 end

		-- Check creator tag for kill credit
		local tag = humanoid:FindFirstChild("creator")
		if tag and tag.Value and tag.Value ~= player then
			local killer   = tag.Value
			local killerId = killer.UserId
			State.killCounts[killerId] = (State.killCounts[killerId] or 0) + 1
			local kData = sessionData[killerId]
			if kData then kData.kills = (kData.kills or 0) + 1 end
			updateKills:FireClient(killer, State.killCounts[killerId])
		end

		notifyDeath:FireClient(player)

		-- Eject from vehicle on death
		for model, vData in pairs(State.vehicles) do
			if vData.driver == player then
				vData.driver = nil
				ejectVehicle:FireClient(player, model, "died")
				for _, p in ipairs(Players:GetPlayers()) do
					updateVehicle:FireClient(p, model, { driver = nil, health = vData.health })
				end
			end
		end

		-- Respawn after delay if round is active
		if State.phase == "Active" then
			task.delay(WorldConfig.RespawnDelay or 3, function()
				if player and player.Parent then
					player:LoadCharacter()
				end
			end)
		end
	end)

	-- Sync health on change (damage from environment, etc.)
	humanoid.HealthChanged:Connect(function(hp)
		updateHealth:FireClient(player, hp, humanoid.MaxHealth)
	end)
end

-- ── Remote handlers ───────────────────────────────────────────────────────────

-- Client requests to deal damage to a character (validated server-side)
dealDamage.OnServerEvent:Connect(function(attacker, victimChar, amount)
	-- Clamp amount to configured max to prevent exploits
	local maxDmg = WorldConfig.MaxDamagePerHit or 50
	amount = math.clamp(tonumber(amount) or 0, 0, maxDmg)
	applyCombatDamage(attacker, victimChar, amount)
end)

-- Client requests to use a health pack
requestHeal.OnServerEvent:Connect(function(player, pack)
	useHealthPack(player, pack)
end)

-- Client requests to enter a vehicle
requestVehicle.OnServerEvent:Connect(function(player, model)
	local vData = State.vehicles[model]
	if not vData then return end
	if vData.driver ~= nil then return end          -- already occupied
	if vData.health <= 0 then return end            -- destroyed

	vData.driver = player
	-- Notify all clients
	for _, p in ipairs(Players:GetPlayers()) do
		updateVehicle:FireClient(p, model, { driver = player, health = vData.health })
	end
end)

-- Client requests to leave a vehicle
ejectVehicle.OnServerEvent:Connect(function(player, model)
	local vData = State.vehicles[model]
	if not vData then return end
	if vData.driver ~= player then return end       -- not the driver

	vData.driver = nil
	for _, p in ipairs(Players:GetPlayers()) do
		updateVehicle:FireClient(p, model, { driver = nil, health = vData.health })
	end
end)

-- ── Player added / removing ───────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	loadPlayerData(player)
	State.killCounts[player.UserId] = 0

	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
		spawnAtDefault(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)

	-- Free any vehicle this player was driving
	for model, vData in pairs(State.vehicles) do
		if vData.driver == player then
			vData.driver = nil
			for _, p in ipairs(Players:GetPlayers()) do
				updateVehicle:FireClient(p, model, { driver = nil, health = vData.health })
			end
		end
	end

	State.killCounts[player.UserId] = nil
	sessionData[player.UserId]      = nil
	DAMAGE_COOLDOWN[player.UserId]  = nil
end)

-- Save all players if server shuts down unexpectedly
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player)
	end
end)

-- ── Round logic ───────────────────────────────────────────────────────────────
local function resetRoundKills()
	for _, p in ipairs(Players:GetPlayers()) do
		State.killCounts[p.UserId]