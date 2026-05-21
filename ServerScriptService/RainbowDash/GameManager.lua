local GameManager = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local WorldConfig = require(script.Parent:WaitForChild("WorldConfig"))

local gameDataStore = DataStoreService:GetDataStore("GameData_v1")

-- player data cache keyed by userId
local playerDataCache = {}

-- active combat sessions: combatSessions[userId] = { target, startTime, combo }
local combatSessions = {}

-- pvp duels: pvpDuels[userId] = { opponentId, accepted, startTime }
local pvpDuels = {}

-- ensure Remotes folder exists in ReplicatedStorage
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "Remotes"
    remotes.Parent = ReplicatedStorage
end

-- helper: create RemoteEvent if it doesn't already exist
local function ensureRemoteEvent(name)
    local existing = remotes:FindFirstChild(name)
    if existing then
        return existing
    end
    local re = Instance.new("RemoteEvent")
    re.Name = name
    re.Parent = remotes
    return re
end

-- create mechanic RemoteEvents
local combatEvent = ensureRemoteEvent("CombatEvent")
local pvpEvent    = ensureRemoteEvent("PvpEvent")

-- default player data template
local function defaultData()
    return {
        kills    = 0,
        deaths   = 0,
        wins     = 0,
        losses   = 0,
        combos   = 0,
        health   = 100,
        level    = 1,
        xp       = 0,
    }
end

-- load data from DataStore
local function loadData(userId)
    local data
    local success, err = pcall(function()
        data = gameDataStore:GetAsync(tostring(userId))
    end)
    if success and data then
        -- merge with defaults so new fields are always present
        local base = defaultData()
        for k, v in pairs(data) do
            base[k] = v
        end
        return base
    else
        if not success then
            warn("[GameManager] Failed to load data for", userId, ":", err)
        end
        return defaultData()
    end
end

-- save data to DataStore
local function saveData(userId)
    local data = playerDataCache[userId]
    if not data then return end
    local success, err = pcall(function()
        gameDataStore:SetAsync(tostring(userId), data)
    end)
    if not success then
        warn("[GameManager] Failed to save data for", userId, ":", err)
    end
end

-- spawn character at WorldConfig spawn point
local function spawnCharacter(player)
    local spawnCFrame = CFrame.new(0, 5, 0) -- fallback position
    local spawnPoint = WorldConfig.DefaultArea and WorldConfig.DefaultArea.SpawnPoint
    if spawnPoint then
        if typeof(spawnPoint) == "CFrame" then
            spawnCFrame = spawnPoint
        elseif typeof(spawnPoint) == "Vector3" then
            spawnCFrame = CFrame.new(spawnPoint)
        elseif spawnPoint:IsA("BasePart") then
            spawnCFrame = spawnPoint.CFrame + Vector3.new(0, 5, 0)
        end
    end

    -- load character if not loaded
    if not player.Character then
        player:LoadCharacter()
    end

    -- wait for character then teleport
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart", 10)
    if hrp then
        hrp.CFrame = spawnCFrame
    end
end

-- -----------------------------------------------------------------------
-- COMBAT LOGIC
-- -----------------------------------------------------------------------

local COMBO_WINDOW   = 2.0   -- seconds between hits to maintain combo
local COMBO_BONUS    = 1.25  -- damage multiplier per combo hit beyond first
local BASE_DAMAGE    = 15

-- calculate damage with combo multiplier
local function calculateDamage(userId)
    local session = combatSessions[userId]
    if not session then return BASE_DAMAGE end
    local multiplier = 1 + (session.combo - 1) * (COMBO_BONUS - 1)
    return math.floor(BASE_DAMAGE * multiplier)
end

-- apply damage to a target player's character
local function applyDamage(attacker, targetPlayer, damage)
    local character = targetPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    humanoid.Health = math.max(0, humanoid.Health - damage)

    -- notify both clients
    combatEvent:FireClient(attacker, {
        action  = "HitDealt",
        target  = targetPlayer.Name,
        damage  = damage,
        combo   = combatSessions[attacker.UserId] and combatSessions[attacker.UserId].combo or 1,
    })
    combatEvent:FireClient(targetPlayer, {
        action  = "HitReceived",
        source  = attacker.Name,
        damage  = damage,
    })

    if humanoid.Health <= 0 then
        -- handle kill
        local attackerData = playerDataCache[attacker.UserId]
        local victimData   = playerDataCache[targetPlayer.UserId]
        if attackerData then attackerData.kills = attackerData.kills + 1 end
        if victimData   then victimData.deaths  = victimData.deaths  + 1 end

        combatEvent:FireClient(attacker, { action = "KillConfirmed", victim = targetPlayer.Name })
        combatEvent:FireClient(targetPlayer, { action = "Eliminated", killer = attacker.Name })
    end
