extends RefCounted
## The machines' works across the land, drawn by the ruler (docs/LOOK.md law 3):
## FOUND, exact, symmetric, chamfered, riveted, rust only in straight downward
## runs, never hatched. Most still work. Their order lights itself in a few
## accents that mean something: a cold strip along a live installation, a slow
## beacon on a mast, the amber of a working part. Dead ones are dark.
##
## FOUND vertex alpha is light (found.gdshader): 0.5..0.98 a steady strip,
## below 0.5 a beacon on the machine beat. What lies around a work (drifts,
## oil, spilled ore, burnt paper) is the land's and MADE.
##
## Models face +X. Runs (pipes, conveyors) lie along X, two tiles long per
## piece, so a line of them is placed end to end with rot = the line's bearing.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Remains := preload("res://src/models/props/remains.gd")

## The machines' own light, and the ONE place its colour is written: the geometry
## that draws a strip or a beacon, the pool it casts, its wet-ground glint and its
## shaft in fog all read these, so they cannot disagree about what colour a mast is.
##
## It sits on the machines' own arc (docs/LOOK.md and the Palette contract): a
## cold violet-white strip along a live installation, and a beacon at the burnt
## end of the violet arc (hue 331, blue above green) with only an amber cast to
## it. ART §4 gives the machines ONE warm read, the amber working part, so the
## beacon may not be a second: it is held below LENS in value as well as in
## chroma, and a relay mast standing in a clear noon must not be the brightest
## object in the frame.
##
## The alpha is the FOUND light code (found.gdshader): the strip is steady, the
## beacon blinks on the machine beat and is held down so its flash is a warning,
## not a sun.
const STRIP := Color(0.7451, 0.7294, 0.8745, 0.88)
const BEACON := Color(0.7098, 0.5176, 0.6118, 0.36)
const WORKING := Color(0.9098, 0.7608, 0.2275, 0.88)


## The machines' light as a light: the rgb a pool, a glint or a fog shaft takes
## from one of the colours above (15_lights, which works in Vector3).
static func light(col: Color) -> Vector3:
	return Vector3(col.r, col.g, col.b)


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.SIGN: road_sign(k, v, c)
		PropKind.TIDE_GAUGE: tide_gauge(k, v, c)
		PropKind.INTAKE: intake(k, v, c)
		PropKind.PUMP_HOUSE: pump_house(k, v, c)
		PropKind.PIPE: pipe(k, v, c)
		PropKind.RELAY: relay(k, v, c)
		PropKind.CHECKPOINT: checkpoint(k, v, c)
		PropKind.STACK: stack(k, v, c)
		PropKind.DRILL_RIG: drill_rig(k, v, c)
		PropKind.CONVEYOR: conveyor(k, v, c)
		PropKind.SURVEY: survey(k, v, c)
		PropKind.VENT_CAP: vent_cap(k, v, c)
		PropKind.ARCHIVE: archive(k, v, c)


## A light colour at a glow level (FOUND alpha code).
static func lit(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, a)


## Rust weeping down a FOUND face from `top`: dark and narrow where it starts,
## warmer and wider as it runs, a pale stain at the tail.
##
## IT WAS A STRAP. The first version was one quad, uniform width and RUST[2] end
## to end, and the moment it could be photographed (#79, #80) it read as
## something painted on: square cuts top and bottom starting in the middle of a
## flat panel, no source, no tail, no halo, and crossing a flange without being
## interrupted. Measured, it was also DARKER than the metal it lay on — RUST[2]
## is luma 0.244 against PLATE[2] 0.287 and PLATE[3] 0.389 — and rust on grey
## steel reads warmer AND lighter. Three faults, one of them arithmetic.
##
## So: a graded strip. The darkest rung at the weep, the light rungs down the
## run, and a last step lerped toward the plate so it thins into staining rather
## than stopping on a ruled line. It leans as it falls, by a hash of where it
## starts, so two runs on one drum are not two copies of each other.
##
## WHERE it begins is still the caller's and cannot be worked out here: rust
## starts where water sits or metal is broken, so pass a `top` at a seam, a bolt
## or a lip rather than the middle of a panel.
##
## `along` runs ACROSS the face and a quad's front is `(c - b) x (a - b)`, which
## in the order these corners were first written came out at -`out`: every rust
## run in the game stood a hair proud of its plate FACING INTO IT, and
## found.gdshader culls a back face, so not one of them has ever been drawn.
## Nothing said so, because a missing thing raises no error
## (tests/render/test_found_drawn.gd). The winding is decided here, from the
## direction the run is meant to be seen from, and never left to corner order.
const RUN_STEPS := 6
## Per step down the run, how wide it is against `width`. It only ever WIDENS:
## narrowing it again at the tail drew a dagger — a brush stroke with a point on
## it — where what is wanted is a weep that spreads. The tail fades by COLOUR
## instead, which is what staining does.
const RUN_WIDE: Array[float] = [0.34, 0.72, 0.98, 1.12, 1.22, 1.30]


static func run(k: Kit, top: Vector3, width: float, length: float, out: Vector3) -> void:
	var o := out.normalized()
	var side := Vector3(o.z, 0, -o.x)
	if side.cross(Vector3.DOWN).dot(o) < 0.0:
		side = -side
	var lift := o * 0.006
	# The tail is rust let down toward the plate: a stain, not an edge.
	var shades: Array[Color] = [P.RUST[1], P.RUST[3], P.RUST[4], P.RUST[4],
		P.RUST[4].lerp(P.PLATE[4], 0.35), P.RUST[4].lerp(P.PLATE[4], 0.62)]
	# A lean of its own, from where it starts, so a drum's runs are not copies.
	var lean := sin(top.x * 12.9898 + top.y * 4.1414 + top.z * 78.233) * width * 0.6
	for i in RUN_STEPS:
		var t0 := float(i) / RUN_STEPS
		var t1 := float(i + 1) / RUN_STEPS
		var a0 := top + Vector3(0, -length * t0, 0) + side * lean * t0 * t0 + lift
		var a1 := top + Vector3(0, -length * t1, 0) + side * lean * t1 * t1 + lift
		var w0 := side * width * 0.5 * RUN_WIDE[i]
		var w1 := side * width * 0.5 * RUN_WIDE[mini(i + 1, RUN_STEPS - 1)]
		k.found.quad(a0 - w0, a0 + w0, a1 + w1, a1 - w1, shades[i])


## A row of rivets along a line on a face.
static func rivets(k: Kit, a: Vector3, b: Vector3, n: int, out: Vector3) -> void:
	var o := out.normalized() * 0.008
	var u := (b - a).normalized() * 0.014
	var up := Vector3(0, 0.014, 0) if absf(o.y) < 0.5 else Vector3(0.014, 0, 0)
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n) + o
		k.found.quad(p - u - up, p + u - up, p + u + up, p - u + up, P.PLATE[5])


## What a work stands in: its landscape's drift, low, MADE.
static func footing(k: Kit, c: int, r: float, s: int) -> void:
	var d := Remains.drift_of(c)
	Remains.banks(k, [[r, r * 0.3, r * 0.4, 0.12], [-r * 0.8, -r * 0.6, r * 0.35, 0.1], [-r * 0.2, r * 0.9, r * 0.3, 0.08]], d[0], s)


# --- signs ---------------------------------------------------------------------

