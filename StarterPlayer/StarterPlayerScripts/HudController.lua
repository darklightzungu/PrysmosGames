local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Build ScreenGui ───────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ── Utility: create a rounded frame ─────────────────────────────────────────
local function makeFrame(name, size, position, color, parent)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = f
	f.Parent = parent
	return f
end

local function makeLabel(name, text, size, position, textColor, fontSize, parent)
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Size = size
	lbl.Position = position
	lbl.Text = text
	lbl.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	lbl.TextSize = fontSize or 16
	lbl.Font = Enum.Font.GothamBold
	lbl.BackgroundTransparency = 1
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = parent
	return lbl
end

-- ── Top bar: semi-transparent strip ─────────────────────────────────────────
local topBar = makeFrame(
	"TopBar",
	UDim2.new(1, 0, 0, 48),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(15, 15, 25),
	screenGui
)
topBar.BackgroundTransparency = 0.35

-- Game title
local titleLabel = makeLabel(
	"Title",
	"ROUTE RAGE",
	UDim2.new(0, 200, 1, 0),
	UDim2.new(0, 12, 0, 0),
	Color3.fromRGB(255, 200, 50),
	22,
	topBar
)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Round timer (center of top bar)
local roundTimer = makeLabel(
	"RoundTimer",
	"0:00",
	UDim2.new(0, 120, 1, 0),
	UDim2.new(0.5, -60, 0, 0),
	Color3.fromRGB(255, 255, 255),
	22,
	topBar
)
roundTimer.TextXAlignment = Enum.TextXAlignment.Center

-- Speed stat (top-right)
local speedLabel = makeLabel(
	"SpeedLabel",
	"SPD: 0",
	UDim2.new(0, 110, 1, 0),
	UDim2.new(1, -120, 0, 0),
	Color3.fromRGB(100, 220, 255),
	18,
	topBar
)
speedLabel.TextXAlignment = Enum.TextXAlignment.Right

-- ── Health bar (bottom-left) ─────────────────────────────────────────────────
local healthBarBg = makeFrame(
	"HealthBar",
	UDim2.new(0, 220, 0, 20),
	UDim2.new(0, 12, 1, -36),
	Color3.fromRGB(40, 40, 40),
	screenGui
)

local healthFill = makeFrame(
	"Fill",
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(80, 200, 80),
	healthBarBg
)

local healthLabel = makeLabel(
	"HealthLabel",
	"HP",
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 4, 0, 0),
	Color3.fromRGB(255, 255, 255),
	14,
	healthBarBg
)
healthLabel.TextXAlignment = Enum.TextXAlignment.Center

-- ── Zone / suburb panel (left side) ─────────────────────────────────────────
local zonePanelBg = makeFrame(
	"ZonePanel",
	UDim2.new(0, 200, 0, 80),
	UDim2.new(0, 12, 0.5, -40),
	Color3.fromRGB(20, 20, 35),
	screenGui
)
zonePanelBg.BackgroundTransparency = 0.35

local zoneTitle = makeLabel(
	"ZoneTitle",
	"ZONE",
	UDim2.new(1, -8, 0, 20),
	UDim2.new(0, 8, 0, 4),
	Color3.fromRGB(255, 200, 50),
	13,
	zonePanelBg
)

local zoneNameLabel = makeLabel(
	"ZoneName",
	"Starter Suburbs",
	UDim2.new(1, -8, 0, 24),
	UDim2.new(0, 8, 0, 22),
	Color3.fromRGB(255, 255, 255),
	16,
	zonePanelBg
)

local suburbProgressLabel = makeLabel(
	"SuburbProgress",
	"Progress: 0%",
	UDim2.new(1, -8, 0, 20),
	UDim2.new(0, 8, 0, 50),
	Color3.fromRGB(180, 180, 180),
	13,
	zonePanelBg
)

-- ── Road network panel (right side) ─────────────────────────────────────────
local roadPanelBg = makeFrame(
	"RoadPanel",
	UDim2.new(0, 200, 0, 100),
	UDim2.new(1, -212, 0.5, -50),
	Color3.fromRGB(20, 20, 35),
	screenGui
)
roadPanelBg.BackgroundTransparency = 0.35

