extends RefCounted
## What stands on the Salt Flats. The crust is the hand's work: pale, buckled,
## lifting at every join, drawn with the same pen as turf. What the machines put
## on it is the ruler's: the bunds of the evaporation pans, their sluice gates,
## and the rakes still going round. Between them, what people took and could not
## carry: a heap of salt under a weighted sheet, going nowhere.
##
## Nothing here is a cube. Crust is a plate that broke and tipped; a heap is a
## cone with a sheet sagging over it; a gate is a ruled frame with a screw.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")

## The machines' cold strip and the salt's own light.
##
## The crust stops short of the page, and so does everything cut from it. A
## frame that holds two landscapes lifts every wash in it by the average of
## their grades (src/content/biomes/salt_flats.gd, Ground.SALT), so a salt heap
## drawn at LINEN[5] stood on coast turf as a flat white blob with no facets,
## no rake lines and no shadow in it (art review 1). CRUST is the crust wash
## itself, CRUST_UP the one lit edge, and nothing here goes above it.
## The machines' own light is written ONCE, in `props/works.gd`, and read by the
## geometry, the pool, the glint and the fog shaft alike (CLAUDE.md, Palette).
## This declared its own instead: a bright cyan at hue 184, where every other
## strip in the game is `Works.STRIP` at 246 -- inside the violet band the
## machine ramps are packed into, which runs 240 to 336. It reached two places,
## the chamfer that draws the strip and the `glow_points` entry 15_lights hangs a
## pool on, so a pan gate lit the crust round it a colour nothing else in the
## world lights anything.
const STRIP := Works.STRIP
## The crust as a THING, which sits lower than the crust as GROUND: a prop's
## lit top face gets the full sun band with no shade step and no ground mark
## under it, so the same value that draws as crust at 215 draws on a salt heap
## at the page. Measured, not guessed (art review 1).
const CRUST := Color(0.4870, 0.4620, 0.4030)
const CRUST_DOWN := Color(0.3900, 0.3640, 0.3010)
## The one lit edge, and the ceiling on everything cut from the crust.
## It stops below the page on purpose — a glare landscape adds its own lift on
## top of the grade (sky.gdshaderinc, sky_air.y), and a lit rim at the page is a
## white line with nothing drawn in it.
const CRUST_UP := Color(0.5250, 0.4980, 0.4350)
const STAIN := Color(0.4314, 0.2000, 0.1255)


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.SALT_RIDGE: ridge(k, v)
		PropKind.SALT_HEAP: heap(k, v)
		PropKind.PAN_GATE: gate(k, v)


