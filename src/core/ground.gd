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
}

const COUNT := 23

const NAMES: PackedStringArray = [
	"deep water", "water", "sand", "grass", "moss", "mud", "needles",
	"snow", "bone", "ash", "rock", "road", "floor",
	"heath", "shingle", "gravel", "scree", "limestone", "clinker", "ice", "blackwater", "peat", "river",
]


static func is_water(g: int) -> bool:
	return g == DEEP_WATER or g == WATER or g == BLACKWATER or g == RIVER
