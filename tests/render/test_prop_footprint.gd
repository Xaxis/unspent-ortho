extends TestCase
## WHAT STOPS A BODY IS WHAT IS DRAWN (#75). Every prop kind's model, in every
## land that draws it, against the collision a body meets there, both ways
## within PropWalls.TOL (the machines' own tolerance, tests/models/test_hit_shapes):
##   an INVISIBLE WALL: the collision's edge standing further than TOL from
##     anything drawn at a body's height (the bake's LO..HI);
##   a WALK-THROUGH: drawn mass at the waist (PropWalls.WAIST..HI) lying further
##     than TOL past the collision, so a body stands inside what it sees.
## A walled kind (PropWalls.KINDS) is held to its baked walls in every land; a
## model that changes under them fails here until the table is baked again. Every
## other kind is held to its one disc within DISC_TOL, or named below with why, or
## with what it measures until its walls are fitted.

const F := preload("res://tools/gd/footprint.gd")
const Bake := preload("res://tools/gd/prop_walls_bake.gd")

## How far a kind on one disc may miss its drawing, both ways: a disc cannot
## follow a crown, a heap's slump or a rock's facets closer than this, so it is
## looser than the walls' TOL; a kind that misses by more is walled, or named.
const DISC_TOL := 0.4
## The footprint's raster measures in tenths of a tile, read back as floats.
const ROUND := 0.005
## Kinds that are right to miss a disc, and why. Not measured.
const EXEMPT := {
	PropKind.FIRE: "walked round, not into: nothing of a fire stands at a body's height",
	PropKind.SEAL_HOLE: "a hole in the ice: a body falls in, it does not walk into it",
	PropKind.REEDS: "stems a body pushes through",
	PropKind.PLATFORM: "a deck on legs, walked under: its legs are thinner than a body",
	PropKind.PINE: "a crown over a trunk: the trunk stops a body, the crown hangs over the walk",
	PropKind.SNOW_PINE: "a crown over a trunk, as the pine",
	PropKind.BROADLEAF: "a crown over a trunk, as the pine",
	PropKind.DEAD_TREE: "bare limbs over a trunk, as the pine",
	PropKind.GRAFT_TREE: "a crown over a trunk, as the pine",
	PropKind.SCRAP_TREE: "a crown over a trunk, as the pine",
	PropKind.MOSS_CORE: "a crown over a trunk, as the pine",
	PropKind.GRAVE: "a slab and its marker: a body steps round the mound's disc",
}
## Kinds still on one disc that miss it by more than DISC_TOL, at what they
## measure (gap, walk), until their walls are fitted (#75). A kind that grows past
## its numbers fails; one that comes under DISC_TOL is struck off.
const OVER := {
	PropKind.PYLON: Vector2(0.10, 0.42),
	# Long and thin: they wait for a capsule shape and a nav that sees a wall
	# between two tile centres (#102); fitted as circles, a field routed across them.
	PropKind.FENCE: Vector2(0.00, 1.43),
	PropKind.PIPE: Vector2(0.00, 1.06),
	PropKind.CONVEYOR: Vector2(0.00, 1.39),
	PropKind.SEA_WALL: Vector2(0.41, 1.10),
	PropKind.SALT_RIDGE: Vector2(0.00, 1.40),
	PropKind.WRECKAGE: Vector2(0.00, 1.10),
	PropKind.TIP: Vector2(0.00, 0.41),
	PropKind.WRECK: Vector2(0.57, 0.67),
	PropKind.BENCH: Vector2(0.10, 0.85),
	PropKind.KILN: Vector2(0.00, 0.41),
	PropKind.FIRE_TOWER: Vector2(0.20, 0.50),
	PropKind.STACK: Vector2(0.00, 0.70),
	PropKind.DRILL_RIG: Vector2(0.58, 0.36),
	PropKind.WATER_TANK: Vector2(0.10, 0.42),
	PropKind.SLAG_HEAP: Vector2(0.40, 0.71),
	PropKind.MEMORIAL: Vector2(0.20, 0.50),
	PropKind.MAGNET_HEAP: Vector2(0.00, 0.78),
	PropKind.PRESSURE_BLOCK: Vector2(0.30, 0.80),
	PropKind.GLASS_BLISTER: Vector2(0.00, 0.66),
	PropKind.FUSED_CAR: Vector2(0.10, 0.71),
	PropKind.STRIKE_ROD: Vector2(0.10, 0.67),
	PropKind.LIFT_SHAFT: Vector2(0.20, 0.81),
	PropKind.SHOPFRONT: Vector2(0.60, 0.54),
	PropKind.STAIR_TO_WATER: Vector2(0.00, 0.72),
	PropKind.HOODOO: Vector2(0.14, 0.50),
}


