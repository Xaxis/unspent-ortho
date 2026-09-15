class_name GroundColors
## The washes of the land (docs/ART.md §3): what colour a ground is in each
## country, which ink MARK world.gdshader draws into it, and what its cliffs are
## made of. Every wash is a palette value or a named mix of two.
##
## Marks are stored in a vertex colour's alpha as `code / 255` (see
## world.gdshader). 0 and 255 are plain, so an ordinary palette colour
## (alpha 1) never carries a mark.

## The measured one-ramp-step darken of the source game (art-audio-extract §8).
const STEP_DOWN := Vector3(0.700, 0.704, 0.749)
const P := preload("res://src/render/palette.gd")

## Mark codes. Keep in sync with world.gdshader.
const PLAIN := 0
## 1..16: glowing (ember, flame), strength code / 8. 17..32: a lamp, lit when
## the sky is dim, strength (code - 16) / 8.
const GLOW := 0
const LAMP := 16
const GLINT := 33
const TURF := 40
const HEATH := 41
const SAND := 42
const SHINGLE := 43
const SNOW := 44
const PAVEMENT := 45
const ASH := 46
const CLINKER := 47
const FEN := 48
const PEAT := 49
const NEEDLES := 50
const ICE := 51
const ROCK := 52
const MUD := 53
const ROAD := 54
## Cliff strata: STRATA + one of the STRATA_* ids.
const STRATA := 60
const STRATA_COAST := 1
const STRATA_MOSS := 2
const STRATA_PINE := 3
const STRATA_SNOW := 4
const STRATA_BONE := 5
const STRATA_BASALT := 6
const STRATA_SAND := 7
const STRATA_ICE := 8

static var _wash: PackedColorArray
static var _marks: PackedInt32Array
static var _cliff: PackedColorArray


static func _static_init() -> void:
	_wash.resize(Ground.COUNT * Country.COUNT)
	_marks.resize(Ground.COUNT * Country.COUNT)
	_cliff.resize(Ground.COUNT * Country.COUNT)
	for g in Ground.COUNT:
		for c in Country.COUNT:
			var i := g * Country.COUNT + c
			_wash[i] = _make(g, c)
			_marks[i] = _make_mark(g, c)
			_cliff[i] = _make_cliff(g, c)


static func _m(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)


