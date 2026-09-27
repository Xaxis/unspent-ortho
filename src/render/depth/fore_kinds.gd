class_name ForeKinds
extends RefCounted
## What hangs over the frame, and off WHAT (docs/LOOK.md law 3).
##
## The one rule this file exists to keep: **a foreground piece is always hung on
## something the player can see**. Nothing here is placed by a tile hash in open
## air. A bough grows out of a pine that is standing there; a snapped line runs
## from a pole that is standing there; an eave juts off a house. Under an
## orthographic camera a floating limb with no trunk is not mysterious, it is a
## bug, and the player is right to read it as one -- so the world's own props are
## the anchors and `ROWS` is the whole list of which kinds can carry a piece.
##
## It also means the layer is free of worldgen: adding a landscape changes what
## stands on it, which changes what hangs over it, with nothing written here. A
## pinewood ends up roofed because it is full of pines.
##
## DETERMINISM. Every number is `Rng.hash01(seed, prop.id, salt)`. A piece hung
## on prop 412 in seed 1 is the same piece in every run, so `same A B TOL` in a
## tour holds and two shots of one moment are one picture.
##
## GEOMETRY BUDGET. A piece is 40-260 triangles and there are at most a couple
## of dozen alive (Quality's `fore` row), because meshes are built ONCE per
## (kind, variant) and shared: a piece on the land is a MeshInstance3D with a
## transform and nothing else. `templates()` is the cache.
##
## MATTER. `MeshKit` colour ALPHA carries the material id, which is world.gdshader's
## own convention (`m1 = int(COLOR.a * 255.0 + 0.5)`) and fore.gdshader's too.

## The material ids this file uses (matter.gdshaderinc `matter_of`).
const M_MADE := 0
const M_NEEDLES := 50
const M_ROCK := 52
const M_SWARF := 56
## Not a material: the STOLEN NEON mark (`GroundColors.NEON`), which every lit
## shader reads the same way — dark by day, burning when the light goes, and on
## the machines' power so a strike stutters it. A sign over a street is the one
## thing this package hangs that is supposed to be a light.
const M_NEON := 34

## Piece shapes.
enum { BOUGH, LINE, EAVE, GIRDER, TANGLE, WALKWAY, SIGN_ARM }

## Variants per shape. Four is enough that a wood does not repeat within a
## frame, and few enough that the cache is a handful of meshes.
const VARIANTS := 4

