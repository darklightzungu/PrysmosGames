```lua
-- =============================================================================
-- Monetisation System: Gamepass & Developer Products
-- Genre: Action | Mechanics: Combat, Quests
-- =============================================================================
-- Structure:
--   ServerScriptService/MonetisationServer.server.lua  (this file handles both)
--   LocalScript portion is separated via a comment boundary and should be
--   placed in StarterPlayerScripts/MonetisationClient.client.lua
-- =============================================================================

-- ██████████████████████████████████████████████████████████████████████████
-- SERVER SCRIPT  (place in ServerScriptService as MonetisationServer.server.lua)
-- ██████████████████████████████████████████████████████████████████████████
local ServerScriptService = game:GetService("ServerScriptService")
local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")

-- ── Guard: only run on server ──────────────────────────────────────────────
if RunService:IsClient() then
    error("MonetisationServer must run on the server.")
end

-- ══════════════════════════════════════════════════════════════════════════
-- CONSTANTS
-- ══════════════════════════════════════════════════════════════════════════
local GAMEPASS_IDS = {
    DoubleXP        = GAMEPASS_ID_PLACEHOLDER,   -- 2× XP from combat & quests
    VIPCombat       = GAMEPASS_ID_PLACEHOLDER,   -- Unlocks VIP combat abilities
    QuestMaster     = GAMEPASS_ID_PLACEHOLDER,   -- Unlocks exclusive quest line
    ExtraLoadout    = GAMEPASS_ID_PLACEHOLDER,   -- +2 loadout slots
}

local DEVPRODUCT_IDS = {
    HealthBoost     = DEVPRODUCT_ID_PLACEHOLDER, -- Instant full HP restore
    XPBoost1Hour    = DEVPRODUCT_ID_PLACEHOLDER, -- 1-hour 2× XP boost
    BonusQuestSkip  = DEVPRODUCT_ID_PLACEHOLDER, -- Skip current quest stage
    CombatBundle    = DEVPRODUCT_ID_PLACEHOLDER, -- 500 combat coins
}

-- Active timed boosts: [userId] = { boostName = expireTime }
local activeBoosts: { [number]: { [string]: number } } = {}

-- ══════════════════════════════════════════════════════════════════════════
-- REMOTE EVENT SETUP  (creates or reuses events in ReplicatedStorage)
-- ══════════════════════════════════════════════════════════════════════════
local function getOrCreate(parent: Instance, className: string, name: string): Instance
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA(className) then
        return existing
    end
    local obj = Instance.new(className)
    obj.Name   = name
    obj.Parent = parent
    return obj
end

-- Folder keeps ReplicatedStorage tidy
local remoteFolder: Folder = getOrCreate(ReplicatedStorage, "Folder", "MonetisationRemotes") :: Folder

-- Server → Client notifications
local remoteGrantGamepass: RemoteEvent    = getOrCreate(remoteFolder, "RemoteEvent", "GrantGamepass")    :: RemoteEvent
local remoteGrantProduct: RemoteEvent     = getOrCreate(remoteFolder, "RemoteEvent", "GrantProduct")     :: RemoteEvent
local remoteBoostStatus: RemoteEvent      = getOrCreate(remoteFolder, "RemoteEvent", "BoostStatus")      :: RemoteEvent

-- Client → Server purchase requests (client calls MPS directly, but we also
-- expose a RemoteFunction so the UI can query ownership)
local remoteFnOwnsGamepass: RemoteFunction = getOrCreate(remoteFolder, "RemoteFunction", "OwnsGamepass")  :: RemoteFunction
local remoteFnGetBoosts: RemoteFunction    = getOrCreate(remoteFolder, "RemoteFunction", "GetBoosts")     :: RemoteFunction

-- ══════════════════════════════════════════════════════════════════════════
-- UTILITY HELPERS
-- ══════════════════════════════════════════════════════════════════════════
local function safeGetPlayer(userId: number): Player?
    return Players:GetPlayerByUserId(userId)
end

--- Checks if a player currently owns a named gamepass (with pcall safety).
local function playerOwnsGamepass(player: Player, passName: string): boolean
    local id = GAMEPASS_IDS[passName]
    if not id then return false end
    local ok, result = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
    end)
    return ok and result == true
end

--- Returns remaining boost seconds (0 if none).
local function getRemainingBoost(userId: number, boostName: string): number
    local userBoosts = activeBoosts[userId]
    if not userBoosts then return 0 end
    local expireTime = userBoosts[boostName]
    if not expireTime then return 0 end
    local remaining = expireTime - os.time()
    return math.max(0, remaining)
end

--- Applies a timed boost for `duration` seconds.
local function applyTimedBoost(userId: number, boostName: string, duration: number)
    if not activeBoosts[userId] then
        activeBoosts[userId] = {}
    end
    -- Stack with any existing time
    local current = getRemainingBoost(userId, boostName)
    activeBoosts[userId][boostName] = os.time() + current + duration

    local player = safeGetPlayer(userId)
    if player then
        remoteBoostStatus:FireClient(player, boostName, activeBoosts[userId][boostName])
    end
end

-- ══════════════════════════════════════════════════════════════════════════
-- GAMEPASS PERKS APPLICATION
-- ══════════════════════════════════════════════════════════════════════════
--- Called on join and after a gamepass is purchased to apply persistent perks.
local function applyGamepassPerks(player: Player)
    -- DoubleXP: tag the player's leaderstats / character attributes so other
    --           systems can read it without importing this module.
    if playerOwnsGamepass(player, "DoubleXP") then
        player:SetAttribute("HasDoubleXP", true)
    end

    -- VIPCombat: unlocks special combat moves flagged in the combat system
    if playerOwnsGamepass(player, "VIPCombat") then
        player:SetAttribute("HasVIPCombat", true)
    end

    -- QuestMaster: unlocks the exclusive quest chain
    if playerOwnsGamepass(player, "QuestMaster") then
        player:SetAttribute("HasQuestMaster", true)
    end

    -- ExtraLoadout: increases allowed loadout count
    if playerOwnsGamepass(player, "ExtraLoadout") then
        player:SetAttribute("ExtraLoadoutSlots", 2)
    end
end

-- ══════════════════════════════════════════════════════════════════════════
-- DEVELOPER PRODUCT FULFILLMENT
-- ══════════════════════════════════════════════════════════════════════════
--- Fulfill purchased developer products.  Must return Enum.ProductPurchaseDecision.
MarketplaceService.ProcessReceipt = function(receiptInfo: { [string]: any })
    local userId    = receiptInfo.PlayerId
    local productId = receiptInfo.ProductId
    local player    = safeGetPlayer(userId)

    -- If player left, we cannot fulfill right now; return NotProcessedYet so
    -- Roblox retries when they rejoin.
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- ── HealthBoost ────────────────────────────────────────────────────────
    if productId == DEVPRODUCT_IDS.HealthBoost then
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.Health = humanoid.MaxHealth
            end
        end
        remoteGrantProduct:FireClient(player, "HealthBoost")
        return Enum.ProductPurchaseDecision.PurchaseGranted

    -- ── XPBoost1Hour ───────────────────────────────────────────────────────
    elseif productId == DEVPRODUCT_IDS.XPBoost1Hour then
        applyTimedBoost(userId, "XPBoost", 3600) -- 1 hour
        remoteGrantProduct:FireClient(player, "XPBoost1Hour")
        return Enum.ProductPurchaseDecision.PurchaseGranted

    -- ── BonusQuestSkip ─────────────────────────────────────────────────────
    elseif productId == DEVPRODUCT_IDS.BonusQuestSkip then
        -- Signal the quest system via attribute; quest system should listen
        -- for this attribute change and advance the stage.
        local skipCount = (player:GetAttribute("QuestSkipsAvailable") or 0) + 1
        player:SetAttribute("QuestSkipsAvailable", skipCount)
        remoteGrantProduct:FireClient(player, "BonusQuestSkip")
        return Enum.ProductPurchaseDecision.PurchaseGranted

    -- ── CombatBundle ───────────────────────────────────────────────────────
    elseif productId == DEVPRODUCT_IDS.CombatBundle then
        local current = player:GetAttribute("CombatCoins") or 0
        player:SetAttribute("CombatCoins", current + 500)
        remoteGrantProduct:FireClient(player, "CombatBundle", 500)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    -- Unknown product — do not grant, let Roblox retry after a deploy fix.
    warn(string.format("[Monetisation] Unknown ProductId %d for player %s", productId, player.Name))
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- ══════════════════════════════════════════════════════════════════════════
-- GAMEPASS PURCHASE PROMPT HANDLER  (fires when client buys while in-game)
-- ══════════════════════════════════════════════════════════════════════════
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(
    player: Player,
    gamepassId: number,
    wasPurchased: boolean
)
    if not wasPurchased then return end

    -- Find which named pass was bought
    for passName, id in pairs(GAMEPASS_IDS) do
        if id == gamepassId then
            applyGamepassPerks(player)          -- re-apply all (idempotent)
            remoteGrantGamepass:FireClient(player, passName)
            break
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════════════
-- REMOTE FUNCTION HANDLERS
-- ══════════════════════════════════════════════════════════════════════════

--- Client asks: "Do I own gamepass <passName>?"
remoteFnOwnsGamepass.OnServerInvoke = function(player: Player, passName: string): boolean
    if type(passName) ~= "string" then return false end
    return playerOwnsGamepass(player, passName)
end

--- Client asks: "What boosts do I have active?"
remoteFnGetBoosts.OnServerInvoke = function(player: Player): { [string]: number }
    local userBoosts = activeBoosts[player.UserId]
    if not userBoosts then return {} end

    -- Return only boosts that haven't expired, with seconds remaining
    local result: { [string]: number } = {}
    for boostName, expireTime in pairs(userBoosts) do
        local remaining = expireTime - os.time()
        if remaining > 0 then
            result[boostName] = remaining
        end
    end
    return result
end

-- ══════════════════════════════════════════════════════════════════════════
-- PLAYER LIFECYCLE
-- ══════════════════════════════════════════════════════════════════════════
local function onPlayerAdded(player: Player)
    -- Apply perks as soon as the player joins (handles prior purchases)
    applyGamepassPerks(player)

    -- Initialise combat coins if not set (could be DataStore'd in production)
    if player:GetAttribute("CombatCoins") == nil then
        player:SetAttribute("CombatCoins", 0)
    end
end

local function onPlayerRemoving(player: Player)
    -- Clean up boost cache to prevent memory leak on long-running servers
    activeBoosts[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players already in-game (e.g. during Studio testing)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

-- ══════════════════════════════════════════════════════════════════════════
-- PERIODIC BOOST CLEANUP  (every 60 s, remove expired entries)
-- ══════════════════════════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(60)
        local now = os.time()
        for userId, boosts in pairs(activeBoosts) do
            for boostName, expireTime in pairs(boosts) do
                if expireTime <= now then
                    boosts[boostName] = nil
                end
            end
            -- Remove empty tables
            if next(boosts) == nil then
                activeBoosts[userId] = nil
            end
        end
    end
end)

print("[Monetisation] Server module loaded.")


-- ██████████████████████████████████████████████████████████████████████████
--  CLIENT SCRIPT
--  Place the code BELOW into StarterPlayerScripts/MonetisationClient.client.lua
-- ██████████████████████████████████████████████████████████████████████████
--[[
============ MonetisationClient.client.lua ============

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")

if RunService:IsServer() then
    error("MonetisationClient must run on the client.")
end

local localPlayer: Player = Players.LocalPlayer
if not localPlayer then
    error("LocalPlayer is nil – client script initialised too early.")
end

-- ── Remote references ──────────────────────────────────────────────────────
local remoteFolder: Folder = ReplicatedStorage:WaitForChild("MonetisationRemotes", 10) :: Folder
if not remoteFolder then
    error("[MonetisationClient] MonetisationRemotes folder not found.")
end

local remoteGrantGamepass: RemoteEvent     = remoteFolder:WaitForChild("GrantGamepass", 10)  :: RemoteEvent
local remoteGrantProduct: RemoteEvent      = remoteFolder:WaitForChild("GrantProduct", 10)   :: RemoteEvent
local remoteBoostStatus: RemoteEvent       = remoteFolder:WaitForChild("BoostStatus", 10)    :: RemoteEvent
local remoteFnOwnsGamepass: RemoteFunction = remoteFolder:WaitForChild("OwnsGamepass", 10)   :: RemoteFunction
local remoteFnGetBoosts: RemoteFunction    = remoteFolder:WaitForChild("GetBoosts", 10)      :: RemoteFunction

-- ── Gamepass IDs (mirrors server; client uses these to prompt purchases) ───
local GAMEPASS_IDS = {
    DoubleXP