extends RefCounted
## Houses and ruins. Each house is one picture read in order: silhouette, then
## roof material, then walls (art-audio-extract §5). All are MADE (irregular
## footprints, leaning walls, sagging ridges, chimneys off true, turf banked at
## the foot) except what came off machines, which is FOUND: roof plate laid
## where the old roof failed, cable, cast discs, the lived-in machine housing of
## the "but", and the enamel plate on the wall. The plate is ruled; the line
## struck through it is drawn by hand.
##
## A house faces +X (its door), like every model.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.HAND)
	if kind == PropKind.RUIN:
		ruin(k, v, c)
		return
	match v:
		0: washed(k, c, 0)
		1: slated(k, c, 0)
		2: long_house(k, c)
		3: but(k, c)
		4: washed(k, c, 1)
		5: slated(k, c, 1)
		_: washed(k, c, 2)


## Variants of HOUSE (PropModels.variants): three washed, two slated, the long
## house and the but, so a village is never a row of one house.
const VARIANTS := 7


## Four leaning walls on an irregular footprint. Returns the corners as
## [b00, b10, b11, b01, t00, t10, t11, t01] (b bottom, t top; x then z).
static func walls(k: Kit, w: float, d: float, h: float, seed_value: int, front: Color, side: Color, lean: Vector3 = Vector3(0.05, 0.0, 0.03)) -> Array[Vector3]:
	var c: Array[Vector3] = []
	var sx: Array[float] = [-1.0, 1.0, 1.0, -1.0]
	var sz: Array[float] = [-1.0, -1.0, 1.0, 1.0]
	for i in 4:
		c.append(Vector3(sx[i] * w * 0.5 + Kit.j(seed_value, i, 0.1), 0.0, sz[i] * d * 0.5 + Kit.j(seed_value, i + 4, 0.1)))
	for i in 4:
		# Walls batter in and lean, and no two corners stand the same height.
		var b := c[i]
		c.append(Vector3(b.x * 0.94, h + Kit.j(seed_value, i + 8, 0.07), b.z * 0.955) + lean * h * 1.4)
	# Faces: +x front (door), +z, -x, -z. Order bottom-left, bottom-right, top-right, top-left seen from outside.
	k.made.quad(c[2], c[1], c[5], c[6], front)
	k.made.quad(c[3], c[2], c[6], c[7], side)
	k.made.quad(c[0], c[3], c[7], c[4], GroundColors.down(side, 0.2))
	k.made.quad(c[1], c[0], c[4], c[5], GroundColors.down(front, 0.15))
	return c


## A point on a wall face (bl, br, tr, tl), u along, v up, pushed out a hair.
static func on_wall(bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, u: float, v: float, out: float = 0.01) -> Vector3:
	var p := bl.lerp(br, u).lerp(tl.lerp(tr, u), v)
	var n := (tr - br).cross(bl - br).normalized()
	return p + n * out


## A rectangle on a wall face from (u0, v0) to (u1, v1).
static func wall_rect(pen: MeshKit, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, u0: float, v0: float, u1: float, v1: float, out: float, col: Color) -> void:
	pen.quad(on_wall(bl, br, tr, tl, u0, v0, out), on_wall(bl, br, tr, tl, u1, v0, out), on_wall(bl, br, tr, tl, u1, v1, out), on_wall(bl, br, tr, tl, u0, v1, out), col)


## The enamel plate the machinery still counts a house by, struck through by
## hand, a third of the way along the wall and a little under half height.
static func struck_plate(k: Kit, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, u: float, v: float) -> void:
	var wlen := bl.distance_to(br)
	var hu := 0.16 / wlen
	var hv := 0.11
	wall_rect(k.found, bl, br, tr, tl, u - hu, v - hv, u + hu, v + hv, 0.012, P.INK[0])
	wall_rect(k.found, bl, br, tr, tl, u - hu * 0.85, v - hv * 0.8, u + hu * 0.85, v + hv * 0.8, 0.016, P.RIME[5])
	for t in 5:
		var tu := u - hu * 0.6 + t * hu * 0.3
		wall_rect(k.found, bl, br, tr, tl, tu - 0.006, v + 0.02, tu + 0.006, v + 0.06, 0.02, P.SLATE[2])
	# The strike: thick, a little off level, past both edges.
	k.made.quad(on_wall(bl, br, tr, tl, u - hu * 1.25, v - 0.05, 0.026), on_wall(bl, br, tr, tl, u + hu * 1.25, v + 0.03, 0.026), on_wall(bl, br, tr, tl, u + hu * 1.25, v + 0.065, 0.026), on_wall(bl, br, tr, tl, u - hu * 1.25, v - 0.015, 0.026), P.INK[0])


## A window: a copper frame over glass that is lit at night.
static func window(k: Kit, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, u: float, v: float, hw: float, hh: float) -> void:
	wall_rect(k.made, bl, br, tr, tl, u - hw, v - hh, u + hw, v + hh, 0.012, P.COPPER[1])
	wall_rect(k.made, bl, br, tr, tl, u - hw * 0.72, v - hh * 0.75, u + hw * 0.72, v + hh * 0.75, 0.016, GroundColors.lamp(P.COPPER[4], 0.9))
	wall_rect(k.made, bl, br, tr, tl, u - hw * 0.08, v - hh * 0.75, u + hw * 0.08, v + hh * 0.75, 0.02, P.COPPER[2])


## Ink & Neon: a tube of stolen neon fixed to a wall, lit at night: somebody
## wired a machine's light into their house. Its colour is the house's own.
static func neon_tube(k: Kit, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, u0: float, u1: float, v: float, col: Color) -> void:
	wall_rect(k.made, bl, br, tr, tl, u0 - 0.01, v - 0.02, u1 + 0.01, v + 0.02, 0.03, P.INK[1])
	wall_rect(k.made, bl, br, tr, tl, u0, v - 0.011, u1, v + 0.011, 0.04, GroundColors.lamp(col, 2.0))


