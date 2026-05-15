-- Monetisation.lua
-- Route Rage — GamePass & DevProduct wiring
-- Place in: ServerScriptService
-- Replace GAMEPASS_ID_PLACEHOLDER and DEVPRODUCT_ID_PLACEHOLDER
-- after setting up products in the Roblox Creator Dashboard.

local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local Monetisation = {}

-- ── Product IDs ──────────────────────────────────────────────────────────────

local GAMEPASSES = {
	RoadRager    = GAMEPASS_ID_PLACEHOLDER,  -- 299 Robux — exclusive vehicle skin bundle + boost
	NitroInfinity = GAMEPASS_ID_PLACEHOLDER, -- 499 Robux — permanent unlimited nitro charges
	VIPLane      = GAMEPASS_ID_PLACEHOLDER,  -- 199 Robux — VIP tag, exclusive lane, 2× XP
}

local DEVPRODUCTS = {
	NitroPack     = DEVPRODUCT_ID_PLACEHOLDER,  -- 49 Robux  — instant 5× nitro refill
	CoinBoost     = DEVPRODUCT_ID_PLACEHOLDER,  -- 99 Robux  — 2× coin multiplier for 30 minutes
	RespawnShield = DEVPRODUCT_ID_PLACEHOLDER,  -- 75 Robux  — one-time crash immunity shield
}

-- Expose tables publicly so other scripts can reference IDs
Monetisation.GAMEPASSES  = GAMEPASSES
Monetisation.DEVPRODUCTS = DEVPRODUCTS

-- ── Remotes (must exist in ReplicatedStorage.Remotes) ───────────────────────
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ── Ownership cache ──────────────────────────────────────────────────────────
local ownershipCache = {}  -- [userId][passId] = bool

-- hasPremiumPass: returns true if the player owns the named GamePass
function Monetisation.hasPremiumPass(player, passName)
	local passId = GAMEPASSES[passName]
	if not passId then
		warn("[Monetisation] Unknown GamePass name:", passName)
		return false
	end

	local uid = player.UserId
	ownershipCache[uid] = ownershipCache[uid] or {}

	-- Return cached result to avoid redundant API calls
	if ownershipCache[uid][passId] ~= nil then
		return ownershipCache[uid][passId]
	end

	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(uid, passId)
	end)

	local owns = ok and result or false
	ownershipCache[uid][passId] = owns
	return owns
end

-- ── Prompt helpers ───────────────────────────────────────────────────────────
function Monetisation.promptGamePass(player, passName)
	local id = GAMEPASSES[passName]
	if not id then warn("[Monetisation] Unknown GamePass:", passName) return end
	MarketplaceService:PromptGamePassPurchase(player, id)
end

function Monetisation.promptDevProduct(player, productName)
	local id = DEVPRODUCTS[productName]
	if not id then warn("[Monetisation] Unknown DevProduct:", productName) return end
	MarketplaceService:PromptProductPurchase(player, id)
end

-- ── ProcessReceipt ───────────────────────────────────────────────────────────
local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)

	-- Player may have left; defer until they rejoin
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId

	if productId == DEVPRODUCTS.NitroPack then
		-- Tell the client to refill nitro × 5 immediately
		local nitroEvent = remotes:FindFirstChild("RefillNitro")
		if nitroEvent then
			nitroEvent:FireClient(player, 5)
		end

	elseif productId == DEVPRODUCTS.CoinBoost then
		-- Tell the client (and server logic) to activate a 2× coin multiplier
		local boostEvent = remotes:FindFirstChild("ActivateCoinBoost")
		if boostEvent then
			boostEvent:FireClient(player, 2, 1800)  -- multiplier, duration in seconds
		end

	elseif productId == DEVPRODUCTS.RespawnShield then
		-- Grant a one-time crash immunity shield
		local shieldEvent = remotes:FindFirstChild("GrantRespawnShield")
		if shieldEvent then
			shieldEvent:FireClient(player)
		end
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt

-- ── Apply GamePass perks on character spawn ──────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		-- NitroInfinity pass: notify client to enable limitless nitro UI
		if Monetisation.hasPremiumPass(player, "NitroInfinity") then
			local nitroInfinityEvent = remotes:FindFirstChild("EnableInfiniteNitro")
			if nitroInfinityEvent then
				nitroInfinityEvent:FireClient(player)
			end
		end

		-- VIPLane pass: apply VIP perks (tag, lane access, XP multiplier)
		if Monetisation.hasPremiumPass(player, "VIPLane") then
			local vipEvent = remotes:FindFirstChild("ApplyVIPPerks")
			if vipEvent then
				vipEvent:FireClient(player)
			end
		end

		-- RoadRager pass: apply exclusive vehicle skin bundle
		if Monetisation.hasPremiumPass(player, "RoadRager") then
			local skinEvent = remotes:FindFirstChild("ApplyRoadRagerSkin")
			if skinEvent then
				skinEvent:FireClient(player)
			end
		end
	end)

	-- Clear cache when the player leaves to free memory
	player.AncestryChanged:Connect(function()
		if not player:IsDescendantOf(game) then
			ownershipCache[player.UserId] = nil
		end
	end)
end)

return Monetisation