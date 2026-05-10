-- GameManager.lua
-- Route Rage Terrain — ServerScript for game state & core logic
-- Place in: ServerScriptService

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")

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

-- One RemoteEvent per core mechanic
local evTerrainGeneration = getOrCreate("TerrainGeneration", "RemoteEvent")
local evStarterSuburbs    = getOrCreate("StarterSuburbs",    "RemoteEvent")
local evRoadNetwork       = getOrCreate("RoadNetwork",       "RemoteEvent")
local evShortcuts         = getOrCreate("Shortcuts",         "RemoteEvent")

-- ── Game state ───────────────────────────────────────────────────────────────
local State = {
	phase            = "Waiting",   -- Waiting | Generating | Active
	playerData       = {},          -- [userId] = { coins, shortcuts, completedRoads }
	generatedChunks  = {},          -- tracks which terrain chunks are active
	roadNodes        = {},          -- list of road node CFrames
	shortcutNodes    = {},          -- list of unlocked shortcut positions
	suburbRegions    = {},          -- suburb zone data
}

-- ── Default player data template ─────────────────────────────────────────────
local function defaultData()
	return {
		coins          = 0,
		shortcuts      = {},   -- list of shortcut IDs unlocked
		completedRoads = 0,
		lastArea       = WorldConfig.DefaultArea or "Suburbs",
	}
end

-- ── DataStore helpers ─────────────────────────────────────────────────────────
local function loadPlayerData(player)
	local userId = player.UserId
	local success, result = pcall(function()
		return gameDataStore:GetAsync(tostring(userId))
	end)
	if success and result then
		State.playerData[userId] = result
	else
		if not success then
			warn("[GameManager] Failed to load data for", player.Name, ":", result)
		end
		State.playerData[userId] = defaultData()
	end
end

local function savePlayerData(player)
	local userId = player.UserId
	local data   = State.playerData[userId]
	if not data then return end
	local success, err = pcall(function()
		gameDataStore:SetAsync(tostring(userId), data)
	end)
	if not success then
		warn("[GameManager] Failed to save data for", player.Name, ":", err)
	end
end

-- ── Terrain generation ───────────────────────────────────────────────────────
-- Procedurally fills terrain chunks using Workspace.Terrain:FillBlock
local CHUNK_SIZE  = WorldConfig.ChunkSize  or 128
local CHUNK_COUNT = WorldConfig.ChunkCount or 9   -- 3x3 grid of chunks

local function generateTerrainChunk(chunkX, chunkZ)
	local chunkKey = chunkX .. "_" .. chunkZ
	if State.generatedChunks[chunkKey] then return end  -- already generated
	State.generatedChunks[chunkKey] = true

	local terrain = Workspace.Terrain
	local baseY   = WorldConfig.TerrainBaseY or 0
	local size    = Vector3.new(CHUNK_SIZE, 4, CHUNK_SIZE)
	local origin  = CFrame.new(
		chunkX * CHUNK_SIZE,
		baseY,
		chunkZ * CHUNK_SIZE
	)

	-- Fill ground layer with Grass material
	terrain:FillBlock(origin, size, Enum.Material.Grass)

	-- Notify clients a new chunk was generated
	evTerrainGeneration:FireAllClients({ chunkX = chunkX, chunkZ = chunkZ, size = CHUNK_SIZE })
end

local function generateWorld()
	local half = math.floor(math.sqrt(CHUNK_COUNT) / 2)
	for cx = -half, half do
		for cz = -half, half do
			generateTerrainChunk(cx, cz)
		end
	end
end