## A warning nobody reads. 0: the machines' plate on an exact post, glyphs in
## rows and a triangle; 1: a curfew board of ruled hours, a lens still set in
## it; 2: people's own board nailed over a machine plate, a skull of strokes;
## 3: one knocked down (tipped_sign).
## Scoured pale in the bonelands, rimed in the snow, scorched in the burning.
static func road_sign(k: Kit, v: int, c: int) -> void:
	if v == 3:
		tipped_sign(k, c)
		return
	var dress := BiomeDressing.of(c)
	var s := 30100 + v * 3 + c
	var face := dress.sign[0]
	var ink := dress.sign[1]
	# Soft ground lets a post go over; scoured ground undercuts one.
	var lean := Basis(Vector3.BACK, 0.06 if BiomeDressing.reedy(c) else 0.0) * Basis(Vector3.RIGHT, 0.05 if dress.perishes() else 0.0)
	k.found.push(Transform3D(lean, Vector3.ZERO))
	match v % 3:
		0:
			k.found.prism(0, -0.05, 0, 0.045, 1.35, 0.045, 4, P.PLATE[2], P.PLATE[3], PI * 0.25)
			var y0 := 0.8
			k.found.quad(Vector3(0.05, y0, 0.32), Vector3(0.05, y0, -0.32), Vector3(0.05, y0 + 0.48, -0.32), Vector3(0.05, y0 + 0.48, 0.32), P.PLATE[1])
			k.found.quad(Vector3(0.056, y0 + 0.03, 0.29), Vector3(0.056, y0 + 0.03, -0.29), Vector3(0.056, y0 + 0.45, -0.29), Vector3(0.056, y0 + 0.45, 0.29), face)
			# The triangle and its bar: stop.
			k.found.tri(Vector3(0.06, y0 + 0.1, 0.24), Vector3(0.06, y0 + 0.1, 0.02), Vector3(0.06, y0 + 0.38, 0.13), ink)
			k.found.tri(Vector3(0.062, y0 + 0.15, 0.2), Vector3(0.062, y0 + 0.15, 0.06), Vector3(0.062, y0 + 0.31, 0.13), P.RUST[3])
			for r in 4:
				var y := y0 + 0.1 + r * 0.08
				k.found.quad(Vector3(0.06, y, -0.04), Vector3(0.06, y, -0.26 + (r % 2) * 0.06), Vector3(0.06, y + 0.035, -0.26 + (r % 2) * 0.06), Vector3(0.06, y + 0.035, -0.04), ink)
			run(k, Vector3(0.057, y0 + 0.44, -0.2), 0.03, 0.25, Vector3(1, 0, 0))
			k.found.quad(Vector3(-0.05, y0, -0.32), Vector3(-0.05, y0, 0.32), Vector3(-0.05, y0 + 0.48, 0.32), Vector3(-0.05, y0 + 0.48, -0.32), P.PLATE[2])
		1:
			for sz: float in [-0.36, 0.36]:
				k.found.prism(0, -0.05, sz, 0.04, 1.8, 0.04, 4, P.PLATE[2], P.PLATE[3], PI * 0.25)
			var y0 := 0.7
			k.found.quad(Vector3(0.04, y0, 0.42), Vector3(0.04, y0, -0.42), Vector3(0.04, y0 + 1.0, -0.42), Vector3(0.04, y0 + 1.0, 0.42), P.PLATE[1])
			k.found.quad(Vector3(0.046, y0 + 0.04, 0.38), Vector3(0.046, y0 + 0.04, -0.38), Vector3(0.046, y0 + 0.96, -0.38), Vector3(0.046, y0 + 0.96, 0.38), face)
			# The hours in a ruled grid, most of them struck: the curfew.
			for r in 6:
				for col in 7:
					var y := y0 + 0.12 + r * 0.13
					var z := 0.3 - col * 0.1
					var on := Rng.hash01(s, r * 7 + col) < 0.62
					k.found.quad(Vector3(0.05, y, z), Vector3(0.05, y, z - 0.07), Vector3(0.05, y + 0.08, z - 0.07), Vector3(0.05, y + 0.08, z), ink if on else P.PLATE[4])
			k.found.prism(0.05, y0 + 0.92, 0.0, 0.05, y0 + 0.93, 0.05, 8, P.PLATE[1])
			k.found.push(Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(0.05, y0 + 0.9, 0.0)))
			k.found.prism(0, 0, 0, 0.035, 0.04, 0.035, 8, lit(P.LENS[2], 0.9))
			k.found.pop()
			k.found.quad(Vector3(-0.04, y0, -0.42), Vector3(-0.04, y0, 0.42), Vector3(-0.04, y0 + 1.0, 0.42), Vector3(-0.04, y0 + 1.0, -0.42), P.PLATE[2])
		_:
			# The machine's plate, and it stands TALLER than what was nailed over
			# it: at 0.62..1.02 the people's two boards covered every pixel of it,
			# so the one thing this variant is about — their warning nailed over
			# the machines' — read as a wood board on a post, and the plate under
			# it was triangles nobody had ever seen.
			k.found.prism(0, -0.05, 0, 0.04, 1.14, 0.04, 4, P.PLATE[2], P.PLATE[3], PI * 0.25)
			k.found.quad(Vector3(0.042, 0.56, 0.3), Vector3(0.042, 0.56, -0.3), Vector3(0.042, 1.16, -0.3), Vector3(0.042, 1.16, 0.3), P.PLATE[1])
			k.found.quad(Vector3(0.048, 0.59, 0.27), Vector3(0.048, 0.59, -0.27), Vector3(0.048, 1.13, -0.27), Vector3(0.048, 1.13, 0.27), face)
	k.found.pop()
	if v % 3 == 2:
		# People's board over it: planks, a skull and a bar, a warning of their own.
		var wood := Remains.wood_of(c)
		# Low on the plate, so its pale ruled head stands clear over them.
		k.made.push(Transform3D(lean * Basis(Vector3.RIGHT, 0.08), Vector3(0.07, 0.0, 0.0)))
		k.slab(0.0, 0.41, 0.0, 0.03, 0.26, 0.7, s, wood[0], wood[1], 0.02)
		k.slab(0.0, 0.68, 0.02, 0.03, 0.24, 0.66, s + 1, wood[1], wood[0], 0.02)
		k.made.prism(0.02, 0.66, -0.05, 0.1, 0.69, 0.09, 7, P.LINEN[5])
		k.made.quad(Vector3(0.025, 0.68, -0.1), Vector3(0.025, 0.68, -0.06), Vector3(0.025, 0.72, -0.06), Vector3(0.025, 0.72, -0.1), P.INK[0])
		k.made.quad(Vector3(0.025, 0.68, -0.04), Vector3(0.025, 0.68, 0.0), Vector3(0.025, 0.72, 0.0), Vector3(0.025, 0.72, -0.04), P.INK[0])
		k.made.quad(Vector3(0.025, 0.49, 0.28), Vector3(0.025, 0.49, -0.28), Vector3(0.025, 0.55, -0.26), Vector3(0.025, 0.55, 0.3), P.RUST[3])
		k.made.pop()
	if dress.cold():
		k.clump(0.0, 1.28 if v % 3 == 0 else (1.7 if v % 3 == 1 else 1.16), 0.0, 0.2 if v % 3 == 0 else 0.26, 0.06, s + 7, dress.snow[0], 6)
		Remains.banks(k, [[0.2, 0.2, 0.3, 0.2], [-0.2, -0.1, 0.25, 0.14]], dress.snow[0], s + 8)
	elif dress.perishes():
		# Scoured: the dust undercuts a post rather than banking over it.
		Remains.banks(k, [[-0.25, 0.1, 0.3, 0.1]], dress.drift[0], s + 8)