## What each prop kind carries, if anything.
##
##   shape   which of the five it hangs
##   lift    Vector2 (least, most) height above the prop's own ground, in units
##   span    Vector2 (least, most) how far it reaches out, in tiles
##   chance  0..1 how many props of the kind carry one. Under 1 on purpose: a
##           wood where every tree has a bough over the frame is a ceiling, and
##           a ceiling is not a depth cue, it is a lid
##
## What a shape does in the wind is BAKED into its template (`MeshKit.sway`),
## not written per prop kind, because the template is shared by every piece of
## that shape: a weight here would be a number nothing could apply.
const ROWS := {
	PropKind.PINE: {"shape": BOUGH, "lift": Vector2(2.5, 3.6), "span": Vector2(3.4, 5.2), "chance": 0.55},
	PropKind.SNOW_PINE: {"shape": BOUGH, "lift": Vector2(2.5, 3.6), "span": Vector2(3.2, 5.0), "chance": 0.50},
	PropKind.BROADLEAF: {"shape": BOUGH, "lift": Vector2(2.2, 3.1), "span": Vector2(3.2, 4.8), "chance": 0.46},
	PropKind.DEAD_TREE: {"shape": TANGLE, "lift": Vector2(1.9, 2.8), "span": Vector2(2.6, 4.0), "chance": 0.50},
	PropKind.SCRAP_TREE: {"shape": TANGLE, "lift": Vector2(2.0, 3.0), "span": Vector2(2.4, 3.8), "chance": 0.55},
	# A line is the strongest of the five and the cheapest: one slack cable
	# crossing the whole frame says "you are under something" in 24 triangles.
	PropKind.POLE: {"shape": LINE, "lift": Vector2(3.0, 4.2), "span": Vector2(6.0, 9.0), "chance": 0.55},
	PropKind.PYLON: {"shape": LINE, "lift": Vector2(4.2, 5.8), "span": Vector2(7.0, 10.0), "chance": 0.70},
	PropKind.RELAY: {"shape": LINE, "lift": Vector2(3.4, 4.6), "span": Vector2(5.0, 8.0), "chance": 0.60},
	PropKind.HOUSE: {"shape": EAVE, "lift": Vector2(2.1, 2.7), "span": Vector2(1.3, 1.8), "chance": 0.40},
	PropKind.SHACK: {"shape": EAVE, "lift": Vector2(1.9, 2.4), "span": Vector2(1.2, 1.6), "chance": 0.45},
	PropKind.PUMP_HOUSE: {"shape": EAVE, "lift": Vector2(2.2, 2.8), "span": Vector2(1.3, 1.7), "chance": 0.45},
	PropKind.RUIN: {"shape": GIRDER, "lift": Vector2(2.4, 3.4), "span": Vector2(3.4, 5.4), "chance": 0.45},
	PropKind.WRECKAGE: {"shape": GIRDER, "lift": Vector2(2.2, 3.2), "span": Vector2(3.2, 5.0), "chance": 0.50},
	PropKind.STACK: {"shape": GIRDER, "lift": Vector2(4.0, 5.6), "span": Vector2(4.0, 6.4), "chance": 0.65},
	PropKind.CONVEYOR: {"shape": GIRDER, "lift": Vector2(3.0, 4.2), "span": Vector2(5.0, 7.5), "chance": 0.70},
	PropKind.DRILL_RIG: {"shape": GIRDER, "lift": Vector2(4.0, 5.8), "span": Vector2(4.5, 7.0), "chance": 0.70},
	PropKind.FIRE_TOWER: {"shape": GIRDER, "lift": Vector2(4.2, 6.0), "span": Vector2(4.0, 6.0), "chance": 0.75},
}

## WHAT A BUILDING HANGS IS DECIDED BY ITS FORM, NOT BY ITS PROP KIND. Every
## building in the game is `PropKind.HOUSE` — a cot and a six-storey tower are the
## same kind with a different variant — so the row above hung a 2.1-unit cottage
## eave over a city street. That was right for as long as a house was always a
## cot, and it stopped being right the day a landscape could declare `RAISED`.
##
## THIS IS WHERE A CITY'S HEIGHT LIVES. The camera is orthographic: nothing far
## away is smaller, so there is no skyline to put on the horizon and a tower
## thirty tiles off is not distant, it is off the picture. The only place height
## can be read is right where the player is standing — which makes what crosses
## OVER the street the whole of it.
##
##   at    Vector2 (least, most) share of the FORM's own height the piece hangs at
##   span  Vector2 (least, most) how far it reaches, in tiles
##
## `at` is a share and not a number because the piece hangs off the building: a
## walkway leaves a tower near its top and a shopfront's sign arm hangs at the
## first floor whatever is standing behind it.
const FORM_ROWS := {
	&"tower": {"shape": WALKWAY, "at": Vector2(0.52, 0.72), "span": Vector2(4.5, 7.0), "chance": 0.75},
	&"stack": {"shape": WALKWAY, "at": Vector2(0.48, 0.68), "span": Vector2(4.0, 6.5), "chance": 0.70},
	&"block": {"shape": SIGN_ARM, "at": Vector2(0.40, 0.58), "span": Vector2(2.2, 3.6), "chance": 0.65},
	&"shell": {"shape": GIRDER, "at": Vector2(0.55, 0.80), "span": Vector2(3.0, 5.0), "chance": 0.60},
	&"arcade": {"shape": SIGN_ARM, "at": Vector2(0.34, 0.50), "span": Vector2(2.4, 3.8), "chance": 0.80},
	&"spire": {"shape": WALKWAY, "at": Vector2(0.44, 0.62), "span": Vector2(4.0, 6.0), "chance": 0.65},
}


