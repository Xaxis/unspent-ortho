class_name Ground
## What a tile's surface is made of. Stored per tile in WorldData.ground.

enum {
	DEEP_WATER,
	WATER,
	SAND,
	GRASS,
	MOSS,
	MUD,
	NEEDLES,
	SNOW,
	BONE,
	ASH,
	ROCK,
	ROAD,
	FLOOR,
	HEATH,
	SHINGLE,
	GRAVEL,
	SCREE,
	LIMESTONE,
	CLINKER,
	ICE,
	BLACKWATER,
	PEAT,
	RIVER,
	# M2: new landscapes bring their own ground. Append only (ids are saved).
	SALT,
	PAN,
	SWARF,
}

const COUNT := 26

const NAMES: PackedStringArray = [
	"deep water", "water", "sand", "grass", "moss", "mud", "needles",
	"snow", "bone", "ash", "rock", "road", "floor",
	"heath", "shingle", "gravel", "scree", "limestone", "clinker", "ice", "blackwater", "peat", "river",
	"salt", "pan", "swarf",
]


static func is_water(g: int) -> bool:
	return g == DEEP_WATER or g == WATER or g == BLACKWATER or g == RIVER


## Out of a body's depth: swum, not waded (src/core/swim.gd).
static func is_deep(g: int) -> bool:
	return g == DEEP_WATER


## Water a body walks through rather than over its head.
static func is_shallow(g: int) -> bool:
	return g == WATER or g == BLACKWATER or g == RIVER