## The wash of ground g as drawn in country c.
static func _make(g: int, c: int) -> Color:
	match g:
		Ground.DEEP_WATER: return P.BRINE[1]
		Ground.WATER, Ground.RIVER: return _m(P.SAND[2], P.BRINE[2], 0.5)
		Ground.BLACKWATER: return P.BRINE[0]
		Ground.FLOOR: return P.STONE[2]
		Ground.ROAD:
			match c:
				Country.SNOWFIELD: return _m(P.ASH[3], P.EARTH[3], 0.35)
				# A track trodden through the ash, darker and browner than the drifts.
				Country.BURNING: return _m(P.ASH[2], P.EARTH[2], 0.45)
				Country.BONELANDS: return _m(P.LINEN[3], P.EARTH[3], 0.4)
			return _m(P.EARTH[3], P.SAND[3], 0.4)
		Ground.SAND:
			match c:
				Country.SNOWFIELD: return _m(P.SAND[4], P.RIME[4], 0.45)
				Country.BURNING: return _m(P.SAND[3], P.ASH[2], 0.5)
				Country.MOSS: return P.SAND[3]
			return P.SAND[4]
		Ground.SHINGLE:
			match c:
				Country.BURNING: return P.STONE[1]
				Country.SNOWFIELD: return _m(P.STONE[3], P.RIME[3], 0.3)
			# Warm grey, not yellow: shingle is stone that the sea sorted.
			return _m(P.STONE[3], P.SAND[3], 0.3)
		Ground.GRAVEL:
			match c:
				Country.BONELANDS: return _m(P.STONE[3], P.LINEN[3], 0.5)
				Country.BURNING: return P.STONE[1]
			return _m(P.STONE[3], P.SAND[3], 0.45)
		Ground.GRASS:
			match c:
				Country.MOSS: return P.MOSS[2]
				# A clearing: the light gets in.
				Country.PINEWOOD: return _m(P.MOSS[3], P.SPRUCE[3], 0.45)
				# Frost-bitten turf between drifts.
				Country.SNOWFIELD: return _m(P.MOSS[3], P.ASH[3], 0.55)
				# Bleached sheep-bitten grass on the limestone.
				Country.BONELANDS: return _m(P.MOSS[4], P.SAND[4], 0.5)
				# Scorched: what grass is left near the burning.
				Country.BURNING: return _m(P.EARTH[3], P.ASH[2], 0.5)
			# Grey-green coast turf.
			return _m(P.MOSS[3], P.SLATE[3], 0.22)
		Ground.HEATH:
			match c:
				Country.MOSS: return _m(P.EARTH[1], P.MOSS[1], 0.5)
				Country.BONELANDS: return _m(P.EARTH[3], P.SAND[3], 0.5)
				Country.SNOWFIELD: return _m(P.EARTH[2], P.ASH[2], 0.5)
				Country.BURNING: return P.EARTH[1]
			# Heather browns under a grey-green cast, never orange.
			return _m(P.EARTH[2], P.MOSS[2], 0.5)
		Ground.MOSS:
			match c:
				Country.SNOWFIELD: return _m(P.SPRUCE[2], P.ASH[3], 0.4)
				Country.BURNING: return _m(P.MOSS[1], P.ASH[1], 0.4)
			return _m(P.MOSS[2], P.SPRUCE[2], 0.4)
		Ground.PEAT: return _m(P.EARTH[1], P.EARTH[2], 0.35)
		Ground.MUD:
			if c == Country.MOSS:
				return _m(P.EARTH[1], P.EARTH[2], 0.35)
			return P.EARTH[2]
		Ground.NEEDLES:
			match c:
				Country.SNOWFIELD: return _m(P.EARTH[2], P.ASH[3], 0.35)
				Country.BURNING: return P.EARTH[1]
			return _m(P.EARTH[2], P.EARTH[3], 0.45)
		Ground.SNOW:
			match c:
				Country.BURNING: return _m(P.RIME[4], P.ASH[3], 0.55)
				Country.SNOWFIELD: return P.RIME[5]
			return _m(P.RIME[5], P.RIME[4], 0.4)
		Ground.ICE: return P.RIME[4]
		Ground.BONE, Ground.LIMESTONE:
			if c == Country.BURNING:
				return _m(P.LINEN[3], P.ASH[3], 0.5)
			return P.LINEN[4]
		Ground.SCREE:
			match c:
				Country.BONELANDS: return _m(P.SLATE[3], P.LINEN[3], 0.35)
				Country.BURNING: return P.STONE[1]
			return P.SLATE[3]
		Ground.ROCK:
			match c:
				Country.BONELANDS: return _m(P.LINEN[3], P.SLATE[3], 0.4)
				Country.BURNING: return _m(P.STONE[1], P.ASH[1], 0.5)
				Country.SNOWFIELD: return _m(P.SLATE[3], P.RIME[3], 0.4)
				Country.MOSS: return _m(P.SLATE[2], P.SPRUCE[2], 0.35)
				Country.PINEWOOD: return _m(P.SLATE[2], P.SPRUCE[2], 0.25)
			return P.SLATE[3]
		# Ash over a fire that has not gone out: warmed off the cold grey.
		Ground.ASH: return _m(P.ASH[2], P.EARTH[2], 0.22)
		Ground.CLINKER: return _m(P.STONE[1], P.ASH[1], 0.4)
	return P.BLOOM[3]


static func _make_mark(g: int, c: int) -> int:
	match g:
		Ground.GRASS: return TURF
		Ground.HEATH: return HEATH
		Ground.SAND: return SAND
		Ground.SHINGLE, Ground.GRAVEL: return SHINGLE
		Ground.SNOW: return SNOW
		Ground.BONE, Ground.LIMESTONE: return PAVEMENT
		Ground.ASH: return ASH
		Ground.CLINKER: return CLINKER
		Ground.MOSS: return FEN
		Ground.PEAT: return PEAT
		Ground.MUD: return PEAT if c == Country.MOSS else MUD
		Ground.NEEDLES: return NEEDLES
		Ground.ICE: return ICE
		Ground.ROCK, Ground.SCREE: return ROCK
		Ground.ROAD: return ROAD
	return PLAIN


## The base wash of a terrace wall under ground g in country c; strata() says
## how world.gdshader bands it.
static func _make_cliff(g: int, c: int) -> Color:
	match g:
		Ground.SAND, Ground.SHINGLE, Ground.GRAVEL:
			return P.SAND[3] if g == Ground.SAND else P.STONE[2]
		Ground.ICE:
			return P.RIME[3]
	match c:
		Country.MOSS: return P.EARTH[1]
		Country.PINEWOOD: return _m(P.SLATE[2], P.SPRUCE[2], 0.4)
		Country.SNOWFIELD: return _m(P.SLATE[2], P.RIME[2], 0.5)
		Country.BONELANDS: return P.LINEN[3]
		Country.BURNING: return P.STONE[0]
	# Weathered coast rock, grey warmed by the soil washed over it.
	return _m(P.STONE[3], P.EARTH[3], 0.3)


