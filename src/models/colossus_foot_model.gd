extends RefCounted
## THE NEAR FOOT OF A COLOSSUS (L0): what a person standing in its tread sees
## over them. Honest size -- the ankle block is three hundred metres across and
## stands its own height clear of the ground, and the three toes arch down to
## pads forty metres wide -- in ordinary FOUND plate on found.gdshader, lit by
## the renderer and worn by the land it stands in, like any other machine.
##
## Built as separate MeshKits, each one surface (`PARTS`), because it is built on
## a worker when a foot comes near and handed to the renderer a surface a frame
## (src/render/colossus/colossus_foot.gd): the ankle, the three toes, and the
## stub of the shin up to `SEAM`, where the far body (colossus.gdshader) takes
## over. The stub is its own node on the shin's bone, because a planted foot
## stands still while the shin above it swings with the hub.
##
## THE FRAME, as colossus_model.gd's foot bone: origin at the ankle, +Y up, toes
## at 0, 120 and 240 degrees round local +X; the pads' soles lie on y = -ankle_up.
## The stub's frame has its origin at the ankle too, +Y up the shin.
##
## THE SEAM MATCHES THE FAR BODY: the stub's radius is the shin profile of
## colossus_model.gd `_leg` at the same height, and it carries the lower ends of
## the far body's ankle cage (`_shin_works`), so where one hands over to the
## other nothing changes width.
##
## Colours are colossus_model.gd's FOUND ramp; light is marked in vertex alpha
## as found.gdshader reads it (0.5..0.98 a steady strip, under 0.5 a beacon).

const Model := preload("res://src/models/colossus_model.gd")

## How far up the shin the near body reaches, metres over the ankle.
const SEAM := 400.0
## The surfaces, in the order they are built and uploaded.
const PARTS := [&"ankle", &"toe0", &"toe1", &"toe2", &"stub"]

const BODY := Model.BODY
const PLATE := Model.PLATE
const DARK := Model.DARK
const RIM := Model.RIM
## A cold strip, steady (found.gdshader: glow (1 - a) * 5), and a pad's beacon.
const STRIP := Color(0.7451, 0.7294, 0.8745, 0.72)
const BEACON := Color(0.7098, 0.5176, 0.6118, 0.30)

## The vents under the drum: how many, and how far out their ring is.
const VENTS := 12
const VENT_R := 80.0

## Where the toes join, bend and end, in the toe's own plane: (out, down).
const ROOT := Vector2(66.0, -64.0)
const KNUCKLE := Vector2(122.0, -84.0)
const HEEL := Vector2(164.0, -104.0)


## The surface named `part`, built into a MeshKit (safe on a worker: nothing
## here touches a node or the renderer).
static func build(def: RefCounted, part: StringName) -> MeshKit:
	var k := MeshKit.new()
	k.style = Ink.NONE
	k.style2 = Ink.NONE
	match part:
		&"ankle":
			_ankle(k, def)
		&"toe0":
			_toe(k, def, 0)
		&"toe1":
			_toe(k, def, 1)
		&"toe2":
			_toe(k, def, 2)
		&"stub":
			_stub(k, def)
	return k


## A lathe about local Y through `c`: `prof` is (radius, y) in order, one colour
## per band. Welded round (a machine this size is turned, not faceted), creased
## at every band so a collar stays a collar.
static func _lathe(k: MeshKit, c: Vector3, prof: Array, sides: int, cols: Array, turn := 0.0) -> void:
	for i in prof.size() - 1:
		var p0: Vector2 = prof[i]
		var p1: Vector2 = prof[i + 1]
		var col: Color = cols[mini(i, cols.size() - 1)]
		var from := k.vertex_count()
		for s in sides:
			var a0 := turn + TAU * float(s) / float(sides)
			var a1 := turn + TAU * float(s + 1) / float(sides)
			var q00 := c + Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var q01 := c + Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var q10 := c + Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var q11 := c + Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			if p0.x > 0.0 and p1.x > 0.0:
				k.quad(q01, q00, q10, q11, col)
			elif p1.x > 0.0:
				k.tri(c + Vector3(0.0, p0.y, 0.0), q10, q11, col)
			elif p0.x > 0.0:
				k.tri(q01, q00, c + Vector3(0.0, p1.y, 0.0), col)
		k.smooth_range(from, k.vertex_count(), 360.0 / float(sides) + 6.0)