const NEON_TUBES: Array[Color] = [Color(0.3, 0.95, 1.0), Color(1.0, 0.25, 0.8), Color(0.55, 1.0, 0.35)]


## A plank door, its latch.
static func door(k: Kit, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, u: float, hw: float, hv: float) -> void:
	wall_rect(k.made, bl, br, tr, tl, u - hw * 1.2, 0.0, u + hw * 1.2, hv + 0.05, 0.012, P.EARTH[1])
	for p in 3:
		var pu := u - hw + (p + 0.5) * (2.0 * hw / 3.0)
		wall_rect(k.made, bl, br, tr, tl, pu - hw / 3.0 + 0.012, 0.01, pu + hw / 3.0 - 0.012, hv - 0.02 * p, 0.018, P.EARTH[2] if p != 1 else P.EARTH[3])
	wall_rect(k.made, bl, br, tr, tl, u - hw * 0.7, hv * 0.45, u - hw * 0.5, hv * 0.52, 0.026, P.COPPER[3])


## Turf banked against the foot of the walls.
static func turf_foot(k: Kit, corners: Array[Vector3], seed_value: int, c: int) -> void:
	var cols: Array[Color] = [P.MOSS[2], P.MOSS[3]]
	match c:
		Country.SNOWFIELD: cols = [P.RIME[4], P.RIME[5]]
		Country.BURNING: cols = [P.ASH[1], P.EARTH[1]]
		Country.BONELANDS: cols = [P.MOSS[3].lerp(P.SAND[4], 0.4), P.MOSS[3]]
	for side in 4:
		var a := corners[side]
		var b := corners[(side + 1) % 4]
		var out := Vector3(b.z - a.z, 0, a.x - b.x).normalized() * -0.04
		for i in 4:
			var p := a.lerp(b, (i + 0.5) / 4.0) + out
			k.clump(p.x, -0.05, p.z, 0.16 + Kit.j(seed_value, side * 10 + i, 0.05), 0.18 + Kit.j(seed_value, side * 20 + i, 0.06), seed_value + side * 7 + i, cols[(i + side) % 2], 6)


## A hipped roof over the wall tops: eaves out by `over`, a ridge along z of half
## length `rz` that sags in the middle. `pen` draws the slopes (MADE or FOUND).
## Returns [e00, e10, e11, e01, r0, rm, r1].
static func hipped(k: Kit, pen: MeshKit, t: Array[Vector3], over: float, rise: float, rz: float, sag: float, front: Color, back: Color, ends: Color) -> Array[Vector3]:
	var centre := (t[0] + t[1] + t[2] + t[3]) * 0.25
	var e: Array[Vector3] = []
	for i in 4:
		var dir := (t[i] - centre)
		dir.y = 0.0
		e.append(t[i] + dir.normalized() * over + Vector3(0, -0.06, 0))
	var yr := centre.y + rise
	var r0 := Vector3(centre.x, yr, centre.z - rz)
	var r1 := Vector3(centre.x, yr, centre.z + rz)
	var rm := Vector3(centre.x, yr - sag, centre.z)
	# Front (+x) slope: e10 -> e11 along the eave, up to r1, rm, r0.
	pen.tri(e[2], e[1], rm, front)
	pen.tri(r1, e[2], rm, front)
	pen.tri(rm, e[1], r0, front)
	# Back (-x) slope.
	pen.tri(e[0], e[3], rm, back)
	pen.tri(r0, e[0], rm, back)
	pen.tri(rm, e[3], r1, back)
	# Hip ends.
	pen.tri(e[3], e[2], r1, ends)
	pen.tri(e[1], e[0], r0, GroundColors.down(ends, 0.3))
	# The dark overhang under the eaves.
	k.made.quad(e[0], e[1], e[2], e[3], P.INK[2])
	return [e[0], e[1], e[2], e[3], r0, rm, r1]


