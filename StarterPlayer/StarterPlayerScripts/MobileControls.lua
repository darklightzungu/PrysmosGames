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
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local pickupItemRemote = remotes:WaitForChild("PickupItem")
local throwItemRemote = remotes:WaitForChild("ThrowItem")
local pickupConfirmedRemote = remotes:WaitForChild("PickupConfirmed")
local deliverySuccessRemote = remotes:WaitForChild("DeliverySuccess")

-- Held item state
local heldItemName = nil
local heldItemCount = 0

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

-- Whether the player is currently holding an item (used for left-click throw)
local function isHoldingItem()
	return heldItemName ~= nil and heldItemCount > 0
end

------------------------------------------------------------------------
-- ITEM INDICATOR (all devices)
------------------------------------------------------------------------
local indicatorGui = Instance.new("ScreenGui")
indicatorGui.Name = "ItemIndicatorGui"
indicatorGui.ResetOnSpawn = false
indicatorGui.DisplayOrder = 10
indicatorGui.IgnoreGuiInset = false
indicatorGui.Parent = playerGui

local indicatorLabel = Instance.new("TextLabel")
indicatorLabel.Name = "ItemIndicator"
indicatorLabel.Size = UDim2.new(0, 220, 0, 36)
indicatorLabel.Position = UDim2.new(0, 12, 0, 12)
indicatorLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
indicatorLabel.BackgroundTransparency = 0.35
indicatorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
indicatorLabel.Font = Enum.Font.GothamBold
indicatorLabel.TextSize = 13
indicatorLabel.Text = "No items — visit DEPOT"
indicatorLabel.TextXAlignment = Enum.TextXAlignment.Left
indicatorLabel.TextTruncate = Enum.TextTruncate.AtEnd
indicatorLabel.BorderSizePixel = 0
indicatorLabel.Parent = indicatorGui

-- Rounded corners for the indicator
local indicatorCorner = Instance.new("UICorner")
indicatorCorner.CornerRadius = UDim.new(0, 8)
indicatorCorner.Parent = indicatorLabel

-- Padding inside label
local indicatorPadding = Instance.new("UIPadding")
indicatorPadding.PaddingLeft = UDim.new(0, 10)
indicatorPadding.Parent = indicatorLabel

-- Update the indicator text whenever held item changes
local function updateIndicator()
	if heldItemName and heldItemCount > 0 then
		indicatorLabel.Text = heldItemName .. " x" .. heldItemCount
	else
		indicatorLabel.Text = "No items — visit DEPOT"
	end
end

-- Listen for item pickup confirmation from server
pickupConfirmedRemote.OnClientEvent:Connect(function(itemName, count)
	heldItemName = itemName
	heldItemCount = count or 1
	updateIndicator()
end)

-- Listen for successful delivery (clears held item display)
deliverySuccessRemote.OnClientEvent:Connect(function()
	heldItemName = nil
	heldItemCount = 0
	updateIndicator()
end)

------------------------------------------------------------------------
-- KEYBOARD BINDINGS (all devices)
------------------------------------------------------------------------

-- F key: fire PickupItem
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.F then
		pickupItemRemote:FireServer()

	elseif input.KeyCode == Enum.KeyCode.Q then
		-- Q key: throw left
		throwItemRemote:FireServer(getThrowDirection("left"))
	end
end)

-- Left click while holding item: throw forward
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isHoldingItem() then
			throwItemRemote:FireServer(getThrowDirection("forward"))
		end
	end
end)

------------------------------------------------------------------------
-- MOBILE UI (only if isMobile)
------------------------------------------------------------------------
if isMobile then

	local mobileGui = Instance.new("ScreenGui")
	mobileGui.Name = "MobileControlsGui"
	mobileGui.ResetOnSpawn = false
	mobileGui.DisplayOrder = 5
	mobileGui.IgnoreGuiInset = true
	mobileGui.Parent = playerGui

	-- Helper: creates a circular button with label text
	local function createButton(labelText, position)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 80, 0, 80)
		btn.Position = position
		btn.AnchorPoint = Vector2.new(0.5, 1) -- anchor bottom-centre for easy bottom placement
		btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		btn.BackgroundTransparency = 0.3
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 14
		btn.Text = labelText
		btn.BorderSizePixel = 0
		btn.Parent = mobileGui

		-- Circular shape
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = btn

		-- Scale down on press, restore on release
		btn.TouchBegan:Connect(function()
			btn.Size = UDim2.new(0, 72, 0, 72) -- scale to ~0.9
		end)
		btn.TouchEnded:Connect(function()
			btn.Size = UDim2.new(0, 80, 0, 80)
		end)

		return btn
	end

	-- Button positions (bottom-left cluster + bottom-right pickup)
	-- Using scale so it adapts to screen size; small offset from edges
	local throwLeftBtn = createButton("⟵ Left",   UDim2.new(0, 60,  1, -20))
	local throwRightBtn = createButton("Right ⟶", UDim2.new(0, 155, 1, -20))
	local throwFwdBtn  = createButton("↑ Fwd",    UDim2.new(0, 107, 1, -110))
	local pickupBtn    = createButton("Pickup",   UDim2.new(1, -55, 1, -20))

	-- Wire up button actions
	throwLeftBtn.Activated:Connect(function()
		throwItemRemote:FireServer(getThrowDirection("left"))
	end)

	throwRightBtn.Activated:Connect(function()
		throwItemRemote:FireServer(getThrowDirection("right"))
	end)

	throwFwdBtn.Activated:Connect(function()
		throwItemRemote:FireServer(getThrowDirection("forward"))
	end)

	pickupBtn.Activated:Connect(function()
		pickupItemRemote:FireServer()
	end)
end

print("[MobileControls] Controls initialised — mobile:", isMobile)