## THE ANKLE BLOCK: a turned drum three hundred metres across with a belt and a
## shoulder, the shin going up out of its crown, and under it -- the ceiling a
## person between the toes looks up at -- a stepped underside hung with a
## bearing boss, a ring of vents and a ring of cold light.
static func _ankle(k: MeshKit, def: RefCounted) -> void:
	var sr: Vector2 = def.shin_r
	var prof := [
		Vector2(0.0, -80.0), Vector2(18.0, -80.0), Vector2(26.0, -77.0), Vector2(30.0, -72.0),
		Vector2(44.0, -70.0), Vector2(62.0, -68.0), Vector2(64.0, -66.0), Vector2(96.0, -65.0),
		Vector2(98.0, -63.0), Vector2(128.0, -61.0), Vector2(150.0, -56.0), Vector2(157.0, -52.0),
		Vector2(157.0, -41.0), Vector2(151.0, -37.0), Vector2(148.0, -30.0), Vector2(146.0, -10.0),
		Vector2(152.0, -6.0), Vector2(152.0, 0.0), Vector2(138.0, 7.0), Vector2(sr.y * 1.03, 13.0),
		Vector2(sr.y * 1.0, 16.0),
	]
	var cols := [DARK, DARK, RIM, DARK, PLATE, RIM, DARK, RIM, PLATE, BODY, BODY, RIM, PLATE,
		BODY, BODY, RIM, PLATE, BODY, BODY, BODY]
	_lathe(k, Vector3.ZERO, prof, 40, cols, PI / 40.0)
	# The vents under it, a ring of twelve turned bosses hung from the stepped
	# underside, each with a lip: what the ceiling is read by from below, and
	# where the steam comes out when the weight comes onto the foot.
	for i in VENTS:
		var a := TAU * (float(i) + 0.5) / float(VENTS)
		var c := Vector3(cos(a) * VENT_R, -64.5, sin(a) * VENT_R)
		_lathe(k, c, [Vector2(0.0, -5.2), Vector2(5.2, -5.4), Vector2(5.8, -7.4), Vector2(8.6, -7.4),
			Vector2(8.6, -6.0), Vector2(7.5, -5.0), Vector2(7.5, 0.0)], 16, [DARK, DARK, DARK, RIM, RIM, PLATE])
	# A ring of cold light under the drum, lighting the ground it stands over.
	_lathe(k, Vector3.ZERO, [Vector2(100.0, -63.4), Vector2(116.0, -63.8)], 40, [STRIP])
	# Beacons round the belt, so whichever side it is seen from a light is on it.
	for i in 6:
		var a := TAU * float(i) / 6.0
		_ball(k, Vector3(cos(a) * 158.5, -46.5, sin(a) * 158.5), 2.4, 6, BEACON)


