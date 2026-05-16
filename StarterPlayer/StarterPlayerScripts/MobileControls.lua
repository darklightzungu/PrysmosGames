local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = workspace.CurrentCamera

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Remote references
local remotes               = ReplicatedStorage:WaitForChild("Remotes")
local pickupItemRemote      = remotes:WaitForChild("PickupItem")
local throwItemRemote       = remotes:WaitForChild("ThrowItem")
local pickupConfirmedRemote = remotes:WaitForChild("PickupConfirmed")
local deliverySuccessRemote = remotes:WaitForChild("DeliverySuccess")

-- Held item state
local heldItemName  = nil
local heldItemCount = 0
local heldItemType  = nil   -- server-recognised key: "newspaper" | "flyer" | "package"

local THROW_SPEED = 60

-- Compute throw direction based on offset string relative to camera
local function getThrowDirection(offset)
	local cf = camera.CFrame
	if offset == "left" then
		return (-cf.RightVector + cf.LookVector * 0.5).Unit
	end
	if offset == "right" then
		return (cf.RightVector + cf.LookVector * 0.5).Unit
	end
	return cf.LookVector
end

local function isHoldingItem()
	return heldItemName ~= nil and heldItemCount > 0
end

------------------------------------------------------------------------
-- ITEM INDICATOR (all devices)
------------------------------------------------------------------------
local indicatorGui = Instance.new("ScreenGui")
indicatorGui.Name            = "ItemIndicatorGui"
indicatorGui.ResetOnSpawn    = false
indicatorGui.DisplayOrder    = 10
indicatorGui.IgnoreGuiInset  = false
indicatorGui.Parent          = playerGui

local indicatorLabel = Instance.new("TextLabel")
indicatorLabel.Name                   = "ItemIndicator"
indicatorLabel.Size                   = UDim2.new(0, 220, 0, 36)
indicatorLabel.Position               = UDim2.new(0, 12, 0, 12)
indicatorLabel.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
indicatorLabel.BackgroundTransparency = 0.35
indicatorLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
indicatorLabel.Font                   = Enum.Font.GothamBold
indicatorLabel.TextSize               = 13
indicatorLabel.Text                   = "No items — visit DEPOT"
indicatorLabel.TextXAlignment         = Enum.TextXAlignment.Left
indicatorLabel.TextTruncate           = Enum.TextTruncate.AtEnd
indicatorLabel.BorderSizePixel        = 0
indicatorLabel.Parent                 = indicatorGui

local indicatorCorner = Instance.new("UICorner")
indicatorCorner.CornerRadius = UDim.new(0, 8)
indicatorCorner.Parent       = indicatorLabel

local indicatorPadding = Instance.new("UIPadding")
indicatorPadding.PaddingLeft = UDim.new(0, 10)
indicatorPadding.Parent      = indicatorLabel

local function updateIndicator()
	if heldItemName and heldItemCount > 0 then
		indicatorLabel.Text = heldItemName .. " x" .. heldItemCount
	else
		indicatorLabel.Text = "No items — visit DEPOT"
	end
end

-- Server fires PickupConfirmed when player picks up from depot
pickupConfirmedRemote.OnClientEvent:Connect(function(itemName, count)
	heldItemName  = itemName
	heldItemCount = count or 1
	heldItemType  = itemName:lower()   -- "Newspaper" → "newspaper"
	updateIndicator()
end)

-- Server fires DeliverySuccess on successful delivery (clears held item)
deliverySuccessRemote.OnClientEvent:Connect(function(eventType)
	-- "pickup" events come through DeliverySuccess for legacy reasons;
	-- only clear item on actual delivery events
	if eventType ~= "pickup" then
		heldItemName  = nil
		heldItemCount = 0
		heldItemType  = nil
		updateIndicator()
	end
end)

------------------------------------------------------------------------
-- ARC PREVIEW — 8 yellow neon dots along parabolic throw trajectory
------------------------------------------------------------------------
local ARC_DOTS  = 8
local THROW_UP  = 15
local GRAVITY   = -196.2

local arcDots = {}
for i = 1, ARC_DOTS do
	local dot           = Instance.new("Part")
	dot.Shape           = Enum.PartType.Ball
	dot.Size            = Vector3.new(0.25, 0.25, 0.25)
	dot.Color           = Color3.fromRGB(255, 200, 0)
	dot.Material        = Enum.Material.Neon
	dot.Anchored        = true
	dot.CanCollide      = false
	dot.CastShadow      = false
	dot.Transparency    = 1   -- hidden by default
	dot.Parent          = workspace
	arcDots[i]          = dot
