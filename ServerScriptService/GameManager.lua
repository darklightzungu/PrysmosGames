local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local WorldConfig = require(script.Parent:WaitForChild("WorldConfig"))

-- DataStore setup
local gameDataStore = DataStoreService:GetDataStore("GameData_v1")

-- Remotes folder setup
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

-- Create RemoteEvents for each mechanic
local function getOrCreateRemoteEvent(name)
	local existing = remotes:FindFirstChild(name)
	if existing then return existing end
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end

local combatEvent       = getOrCreateRemoteEvent("Combat")
local dealDamageEvent   = getOrCreateRemoteEvent("DealDamage")
local playerDiedEvent   = getOrCreateRemoteEvent("PlayerDied")
local combatStateEvent  = getOrCreateRemoteEvent("CombatState")

-- In-memory player data cache
local playerData = {}

-- Default player data template
local function defaultData()
	return {
		kills  = 0,
		deaths = 0,
		score  = 0,
		level  = 1,
		xp     = 0,
	}
end

-- Load data from DataStore for a player
local function loadPlayerData(player)
	local key = tostring(player.UserId)
	local success, result = pcall(function()
		return gameDataStore:GetAsync(key)
	end)
	if success and result then
		-- Merge stored data with defaults to handle new fields
		local data = defaultData()
		for k, v in pairs(result) do
			data[k] = v
		end
		playerData[player.UserId] = data
	else
		if not success then
			warn("[GameManager] Failed to load data for " .. player.Name .. ": " .. tostring(result))
		end
		playerData[player.UserId] = defaultData()
	end
end