## The row this prop actually carries. A HOUSE asks the landscape what it BUILT
## and takes the form's row if there is one; everything else, and every landscape
## whose buildings are one storey, takes `ROWS` exactly as before.
##
## `country` is -1 where the caller does not know it (a test, a gallery), and the
## answer is then the kind's own row: a wrong guess about a landscape would hang a
## city walkway over a fishing village.
static func row_of(p: WorldProp, seed_value: int, country: int) -> Dictionary:
	if country >= 0:
		var own: Dictionary = BiomeRegistry.by_index(country).fore_rows
		if own.has(p.kind):
			return land_row(own[p.kind])
	if p.kind != PropKind.HOUSE or country < 0:
		return ROWS.get(p.kind, {})
	var forms := BiomeForms.of(country)
	var v := PropModels.variant_of(p, seed_value, country)
	var row: Variant = FORM_ROWS.get(forms.form(v))
	if row == null:
		return ROWS.get(p.kind, {})
	var city: Dictionary = row
	var high := forms.fact(v, BiomeForms.HIGH, 2.6)
	var at: Vector2 = city.at
	return {"shape": city.shape, "lift": Vector2(at.x * high, at.y * high),
		"span": city.span, "chance": city.chance}

## A landscape's own row (BiomeDef.fore_rows) with its shape named, as ROWS has it.
static func land_row(row: Dictionary) -> Dictionary:
	var out := row.duplicate()
	out["shape"] = SHAPE_NAMES.find(String(row.get("shape", "line")))
	return out


## The shapes by the name a landscape file gives them.
const SHAPE_NAMES: Array[String] = ["bough", "line", "eave", "girder", "tangle", "walkway", "sign_arm"]

## Salts, so no two decisions about one prop share a stream.
const S_TAKE := 0xF0
const S_LIFT := 0xF1
const S_SPAN := 0xF2
const S_TURN := 0xF3
const S_VARIANT := 0xF4

static var _cache: Dictionary = {}


## Whether this prop kind can carry a foreground piece at all.
static func carries(kind: int) -> bool:
	if ROWS.has(kind):
		return true
	if _land_kinds.is_empty():
		_land_kinds[-1] = true
		for d: BiomeDef in BiomeRegistry.all():
			for k: int in d.fore_rows:
				_land_kinds[k] = true
	return _land_kinds.has(kind)


## Every kind some landscape hangs a piece off (BiomeDef.fore_rows), built once.
static var _land_kinds: Dictionary = {}


## Whether THIS prop does. Deterministic and stable for the life of the world.
static func hung_on(p: WorldProp, seed_value: int, country: int = -1) -> bool:
	var row := row_of(p, seed_value, country)
	if row.is_empty():
		return false
	return Rng.hash01(seed_value, p.id, S_TAKE) < float(row.chance)


## How the piece on `p` stands: {shape, lift, span, turn, variant}. Pure.
static func hang(p: WorldProp, seed_value: int, country: int = -1) -> Dictionary:
	var row := row_of(p, seed_value, country)
	var lift: Vector2 = row.lift
	var span: Vector2 = row.span
	return {
		"shape": int(row.shape),
		"lift": lerpf(lift.x, lift.y, Rng.hash01(seed_value, p.id, S_LIFT)) * maxf(0.6, p.scale),
		"span": lerpf(span.x, span.y, Rng.hash01(seed_value, p.id, S_SPAN)) * maxf(0.7, p.scale),
		"turn": Rng.hash01(seed_value, p.id, S_TURN),
		"variant": int(Rng.hash01(seed_value, p.id, S_VARIANT) * VARIANTS) % VARIANTS,
	}


