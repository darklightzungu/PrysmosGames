-- HudBase.client.lua — delivery HUD + throw
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
-- Camera may not exist immediately; guard all usages below
local camera = workspace.CurrentCamera

-- Wait for RemoteEvent folder with a generous timeout
local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
assert(remotes, "[DeliveryHUD] Remotes folder not found in ReplicatedStorage")

local throwPaper      = remotes:WaitForChild("ThrowPaper",      15)
local updateScore     = remotes:WaitForChild("UpdateScore",     15)
local showMessage     = remotes:WaitForChild("ShowMessage",     15)
local subscriberUpdate = remotes:WaitForChild("SubscriberUpdate", 15)
local runComplete     = remotes:WaitForChild("RunComplete",     15)

-- ── GUI root ──────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name           = "DeliveryHUD"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling  -- predictable draw order
gui.Parent         = player:WaitForChild("PlayerGui")

-- ── Helper: create a styled TextLabel ────────────────────────────────────────
local function makeLabel(name, size, pos, text)
    local lbl = Instance.new("TextLabel")
    lbl.Name                  = name
    lbl.Size                  = size
    lbl.Position              = pos
    lbl.AnchorPoint           = Vector2.new(0, 0)
    lbl.BackgroundTransparency = 0.3
    lbl.BackgroundColor3      = Color3.fromRGB(30, 30, 40)
    lbl.TextColor3            = Color3.fromRGB(255, 255, 255)
    lbl.Font                  = Enum.Font.GothamBold
    lbl.TextSize              = 20
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.Text                  = text
    lbl.BorderSizePixel       = 0
    lbl.Parent                = gui

    -- Rounded corners via UICorner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent       = lbl

    -- Subtle padding via UIPadding
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft  = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent       = lbl

    return lbl
end

-- ── HUD elements ──────────────────────────────────────────────────────────────
local scoreLabel = makeLabel(
    "ScoreLabel",
    UDim2.new(0, 200, 0, 44),
    UDim2.new(0, 12, 0, 12),
    "Score: 0"
)

local subsLabel = makeLabel(
    "SubsLabel",
    UDim2.new(0, 320, 0, 44),
    UDim2.new(0, 12, 0, 62),
    "Subs: 0 | Lives: 3 | Papers: 0"
)

-- Toast notification (centred, near bottom)
local toast = makeLabel(
    "ToastLabel",
    UDim2.new(0, 420, 0, 44),
    UDim2.new(0.5, -210, 1, -70),
    ""
)
toast.TextXAlignment        = Enum.TextXAlignment.Center
toast.BackgroundColor3      = Color3.fromRGB(20, 20, 30)
toast.BackgroundTransparency = 0.15
toast.Visible               = false

-- ── Toast helper with fade-out tween ─────────────────────────────────────────
local toastThread: thread? = nil  -- track active dismiss thread

local function showToast(msg: string, duration: number?)
    duration = duration or 2.5

    toast.Text    = msg
    toast.Visible = true
    toast.TextTransparency = 0  -- reset in case previous fade left it partial

    -- Cancel any pending dismiss from a previous toast
    if toastThread then
        task.cancel(toastThread)
        toastThread = nil
    end

    toastThread = task.delay(duration, function()
        -- Fade out smoothly
        local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(toast, tweenInfo, { TextTransparency = 1 })
        tween:Play()
        tween.Completed:Wait()
        toast.Visible = false
        toast.TextTransparency = 0  -- reset for next use
        toastThread = nil
    end)
end

-- ── Remote event listeners ────────────────────────────────────────────────────
updateScore.OnClientEvent:Connect(function(score)
    -- Validate incoming data before display
    if type(score) ~= "number" then return end
    scoreLabel.Text = string.format("Score: %d", score)
end)

subscriberUpdate.OnClientEvent:Connect(function(subs, lives, papers)
    if type(subs) ~= "number" or type(lives) ~= "number" or type(papers) ~= "number" then
        return
    end
    subsLabel.Text = string.format("Subs: %d | Lives: %d | Papers: %d", subs, lives, papers)
end)

showMessage.OnClientEvent:Connect(function(msg)
    if type(msg) ~= "string" or msg == "" then return end
    showToast(msg)
end)

runComplete.OnClientEvent:Connect(function(score, bucks, reason)
    if type(score) ~= "number" or type(bucks) ~= "number" then return end
    local reasonStr = type(reason) == "string" and reason or "Run Over!"
    -- Keep the end-of-run toast visible longer so players can read it
    showToast(string.format("%s  Score: %d  (+%d bucks)", reasonStr, score, bucks), 5)
end)

-- ── Throw input ───────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    -- Ignore if UI element consumed the input (e.g. chat box)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

    -- Guard against missing character hierarchy
    local char = player.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Re-read camera each frame in case it was replaced
    local cam = workspace.CurrentCamera
    if not cam then return end

    local mousePos = UserInputService:GetMouseLocation()
    -- ViewportPointToRay returns a Ray with a unit Direction
    local ray = cam:ViewportPointToRay(mousePos.X, mousePos.Y)

    -- Fire from slightly above HRP so the paper clears the character geometry
    local origin = hrp.Position + Vector3.new(0, 2, 0)
    throwPaper:FireServer(origin, ray.Direction)
end)