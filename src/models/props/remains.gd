extends RefCounted
## What people left, and the patched places where they still live. Everything a
## person built is MADE here, however much steel is in it: the trawler, the car,
## the sea wall, the fire tower are the hand's work gone to rust and ruin, drawn
## uneven and hatched. What came off a machine and was put to use (plate nailed
## over a hole, a light panel wired to a stove-pipe) is FOUND: ruled, clean,
## violet, riveted, and it never quite belongs.
##
## Each model dresses for its landscape: a car drowned at the coast's tide line,
## sunk to its windows in the moss, buried in snow, scoured pale in the
## bonelands, burnt to its shell in the burning. The shape says what it was;
## the dressing says what the land did to it.
##
## Models face +X. Runs (fences, walls, barricades) lie along X, so a line of
## them is placed with rot = the line's bearing.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")

## The stolen light people wire in: the same three tubes the houses use.
const NEON: Array[Color] = [Color(0.3, 0.95, 1.0), Color(1.0, 0.25, 0.8), Color(0.55, 1.0, 0.35)]


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.HAND)
	match kind:
		PropKind.FENCE: fence(k, v, c)
		PropKind.BARRICADE: barricade(k, v, c)
		PropKind.GRAVE: grave(k, v, c)
		PropKind.DEBRIS: debris(k, v, c)
		PropKind.SHACK: shack(k, v, c)
		PropKind.VEHICLE: vehicle(k, v, c)
		PropKind.HULL: hull(k, v, c)
		PropKind.SEA_WALL: sea_wall(k, v, c)
		PropKind.STUMP: stump(k, v, c)
		PropKind.FIRE_TOWER: fire_tower(k, v, c)
		PropKind.WATER_TANK: water_tank(k, v, c)
		PropKind.SLAG_HEAP: slag_heap(k, v, c)
		PropKind.WRECKAGE: wreckage(k, v, c)
		PropKind.MEMORIAL: memorial(k, v, c)


# --- shared pieces -------------------------------------------------------------

## What drifts and banks against a thing left out here (sand, peat, needles,
## snow, dust, ash), and a step darker. Declared as `BiomeDressing.drift`, and
## worked out from the landscape's own plain ground where it does not argue.
##
## **DELIBERATELY UNTAGGED, and it is the one here most tempting to tag.** Every
## material it names is real and every one of them has a row — SAND 42, SNOW 44,
## ASH 46. They are GROUND rows, in the 40..77 band that `world.gdshader` gives
## the landscape's own ground treatment, so a drift wearing one stops being a
## drift banked against a wreck and becomes a hole in the wreck with the land
## showing through it. `towers.gd`'s header carries the frame where that happened
## to a settlement's roofs. A made surface takes a made mark or none, and sand
## lying against a hull is still a made surface.
static func drift_of(c: int) -> Array[Color]:
	return BiomeDressing.of(c).drift


## Timber as this landscape weathers it: silvered by salt, black with bog, grey
## with needles, bleached, or charred (`BiomeDressing.timber`).
##
## Tagged TIMBER here rather than in `BiomeDressing`, which would have fixed the
## whole game in one line and is exactly why it was not done there. The dressing
## is read by every package, this mark is only ever safe on MADE geometry, and
## `BiomeDef.dressing` is digested by `WorldStamp` — moving an alpha there risks
## refusing every save on disk to improve a roof. This accessor's blast radius is
## two files and can be read in one screen: 33 uses of the returned colours,
## every one on a MADE pen, none through a `lerp` (`Kit.slab` and `Kit.made.*`
## both build into `made`; `Kit.tone`, `GroundColors.up`/`down` keep the alpha).
static func wood_of(c: int) -> Array[Color]:
	var out: Array[Color] = []
	for col: Color in BiomeDressing.of(c).timber:
		out.append(GroundColors.made(col, GroundColors.TIMBER))
	return out


## Soft lumps [x, z, r, h] banked against a thing, feet sunk in the ground.
## Drifts lie long and low along their own axis, never piled like stones.
static func banks(k: Kit, lumps: Array, col: Color, seed_value: int) -> void:
	for i in lumps.size():
		var l: Array = lumps[i]
		var r: float = l[2]
		var ang := Rng.hash01(seed_value, i, 5) * PI
		drift(k, Vector3(float(l[0]), 0.0, float(l[1])), r * 1.35, r * 0.72, minf(float(l[3]), r * 0.42), ang, col if i % 2 == 0 else GroundColors.down(col, 0.06), seed_value + i)


## One long, low, soft drift: an elliptical mound `length` by `width` (half
## extents, length along x before the turn `ang` about y), `height` at its
## crest. The crest leans toward -z, so its lee face is short and steep and
## takes a step of shade; the rim is ragged and sunk. The normals are the
## mound's own, not the facets', so light slides over it in one soft band
## instead of breaking it into shards.
static func drift(k: Kit, at: Vector3, length: float, width: float, height: float, ang: float, col: Color, s: int) -> void:
	const SEG := 10
	const RINGS: Array[float] = [0.0, 0.4, 0.72, 0.92, 1.0]
	var rot := Basis(Vector3.UP, ang)
	var pts: Array = []
	for ri in RINGS.size():
		var t := RINGS[ri]
		var ring: Array[Vector3] = []
		for si in SEG:
			var a := float(si) / SEG * TAU
			# The rim's rag is the same for the last rings, so they never fold.
			var rag := 1.0 + Kit.j(s, si * 7, 0.1) * smoothstep(0.6, 1.0, t)
			var u := cos(a) * t * rag
			var v := sin(a) * t * rag
			ring.append(Vector3(u, _drift_y(u, v), v))
		pts.append(ring)
	# The lee face a clear step down and cooler, the drift's blue shadow (ART 3).
	var lee := GroundColors.down(col, 0.24).lerp(P.SLATE[3], 0.18)
	var world := func(q: Vector3) -> Vector3:
		return at + rot * Vector3(q.x * length, q.y * height - (0.05 if q.y <= 0.0 else 0.0), q.z * width)
	var start := k.made.vertex_count()
	var apex: Vector3 = world.call(Vector3(0.0, 1.0, -DRIFT_LEAN))
	var first: Array[Vector3] = pts[1]
	for si in SEG:
		var q0 := first[si]
		var q1 := first[(si + 1) % SEG]
		k.made.tri(apex, world.call(q1), world.call(q0), lee if q0.z + q1.z < -DRIFT_LEAN * 1.2 else col)
	for ri in range(1, RINGS.size() - 1):
		var a0: Array[Vector3] = pts[ri]
		var a1: Array[Vector3] = pts[ri + 1]
		for si in SEG:
			var n := (si + 1) % SEG
			# The lee face: behind the crest, its edge ragged by the rim's own rag.
			var shade := lee if a0[si].z + a0[n].z < -DRIFT_LEAN * 2.0 + Kit.j(s, si + 40, 0.25) else col
			k.made.quad(world.call(a0[n]), world.call(a0[si]), world.call(a1[si]), world.call(a1[n]), shade)
	# The mound's own normals, from its height field. (A drift is never drawn
	# inside a push, so its vertices are where it put them.)
	var inv := rot.inverse()
	for vi in range(start, k.made.vertex_count()):
		var q := inv * (k.made.verts[vi] - at)
		var u := q.x / length
		var v := q.z / width
		var e := 0.01
		var dyu := (_drift_y(u + e, v) - _drift_y(u - e, v)) / (2.0 * e) * height / length
		var dyv := (_drift_y(u, v + e) - _drift_y(u, v - e)) / (2.0 * e) * height / width
		k.made.normals[vi] = (rot * Vector3(-dyu, 1.0, -dyv)).normalized()


## How far a drift's crest leans toward its lee (-z), in its unit ellipse.
const DRIFT_LEAN := 0.3


## A drift's height (0..1) at (u, v) in its unit ellipse: a soft crest leaned
## toward -v, falling away to 0 at the rim.
static func _drift_y(u: float, v: float) -> float:
	var vv := (v + DRIFT_LEAN) / (1.0 + DRIFT_LEAN * signf(v + DRIFT_LEAN))
	var t2 := minf(u * u + vv * vv, 1.0)
	return pow(1.0 - t2, 1.5)


## A quad seen from both sides.
static func both(pen: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	pen.quad(a, b, c, d, col)
	pen.quad(d, c, b, a, GroundColors.down(col, 0.1))


## A corrugated sheet on the plane (o, o + u, o + u + v, o + v): ribs along v,
## light and dark by turns, so it reads as tin at a glance.
static func corrugated(pen: MeshKit, o: Vector3, u: Vector3, v: Vector3, ribs: int, col: Color) -> void:
	var n := u.cross(v).normalized() * 0.006
	for i in ribs:
		var a := o + u * (float(i) / ribs)
		var b := o + u * (float(i + 1) / ribs)
		var cc := col if i % 2 == 0 else GroundColors.down(col, 0.35)
		pen.quad(a + n * float(i % 2), b + n * float(i % 2), b + v + n * float(i % 2), a + v + n * float(i % 2), cc)


## A rust run down a MADE face from `top`: wide at the top, drying to a thread.
## Wound from the direction it is meant to be seen from: taken in corner order
## the front came out at -`out`, and world.gdshader culls a back face, so every
## streak in this file stood proud of its wall facing into it and none of them
## drew (props/works.gd `run` had the same fault).
static func streak(k: Kit, top: Vector3, width: float, length: float, out: Vector3, col: Color = P.RUST[2]) -> void:
	var along := Vector3(out.z, 0, -out.x).normalized() * width * 0.5
	if along.cross(Vector3.DOWN).dot(out) < 0.0:
		along = -along
	var lift := out.normalized() * 0.008
	# A STAIN FADES TOWARD WHAT IT LIES ON. This DARKENED as it fell
	# (`down(col, 0.3)`), which is a stain getting heavier as it dries, and it is
	# most of why a run read as a strap somebody painted on. The taper is kept:
	# these lie on hulls and drums that curve away, and a widening foot leaves
	# the surface — `Works.run` may widen because a panel is flat, and
	# `Rocks._run` may not for the same reason this may not.
	var mid := top + Vector3(0, -length * 0.5, 0)
	var foot := top + Vector3(0, -length, 0)
	k.made.quad(top - along + lift, top + along + lift, mid + along * 0.45 + lift, mid - along * 0.6 + lift, col)
	k.made.quad(mid - along * 0.6 + lift, mid + along * 0.45 + lift, foot + along * 0.1 + lift, foot - along * 0.08 + lift, GroundColors.up(col, 0.5))


## A piece of machine plate put to a person's use: ruled, riveted, on the
## plane of (a, b, c, d), a hair out. FOUND.
static func patch(k: Kit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tone: int = 3) -> void:
	k.plate(a, b, c, d, P.PLATE[tone], P.PLATE[maxi(tone - 2, 0)], P.PLATE[5])


## There is no two-sided plate here any more. Its one caller was the dugout's
## roof, which is dug into the ash with the bank closed over both slopes: the
## play camera is always above it, so the four undersides it drew were the
## largest unseen pieces in the game (about 450 cells each) and cost triangles
## in every chunk bake. A plate a player really can get under wants ONE call per
## face, wound deliberately, not a pair that hides half of itself by
## construction (tests/render/test_found_drawn.gd).


## A tube of stolen neon along a wall from a to b, standing out along `out`:
## a dark mount, then the tube, lit when the light goes.
static func neon_tube(k: Kit, a: Vector3, b: Vector3, out: Vector3, col: Color) -> void:
	var o := out.normalized()
	_facing_quad(k.made, a + o * 0.01 + Vector3(0, -0.045, 0), b + o * 0.01 + Vector3(0, -0.045, 0), Vector3(0, 0.09, 0), o, P.INK[1])
	_facing_quad(k.made, a + o * 0.02 + Vector3(0, -0.028, 0), b + o * 0.02 + Vector3(0, -0.028, 0), Vector3(0, 0.056, 0), o, GroundColors.lamp(col, 2.0))


## The quad (a, b, b + rise, a + rise), wound so its front faces `out`.
static func _facing_quad(pen: MeshKit, a: Vector3, b: Vector3, rise: Vector3, out: Vector3, col: Color) -> void:
	if (b - a).cross(rise).dot(out) >= 0.0:
		pen.quad(a, b, b + rise, a + rise, col)
	else:
		pen.quad(b, a, a + rise, b + rise, col)


## A wheel on its side axis (z): tyre and hub.
static func wheel(k: Kit, at: Vector3, r: float, width: float, tyre: Color, hub: Color) -> void:
	k.made.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0, -width * 0.5)))
	k.made.prism(0, 0, 0, r, width, r, 9, tyre, hub)
	k.made.prism(0, -0.004, 0, r * 0.45, width + 0.008, r * 0.45, 7, hub, GroundColors.up(hub, 0.3))
	k.made.pop()


# --- fences and barricades -----------------------------------------------------

