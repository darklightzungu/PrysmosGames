-- world_config.lua
-- Route Rage Terrain — Zone & Spawn Configuration
-- Place in: ServerScriptService
-- DO NOT modify area names — agents reference them by name.

local WorldConfig = {}

WorldConfig.GameName   = "route-rage-terrain"
WorldConfig.MaxPlayers = 16
WorldConfig.RoundDuration        = 240  -- seconds per round
WorldConfig.IntermissionDuration = 20   -- seconds between rounds
WorldConfig.DefaultArea          = "HighwayClash"

-- ──────────────────────────────────────────────
-- Areas
-- ──────────────────────────────────────────────
WorldConfig.Areas = {
	{
		name        = "HighwayClash",
		displayName = "Highway Clash",
		size        = "large",
		maxPlayers  = 16,
		-- Spawn points flanking a multi-lane highway strip
		spawnPoints = {
			Vector3.new(90,  4,  20),
			Vector3.new(-90, 4,  20),
			Vector3.new(90,  4, -20),
			Vector3.new(-90, 4, -20),
			Vector3.new(60,  4,  50),
			Vector3.new(-60, 4,  50),
			Vector3.new(60,  4, -50),
			Vector3.new(-60, 4, -50),
		},
		ambientColor      = Color3.fromRGB(90, 80, 60),
		ambientBrightness = 0.65,
		fogColor          = Color3.fromRGB(70, 65, 55),
		fogEnd            = 900,
		-- Destructible/cover props expected in workspace via CollectionService tags
		coverTags = { "Cover_Car", "Cover_Barrier", "Cover_Truck", "Cover_Guardrail" },
	},
	{
		name        = "UrbanIntersection",
		displayName = "Urban Intersection",
		size        = "medium",
		maxPlayers  = 12,
		-- Four-way city crossroads; spawns tucked behind building corners
		spawnPoints = {
			Vector3.new(40,  4,  40),
			Vector3.new(-40, 4,  40),
			Vector3.new(40,  4, -40),
			Vector3.new(-40, 4, -40),
			Vector3.new(0,   4,  55),
			Vector3.new(0,   4, -55),
		},
		ambientColor      = Color3.fromRGB(60, 55, 70),
		ambientBrightness = 0.5,
		fogColor          = Color3.fromRGB(40, 40, 60),
		fogEnd            = 500,
		coverTags = { "Cover_Car", "Cover_Dumpster", "Cover_Wall", "Cover_Pillar" },
	},
	{
		name        = "TunnelRun",
		displayName = "Tunnel Run",
		size        = "small",
		maxPlayers  = 8,
		-- Tight tunnel corridor; spawns at each mouth and mid-side alcoves
		spawnPoints = {
			Vector3.new(70,  3,   0),
			Vector3.new(-70, 3,   0),
			Vector3.new(30,  3,  10),
			Vector3.new(-30, 3,  10),
			Vector3.new(30,  3, -10),
			Vector3.new(-30, 3, -10),
		},
		ambientColor      = Color3.fromRGB(30, 30, 40),
		ambientBrightness = 0.3,
		fogColor          = Color3.fromRGB(20, 20, 30),
		fogEnd            = 250,
		coverTags = { "Cover_Barrel", "Cover_Crate", "Cover_Pillar" },
	},
	{
		name        = "BridgeBattle",
		displayName = "Bridge Battle",
		size        = "medium",
		maxPlayers  = 12,
		-- Elevated bridge; spawns at bridge ends and on lower support platforms
		spawnPoints = {
			Vector3.new(100, 12,   5),
			Vector3.new(-100,12,   5),
			Vector3.new(100, 12,  -5),
			Vector3.new(-100,12,  -5),
			Vector3.new(0,   8,  15),  -- lower support platform
			Vector3.new(0,   8, -15),
		},
		ambientColor      = Color3.fromRGB(50, 70, 90),
		ambientBrightness = 0.55,
		fogColor          = Color3.fromRGB(30, 50, 80),
		fogEnd            = 600,
		coverTags = { "Cover_Car", "Cover_Barrier", "Cover_Crate" },
	},
	{
		name        = "ConstructionZone",
		displayName = "Construction Zone",
		size        = "large",
		maxPlayers  = 16,
		-- Open construction site with elevated scaffolding; multi-level spawns
		spawnPoints = {
			Vector3.new(75,  4,  75),
			Vector3.new(-75, 4,  75),
			Vector3.new(75,  4, -75),
			Vector3.new(-75, 4, -75),
			Vector3.new(0,  14,  40),  -- scaffolding level
			Vector3.new(0,  14, -40),
			Vector3.new(50, 14,   0),
			Vector3.new(-50,14,   0),
		},
		ambientColor      = Color3.fromRGB(80, 70, 50),
		ambientBrightness = 0.6,
		fogColor          = Color3.fromRGB(65, 55, 40),
		fogEnd            = 750,
		coverTags = { "Cover_Crate", "Cover_Wall", "Cover_Barrel", "Cover_Scaffold", "Cover_Truck" },
	},
}

-- ──────────────────────────────────────────────
-- Combat Configuration
-- ──────────────────────────────────────────────
WorldConfig.CombatConfig = {
	-- Health & respawn
	PlayerMaxHealth      = 100,
	RespawnDelay         = 5,      -- seconds before a dead player respawns
	RespawnInvincibility = 2.5,    -- seconds of spawn protection

	-- Damage tuning
	MeleeDamage          = 35,
	MeleeRange           = 6,      -- studs
	MeleeCooldown        = 0.8,    -- seconds between swings

	-- Weapon slots available to all players
	DefaultWeaponSlots   = { "Pistol", "Melee" },

	-- Pickup item tags expected in workspace via CollectionService
	AmmoPickupTag        = "Pickup_Ammo",
	HealthPickupTag      = "Pickup_Health",
	WeaponPickupTag      = "Pickup_Weapon",

	-- Kill streak thresholds and reward DevProduct IDs
	KillStreakThresholds = { 3, 5, 10 },

	-- Vehicle combat (core to the route-rage theme)
	VehiclesEnabled      = true,
	VehicleMaxSpeed      = 120,    -- studs/s
	VehicleRamDamage     = 50,     -- damage dealt on collision with another player
	VehicleRamCooldown   = 1.5,    -- seconds between ram damage events per vehicle
	VehicleHealthPool    = 300,    -- vehicle hitpoints before it is destroyed
	VehicleRespawnDelay  = 12,     -- seconds before a destroyed vehicle respawns

	-- Score settings
	KillScore            = 10,
	AssistScore          = 5,
	VehicleKillBonus     = 15,     -- extra points for ramming a kill
	WinScore             = 50,     -- flat bonus awarded to winning team/player

	-- Team settings
	TeamsEnabled         = true,
	TeamNames            = { "Redline", "Blacktop" },
	FriendlyFire         = false,
}

-- ──────────────────────────────────────────────
-- Gamepass / Monetisation stubs
-- ──────────────────────────────────────────────
WorldConfig.Monetisation = {
	VipGamepassId          = "GAMEPASS_ID_PLACEHOLDER",  -- doubles XP
	ExtraVehicleGamepassId = "GAMEPASS_ID_PLACEHOLDER",  -- unlocks bonus vehicle
	RespawnBoostProductId  = "DEVPRODUCT_ID_PLACEHOLDER", -- instant respawn
}

return WorldConfig