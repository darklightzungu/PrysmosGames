local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- Services and remotes — own all RemoteEvents so clients can WaitForChild
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes        = Instance.new("Folder")
	remotes.Name   = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemote(name)
	local r = remotes:FindFirstChild(name)
	if r then return r end
	r        = Instance.new("RemoteEvent")
	r.Name   = name
	r.Parent = remotes
	return r
end

local throwItemRemote       = ensureRemote("ThrowItem")
local deliverySuccessRemote = ensureRemote("DeliverySuccess")
local updateKillsRemote     = ensureRemote("UpdateKills")
local updateComboRemote     = ensureRemote("UpdateCombo")
local pickupConfirmedRemote = ensureRemote("PickupConfirmed")

-- Item definitions
local ITEM_TYPES = {
	newspaper = { throwable = true,  range = 30, points = 10, label = "Newspaper" },
	flyer     = { throwable = true,  range = 20, points = 5,  label = "Flyer"     },
	package   = { throwable = false, range = 0,  points = 25, label = "Package"   },
}

-- Delivery target positions
local TARGET_POSITIONS = {
	Vector3.new(40, 2, 30),   Vector3.new(-40, 2, 30),
	Vector3.new(40, 2, -30),  Vector3.new(-40, 2, -30),
	Vector3.new(80, 2, 60),   Vector3.new(-80, 2, 60),
	Vector3.new(80, 2, -60),  Vector3.new(-80, 2, -60),
}

-- Per-player state
local playerInventory   = {}  -- [player] = itemType string or nil
local playerScores      = {}  -- [player] = number
local playerCombos      = {}  -- [player] = { count, lastTime }
local throwCooldowns    = {}  -- [player] = last throw tick

local COMBO_WINDOW      = 8   -- seconds between deliveries to maintain combo
local THROW_COOLDOWN    = 0.5 -- minimum seconds between throws
local MAX_THROW_SPEED   = 80

-- ============================================================
-- Helper: get combo multiplier
-- ============================================================
local function getComboMultiplier(count)
	if count >= 4 then return 3
	elseif count == 3 then return 2
	elseif count == 2 then return 1.5
	else return 1
	end
end

-- ============================================================
-- Helper: award points with combo
-- ============================================================
local function awardPoints(player, basePoints)
	if not playerScores[player] then playerScores[player] = 0 end
	if not playerCombos[player]  then playerCombos[player]  = { count = 0, lastTime = 0 } end

	local comboData   = playerCombos[player]
	local now         = tick()
	local elapsed     = now - comboData.lastTime

	-- Reset combo if timeout exceeded
	if elapsed > COMBO_WINDOW and comboData.count > 0 then
		comboData.count = 0
	end

	comboData.count    = comboData.count + 1
	comboData.lastTime = now

	local multiplier   = getComboMultiplier(comboData.count)
	local awarded      = math.floor(basePoints * multiplier)

	playerScores[player] = playerScores[player] + awarded

	-- Notify client of updated score delta and combo
	updateKillsRemote:FireClient(player, awarded)
	updateComboRemote:FireClient(player, comboData.count)

	return awarded
end

-- ============================================================
-- Helper: reset player combo (wrong delivery / crash)
-- ============================================================
local function resetCombo(player)
	if playerCombos[player] then
		playerCombos[player].count    = 0
		playerCombos[player].lastTime = 0
		updateComboRemote:FireClient(player, 0)
	end
end

-- ============================================================
-- Helper: flash a part green briefly
-- ============================================================
local function flashRed(part)
	local originalColor = part.BrickColor
	part.BrickColor = BrickColor.new("Bright red")
	task.delay(0.4, function()
		if part and part.Parent then
			part.BrickColor = originalColor
		end
	end)
end

-- ============================================================
-- Helper: play a delivery sound at a position
-- ============================================================
local function playDeliverySound(position)
	local soundPart = Instance.new("Part")
	soundPart.Anchored    = true
	soundPart.CanCollide  = false
	soundPart.Transparency = 1
	soundPart.Size        = Vector3.new(1, 1, 1)
	soundPart.Position    = position
	soundPart.Parent      = workspace

	local sound = Instance.new("Sound")
	sound.SoundId   = "rbxassetid://4612375922" -- generic pickup chime
	sound.Volume    = 1
	sound.Parent    = soundPart
	sound:Play()

	Debris:AddItem(soundPart, 3)
end

-- ============================================================
-- Build DEPOT
-- ============================================================
local depotFolder = Instance.new("Folder")
depotFolder.Name  = "Depot"
depotFolder.Parent = workspace