## A run of fence two tiles along X. 0: posts and barbed wire, 1: a machine's
## mesh panel between hand posts, 2: a section gone over. Snow fences are slats
## in the Snowfield; reeds grow through them in the Moss.
static func fence(k: Kit, v: int, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var burnt := BiomeDressing.burnt(c)
	var s := 20100 + v * 13 + c
	var wood := wood_of(c)
	var posts: Array[float] = [-0.98, 0.02]
	if dress.cold() and v != 1:
		# A snow fence: split slats wired in a ribbon, a drift built up behind.
		for pi in 2:
			k.limb(Vector3(posts[pi], -0.1, 0.0), Vector3(posts[pi] + Kit.j(s, pi, 0.05), 1.05, Kit.j(s, pi + 3, 0.04)), 0.04, 0.03, 5, wood[1])
		var lean := 0.0 if v == 0 else 0.35
		for i in 13:
			var x := -1.0 + i * 0.155
			var h := 0.85 + Kit.j(s, 10 + i, 0.08) - (absf(x) * 0.3 if v == 2 else 0.0)
			k.made.push(Transform3D(Basis(Vector3.RIGHT, lean + Kit.j(s, 30 + i, 0.05)), Vector3(x, -0.05, 0.0)))
			k.slab(0.0, 0.0, 0.0, 0.07, h, 0.025, s + 40 + i, wood[0] if i % 3 else wood[1], dress.snow[0], 0.008)
			k.made.pop()
		k.sag(Vector3(-1.0, 0.25, 0.02), Vector3(1.0, 0.25, 0.02), 0.03, 4, 0.007, P.INK[2])
		k.sag(Vector3(-1.0, 0.7, 0.02), Vector3(1.0, 0.7, 0.02), 0.03, 4, 0.007, P.INK[2])
		banks(k, [[-0.6, -0.3, 0.45, 0.45], [0.2, -0.35, 0.55, 0.55], [0.8, -0.28, 0.4, 0.4], [-0.1, 0.25, 0.3, 0.14]], dress.snow[0], s + 60)
		return
	match v:
		0:
			for pi in 2:
				var top := Vector3(posts[pi] + Kit.j(s, pi, 0.06), 0.9 + Kit.j(s, pi + 5, 0.08), Kit.j(s, pi + 3, 0.05))
				k.limb(Vector3(posts[pi], -0.1, 0.0), top, 0.045, 0.032, 5, wood[0] if pi == 0 else wood[1])
			# Three strands, the lowest slack; barbs every hand's width.
			for h: float in [0.3, 0.55, 0.8]:
				var dip := 0.04 if h > 0.5 else 0.12
				k.sag(Vector3(-1.0, h, 0.0), Vector3(1.0, h - 0.03, 0.0), dip, 6, 0.006, P.INK[2])
				for b in 7:
					var t := (b + 0.5) / 7.0
					var p := Vector3(-1.0 + t * 2.0, h - 0.015 - dip * 4.0 * t * (1.0 - t), 0.0)
					k.fleck(p + Vector3(-0.02, -0.02, 0.0), p + Vector3(0.02, 0.02, 0.01), p + Vector3(0.0, 0.0, -0.02), P.INK[3])
			# A rag caught on the top strand, long faded.
			k.fleck(Vector3(0.35, 0.78, 0.0), Vector3(0.45, 0.62, 0.02), Vector3(0.31, 0.6, -0.01), P.ASH[1] if burnt else P.BLOOM[1])
		1:
			# A machine's mesh panel, ruled and exact, lashed between hand posts;
			# it sags where one post leans. Razor coil along its top.
			for pi in 2:
				k.limb(Vector3(posts[pi], -0.1, 0.0), Vector3(posts[pi] + (0.08 if pi == 1 else 0.0), 1.25, 0.0), 0.05, 0.04, 5, wood[pi])
			k.found.push(Transform3D(Basis(Vector3.BACK, 0.03) * Basis(Vector3.RIGHT, 0.06), Vector3(-0.48, 0.1, 0.03)))
			var pw := 0.96
			var ph := 1.02
			k.found.quad(Vector3(-pw, 0, 0), Vector3(pw, 0, 0), Vector3(pw, 0.04, 0), Vector3(-pw, 0.04, 0), P.PLATE[2])
			k.found.quad(Vector3(-pw, ph - 0.04, 0), Vector3(pw, ph - 0.04, 0), Vector3(pw, ph, 0), Vector3(-pw, ph, 0), P.PLATE[2])
			for i in 11:
				var x := -pw + i * (pw * 2.0 / 10.0)
				k.found.quad(Vector3(x - 0.008, 0, 0.004), Vector3(x + 0.008, 0, 0.004), Vector3(x + 0.008, ph, 0.004), Vector3(x - 0.008, ph, 0.004), P.PLATE[3])
				k.found.quad(Vector3(x + 0.008, 0, -0.004), Vector3(x - 0.008, 0, -0.004), Vector3(x - 0.008, ph, -0.004), Vector3(x + 0.008, ph, -0.004), P.PLATE[1])
			for j in 5:
				var y := 0.2 + j * 0.17
				k.found.quad(Vector3(-pw, y - 0.007, 0.006), Vector3(pw, y - 0.007, 0.006), Vector3(pw, y + 0.007, 0.006), Vector3(-pw, y + 0.007, 0.006), P.PLATE[3])
				k.found.quad(Vector3(pw, y - 0.007, -0.006), Vector3(-pw, y - 0.007, -0.006), Vector3(-pw, y + 0.007, -0.006), Vector3(pw, y + 0.007, -0.006), P.PLATE[1])
			for i in 5:
				k.hoop(Vector3(-0.8 + i * 0.4, ph + 0.1, 0.0), 0.1, 6, 0.008, P.PLATE[4], Vector3(1, 0, 0))
			k.found.pop()
			# Lashed on with rope where the ruler meets the hand.
			for pi in 2:
				k.made.prism(posts[pi] + (0.03 if pi == 1 else 0.0), 0.5, 0.0, 0.06, 0.58, 0.06, 5, P.LINEN[2])
		_:
			# Gone over: one post snapped, the wire slack on the ground, the
			# other post still standing with a strand wound round it.
			k.limb(Vector3(-0.98, -0.1, 0.0), Vector3(-0.95, 0.85, 0.05), 0.045, 0.034, 5, wood[0])
			k.limb(Vector3(0.02, -0.05, 0.0), Vector3(0.1, 0.3, 0.02), 0.045, 0.04, 5, wood[1])
			k.limb(Vector3(0.12, 0.03, 0.08), Vector3(0.85, 0.04, 0.4), 0.04, 0.03, 5, wood[1])
			k.sag(Vector3(-0.95, 0.75, 0.05), Vector3(0.8, 0.05, 0.35), 0.1, 6, 0.006, P.INK[2])
			k.sag(Vector3(-0.95, 0.5, 0.05), Vector3(1.0, 0.03, -0.2), 0.05, 6, 0.006, P.INK[2])
			k.sag(Vector3(-0.2, 0.03, -0.3), Vector3(0.6, 0.03, 0.1), -0.05, 5, 0.006, P.INK[3])
	if BiomeDressing.reedy(c):
		# Reeds through the wire, taller than the posts.
		var rs := k.made.vertex_count()
		for i in 9:
			var x := -0.9 + i * 0.22 + Kit.j(s, 70 + i, 0.06)
			var z := Kit.j(s, 80 + i, 0.18)
			k.blade(Vector3(x, -0.02, z), Vector3(x + 0.05, 0.9 + Kit.j(s, 90 + i, 0.25), z), 0.05, Kit.j(s, 95 + i, 1.5), P.SPRUCE[3] if i % 2 else P.MOSS[3])
		k.sway_by_height(rs, 0.0, 1.0, 0.7)
	elif burnt:
		banks(k, [[-0.6, 0.2, 0.3, 0.12], [0.5, -0.2, 0.35, 0.1]], dress.drift[0], s + 90)


## A barricade across a way in: 0 tyres, sandbags and a leaning sheet of plate
## behind crossed stakes; 1 cast blocks with faded chevrons and a machine plate
## bolted on, struck through.
static func barricade(k: Kit, v: int, c: int) -> void:
	var burnt := BiomeDressing.burnt(c)
	var s := 20300 + v * 11 + c
	var wood := wood_of(c)
	var drift := drift_of(c)
	if v % 2 == 0:
		for i in 3:
			var x := -0.9 + i * 0.12
			for t in 3 - i:
				k.made.prism(x + 0.02 * t, t * 0.14 - 0.02, -0.35 + i * 0.25, 0.2, t * 0.14 + 0.12, 0.2, 9, P.INK[2], P.INK[1])
				k.made.prism(x + 0.02 * t, t * 0.14 + 0.121, -0.35 + i * 0.25, 0.09, t * 0.14 + 0.124, 0.09, 9, P.INK[0])
		for i in 7:
			var x := -0.2 + (i % 4) * 0.34 + (0.17 if i >= 4 else 0.0)
			var y := -0.02 + (0.18 if i >= 4 else 0.0)
			k.slab(x, y, -0.1 + Kit.j(s, i, 0.05), 0.34, 0.2, 0.26, s + i, P.LINEN[3] if i % 3 else P.EARTH[3], P.LINEN[4], 0.035, 0.25)
		# The sheet: plate off a machine, propped on a stake.
		k.found.push(Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0.2, 0.0, -0.5)))
		k.plate(Vector3(-0.55, 0, 0), Vector3(0.75, 0, 0), Vector3(0.75, 0.95, 0), Vector3(-0.55, 0.95, 0), P.PLATE[3], P.PLATE[1], P.PLATE[5])
		k.found.pop()
		k.limb(Vector3(0.7, -0.05, -1.0), Vector3(0.62, 0.8, -0.72), 0.03, 0.025, 4, wood[1])
		# Crossed stakes in front, sharpened, wired.
		for i in 3:
			var x := -0.9 + i * 0.85
			k.limb(Vector3(x - 0.35, -0.05, 0.55), Vector3(x + 0.3, 0.75, 0.9), 0.035, 0.012, 4, wood[0])
			k.limb(Vector3(x + 0.35, -0.05, 0.55), Vector3(x - 0.3, 0.75, 0.9), 0.035, 0.012, 4, wood[1])
		k.sag(Vector3(-1.2, 0.35, 0.72), Vector3(1.2, 0.35, 0.72), 0.06, 7, 0.006, P.INK[2])
	else:
		var concrete := BiomeDressing.of(c).concrete
		for i in 3:
			var x := -0.85 + i * 0.85
			var rot := Kit.j(s, i, 0.2)
			k.made.push(Transform3D(Basis(Vector3.UP, rot) * Basis(Vector3.BACK, Kit.j(s, i + 4, 0.06)), Vector3(x, -0.04, Kit.j(s, i + 8, 0.12))))
			k.slab(0.0, 0.0, 0.0, 0.84, 0.5, 0.42, s + 20 + i, concrete, GroundColors.up(concrete, 0.2), 0.02, 0.55)
			# Chevrons, faded, painted on by a hand that wanted to be seen.
			for ch in 3:
				var cx := -0.26 + ch * 0.24
				k.made.quad(Vector3(cx, 0.06, 0.216), Vector3(cx + 0.1, 0.06, 0.216), Vector3(cx + 0.16, 0.42, 0.13), Vector3(cx + 0.06, 0.42, 0.13), P.RUST[1] if burnt else P.RUST[3])
			k.made.pop()
		k.limb(Vector3(-0.4, 0.5, 0.1), Vector3(-0.2, 0.95, 0.35), 0.018, 0.014, 4, P.RUST[2])
		k.limb(Vector3(0.45, 0.5, -0.05), Vector3(0.9, 0.82, -0.1), 0.018, 0.014, 4, P.RUST[2])
		# The machines' own plate, bolted on the middle block, and struck.
		k.plate(Vector3(-0.2, 0.12, 0.24), Vector3(0.2, 0.12, 0.24), Vector3(0.2, 0.34, 0.18), Vector3(-0.2, 0.34, 0.18), P.RIME[5].lerp(P.PLATE[4], 0.5), P.PLATE[1], P.PLATE[2])
		k.made.quad(Vector3(-0.26, 0.15, 0.25), Vector3(0.26, 0.28, 0.215), Vector3(0.26, 0.32, 0.205), Vector3(-0.26, 0.19, 0.24), P.INK[0])
	banks(k, [[-0.9, -0.5, 0.35, 0.12], [0.8, -0.45, 0.4, 0.14]], drift[0], s + 50)


# --- the dead ------------------------------------------------------------------

## Graves and memorials. 0: a mound under a lashed cross with a rag on it;
## 1: a marker cut from machine plate with the name scratched by hand and a jar
## lamp that someone still lights; 2: three stakes in a row (in the Moss, the
## bog's grave markers, tall so they can be found again).
static func grave(k: Kit, v: int, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 20500 + v * 7 + c
	var wood := wood_of(c)
	var mound := drift_of(c)
	if dress.covers == &"wrack":
		# Sand will not hold a grave: they dig into the turf behind the dunes.
		mound = [P.EARTH[2].lerp(dress.growth, 0.4), P.EARTH[2]]
	match v % 3:
		0:
			_mound(k, Vector3(0.1, 0.0, 0.0), 0.62, 0.26, s, mound)
			k.limb(Vector3(-0.55, -0.05, 0.0), Vector3(-0.53, 0.95, 0.02), 0.035, 0.028, 5, wood[0])
			k.limb(Vector3(-0.54, 0.7, -0.26), Vector3(-0.52, 0.72, 0.28), 0.028, 0.024, 5, wood[0])
			k.made.prism(-0.535, 0.66, 0.0, 0.045, 0.76, 0.045, 5, P.LINEN[2])
			k.fleck(Vector3(-0.52, 0.72, 0.22), Vector3(-0.47, 0.42, 0.26), Vector3(-0.5, 0.45, 0.16), P.RUST[2] if dress.cold() else P.BLOOM[1])
			for i in 8:
				var a := float(i) / 8.0 * TAU
				k.stone(0.1 + cos(a) * 0.72, -0.04, sin(a) * 0.36, 0.07, 0.08, s + 10 + i, P.STONE[3] if i % 2 else P.LINEN[3], 5)
		1:
			_mound(k, Vector3(0.15, 0.0, 0.0), 0.55, 0.2, s, mound)
			k.found.push(Transform3D(Basis(Vector3.BACK, -0.08), Vector3(-0.5, -0.1, 0.0)))
			k.found.quad(Vector3(0, 0, 0.22), Vector3(0, 0, -0.22), Vector3(0, 0.62, -0.22), Vector3(0, 0.7, 0.22), P.PLATE[3])
			k.found.quad(Vector3(0, 0, -0.22), Vector3(0, 0, 0.22), Vector3(0, 0.7, 0.22), Vector3(0, 0.62, -0.22), P.PLATE[2])
			for r in 4:
				k.found.quad(Vector3(0.004, 0.08 + r * 0.16, 0.17), Vector3(0.004, 0.08 + r * 0.16, 0.15), Vector3(0.004, 0.1 + r * 0.16, 0.15), Vector3(0.004, 0.1 + r * 0.16, 0.17), P.PLATE[5])
			k.found.pop()
			# The name, scratched with a nail: a row of short strokes.
			for i in 5:
				var z := -0.12 + i * 0.05
				k.made.quad(Vector3(-0.47, 0.4, z), Vector3(-0.47, 0.4, z + 0.02), Vector3(-0.465, 0.5 - (i % 2) * 0.03, z + 0.03), Vector3(-0.465, 0.5 - (i % 2) * 0.03, z + 0.01), P.LINEN[5])
			# A jar with a stub of candle: the lamp code lights it after dusk.
			k.made.prism(-0.25, -0.02, 0.28, 0.06, 0.14, 0.055, 7, P.SPRUCE[3], P.SPRUCE[4])
			k.made.prism(-0.25, 0.05, 0.28, 0.022, 0.12, 0.018, 5, GroundColors.lamp(P.EMBER[4], 1.4))
			# Flowers left on it, one fresh.
			k.fleck(Vector3(0.2, 0.12, -0.2), Vector3(0.3, 0.12, -0.12), Vector3(0.24, 0.2, -0.16), P.BLOOM[4])
			k.fleck(Vector3(0.28, 0.1, -0.28), Vector3(0.36, 0.1, -0.2), Vector3(0.3, 0.17, -0.24), P.LINEN[5])
		_:
			# Tall where the ground drowns things, so a grave can be found again.
			var tall := 1.35 if BiomeDressing.reedy(c) else 0.8
			for i in 3:
				var z := -0.5 + i * 0.5
				_mound(k, Vector3(0.15, 0.0, z), 0.34, 0.14, s + i, mound)
				k.limb(Vector3(-0.2, -0.05, z), Vector3(-0.19 + Kit.j(s, i, 0.05), tall - i * 0.08, z + Kit.j(s, i + 3, 0.04)), 0.03, 0.02, 4, wood[i % 2])
				k.made.prism(-0.19, tall * 0.78 - i * 0.08, z, 0.04, tall * 0.84 - i * 0.08, 0.04, 5, [P.LINEN[4], P.RUST[3], P.BLOOM[2]][i])
			if dress.cold():
				k.clump(0.1, 0.02, 0.0, 0.5, 0.18, s + 9, dress.snow[0], 8)


## A grave's mound: long and low along x, the fresh side darker.
static func _mound(k: Kit, at: Vector3, length: float, h: float, s: int, cols: Array[Color]) -> void:
	k.made.push(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.5)), at))
	k.clump(0.0, -0.1, 0.0, length, h + 0.1, s, cols[0], 9)
	k.made.pop()
	k.made.push(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.45)), at + Vector3(0.12, 0.0, 0.03)))
	k.clump(0.0, -0.1, 0.0, length * 0.6, h + 0.08, s + 1, cols[1], 7)
	k.made.pop()


# --- litter of the world before --------------------------------------------------

## A field of debris you walk through. 0: a slab of broken concrete with bars
## out of it; 1: a length of pipe, a tyre, cans; 2: a roof sheet blown flat,
## cable in loops and broken glass that catches the light.
static func debris(k: Kit, v: int, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var burnt := BiomeDressing.burnt(c)
	var s := 20700 + v * 5 + c
	var concrete := dress.concrete
	match v % 3:
		0:
			k.made.push(Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, 0.12), Vector3(0.0, -0.05, 0.0)))
			k.slab(0.0, 0.0, 0.0, 1.1, 0.14, 0.8, s, concrete, GroundColors.up(concrete, 0.15), 0.05, 0.05)
			k.made.pop()
			k.slab(0.7, -0.04, -0.4, 0.4, 0.12, 0.3, s + 1, GroundColors.down(concrete, 0.2), concrete, 0.04, 0.1)
			for i in 5:
				var a := Vector3(-0.45 + i * 0.2, 0.1, 0.33 - i * 0.07)
				k.limb(a, a + Vector3(0.1 + Kit.j(s, i, 0.1), 0.3 + Kit.j(s, i + 5, 0.12), 0.15), 0.014, 0.01, 4, P.RUST[2])
			for i in 6:
				k.stone(-0.6 + i * 0.26, -0.03, -0.55 + Kit.j(s, 20 + i, 0.12), 0.06, 0.05, s + 20 + i, concrete, 4)
		1:
			k.limb(Vector3(-0.8, 0.1, -0.2), Vector3(0.6, 0.08, 0.1), 0.1, 0.1, 8, P.RUST[2])
			k.made.prism(-0.8, 0.0, -0.2, 0.12, 0.2, 0.12, 8, P.RUST[1], P.INK[1])
			k.made.push(Transform3D(Basis(Vector3.BACK, 0.22), Vector3(0.45, 0.02, -0.5)))
			k.made.prism(0, 0, 0, 0.26, 0.14, 0.26, 10, P.INK[2], P.INK[1])
			k.made.prism(0, 0.141, 0, 0.12, 0.145, 0.12, 10, P.INK[0])
			k.made.pop()
			for i in 4:
				var p := Vector3(-0.4 + i * 0.22, 0.0, 0.45 + Kit.j(s, i, 0.1))
				k.made.prism(p.x, 0.0, p.z, 0.04, 0.09, 0.04, 6, P.RUST[3] if i % 2 else P.SLATE[3], P.INK[2])
		_:
			corrugated(k.made, Vector3(-0.7, 0.03, -0.45), Vector3(-0.15, 0.02, 0.75), Vector3(1.2, 0.04, 0.2), 9, P.RUST[1] if burnt else P.SLATE[3])
			k.cable(Vector3(0.5, 0.03, 0.3), Vector3(0.85, 0.05, -0.4), -0.05, 5, 0.012, P.INK[2])
			k.hoop(Vector3(0.6, 0.03, -0.1), 0.15, 8, 0.01, P.INK[3])
			for i in 5:
				var p := Vector3(-0.5 + i * 0.18, 0.02, 0.55 + Kit.j(s, i, 0.08))
				k.fleck(p, p + Vector3(0.05, 0.005, 0.03), p + Vector3(0.01, 0.01, -0.04), GroundColors.glint(P.SPRUCE[4] if i % 2 else P.RIME[4]))
	if dress.cold():
		k.clump(0.1, -0.1, 0.1, 0.5, 0.18, s + 30, dress.snow[0], 8)
	elif BiomeDressing.mossy(c):
		k.clump(-0.3, -0.06, 0.3, 0.2, 0.1, s + 31, dress.growth, 6)


# --- where people still live ---------------------------------------------------

## A patched shelter. Which one people put up is the landscape's own
## (`BiomeDressing.shelter`), not this file's: a boarded fishing shack, a hut
## on stilts over standing water, a platform up among the trunks, an emergency
## shell half under the snow, a dry-stone lean-to under tin, a dugout in the
## ash. Each form is the same wherever it is put up — a pod is an orange shell
## whatever land it is buried in — and only what the LAND walls it with and
## banks against it comes off the dressing. Variant 1 has stolen tech in it: a
## machine's light panel wired to a neon tube and an aerial, lit after dusk.
static func shack(k: Kit, v: int, c: int) -> void:
	var d := BiomeDressing.of(c)
	var s := 21000 + v * 17 + c * 3
	var lit := v % 2 == 1
	match d.shelter:
		&"stilt": _stilt_hut(k, s, lit, d)
		&"blind": _blind(k, s, lit, d)
		&"pod": _pod(k, s, lit, d)
		&"lean_to": _lean_to(k, s, lit, d)
		&"dugout": _dugout(k, s, lit, d)
		# The crags' round under turf (props/crags.gd) never wires a light in;
		# its lit one has a hearth going inside the door instead.
		&"roundhouse": PropModels.Crags.roundhouse_shelter(k, s, lit, d)
		&"infill": _infill(k, s, lit, d)
		# The mesas' hollow under the rock (props/mesas.gd): a hearth, never a tube.
		&"cut_room": PropModels.Mesas.cut_room_shelter(k, s, lit, d, c)
		_: _fish_shack(k, s, lit, d)


