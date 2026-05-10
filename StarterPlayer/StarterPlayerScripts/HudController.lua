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

-- ── Utility: make a Frame ────────────────────────────────────────────────────
local function makeFrame(name, size, position, color, parent, transparency)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = color or Color3.fromRGB(30, 30, 30)
	f.BackgroundTransparency = transparency or 0.35
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- ── Utility: make a TextLabel ────────────────────────────────────────────────
local function makeLabel(name, text, size, position, parent, fontSize)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.fromRGB(255, 255, 255)
	l.Font = Enum.Font.GothamBold
	l.TextSize = fontSize or 16
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

-- ── Utility: make a TextButton ───────────────────────────────────────────────
local function makeButton(name, text, size, position, color, parent)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = color or Color3.fromRGB(60, 120, 200)
	b.BackgroundTransparency = 0.2
	b.BorderSizePixel = 0
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.Parent = parent
	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = b
	return b
end

-- ── Corner helper ────────────────────────────────────────────────────────────
local function addCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
end

-- ══════════════════════════════════════════════════════════════════════════════
-- HEALTH BAR (top-left)
-- ══════════════════════════════════════════════════════════════════════════════
local healthBarBg = makeFrame("HealthBarBg",
	UDim2.new(0, 220, 0, 22),
	UDim2.new(0, 16, 0, 16),
	Color3.fromRGB(20, 20, 20), screenGui, 0.3)
addCorner(healthBarBg, 8)

local healthFill = makeFrame("HealthFill",
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(80, 200, 80), healthBarBg, 0)
addCorner(healthFill, 8)

local healthLabel = makeLabel("HealthLabel", "HP  100 / 100",
	UDim2.new(1, 0, 1, 0), UDim2.new(0, 6, 0, 0), healthBarBg, 13)
healthLabel.TextXAlignment = Enum.TextXAlignment.Center
healthLabel.ZIndex = 3

-- ══════════════════════════════════════════════════════════════════════════════
-- STAT PANEL (below health bar) — world-builder & route info
-- ══════════════════════════════════════════════════════════════════════════════
local statPanel = makeFrame("StatPanel",
	UDim2.new(0, 220, 0, 130),
	UDim2.new(0, 16, 0, 46),
	Color3.fromRGB(15, 15, 15), screenGui, 0.3)
addCorner(statPanel, 8)

-- Route Rage coins / build points
local coinsLabel     = makeLabel("CoinsLabel",     "🪙 Coins: 0",
	UDim2.new(1, -10, 0, 22), UDim2.new(0, 8, 0, 4),  statPanel, 14)
-- Suburb / zone name
local zoneLabel      = makeLabel("ZoneLabel",      "📍 Zone: Starter Suburbs",
	UDim2.new(1, -10, 0, 22), UDim2.new(0, 8, 0, 28), statPanel, 13)
-- Active hazard count
local hazardLabel    = makeLabel("HazardLabel",    "⚠️  Hazards: 0",
	UDim2.new(1, -10, 0, 22), UDim2.new(0, 8, 0, 52), statPanel, 13)
-- Shortcut bonus
local shortcutLabel  = makeLabel("ShortcutLabel",  "⚡ Shortcuts: 0",
	UDim2.new(1, -10, 0, 22), UDim2.new(0, 8, 0, 76), statPanel, 13)
-- Spawn pad cooldown
local spawnPadLabel  = makeLabel("SpawnPadLabel",  "🔵 Spawn Pad: Ready",
	UDim2.new(1, -10, 0, 22), UDim2.new(0, 8, 0, 100), statPanel, 13)

-- ══════════════════════════════════════════════════════════════════════════════
-- NOTIFICATION BANNER (centre-top) — hazard alerts, shortcut unlocks
-- ══════════════════════════════════════════════════════════════════════════════
local notifBg = makeFrame("NotifBg",
	UDim2.new(0, 320, 0, 36),
	UDim2.new(0.5, -160, 0, 12),
	Color3.fromRGB(220, 140, 0), screenGui, 0)
addCorner(notifBg, 10)
notifBg.Visible = false

local notifLabel = makeLabel("NotifLabel", "",
	UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), notifBg, 15)
notifLabel.TextXAlignment = Enum.TextXAlignment.Center

-- ══════════════════════════════════════════════════════════════════════════════
-- ACTION BUTTONS (bottom-centre) — world-builder tools
-- ══════════════════════════════════════════════════════════════════════════════
local buttonRow = makeFrame("ButtonRow",
	UDim2.new(0, 430, 0, 52),
	UDim2.new(0.5, -215, 1, -68),
	Color3.fromRGB(10, 10, 10), screenGui, 0.4)
