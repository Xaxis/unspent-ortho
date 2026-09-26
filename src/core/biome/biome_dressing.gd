class_name BiomeDressing
extends RefCounted
## What a landscape's BUILT and FOUND things are made of: the stone its boulders
## are, the timber its fences weather to, what drifts against a wreck, what kind
## of patched shelter people put up in it, what the weather leaves on anything
## left out.
##
## Until now this was the one thing about a landscape that was not data. The
## seven builders under `src/models/props/` matched on `Country` — names for the
## first seven registry slots — so a landscape registered after the M1 six got
## the COAST'S houses, boulders, wrecks, signs and shore dressing, however
## carefully its own file described it. A landscape added today looked borrowed,
## and that is what blocked M3.
##
## It is declared as `BiomeDef.dressing`, and a landscape only writes down what
## it ARGUES WITH: everything unset is worked out from what the file already
## says about itself (`rock_color`, `grass_colors`, `plain_ground`, `wet`,
## `scorched`, and whether snow lies here), so a four-line landscape is dressed
## as ITSELF rather than as somewhere else. `BiomeDressing.of(index)` is the one
## door and it hands back a resolved row; nothing under `src/models/props/` may
## branch on a landscape by name again.
##
## Two things deliberately NOT here. A house's joinery — its doors, its boards,
## its window frames — is sawn timber brought in and kept under a roof, so it is
## the same brown everywhere; `timber` is what the weather does to a post left
## standing in it, which is a different question. And a landscape's TREES are
## coloured through `BiomeDef.tree_tints`, which was already the door for that
## and now carries the pine, the dead wood, the scrub and the reeds as well.

const P := preload("res://src/render/palette.gd")

## How wet a landscape has to lie before a thing left out in it is grown
## through. Three steps, because three different things happen: grass comes up
## round anything at all, moss takes hold on what lies flat, and reeds come up
## through a fence. Read off `BiomeDef.wet`, which every landscape already
## declares, so this costs no new field and cannot drift from the ground itself.
const WET_GRASS := 0.15
const WET_MOSS := 0.2
const WET_REEDS := 0.3

## Sentinels. A colour nobody set is transparent, which no palette value is.
const NONE := Color(0, 0, 0, 0)
const UNSET2 := Vector2(INF, INF)

# --- what things here are made of ---------------------------------------------

## The country's rock: [body, its shaded side, what grows or lies on its top].
## Boulders, cairns, ore hosts and standing stones are all cut from it.
var stone: Array[Color] = []
## How blockily that rock breaks, as the sides of a drawn boulder (5 is slabby
## limestone, 7 the ordinary crumble). 0 takes the ordinary one.
var facets := 0
## Bleached things: bone, limestone, the lime somebody burnt sixty years ago.
## [the face turned to the weather, the older bone under it, a fresh split].
var pale: Array[Color] = []
## Timber that has stood out in this weather for years: [board, the dark of it].
## Silvered by salt, black with bog water, grey with needles, bleached, charred.
var timber: Array[Color] = []
## What banks and drifts against anything left out — sand, peat, needles, snow,
## dust, ash: [the lit crest, its shade]. Unset it is the land's own plain ground.
var drift: Array[Color] = []
## Sods cut from this ground and laid on a roof or banked at a wall's foot:
## [a, another, a cut one, the dark it alternates with].
var turf: Array[Color] = []
## The stone people build a wall out of here, in four tones: a ruin, a lean-to,
## a dry-stone gable.
var walling: Array[Color] = []
## What the machine age cast here, once the weather has had it.
var concrete := NONE
## The machines' enamel warning: [its face, the glyphs ruled on it].
var sign: Array[Color] = []
## What greens a wall's foot and a damp corner.
var growth := NONE
## What the sun and the dust leave a colour as here. Unset, nothing bleaches —
## and where something does, rubber and cloth do not last either, so a vehicle
## stands on its rims.
var bleach := NONE
## What the scrub here carries, if anything: haws, crowberries, hips.
var berry := NONE

# --- what the weather does to a thing left out in it --------------------------

