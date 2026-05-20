local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- Wait for Remotes folder
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Remote events for combat
local updateHealthEvent = remotes:WaitForChild("UpdateHealth")
local updateStatsEvent = remotes:WaitForChild("UpdateStats")
local combatFeedbackEvent = remotes:WaitForChild("CombatFeedback")
local actionCooldownEvent = remotes:WaitForChild("ActionCooldown")

-- Tween info presets
local tweenFast = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenMedium = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenSlow = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- HUD state
local hudState = {
	maxHealth = 100,
	currentHealth = 100,
	kills = 0,
	combo = 0,
	rage = 0,
	maxRage = 100,
}

-- Destroy old HUD if it exists
local function cleanupHud()
	local old = playerGui:FindFirstChild("HUD")
	if old then old:Destroy() end
end

-- Helper: create a UICorner
local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
end

-- Helper: create a UIStroke
local function addStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(255, 255, 255)
	stroke.Thickness = thickness or 1.5
	stroke.Parent = parent
end

-- Helper: create a text label
local function makeLabel(parent, name, text, size, pos, textSize, color, bold)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = pos
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = textSize or 16
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.TextStrokeTransparency = 0.6
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

-- Build the HUD
local function buildHud()
	cleanupHud()

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- ============================================================
	-- HEALTH BAR (bottom left)
	-- ============================================================
	local healthContainer = Instance.new("Frame")
	healthContainer.Name = "HealthContainer"
	healthContainer.Size = UDim2.new(0, 300, 0, 50)
	healthContainer.Position = UDim2.new(0, 20, 1, -120)
	healthContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	healthContainer.BackgroundTransparency = 0.3
	addCorner(healthContainer, 10)
	addStroke(healthContainer, Color3.fromRGB(80, 80, 80), 1.5)
	healthContainer.Parent = screenGui

	local healthLabel = makeLabel(
		healthContainer, "HealthLabel", "HP",
		UDim2.new(0, 30, 1, 0),
		UDim2.new(0, 8, 0, 0),
		14, Color3.fromRGB(220, 220, 220), true
	)
	healthLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Health bar background
	local healthBarBg = Instance.new("Frame")
	healthBarBg.Name = "HealthBarBg"
	healthBarBg.Size = UDim2.new(1, -50, 0, 16)
	healthBarBg.Position = UDim2.new(0, 42, 0.5, -8)
	healthBarBg.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
	addCorner(healthBarBg, 6)
	healthBarBg.Parent = healthContainer

	-- Health bar fill
	local healthFill = Instance.new("Frame")
	healthFill.Name = "HealthFill"
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.Position = UDim2.new(0, 0, 0, 0)
	healthFill.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
	addCorner(healthFill, 6)
	healthFill.Parent = healthBarBg

	-- Gradient on health fill
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 255, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 160, 60)),
	})
	grad.Rotation = 90
	grad.Parent = healthFill

	-- Health number label
	local healthNumLabel = makeLabel(
		healthContainer, "HealthNum", "100/100",
		UDim2.new(0, 90, 0, 14),
		UDim2.new(0, 42, 1, -16),
		12, Color3.fromRGB(200, 255, 200), false
	)
	healthNumLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- ============================================================
	-- RAGE BAR (below health bar)
	-- ============================================================
	local rageContainer = Instance.new("Frame")
	rageContainer.Name = "RageContainer"
	rageContainer.Size = UDim2.new(0, 300, 0, 36)
	rageContainer.Position = UDim2.new(0, 20, 1, -76)
	rageContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	rageContainer.BackgroundTransparency = 0.3
	addCorner(rageContainer, 8)
	addStroke(rageContainer, Color3.fromRGB(80, 80, 80), 1.5)
	rageContainer.Parent = screenGui

	local rageIconLabel = makeLabel(
		rageContainer, "RageIcon", "RAGE",
		UDim2.new(0, 42, 1, 0),
		UDim2.new(0, 8, 0, 0),
		12, Color3.fromRGB(255, 120, 40), true
	)
	rageIconLabel.TextXAlignment = Enum.TextXAlignment.Left

	local rageBarBg = Instance.new("Frame")
	rageBarBg.Name = "RageBarBg"
	rageBarBg.Size = UDim2.new(1, -58, 0, 12)
	rageBarBg.Position = UDim2.new(0, 50, 0.5, -6)
	rageBarBg.BackgroundColor3 = Color3.fromRGB(50, 20, 0)
	addCorner(rageBarBg, 5)
	rageBarBg.Parent = rageContainer

	local rageFill = Instance.new("Frame")
	rageFill.Name = "RageFill"
	rageFill.Size = UDim2.new(0, 0, 1, 0)
	rageFill.BackgroundColor3 = Color3.fromRGB(255, 80, 0)
	addCorner(rageFill, 5)
	rageFill.Parent = rageBarBg

	local rageGrad = Instance.new("UIGradient")
	rageGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 40, 0)),
	})
	rageGrad.Rotation = 90
	rageGrad.Parent = rageFill

	-- ============================================================
	-- STAT LABELS (top left)
	-- ============================================================
	local statsContainer = Instance.new("Frame")
	statsContainer.Name = "StatsContainer"
	statsContainer.Size = UDim2.new(0, 200, 0, 80)
	statsContainer.Position = UDim2.new(0, 20, 0, 20)
	statsContainer.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	statsContainer.BackgroundTransparency = 0.4
	addCorner(statsContainer, 10)
	addStroke(statsContainer, Color3.fromRGB(60, 60, 60), 1.5)
	statsContainer.Parent = screenGui

	local killsLabel = makeLabel(
		statsContainer, "KillsLabel", "☠ Kills: 0",
		UDim2.new(1, -10, 0, 30),
		UDim2.new(0, 10, 0, 8),
		16, Color3.fromRGB(255, 220, 60), true
	)

	local comboLabel = makeLabel(
		statsContainer, "ComboLabel", "⚡ Combo: x0",
		UDim2.new(1, -10, 0, 30),
		UDim2.new(0, 10, 0, 42),
		14, Color3.fromRGB(100, 200, 255), false
	)

	-- ============================================================
	-- COMBAT FEEDBACK / COMBO POPUP (center top)
	-- ============================================================
	local feedbackLabel = Instance.new("TextLabel")
	feedbackLabel.Name = "FeedbackLabel"
	feedbackLabel.Size = UDim2.new(0, 400, 0, 60)
	feedbackLabel.Position = UDim2.new(0.5, -200, 0, 80)
	feedbackLabel.BackgroundTransparency = 1
	feedbackLabel.Text = ""
	feedbackLabel.TextSize = 36
	feedbackLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	feedbackLabel.Font = Enum.Font.GothamBlack
	feedbackLabel.TextStrokeTransparency = 0.3
	feedbackLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	feedbackLabel.TextXAlignment = Enum.TextXAlignment.Center
	feedbackLabel.TextTransparency = 1
	feedbackLabel.Parent = screenGui

	-- ============================================================
	-- ACTION BUTTONS (bottom right)
	-- ============================================================
	local actionsContainer = Instance.new("Frame")
	actionsContainer.Name = "ActionsContainer"
	actionsContainer.Size = UDim2.new(0, 220, 0, 110)
	actionsContainer.Position = UDim2.new(1, -240, 1, -130)
	actionsContainer.BackgroundTransparency = 1
	actionsContainer.Parent = screenGui

	local actionDefs = {
		{ name = "Attack",    key = "LMB", color = Color3.fromRGB(220, 60, 60),   pos = UDim2.new(0, 0, 0, 0) },
		{ name = "Block",     key = "RMB", color = Color3.fromRGB(60, 120, 220),  pos = UDim2.new(0, 110, 0, 0) },
		{ name = "Dodge",     key = "Q",   color = Color3.fromRGB(80, 200, 120),  pos = UDim2.new(0, 0, 0, 60) },
		{ name = "RageMode",  key = "E",   color = Color3.fromRGB(255, 100, 20),  pos = UDim2.new(0, 110, 0, 60) },
	}

	local actionButtons = {} -- keyed by action name

	for _, def in ipairs(actionDefs) do
		local btn = Instance.new("Frame")
		btn.Name = def.name .. "Btn"
		btn.Size = UDim2.new(0, 100, 0, 50)
		btn.Position = def.pos
		btn.BackgroundColor3 = def.color
		btn.BackgroundTransparency = 0.2
		addCorner(btn, 8)
		addStroke(btn, Color3.fromRGB(200, 200, 200), 1)
		btn.Parent = actionsContainer

		-- Label
		local btnLabel = Instance.new("TextLabel")
		btnLabel.Size = UDim2.new(1, 0, 0.55, 0)
		btnLabel.Position = UDim2.new(0, 0, 0, 0)
		btnLabel.BackgroundTransparency = 1
		btnLabel.Text = def.name
		btnLabel.TextSize = 12
		btnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		btnLabel.Font = Enum.Font.GothamBold
		btnLabel.TextStrokeTransparency = 0.5
		btnLabel.Parent = btn

		-- Key hint
		local keyLabel = Instance.new("TextLabel")
		keyLabel.Size = UDim2.new(1, 0, 0.4, 0)
		keyLabel.Position = UDim2.new(0, 0, 0.58, 0)
		keyLabel.BackgroundTransparency = 1
		keyLabel.Text = "[" .. def.key .. "]"
		keyLabel.TextSize = 11
		keyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		keyLabel.Font = Enum.Font.Gotham
		keyLabel.Parent = btn

		-- Cooldown overlay
		local cdOverlay = Instance.new("Frame")
		cdOverlay.Name = "Cooldown"
		cdOverlay.Size = UDim2.new(1, 0, 0, 0) -- grows from bottom
		cdOverlay.Position = UDim2.new(0, 0, 1, 0)
		cdOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		cdOverlay.BackgroundTransparency = 0.4
		addCorner(cdOverlay, 8)
		cdOverlay.ClipsDescendants = true
		cdOverlay.Parent = btn

		actionButtons[def.name] = { frame = btn, overlay = cdOverlay }
	end

	-- ============================================================
	-- CROSSHAIR / CENTER DOT
	-- ============================================================
	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.Size = UDim2.new(0, 6, 0, 6)
	crosshair.Position = UDim2.new(0.5, -3, 0.5, -3)
	crosshair.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	crosshair.BackgroundTransparency = 0.3
	addCorner(crosshair, 3)
	crosshair.Parent = screenGui

	-- ============================================================
	-- RETURN references
	-- ============================================================
	return {
		screenGui = screenGui,
		healthFill = healthFill,
		healthNumLabel = healthNumLabel,
		rageFill = rageFill,
		killsLabel = killsLabel,
		comboLabel = comboLabel,
		feedbackLabel = feedbackLabel,
		actionButtons = actionButtons,
	}