## ONE TOE, in the foot's frame at 120 degrees times `toe`: a root joint under
## the drum, a thick proximal segment to a knuckle, a distal one to the heel of
## the pad, a piston along the top of each, cable runs down the sides, and the
## pad itself -- a forty-metre disc with six claws driven into the ground.
static func _toe(k: MeshKit, def: RefCounted, toe: int) -> void:
	var up: float = def.ankle_up
	var reach: float = def.toe_reach
	var pad: float = def.pad
	var a := TAU * float(toe) / 3.0
	var d := Vector3(cos(a), 0.0, sin(a))
	var side := Vector3(-d.z, 0.0, d.x)
	var at := func(p: Vector2) -> Vector3: return d * p.x + Vector3(0.0, p.y, 0.0)
	var root: Vector3 = at.call(ROOT)
	var knuckle: Vector3 = at.call(KNUCKLE)
	var heel: Vector3 = at.call(HEEL)
	var sole := d * reach + Vector3(0.0, -up, 0.0)
	_ball(k, root, 17.0, 16, RIM)
	_segment(k, root, knuckle, 13.5, 11.0, 16)
	_ball(k, knuckle, 12.5, 16, BODY)
	# Cheek plates either side of the knuckle, and the pin it turns on through
	# them: a joint, not a lump.
	for s: float in [1.0, -1.0]:
		var c := knuckle + side * s * 13.0
		k.strut(c - side * s * 1.0, c + side * s * 2.2, 16.5, 16, PLATE)
		k.strut(c + side * s * 2.2, c + side * s * 4.2, 6.0, 12, RIM)
	_segment(k, knuckle, heel, 11.0, 9.0, 16)
	# The pistons that curl the toe: a cylinder off the drum's underside to the
	# knuckle, and one from the knuckle's top to the heel, rods shining.
	var over := Vector3(0.0, 1.0, 0.0)
	var c0: Vector3 = at.call(Vector2(98.0, -64.0))
	var c1 := knuckle + over * 14.0 - d * 5.0
	k.strut(c0, c0.lerp(c1, 0.62), 6.2, 10, DARK)
	k.strut(c0.lerp(c1, 0.55), c1, 3.6, 8, PLATE)
	var c2 := knuckle + over * 13.0 + d * 4.0
	var c3 := heel + over * 10.0
	k.strut(c2, c2.lerp(c3, 0.6), 5.0, 10, DARK)
	k.strut(c2.lerp(c3, 0.52), c3, 2.9, 8, PLATE)
	# Cable runs down both flanks, clamped.
	for s: float in [1.0, -1.0]:
		var off := side * s
		var pts := [root + off * 14.0 + over * 5.0, knuckle + off * 12.0 + over * 3.0, heel + off * 9.5 + over * 2.0]
		for i in 2:
			k.strut(pts[i], pts[i + 1], 1.8, 5, DARK)
		for i in 3:
			var q: Vector3 = (pts[0] as Vector3).lerp(pts[1], 0.3 + 0.35 * float(i)) if i < 2 else (pts[1] as Vector3).lerp(pts[2], 0.5)
			k.strut(q - off * 1.0, q + off * 2.4, 3.2, 6, RIM)
	# The heel joint and the pad: a turned disc, bevelled, its collar, and the
	# sole flat on the crater floor.
	_ball(k, heel, 10.5, 14, RIM)
	var pc := sole
	_lathe(k, pc, [Vector2(0.0, 0.0), Vector2(pad * 0.96, 0.0), Vector2(pad * 1.06, 1.6),
		Vector2(pad * 1.08, 4.8), Vector2(pad * 1.0, 6.6), Vector2(pad * 0.86, 8.4),
		Vector2(pad * 0.84, 10.2), Vector2(pad * 0.66, 13.0), Vector2(pad * 0.40, 15.4),
		Vector2(pad * 0.2, 16.6), Vector2(0.0, 17.2)],
		28, [DARK, DARK, RIM, PLATE, RIM, BODY, BODY, BODY, BODY, BODY])
	k.strut(heel, pc + Vector3(0.0, 15.0, 0.0), 8.5, 12, BODY)
	# Six claws off the pad's edge, driven into the ground past the sole.
	for i in 6:
		var b := TAU * (float(i) + 0.5) / 6.0 + a
		var o := Vector3(cos(b), 0.0, sin(b))
		k.strut(pc + o * (pad * 0.98) + Vector3(0.0, 3.4, 0.0), pc + o * (pad * 1.32) + Vector3(0.0, -3.0, 0.0), 1.9, 6, PLATE)
	# A beacon on the crown of every pad.
	_ball(k, pc + Vector3(0.0, 17.6, 0.0), 1.6, 6, BEACON)


