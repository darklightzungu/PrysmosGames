local InsertService     = game:GetService("InsertService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local BIKE_ASSET_ID = 10416886834

local SPAWN_POSITIONS = {
	Vector3.new( 12, 4,  20),
	Vector3.new(-12, 4,  20),
	Vector3.new( 12, 4, -20),
	Vector3.new(-12, 4, -20),
}

-- Ensure Remotes folder exists
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name   = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemoteEvent(name)
	local existing = remotes:FindFirstChild(name)
	if existing then return existing end
	local re = Instance.new("RemoteEvent")
	re.Name   = name
	re.Parent = remotes
	return re
end

local mountedEvent    = ensureRemoteEvent("VehicleMounted")
local dismountedEvent = ensureRemoteEvent("VehicleDismounted")

local parentFolder    = workspace:FindFirstChild("StarterSuburbs") or workspace
local occupiedPlayers = {}

local function spawnBike(spawnPos)
	local success, result = pcall(function()
		return InsertService:LoadAsset(BIKE_ASSET_ID)
	end)
	if not success or not result then
		warn("[BikeSpawner] LoadAsset failed: " .. tostring(result))
		return nil
	end

	-- LoadAsset wraps the asset in a container Model; unwrap it
	local model = result:FindFirstChildWhichIsA("Model") or result
	if model ~= result then
		model.Parent = nil
		result:Destroy()
	end

	-- Ensure PrimaryPart is set so PivotTo and SetPrimaryPartCFrame work
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
	model:PivotTo(CFrame.new(spawnPos))

	CollectionService:AddTag(model, "Bike")
	CollectionService:AddTag(model, "Vehicle")

	-- Add ProximityPrompt only if the loaded model has none
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		local seat        = model:FindFirstChildWhichIsA("VehicleSeat", true)
		local promptHost  = seat or model.PrimaryPart or model
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText            = "Ride"
		prompt.ObjectText            = "Bike"
		prompt.KeyboardKeyCode       = Enum.KeyCode.E
		prompt.MaxActivationDistance = 8
		prompt.Parent                = promptHost
	end

	-- Wire prompt to seat player without altering any seat properties
	prompt.Triggered:Connect(function(player)
		if occupiedPlayers[player] then return end
		local character = player.Character
		if not character then return end
		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		if not humanoid then return end
		local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
		if not seat then return end
		seat:Sit(humanoid)
		occupiedPlayers[player] = true
		mountedEvent:FireClient(player, model)
		local conn
		conn = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if seat.Occupant == nil then
				occupiedPlayers[player] = nil
				dismountedEvent:FireClient(player, model)
				conn:Disconnect()
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		occupiedPlayers[player] = nil
	end)

	-- Stuck detection: if bike has fallen below Y=0 within 3s, return it to spawn
	task.delay(3, function()
		if model and model.PrimaryPart and
		   model.PrimaryPart.Position.Y < 0 then
			model:SetPrimaryPartCFrame(CFrame.new(spawnPos))
		end
	end)

	return model
end

local count = 0
for _, pos in ipairs(SPAWN_POSITIONS) do
	local bike = spawnBike(pos)
	if bike then
		count = count + 1
	end
end

print("[BikeSpawner] Spawned " .. count .. " bikes — asset 10416886834")