## The mesh for one (shape, variant), built once and shared by every piece that
## wants it. Unit span: the instance scales it, so one mesh serves every length.
static func template(shape: int, variant: int, tint: Color, dying: bool = false) -> ArrayMesh:
	var key := ((shape * VARIANTS + variant) * 8 + int(tint.h * 7.99)) * 2 + (1 if dying else 0)
	if _cache.has(key):
		return _cache[key]
	var k := MeshKit.new()
	var seed_value := shape * 977 + variant * 131
	match shape:
		BOUGH: _bough(k, seed_value, tint)
		LINE: _line(k, seed_value, tint)
		EAVE: _eave(k, seed_value, tint)
		GIRDER: _girder(k, seed_value, tint)
		TANGLE: _tangle(k, seed_value, tint)
		WALKWAY: _walkway(k, seed_value, tint)
		SIGN_ARM: _sign_arm(k, seed_value, tint, dying)
	var mesh := k.build()
	_cache[key] = mesh
	return mesh


## Forget every built mesh. Only the tests want this; a running game shares them
## for its whole life because they are the same six shapes over and over.
static func forget() -> void:
	_cache.clear()


## A limb reaching out along +X from the origin and drooping, with sprays of
## needles or leaf blades along its length. The limb itself is thin: what reads
## on screen is the foliage, and what reads as DEPTH is the shadow it throws on
## the ground four units below.
static func _bough(k: MeshKit, seed_value: int, tint: Color) -> void:
	# Seven, not five: MeshKit joins struts end to end with no mitre, so a limb
	# built of few long ones reads as a chain of black boxes under a near blur.
	var segments := 7
	# A LIMB IS NEEDLES, not timber, and the difference is not cosmetic: the
	# wear model only grows seams on a material outside the ground range, and a
	# limb declared as built came back blooming salt and frost out of its own
	# bark -- a white stick over a dark wood. Nothing grew this; it grew.
	var wood := Palette.EARTH[2].lerp(tint, 0.5)
	wood.a = M_NEEDLES / 255.0
	# The limb bends a little and the foliage on it a lot, which is what a limb
	# does: a bough that moved as one piece would read as a pasted cutout, and
	# the whole job of this layer is to not be one.
	k.sway = 0.30
	var prev := Vector3.ZERO
	for i in range(1, segments + 1):
		var t := float(i) / segments
		# A limb drops away as it reaches: the far end is lower than the root,
		# so it is never a rod sticking out sideways.
		var droop := -t * t * 0.42 - Rng.hash01(seed_value, i, 3) * 0.05
		var wander := (Rng.hash01(seed_value, i, 4) - 0.5) * 0.5 * t
		var here := Vector3(t, droop, wander)
		k.strut(prev, here, lerpf(0.042, 0.012, t), 5, wood)
		prev = here
	# Sprays of needles along the limb. Many small ones, not a few big: the first
	# version hung eleven sprays two tiles across and the bough came out as a
	# giant snowflake over the wood. A spray is about a fifth of the limb's own
	# length, which at a four-unit bough is under a tile -- the size of a real
	# one, and small enough that the eye reads a mass of needles instead of a
	# drawn shape.
	# Darker than the wood it stands over, and only rarely lighter. A thin blade
	# turned to a noon sun catches all of it, so a spray authored at the
	# landscape's own tint came back reading as pale scrub over a dark wood --
	# the piece has to be authored DOWN to land where the trees under it are.
	var leaf := tint.darkened(0.22)
	leaf.a = M_NEEDLES / 255.0
	var dark := tint.darkened(0.46)
	dark.a = leaf.a
	var pale := tint.lightened(0.10)
	pale.a = leaf.a
	for i in 24:
		var t := 0.15 + 0.85 * Rng.hash01(seed_value, i, 5)
		var at := Vector3(t, -t * t * 0.42, (Rng.hash01(seed_value, i, 11) - 0.5) * 0.34 * t)
		# EVERYTHING HERE IS IN UNIT SPAN and multiplied by the piece's own reach,
		# which is three to five tiles. A needle blade authored at 0.2 came out
		# three world units long and the bough read as an agave: a rosette of
		# spikes, not a branch. A blade is 0.4 to 0.7 of a tile on the ground, so
		# in unit span it is a tenth.
		var size := lerpf(0.055, 0.032, t) * (0.8 + Rng.hash01(seed_value, i, 6) * 0.5)
		# The fan lies mostly ACROSS the limb and sweeps back along it, which is
		# how a conifer carries its needles and why a bough has a direction.
		var yaw := (Rng.hash01(seed_value, i, 7) - 0.5) * 2.4 + (PI if (i % 2) == 0 else 0.0)
		k.sway = lerpf(0.45, 0.95, t)
		k.sway_phase = Rng.hash01(seed_value, i, 9)
		var tone := leaf
		if (i % 3) == 0:
			tone = dark
		elif (i % 11) == 0:
			tone = pale
		_spray(k, at, size, yaw, seed_value * 31 + i, tone)
	k.sway = 0.0
	k.sway_phase = 0.0