addCorner(buttonRow, 10)

local btnPlaceProp   = makeButton("BtnPlaceProp",   "🏗️ Place Prop",
	UDim2.new(0, 130, 0, 36), UDim2.new(0, 8,   0, 8),
	Color3.fromRGB(50, 130, 220), buttonRow)

local btnSetSpawn    = makeButton("BtnSetSpawn",    "🔵 Set Spawn",
	UDim2.new(0, 120, 0, 36), UDim2.new(0, 148, 0, 8),
	Color3.fromRGB(40, 160, 100), buttonRow)

local btnHazard      = makeButton("BtnHazard",      "⚠️ Hazard",
	UDim2.new(0, 110, 0, 36), UDim2.new(0, 278, 0, 8),
	Color3.fromRGB(200, 70, 50), buttonRow)

-- ══════════════════════════════════════════════════════════════════════════════
-- MINIMAP PLACEHOLDER (top-right) — shows suburb layout hint
-- ══════════════════════════════════════════════════════════════════════════════
local minimapBg = makeFrame("MinimapBg",
	UDim2.new(0, 130, 0, 130),
	UDim2.new(1, -146, 0, 16),
	Color3.fromRGB(20, 20, 20), screenGui, 0.25)
addCorner(minimapBg, 10)

local minimapLabel = makeLabel("MinimapLabel", "MAP",
	UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), minimapBg, 13)
minimapLabel.TextXAlignment = Enum.TextXAlignment.Center
minimapLabel.TextColor3 = Color3.fromRGB(160, 160, 160)

-- ══════════════════════════════════════════════════════════════════════════════
-- REMOTES
-- ══════════════════════════════════════════════════════════════════════════════
local remotes         = ReplicatedStorage:WaitForChild("Remotes")
local updateHealth    = remotes:WaitForChild("UpdateHealth")
local updateCoins     = remotes:WaitForChild("UpdateCoins")
local updateZone      = remotes:WaitForChild("UpdateZone")
local updateHazards   = remotes:WaitForChild("UpdateHazards")
local updateShortcuts = remotes:WaitForChild("UpdateShortcuts")
local updateSpawnPad  = remotes:WaitForChild("UpdateSpawnPad")
local sendNotif       = remotes:WaitForChild("SendNotification")
local placePropRemote = remotes:WaitForChild("PlaceProp")
local setSpawnRemote  = remotes:WaitForChild("SetSpawnPad")
local placeHazardRemote = remotes:WaitForChild("PlaceHazard")

-- ══════════════════════════════════════════════════════════════════════════════
-- HEALTH BAR LOGIC
-- ══════════════════════════════════════════════════════════════════════════════
local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function applyHealthVisuals(health, maxHealth)
	local pct = math.clamp(health / maxHealth, 0, 1)
	local targetSize = UDim2.new(pct, 0, 1, 0)

	-- Colour based on percentage
	local fillColor
	if pct > 0.6 then
		fillColor = Color3.fromRGB(80, 200, 80)
	elseif pct > 0.3 then
		fillColor = Color3.fromRGB(230, 190, 0)
	else
		fillColor = Color3.fromRGB(220, 50, 50)
	end

	TweenService:Create(healthFill, tweenInfo, {
		Size = targetSize,
		BackgroundColor3 = fillColor,
	}):Play()

	healthLabel.Text = string.format("HP  %d / %d", math.ceil(health), maxHealth)
end

local function connectHumanoid(character)
	local humanoid = character:WaitForChild("Humanoid")
	applyHealthVisuals(humanoid.Health, humanoid.MaxHealth)
	humanoid.HealthChanged:Connect(function(hp)
		applyHealthVisuals(hp, humanoid.MaxHealth)
	end)
end

-- ServerSide health sync via remote (authoritative)
updateHealth.OnClientEvent:Connect(function(hp, maxHp)
	applyHealthVisuals(hp, maxHp)
end)

-- Also hook directly into the character humanoid for responsiveness
local character = player.Character or player.CharacterAdded:Wait()
connectHumanoid(character)