## Snow lies here: [the crust on a roof, rime on a wire, an icicle, its shade].
## Empty and nothing lies — which is also how every model asks the question.
var snow: Array[Color] = []
## What this land throws over a thing left standing in it, which decides the
## SHAPE of what gathers and not only its colour:
##   &"drift"    dust and sand banked along one side (the plain answer)
##   &"snow"     deep drifts to the belt on the windward side, a tail in the lee
##   &"ash"      low banks of ash, and everything under them charred
##   &"needles"  a mat on the roof, a bough come down across it
##   &"weed"     black water round it and reeds up through it
##   &"wrack"    a tide line of weed hung on it, and rust where the salt gets in
var covers: StringName = &""
## How hard the prevailing wind bends and crops what grows here. 0 and nothing
## leans; above 0 a crown leans downwind and its top is cropped, and WorldView
## turns those kinds to one bearing instead of a random one.
var wind := 0.0
## How deep a heavy thing settles into this ground once it has stood a while.
var sink := -1.0
## And how it lies once it has: (roll, pitch) in radians.
var lie := UNSET2

# --- what people and what grows take for a shape here -------------------------

## The patched shelter people put up in this landscape (props/remains.gd):
## &"shack" a boarded fishing shack, &"stilt" a hut on stilts over the water,
## &"blind" a platform up among the trunks, &"pod" an emergency shell half under
## the snow, &"lean_to" a dry-stone lean-to under tin, &"dugout" dug into the ash,
## &"infill" a dead tower's ground floor walled in with salvaged doors.
var shelter: StringName = &""
## What a broadleaf is here: &"full" a crown of leaves, &"bare" branches only,
## &"low" a wind-cropped thorn, wide and bent right over.
var crown: StringName = &""
## How wide that crown stands, as a multiple of the ordinary one.
var spread := 0.0
## How a storey somebody still lives behind shows after dark (props/towers.gd):
##   &"floors"  the whole band lit on the city's stolen power, a floor left on
##   &"gaps"    no power: one light of the band, by a lamp or a fire, and the
##              rest of it dark glass -- people living in the gaps of a tower
##              that is not theirs
var windows: StringName = &""

## Every form each field may name, so a typo is a failing test and not a
## landscape quietly dressed as somewhere else (BiomeRegistry.problems).
const COVERS: Array[StringName] = [&"drift", &"snow", &"ash", &"needles", &"weed", &"wrack"]
const SHELTERS: Array[StringName] = [&"shack", &"stilt", &"blind", &"pod", &"lean_to", &"dugout",
	# The crags': a small dry-stone round under turf, patched with plate
	# (props/crags.gd). It never wires a light in.
	&"roundhouse",
	# The metropolis': a dead tower's ground floor walled in with salvaged
	# doors (props/remains.gd `_infill`).
	&"infill",
	# The mesas': a hollow under a lip of banded rock with a hide across its
	# mouth (props/mesas.gd). It never wires a light in; its lit one has a
	# hearth in the mouth of the cut.
	&"cut_room"]
const CROWNS: Array[StringName] = [&"full", &"bare", &"low"]
const WINDOWS: Array[StringName] = [&"floors", &"gaps"]
## Every ramp `BiomeDef.tree_tints` may name, and how many colours each wants.
const RAMPS := {&"leaf": 4, &"trunk": 1, &"needle": 3, &"under": 1, &"scrub": 3,
	&"gorse": 3, &"dead": 2, &"reed": 3, &"reed_head": 1}


# --- the one door -------------------------------------------------------------

static var _rows: Array[BiomeDressing] = []


## The resolved dressing of landscape index `c`: what its file declared, with
## everything else worked out from what else that file says. Built once per
## registry and read from the chunk workers, so it holds nothing but colours.
static func of(c: int) -> BiomeDressing:
	var rows := _rows
	if rows.size() != BiomeRegistry.count():
		rows = _build()
	return rows[clampi(c, 0, rows.size() - 1)]


static func _build() -> Array[BiomeDressing]:
	var out: Array[BiomeDressing] = []
	for d: BiomeDef in BiomeRegistry.all():
		out.append(resolve(d))
	# Assigned whole: a chunk worker reading this while another builds it sees
	# either the old array or the new one, never a half-filled one.
	_rows = out
	return out