## Stolen tech on a wall: a FOUND light panel, the neon tube it feeds, a cable
## down to the ground and an aerial on the roof line. Sized to read at 640x360.
static func _wired(k: Kit, wall_a: Vector3, wall_b: Vector3, out: Vector3, roof: Vector3, col: Color) -> void:
	var mid := wall_a.lerp(wall_b, 0.5)
	var o := out.normalized()
	var u := (wall_b - wall_a).normalized()
	_facing_quad(k.found, mid + o * 0.02 - u * 0.18 - Vector3(0, 0.02, 0), mid + o * 0.02 + u * 0.18 - Vector3(0, 0.02, 0), Vector3(0, 0.26, 0), o, P.PLATE[1])
	_facing_quad(k.found, mid + o * 0.03 - u * 0.14 + Vector3(0, 0.02, 0), mid + o * 0.03 + u * 0.14 + Vector3(0, 0.02, 0), Vector3(0, 0.18, 0), o, Color(col.r, col.g, col.b, 0.7))
	neon_tube(k, wall_a + Vector3(0, 0.4, 0), wall_b + Vector3(0, 0.4, 0), o, col)
	k.sag(mid + o * 0.04, mid + o * 0.3 + Vector3(0, -mid.y, 0), 0.02, 3, 0.008, P.INK[1])
	k.rod(roof, roof + Vector3(0.02, 0.75, 0.0), 0.012, 4, P.PLATE[3])
	k.rod(roof + Vector3(0.02, 0.62, -0.18), roof + Vector3(0.02, 0.62, 0.18), 0.008, 4, P.PLATE[3])
	k.rod(roof + Vector3(0.02, 0.5, -0.12), roof + Vector3(0.02, 0.5, 0.12), 0.008, 4, P.PLATE[3])
	k.found.prism(roof.x + 0.02, roof.y + 0.75, roof.z, 0.03, roof.y + 0.82, 0.02, 6, Color(1.0, 0.25, 0.3, 0.3))
	# A loop of the same tube wound up the aerial, so the stolen light shows
	# whichever way the shack is turned.
	k.made.prism(roof.x + 0.02, roof.y + 0.12, roof.z, 0.1, roof.y + 0.5, 0.1, 6, GroundColors.lamp(col, 1.0))


static func _fish_shack(k: Kit, s: int, lit: bool, d: BiomeDressing) -> void:
	var tar := P.INK[3].lerp(P.EARTH[1], 0.4)
	var t := PropModels.Houses.walls(k, 1.5, 2.1, 1.05, s, tar, GroundColors.down(tar, 0.2), Vector3(0.04, 0.0, -0.02))
	# Weatherboards lapped on every wall, not lines painted on two: from the side
	# over the shoulder a painted line is nothing and the wall was one dark sheet.
	# The door and the wired panel's corner of the front are left bare.
	var fs := PropModels.Houses.faces(t)
	for fi in fs.size():
		var wf: Array = fs[fi]
		var gaps: Array = []
		if fi == 0:
			gaps = [Vector4(0.34, 0.64, 0.0, 0.84), Vector4(-0.1, 0.2, 0.3, 0.8)]
		PropModels.Houses.boards(k, wf[0], wf[1], wf[2], wf[3], s + 90 + fi, d.timber[0].lerp(tar, 0.4), 7, gaps)
	# Pent roof of tin, rust in bands, a sheet of machine plate over the hole.
	var ry := 1.08
	corrugated(k.made, Vector3(-0.95, ry + 0.3, -1.25), Vector3(0.0, 0.0, 2.5), Vector3(1.95, -0.34, 0.0), 12, P.RUST[2])
	k.made.quad(Vector3(-0.95, ry + 0.3, -1.25), Vector3(1.0, ry - 0.04, -1.25), Vector3(1.0, ry - 0.04, 1.25), Vector3(-0.95, ry + 0.3, 1.25), P.INK[2])
	patch(k, Vector3(-0.3, ry + 0.21, -0.2), Vector3(-0.3, ry + 0.21, 0.6), Vector3(0.5, ry + 0.08, 0.6), Vector3(0.5, ry + 0.08, -0.2), 2)
	# Door on the front, a stovepipe off true.
	k.made.quad(Vector3(0.77, 0.0, 0.25), Vector3(0.77, 0.0, -0.2), Vector3(0.8, 0.82, -0.2), Vector3(0.8, 0.82, 0.25), P.EARTH[1])
	k.limb(Vector3(-0.5, ry + 0.25, 0.7), Vector3(-0.44, ry + 0.95, 0.72), 0.06, 0.055, 6, P.INK[2])
	# Nets hung to dry between two poles, floats on the head-rope; creels stacked.
	k.limb(Vector3(1.4, -0.05, -1.3), Vector3(1.42, 1.3, -1.3), 0.03, 0.025, 4, P.LINEN[2])
	k.limb(Vector3(1.45, -0.05, 0.6), Vector3(1.43, 1.25, 0.6), 0.03, 0.025, 4, P.LINEN[2])
	k.sag(Vector3(1.42, 1.22, -1.3), Vector3(1.43, 1.18, 0.6), 0.12, 6, 0.008, P.LINEN[3])
	for i in 8:
		var z := -1.2 + i * 0.24
		var top := Vector3(1.42, 1.2 - 0.48 * (1.0 - pow((z + 0.35) / 0.95, 2.0)) * 0.25, z)
		k.made.quad(top, top + Vector3(0.005, 0, 0.24), top + Vector3(0.03, -0.9 + Kit.j(s, i, 0.15), 0.24), top + Vector3(0.03, -0.85 + Kit.j(s, i + 9, 0.15), 0.0), P.SLATE[1] if i % 2 else P.INK[3])
		if i % 2 == 0:
			k.fleck(top + Vector3(0.02, 0.0, 0.02), top + Vector3(0.02, -0.05, 0.08), top + Vector3(0.05, -0.02, 0.05), P.RUST[4])
	for i in 3:
		k.made.prism(1.0, i * 0.22, -0.9, 0.2, 0.2 + i * 0.22, 0.17, 6, P.EARTH[2] if i % 2 else P.EARTH[3], P.INK[2])
	if lit:
		# At the far end of the door wall from the creels: the nets hang out at
		# x 1.42 from z -1.3 to 0.72 and stood squarely in front of the panel,
		# so the one thing that says somebody wired a machine into this shack
		# was drawn by no bearing the play camera can take.
		_wired(k, Vector3(0.79, 0.45, 0.76), Vector3(0.79, 0.45, 1.0), Vector3(1, 0, 0), Vector3(0.6, ry + 0.02, 1.1), NEON[0])
	banks(k, [[-0.6, 1.05, 0.4, 0.14], [0.7, 1.1, 0.35, 0.12]], d.drift[0], s + 70)


static func _stilt_hut(k: Kit, s: int, lit: bool, _d: BiomeDressing) -> void:
	var floor_y := 0.75
	# Stilts sunk in the black water, a ladder, a walkway plank out to firm ground.
	for sx: float in [-0.6, 0.6]:
		for sz: float in [-0.7, 0.7]:
			k.limb(Vector3(sx * 1.05, -0.25, sz * 1.05), Vector3(sx, floor_y, sz), 0.05, 0.04, 5, P.EARTH[1])
	k.slab(0.0, floor_y, 0.0, 1.5, 0.06, 1.7, s, P.EARTH[2], P.EARTH[3], 0.02)
	k.made.push(Transform3D(Basis.IDENTITY, Vector3(0, floor_y + 0.06, 0)))
	PropModels.Houses.walls(k, 1.15, 1.4, 0.8, s + 1, P.EARTH[2].lerp(P.MOSS[1], 0.3), P.EARTH[1], Vector3(-0.03, 0.0, 0.02))
	k.made.pop()
	# Reed thatch, heavy and shaggy, held down with a net of cable.
	var ry := floor_y + 0.86
	var dome := Vector3(0.0, ry - 0.12, 0.0)
	var dome_r := 1.05
	var dome_h := 0.75
	k.clump(dome.x, dome.y, dome.z, dome_r, dome_h, s + 2, P.EARTH[3].lerp(P.MOSS[2], 0.3), 9)
	var th := k.made.vertex_count()
	for i in 14:
		var a := float(i) / 14.0 * TAU
		var base := Vector3(cos(a) * 0.85, ry - 0.02, sin(a) * 0.95)
		k.blade(base, base * 1.18 + Vector3(0, -0.28, 0), 0.12, a + 1.57, P.EARTH[3] if i % 2 else P.SAND[3])
	k.sway_by_height(th, ry - 0.3, ry, 0.15)
	# Over the thatch, not through it: drawn as two chords lifted 0.2 the cables
	# ran INSIDE a dome 0.75 deep, so the net that is the whole reason this roof
	# stays on was never once drawn (tests/render/test_found_drawn.gd).
	_rope_over(k, dome, dome_r, dome_h, 0.6, P.INK[2])
	_rope_over(k, dome, dome_r, dome_h, 0.6 + PI * 0.5, P.INK[2])
	# The machine plate is on the ROOF, over a hole in the reeds and weighted
	# with a stone. On the door wall it sat under a thatch that overhangs by
	# half a tile, and at this camera's pitch that hides the whole wall.
	_thatch_patch(k, dome, dome_r, dome_h, -0.55, s + 7)
	k.made.quad(Vector3(0.6, floor_y + 0.07, 0.35), Vector3(0.6, floor_y + 0.07, 0.05), Vector3(0.6, floor_y + 0.7, 0.05), Vector3(0.6, floor_y + 0.7, 0.35), P.INK[2])
	for i in 5:
		var y := i * 0.17
		k.limb(Vector3(0.95 + y * 0.35, y - 0.1, 0.05), Vector3(0.95 + y * 0.35, y - 0.1, 0.35), 0.018, 0.018, 4, P.EARTH[2])
	k.limb(Vector3(0.95, -0.1, 0.03), Vector3(0.62, floor_y, 0.03), 0.02, 0.02, 4, P.EARTH[1])
	k.limb(Vector3(0.95, -0.1, 0.37), Vector3(0.62, floor_y, 0.37), 0.02, 0.02, 4, P.EARTH[1])
	k.slab(1.6, -0.08, -0.5, 1.6, 0.05, 0.28, s + 5, P.EARTH[2], P.EARTH[3], 0.03)
	# Black water under it, a green scum at the rim.
	_pool(k, Vector3(0.0, 0.0, 0.0), 1.2, s + 6)
	if lit:
		_wired(k, Vector3(0.6, floor_y + 0.12, -0.45), Vector3(0.6, floor_y + 0.12, -0.12), Vector3(1, 0, 0), Vector3(-0.2, ry + 0.4, 0.0), NEON[2])


## A cable pulled over a thatch dome along `ang`, following the dome's own
## surface (`Kit.clump_top`) and pegged past the eave at both ends.
## **NOT TAGGED ROPE, AND THE NAME IS THE TRAP.** This draws with `k.rod`, and
## `Kit.rod` is `found.strut` — the FOUND pen. FIVE of Kit's helpers draw into
## FOUND and `kit.gd`'s own header names them all; this line said "only two" for
## one commit, from a grep that read two lines past each `func` and stopped,
## which is how a sentence gets to be precise and wrong at the same time. A
## made mark is alpha 0.314..0.361 and `found.gdshader` reads anything under 0.5
## as a beacon that BLINKS on the machines' beat, so tagging the obvious material
## here would put a flashing lamp over every thatch dome in the game, and nothing
## would raise an error. Read the PEN, never the function name: the thing a
## player sees as a rope lashed over a roof is drawn as ruled machine stock.
static func _rope_over(k: Kit, centre: Vector3, r: float, h: float, ang: float, col: Color) -> void:
	var dir := Vector3(cos(ang), 0.0, sin(ang))
	var pts := PackedVector3Array()
	for i in 9:
		var u := -1.0 + float(i) * 0.25
		var p := centre + dir * r * u
		p.y = centre.y + h * Kit.clump_top(absf(u)) + 0.05
		pts.append(p)
	for i in pts.size() - 1:
		k.rod(pts[i], pts[i + 1], 0.011, 3, col)
	for e: int in [0, pts.size() - 1]:
		k.rod(pts[e], pts[e] + dir * (0.14 if e > 0 else -0.14) + Vector3(0, -0.24, 0), 0.01, 3, col)


## A sheet of plate laid over a hole in a thatch dome on the `ang` side of it,
## lying on the dome's own surface, with a stone on it to hold it down.
static func _thatch_patch(k: Kit, centre: Vector3, r: float, h: float, ang: float, s: int) -> void:
	var dir := Vector3(cos(ang), 0.0, sin(ang))
	var side := Vector3(-sin(ang), 0.0, cos(ang))
	var corners: Array[Vector3] = []
	for c: Vector2 in [Vector2(0.18, 0.30), Vector2(0.66, 0.24), Vector2(0.62, -0.30), Vector2(0.14, -0.26)]:
		var p := centre + dir * (r * c.x) + side * (r * c.y)
		p.y = centre.y + h * Kit.clump_top(c.length()) + 0.06
		corners.append(p)
	patch(k, corners[0], corners[1], corners[2], corners[3], 2)
	var mid := (corners[0] + corners[1] + corners[2] + corners[3]) * 0.25
	k.stone(mid.x, mid.y, mid.z, 0.11, 0.1, s, P.STONE[2], 5)


## A still pool of black water with a green rim, lying flat on the ground.
static func _pool(k: Kit, at: Vector3, r: float, s: int) -> void:
	var ring: Array[Vector3] = []
	var rim: Array[Vector3] = []
	for i in 12:
		var a := float(i) / 12.0 * TAU
		var rr := r * (0.8 + Rng.hash01(s, i) * 0.35)
		ring.append(at + Vector3(cos(a) * rr, 0.012, sin(a) * rr))
		rim.append(at + Vector3(cos(a) * (rr + 0.09), 0.008, sin(a) * (rr + 0.09)))
	for i in 12:
		var n := (i + 1) % 12
		k.made.tri(at + Vector3(0, 0.012, 0), ring[n], ring[i], P.BRINE[0])
		k.made.quad(ring[i], ring[n], rim[n], rim[i], P.SPRUCE[2])


static func _blind(k: Kit, s: int, lit: bool, _d: BiomeDressing) -> void:
	# A platform up among the trunks on four poles, a screen of cut boughs
	# round it, a ladder, a tarp roof tied down.
	var fy := 1.3
	for sx: float in [-0.45, 0.45]:
		for sz: float in [-0.45, 0.45]:
			k.limb(Vector3(sx * 1.3, -0.05, sz * 1.3), Vector3(sx, fy + 0.8, sz), 0.045, 0.035, 5, P.EARTH[1])
	k.limb(Vector3(-0.58, 0.4, -0.58), Vector3(0.58, 0.9, 0.58), 0.025, 0.025, 4, P.EARTH[2])
	k.limb(Vector3(0.58, 0.4, -0.58), Vector3(-0.58, 0.9, 0.58), 0.025, 0.025, 4, P.EARTH[2])
	k.slab(0.0, fy, 0.0, 1.2, 0.06, 1.2, s, P.EARTH[2], P.EARTH[3], 0.02)
	for side in 4:
		var a := float(side) * PI * 0.5
		var out := Vector3(cos(a), 0, sin(a))
		var along := Vector3(-sin(a), 0, cos(a))
		for i in 5:
			var base := out * 0.6 + along * (-0.48 + i * 0.24) + Vector3(0, fy + 0.04, 0)
			k.blade(base, base + Vector3(0, 0.55 + Kit.j(s, side * 10 + i, 0.1), 0) + out * 0.08, 0.28, a + PI * 0.5, P.SPRUCE[2] if (i + side) % 2 else P.SPRUCE[1])
	# The shooting slot left open on the front.
	k.made.quad(Vector3(0.62, fy + 0.35, -0.2), Vector3(0.62, fy + 0.35, 0.2), Vector3(0.62, fy + 0.45, 0.2), Vector3(0.62, fy + 0.45, -0.2), P.INK[1])
	var ty := fy + 0.85
	both(k.made, Vector3(-0.7, ty, -0.7), Vector3(0.7, ty - 0.12, -0.7), Vector3(0.7, ty - 0.12, 0.7), Vector3(-0.7, ty, 0.7), P.EARTH[3].lerp(P.SPRUCE[3], 0.45))
	for i in 7:
		var y := i * 0.19
		k.limb(Vector3(0.95 - y * 0.2, y, -0.18), Vector3(0.95 - y * 0.2, y, 0.18), 0.016, 0.016, 4, P.EARTH[2])
	k.limb(Vector3(1.0, -0.05, -0.2), Vector3(0.66, fy, -0.2), 0.02, 0.02, 4, P.EARTH[1])
	k.limb(Vector3(1.0, -0.05, 0.2), Vector3(0.66, fy, 0.2), 0.02, 0.02, 4, P.EARTH[1])
	# Skins stretched on a frame by the ladder, and a bucket.
	k.made.quad(Vector3(-0.9, 0.1, 0.9), Vector3(-0.3, 0.1, 1.05), Vector3(-0.28, 0.75, 1.02), Vector3(-0.92, 0.7, 0.88), P.EARTH[3])
	if lit:
		_wired(k, Vector3(0.62, fy + 0.05, 0.25), Vector3(0.62, fy + 0.05, 0.55), Vector3(1, 0, 0), Vector3(0.0, ty, 0.0), NEON[0])