## One spray: needle blades along a short axis, alternating either side of it
## and drooping at their tips. A FEATHER, not a star.
##
## The first version fanned five blades over 110 degrees in the ground plane,
## and from a camera looking straight down that is a five-pointed star -- so a
## pinewood came out roofed in asterisks. A conifer carries its needles in two
## rows along a twig, which from above reads as a soft directional mass, and
## direction is exactly what a foreground piece needs: the eye has to be able to
## see which way the branch is going, or it is a decal.
static func _spray(k: MeshKit, at: Vector3, size: float, yaw: float, seed_value: int, col: Color) -> void:
	var along := Vector3(cos(yaw), 0.0, sin(yaw))
	var across := Vector3(-sin(yaw), 0.0, cos(yaw))
	for b in 7:
		var t := (float(b) + 0.5) / 7.0
		var hand := 1.0 if (b % 2) == 0 else -1.0
		# Out at about 50 degrees from the twig, which is the angle that reads as
		# a needle rather than as a rib.
		var out := (along * 0.62 + across * (0.78 * hand)).normalized()
		var length := size * (1.7 + Rng.hash01(seed_value, b, 2) * 1.1)
		var root := at + along * (size * 2.2 * t)
		# Out of the plane, alternating up and down, so the spray has thickness
		# and a shadow with structure instead of one flat silhouette.
		var lift := (Rng.hash01(seed_value, b, 4) - 0.35) * size * 0.9
		var tip := root + out * length + Vector3(0.0, -length * (0.18 + Rng.hash01(seed_value, b, 3) * 0.3) + lift, 0.0)
		var side := across * hand * size * 0.26
		# Counter-clockwise from above, so MeshKit's flat normal points at the sky.
		k.tri(root + side, root - side, tip, col)


## A snapped line, running out along +X and sagging under its own weight, with
## an insulator at the root and a rag or two caught on it. The one shape that
## crosses the whole frame.
static func _line(k: MeshKit, seed_value: int, tint: Color) -> void:
	var wire := Palette.PLATE[1].lerp(tint, 0.2)
	wire.a = M_SWARF / 255.0
	var sag := 0.34 + Rng.hash01(seed_value, 1) * 0.30
	var segments := 7
	var prev := Vector3.ZERO
	for i in range(1, segments + 1):
		var t := float(i) / segments
		# A catenary a snapped line really makes: deepest in the middle, and
		# the loose end hangs lower than the fixed one.
		var y := -sin(t * PI) * sag - t * t * 0.28
		var here := Vector3(t, y, (Rng.hash01(seed_value, i, 2) - 0.5) * 0.08)
		k.strut(prev, here, 0.022, 3, wire)
		prev = here
	var iron := Palette.PLATE[2]
	iron.a = M_SWARF / 255.0
	k.prism(0.02, -0.09, 0.0, 0.055, 0.06, 0.04, 5, iron)
	# A rag caught on the line: cloth, so it is MADE and it sways.
	if Rng.hash01(seed_value, 3) < 0.7:
		var t := 0.35 + Rng.hash01(seed_value, 4) * 0.4
		var y := -sin(t * PI) * sag - t * t * 0.28
		var cloth := Palette.LINEN[2].lerp(tint, 0.3)
		cloth.a = M_MADE / 255.0
		k.sway = 0.9
		var w := 0.07 + Rng.hash01(seed_value, 5) * 0.06
		var d := 0.22 + Rng.hash01(seed_value, 6) * 0.20
		k.quad(Vector3(t - w, y, 0.0), Vector3(t + w, y, 0.0),
			Vector3(t + w * 0.7, y - d, 0.03), Vector3(t - w * 0.8, y - d, -0.02), cloth)
		k.sway = 0.0


