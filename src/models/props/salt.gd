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


## A pressure ridge in the crust: plates that met, buckled and tipped, one lip
## standing over the other with the dark pan showing in the gap.
static func ridge(k: Kit, v: int) -> void:
	var s := 400 + v * 17
	var run := 1.5 + v * 0.35
	var along := Vector3(1, 0, 0.1 + Kit.j(s, 1, 0.2)).normalized()
	var across := Vector3(-along.z, 0, along.x)
	var plates := 4 + v
	for i in plates:
		var t := (float(i) / plates - 0.5) * run
		var base := along * t + across * Kit.j(s, i * 3, 0.1)
		var rise := 0.1 + absf(Kit.j(s, i * 3 + 1, 0.12))
		var tip := Kit.j(s, i * 3 + 2, 0.5)
		# Each plate is a quad tipped up on the ridge line: no two the same.
		var w := 0.26 + absf(Kit.j(s, i * 3 + 3, 0.1))
		var a := base - across * w * 0.5
		var b := base + across * w * 0.5
		var lift := Vector3(0, rise, 0) + across * tip * 0.1
		var pale := CRUST if i % 3 != 1 else P.LINEN[4]
		k.made.quad(a, b, b + lift + along * 0.12, a + lift + along * 0.1, pale)
		# Its shaded underside, and the stained pan showing beneath.
		k.made.quad(a, a + lift + along * 0.1, a + lift + along * 0.1 - across * 0.06, a - across * 0.05, CRUST_DOWN)
		if i % 2 == 0:
			k.made.quad(a - across * 0.05, a - across * 0.16, b - across * 0.16, b - across * 0.05, STAIN.lerp(P.LINEN[2], 0.45))
	# A few grains thrown up along the line, catching the light.
	for i in 3:
		var t := (float(i) / 3.0 - 0.4) * run
		k.fleck(along * t + Vector3(0, 0.02, 0), along * t + Vector3(0.05, 0.05, 0.02),
			along * t + Vector3(0.02, 0.06, 0.04), P.LINEN[5])


## A heap the pan rakers built and never came back for: a raked cone of salt,
## a sheet weighted down over half of it, and the rake standing in it.
static func heap(k: Kit, v: int) -> void:
	var s := 430 + v * 23
	var r := 0.55 + v * 0.12
	var h := 0.5 + v * 0.1
	k.clump(0, 0, 0, r, h, s, CRUST)
	# Rake lines still in its flank: the cone was worked, not tipped.
	for i in 7:
		var a := float(i) / 7.0 * TAU + Kit.j(s, i, 0.2)
		var foot := Vector3(cos(a) * r * 0.95, 0.02, sin(a) * r * 0.95)
		k.fleck(foot, foot * 0.35 + Vector3(0, h * 0.85, 0), foot * 0.4 + Vector3(0.03, h * 0.8, 0.02), CRUST_DOWN)
	# The sheet: a sagging tarpaulin over one side, weighted with stones.
	var sheet := P.SLATE[3].lerp(P.RUST[2], 0.25)
	var lip := Vector3(-r * 1.05, 0.03, -r * 0.5)
	var lip2 := Vector3(-r * 0.9, 0.03, r * 0.75)
	var top := Vector3(0.05, h * 0.92, 0.0)
	k.made.quad(lip, lip2, top + Vector3(0.1, -0.06, 0.18), top + Vector3(0.0, 0.0, -0.2), sheet)
	k.made.quad(lip, top + Vector3(0.0, 0.0, -0.2), top + Vector3(-0.12, -0.1, -0.3), lip + Vector3(0.06, -0.02, -0.18), Kit.tone(sheet, 0.8))
	for i in 3:
		var p := lip.lerp(lip2, (i + 0.5) / 3.0) + Vector3(-0.04, 0.0, 0.0)
		k.stone(p.x, 0.0, p.z, 0.08, 0.07, s + i * 5, P.STONE[2], 5, 0.2)
	# The rake: a MADE haft, a FOUND head cut off something else.
	var haft_a := Vector3(r * 0.5, 0.0, r * 0.35)
	var haft_b := haft_a + Vector3(-0.22, 1.05, -0.1)
	k.limb(haft_a, haft_b, 0.022, 0.016, 5, P.EARTH[3])
	k.found.push(Transform3D(Basis(Vector3.UP, 0.6), haft_a + Vector3(0.0, 0.03, 0.0)))
	k.chamfer(0, 0, 0, 0.34, 0.035, 0.05, 0.012, P.PLATE[3], P.PLATE[4])
	for i in 5:
		k.chamfer(-0.13 + i * 0.065, -0.07, 0.0, 0.016, 0.075, 0.016, 0.004, P.PLATE[2])
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