## One landscape's dressing, declared and derived. Public so a test can ask what
## a landscape that declares nothing would be dressed as.
static func resolve(d: BiomeDef) -> BiomeDressing:
	var r := BiomeDressing.new()
	var s: BiomeDressing = d.dressing if d.dressing != null else BiomeDressing.new()
	var burnt := d.scorched
	var rock := d.rock_color
	var green: Color = d.grass_colors[0] if not d.grass_colors.is_empty() else P.MOSS[3]
	var green2: Color = d.grass_colors[1] if d.grass_colors.size() > 1 else GroundColors.down(green, 0.2)

	r.snow = s.snow
	var cold := not r.snow.is_empty()

	if not s.stone.is_empty():
		r.stone = s.stone
	else:
		r.stone = [rock, GroundColors.down(rock, 0.22), green]
	r.facets = s.facets if s.facets > 0 else 7
	if not s.pale.is_empty():
		r.pale = s.pale
	elif burnt:
		r.pale = [P.ASH[3], P.ASH[2], P.ASH[1]]
	else:
		r.pale = [P.LINEN[4], P.LINEN[3], P.LINEN[2]]
	if not s.timber.is_empty():
		r.timber = s.timber
	elif burnt:
		r.timber = [P.INK[2], P.STONE[0]]
	elif cold:
		r.timber = [P.SLATE[2], P.EARTH[1]]
	else:
		r.timber = [P.LINEN[3].lerp(P.ASH[3], 0.4), P.LINEN[2]]
	if not s.drift.is_empty():
		r.drift = s.drift
	else:
		# What blows against a thing is the land's own ground, one step darker.
		var w := GroundColors.wash(d.plain_ground, maxi(d.index, 0))
		r.drift = [w, GroundColors.down(w, 0.12)]
	if not s.turf.is_empty():
		r.turf = s.turf
	elif cold:
		r.turf = [r.snow[1], r.snow[0], r.snow[1].lerp(P.SLATE[3], 0.4), P.SLATE[3]]
	elif burnt:
		r.turf = [P.ASH[1], P.ASH[2], P.ASH[1].lerp(P.EARTH[1], 0.4), P.ASH[2]]
	else:
		r.turf = [green, green2, green.lerp(P.EARTH[2], 0.35), green2]
	if not s.walling.is_empty():
		r.walling = s.walling
	else:
		r.walling = [r.stone[1], r.stone[0], GroundColors.up(r.stone[0], 0.25), r.pale[1]]
	if s.concrete.a > 0.0:
		r.concrete = s.concrete
	elif burnt:
		r.concrete = P.STONE[1]
	elif cold:
		r.concrete = P.SLATE[3]
	else:
		r.concrete = P.STONE[3].lerp(P.LINEN[3], 0.35)
	if not s.sign.is_empty():
		r.sign = s.sign
	elif burnt:
		r.sign = [P.PLATE[2], P.INK[0]]
	else:
		r.sign = [P.RIME[5].lerp(P.PLATE[4], 0.35), P.INK[1]]
	r.growth = s.growth if s.growth.a > 0.0 else (P.SLATE[2] if cold else P.MOSS[2])
	r.bleach = s.bleach
	r.berry = s.berry

	if s.covers != &"":
		r.covers = s.covers
	elif cold:
		r.covers = &"snow"
	elif burnt:
		r.covers = &"ash"
	elif d.wet >= WET_REEDS:
		r.covers = &"weed"
	else:
		r.covers = &"drift"
	r.wind = s.wind
	r.sink = s.sink if s.sink >= 0.0 else 0.06
	r.lie = s.lie if s.lie != UNSET2 else Vector2(-0.06, 0.08)

	if s.shelter != &"":
		r.shelter = s.shelter
	elif cold:
		r.shelter = &"pod"
	elif burnt:
		r.shelter = &"dugout"
	elif d.wet >= WET_REEDS:
		r.shelter = &"stilt"
	else:
		r.shelter = &"shack"
	r.crown = s.crown if s.crown != &"" else (&"bare" if cold or burnt else &"full")
	r.spread = s.spread if s.spread > 0.0 else 1.0
	r.windows = s.windows if s.windows != &"" else &"floors"
	return r