local roadTitle = makeLabel(
	"RoadTitle",
	"ROAD NETWORK",
	UDim2.new(1, -8, 0, 20),
	UDim2.new(0, 8, 0, 4),
	Color3.fromRGB(100, 220, 255),
	13,
	roadPanelBg
)

local currentRoadLabel = makeLabel(
	"CurrentRoad",
	"Road: —",
	UDim2.new(1, -8, 0, 20),
	UDim2.new(0, 8, 0, 24),
	Color3.fromRGB(255, 255, 255),
	15,
	roadPanelBg
)

local shortcutLabel = makeLabel(
	"ShortcutLabel",
	"Shortcut: None",
	UDim2.new(1, -8, 0, 20),
	UDim2.new(0, 8, 0, 46),
	Color3.fromRGB(120, 255, 120),
	14,
	roadPanelBg
)

local shortcutUnlockedLabel = makeLabel(
	"ShortcutsUnlocked",
	"Unlocked: 0",
	UDim2.new(1, -8, 0, 20),
	UDim2.new(0, 8, 0, 68),
	Color3.fromRGB(180, 180, 180),
	13,
	roadPanelBg
)

-- ── Shortcut notification (center, fades in/out) ─────────────────────────────
local shortcutNotif = makeFrame(
	"ShortcutNotif",
	UDim2.new(0, 320, 0, 50),
	UDim2.new(0.5, -160, 0, 60),
	Color3.fromRGB(30, 180, 80),
	screenGui
)
shortcutNotif.BackgroundTransparency = 1

local shortcutNotifLabel = makeLabel(
	"ShortcutNotifText",
	"🔓 Shortcut Unlocked!",
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(255, 255, 255),
	20,
	shortcutNotif
)
shortcutNotifLabel.TextXAlignment = Enum.TextXAlignment.Center

-- ── Terrain generation progress bar (bottom-center) ─────────────────────────
local terrainBarBg = makeFrame(
	"TerrainBar",
	UDim2.new(0, 300, 0, 18),
	UDim2.new(0.5, -150, 1, -28),
	Color3.fromRGB(40, 40, 40),
	screenGui
)