## An eave: the end of a roof and its gutter, jutting out over the ground.
static func _eave(k: MeshKit, seed_value: int, tint: Color) -> void:
	var timber := Palette.EARTH[2].lerp(tint, 0.35)
	timber.a = M_MADE / 255.0
	var plate := Palette.PLATE[2].lerp(tint, 0.2)
	plate.a = M_SWARF / 255.0
	# The roof's own LIP, and the word is load-bearing: this is the last foot of
	# a roof and the gutter under it, not a second roof. Authored at a three-unit
	# reach it came out wider than the house it hung off (see ROWS).
	var w := 0.46
	k.quad(Vector3(0.0, 0.0, -w), Vector3(1.0, -0.20, -w * 0.82),
		Vector3(1.0, -0.20, w * 0.82), Vector3(0.0, 0.0, w), plate)
	# Two rafters under it, so the underside is not a blank plane.
	for i in 2:
		var z := lerpf(-w * 0.55, w * 0.55, float(i))
		k.strut(Vector3(0.05, -0.04, z), Vector3(0.96, -0.24, z * 0.85), 0.035, 4, timber)
	# A gutter along the lip, and a length of it fallen away.
	if Rng.hash01(seed_value, 1) < 0.75:
		var run := 0.5 + Rng.hash01(seed_value, 2) * 0.4
		k.strut(Vector3(0.99, -0.24, -w * 0.8), Vector3(0.99, -0.24, -w * 0.8 + run * 1.6),
			0.046, 4, plate)
	# A board hanging off by one nail.
	if Rng.hash01(seed_value, 3) < 0.55:
		var z2 := lerpf(-w * 0.7, w * 0.7, Rng.hash01(seed_value, 4))
		k.sway = 0.5
		k.quad(Vector3(0.88, -0.22, z2 - 0.07), Vector3(0.96, -0.22, z2 + 0.07),
			Vector3(0.90, -0.62, z2 + 0.09), Vector3(0.82, -0.62, z2 - 0.05), timber)
		k.sway = 0.0


## A girder: what the machines left standing. Two rails and cross-ties, ruled
## and straight, because FOUND is ruled and MADE is not (docs/LOOK.md law 1).
static func _girder(k: MeshKit, seed_value: int, tint: Color) -> void:
	var steel := Palette.PLATE[1].lerp(tint, 0.25)
	steel.a = M_SWARF / 255.0
	var z := 0.17
	# The rails droop a little at the far end: it is holding itself up and only
	# just. A dead level beam reads as a placed object.
	var drop := 0.06 + Rng.hash01(seed_value, 1) * 0.12
	for s in 2:
		var zz := z * (1.0 if s == 0 else -1.0)
		k.strut(Vector3(0.0, 0.0, zz), Vector3(1.0, -drop, zz * 0.86), 0.048, 4, steel)
	var ties := 4 + int(Rng.hash01(seed_value, 2) * 3.0)
	for i in ties:
		var t := (float(i) + 0.5) / ties
		var y := -drop * t
		var zz := z * lerpf(1.0, 0.86, t)
		k.strut(Vector3(t, y, -zz), Vector3(t, y, zz), 0.030, 3, steel)
	# One diagonal brace, and a broken end where it was cut.
	k.strut(Vector3(0.05, 0.0, -z), Vector3(0.62, -drop * 0.6, z * 0.9), 0.024, 3, steel)
	if Rng.hash01(seed_value, 3) < 0.6:
		var frayed := Palette.RUST[2].lerp(tint, 0.2)
		frayed.a = M_SWARF / 255.0
		k.prism(1.0, -drop - 0.05, 0.0, 0.10, -drop + 0.05, 0.02, 5, frayed)


