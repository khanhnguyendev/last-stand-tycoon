class_name MapLayout
extends RefCounted
## The single source of map coordinates (spec 6.1, D-054, D-055, D-062, D-091–D-093, D-112).
## Positions are Vector2(x, z). North = −z. Origin = diner center.

const DINER_HALF := 4.0
const DINER_HEIGHT := 3.0
const BOUNDS_MIN := Vector2(-24, -24)
const BOUNDS_MAX := Vector2(24, 14)
const HOME := Vector2(0, 9.5)  ## outside every zone (D-122); the sign is SIGN
## New game and night-1 restart spawn: north of the diner, off the lane, outside every zone (D-126).
const NIGHT1_START := Vector2(-2.5, -7)
const HERO_RADIUS := 0.4
const TOWER_VISUAL_RADIUS := 0.5  ## mesh only: towers never collide with the hero (D-125)

const LANE_PATHS := {
	"north": [Vector2(0, -24), Vector2(0, -5.2)],
	"west": [Vector2(-16, -24), Vector2(-11, -11), Vector2(-5.2, 0)],
	"east": [Vector2(16, -24), Vector2(11, -11), Vector2(5.2, 0)],
}
## Width axis of each lane's attack zone (D-111).
## Oriented so dot(axis, end-of-path perpendicular) > 0, keeping the blend on one side of the centerline.
const ZONE_AXIS := {"north": Vector2(-1, 0), "west": Vector2(0, 1), "east": Vector2(0, -1)}
## Band between each wall and the reach line (D-101). Rect2(x, z, w, h).
const ZONE_RECTS := {
	"west": Rect2(-5.2, -1.5, 1.2, 3.0),
	"north": Rect2(-1.5, -5.2, 3.0, 1.2),
	"east": Rect2(4.0, -1.5, 1.2, 3.0),
}

const SPOT_IDS: Array[String] = ["tower_nw", "tower_ne", "fence_w", "fence_n", "fence_e"]
const TOWER_SPOTS := {"tower_nw": Vector2(-5, -5), "tower_ne": Vector2(5, -5)}
const TOWER_LANES := {"tower_nw": ["west", "north"], "tower_ne": ["north", "east"]}
const FENCE_LANE := {"fence_w": "west", "fence_n": "north", "fence_e": "east"}
const LANE_FENCE := {"west": "fence_w", "north": "fence_n", "east": "fence_e"}
const FENCE_OFFSET_FROM_END := 4.0
const TELEGRAPH_OFFSET_FROM_END := 5.5

const COUNTER := Vector2(0, 4.8)
const COUNTER_SIZE := Vector2(3, 1)
const COUNTER_DROP := Vector2(2.2, 4.8)
const SERVICE_POINT := Vector2(0, 6.0)
## Slots 0-3: the S1 diagonal. Slots 4-8 (E1, D-230): a second row just north of the road, filling eastward, so an
## arriving traveler never walks through the queue and the whole line is on screen from the counter.
const QUEUE_SLOTS := [Vector2(0, 6.0), Vector2(-1.2, 7.0), Vector2(-2.4, 8.0), Vector2(-3.6, 9.0),
	Vector2(-3.0, 10.3), Vector2(-1.8, 10.3), Vector2(-0.6, 10.3), Vector2(0.6, 10.3), Vector2(1.8, 10.3)]
const GOLD_PILE := Vector2(-2.5, 5.5)
const FREEZER := Vector2(5.5, 5.0)
const FREEZER_SIZE := Vector2(1.5, 1.5)
const FREEZER_ZONE := Vector2(5.5, 6.3)
const SIGN := Vector2(0, 8)
const ROAD_Z := 11.0
const TRAVELER_ENTER := Vector2(24, 11)
const TRAVELER_EXIT := Vector2(-24, 11)
const STATION_RADIUS := 1.0
const BUILD_RADIUS := 1.2
## E1 upgrade pads (radius BUILD_RADIUS) and where the hero stands to use each station (camera test).
const STATION_PADS := {&"counter": Vector2(2.6, 7.2), &"freezer": Vector2(7.9, 7.0)}
const STATION_STAND := {&"counter": COUNTER_DROP, &"freezer": FREEZER_ZONE}

## S2 guard posts (D-163): the Archer on the diner roof; the Tank on the west lane's center line,
## TANK_POST_BACK m before the lane end. A knocked-out guard respawns at DINER_DOOR (D-165).
const GUARD_POST_ARCHER := Vector2(2.5, -2.5)
const DINER_DOOR := Vector2(-3.0, 4.6)
const TANK_POST_BACK := 3.0

static func guard_post(id: StringName) -> Vector2:
	if id == &"archer":
		return GUARD_POST_ARCHER
	assert(id == &"tank", "no guard post for %s" % id)
	return Geometry.point_back_from_end(LANE_PATHS["west"], TANK_POST_BACK)

## Door -> south-west corner (outside the diner) -> Tank post; test_geometry proves it clears the diner and towers.
static func tank_return_path() -> Array:
	return [DINER_DOOR, Vector2(-5.0, 4.6), guard_post(&"tank")]

static func to3(v: Vector2, y := 0.0) -> Vector3:
	return Vector3(v.x, y, v.y)

static func path_length(lane: String) -> float:
	return Geometry.path_length(LANE_PATHS[lane])

static func lane_end(lane: String) -> Vector2:
	var path: Array = LANE_PATHS[lane]
	return path[path.size() - 1]

static func fence_spot(lane: String) -> Vector2:
	return Geometry.point_back_from_end(LANE_PATHS[lane], FENCE_OFFSET_FROM_END)

static func telegraph_spot(lane: String) -> Vector2:
	return Geometry.point_back_from_end(LANE_PATHS[lane], TELEGRAPH_OFFSET_FROM_END)

static func spot_kind(spot_id: String) -> String:
	return "tower" if spot_id.begins_with("tower") else "fence"

static func spot_position(spot_id: String) -> Vector2:
	if TOWER_SPOTS.has(spot_id):
		return TOWER_SPOTS[spot_id]
	return fence_spot(FENCE_LANE[spot_id])
