class_name GroundColors
## The washes of the land (docs/LOOK.md): what colour a ground is in each
## landscape type, which ink MARK world.gdshader draws into it, and what its
## cliffs are made of.
##
## A ground has one wash the whole world over, and a landscape type OVERRIDES
## the ones it argues with (`BiomeDef.grounds`, `ground_marks`): the table here
## is what a ground is when nobody argues. Every wash is a palette value or a
## named mix of two. Adding a landscape adds no code here.
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
## Stolen neon: a machine's own light wired into somebody's wall. Lit like a
## lamp, but on the MACHINES' power, so a strike stutters it the way it stutters
## every strip and beacon on the coast. A hearth and a window keep burning, which
## is why this cannot be a lamp code (world.gdshader lights 17..32 steadily).
const NEON := 34
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
const SALT := 55
const SWARF := 56
const PAN := 57
## The glass desert's fused sheet: sand turned to green-black glass in a second
## and breaking ever since. It is ROCK there (`BiomeDef.ground_marks`), so the
## island does not move; world.gdshader draws plates, crazing and flow banding,
## and matter_of gives it the one mirror-hard floor in the game besides ice.
const VITRIFIED := 59
## The drowned city's floor: poured concrete the tide came up over and went down
## off, silted below the old high-water line and standing in puddles. It is
## FLOOR there (`BiomeDef.ground_marks`), so the island does not move. 60 is
## STRATA + 0, which no wall is ever given (strata ids start at 1), so it was
## free; world.gdshader dispatches it with the grounds.
const TIDEFLAT := 60
## --- WHAT A PERSON MADE (matter.gdshaderinc `matter_of`) ---------------------
## 40..58 above are GROUND. Until this band existed, every timber post, thatched
## roof, canvas awning, concrete slab, glass pane and rope lashing came back as
## ONE default material, so under a single sun only the mesh normal told a roof
## from a wall — and the normals are flat facets.
##
## **75..79 ARE DELIBERATELY EMPTY**, between the cliff strata (61..74) and this
## band, so an off-by-one lands on nothing instead of on a material. 92..95 are
## spare. Tag a surface with `GroundColors.made(col, GroundColors.THATCH)`; a
## builder that tags nothing still gets the default, which is what every model
## got before and is a perfectly good unpainted timber.
##
## SLATE (92) was the first row asked for by a surface rather than by a spec.
## `houses.gd` refused to tag its roofs with CUTSTONE and wrote down why, and
## the argument it gave is the one that earned the row: slate is not dressed
## block, it is a thin cleaved tile that should catch MORE light than a sawn
## board, not less. 93..95 are spare.
const TIMBER := 80
const THATCH := 81
const CLOTH := 82
const ROPE := 83
const CLAY := 84
const CONCRETE := 85
const GLASS := 86
const TAR := 87
const ENAMEL := 88
const HIDE := 89
const BONE_MADE := 90
const CUTSTONE := 91
const SLATE := 92
const MADE_FIRST := TIMBER
const MADE_LAST := SLATE
## A face the taking has just opened: the cut through a boulder a pick has been
## into, a wreck cut down. Nothing has settled on it yet, so the wear the land
## lays on everything standing in it (`matter_worn`) is kept off this face alone
## (Broken, world.gdshader). It carries no mark of its own.
const FRESH := 58
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
const STRATA_SALT := 9
const STRATA_SCRAP := 10
## A terrace wall the glassing ran over: melt that ran down the face and set,
## a rolled lip with drips, fulgurite veins (71).
const STRATA_GLASS := 11
## The drowned city's walls: slick weed under the working tide, stained concrete
## up to one white high-water line at the same height on every wall in the city,
## and salt-bleached pour lines above it (72).
const STRATA_TIDE := 12
## A cave wall: dark wet limestone hung with flowstone curtains that run down
## from the lip and end in rounded lobes, stained with iron, and wet (73).
const STRATA_CAVE := 13
## The middens' walls: refuse the plan SORTED before it dumped it, in bands by
## what it is -- boards, cable, white goods, rust -- with cable hanging off the
## lip (74).
const STRATA_REFUSE := 14

static var _wash: PackedColorArray
static var _marks: PackedInt32Array
static var _cliff: PackedColorArray
static var _strata: PackedInt32Array
static var _stride := 0
static var _fill := Mutex.new()


## Rebuilt on first use, and whenever the registry has changed under us (tests
## that mute types to prove parity with the M1 six).
##
## Workers ask too (the far blocks, the map), so the fill is ONE thread's, under
## `_fill`, and `_stride` is written LAST: it is what the quick test below reads,
## and it once went first, so a thread arriving mid-fill read colours not yet
## written and two arriving together resized the same arrays.
static func _ensure() -> void:
	var n := BiomeRegistry.count()
	if _stride == n and not _wash.is_empty():
		return
	_fill.lock()
	if _stride == n and not _wash.is_empty():
		_fill.unlock()
		return
	_stride = -1
	_wash.resize(Ground.COUNT * n)
	_marks.resize(Ground.COUNT * n)
	_cliff.resize(Ground.COUNT * n)
	_strata.resize(Ground.COUNT * n)
	for d: BiomeDef in BiomeRegistry.all():
		for g in Ground.COUNT:
			var i := g * n + d.index
			_wash[i] = d.grounds.get(g, _base(g))
			_marks[i] = d.ground_marks.get(g, _base_mark(g))
			_cliff[i] = _make_cliff(g, d)
			_strata[i] = _make_strata(g, d)
	_stride = n
	_fill.unlock()


