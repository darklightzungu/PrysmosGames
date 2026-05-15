local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Detect device type ───────────────────────────────────────────────────────
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ── Build ScreenGui ──────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ── Helper: make a Frame ─────────────────────────────────────────────────────
local function makeFrame(name, size, pos, color, parent, transparency)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color or Color3.fromRGB(30, 30, 30)
	f.BackgroundTransparency = transparency or 0.4
	f.BorderSizePixel = 0
	f.Parent = parent or screenGui
	return f
end

-- ── Helper: make a TextLabel ─────────────────────────────────────────────────
local function makeLabel(name, text, size, pos, parent, fontSize, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.Parent = parent or screenGui
	return l
end

-- ── Helper: make a TextButton ────────────────────────────────────────────────
local function makeButton(name, text, size, pos, color, parent)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color or Color3.fromRGB(60, 120, 200)
	b.BackgroundTransparency = 0.2
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.BorderSizePixel = 0
	b.Parent = parent or screenGui
	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	return b
end

-- ── Health bar ───────────────────────────────────────────────────────────────
local healthBg = makeFrame("HealthBar",
	UDim2.new(0.22, 0, 0.03, 0),
	UDim2.new(0.01, 0, 0.94, 0),
	Color3.fromRGB(20, 20, 20), screenGui, 0.3)
local corner1 = Instance.new("UICorner"); corner1.CornerRadius = UDim.new(0, 6); corner1.Parent = healthBg

local healthFill = Instance.new("Frame")
healthFill.Name = "Fill"
healthFill.Size = UDim2.new(1, 0, 1, 0)
healthFill.Position = UDim2.new(0, 0, 0, 0)
healthFill.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
healthFill.BorderSizePixel = 0
healthFill.Parent = healthBg
local corner2 = Instance.new("UICorner"); corner2.CornerRadius = UDim.new(0, 6); corner2.Parent = healthFill

local healthLabel = makeLabel("HealthLabel", "HP: 100", UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0), healthBg, 14)
healthLabel.ZIndex = 3

-- ── Delivery counter ─────────────────────────────────────────────────────────
local deliveryLabel = makeLabel("DeliveryCounter", "📦 Deliveries: 0",
	UDim2.new(0.2, 0, 0.05, 0),
	UDim2.new(0.01, 0, 0.04, 0), screenGui)

-- ── Combo score display ───────────────────────────────────────────────────────
local comboFrame = makeFrame("ComboFrame",
	UDim2.new(0.18, 0, 0.08, 0),
	UDim2.new(0.41, 0, 0.03, 0),
	Color3.fromRGB(200, 120, 20), screenGui, 0.25)
local corner3 = Instance.new("UICorner"); corner3.CornerRadius = UDim.new(0, 8); corner3.Parent = comboFrame

local comboLabel = makeLabel("ComboLabel", "COMBO x1",
	UDim2.new(1, 0, 0.5, 0),
	UDim2.new(0, 0, 0, 0), comboFrame, 18, Color3.fromRGB(255, 220, 50))

local scoreLabel = makeLabel("ScoreLabel", "Score: 0",
	UDim2.new(1, 0, 0.5, 0),
	UDim2.new(0, 0, 0.5, 0), comboFrame, 14, Color3.fromRGB(255, 255, 255))

-- ── Vehicle / mount status ────────────────────────────────────────────────────
local mountLabel = makeLabel("MountStatus", "🚲 On Foot",
	UDim2.new(0.2, 0, 0.04, 0),
	UDim2.new(0.01, 0, 0.10, 0), screenGui, 14, Color3.fromRGB(180, 230, 255))

-- ── Proximity delivery indicator ─────────────────────────────────────────────
local proximityFrame = makeFrame("ProximityIndicator",
	UDim2.new(0.22, 0, 0.05, 0),
	UDim2.new(0.39, 0, 0.88, 0),
	Color3.fromRGB(50, 200, 120), screenGui, 0.2)
local corner4 = Instance.new("UICorner"); corner4.CornerRadius = UDim.new(0, 8); corner4.Parent = proximityFrame
proximityFrame.Visible = false

local proximityLabel = makeLabel("ProximityLabel", "📍 DELIVER HERE  [E]",
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0), proximityFrame, 14, Color3.fromRGB(20, 20, 20))