## A tapered, plated segment between two joints: a turned body with a raised
## collar at each end and a course of plate down its middle.
static func _segment(k: MeshKit, a: Vector3, b: Vector3, r0: float, r1: float, sides: int) -> void:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 1e-3:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y)
	var len := a.distance_to(b)
	k.push(Transform3D(Basis(x, y, z), a))
	var prof := [Vector2(r0 * 0.9, 0.0), Vector2(r0 * 1.08, len * 0.05), Vector2(r0 * 1.08, len * 0.12),
		Vector2(r0, len * 0.16), Vector2(lerpf(r0, r1, 0.45), len * 0.46), Vector2(lerpf(r0, r1, 0.5) * 1.04, len * 0.5),
		Vector2(lerpf(r0, r1, 0.55), len * 0.54), Vector2(r1, len * 0.84), Vector2(r1 * 1.1, len * 0.88),
		Vector2(r1 * 1.1, len * 0.95), Vector2(r1 * 0.9, len)]
	_lathe(k, Vector3.ZERO, prof, sides, [RIM, RIM, BODY, BODY, PLATE, BODY, BODY, RIM, RIM, BODY], PI / float(sides))
	k.pop()


static func _ball(k: MeshKit, c: Vector3, r: float, sides: int, col: Color) -> void:
	var prof: Array = []
	var rows := maxi(4, sides / 2)
	for i in rows + 1:
		var t := -PI * 0.5 + PI * float(i) / float(rows)
		prof.append(Vector2(cos(t) * r, sin(t) * r))
	_lathe(k, c, prof, sides, [col])


## THE STUB OF THE SHIN, from inside the drum up to the seam: the far body's own
## profile at those heights, courses of plate, two cold rings, and the lower
## ends of the ankle cage braced down onto the drum's shoulder.
static func _stub(k: MeshKit, def: RefCounted) -> void:
	var shin: float = def.shin
	var sr: Vector2 = def.shin_r
	var prof: Array = []
	var cols: Array = []
	var y := 8.0
	var i := 0
	while y < SEAM + 30.0:
		prof.append(Vector2(radius_at(def, y), y))
		cols.append(RIM if i % 5 == 4 else (PLATE if i % 5 == 2 else BODY))
		y += 20.0
		i += 1
	_lathe(k, Vector3.ZERO, prof, 32, cols, PI / 32.0)
	for ring: float in [150.0, 330.0]:
		var w := radius_at(def, ring) * 1.12
		_lathe(k, Vector3.ZERO, [Vector2(w * 0.9, ring), Vector2(w, ring), Vector2(w, ring + 12.0), Vector2(w * 0.9, ring + 12.0)], 32, [STRIP])
	# The cage: the far body lays six struts from high on the shin down to 20 m
	# over the ankle (colossus_model.gd `_shin_works`); here are their feet.
	for c in 6:
		var a := TAU * float(c) / 6.0
		var dir := Vector3(cos(a), 0.0, -sin(a))
		var top_r := sr.y * 1.1
		var low_r := sr.y * 2.2
		var y_top := shin - shin * 0.93
		var t := (y_top - (SEAM + 30.0)) / (y_top - 20.0)
		var from := dir * lerpf(top_r, low_r, t) + Vector3(0.0, SEAM + 30.0, 0.0)
		var to := dir * low_r + Vector3(0.0, 20.0, 0.0)
		k.strut(from, to, lerpf(24.0, 30.0, t), 10, PLATE)
		_ball(k, to, 34.0, 10, RIM)
		k.strut(to, dir * 150.0 + Vector3(0.0, -4.0, 0.0), 14.0, 8, BODY)


## The shin's radius `y` metres over the ankle, as colossus_model.gd `_leg` lays
## it (w = lerp(root, tip, t^0.8), t the share of the way from the knee).
static func radius_at(def: RefCounted, y: float) -> float:
	var sr: Vector2 = def.shin_r
	var t := clampf(1.0 - y / float(def.shin), 0.0, 1.0)
	return lerpf(sr.x, sr.y, pow(t, 0.8))