-- ── Suburb generation ────────────────────────────────────────────────────────
-- Places suburb building pads inside designated suburb zones from WorldConfig
local function buildStarterSuburbs()
	State.suburbRegions = {}
	local zones = WorldConfig.SuburbZones or {}

	for i, zone in ipairs(zones) do
		-- Place a flat concrete base for each suburb lot
		local lotSize = Vector3.new(zone.width or 20, 2, zone.depth or 20)
		local origin  = CFrame.new(zone.position or Vector3.new(0, 1, 0))
		Workspace.Terrain:FillBlock(origin, lotSize, Enum.Material.Concrete)

		-- Optionally spawn a building model if configured
		local buildingModel = WorldConfig.SuburbBuilding
		if buildingModel then
			local clone = buildingModel:Clone()
			clone:PivotTo(origin * CFrame.new(0, lotSize.Y / 2, 0))
			clone.Parent = Workspace
		end

		table.insert(State.suburbRegions, {
			id       = i,
			position = zone.position or Vector3.new(0, 0, 0),
			name     = zone.name or ("Suburb_" .. i),
		})
	end

	-- Broadcast suburb data to all clients
	evStarterSuburbs:FireAllClients(State.suburbRegions)
end

-- ── Road network generation ──────────────────────────────────────────────────
-- Creates road nodes along a grid and marks them with invisible Parts
local ROAD_WIDTH  = WorldConfig.RoadWidth  or 8
local ROAD_GRID   = WorldConfig.RoadGrid   or 4   -- intersections per side

local function buildRoadNetwork()
	State.roadNodes = {}
	local spacing = CHUNK_SIZE / ROAD_GRID
	local roadFolder = Workspace:FindFirstChild("RoadNetwork")
	if not roadFolder then
		roadFolder = Instance.new("Folder")
		roadFolder.Name = "RoadNetwork"
		roadFolder.Parent = Workspace
	end

	for i = 0, ROAD_GRID do
		for j = 0, ROAD_GRID do
			local worldX = (i - ROAD_GRID / 2) * spacing
			local worldZ = (j - ROAD_GRID / 2) * spacing
			local nodePos = Vector3.new(worldX, (WorldConfig.TerrainBaseY or 0) + 2, worldZ)

			-- Lay a road segment using Terrain (smooth asphalt strip along X)
			Workspace.Terrain:FillBlock(
				CFrame.new(nodePos),
				Vector3.new(spacing, 0.5, ROAD_WIDTH),
				Enum.Material.SmoothPlastic
			)
			-- Lay perpendicular strip along Z
			Workspace.Terrain:FillBlock(
				CFrame.new(nodePos),
				Vector3.new(ROAD_WIDTH, 0.5, spacing),
				Enum.Material.SmoothPlastic
			)

			table.insert(State.roadNodes, nodePos)
		end
	end

	-- Send road node positions to clients for minimap / UI
	evRoadNetwork:FireAllClients(State.roadNodes)
end

-- ── Shortcuts ────────────────────────────────────────────────────────────────
-- Registers shortcut paths between non-adjacent road nodes
local function registerShortcuts()
	State.shortcutNodes = {}
	local shortcuts = WorldConfig.Shortcuts or {}

	for i, sc in ipairs(shortcuts) do
		local entry = {
			id      = i,
			label   = sc.label or ("Shortcut_" .. i),
			from    = sc.from,    -- Vector3
			to      = sc.to,      -- Vector3
			locked  = sc.locked ~= false,  -- default locked
		}
		table.insert(State.shortcutNodes, entry)

		-- Place a visible trigger Part at shortcut entry point
		local trigger = Instance.new("Part")
		trigger.Name        = "Shortcut_" .. i
		trigger.Size        = Vector3.new(6, 4, 6)
		trigger.CFrame      = CFrame.new(sc.from or Vector3.new(0, 2, 0))
		trigger.Anchored    = true
		trigger.CanCollide  = false
		trigger.Transparency = 0.6
		trigger.BrickColor  = BrickColor.new("Bright yellow")
		trigger.Parent      = Workspace

		-- Touched event: unlock shortcut for the touching player
		trigger.Touched:Connect(function(hit)
			local char = hit.Parent
			local player = Players:GetPlayerFromCharacter(char)
			if not player then return end

			local data = State.playerData[player.UserId]
			if not data then return end

			-- Check if player has already unlocked this shortcut
			local alreadyUnlocked = false
			for _, id in ipairs(data.shortcuts) do
				if id == i then alreadyUnlocked = true break end
			end

			if not alreadyUnlocked then
				table.insert(data.shortcuts, i)
				entry.locked = false
				-- Notify the touching player of their newly unlocked shortcut
				evShortcuts:FireClient(player, { action = "Unlocked", shortcut = entry })
			end
		end)
	end

	-- Broadcast all shortcut metadata to clients
	evShortcuts:FireAllClients({ action = "Register", shortcuts = State.shortcutNodes })
