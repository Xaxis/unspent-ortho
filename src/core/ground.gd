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
}

const COUNT := 13

const NAMES: PackedStringArray = [
	"deep water", "water", "sand", "grass", "moss", "mud", "needles",
	"snow", "bone", "ash", "rock", "road", "floor",
]


static func is_water(g: int) -> bool:
	return g == DEEP_WATER or g == WATER