player.CharacterAdded:Connect(function(newChar)
	connectHumanoid(newChar)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- STAT LABEL UPDATES
-- ══════════════════════════════════════════════════════════════════════════════
updateCoins.OnClientEvent:Connect(function(amount)
	coinsLabel.Text = "🪙 Coins: " .. tostring(amount)
	-- Briefly highlight
	TweenService:Create(coinsLabel, TweenInfo.new(0.15), {
		TextColor3 = Color3.fromRGB(255, 230, 50),
	}):Play()
	task.delay(0.5, function()
		TweenService:Create(coinsLabel, TweenInfo.new(0.3), {
			TextColor3 = Color3.fromRGB(255, 255, 255),
		}):Play()
	end)
end)

updateZone.OnClientEvent:Connect(function(zoneName)
	zoneLabel.Text = "📍 Zone: " .. tostring(zoneName)
end)

updateHazards.OnClientEvent:Connect(function(count)
	hazardLabel.Text = "⚠️  Hazards: " .. tostring(count)
	-- Flash orange when a new hazard is added
	local flashColor = count > 0 and Color3.fromRGB(255, 120, 30) or Color3.fromRGB(255, 255, 255)
	TweenService:Create(hazardLabel, TweenInfo.new(0.2), { TextColor3 = flashColor }):Play()
	task.delay(0.6, function()
		TweenService:Create(hazardLabel, TweenInfo.new(0.3), {
			TextColor3 = Color3.fromRGB(255, 255, 255),
		}):Play()
	end)
end)

updateShortcuts.OnClientEvent:Connect(function(count)
	shortcutLabel.Text = "⚡ Shortcuts: " .. tostring(count)
end)

-- spawnPad: receives ("Ready") or ("Cooldown", secondsLeft)
updateSpawnPad.OnClientEvent:Connect(function(state, seconds)
	if state == "Ready" then
		spawnPadLabel.Text = "🔵 Spawn Pad: Ready"
		spawnPadLabel.TextColor3 = Color3.fromRGB(80, 200, 255)
	elseif state == "Cooldown" then
		spawnPadLabel.Text = string.format("🔵 Spawn Pad: %ds", math.ceil(seconds or 0))
		spawnPadLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- NOTIFICATION BANNER
-- ══════════════════════════════════════════════════════════════════════════════
local notifTween = nil

local function showNotification(message, color)
	-- Cancel previous if still visible
	if notifTween then notifTween:Cancel() end

	notifLabel.Text = message
	notifBg.BackgroundColor3 = color or Color3.fromRGB(220, 140, 0)
	notifBg.Visible = true
	notifBg.BackgroundTransparency = 0

	-- Fade out after 2.5 seconds
	task.delay(2.5, function()
		notifTween = TweenService:Create(notifBg, TweenInfo.new(0.6), {
			BackgroundTransparency = 1,
		})
		notifTween:Play()
		notifTween.Completed:Connect(function()
			notifBg.Visible = false
		end)
	end)
end

sendNotif.OnClientEvent:Connect(function(message, colorRGB)
	local c = colorRGB and Color3.fromRGB(colorRGB.r * 255, colorRGB.g * 255, colorRGB.b * 255) or nil
	showNotification(message, c)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- ACTION BUTTON INTERACTIONS (world-builder tools)
-- ══════════════════════════════════════════════════════════════════════════════
local function buttonClickEffect(button)
	local orig = button.BackgroundTransparency
	TweenService:Create(button, TweenInfo.new(0.1), { BackgroundTransparency = 0 }):Play()
	task.delay(0.15, function()
		TweenService:Create(button, TweenInfo.new(0.2), { BackgroundTransparency = 0.2 }):Play()
	end)
end

-- Place a world prop (e.g. barriers, ramps) — server decides placement
btnPlaceProp.MouseButton1Click:Connect(function()
	buttonClickEffect(btnPlaceProp)
	placePropRemote:FireServer()          -- server handles validation & placement
end)

-- Set / activate a spawn pad at player's current position
btnSetSpawn.MouseButton1Click:Connect(function()
	buttonClickEffect(btnSetSpawn)
	setSpawnRemote:FireServer()
end)

-- Drop a hazard prop near the player's current position
btnHazard.MouseButton1Click:Connect(function()
	buttonClickEffect(btnHazard)
	placeHazardRemote:FireServer()
end)

-- Mobile / touch: hover effect via mouse enter/leave (ignored on mobile, harmless)
for _, btn in ipairs({btnPlaceProp, btnSetSpawn, btnHazard}) do
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), {
			BackgroundTransparency = 0.05,
		}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), {
			BackgroundTransparency = 0.2,
		}):Play()
	end)
end