local depotPart       = Instance.new("Part")
depotPart.Name        = "DepotPart"
depotPart.Size        = Vector3.new(6, 3, 6)
depotPart.BrickColor  = BrickColor.new("Bright yellow")
depotPart.Anchored    = true
depotPart.Position    = Vector3.new(0, 2, -10)
depotPart.Parent      = depotFolder

-- BillboardGui on depot
local depotBillboard        = Instance.new("BillboardGui")
depotBillboard.Size         = UDim2.new(0, 200, 0, 50)
depotBillboard.StudsOffset  = Vector3.new(0, 3, 0)
depotBillboard.AlwaysOnTop  = false
depotBillboard.Parent       = depotPart

local depotLabel            = Instance.new("TextLabel")
depotLabel.Size             = UDim2.new(1, 0, 1, 0)
depotLabel.BackgroundTransparency = 1
depotLabel.Text             = "DEPOT — Press E to reload"
depotLabel.TextColor3       = Color3.fromRGB(255, 255, 255)
depotLabel.TextScaled       = true
depotLabel.Font             = Enum.Font.GothamBold
depotLabel.Parent           = depotBillboard

-- ProximityPrompt on depot
local depotPrompt             = Instance.new("ProximityPrompt")
depotPrompt.ActionText        = "Reload"
depotPrompt.KeyboardKeyCode   = Enum.KeyCode.E
depotPrompt.MaxActivationDistance = 10
depotPrompt.Parent            = depotPart

-- Cycle through item types for each player pickup
local itemCycle = { "newspaper", "flyer", "package" }
local cycleIndex = 0