end

local function setArcVisible(visible)
	local transparency = visible and 0.3 or 1
	for _, d in ipairs(arcDots) do
		d.Transparency = transparency
	end
end

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or not heldItemType then
		setArcVisible(false)
		return
	end
	setArcVisible(true)

	local p0  = hrp.Position + Vector3.new(0, 2, 0)
	local dir = getThrowDirection("forward")

	for i = 1, ARC_DOTS do
		local t   = (i / ARC_DOTS) * 1.2   -- simulate 1.2 s of flight
		local pos = p0 + Vector3.new(
			dir.X * THROW_SPEED * t,
			THROW_UP * t + 0.5 * GRAVITY * t * t,
			dir.Z * THROW_SPEED * t
		)
		arcDots[i].CFrame = CFrame.new(pos)
	end
end)

player.CharacterRemoving:Connect(function()
	setArcVisible(false)
end)

------------------------------------------------------------------------
-- KEYBOARD BINDINGS (all devices)
------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.F then
		-- Attempt F-key pickup (backup for when ProximityPrompt is out of range)
		pickupItemRemote:FireServer()

	elseif input.KeyCode == Enum.KeyCode.Q then
		-- Q: throw left
		throwItemRemote:FireServer(heldItemType or "newspaper", getThrowDirection("left"), THROW_SPEED)

	elseif input.KeyCode == Enum.KeyCode.E then
		-- E: throw right (only fires when ProximityPrompt is NOT active)
		throwItemRemote:FireServer(heldItemType or "newspaper", getThrowDirection("right"), THROW_SPEED)
	end
end)

-- Left click while holding item: throw forward
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isHoldingItem() then
			throwItemRemote:FireServer(heldItemType or "newspaper", getThrowDirection("forward"), THROW_SPEED)
		end
	end
end)

------------------------------------------------------------------------
-- MOBILE UI (only if isMobile)
------------------------------------------------------------------------
if isMobile then

	local mobileGui = Instance.new("ScreenGui")
	mobileGui.Name           = "MobileControlsGui"
	mobileGui.ResetOnSpawn   = false
	mobileGui.DisplayOrder   = 5
	mobileGui.IgnoreGuiInset = true
	mobileGui.Parent         = playerGui

	local function createButton(labelText, position)
		local btn                    = Instance.new("TextButton")
		btn.Size                     = UDim2.new(0, 80, 0, 80)
		btn.Position                 = position
		btn.AnchorPoint              = Vector2.new(0.5, 1)
		btn.BackgroundColor3         = Color3.fromRGB(30, 30, 30)
		btn.BackgroundTransparency   = 0.3
		btn.TextColor3               = Color3.fromRGB(255, 255, 255)
		btn.Font                     = Enum.Font.GothamBold
		btn.TextSize                 = 14
		btn.Text                     = labelText
		btn.BorderSizePixel          = 0
		btn.Parent                   = mobileGui

		local corner             = Instance.new("UICorner")
		corner.CornerRadius      = UDim.new(1, 0)
		corner.Parent            = btn

		btn.TouchBegan:Connect(function() btn.Size = UDim2.new(0, 72, 0, 72) end)
		btn.TouchEnded:Connect(function()  btn.Size = UDim2.new(0, 80, 0, 80) end)

		return btn
	end

	local throwLeftBtn  = createButton("⟵ Left",   UDim2.new(0, 60,  1, -20))
	local throwRightBtn = createButton("Right ⟶",  UDim2.new(0, 155, 1, -20))
	local throwFwdBtn   = createButton("↑ Fwd",     UDim2.new(0, 107, 1, -110))
	local pickupBtn     = createButton("Pickup",    UDim2.new(1, -55, 1, -20))

	throwLeftBtn.Activated:Connect(function()
		throwItemRemote:FireServer(heldItemType or "newspaper", getThrowDirection("left"), THROW_SPEED)
	end)

	throwRightBtn.Activated:Connect(function()
		throwItemRemote:FireServer(heldItemType or "newspaper", getThrowDirection("right"), THROW_SPEED)
	end)

	throwFwdBtn.Activated:Connect(function()
		throwItemRemote:FireServer(heldItemType or "newspaper", getThrowDirection("forward"), THROW_SPEED)
	end)

	pickupBtn.Activated:Connect(function()
		pickupItemRemote:FireServer()
	end)
end

print("[MobileControls] Controls initialised — mobile:", isMobile)