static func _pod(k: Kit, s: int, lit: bool, d: BiomeDressing) -> void:
	# Half under whatever this land buries a thing in.
	var over: Color = d.snow[0] if d.cold() else d.drift[0]
	# An emergency shelter from before: a ribbed shell, once orange, half
	# under the snow, a hatch dug clear, a flue and a flag on a pole.
	var shell := P.RUST[3].lerp(P.LINEN[3], 0.45)
	var ribs := 7
	for i in ribs:
		var x0 := -1.1 + i * (2.2 / ribs)
		var x1 := x0 + 2.2 / ribs
		var col := shell if i % 2 == 0 else GroundColors.down(shell, 0.18)
		for j in 6:
			var a0 := PI * float(j) / 6.0
			var a1 := PI * float(j + 1) / 6.0
			var p0 := Vector3(0, sin(a0) * 0.9 - 0.2, cos(a0) * 0.9)
			var p1 := Vector3(0, sin(a1) * 0.9 - 0.2, cos(a1) * 0.9)
			k.made.quad(Vector3(x0, p0.y, p0.z), Vector3(x1, p0.y, p0.z), Vector3(x1, p1.y, p1.z), Vector3(x0, p1.y, p1.z), col)
	for i in 12:
		var a0 := PI * float(i) / 12.0
		var a1 := PI * float(i + 1) / 12.0
		k.fleck(Vector3(1.1, -0.2, 0), Vector3(1.1, sin(a0) * 0.9 - 0.2, cos(a0) * 0.9), Vector3(1.1, sin(a1) * 0.9 - 0.2, cos(a1) * 0.9), GroundColors.down(shell, 0.1))
	# The hatch on the end, the letters of an old aid mark worn to blocks.
	k.made.quad(Vector3(1.11, -0.1, 0.3), Vector3(1.11, -0.1, -0.3), Vector3(1.11, 0.5, -0.25), Vector3(1.11, 0.5, 0.25), P.INK[2])
	# An aid cross once, worn down to two pale bars on the flank.
	k.made.quad(Vector3(0.1, 0.52, 0.6), Vector3(0.6, 0.52, 0.6), Vector3(0.6, 0.62, 0.53), Vector3(0.1, 0.62, 0.53), P.LINEN[5])
	k.made.quad(Vector3(0.3, 0.38, 0.69), Vector3(0.4, 0.38, 0.69), Vector3(0.4, 0.76, 0.43), Vector3(0.3, 0.76, 0.43), P.LINEN[5])
	k.limb(Vector3(-0.4, 0.55, -0.3), Vector3(-0.38, 1.2, -0.3), 0.05, 0.045, 6, P.INK[2])
	patch(k, Vector3(-0.8, 0.55, -0.52), Vector3(-0.3, 0.65, -0.52), Vector3(-0.3, 0.3, -0.8), Vector3(-0.8, 0.2, -0.8), 3)
	k.limb(Vector3(1.4, -0.1, -0.7), Vector3(1.42, 1.6, -0.7), 0.025, 0.02, 4, P.SLATE[2])
	k.fleck(Vector3(1.42, 1.55, -0.7), Vector3(1.75, 1.45, -0.62), Vector3(1.42, 1.35, -0.7), P.RUST[3])
	banks(k, [[-0.9, 0.6, 0.8, 0.55], [0.0, 0.8, 0.9, 0.5], [-0.9, -0.6, 0.7, 0.45], [0.2, -0.85, 0.8, 0.4], [-1.3, 0.0, 0.6, 0.6], [1.3, 0.75, 0.4, 0.2]], over, s + 40)
	k.clump(-0.3, 0.45, 0.0, 0.7, 0.3, s + 50, over, 8)
	if lit:
		_wired(k, Vector3(1.12, 0.05, 0.42), Vector3(1.12, 0.05, 0.75), Vector3(1, 0, 0), Vector3(0.3, 0.68, 0.0), NEON[1])


static func _lean_to(k: Kit, s: int, lit: bool, d: BiomeDressing) -> void:
	# A dry-stone wall against a cast slab, tin laid across weighted with
	# stones, a barrel for water, a goat-hide door.
	var stone := d.walling
	PropModels.Houses.rubble_wall(k, Vector2(-0.9, -0.8), Vector2(0.9, -0.85), PackedFloat32Array([1.0, 1.05, 1.0, 0.95, 0.9, 0.85, 0.8]), 0.3, s, stone)
	PropModels.Houses.rubble_wall(k, Vector2(-0.95, -0.7), Vector2(-0.9, 0.8), PackedFloat32Array([1.0, 0.95, 0.9, 0.9, 0.85, 0.8, 0.75]), 0.3, s + 1, stone)
	PropModels.Houses.rubble_wall(k, Vector2(-0.8, 0.85), Vector2(0.2, 0.9), PackedFloat32Array([0.75, 0.7, 0.72, 0.6]), 0.28, s + 2, stone)
	corrugated(k.made, Vector3(-1.1, 1.08, -1.0), Vector3(0.0, 0.0, 2.05), Vector3(2.0, -0.35, 0.0), 11, P.RUST[3].lerp(P.LINEN[3], 0.3))
	k.made.quad(Vector3(-1.1, 1.08, -1.0), Vector3(0.9, 0.73, -1.0), Vector3(0.9, 0.73, 1.05), Vector3(-1.1, 1.08, 1.05), P.INK[2])
	for i in 4:
		k.stone(-0.6 + i * 0.4, 1.02 - i * 0.07, -0.4 + (i % 2) * 0.6, 0.12, 0.1, s + 10 + i, P.LINEN[4], 5)
	k.made.quad(Vector3(0.85, 0.0, 0.1), Vector3(0.85, 0.0, -0.55), Vector3(0.88, 0.72, -0.55), Vector3(0.88, 0.72, 0.1), P.EARTH[3])
	k.made.prism(1.25, 0.0, 0.6, 0.24, 0.62, 0.22, 9, P.RUST[2], P.INK[1])
	for i in 2:
		k.made.prism(1.25, 0.15 + i * 0.3, 0.6, 0.245, 0.18 + i * 0.3, 0.245, 9, P.INK[2])
	if lit:
		_wired(k, Vector3(0.9, 0.3, 0.2), Vector3(0.9, 0.3, 0.55), Vector3(1, 0, 0), Vector3(-0.2, 0.95, 0.0), NEON[2])
	banks(k, [[-0.4, -1.1, 0.5, 0.18], [0.8, -1.0, 0.4, 0.14]], d.drift[0], s + 30)


static func _dugout(k: Kit, s: int, lit: bool, d: BiomeDressing) -> void:
	# Dug into the ash for the heat: a roof of machine plate on ribs, banked
	# over with ash, a heat shield of plate at the door, a pipe breathing.
	banks(k, [[-0.7, -0.7, 0.8, 0.5], [0.3, -0.8, 0.8, 0.45], [-0.8, 0.6, 0.8, 0.5], [0.4, 0.75, 0.7, 0.42], [-1.1, 0.0, 0.7, 0.6]], d.drift[0], s + 1)
	for i in 4:
		var x := -0.8 + i * 0.5
		k.limb(Vector3(x, 0.1, -0.75), Vector3(x, 0.85, 0.0), 0.04, 0.035, 4, P.INK[2])
		k.limb(Vector3(x, 0.85, 0.0), Vector3(x, 0.1, 0.75), 0.035, 0.03, 4, P.INK[2])
	# One face per slope, turned to the sky: this roof is dug into the ash with
	# the bank closed over both sides, so its undersides were never reachable.
	patch(k, Vector3(-0.95, 0.9, 0.05), Vector3(0.75, 0.9, 0.05), Vector3(0.75, 0.35, -0.55), Vector3(-0.95, 0.35, -0.55), 2)
	patch(k, Vector3(0.75, 0.9, -0.03), Vector3(-0.95, 0.9, -0.03), Vector3(-0.95, 0.35, 0.55), Vector3(0.75, 0.35, 0.55), 3)
	k.clump(-0.4, 0.6, 0.0, 0.6, 0.35, s + 5, d.drift[0], 8)
	k.made.quad(Vector3(0.78, 0.0, 0.3), Vector3(0.78, 0.0, -0.3), Vector3(0.78, 0.6, -0.2), Vector3(0.78, 0.6, 0.2), P.INK[1])
	k.plate(Vector3(1.05, 0.0, -0.55), Vector3(1.05, 0.0, -0.2), Vector3(1.0, 0.75, -0.2), Vector3(1.0, 0.75, -0.55), P.PLATE[3], P.PLATE[1], P.PLATE[5])
	k.limb(Vector3(0.1, 0.8, 0.3), Vector3(0.15, 1.4, 0.32), 0.05, 0.05, 6, P.RUST[1])
	k.made.prism(0.15, 1.4, 0.32, 0.055, 1.42, 0.055, 6, P.INK[0], GroundColors.glow(P.EMBER[3], 0.8))
	if lit:
		_wired(k, Vector3(0.8, 0.1, 0.35), Vector3(0.8, 0.1, 0.6), Vector3(1, 0, 0), Vector3(-0.3, 0.9, 0.0), NEON[1])


static func _infill(k: Kit, s: int, lit: bool, d: BiomeDressing) -> void:
	# The Ruined Metropolis's shelter: a bay of a dead tower's ground floor —
	# two cast columns and the lintel between them, CONCRETE — walled in with
	# salvaged doors, each its own colour and its own lean, one of them ajar,
	# and a sheet of machine plate laid from the lintel back to a rubble wall.
	# A shape a city gives away for nothing: nobody here builds a hut when a
	# frame is standing on every block.
	var con := GroundColors.made(d.concrete, GroundColors.CONCRETE)
	for sz: float in [-1.0, 1.0]:
		k.slab(-0.2, 0.0, sz * 0.95, 0.32, 2.2 + Kit.j(s, int(sz) + 1, 0.1), 0.32, s + int(sz), GroundColors.down(con, 0.1), GroundColors.up(con, 0.12), 0.03, 0.0, Kit.j(s, int(sz) + 4, 0.02))
	k.slab(-0.2, 2.15, 0.0, 0.4, 0.3, 2.3, s + 3, con, GroundColors.up(con, 0.15), 0.03)
	# The reinforcement out of the columns' tops: the tower went on up from here.
	PropModels.Rocks._rebar(k, [Vector3(-0.2, 2.45, -0.9), Vector3(-0.15, 2.45, 0.95), Vector3(-0.25, 2.45, 0.2)],
		[Vector3(-0.35, 2.75, -1.1), Vector3(0.0, 2.7, 1.05), Vector3(-0.5, 2.65, 0.3)])
	# The doors across the bay, TIMBER: three of them, the middle one ajar on
	# its hinge, the dark of the room showing in the gap.
	var doors: Array[Color] = [GroundColors.made(P.EARTH[2], GroundColors.TIMBER), GroundColors.made(d.timber[0], GroundColors.TIMBER),
		GroundColors.made(P.SLATE[2].lerp(P.EARTH[1], 0.4), GroundColors.TIMBER)]
	_facing_quad(k.made, Vector3(-0.02, 0.0, 0.8), Vector3(-0.02, 0.0, -0.8), Vector3(0, 2.0, 0), Vector3(1, 0, 0), P.INK[0])
	for i in 3:
		var z0 := 0.78 - i * 0.54
		var col: Color = doors[i]
		if i == 1:
			# Ajar: swung out on the hinge at its edge, so the wall has a gap in it.
			var hinge := Vector3(0.0, 0.0, z0)
			var swing := Vector3(0.36, 0.0, -0.38)
			_facing_quad(k.made, hinge, hinge + swing, Vector3(0, 1.95, 0), Vector3(0.7, 0, 0.7), col)
			_facing_quad(k.made, hinge + swing, hinge, Vector3(0, 1.95, 0), Vector3(-0.7, 0, -0.7), GroundColors.down(col, 0.2))
			k.made.strut(hinge + Vector3(0, 0.9, 0) + swing * 0.9, hinge + Vector3(0.02, 0.98, 0) + swing * 0.9, 0.02, 4, P.COPPER[3])
			continue
		var tilt := Kit.j(s, i + 10, 0.03)
		_facing_quad(k.made, Vector3(0.02 + tilt, 0.0, z0), Vector3(0.02 - tilt, 0.0, z0 - 0.52), Vector3(0.03, 1.98 + Kit.j(s, i + 14, 0.06), 0), Vector3(1, 0, 0), col)
		# A panel line and a handle, so a door reads as a door and not a board.
		_facing_quad(k.made, Vector3(0.04 + tilt, 0.5, z0 - 0.06), Vector3(0.04 - tilt, 0.5, z0 - 0.46), Vector3(0, 0.9, 0), Vector3(1, 0, 0), GroundColors.down(col, 0.25))
		k.made.strut(Vector3(0.05, 0.95, z0 - 0.44), Vector3(0.05, 1.03, z0 - 0.44), 0.018, 4, P.COPPER[3])
	# The roof: a sheet of machine plate from the lintel back to the wall,
	# weighted with rubble, and the rubble wall it rests on at the back.
	patch(k, Vector3(-0.1, 2.32, 1.12), Vector3(-0.1, 2.32, -1.12), Vector3(-1.6, 1.6, -1.05), Vector3(-1.6, 1.6, 1.05), 2)
	PropModels.Houses.rubble_wall(k, Vector2(-1.6, -1.0), Vector2(-1.6, 1.0), PackedFloat32Array([1.5, 1.55, 1.5, 1.45, 1.5]), 0.3, s + 20, d.walling)
	for i in 3:
		k.stone(-0.6 - i * 0.4, 2.3 - i * 0.2, -0.5 + (i % 2) * 0.9, 0.11, 0.09, s + 30 + i, GroundColors.down(d.concrete, 0.12), 5)
	# The side walls: plate on one side, boards on the other, under the roof.
	patch(k, Vector3(-0.2, 0.0, -1.14), Vector3(-1.5, 0.0, -1.1), Vector3(-1.5, 1.5, -1.1), Vector3(-0.2, 2.1, -1.14), 3)
	for i in 4:
		var y := 0.2 + i * 0.5
		k.made.quad(Vector3(-0.2, y, 1.14), Vector3(-1.5, y - 0.1, 1.11), Vector3(-1.5, y + 0.32, 1.11), Vector3(-0.2, y + 0.4, 1.14), doors[(i + 1) % 3] if i != 2 else GroundColors.down(doors[0], 0.3))
	# A stovepipe out through the plate, a drum for water by the door.
	k.limb(Vector3(-0.9, 1.9, 0.5), Vector3(-0.88, 2.7, 0.52), 0.05, 0.05, 6, P.RUST[1])
	k.made.prism(-0.88, 2.7, 0.52, 0.055, 2.72, 0.055, 6, P.INK[0], GroundColors.glow(P.EMBER[3], 0.6))
	k.made.prism(0.5, 0.0, -1.1, 0.22, 0.6, 0.2, 9, P.RUST[2], P.INK[1])
	if lit:
		_wired(k, Vector3(0.62, 0.35, 0.55), Vector3(0.62, 0.35, 0.9), Vector3(1, 0, 0), Vector3(-0.1, 2.35, 0.0), NEON[0])
	banks(k, [[0.3, 1.0, 0.5, 0.16], [-1.0, -1.2, 0.5, 0.14]], d.drift[0], s + 40)


# --- vehicles ------------------------------------------------------------------

