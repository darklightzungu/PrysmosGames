-- Monetisation.server.lua — cosmetic-only (Neo Paperboy)
-- Handles gamepass checks on join, purchase callbacks, and dev product receipts.

local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- ── Placeholder IDs (replace before publishing) ──────────────────────────────
local RAINBOW_PAPER_PASS   = "GAMEPASS_ID_PLACEHOLDER"   -- Rainbow Paper Trail gamepass
local ROUTE_RIDER_PASS     = "GAMEPASS_ID_PLACEHOLDER"   -- Route Rider Cosmetic Pack gamepass
local CHAOS_KING_PRODUCT   = "DEVPRODUCT_ID_PLACEHOLDER" -- Chaos King cosmetic dev product
local DELIVERY_BUCK_PRODUCT = "DEVPRODUCT_ID_PLACEHOLDER" -- Delivery Buck packs dev product
-- ─────────────────────────────────────────────────────────────────────────────

-- RemoteEvents so clients can react to cosmetic grants (e.g. equip effects).
-- Folder is created once here; all other scripts should reference it by path.
local eventsFolder = ReplicatedStorage:FindFirstChild("MonetisationEvents")
    or Instance.new("Folder", ReplicatedStorage)
eventsFolder.Name = "MonetisationEvents"

local function getOrCreateEvent(name: string): RemoteEvent
    local existing = eventsFolder:FindFirstChild(name)
    if existing and existing:IsA("RemoteEvent") then
        return existing
    end
    local re = Instance.new("RemoteEvent")
    re.Name = name
    re.Parent = eventsFolder
    return re
end

local rainbowTrailGranted  = getOrCreateEvent("RainbowTrailGranted")
local routeRiderGranted    = getOrCreateEvent("RouteRiderGranted")
local chaosKingGranted     = getOrCreateEvent("ChaosKingGranted")
local deliveryBuckGranted  = getOrCreateEvent("DeliveryBuckGranted")

-- ── Helpers ───────────────────────────────────────────────────────────────────

--- Safely checks whether a player owns a gamepass.
--- Returns false if the ID is still a placeholder or the API call fails.
local function ownsPass(player: Player, passId: string): boolean
    if passId == "GAMEPASS_ID_PLACEHOLDER" then
        warn(("[Monetisation] ownsPass called with placeholder ID for %s"):format(player.Name))
        return false
    end
    local numericId = tonumber(passId)
    if not numericId then
        warn(("[Monetisation] Non-numeric passId '%s'"):format(passId))
        return false
    end
    local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, numericId)
    if not ok then
        warn(("[Monetisation] UserOwnsGamePassAsync failed for %s (passId %s): %s"):format(player.Name, passId, result))
        return false
    end
    return result == true
end

--- Applies gamepass-derived attributes and fires the matching RemoteEvent to the client.
local function applyPassGrant(player: Player, passId: string)
    if passId == tostring(RAINBOW_PAPER_PASS) then
        player:SetAttribute("RainbowPaperTrail", true)
        rainbowTrailGranted:FireClient(player)

    elseif passId == tostring(ROUTE_RIDER_PASS) then
        player:SetAttribute("RouteRiderPack", true)
        routeRiderGranted:FireClient(player)
    end
end

-- ── Gamepass: grant on join ────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player: Player)
    -- Initialise attributes to false so downstream code never sees nil.
    player:SetAttribute("RainbowPaperTrail", false)
    player:SetAttribute("RouteRiderPack", false)

    -- Ownership checks are async; run them in a separate thread so we don't
    -- stall other PlayerAdded listeners.
    task.spawn(function()
        local hasRainbow   = ownsPass(player, RAINBOW_PAPER_PASS)
        local hasRouteRider = ownsPass(player, ROUTE_RIDER_PASS)

        -- Guard: player may have left while the API call was in flight.
        if not player.Parent then return end

        if hasRainbow then
            player:SetAttribute("RainbowPaperTrail", true)
            rainbowTrailGranted:FireClient(player)
        end
        if hasRouteRider then
            player:SetAttribute("RouteRiderPack", true)
            routeRiderGranted:FireClient(player)
        end
    end)
end)

-- ── Gamepass: grant on purchase ───────────────────────────────────────────────

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
    if not purchased then return end
    -- Guard: player may have left between prompt and callback.
    if not player or not player.Parent then return end
    applyPassGrant(player, tostring(passId))
end)

-- ── Dev products: ProcessReceipt ──────────────────────────────────────────────
-- Only one ProcessReceipt handler can exist per server; all product IDs are
-- handled here.  Always return a decision so Roblox can finalise the transaction.

MarketplaceService.ProcessReceipt = function(receiptInfo: {[string]: any}): Enum.ProductPurchaseDecision
    local productId = tostring(receiptInfo.ProductId)
    local player    = Players:GetPlayerByUserId(receiptInfo.PlayerId)

    -- If the player is not in the server, defer so Roblox retries when they rejoin.
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    if productId == tostring(CHAOS_KING_PRODUCT) then
        -- Chaos King is a cosmetic unlock; grant immediately.
        player:SetAttribute("ChaosKingUnlocked", true)
        chaosKingGranted:FireClient(player)
        return Enum.ProductPurchaseDecision.PurchaseGranted

    elseif productId == tostring(DELIVERY_BUCK_PRODUCT) then
        -- Delivery Bucks are a currency/cosmetic pack; award to the player.
        -- TODO: integrate with your currency datastore here.
        player:SetAttribute("PendingDeliveryBucks", true)
        deliveryBuckGranted:FireClient(player)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    -- Unknown product — do not grant; Roblox will not retry.
    warn(("[Monetisation] Unknown ProductId '%s' for player '%s'"):format(productId, player.Name))
    return Enum.ProductPurchaseDecision.NotProcessedYet
end