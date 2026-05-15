local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

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
local reBikeSpawner       = getOrCreate("BikeSpawner",       "RemoteEvent")
local reVehicleMount      = getOrCreate("VehicleMount",      "RemoteEvent")
local reDeliverySystem    = getOrCreate("DeliverySystem",    "RemoteEvent")
local reThrowMechanic     = getOrCreate("ThrowMechanic",     "RemoteEvent")
local reProximityDelivery = getOrCreate("ProximityDelivery", "RemoteEvent")
local reMobileControls    = getOrCreate("MobileControls",    "RemoteEvent")
local reComboScoring      = getOrCreate("ComboScoring",      "RemoteEvent")
local reDeviceDetection   = getOrCreate("DeviceDetection",   "RemoteEvent")
local reHudUpdate         = getOrCreate("HudUpdate",         "RemoteEvent")

-- ── Default player data template ─────────────────────────────────────────────
local function defaultData()
	return {
		totalDeliveries = 0,
		totalScore      = 0,
		highestCombo    = 0,
		coins           = 0,
		bikeSkin        = "Default",
	}
end

-- ── Game State ────────────────────────────────────────────────────────────────
local playerData   = {}   -- [userId] = data table
local playerStates = {}   -- [userId] = runtime state (bike, cargo, combo, etc.)

local DELIVERY_RADIUS     = 10   -- studs for proximity delivery
local COMBO_RESET_TIME    = 8    -- seconds before combo resets
local BIKE_RESPAWN_DELAY  = 5    -- seconds before a new bike can be spawned
local MAX_COMBO           = 20   -- cap combo multiplier display
local DELIVERY_BASE_SCORE = 100  -- base points per delivery