## A warning knocked flat: its post snapped at the foot and bent, the plate
## face up in the grass where it fell, still ruled, still warning; a second
## plate torn off it lying apart; the stub standing.
static func tipped_sign(k: Kit, c: int) -> void:
	var s := 30190 + c
	var face := BiomeDressing.of(c).sign[0]
	k.found.prism(0, -0.05, 0, 0.05, 0.28, 0.05, 4, P.PLATE[2], P.PLATE[1], PI * 0.25)
	k.found.push(Transform3D(Basis(Vector3.BACK, -1.35) * Basis(Vector3.UP, 0.2), Vector3(0.02, 0.26, 0.0)))
	k.found.prism(0, 0.0, 0, 0.045, 1.2, 0.045, 4, P.PLATE[2], P.PLATE[3], PI * 0.25)
	k.found.pop()
	# The plate, lying a hair off the ground on its bent post, tilted up at one edge.
	k.found.push(Transform3D(Basis(Vector3.UP, 0.2) * Basis(Vector3.BACK, 0.12), Vector3(1.05, 0.09, 0.05)))
	k.found.quad(Vector3(-0.32, 0.0, 0.26), Vector3(0.32, 0.0, 0.26), Vector3(0.32, 0.0, -0.26), Vector3(-0.32, 0.0, -0.26), P.PLATE[1])
	k.found.quad(Vector3(-0.29, 0.006, 0.23), Vector3(0.29, 0.006, 0.23), Vector3(0.29, 0.006, -0.23), Vector3(-0.29, 0.006, -0.23), face)
	k.found.tri(Vector3(-0.2, 0.01, 0.16), Vector3(0.02, 0.01, 0.16), Vector3(-0.09, 0.01, -0.12), P.INK[1])
	k.found.tri(Vector3(-0.16, 0.012, 0.11), Vector3(-0.02, 0.012, 0.11), Vector3(-0.09, 0.012, -0.05), P.RUST[3])
	for r in 4:
		var x := 0.06 + r * 0.055
		k.found.quad(Vector3(x, 0.01, 0.2), Vector3(x + 0.03, 0.01, 0.2), Vector3(x + 0.03, 0.01, -0.2 + (r % 2) * 0.08), Vector3(x, 0.01, -0.2 + (r % 2) * 0.08), P.INK[1])
	k.found.pop()
	# The second plate, torn away, face down, its back ruled with its bracing.
	k.found.push(Transform3D(Basis(Vector3.UP, -0.7) * Basis(Vector3.RIGHT, 0.2), Vector3(0.35, 0.05, -0.65)))
	k.found.quad(Vector3(-0.22, 0.0, 0.16), Vector3(0.22, 0.0, 0.16), Vector3(0.22, 0.0, -0.16), Vector3(-0.22, 0.0, -0.16), P.PLATE[2])
	k.found.quad(Vector3(-0.2, 0.006, 0.012), Vector3(0.2, 0.006, 0.012), Vector3(0.2, 0.006, -0.012), Vector3(-0.2, 0.006, -0.012), P.PLATE[4])
	k.found.pop()
	# What grew or blew over it.
	var d := Remains.drift_of(c)
	var dress := BiomeDressing.of(c)
	if dress.cold():
		Remains.drift(k, Vector3(0.9, 0.0, -0.3), 0.6, 0.3, 0.12, 0.3, dress.snow[0], s)
	elif BiomeDressing.grassy(c):
		var rs := k.made.vertex_count()
		for i in 7:
			var base := Vector3(0.7 + i * 0.12, 0.0, 0.32 + Kit.j(s, i, 0.08))
			k.blade(base, base + Vector3(0.03, 0.3 + Kit.j(s, i + 9, 0.08), 0.02), 0.04, i * 0.7, P.MOSS[3] if i % 2 else P.SPRUCE[2])
		k.sway_by_height(rs, 0.0, 0.35, 0.5)
	else:
		Remains.drift(k, Vector3(1.3, 0.0, -0.1), 0.4, 0.25, 0.06, 0.5, d[0], s)


# --- the coast -----------------------------------------------------------------

## 0: a tide gauge on the shore: a staff ruled in bands, a housing with its
## lens, a beacon on top. 1: a warning buoy thrown up the beach, its lamp dead.
static func tide_gauge(k: Kit, v: int, c: int) -> void:
	var s := 30300 + v + c
	if v % 2 == 0:
		k.chamfer(0.0, -0.1, 0.0, 0.5, 0.25, 0.5, 0.08, P.PLATE[1], P.PLATE[2])
		k.found.prism(0, 0.15, 0, 0.06, 2.4, 0.06, 6, P.PLATE[3], P.PLATE[4])
		for i in 10:
			var y := 0.2 + i * 0.2
			k.found.prism(0, y, 0, 0.065, y + 0.1, 0.065, 6, P.COLD[3] if i % 2 == 0 else P.INK[1])
		k.chamfer(0.0, 1.55, 0.14, 0.26, 0.4, 0.2, 0.05, P.PLATE[2], P.PLATE[3])
		k.found.quad(Vector3(0.131, 1.75, 0.2), Vector3(0.131, 1.75, 0.08), Vector3(0.131, 1.85, 0.08), Vector3(0.131, 1.85, 0.2), lit(P.LENS[2], 0.86))
		rivets(k, Vector3(0.131, 1.62, 0.06), Vector3(0.131, 1.62, 0.22), 3, Vector3(1, 0, 0))
		k.found.prism(0, 2.4, 0, 0.1, 2.46, 0.1, 8, P.PLATE[2])
		k.found.prism(0, 2.46, 0, 0.05, 2.6, 0.04, 8, BEACON)
		k.rod(Vector3(0, 2.1, 0), Vector3(0.0, 2.1, -0.5), 0.012, 4, P.PLATE[3])
		k.found.quad(Vector3(0.0, 1.95, -0.5), Vector3(0.0, 1.95, -0.3), Vector3(0.0, 2.2, -0.3), Vector3(0.0, 2.2, -0.5), P.PLATE[4])
		run(k, Vector3(0.061, 2.3, 0.0), 0.02, 0.9, Vector3(1, 0, 0))
		# Weed and barnacles up the foot, where the water comes.
		k.clump(0.05, -0.1, 0.1, 0.35, 0.2, s, P.SPRUCE[1], 7)
	else:
		k.found.push(Transform3D(Basis(Vector3.BACK, 1.2) * Basis(Vector3.UP, 0.4), Vector3(0.0, 0.35, 0.0)))
		k.found.prism(0, -0.4, 0, 0.45, 0.0, 0.45, 12, P.RUST[3].lerp(P.PLATE[2], 0.3), P.PLATE[1])
		k.found.prism(0, 0.0, 0, 0.45, 0.1, 0.3, 12, P.RUST[2], P.RUST[3])
		k.found.prism(0, -0.6, 0, 0.3, -0.4, 0.45, 12, P.PLATE[1])
		for i in 4:
			var a := float(i) / 4.0 * TAU + PI * 0.25
			k.rod(Vector3(cos(a) * 0.25, 0.1, sin(a) * 0.25), Vector3(cos(a) * 0.1, 1.0, sin(a) * 0.1), 0.02, 4, P.PLATE[2])
		k.hoop(Vector3(0, 0.55, 0), 0.18, 8, 0.015, P.PLATE[2])
		k.found.prism(0, 1.0, 0, 0.09, 1.2, 0.07, 8, P.COLD[1], P.INK[1])
		for i in 6:
			var a := float(i) / 6.0 * TAU
			run(k, Vector3(cos(a) * 0.455, -0.02, sin(a) * 0.455), 0.05, 0.3, Vector3(cos(a), 0, sin(a)))
		k.found.pop()
		Remains.banks(k, [[-0.4, 0.4, 0.5, 0.25], [0.5, -0.3, 0.4, 0.2], [0.1, 0.6, 0.35, 0.16]], Remains.drift_of(c)[0], s + 3)
		for i in 4:
			k.made.quad(Vector3(-0.6 + i * 0.3, 0.02, -0.5), Vector3(-0.5 + i * 0.3, 0.02, -0.5), Vector3(-0.45 + i * 0.3, 0.02, -0.9), Vector3(-0.55 + i * 0.3, 0.02, -0.9), P.EARTH[1] if i % 2 else P.SPRUCE[1])