-- ── Round timer ───────────────────────────────────────────────────────────────
local timerLabel = makeLabel("RoundTimer", "5:00",
	UDim2.new(0.12, 0, 0.05, 0),
	UDim2.new(0.44, 0, 0.01, 0), screenGui, 20, Color3.fromRGB(255, 255, 255))

-- ── Device label (shown briefly at start) ────────────────────────────────────
local deviceLabel = makeLabel("DeviceLabel",
	isMobile and "📱 Mobile Controls Active" or "🖥️ PC Controls Active",
	UDim2.new(0.3, 0, 0.04, 0),
	UDim2.new(0.35, 0, 0.46, 0), screenGui, 14, Color3.fromRGB(200, 200, 200))
-- Fade out after 4 seconds
task.delay(4, function()
	TweenService:Create(deviceLabel, TweenInfo.new(1), {TextTransparency = 1}):Play()
end)

-- ── Mobile-only action buttons ────────────────────────────────────────────────
local spawnBikeBtn, throwBtn, deliverBtn

if isMobile then
	-- Spawn bike button (bottom-right cluster)
	spawnBikeBtn = makeButton("SpawnBikeBtn", "🚲 Spawn",
		UDim2.new(0.14, 0, 0.07, 0),
		UDim2.new(0.85, 0, 0.82, 0),
		Color3.fromRGB(40, 100, 220), screenGui)

	-- Throw package button
	throwBtn = makeButton("ThrowBtn", "🎯 Throw",
		UDim2.new(0.14, 0, 0.07, 0),
		UDim2.new(0.85, 0, 0.73, 0),
		Color3.fromRGB(200, 80, 40), screenGui)

	-- Deliver button
	deliverBtn = makeButton("DeliverBtn", "📦 Deliver",
		UDim2.new(0.14, 0, 0.07, 0),
		UDim2.new(0.70, 0, 0.82, 0),
		Color3.fromRGB(40, 180, 80), screenGui)
end

-- ── RemoteEvents ──────────────────────────────────────────────────────────────
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local updateHealth    = remotes:WaitForChild("UpdateHealth")
local updateDelivery  = remotes:WaitForChild("UpdateDelivery")
local updateCombo     = remotes:WaitForChild("UpdateCombo")
local updateScore     = remotes:WaitForChild("UpdateScore")
local updateMount     = remotes:WaitForChild("UpdateMount")
local updateTimer     = remotes:WaitForChild("UpdateTimer")
local showProximity   = remotes:WaitForChild("ShowProximity")
-- Mobile button → server remotes
local requestSpawnBike = remotes:WaitForChild("RequestSpawnBike")
local requestThrow     = remotes:WaitForChild("RequestThrow")
local requestDeliver   = remotes:WaitForChild("RequestDeliver")

-- ── Health update ─────────────────────────────────────────────────────────────
local function applyHealth(hp, maxHp)
	local pct = math.clamp(hp / maxHp, 0, 1)
	TweenService:Create(healthFill, TweenInfo.new(0.25),
		{Size = UDim2.new(pct, 0, 1, 0)}):Play()
	healthLabel.Text = string.format("HP: %d", hp)
	local fillColor
	if pct > 0.6 then
		fillColor = Color3.fromRGB(80, 200, 80)
	elseif pct > 0.3 then
		fillColor = Color3.fromRGB(230, 200, 0)
	else
		fillColor = Color3.fromRGB(220, 50, 50)
	end
	TweenService:Create(healthFill, TweenInfo.new(0.25),
		{BackgroundColor3 = fillColor}):Play()
end

-- ── Combo pop animation ───────────────────────────────────────────────────────
local function popCombo()
	comboLabel.TextSize = 28 -- momentarily large (TextScaled overrides scale, so tweak UIScale)
	TweenService:Create(comboLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{TextTransparency = 0}):Play()
	-- Subtle frame flash
	TweenService:Create(comboFrame, TweenInfo.new(0.1),
		{BackgroundTransparency = 0}):Play()
	task.delay(0.15, function()
		TweenService:Create(comboFrame, TweenInfo.new(0.3),
			{BackgroundTransparency = 0.25}):Play()
	end)
end