## A car (0) or a van (1) from before, and what each landscape did to it:
## drowned at the tide line, nose down in the bog, grown over in the pines,
## buried in snow, scoured to primer in the bonelands, burnt out in the
## burning. Never a box: wheel arches cut out of the body, the roof caved in,
## the glass gone to black holes with shards in the frames, a door missing on
## the car and the bonnet torn off to the engine, the van's back doors hanging,
## and the whole of it tipped into the ground.
static func vehicle(k: Kit, v: int, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var burnt := BiomeDressing.burnt(c)
	var s := 21500 + v * 19 + c * 5
	# Body paint as it was, and what the years here did to it.
	var paint: Color = [P.SPRUCE[2].lerp(P.SLATE[3], 0.5), P.RUST[3].lerp(P.LINEN[3], 0.4), P.LINEN[3], P.SLATE[3]][(v + c) % 4]
	# How deep a heavy thing settles here, and how it lies once it has.
	var sink := dress.sink
	var tilt := Basis(Vector3.BACK, dress.lie.x) * Basis(Vector3.RIGHT, dress.lie.y)
	# Rubber does not last where the sun takes the colour out of things, and
	# nothing rubber survives a fire at all: those stand on their rims.
	var wheels := not burnt and not dress.perishes()
	var cave := 0.24 if burnt else (0.18 if dress.covers == &"needles" else 0.1)
	if burnt:
		# Burnt to bare metal gone to rust and ash, lighter than the ash it sits in.
		paint = P.RUST[2].lerp(P.ASH[2], 0.45)
	elif dress.perishes():
		paint = dress.bleach.lerp(paint, 0.25)
	else:
		match dress.covers:
			&"wrack": paint = paint.lerp(P.RUST[2], 0.45)
			&"weed": paint = paint.lerp(drift_of(c)[1], 0.55)
			&"needles": paint = paint.lerp(dress.growth, 0.3)
	var van := v % 2 == 1
	var hw := 0.56 if van else 0.5
	var hole := P.INK[0]
	var inside := P.INK[1]
	# The body's side profile (x along, y up) run clockwise from the rear foot,
	# the wheel arches cut out of it.
	var arch := func(cx: float) -> Array[Vector2]:
		var out: Array[Vector2] = []
		for e in 5:
			var a := PI * float(e) / 4.0
			out.append(Vector2(cx + cos(a) * 0.26, 0.24 + sin(a) * 0.22))
		return out
	var lower: Array[Vector2] = []
	var rear := -1.35 if van else -1.26
	var front := 1.38 if van else 1.28
	var belt := 0.76 if van else 0.63
	lower.append(Vector2(rear + 0.02, 0.26))
	lower.append(Vector2(rear, belt - 0.1))
	lower.append(Vector2(rear + 0.1, belt))
	if van:
		lower.append(Vector2(0.95, belt))
		lower.append(Vector2(1.3, belt - 0.1))
	else:
		lower.append(Vector2(0.58, belt + 0.01))
		lower.append(Vector2(1.16, belt - 0.07))
	lower.append(Vector2(front, belt - 0.2))
	lower.append(Vector2(front - 0.02, 0.26))
	for q: Vector2 in arch.call(0.82):
		lower.append(q)
	for q: Vector2 in arch.call(-0.82):
		lower.append(q)
	var poly := PackedVector2Array(lower)
	var tris := Geometry2D.triangulate_polygon(poly)
	# Some were rolled onto their side, which shows the car's whole profile
	# (arches, glass, pillars) to anyone looking down on it.
	var rolled := burnt or (dress.perishes() and van)
	if rolled:
		k.made.push(Transform3D(Basis(Vector3.UP, 0.08) * Basis(Vector3.RIGHT, PI * 0.5 - 0.12), Vector3(0.0, hw - 0.06, -0.55)))
	else:
		k.made.push(Transform3D(tilt, Vector3(0, -sink, 0)))
	var n := lower.size()
	for i in n:
		var j := (i + 1) % n
		var a := lower[i]
		var b := lower[j]
		var col := paint
		if b.y < 0.3 and a.y < 0.3:
			col = P.INK[2]
		elif i == 0 or (a.x > 0.9 and b.x > 0.9):
			col = GroundColors.down(paint, 0.2)
		elif a.y < 0.47 and b.y < 0.47:
			# The arches' inner lips: dark, the tyre shows in them.
			col = inside
		k.made.quad(Vector3(a.x, a.y, hw), Vector3(b.x, b.y, hw), Vector3(b.x, b.y, -hw), Vector3(a.x, a.y, -hw), col)
	for t in range(0, tris.size(), 3):
		var a := poly[tris[t]]
		var b := poly[tris[t + 1]]
		var cc := poly[tris[t + 2]]
		if (b - a).cross(cc - a) < 0.0:
			var tmp := b
			b = cc
			cc = tmp
		k.made.tri(Vector3(a.x, a.y, hw), Vector3(b.x, b.y, hw), Vector3(cc.x, cc.y, hw), paint)
		k.made.tri(Vector3(a.x, a.y, -hw), Vector3(cc.x, cc.y, -hw), Vector3(b.x, b.y, -hw), GroundColors.down(paint, 0.18))
	# The cabin on the belt: the roof caved in at its middle, the glass gone.
	var cin := 0.08 if van else 0.14
	var base0 := rear + 0.14
	var base1 := 0.9 if van else 0.56
	var top0 := rear + 0.05 if van else -0.74
	var top1 := 0.6 if van else 0.04
	var roof_y := 1.28 if van else 1.0
	var bz := hw - 0.03
	var tz := hw - cin
	var c0 := Vector3(base0, belt, bz)
	var c1 := Vector3(base1, belt, bz)
	var c2 := Vector3(top1, roof_y, tz)
	var c3 := Vector3(top0, roof_y, tz)
	var mid_x := lerpf(top0, top1, 0.45)
	var cm := Vector3(mid_x, roof_y - cave, tz * 0.92)
	var m := Vector3(1, 1, -1)
	var roof := GroundColors.up(paint, 0.2)
	if burnt:
		# The roof burnt away to its rails: the black cab open to the sky, the
		# seats' bare springs in it.
		k.made.quad(Vector3(top0, belt + 0.03, tz), Vector3(top1 + 0.2, belt + 0.03, tz), Vector3(top1 + 0.2, belt + 0.03, -tz), Vector3(top0, belt + 0.03, -tz), hole)
		for sz: float in [1.0, -1.0]:
			var mz := Vector3(1, 1, sz)
			k.limb(c3 * mz, cm * mz, 0.035, 0.035, 4, roof)
			k.limb(cm * mz, c2 * mz, 0.035, 0.035, 4, roof)
		k.limb(c3, c3 * m, 0.03, 0.03, 4, roof)
		k.limb(c2, c2 * m, 0.03, 0.03, 4, roof)
		for sx: float in [-0.45, 0.15]:
			for sz: float in [0.22, -0.22]:
				k.limb(Vector3(sx, belt + 0.04, sz - 0.14), Vector3(sx - 0.12, belt + 0.38, sz - 0.12), 0.018, 0.018, 3, P.RUST[1])
				k.limb(Vector3(sx, belt + 0.04, sz + 0.14), Vector3(sx - 0.12, belt + 0.38, sz + 0.12), 0.018, 0.018, 3, P.RUST[1])
				k.limb(Vector3(sx - 0.12, belt + 0.38, sz - 0.12), Vector3(sx - 0.12, belt + 0.38, sz + 0.12), 0.018, 0.018, 3, P.RUST[1])
	else:
		k.made.quad(c3, cm, cm * m, c3 * m, roof)
		k.made.quad(cm, c2, c2 * m, cm * m, GroundColors.down(roof, 0.12))
		# A dent's crease across the cave.
		k.made.quad(cm + Vector3(-0.03, 0.012, 0.0), cm + Vector3(0.03, 0.012, 0.0), cm * m + Vector3(0.03, 0.012, 0.0), cm * m + Vector3(-0.03, 0.012, 0.0), P.INK[2])
	# The screen: a black hole in its frame, shards left in the corners.
	var narrow := Vector3(1, 1, 0.84)
	var scr := [c1.lerp(c2, 0.9) * narrow, c1.lerp(c2, 0.1) * narrow, (c1 * m).lerp(c2 * m, 0.1) * narrow, (c1 * m).lerp(c2 * m, 0.9) * narrow]
	k.made.quad(c2, c1, c1 * m, c2 * m, paint)
	_glass_gone(k, scr, Vector3(1, 0.6, 0).normalized(), s, not burnt)
	# Back: the car's rear glass, the van's panelled back with its doors.
	k.made.quad(c0, c3, c3 * m, c0 * m, paint if van else GroundColors.down(paint, 0.1))
	if not van:
		var back := [c0.lerp(c3, 0.12) * narrow, c0.lerp(c3, 0.88) * narrow, (c0 * m).lerp(c3 * m, 0.88) * narrow, (c0 * m).lerp(c3 * m, 0.12) * narrow]
		_glass_gone(k, back, Vector3(-1, 0.6, 0).normalized(), s + 3, not burnt)
	# The flanks of the cabin, each with its lights gone to holes.
	k.made.quad(c0, c1, c2, cm, paint)
	k.made.tri(c0, cm, c3, paint)
	k.made.quad(c1 * m, c0 * m, cm * m, c2 * m, GroundColors.down(paint, 0.18))
	k.made.tri(c0 * m, c3 * m, cm * m, GroundColors.down(paint, 0.18))
	for sz: float in [1.0, -1.0]:
		var q0 := c0 * Vector3(1, 1, sz)
		var q1 := c1 * Vector3(1, 1, sz)
		var q2 := c2 * Vector3(1, 1, sz)
		var q3 := c3 * Vector3(1, 1, sz)
		var nrm := (q1 - q0).cross(q3 - q0).normalized() * (0.014 * sz)
		var u0 := 0.62 if van else 0.1
		var u1 := 0.94 if van else 0.9
		var cell := func(ua: float, ub: float, lo: float, hi: float) -> Array:
			return [q0.lerp(q1, ua).lerp(q3.lerp(q2, ua), lo) + nrm, q0.lerp(q1, ub).lerp(q3.lerp(q2, ub), lo) + nrm, q0.lerp(q1, ub).lerp(q3.lerp(q2, ub), hi) + nrm, q0.lerp(q1, ua).lerp(q3.lerp(q2, ua), hi) + nrm]
		var lights: Array = [cell.call(u0, u1, 0.16, 0.8)] if van else [cell.call(u0, 0.47, 0.16, 0.8), cell.call(0.55, u1, 0.16, 0.8)]
		for li in lights.size():
			var w4: Array = lights[li]
			if sz < 0.0:
				w4 = [w4[1], w4[0], w4[3], w4[2]]
			_glass_gone(k, w4, Vector3(0, 0, sz), s + 10 + li + int(sz), not burnt)
		var fz := (hw + 0.012) * sz
		# A seam, rust along the sill.
		var sa := Vector3(-0.5, 0.27, fz * 1.01)
		var sb := Vector3(0.45, 0.27, fz * 1.01)
		if sz > 0.0:
			k.made.quad(sa, sb, sb + Vector3(-0.1, 0.1, 0), sa + Vector3(0.12, 0.09, 0), P.RUST[2])
		else:
			k.made.quad(sb, sa, sa + Vector3(0.12, 0.09, 0), sb + Vector3(-0.1, 0.1, 0), P.RUST[2])
	if not van:
		# The near front door is gone: the hole into the cab, the seat's back in it.
		var dz := hw + 0.016
		k.made.quad(Vector3(0.02, 0.3, dz), Vector3(0.56, 0.3, dz), Vector3(0.56, belt - 0.01, dz), Vector3(0.02, belt - 0.01, dz), hole)
		k.made.quad(Vector3(0.12, 0.36, dz + 0.004), Vector3(0.3, 0.36, dz + 0.004), Vector3(0.26, belt - 0.03, dz + 0.004), Vector3(0.1, belt - 0.05, dz + 0.004), P.EARTH[1])
		# The bonnet torn off: the engine bay open, the block and its pipes in it.
		var bx0 := 0.66
		var bx1 := 1.1
		var by0 := belt + 0.01 - (bx0 - 0.58) / 0.58 * 0.08 + 0.012
		var by1 := belt + 0.01 - (bx1 - 0.58) / 0.58 * 0.08 + 0.012
		var bz0 := hw - 0.08
		k.made.quad(Vector3(bx0, by0, bz0), Vector3(bx1, by1, bz0), Vector3(bx1, by1, -bz0), Vector3(bx0, by0, -bz0), hole)
		k.slab(0.92, belt - 0.2, 0.0, 0.34, 0.24, 0.5, s + 41, P.RUST[1], P.STONE[1], 0.02)
		k.made.prism(0.8, belt - 0.02, 0.28, 0.035, belt + 0.1, 0.035, 5, P.RUST[2])
	else:
		# The van's back doors: one hanging open on a hinge, the load space black.
		var dz := rear - 0.012
		k.made.quad(Vector3(dz, 0.3, -hw + 0.06), Vector3(dz, 0.3, hw - 0.06), Vector3(dz, roof_y - 0.08, tz - 0.04), Vector3(dz, roof_y - 0.08, -tz + 0.04), hole)
		k.made.quad(Vector3(rear - 0.5, 0.3, hw + 0.36), Vector3(rear, 0.3, hw), Vector3(rear, roof_y - 0.1, tz), Vector3(rear - 0.46, roof_y - 0.12, hw + 0.3), paint)
		k.made.quad(Vector3(rear, 0.3, hw), Vector3(rear - 0.5, 0.3, hw + 0.36), Vector3(rear - 0.46, roof_y - 0.12, hw + 0.3), Vector3(rear, roof_y - 0.1, tz), GroundColors.down(paint, 0.3))
		# A faded panel on the load side, where a name was painted.
		k.made.quad(Vector3(-0.9, 0.55, hw + 0.014), Vector3(0.3, 0.55, hw + 0.014), Vector3(0.3, belt - 0.06, hw + 0.014), Vector3(-0.9, belt - 0.06, hw + 0.014), paint.lerp(P.LINEN[4], 0.25))
	# Lamps: dead headlights, the red of a tail light.
	for sz: float in [0.3, -0.3]:
		k.made.quad(Vector3(front + 0.012, 0.42, sz - 0.09), Vector3(front + 0.012, 0.42, sz + 0.09), Vector3(front + 0.006, 0.5, sz + 0.09), Vector3(front + 0.006, 0.5, sz - 0.09), hole if burnt else P.LINEN[2])
		k.made.quad(Vector3(rear - 0.014, 0.46, sz + 0.09), Vector3(rear - 0.014, 0.46, sz - 0.09), Vector3(rear - 0.014, 0.54, sz - 0.09), Vector3(rear - 0.014, 0.54, sz + 0.09), P.RUST[1])
	if wheels:
		for wx: float in [-0.82, 0.82]:
			for wz: float in [hw - 0.1, -hw + 0.1]:
				# Tyres gone flat: squashed on the ground, a rim showing.
				wheel(k, Vector3(wx, 0.19, wz), 0.2, 0.16, P.INK[2], P.STONE[2])
	else:
		for wx: float in [-0.82, 0.82]:
			for wz: float in [hw - 0.12, -hw + 0.12]:
				k.made.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(wx, 0.16, wz - 0.04)))
				k.made.prism(0, 0, 0, 0.12, 0.08, 0.12, 7, P.RUST[1], P.STONE[1])
				k.made.pop()
	if burnt:
		# Scorch run up the flanks from where it burnt.
		for i in 4:
			var x := -1.0 + i * 0.55
			k.made.quad(Vector3(x, 0.3, hw + 0.02), Vector3(x + 0.3, 0.3, hw + 0.02), Vector3(x + 0.18, 0.62, hw + 0.02), Vector3(x + 0.06, 0.58, hw + 0.02), P.INK[1])
	k.made.pop()
	if not van:
		# The torn-off door, thrown down beside the car, breaking its outline.
		k.made.push(Transform3D(Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, -0.18), Vector3(0.35, 0.03, hw + 0.62)))
		k.made.quad(Vector3(-0.3, 0.0, -0.2), Vector3(0.3, 0.0, -0.22), Vector3(0.32, 0.06, 0.22), Vector3(-0.3, 0.05, 0.2), P.INK[2])
		k.made.quad(Vector3(-0.3, 0.05, 0.2), Vector3(0.32, 0.06, 0.22), Vector3(0.3, 0.0, -0.22), Vector3(-0.3, 0.0, -0.2), GroundColors.down(paint, 0.1))
		k.made.quad(Vector3(-0.22, 0.064, 0.02), Vector3(0.24, 0.068, 0.02), Vector3(0.22, 0.066, -0.15), Vector3(-0.22, 0.062, -0.14), P.INK[0])
		k.made.pop()
	# What the land did: not which landscape this is, but what it throws over a
	# thing left standing in it (BiomeDressing.covers).
	var d := drift_of(c)
	match dress.covers:
		&"wrack":
			drift(k, Vector3(-0.2, 0.0, 0.85), 1.7, 0.42, 0.24, 0.05, d[0], s + 60)
			drift(k, Vector3(1.4, 0.0, -0.2), 0.7, 0.4, 0.2, 1.4, d[0], s + 61)
			# Weed hung along it at the tide line, and rust where the salt got in.
			for i in 6:
				var x := -0.9 + i * 0.35
				var y := roof_y - sink - cave * 0.6 if absf(x) < 0.4 else belt - sink
				k.made.quad(Vector3(x, y, -0.4), Vector3(x + 0.08, y, -0.4), Vector3(x + 0.14, y - 0.35, -0.62), Vector3(x + 0.02, y - 0.3, -0.62), P.EARTH[1] if i % 2 else P.SPRUCE[1])
			streak(k, Vector3(0.6, 0.5 - sink, hw + 0.03), 0.2, 0.3, Vector3(0, 0, 1))
		&"weed":
			_pool(k, Vector3(0.3, 0.0, 0.0), 1.6, s + 70)
			var rs := k.made.vertex_count()
			for i in 12:
				var a := float(i) * 0.9
				var base := Vector3(cos(a) * (1.35 + Kit.j(s, i, 0.2)), 0.0, sin(a) * 0.95)
				k.blade(base, base + Vector3(0.05, 0.75 + Kit.j(s, i + 20, 0.2), 0.0), 0.06, a, P.SPRUCE[3] if i % 2 else P.MOSS[3])
			k.sway_by_height(rs, 0.0, 0.8, 0.6)
		&"needles":
			drift(k, Vector3(-0.2, roof_y - sink - cave, 0.0), 0.5, 0.36, 0.08, 0.3, dress.growth, s + 80)
			# A bough came down across it.
			k.limb(Vector3(-1.6, 0.05, 0.9), Vector3(0.6, roof_y + 0.05, -0.2), 0.05, 0.02, 5, P.EARTH[1])
			drift(k, Vector3(0.0, 0.0, -0.8), 1.4, 0.35, 0.14, 0.1, d[0], s + 82)
		&"snow":
			# Buried to the belt on the windward side, a long tail of drift in its lee.
			drift(k, Vector3(-0.1, 0.0, hw + 0.2), 1.9, 0.55, belt + 0.02, 0.0, dress.snow[0], s + 90)
			drift(k, Vector3(0.4, 0.0, -hw - 0.45), 2.2, 0.75, 0.42, PI - 0.12, dress.snow[0], s + 91)
			drift(k, Vector3(1.55, 0.0, 0.1), 0.7, 0.55, 0.36, 1.57, GroundColors.down(dress.snow[0], 0.05), s + 92)
			drift(k, Vector3(-0.35, roof_y - sink - cave * 0.6, 0.0), 0.62, 0.42, 0.1, 0.0, dress.snow[0], s + 95)
			drift(k, Vector3(0.95, belt - sink - 0.05, 0.0), 0.3, 0.4, 0.06, 0.0, dress.snow[0], s + 96)
		&"ash":
			drift(k, Vector3(-0.6, 0.0, 0.75), 1.2, 0.36, 0.2, 0.1, d[0], s + 110)
			drift(k, Vector3(0.8, 0.0, -0.8), 1.1, 0.4, 0.18, -0.2, d[1], s + 111)
		_:
			drift(k, Vector3(-0.3, 0.0, 0.72), 1.6, 0.4, 0.34, 0.0, d[0], s + 100)
			drift(k, Vector3(1.4, 0.0, 0.2), 0.6, 0.4, 0.2, 1.3, d[0], s + 101)
			if dress.perishes():
				# Scoured back to primer: the rust comes through in ruled marks.
				for i in 9:
					var p := Vector3(-1.0 + i * 0.25, 0.35 + Kit.j(s, i, 0.1), hw + 0.018)
					k.made.quad(p, p + Vector3(0.04, 0, 0), p + Vector3(0.04, 0.03, 0), p + Vector3(0, 0.03, 0), P.RUST[2])


## Where a pane of glass was: a black hole in the frame `quad` (four corners in
## order), a few shards still caught in its corners catching the light.
static func _glass_gone(k: Kit, quad4: Array, out: Vector3, s: int, shards: bool) -> void:
	var a: Vector3 = quad4[0]
	var b: Vector3 = quad4[1]
	var c: Vector3 = quad4[2]
	var d: Vector3 = quad4[3]
	var lift := out.normalized() * 0.006
	k.made.quad(a + lift, b + lift, c + lift, d + lift, P.INK[0])
	if not shards:
		return
	var corners: Array[Vector3] = [a, b, c, d]
	for i in 4:
		if Rng.hash01(s, i, 11) < 0.45:
			continue
		var p := corners[i] + lift * 2.0
		var toward := (a + b + c + d) * 0.25 - corners[i]
		var e1 := corners[(i + 1) % 4] - corners[i]
		k.made.tri(p, p + e1 * (0.25 + Rng.hash01(s, i, 12) * 0.2), p + toward * (0.35 + Rng.hash01(s, i, 13) * 0.3), GroundColors.glint(P.SLATE[4]))


# --- the coast's dead fleet and its wall ---------------------------------------