end

-- Active HUD reference
local hud = nil
local feedbackTween = nil -- track active feedback tween

-- ============================================================
-- HUD UPDATE FUNCTIONS
-- ============================================================

local function updateHealthBar(currentHp, maxHp)
	if not hud then return end
	maxHp = maxHp or hudState.maxHealth
	currentHp = math.clamp(currentHp, 0, maxHp)
	hudState.currentHealth = currentHp
	hudState.maxHealth = maxHp

	local ratio = currentHp / maxHp

	-- Tween health bar fill width
	TweenService:Create(hud.healthFill, tweenMedium, {
		Size = UDim2.new(ratio, 0, 1, 0)
	}):Play()

	-- Change color based on health ratio
	local fillColor
	if ratio > 0.6 then
		fillColor = Color3.fromRGB(60, 200, 80)
	elseif ratio > 0.3 then
		fillColor = Color3.fromRGB(220, 180, 40)
	else
		fillColor = Color3.fromRGB(220, 60, 60)
	end

	TweenService:Create(hud.healthFill, tweenMedium, {
		BackgroundColor3 = fillColor
	}):Play()

	hud.healthNumLabel.Text = math.floor(currentHp) .. "/" .. math.floor(maxHp)
end

local function updateRageBar(rageAmount, maxRage)
	if not hud then return end
	maxRage = maxRage or hudState.maxRage
	rageAmount = math.clamp(rageAmount, 0, maxRage)
	hudState.rage = rageAmount
	hudState.maxRage = maxRage

	local ratio = rageAmount / maxRage

	TweenService:Create(hud.rageFill, tweenMedium, {
		Size = UDim2.new(ratio, 0, 1, 0)
	}):Play()