-- ── Humanoid health wiring (reconnect on respawn) ─────────────────────────────
local function connectHumanoid(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.HealthChanged:Connect(function(hp)
		applyHealth(hp, humanoid.MaxHealth)
	end)
	applyHealth(humanoid.Health, humanoid.MaxHealth)
end

player.CharacterAdded:Connect(function(character)
	connectHumanoid(character)
end)

if player.Character then
	connectHumanoid(player.Character)
end

-- ── Server event listeners ────────────────────────────────────────────────────
updateHealth.OnClientEvent:Connect(function(hp, maxHp)
	applyHealth(hp, maxHp)
end)

updateDelivery.OnClientEvent:Connect(function(count)
	deliveryLabel.Text = string.format("📦 Deliveries: %d", count)
	-- Quick bounce tween via transparency flash
	TweenService:Create(deliveryLabel, TweenInfo.new(0.1),
		{TextTransparency = 0.5}):Play()
	task.delay(0.1, function()
		TweenService:Create(deliveryLabel, TweenInfo.new(0.2),
			{TextTransparency = 0}):Play()
	end)
end)

updateCombo.OnClientEvent:Connect(function(multiplier)
	comboLabel.Text = string.format("COMBO x%d", multiplier)
	popCombo()
	-- Reset combo color based on level
	if multiplier >= 5 then
		TweenService:Create(comboLabel, TweenInfo.new(0.2),
			{TextColor3 = Color3.fromRGB(255, 80, 80)}):Play()
	elseif multiplier >= 3 then
		TweenService:Create(comboLabel, TweenInfo.new(0.2),
			{TextColor3 = Color3.fromRGB(255, 180, 0)}):Play()
	else
		TweenService:Create(comboLabel, TweenInfo.new(0.2),
			{TextColor3 = Color3.fromRGB(255, 220, 50)}):Play()
	end
end)

updateScore.OnClientEvent:Connect(function(score)
	scoreLabel.Text = string.format("Score: %d", score)
end)

updateMount.OnClientEvent:Connect(function(mounted, vehicleName)
	if mounted then
		mountLabel.Text = string.format("🚲 Riding: %s", vehicleName or "Bike")
		TweenService:Create(mountLabel, TweenInfo.new(0.3),
			{TextColor3 = Color3.fromRGB(100, 255, 180)}):Play()
	else
		mountLabel.Text = "🚲 On Foot"
		TweenService:Create(mountLabel, TweenInfo.new(0.3),
			{TextColor3 = Color3.fromRGB(180, 230, 255)}):Play()
	end
end)

updateTimer.OnClientEvent:Connect(function(secondsLeft)
	local m = math.floor(secondsLeft / 60)
	local s = secondsLeft % 60
	timerLabel.Text = string.format("%d:%02d", m, s)
	if secondsLeft <= 10 then
		TweenService:Create(timerLabel, TweenInfo.new(0.2),
			{TextColor3 = Color3.fromRGB(220, 50, 50)}):Play()
	else
		TweenService:Create(timerLabel, TweenInfo.new(0.2),
			{TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
	end
end)

showProximity.OnClientEvent:Connect(function(visible, label)
	proximityFrame.Visible = visible
	if visible then
		proximityLabel.Text = string.format("📍 %s  %s",
			label or "DELIVER HERE", isMobile and "[TAP]" or "[E]")
		-- Pulse animation
		TweenService:Create(proximityFrame, TweenInfo.new(0.3, Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut, -1, true),
			{BackgroundTransparency = 0.5}):Play()
	else
		-- Stop pulsing
		proximityFrame:FindFirstChildWhichIsA("Tween") -- stop via re-tween
		TweenService:Create(proximityFrame, TweenInfo.new(0.15),
			{BackgroundTransparency = 0.2}):Play()
	end
end)

-- ── Mobile button wiring ──────────────────────────────────────────────────────
if isMobile and spawnBikeBtn and throwBtn and deliverBtn then
	-- Visual press feedback helper
	local function pressEffect(btn)
		TweenService:Create(btn, TweenInfo.new(0.08),
			{BackgroundTransparency = 0.5}):Play()
		task.delay(0.08, function()
			TweenService:Create(btn, TweenInfo.new(0.15),
				{BackgroundTransparency = 0.2}):Play()
		end)
	end

	spawnBikeBtn.Activated:Connect(function()
		pressEffect(spawnBikeBtn)
		requestSpawnBike:FireServer()
	end)

	throwBtn.Activated:Connect(function()
		pressEffect(throwBtn)
		requestThrow:FireServer()
	end)

	deliverBtn.Activated:Connect(function()
		pressEffect(deliverBtn)
		requestDeliver:FireServer()
	end)
end