## A trawler beached years ago. 0: heeled over on the sand, nets still on her
## gantry; 1: broken in two, the stern swung away, ribs showing in the gap.
static func hull(k: Kit, v: int, c: int) -> void:
	var s := 22000 + v * 23 + c
	var drift := drift_of(c)
	if v % 2 == 0:
		k.made.push(Transform3D(Basis(Vector3.RIGHT, 0.42) * Basis(Vector3.BACK, 0.06), Vector3(0.0, -0.3, 0.0)))
		_hull_part(k, 0, 8, s, true)
		k.made.pop()
		banks(k, [[-1.5, -0.95, 0.55, 0.32], [0.1, -1.1, 0.6, 0.34], [1.5, -0.8, 0.5, 0.26], [-2.3, 0.3, 0.4, 0.2], [0.6, 1.0, 0.45, 0.16]], drift[0], s + 50)
	else:
		k.made.push(Transform3D(Basis(Vector3.RIGHT, 0.18) * Basis(Vector3.BACK, 0.1), Vector3(0.55, -0.3, 0.0)))
		_hull_part(k, 3, 8, s, false)
		k.made.pop()
		k.made.push(Transform3D(Basis(Vector3.UP, 0.55) * Basis(Vector3.RIGHT, -0.34), Vector3(-0.9, -0.3, 0.55)))
		_hull_part(k, 0, 4, s + 1, true)
		k.made.pop()
		banks(k, [[-1.8, 1.3, 0.5, 0.3], [0.5, -1.0, 0.55, 0.3], [1.9, -0.7, 0.45, 0.24], [-0.3, 0.25, 0.4, 0.2], [2.5, 0.4, 0.35, 0.18]], drift[0], s + 60)
		# Plates and a winch drum spilled from the break.
		k.slab(-0.2, -0.05, -0.9, 0.5, 0.05, 0.3, s + 70, P.RUST[2], P.RUST[3], 0.02)
		k.made.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.2, 0.18, 1.2)))
		k.made.prism(0, 0, 0, 0.2, 0.35, 0.2, 8, P.RUST[1], P.INK[2])
		k.made.pop()


## Hull stations: x, half beam, keel y, sheer y.
const _STATIONS: Array[Vector4] = [
	Vector4(-2.1, 0.62, 0.05, 1.12), Vector4(-1.6, 0.74, -0.14, 1.06), Vector4(-0.8, 0.8, -0.3, 1.02),
	Vector4(0.0, 0.8, -0.33, 1.02), Vector4(0.8, 0.74, -0.3, 1.08), Vector4(1.5, 0.56, -0.2, 1.2),
	Vector4(2.0, 0.3, -0.04, 1.34), Vector4(2.35, 0.02, 0.2, 1.48),
]


## Stations [from, to) of the hull, plated, with a wheelhouse, gantry and nets
## if `stern` and the stern is in range; an open torn end gets ribs.
static func _hull_part(k: Kit, from: int, to: int, s: int, stern: bool) -> void:
	var hullc := P.INK[3].lerp(P.BRINE[1], 0.35)
	var bottom := P.RUST[1]
	var band := P.LINEN[3]
	var rings: Array = []
	for si in range(from, to):
		var st := _STATIONS[si]
		var b := st.y
		var kl := st.z
		var sh := st.w
		var pts: Array[Vector3] = []
		# One side keel to sheer, then the other sheer to keel.
		for q: Vector2 in [Vector2(0.0, 0.0), Vector2(0.55, 0.12), Vector2(0.95, 0.5), Vector2(1.0, 0.86), Vector2(0.97, 1.0)]:
			pts.append(Vector3(st.x, lerpf(kl, sh, q.y), b * q.x))
		rings.append(pts)
	for r in rings.size() - 1:
		var a: Array[Vector3] = rings[r]
		var bb: Array[Vector3] = rings[r + 1]
		for e in a.size() - 1:
			for sgn: float in [1.0, -1.0]:
				var p0 := a[e] * Vector3(1, 1, sgn)
				var p1 := a[e + 1] * Vector3(1, 1, sgn)
				var q0 := bb[e] * Vector3(1, 1, sgn)
				var q1 := bb[e + 1] * Vector3(1, 1, sgn)
				# Strakes of rust and bare plate by turns below the waterline.
				var col := (bottom if (r + from) % 2 == 0 else P.RUST[2]) if e <= 1 else (band if e == 3 else hullc)
				if e == 2 and (r + from) % 3 == 1:
					col = hullc.lerp(P.RUST[2], 0.5)
				if sgn > 0.0:
					k.made.quad(p0, q0, q1, p1, col)
				else:
					k.made.quad(p1, q1, q0, p0, GroundColors.down(col, 0.15))
		# The deck between the sheers.
		var ds := a[4] + Vector3(0, -0.04, 0)
		var dq := bb[4] + Vector3(0, -0.04, 0)
		k.made.quad(ds, dq, dq * Vector3(1, 1, -1), ds * Vector3(1, 1, -1), P.EARTH[2])
		# Planks gone grey in lines along the deck, a hatch left open on it.
		for pz: float in [-0.3, 0.0, 0.3]:
			var a0 := Vector3(ds.x, ds.y + 0.012, ds.z * pz)
			var a1 := Vector3(dq.x, dq.y + 0.012, dq.z * pz)
			k.made.quad(a0 + Vector3(0, 0, 0.02), a1 + Vector3(0, 0, 0.02), a1 - Vector3(0, 0, 0.02), a0 - Vector3(0, 0, 0.02), P.EARTH[1])
		if (r + from) % 3 == 2:
			var hc := ds.lerp(dq, 0.5) + Vector3(0, 0.02, 0)
			k.made.quad(hc + Vector3(-0.18, 0, 0.2), hc + Vector3(0.18, 0, 0.2), hc + Vector3(0.18, 0, -0.2), hc + Vector3(-0.18, 0, -0.2), P.INK[1])
		# Rust weeping from the scuppers down the topsides.
		if r % 2 == 0:
			var mid := a[4].lerp(bb[4], 0.5)
			streak(k, mid + Vector3(0, -0.05, 0.02), 0.12, 0.55, Vector3(0, 0, 1))
	# Ends: the stern transom, the stem, or a torn edge with ribs.
	var first: Array[Vector3] = rings[0]
	var last: Array[Vector3] = rings[rings.size() - 1]
	if from == 0:
		for e in first.size() - 1:
			k.made.quad(first[e + 1] * Vector3(1, 1, -1), first[e] * Vector3(1, 1, -1), first[e], first[e + 1], GroundColors.down(hullc, 0.3))
	else:
		_torn(k, first, s, 1.0)
	if to < _STATIONS.size():
		_torn(k, last, s + 3, -1.0)
	if stern and from == 0:
		# The wheelhouse, its windows out, a gantry over the stern with the
		# net still hanging from it.
		k.slab(-0.9, 1.0, 0.0, 0.9, 0.72, 0.9, s + 10, P.LINEN[3], P.LINEN[4], 0.02, 0.06)
		k.slab(-0.9, 1.72, 0.0, 1.05, 0.08, 1.02, s + 11, P.INK[2], P.RUST[2], 0.02)
		for i in 3:
			var z := -0.3 + i * 0.3
			k.made.quad(Vector3(-0.44, 1.35, z - 0.1), Vector3(-0.44, 1.35, z + 0.1), Vector3(-0.45, 1.6, z + 0.1), Vector3(-0.45, 1.6, z - 0.1), P.INK[1])
		k.made.quad(Vector3(-1.2, 1.35, 0.465), Vector3(-0.6, 1.35, 0.465), Vector3(-0.6, 1.58, 0.465), Vector3(-1.2, 1.58, 0.465), P.INK[1])
		streak(k, Vector3(-0.7, 1.3, 0.47), 0.1, 0.3, Vector3(0, 0, 1))
		k.limb(Vector3(-1.95, 1.05, 0.55), Vector3(-2.2, 2.3, 0.1), 0.04, 0.035, 5, P.RUST[3])
		k.limb(Vector3(-1.95, 1.05, -0.55), Vector3(-2.2, 2.3, -0.1), 0.04, 0.035, 5, P.RUST[3])
		k.limb(Vector3(-2.2, 2.3, -0.12), Vector3(-2.2, 2.3, 0.12), 0.035, 0.035, 4, P.RUST[2])
		for i in 6:
			var z := -0.3 + i * 0.12
			k.made.quad(Vector3(-2.2, 2.28, z), Vector3(-2.2, 2.28, z + 0.12), Vector3(-2.45 + Kit.j(s, i, 0.05), 0.9, z + 0.14), Vector3(-2.4, 0.95, z), P.SLATE[1] if i % 2 else P.INK[3])
		for i in 4:
			k.fleck(Vector3(-2.3, 1.7 - i * 0.2, -0.3 + i * 0.2), Vector3(-2.33, 1.62 - i * 0.2, -0.24 + i * 0.2), Vector3(-2.28, 1.66 - i * 0.2, -0.2 + i * 0.2), P.RUST[4])
		k.limb(Vector3(-0.2, 1.0, 0.0), Vector3(0.1, 2.6, 0.0), 0.04, 0.03, 5, P.RUST[2])
		k.limb(Vector3(0.05, 2.2, 0.0), Vector3(1.3, 1.1, 0.0), 0.02, 0.02, 4, P.RUST[2])
	# A hull number in white, three blocks weathered down to marks.
	if to >= 7:
		for i in 3:
			var x := 1.35 + i * 0.16
			k.made.quad(Vector3(x, 0.72, 0.62 - i * 0.07), Vector3(x + 0.1, 0.72, 0.6 - i * 0.07), Vector3(x + 0.1, 0.92, 0.6 - i * 0.07), Vector3(x, 0.92, 0.62 - i * 0.07), P.LINEN[4])


## A torn end: ragged plate edges and ribs standing out of it.
static func _torn(k: Kit, ring: Array[Vector3], s: int, inward: float = 1.0) -> void:
	# What the tear shows: the hull's inside, closed off a little way in and
	# drawn on the ink floor, so a torn end is a dark interior with ribs across
	# it and never a hole in the page (docs/LOOK.md section 6).
	var step := Vector3(0.34 * inward, 0.0, 0.0)
	var hub := ring[0] + step + Vector3(0.0, 0.2, 0.0)
	var sheer := ring[ring.size() - 1] + step
	for e in ring.size() - 1:
		for sgn: float in [1.0, -1.0]:
			var a := ring[e] * Vector3(1, 1, sgn) + step
			var b := ring[e + 1] * Vector3(1, 1, sgn) + step
			k.made.tri(hub, a, b, P.INK[2])
			k.made.tri(hub, b, a, P.INK[3])
	k.made.tri(hub, sheer, sheer * Vector3(1, 1, -1), P.INK[2])
	k.made.tri(hub, sheer * Vector3(1, 1, -1), sheer, P.INK[3])
	for e in ring.size() - 1:
		for sgn: float in [1.0, -1.0]:
			var a := ring[e] * Vector3(1, 1, sgn)
			var b := ring[e + 1] * Vector3(1, 1, sgn)
			k.limb(a, b, 0.035, 0.035, 4, P.RUST[1])
			var tip := a.lerp(b, 0.5) + Vector3(0.18 + Kit.j(s, e, 0.1), Kit.j(s, e + 10, 0.1), 0.0)
			k.fleck(a, b, tip, P.RUST[2])


## A sea wall. 0: a standing length of cast wall with its wave-return lip, a
## bent rail, chevrons nobody reads, bars out of both broken ends; 1: the wall
## gone, blocks tumbled and the breakwater's cast tetrapods thrown up the beach.
static func sea_wall(k: Kit, v: int, c: int) -> void:
	var s := 22500 + v * 29 + c
	var concrete := BiomeDressing.of(c).concrete
	if v % 2 == 0:
		# Profile across the wall (z seaward +), extruded along x in lengths
		# whose tops break down at both ends.
		var prof: Array[Vector2] = [Vector2(-0.4, -0.1), Vector2(-0.34, 1.12), Vector2(0.18, 1.12), Vector2(0.42, 1.04), Vector2(0.32, 0.92), Vector2(0.26, 0.62), Vector2(0.36, 0.3), Vector2(0.46, -0.1)]
		var xs: Array[float] = [-1.35, -0.9, -0.45, 0.0, 0.45, 0.9, 1.35]
		var drop: Array[float] = [0.55, 0.12, 0.0, 0.0, 0.05, 0.3, 0.7]
		for i in xs.size() - 1:
			for e in prof.size() - 1:
				var a := prof[e]
				var b := prof[e + 1]
				var ay := minf(a.y, 1.12 - drop[i]) if a.y > 0.0 else a.y
				var by := minf(b.y, 1.12 - drop[i]) if b.y > 0.0 else b.y
				var ay2 := minf(a.y, 1.12 - drop[i + 1]) if a.y > 0.0 else a.y
				var by2 := minf(b.y, 1.12 - drop[i + 1]) if b.y > 0.0 else b.y
				var col := concrete if e != 1 else GroundColors.up(concrete, 0.2)
				if e >= 4 and e <= 6:
					col = GroundColors.down(concrete, 0.25)
				k.made.quad(Vector3(xs[i], by, b.x), Vector3(xs[i + 1], by2, b.x), Vector3(xs[i + 1], ay2, a.x), Vector3(xs[i], ay, a.x), col)
			# A dark weed line along the foot of the sea face.
			k.made.quad(Vector3(xs[i], -0.05, 0.475), Vector3(xs[i + 1], -0.05, 0.475), Vector3(xs[i + 1], 0.3, 0.375), Vector3(xs[i], 0.3, 0.375), P.SPRUCE[1])
		for endi: int in [0, xs.size() - 1]:
			var x := xs[endi]
			var top := 1.12 - drop[endi]
			var sgn := -1.0 if endi == 0 else 1.0
			both(k.made, Vector3(x, -0.1, -0.4), Vector3(x, -0.1, 0.46), Vector3(x, minf(top, 0.62), 0.26), Vector3(x, top, -0.34), GroundColors.down(concrete, 0.4) if sgn > 0.0 else GroundColors.down(concrete, 0.1))
			for b in 3:
				var root := Vector3(x, top * (0.35 + b * 0.2), -0.25 + b * 0.22)
				k.limb(root, root + Vector3(sgn * (0.25 + Kit.j(s, b + endi, 0.1)), 0.18 + Kit.j(s, b + endi + 5, 0.1), 0.06), 0.014, 0.01, 4, P.RUST[2])
		# Chevrons on the landward face, faded to a rumour.
		for i in 5:
			var x := -0.7 + i * 0.32
			k.made.quad(Vector3(x + 0.1, 0.75, -0.372), Vector3(x + 0.22, 0.75, -0.372), Vector3(x + 0.12, 0.3, -0.397), Vector3(x, 0.3, -0.397), P.RUST[3].lerp(concrete, 0.4) if i % 2 == 0 else P.LINEN[4].lerp(concrete, 0.3))
		# The rail: posts and a top bar, bent down where something hit it.
		var rail := P.RUST[2]
		for i in 5:
			var x := -0.7 + i * 0.35
			k.limb(Vector3(x, 1.1, -0.15), Vector3(x + (0.15 if i == 3 else 0.0), 1.55 - (0.2 if i == 3 else 0.0), -0.15 + (0.2 if i == 3 else 0.0)), 0.018, 0.016, 4, rail)
		k.sag(Vector3(-0.7, 1.55, -0.15), Vector3(0.35, 1.55, -0.15), 0.0, 3, 0.014, rail)
		k.sag(Vector3(0.35, 1.55, -0.15), Vector3(0.7, 1.35, 0.05), 0.02, 2, 0.014, rail)
		k.sag(Vector3(0.7, 1.35, 0.05), Vector3(0.7, 1.55, -0.15), 0.0, 1, 0.014, rail)
		for i in 7:
			k.fleck(Vector3(-1.0 + i * 0.3, 0.15 + (i % 3) * 0.06, 0.44), Vector3(-0.97 + i * 0.3, 0.19 + (i % 3) * 0.06, 0.45), Vector3(-1.02 + i * 0.3, 0.2 + (i % 3) * 0.06, 0.44), P.LINEN[5])
	else:
		k.made.push(Transform3D(Basis(Vector3.UP, 0.3) * Basis(Vector3.BACK, 0.5), Vector3(-0.7, 0.1, -0.2)))
		k.slab(0.0, 0.0, 0.0, 1.1, 0.8, 0.7, s, concrete, GroundColors.up(concrete, 0.2), 0.04, 0.05)
		k.made.pop()
		k.made.push(Transform3D(Basis(Vector3.UP, -0.5) * Basis(Vector3.RIGHT, 0.35), Vector3(0.6, -0.05, 0.35)))
		k.slab(0.0, 0.0, 0.0, 0.9, 0.55, 0.6, s + 1, GroundColors.down(concrete, 0.1), concrete, 0.04, 0.08)
		k.made.pop()
		for i in 3:
			_tetrapod(k, Vector3(-0.9 + i * 0.95, 0.25, 0.9 - (i % 2) * 0.45), 0.42, s + 10 + i, concrete)
		k.limb(Vector3(0.3, 0.4, 0.3), Vector3(0.8, 1.0, 0.1), 0.016, 0.012, 4, P.RUST[2])
	banks(k, [[-1.2, 0.6, 0.45, 0.2], [0.5, 0.7, 0.55, 0.18], [1.3, -0.5, 0.4, 0.14]], drift_of(c)[0], s + 40)


## A cast breakwater tetrapod: four tapered legs from a knot.
static func _tetrapod(k: Kit, at: Vector3, size: float, s: int, col: Color) -> void:
	var dirs: Array[Vector3] = [Vector3(0, 1, 0), Vector3(0.94, -0.33, 0), Vector3(-0.47, -0.33, 0.82), Vector3(-0.47, -0.33, -0.82)]
	var rot := Basis(Vector3.UP, Rng.hash01(s, 1) * TAU) * Basis(Vector3.RIGHT, Rng.hash01(s, 2) * 0.8)
	for i in 4:
		var d := rot * dirs[i]
		k.limb(at, at + d * size, size * 0.3, size * 0.16, 6, col if i % 2 == 0 else GroundColors.down(col, 0.15))


# --- the pinewood's order and its watch ----------------------------------------