## A PRESSURE RIDGE: where the crust grew faster than there was room for it and
## the polygons shoved up against each other into a tent. Two plates of crust
## leaning together along a crack, knee to thigh high, their undersides the
## brown the brine left in them, a rim of fresh crystal along the crest where
## the brine still wicks up, and gaps where the tent fell in. At eye level it is
## a low jagged wall to step over; from above, a line with a shadow on one side.
static func ridge(k: Kit, v: int) -> void:
	var s := 400 + v * 17
	var run := 2.2 + v * 0.6
	var along := Vector3(1, 0, 0.14 + Kit.j(s, 1, 0.22)).normalized()
	var across := Vector3(-along.z, 0, along.x)
	var tents := 4 + v
	var step := run / tents
	var under := CRUST_DOWN.lerp(STAIN, 0.45).darkened(0.25)
	var rim := CRUST_UP
	# FROM ABOVE A RIDGE IS A LINE. Its tents are a hand wide each and their lit
	# faces are the crust's own value, so seen from the play camera they were a
	# few dark flecks. Under the whole run lies the crack it grew along: a dark
	# wet band where the brine comes up, wider on the shaded side, and on the
	# lit side a pale rim of fresh crystal wicked out of it. Dark line, pale
	# edge: a ridge reads as a ruled stroke across the plain.
	var ends := along * (run * 0.5 + 0.12)
	var wet := STAIN.lerp(CRUST_DOWN, 0.45).darkened(0.3)
	_flat(k, -ends + across * 0.06, ends + across * 0.06, ends - across * 0.5, -ends - across * 0.42, 0.012, wet)
	_flat(k, ends + across * 0.06, -ends + across * 0.06, -ends + across * 0.3, ends + across * 0.26, 0.014, CRUST_UP)
	for i in tents:
		var t := (float(i) - tents * 0.5 + 0.5) * step
		# A fallen tent: the plates lie flat and broken where it gave way.
		if Rng.hash01(s, i, 5) < 0.18:
			var at := along * t
			k.made.push(Transform3D(Basis(Vector3.UP, along.angle_to(Vector3.RIGHT) + Kit.j(s, 60 + i, 0.5)), at))
			k.made.prism(0, 0, 0, step * 0.45, 0.05, step * 0.4, 5, CRUST_DOWN, CRUST)
			k.made.pop()
			continue
		var rise := 0.22 + Rng.hash01(s, i, 1) * 0.34
		var spread := 0.1 + Rng.hash01(s, i, 2) * 0.12
		var half := step * (0.5 + Rng.hash01(s, i, 3) * 0.14)
		var mid := along * t + across * Kit.j(s, i * 4 + 2, 0.05)
		var a := mid - along * half
		var b := mid + along * half
		var c := mid + along * Kit.j(s, i * 4 + 4, half * 0.4)
		# A broken crest: each plate snapped at its own height, so the top is a
		# jag of three points and never a roof line.
		var lean := across * Kit.j(s, i * 4 + 3, 0.05)
		var ca := a + Vector3(0, rise * (0.45 + Rng.hash01(s, i, 11) * 0.4), 0) + lean + along * 0.05
		var cc := c + Vector3(0, rise, 0) + lean
		var cb := b + Vector3(0, rise * (0.35 + Rng.hash01(s, i, 12) * 0.5), 0) + lean - along * 0.05
		var crest := Vector3(0, rise, 0) + lean
		for side: float in [-1.0, 1.0]:
			var off := across * spread * side
			var fa := a + off + along * Kit.j(s, i * 4 + 6 + int(side), 0.06)
			var fb := b + off
			var fc := c + off * 1.15
			# A tipped plate shows the side that grew under the brine: the one
			# facing away is its stained underside, dark from above and at eye
			# level alike, so a ridge never sinks into the crust round it.
			var face := CRUST_UP if side > 0.0 else under
			var back := across * 0.03 * side
			if side > 0.0:
				k.made.quad(fa, fc, cc, ca, face)
				k.made.quad(fc, fb, cb, cc, GroundColors.down(face, 0.08))
				k.made.quad(fc - back, fa - back, ca - back * 0.6, cc - back * 0.6, under)
				k.made.quad(fb - back, fc - back, cc - back * 0.6, cb - back * 0.6, under)
			else:
				k.made.quad(fc, fa, ca, cc, face)
				k.made.quad(fb, fc, cc, cb, GroundColors.down(face, 0.08))
				k.made.quad(fa - back, fc - back, cc - back * 0.6, ca - back * 0.6, under)
				k.made.quad(fc - back, fb - back, cb - back * 0.6, cc - back * 0.6, under)
		# The crest: fresh crystal wicked up along it, a row of pale teeth.
		for q in 3:
			var at := [ca, cc, cb][q] as Vector3
			var th := 0.05 + Rng.hash01(s, i * 4 + q, 9) * 0.06
			k.made.prism(at.x, at.y - 0.02, at.z, 0.045, at.y + th, 0.0, 5, rim, rim)
		# The brine seep at the shaded foot: a dark wet line.
		k.made.quad(a - across * (spread + 0.02), b - across * (spread + 0.02), b - across * (spread + 0.42), a - across * (spread + 0.34), STAIN.lerp(CRUST_DOWN, 0.5).darkened(0.2))


## A quad lying on the ground at `y`, wound to face up whatever order its
## corners come in: a flat piece drawn face-down is not drawn at all.
static func _flat(k: Kit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, y: float, col: Color) -> void:
	var lift := Vector3(0, y, 0)
	a += lift
	b += lift
	c += lift
	d += lift
	# MeshKit.tri's normal is (c - b) x (a - b); up when that points up.
	if (c - b).cross(a - b).y < 0.0:
		k.made.quad(d, c, b, a, col)
	else:
		k.made.quad(a, b, c, d, col)


## A heap the pan rakers built and never came back for: a raked cone of salt
## taller than a person, a sheet weighted down over one flank, and the rake
## left standing in it. Its silhouette is the point: a white cone with one dark
## shoulder and a stick against the sky.
static func heap(k: Kit, v: int) -> void:
	var s := 430 + v * 23
	var r := 0.5 + v * 0.1
	var h := 0.95 + v * 0.2
	# Faceted and leaning, so a heap is a heap and not a tent.
	k.stone(0, 0, 0, r, h, s, CRUST, 7, 0.14, CRUST_UP)
	# Rake lines down its flank: the cone was worked, not tipped.
	for i in 8:
		var a := float(i) / 8.0 * TAU + Kit.j(s, i, 0.2)
		var foot := Vector3(cos(a) * r * 0.94, 0.02, sin(a) * r * 0.94)
		k.fleck(foot, foot * 0.2 + Vector3(0, h * 0.9, 0), foot * 0.3 + Vector3(0.04, h * 0.78, 0.03),
			CRUST_DOWN if i % 2 == 0 else P.LINEN[3])
	# The sheet: a tarpaulin thrown over one flank, sagging between its weights,
	# dark against the salt so the heap has a shoulder.
	var sheet := P.SLATE[2].lerp(P.RUST[1], 0.3)
	var top := Vector3(-0.04, h * 0.99, -0.02)
	var hem_a := Vector3(-r * 1.3, 0.04, -r * 1.15)
	var hem_b := Vector3(-r * 0.55, 0.04, r * 1.3)
	var mid := (hem_a + hem_b) * 0.5 + Vector3(-0.2, -0.05, 0.0)
	k.made.quad(hem_a, mid, top + Vector3(0.0, -0.06, -0.06), top + Vector3(-0.04, 0.02, -0.3), sheet)
	k.made.quad(mid, hem_b, top + Vector3(0.06, 0.02, 0.3), top + Vector3(0.0, -0.06, 0.06), Kit.tone(sheet, 0.88))
	# Its hem, curled up off the crust where the wind gets under it.
	k.made.quad(hem_a, hem_b, hem_b + Vector3(0.02, 0.07, 0.04), hem_a + Vector3(0.04, 0.05, -0.02), Kit.tone(sheet, 0.65))
	for i in 3:
		var p := hem_a.lerp(hem_b, (i + 0.5) / 3.0) + Vector3(-0.05, 0.0, 0.0)
		k.stone(p.x, 0.0, p.z, 0.09, 0.08, s + i * 5, P.STONE[2], 5, 0.25)
	# The rake: a MADE haft leaning out of the heap, a FOUND head cut off
	# something else and bolted to it.
	var haft_a := Vector3(r * 0.86, 0.06, r * 0.5)
	var haft_b := haft_a + Vector3(0.36, h + 0.55, 0.18)
	k.limb(haft_a, haft_b, 0.026, 0.018, 5, P.EARTH[3])
	k.found.push(Transform3D(Basis(Vector3.UP, -0.5) * Basis(Vector3.BACK, 0.35), haft_a + Vector3(-0.02, -0.02, -0.01)))
	k.chamfer(0, 0, 0, 0.4, 0.04, 0.06, 0.014, P.PLATE[3], P.PLATE[4])
	for i in 5:
		k.chamfer(-0.15 + i * 0.075, -0.1, 0.0, 0.018, 0.1, 0.018, 0.005, P.PLATE[2])
	k.found.pop()