depotPrompt.Triggered:Connect(function(player)
	cycleIndex              = (cycleIndex % #itemCycle) + 1
	local assignedType      = itemCycle[cycleIndex]
	playerInventory[player] = assignedType
	pickupConfirmedRemote:FireClient(player, assignedType, 1)
end)

-- ============================================================
-- Build DELIVERY TARGETS
-- ============================================================
local targetsFolder   = Instance.new("Folder")
targetsFolder.Name    = "DeliveryTargets"
targetsFolder.Parent  = workspace

local targets = {}

for i, pos in ipairs(TARGET_POSITIONS) do
	local targetPart              = Instance.new("Part")
	targetPart.Name               = "DeliveryTarget_" .. i
	targetPart.Size               = Vector3.new(3, 4, 3)
	targetPart.BrickColor         = BrickColor.new("White")
	targetPart.Material           = Enum.Material.Neon
	targetPart.Anchored           = true
	targetPart.CanCollide         = false
	targetPart.Position           = pos
	targetPart.Parent             = targetsFolder

	CollectionService:AddTag(targetPart, "DeliveryTarget")

	-- BillboardGui on target
	local billboard               = Instance.new("BillboardGui")
	billboard.Size                = UDim2.new(0, 160, 0, 40)
	billboard.StudsOffset         = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop         = false
	billboard.Parent              = targetPart

	local label                   = Instance.new("TextLabel")
	label.Size                    = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency  = 1
	label.Text                    = "DELIVER HERE"
	label.TextColor3              = Color3.fromRGB(255, 255, 255)
	label.TextScaled              = true
	label.Font                    = Enum.Font.GothamBold
	label.Parent                  = billboard

	-- ProximityPrompt for package delivery
	local proximity               = Instance.new("ProximityPrompt")
	proximity.ActionText          = "Deliver Package"
	proximity.KeyboardKeyCode     = Enum.KeyCode.E
	proximity.MaxActivationDistance = 10
	proximity.Parent              = targetPart

	-- ClickDetector for throwable delivery fallback
	local clickDetector           = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 40
	clickDetector.Parent          = targetPart

	-- Package proximity delivery
	proximity.Triggered:Connect(function(player)
		local held = playerInventory[player]
		if held ~= "package" then return end

		playerInventory[player] = nil
		local awarded = awardPoints(player, ITEM_TYPES["package"].points)

		flashGreen(targetPart)
		playDeliverySound(pos)
		deliverySuccessRemote:FireClient(player, "package", awarded)
	end)

	-- ClickDetector delivery (throwable items at close range)
	clickDetector.MouseClick:Connect(function(player)
		local held = playerInventory[player]
		if not held then return end
		local itemDef = ITEM_TYPES[held]
		if not itemDef or not itemDef.throwable then return end

		-- Check player distance to target
		local character = player.Character
		if not character then return end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		local dist = (rootPart.Position - pos).Magnitude
		if dist > itemDef.range then return end

		playerInventory[player] = nil
		local awarded = awardPoints(player, itemDef.points)

		flashGreen(targetPart)
		playDeliverySound(pos)
		deliverySuccessRemote:FireClient(player, held, awarded)
	end)

	targets[#targets + 1] = targetPart
end

-- ============================================================
-- THROW MECHANIC
-- ============================================================
throwItemRemote.OnServerEvent:Connect(function(player, itemType, direction, speed)
	-- Validate item type
	local itemDef = ITEM_TYPES[itemType]
	if not itemDef or not itemDef.throwable then return end

	-- Validate player actually holds this item
	if playerInventory[player] ~= itemType then return end

	-- Rate limit
	local now      = tick()
	local lastThrow = throwCooldowns[player] or 0
	if now - lastThrow < THROW_COOLDOWN then return end
	throwCooldowns[player] = now

	-- Validate direction is a Vector3
	if typeof(direction) ~= "Vector3" then return end
	if typeof(speed) ~= "number"      then return end

	-- Clamp speed
	speed = math.clamp(speed, 0, MAX_THROW_SPEED)

	-- Normalise direction (client might send non-unit vector)
	local mag = direction.Magnitude
	if mag < 0.001 then return end
	direction = direction / mag

	-- Remove item from inventory now (thrown)
	playerInventory[player] = nil

	-- Get spawn position from character
	local character = player.Character
	if not character then return end
	local rootPart  = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local spawnPos  = rootPart.Position + Vector3.new(0, 1, 0)

	-- Create projectile
	local projectile              = Instance.new("Part")
	projectile.Name               = "DeliveryProjectile_" .. itemType
	projectile.Shape              = Enum.PartType.Ball
	projectile.Size               = Vector3.new(1, 1, 1)
	projectile.BrickColor         = BrickColor.new("Bright yellow")
	projectile.Anchored           = false
	projectile.CanCollide         = true
	projectile.Position           = spawnPos
	projectile.Parent             = workspace

	-- Store metadata on projectile
	projectile:SetAttribute("ItemType",   itemType)
	projectile:SetAttribute("ThrowerID",  player.UserId)
	projectile:SetAttribute("Points",     itemDef.points)

	-- Apply velocity
	local bv          = Instance.new("BodyVelocity")
	bv.Velocity       = direction * speed
	bv.MaxForce       = Vector3.new(1e5, 1e5, 1e5)
	bv.P              = 1e4
	bv.Parent         = projectile

	-- Auto-remove after 10 seconds
	Debris:AddItem(projectile, 10)

	local hit = false  -- prevent multi-hit

	-- Touch detection for delivery targets
	projectile.Touched:Connect(function(otherPart)
		if hit then return end
		if not CollectionService:HasTag(otherPart, "DeliveryTarget") then return end

		hit = true

		local throwerID = projectile:GetAttribute("ThrowerID")
		local basePoints = projectile:GetAttribute("Points")
		local thrownType = projectile:GetAttribute("ItemType")

		-- Find the player who threw it
		local thrower = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == throwerID then
				thrower = p
				break
			end
		end

		-- Remove projectile immediately
		projectile:Destroy()

		if not thrower then return end

		local awarded = awardPoints(thrower, basePoints)
		flashGreen(otherPart)
		playDeliverySound(otherPart.Position)
		deliverySuccessRemote:FireClient(thrower, thrownType, awarded)
	end)
end)

-- ============================================================
-- Player lifecycle
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	playerInventory[player] = nil
	playerScores[player]    = 0
	playerCombos[player]    = { count = 0, lastTime = 0 }
	throwCooldowns[player]  = 0

	-- Reset combo on character respawn (crash)
	player.CharacterAdded:Connect(function()
		resetCombo(player)
		playerInventory[player] = nil
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playerInventory[player]  = nil
	playerScores[player]     = nil
	playerCombos[player]     = nil
	throwCooldowns[player]   = nil
end)

-- ============================================================
-- Combo timeout ticker (checks every second)
-- ============================================================
task.spawn(function()
	while true do
		task.wait(1)
		local now = tick()
		for _, player in ipairs(Players:GetPlayers()) do
			local comboData = playerCombos[player]
			if comboData and comboData.count > 0 then
				if now - comboData.lastTime >= COMBO_WINDOW then
					resetCombo(player)
				end
			end
		end
	end
end)

print("[DeliverySystem] " .. #targets .. " delivery targets placed")