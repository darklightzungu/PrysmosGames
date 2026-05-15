-- WorldConfig.lua
-- Route Rage Content — World & Game Configuration
-- Place in: ServerScriptService
-- DO NOT rename area entries — agents and systems reference them by name.

local WorldConfig = {}

WorldConfig.GameName   = "route-rage-content"
WorldConfig.MaxPlayers = 12
WorldConfig.RoundDuration        = 210  -- seconds per round
WorldConfig.IntermissionDuration = 15   -- seconds between rounds
WorldConfig.DefaultArea          = "Highway101"

-- ─────────────────────────────────────────────
--  Areas
--  Spawn points are positioned above road/surface level (+4 Y offset)
--  so characters land cleanly without clipping.
-- ─────────────────────────────────────────────
WorldConfig.Areas = {
	{
		name        = "Highway101",
		displayName = "Highway 101",
		description = "A wide multi-lane expressway — high speed, low cover.",
		size        = "large",
		maxPlayers  = 12,
		spawnPoints = {
			Vector3.new( 80,  4,  20),
			Vector3.new(-80,  4,  20),
			Vector3.new( 80,  4, -20),
			Vector3.new(-80,  4, -20),
			Vector3.new(  0,  4,  50),
			Vector3.new(  0,  4, -50),
			Vector3.new( 40,  4,   0),
			Vector3.new(-40,  4,   0),
		},
		ambientColor      = Color3.fromRGB(180, 160, 120),
		ambientBrightness = 0.7,
		fogColor          = Color3.fromRGB(200, 190, 160),
		fogEnd            = 900,
		-- Props/tags expected in Workspace for this area
		coverTags  = { "Cover_GuardRail", "Cover_Car", "Cover_OverpassPillar" },
		hazardTags = { "Hazard_OncomingTraffic", "Hazard_OilSlick" },
	},
	{
		name        = "DowntownGrid",
		displayName = "Downtown Grid",
		description = "Dense city blocks with intersections and tight alleys.",
		size        = "medium",
		maxPlayers  = 10,
		spawnPoints = {
			Vector3.new( 50,  4,  50),
			Vector3.new(-50,  4,  50),
			Vector3.new( 50,  4, -50),
			Vector3.new(-50,  4, -50),
			Vector3.new(  0,  4,  60),
			Vector3.new(  0,  4, -60),
		},
		ambientColor      = Color3.fromRGB(80, 80, 110),
		ambientBrightness = 0.5,
		fogColor          = Color3.fromRGB(60, 60, 90),
		fogEnd            = 500,
		coverTags  = { "Cover_Car", "Cover_Dumpster", "Cover_NewsStand", "Cover_Wall" },
		hazardTags = { "Hazard_Pothole", "Hazard_Pedestrian" },
	},
	{
		name        = "IndustrialPort",
		displayName = "Industrial Port",
		description = "Cargo yard with shipping containers and fork-lift lanes.",
		size        = "medium",
		maxPlayers  = 8,
		spawnPoints = {
			Vector3.new( 60,  4,  30),
			Vector3.new(-60,  4,  30),
			Vector3.new( 60,  4, -30),
			Vector3.new(-60,  4, -30),
			Vector3.new(  0,  4,  70),
			Vector3.new(  0,  4, -70),
		},
		ambientColor      = Color3.fromRGB(60, 70, 60),
		ambientBrightness = 0.45,
		fogColor          = Color3.fromRGB(40, 50, 40),
		fogEnd            = 400,
		coverTags  = { "Cover_Container", "Cover_Crate", "Cover_Forklift", "Cover_Wall" },
		hazardTags = { "Hazard_SwingCrane", "Hazard_OilSlick" },
	},
	{
		name        = "SuburbanLoop",
		displayName = "Suburban Loop",
		description = "Quiet residential streets — narrow roads, parked cars everywhere.",
		size        = "small",
		maxPlayers  = 6,
		spawnPoints = {
			Vector3.new( 25,  4,  25),
			Vector3.new(-25,  4,  25),
			Vector3.new( 25,  4, -25),
			Vector3.new(-25,  4, -25),
		},
		ambientColor      = Color3.fromRGB(140, 180, 120),
		ambientBrightness = 0.65,
		fogColor          = Color3.fromRGB(180, 200, 160),
		fogEnd            = 350,
		coverTags  = { "Cover_Car", "Cover_Hedge", "Cover_Mailbox", "Cover_Fence" },
		hazardTags = { "Hazard_SpeedBump", "Hazard_Pedestrian" },
	},
	{
		name        = "TunnelRun",
		displayName = "Tunnel Run",
		description = "Underground tunnel — chokepoint chaos, limited escape routes.",
		size        = "small",
		maxPlayers  = 6,
		spawnPoints = {
			Vector3.new( 90,  4,   0),
			Vector3.new(-90,  4,   0),
			Vector3.new( 60,  4,  10),
			Vector3.new(-60,  4, -10),
		},
		ambientColor      = Color3.fromRGB(30, 30, 40),
		ambientBrightness = 0.25,
		fogColor          = Color3.fromRGB(20, 20, 30),
		fogEnd            = 180,
		coverTags  = { "Cover_BarrierCone", "Cover_BrokenPillar", "Cover_Car" },
		hazardTags = { "Hazard_LowCeiling", "Hazard_FloodWater" },
	},
}

-- ─────────────────────────────────────────────
--  CombatConfig — action/vehicular combat tuning
-- ─────────────────────────────────────────────
WorldConfig.CombatConfig = {
	-- Vehicle stats base values (scaled by upgrades)
	BaseVehicleSpeed      = 60,   -- studs/s
	MaxVehicleSpeed       = 160,  -- studs/s with full boost
	BoostDuration         = 3,    -- seconds per boost charge
	BoostCooldown         = 8,    -- seconds before next boost

	-- Weapon / projectile settings
	RamDamageBase         = 35,   -- damage dealt on direct vehicle ram
	ProjectileDamageBase  = 20,   -- damage per standard projectile hit
	ProjectileSpeed       = 120,  -- studs/s
	ProjectileLifetime    = 4,    -- seconds before projectile expires

	-- Health & respawn
	PlayerMaxHealth       = 100,
	VehicleMaxHealth      = 250,
	RespawnDelay          = 5,    -- seconds after elimination

	-- Scoring
	EliminationPoints     = 100,
	AssistPoints          = 50,
	HazardKillBonus       = 25,   -- bonus for using environmental hazards
	FirstBloodBonus       = 75,

	-- Power-up spawns
	PowerUpRespawnTime    = 20,   -- seconds between power-up respawns
	PowerUpTypes = {
		"Repair",        -- restores vehicle HP
		"SpeedBoost",    -- temporary top-speed increase
		"Ammo",          -- replenishes projectile count
		"Shield",        -- temporary damage immunity
	},

	-- Match-end conditions
	ScoreLimit            = 1500, -- first team/player to reach this wins
	SuddenDeathThreshold  = 30,   -- seconds remaining when overtime triggers if tied
}

-- ─────────────────────────────────────────────
--  TeamConfig — two rival factions
-- ─────────────────────────────────────────────
WorldConfig.TeamConfig = {
	{
		name      = "Redline",
		color     = BrickColor.new("Bright red"),
		spawnSide = "positive",  -- uses spawn points with positive X
	},
	{
		name      = "Cobalt",
		color     = BrickColor.new("Bright blue"),
		spawnSide = "negative",  -- uses spawn points with negative X
	},
}

return WorldConfig