## An intake the machines sank at the shore: an exact housing, two ruled pipes
## running out to the water, grilles, a strip of cold light, and the amber of
## the pump still working. It hums. 1: its grille torn off, one pipe broken.
static func intake(k: Kit, v: int, c: int) -> void:
	var s := 30500 + v + c
	var body := P.PLATE[2]
	k.chamfer(-0.6, -0.1, 0.0, 1.6, 1.25, 1.9, 0.22, body, P.PLATE[3])
	k.chamfer(-0.6, 1.15, 0.0, 1.3, 0.2, 1.6, 0.14, P.PLATE[1], P.PLATE[2])
	# Louvres on the landward end, a door plate, the strip along the eave.
	#
	# Real blades, not a painted ladder: these were flat quads on the plane of the
	# end wall wound to face +X, which is INTO the housing, so four of the five
	# drew from no bearing at all. A blade that sheds rain slopes down and out,
	# which turns its one seen face UP and out — the only way a thing on a wall
	# stays visible to a camera that is always above it. And no slot drawn behind
	# it: a recess under a blade that overhangs it is hidden from that same
	# camera, so the blade's own shade on the wall is the slot.
	for i in 5:
		var y := 0.25 + i * 0.16
		Remains._facing_quad(k.found, Vector3(-1.398, y + 0.09, 0.5), Vector3(-1.398, y + 0.09, -0.5),
			Vector3(-0.07, -0.08, 0), Vector3(-0.75, 0.66, 0), P.PLATE[0])
	for sz: float in [1.0, -1.0]:
		var z := 0.951 * sz
		Remains._facing_quad(k.found, Vector3(-1.3, 0.99, z), Vector3(0.1, 0.99, z), Vector3(0, 0.09, 0), Vector3(0, 0, sz), STRIP)
		rivets(k, Vector3(-1.3, 0.2, z), Vector3(0.1, 0.2, z), 8, Vector3(0, 0, sz))
		run(k, Vector3(-0.4, 0.98, z + 0.004 * sz), 0.05, 0.5, Vector3(0, 0, sz))
		run(k, Vector3(-1.0, 0.98, z + 0.004 * sz), 0.04, 0.72, Vector3(0, 0, sz))
	k.found.quad(Vector3(0.201, 0.9, 0.12), Vector3(0.201, 0.9, -0.12), Vector3(0.201, 1.02, -0.12), Vector3(0.201, 1.02, 0.12), WORKING)
	# The pipes out to the sea, on exact saddles.
	for pz: float in [-0.45, 0.45]:
		var broken := v % 2 == 1 and pz > 0.0
		var end := 1.1 if broken else 2.4
		k.found.push(Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(0.1, 0.42, pz)))
		k.found.prism(0, 0, 0, 0.26, end, 0.26, 10, P.PLATE[3], P.PLATE[2])
		for i in 3:
			var y := 0.3 + i * 0.7
			if y < end:
				k.found.prism(0, y, 0, 0.3, y + 0.08, 0.3, 10, P.PLATE[1])
		k.found.pop()
		if not broken:
			# The mouth: a grille over black.
			k.found.push(Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(2.5, 0.42, pz)))
			k.found.prism(0, 0, 0, 0.32, 0.06, 0.32, 10, P.PLATE[1], P.INK[0])
			k.found.pop()
			for g in 3:
				var gz := pz - 0.18 + g * 0.18
				k.rod(Vector3(2.57, 0.16, gz), Vector3(2.57, 0.68, gz), 0.014, 4, P.PLATE[3])
		else:
			k.found.push(Transform3D(Basis(Vector3.BACK, -PI * 0.5 + 0.35), Vector3(1.6, 0.2, pz + 0.1)))
			k.found.prism(0, 0, 0, 0.26, 0.9, 0.26, 10, P.RUST[2], P.PLATE[1])
			k.found.pop()
		for sx: float in [0.9, 1.8]:
			if sx < end:
				k.chamfer(sx, -0.1, pz, 0.12, 0.3, 0.6, 0.03, P.PLATE[1], P.PLATE[2])
	footing(k, c, 1.4, s + 10)


# --- the drained fen -------------------------------------------------------------

## A pump house draining the moss: a squat exact block, a flywheel housing,
## the outfall pipe leaving +X, oil sheened on the water under it. 1: dead,
## its strip dark and its door plate hanging.
static func pump_house(k: Kit, v: int, c: int) -> void:
	var s := 30700 + v + c
	var alive := v % 2 == 0
	k.chamfer(0.0, -0.1, 0.0, 1.7, 1.3, 1.5, 0.2, P.PLATE[2], P.PLATE[3])
	k.found.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.2, 1.15, -0.78)))
	k.found.prism(0, 0, 0, 0.5, 0.18, 0.5, 12, P.PLATE[1], P.PLATE[3])
	k.found.prism(0, 0.18, 0, 0.12, 0.26, 0.12, 8, lit(P.LENS[2], 0.86) if alive else P.PLATE[4])
	k.found.pop()
	k.chamfer(0.0, 1.2, 0.0, 1.2, 0.3, 1.0, 0.1, P.PLATE[1], P.PLATE[2])
	for sz: float in [0.751, -0.751]:
		Remains._facing_quad(k.found, Vector3(-0.7, 0.92, sz), Vector3(0.7, 0.92, sz), Vector3(0, 0.08, 0), Vector3(0, 0, signf(sz)), STRIP if alive else P.PLATE[0])
		rivets(k, Vector3(-0.7, 0.12, sz), Vector3(0.7, 0.12, sz), 7, Vector3(0, 0, signf(sz)))
		run(k, Vector3(0.3, 0.92, sz * 1.004), 0.05, 0.62, Vector3(0, 0, signf(sz)))
	if alive:
		k.found.quad(Vector3(0.851, 0.1, 0.3), Vector3(0.851, 0.1, -0.1), Vector3(0.851, 0.85, -0.1), Vector3(0.851, 0.85, 0.3), P.PLATE[1])
	else:
		k.found.quad(Vector3(0.86, 0.05, 0.25), Vector3(0.95, 0.05, -0.15), Vector3(0.95, 0.8, -0.15), Vector3(0.86, 0.8, 0.25), P.PLATE[3])
		k.found.quad(Vector3(0.851, 0.1, 0.3), Vector3(0.851, 0.1, -0.1), Vector3(0.851, 0.85, -0.1), Vector3(0.851, 0.85, 0.3), P.INK[0])
	# The outfall: out at +X, down to the cut.
	k.found.push(Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(0.85, 0.35, -0.45)))
	k.found.prism(0, 0, 0, 0.16, 0.9, 0.16, 8, P.PLATE[3], P.PLATE[2])
	k.found.prism(0, 0.85, 0, 0.2, 0.93, 0.2, 8, P.PLATE[1], P.INK[0])
	k.found.pop()
	_oil(k, Vector3(1.9, 0.0, -0.45), 0.42, s + 5)
	Remains.banks(k, [[-0.9, 0.8, 0.45, 0.14], [-1.0, -0.7, 0.4, 0.12]], Remains.drift_of(c)[0], s + 9)


## A slick of oily runoff on standing water: black, with the sheen of the sky
## in thin bands across it. MADE (it is the land's now).
static func _oil(k: Kit, at: Vector3, r: float, s: int) -> void:
	var ring: Array[Vector3] = []
	for i in 10:
		var a := float(i) / 10.0 * TAU
		var rr := r * (0.75 + Rng.hash01(s, i) * 0.4)
		ring.append(at + Vector3(cos(a) * rr * 1.3, 0.012, sin(a) * rr))
	for i in 10:
		k.made.tri(at + Vector3(0, 0.012, 0), ring[(i + 1) % 10], ring[i], P.INK[3].lerp(P.SPRUCE[1], 0.5))
	var sheen: Array[Color] = [P.BLOOM[2], P.SPRUCE[4], P.RUST[3]]
	for b in 3:
		var y := 0.016
		var z := at.z - r * 0.4 + b * r * 0.35
		k.made.quad(Vector3(at.x - r * 0.7 + b * 0.1, y, z), Vector3(at.x + r * 0.6, y, z + 0.08), Vector3(at.x + r * 0.6, y, z + 0.12), Vector3(at.x - r * 0.7 + b * 0.1, y, z + 0.035), GroundColors.glint(sheen[b]))


## A pipeline run on stilts, two tiles to a piece. 0: whole, a flange and a
## valve wheel; 1: fallen off one stilt and split, leaking. Taller over the
## moss; blackened and collapsed in the burning's refinery runs.
static func pipe(k: Kit, v: int, c: int) -> void:
	var d := BiomeDressing.of(c)
	var s := 30900 + v + c
	# Carried clear of standing water where there is any.
	var h := 1.1 if BiomeDressing.reedy(c) else 0.8
	var col: Color = P.STONE[1].lerp(P.PLATE[2], 0.4) if BiomeDressing.burnt(c) else P.PLATE[3]
	var r := 0.14
	for sx: float in [-0.55, 0.45]:
		if v % 2 == 1 and sx > 0.0:
			k.rod(Vector3(sx, -0.05, 0), Vector3(sx + 0.3, 0.5, 0.1), 0.03, 4, P.PLATE[1])
			continue
		k.rod(Vector3(sx, -0.15, -0.18), Vector3(sx, h - r, 0), 0.03, 4, P.PLATE[1])
		k.rod(Vector3(sx, -0.15, 0.18), Vector3(sx, h - r, 0), 0.03, 4, P.PLATE[1])
		k.chamfer(sx, h - r - 0.06, 0.0, 0.1, 0.06, 0.34, 0.02, P.PLATE[2])
	if v % 2 == 0:
		k.found.push(Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(-1.0, h, 0.0)))
		k.found.prism(0, 0, 0, r, 2.0, r, 8, col, col)
		k.found.prism(0, 0.96, 0, r + 0.04, 1.04, r + 0.04, 8, P.PLATE[1])
		k.found.pop()
		k.rod(Vector3(0.0, h + r, 0.0), Vector3(0.0, h + r + 0.16, 0.0), 0.02, 4, P.PLATE[2])
		k.hoop(Vector3(0.0, h + r + 0.18, 0.0), 0.12, 8, 0.014, P.RUST[3])
	else:
		k.found.push(Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(-1.0, h, 0.0)))
		k.found.prism(0, 0, 0, r, 0.95, r, 8, col, col)
		k.found.pop()
		k.found.push(Transform3D(Basis(Vector3.BACK, -PI * 0.5 - 0.62), Vector3(0.05, h - 0.1, 0.05)))
		k.found.prism(0, 0, 0, r, 1.0, r, 8, P.RUST[2].lerp(col, 0.4), P.INK[1])
		k.found.pop()
		_oil(k, Vector3(0.3, 0.0, 0.25), 0.28, s + 3)
	if BiomeDressing.reedy(c):
		var rs := k.made.vertex_count()
		for i in 6:
			var x := -0.9 + i * 0.35
			k.blade(Vector3(x, -0.02, 0.25), Vector3(x + 0.05, 0.7, 0.3), 0.05, 0.3 * i, P.SPRUCE[3] if i % 2 else P.MOSS[3])
		k.sway_by_height(rs, 0.0, 0.7, 0.6)
	else:
		Remains.banks(k, [[0.6, 0.3, 0.3, 0.1], [-0.6, -0.3, 0.3, 0.08]], d.drift[0], s + 5)