## A tangle: dead limbs and caught wire, for a dead tree or a scrapwood trunk.
## No foliage, so it reads as an open cage rather than a screen -- which is
## exactly what a bare tree over the frame should be.
static func _tangle(k: MeshKit, seed_value: int, tint: Color) -> void:
	# Dead wood is still wood: needles, for the same reason a bough's limb is
	# (see _bough). The wire caught in it IS built and does rust.
	var wood := Palette.EARTH[1].lerp(tint, 0.35).darkened(0.15)
	wood.a = M_NEEDLES / 255.0
	var wire := Palette.PLATE[1]
	wire.a = M_SWARF / 255.0
	for i in 4:
		var t0 := Rng.hash01(seed_value, i, 1) * 0.3
		var t1 := 0.55 + Rng.hash01(seed_value, i, 2) * 0.45
		var y0 := -t0 * 0.2
		var y1 := -t1 * t1 * 0.5 - Rng.hash01(seed_value, i, 3) * 0.15
		var zz := (Rng.hash01(seed_value, i, 4) - 0.5) * 0.7
		k.sway = 0.35
		k.strut(Vector3(t0, y0, zz * t0), Vector3(t1, y1, zz), lerpf(0.05, 0.018, t1), 4, wood)
		# A twig off each limb, so the cage has more than four bars in it.
		var m := (t0 + t1) * 0.5
		k.strut(Vector3(m, (y0 + y1) * 0.5, zz * 0.6),
			Vector3(m + 0.22, (y0 + y1) * 0.5 - 0.28, zz * 0.6 + (Rng.hash01(seed_value, i, 5) - 0.5) * 0.4),
			0.016, 3, wood)
		k.sway = 0.0
	if Rng.hash01(seed_value, 9) < 0.8:
		k.sway = 0.6
		k.strut(Vector3(0.22, -0.12, 0.1), Vector3(0.85, -0.66, -0.2), 0.013, 3, wire)
		k.sway = 0.0


## A WALKWAY: the way across, two storeys up. This is the piece that makes a city
## a city under this camera. Nothing far away is smaller here, so a skyline does
## nothing — what says "canyon" is a deck crossing over the player's head with a
## lit building standing behind it, and its shadow laid across the street they
## are walking on.
##
## Steel, ruled, and not maintained: a plate deck with a handrail on each side,
## two stays back to the wall it leaves, and one panel gone. It does not sway —
## a bridge that moves in the wind is a rope bridge, and this was poured with the
## block.
static func _walkway(k: MeshKit, seed_value: int, tint: Color) -> void:
	var steel := Palette.PLATE[1].lerp(tint, 0.22)
	steel.a = M_SWARF / 255.0
	var rail := Palette.PLATE[2].lerp(tint, 0.15)
	rail.a = M_SWARF / 255.0
	var w := 0.19
	# The deck in four bays with one of them missing, because a gap is what says
	# nobody has been up here to fix it and it lets the light through.
	var gone := 1 + int(Rng.hash01(seed_value, 1) * 3.0)
	for i in 4:
		if i == gone:
			continue
		var x0 := float(i) * 0.25
		k.box(Vector3(x0, -0.05, -w), Vector3(x0 + 0.245, 0.0, w), steel)
	# Two rails and their stanchions. The rails run the whole way whatever the
	# deck is doing: the gap is in the floor, not in the handrail.
	for s in 2:
		var zz := w * (1.0 if s == 0 else -1.0)
		k.strut(Vector3(0.0, 0.34, zz), Vector3(1.0, 0.30, zz), 0.022, 4, rail)
		k.strut(Vector3(0.0, 0.17, zz), Vector3(1.0, 0.15, zz), 0.014, 3, rail)
		for i in 4:
			var t := 0.08 + float(i) * 0.28
			k.strut(Vector3(t, 0.0, zz), Vector3(t, 0.33, zz), 0.018, 4, rail)
	# Two stays back to the wall it left, so the deck is held up by something.
	for s in 2:
		var zz := w * 0.8 * (1.0 if s == 0 else -1.0)
		k.strut(Vector3(0.02, 0.46, zz), Vector3(0.58, -0.02, zz), 0.020, 4, steel)
	# A conduit slung under it, which is what a city runs between two buildings.
	if Rng.hash01(seed_value, 2) < 0.75:
		k.strut(Vector3(0.0, -0.10, w * 0.4), Vector3(1.0, -0.14, w * 0.4), 0.026, 4, steel)


