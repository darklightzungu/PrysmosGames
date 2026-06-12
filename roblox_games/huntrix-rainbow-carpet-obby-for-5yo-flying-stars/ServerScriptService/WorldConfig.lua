```lua
-- WorldGen: Action Game World Configuration
-- Handles world generation, combat zones, and quest regions
-- Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

-- Constants
local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

-- ============================================================
-- WORLD CONFIGURATION
-- ============================================================

local WorldConfig = {
    -- General world settings
    world = {
        name          = "ActionRealm",
        version       = "1.0.0",
        gravity       = 196.2,
        ambientColor  = Color3.fromRGB(120, 130, 150),
        fogEnd        = 800,
        fogColor      = Color3.fromRGB(180, 190, 210),
        timeOfDay     = "14:00:00",
        cycleEnabled  = true,
        cycleDuration = 600, -- seconds for full day/night cycle
    },

    -- Combat zone definitions
    combatZones = {
        {
            id           = "zone_01_plains",
            displayName  = "Verdant Plains",
            position     = Vector3.new(0, 0, 0),
            radius       = 300,
            minLevel     = 1,
            maxLevel     = 10,
            pvpEnabled   = false,
            enemyTypes   = { "Goblin", "Slime", "Bandit" },
            spawnRate    = 5,   -- seconds between spawns
            maxEnemies   = 20,
            lootTable    = {
                { itemId = "coin_bronze",  weight = 60 },
                { itemId = "herb_basic",   weight = 25 },
                { itemId = "sword_iron",   weight = 10 },
                { itemId = "armor_light",  weight = 5  },
            },
            ambientSound = "rbxassetid://0",
            theme        = "forest",
        },
        {
            id           = "zone_02_dungeon",
            displayName  = "Shadow Dungeon",
            position     = Vector3.new(500, -50, 500),
            radius       = 150,
            minLevel     = 10,
            maxLevel     = 25,
            pvpEnabled   = false,
            enemyTypes   = { "Skeleton", "Vampire", "DarkKnight" },
            spawnRate    = 8,
            maxEnemies   = 15,
            lootTable    = {
                { itemId = "coin_silver",    weight = 50 },
                { itemId = "gem_ruby",       weight = 20 },
                { itemId = "sword_shadow",   weight = 15 },
                { itemId = "armor_enchanted",weight = 10 },
                { itemId = "key_dungeon",    weight = 5  },
            },
            ambientSound = "rbxassetid://0",
            theme        = "dungeon",
        },
        {
            id           = "zone_03_volcano",
            displayName  = "Inferno Summit",
            position     = Vector3.new(-600, 100, -400),
            radius       = 200,
            minLevel     = 25,
            maxLevel     = 50,
            pvpEnabled   = true,
            enemyTypes   = { "FireDemon", "LavaGolem", "VolcanoWyrm" },
            spawnRate    = 12,
            maxEnemies   = 10,
            lootTable    = {
                { itemId = "coin_gold",       weight = 40 },
                { itemId = "gem_diamond",     weight = 20 },
                { itemId = "sword_inferno",   weight = 20 },
                { itemId = "armor_volcanic",  weight = 15 },
                { itemId = "boss_core",       weight = 5  },
            },
            ambientSound = "rbxassetid://0",
            theme        = "volcanic",
        },
        {
            id           = "zone_04_pvp_arena",
            displayName  = "Gladiator Arena",
            position     = Vector3.new(0, 0, -800),
            radius       = 100,
            minLevel     = 5,
            maxLevel     = 999,
            pvpEnabled   = true,
            enemyTypes   = {},  -- player vs player only
            spawnRate    = 0,
            maxEnemies   = 0,
            lootTable    = {
                { itemId = "trophy_bronze", weight = 60 },
                { itemId = "trophy_silver", weight = 30 },
                { itemId = "trophy_gold",   weight = 10 },
            },
            ambientSound = "rbxassetid://0",
            theme        = "arena",
        },
    },

    -- Quest definitions
    quests = {
        {
            id           = "quest_01_tutorial",
            displayName  = "A Hero's Beginning",
            description  = "Defeat 5 Goblins in the Verdant Plains.",
            type         = "kill",
            zoneId       = "zone_01_plains",
            minLevel     = 1,
            objectives   = {
                { targetType = "Goblin", count = 5, current = 0 },
            },
            rewards      = {
                xp         = 200,
                coins      = 50,
                items      = { "sword_iron" },
            },
            prereqs      = {},
            repeatable   = false,
            timeLimit    = nil,
        },
        {
            id           = "quest_02_bandit_camp",
            displayName  = "Bandit Eradication",
            description  = "Clear out the bandit camp by defeating 10 Bandits.",
            type         = "kill",
            zoneId       = "zone_01_plains",
            minLevel     = 5,
            objectives   = {
                { targetType = "Bandit", count = 10, current = 0 },
            },
            rewards      = {
                xp         = 500,
                coins      = 120,
                items      = { "armor_light" },
            },
            prereqs      = { "quest_01_tutorial" },
            repeatable   = false,
            timeLimit    = nil,
        },
        {
            id           = "quest_03_dungeon_key",
            displayName  = "Key to Darkness",
            description  = "Retrieve the dungeon key from the Shadow Dungeon.",
            type         = "collect",
            zoneId       = "zone_02_dungeon",
            minLevel     = 10,
            objectives   = {
                { targetType = "key_dungeon", count = 1, current = 0 },
            },
            rewards      = {
                xp         = 1000,
                coins      = 300,
                items      = { "sword_shadow" },
            },
            prereqs      = { "quest_02_bandit_camp" },
            repeatable   = false,
            timeLimit    = 3600, -- 1 hour time limit
        },
        {
            id           = "quest_04_boss_hunt",
            displayName  = "Slayer of Demons",
            description  = "Defeat the Volcano Wyrm at Inferno Summit.",
            type         = "boss",
            zoneId       = "zone_03_volcano",
            minLevel     = 30,
            objectives   = {
                { targetType = "VolcanoWyrm", count = 1, current = 0 },
            },
            rewards      = {
                xp         = 5000,
                coins      = 1000,
                items      = { "armor_volcanic", "sword_inferno" },
            },
            prereqs      = { "quest_03_dungeon_key" },
            repeatable   = true,
            timeLimit    = nil,
        },
        {
            id           = "quest_05_daily_arena",
            displayName  = "Arena Champion",
            description  = "Win 3 PvP matches in the Gladiator Arena.",
            type         = "pvp",
            zoneId       = "zone_04_pvp_arena",
            minLevel     = 5,
            objectives   = {
                { targetType = "pvp_win", count = 3, current = 0 },
            },
            rewards      = {
                xp         = 800,
                coins      = 200,
                items      = { "trophy_silver" },
            },
            prereqs      = {},
            repeatable   = true,
            timeLimit    = 86400, -- 24 hour daily reset
        },
    },

    -- Spawn points per zone theme
    spawnPoints = {
        safe = {
            Vector3.new(0,   5,  0),
            Vector3.new(10,  5,  10),
            Vector3.new(-10, 5,  10),
            Vector3.new(10,  5, -10),
            Vector3.new(-10, 5, -10),
        },
    },

    -- Monetization
    monetization = {
        gamePasses = {
            doubleXP     = GAMEPASS_ID_PLACEHOLDER,
            vipAccess    = GAMEPASS_ID_PLACEHOLDER,
            premiumZones = GAMEPASS_ID_PLACEHOLDER,
        },
        devProducts = {
            coinBundle100  = DEVPRODUCT_ID_PLACEHOLDER,
            coinBundle500  = DEVPRODUCT_ID_PLACEHOLDER,
            xpBoost1h      = DEVPRODUCT_ID_PLACEHOLDER,
            reviveToken    = DEVPRODUCT_ID_PLACEHOLDER,
        },
    },

    -- Enemy base stats by type
    enemyStats = {
        Goblin      = { health = 50,  damage = 5,  speed = 14, xpReward = 20  },
        Slime       = { health = 30,  damage = 3,  speed = 10, xpReward = 10  },
        Bandit      = { health = 80,  damage = 10, speed = 16, xpReward = 35  },
        Skeleton    = { health = 100, damage = 15, speed = 14, xpReward = 50  },
        Vampire     = { health = 150, damage = 20, speed = 18, xpReward = 80  },
        DarkKnight  = { health = 250, damage = 30, speed = 12, xpReward = 120 },
        FireDemon   = { health = 300, damage = 35, speed = 15, xpReward = 150 },
        LavaGolem   = { health = 500, damage = 25, speed = 8,  xpReward = 200 },
        VolcanoWyrm = { health = 2000,damage = 80, speed = 20, xpReward = 1000},
    },
}

-- ============================================================
-- REMOTE EVENTS SETUP (Server-side creation)
-- ============================================================

local remoteEvents = {}
local remoteFunctions = {}

if IS_SERVER then
    -- Create RemoteEvents folder
    local eventsFolder = ReplicatedStorage:FindFirstChild("WorldEvents")
    if not eventsFolder then
        eventsFolder = Instance.new("Folder")
        eventsFolder.Name = "WorldEvents"
        eventsFolder.Parent = ReplicatedStorage
    end

    -- List of all required RemoteEvents
    local eventNames = {
        "RequestWorldConfig",    -- Client requests world data
        "ZoneEntered",           -- Player entered a combat zone
        "ZoneExited",            -- Player left a combat zone
        "QuestStarted",          -- Quest was accepted
        "QuestUpdated",          -- Quest objective progress updated
        "QuestCompleted",        -- Quest finished and rewards given
        "EnemySpawned",          -- Notify clients of new enemy
        "EnemyDefeated",         -- Enemy was killed
        "PlayerLevelUp",         -- Player leveled up
        "CombatDamage",          -- Damage event for combat system
        "PlayerRevived",         -- Player respawned after death
    }

    for _, name in ipairs(eventNames) do
        if not eventsFolder:FindFirstChild(name) then
            local re = Instance.new("RemoteEvent")
            re.Name = name
            re.Parent = eventsFolder
        end
        remoteEvents[name] = eventsFolder:FindFirstChild(name)
    end

    -- RemoteFunctions
    local functionNames = {
        "GetWorldConfig",   -- Synchronous world config fetch
        "GetZoneInfo",      -- Get info for a specific zone ID
        "GetQuestInfo",     -- Get info for a specific quest ID
    }

    local functionsFolder = ReplicatedStorage:FindFirstChild("WorldFunctions")
    if not functionsFolder then
        functionsFolder = Instance.new("Folder")
        functionsFolder.Name = "WorldFunctions"
        functionsFolder.Parent = ReplicatedStorage
    end

    for _, name in ipairs(functionNames) do
        if not functionsFolder:FindFirstChild(name) then
            local rf = Instance.new("RemoteFunction")
            rf.Name = name
            rf.Parent = functionsFolder
        end
        remoteFunctions[name] = functionsFolder:FindFirstChild(name)
    end
end

-- ============================================================
-- SERVER-SIDE WORLD LOGIC
-- ============================================================

if IS_SERVER then

    -- Helper: deep-copy a table to avoid mutation of config
    local function deepCopy(original)
        local copy = {}
        for k, v in pairs(original) do
            if type(v) == "table" then
                copy[k] = deepCopy(v)
            else
                copy[k] = v
            end
        end
        return copy
    end

    -- Helper: find zone by id
    local function getZoneById(zoneId)
        for _, zone in ipairs(WorldConfig.combatZones) do
            if zone.id == zoneId then
                return zone
            end
        end
        return nil
    end

    -- Helper: find quest by id
    local function getQuestById(questId)
        for _, quest in ipairs(WorldConfig.quests) do
            if quest.id == questId then
                return quest
            end
        end
        return nil
    end

    -- Player zone tracking: [userId] = zoneId | nil
    local playerZones = {}

    -- Player quest progress: [userId][questId] = { objectives = {...}, startTime = tick() }
    local playerQuests = {}

    -- --------------------------------------------------------
    -- Apply world settings to Workspace/Lighting
    -- --------------------------------------------------------
    local function applyWorldSettings()
        local cfg = WorldConfig.world

        -- Workspace gravity
        Workspace.Gravity = cfg.gravity

        -- Attempt to set Lighting properties safely
        local lighting = game:GetService("Lighting")
        if lighting then
            lighting.Ambient           = cfg.ambientColor
            lighting.FogEnd            = cfg.fogEnd
            lighting.FogColor          = cfg.fogColor
            lighting.TimeOfDay         = cfg.timeOfDay
            lighting.ClockTime         = tonumber(cfg.timeOfDay:match("^(%d+)")) or 14
        end

        print("[WorldGen] World settings applied for:", cfg.name)
    end

    applyWorldSettings()

    -- --------------------------------------------------------
    -- Day/Night Cycle
    -- --------------------------------------------------------
    if WorldConfig.world.cycleEnabled then
        local lighting = game:GetService("Lighting")
        local cycleDuration = WorldConfig.world.cycleDuration

        RunService.Heartbeat:Connect(function(dt)
            -- Advance clock proportionally each frame
            local hoursPerSecond = 24 / cycleDuration
            lighting.ClockTime = (lighting.ClockTime + hoursPerSecond * dt) % 24
        end)
    end

    -- --------------------------------------------------------
    -- Zone Detection: poll player positions
    -- --------------------------------------------------------
    RunService.Heartbeat:Connect(function()
        for _,