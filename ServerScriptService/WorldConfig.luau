-- world_config.lua
-- Route Rage — World & Spawn Configuration
-- Place in: ServerScriptService
-- DO NOT modify area names — agents reference them by name.

local WorldConfig = {}

WorldConfig.GameName   = "Route Rage"
WorldConfig.MaxPlayers = 12
WorldConfig.RoundDuration        = 240  -- seconds per round
WorldConfig.IntermissionDuration = 15   -- seconds between rounds
WorldConfig.DefaultArea = "HighwayOnramp"

-- Combat tuning shared across all areas
WorldConfig.CombatConfig = {
	RespawnDelay        = 5,       -- seconds before a player respawns
	MaxHealth           = 100,
	ArmorPickupAmount   = 50,      -- bonus armor granted by pickup pads
	SpeedBoostMultiplier = 1.4,    -- speed-pad velocity multiplier
	NitroBoostDuration  = 3,       -- seconds a nitro boost lasts
	RoadKillBonusScore  = 25,      -- extra score for vehicle eliminations
	WeaponDropChance    = 0.35,    -- 0–1 probability an enemy drops a weapon
	FriendlyFire        = false,
	VehicleRespawnDelay = 10,      -- seconds until a destroyed vehicle respawns
}

-- Five road/racing-action areas with spawn points positioned along routes
WorldConfig.Areas = {
	{
		name        = "HighwayOnramp",
		displayName = "Highway On-Ramp",
		size        = "small",
		maxPlayers  = 4,
		spawnPoints = {
			Vector3.new(12, 3, 20),
			Vector3.new(-12, 3, 20),
			Vector3.new(12, 3, -20),
			Vector3.new(-12, 3, -20),
		},
		ambientColor      = Color3.fromRGB(200, 180, 120),
		ambientBrightness = 0.6,
		fogColor          = Color3.fromRGB(180, 170, 140),
		fogEnd            = 300,
		-- Prop tags expected in workspace for this area
		coverTags  = { "Cover_Barrier", "Cover_SignPost", "Cover_Cone" },
		hazardTags = { "Hazard_OilSlick", "Hazard_Pothole" },
	},
	{
		name        = "DowntownGrid",
		displayName = "Downtown Grid",
		size        = "medium",
		maxPlayers  = 8,
		spawnPoints = {
			Vector3.new(40, 3, 40),
			Vector3.new(-40, 3, 40),
			Vector3.new(40, 3, -40),
			Vector3.new(-40, 3, -40),
			Vector3.new(0, 3, 55),
			Vector3.new(0, 3, -55),
		},
		ambientColor      = Color3.fromRGB(80, 90, 120),
		ambientBrightness = 0.45,
		fogColor          = Color3.fromRGB(60, 65, 90),
		fogEnd            = 500,
		coverTags  = { "Cover_Taxi", "Cover_Dumpster", "Cover_NewsStand", "Cover_Barrier" },
		hazardTags = { "Hazard_ManholeSteam", "Hazard_OilSlick", "Hazard_LooseCable" },
	},
	{
		name        = "IndustrialLoop",
		displayName = "Industrial Loop",
		size        = "medium",
		maxPlayers  = 8,
		spawnPoints = {
			Vector3.new(50, 3, 15),
			Vector3.new(-50, 3, 15),
			Vector3.new(50, 3, -15),
			Vector3.new(-50, 3, -15),
			Vector3.new(0, 3, 60),
			Vector3.new(0, 3, -60),
		},
		ambientColor      = Color3.fromRGB(60, 55, 45),
		ambientBrightness = 0.35,
		fogColor          = Color3.fromRGB(50, 45, 40),
		fogEnd            = 400,
		coverTags  = { "Cover_Container", "Cover_Barrel", "Cover_ForkLift", "Cover_Pillar" },
		hazardTags = { "Hazard_SpilledFuel", "Hazard_MovingCrane", "Hazard_OilSlick" },
	},
	{
		name        = "FreewayBridge",
		displayName = "Freeway Bridge",
		size        = "large",
		maxPlayers  = 12,
		spawnPoints = {
			Vector3.new(90, 10, 0),
			Vector3.new(-90, 10, 0),
			Vector3.new(60, 10, 20),
			Vector3.new(-60, 10, 20),
			Vector3.new(60, 10, -20),
			Vector3.new(-60, 10, -20),
			Vector3.new(30, 10, 30),
			Vector3.new(-30, 10, 30),
		},
		ambientColor      = Color3.fromRGB(120, 150, 190),
		ambientBrightness = 0.7,
		fogColor          = Color3.fromRGB(100, 130, 170),
		fogEnd            = 700,
		coverTags  = { "Cover_Barrier", "Cover_Stanchion", "Cover_BrokenCar" },
		hazardTags = { "Hazard_CrossWind", "Hazard_OilSlick", "Hazard_WaterPuddle" },
	},
	{
		name        = "SuburbanSprawl",
		displayName = "Suburban Sprawl",
		size        = "large",
		maxPlayers  = 12,
		spawnPoints = {
			Vector3.new(100, 3, 100),
			Vector3.new(-100, 3, 100),
			Vector3.new(100, 3, -100),
			Vector3.new(-100, 3, -100),
			Vector3.new(0, 3, 110),
			Vector3.new(0, 3, -110),
			Vector3.new(110, 3, 0),
			Vector3.new(-110, 3, 0),
		},
		ambientColor      = Color3.fromRGB(160, 190, 140),
		ambientBrightness = 0.75,
		fogColor          = Color3.fromRGB(140, 170, 130),
		fogEnd            = 900,
		coverTags  = { "Cover_Fence", "Cover_Mailbox", "Cover_Car", "Cover_Hedge", "Cover_Barrel" },
		hazardTags = { "Hazard_SpeedBump", "Hazard_OilSlick", "Hazard_LooseDog" },
	},
}

return WorldConfig