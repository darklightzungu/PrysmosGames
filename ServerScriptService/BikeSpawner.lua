local InsertService = game:GetService("InsertService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local BIKE_ASSET_IDS = {10416541346, 13585889916, 10603776262}

local SPAWN_POSITIONS = {
	Vector3.new(12, 3, 20), Vector3.new(-12, 3, 20),
	Vector3.new(12, 3, -20), Vector3.new(-12, 3, -20),
}

-- Ensure Remotes folder exists
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemoteEvent(name)
	local existing = remotes:FindFirstChild(name)
	if existing then return existing end
	local re = Instance.new("RemoteEvent")
	re.Name = name
	re.Parent = remotes
	return re
end

local mountedEvent   = ensureRemoteEvent("VehicleMounted")
local dismountedEvent = ensureRemoteEvent("VehicleDismounted")

-- Resolve parent folder in workspace
local parentFolder = workspace:FindFirstChild("StarterSuburbs") or workspace

-- Track which players are currently in a vehicle to prevent double-mount
local occupiedPlayers = {}

-- Attempt to load a bike model using the asset ID list
local function loadBikeModel()
	for _, assetId in ipairs(BIKE_ASSET_IDS) do
		local success, result = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if success and result then
			-- LoadAsset returns a Model containing the asset
			local model = result:FindFirstChildWhichIsA("Model")
			if model then
				model.Parent = nil
				result:Destroy()
				return model
			else
				-- Sometimes the root itself is usable
				result.Parent = nil
				return result
			end
		else
			warn("[BikeSpawner] Failed to load asset " .. assetId .. ": " .. tostring(result))
		end
	end
	return nil
end

-- Strip Sound objects and Animation instances (with AnimationId) loaded from the asset
local function sanitizeModel(model)
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("Sound") or desc:IsA("Animation") then
			desc:Destroy()
		end
	end
end

-- Weld a part to a primary part using a WeldConstraint
local function weldToPrimary(primaryPart, part)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = primaryPart
	weld.Part1 = part
	weld.Parent = primaryPart
end

-- Configure or find a VehicleSeat within the model
local function ensureVehicleSeat(model)
	local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
	if not seat then
		-- No VehicleSeat found; create one and weld to PrimaryPart
		seat = Instance.new("VehicleSeat")
		seat.Name = "VehicleSeat"
		seat.Size = Vector3.new(2, 0.5, 4)
		seat.BrickColor = BrickColor.new("Dark grey")
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.BottomSurface = Enum.SurfaceType.Smooth

		local primary = model.PrimaryPart
		if not primary then
			-- Assign first BasePart as primary if unset
			for _, desc in ipairs(model:GetDescendants()) do
				if desc:IsA("BasePart") then
					model.PrimaryPart = desc
					primary = desc
					break
				end
			end
		end

		if primary then
			seat.CFrame = primary.CFrame * CFrame.new(0, 1, 0)
			seat.Parent = model
			weldToPrimary(primary, seat)
		else
			seat.Parent = model
		end
	end

	seat.MaxSpeed  = 60
	seat.Torque    = 8
	seat.TurnSpeed = 1.2
	return seat
end

-- Add a ProximityPrompt to the VehicleSeat
local function addProximityPrompt(seat)
	-- Remove existing prompt if any to avoid duplicates
	local existing = seat:FindFirstChildWhichIsA("ProximityPrompt")
	if existing then existing:Destroy() end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText           = "Ride"
	prompt.ObjectText           = "Bike"
	prompt.KeyboardKeyCode      = Enum.KeyCode.E
	prompt.MaxActivationDistance = 8
	prompt.Parent               = seat
	return prompt
end

-- Place model at spawn position, grounding it so it sits on the surface
local function placeModel(model, position)
	-- Compute bounding box to offset model upward so it sits on ground
	local cf, size = model:GetBoundingBox()
	local halfHeight = size.Y / 2
	local targetCFrame = CFrame.new(position) * CFrame.new(0, halfHeight - (cf.Position.Y - model:GetPivot().Position.Y), 0)
	model:PivotTo(targetCFrame)
end

-- Respawn a bike at its original position after a delay
local function scheduleRespawn(bikeData)
	task.delay(5, function()
		if bikeData.model and bikeData.model.Parent then
			-- Check if still fallen
			local primaryPart = bikeData.model.PrimaryPart
			if primaryPart and primaryPart.Position.Y < -50 then
				placeModel(bikeData.model, bikeData.spawnPosition)
				-- Re-anchor briefly then release to reset physics
				for _, part in ipairs(bikeData.model:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Velocity        = Vector3.zero
						part.RotVelocity     = Vector3.zero
					end
				end
			end
		end
	end)
end

-- Monitor a bike for falling below the world
local function startFallMonitor(bikeData)
	task.spawn(function()
		while bikeData.model and bikeData.model.Parent do
			task.wait(2)
			local primaryPart = bikeData.model.PrimaryPart
			if primaryPart and primaryPart.Position.Y < -50 then
				scheduleRespawn(bikeData)
				task.wait(6) -- Avoid repeated triggers during respawn delay
			end
		end
	end)
end

-- Mount handler: triggered when a player interacts with the ProximityPrompt
local function onPromptTriggered(player, bikeModel, seat)
	if occupiedPlayers[player] then
		return -- Player already in a vehicle
	end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then return end

	-- Sit humanoid in the VehicleSeat
	seat:Sit(humanoid)
	occupiedPlayers[player] = true

	-- Notify client
	mountedEvent:FireClient(player, bikeModel)

	-- Watch for dismount (occupant becomes nil)
	local connection
	connection = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant == nil then
			occupiedPlayers[player] = nil
			dismountedEvent:FireClient(player, bikeModel)
			if connection then
				connection:Disconnect()
			end
		end
	end)
end

-- Spawn a bike at a given position and set up all behaviour
local function spawnBike(position)
	local model = loadBikeModel()
	if not model then
		warn("[BikeSpawner] Could not load any bike model for position " .. tostring(position))
		return nil
	end

	sanitizeModel(model)

	-- Ensure model has a PrimaryPart before parenting
	if not model.PrimaryPart then
		for _, desc in ipairs(model:GetDescendants()) do
			if desc:IsA("BasePart") then
				model.PrimaryPart = desc
				break
			end
		end
	end

	model.Name   = "Bike"
	model.Parent = parentFolder

	placeModel(model, position)

	local seat   = ensureVehicleSeat(model)
	local prompt = addProximityPrompt(seat)

	-- Apply CollectionService tags
	CollectionService:AddTag(model, "Bike")
	CollectionService:AddTag(model, "Vehicle")

	local bikeData = {
		model         = model,
		spawnPosition = position,
		seat          = seat,
	}

	-- Connect proximity prompt
	prompt.Triggered:Connect(function(player)
		onPromptTriggered(player, model, seat)
	end)

	-- Clean up occupiedPlayers if player leaves while mounted
	Players.PlayerRemoving:Connect(function(player)
		if occupiedPlayers[player] then
			occupiedPlayers[player] = nil
		end
	end)

	startFallMonitor(bikeData)

	return model
end

-- Main: spawn a bike at every defined position
local count = 0
for _, pos in ipairs(SPAWN_POSITIONS) do
	local bike = spawnBike(pos)
	if bike then
		count = count + 1
	end
end

print("[BikeSpawner] Spawned " .. count .. " bikes")