## "washed": lime-washed rubble walls under a hipped roof re-laid in plate,
## a few old slates left where they held. `form` varies the proportions, where
## the wash has come off, where the roof failed and was plated, and the chimney,
## so no two in a village are the same drawing.
static func washed(k: Kit, c: int, form: int) -> void:
	var s := 1400 + form * 37
	var w: float = [2.3, 2.0, 2.6][form]
	var d: float = [2.9, 2.5, 3.3][form]
	var h: float = [1.35, 1.2, 1.45][form]
	var wash: Color = [P.LINEN[4], P.LINEN[5].lerp(P.LINEN[4], 0.5), P.LINEN[4].lerp(P.SAND[4], 0.35)][form]
	var t := walls(k, w, d, h, s, wash, GroundColors.down(wash, 0.35))
	var fb := [t[2], t[1], t[5], t[6]]
	# Wash off in patches where the roof drips and boots scuff: rubble shows.
	for i in 2 + form:
		var u0 := fmod(0.13 + i * 0.41 + form * 0.23, 0.8)
		var v0 := fmod(0.05 + i * 0.57 + form * 0.31, 0.75)
		wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], u0, v0, u0 + 0.12 + fmod(i * 0.13, 0.12), v0 + 0.1 + fmod(i * 0.07, 0.12), 0.008, P.STONE[2] if i % 2 == 0 else P.STONE[3])
	wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], 0.0, 0.0, 1.0, 0.07, 0.006, P.LINEN[2])
	var door_u: float = [0.34, 0.66, 0.46][form]
	door(k, fb[0], fb[1], fb[2], fb[3], door_u, 0.1, 0.95)
	if form == 1:
		# One house in three wired a machine's light over its door.
		neon_tube(k, fb[0], fb[1], fb[2], fb[3], door_u - 0.14, door_u + 0.14, 0.86, NEON_TUBES[form % 3])
	window(k, fb[0], fb[1], fb[2], fb[3], 0.8 if door_u < 0.5 else 0.22, 0.6, 0.08, 0.13)
	if form == 2:
		window(k, fb[0], fb[1], fb[2], fb[3], 0.18, 0.58, 0.07, 0.12)
	struck_plate(k, fb[0], fb[1], fb[2], fb[3], [0.58, 0.36, 0.72][form], [0.44, 0.5, 0.4][form])
	var sb := [t[3], t[2], t[6], t[7]]
	window(k, sb[0], sb[1], sb[2], sb[3], [0.4, 0.62, 0.3][form], 0.58, 0.08, 0.13)
	# The roof: old slate by hand, with plate off a machine laid where it failed.
	var r := hipped(k, k.made, t, 0.24, [1.05, 0.9, 1.2][form], d * 0.2, [0.12, 0.16, 0.08][form], P.SLATE[2], P.SLATE[1], P.SLATE[2].lerp(P.SLATE[1], 0.5))
	for i in 3:
		var f := 0.25 + i * 0.25
		var a := r[1].lerp(r[4], f) + Vector3(0.01, 0.012, 0)
		var b := r[2].lerp(r[6], f) + Vector3(0.01, 0.012, 0)
		k.made.quad(b, a, a + Vector3(-0.03, 0.02, 0), b + Vector3(-0.03, 0.02, 0), P.SLATE[1])
	match form:
		0:
			_patch(k, r[1], r[2], r[6], r[4], 0.15, 0.5, 0.42, 0.82)
			_patch(k, r[1], r[2], r[6], r[4], 0.64, 0.12, 0.92, 0.36)
		1:
			# A whole strip along the eave, where the rot started.
			_patch(k, r[1], r[2], r[6], r[4], 0.04, 0.04, 0.5, 0.26)
			_patch(k, r[1], r[2], r[6], r[4], 0.5, 0.06, 0.96, 0.3)
		_:
			_patch(k, r[1], r[2], r[6], r[4], 0.36, 0.34, 0.64, 0.7)
	k.made.strut(r[4] + Vector3(0, 0.02, 0), r[5] + Vector3(0, 0.02, 0), 0.035, 4, P.SLATE[3])
	k.made.strut(r[5] + Vector3(0, 0.02, 0), r[6] + Vector3(0, 0.02, 0), 0.035, 4, P.SLATE[3])
	_chimney(k, [-0.45, 0.35, -0.3][form], h - 0.2, [-d * 0.3, d * 0.32, -d * 0.05][form], [1.45, 1.3, 1.6][form], s + 10)
	turf_foot(k, t, s + 20, c)
	if c == Country.SNOWFIELD:
		_snow_on(k, r)


## "slated": a gable house of rubble; half its slates, the other half replaced
## in plate course by course.
static func slated(k: Kit, c: int, form: int) -> void:
	var s := 1500 + form * 41
	var w := 2.2 if form == 0 else 1.9
	var d := 3.1 if form == 0 else 3.6
	var h := 1.3 if form == 0 else 1.15
	# Warm grey rubble, a clear step lighter than the slate over it.
	var rubble: Color = P.STONE[3].lerp(P.SAND[3], 0.4) if form == 0 else P.STONE[3].lerp(P.LINEN[3], 0.35)
	var t := walls(k, w, d, h, s, rubble, GroundColors.down(rubble, 0.3), Vector3(-0.04, 0, 0.02) if form == 0 else Vector3(0.03, 0, -0.03))
	var fb := [t[2], t[1], t[5], t[6]]
	# Quoins lighter at the corners, a few dark stones in the courses.
	for i in 5:
		wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], 0.0, i * 0.2, 0.08 + (i % 2) * 0.04, i * 0.2 + 0.16, 0.008, GroundColors.up(rubble, 0.35))
		wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], 0.9 - (i % 2) * 0.04, i * 0.2 + 0.04, 1.0, i * 0.2 + 0.18, 0.008, GroundColors.up(rubble, 0.35))
	for i in 8:
		var u := 0.15 + fmod(i * 0.37, 0.7)
		var vv := 0.1 + fmod(i * 0.41, 0.8)
		wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], u, vv, u + 0.06, vv + 0.07, 0.008, P.SLATE[2] if i % 2 else P.STONE[1])
	door(k, fb[0], fb[1], fb[2], fb[3], 0.64 if form == 0 else 0.3, 0.1, 0.95)
	if form == 0:
		neon_tube(k, fb[0], fb[1], fb[2], fb[3], 0.48, 0.8, 0.84, NEON_TUBES[1])
	window(k, fb[0], fb[1], fb[2], fb[3], 0.24 if form == 0 else 0.74, 0.6, 0.08, 0.13)
	struck_plate(k, fb[0], fb[1], fb[2], fb[3], 0.4 if form == 0 else 0.52, 0.42)
	# Gable roof, ridge along z, sagging. Front slope: slate low (MADE), plate high (FOUND).
	var over := 0.2
	var yr := h + 1.05
	var cx := (t[4].x + t[5].x + t[6].x + t[7].x) * 0.25
	var ez := d * 0.5 + 0.14
	var ex := w * 0.5 + over
	var sag := 0.07
	var courses := 6
	for i in courses:
		var f0 := float(i) / courses
		var f1 := float(i + 1) / courses
		for half in 2:
			var z0 := -ez if half == 0 else 0.0
			var z1 := 0.0 if half == 0 else ez
			var ya0 := lerpf(h - 0.05, yr, f0)
			var ya1 := lerpf(h - 0.05, yr, f1)
			var s0 := sag * f0
			var s1 := sag * f1
			var a0 := Vector3(cx + ex * (1.0 - f0), ya0 - (s0 if z0 == 0.0 else 0.0), z0)
			var b0 := Vector3(cx + ex * (1.0 - f0), ya0 - (s0 if z1 == 0.0 else 0.0), z1)
			var a1 := Vector3(cx + ex * (1.0 - f1), ya1 - (s1 if z0 == 0.0 else 0.0), z0)
			var b1 := Vector3(cx + ex * (1.0 - f1), ya1 - (s1 if z1 == 0.0 else 0.0), z1)
			# Half the slates held; the rest were replaced in plate course by course.
			var plate := (i >= 4 and half == 1) if form == 0 else (i <= 1 or (i == 2 and half == 0))
			var pen := k.found if plate else k.made
			var col: Color = (P.PLATE[3] if i % 2 == 0 else P.PLATE[2]) if plate else (P.SLATE[3] if i % 2 == 0 else P.SLATE[2])
			pen.quad(b0, a0, a1, b1, col)
	# Back slope: plate, with one patch of old slate.
	var bk0 := Vector3(cx - ex, h - 0.05, -ez)
	var bk1 := Vector3(cx - ex, h - 0.05, ez)
	var rr0 := Vector3(cx, yr, -ez)
	var rr1 := Vector3(cx, yr, ez)
	var rrm := Vector3(cx, yr - sag, 0.0)
	k.made.tri(bk0, bk1, rrm, P.SLATE[2])
	k.made.tri(bk0, rrm, rr0, P.SLATE[2])
	k.made.tri(bk1, rr1, rrm, P.SLATE[2])
	k.made.quad(Vector3(cx - ex, h - 0.05, -ez), Vector3(cx + ex, h - 0.05, -ez), Vector3(cx + ex, h - 0.05, ez), Vector3(cx - ex, h - 0.05, ez), P.INK[2])
	# Gable ends in stone.
	k.made.tri(t[7] + Vector3(0, 0, 0.004), t[6] + Vector3(0, 0, 0.004), Vector3(cx, yr - 0.06, t[6].z + 0.004), GroundColors.down(rubble, 0.3))
	k.made.tri(t[5] + Vector3(0, 0, -0.004), t[4] + Vector3(0, 0, -0.004), Vector3(cx, yr - 0.06, t[4].z - 0.004), GroundColors.down(rubble, 0.5))
	# The ridge, lighter than the eaves.
	k.made.strut(rr0 + Vector3(0, 0.03, 0), rrm + Vector3(0, 0.03, 0), 0.04, 4, P.SLATE[4])
	k.made.strut(rrm + Vector3(0, 0.03, 0), rr1 + Vector3(0, 0.03, 0), 0.04, 4, P.SLATE[4])
	_chimney(k, cx + 0.05, yr - 0.55, (d * 0.5 - 0.24) * (1.0 if form == 0 else -1.0), 1.0, s + 10)
	turf_foot(k, t, s + 20, c)
	if c == Country.SNOWFIELD:
		# Snow over both slopes, the eaves left dark.
		var sl := Vector3(0, 0.05, 0)
		k.made.quad(Vector3(cx + ex * 0.85, lerpf(h, yr, 0.15), ez) + sl, Vector3(cx + ex * 0.85, lerpf(h, yr, 0.15), -ez) + sl, Vector3(cx, yr - sag, -ez * 0.2) + sl, Vector3(cx, yr - sag, ez * 0.2) + sl, P.RIME[5])
		k.made.tri(Vector3(cx + ex * 0.85, lerpf(h, yr, 0.15), ez) + sl, Vector3(cx, yr - sag, ez * 0.2) + sl, Vector3(cx, yr, ez) + sl, P.RIME[5])
		k.made.tri(Vector3(cx, yr - sag, -ez * 0.2) + sl, Vector3(cx + ex * 0.85, lerpf(h, yr, 0.15), -ez) + sl, Vector3(cx, yr, -ez) + sl, P.RIME[5])
		k.made.quad(Vector3(cx - ex * 0.85, lerpf(h, yr, 0.15), -ez) + sl, Vector3(cx - ex * 0.85, lerpf(h, yr, 0.15), ez) + sl, Vector3(cx, yr - sag, ez * 0.2) + sl, Vector3(cx, yr - sag, -ez * 0.2) + sl, P.RIME[4])


