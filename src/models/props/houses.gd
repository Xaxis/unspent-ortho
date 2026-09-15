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
	match v % 4:
		0: washed(k, c)
		1: slated(k, c)
		2: long_house(k, c)
		_: but(k, c)


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
## a few old slates left where they held, a cable off the ridge to a pole.
static func washed(k: Kit, c: int) -> void:
	var s := 1400
	var w := 2.3
	var d := 2.9
	var h := 1.35
	var t := walls(k, w, d, h, s, P.LINEN[4], P.LINEN[3])
	var fb := [t[2], t[1], t[5], t[6]]
	# Wash off in patches where the roof drips and boots scuff: rubble shows.
	wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], 0.62, 0.0, 0.9, 0.22, 0.008, P.STONE[2])
	wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], 0.05, 0.72, 0.3, 0.9, 0.008, P.STONE[2])
	wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], 0.0, 0.0, 1.0, 0.07, 0.006, P.LINEN[2])
	door(k, fb[0], fb[1], fb[2], fb[3], 0.34, 0.1, 0.95)
	window(k, fb[0], fb[1], fb[2], fb[3], 0.78, 0.6, 0.08, 0.13)
	struck_plate(k, fb[0], fb[1], fb[2], fb[3], 0.58, 0.44)
	var sb := [t[3], t[2], t[6], t[7]]
	window(k, sb[0], sb[1], sb[2], sb[3], 0.4, 0.58, 0.08, 0.13)
	# The roof: old slate by hand, with plate off a machine laid where it failed.
	var r := hipped(k, k.made, t, 0.24, 1.05, d * 0.2, 0.12, P.SLATE[2], P.SLATE[1], P.SLATE[2].lerp(P.SLATE[1], 0.5))
	for i in 3:
		var f := 0.25 + i * 0.25
		var a := r[1].lerp(r[4], f) + Vector3(0.01, 0.012, 0)
		var b := r[2].lerp(r[6], f) + Vector3(0.01, 0.012, 0)
		k.made.quad(b, a, a + Vector3(-0.03, 0.02, 0), b + Vector3(-0.03, 0.02, 0), P.SLATE[1])
	_patch(k, r[1], r[2], r[6], r[4], 0.15, 0.55, 0.45, 0.85)
	_patch(k, r[1], r[2], r[6], r[4], 0.62, 0.15, 0.9, 0.4)
	k.made.strut(r[4] + Vector3(0, 0.02, 0), r[5] + Vector3(0, 0.02, 0), 0.035, 4, P.SLATE[3])
	k.made.strut(r[5] + Vector3(0, 0.02, 0), r[6] + Vector3(0, 0.02, 0), 0.035, 4, P.SLATE[3])
	_chimney(k, -0.45, h - 0.2, -d * 0.3, 1.45, s + 10)
	turf_foot(k, t, s + 20, c)
	if c == Country.SNOWFIELD:
		_snow_on(k, r)


## "slated": a gable house of rubble; half its slates, the other half replaced
## in plate course by course.
static func slated(k: Kit, c: int) -> void:
	var s := 1500
	var w := 2.2
	var d := 3.1
	var h := 1.3
	var t := walls(k, w, d, h, s, P.STONE[2], GroundColors.down(P.STONE[2], 0.25), Vector3(-0.04, 0, 0.02))
	var fb := [t[2], t[1], t[5], t[6]]
	# Quoins lighter at the corners, a few dark stones in the courses.
	for i in 5:
		wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], 0.0, i * 0.2, 0.08 + (i % 2) * 0.04, i * 0.2 + 0.16, 0.008, P.STONE[3])
		wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], 0.9 - (i % 2) * 0.04, i * 0.2 + 0.04, 1.0, i * 0.2 + 0.18, 0.008, P.STONE[3])
	for i in 8:
		var u := 0.15 + fmod(i * 0.37, 0.7)
		var vv := 0.1 + fmod(i * 0.41, 0.8)
		wall_rect(k.made, fb[0], fb[1], fb[2], fb[3], u, vv, u + 0.06, vv + 0.07, 0.008, P.SLATE[2] if i % 2 else P.STONE[1])
	door(k, fb[0], fb[1], fb[2], fb[3], 0.64, 0.1, 0.95)
	window(k, fb[0], fb[1], fb[2], fb[3], 0.24, 0.6, 0.08, 0.13)
	struck_plate(k, fb[0], fb[1], fb[2], fb[3], 0.4, 0.42)
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
			var plate := i >= 4 and half == 1
			var pen := k.found if plate else k.made
			var col: Color = (P.PLATE[2] if i % 2 == 0 else P.PLATE[1]) if plate else (P.SLATE[2] if i % 2 == 0 else P.SLATE[1])
			pen.quad(b0, a0, a1, b1, col)
	# Back slope: plate, with one patch of old slate.
	var bk0 := Vector3(cx - ex, h - 0.05, -ez)
	var bk1 := Vector3(cx - ex, h - 0.05, ez)
	var rr0 := Vector3(cx, yr, -ez)
	var rr1 := Vector3(cx, yr, ez)
	var rrm := Vector3(cx, yr - sag, 0.0)
	k.made.tri(bk0, bk1, rrm, P.SLATE[1])
	k.made.tri(bk0, rrm, rr0, P.SLATE[1])
	k.made.tri(bk1, rr1, rrm, P.SLATE[1])
	k.made.quad(Vector3(cx - ex, h - 0.05, -ez), Vector3(cx + ex, h - 0.05, -ez), Vector3(cx + ex, h - 0.05, ez), Vector3(cx - ex, h - 0.05, ez), P.INK[2])
	# Gable ends in stone.
	k.made.tri(t[7] + Vector3(0, 0, 0.004), t[6] + Vector3(0, 0, 0.004), Vector3(cx, yr - 0.06, t[6].z + 0.004), P.STONE[2])
	k.made.tri(t[5] + Vector3(0, 0, -0.004), t[4] + Vector3(0, 0, -0.004), Vector3(cx, yr - 0.06, t[4].z - 0.004), GroundColors.down(P.STONE[2], 0.3))
	k.made.strut(rr0 + Vector3(0, 0.03, 0), rrm + Vector3(0, 0.03, 0), 0.035, 4, P.SLATE[3])
	k.made.strut(rrm + Vector3(0, 0.03, 0), rr1 + Vector3(0, 0.03, 0), 0.035, 4, P.SLATE[3])
	_chimney(k, cx + 0.05, yr - 0.55, d * 0.5 - 0.24, 1.0, s + 10)
	turf_foot(k, t, s + 20, c)
	if c == Country.SNOWFIELD:
		k.made.quad(Vector3(cx + ex * 0.55, lerpf(h, yr, 0.45) + 0.05, ez), Vector3(cx + ex * 0.55, lerpf(h, yr, 0.45) + 0.05, -ez), Vector3(cx, yr + 0.05, -ez), Vector3(cx, yr + 0.05, ez), P.RIME[5])


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
	var plate := P.PLATE[3]
	var lit := P.PLATE[4]
	var dark := P.PLATE[2]
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
		k.clump(0, top + 0.08, 0, 0.75, 0.14, 1340, P.RIME[5], 8)


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


