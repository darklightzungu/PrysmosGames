-- HudController.lua
-- Route Rage — HUD LocalScript
-- Place in: StarterPlayerScripts

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Build ScreenGui ──────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "HUD"
screenGui.ResetOnSpawn    = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.Parent          = playerGui

-- ── Utility: make a Frame ────────────────────────────────────────────────────
local function makeFrame(name, size, position, color, parent, transparency)
	local f = Instance.new("Frame")
	f.Name                  = name
	f.Size                  = size
	f.Position              = position
	f.BackgroundColor3      = color or Color3.fromRGB(30, 30, 30)
	f.BackgroundTransparency = transparency or 0.4
	f.BorderSizePixel       = 0
	f.Parent                = parent or screenGui
	return f
end

-- ── Utility: make a TextLabel ────────────────────────────────────────────────
local function makeLabel(name, text, size, position, parent, fontSize)
	local l = Instance.new("TextLabel")
	l.Name                  = name
	l.Text                  = text
	l.Size                  = size
	l.Position              = position
	l.BackgroundTransparency = 1
	l.TextColor3            = Color3.fromRGB(255, 255, 255)
	l.Font                  = Enum.Font.GothamBold
	l.TextSize              = fontSize or 16
	l.TextXAlignment        = Enum.TextXAlignment.Left
	l.Parent                = parent or screenGui
	return l
end