## A sluice gate in the bund between two pans: the ruler's work, still holding
## back nothing. A screw stem, a cold strip that still reads, and the sandbags
## somebody stacked against it when the brine went the wrong way.
static func gate(k: Kit, v: int) -> void:
	var w := 0.85 + v * 0.2
	# The frame: two posts and a head beam, chamfered and riveted.
	for side: float in [-1.0, 1.0]:
		k.chamfer(side * w * 0.5, 0.0, 0.0, 0.09, 1.25, 0.11, 0.02, P.PLATE[3], P.PLATE[4])
	k.chamfer(0, 1.25, 0.0, w + 0.1, 0.1, 0.13, 0.025, P.PLATE[4], P.PLATE[5])
	# The gate leaf, dropped part way, its lower edge crusted white.
	var drop := 0.42 + v * 0.1
	k.chamfer(0, drop, 0.0, w - 0.08, 0.5, 0.05, 0.012, P.PLATE[2], P.PLATE[3])
	k.made.push(Transform3D(Basis.IDENTITY, Vector3(0, drop - 0.24, 0)))
	k.made.prism(0, 0, 0, (w - 0.08) * 0.5, 0.05, 0.035, 4, CRUST, CRUST_UP)
	k.made.pop()
	# The screw stem and its handwheel, the one thing anybody still turns.
	k.chamfer(0, 1.3, 0.0, 0.05, 0.42, 0.05, 0.012, P.PLATE[4])
	for i in 9:
		k.chamfer(0, 1.34 + i * 0.043, 0.0, 0.075, 0.012, 0.075, 0.004, P.PLATE[3])
	k.hoop(Vector3(0, 1.74, 0), 0.17, 10, 0.017, P.PLATE[5])
	for i in 3:
		var a := float(i) / 3.0 * TAU
		k.found.push(Transform3D(Basis(Vector3.UP, a), Vector3(0, 1.74, 0)))
		k.chamfer(0.085, 0, 0, 0.17, 0.015, 0.015, 0.004, P.PLATE[4])
		k.found.pop()
	# One cold strip down a post: the machines' order, lighting itself.
	if v == 0:
		k.chamfer(-w * 0.5 + 0.05, 0.35, 0.056, 0.012, 0.55, 0.012, 0.0, STRIP)
	# Sandbags at the foot, by hand, sagging and patched.
	for i in 4:
		var s := 470 + i * 13 + v * 5
		var bx := -w * 0.4 + i * (w * 0.27)
		k.made.push(Transform3D(Basis(Vector3.UP, Kit.j(s, 1, 0.3)), Vector3(bx, 0.0, 0.22 + Kit.j(s, 2, 0.05))))
		k.made.prism(0, 0, 0, 0.13 + Kit.j(s, 3, 0.02), 0.11, 0.09, 5, P.SAND[3], P.SAND[4])
		k.made.pop()
	for i in 2:
		var s := 480 + i * 9
		k.made.push(Transform3D(Basis(Vector3.UP, 0.4 + Kit.j(s, 1, 0.4)), Vector3(-w * 0.25 + i * w * 0.5, 0.11, 0.2)))
		k.made.prism(0, 0, 0, 0.12, 0.1, 0.085, 5, P.SAND[2], P.SAND[3])
		k.made.pop()


static func glow_points(kind: int, v: int) -> Array:
	if kind == PropKind.PAN_GATE and v == 0:
		return [{"at": Vector3(-0.375, 0.62, 0.056), "size": Vector2(0.012, 0.55), "color": STRIP, "blink": false}]
	return []