## "long": a low stone house under deep thatch roped down with cable and
## weighted with cast discs, built against the foot of a lattice pylon.
static func long_house(k: Kit, c: int) -> void:
	var s := 1600
	var w := 2.0
	var d := 3.4
	var h := 0.95
	k.made.push(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.2)))
	var t := walls(k, w, d, h, s, P.STONE[2], GroundColors.down(P.STONE[2], 0.25), Vector3(0.03, 0, 0.0))
	k.made.pop()
	for i in t.size():
		t[i] += Vector3(0, 0, 0.2)
	var fb := [t[2], t[1], t[5], t[6]]
	door(k, fb[0], fb[1], fb[2], fb[3], 0.26, 0.1, 0.82)
	window(k, fb[0], fb[1], fb[2], fb[3], 0.68, 0.55, 0.07, 0.12)
	struck_plate(k, fb[0], fb[1], fb[2], fb[3], 0.48, 0.45)
	# Thatch: a deep, soft hip with a ragged eave.
	var r := hipped(k, k.made, t, 0.36, 1.25, d * 0.3, 0.16, P.EARTH[3], P.EARTH[2], P.EARTH[3].lerp(P.SAND[3], 0.4))
	for i in 10:
		var f := (i + 0.5) / 10.0
		var a := r[1].lerp(r[2], f)
		var drop := 0.06 + fmod(i * 0.37, 0.09)
		k.made.tri(a + Vector3(0.02, -drop * 0.3, 0.17), a + Vector3(0.02, -drop, -0.17), a + Vector3(-0.14, 0.16, 0.0), P.EARTH[2] if i % 2 else P.SAND[3])
	for f: float in [0.35, 0.62]:
		var a := r[1].lerp(r[4], f) + Vector3(0.02, 0.02, 0)
		var b := r[2].lerp(r[6], f) + Vector3(0.02, 0.02, 0)
		k.made.quad(b, a, a + Vector3(-0.08, 0.06, 0), b + Vector3(-0.08, 0.06, 0), P.EARTH[2])
	# Cables over the ridge, a cast disc hanging at each end (FOUND).
	for i in 4:
		var f := 0.15 + i * 0.23
		var eave_f := r[1].lerp(r[2], f)
		var eave_b := r[0].lerp(r[3], f)
		var ridge := r[4].lerp(r[6], f) + Vector3(0, 0.04, 0)
		k.cable(eave_f + Vector3(0.05, 0.05, 0), ridge, -0.04, 3, 0.011, P.INK[2])
		k.cable(ridge, eave_b + Vector3(-0.05, 0.05, 0), -0.04, 3, 0.011, P.INK[2])
		for side: Vector3 in [eave_f + Vector3(0.06, 0.0, 0), eave_b + Vector3(-0.06, 0.0, 0)]:
			k.rod(side, side + Vector3(0, -0.3, 0), 0.01, 3, P.INK[2])
			k.found.push(Transform3D(Basis(Vector3.BACK, PI * 0.5), side + Vector3(0, -0.36, 0)))
			k.found.prism(0, -0.025, 0, 0.1, 0.025, 0.1, 10, P.STONE[3], P.STONE[4])
			k.found.pop()
	# The pylon foot it leans on: exact lattice, cut off above the roof.
	var pz := -d * 0.5 - 0.3
	var legs: Array[Vector2] = [Vector2(-0.46, pz - 0.46), Vector2(0.46, pz - 0.46), Vector2(0.46, pz + 0.46), Vector2(-0.46, pz + 0.46)]
	for i in 4:
		var l := legs[i]
		var n := legs[(i + 1) % 4]
		var lt := Vector3(l.x * 0.72, 2.7, pz + (l.y - pz) * 0.72)
		k.rod(Vector3(l.x, 0, l.y), lt, 0.04, 4, P.PLATE[3])
		for yy: float in [0.9, 1.8, 2.7]:
			var f := 1.0 - yy / 2.7 * 0.28
			k.rod(Vector3(l.x * f, yy, pz + (l.y - pz) * f), Vector3(n.x * f, yy, pz + (n.y - pz) * f), 0.022, 4, P.PLATE[2])
		k.rod(Vector3(l.x, 0.05, l.y), Vector3(n.x * 0.9, 0.9, pz + (n.y - pz) * 0.9), 0.016, 4, P.PLATE[2])
		k.chamfer(l.x, -0.04, l.y, 0.2, 0.14, 0.2, 0.04, P.STONE[2], P.STONE[3])
	turf_foot(k, t, s + 20, c)
	if c == Country.SNOWFIELD:
		_snow_on(k, r)


