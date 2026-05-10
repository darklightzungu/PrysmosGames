-- Monetisation.lua
-- Route Rage World — GamePass & DevProduct wiring
-- Place in: ServerScriptService
-- Replace GAMEPASS_ID_PLACEHOLDER and DEVPRODUCT_ID_PLACEHOLDER
-- after setting up products in Roblox Creator Dashboard.

local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local Monetisation = {}

-- ── Product IDs ─────────────────────────────────────────────────────────────

local GAMEPASSES = {
	RoadWarriorPack  = GAMEPASS_ID_PLACEHOLDER,  -- 199 Robux — exclusive vehicle skin bundle
	TurboBoostPass   = GAMEPASS_ID_PLACEHOLDER,  -- 299 Robux — permanent turbo boost ability
	VIPLanePass      = GAMEPASS_ID_PLACEHOLDER,  -- 149 Robux — VIP lane access & bonus XP
}

local DEVPRODUCTS = {
	NitroRefill      = DEVPRODUCT_ID_PLACEHOLDER,  -- 50 Robux  — instantly refill nitro tank
	CrashCoins_500   = DEVPRODUCT_ID_PLACEHOLDER,  -- 99 Robux  — 500 in-game Crash Coins
	RespawnToken     = DEVPRODUCT_ID_PLACEHOLDER,  -- 25 Robux  — instant roadside respawn
}

-- Expose tables publicly so other modules can read IDs
Monetisation.GAMEPASSES   = GAMEPASSES
Monetisation.DEVPRODUCTS  = DEVPRODUCTS

-- ── Remotes (must be created beforehand, e.g. via a separate setup script) ───
local function getRemote(name)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		warn("Monetisation: ReplicatedStorage.Remotes folder not found")
		return nil
	end
	return remotes:FindFirstChild(name)
end

-- ── GamePass ownership cache ─────────────────────────────────────────────────
local ownershipCache = {}  -- [userId][passId] = true/false

-- Checks (and caches) whether a player owns a named GamePass
local function hasGamePass(player, passId)
	local uid = player.UserId
	ownershipCache[uid] = ownershipCache[uid] or {}

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

-- Public-facing wrapper that accepts a pass name string
function Monetisation.hasPremiumPass(player, passName)
	local id = GAMEPASSES[passName]
	if not id then
		warn("Monetisation.hasPremiumPass: unknown pass name:", passName)
		return false
	end
	return hasGamePass(player, id)
end

-- ── Prompt helpers ───────────────────────────────────────────────────────────
function Monetisation.promptGamePass(player, passName)
	local id = GAMEPASSES[passName]
	if not id then warn("Monetisation: unknown GamePass:", passName) return end
	MarketplaceService:PromptGamePassPurchase(player, id)
end

function Monetisation.promptDevProduct(player, productName)
	local id = DEVPRODUCTS[productName]
	if not id then warn("Monetisation: unknown DevProduct:", productName) return end
	MarketplaceService:PromptProductPurchase(player, id)
end

-- ── Process DevProduct receipts ──────────────────────────────────────────────
local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	-- If player has left, retry later
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId

	if productId == DEVPRODUCTS.NitroRefill then
		-- Tell the client to refill the nitro gauge immediately
		local nitroEvent = getRemote("RefillNitro")
		if nitroEvent then
			nitroEvent:FireClient(player)
		end

	elseif productId == DEVPRODUCTS.CrashCoins_500 then
		-- Award Crash Coins via a server-side currency event
		local coinsEvent = getRemote("AwardCrashCoins")
		if coinsEvent then
			coinsEvent:FireClient(player, 500)
		end

	elseif productId == DEVPRODUCTS.RespawnToken then
		-- Trigger an instant roadside respawn for the player
		local respawnEvent = getRemote("InstantRespawn")
		if respawnEvent then
			respawnEvent:FireClient(player)
		end
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt

-- ── Apply GamePass perks on character spawn ───────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		-- TurboBoostPass — notify client to enable the permanent turbo UI/ability
		if hasGamePass(player, GAMEPASSES.TurboBoostPass) then
			local turboEvent = getRemote("EnableTurboBoost")
			if turboEvent then
				turboEvent:FireClient(player)
			end
		end

		-- RoadWarriorPack — apply exclusive vehicle skin bundle
		if hasGamePass(player, GAMEPASSES.RoadWarriorPack) then
			local skinEvent = getRemote("ApplyRoadWarriorSkin")
			if skinEvent then
				skinEvent:FireClient(player)
			end
		end

		-- VIPLanePass — grant VIP lane access flag on the client
		if hasGamePass(player, GAMEPASSES.VIPLanePass) then
			local vipEvent = getRemote("GrantVIPLane")
			if vipEvent then
				vipEvent:FireClient(player)
			end
		end
	end)

	-- Clear cache when player leaves to free memory
	player.AncestryChanged:Connect(function()
		if not player:IsDescendantOf(game) then
			ownershipCache[player.UserId] = nil
		end
	end)
end)

return Monetisation