func test_the_table_holds_every_walled_drawing() -> void:
	var bad: Array = []
	var last := -1
	var n := 0
	for c: Array in Bake.cases():
		var kind: int = c[0]
		if kind != last:
			# A line per kind: the gate's hang guard reads ten silent minutes as stuck.
			print("  info walls: %s" % PropKind.NAMES[kind])
			last = kind
		var s := PropWalls.shape(kind, c[1], c[2])
		var polys := Bake.drawn(kind, c[1], c[2])
		var mid := Bake.waist(kind, c[1], c[2])
		n += 1
		if s.is_empty() and not polys.is_empty():
			bad.append("%s v%d %s has no walls" % [PropKind.NAMES[kind], c[1], BiomeRegistry.names()[c[2]]])
		elif not Bake.holds(polys, mid, s):
			var cs := Bake.circles(s)
			bad.append("%s v%d %s: gap %.2f walk %.2f" % [PropKind.NAMES[kind], c[1], BiomeRegistry.names()[c[2]],
				float(F.measure(polys, cs).get("gap", 0.0)), float(F.measure(mid, cs).get("walk", 0.0))])
	print("  info walls: %d models of %d walled kinds" % [n, PropWalls.KINDS.size()])
	eq(bad.size(), 0, "every walled model stands inside its walls within %.2f (regenerate: tools/bake_walls.sh): %s" % [PropWalls.TOL, bad])


func test_a_walled_kind_is_neither_named_nor_exempt() -> void:
	for kind: int in PropWalls.KINDS:
		check(not OVER.has(kind) and not EXEMPT.has(kind), "%s is walled: strike it from OVER and EXEMPT" % PropKind.NAMES[kind])
		# The view casts every prop but a cable's (WorldView.prop_xform) and its
		# walls are cast the same way (PropWalls.of_row).
		check(WorldView.cable_points(kind).is_empty(), "%s hangs no cable" % PropKind.NAMES[kind])


func test_every_other_kind_stops_a_body_where_it_is_drawn() -> void:
	var worst := {}
	for c: Array in _disc_cases():
		var kind: int = c[0]
		var t := PropModels.template(kind, c[1], c[2])
		var body: Array = []
		F.polys(t.made_v, Transform3D.IDENTITY, body, Bake.LO, Bake.HI)
		F.polys(t.found_v, Transform3D.IDENTITY, body, Bake.LO, Bake.HI)
		var waist: Array = []
		F.polys(t.made_v, Transform3D.IDENTITY, waist, PropWalls.WAIST, Bake.HI)
		F.polys(t.found_v, Transform3D.IDENTITY, waist, PropWalls.WAIST, Bake.HI)
		var g := float(F.measure(body, c[3]).get("gap", 0.0))
		var w := float(F.measure(waist, c[3]).get("walk", 0.0))
		var was: Vector2 = worst.get(kind, Vector2.ZERO)
		worst[kind] = Vector2(maxf(was.x, g), maxf(was.y, w))
	var over: Array = []
	var struck: Array = []
	for kind: int in worst:
		var m: Vector2 = worst[kind]
		if OVER.has(kind):
			var bar: Vector2 = OVER[kind]
			if m.x > bar.x + 0.01 or m.y > bar.y + 0.01:
				over.append("%s grew to gap %.2f walk %.2f (named at %.2f, %.2f)" % [PropKind.NAMES[kind], m.x, m.y, bar.x, bar.y])
			elif m.x <= DISC_TOL + ROUND and m.y <= DISC_TOL + ROUND:
				struck.append(PropKind.NAMES[kind])
		elif m.x > DISC_TOL + ROUND or m.y > DISC_TOL + ROUND:
			over.append("%s: Vector2(%.2f, %.2f)," % [PropKind.NAMES[kind], m.x, m.y])
	print("  info %d kinds on one disc measured, %d named over %.2f" % [worst.size(), OVER.size(), DISC_TOL])
	eq(over.size(), 0, "every kind on one disc is drawn within %.2f of it, or named: %s" % [DISC_TOL, over])
	eq(struck.size(), 0, "named kinds now inside DISC_TOL, strike them from OVER: %s" % [struck])


## [kind, variant, land, circles (x, z, r) model space] for every kind on one
## disc, in each land that lays it and the coast, one per distinct model.
static func _disc_cases() -> Array:
	var out: Array = []
	var lands: Dictionary = {}
	for d: BiomeDef in BiomeRegistry.land():
		for k: int in d.props:
			lands[k] = (lands.get(k, []) as Array) + [d.index]
		for row: Array in d.ore:
			lands[int(row[0])] = (lands.get(int(row[0]), []) as Array) + [d.index]
	for kind in PropKind.COUNT:
		if PropWalls.KINDS.has(kind) or EXEMPT.has(kind):
			continue
		var seen := {}
		var where: Array = [Country.COAST]
		if kind == PropKind.HOUSE or kind == PropKind.HOUSE_BURNT or PropModels.DRESSED.has(kind):
			where = []
			for d: BiomeDef in BiomeRegistry.land():
				where.append(d.index)
		else:
			for l: int in lands.get(kind, []):
				if not where.has(l):
					where.append(l)
		for land: int in where:
			for v in PropModels.variants(kind, land):
				var t := PropModels.template(kind, v, land)
				var sig := "%d/%d" % [t.made_v.size(), t.found_v.size()]
				if kind == PropKind.HOUSE or kind == PropKind.HOUSE_BURNT:
					sig = String(BiomeForms.of(land).form(v))
				if seen.has(sig):
					continue
				seen[sig] = true
				var solid := PropKind.SOLID[kind]
				if kind == PropKind.HOUSE or kind == PropKind.HOUSE_BURNT:
					solid = BiomeForms.of(land).reach(v)
				out.append([kind, v, land, [Vector3(0, 0, solid)] if solid > 0.0 else []])
	return out