## "but": a machine housing lived in. The housing is FOUND and exact: rounded
## shoulders, riveted ribs, a bullnose lid, the original hatch. Everything the
## people did to it is MADE: sods along the lid, a stone chimney through it, a
## plank door in the burnt-through hole, bars across the hatch.
static func but(k: Kit, c: int) -> void:
	var w := 2.1
	var d := 2.6
	var h := 1.15
	# Weathered: a housing that has stood in the rain for years, not a live machine.
	var plate := P.PLATE[2]
	var lit := P.PLATE[3]
	var dark := P.PLATE[1]
	k.chamfer(0, 0, 0, w, h, d, 0.24, plate, lit)
	# The bullnose lid.
	k.chamfer(0, h - 0.02, 0, w - 0.3, 0.28, d - 0.3, 0.3, plate, lit)
	# Ribs and rivet rows, exact, on both seen faces.
	for rz: float in [-0.46, 0.46]:
		k.chamfer(w * 0.5 + 0.02, 0.0, rz, 0.05, h - 0.1, 0.09, 0.015, dark, plate)
		for i in 5:
			k.found.quad(Vector3(w * 0.5 + 0.048, 0.12 + i * 0.2, rz + 0.016), Vector3(w * 0.5 + 0.048, 0.12 + i * 0.2, rz - 0.016), Vector3(w * 0.5 + 0.048, 0.15 + i * 0.2, rz - 0.016), Vector3(w * 0.5 + 0.048, 0.15 + i * 0.2, rz + 0.016), P.PLATE[5])
	for rx: float in [-0.36, 0.36]:
		k.chamfer(rx, 0.0, d * 0.5 + 0.02, 0.09, h - 0.1, 0.05, 0.015, dark, plate)
	# Rust bleeding down from a rib.
	k.made.quad(Vector3(w * 0.5 + 0.05, 0.05, 0.52), Vector3(w * 0.5 + 0.05, 0.05, 0.4), Vector3(w * 0.5 + 0.05, 0.9, 0.44), Vector3(w * 0.5 + 0.05, 0.9, 0.48), P.RUST[3])
	var fx := w * 0.5 + 0.004
	# The door burnt through, a plank door hung in the hole (MADE).
	var hole: Array[Vector3] = [Vector3(fx, 0.02, -0.04), Vector3(fx, 0.02, -0.54), Vector3(fx, 0.5, -0.58), Vector3(fx, 0.92, -0.52), Vector3(fx, 1.0, -0.3), Vector3(fx, 0.95, -0.06), Vector3(fx, 0.55, 0.0)]
	var centre := Vector3(fx, 0.5, -0.28)
	for i in hole.size():
		k.made.tri(centre, hole[i], hole[(i + 1) % hole.size()], P.RUST[1])
	var fbl := Vector3(fx + 0.004, 0.0, 0.2)
	var fbr := Vector3(fx + 0.004, 0.0, -0.8)
	door(k, fbl, fbr, fbr + Vector3(0, 1.0, 0), fbl + Vector3(0, 1.0, 0), 0.48, 0.09, 0.86)
	window(k, Vector3(fx, 0, 1.2), Vector3(fx, 0, 0.3), Vector3(fx, 1, 0.3), Vector3(fx, 1, 1.2), 0.5, 0.62, 0.1, 0.14)
	# The original hatch, barred from outside.
	var fz := d * 0.5 + 0.004
	k.found.quad(Vector3(0.28, 0.28, fz), Vector3(0.9, 0.28, fz), Vector3(0.9, 0.9, fz), Vector3(0.28, 0.9, fz), P.PLATE[1])
	k.found.quad(Vector3(0.32, 0.32, fz + 0.004), Vector3(0.86, 0.32, fz + 0.004), Vector3(0.86, 0.86, fz + 0.004), Vector3(0.32, 0.86, fz + 0.004), dark)
	k.slab(0.6, 0.58, fz + 0.04, 0.86, 0.08, 0.04, 1330, P.EARTH[2], P.EARTH[3], 0.01, 0.0, 0.0)
	k.slab(0.58, 0.42, fz + 0.045, 0.8, 0.07, 0.04, 1331, P.EARTH[1], P.EARTH[2], 0.01)
	# A louvred vent and a junction box.
	for i in 4:
		k.chamfer(-0.55, 0.44 + i * 0.09, fz + 0.02, 0.4, 0.03, 0.04, 0.008, dark, lit)
	k.chamfer(-0.2, 0.72, fz + 0.04, 0.16, 0.2, 0.08, 0.02, dark, plate)
	var sb := [Vector3(fx, 0, d * 0.5), Vector3(fx, 0, -d * 0.5), Vector3(fx, 1, -d * 0.5), Vector3(fx, 1, d * 0.5)]
	struck_plate(k, sb[0], sb[1], sb[2], sb[3], 0.25, 0.3)
	# Sods laid along the lid, uneven.
	var top := h + 0.26
	for i in 5:
		var z := -d * 0.5 + 0.42 + i * 0.44
		k.slab(Kit.j(1301, i, 0.08), top, z, w - 0.7, 0.1, 0.42, 1300 + i, P.EARTH[2], P.MOSS[2] if i % 2 else P.MOSS[3], 0.03)
	# A stone chimney built by hand through the lid.
	_chimney(k, -0.55, top - 0.2, -0.8, 0.95, 1310)
	var foot: Array[Vector3] = [Vector3(-w * 0.5, 0, -d * 0.5), Vector3(w * 0.5, 0, -d * 0.5), Vector3(w * 0.5, 0, d * 0.5), Vector3(-w * 0.5, 0, d * 0.5)]
	turf_foot(k, foot, 1320, c)
	if c == Country.SNOWFIELD:
		# Snow lying on each sod and drifted against the chimney, the lid's
		# ruled edge left showing where the wind cleared it.
		for i in 5:
			var z := -d * 0.5 + 0.42 + i * 0.44
			var x := Kit.j(1301, i, 0.08)
			k.clump(x - 0.1 + fmod(i * 0.37, 0.2), top + 0.05, z, (w - 0.8) * 0.5, 0.12 + fmod(i * 0.13, 0.05), 1350 + i, P.RIME[5], 7)
			k.clump(x + 0.35 - fmod(i * 0.23, 0.2), top + 0.05, z + 0.08, 0.2, 0.1, 1370 + i, P.RIME[4], 6)
		k.clump(-0.4, top + 0.05, -0.62, 0.26, 0.2, 1360, P.RIME[5], 7)
		k.clump(w * 0.5 - 0.1, -0.04, -0.9, 0.34, 0.3, 1361, P.RIME[5], 7)


