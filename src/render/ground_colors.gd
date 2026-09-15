class_name GroundColors
## Ground and cliff colours per Ground type, from art-audio-extract §2b.
## Each ground has three grades (dark, base, light). The grade a tile shows comes
## from a WORLD-POSITION field, never per-tile noise: large forms, flat masses,
## no chequerboard.

static var _top: Array = []
static var _side: Array = []


static func _static_init() -> void:
	_top.resize(Ground.COUNT)
	_side.resize(Ground.COUNT)
	_put(Ground.DEEP_WATER, [Palette.BRINE[0], Palette.BRINE[1], Palette.BRINE[1]], [Palette.BRINE[0], Palette.BRINE[0]])
	_put(Ground.WATER, [Palette.SAND[2], Palette.SAND[3], Palette.SAND[3]], [Palette.SAND[1], Palette.SAND[2]])
	_put(Ground.SAND, [Palette.SAND[3], Palette.SAND[4], Palette.SAND[4].lerp(Palette.SAND[5], 0.35)], [Palette.SAND[2], Palette.SAND[3]])
	_put(Ground.GRASS, [Palette.MOSS[2], Palette.MOSS[3], Palette.MOSS[3].lerp(Palette.MOSS[4], 0.3)], [Palette.SLATE[1], Palette.SLATE[2]])
	_put(Ground.MOSS, [Palette.MOSS[1], Palette.MOSS[2], Palette.MOSS[2].lerp(Palette.SPRUCE[3], 0.4)], [Palette.EARTH[1], Palette.EARTH[2]])
	_put(Ground.MUD, [Palette.EARTH[1], Palette.EARTH[2], Palette.EARTH[2].lerp(Palette.MOSS[2], 0.3)], [Palette.EARTH[1], Palette.EARTH[1].lerp(Palette.EARTH[2], 0.5)])
	_put(Ground.NEEDLES, [Palette.EARTH[1], Palette.EARTH[2], Palette.EARTH[3]], [Palette.SLATE[1], Palette.EARTH[1]])
	_put(Ground.SNOW, [Palette.RIME[4], Palette.RIME[5], Palette.RIME[5]], [Palette.RIME[2], Palette.RIME[3]])
	_put(Ground.BONE, [Palette.LINEN[3], Palette.LINEN[4], Palette.LINEN[5]], [Palette.LINEN[2], Palette.LINEN[3]])
	_put(Ground.ASH, [Palette.ASH[0], Palette.ASH[1], Palette.ASH[2]], [Palette.STONE[0], Palette.STONE[1]])
	_put(Ground.ROCK, [Palette.SLATE[2], Palette.SLATE[3], Palette.STONE[3]], [Palette.SLATE[1], Palette.SLATE[2]])
	_put(Ground.ROAD, [Palette.EARTH[2], Palette.EARTH[3], Palette.EARTH[3].lerp(Palette.SAND[3], 0.4)], [Palette.EARTH[1], Palette.EARTH[2]])
	# Placeholders for grounds the worldgen package adds; the landscape package tunes them.
	_put(Ground.HEATH, [Palette.EARTH[2], Palette.EARTH[2].lerp(Palette.MOSS[2], 0.5), Palette.MOSS[2]], [Palette.SLATE[1], Palette.SLATE[2]])
	_put(Ground.SHINGLE, [Palette.STONE[1], Palette.STONE[2], Palette.STONE[3]], [Palette.SLATE[1], Palette.SLATE[2]])
	_put(Ground.GRAVEL, [Palette.STONE[1], Palette.STONE[2], Palette.STONE[3]], [Palette.STONE[0], Palette.STONE[1]])
	_put(Ground.SCREE, [Palette.SLATE[1], Palette.SLATE[2], Palette.SLATE[3]], [Palette.SLATE[0], Palette.SLATE[1]])
	_put(Ground.LIMESTONE, [Palette.LINEN[3], Palette.LINEN[4], Palette.LINEN[5]], [Palette.LINEN[2], Palette.LINEN[3]])
	_put(Ground.CLINKER, [Palette.STONE[0], Palette.STONE[1], Palette.INK[3]], [Palette.INK[1], Palette.INK[2]])
	_put(Ground.ICE, [Palette.RIME[3], Palette.RIME[4], Palette.RIME[5]], [Palette.RIME[2], Palette.RIME[3]])
	_put(Ground.BLACKWATER, [Palette.BRINE[0], Palette.SPRUCE[1], Palette.SPRUCE[2]], [Palette.EARTH[1], Palette.EARTH[1]])
	_put(Ground.PEAT, [Palette.EARTH[1], Palette.EARTH[1].lerp(Palette.EARTH[2], 0.5), Palette.EARTH[2]], [Palette.EARTH[0], Palette.EARTH[1]])
	_put(Ground.RIVER, [Palette.BRINE[2], Palette.BRINE[3], Palette.BRINE[3]], [Palette.SLATE[1], Palette.SLATE[2]])
	_put(Ground.FLOOR, [Palette.STONE[1], Palette.STONE[2], Palette.STONE[3]], [Palette.STONE[0], Palette.STONE[1]])


static func _put(g: int, top: Array[Color], side: Array[Color]) -> void:
	# Grades sit close to the base: a field reads as one mass with slow drifts.
	_top[g] = [top[1].lerp(top[0], 0.4), top[1], top[1].lerp(top[2], 0.4)]
	_side[g] = side


## grade: 0 dark, 1 base, 2 light.
static func top(g: int, grade: int) -> Color:
	return _top[g][grade]


## band: 0 or 1, alternating per level of cliff.
static func side(g: int, band: int) -> Color:
	return _side[g][band]