-- Save data to DataStore for a player
local function savePlayerData(player)
	local data = playerData[player.UserId]
	if not data then return end
	local key = tostring(player.UserId)
	local success, err = pcall(function()
		gameDataStore:SetAsync(key, data)
	end)
	if not success then
		warn("[GameManager] Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
end

-- Spawn player at the configured spawn point
local function spawnPlayerAtSpawn(player)
	local spawnPoint = nil

	-- Attempt to get spawn point from WorldConfig.DefaultArea
	local ok, result = pcall(function()
		local area = WorldConfig.DefaultArea
		if typeof(area) == "Instance" then
			-- Look for a SpawnLocation or Part named "SpawnPoint" inside the area
			local sp = area:FindFirstChild("SpawnPoint") or area:FindFirstChildWhichIsA("SpawnLocation")
			if sp then
				return sp
			end
		elseif typeof(area) == "Vector3" then
			return area
		end
		return nil
	end)

	if ok and result then
		spawnPoint = result
	end

	-- Apply spawn CFrame to character after it loads
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
	if humanoidRootPart then
		if typeof(spawnPoint) == "Instance" and spawnPoint:IsA("BasePart") then
			humanoidRootPart.CFrame = spawnPoint.CFrame + Vector3.new(0, 3, 0)
		elseif typeof(spawnPoint) == "Vector3" then
			humanoidRootPart.CFrame = CFrame.new(spawnPoint + Vector3.new(0, 3, 0))
		end
	end
end

-- =====================
-- COMBAT SYSTEM
-- =====================

local COMBO_WINDOW    = 1.5   -- seconds to chain combo hits
local BASE_DAMAGE     = 20    -- base hit damage
local COMBO_BONUS     = 5     -- extra damage per combo hit beyond first
local KO_SCORE        = 100   -- score awarded for a kill
local XP_PER_KILL     = 50

-- Per-player combat state
local combatState = {}

local function getCombatState(userId)
	if not combatState[userId] then
		combatState[userId] = {
			inCombat   = false,
			comboCount = 0,
			lastHitTime = 0,
		}
	end
	return combatState[userId]
end

-- Apply damage to a target character
local function applyDamage(attacker, targetCharacter, damage)
	if not targetCharacter then return end
	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	humanoid:TakeDamage(damage)
	return humanoid.Health
end

-- Award kill credit to attacker
local function awardKill(attacker)
	local data = playerData[attacker.UserId]
	if not data then return end
	data.kills  = data.kills + 1
	data.score  = data.score + KO_SCORE
	data.xp     = data.xp + XP_PER_KILL

	-- Level up every 200 XP
	local xpNeeded = data.level * 200
	if data.xp >= xpNeeded then
		data.xp    = data.xp - xpNeeded
		data.level = data.level + 1
	end

	-- Notify attacker of updated combat state
	combatStateEvent:FireClient(attacker, {
		kills  = data.kills,
		deaths = data.deaths,
		score  = data.score,
		level  = data.level,
		xp     = data.xp,
	})
end

-- Handle a combat hit request from a client
combatEvent.OnServerEvent:Connect(function(attacker, targetPlayer, hitData)
	-- Validate attacker
	if not attacker or not attacker.Character then return end
	if not attacker.Character:FindFirstChildOfClass("Humanoid") then return end

	-- Validate target
	local targetCharacter
	if typeof(targetPlayer) == "Instance" and targetPlayer:IsA("Player") then
		targetCharacter = targetPlayer.Character
	elseif typeof(targetPlayer) == "Instance" and targetPlayer:IsA("Model") then
		targetCharacter = targetPlayer -- NPC support
	end

	if not targetCharacter then return end
	local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then return end

	-- Sanity check: attacker and target must be reasonably close (anti-exploit)
	local attackerRoot = attacker.Character:FindFirstChild("HumanoidRootPart")
	local targetRoot   = targetCharacter:FindFirstChild("HumanoidRootPart")
	if attackerRoot and targetRoot then
		local dist = (attackerRoot.Position - targetRoot.Position).Magnitude
		if dist > 20 then
			warn("[GameManager] Combat hit rejected: too far (" .. dist .. " studs) for " .. attacker.Name)
			return
		end
	end

	-- Combo system
	local cs   = getCombatState(attacker.UserId)
	local now  = tick()
	local elapsed = now - cs.lastHitTime

	if elapsed <= COMBO_WINDOW then
		cs.comboCount = cs.comboCount + 1
	else
		cs.comboCount = 1
	end
	cs.lastHitTime = now
	cs.inCombat    = true

	local damage = BASE_DAMAGE + (cs.comboCount - 1) * COMBO_BONUS

	-- Apply damage
	local remainingHealth = applyDamage(attacker, targetCharacter, damage)

	-- Fire damage event to all clients for visual feedback
	dealDamageEvent:FireAllClients(attacker, targetCharacter, damage, cs.comboCount)

	-- Check if target was defeated
	if remainingHealth ~= nil and remainingHealth <= 0 then
		-- Award kill to attacker
		awardKill(attacker)

		-- Record death for target player if applicable
		local targetPlayerObj = Players:GetPlayerFromCharacter(targetCharacter)
		if targetPlayerObj then
			local tData = playerData[targetPlayerObj.UserId]
			if tData then
				tData.deaths = tData.deaths + 1
			end
			playerDiedEvent:FireAllClients(targetPlayerObj, attacker)
		else
			playerDiedEvent:FireAllClients(nil, attacker)
		end

		-- Reset attacker combo after KO
		cs.comboCount = 0
		cs.inCombat   = false
	end
end)

-- Reset combo if window expires (polled periodically)
RunService.Heartbeat:Connect(function()
	local now = tick()
	for userId, cs in pairs(combatState) do
		if cs.inCombat and (now - cs.lastHitTime) > COMBO_WINDOW then
			cs.comboCount = 0
			cs.inCombat   = false
		end
	end
end)

-- =====================
-- PLAYER LIFECYCLE
-- =====================

Players.PlayerAdded:Connect(function(player)
	loadPlayerData(player)

	-- Spawn character at configured spawn point
	player.CharacterAdded:Connect(function(character)
		-- Re-initialize combat state on respawn
		combatState[player.UserId] = {
			inCombat    = false,
			comboCount  = 0,
			lastHitTime = 0,
		}

		-- Send initial combat state to client
		local data = playerData[player.UserId]
		if data then
			combatStateEvent:FireClient(player, {
				kills  = data.kills,
				deaths = data.deaths,
				score  = data.score,
				level  = data.level,
				xp     = data.xp,
			})
		end
	end)

	-- Spawn immediately if character already exists
	if player.Character then
		spawnPlayerAtSpawn(player)
	end

	player.CharacterAdded:Connect(function()
		spawnPlayerAtSpawn(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
	playerData[player.UserId]   = nil
	combatState[player.UserId]  = nil
end)

-- Save all players on server shutdown
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player)
	end
end)

-- =====================
-- GAMEMANAGER MODULE API
-- =====================

local GameManager = {}

-- Get a copy of a player's current data
function GameManager.GetPlayerData(player)
	if not player then return nil end
	local data = playerData[player.UserId]
	if not data then return nil end
	-- Return a shallow copy to prevent external mutation
	local copy = {}
	for k, v in pairs(data) do copy[k] = v end
	return copy
end

-- Manually add score to a player (e.g. for objective completion)
function GameManager.AddScore(player, amount)
	if not player then return end
	local data = playerData[player.UserId]
	if not data then return end
	data.score = data.score + (amount or 0)
	combatStateEvent:FireClient(player, {
		kills  = data.kills,
		deaths = data.deaths,
		score  = data.score,
		level  = data.level,
		xp     = data.xp,
	})
end

-- Manually add XP to a player
function GameManager.AddXP(player, amount)
	if not player then return end
	local data = playerData[player.UserId]
	if not data then return end
	data.xp = data.xp + (amount or 0)
	local xpNeeded = data.level * 200
	if data.xp >= xpNeeded then
		data.xp    = data.xp - xpNeeded
		data.level = data.level + 1
	end
	combatStateEvent:FireClient(player, {
		kills  = data.kills,
		deaths = data.deaths,
		score  = data.score,
		level  = data.level,
		xp     = data.xp,
	})
end

-- Get current combat state for a player
function GameManager.GetCombatState(player)
	if not player then return nil end
	local cs = combatState[player.UserId]
	if not cs then return nil end
	return {
		inCombat   = cs.inCombat,
		comboCount = cs.comboCount,
	}
end

-- Force save a specific player's data
function GameManager.SavePlayer(player)
	savePlayerData(player)
end

-- Teleport a player back to spawn
function GameManager.RespawnAtSpawn(player)
	if not player then return end
	player:LoadCharacter()
end

-- Broadcast a message to all clients via combatStateEvent (reuse channel)
function GameManager.BroadcastCombatState(player)
	if not player then return end
	local data = playerData[player.UserId]
	if not data then return end
	combatStateEvent:FireAllClients({
		player = player.Name,
		kills  = data.kills,
		deaths = data.deaths,
		score  = data.score,
		level  = data.level,
	})
end

return GameManager