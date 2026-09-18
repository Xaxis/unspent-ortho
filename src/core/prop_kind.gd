class_name PropKind
## Static things placed in the world by the generator. Rendered as MultiMesh
## instances per kind per chunk; collided with as circles.
##
## New kinds are appended at the end only: ids are saved and hashed.
## From FENCE on: the dystopian evidence each landscape holds (M2.0): what
## people left and still live in, and the machines' works across the land
## (src/models/props/remains.gd and works.gd, placed by GenWorks).

enum {
	PINE,
	BROADLEAF,
	DEAD_TREE,
	BUSH,
	REEDS,
	BOULDER,
	STONE_ORE,
	IRON_ORE,
	COPPER_ORE,
	PYLON,
	RUIN,
	HOUSE,
	LAMP,
	BONES,
	GORSE,
	DRIFTWOOD,
	WRACK,
	MUSSEL_ROCK,
	STANDING_STONE,
	CLINTS,
	VENT,
	TIP,
	WRECK,
	PEAT_BANK,
	SNOW_PINE,
	COAL_ORE,
	TIN_ORE,
	FIRE,
	BENCH,
	KILN,
	CAIRN,
	POLE,
	FENCE,
	BARRICADE,
	SIGN,
	GRAVE,
	DEBRIS,
	SHACK,
	VEHICLE,
	HULL,
	SEA_WALL,
	TIDE_GAUGE,
	INTAKE,
	PUMP_HOUSE,
	PIPE,
	STUMP,
	FIRE_TOWER,
	RELAY,
	CHECKPOINT,
	STACK,
	DRILL_RIG,
	CONVEYOR,
	SURVEY,
	WATER_TANK,
	SLAG_HEAP,
	VENT_CAP,
	ARCHIVE,
	WRECKAGE,
	MEMORIAL,
	# M2 landscapes bring their own things (salt flats, scrapwood).
	SALT_RIDGE,
	SALT_HEAP,
	PAN_GATE,
	SCRAP_TREE,
	MAGNET_HEAP,
	# The Slums: the wall the city painted, and what got bolted over it. The
	# sign itself is not a kind -- `Towers.billboard` hangs it on a wall.
	MURAL,
}

const COUNT := 65

const NAMES: PackedStringArray = [
	"pine", "broadleaf", "dead tree", "bush", "reeds", "boulder", "stone ore",
	"iron ore", "copper ore", "pylon", "ruin", "house", "lamp", "bones",
	"gorse", "driftwood", "wrack", "mussel rock", "standing stone", "clints", "vent", "tip",
	"wreck", "peat bank", "snow pine", "coal ore", "tin ore", "fire", "bench", "kiln", "cairn", "pole",
	"fence", "barricade", "sign", "grave", "debris", "shack", "vehicle", "hull", "sea wall", "tide gauge",
	"intake", "pump house", "pipe", "stump", "fire tower", "relay", "checkpoint", "stack", "drill rig",
	"conveyor", "survey", "water tank", "slag heap", "vent cap", "archive",
	"wreckage", "memorial",
	"salt ridge", "salt heap", "pan gate", "scrap tree", "magnet heap",
	"mural",
]

## Kinds past FENCE that are a landscape's own NATURE, not evidence somebody
## left: they are scattered like a boulder, by the per-tile scatter, and a
## reader counting what happened to a landscape should pass over them.
const WILD: Array[int] = [SALT_RIDGE, SCRAP_TREE, MAGNET_HEAP]

## Collision radius in tiles at scale 1. 0 means you walk through it.
const SOLID: PackedFloat32Array = [
	0.3, 0.35, 0.25, 0.0, 0.0, 0.45, 0.4,
	0.4, 0.4, 0.4, 0.5, 1.6, 0.15, 0.0,
	0.3, 0.0, 0.0, 0.45, 0.35, 0.0, 0.35, 0.9,
	1.2, 0.4, 0.3, 0.4, 0.4, 0.3, 0.45, 0.6, 0.45, 0.12,
	0.0, 0.5, 0.1, 0.0, 0.0, 0.95, 0.8, 1.3, 0.6, 0.15,
	1.2, 0.95, 0.0, 0.0, 0.7, 0.2, 0.5, 0.9, 0.35,
	0.0, 0.0, 0.7, 1.0, 0.4, 0.6,
	0.0, 0.25,
	0.0, 0.55, 0.45, 0.4, 0.3,
	# A mural wall is SIX TILES of wall answered by ONE circle, which is the
	# limit of what a prop can say about itself. Whoever places these should hand
	# the wall to `WorldQuery.set_blocks` as circles along its length, the way a
	# landmark's tower and a depot's deck already do, or a player walks through
	# both ends of it.
	1.5,
]