end

local function updateKills(kills)
	if not hud then return end
	hudState.kills = kills
	hud.killsLabel.Text = "☠ Kills: " .. kills

	-- Brief scale bounce effect using position shift
	TweenService:Create(hud.killsLabel, tweenFast, {
		TextSize = 20
	}):Play()
	task.delay(0.2, function()
		if hud and hud.killsLabel then
			TweenService:Create(hud.killsLabel, tweenFast, { TextSize = 16 }):Play()
		end
	end)
end

local function updateCombo(combo)
	if not hud then return end
	hudState.combo = combo
	hud.comboLabel.Text = "⚡ Combo: x" .. combo

	-- Highlight on high combo
	local color = combo >= 10 and Color3.fromRGB(255, 100, 40)
		or combo >= 5 and Color3.fromRGB(255, 200, 40)
		or Color3.fromRGB(100, 200, 255)
	TweenService:Create(hud.comboLabel, tweenFast, { TextColor3 = color }):Play()
end

local function showCombatFeedback(message, color)
	if not hud then return end
	color = color or Color3.fromRGB(255, 200, 50)

	-- Cancel previous tween
	if feedbackTween then feedbackTween:Cancel() end

	hud.feedbackLabel.Text = message
	hud.feedbackLabel.TextColor3 = color
	hud.feedbackLabel.TextTransparency = 0
	hud.feedbackLabel.Position = UDim2.new(0.5, -200, 0, 80)

	-- Float upward and fade
	local moveTween = TweenService:Create(hud.feedbackLabel, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -200, 0, 40),
		TextTransparency = 1,
	})
	moveTween:Play()
	feedbackTween = moveTween
