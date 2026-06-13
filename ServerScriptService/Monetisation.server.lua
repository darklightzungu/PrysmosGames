-- Monetisation.server.lua — cosmetic-only (Neo Paperboy)
-- Handles gamepass checks on join, purchase callbacks, and dev product receipts.

local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- ── ID Constants ─────────────────────────────────────────────────────────────
-- Replace placeholders with real numeric IDs before publishing.
local RAINBOW_PAPER_PASS_ID  = "GAMEPASS_ID_PLACEHOLDER"   -- Rainbow Paper Trail gamepass
local ROUTE_RIDER_PASS_ID    = "GAMEPASS_ID_PLACEHOLDER"   -- Route Rider cosmetic pack gamepass
local CHAOS_KING_PRODUCT_ID  = "DEVPRODUCT_ID_PLACEHOLDER" -- Chaos King cosmetic dev product
local BUCK_PACK_PRODUCT_ID   = "DEVPRODUCT_ID_PLACEHOLDER" -- Delivery Buck packs dev product

-- ── RemoteEvents (create once, used by LocalScripts to trigger purchase prompts) ─
local remoteFolder = ReplicatedStorage:FindFirstChild("MonetisationRemotes")
	or Instance.new("Folder", ReplicatedStorage)
remoteFolder.Name = "MonetisationRemotes"

local function ensureRemote(name: string): RemoteEvent
	local existing = remoteFolder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local re = Instance.new("RemoteEvent")
	re.Name = name
	re.Parent = remoteFolder
	return re
end

-- Clients fire these to request a purchase prompt from the server
local promptRainbowPaperEvent = ensureRemote("PromptRainbowPaperTrail")
local promptRouteRiderEvent   = ensureRemote("PromptRouteRiderPack")
local promptChaosKingEvent    = ensureRemote("PromptChaosKing")
local promptBuckPackEvent     = ensureRemote("PromptBuckPack")

-- Server fires these to inform clients that an attribute was granted
local cosmeticGrantedEvent    = ensureRemote("CosmeticGranted")

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Returns true only when passId is a real (non-placeholder) numeric string.
local function isValidId(id: string): boolean
	return id ~= "GAMEPASS_ID_PLACEHOLDER"
		and id ~= "DEVPRODUCT_ID_PLACEHOLDER"
		and tonumber(id) ~= nil
end

-- Safely checks whether a player owns a gamepass; returns false on any error.
local function ownsPass(player: Player, passId: string): boolean
	if not isValidId(passId) then
		-- ID not yet configured; treat as unowned to avoid blocking gameplay
		return false
	end
	local ok, result = pcall(
		MarketplaceService.UserOwnsGamePassAsync,
		MarketplaceService,
		player.UserId,
		tonumber(passId)
	)
	if not ok then
		warn(("[Monetisation] ownsPass check failed for %s (pass %s): %s"):format(
			player.Name, passId, tostring(result)
		))
		return false
	end
	return result == true
end

-- Grants a named attribute and notifies the owning client.
local function grantAttribute(player: Player, attribute: string)
	player:SetAttribute(attribute, true)
	-- Inform the client so it can apply visual changes immediately
	cosmeticGrantedEvent:FireClient(player, attribute)
end

-- ── Player Join ───────────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player: Player)
	-- Restore persistent gamepass cosmetics on every join
	if ownsPass(player, RAINBOW_PAPER_PASS_ID) then
		grantAttribute(player, "RainbowPaperTrail")
	else
		player:SetAttribute("RainbowPaperTrail", false)
	end

	if ownsPass(player, ROUTE_RIDER_PASS_ID) then
		grantAttribute(player, "RouteRiderPack")
	else
		player:SetAttribute("RouteRiderPack", false)
	end
end)

-- ── Gamepass Purchase Finished ────────────────────────────────────────────────

MarketplaceService.PromptGamePassPurchaseFinished:Connect(
	function(player: Player, passId: number, purchased: boolean)
		if not purchased then return end

		local idStr = tostring(passId)
		if idStr == RAINBOW_PAPER_PASS_ID then
			grantAttribute(player, "RainbowPaperTrail")
		elseif idStr == ROUTE_RIDER_PASS_ID then
			grantAttribute(player, "RouteRiderPack")
		end
	end
)

-- ── Dev Product Receipt Handler ───────────────────────────────────────────────
-- Roblox only calls ProcessReceipt once per purchase and expects a decision
-- before the session ends.  Return PurchaseGranted only after the reward is
-- successfully applied; return NotProcessedYet on unexpected errors so Roblox
-- will retry on the next session.

local function handleChaosKing(player: Player): boolean
	-- Chaos King is a cosmetic: grant the attribute (one-session flag).
	-- Developers may persist this via DataStore if permanent unlock is desired.
	grantAttribute(player, "ChaosKingCosmetic")
	return true
end

local function handleBuckPack(player: Player): boolean
	-- Delivery Buck pack: award in-game currency.
	-- Replace the stub below with your DataStore / leaderstats logic.
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local bucks = leaderstats:FindFirstChild("DeliveryBucks")
		if bucks then
			bucks.Value = bucks.Value + 500 -- example amount per pack
		end
	end
	-- Grant a session flag so the client can show a confirmation UI
	grantAttribute(player, "BuckPackPurchased")
	return true
end

MarketplaceService.ProcessReceipt = function(receiptInfo: { [string]: any })
	local productIdStr = tostring(receiptInfo.ProductId)
	local player       = Players:GetPlayerByUserId(receiptInfo.PlayerId)

	-- Player may have left; Roblox will retry next session automatically.
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local success, err = pcall(function()
		if productIdStr == CHAOS_KING_PRODUCT_ID and isValidId(CHAOS_KING_PRODUCT_ID) then
			handleChaosKing(player)
		elseif productIdStr == BUCK_PACK_PRODUCT_ID and isValidId(BUCK_PACK_PRODUCT_ID) then
			handleBuckPack(player)
		end
		-- Unknown products fall through; still grant below to avoid infinite retries
		-- once IDs are properly configured.
	end)

	if not success then
		warn(("[Monetisation] ProcessReceipt error for product %s (player %s): %s"):format(
			productIdStr, player.Name, tostring(err)
		))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ── Client-Requested Purchase Prompts ────────────────────────────────────────
-- Clients should not call MarketplaceService directly; route through the server
-- so we control prompt eligibility (anti-spam, level gates, etc.).

local function promptGamepass(player: Player, passId: string)
	if not isValidId(passId) then
		warn(("[Monetisation] promptGamepass: ID not configured (%s)"):format(passId))
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, tonumber(passId))
end

local function promptProduct(player: Player, productId: string)
	if not isValidId(productId) then
		warn(("[Monetisation] promptProduct: ID not configured (%s)"):format(productId))
		return
	end
	MarketplaceService:PromptProductPurchase(player, tonumber(productId))
end

promptRainbowPaperEvent.OnServerEvent:Connect(function(player: Player)
	promptGamepass(player, RAINBOW_PAPER_PASS_ID)
end)

promptRouteRiderEvent.OnServerEvent:Connect(function(player: Player)
	promptGamepass(player, ROUTE_RIDER_PASS_ID)
end)

promptChaosKingEvent.OnServerEvent:Connect(function(player: Player)
	promptProduct(player, CHAOS_KING_PRODUCT_ID)
end)

promptBuckPackEvent.OnServerEvent:Connect(function(player: Player)
	promptProduct(player, BUCK_PACK_PRODUCT_ID)
end)