class_name GroundColors
## Ground colours per Ground type AND per country, from art-audio-extract §2b.
##
## A tile's base colour is table[ground][country] mixed toward
## table[ground][country2] by blend, so the same grass is grey-green on the coast,
## blue-dark under pines, frost-bitten toward the snow, bleached on the bones and
## scorched near the burning. Grades, patterns and dusting are drawn on top by
## world.gdshader from world-position fields (never per-tile noise).
##
## Every colour here is a palette value or a fixed mix of two palette values.

## The measured one-ramp-step darken of the source game (art-audio-extract §8).
const STEP_DOWN := Vector3(0.700, 0.704, 0.749)

static var _table: Array[Color] = []
static var _side: Array = []


static func _static_init() -> void:
	_table.resize(Ground.COUNT * Country.COUNT)
	for g in Ground.COUNT:
		for c in Country.COUNT:
			_table[g * Country.COUNT + c] = _make(g, c)
	_side.resize(Ground.COUNT)
	for g in Ground.COUNT:
		var b := base(g, Country.COAST)
		_side[g] = [down(b, 1.0), down(b, 1.6)]


static func _m(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)


## The home look of a ground, before any country's mood.
static func _native(g: int) -> Color:
	match g:
		Ground.DEEP_WATER: return Palette.BRINE[1]
		Ground.WATER: return _m(Palette.SAND[3], Palette.BRINE[2], 0.4)
		Ground.SAND: return Palette.SAND[4]
		Ground.GRASS: return _m(Palette.MOSS[3], Palette.MOSS[2], 0.4)
		Ground.MOSS: return _m(Palette.MOSS[2], Palette.SPRUCE[2], 0.3)
		Ground.MUD: return _m(Palette.EARTH[2], Palette.EARTH[1], 0.3)
		Ground.NEEDLES: return _m(Palette.EARTH[2], Palette.EARTH[1], 0.3)
		Ground.SNOW: return Palette.RIME[5]
		Ground.BONE: return _m(Palette.LINEN[4], Palette.LINEN[5], 0.25)
		Ground.ASH: return _m(Palette.ASH[1], Palette.ASH[2], 0.45)
		Ground.ROCK: return Palette.SLATE[2]
		Ground.ROAD: return _m(Palette.EARTH[3], Palette.SAND[3], 0.3)
		Ground.FLOOR: return Palette.STONE[2]
		Ground.HEATH: return _m(Palette.EARTH[2], Palette.MOSS[2], 0.45)
		Ground.SHINGLE: return _m(Palette.STONE[2], Palette.SAND[2], 0.25)
		Ground.GRAVEL: return _m(Palette.STONE[2], Palette.SAND[3], 0.3)
		Ground.SCREE: return _m(Palette.SLATE[2], Palette.SLATE[1], 0.3)
		Ground.LIMESTONE: return Palette.LINEN[4]
		Ground.CLINKER: return _m(Palette.STONE[0], Palette.INK[2], 0.4)
		Ground.ICE: return _m(Palette.RIME[4], Palette.RIME[3], 0.2)
		Ground.BLACKWATER: return Palette.BRINE[0]
		Ground.PEAT: return _m(Palette.EARTH[1], Palette.EARTH[2], 0.3)
		Ground.RIVER: return _m(Palette.SAND[3], Palette.BRINE[2], 0.4)
	return Palette.BLOOM[3]


## Which country a ground belongs to; elsewhere it takes that country's mood.
static func _home(g: int) -> int:
	match g:
		Ground.MOSS, Ground.MUD, Ground.PEAT, Ground.BLACKWATER: return Country.MOSS
		Ground.NEEDLES: return Country.PINEWOOD
		Ground.SNOW, Ground.ICE: return Country.SNOWFIELD
		Ground.BONE, Ground.LIMESTONE, Ground.SCREE: return Country.BONELANDS
		Ground.ASH, Ground.CLINKER: return Country.BURNING
	return Country.COAST


static func _make(g: int, c: int) -> Color:
	var col := _native(g)
	# Rock takes the country's geology rather than a mood.
	match g:
		Ground.ROCK, Ground.SCREE, Ground.SHINGLE, Ground.GRAVEL:
			match c:
				Country.BONELANDS: return _m(col, Palette.LINEN[3], 0.45)
				Country.BURNING: return _m(col, Palette.INK[3], 0.55)
				Country.SNOWFIELD: return _m(col, Palette.RIME[3], 0.3)
				Country.MOSS: return _m(col, Palette.SPRUCE[2], 0.25)
				Country.PINEWOOD: return _m(col, Palette.SPRUCE[1], 0.2)
			return col
		Ground.SNOW:
			match c:
				Country.BURNING: return _m(Palette.RIME[4], Palette.ASH[3], 0.5)
				Country.SNOWFIELD: return col
			return _m(col, Palette.RIME[4], 0.35)
	if c == _home(g) or c == Country.SEA:
		return col
	match c:
		Country.COAST: return _m(col, Palette.MOSS[3], 0.1)
		Country.MOSS: return _m(col, Palette.SPRUCE[1], 0.2)
		Country.PINEWOOD: return _m(col, Palette.SPRUCE[2], 0.16)
		Country.SNOWFIELD: return _m(col, Palette.RIME[4], 0.32)
		Country.BONELANDS: return _m(col, Palette.LINEN[4], 0.22)
		Country.BURNING: return _m(col, Palette.ASH[1], 0.4)
	return col


## Base colour of a ground in a country.
static func base(g: int, c: int) -> Color:
	return _table[clampi(g, 0, Ground.COUNT - 1) * Country.COUNT + clampi(c, 0, Country.COUNT - 1)]


## A tile's base colour across an ecotone. blend 0.5 on the border meets the
## neighbour's colour exactly, so there is no seam.
static func tile(g: int, c: int, c2: int, blend: float) -> Color:
	if blend <= 0.0:
		return base(g, c)
	return base(g, c).lerp(base(g, c2), blend)


## n ramp steps darker (fractional allowed), the palette's own blue-violet step.
static func down(col: Color, n: float = 1.0) -> Color:
	return Color(col.r * pow(STEP_DOWN.x, n), col.g * pow(STEP_DOWN.y, n), col.b * pow(STEP_DOWN.z, n), col.a)


## n ramp steps lighter.
static func up(col: Color, n: float = 1.0) -> Color:
	return down(col, -n).clamp()


## Legacy grades (0 dark, 1 base, 2 light) of the coast look; the map tool uses them.
static func top(g: int, grade: int) -> Color:
	var b := base(g, Country.COAST)
	match grade:
		0: return down(b, 0.4)
		2: return up(b, 0.3)
	return b


## Legacy cliff bands (0 or 1) of the coast look.
static func side(g: int, band: int) -> Color:
	return _side[clampi(g, 0, Ground.COUNT - 1)][band & 1]


static func luminance(col: Color) -> float:
	return (0.299 * col.r + 0.587 * col.g + 0.114 * col.b) * 255.0
