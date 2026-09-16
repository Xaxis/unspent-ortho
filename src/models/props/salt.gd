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

## The machines' cold strip and the salt's own light.
const STRIP := Color(0.3, 0.95, 1.0, 0.8)
const CRUST := Color(0.9098, 0.8627, 0.7529)
const CRUST_DOWN := Color(0.7529, 0.7020, 0.5804)
const STAIN := Color(0.4314, 0.2000, 0.1255)


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.SALT_RIDGE: ridge(k, v)
		PropKind.SALT_HEAP: heap(k, v)
		PropKind.PAN_GATE: gate(k, v)


## A pressure ridge in the crust: plates that met, buckled and tipped, standing
## in a low wall along the line where they hit. It has to read at 640x360, so
## the wall is continuous and its shadow side is dark: a white tick with a cut
## under it, never a row of dashes.
static func ridge(k: Kit, v: int) -> void:
	var s := 400 + v * 17
	var run := 1.9 + v * 0.5
	var along := Vector3(1, 0, 0.14 + Kit.j(s, 1, 0.22)).normalized()
	var across := Vector3(-along.z, 0, along.x)
	var plates := 5 + v
	var step := run / plates
	for i in plates:
		var t := (float(i) - plates * 0.5 + 0.5) * step
		var lean := Kit.j(s, i * 4, 0.35)
		var rise := 0.22 + absf(Kit.j(s, i * 4 + 1, 0.16))
		var base := along * t + across * Kit.j(s, i * 4 + 2, 0.06)
		# Each plate is a slab of crust stood on edge, overlapping its neighbour
		# so the line never breaks.
		var half := step * 0.72
		var a := base - along * half
		var b := base + along * half
		var up := Vector3(0, rise, 0) + across * lean * 0.22
		var pale := CRUST if i % 3 != 1 else P.LINEN[4]
		# The lit face, the shaded back, and the dark cut at its foot.
		k.made.quad(a, b, b + up, a + up, pale)
		k.made.quad(b - across * 0.07, a - across * 0.07, a + up - across * 0.05, b + up - across * 0.05, CRUST_DOWN)
		k.made.quad(a + up, b + up, b + up + across * 0.06 - Vector3(0, 0.02, 0), a + up + across * 0.06 - Vector3(0, 0.02, 0), P.LINEN[5])
		k.made.quad(a - across * 0.07, b - across * 0.07, b - across * 0.2, a - across * 0.2,
			STAIN.lerp(P.LINEN[2], 0.4) if i % 2 == 0 else P.LINEN[2])
	# Slabs that broke off and fell against the wall, on the sunny side.
	for i in 3:
		var t := (float(i) / 3.0 - 0.35) * run
		var at := along * t + across * 0.22
		k.made.push(Transform3D(Basis(Vector3.UP, along.angle_to(Vector3.RIGHT) + Kit.j(s, 40 + i, 0.6)) * Basis(Vector3.RIGHT, 1.1), at))
		k.made.prism(0, 0, 0, 0.13 + Kit.j(s, 50 + i, 0.03), 0.02, 0.1, 5, P.LINEN[4], CRUST)
		k.made.pop()


## A heap the pan rakers built and never came back for: a raked cone of salt
## taller than a person, a sheet weighted down over one flank, and the rake
## left standing in it. Its silhouette is the point: a white cone with one dark
## shoulder and a stick against the sky.
static func heap(k: Kit, v: int) -> void:
	var s := 430 + v * 23
	var r := 0.5 + v * 0.1
	var h := 0.95 + v * 0.2
	# Faceted and leaning, so a heap is a heap and not a tent.
	k.stone(0, 0, 0, r, h, s, CRUST, 7, 0.14, P.LINEN[5])
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
	k.made.prism(0, 0, 0, (w - 0.08) * 0.5, 0.05, 0.035, 4, CRUST, P.LINEN[4])
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