static func _m(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)


## The wash of ground g where no landscape says otherwise.
static func _base(g: int) -> Color:
	match g:
		Ground.DEEP_WATER: return P.BRINE[1]
		Ground.WATER, Ground.RIVER: return _m(P.SAND[2], P.BRINE[2], 0.5)
		Ground.BLACKWATER: return P.BRINE[0]
		Ground.FLOOR: return P.STONE[2]
		Ground.ROAD: return _m(P.EARTH[3], P.SAND[3], 0.4)
		Ground.SAND: return P.SAND[4]
		# Warm grey, not yellow: shingle is stone that the sea sorted.
		Ground.SHINGLE: return _m(P.STONE[3], P.SAND[3], 0.3)
		Ground.GRAVEL: return _m(P.STONE[3], P.SAND[3], 0.45)
		# Grey-green coast turf.
		Ground.GRASS: return _m(P.MOSS[3], P.SLATE[3], 0.22)
		# Heather browns under a grey-green cast, never orange.
		Ground.HEATH: return _m(P.EARTH[2], P.MOSS[2], 0.5)
		Ground.MOSS: return _m(P.MOSS[2], P.SPRUCE[2], 0.4)
		Ground.PEAT: return _m(P.EARTH[1], P.EARTH[2], 0.35)
		Ground.MUD: return P.EARTH[2]
		Ground.NEEDLES: return _m(P.EARTH[2], P.EARTH[3], 0.45)
		Ground.SNOW: return _m(P.RIME[5], P.RIME[4], 0.4)
		Ground.ICE: return P.RIME[4]
		# Bone-pale, cooled a touch toward the grey of weathered stone.
		Ground.BONE, Ground.LIMESTONE: return _m(_m(P.LINEN[4], P.LINEN[5], 0.45), P.STONE[4], 0.15)
		Ground.SCREE: return P.SLATE[3]
		Ground.ROCK: return P.SLATE[3]
		# Ash over a fire that has not gone out: warmed off the cold grey.
		Ground.ASH: return _m(P.ASH[2], P.EARTH[2], 0.22)
		# Slag grit: a dark rust-grey, never near black; the glass lies in pools.
		Ground.CLINKER: return _m(P.STONE[2], P.RUST[1], 0.3)
		# Evaporite crust: linen bleached almost to the page, faintly warm.
		Ground.SALT: return _m(P.LINEN[5], P.SAND[5], 0.2)
		# A pan the brine drew back from: grey mineral silt with a warm cast,
		# pale enough that it reads as a dry floor and never as mud.
		Ground.PAN: return _m(_m(P.LINEN[3], P.STONE[3], 0.3), P.RUST[2], 0.12)
		# Rust grit and metal filings trodden into the leaf litter: more grit
		# than soil, so a wood floored in it never reads as the bare earth that
		# borders every other wood.
		Ground.SWARF: return _m(_m(P.EARTH[1], P.SLATE[2], 0.45), P.RUST[2], 0.28)
	return P.BLOOM[3]


static func _base_mark(g: int) -> int:
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
		Ground.MUD: return MUD
		Ground.NEEDLES: return NEEDLES
		Ground.ICE: return ICE
		Ground.ROCK, Ground.SCREE: return ROCK
		Ground.ROAD, Ground.FLOOR: return ROAD
		Ground.SALT: return SALT
		Ground.PAN: return PAN
		Ground.SWARF: return SWARF
	# Only water reaches here, and water is drawn by the chart rather than by a
	# ground material. Every WALKABLE ground must have a row above: one with no
	# row takes PLAIN, and PLAIN is the one code `world.gdshader` dispatches
	# NOWHERE -- not to `ground_mark`, not to `ground_wear`, not to the works or
	# survey marks -- so it draws as a flat untreated wash and nothing says a
	# word. FLOOR was in exactly that state and is the reason this is now held
	# by `tests/render/test_ground_marks.gd` rather than by a comment.
	return PLAIN


## The base wash of a terrace wall under ground g in landscape d; strata() says
## how world.gdshader bands it. Loose ground decides its own wall; everything
## else is the landscape's bedrock.
static func _make_cliff(g: int, d: BiomeDef) -> Color:
	match g:
		Ground.SAND: return P.SAND[3]
		Ground.SHINGLE, Ground.GRAVEL: return P.STONE[2]
		Ground.ICE: return P.RIME[3]
	return d.cliff_wash


static func _make_strata(g: int, d: BiomeDef) -> int:
	match g:
		Ground.SAND, Ground.SHINGLE, Ground.GRAVEL: return STRATA_SAND
		Ground.ICE: return STRATA_ICE
		Ground.SNOW: return STRATA_SNOW
	return d.strata