# --- the pinewood's corridor -----------------------------------------------------

## A relay mast on the corridor cut through the pines: a slim exact lattice, a
## dish, arms for the line, a cold strip up its spine and a beacon on the beat.
static func relay(k: Kit, v: int, c: int) -> void:
	var s := 31100 + v + c
	var top := 3.6
	var legs: Array[Vector2] = [Vector2(0.28, 0.0), Vector2(-0.14, 0.24), Vector2(-0.14, -0.24)]
	k.chamfer(0.0, -0.1, 0.0, 0.7, 0.18, 0.7, 0.12, P.STONE[2], P.STONE[3])
	for i in 3:
		var a := legs[i]
		var b := legs[(i + 1) % 3]
		k.rod(Vector3(a.x, 0.05, a.y), Vector3(a.x * 0.35, top, a.y * 0.35), 0.03, 4, P.PLATE[3])
		for li in 6:
			var y0 := 0.05 + li * (top / 6.0)
			var y1 := y0 + top / 6.0
			var k0 := 1.0 - y0 / top * 0.65
			var k1 := 1.0 - y1 / top * 0.65
			k.rod(Vector3(a.x * k0, y0, a.y * k0), Vector3(b.x * k1, y1, b.y * k1), 0.012, 4, P.PLATE[2])
	k.found.quad(Vector3(0.1, 0.4, -0.035), Vector3(0.1, 0.4, 0.035), Vector3(0.1, top - 0.2, 0.035), Vector3(0.1, top - 0.2, -0.035), STRIP)
	k.found.quad(Vector3(0.1, top - 0.2, -0.035), Vector3(0.1, top - 0.2, 0.035), Vector3(0.1, 0.4, 0.035), Vector3(0.1, 0.4, -0.035), STRIP)
	# Arms carry the line (WorldView.cable_points), a dish looks down the cut.
	k.rod(Vector3(0, top - 0.3, -0.6), Vector3(0, top - 0.3, 0.6), 0.025, 4, P.PLATE[3])
	for sz: float in [-0.55, 0.55]:
		k.found.prism(0, top - 0.46, sz, 0.035, top - 0.32, 0.03, 8, P.COLD[2], P.COLD[3])
	k.found.push(Transform3D(Basis(Vector3.BACK, -PI * 0.5 + 0.2), Vector3(0.18, top - 0.9, 0.0)))
	k.found.prism(0, 0, 0, 0.36, 0.1, 0.1, 10, P.PLATE[4], P.PLATE[3])
	k.found.prism(0, 0.1, 0, 0.02, 0.35, 0.02, 4, P.PLATE[2])
	k.found.pop()
	k.found.prism(0, top, 0, 0.06, top + 0.1, 0.05, 6, P.PLATE[2])
	k.found.prism(0, top + 0.1, 0, 0.045, top + 0.22, 0.035, 6, BEACON)
	var d := BiomeDressing.of(c)
	if d.cold():
		for i in 5:
			k.rod(Vector3(-0.1, top - 0.32, -0.5 + i * 0.25), Vector3(-0.1, top - 0.5 - (i % 2) * 0.1, -0.5 + i * 0.25), 0.008, 3, d.snow[1])
	footing(k, c, 0.6, s)


# --- the snowfield -------------------------------------------------------------