## Wash of ground g in country c.
static func wash(g: int, c: int) -> Color:
	return _wash[clampi(g, 0, Ground.COUNT - 1) * Country.COUNT + clampi(c, 0, Country.COUNT - 1)]


## Ink mark code of ground g in country c.
static func mark(g: int, c: int) -> int:
	return _marks[clampi(g, 0, Ground.COUNT - 1) * Country.COUNT + clampi(c, 0, Country.COUNT - 1)]


static func cliff(g: int, c: int) -> Color:
	return _cliff[clampi(g, 0, Ground.COUNT - 1) * Country.COUNT + clampi(c, 0, Country.COUNT - 1)]


## Strata id for a wall under ground g in country c.
static func strata(g: int, c: int) -> int:
	match g:
		Ground.SAND, Ground.SHINGLE, Ground.GRAVEL: return STRATA_SAND
		Ground.ICE: return STRATA_ICE
		Ground.SNOW: return STRATA_SNOW
	match c:
		Country.MOSS: return STRATA_MOSS
		Country.PINEWOOD: return STRATA_PINE
		Country.SNOWFIELD: return STRATA_SNOW
		Country.BONELANDS: return STRATA_BONE
		Country.BURNING: return STRATA_BASALT
	return STRATA_COAST


## A colour carrying mark `code` in its alpha.
static func marked(col: Color, code: int) -> Color:
	return Color(col.r, col.g, col.b, clampi(code, 0, 255) / 255.0)


## Glowing: embers, flames, a kiln mouth. strength 0.125..2.
static func glow(col: Color, strength: float) -> Color:
	return marked(col, GLOW + clampi(roundi(strength * 8.0), 1, 16))


## A lamp: glows only when the light is going.
static func lamp(col: Color, strength: float) -> Color:
	return marked(col, LAMP + clampi(roundi(strength * 8.0), 1, 16))


static func glint(col: Color) -> Color:
	return marked(col, GLINT)


## Ground a turf of country `from` becomes when drawn as country `to`, so an
## ecotone interleaves each country's own ground (used only when world gen has
## not dithered the grounds itself). Rock, sand, water and roads stay.
static func morph(g: int, to: int) -> int:
	match g:
		Ground.GRASS, Ground.HEATH, Ground.MOSS, Ground.MUD, Ground.PEAT, Ground.NEEDLES, Ground.SNOW, Ground.BONE, Ground.LIMESTONE, Ground.ASH:
			return home_turf(to)
		Ground.ROCK, Ground.SCREE, Ground.CLINKER:
			return Ground.CLINKER if to == Country.BURNING else (Ground.SCREE if to == Country.BONELANDS else Ground.ROCK)
	return g


## What the bank of inland water is drawn as where the tile under it is wet
## but the terrace is not.
static func bank(c: int) -> int:
	match c:
		Country.MOSS: return Ground.PEAT
		Country.PINEWOOD: return Ground.NEEDLES
		Country.SNOWFIELD: return Ground.SNOW
		Country.BONELANDS: return Ground.GRAVEL
		Country.BURNING: return Ground.ASH
	return Ground.SAND


static func home_turf(c: int) -> int:
	match c:
		Country.MOSS: return Ground.MOSS
		Country.PINEWOOD: return Ground.NEEDLES
		Country.SNOWFIELD: return Ground.SNOW
		Country.BONELANDS: return Ground.LIMESTONE
		Country.BURNING: return Ground.ASH
	return Ground.GRASS


## n ramp steps darker (fractional allowed), the palette's own blue-violet step.
static func down(col: Color, n: float = 1.0) -> Color:
	return Color(col.r * pow(STEP_DOWN.x, n), col.g * pow(STEP_DOWN.y, n), col.b * pow(STEP_DOWN.z, n), col.a)


## n ramp steps lighter.
static func up(col: Color, n: float = 1.0) -> Color:
	var c := down(col, -n)
	return Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0), col.a)


## The map tool's colour for a tile.
static func top(g: int, c: int = Country.COAST) -> Color:
	return wash(g, c)


static func luminance(col: Color) -> float:
	return (0.299 * col.r + 0.587 * col.g + 0.114 * col.b) * 255.0
