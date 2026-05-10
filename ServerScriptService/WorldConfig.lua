-- WorldConfig.lua
-- Route Rage World — Zone & Spawn Configuration
-- Place in: ServerScriptService
-- DO NOT modify area names — agents reference them by name.

local WorldConfig = {}

WorldConfig.GameName   = "route-rage-world"
WorldConfig.MaxPlayers = 16
WorldConfig.RoundDuration        = 180  -- seconds per round
WorldConfig.IntermissionDuration = 15   -- seconds between rounds
WorldConfig.DefaultArea          = "DowntownStrip"

-- ─────────────────────────────────────────────
-- Areas
-- ─────────────────────────────────────────────
WorldConfig.Areas = {
	{
		name        = "DowntownStrip",
		displayName = "Downtown Strip",
		size        = "medium",
		maxPlayers  = 12,
		-- Central urban boulevard with two opposing spawn clusters
		spawnPoints = {
			Vector3.new( 40, 4,  80),
			Vector3.new( 20, 4,  80),
			Vector3.new(-20, 4,  80),
			Vector3.new(-40, 4,  80),
			Vector3.new( 40, 4, -80),
			Vector3.new( 20, 4, -80),
			Vector3.new(-20, 4, -80),
			Vector3.new(-40, 4, -80),
		},
		ambientColor      = Color3.fromRGB(90, 75, 60),
		ambientBrightness = 0.55,
		fogColor          = Color3.fromRGB(70, 65, 55),
		fogEnd            = 600,
		-- Destructible/cover prop tags expected in workspace
		coverTags = { "Cover_Car", "Cover_Dumpster", "Cover_Barrier", "Cover_Wall" },
	},
	{
		name        = "HighwayOverpass",
		displayName = "Highway Overpass",
		size        = "large",
		maxPlayers  = 16,
		-- Elevated multi-lane highway; spawns staggered across lanes
		spawnPoints = {
			Vector3.new( 60, 18,  120),
			Vector3.new( 20, 18,  120),
			Vector3.new(-20, 18,  120),
			Vector3.new(-60, 18,  120),
			Vector3.new( 60, 18, -120),
			Vector3.new( 20, 18, -120),
			Vector3.new(-20, 18, -120),
			Vector3.new(-60, 18, -120),
			Vector3.new(  0, 18,    0),  -- central overpass midpoint
			Vector3.new( 80, 18,    0),
			Vector3.new(-80, 18,    0),
		},
		ambientColor      = Color3.fromRGB(60, 70, 90),
		ambientBrightness = 0.5,
		fogColor          = Color3.fromRGB(40, 50, 70),
		fogEnd            = 900,
		coverTags = { "Cover_Barrier", "Cover_Car", "Cover_Truck", "Cover_Pillar" },
	},
	{
		name        = "IndustrialYard",
		displayName = "Industrial Yard",
		size        = "medium",
		maxPlayers  = 10,
		-- Tight container yard; short sight lines, close-quarters
		spawnPoints = {
			Vector3.new( 30, 4,  50),
			Vector3.new(-30, 4,  50),
			Vector3.new( 30, 4, -50),
			Vector3.new(-30, 4, -50),
			Vector3.new(  0, 4,  60),
			Vector3.new(  0, 4, -60),
		},
		ambientColor      = Color3.fromRGB(50, 55, 45),
		ambientBrightness = 0.4,
		fogColor          = Color3.fromRGB(30, 35, 25),
		fogEnd            = 350,
		coverTags = { "Cover_Container", "Cover_Crate", "Cover_Pillar", "Cover_Wall" },
	},
	{
		name        = "SuburbanCul",
		displayName = "Suburban Cul-de-Sac",
		size        = "small",
		maxPlayers  = 6,
		-- Residential loop; ideal for small chaotic skirmishes
		spawnPoints = {
			Vector3.new( 15, 4,  25),
			Vector3.new(-15, 4,  25),
			Vector3.new( 15, 4, -25),
			Vector3.new(-15, 4, -25),
		},
		ambientColor      = Color3.fromRGB(100, 90, 70),
		ambientBrightness = 0.65,
		fogColor          = Color3.fromRGB(80, 80, 70),
		fogEnd            = 250,
		coverTags = { "Cover_Car", "Cover_Mailbox", "Cover_Fence", "Cover_Dumpster" },
	},
	{
		name        = "TunnelRun",
		displayName = "Tunnel Run",
		size        = "large",
		maxPlayers  = 14,
		-- Underground freeway tunnel; long corridor, flanking side paths
		spawnPoints = {
			Vector3.new(  0, 2,  200),
			Vector3.new( 10, 2,  200),
			Vector3.new(-10, 2,  200),
			Vector3.new(  0, 2, -200),
			Vector3.new( 10, 2, -200),
			Vector3.new(-10, 2, -200),
			Vector3.new( 20, 2,    0),  -- mid-tunnel flanks
			Vector3.new(-20, 2,    0),
		},
		ambientColor      = Color3.fromRGB(20, 20, 30),
		ambientBrightness = 0.2,
		fogColor          = Color3.fromRGB(15, 15, 25),
		fogEnd            = 300,
		coverTags = { "Cover_Barrier", "Cover_Car", "Cover_Pillar" },
	},
}

-- ─────────────────────────────────────────────
-- Combat / Action Config
-- ─────────────────────────────────────────────
WorldConfig.CombatConfig = {
	-- Respawn
	RespawnDelay        = 5,    -- seconds before a player respawns
	RespawnInvincibility = 3,   -- seconds of spawn protection

	-- Health
	BaseHealth          = 100,
	HealthRegenRate     = 0,    -- no passive regen; pick up health packs
	HealthPackHeal      = 40,

	-- Vehicles (core to route-rage theme)
	VehicleSpeedMultiplier = 1.0,
	VehicleRamDamage       = 60,   -- damage dealt on successful vehicle ram
	VehicleExplosionRadius = 20,   -- studs
	VehicleExplosionDamage = 80,
	MaxVehiclesPerPlayer   = 1,

	-- Weapons
	DefaultWeapon       = "Pistol",
	WeaponDropOnDeath   = true,    -- dropped weapon can be looted
	AmmoPickupAmount    = 30,

	-- Scoring
	KillScore           = 100,
	RamKillBonus        = 50,      -- extra score for vehicle-ram kill
	AssistScore         = 25,
	ObjectiveScore      = 150,

	-- Kill streak thresholds → triggers server broadcast
	KillStreakThresholds = { 3, 5, 10 },

	-- Zone hazard: oil slick chance each round (0–1)
	OilSlickSpawnChance = 0.35,
	OilSlickDuration    = 20,   -- seconds before despawn

	-- Nitro boost (vehicle powerup)
	NitroDuration       = 4,    -- seconds
	NitroSpeedBoost     = 1.6,  -- multiplier on top of VehicleSpeedMultiplier
}

-- ─────────────────────────────────────────────
-- Powerup Config
-- ─────────────────────────────────────────────
WorldConfig.PowerupConfig = {
	SpawnInterval  = 30,  -- seconds between powerup spawns
	MaxPowerups    = 6,   -- max simultaneous powerups in any area
	Powerups = {
		{ id = "Nitro",      weight = 3, duration = WorldConfig.CombatConfig and WorldConfig.CombatConfig.NitroDuration or 4 },
		{ id = "Shield",     weight = 2, duration = 8  },
		{ id = "HealthPack", weight = 4, duration = 0  },  -- instant, no duration
		{ id = "Missile",    weight = 1, duration = 0  },  -- one-shot projectile pickup
	},
}

return WorldConfig