## A checkpoint gate on a road. The booth stands beside the way (GenWorks puts
## it 2.2 to 2.7 tiles off the road's line) and everything else reaches over the
## road on its +Z side: the pivot post and counterweight, the striped boom
## across to a rest post on the far verge, cast blocks set on both verges to
## narrow the way. The booth has a visor slit on three faces with an amber lens
## watching the road, a floodlight on a mast leaning out over the boom, a
## beacon. Snow drifts against the booth's back and the posts in the snowfield.
## 1: the boom snapped, its end on the road, the lens and beacon dark; the
## flood still burns over the broken gate, knocked askew.
static func checkpoint(k: Kit, v: int, c: int) -> void:
	var s := 31300 + v + c
	var alive := v % 2 == 0
	var d := BiomeDressing.of(c)
	var cold := d.cold()
	# The pad and the booth.
	k.chamfer(0.0, -0.12, 0.0, 1.5, 0.16, 1.35, 0.18, P.STONE[2], P.STONE[3])
	k.chamfer(0.0, 0.02, 0.0, 1.1, 1.72, 1.0, 0.16, P.PLATE[2], P.PLATE[3])
	k.chamfer(0.0, 1.74, 0.0, 1.32, 0.14, 1.22, 0.16, P.PLATE[1], P.PLATE[2])
	k.chamfer(0.0, 1.88, 0.0, 0.8, 0.1, 0.7, 0.1, P.PLATE[2], P.PLATE[3])
	# The visor slit on the road face and both ends, the lens in the road face.
	var slit := P.COLD[1]
	var on := func(a: Vector3, b: Vector3, rise: float, out: Vector3, col: Color) -> void:
		Remains._facing_quad(k.found, a, b, Vector3(0, rise, 0), out, col)
	on.call(Vector3(0.36, 1.18, 0.501), Vector3(-0.36, 1.18, 0.501), 0.16, Vector3.BACK, P.PLATE[0])
	on.call(Vector3(0.33, 1.21, 0.504), Vector3(-0.33, 1.21, 0.504), 0.1, Vector3.BACK, slit)
	for sx: float in [0.551, -0.551]:
		var sg := signf(sx)
		on.call(Vector3(sx, 1.18, -0.3), Vector3(sx, 1.18, 0.3), 0.16, Vector3(sg, 0, 0), P.PLATE[0])
		on.call(Vector3(sx + 0.003 * sg, 1.21, -0.27), Vector3(sx + 0.003 * sg, 1.21, 0.27), 0.1, Vector3(sg, 0, 0), slit)
	k.found.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.16, 1.26, 0.505)))
	k.found.prism(0, 0, 0, 0.07, 0.025, 0.07, 8, lit(P.LENS[2], 0.8) if alive else P.PLATE[4])
	k.found.pop()
	# A hatch on the far end, a vent grille, rivets, rust in straight runs.
	on.call(Vector3(-0.552, 0.1, -0.22), Vector3(-0.552, 0.1, 0.22), 0.88, Vector3.LEFT, P.PLATE[1])
	for i in 4:
		on.call(Vector3(0.36, 0.2 + i * 0.1, 0.502), Vector3(-0.1, 0.2 + i * 0.1, 0.502), 0.04, Vector3.BACK, P.PLATE[0])
	rivets(k, Vector3(-0.42, 1.05, 0.502), Vector3(0.42, 1.05, 0.502), 7, Vector3(0, 0, 1))
	run(k, Vector3(0.2, 1.16, 0.503), 0.05, 0.6, Vector3(0, 0, 1))
	run(k, Vector3(-0.3, 1.7, 0.503), 0.035, 0.4, Vector3(0, 0, 1))
	k.found.prism(0, 1.98, 0, 0.07, 2.04, 0.07, 8, P.PLATE[1])
	k.found.prism(0, 2.04, 0, 0.05, 2.16, 0.04, 8, BEACON if alive else P.PLATE[4])
	# The floodlight: a mast off the booth's back corner, its head leaning out
	# over the boom and looking down at the road.
	k.rod(Vector3(-0.45, 1.88, -0.4), Vector3(-0.45, 3.1, -0.4), 0.035, 6, P.PLATE[3])
	k.rod(Vector3(-0.45, 3.0, -0.4), Vector3(-0.2, 3.12, 0.55), 0.025, 4, P.PLATE[3])
	# Its lamp face looks out over the road (+Z) and down, where the camera sees it.
	var head := Basis(Vector3.RIGHT, 0.12) if alive else Basis(Vector3.RIGHT, 0.3) * Basis(Vector3.BACK, 0.35)
	k.found.push(Transform3D(head, Vector3(-0.2, 3.02, 0.62)))
	k.chamfer(0.0, -0.14, 0.0, 0.5, 0.28, 0.2, 0.04, P.PLATE[1], P.PLATE[2])
	on.call(Vector3(0.21, -0.12, 0.12), Vector3(-0.21, -0.12, 0.12), 0.24, Vector3.BACK, lit(STRIP, 0.8))
	# The lamp's heat vent on top catches its light, so it reads from any side.
	k.found.quad(Vector3(-0.18, 0.16, -0.05), Vector3(-0.18, 0.16, 0.09), Vector3(0.18, 0.16, 0.09), Vector3(0.18, 0.16, -0.05), lit(STRIP, 0.8))
	k.found.pop()
	# The pivot post and its counterweight, the striped boom over the road.
	k.chamfer(0.0, -0.1, 0.85, 0.26, 1.12, 0.26, 0.06, P.PLATE[2], P.PLATE[3])
	k.chamfer(0.0, 0.84, 0.62, 0.3, 0.3, 0.34, 0.05, P.PLATE[1], P.PLATE[2])
	var reach := 4.5
	var stripes := 10
	if alive:
		for i in stripes:
			var z0 := 0.95 + i * (reach - 0.95) / stripes
			k.chamfer(0.0, 0.94, z0 + (reach - 0.95) / stripes * 0.5, 0.11, 0.11, (reach - 0.95) / stripes, 0.025, P.RIME[5] if i % 2 == 0 else P.RUST[3])
	else:
		k.found.push(Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(0.0, 1.0, 0.9)))
		for i in 4:
			var seg := (reach - 0.95) / stripes
			k.chamfer(0.0, -0.055, 0.05 + i * seg + seg * 0.5, 0.11, 0.11, seg, 0.025, P.RIME[5] if i % 2 == 0 else P.RUST[3])
		k.found.pop()
		k.found.push(Transform3D(Basis(Vector3.UP, 0.35), Vector3(0.25, 0.0, 2.6)))
		for i in 5:
			var seg := (reach - 0.95) / stripes
			k.chamfer(0.0, 0.0, i * seg, 0.11, 0.11, seg, 0.025, P.RIME[5] if (i + 4) % 2 == 0 else P.RUST[3])
		k.found.pop()
	# The rest post on the far verge, its fork waiting.
	k.chamfer(0.0, -0.1, reach + 0.12, 0.14, 1.0, 0.14, 0.04, P.PLATE[2], P.PLATE[3])
	for sx: float in [-0.08, 0.08]:
		k.rod(Vector3(sx, 0.88, reach + 0.12), Vector3(sx, 1.02, reach + 0.12), 0.015, 4, P.PLATE[3])
	# Cast blocks on both verges, narrowing the way.
	for b: Vector3 in [Vector3(1.55, 0.0, 1.0), Vector3(-1.5, 0.0, 1.05), Vector3(1.4, 0.0, reach - 0.3)]:
		k.chamfer(b.x, -0.08, b.z, 0.95, 0.24, 0.5, 0.08, P.STONE[3], P.STONE[3])
		k.chamfer(b.x, 0.16, b.z, 0.95, 0.3, 0.22, 0.06, P.STONE[3], P.STONE[4])
		for ch in 3:
			var x := b.x - 0.3 + ch * 0.3
			k.found.quad(Vector3(x - 0.05, 0.08, b.z + 0.252), Vector3(x + 0.05, 0.08, b.z + 0.252), Vector3(x + 0.1, 0.3, b.z + 0.112), Vector3(x, 0.3, b.z + 0.112), P.RUST[3])
	if cold:
		# Rime on the roof, icicles on the boom, snow drifted against the back
		# of the booth and the foot of every post.
		Remains.drift(k, Vector3(0.0, 1.98, 0.0), 0.42, 0.36, 0.1, 0.0, P.RIME[5], s + 1)
		if alive:
			for i in 10:
				var z := 1.1 + i * 0.33
				k.made.prism(0.0, 0.9 - 0.12 - (i % 3) * 0.05, z, 0.018, 0.9, 0.012, 4, P.RIME[4])
		Remains.drift(k, Vector3(-0.1, 0.0, -0.95), 1.3, 0.6, 0.55, PI, P.RIME[5], s + 2)
		Remains.drift(k, Vector3(-0.95, 0.0, 0.0), 0.8, 0.5, 0.42, PI * 0.5, P.RIME[5], s + 3)
		Remains.drift(k, Vector3(0.3, 0.0, reach + 0.6), 0.9, 0.45, 0.32, 0.2, P.RIME[5], s + 4)
		Remains.drift(k, Vector3(2.1, 0.0, 0.6), 0.7, 0.4, 0.26, 0.9, P.RIME[5], s + 5)
	else:
		footing(k, c, 0.8, s + 2)


## The tall stack: an exhaust of the works standing over the snowfield, seen
## from everywhere. Octagonal, banded, with ladder and platforms, warning
## beacons at two heights, a ducted housing at its foot. Rime banded up it.
static func stack(k: Kit, v: int, c: int) -> void:
	var d := BiomeDressing.of(c)
	var s := 31500 + v + c
	var h := 8.0
	k.chamfer(0.0, -0.1, 0.0, 2.2, 0.9, 2.2, 0.4, P.PLATE[1], P.PLATE[2])
	k.chamfer(1.2, -0.1, 0.0, 0.9, 0.6, 1.1, 0.15, P.PLATE[2], P.PLATE[3])
	var r0 := 0.78
	var r1 := 0.46
	var bands := 8
	for i in bands:
		var y0 := 0.8 + i * (h - 0.8) / bands
		var y1 := y0 + (h - 0.8) / bands
		var ra := lerpf(r0, r1, float(i) / bands)
		var rb := lerpf(r0, r1, float(i + 1) / bands)
		var col := P.PLATE[3] if i % 2 == 0 else P.PLATE[2]
		if d.cold() and i % 3 == 1:
			col = d.snow[1]
		k.found.prism(0, y0, 0, ra, y1, rb, 8, col, col, PI / 8.0)
		k.found.prism(0, y1 - 0.06, 0, rb + 0.03, y1, rb + 0.03, 8, P.PLATE[1], P.PLATE[1], PI / 8.0)
	# The mouth, black, a lip of soot.
	k.found.prism(0, h, 0, r1 + 0.04, h + 0.12, r1 + 0.04, 8, P.INK[2], P.INK[0], PI / 8.0)
	# Ladder up the lit face, cages every few rungs.
	for i in 22:
		var y := 0.9 + i * 0.32
		var rr := lerpf(r0, r1, (y - 0.8) / (h - 0.8)) + 0.1
		k.rod(Vector3(rr, y, -0.1), Vector3(rr, y, 0.1), 0.01, 3, P.PLATE[4])
	for yp: float in [3.4, 6.2]:
		var rr := lerpf(r0, r1, (yp - 0.8) / (h - 0.8))
		k.hoop(Vector3(0, yp, 0), rr + 0.3, 12, 0.02, P.PLATE[4])
		k.found.prism(0, yp - 0.04, 0, rr + 0.3, yp, rr + 0.3, 12, P.PLATE[1])
		for i in 4:
			var a := float(i) / 4.0 * TAU + PI * 0.25
			k.found.prism(cos(a) * (rr + 0.02), yp + 0.02, sin(a) * (rr + 0.02), 0.05, yp + 0.12, 0.04, 6, BEACON)
	run(k, Vector3(0.0, h - 0.2, r1 + 0.01), 0.1, 2.4, Vector3(0, 0, 1))
	run(k, Vector3(-0.3, h - 0.5, r1 + 0.02), 0.06, 1.6, Vector3(-0.3, 0, 1))
	k.found.quad(Vector3(1.651, 0.1, 0.2), Vector3(1.651, 0.1, -0.2), Vector3(1.651, 0.35, -0.2), Vector3(1.651, 0.35, 0.2), STRIP)
	if d.cold():
		Remains.banks(k, [[-1.2, -1.0, 0.9, 0.5], [1.0, -1.1, 0.8, 0.45], [-1.3, 0.9, 0.7, 0.4], [2.0, 0.7, 0.5, 0.3]], d.snow[0], s + 3)
		k.clump(0.0, 0.8, 0.0, 1.1, 0.14, s + 4, d.snow[0], 9)
	else:
		footing(k, c, 1.6, s + 3)