## A stump sawn flat by a harvester's head, standing in its exact row. 0: bare,
## 1: with its log bucked and left, 2: with brash thrown over it.
static func stump(k: Kit, v: int, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var burnt := BiomeDressing.burnt(c)
	var s := 23000 + v * 7 + c
	var bark: Color = P.INK[2] if burnt else P.EARTH[1]
	var face: Color = P.STONE[1] if burnt else P.LINEN[4].lerp(P.SAND[4], 0.3)
	var r := 0.2 + v * 0.02
	k.made.prism(0, -0.05, 0, r * 1.2, 0.08, r, 8, bark)
	k.made.prism(0, 0.08, 0, r, 0.26, r * 0.95, 8, bark, face)
	# The saw's face: rings, and the dark heart.
	k.made.prism(0.0, 0.261, 0.0, r * 0.62, 0.263, r * 0.62, 8, face, GroundColors.down(face, 0.15))
	k.made.prism(0.0, 0.264, 0.0, r * 0.25, 0.266, r * 0.25, 6, face, P.EARTH[3])
	for i in 4:
		var a := float(i) / 4.0 * TAU + 0.4
		k.limb(Vector3(cos(a) * r * 0.8, 0.06, sin(a) * r * 0.8), Vector3(cos(a) * r * 1.55, -0.03, sin(a) * r * 1.55), 0.07, 0.04, 4, bark)
	match v % 3:
		1:
			k.made.push(Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.2, 0.0, 0.55)))
			k.limb(Vector3(-0.55, 0.13, 0), Vector3(0.55, 0.12, 0), 0.14, 0.12, 7, P.INK[2] if burnt else P.EARTH[2])
			k.made.push(Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.71, 0.135, 0.0)))
			k.made.prism(0, 0, 0, 0.13, 0.01, 0.13, 7, face, face)
			k.made.pop()
			k.made.pop()
		2:
			var bs := k.made.vertex_count()
			for i in 7:
				var a := Kit.j(s, i, 1.8) + i * 0.9
				var from := Vector3(cos(a) * 0.3, 0.05 + i * 0.02, sin(a) * 0.3)
				k.limb(from, from + Vector3(cos(a + 0.4) * 0.42, 0.04, sin(a + 0.4) * 0.42), 0.03, 0.014, 3, P.EARTH[2])
				if not burnt:
					k.clump(from.x + cos(a + 0.4) * 0.36, 0.0, from.z + sin(a + 0.4) * 0.36, 0.13, 0.08, s + 40 + i, P.EARTH[3] if i % 2 else P.RUST[2], 5)
			k.sway_by_height(bs, 0.0, 0.3, 0.05)
	if dress.cold():
		k.clump(0.0, 0.2, 0.0, r * 0.9, 0.1, s + 5, dress.snow[0], 6)


## A fire tower of timber: four legs raking in, braces, a cabin at the top
## with its windows on every side. 1: the cabin burnt out and a leg gone, the
## whole thing leaning.
static func fire_tower(k: Kit, v: int, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 23500 + v * 13 + c
	var wood := wood_of(c)
	var top := 4.2
	var lean := Basis.IDENTITY if v % 2 == 0 else Basis(Vector3.BACK, -0.12) * Basis(Vector3.RIGHT, 0.06)
	k.made.push(Transform3D(lean, Vector3.ZERO))
	var feet: Array[Vector2] = [Vector2(-0.75, -0.75), Vector2(0.75, -0.75), Vector2(0.75, 0.75), Vector2(-0.75, 0.75)]
	var levels: Array[float] = [0.0, 1.1, 2.2, 3.2, top]
	for i in 4:
		var f := feet[i]
		var g := feet[(i + 1) % 4]
		if v % 2 == 1 and i == 2:
			k.limb(Vector3(f.x, -0.05, f.y), Vector3(f.x * 0.8, 1.6, f.y * 0.8), 0.06, 0.05, 5, P.INK[2])
		else:
			k.limb(Vector3(f.x, -0.05, f.y), Vector3(f.x * 0.45, top, f.y * 0.45), 0.065, 0.05, 5, wood[i % 2])
		for li in levels.size() - 1:
			var y0 := levels[li]
			var y1 := levels[li + 1]
			var k0 := 1.0 - y0 / top * 0.55
			var k1 := 1.0 - y1 / top * 0.55
			if v % 2 == 1 and i == 2 and li > 0:
				continue
			k.limb(Vector3(f.x * k0, y0 + 0.1, f.y * k0), Vector3(g.x * k1, y1, g.y * k1), 0.025, 0.025, 4, wood[1])
			k.limb(Vector3(f.x * k1, y1, f.y * k1), Vector3(g.x * k1, y1, g.y * k1), 0.025, 0.025, 4, wood[0])
	# Stairs as a zigzag of flights inside.
	for i in 6:
		var y := 0.3 + i * 0.62
		var sgn := 1.0 if i % 2 == 0 else -1.0
		k.limb(Vector3(-0.35 * sgn, y, 0.1), Vector3(0.35 * sgn, y + 0.6, 0.1), 0.03, 0.03, 4, wood[0])
	# The cabin.
	var cy := top
	k.slab(0.0, cy, 0.0, 1.0, 0.06, 1.0, s, wood[0], wood[1], 0.02)
	if v % 2 == 0:
		for side in 4:
			var a := float(side) * PI * 0.5
			var out := Vector3(cos(a), 0, sin(a)) * 0.48
			var along := Vector3(-sin(a), 0, cos(a)) * 0.48
			k.made.quad(out - along + Vector3(0, cy + 0.06, 0), out + along + Vector3(0, cy + 0.06, 0), out + along + Vector3(0, cy + 0.42, 0), out - along + Vector3(0, cy + 0.42, 0), wood[1] if side % 2 else wood[0])
			k.made.quad(out * 1.01 - along * 0.85 + Vector3(0, cy + 0.44, 0), out * 1.01 + along * 0.85 + Vector3(0, cy + 0.44, 0), out * 1.01 + along * 0.85 + Vector3(0, cy + 0.8, 0), out * 1.01 - along * 0.85 + Vector3(0, cy + 0.8, 0), P.INK[1])
			k.limb(out - along + Vector3(0, cy + 0.42, 0), out - along + Vector3(0, cy + 0.86, 0), 0.02, 0.02, 4, wood[1])
		k.made.push(Transform3D(Basis.IDENTITY, Vector3(0, cy + 0.86, 0)))
		k.made.prism(0, 0, 0, 0.8, 0.45, 0.0, 4, P.SLATE[1], Color(0, 0, 0, 0), PI * 0.25)
		k.made.pop()
		# A lookout's lamp left on the sill: one of the few that still burn.
		k.made.prism(0.35, cy + 0.44, 0.2, 0.04, cy + 0.54, 0.035, 6, GroundColors.lamp(P.COPPER[4], 1.3))
		if dress.cold():
			k.clump(0.0, cy + 1.05, 0.0, 0.55, 0.18, s + 3, dress.snow[0], 7)
	else:
		for side in 3:
			var a := float(side) * PI * 0.5
			var out := Vector3(cos(a), 0, sin(a)) * 0.48
			var along := Vector3(-sin(a), 0, cos(a)) * 0.48
			k.made.quad(out - along + Vector3(0, cy + 0.06, 0), out + along * 0.4 + Vector3(0, cy + 0.06, 0), out + along * 0.2 + Vector3(0, cy + 0.3 + side * 0.08, 0), out - along + Vector3(0, cy + 0.5, 0), P.INK[2])
		k.limb(Vector3(0.45, cy + 0.06, 0.45), Vector3(0.3, cy + 0.9, 0.2), 0.03, 0.02, 4, P.INK[2])
	k.made.pop()
	if v % 2 == 1:
		k.slab(1.2, -0.05, 0.8, 0.8, 0.1, 0.7, s + 20, P.INK[2], P.STONE[1], 0.08, 0.1)
		k.limb(Vector3(0.9, 0.0, 1.3), Vector3(1.9, 0.08, 0.5), 0.05, 0.04, 5, P.INK[2])


# --- water and slag ------------------------------------------------------------

## Water kept where there is none. 0: a riveted tank on a timber stand with a
## ladder and a pipe down to a trough; 1: a cast cistern capped with machine
## plate, a tap, and the buckets waiting their turn.
static func water_tank(k: Kit, v: int, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 24000 + v * 11 + c
	var wood := wood_of(c)
	if v % 2 == 0:
		for sx: float in [-0.45, 0.45]:
			for sz: float in [-0.45, 0.45]:
				k.limb(Vector3(sx * 1.15, -0.05, sz * 1.15), Vector3(sx, 1.2, sz), 0.05, 0.045, 5, wood[0])
		k.limb(Vector3(-0.52, 0.5, -0.52), Vector3(0.52, 1.0, 0.52), 0.025, 0.025, 4, wood[1])
		k.limb(Vector3(0.52, 0.5, -0.52), Vector3(-0.52, 1.0, 0.52), 0.025, 0.025, 4, wood[1])
		k.slab(0.0, 1.2, 0.0, 1.15, 0.06, 1.15, s, wood[1], wood[0], 0.02)
		var tank := P.RUST[2].lerp(P.SLATE[2], 0.3)
		k.made.prism(0, 1.26, 0, 0.62, 2.1, 0.62, 12, tank, GroundColors.up(tank, 0.1))
		k.made.prism(0, 2.1, 0, 0.64, 2.25, 0.0, 12, GroundColors.down(tank, 0.2))
		for i in 3:
			k.made.prism(0, 1.45 + i * 0.25, 0, 0.625, 1.47 + i * 0.25, 0.625, 12, P.INK[2])
		streak(k, Vector3(0.62, 2.05, 0.05), 0.2, 0.7, Vector3(1, 0, 0))
		streak(k, Vector3(0.1, 2.0, 0.63), 0.14, 0.6, Vector3(0, 0, 1))
		for i in 9:
			var y := 0.1 + i * 0.22
			k.limb(Vector3(0.78, y, -0.15), Vector3(0.7, y, 0.15), 0.014, 0.014, 4, wood[1])
		k.limb(Vector3(0.8, -0.05, -0.16), Vector3(0.66, 2.05, -0.16), 0.02, 0.02, 4, wood[0])
		k.limb(Vector3(0.8, -0.05, 0.16), Vector3(0.66, 2.05, 0.16), 0.02, 0.02, 4, wood[0])
		k.limb(Vector3(-0.3, 1.3, 0.5), Vector3(-0.45, 0.35, 1.0), 0.03, 0.03, 5, P.RUST[1])
		k.slab(-0.45, 0.0, 1.15, 0.9, 0.3, 0.35, s + 1, P.STONE[3], P.BRINE[2], 0.02)
	else:
		var cast := P.STONE[3].lerp(P.LINEN[3], 0.4)
		k.made.prism(0, -0.05, 0, 0.8, 0.8, 0.76, 10, cast, GroundColors.up(cast, 0.15))
		k.made.prism(0, 0.2, 0, 0.805, 0.24, 0.805, 10, GroundColors.down(cast, 0.3))
		k.found.prism(0, 0.8, 0, 0.7, 0.86, 0.66, 8, P.PLATE[3], P.PLATE[4], PI / 8.0)
		for i in 8:
			var a := float(i) / 8.0 * TAU
			k.found.prism(cos(a) * 0.6, 0.86, sin(a) * 0.6, 0.025, 0.89, 0.025, 6, P.PLATE[5])
		k.limb(Vector3(0.78, 0.3, 0.0), Vector3(1.0, 0.3, 0.0), 0.03, 0.025, 5, P.COPPER[1])
		for i in 4:
			var z := -0.6 + i * 0.4
			k.made.prism(1.35 + (i % 2) * 0.2, -0.02, z, 0.13, 0.22, 0.15, 7, [P.RUST[3], P.SLATE[3], P.LINEN[3], P.BRINE[2]][i], P.BRINE[1])
		k.limb(Vector3(-0.9, -0.05, 0.7), Vector3(-0.85, 1.4, 0.72), 0.03, 0.025, 4, wood[0])
		k.fleck(Vector3(-0.85, 1.35, 0.72), Vector3(-0.5, 1.2, 0.72), Vector3(-0.85, 1.1, 0.72), P.BRINE[3])
	if dress.cold():
		k.clump(0.0, 2.2 if v % 2 == 0 else 0.86, 0.0, 0.55, 0.14, s + 9, dress.snow[0], 8)
	elif not BiomeDressing.grassy(c):
		# Dry ground: what blows about here banks against the stand.
		banks(k, [[-0.8, -0.8, 0.5, 0.16], [0.8, -0.7, 0.4, 0.12]], drift_of(c)[0], s + 10)


## A heap of slag where a works tipped it: a dark cone run with glassy pours,
## seams that still glow, and (0) the tipping rail and its ladle car still up
## on top, or (1) twin heaps with a crust broken open.
static func slag_heap(k: Kit, v: int, c: int) -> void:
	var s := 24500 + v * 3 + c
	var slag := P.STONE[1].lerp(P.RUST[1], 0.35)
	var cone := func(cx: float, cz: float, r: float, h: float, seed_value: int) -> void:
		var ring0: Array[Vector3] = []
		var ring1: Array[Vector3] = []
		for i in 11:
			var a := float(i) / 11.0 * TAU
			var rr := r * (0.85 + Rng.hash01(seed_value, i) * 0.3)
			ring0.append(Vector3(cx + cos(a) * rr, -0.1, cz + sin(a) * rr))
			ring1.append(Vector3(cx + cos(a) * rr * 0.45, h * (0.62 + Kit.j(seed_value, i, 0.06)), cz + sin(a) * rr * 0.45))
		var apex := Vector3(cx + r * 0.08, h, cz)
		for i in 11:
			var n := (i + 1) % 11
			var col := slag if i % 3 else GroundColors.down(slag, 0.3)
			k.made.quad(ring0[n], ring0[i], ring1[i], ring1[n], col)
			k.made.tri(apex, ring1[n], ring1[i], GroundColors.up(slag, 0.1) if i % 2 else slag)
			# A pour run down the flank: glass, dark green over black.
			if i % 4 == 1:
				var mid := ring0[i].lerp(ring1[i], 0.5)
				var o := (ring0[i] - Vector3(cx, 0, cz)).normalized() * 0.03
				k.made.quad(ring1[i] + o, ring1[n] + o, ring0[n].lerp(ring0[i], 0.6) + o, ring0[i] + o * 1.5, P.SPRUCE[1].lerp(P.INK[2], 0.4))
				k.fleck(mid + o * 2.0, mid + o * 2.0 + Vector3(0.06, 0.04, 0.0), mid + o * 2.0 + Vector3(0.0, 0.06, 0.05), GroundColors.glint(P.SPRUCE[4]))
			if i % 5 == 2:
				var p := ring0[i].lerp(ring1[i], 0.3) + (ring0[i] - Vector3(cx, 0, cz)).normalized() * 0.04
				k.made.quad(p, p + Vector3(0.1, 0.02, 0.0), p + Vector3(0.1, 0.2, 0.0) - (ring0[i] - Vector3(cx, 0, cz)).normalized() * 0.08, p + Vector3(0.0, 0.18, 0.0) - (ring0[i] - Vector3(cx, 0, cz)).normalized() * 0.08, GroundColors.glow(P.EMBER[3], 0.9))
	if v % 2 == 0:
		cone.call(0.0, 0.0, 1.35, 1.35, s)
		# The tipping rail on its trestle, running off the top, the ladle car
		# tipped at its end, a lip of fresh slag frozen coming out of it.
		for i in 3:
			var x := -1.8 + i * 0.7
			var y := 0.4 + i * 0.35
			k.rod(Vector3(x, -0.1, -0.3), Vector3(x, y, -0.2), 0.03, 4, P.PLATE[2])
			k.rod(Vector3(x, -0.1, 0.3), Vector3(x, y, 0.2), 0.03, 4, P.PLATE[2])
		k.rod(Vector3(-1.9, 0.38, -0.2), Vector3(0.0, 1.45, -0.2), 0.022, 4, P.PLATE[3])
		k.rod(Vector3(-1.9, 0.38, 0.2), Vector3(0.0, 1.45, 0.2), 0.022, 4, P.PLATE[3])
		k.found.push(Transform3D(Basis(Vector3.BACK, -0.7), Vector3(0.1, 1.55, 0.0)))
		k.found.prism(0, 0, 0, 0.26, 0.45, 0.36, 10, P.PLATE[2], P.INK[1])
		k.found.prism(0, -0.05, 0, 0.3, 0.02, 0.3, 10, P.PLATE[1])
		k.found.pop()
		k.made.quad(Vector3(0.45, 1.62, -0.12), Vector3(0.45, 1.62, 0.12), Vector3(0.9, 1.0, 0.16), Vector3(0.85, 0.98, -0.14), GroundColors.glow(P.EMBER[2], 0.6))
	else:
		cone.call(-0.5, -0.2, 1.1, 1.05, s)
		cone.call(0.75, 0.45, 0.85, 0.8, s + 7)
		k.made.prism(-0.45, 1.0, -0.2, 0.2, 1.04, 0.14, 7, P.INK[1], GroundColors.glow(P.EMBER[3], 1.0))
	banks(k, [[-1.5, 1.0, 0.5, 0.12], [1.5, -0.9, 0.45, 0.1]], drift_of(c)[1], s + 20)


# --- what was lost ---------------------------------------------------------------

## Wreckage at walking scale, the pieces of things that ended. 0: a car's door
## torn off and lying glass-up, its bonnet propped against a wheel; 1: an engine
## block dropped out of something, its axle and one wheel, oil gone into the
## ground; 2: a household's last load: a pram on its side, a burst case with its
## clothes blown out of it, a mattress half under the land.
static func wreckage(k: Kit, v: int, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 24800 + v * 13 + c * 3
	var d := drift_of(c)
	var rot := BiomeDressing.burnt(c)
	var paint: Color = [P.SLATE[3], P.RUST[3].lerp(P.LINEN[3], 0.4), P.SPRUCE[2].lerp(P.SLATE[3], 0.5)][(v + c) % 3]
	if rot:
		paint = P.STONE[1].lerp(P.RUST[1], 0.4)
	elif dress.perishes():
		paint = dress.bleach.lerp(paint, 0.3)
	match v % 3:
		0:
			# The door, lying flat: its skin, the window frame empty, a handle.
			k.made.push(Transform3D(Basis(Vector3.UP, 0.35) * Basis(Vector3.RIGHT, 0.06), Vector3(-0.3, 0.02, 0.1)))
			k.made.quad(Vector3(-0.5, 0.0, 0.34), Vector3(0.5, 0.0, 0.34), Vector3(0.52, 0.05, -0.02), Vector3(-0.5, 0.05, -0.02), paint)
			k.made.quad(Vector3(-0.5, 0.05, -0.02), Vector3(0.52, 0.05, -0.02), Vector3(0.36, 0.06, -0.36), Vector3(-0.42, 0.06, -0.36), GroundColors.down(paint, 0.15))
			k.made.quad(Vector3(-0.36, 0.064, -0.05), Vector3(0.4, 0.064, -0.05), Vector3(0.28, 0.068, -0.3), Vector3(-0.3, 0.068, -0.3), P.INK[0])
			k.made.tri(Vector3(-0.3, 0.07, -0.3), Vector3(-0.1, 0.07, -0.3), Vector3(-0.32, 0.07, -0.18), GroundColors.glint(P.SLATE[4]))
			k.made.quad(Vector3(0.22, 0.02, 0.2), Vector3(0.38, 0.02, 0.2), Vector3(0.38, 0.02, 0.24), Vector3(0.22, 0.02, 0.24), P.STONE[3])
			k.made.quad(Vector3(-0.5, 0.012, 0.3), Vector3(0.1, 0.012, 0.32), Vector3(0.0, 0.012, 0.1), Vector3(-0.45, 0.012, 0.12), P.RUST[2])
			# Its lining and wires spilled out of the torn hinge side.
			k.sag(Vector3(-0.52, 0.04, 0.1), Vector3(-0.85, 0.02, 0.3), -0.02, 3, 0.008, P.INK[2])
			k.sag(Vector3(-0.52, 0.04, 0.0), Vector3(-0.8, 0.02, -0.25), -0.02, 3, 0.008, P.COPPER[2] if not rot else P.INK[2])
			k.made.pop()
			# A wheel on its side, the bonnet leaning up against it, bent.
			k.made.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.55, 0.06, -0.4)))
			k.made.prism(0, 0, 0, 0.22, 0.12, 0.22, 9, P.INK[2] if not rot else P.RUST[1], P.INK[1])
			k.made.prism(0, 0.121, 0, 0.1, 0.125, 0.1, 7, P.STONE[2])
			k.made.pop()
			k.made.push(Transform3D(Basis(Vector3.UP, -0.5) * Basis(Vector3.BACK, 0.9), Vector3(0.62, 0.0, 0.25)))
			k.made.quad(Vector3(0.0, 0.0, -0.36), Vector3(0.0, 0.0, 0.36), Vector3(0.6, 0.05, 0.3), Vector3(0.6, 0.05, -0.3), paint)
			k.made.quad(Vector3(0.6, 0.05, -0.3), Vector3(0.6, 0.05, 0.3), Vector3(0.0, 0.0, 0.36), Vector3(0.0, 0.0, -0.36), GroundColors.down(paint, 0.35))
			k.made.quad(Vector3(0.2, 0.021, -0.36), Vector3(0.24, 0.026, 0.36), Vector3(0.3, 0.03, 0.36), Vector3(0.26, 0.025, -0.36), P.INK[2])
			k.made.pop()
		1:
			# The block: finned and heavy, its manifold rusted, a belt pulley.
			k.made.push(Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.BACK, 0.12), Vector3(-0.2, -0.04, 0.0)))
			k.slab(0.0, 0.0, 0.0, 0.62, 0.42, 0.44, s, P.STONE[1] if not rot else P.INK[2], P.STONE[2], 0.02)
			for i in 4:
				k.made.prism(-0.22 + i * 0.15, 0.42, 0.0, 0.05, 0.5, 0.05, 6, P.RUST[2], P.INK[1])
			k.limb(Vector3(-0.3, 0.3, 0.25), Vector3(0.32, 0.26, 0.26), 0.035, 0.035, 5, P.RUST[1])
			k.made.push(Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.34, 0.24, 0.0)))
			k.made.prism(0, 0, 0, 0.14, 0.06, 0.14, 9, P.INK[2], P.STONE[3])
			k.made.pop()
			k.made.pop()
			# The axle, and the wheel still on it, the other end in the ground.
			k.limb(Vector3(0.15, 0.1, -0.55), Vector3(1.0, 0.02, 0.2), 0.04, 0.035, 5, P.RUST[1])
			k.made.push(Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, PI * 0.5 - 0.25), Vector3(0.12, 0.2, -0.6)))
			k.made.prism(0, -0.06, 0, 0.22, 0.08, 0.22, 9, P.INK[2] if not rot else P.RUST[1], P.INK[1])
			k.made.prism(0, 0.081, 0, 0.1, 0.085, 0.1, 7, P.STONE[2])
			k.made.pop()
			# The oil gone into the ground: a black stain with the sky caught in it.
			var ring: Array[Vector3] = []
			for i in 9:
				var a := float(i) / 9.0 * TAU
				var rr := 0.55 * (0.7 + Rng.hash01(s, i) * 0.5)
				ring.append(Vector3(-0.1 + cos(a) * rr * 1.2, 0.008, 0.2 + sin(a) * rr))
			for i in 9:
				k.made.tri(Vector3(-0.1, 0.008, 0.2), ring[(i + 1) % 9], ring[i], P.INK[3].lerp(P.SPRUCE[1], 0.4))
			k.made.quad(Vector3(-0.5, 0.012, 0.15), Vector3(0.2, 0.012, 0.2), Vector3(0.2, 0.012, 0.23), Vector3(-0.5, 0.012, 0.18), GroundColors.glint(P.BLOOM[2]))
		_:
			# The pram on its side, its hood torn, one wheel in the air.
			k.made.push(Transform3D(Basis(Vector3.UP, -0.3) * Basis(Vector3.RIGHT, PI * 0.5 - 0.15), Vector3(0.45, 0.25, -0.25)))
			k.made.prism(0.0, -0.18, 0.0, 0.24, 0.18, 0.2, 8, paint, GroundColors.down(paint, 0.2))
			k.made.quad(Vector3(-0.24, 0.18, -0.2), Vector3(0.06, 0.18, -0.2), Vector3(0.0, 0.18, 0.2), Vector3(-0.24, 0.18, 0.2), P.INK[1])
			for i in 4:
				var a := float(i) / 4.0 * PI
				k.made.strut(Vector3(-0.22 + cos(a) * 0.02, 0.18, -0.2), Vector3(-0.1 + cos(a) * 0.2, 0.18 + sin(a) * 0.05, 0.2 - sin(a) * 0.02), 0.012, 3, P.INK[2])
			k.made.pop()
			for wx: float in [0.2, 0.7]:
				k.made.push(Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(wx, 0.08 + (0.28 if wx > 0.5 else 0.0), 0.05)))
				for e in 7:
					var a0 := float(e) / 7.0 * TAU
					var a1 := float(e + 1) / 7.0 * TAU
					k.made.strut(Vector3(cos(a0), 0.0, sin(a0)) * 0.11, Vector3(cos(a1), 0.0, sin(a1)) * 0.11, 0.012, 3, P.INK[2])
				k.made.pop()
			k.limb(Vector3(0.3, 0.14, -0.05), Vector3(0.75, 0.38, 0.0), 0.012, 0.012, 3, P.STONE[3])
			# The case burst open, its clothes blown out across the ground.
			k.made.push(Transform3D(Basis(Vector3.UP, 0.6), Vector3(-0.45, 0.0, 0.3)))
			k.slab(0.0, -0.02, 0.0, 0.5, 0.12, 0.34, s + 1, P.EARTH[2] if not rot else P.INK[2], P.EARTH[3], 0.015)
			k.made.quad(Vector3(-0.25, 0.1, -0.17), Vector3(0.25, 0.1, -0.17), Vector3(0.24, 0.42, -0.26), Vector3(-0.26, 0.4, -0.25), P.EARTH[1])
			k.made.quad(Vector3(0.24, 0.42, -0.26), Vector3(0.25, 0.1, -0.17), Vector3(-0.25, 0.1, -0.17), Vector3(-0.26, 0.4, -0.25), P.INK[2])
			k.made.pop()
			var cloth: Array[Color] = [P.BLOOM[1], P.LINEN[4], P.SLATE[3], P.BRINE[2], P.RUST[3]]
			for i in 6:
				var p := Vector3(-0.95 + i * 0.2 + Kit.j(s, i, 0.08), 0.015, 0.55 + Kit.j(s, i + 10, 0.25))
				var col := cloth[i % cloth.size()] if not rot else (P.INK[2] if i % 2 else P.ASH[2])
				# WOUND TO FACE THE SKY. These lie flat on the ground, and wound the
				# other way `MeshKit.tri`'s normal — (c - b) x (a - b) — came out
				# pointing DOWN, so six scraps of cloth were drawn into the dirt and
				# nothing was on the screen. Not dark: ABSENT, which reads as
				# something standing in front of them, which is why the fix is the
				# winding and never the shape.
				k.made.quad(p + Vector3(-0.1, 0.0, -0.06), p + Vector3(-0.07, 0.004, 0.08), p + Vector3(0.12, 0.008, 0.05), p + Vector3(0.09, 0.004, -0.09), col)
			# A mattress sunk half under the land.
			k.made.push(Transform3D(Basis(Vector3.UP, -0.2) * Basis(Vector3.BACK, 0.08), Vector3(-0.2, -0.05, -0.55)))
			k.slab(0.0, 0.0, 0.0, 1.0, 0.12, 0.5, s + 2, P.LINEN[3] if not rot else P.ASH[1], P.LINEN[4] if not rot else P.ASH[2], 0.03)
			for i in 3:
				# Same winding, same result: the mattress's own straps lay face down
				# on top of it.
				k.made.quad(Vector3(-0.4 + i * 0.3, 0.125, 0.22), Vector3(-0.38 + i * 0.3, 0.125, 0.22), Vector3(-0.38 + i * 0.3, 0.125, -0.22), Vector3(-0.4 + i * 0.3, 0.125, -0.22), P.EARTH[2] if not rot else P.INK[2])
			k.made.pop()
	if dress.cold():
		drift(k, Vector3(0.1, 0.0, -0.3), 0.9, 0.45, 0.2, 0.3, dress.snow[0], s + 30)
	elif BiomeDressing.reedy(c):
		var rs := k.made.vertex_count()
		for i in 6:
			var a := float(i) * 1.1
			var base := Vector3(cos(a) * 0.7, 0.0, sin(a) * 0.6)
			k.blade(base, base + Vector3(0.04, 0.55 + Kit.j(s, i, 0.15), 0.0), 0.05, a, P.SPRUCE[3] if i % 2 else P.MOSS[3])
		k.sway_by_height(rs, 0.0, 0.6, 0.6)
	elif dress.covers != &"needles":
		drift(k, Vector3(-0.5, 0.0, -0.35), 0.6, 0.3, 0.1, 0.4, d[0], s + 31)