## A plate taken off a machine, laid on a front roof slope (e10, e11, r1, r0)
## between slope coordinates (u along the eave, v up the slope).
static func _patch(k: Kit, e10: Vector3, e11: Vector3, r1: Vector3, r0: Vector3, u0: float, v0: float, u1: float, v1: float) -> void:
	var lift := Vector3(0.012, 0.02, 0)
	var a := e10.lerp(e11, u0).lerp(r0.lerp(r1, u0), v0) + lift
	var b := e10.lerp(e11, u1).lerp(r0.lerp(r1, u1), v0) + lift
	var c := e10.lerp(e11, u1).lerp(r0.lerp(r1, u1), v1) + lift
	var d := e10.lerp(e11, u0).lerp(r0.lerp(r1, u0), v1) + lift
	k.plate(b, a, d, c, P.PLATE[2], P.PLATE[1], P.PLATE[4])


## A chimney built by hand: battered, off true, a cap stone on it.
static func _chimney(k: Kit, x: float, y0: float, z: float, h: float, seed_value: int) -> void:
	k.slab(x, y0, z, 0.36, h, 0.38, seed_value, P.STONE[2], P.STONE[1], 0.035, 0.2, Kit.j(seed_value, 1, 0.07))
	var lean := Kit.j(seed_value, 1, 0.07) * h
	k.slab(x + lean, y0 + h - 0.01, z, 0.36, 0.07, 0.38, seed_value + 1, P.STONE[3], P.STONE[3], 0.02)


## Snow lying on the upper slopes of a hipped roof.
static func _snow_on(k: Kit, r: Array[Vector3]) -> void:
	var lift := Vector3(0, 0.05, 0)
	var f := 0.45
	k.made.tri(r[2].lerp(r[6], f) + lift, r[1].lerp(r[4], f) + lift, r[5] + lift, P.RIME[5])
	k.made.tri(r[6] + lift, r[2].lerp(r[6], f) + lift, r[5] + lift, P.RIME[5])
	k.made.tri(r[5] + lift, r[1].lerp(r[4], f) + lift, r[4] + lift, P.RIME[5])
	k.made.tri(r[0].lerp(r[4], f) + lift, r[3].lerp(r[6], f) + lift, r[5] + lift, P.RIME[4])
	k.made.tri(r[4] + lift, r[0].lerp(r[4], f) + lift, r[5] + lift, P.RIME[4])
	k.made.tri(r[5] + lift, r[3].lerp(r[6], f) + lift, r[6] + lift, P.RIME[4])