end

-- start or refresh a combat session
function GameManager.StartCombat(attacker, targetPlayer)
    if not attacker or not targetPlayer then return end
    local uid = attacker.UserId

    local now = tick()
    local session = combatSessions[uid]

    if session then
        -- extend combo if within window
        if (now - session.lastHitTime) <= COMBO_WINDOW then
            session.combo = session.combo + 1
        else
            session.combo = 1
        end
        session.target      = targetPlayer
        session.lastHitTime = now
    else
        combatSessions[uid] = {
            target      = targetPlayer,
            startTime   = now,
            lastHitTime = now,
            combo       = 1,
        }
        session = combatSessions[uid]
    end

    -- track total combos in persistent data
    local data = playerDataCache[uid]
    if data and session.combo > 1 then
        data.combos = data.combos + 1
    end

    local damage = calculateDamage(uid)
    applyDamage(attacker, targetPlayer, damage)
end

-- end a combat session for a player
function GameManager.EndCombat(userId)
    combatSessions[userId] = nil
end

-- -----------------------------------------------------------------------
-- PVP LOGIC
-- -----------------------------------------------------------------------

local PVP_ACCEPT_TIMEOUT = 30 -- seconds to accept a duel
local PVP_DUEL_DURATION  = 120 -- max duel length in seconds

-- send a pvp challenge from challenger to opponent
function GameManager.ChallengePvp(challenger, opponentPlayer)
    if not challenger or not opponentPlayer then return end
    if challenger.UserId == opponentPlayer.UserId then return end

    local cid = challenger.UserId
    local oid = opponentPlayer.UserId

    -- cancel any existing outgoing challenge
    pvpDuels[cid] = {
        opponentId  = oid,
        accepted    = false,
        startTime   = tick(),
    }

    pvpEvent:FireClient(challenger, {
        action   = "ChallengeSent",
        opponent = opponentPlayer.Name,
    })
    pvpEvent:FireClient(opponentPlayer, {
        action     = "ChallengeReceived",
        challenger = challenger.Name,
    })

    -- auto-expire challenge
    task.delay(PVP_ACCEPT_TIMEOUT, function()
        local duel = pvpDuels[cid]
        if duel and not duel.accepted and duel.opponentId == oid then
            pvpDuels[cid] = nil
            if Players:GetPlayerByUserId(cid) then
                pvpEvent:FireClient(Players:GetPlayerByUserId(cid), { action = "ChallengeExpired" })
            end
            if Players:GetPlayerByUserId(oid) then
                pvpEvent:FireClient(Players:GetPlayerByUserId(oid), { action = "ChallengeExpired" })
            end
        end
    end)
end

-- opponent accepts a pvp challenge
function GameManager.AcceptPvp(opponent, challengerPlayer)
    if not opponent or not challengerPlayer then return end
    local cid = challengerPlayer.UserId
    local oid = opponent.UserId

    local duel = pvpDuels[cid]
    if not duel or duel.opponentId ~= oid or duel.accepted then return end

    duel.accepted  = true
    duel.startTime = tick()

    -- mirror reference so both sides can look up the duel
    pvpDuels[oid] = {
        opponentId = cid,
        accepted   = true,
        startTime  = duel.startTime,
        isMirror   = true,
    }

    pvpEvent:FireClient(challengerPlayer, {
        action   = "DuelStarted",
        opponent = opponent.Name,
    })
    pvpEvent:FireClient(opponent, {
        action   = "DuelStarted",
        opponent = challengerPlayer.Name,
    })

    -- auto-end duel after max duration
    task.delay(PVP_DUEL_DURATION, function()
        GameManager.EndPvp(cid, oid, "timeout")
    end)
end

