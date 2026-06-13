-- WorldConfig.lua — Daily Blox Delivery (Neo Paperboy v1)
-- Central configuration module; require this from both server and client scripts.
-- Never mutate the returned table at runtime — treat it as read-only.

local WorldConfig = {}

-- ─── Game Identity ────────────────────────────────────────────────────────────
WorldConfig.GameTitle   = "Daily Blox Delivery"
WorldConfig.Version     = "1.0.0"

-- ─── Scroll / Road ────────────────────────────────────────────────────────────
WorldConfig.ScrollSpeed    = 32   -- studs per second; player's forward movement rate
WorldConfig.RoadHalfWidth  = 16   -- studs from road centre to either kerb
WorldConfig.StreetLength   = 600  -- total playable road length in studs
WorldConfig.FallKillY      = -20  -- Y threshold below which the player is respawned / killed

-- ─── Player State ─────────────────────────────────────────────────────────────
WorldConfig.StartLives       = 3
WorldConfig.StartSubscribers = 8   -- houses that begin as active subscribers
WorldConfig.PaperCount       = 20  -- newspapers the player carries at the start of each run

-- ─── Scoring ──────────────────────────────────────────────────────────────────
-- Points awarded per successful delivery target type.
WorldConfig.Score = {
	Mailbox  = 700,  -- precision throw directly into the mailbox
	Porch    = 350,  -- lands anywhere on the porch area
	Chaos    = 300,  -- intentional chaos bonus (e.g. smashing a garden gnome)
	Bundle   = 50,   -- picking up a bonus paper bundle mid-run
}

-- ─── Houses ───────────────────────────────────────────────────────────────────
-- Each entry describes one house on the street.
--   z          : distance along the road (studs from spawn)
--   x          : lateral offset from road centre (negative = left side, positive = right side)
--   subscriber : true  → active subscriber; missing a delivery loses a subscriber
--                false → non-subscriber; hitting their property causes a chaos penalty
WorldConfig.Houses = {
	{ z =  60,  x = -14, subscriber = true  },
	{ z =  60,  x =  14, subscriber = true  },
	{ z = 120,  x = -14, subscriber = true  },
	{ z = 120,  x =  14, subscriber = false },
	{ z = 200,  x = -14, subscriber = true  },
	{ z = 200,  x =  14, subscriber = true  },
	{ z = 280,  x = -14, subscriber = false },
	{ z = 280,  x =  14, subscriber = true  },
	{ z = 360,  x = -14, subscriber = true  },
	{ z = 360,  x =  14, subscriber = true  },
	{ z = 440,  x = -14, subscriber = true  },
	{ z = 520,  x =  14, subscriber = false },
}

-- ─── Obstacles ────────────────────────────────────────────────────────────────
-- Each entry describes one hazard placed on the street.
-- Fields:
--   kind : string identifier matched against the obstacle spawner
--   z    : distance along the road (studs from spawn)
--   lane : integer lane index for vehicle-style obstacles
--            0 = centre lane, negative = left, positive = right
--   x    : explicit lateral offset (studs) for static props;
--           ignored when `lane` is present — the spawner converts lane → x at runtime
--
-- NOTE: "car" and "pothole" use `lane` so the spawner can apply lane-width logic.
--       All other obstacles use an explicit `x` position for precise placement.
WorldConfig.Obstacles = {
	{ kind = "car",      z = 180, lane =   0              },  -- oncoming vehicle, centre lane
	{ kind = "dog",      z = 260,            x = -10      },  -- dog darting from left kerb
	{ kind = "trash",    z = 320,            x =  12      },  -- fallen bin on right side
	{ kind = "hydrant",  z = 400,            x = -12      },  -- fire hydrant, left pavement
	{ kind = "sign",     z = 480,            x =  10      },  -- fallen street sign, right side
	{ kind = "pothole",  z = 540, lane =   0              },  -- road pothole, centre lane
}

-- ─── Derived / Computed Helpers ───────────────────────────────────────────────
-- Cached values derived from the config above so consumers don't recompute them.

-- Total number of subscriber houses; used to calculate end-of-run score percentage.
local subscriberCount = 0
for _, house in ipairs(WorldConfig.Houses) do
	if house.subscriber then
		subscriberCount = subscriberCount + 1
	end
end
WorldConfig.TotalSubscriberHouses = subscriberCount  -- read-only; do not override

-- Width of a single road lane (two lanes fill the road half-width on each side).
WorldConfig.LaneWidth = WorldConfig.RoadHalfWidth / 2  -- 8 studs per lane

-- ─── Validation (runs once at require-time in Studio / server) ────────────────
-- Catches misconfiguration early rather than producing silent runtime bugs.
do
	assert(WorldConfig.PaperCount >= subscriberCount,
		string.format(
			"[WorldConfig] PaperCount (%d) must be >= TotalSubscriberHouses (%d) "
			.. "so every subscriber can receive a paper.",
			WorldConfig.PaperCount, subscriberCount
		)
	)
	assert(WorldConfig.StartLives > 0,
		"[WorldConfig] StartLives must be a positive integer."
	)
	assert(WorldConfig.ScrollSpeed > 0,
		"[WorldConfig] ScrollSpeed must be a positive number."
	)
	for i, obs in ipairs(WorldConfig.Obstacles) do
		assert(
			obs.lane ~= nil or obs.x ~= nil,
			string.format(
				"[WorldConfig] Obstacle #%d ('%s') must define either 'lane' or 'x'.",
				i, tostring(obs.kind)
			)
		)
		assert(
			obs.z > 0 and obs.z <= WorldConfig.StreetLength,
			string.format(
				"[WorldConfig] Obstacle #%d ('%s') z=%d is outside the street (0–%d).",
				i, tostring(obs.kind), obs.z, WorldConfig.StreetLength
			)
		)
	end
end

return WorldConfig