## A ruin: drystone walls fallen to uneven heights, never a stack of blocks.
## Each wall is one battered mass with a broken top, faced in courses of
## uneven stones, coping lumps along what is left of the top, and the stones
## that fell lying in a spill at its foot, grassed over.
static func ruin(k: Kit, v: int, c: int) -> void:
	var stone: Array[Color] = [P.STONE[2], P.SLATE[2], P.STONE[3], P.SLATE[3]]
	if c == Country.BONELANDS:
		stone = [P.LINEN[3], P.LINEN[2], P.LINEN[4], P.SAND[3]]
	elif c == Country.BURNING:
		stone = [P.STONE[1], P.ASH[1], P.STONE[2], P.STONE[0]]
	elif c == Country.SNOWFIELD:
		stone = [P.SLATE[2], P.SLATE[3], P.STONE[3], P.RIME[2]]
	var s := 1700 + v * 31
	match v % 3:
		0:
			# The corner of a house: two walls highest where they meet.
			rubble_wall(k, Vector2(-1.0, -0.6), Vector2(1.1, -0.7), _broken([1.35, 1.2, 0.8, 0.9, 0.35, 0.2], s, 0.1), 0.34, s, stone)
			rubble_wall(k, Vector2(-1.0, -0.43), Vector2(-0.9, 0.95), _broken([1.3, 1.0, 0.55, 0.25, 0.3], s + 1, 0.08), 0.34, s + 1, stone)
			_spill(k, Vector2(0.2, -0.2), Vector2(0.9, 0.35), 9, s + 2, stone)
			_spill(k, Vector2(-0.55, 0.4), Vector2(0.3, 0.3), 5, s + 3, stone)
		1:
			# A gable end standing alone, its window open to the sky.
			var tops := _broken([0.55, 0.9, 1.5, 1.95, 1.5, 1.0, 0.8], s, 0.06)
			tops[1] = 0.5
			rubble_wall(k, Vector2(-1.0, 0.0), Vector2(1.0, 0.05), tops, 0.36, s, stone)
			var hole := [Vector2(-0.12, 0.72), Vector2(0.18, 0.72), Vector2(0.2, 1.08), Vector2(0.04, 1.2), Vector2(-0.12, 1.08)]
			for side: float in [1.0, -1.0]:
				var ring := PackedVector3Array()
				for q: Vector2 in hole:
					ring.append(Vector3(q.x, q.y, 0.025 + side * 0.19 - q.y * 0.04 * side))
				for i in range(1, ring.size() - 1):
					if side > 0.0:
						k.made.tri(ring[0], ring[i], ring[i + 1], P.INK[1])
					else:
						k.made.tri(ring[0], ring[i + 1], ring[i], P.INK[1])
			# The lintel fell and lies across the spill.
			k.slab(0.35, 0.02, 0.62, 0.62, 0.12, 0.16, s + 7, stone[2], GroundColors.up(stone[2], 0.2), 0.02, 0.1, 0.0)
			_spill(k, Vector2(-0.3, 0.5), Vector2(1.0, 0.4), 10, s + 2, stone)
			_spill(k, Vector2(0.2, -0.55), Vector2(0.8, 0.3), 5, s + 3, stone)
		_:
			# Footings of a long house, knee high, a doorway gap, the chimney
			# stack still standing at the gable.
			rubble_wall(k, Vector2(-1.2, -0.75), Vector2(1.1, -0.8), _broken([0.55, 0.4, 0.5, 0.3, 0.45], s, 0.08), 0.3, s, stone)
			rubble_wall(k, Vector2(1.1, -0.8), Vector2(1.15, 0.85), _broken([0.45, 0.3, 0.15, 0.35], s + 1, 0.06), 0.3, s + 1, stone)
			rubble_wall(k, Vector2(1.15, 0.85), Vector2(0.15, 0.8), _broken([0.4, 0.5, 0.25], s + 2, 0.06), 0.3, s + 2, stone)
			rubble_wall(k, Vector2(-0.45, 0.8), Vector2(-1.2, 0.78), _broken([0.3, 0.55], s + 3, 0.05), 0.3, s + 3, stone)
			rubble_wall(k, Vector2(-1.2, 0.95), Vector2(-1.2, -0.9), _broken([1.6, 1.7, 1.05, 0.5, 0.45], s + 4, 0.05), 0.36, s + 4, stone)
			_spill(k, Vector2(-0.6, 0.0), Vector2(0.5, 0.5), 7, s + 5, stone)
			_spill(k, Vector2(0.4, 1.1), Vector2(0.6, 0.2), 4, s + 6, stone)
	# Grass took the floor and the foot of every wall.
	var gs := k.made.vertex_count()
	for i in 7:
		var p := Vector2(-0.9 + i * 0.3 + Kit.j(s, 900 + i, 0.1), Kit.j(s, 920 + i, 0.6))
		k.clump(p.x, -0.04, p.y, 0.14 + Kit.j(s, 940 + i, 0.04), 0.16, s + 900 + i, P.MOSS[2] if i % 2 else P.MOSS[3], 6)
	k.sway_by_height(gs, 0.0, 0.18, 0.2)


## Heights at even steps along a wall from a few control heights: jagged by
## `jag`, with a gap bitten out of the top here and there.
static func _broken(ctrl: Array, seed_value: int, jag: float) -> PackedFloat32Array:
	var n := (ctrl.size() - 1) * 3
	var out := PackedFloat32Array()
	for i in n + 1:
		var f := float(i) / 3.0
		var a := mini(floori(f), ctrl.size() - 2)
		var h := lerpf(float(ctrl[a]), float(ctrl[a + 1]), f - a)
		h += Kit.j(seed_value, i + 300, jag)
		if Rng.hash01(seed_value, i, 301) < 0.18:
			h *= 0.7
		out.append(maxf(0.12, h))
	return out


