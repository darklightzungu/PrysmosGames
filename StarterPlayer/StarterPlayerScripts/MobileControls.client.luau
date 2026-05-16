local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- Device detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Remote references
local remotes               = ReplicatedStorage:WaitForChild("Remotes")
local throwItemRemote       = remotes:WaitForChild("ThrowItem")
local pickupConfirmedRemote = remotes:WaitForChild("PickupConfirmed")
local deliverySuccessRemote = remotes:WaitForChild("DeliverySuccess")

local heldItemName  = nil
local heldItemCount = 0

local THROW_SPEED = 60
local ARC_STEPS   = 20
local ARC_DT      = 0.1


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
indicatorLabel.Size                   = UDim2.new(0, 260, 0, 36)
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
indicatorCorner.Parent = indicatorLabel

local indicatorPadding = Instance.new("UIPadding")
indicatorPadding.PaddingLeft = UDim.new(0, 10)
indicatorPadding.Parent = indicatorLabel

local function updateIndicator()
	if heldItemName and heldItemCount > 0 then
		local display = heldItemName:sub(1,1):upper() .. heldItemName:sub(2)
		indicatorLabel.Text = display .. " x" .. heldItemCount .. "  |  F to throw"
	else
		indicatorLabel.Text = "No items — visit DEPOT (E)"
	end
end

------------------------------------------------------------------------
-- THROW ARC
------------------------------------------------------------------------
local arcFolder = Instance.new("Folder")
arcFolder.Name   = "ThrowArc"
arcFolder.Parent = workspace

local arcParts = {}
for i = 1, ARC_STEPS do
	local p = Instance.new("Part")
	p.Name         = "ArcDot_" .. i
	p.Shape        = Enum.PartType.Ball
	p.Size         = Vector3.new(0.35, 0.35, 0.35)
	p.Anchored     = true
	p.CanCollide   = false
	p.CastShadow   = false
	p.Color        = Color3.fromRGB(255, 220, 0)
	p.Material     = Enum.Material.Neon
	p.Transparency = 1
	p.Parent       = arcFolder
	arcParts[i]    = p
end

local function setArcVisible(visible)
	for _, p in ipairs(arcParts) do
		p.Transparency = visible and 0.3 or 1
	end
end

local function updateArc()
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local origin = root.Position + Vector3.new(0, 2, 0)
	local vel    = camera.CFrame.LookVector * THROW_SPEED
	local g      = workspace.Gravity
	for i = 1, ARC_STEPS do
		local t = i * ARC_DT
		arcParts[i].Position = origin + vel * t + Vector3.new(0, -0.5 * g * t * t, 0)
	end
end

local function isHoldingItem()
	return heldItemName ~= nil and heldItemCount > 0
end

local function doThrow(direction)
	if not isHoldingItem() then return end
	throwItemRemote:FireServer(heldItemName, direction or camera.CFrame.LookVector, THROW_SPEED)
	heldItemName  = nil
	heldItemCount = 0
	updateIndicator()
end

------------------------------------------------------------------------
-- REMOTE EVENTS
------------------------------------------------------------------------
pickupConfirmedRemote.OnClientEvent:Connect(function(itemName, count)
	heldItemName  = itemName
	heldItemCount = count or 1
	updateIndicator()
end)

deliverySuccessRemote.OnClientEvent:Connect(function()
	heldItemName  = nil
	heldItemCount = 0
	updateIndicator()
end)

------------------------------------------------------------------------
-- ARC UPDATE LOOP
------------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	if isHoldingItem() then
		setArcVisible(true)
		updateArc()
	else
		setArcVisible(false)
	end
end)

------------------------------------------------------------------------
-- KEYBOARD BINDINGS (all devices)
------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.F then
		doThrow()
	end
end)

-- Left-click throw toward mouse cursor
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isHoldingItem() then
			local mousePos = UserInputService:GetMouseLocation()
			local ray      = camera:ScreenPointToRay(mousePos.X, mousePos.Y)
			doThrow(ray.Direction)
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
		local btn = Instance.new("TextButton")
		btn.Size                   = UDim2.new(0, 80, 0, 80)
		btn.Position               = position
		btn.AnchorPoint            = Vector2.new(0.5, 1)
		btn.BackgroundColor3       = Color3.fromRGB(30, 30, 30)
		btn.BackgroundTransparency = 0.3
		btn.TextColor3             = Color3.fromRGB(255, 255, 255)
		btn.Font                   = Enum.Font.GothamBold
		btn.TextSize               = 14
		btn.Text                   = labelText
		btn.BorderSizePixel        = 0
		btn.Parent                 = mobileGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = btn

		btn.TouchBegan:Connect(function() btn.Size = UDim2.new(0, 72, 0, 72) end)
		btn.TouchEnded:Connect(function() btn.Size = UDim2.new(0, 80, 0, 80) end)
		return btn
	end

	local throwBtn = createButton("THROW", UDim2.new(0.5, 0, 1, -20))
	throwBtn.Activated:Connect(function() doThrow() end)
end

print("[MobileControls] Controls initialised — mobile:", isMobile)