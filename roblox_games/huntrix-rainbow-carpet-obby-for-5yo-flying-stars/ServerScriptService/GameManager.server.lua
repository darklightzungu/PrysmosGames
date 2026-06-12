```lua
-- ============================================================
-- ACTION GAME: Combat & Quest System
-- Structure:
--   ServerScriptService/GameServer.server.lua  (this file, split by markers)
--   StarterPlayerScripts/GameClient.client.lua
--   StarterGui/GameGui.lua (LocalScript)
-- ============================================================

-- ============================================================
-- [SERVER] GameServer.server.lua
-- Place in: ServerScriptService
-- ============================================================

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local MarketplaceService  = game:GetService("MarketplaceService")
local TweenService        = game:GetService("TweenService")

---------------------------------------------------------------------------
-- Remote Event / Function Setup
---------------------------------------------------------------------------
local remoteFolder = Instance.new("Folder")
remoteFolder.Name  = "GameRemotes"
remoteFolder.Parent = ReplicatedStorage

local function makeEvent(name)
    local e = Instance.new("RemoteEvent")
    e.Name   = name
    e.Parent = remoteFolder
    return e
end

local function makeFunction(name)
    local f = Instance.new("RemoteFunction")
    f.Name   = name
    f.Parent = remoteFolder
    return f
end

-- Combat remotes
local RE_Attack         = makeEvent("Attack")
local RE_TakeDamage     = makeEvent("TakeDamage")
local RE_PlayerDied     = makeEvent("PlayerDied")
local RE_PlayerRespawn  = makeEvent("PlayerRespawn")
local RE_ComboUpdate    = makeEvent("ComboUpdate")
local RE_SpecialAbility = makeEvent("SpecialAbility")

-- Quest remotes
local RE_QuestAssign    = makeEvent("QuestAssign")
local RE_QuestUpdate    = makeEvent("QuestUpdate")
local RE_QuestComplete  = makeEvent("QuestComplete")
local RF_GetQuests      = makeFunction("GetQuests")
local RF_AcceptQuest    = makeFunction("AcceptQuest")
local RF_AbandonQuest   = makeFunction("AbandonQuest")

-- Store / Gamepass remotes
local RE_PurchaseProduct = makeEvent("PurchaseProduct")
local RE_GamepassCheck   = makeEvent("GamepassCheck")

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
local GAMEPASS_ID      = GAMEPASS_ID_PLACEHOLDER
local DEVPRODUCT_ID    = DEVPRODUCT_ID_PLACEHOLDER

local BASE_DAMAGE      = 20
local COMBO_MULTIPLIER = 0.25   -- each combo hit adds 25 % damage
local MAX_COMBO        = 5
local COMBO_RESET_TIME = 2.5    -- seconds without hitting resets combo
local ATTACK_COOLDOWN  = 0.4    -- min time between attacks per player
local SPECIAL_COOLDOWN = 12     -- special ability cooldown
local RESPAWN_TIME     = 5
local KNOCKBACK_FORCE  = 80

---------------------------------------------------------------------------
-- Quest Definitions
---------------------------------------------------------------------------
local QUEST_DEFINITIONS = {
    {
        id          = "quest_kill_10",
        name        = "First Blood",
        description = "Defeat 10 enemies.",
        type        = "kill",
        target      = 10,
        rewards     = { xp = 150, gold = 50 },
    },
    {
        id          = "quest_combo_5",
        name        = "Combo King",
        description = "Land a 5-hit combo.",
        type        = "combo",
        target      = 5,
        rewards     = { xp = 100, gold = 30 },
    },
    {
        id          = "quest_survive_60",
        name        = "Survivor",
        description = "Survive for 60 seconds without dying.",
        type        = "survive",
        target      = 60,
        rewards     = { xp = 200, gold = 75 },
    },
    {
        id          = "quest_special_3",
        name        = "Power Surge",
        description = "Use your special ability 3 times.",
        type        = "special",
        target      = 3,
        rewards     = { xp = 120, gold = 40 },
    },
}

---------------------------------------------------------------------------
-- Player Data Store (in-memory; swap with DataStore2 / ProfileService)
---------------------------------------------------------------------------
local playerData = {}   -- [userId] = { combat={}, quests={}, stats={} }

local function initPlayerData(player)
    playerData[player.UserId] = {
        stats = {
            xp         = 0,
            gold       = 0,
            level      = 1,
            kills      = 0,
            deaths     = 0,
            hasGamepass = false,
        },
        combat = {
            combo          = 0,
            lastHitTime    = 0,
            lastAttackTime = 0,
            lastSpecialTime= 0,
            aliveTime      = 0,
            aliveStart     = tick(),
        },
        quests = {
            active    = {},  -- [questId] = { def, progress }
            completed = {},  -- set of questId
        },
    }
end

local function getPlayerData(player)
    return playerData[player.UserId]
end

---------------------------------------------------------------------------
-- Gamepass Check
---------------------------------------------------------------------------
local function checkGamepass(player)
    local data = getPlayerData(player)
    if not data then return false end
    local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync,
                           MarketplaceService, player.UserId, GAMEPASS_ID)
    local result = ok and owns or false
    data.stats.hasGamepass = result
    return result
end

---------------------------------------------------------------------------
-- XP / Level helpers
---------------------------------------------------------------------------
local function xpForNextLevel(level)
    return math.floor(100 * (level ^ 1.5))
end

local function tryLevelUp(player)
    local data = getPlayerData(player)
    if not data then return end
    local stats = data.stats
    local needed = xpForNextLevel(stats.level)
    while stats.xp >= needed do
        stats.xp    = stats.xp - needed
        stats.level = stats.level + 1
        needed      = xpForNextLevel(stats.level)
        -- Notify client
        RE_QuestUpdate:FireClient(player, { type = "levelUp", level = stats.level })
    end
end

local function giveRewards(player, rewards)
    local data = getPlayerData(player)
    if not data then return end
    data.stats.xp   = data.stats.xp   + (rewards.xp   or 0)
    data.stats.gold = data.stats.gold + (rewards.gold  or 0)
    tryLevelUp(player)
    RE_QuestUpdate:FireClient(player, {
        type  = "rewardGiven",
        xp    = rewards.xp   or 0,
        gold  = rewards.gold  or 0,
        stats = data.stats,
    })
end

---------------------------------------------------------------------------
-- Quest System
---------------------------------------------------------------------------
local function assignDefaultQuests(player)
    local data = getPlayerData(player)
    if not data then return end
    -- Give the first two quests by default
    for i = 1, math.min(2, #QUEST_DEFINITIONS) do
        local def = QUEST_DEFINITIONS[i]
        if not data.quests.completed[def.id] and not data.quests.active[def.id] then
            data.quests.active[def.id] = { def = def, progress = 0 }
            RE_QuestAssign:FireClient(player, def, 0)
        end
    end
end

local function advanceQuest(player, questType, amount)
    local data = getPlayerData(player)
    if not data then return end
    amount = amount or 1
    for questId, entry in pairs(data.quests.active) do
        if entry.def.type == questType then
            entry.progress = entry.progress + amount
            -- Clamp to target
            local capped = math.min(entry.progress, entry.def.target)
            RE_QuestUpdate:FireClient(player, {
                type     = "progress",
                questId  = questId,
                progress = capped,
                target   = entry.def.target,
            })
            -- Check completion
            if entry.progress >= entry.def.target then
                data.quests.completed[questId] = true
                data.quests.active[questId]    = nil
                giveRewards(player, entry.def.rewards)
                RE_QuestComplete:FireClient(player, entry.def)
            end
        end
    end
end

-- RF_GetQuests handler
RF_GetQuests.OnServerInvoke = function(player)
    local data = getPlayerData(player)
    if not data then return {}, {} end
    local active, completed = {}, {}
    for _, entry in pairs(data.quests.active) do
        table.insert(active, { def = entry.def, progress = entry.progress })
    end
    for qId in pairs(data.quests.completed) do
        table.insert(completed, qId)
    end
    return active, completed
end

-- RF_AcceptQuest handler
RF_AcceptQuest.OnServerInvoke = function(player, questId)
    local data = getPlayerData(player)
    if not data then return false, "No data" end
    if data.quests.active[questId] then return false, "Already active" end
    if data.quests.completed[questId] then return false, "Already completed" end

    local def
    for _, d in ipairs(QUEST_DEFINITIONS) do
        if d.id == questId then def = d break end
    end
    if not def then return false, "Quest not found" end

    data.quests.active[questId] = { def = def, progress = 0 }
    RE_QuestAssign:FireClient(player, def, 0)
    return true, "Quest accepted"
end

-- RF_AbandonQuest handler
RF_AbandonQuest.OnServerInvoke = function(player, questId)
    local data = getPlayerData(player)
    if not data then return false end
    if not data.quests.active[questId] then return false, "Not active" end
    data.quests.active[questId] = nil
    RE_QuestUpdate:FireClient(player, { type = "abandoned", questId = questId })
    return true
end

---------------------------------------------------------------------------
-- Combat System
---------------------------------------------------------------------------

-- Validate that the target is a real player/NPC and within range
local function validateTarget(attacker, targetCharacter, maxRange)
    if not attacker.Character then return false end
    local attackerRoot = attacker.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot   = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
    if not attackerRoot or not targetRoot then return false end

    local distance = (attackerRoot.Position - targetRoot.Position).Magnitude
    return distance <= (maxRange or 12)
end

-- Apply damage and knockback to a humanoid
local function applyDamage(targetCharacter, damage, attackerCharacter)
    local humanoid = targetCharacter:FindFirstChildWhichIsA("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end

    humanoid:TakeDamage(damage)

    -- Knockback via BodyVelocity on the HRP
    local targetRoot   = targetCharacter:FindFirstChild("HumanoidRootPart")
    local attackerRoot = attackerCharacter and attackerCharacter:FindFirstChild("HumanoidRootPart")
    if targetRoot and attackerRoot then
        local direction = (targetRoot.Position - attackerRoot.Position).Unit
        local bv = Instance.new("BodyVelocity")
        bv.Velocity   = (direction + Vector3.new(0, 0.4, 0)) * KNOCKBACK_FORCE
        bv.MaxForce   = Vector3.new(1e5, 1e5, 1e5)
        bv.Parent     = targetRoot
        game:GetService("Debris"):AddItem(bv, 0.15)
    end
    return true
end

-- Handle incoming Attack remote from client
RE_Attack.OnServerEvent:Connect(function(player, targetPlayer, attackType)
    local data = getPlayerData(player)
    if not data then return end

    local now = tick()
    -- Cooldown guard
    if now - data.combat.lastAttackTime < ATTACK_COOLDOWN then return end
    data.combat.lastAttackTime = now

    -- Only allow attacking other players (PvP) or NPCs tagged as "Enemy"
    local targetCharacter
    if targetPlayer and targetPlayer:IsA("Player") then
        if targetPlayer == player then return end  -- no self-damage
        targetCharacter = targetPlayer.Character
    elseif targetPlayer and targetPlayer:IsA("Model") and targetPlayer:GetAttribute("IsEnemy") then
        targetCharacter = targetPlayer
    else
        return
    end

    if not validateTarget(player, targetCharacter) then return end

    -- Combo management
    if now - data.combat.lastHitTime > COMBO_RESET_TIME then
        data.combat.combo = 0
    end
    data.combat.combo       = math.min(data.combat.combo + 1, MAX_COMBO)
    data.combat.lastHitTime = now

    -- Calculate damage with combo multiplier
    local multiplier = 1 + (data.combat.combo - 1) * COMBO_MULTIPLIER
    -- Gamepass bonus
    if data.stats.hasGamepass then multiplier = multiplier * 1.25 end
    local finalDamage = math.floor(BASE_DAMAGE * multiplier)

    -- Notify attacker's client about combo
    RE_ComboUpdate:FireClient(player, data.combat.combo)

    -- Apply damage
    local hit = applyDamage(targetCharacter, finalDamage, player.Character)
    if not hit then return end

    -- Notify target client of damage taken
    local targetPlayerObj = Players:GetPlayerFromCharacter(targetCharacter)
    if targetPlayerObj then
        RE_TakeDamage:FireClient(targetPlayerObj, finalDamage, player.Name)
    end

    -- Quest: combo
    if data.combat.combo >= 5 then
        advanceQuest(player, "combo", 1)
    end

    -- Check if target died
    local targetHumanoid = targetCharacter:FindFirstChildWhichIsA("Humanoid")
    if targetHumanoid and targetHumanoid.Health <= 0 then
        data.stats.kills = data.stats.kills + 1
        advanceQuest(player, "kill", 1)

        -- Notify everyone for kill feed
        RE_PlayerDied:FireAllClients(
            targetPlayerObj and targetPlayerObj.Name or targetCharacter.Name,
            player.Name,
            finalDamage
        )

        if targetPlayerObj then
            local tData = getPlayerData(targetPlayerObj)
            if tData then
                tData.stats.deaths = tData.stats.deaths + 1
                -- Reset their survive quest progress
                tData.combat.aliveStart = nil
            end
        end
    end
end)

-- Special ability
RE_SpecialAbility.OnServerEvent:Connect(function(player)
    local data = getPlayerData(player)
    if not data then return end

    local now = tick()
    if now - data.combat.lastSpecialTime < SPECIAL_COOLDOWN then
        -- Send remaining cooldown back
        RE_SpecialAbility:FireClient(player, false,
            SPECIAL_COOLDOWN - (now - data.combat.lastSpecialTime))
        return
    end
    data.combat.lastSpecialTime = now

    -- Validate character
    local char = player.Character
    if not char then