## A SIGN ARM: the bracket a shopfront hangs its board off, out over the lane.
##
## NOT the sign's LIGHT. What a building's stolen tube is and where it burns is
## `PropModels.neon_point`'s and it hangs on the building itself; this is the
## thing that holds a board out over the street, and what the tube's light falls
## on. Under sodium at head height that is most of what an advertising street IS,
## and it costs a bracket and a plate.
##
## Where the plan's signage is dying (BiomeDressing.signage) the board is dead
## enamel under grime, unlit: nothing over that lane burns at full strength.
static func _sign_arm(k: MeshKit, seed_value: int, tint: Color, dying: bool = false) -> void:
	var steel := Palette.PLATE[1].lerp(tint, 0.2)
	steel.a = M_SWARF / 255.0
	# Enamel, and warm, because everything the eye reads at street level is lit by
	# sodium and a cold board would be the one thing arguing with the light.
	# Barely lifted toward white: the board is a LIGHT, and emission carries a
	# colour toward the page as it burns, so a board that starts pale arrives on
	# screen as a blank white slab and the street has lost the one saturated warm
	# thing in it.
	var enamel := Palette.EMBER[3].lerp(Palette.LINEN[3], 0.10).lerp(tint, 0.12)
	enamel.a = M_NEON / 255.0
	if dying:
		enamel = enamel.darkened(0.6).lerp(Palette.MOSS[1], 0.3)
		enamel.a = M_MADE / 255.0
	k.strut(Vector3(0.0, 0.0, 0.0), Vector3(1.0, -0.06, 0.0), 0.05, 4, steel)
	k.strut(Vector3(0.04, 0.26, 0.0), Vector3(0.74, -0.04, 0.0), 0.028, 4, steel)
	# The board, hung under the end and turned a few degrees off the arm, because
	# one bolt has gone and nothing here is square any more.
	#
	# The drop is held under the stay's own height for a reason a test keeps: the
	# instance scales this template by the piece's SPAN, so a board that hangs a
	# whole unit down at unit span hangs four units down on a shopfront and the
	# street has a curtain across it instead of a sign over it.
	var lean := (Rng.hash01(seed_value, 1) - 0.5) * 0.22
	var drop := 0.46 + Rng.hash01(seed_value, 2) * 0.16
	var half := 0.30 + Rng.hash01(seed_value, 3) * 0.10
	var x0 := 0.52
	var x1 := 0.98
	k.quad(Vector3(x0, -0.10, -half), Vector3(x1, -0.12, -half),
		Vector3(x1, -0.12 - drop, -half + lean), Vector3(x0, -0.10 - drop, -half + lean), enamel)
	k.quad(Vector3(x0, -0.10, half), Vector3(x0, -0.10 - drop, half + lean),
		Vector3(x1, -0.12 - drop, half + lean), Vector3(x1, -0.12, half), enamel)
	# Two hangers, and the conduit that feeds it.
	for s in 2:
		var zz := half * 0.7 * (1.0 if s == 0 else -1.0)
		k.strut(Vector3(x0 + 0.06, -0.04, zz), Vector3(x0 + 0.06, -0.12, zz), 0.016, 3, steel)
		k.strut(Vector3(x1 - 0.06, -0.06, zz), Vector3(x1 - 0.06, -0.14, zz), 0.016, 3, steel)
	k.strut(Vector3(0.0, 0.06, 0.03), Vector3(x1 - 0.1, -0.06, 0.03), 0.014, 3, steel)