-- ── Corner radius helper ─────────────────────────────────────────────────────
local function addCorner(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = instance
end

-- ════════════════════════════════════════════════════════════════════════════
-- HEALTH BAR
-- ════════════════════════════════════════════════════════════════════════════
local healthPanel = makeFrame(
	"HealthPanel",
	UDim2.new(0, 220, 0, 36),
	UDim2.new(0, 16, 1, -56),
	Color3.fromRGB(20, 20, 20),
	screenGui, 0.3
)
addCorner(healthPanel, 8)

-- Heart icon label
local heartIcon = makeLabel("HeartIcon", "❤", UDim2.new(0, 30, 1, 0),
	UDim2.new(0, 6, 0, 0), healthPanel, 18)
heartIcon.TextXAlignment = Enum.TextXAlignment.Center
heartIcon.TextColor3     = Color3.fromRGB(230, 60, 60)

-- Health bar background track
local healthBarBg = makeFrame(
	"HealthBarBg",
	UDim2.new(1, -46, 0, 14),
	UDim2.new(0, 40, 0.5, -7),
	Color3.fromRGB(50, 50, 50),
	healthPanel, 0
)
addCorner(healthBarBg, 5)

-- Health fill
local healthFill = makeFrame(
	"HealthFill",
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(80, 200, 80),
	healthBarBg, 0
)
addCorner(healthFill, 5)

-- Health text e.g. "100 / 100"
local healthLabel = makeLabel(
	"HealthLabel", "100 / 100",
	UDim2.new(1, -46, 0, 14),
	UDim2.new(0, 40, 0.5, 8),
	healthPanel, 12
)
healthLabel.TextXAlignment = Enum.TextXAlignment.Center
healthLabel.Size           = UDim2.new(1, -46, 0, 12)

-- ════════════════════════════════════════════════════════════════════════════
-- COMBAT PANEL  (kill counter + combo)
-- ════════════════════════════════════════════════════════════════════════════
local combatPanel = makeFrame(
	"CombatPanel",
	UDim2.new(0, 160, 0, 70),
	UDim2.new(1, -176, 0, 16),
	Color3.fromRGB(20, 20, 20),
	screenGui, 0.3
)
addCorner(combatPanel, 8)

local killLabel = makeLabel(
	"KillLabel", "🔫  Kills: 0",
	UDim2.new(1, -8, 0, 28),
	UDim2.new(0, 8, 0, 4),
	combatPanel, 15
)
killLabel.TextXAlignment = Enum.TextXAlignment.Left

local comboLabel = makeLabel(
	"ComboLabel", "⚡  Combo: x0",
	UDim2.new(1, -8, 0, 28),
	UDim2.new(0, 8, 0, 36),
	combatPanel, 14
)
comboLabel.TextXAlignment = Enum.TextXAlignment.Left
comboLabel.TextColor3     = Color3.fromRGB(255, 220, 60)

-- ════════════════════════════════════════════════════════════════════════════
-- VEHICLE PANEL  (speed + gear + nitro)
-- ════════════════════════════════════════════════════════════════════════════
local vehiclePanel = makeFrame(
	"VehiclePanel",
	UDim2.new(0, 200, 0, 90),
	UDim2.new(0.5, -100, 1, -106),
	Color3.fromRGB(20, 20, 20),
	screenGui, 0.3
)
addCorner(vehiclePanel, 8)

local speedLabel = makeLabel(
	"SpeedLabel", "🚗  0 km/h",
	UDim2.new(1, -8, 0, 26),
	UDim2.new(0, 8, 0, 4),
	vehiclePanel, 18
)
speedLabel.TextXAlignment = Enum.TextXAlignment.Center
speedLabel.Size           = UDim2.new(1, -8, 0, 26)

local gearLabel = makeLabel(
	"GearLabel", "GEAR  N",
	UDim2.new(1, -8, 0, 22),
	UDim2.new(0, 8, 0, 32),
	vehiclePanel, 14
)
gearLabel.TextXAlignment = Enum.TextXAlignment.Center
gearLabel.Size           = UDim2.new(1, -8, 0, 22)

-- Nitro bar background
local nitroBarBg = makeFrame(
	"NitroBarBg",
	UDim2.new(1, -16, 0, 12),
	UDim2.new(0, 8, 0, 60),
	Color3.fromRGB(30, 30, 60),
	vehiclePanel, 0
)
addCorner(nitroBarBg, 4)

local nitroFill = makeFrame(
	"NitroFill",
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(60, 120, 255),
	nitroBarBg, 0
)
addCorner(nitroFill, 4)

local nitroLabel = makeLabel(
	"NitroLabel", "NITRO",
	UDim2.new(1, -16, 0, 12),
	UDim2.new(0, 8, 0, 74),
	vehiclePanel, 10
)
nitroLabel.TextXAlignment = Enum.TextXAlignment.Center
nitroLabel.Size           = UDim2.new(1, -16, 0, 12)

-- ════════════════════════════════════════════════════════════════════════════
-- ROUND TIMER  (top-centre)
-- ════════════════════════════════════════════════════════════════════════════
local timerPanel = makeFrame(
	"TimerPanel",
	UDim2.new(0, 110, 0, 38),
	UDim2.new(0.5, -55, 0, 10),
	Color3.fromRGB(20, 20, 20),
	screenGui, 0.3
)
addCorner(timerPanel, 8)

local roundTimer = makeLabel(
	"RoundTimer", "0:00",
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	timerPanel, 22
)
roundTimer.TextXAlignment = Enum.TextXAlignment.Center
roundTimer.Font           = Enum.Font.GothamBold

-- ════════════════════════════════════════════════════════════════════════════
-- REMOTES
-- ════════════════════════════════════════════════════════════════════════════
local remotes        = ReplicatedStorage:WaitForChild("Remotes")
local evUpdateKills  = remotes:WaitForChild("UpdateKills")
local evUpdateTimer  = remotes:WaitForChild("UpdateTimer")
local evUpdateVehicle = remotes:WaitForChild("UpdateVehicle")  -- speed, gear, nitro 0-1
local evUpdateCombo  = remotes:WaitForChild("UpdateCombo")

-- ── TweenInfo presets ────────────────────────────────────────────────────────
local tweenFast   = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenMedium = TweenInfo.new(0.4,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ── Health bar update ────────────────────────────────────────────────────────
local function updateHealthBar(health, maxHealth)
	local pct = math.clamp(health / maxHealth, 0, 1)

	-- Smooth fill tween
	TweenService:Create(healthFill, tweenFast,
		{ Size = UDim2.new(pct, 0, 1, 0) }):Play()

	-- Colour shift green → yellow → red
	local fillColor
	if pct > 0.6 then
		fillColor = Color3.fromRGB(80, 200, 80)
	elseif pct > 0.3 then
		fillColor = Color3.fromRGB(230, 200, 0)
	else
		fillColor = Color3.fromRGB(220, 50, 50)
	end
	TweenService:Create(healthFill, tweenFast,
		{ BackgroundColor3 = fillColor }):Play()

	healthLabel.Text = math.floor(health) .. " / " .. math.floor(maxHealth)
end

-- ── Connect humanoid health changes ─────────────────────────────────────────
local function connectCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	updateHealthBar(humanoid.Health, humanoid.MaxHealth)

	humanoid.HealthChanged:Connect(function(health)
		updateHealthBar(health, humanoid.MaxHealth)
	end)
end

-- Initial connection
local character = player.Character or player.CharacterAdded:Wait()
connectCharacter(character)

-- Reconnect after respawn
player.CharacterAdded:Connect(function(newChar)
	connectCharacter(newChar)
end)

-- ── Kill counter ─────────────────────────────────────────────────────────────
evUpdateKills.OnClientEvent:Connect(function(kills)
	killLabel.Text = "🔫  Kills: " .. tostring(kills)

	-- Brief flash white on new kill
	killLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
	TweenService:Create(killLabel, tweenMedium,
		{ TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
end)

-- ── Combo counter ────────────────────────────────────────────────────────────
evUpdateCombo.OnClientEvent:Connect(function(combo)
	comboLabel.Text = "⚡  Combo: x" .. tostring(combo)

	-- Scale pulse effect via TextSize
	comboLabel.TextSize = 18
	TweenService:Create(comboLabel, tweenFast,
		{ TextSize = 14 }):Play()

	-- Highlight on high combo
	if combo >= 5 then
		comboLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	elseif combo >= 3 then
		comboLabel.TextColor3 = Color3.fromRGB(255, 180, 40)
	else
		comboLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
	end
end)

-- ── Round timer ──────────────────────────────────────────────────────────────
evUpdateTimer.OnClientEvent:Connect(function(secondsLeft)
	local m = math.floor(secondsLeft / 60)
	local s = secondsLeft % 60
	roundTimer.Text = string.format("%d:%02d", m, s)

	-- Flash red in final 10 seconds
	if secondsLeft <= 10 then
		roundTimer.TextColor3 = Color3.fromRGB(220, 50, 50)
		-- Quick scale throb
		roundTimer.TextSize = 26
		TweenService:Create(roundTimer, tweenFast,
			{ TextSize = 22 }):Play()
	else
		roundTimer.TextColor3 = Color3.fromRGB(255, 255, 255)
		roundTimer.TextSize   = 22
	end
end)

-- ── Vehicle stats ─────────────────────────────────────────────────────────────
-- Server fires: UpdateVehicle(speed [number], gear [string], nitroPct [0-1])
evUpdateVehicle.OnClientEvent:Connect(function(speed, gear, nitroPct)
	-- Speed
	speedLabel.Text = string.format("🚗  %d km/h", math.floor(speed or 0))

	-- Gear label
	local gearStr = tostring(gear or "N")
	gearLabel.Text = "GEAR  " .. gearStr

	-- Colour gear label by type
	if gearStr == "R" then
		gearLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	elseif gearStr == "N" then
		gearLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	else
		gearLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
	end

	-- Nitro bar fill tween
	local np = math.clamp(nitroPct or 0, 0, 1)
	TweenService:Create(nitroFill, tweenFast,
		{ Size = UDim2.new(np, 0, 1, 0) }):Play()

	-- Tint bar cyan when nearly full
	local nitroColor = np >= 0.9
		and Color3.fromRGB(140, 200, 255)
		or  Color3.fromRGB(60, 120, 255)
	TweenService:Create(nitroFill, tweenFast,
		{ BackgroundColor3 = nitroColor }):Play()
end)

-- ── Health sync (server authoritative) ──────────────────────────────────────
local evUpdateHealth = remotes:WaitForChild("UpdateHealth")
evUpdateHealth.OnClientEvent:Connect(function(health, maxHealth)
	updateHealthBar(health, maxHealth)
end)

-- ── Death & round-end overlay ────────────────────────────────────────────────
local evNotifyDeath = remotes:WaitForChild("NotifyDeath")

evNotifyDeath.OnClientEvent:Connect(function(eventType, winnerName, winnerKills)
	if eventType == "round_end" then
		-- Round-end banner
		local banner = Instance.new("TextLabel")
		banner.Name                   = "RoundEndBanner"
		banner.Size                   = UDim2.new(0, 440, 0, 70)
		banner.Position               = UDim2.new(0.5, -220, 0.35, 0)
		banner.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
		banner.BackgroundTransparency = 0.15
		banner.TextColor3             = Color3.fromRGB(255, 220, 60)
		banner.Font                   = Enum.Font.GothamBold
		banner.TextSize               = 22
		banner.Text                   = string.format(
			"🏆  %s wins  ·  %d kills!", winnerName or "—", winnerKills or 0)
		banner.BorderSizePixel        = 0
		banner.Parent                 = screenGui
		addCorner(banner, 10)

		-- Fade out after 4 s
		task.delay(4, function()
			TweenService:Create(banner, TweenInfo.new(0.5, Enum.EasingStyle.Quad),
				{ BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			task.delay(0.6, function() banner:Destroy() end)
		end)
	else
		-- Death flash: full-screen red vignette
		local flash = Instance.new("Frame")
		flash.Name                   = "DeathFlash"
		flash.Size                   = UDim2.new(1, 0, 1, 0)
		flash.BackgroundColor3       = Color3.fromRGB(200, 30, 30)
		flash.BackgroundTransparency = 0.45
		flash.BorderSizePixel        = 0
		flash.Parent                 = screenGui

		TweenService:Create(flash,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }):Play()
		task.delay(1, function() flash:Destroy() end)
	end
end)