-- ── Spawn helpers ─────────────────────────────────────────────────────────────
local function getDefaultSpawn()
	-- WorldConfig.DefaultArea should expose a SpawnPoints list
	local area = WorldConfig.DefaultArea
	if area and area.SpawnPoints and #area.SpawnPoints > 0 then
		return area.SpawnPoints[math.random(#area.SpawnPoints)]
	end
	return Vector3.new(0, 5, 0)
end

local function spawnPlayerAtDefault(player)
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(getDefaultSpawn())
	end
end

-- ── Data persistence ──────────────────────────────────────────────────────────
local function loadData(player)
	local uid = player.UserId
	local success, result = pcall(function()
		return gameDataStore:GetAsync("player_" .. uid)
	end)
	if success and result then
		-- Merge saved data onto default to handle missing keys from updates
		local data = defaultData()
		for k, v in pairs(result) do
			data[k] = v
		end
		playerData[uid] = data
	else
		if not success then
			warn("[GameManager] Failed to load data for", player.Name, ":", result)
		end
		playerData[uid] = defaultData()
	end
end

local function saveData(player)
	local uid = player.UserId
	local data = playerData[uid]
	if not data then return end
	local success, err = pcall(function()
		gameDataStore:SetAsync("player_" .. uid, data)
	end)
	if not success then
		warn("[GameManager] Failed to save data for", player.Name, ":", err)
	end
end

-- ── Runtime state helpers ─────────────────────────────────────────────────────
local function initPlayerState(player)
	playerStates[player.UserId] = {
		bike             = nil,       -- current bike model reference
		hasCargo         = false,     -- carrying a delivery package
		cargoDestination = nil,       -- current delivery target (Part)
		combo            = 0,         -- current combo count
		comboTimer       = 0,         -- last delivery timestamp for combo window
		isMobile         = false,     -- detected device type
		lastBikeSpawn    = -math.huge, -- tick() of last bike spawn
		mountedSeat      = nil,       -- VehicleSeat reference
	}
end

local function getState(player)
	return playerStates[player.UserId]
end

-- ── Device Detection ──────────────────────────────────────────────────────────
-- Client fires back after detecting; server stores it for logic branching
reDeviceDetection.OnServerEvent:Connect(function(player, isMobile)
	local st = getState(player)
	if st then
		st.isMobile = isMobile == true
		-- Optionally send mobile UI activation back to client
		if st.isMobile then
			reMobileControls:FireClient(player, "ShowMobileUI", true)
		end
	end
end)

-- ── Bike Spawner ──────────────────────────────────────────────────────────────
local function spawnBikeForPlayer(player)
	local st = getState(player)
	if not st then return end

	local now = tick()
	if now - st.lastBikeSpawn < BIKE_RESPAWN_DELAY then
		local remaining = math.ceil(BIKE_RESPAWN_DELAY - (now - st.lastBikeSpawn))
		reBikeSpawner:FireClient(player, "Cooldown", remaining)
		return
	end

	-- Remove old bike if it exists and is still in workspace
	if st.bike and st.bike.Parent then
		st.bike:Destroy()
		st.bike = nil
	end

	-- Attempt to clone a bike template from WorldConfig or workspace
	local bikeTemplate = WorldConfig.BikeTemplate
		or ReplicatedStorage:FindFirstChild("BikeModel")
		or workspace:FindFirstChild("BikeModel")

	if not bikeTemplate then
		warn("[GameManager] No BikeModel found for spawning.")
		return
	end

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local bike = bikeTemplate:Clone()
	-- Position bike slightly in front of the player
	bike:SetPrimaryPartCFrame(root.CFrame * CFrame.new(0, 0, -5))
	bike.Name = "Bike_" .. player.UserId
	CollectionService:AddTag(bike, "PlayerBike")
	bike.Parent = workspace

	st.bike = bike
	st.lastBikeSpawn = now

	reBikeSpawner:FireClient(player, "Spawned", bike)
end

reBikeSpawner.OnServerEvent:Connect(function(player, action)
	if action == "RequestSpawn" then
		spawnBikeForPlayer(player)
	elseif action == "Despawn" then
		local st = getState(player)
		if st and st.bike and st.bike.Parent then
			st.bike:Destroy()
			st.bike = nil
		end
	end
end)

-- ── Vehicle Mount ─────────────────────────────────────────────────────────────
local function mountPlayerToBike(player)
	local st = getState(player)
	if not st or not st.bike then
		reVehicleMount:FireClient(player, "NoVehicle")
		return
	end

	local seat = st.bike:FindFirstChildOfClass("VehicleSeat")
		or st.bike:FindFirstChild("DriveSeat")
	if not seat then
		warn("[GameManager] Bike has no VehicleSeat for", player.Name)
		return
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	seat:Sit(hum)
	st.mountedSeat = seat
	reVehicleMount:FireClient(player, "Mounted", seat)
end

local function unmountPlayer(player)
	local st = getState(player)
	if not st then return end
	st.mountedSeat = nil
	reVehicleMount:FireClient(player, "Dismounted")
end

reVehicleMount.OnServerEvent:Connect(function(player, action)
	if action == "Mount" then
		mountPlayerToBike(player)
	elseif action == "Dismount" then
		unmountPlayer(player)
	end
end)

-- ── Delivery System ───────────────────────────────────────────────────────────
local deliveryDestinations = {} -- list of active delivery Parts in workspace

local function refreshDeliveryDestinations()
	deliveryDestinations = {}
	-- Tag delivery zones in workspace with "DeliveryZone" CollectionService tag
	for _, part in ipairs(CollectionService:GetTagged("DeliveryZone")) do
		table.insert(deliveryDestinations, part)
	end
	-- Fallback: use WorldConfig delivery zones if defined
	if #deliveryDestinations == 0 and WorldConfig.DeliveryZones then
		for _, z in ipairs(WorldConfig.DeliveryZones) do
			if typeof(z) == "Instance" then
				table.insert(deliveryDestinations, z)
			end
		end
	end
end

local function assignDelivery(player)
	refreshDeliveryDestinations()
	if #deliveryDestinations == 0 then
		reDeliverySystem:FireClient(player, "NoZonesAvailable")
		return
	end

	local st = getState(player)
	if not st then return end

	-- Pick a random destination
	local dest = deliveryDestinations[math.random(#deliveryDestinations)]
	st.hasCargo         = true
	st.cargoDestination = dest

	reDeliverySystem:FireClient(player, "PickedUp", dest.Position)
end

reDeliverySystem.OnServerEvent:Connect(function(player, action)
	if action == "PickupCargo" then
		local st = getState(player)
		if st and not st.hasCargo then
			assignDelivery(player)
		else
			reDeliverySystem:FireClient(player, "AlreadyCarrying")
		end
	elseif action == "DropCargo" then
		local st = getState(player)
		if st then
			st.hasCargo = false
			st.cargoDestination = nil
			-- Dropping resets combo
			st.combo = 0
			reDeliverySystem:FireClient(player, "Dropped")
			reComboScoring:FireClient(player, "ComboReset", 0)
		end
	end
end)

-- ── Throw Mechanic ────────────────────────────────────────────────────────────
-- Player can throw their cargo to a nearby delivery zone
reThrowMechanic.OnServerEvent:Connect(function(player, action, throwVector)
	if action == "Throw" then
		local st = getState(player)
		if not st or not st.hasCargo then
			reThrowMechanic:FireClient(player, "NoCargo")
			return
		end

		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then return end

		-- Spawn a throwable part representing the package
		local pkg = Instance.new("Part")
		pkg.Name    = "Package_" .. player.UserId
		pkg.Size    = Vector3.new(1.5, 1.5, 1.5)
		pkg.BrickColor = BrickColor.new("Bright yellow")
		pkg.CFrame  = root.CFrame * CFrame.new(0, 1, -2)
		pkg.Parent  = workspace

		-- Apply throw velocity
		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bv.Velocity = (typeof(throwVector) == "Vector3" and throwVector or root.CFrame.LookVector * 40 + Vector3.new(0, 15, 0))
		bv.Parent   = pkg

		-- Tag package for proximity detection
		CollectionService:AddTag(pkg, "ThrownPackage")
		pkg:SetAttribute("OwnerId", player.UserId)

		st.hasCargo = false
		st.cargoDestination = nil
		reThrowMechanic:FireClient(player, "Thrown", pkg)

		-- Remove velocity after brief flight, then check landing
		task.delay(0.3, function()
			if pkg and pkg.Parent then
				bv:Destroy()
			end
		end)

		-- Auto-remove package after 10 seconds if not delivered
		task.delay(10, function()
			if pkg and pkg.Parent then
				pkg:Destroy()
			end
		end)
	end
end)

-- ── Combo Scoring ─────────────────────────────────────────────────────────────
local function awardDeliveryScore(player, isThrow)
	local st = getState(player)
	local data = playerData[player.UserId]
	if not st or not data then return end

	local now = tick()
	-- Check if within combo window
	if now - st.comboTimer <= COMBO_RESET_TIME then
		st.combo = math.min(st.combo + 1, MAX_COMBO)
	else
		st.combo = 1
	end
	st.comboTimer = now

	local multiplier = st.combo
	local bonus      = isThrow and 1.5 or 1   -- throw deliveries score bonus
	local score      = math.floor(DELIVERY_BASE_SCORE * multiplier * bonus)

	data.totalScore      = data.totalScore + score
	data.totalDeliveries = data.totalDeliveries + 1
	data.coins           = data.coins + math.floor(score / 10)

	if st.combo > data.highestCombo then
		data.highestCombo = st.combo
	end

	reComboScoring:FireClient(player, "ComboUpdate", st.combo, score)
	reHudUpdate:FireClient(player, {
		score      = data.totalScore,
		deliveries = data.totalDeliveries,
		combo      = st.combo,
		coins      = data.coins,
	})
end

-- ── Proximity Delivery ────────────────────────────────────────────────────────
-- Poll: check if player with cargo is near their destination each heartbeat tick
local proximityThrottle = 0
RunService.Heartbeat:Connect(function(dt)
	proximityThrottle = proximityThrottle + dt
	if proximityThrottle < 0.5 then return end  -- check every 0.5s to reduce load
	proximityThrottle = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local st = getState(player)
		if not st or not st.hasCargo or not st.cargoDestination then continue end

		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		local dest = st.cargoDestination
		if not dest or not dest.Parent then
			-- Destination removed; reset
			st.hasCargo = false
			st.cargoDestination = nil
			continue
		end

		local dist = (root.Position - dest.Position).Magnitude
		if dist <= DELIVERY_RADIUS then
			-- Successful proximity delivery
			st.hasCargo = false
			st.cargoDestination = nil
			reProximityDelivery:FireClient(player, "Delivered", dest.Position)
			awardDeliveryScore(player, false)
		end
	end

	-- Check thrown packages proximity to delivery zones
	for _, pkg in ipairs(CollectionService:GetTagged("ThrownPackage")) do
		if not pkg.Parent then continue end
		local ownerId = pkg:GetAttribute("OwnerId")
		local owner   = Players:GetPlayerByUserId(ownerId)

		for _, zone in ipairs(deliveryDestinations) do
			if not zone.Parent then continue end
			local dist = (pkg.Position - zone.Position).Magnitude
			if dist <= DELIVERY_RADIUS then
				pkg:Destroy()
				if owner then
					local st = getState(owner)
					if st then
						reProximityDelivery:FireClient(owner, "ThrowDelivered", zone.Position)
						awardDeliveryScore(owner, true)
					end
				end
				break
			end
		end
	end
end)

-- ── Mobile Controls ───────────────────────────────────────────────────────────
-- Client fires mobile button presses; server translates to game actions
reMobileControls.OnServerEvent:Connect(function(player, action, ...)
	if action == "SpawnBike" then
		spawnBikeForPlayer(player)
	elseif action == "Mount" then
		mountPlayerToBike(player)
	elseif action == "Dismount" then
		unmountPlayer(player)
	elseif action == "Pickup" then
		local st = getState(player)
		if st and not st.hasCargo then
			assignDelivery(player)
		end
	elseif action == "Throw" then
		local throwVec = ...
		reThrowMechanic:FireServer(player, "Throw", throwVec)  -- re-route to throw handler
		-- Direct handling:
		local st = getState(player)
		if st and st.hasCargo then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				local pkg = Instance.new("Part")
				pkg.Name    = "Package_" .. player.UserId
				pkg.Size    = Vector3.new(1.5, 1.5, 1.5)
				pkg.BrickColor = BrickColor.new("Bright yellow")
				pkg.CFrame  = root.CFrame * CFrame.new(0, 1, -2)
				pkg.Parent  = workspace
				local bv = Instance.new("BodyVelocity")
				bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
				bv.Velocity = root.CFrame.LookVector * 40 + Vector3.new(0, 15, 0)
				bv.Parent   = pkg
				CollectionService:AddTag(pkg, "ThrownPackage")
				pkg:SetAttribute("OwnerId", player.UserId)
				st.hasCargo = false
				st.cargoDestination = nil
				reThrowMechanic:FireClient(player, "Thrown", pkg)
				task.delay(0.3, function() if pkg and pkg.Parent then bv:Destroy() end end)
				task.delay(10,  function() if pkg and pkg.Parent then pkg:Destroy() end end)
			end
		end
	end
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	loadData(player)
	initPlayerState(player)

	player.CharacterAdded:Connect(function(char)
		-- Small delay so character fully loads before teleporting
		task.wait(0.1)
		spawnPlayerAtDefault(player)

		-- Detect device: fire to client, client responds via DeviceDetection remote
		reDeviceDetection:FireClient(player, "DetectDevice")

		-- Push initial HUD data
		local data = playerData[player.UserId]
		if data then
			reHudUpdate:FireClient(player, {
				score      = data.totalScore,
				deliveries = data.totalDeliveries,
				combo      = 0,
				coins      = data.coins,
			})
		end

		-- Track Humanoid death for respawn
		local humanoid = char:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			-- Drop cargo on death
			local st = getState(player)
			if st then
				st.hasCargo = false
				st.cargoDestination = nil
				st.combo = 0
				st.mountedSeat = nil
				reComboScoring:FireClient(player, "ComboReset", 0)
			end
			task.delay(3, function()
				if player and player.Parent then
					player:LoadCharacter()
				end
			end)
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	-- Clean up bike
	local st = getState(player)
	if st and st.bike and st.bike.Parent then
		st.bike:Destroy()
	end
	playerStates[player.UserId] = nil
	playerData[player.UserId]   = nil
end)

-- Save all player data on server close
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)

-- ── Public API (GameManager module table) ────────────────────────────────────
local GameManager = {}

function GameManager.GetPlayerData(player)
	return playerData[player.UserId]
end

function GameManager.GetPlayerState(player)
	return playerStates[player.UserId]
end

function GameManager.SpawnBike(player)
	spawnBikeForPlayer(player)
end

function GameManager.MountPlayer(player)
	mountPlayerToBike(player)
end

function GameManager.UnmountPlayer(player)
	unmountPlayer(player)
end

function GameManager.AssignDelivery(player)
	assignDelivery(player)
end

function GameManager.AwardScore(player, isThrow)
	awardDeliveryScore(player, isThrow)
end

function GameManager.GetLeaderboard()
	local list = {}
	for uid, data in pairs(playerData) do
		local player = Players:GetPlayerByUserId(uid)
		table.insert(list, {
			name        = player and player.Name or tostring(uid),
			totalScore  = data.totalScore,
			deliveries  = data.totalDeliveries,
			highestCombo= data.highestCombo,
		})
	end
	table.sort(list, function(a, b) return a.totalScore > b.totalScore end)
	return list
end

function GameManager.AddCoins(player, amount)
	local data = playerData[player.UserId]
	if data then
		data.coins = data.coins + amount
		reHudUpdate:FireClient(player, { coins = data.coins })
	end
end

return GameManager