-- resolve a pvp duel
function GameManager.EndPvp(playerAId, playerBId, reason)
    local duelA = pvpDuels[playerAId]
    local duelB = pvpDuels[playerBId]

    -- only resolve if still active
    if not duelA and not duelB then return end

    pvpDuels[playerAId] = nil
    pvpDuels[playerBId] = nil

    local playerA = Players:GetPlayerByUserId(playerAId)
    local playerB = Players:GetPlayerByUserId(playerBId)

    if playerA then
        pvpEvent:FireClient(playerA, { action = "DuelEnded", reason = reason })
    end
    if playerB then
        pvpEvent:FireClient(playerB, { action = "DuelEnded", reason = reason })
    end
end

-- declare a winner for a pvp duel
function GameManager.DeclarePvpWinner(winnerId, loserId)
    local winnerData = playerDataCache[winnerId]
    local loserData  = playerDataCache[loserId]
    if winnerData then winnerData.wins   = winnerData.wins   + 1 end
    if loserData  then loserData.losses  = loserData.losses  + 1 end

    local winner = Players:GetPlayerByUserId(winnerId)
    local loser  = Players:GetPlayerByUserId(loserId)
    if winner then pvpEvent:FireClient(winner, { action = "DuelWon"  }) end
    if loser  then pvpEvent:FireClient(loser,  { action = "DuelLost" }) end

    GameManager.EndPvp(winnerId, loserId, "decided")
end

-- -----------------------------------------------------------------------
-- REMOTE EVENT HANDLERS (client → server)
-- -----------------------------------------------------------------------

combatEvent.OnServerEvent:Connect(function(player, payload)
    if type(payload) ~= "table" then return end

    if payload.action == "Attack" then
        -- payload.targetName: name of the target player
        local targetPlayer = Players:FindFirstChild(payload.targetName)
        if targetPlayer and targetPlayer ~= player then
            GameManager.StartCombat(player, targetPlayer)
        end

    elseif payload.action == "StopCombat" then
        GameManager.EndCombat(player.UserId)
    end
end)

pvpEvent.OnServerEvent:Connect(function(player, payload)
    if type(payload) ~= "table" then return end

    if payload.action == "Challenge" then
        local opponent = Players:FindFirstChild(payload.opponentName)
        if opponent then
            GameManager.ChallengePvp(player, opponent)
        end

    elseif payload.action == "Accept" then
        local challenger = Players:FindFirstChild(payload.challengerName)
        if challenger then
            GameManager.AcceptPvp(player, challenger)
        end

    elseif payload.action == "Forfeit" then
        local duel = pvpDuels[player.UserId]
        if duel and duel.accepted then
            GameManager.DeclarePvpWinner(duel.opponentId, player.UserId)
        end
    end
end)

-- -----------------------------------------------------------------------
-- PLAYER LIFECYCLE
-- -----------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player)
    local userId = player.UserId

    -- load persistent data
    local data = loadData(userId)
    playerDataCache[userId] = data

    -- spawn at WorldConfig default area
    player.CharacterAdded:Connect(function()
        task.wait() -- brief wait for physics init
        spawnCharacter(player)
    end)

    -- if character already exists (rare but possible), spawn now
    if player.Character then
        spawnCharacter(player)
    else
        player:LoadCharacter()
    end

    -- watch for death to handle pvp resolution
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid then return end

        humanoid.Died:Connect(function()
            -- resolve active pvp duel if any
            local duel = pvpDuels[userId]
            if duel and duel.accepted and not duel.isMirror then
                GameManager.DeclarePvpWinner(duel.opponentId, userId)
            end
            -- clear combat session on death
            GameManager.EndCombat(userId)
        end)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    local userId = player.UserId
    saveData(userId)
    playerDataCache[userId] = nil
    combatSessions[userId]  = nil
    pvpDuels[userId]        = nil
end)

-- save all players on server shutdown
game:BindToClose(function()
    for userId, _ in pairs(playerDataCache) do
        saveData(userId)
    end
end)

-- -----------------------------------------------------------------------
-- PUBLIC API
-- -----------------------------------------------------------------------

function GameManager.GetPlayerData(userId)
    return playerDataCache[userId]
end

function GameManager.SetPlayerData(userId, key, value)
    local data = playerDataCache[userId]
    if data then
        data[key] = value
    end
end

function GameManager.GetCombatSession(userId)
    return combatSessions[userId]
end

function GameManager.GetPvpDuel(userId)
    return pvpDuels[userId]
end

return GameManager