local terrainFill = makeFrame(
	"TerrainFill",
	UDim2.new(0, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(255, 160, 40),
	terrainBarBg
)

local terrainLabel = makeLabel(
	"TerrainLabel",
	"Terrain: Generating...",
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(255, 255, 255),
	13,
	terrainBarBg
)
terrainLabel.TextXAlignment = Enum.TextXAlignment.Center

-- ── TweenInfo presets ────────────────────────────────────────────────────────
local tweenFast  = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenSlow  = TweenInfo.new(0.6,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenFade  = TweenInfo.new(0.4,  Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- ── Health bar logic ─────────────────────────────────────────────────────────
local function updateHealth(health, maxHealth)
	local pct = math.clamp(health / maxHealth, 0, 1)
	local targetColor
	if pct > 0.6 then
		targetColor = Color3.fromRGB(80, 200, 80)
	elseif pct > 0.3 then
		targetColor = Color3.fromRGB(230, 180, 0)
	else
		targetColor = Color3.fromRGB(220, 50, 50)
	end
	TweenService:Create(healthFill, tweenFast, {
		Size = UDim2.new(pct, 0, 1, 0),
		BackgroundColor3 = targetColor,
	}):Play()
	healthLabel.Text = string.format("HP  %d / %d", math.ceil(health), math.ceil(maxHealth))
end

-- ── Character connection helper ───────────────────────────────────────────────
local function connectCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.HealthChanged:Connect(function(health)
		updateHealth(health, humanoid.MaxHealth)
	end)
	updateHealth(humanoid.Health, humanoid.MaxHealth)
end

local character = player.Character
if character then
	connectCharacter(character)
end
player.CharacterAdded:Connect(function(char)
	connectCharacter(char)
end)

-- ── RemoteEvents ─────────────────────────────────────────────────────────────
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- UpdateTimer  →  (secondsLeft: number)
local updateTimerEvent = remotes:WaitForChild("UpdateTimer")
updateTimerEvent.OnClientEvent:Connect(function(secondsLeft)
	local m = math.floor(secondsLeft / 60)
	local s = secondsLeft % 60
	roundTimer.Text = string.format("%d:%02d", m, s)
	local flash = secondsLeft <= 10
	TweenService:Create(roundTimer, tweenFade, {
		TextColor3 = flash and Color3.fromRGB(220, 50, 50) or Color3.fromRGB(255, 255, 255),
	}):Play()
end)

-- UpdateSpeed  →  (speed: number)
local updateSpeedEvent = remotes:WaitForChild("UpdateSpeed")
updateSpeedEvent.OnClientEvent:Connect(function(speed)
	speedLabel.Text = string.format("SPD: %d", math.floor(speed))
	-- brief highlight when speed changes
	TweenService:Create(speedLabel, tweenFast, {
		TextColor3 = Color3.fromRGB(255, 240, 100),
	}):Play()
	task.delay(0.4, function()
		TweenService:Create(speedLabel, tweenSlow, {
			TextColor3 = Color3.fromRGB(100, 220, 255),
		}):Play()
	end)
end)

-- UpdateZone  →  (zoneName: string, progressPercent: number)
local updateZoneEvent = remotes:WaitForChild("UpdateZone")
updateZoneEvent.OnClientEvent:Connect(function(zoneName, progressPercent)
	zoneNameLabel.Text = zoneName or "Unknown"
	local pct = math.clamp(progressPercent or 0, 0, 100)
	suburbProgressLabel.Text = string.format("Progress: %d%%", pct)
end)

-- UpdateRoad  →  (roadName: string)
local updateRoadEvent = remotes:WaitForChild("UpdateRoad")
updateRoadEvent.OnClientEvent:Connect(function(roadName)
	currentRoadLabel.Text = "Road: " .. (roadName or "—")
end)

-- UpdateShortcut  →  (shortcutName: string, totalUnlocked: number)
local updateShortcutEvent = remotes:WaitForChild("UpdateShortcut")
updateShortcutEvent.OnClientEvent:Connect(function(shortcutName, totalUnlocked)
	shortcutLabel.Text = "Shortcut: " .. (shortcutName or "None")
	shortcutUnlockedLabel.Text = string.format("Unlocked: %d", totalUnlocked or 0)

	-- Pop-up notification
	if shortcutName then
		shortcutNotifLabel.Text = "🔓 " .. shortcutName .. " Unlocked!"
		-- fade in
		TweenService:Create(shortcutNotif, tweenFade, {
			BackgroundTransparency = 0.25,
		}):Play()
		TweenService:Create(shortcutNotifLabel, tweenFade, {
			TextTransparency = 0,
		}):Play()
		-- fade out after 2.5 s
		task.delay(2.5, function()
			TweenService:Create(shortcutNotif, tweenSlow, {
				BackgroundTransparency = 1,
			}):Play()
			TweenService:Create(shortcutNotifLabel, tweenSlow, {
				TextTransparency = 1,
			}):Play()
		end)
	end
end)

-- UpdateTerrain  →  (progressPercent: number, statusText: string)
local updateTerrainEvent = remotes:WaitForChild("UpdateTerrain")
updateTerrainEvent.OnClientEvent:Connect(function(progressPercent, statusText)
	local pct = math.clamp(progressPercent or 0, 0, 100)
	local fillRatio = pct / 100
	TweenService:Create(terrainFill, tweenSlow, {
		Size = UDim2.new(fillRatio, 0, 1, 0),
	}):Play()
	terrainLabel.Text = statusText or string.format("Terrain: %d%%", pct)
	-- hide bar when fully generated
	if pct >= 100 then
		task.delay(1.5, function()
			TweenService:Create(terrainBarBg, tweenFade, {
				BackgroundTransparency = 1,
			}):Play()
			TweenService:Create(terrainLabel, tweenFade, {
				TextTransparency = 1,
			}):Play()
		end)
	end
end)