# --- the questions the model builders ask --------------------------------------

## Snow lies here at all.
func cold() -> bool:
	return not snow.is_empty()


## Rubber, cloth and paint do not last here.
func perishes() -> bool:
	return bleach.a > 0.0


## Grass comes up round a thing left lying on this ground.
static func grassy(c: int) -> bool:
	return BiomeRegistry.by_index(c).wet >= WET_GRASS


## Moss takes hold on a thing lying flat here.
static func mossy(c: int) -> bool:
	return BiomeRegistry.by_index(c).wet >= WET_MOSS


## Reeds come up through a fence here, and standing water gathers round a wreck.
static func reedy(c: int) -> bool:
	return BiomeRegistry.by_index(c).wet >= WET_REEDS


## Nothing green survives here, so everything left out is charred.
static func burnt(c: int) -> bool:
	return BiomeRegistry.by_index(c).scorched


## A landscape's tints for what grows in it (`BiomeDef.tree_tints`), or `fallback`
## where it does not argue. The keys, and what each is a ramp of, are `RAMPS`.
static func tint(c: int, key: StringName, fallback: Array[Color]) -> Array[Color]:
	var own: Dictionary = BiomeRegistry.by_index(c).tree_tints
	if not own.has(key):
		return fallback
	var out: Array[Color] = []
	out.assign(own[key])
	return out


## One colour off that table.
static func tint1(c: int, key: StringName, fallback: Color) -> Color:
	var own: Dictionary = BiomeRegistry.by_index(c).tree_tints
	if not own.has(key):
		return fallback
	var ramp: Array = own[key]
	return ramp[0] if not ramp.is_empty() else fallback


# --- what a landscape got wrong ------------------------------------------------

## Problems with one landscape's declared dressing, as lines for
## `BiomeRegistry.problems()`. A form nobody has and a ramp of the wrong length
## are both silent otherwise: the model draws, in somebody else's clothes.
static func problems(d: BiomeDef) -> PackedStringArray:
	var out := PackedStringArray()
	var w := "biome %s: " % d.id
	var s := d.dressing
	if s != null:
		for row: Array in [[s.stone, 3, "stone"], [s.pale, 3, "pale"], [s.timber, 2, "timber"],
				[s.drift, 2, "drift"], [s.turf, 4, "turf"], [s.walling, 4, "walling"],
				[s.sign, 2, "sign"], [s.snow, 4, "snow"]]:
			var ramp: Array = row[0]
			if not ramp.is_empty() and ramp.size() != int(row[1]):
				out.append(w + "dressing %s wants %d colours, not %d" % [row[2], int(row[1]), ramp.size()])
		if s.covers != &"" and not COVERS.has(s.covers):
			out.append(w + "nothing is covered in %s" % s.covers)
		if s.covers == &"snow" and s.snow.is_empty():
			out.append(w + "is covered in snow but never says what colour snow is here")
		if s.shelter != &"" and not SHELTERS.has(s.shelter):
			out.append(w + "nobody builds a %s" % s.shelter)
		if s.crown != &"" and not CROWNS.has(s.crown):
			out.append(w + "no crown is %s" % s.crown)
		if s.windows != &"" and not WINDOWS.has(s.windows):
			out.append(w + "no window is lit as %s" % s.windows)
		if s.facets != 0 and (s.facets < 4 or s.facets > 9):
			out.append(w + "rock breaks into %d sides, which is not 4..9" % s.facets)
	# Tree tints are a dictionary, so a misspelt key is silent the same way.
	for k: StringName in d.tree_tints:
		if not RAMPS.has(k):
			out.append(w + "nothing grows a %s" % k)
		elif (d.tree_tints[k] as Array).size() != int(RAMPS[k]):
			out.append(w + "%s wants %d colours, not %d" % [k, int(RAMPS[k]), (d.tree_tints[k] as Array).size()])
	return out