end

-- ── Spawn helper ─────────────────────────────────────────────────────────────
local function spawnAtDefaultArea(player)
	local areaName = WorldConfig.DefaultArea or "Suburbs"
	local spawnPos = WorldConfig.AreaSpawns and WorldConfig.AreaSpawns[areaName]
	if not spawnPos then
		spawnPos = Vector3.new(0, 10, 0)  -- absolute fallback
	end
	local char = player.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(spawnPos)
		end
	end
end

-- ── Player lifecycle ─────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	-- Load persisted data first
	loadPlayerData(player)

	player.CharacterAdded:Connect(function(char)
		-- Small delay ensures HumanoidRootPart is ready
		task.defer(function()
			spawnAtDefaultArea(player)
		end)

		-- Track deaths for road-rage scoring
		local humanoid = char:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			local data = State.playerData[player.UserId]
			if data then
				data.coins = math.max(0, (data.coins or 0) - 5)  -- penalty on death
			end
		end)
	end)

	-- Send current world state to the joining player
	evTerrainGeneration:FireClient(player, { chunks = State.generatedChunks })
	evStarterSuburbs:FireClient(player, State.suburbRegions)
	evRoadNetwork:FireClient(player, State.roadNodes)
	evShortcuts:FireClient(player, { action = "Register", shortcuts = State.shortcutNodes })
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
	State.playerData[player.UserId] = nil
end)

-- Save all online players when server closes
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player)
	end
end)

-- ── World initialisation ─────────────────────────────────────────────────────
local function initWorld()
	State.phase = "Generating"
	generateWorld()
	buildStarterSuburbs()
	buildRoadNetwork()
	registerShortcuts()
	State.phase = "Active"
	print("[GameManager] Route Rage world ready.")
end

task.spawn(initWorld)

-- ── Public API (module table) ─────────────────────────────────────────────────
local GameManager = {}

-- Returns a copy of the player's current data
function GameManager.GetPlayerData(player)
	return State.playerData[player.UserId]
end

-- Award coins to a player (e.g. completing a road segment)
function GameManager.AwardCoins(player, amount)
	local data = State.playerData[player.UserId]
	if not data then return end
	data.coins = (data.coins or 0) + amount
end

-- Forcefully unlock a shortcut for a player by shortcut id
function GameManager.UnlockShortcut(player, shortcutId)
	local data = State.playerData[player.UserId]
	if not data then return end
	for _, id in ipairs(data.shortcuts) do
		if id == shortcutId then return end  -- already unlocked
	end
	table.insert(data.shortcuts, shortcutId)
	local entry = State.shortcutNodes[shortcutId]
	if entry then
		evShortcuts:FireClient(player, { action = "Unlocked", shortcut = entry })
	end
end

-- Regenerates a specific terrain chunk (e.g. after destruction)
function GameManager.RegenerateChunk(chunkX, chunkZ)
	local key = chunkX .. "_" .. chunkZ
	State.generatedChunks[key] = nil  -- mark as needing regen
	generateTerrainChunk(chunkX, chunkZ)
end

-- Returns all current road node positions
function GameManager.GetRoadNodes()
	return State.roadNodes
end

-- Returns current game phase
function GameManager.GetPhase()
	return State.phase
end

return GameManager