## Where the dead of one day are remembered. 0: a board of names on two posts,
## the names scratched in ruled rows, photographs gone pale, ribbons, jars with
## candles someone still lights, flowers at its foot; 1: a cairn of stones with
## the things they carried set on it (a helmet, boots, a toy), a machine's plate
## propped against it with its glyph struck out, candles.
static func memorial(k: Kit, v: int, c: int) -> void:
	var dress := BiomeDressing.of(c)
	var s := 25200 + v * 7 + c
	var wood := wood_of(c)
	var d := drift_of(c)
	if v % 2 == 0:
		for sz: float in [-0.5, 0.5]:
			k.limb(Vector3(0.0, -0.1, sz), Vector3(Kit.j(s, int(sz * 4.0) + 2, 0.04), 1.3, sz + Kit.j(s, int(sz * 4.0) + 5, 0.03)), 0.045, 0.035, 5, wood[0])
		k.slab(0.02, 0.5, 0.0, 0.05, 0.62, 1.05, s, wood[1], wood[0], 0.025)
		k.slab(0.02, 1.12, 0.0, 0.05, 0.1, 1.2, s + 1, wood[0], wood[1], 0.02, 0.0)
		# The names: rows of short strokes, a few longer; pale squares of photographs.
		var ink: Color = P.LINEN[4] if BiomeDressing.burnt(c) else P.INK[1]
		for r in 5:
			var y := 0.58 + r * 0.1
			var z := -0.44
			var i := 0
			while z < 0.42:
				var wlen := 0.05 + Rng.hash01(s, r, i) * 0.12
				k.made.quad(Vector3(0.049, y, z), Vector3(0.049, y, z + wlen), Vector3(0.049, y + 0.025, z + wlen), Vector3(0.049, y + 0.025, z), ink)
				z += wlen + 0.04
				i += 1
		for i in 4:
			var z := -0.38 + i * 0.24 + Kit.j(s, i + 30, 0.04)
			var y := 0.92 + Kit.j(s, i + 40, 0.06)
			k.made.quad(Vector3(0.052, y, z - 0.06), Vector3(0.052, y, z + 0.06), Vector3(0.055, y + 0.14, z + 0.07), Vector3(0.055, y + 0.14, z - 0.05), P.LINEN[5] if i % 2 else P.LINEN[4])
			k.made.quad(Vector3(0.057, y + 0.03, z - 0.035), Vector3(0.057, y + 0.03, z + 0.035), Vector3(0.058, y + 0.1, z + 0.035), Vector3(0.058, y + 0.1, z - 0.035), P.SLATE[2])
		# Ribbons tied on the posts, long faded.
		for sz: float in [-0.5, 0.5]:
			k.fleck(Vector3(0.03, 1.2, sz), Vector3(0.08, 0.85, sz + 0.06), Vector3(0.05, 0.9, sz - 0.02), P.BLOOM[1] if sz < 0.0 else P.BRINE[3])
		# At its foot: jars with candle stubs, flowers, a toy left propped.
		for i in 3:
			var z := -0.35 + i * 0.35
			k.made.prism(0.3, -0.02, z, 0.055, 0.13, 0.05, 7, P.SPRUCE[3], P.SPRUCE[4])
			k.made.prism(0.3, 0.05, z, 0.02, 0.11 + (i % 2) * 0.03, 0.017, 5, GroundColors.lamp(P.EMBER[4], 1.4))
		for i in 5:
			var p := Vector3(0.45 + Kit.j(s, i + 50, 0.12), 0.03, -0.3 + i * 0.15)
			k.limb(p, p + Vector3(0.12, 0.02, 0.03), 0.01, 0.008, 3, P.SPRUCE[2])
			k.fleck(p + Vector3(0.12, 0.02, 0.0), p + Vector3(0.18, 0.05, 0.03), p + Vector3(0.14, 0.07, -0.03), P.BLOOM[4] if i % 2 else P.LINEN[5])
		k.slab(0.24, 0.0, 0.52, 0.14, 0.18, 0.12, s + 3, P.EARTH[3], P.EARTH[3], 0.02)
		k.made.prism(0.24, 0.18, 0.52, 0.06, 0.28, 0.05, 6, P.EARTH[3])
	else:
		# The cairn, stones placed by many hands.
		for i in 9:
			var a := float(i) * 2.2
			var course := floori(i / 3.0)
			var r := 0.46 - course * 0.14
			k.stone(cos(a) * r, course * 0.22 - 0.06, sin(a) * r, 0.2 - course * 0.03, 0.26, s + i, [P.STONE[3], P.LINEN[3], P.STONE[2]][i % 3], 6)
		k.stone(0.0, 0.58, 0.0, 0.12, 0.2, s + 20, P.LINEN[4], 5)
		# A helmet on the top, boots at the foot, a toy.
		k.made.prism(0.02, 0.76, 0.0, 0.13, 0.86, 0.06, 8, P.SLATE[2], P.SLATE[3])
		for sz: float in [0.52, 0.66]:
			k.slab(0.5, -0.02, sz, 0.22, 0.12, 0.1, s + int(sz * 100.0), P.INK[2], P.EARTH[1], 0.015)
			k.slab(0.44, 0.1, sz, 0.09, 0.14, 0.1, s + int(sz * 100.0) + 1, P.INK[2], P.EARTH[1], 0.01)
		k.slab(-0.45, 0.0, 0.5, 0.12, 0.16, 0.1, s + 30, P.BLOOM[2], P.RUST[3], 0.02)
		k.made.prism(-0.45, 0.16, 0.5, 0.055, 0.25, 0.05, 6, P.BLOOM[2])
		# The machines' plate, its glyph struck through by hand.
		k.found.push(Transform3D(Basis(Vector3.BACK, -0.35), Vector3(0.52, -0.05, -0.2)))
		k.plate(Vector3(0.0, 0.0, 0.26), Vector3(0.0, 0.0, -0.26), Vector3(0.0, 0.52, -0.26), Vector3(0.0, 0.52, 0.26), P.PLATE[3], P.PLATE[1], P.PLATE[5])
		k.found.tri(Vector3(0.014, 0.12, 0.12), Vector3(0.014, 0.12, -0.12), Vector3(0.014, 0.38, 0.0), P.PLATE[5])
		k.found.pop()
		k.made.push(Transform3D(Basis(Vector3.BACK, -0.35), Vector3(0.52, -0.05, -0.2)))
		k.made.quad(Vector3(0.022, 0.1, 0.2), Vector3(0.022, 0.14, 0.22), Vector3(0.022, 0.42, -0.2), Vector3(0.022, 0.38, -0.22), P.INK[0])
		k.made.pop()
		for i in 2:
			var z := -0.55 + i * 0.25
			k.made.prism(0.2, -0.02, z, 0.05, 0.12, 0.045, 7, P.SPRUCE[3], P.SPRUCE[4])
			k.made.prism(0.2, 0.05, z, 0.018, 0.12, 0.015, 5, GroundColors.lamp(P.EMBER[4], 1.3))
	if dress.cold():
		drift(k, Vector3(-0.35, 0.0, 0.0), 0.8, 0.6, 0.22, 1.57, dress.snow[0], s + 60)
	elif not BiomeDressing.mossy(c):
		drift(k, Vector3(-0.4, 0.0, -0.4), 0.6, 0.3, 0.1, 0.5, d[0], s + 61)