## A drystone wall from a to b (plan x, z), its top at `tops` (even steps
## along it). Battered: its faces lean in as they rise. Faced in courses of
## uneven stones, each drawn a hair proud of a darker mass, and lumpy coping
## stones along the broken top.
static func rubble_wall(k: Kit, a: Vector2, b: Vector2, tops: PackedFloat32Array, thick: float, seed_value: int, stones: Array[Color]) -> void:
	var n := tops.size() - 1
	var run := b - a
	var length := run.length()
	var dir := run / length
	var nrm := Vector2(-dir.y, dir.x)
	var d3 := Vector3(dir.x, 0, dir.y)
	var n3 := Vector3(nrm.x, 0, nrm.y)
	var mass := GroundColors.down(stones[0], 0.4)
	const BATTER := 0.07
	var pen := k.made
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var p0 := a.lerp(b, t0)
		var p1 := a.lerp(b, t1)
		var h0 := tops[i]
		var h1 := tops[i + 1]
		var base := Vector3(0, -0.04, 0)
		var q0 := Vector3(p0.x, 0, p0.y)
		var q1 := Vector3(p1.x, 0, p1.y)
		var o0 := thick * 0.5 - BATTER * h0
		var o1 := thick * 0.5 - BATTER * h1
		var ab0 := q0 + n3 * thick * 0.5 + base
		var ab1 := q1 + n3 * thick * 0.5 + base
		var bb0 := q0 - n3 * thick * 0.5 + base
		var bb1 := q1 - n3 * thick * 0.5 + base
		var at0 := q0 + n3 * o0 + Vector3(0, h0, 0)
		var at1 := q1 + n3 * o1 + Vector3(0, h1, 0)
		var bt0 := q0 - n3 * o0 + Vector3(0, h0, 0)
		var bt1 := q1 - n3 * o1 + Vector3(0, h1, 0)
		pen.quad(ab0, ab1, at1, at0, mass)
		pen.quad(bb1, bb0, bt0, bt1, GroundColors.down(mass, 0.1))
		pen.quad(at0, at1, bt1, bt0, GroundColors.down(stones[1], 0.3))
		if i == 0:
			pen.quad(bb0, ab0, at0, bt0, GroundColors.down(mass, 0.05))
		if i == n - 1:
			pen.quad(ab1, bb1, bt1, at1, mass)
	# Courses of stone on both faces.
	var idx := 0
	for side: float in [1.0, -1.0]:
		var y := 0.0
		var course := 0
		while y < 2.2:
			var ch := 0.1 + Rng.hash01(seed_value, course, 11) * 0.12
			var u := -Rng.hash01(seed_value, course, 12) * 0.2
			while u < length:
				var sl := 0.12 + Rng.hash01(seed_value, idx, 13) * 0.3
				var u0 := maxf(u, 0.0) + 0.012
				var u1 := minf(u + sl, length) - 0.012
				u += sl
				idx += 1
				if u1 - u0 < 0.06:
					continue
				var top_here := minf(_top_at(tops, u0 / length), _top_at(tops, u1 / length)) - 0.025
				var y0 := y + 0.012
				var y1 := minf(y + ch - 0.012, top_here)
				if y1 - y0 < 0.05:
					continue
				var col := stones[int(Rng.hash01(seed_value, idx, 14) * 4.0) % 4].lerp(stones[0], 0.35)
				col = Kit.tone(col, 0.86 + Rng.hash01(seed_value, idx, 15) * 0.18)
				# A stone is a rough hexagon: corners knocked off, sides not true.
				var jx := Kit.j(seed_value, idx + 40, 0.02)
				var jy := Kit.j(seed_value, idx + 60, 0.015)
				var ym := (y0 + y1) * 0.5 + jy
				var ring: Array[Vector2] = [Vector2(u0 + 0.03, y0), Vector2(u1 - 0.02 + jx, y0 + 0.01), Vector2(u1, ym),
					Vector2(u1 - 0.03, y1), Vector2(u0 + 0.02 - jx, y1 - 0.01), Vector2(u0, ym - jy * 2.0)]
				var pts := PackedVector3Array()
				for r: Vector2 in ring:
					var off := thick * 0.5 - BATTER * r.y + 0.012
					var plan := a + dir * r.x + nrm * off * side
					pts.append(Vector3(plan.x, r.y - 0.04, plan.y))
				for e in range(1, 5):
					if side > 0.0:
						pen.tri(pts[0], pts[e], pts[e + 1], col)
					else:
						pen.tri(pts[0], pts[e + 1], pts[e], GroundColors.down(col, 0.08))
			y += ch
			course += 1
	# Coping: loose lumps along what is left of the top.
	var steps := int(length / 0.24)
	for i in steps:
		var t := (i + 0.5) / steps
		var h := _top_at(tops, t)
		if h < 0.22 or Rng.hash01(seed_value, i, 16) < 0.25:
			continue
		var p := a.lerp(b, t) + nrm * Kit.j(seed_value, i + 80, 0.05)
		k.stone(p.x, h - 0.05, p.y, thick * 0.42, 0.1 + Rng.hash01(seed_value, i, 17) * 0.06, seed_value + 200 + i, stones[(i + 2) % 4].lerp(stones[0], 0.4), 5, Kit.j(seed_value, i + 90, 0.3))


static func _top_at(tops: PackedFloat32Array, t: float) -> float:
	var f := clampf(t, 0.0, 1.0) * (tops.size() - 1)
	var i := mini(floori(f), tops.size() - 2)
	return lerpf(tops[i], tops[i + 1], f - i)


## Stones that fell, lying where they landed in a spill round `centre`
## (spread `size`), tipped and half sunk, a few big ones and many small.
static func _spill(k: Kit, centre: Vector2, size: Vector2, count: int, seed_value: int, stones: Array[Color]) -> void:
	for i in count:
		var p := centre + Vector2(Kit.j(seed_value, i, size.x * 0.5), Kit.j(seed_value, i + 20, size.y * 0.5))
		var big := Rng.hash01(seed_value, i, 3) < 0.35
		var r := (0.13 if big else 0.07) + Rng.hash01(seed_value, i, 4) * 0.05
		var col := stones[i % 4]
		if big and i % 3 == 0:
			k.made.push(Transform3D(Basis(Vector3.UP, Rng.hash01(seed_value, i, 5) * TAU) * Basis(Vector3.BACK, Kit.j(seed_value, i + 40, 0.35)), Vector3(p.x, -0.03, p.y)))
			k.slab(0, 0, 0, r * 2.6, r * 0.9, r * 1.5, seed_value + i, col, GroundColors.up(col, 0.15), 0.02, 0.15, 0.0)
			k.made.pop()
		else:
			k.stone(p.x, -0.05, p.y, r, r * (0.9 + Rng.hash01(seed_value, i, 6) * 0.6), seed_value + i * 3, col, 5, Kit.j(seed_value, i + 60, 0.4))