static func ruin(k: Kit, v: int, c: int) -> void:
	var stone: Array[Color] = [P.STONE[2], P.SLATE[2], P.STONE[1], P.STONE[3]]
	if c == Country.BONELANDS:
		stone = [P.LINEN[3], P.LINEN[2], P.LINEN[4], P.STONE[3]]
	elif c == Country.BURNING:
		stone = [P.INK[3], P.STONE[0], P.STONE[1], P.INK[2]]
	var s := 1700 + v * 31
	var runs: Array = []
	match v % 3:
		0:
			runs = [[Vector2(-1.0, -0.6), Vector2(1.0, -0.6), 4], [Vector2(-1.0, -0.6), Vector2(-1.0, 0.9), 3]]
		1:
			runs = [[Vector2(-0.9, 0.0), Vector2(0.9, 0.0), 5]]
		_:
			runs = [[Vector2(-1.0, -0.8), Vector2(1.0, -0.8), 2], [Vector2(1.0, -0.8), Vector2(1.0, 0.8), 1], [Vector2(-1.0, 0.8), Vector2(0.2, 0.8), 2], [Vector2(-1.0, -0.8), Vector2(-1.0, 0.8), 3]]
	var idx := 0
	for run: Array in runs:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var courses: int = run[2]
		var n := maxi(2, int(a.distance_to(b) / 0.32))
		var dir := (b - a).normalized()
		for ci in courses:
			for i in n:
				# Courses crumble toward one end.
				if ci > 0 and float(i) / n > 1.0 - float(courses - ci) / courses * 0.9 + Kit.j(s, idx, 0.15):
					idx += 1
					continue
				var tt := (i + 0.5 + (ci % 2) * 0.5) / n
				if tt > 1.0:
					continue
				var p := a.lerp(b, tt)
				var col := stone[idx % 4]
				k.made.push(Transform3D(Basis(Vector3.UP, -atan2(dir.y, dir.x) + Kit.j(s, idx + 500, 0.12)), Vector3(p.x, ci * 0.2, p.y)))
				k.slab(0, 0, 0, 0.3 + Kit.j(s, idx, 0.05), 0.19, 0.28, s + idx, col, GroundColors.up(col, 0.15), 0.025)
				k.made.pop()
				idx += 1
		if v % 3 == 1:
			# The gable end with its window hole.
			k.made.tri(Vector3(-0.9, 1.0, -0.14), Vector3(0.9, 1.0, -0.14), Vector3(0.1, 1.7, -0.14), stone[0])
			k.made.tri(Vector3(0.9, 1.0, 0.14), Vector3(-0.9, 1.0, 0.14), Vector3(0.1, 1.7, 0.14), stone[1])
			k.made.quad(Vector3(-0.2, 0.45, 0.15), Vector3(0.2, 0.45, 0.15), Vector3(0.2, 0.8, 0.15), Vector3(-0.2, 0.8, 0.15), P.INK[1])
	var gs := k.made.vertex_count()
	for i in 5:
		k.clump(-0.8 + i * 0.4, -0.03, 0.3 + Kit.j(s, 900 + i, 0.3), 0.18, 0.2, s + 900 + i, P.MOSS[2] if i % 2 else P.MOSS[3], 6)
	k.sway_by_height(gs, 0.0, 0.2, 0.2)
	for i in 5:
		k.stone(-0.6 + i * 0.35, -0.04, -0.3 + Kit.j(s, 950 + i, 0.25), 0.13, 0.12, s + 950 + i, stone[i % 4], 5)