## Wash of ground g in landscape type index c.
static func wash(g: int, c: int) -> Color:
	_ensure()
	return _wash[clampi(g, 0, Ground.COUNT - 1) * _stride + clampi(c, 0, _stride - 1)]


## Ink mark code of ground g in landscape type index c.
static func mark(g: int, c: int) -> int:
	_ensure()
	return _marks[clampi(g, 0, Ground.COUNT - 1) * _stride + clampi(c, 0, _stride - 1)]


static func cliff(g: int, c: int) -> Color:
	_ensure()
	return _cliff[clampi(g, 0, Ground.COUNT - 1) * _stride + clampi(c, 0, _stride - 1)]


## Strata id for a wall under ground g in landscape type index c.
static func strata(g: int, c: int) -> int:
	_ensure()
	return _strata[clampi(g, 0, Ground.COUNT - 1) * _stride + clampi(c, 0, _stride - 1)]


## A colour carrying mark `code` in its alpha.
static func marked(col: Color, code: int) -> Color:
	return Color(col.r, col.g, col.b, clampi(code, 0, 255) / 255.0)


## What a made surface IS, so the renderer can light it as that rather than as
## the one default every made thing shared. Thatch stops reflecting like a mud
## wall, a pane reads as glass beside the timber holding it, and wet clay, dry
## straw and oiled board separate in a single frame.
##
## **ONLY EVER ON MADE GEOMETRY. ON FOUND IT IS A BLINKING BEACON.** The two lit
## shaders read vertex alpha for completely different things, and nothing but
## this comment says so. `world.gdshader` decodes it as the MARK
## (`int(COLOR.a * 255.0 + 0.5)`); `found.gdshader` decodes it as a light built
## into the machine — under 0.98 a steady strip, and **under 0.5 a beacon that
## blinks on the machine beat**. Every mark this function can write is
## `MADE_FIRST..MADE_LAST`, which is alpha 0.314..0.361, so a made mark on a
## FOUND surface is not a material at all: it is a lamp, flashing. Tag at the
## point a thing is built into `k.made`, never on a shared colour that might
## reach either — a
## `BiomeDressing` colour feeds both, so marking one at source would put blinking
## lights across every machine that dresses itself.
##
## The failure is one-sided and that is the only mercy: a mark that gets
## CORRUPTED (any `lerp` moves alpha; `GroundColors.up`/`down` preserve it) lands
## outside `MADE_FIRST..MADE_LAST`, matches no branch in `matter_of`, and falls
## back to the default — which is where most made surfaces still are. So a wrong
## tag degrades to the status quo on MADE, and screams on FOUND. (This said
## "80..91" until SLATE was added at 92, which is the whole argument for naming
## the constants instead of the numbers: the range moved and the sentence did
## not.)
static func made(col: Color, kind: int) -> Color:
	return marked(col, clampi(kind, MADE_FIRST, MADE_LAST))


## The same MATTER as something already tagged, in a different colour.
##
## For a builder that takes a bag of tagged colours and has to mix one more in
## beside them — the ends of a hipped roof are the same roof as its slopes, and
## whatever the slopes were tagged the ends are too. Reading the mark back off a
## neighbour is what lets a GENERIC builder stay generic: `Houses.hipped` is
## handed SLATE_ROOF by one caller and THATCH_ROOF by another and needs to know
## neither. Alpha is the whole of the mark, so this is a copy and not a guess;
## if `like` carries no tag, neither does the answer, which is correct.
static func same_matter(col: Color, like: Color) -> Color:
	return Color(col.r, col.g, col.b, like.a)


## Glowing: embers, flames, a kiln mouth. strength 0.125..2.
static func glow(col: Color, strength: float) -> Color:
	return marked(col, GLOW + clampi(roundi(strength * 8.0), 1, 16))


## A lamp: glows only when the light is going.
static func lamp(col: Color, strength: float) -> Color:
	return marked(col, LAMP + clampi(roundi(strength * 8.0), 1, 16))


static func glint(col: Color) -> Color:
	return marked(col, GLINT)


## A tube of stolen machine light, wired into a wall by somebody.
static func neon(col: Color) -> Color:
	return marked(col, NEON)


## Ground a turf of one landscape becomes when drawn as landscape index `to`, so
## an ecotone interleaves each landscape's own ground (used only when world gen
## has not dithered the grounds itself). Loose ground, water and roads stay.
static func morph(g: int, to: int) -> int:
	match g:
		Ground.GRASS, Ground.HEATH, Ground.MOSS, Ground.MUD, Ground.PEAT, Ground.NEEDLES, Ground.SNOW, Ground.BONE, Ground.LIMESTONE, Ground.ASH, Ground.SALT, Ground.SWARF:
			return home_turf(to)
		Ground.ROCK, Ground.SCREE, Ground.CLINKER:
			return BiomeRegistry.by_index(to).rock_ground
	return g


## What the bank of inland water is drawn as where the tile under it is wet
## but the terrace is not.
static func bank(c: int) -> int:
	return BiomeRegistry.by_index(c).bank_ground


static func home_turf(c: int) -> int:
	return BiomeRegistry.by_index(c).plain_ground


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