end

local function triggerActionCooldown(actionName, duration)
	if not hud then return end
	local actionData = hud.actionButtons[actionName]
	if not actionData then return end

	local overlay = actionData.overlay

	-- Animate overlay from full cover to none (simulating cooldown drain)
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)

	local drainTween = TweenService:Create(overlay, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 1, 0),
	})
	drainTween:Play()
end

-- Sync health from character's Humanoid
local function connectHumanoidHealth(character)
	local humanoid = character:WaitForChild("Humanoid")

	-- Initial sync
	updateHealthBar(humanoid.Health, humanoid.MaxHealth)

	humanoid.HealthChanged:Connect(function(newHp)
		updateHealthBar(newHp, humanoid.MaxHealth)
	end)

	humanoid.Died:Connect(function()
		updateHealthBar(0, humanoid.MaxHealth)
	end)
end

-- ============================================================
-- SETUP & RECONNECT
-- ============================================================

local function setup(character)
	hud = buildHud()
	connectHumanoidHealth(character)
end

-- Initial setup if character already exists
if player.Character then
	setup(player.Character)
end

-- Reconnect HUD on character respawn
player.CharacterAdded:Connect(function(character)
	setup(character)
end)

-- ============================================================
-- REMOTE EVENT LISTENERS
-- ============================================================

-- UpdateHealth: (currentHp, maxHp)
updateHealthEvent.OnClientEvent:Connect(function(currentHp, maxHp)
	updateHealthBar(currentHp, maxHp)
end)

-- UpdateStats: (statTable) e.g. {kills=5, combo=3, rage=40}
updateStatsEvent.OnClientEvent:Connect(function(stats)
	if stats.kills ~= nil then updateKills(stats.kills) end
	if stats.combo ~= nil then updateCombo(stats.combo) end
	if stats.rage ~= nil then updateRageBar(stats.rage, stats.maxRage or hudState.maxRage) end
end)

-- CombatFeedback: (message, colorHex or Color3)
combatFeedbackEvent.OnClientEvent:Connect(function(message, color)
	showCombatFeedback(message, color)
end)

-- ActionCooldown: (actionName, duration)
actionCooldownEvent.OnClientEvent:Connect(function(actionName, duration)
	triggerActionCooldown(actionName, duration)
end)