# --- the bonelands' grids ------------------------------------------------------

## A drill in its exact place on the grid. 0: a tripod derrick over the bore,
## a motor housing with the working amber; 1: a capped bore, a numbered plate
## flush with the pavement and a short standpipe.
static func drill_rig(k: Kit, v: int, c: int) -> void:
	var s := 31700 + v + c
	var dust := Remains.drift_of(c)
	if v % 2 == 0:
		k.found.prism(0, -0.02, 0, 0.42, 0.04, 0.42, 8, P.PLATE[1], P.PLATE[2], PI / 8.0)
		for i in 3:
			var a := float(i) / 3.0 * TAU + PI / 6.0
			k.rod(Vector3(cos(a) * 0.55, -0.05, sin(a) * 0.55), Vector3(0, 2.3, 0), 0.03, 4, P.PLATE[3])
			k.rod(Vector3(cos(a) * 0.35, 0.8, sin(a) * 0.35), Vector3(cos(a + TAU / 3.0) * 0.35, 0.8, sin(a + TAU / 3.0) * 0.35), 0.016, 4, P.PLATE[2])
		k.found.prism(0, 0.0, 0, 0.05, 2.2, 0.05, 6, P.PLATE[4])
		k.chamfer(0.0, 1.35, 0.0, 0.34, 0.42, 0.34, 0.06, P.PLATE[2], P.PLATE[3])
		k.found.quad(Vector3(0.171, 1.5, 0.08), Vector3(0.171, 1.5, -0.08), Vector3(0.171, 1.6, -0.08), Vector3(0.171, 1.6, 0.08), WORKING)
		k.found.prism(0, 2.3, 0, 0.06, 2.36, 0.06, 6, P.PLATE[1])
		k.hoop(Vector3(0, 2.25, 0), 0.14, 8, 0.012, P.PLATE[3])
		run(k, Vector3(0.0, 1.72, 0.171), 0.05, 0.3, Vector3(0, 0, 1))
		k.cable(Vector3(0.1, 1.4, 0.17), Vector3(0.9, 0.02, 0.5), 0.1, 5, 0.014, P.INK[2])
	else:
		k.found.prism(0, -0.02, 0, 0.36, 0.03, 0.36, 8, P.PLATE[2], P.PLATE[3], PI / 8.0)
		k.found.prism(0, 0.03, 0, 0.18, 0.05, 0.18, 8, P.INK[1], P.PLATE[1], PI / 8.0)
		for i in 8:
			var a := float(i) / 8.0 * TAU
			k.found.prism(cos(a) * 0.29, 0.03, sin(a) * 0.29, 0.02, 0.045, 0.02, 6, P.PLATE[5])
		k.found.prism(0.25, 0.03, 0.25, 0.04, 0.35, 0.04, 6, P.PLATE[3], P.PLATE[4])
		k.found.quad(Vector3(0.3, 0.1, 0.24), Vector3(0.3, 0.1, 0.26), Vector3(0.3, 0.28, 0.26), Vector3(0.3, 0.28, 0.24), P.COLD[3])
		for t in 3:
			k.found.quad(Vector3(-0.1 + t * 0.06, 0.0351, 0.28), Vector3(-0.08 + t * 0.06, 0.0351, 0.28), Vector3(-0.08 + t * 0.06, 0.0351, 0.2), Vector3(-0.1 + t * 0.06, 0.0351, 0.2), P.INK[1])
	# Cuttings round the bore: pale rock flour in a ring, MADE.
	for i in 7:
		var a := float(i) / 7.0 * TAU + 0.3
		k.stone(cos(a) * 0.62, -0.04, sin(a) * 0.62, 0.07, 0.05, s + i, dust[0] if i % 2 else dust[1], 4)


## A run of ore conveyor on its trestles, two and a half tiles to a piece:
## belt on rollers between rails, ore spilled under it. 1: its end dropped to
## the ground, the belt torn and hanging.
static func conveyor(k: Kit, v: int, c: int) -> void:
	var s := 31900 + v + c
	var h := 1.1
	var half := 1.25
	var fallen := v % 2 == 1
	var tip := Vector3(half, h, 0.0) if not fallen else Vector3(half, 0.1, 0.1)
	for sx: float in [-0.9, 0.3]:
		for sz: float in [-0.3, 0.3]:
			k.rod(Vector3(sx, -0.1, sz * 1.4), Vector3(sx, h - 0.05, sz), 0.028, 4, P.PLATE[2])
		k.rod(Vector3(sx, h * 0.45, -0.36), Vector3(sx, h * 0.45, 0.36), 0.018, 4, P.PLATE[1])
	var tail := Vector3(-half, h, 0.0)
	for sz: float in [-0.26, 0.26]:
		k.rod(tail + Vector3(0, 0, sz), tip + Vector3(0, 0, sz), 0.025, 4, P.PLATE[3])
	# The belt RIDES its rollers and sags between them. Laid flat, it was a sheet
	# wider than the rollers were long and the belt's own thickness above them,
	# so every roller on this conveyor was drawn from no bearing the play camera
	# can take. Riding them, each roller is a ruled bar across the belt where it
	# is highest, and its ends stand out past the belt's edge into the rails it
	# turns in — which is what a conveyor looks like.
	var n := 8
	var roll := 0.055
	var sag := 0.09
	for i in n + 1:
		var a := tail.lerp(tip, float(i) / n) + Vector3(0, -0.03, 0)
		k.rod(a + Vector3(0, 0, -0.3), a + Vector3(0, 0, 0.3), roll, 6, P.PLATE[4])
	for i in n:
		var a := tail.lerp(tip, float(i) / n) + Vector3(0, roll - 0.032, 0)
		var b := tail.lerp(tip, float(i + 1) / n) + Vector3(0, roll - 0.032, 0)
		var m := a.lerp(b, 0.5) - Vector3(0, sag, 0)
		var col: Color = P.INK[3] if i % 2 else P.STONE[1]
		k.found.quad(a + Vector3(0, 0, 0.22), m + Vector3(0, 0, 0.22), m + Vector3(0, 0, -0.22), a + Vector3(0, 0, -0.22), col)
		k.found.quad(m + Vector3(0, 0, 0.22), b + Vector3(0, 0, 0.22), b + Vector3(0, 0, -0.22), m + Vector3(0, 0, -0.22), col)
		if not fallen or i < n - 2:
			# Ore rides in the sag, which is where it would gather.
			k.stone(m.x, m.y - 0.01, Kit.j(s, i, 0.12), 0.08, 0.07, s + i, P.RUST[3] if i % 2 else P.STONE[2], 4)
	if fallen:
		k.found.quad(Vector3(half - 0.2, 0.3, -0.2), Vector3(half - 0.2, 0.3, 0.2), Vector3(half - 0.1, -0.05, 0.25), Vector3(half - 0.3, -0.05, -0.2), P.INK[2])
	for i in 6:
		var x := -1.0 + i * 0.4
		k.stone(x, -0.04, Kit.j(s, 20 + i, 0.3), 0.1, 0.07, s + 20 + i, P.RUST[3] if i % 2 else P.STONE[3], 5)
	run(k, Vector3(-0.9, h - 0.08, 0.31), 0.03, 0.6, Vector3(0, 0, 1))


