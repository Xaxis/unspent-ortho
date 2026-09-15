class_name Country
## The six countries of the coast, plus the sea. One arc is placed per country,
## so world generation guarantees every land country exists on every seed.

enum {
	SEA,
	COAST,
	MOSS,
	PINEWOOD,
	SNOWFIELD,
	BONELANDS,
	BURNING,
}

const COUNT := 7
const LAND: Array[int] = [COAST, MOSS, PINEWOOD, SNOWFIELD, BONELANDS, BURNING]
const NAMES: PackedStringArray = ["sea", "coast", "moss", "pinewood", "snowfield", "bonelands", "burning"]
