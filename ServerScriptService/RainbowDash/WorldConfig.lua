local WorldConfig = {}

WorldConfig.GameName = "Rainbow Dash"
WorldConfig.MaxPlayers = 12
WorldConfig.RoundDuration = 300 -- 5 minutes per puzzle round
WorldConfig.DefaultArea = "Prism Lobby"

-- Puzzle-specific configuration
WorldConfig.PuzzleConfig = {
	HintCooldown = 30,           -- seconds between hint requests
	MaxHintsPerRound = 3,        -- hints allowed per player per round
	SolveScoreBase = 100,        -- base score awarded for solving a puzzle
	TimeBonus = true,            -- award bonus points for fast solves
	TimeBonusMultiplier = 1.5,   -- multiplier applied to time-remaining bonus
	CheckpointSaveEnabled = true, -- save player progress mid-round
	ColorblindAssist = true,     -- enable colorblind-friendly overlays
	PuzzleResetDelay = 5,        -- seconds before resetting a failed puzzle
	CoopSolveBonus = 25,         -- extra points when 2+ players solve together
	SequencePuzzleSteps = 6,     -- number of steps in sequence-type puzzles
}

WorldConfig.Areas = {
	{
		name = "Prism Lobby",
		description = "The central hub where players gather before rounds begin.",
		spawnPoints = {
			Vector3.new(0, 2, 0),
			Vector3.new(5, 2, 0),
			Vector3.new(-5, 2, 0),
			Vector3.new(0, 2, 5),
			Vector3.new(0, 2, -5),
			Vector3.new(5, 2, 5),
			Vector3.new(-5, 2, 5),
			Vector3.new(5, 2, -5),
			Vector3.new(-5, 2, -5),
		},
		puzzleType = nil, -- lobby area, no puzzles
		ambientColor = Color3.fromRGB(255, 255, 255),
	},
	{
		name = "Chromatic Caverns",
		description = "Underground caves with color-matching tile puzzles.",
		spawnPoints = {
			Vector3.new(120, 4, 30),
			Vector3.new(128, 4, 30),
			Vector3.new(124, 4, 38),
			Vector3.new(116, 4, 38),
			Vector3.new(132, 4, 22),
		},
		puzzleType = "ColorMatch",
		ambientColor = Color3.fromRGB(80, 40, 120),
	},
	{
		name = "Spectrum Bridge",
		description = "A series of suspended platforms requiring sequence puzzles to cross.",
		spawnPoints = {
			Vector3.new(-150, 20, 10),
			Vector3.new(-142, 20, 10),
			Vector3.new(-146, 20, 18),
			Vector3.new(-154, 20, 18),
			Vector3.new(-138, 20, 2),
		},
		puzzleType = "Sequence",
		ambientColor = Color3.fromRGB(255, 180, 60),
	},
	{
		name = "Refraction Ruins",
		description = "Ancient ruins with mirror and light-beam deflection puzzles.",
		spawnPoints = {
			Vector3.new(60, 6, -200),
			Vector3.new(68, 6, -200),
			Vector3.new(64, 6, -192),
			Vector3.new(52, 6, -192),
			Vector3.new(76, 6, -208),
			Vector3.new(60, 6, -208),
		},
		puzzleType = "LightBeam",
		ambientColor = Color3.fromRGB(180, 220, 255),
	},
	{
		name = "Aurora Apex",
		description = "The final challenge zone with multi-layer rainbow cipher puzzles.",
		spawnPoints = {
			Vector3.new(0, 80, -350),
			Vector3.new(8, 80, -350),
			Vector3.new(-8, 80, -350),
			Vector3.new(4, 80, -342),
			Vector3.new(-4, 80, -342),
		},
		puzzleType = "RainbowCipher",
		ambientColor = Color3.fromRGB(200, 255, 220),
	},
}

-- Helper: look up an area table by name
function WorldConfig.GetAreaByName(areaName)
	for _, area in ipairs(WorldConfig.Areas) do
		if area.name == areaName then
			return area
		end
	end
	return nil -- area not found
end

-- Helper: return a random spawn point Vector3 from a given area
function WorldConfig.GetRandomSpawn(areaName)
	local area = WorldConfig.GetAreaByName(areaName)
	if not area or #area.spawnPoints == 0 then
		return Vector3.new(0, 2, 0) -- fallback to world origin
	end
	local index = math.random(1, #area.spawnPoints)
	return area.spawnPoints[index]
end

-- Helper: return the default area table
function WorldConfig.GetDefaultArea()
	return WorldConfig.GetAreaByName(WorldConfig.DefaultArea)
end

return WorldConfig
