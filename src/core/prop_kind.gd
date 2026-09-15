class_name PropKind
## Static things placed in the world by the generator. Rendered as MultiMesh
## instances per kind per chunk; collided with as circles.

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
}

const COUNT := 32

const NAMES: PackedStringArray = [
	"pine", "broadleaf", "dead tree", "bush", "reeds", "boulder", "stone ore",
	"iron ore", "copper ore", "pylon", "ruin", "house", "lamp", "bones",
	"gorse", "driftwood", "wrack", "mussel rock", "standing stone", "clints", "vent", "tip",
	"wreck", "peat bank", "snow pine", "coal ore", "tin ore", "fire", "bench", "kiln", "cairn", "pole",
]

## Collision radius in tiles at scale 1. 0 means you walk through it.
const SOLID: PackedFloat32Array = [
	0.3, 0.35, 0.25, 0.0, 0.0, 0.45, 0.4,
	0.4, 0.4, 0.4, 0.5, 1.6, 0.15, 0.0,
	0.3, 0.0, 0.0, 0.45, 0.35, 0.0, 0.35, 0.9,
	1.2, 0.4, 0.3, 0.4, 0.4, 0.3, 0.45, 0.6, 0.45, 0.12,
]
