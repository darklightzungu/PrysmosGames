local WorldConfig = {}

WorldConfig.GameName = "route-rage"
WorldConfig.MaxPlayers = 16
WorldConfig.RoundDuration = 300 -- 5 minutes per round
WorldConfig.DefaultArea = "Highway Interchange"

-- Combat-specific configuration for this action game
WorldConfig.CombatConfig = {
	RespawnDelay = 5,           -- seconds before player respawns
	MaxHealth = 100,
	HealthRegenRate = 2,        -- HP per second when out of combat
	HealthRegenDelay = 8,       -- seconds after last hit before regen begins
	OutOfCombatTime = 6,        -- seconds of no damage to leave combat state
	KillStreakThresholds = {3, 5, 10}, -- kills needed for each streak bonus
	KillStreakBonuses = {
		[3]  = { name = "On Fire",     speedBoost = 1.15 },
		[5]  = { name = "Unstoppable", speedBoost = 1.25, damageBoost = 1.10 },
		[10] = { name = "Rampage",     speedBoost = 1.35, damageBoost = 1.25 },
	},
	FallDamageThreshold = 50,   -- studs of fall before damage applies
	FallDamageMultiplier = 0.5,
	FriendlyFire = false,
	HeadshotMultiplier = 2.0,
	MaxCarryWeight = 50,        -- arbitrary weight units for loadout system
	DefaultWeapon = "Pistol",
	WeaponPickupRadius = 5,     -- studs within which a player can grab a pickup
	PowerupDuration = 15,       -- seconds a powerup remains active
	ScorePerKill = 100,
	ScorePerAssist = 50,
	ScorePerObjective = 200,
}

-- Vehicle configuration relevant to "route-rage" road theme
WorldConfig.VehicleConfig = {
	DefaultSpeed = 60,          -- studs per second base vehicle speed
	MaxSpeed = 120,
	BoostMultiplier = 1.75,
	BoostDuration = 3,          -- seconds per boost charge
	BoostRechargeTime = 8,
	RamDamageMultiplier = 1.5,  -- bonus damage when colliding with an enemy
	VehicleHealthPool = 300,
	VehicleRespawnDelay = 10,
}

-- Areas for the game world with realistic spawn Vector3 positions
WorldConfig.Areas = {
	{
		name = "Highway Interchange",  -- starting area: elevated multilane crossing
		spawnPoints = {
			Vector3.new(  10,  5,   0),
			Vector3.new( -10,  5,   0),
			Vector3.new(   0,  5,  15),
			Vector3.new(   0,  5, -15),
			Vector3.new(  20,  5,  20),
			Vector3.new( -20,  5, -20),
		},
	},
	{
		name = "Industrial Dockyard",  -- waterfront with cargo stacks and cranes
		spawnPoints = {
			Vector3.new( 150, 3,  200),
			Vector3.new( 170, 3,  220),
			Vector3.new( 130, 3,  180),
			Vector3.new( 160, 12, 200), -- elevated cargo container top
			Vector3.new( 145, 3,  240),
			Vector3.new( 175, 3,  185),
		},
	},
	{
		name = "Abandoned Overpass",   -- crumbling elevated road with gaps
		spawnPoints = {
			Vector3.new(-200, 40,  50),
			Vector3.new(-220, 40,  70),
			Vector3.new(-180, 40,  30),
			Vector3.new(-210, 40,  90),
			Vector3.new(-190, 40,  10),
		},
	},
	{
		name = "Downtown Grid",        -- tight city-block street fighting
		spawnPoints = {
			Vector3.new(  80, 3, -150),
			Vector3.new( 100, 3, -130),
			Vector3.new(  60, 3, -170),
			Vector3.new(  90, 3, -190),
			Vector3.new(  70, 3, -120),
			Vector3.new( 110, 3, -160),
			Vector3.new(  50, 3, -140),
		},
	},
	{
		name = "Tunnel Network",       -- underground corridors beneath the city
		spawnPoints = {
			Vector3.new( -50, -10, -300),
			Vector3.new( -70, -10, -320),
			Vector3.new( -30, -10, -280),
			Vector3.new( -60, -10, -340),
			Vector3.new( -40, -10, -260),
		},
	},
}

-- Quick-access lookup: area name -> area table (built at require time)
WorldConfig.AreaMap = {}
for _, area in ipairs(WorldConfig.Areas) do
	WorldConfig.AreaMap[area.name] = area
end

return WorldConfig