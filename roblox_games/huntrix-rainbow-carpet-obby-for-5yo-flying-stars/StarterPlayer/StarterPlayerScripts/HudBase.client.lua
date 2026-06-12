```lua
-- HUD LocalScript
-- Place in: StarterPlayerScripts or StarterCharacterScripts
-- Handles: Health bar, Quest tracker, Combat indicators, XP bar

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- ============================================================
-- SERVICES & PLAYER REFERENCES
-- ============================================================
local localPlayer = Players.LocalPlayer
if not localPlayer then
	warn("[HUD] LocalPlayer not found – aborting HUD init")
	return
end

local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
if not playerGui then
	warn("[HUD] PlayerGui not found – aborting HUD init")
	return
end

-- ============================================================
-- REMOTE EVENTS (must exist in ReplicatedStorage)
-- ============================================================
local remoteFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	or (function()
		local f = Instance.new("Folder")
		f.Name = "RemoteEvents"
		f.Parent = ReplicatedStorage
		return f
	end)()

local function getOrCreateRemote(name)
	local r = remoteFolder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remoteFolder
	end
	return r
end

local remoteQuestUpdate    = getOrCreateRemote("QuestUpdate")      -- Server → Client: quest data
local remoteXPUpdate       = getOrCreateRemote("XPUpdate")         -- Server → Client: xp/level data
local remoteCombatHit      = getOrCreateRemote("CombatHit")        -- Server → Client: damage dealt/received
local remoteQuestComplete  = getOrCreateRemote("QuestComplete")    -- Server → Client: quest finished
local remoteCombatKill     = getOrCreateRemote("CombatKill")       -- Server → Client: kill notification

-- ============================================================
-- CONSTANTS & CONFIGURATION
-- ============================================================
local CONFIG = {
	HEALTH_TWEEN_TIME      = 0.25,
	XP_TWEEN_TIME          = 0.4,
	DAMAGE_POPUP_LIFETIME  = 1.2,
	KILL_NOTIF_LIFETIME    = 3.0,
	QUEST_NOTIF_LIFETIME   = 4.0,
	MAX_VISIBLE_QUESTS     = 4,
	LOW_HEALTH_THRESHOLD   = 0.3,   -- 30% health triggers warning
	CRITICAL_HEALTH_THRESHOLD = 0.15,
	HUD_PADDING            = 10,
}

local COLORS = {
	HEALTH_FULL    = Color3.fromRGB(80, 200, 80),
	HEALTH_MID     = Color3.fromRGB(220, 180, 40),
	HEALTH_LOW     = Color3.fromRGB(220, 60, 60),
	XP_BAR         = Color3.fromRGB(60, 140, 220),
	XP_BG          = Color3.fromRGB(20, 40, 80),
	DAMAGE_PLAYER  = Color3.fromRGB(255, 80, 80),
	DAMAGE_ENEMY   = Color3.fromRGB(255, 220, 50),
	CRITICAL_HIT   = Color3.fromRGB(255, 140, 0),
	QUEST_ACTIVE   = Color3.fromRGB(255, 200, 50),
	QUEST_COMPLETE = Color3.fromRGB(80, 220, 80),
	BG_DARK        = Color3.fromRGB(15, 15, 20),
	TEXT_WHITE     = Color3.fromRGB(255, 255, 255),
	TEXT_GRAY      = Color3.fromRGB(180, 180, 190),
}

-- ============================================================
-- HUD SCREEN GUI CONSTRUCTION
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name               = "ActionHUD"
screenGui.ResetOnSpawn        = false
screenGui.IgnoreGuiInset      = false
screenGui.ZIndexBehavior      = Enum.ZIndexBehavior.Sibling
screenGui.Parent              = playerGui

-- ── Helper: rounded frame ──────────────────────────────────
local function makeFrame(name, parent, size, pos, bg, alpha, corner)
	local f = Instance.new("Frame")
	f.Name            = name
	f.Size            = size
	f.Position        = pos
	f.BackgroundColor3 = bg or COLORS.BG_DARK
	f.BackgroundTransparency = alpha or 0
	f.BorderSizePixel = 0
	f.Parent          = parent
	if corner then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, corner)
		c.Parent = f
	end
	return f
end

local function makeLabel(name, parent, text, size, pos, color, fontSize, bold, align)
	local l = Instance.new("TextLabel")
	l.Name                  = name
	l.Size                  = size
	l.Position              = pos
	l.Text                  = text
	l.TextColor3            = color or COLORS.TEXT_WHITE
	l.TextSize              = fontSize or 14
	l.Font                  = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.TextXAlignment        = align or Enum.TextXAlignment.Left
	l.BackgroundTransparency = 1
	l.BorderSizePixel        = 0
	l.Parent                = parent
	return l
end

-- ============================================================
-- SECTION 1 ── HEALTH BAR (bottom-left)
-- ============================================================
local healthContainer = makeFrame(
	"HealthContainer", screenGui,
	UDim2.new(0, 280, 0, 50),
	UDim2.new(0, CONFIG.HUD_PADDING, 1, -(60 + CONFIG.HUD_PADDING)),
	COLORS.BG_DARK, 0.45, 10
)

-- Shield/armor icon slot
local healthIcon = makeLabel(
	"HealthIcon", healthContainer, "♥",
	UDim2.new(0, 30, 1, 0), UDim2.new(0, 6, 0, -4),
	Color3.fromRGB(255, 80, 80), 22, true, Enum.TextXAlignment.Center
)

local healthBgBar = makeFrame(
	"HealthBgBar", healthContainer,
	UDim2.new(1, -48, 0, 14),
	UDim2.new(0, 42, 0.5, -7),
	Color3.fromRGB(40, 40, 50), 0, 8
)

local healthFillBar = makeFrame(
	"HealthFillBar", healthBgBar,
	UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
	COLORS.HEALTH_FULL, 0, 8
)

local healthLabel = makeLabel(
	"HealthLabel", healthContainer,
	"100 / 100",
	UDim2.new(1, -48, 0, 14),
	UDim2.new(0, 42, 0.5, -24),
	COLORS.TEXT_WHITE, 11, false, Enum.TextXAlignment.Center
)

-- Pulse overlay for low-health warning
local healthPulseOverlay = Instance.new("Frame")
healthPulseOverlay.Name               = "PulseOverlay"
healthPulseOverlay.Size               = UDim2.new(1, 0, 1, 0)
healthPulseOverlay.BackgroundColor3   = Color3.fromRGB(180, 0, 0)
healthPulseOverlay.BackgroundTransparency = 1
healthPulseOverlay.BorderSizePixel    = 0
healthPulseOverlay.ZIndex             = 10
healthPulseOverlay.Parent             = screenGui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 0)
	c.Parent = healthPulseOverlay
end

-- ============================================================
-- SECTION 2 ── XP / LEVEL BAR (bottom-center)
-- ============================================================
local xpContainer = makeFrame(
	"XPContainer", screenGui,
	UDim2.new(0, 320, 0, 42),
	UDim2.new(0.5, -160, 1, -(52 + CONFIG.HUD_PADDING)),
	COLORS.BG_DARK, 0.45, 10
)

local levelLabel = makeLabel(
	"LevelLabel", xpContainer, "Lv. 1",
	UDim2.new(0, 50, 1, 0), UDim2.new(0, 6, 0, 0),
	COLORS.XP_BAR, 13, true, Enum.TextXAlignment.Center
)

local xpBgBar = makeFrame(
	"XPBgBar", xpContainer,
	UDim2.new(1, -70, 0, 10),
	UDim2.new(0, 58, 0.5, -5),
	COLORS.XP_BG, 0, 6
)

local xpFillBar = makeFrame(
	"XPFillBar", xpBgBar,
	UDim2.new(0, 0, 1, 0), UDim2.new(0, 0, 0, 0),
	COLORS.XP_BAR, 0, 6
)

local xpLabel = makeLabel(
	"XPLabel", xpContainer, "0 / 100 XP",
	UDim2.new(1, -70, 0, 12),
	UDim2.new(0, 58, 0.5, -18),
	COLORS.TEXT_GRAY, 10, false, Enum.TextXAlignment.Center
)

-- ============================================================
-- SECTION 3 ── QUEST TRACKER (right side)
-- ============================================================
local questPanel = makeFrame(
	"QuestPanel", screenGui,
	UDim2.new(0, 240, 0, 20),   -- height expands dynamically
	UDim2.new(1, -(240 + CONFIG.HUD_PADDING), 0, 60 + CONFIG.HUD_PADDING),
	COLORS.BG_DARK, 0.4, 8
)

local questTitle = makeLabel(
	"QuestTitle", questPanel, "🗡  QUESTS",
	UDim2.new(1, -10, 0, 20), UDim2.new(0, 8, 0, 4),
	COLORS.QUEST_ACTIVE, 12, true, Enum.TextXAlignment.Left
)

local questListLayout = Instance.new("UIListLayout")
questListLayout.Padding         = UDim.new(0, 2)
questListLayout.FillDirection   = Enum.FillDirection.Vertical
questListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
questListLayout.VerticalAlignment   = Enum.VerticalAlignment.Top
questListLayout.SortOrder       = Enum.SortOrder.LayoutOrder

local questContentFrame = makeFrame(
	"QuestContentFrame", questPanel,
	UDim2.new(1, -10, 0, 0),   -- height auto
	UDim2.new(0, 5, 0, 26),
	Color3.new(0,0,0), 1
)
questListLayout.Parent = questContentFrame

-- Auto-resize quest panel to content
questListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	local contentH = questListLayout.AbsoluteContentSize.Y
	questContentFrame.Size = UDim2.new(1, -10, 0, contentH)
	questPanel.Size = UDim2.new(0, 240, 0, contentH + 32)
end)

-- Active quest rows: { [questId] = Frame }
local questRows = {}

local function updateQuestRow(questId, data)
	-- data = { name, objective, current, max, complete }
	local row = questRows[questId]
	if not row then
		row = makeFrame(
			"Quest_" .. questId, questContentFrame,
			UDim2.new(1, 0, 0, 38),
			UDim2.new(0, 0, 0, 0),
			Color3.fromRGB(30, 30, 40), 0.3, 4
		)
		row.LayoutOrder = #questRows + 1
		questRows[questId] = row

		makeLabel("QuestName", row, data.name or "Quest",
			UDim2.new(1, -8, 0, 14), UDim2.new(0, 4, 0, 2),
			COLORS.QUEST_ACTIVE, 11, true, Enum.TextXAlignment.Left)

		makeLabel("QuestObj", row, data.objective or "",
			UDim2.new(1, -8, 0, 12), UDim2.new(0, 4, 0, 15),
			COLORS.TEXT_GRAY, 10, false, Enum.TextXAlignment.Left)

		-- Mini progress bar
		local qBg = makeFrame("QBg", row, UDim2.new(1, -8, 0, 5),
			UDim2.new(0, 4, 1, -8),
			Color3.fromRGB(50, 50, 60), 0, 3)
		makeFrame("QFill", qBg, UDim2.new(0, 0, 1, 0), UDim2.new(0,0,0,0),
			COLORS.QUEST_ACTIVE, 0, 3)
	end

	-- Update values
	local nameLabel = row:FindFirstChild("QuestName")
	local objLabel  = row:FindFirstChild("QuestObj")
	local qBg       = row:FindFirstChild("QBg")

	if nameLabel then nameLabel.Text = data.name or "Quest" end
	if objLabel  then objLabel.Text  = data.objective or "" end

	if qBg then
		local qFill = qBg:FindFirstChild("QFill")
		if qFill then
			local pct = (data.max and data.max > 0) and (data.current / data.max) or 0
			pct = math.clamp(pct, 0, 1)
			TweenService:Create(qFill, TweenInfo.new(0.3), {
				Size = UDim2.new(pct, 0, 1, 0)
			}):Play()
			qFill.BackgroundColor3 = data.complete and COLORS.QUEST_COMPLETE or COLORS.QUEST_ACTIVE
		end
	end

	if data.complete then
		-- Grey out row after a moment
		task.delay(1.5, function()
			if row and row.Parent then
				TweenService:Create(row, TweenInfo.new(0.5), {
					BackgroundTransparency = 0.8
				}):Play()
				local nl = row:FindFirstChild("QuestName")
				if nl then nl.TextColor3 = COLORS.TEXT_GRAY end
			end
		end)
	end
end

local function removeQuestRow(questId)
	local row = questRows[questId]
	if