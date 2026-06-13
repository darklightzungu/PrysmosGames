-- HudBase.client.lua — delivery HUD + throw
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
-- Camera may not exist immediately on some platforms; guard with fallback
local camera = workspace.CurrentCamera

-- Wait for the Remotes folder with a generous timeout before proceeding
local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
assert(remotes, "[DeliveryHUD] ReplicatedStorage.Remotes not found – aborting HUD setup")

local throwPaper      = remotes:WaitForChild("ThrowPaper",      15)
local updateScore     = remotes:WaitForChild("UpdateScore",     15)
local showMessage     = remotes:WaitForChild("ShowMessage",     15)
local subscriberUpdate = remotes:WaitForChild("SubscriberUpdate", 15)
local runComplete     = remotes:WaitForChild("RunComplete",     15)

-- ── ScreenGui ──────────────────────────────────────────────────────────────
local playerGui = player:WaitForChild("PlayerGui")

-- Remove any stale HUD from a previous respawn before creating a new one
local existing = playerGui:FindFirstChild("DeliveryHUD")
if existing then
	existing:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name            = "DeliveryHUD"
gui.ResetOnSpawn    = false
gui.DisplayOrder    = 10          -- sit above default Roblox UI layers
gui.IgnoreGuiInset  = false
gui.Parent          = playerGui

-- ── Shared UI corner style ─────────────────────────────────────────────────
local PANEL_COLOR      = Color3.fromRGB(20, 20, 32)
local PANEL_ALPHA      = 0.25     -- BackgroundTransparency
local TEXT_COLOR       = Color3.fromRGB(240, 240, 255)
local ACCENT_COLOR     = Color3.fromRGB(255, 210, 60)
local FONT             = Enum.Font.GothamBold
local CORNER_RADIUS    = UDim.new(0, 8)

-- Helper: create a rounded TextLabel parented to `gui`
local function makeLabel(name, size, position, text)
	local frame = Instance.new("Frame")
	frame.Name                  = name .. "Frame"
	frame.Size                  = size
	frame.Position              = position
	frame.BackgroundColor3      = PANEL_COLOR
	frame.BackgroundTransparency = PANEL_ALPHA
	frame.BorderSizePixel       = 0
	frame.Parent                = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = CORNER_RADIUS
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft   = UDim.new(0, 8)
	padding.PaddingRight  = UDim.new(0, 8)
	padding.Parent = frame

	local lbl = Instance.new("TextLabel")
	lbl.Name                  = name
	lbl.Size                  = UDim2.fromScale(1, 1)
	lbl.Position              = UDim2.fromScale(0, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3            = TEXT_COLOR
	lbl.Font                  = FONT
	lbl.TextSize              = 18
	lbl.TextXAlignment        = Enum.TextXAlignment.Left
	lbl.TextYAlignment        = Enum.TextYAlignment.Center
	lbl.Text                  = text
	lbl.Parent                = frame

	return lbl, frame
end

-- ── Persistent status labels ───────────────────────────────────────────────
local scoreLabel = makeLabel(
	"Score",
	UDim2.new(0, 200, 0, 40),
	UDim2.new(0, 12, 0, 12),
	"Score: 0"
)

local subsLabel = makeLabel(
	"Subs",
	UDim2.new(0, 300, 0, 40),
	UDim2.new(0, 12, 0, 58),
	"Subs: — | Lives: — | Papers: —"
)

-- ── Toast notification (centred, bottom of screen) ────────────────────────
local toastLabel, toastFrame = makeLabel(
	"Toast",
	UDim2.new(0, 440, 0, 44),
	UDim2.new(0.5, -220, 1, -72),
	""
)
toastLabel.TextXAlignment    = Enum.TextXAlignment.Center
toastLabel.TextColor3        = ACCENT_COLOR
toastLabel.TextSize          = 20
toastFrame.BackgroundTransparency = 0.1
toastFrame.Visible           = false

-- Tween presets for toast fade-in / fade-out
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local activeToastThread -- track the pending hide coroutine so it can be cancelled

local function showToast(msg)
	-- Cancel any pending hide task so a new message always shows fully
	if activeToastThread then
		task.cancel(activeToastThread)
		activeToastThread = nil
	end

	toastLabel.Text  = msg
	toastFrame.Visible = true
	-- Snap transparency back to opaque before fading in
	toastFrame.BackgroundTransparency = 0.85
	TweenService:Create(toastFrame, tweenInfo,
		{ BackgroundTransparency = 0.10 }):Play()

	activeToastThread = task.delay(3, function()
		-- Fade out
		local fadeTween = TweenService:Create(toastFrame, tweenInfo,
			{ BackgroundTransparency = 1 })
		fadeTween:Play()
		fadeTween.Completed:Wait()
		toastFrame.Visible = false
		activeToastThread  = nil
	end)
end

-- ── Remote event bindings ─────────────────────────────────────────────────
updateScore.OnClientEvent:Connect(function(score)
	-- Validate type to avoid displaying "Score: nil" on bad server data
	if type(score) == "number" then
		scoreLabel.Text = "Score: " .. tostring(math.floor(score))
	end
end)

subscriberUpdate.OnClientEvent:Connect(function(subs, lives, papers)
	-- Each arg defaults to "?" when nil so the HUD never shows "nil"
	subsLabel.Text = string.format(
		"Subs: %s | Lives: %s | Papers: %s",
		tostring(subs   or "?"),
		tostring(lives  or "?"),
		tostring(papers or "?")
	)
end)

showMessage.OnClientEvent:Connect(function(msg)
	if type(msg) == "string" and #msg > 0 then
		showToast(msg)
	end
end)

runComplete.OnClientEvent:Connect(function(score, bucks, reason)
	local safeReason = tostring(reason or "Run over!")
	local safeScore  = math.floor(tonumber(score) or 0)
	local safeBucks  = math.floor(tonumber(bucks)  or 0)
	showToast(string.format("%s — Score: %d (+%d 💰)", safeReason, safeScore, safeBucks))
end)

-- ── Throw paper on left mouse click ───────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Ignore inputs swallowed by GUI elements (chat box, buttons, etc.)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

	-- Guard: character and root part must both exist
	local char = player.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Guard: camera reference can become nil briefly during a teleport
	local cam = workspace.CurrentCamera
	if not cam then return end

	local mousePos = UserInputService:GetMouseLocation()
	-- ViewportPointToRay returns a Ray; Direction is already unit-length
	local ray = cam:ViewportPointToRay(mousePos.X, mousePos.Y)

	-- Spawn slightly above the root so the paper clears the character mesh
	local spawnPos = hrp.Position + Vector3.new(0, 2, 0)
	throwPaper:FireServer(spawnPos, ray.Direction)
end)