## A survey marker the machines set to lay out their grid: an exact post with
## banded cap and a tag. 1: a tripod beacon with a cold lens, where two lines meet.
static func survey(k: Kit, v: int, c: int) -> void:
	var s := 32100 + v + c
	if v % 2 == 0:
		k.found.prism(0, -0.1, 0, 0.035, 0.7, 0.035, 4, P.PLATE[4], P.PLATE[4], PI * 0.25)
		k.found.prism(0, 0.5, 0, 0.037, 0.58, 0.037, 4, P.RUST[3], P.RUST[3], PI * 0.25)
		k.found.prism(0, 0.62, 0, 0.037, 0.7, 0.037, 4, P.RUST[3], P.COLD[3], PI * 0.25)
		k.found.quad(Vector3(0.036, 0.3, 0.05), Vector3(0.036, 0.3, -0.05), Vector3(0.036, 0.42, -0.05), Vector3(0.036, 0.42, 0.05), P.PLATE[1])
	else:
		for i in 3:
			var a := float(i) / 3.0 * TAU
			k.rod(Vector3(cos(a) * 0.3, -0.05, sin(a) * 0.3), Vector3(0, 1.0, 0), 0.016, 4, P.PLATE[3])
		k.found.prism(0, 1.0, 0, 0.08, 1.12, 0.08, 8, P.PLATE[2], P.PLATE[3])
		k.found.prism(0, 1.12, 0, 0.05, 1.2, 0.04, 8, lit(P.COLD[3], 0.9))
	var d := BiomeDressing.of(c)
	if d.cold():
		Remains.banks(k, [[0.05, 0.05, 0.18, 0.12]], d.snow[0], s)


# --- the burning ---------------------------------------------------------------

## A vent the machines bolted shut: an exact domed cap on a flange of bolts,
## a gauge with its needle, a relief stub; the heat still finds the seam.
static func vent_cap(k: Kit, v: int, c: int) -> void:
	var s := 32300 + v + c
	k.stone(0, -0.08, 0, 0.75, 0.3, s, P.STONE[1], 9, 0.0, P.RUST[1])
	k.found.prism(0, 0.12, 0, 0.5, 0.2, 0.5, 12, P.PLATE[1], P.PLATE[2])
	k.found.prism(0, 0.2, 0, 0.44, 0.38, 0.3, 12, P.PLATE[2], P.PLATE[3])
	k.found.prism(0, 0.38, 0, 0.3, 0.46, 0.0, 12, P.PLATE[3])
	for i in 12:
		var a := float(i) / 12.0 * TAU + PI / 12.0
		k.found.prism(cos(a) * 0.46, 0.2, sin(a) * 0.46, 0.025, 0.25, 0.025, 6, P.PLATE[5])
	# The heat at the seam under the flange: drawn, glowing.
	k.made.prism(0, 0.1, 0, 0.52, 0.12, 0.52, 12, GroundColors.glow(P.EMBER[3], 0.9), GroundColors.glow(P.EMBER[3], 0.9))
	k.chamfer(0.36, 0.2, 0.3, 0.12, 0.3, 0.08, 0.02, P.PLATE[2], P.PLATE[3])
	k.found.prism(0.36, 0.42, 0.34, 0.06, 0.43, 0.06, 10, P.RIME[5])
	k.found.quad(Vector3(0.36, 0.425, 0.341), Vector3(0.38, 0.425, 0.341), Vector3(0.41, 0.445, 0.341), Vector3(0.39, 0.445, 0.341), lit(P.LENS[2], 0.86))
	k.rod(Vector3(-0.2, 0.4, -0.1), Vector3(-0.2, 0.62, -0.1), 0.035, 6, P.PLATE[2])
	k.found.prism(-0.2, 0.62, -0.1, 0.05, 0.66, 0.05, 6, P.PLATE[1], P.INK[0])
	if v % 2 == 1:
		# This one weeps: a crack in the cap, a crust of sulphur round it.
		k.made.quad(Vector3(-0.1, 0.39, 0.2), Vector3(0.15, 0.36, 0.26), Vector3(0.16, 0.37, 0.24), Vector3(-0.1, 0.4, 0.18), GroundColors.glow(P.EMBER[4], 1.2))
		for i in 5:
			var a := float(i) * 1.1
			var p := Vector3(cos(a) * 0.56, 0.1, sin(a) * 0.56)
			k.fleck(p, p + Vector3(0.07, 0.0, 0.02), p + Vector3(0.02, 0.03, 0.06), P.SAND[5])
	Remains.banks(k, [[-0.7, 0.3, 0.3, 0.1]], Remains.drift_of(c)[0], s + 3)


## The clerks' archive in the ash: exact cabinets in a row, drawers ruled,
## one pulled out and its ruled paper spilled and burnt. 1: a cabinet toppled
## on its face and a fan of burnt paper blown out from it.
static func archive(k: Kit, v: int, c: int) -> void:
	var s := 32500 + v + c
	var paper := P.LINEN[4]
	var burnt := P.EARTH[1].lerp(P.INK[2], 0.4)
	if v % 2 == 0:
		for i in 3:
			var z := -0.6 + i * 0.6
			k.chamfer(0.0, -0.05, z, 0.6, 1.5, 0.56, 0.05, P.PLATE[2] if i != 1 else P.PLATE[3], P.PLATE[3])
			for d in 4:
				var y := 0.1 + d * 0.35
				k.found.quad(Vector3(0.301, y, z + 0.24), Vector3(0.301, y, z - 0.24), Vector3(0.301, y + 0.3, z - 0.24), Vector3(0.301, y + 0.3, z + 0.24), P.PLATE[1])
				k.found.quad(Vector3(0.303, y + 0.2, z + 0.06), Vector3(0.303, y + 0.2, z - 0.06), Vector3(0.303, y + 0.23, z - 0.06), Vector3(0.303, y + 0.23, z + 0.06), P.PLATE[5])
			run(k, Vector3(0.302, 1.4, z + 0.1), 0.03, 0.8, Vector3(1, 0, 0))
		# A drawer pulled out and hanging, paper spilling.
		k.chamfer(0.5, 0.8, 0.0, 0.42, 0.26, 0.46, 0.02, P.PLATE[3], P.PLATE[1])
		for i in 6:
			var p := Vector3(0.55 + i * 0.15, 0.02 + (0.5 - i * 0.1 if i < 4 else 0.0), Kit.j(s, i, 0.35))
			_leaf(k, p, 0.12, Kit.j(s, i + 10, 1.5), paper if i % 3 else burnt, s + i)
	else:
		k.found.push(Transform3D(Basis(Vector3.BACK, -PI * 0.5 + 0.1), Vector3(0.1, 0.3, 0.0)))
		k.chamfer(0.0, 0.0, 0.0, 0.6, 1.5, 0.56, 0.05, P.PLATE[2], P.PLATE[3])
		k.found.pop()
		k.chamfer(-0.9, -0.05, -0.2, 0.6, 1.5, 0.56, 0.05, P.PLATE[3], P.PLATE[4])
		for d in 4:
			var y := 0.1 + d * 0.35
			k.found.quad(Vector3(-0.599, y, 0.04), Vector3(-0.599, y, -0.44), Vector3(-0.599, y + 0.3, -0.44), Vector3(-0.599, y + 0.3, 0.04), P.PLATE[1] if d != 2 else P.INK[0])
		for i in 14:
			var a := -0.7 + Kit.j(s, i, 0.7)
			var r := 0.5 + fmod(i * 0.23, 1.2)
			_leaf(k, Vector3(0.3 + cos(a) * r, 0.02, sin(a) * r), 0.13, Kit.j(s, i + 20, 1.6), burnt if i % 3 == 0 else paper, s + 30 + i)
	Remains.banks(k, [[-0.3, 0.9, 0.5, 0.2], [0.4, -1.0, 0.45, 0.16]], Remains.drift_of(c)[0], s + 50)


## A leaf of ruled paper lying on the ground: pale, lines ruled across it,
## its edge burnt dark. MADE: it is ash and weather now.
static func _leaf(k: Kit, at: Vector3, size: float, ang: float, col: Color, s: int) -> void:
	var u := Vector3(cos(ang), 0, sin(ang)) * size
	var w := Vector3(-sin(ang), 0, cos(ang)) * size * 0.72
	var y := Vector3(0, 0.01, 0)
	k.made.quad(at - u + w + y, at + u + w + y, at + u - w + y, at - u - w + y, P.EARTH[1].lerp(P.INK[2], 0.3))
	k.made.quad(at - u * 0.8 + w * 0.8 + y * 1.3, at + u * 0.8 + w * 0.75 + y * 1.3, at + u * 0.7 - w * 0.8 + y * 1.3, at - u * 0.85 - w * 0.8 + y * 1.3, col)
	for r in 3:
		var t := -0.45 + r * 0.4
		k.made.quad(at - u * 0.7 + w * (t + 0.08) + y * 1.6, at + u * 0.6 + w * (t + 0.08) + y * 1.6, at + u * 0.6 + w * t + y * 1.6, at - u * 0.7 + w * t + y * 1.6, P.RIME[3])
