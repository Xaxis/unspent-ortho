extends RefCounted
## Things people built and things the machines left standing. Houses face +X
## (their door), as every model does; WorldView turns them to their square.
##
## MADE (houses, ruins, lamp, stations): uneven, worn, asymmetric; dirt low,
## lime wash off in patches, turf banked at the foot, one struck-through enamel
## plate a third along a wall. FOUND (pylon, pole, the "but"'s housing): exact,
## symmetric, rivet rows, in the weathered machine plate ramp.

const Craft := preload("res://src/models/props/craft.gd")
const P := preload("res://src/render/palette.gd")


static func build(k: MeshKit, kind: int, v: int, c: int) -> void:
	match kind:
		PropKind.HOUSE:
			match v:
				0: but(k, c)
				1: washed(k, c)
				2: slated(k, c)
				_: long_house(k, c)
		PropKind.RUIN: ruin(k, v, c)
		PropKind.LAMP: lamp_post(k)
		PropKind.FIRE: fire(k)
		PropKind.BENCH: bench(k)
		PropKind.KILN: kiln(k, v)
		PropKind.PYLON: pylon(k)
		PropKind.POLE: pole(k)


## The struck-through enamel plate on the wall plane x = fx, centred at (y, z).
static func struck_plate(k: MeshKit, fx: float, y: float, z: float) -> void:
	var w := 0.19
	var h := 0.13
	k.quad(Vector3(fx, y - h, z + w), Vector3(fx, y - h, z - w), Vector3(fx, y + h, z - w), Vector3(fx, y + h, z + w), P.INK[0])
	var i := 0.02
	k.quad(Vector3(fx + 0.003, y - h + i, z + w - i), Vector3(fx + 0.003, y - h + i, z - w + i), Vector3(fx + 0.003, y + h - i, z - w + i), Vector3(fx + 0.003, y + h - i, z + w - i), P.RIME[5])
	for t in 5:
		var tz := z - w + 0.06 + t * 0.06
		k.quad(Vector3(fx + 0.005, y + 0.03, tz + 0.01), Vector3(fx + 0.005, y + 0.03, tz - 0.01), Vector3(fx + 0.005, y + 0.07, tz - 0.01), Vector3(fx + 0.005, y + 0.07, tz + 0.01), P.SLATE[2])
	# The strike: thick, a little off level, running past both edges.
	k.quad(Vector3(fx + 0.008, y - 0.06, z + w + 0.04), Vector3(fx + 0.008, y + 0.03, z - w - 0.04), Vector3(fx + 0.008, y + 0.065, z - w - 0.04), Vector3(fx + 0.008, y - 0.025, z + w + 0.04), P.INK[0])


## A window on the wall plane x = fx: copper frame over brine glass.
static func window(k: MeshKit, fx: float, y: float, z: float, w: float, h: float) -> void:
	k.quad(Vector3(fx, y, z + w), Vector3(fx, y, z - w), Vector3(fx, y + h, z - w), Vector3(fx, y + h, z + w), P.COPPER[1])
	var i := 0.035
	k.quad(Vector3(fx + 0.004, y + i, z + w - i), Vector3(fx + 0.004, y + i, z - w + i), Vector3(fx + 0.004, y + h - i, z - w + i), Vector3(fx + 0.004, y + h - i, z + w - i), P.BRINE[2])
	k.quad(Vector3(fx + 0.006, y + i, z + 0.012), Vector3(fx + 0.006, y + i, z - 0.012), Vector3(fx + 0.006, y + h - i, z - 0.012), Vector3(fx + 0.006, y + h - i, z + 0.012), P.COPPER[2])
	k.quad(Vector3(fx + 0.007, y + h * 0.55, z + w - i), Vector3(fx + 0.007, y + h * 0.55, z - w + i), Vector3(fx + 0.007, y + h * 0.55 + 0.02, z - w + i), Vector3(fx + 0.007, y + h * 0.55 + 0.02, z + w - i), P.BRINE[4])


## A plank door on the wall plane x = fx.
static func door(k: MeshKit, fx: float, z: float, w: float, h: float) -> void:
	k.quad(Vector3(fx, 0.05, z + w + 0.04), Vector3(fx, 0.05, z - w - 0.04), Vector3(fx, h + 0.05, z - w - 0.04), Vector3(fx, h + 0.05, z + w + 0.04), P.EARTH[1])
	for p in 3:
		var pz := z - w + (p + 0.5) * (2.0 * w / 3.0)
		k.quad(Vector3(fx + 0.004, 0.06, pz + w / 3.0 - 0.015), Vector3(fx + 0.004, 0.06, pz - w / 3.0 + 0.015), Vector3(fx + 0.004, h - 0.02 + (p % 2) * 0.02, pz - w / 3.0 + 0.015), Vector3(fx + 0.004, h - 0.02 + (p % 2) * 0.02, pz + w / 3.0 - 0.015), P.EARTH[2] if p != 1 else P.EARTH[3])
	k.block(fx + 0.02, h * 0.5, z - w * 0.6, 0.03, 0.05, 0.05, P.COPPER[2])


## Turf banked at the foot of a w (x) by d (z) wall footprint.
static func turf_foot(k: MeshKit, w: float, d: float, seed_value: int) -> void:
	for side in 4:
		var n := 4
		for i in n:
			var t := (i + 0.5) / n
			var x: float
			var z: float
			match side:
				0:
					x = w * 0.5 + 0.03
					z = lerpf(-d * 0.5, d * 0.5, t)
				1:
					x = -w * 0.5 - 0.03
					z = lerpf(-d * 0.5, d * 0.5, t)
				2:
					x = lerpf(-w * 0.5, w * 0.5, t)
					z = d * 0.5 + 0.03
				_:
					x = lerpf(-w * 0.5, w * 0.5, t)
					z = -d * 0.5 - 0.03
			Craft.blob(k, x, -0.04, z, 0.2 + Craft.j(seed_value, side * 10 + i, 0.05), 0.2 + Craft.j(seed_value, side * 20 + i, 0.06), seed_value + side * 7 + i, P.MOSS[2] if (i + side) % 3 else P.MOSS[3], 5)


## A hipped roof from eave rectangle (±ex, ±ez) at y0 to a ridge along z of half
## length rz at y1. Colours per slope; dark eave underside.
static func hipped(k: MeshKit, ex: float, ez: float, y0: float, rz: float, y1: float, front: Color, back: Color, ends: Color) -> void:
	k.quad(Vector3(ex, y0, ez), Vector3(ex, y0, -ez), Vector3(0, y1, -rz), Vector3(0, y1, rz), front)
	k.quad(Vector3(-ex, y0, -ez), Vector3(-ex, y0, ez), Vector3(0, y1, rz), Vector3(0, y1, -rz), back)
	k.tri(Vector3(-ex, y0, ez), Vector3(ex, y0, ez), Vector3(0, y1, rz), ends)
	k.tri(Vector3(ex, y0, -ez), Vector3(-ex, y0, -ez), Vector3(0, y1, -rz), GroundColors.down(ends, 0.4))
	k.quad(Vector3(-ex, y0, -ez), Vector3(ex, y0, -ez), Vector3(ex, y0, ez), Vector3(-ex, y0, ez), P.INK[2])


static func snow_on_hipped(k: MeshKit, ex: float, ez: float, y0: float, rz: float, y1: float) -> void:
	var lift := Vector3(0, 0.05, 0)
	var f := 0.82
	k.quad(Vector3(ex * f, lerpf(y1, y0, f), ez * f) + lift, Vector3(ex * f, lerpf(y1, y0, f), -ez * f) + lift, Vector3(0, y1, -rz) + lift, Vector3(0, y1, rz) + lift, P.RIME[5])
	k.quad(Vector3(-ex * f, lerpf(y1, y0, f), -ez * f) + lift, Vector3(-ex * f, lerpf(y1, y0, f), ez * f) + lift, Vector3(0, y1, rz) + lift, Vector3(0, y1, -rz) + lift, P.RIME[4])
	k.tri(Vector3(-ex * f, lerpf(y1, y0, f), ez * f) + lift, Vector3(ex * f, lerpf(y1, y0, f), ez * f) + lift, Vector3(0, y1, rz) + lift, P.RIME[5])


## "but": a machine housing lived in. The housing is FOUND and exact; everything
## people did to it is MADE.
static func but(k: MeshKit, c: int) -> void:
	var w := 2.1
	var d := 2.6
	var h := 1.15
	var plate := P.PLATE[3]
	var lit := P.PLATE[4]
	var dark := P.PLATE[2]
	k.block(0, 0, 0, w, h, d, plate, lit)
	# Rounded shoulders and a bullnose lid.
	var b := 0.22
	var top := h + 0.28
	k.quad(Vector3(w * 0.5, h, d * 0.5), Vector3(w * 0.5, h, -d * 0.5), Vector3(w * 0.5 - b, top, -d * 0.5 + b), Vector3(w * 0.5 - b, top, d * 0.5 - b), lit)
	k.quad(Vector3(-w * 0.5, h, -d * 0.5), Vector3(-w * 0.5, h, d * 0.5), Vector3(-w * 0.5 + b, top, d * 0.5 - b), Vector3(-w * 0.5 + b, top, -d * 0.5 + b), dark)
	k.quad(Vector3(-w * 0.5, h, d * 0.5), Vector3(w * 0.5, h, d * 0.5), Vector3(w * 0.5 - b, top, d * 0.5 - b), Vector3(-w * 0.5 + b, top, d * 0.5 - b), plate)
	k.quad(Vector3(w * 0.5, h, -d * 0.5), Vector3(-w * 0.5, h, -d * 0.5), Vector3(-w * 0.5 + b, top, -d * 0.5 + b), Vector3(w * 0.5 - b, top, -d * 0.5 + b), dark)
	k.quad(Vector3(w * 0.5 - b, top, d * 0.5 - b), Vector3(w * 0.5 - b, top, -d * 0.5 + b), Vector3(-w * 0.5 + b, top, -d * 0.5 + b), Vector3(-w * 0.5 + b, top, d * 0.5 - b), lit)
	# Ribs and rivet rows, exact, on both seen faces.
	for rz: float in [-0.45, 0.45]:
		k.block(w * 0.5 + 0.02, 0.0, rz, 0.04, h, 0.08, dark, plate)
		for i in 5:
			k.block(w * 0.5 + 0.045, 0.12 + i * 0.22, rz, 0.01, 0.04, 0.04, P.PLATE[5])
	for rx: float in [-0.35, 0.35]:
		k.block(rx, 0.0, d * 0.5 + 0.02, 0.08, h, 0.04, dark, plate)
		for i in 5:
			k.block(rx, 0.12 + i * 0.22, d * 0.5 + 0.045, 0.04, 0.04, 0.01, P.PLATE[5])
	# Rust bleeding from a rib.
	k.quad(Vector3(w * 0.5 + 0.046, 0.05, 0.5), Vector3(w * 0.5 + 0.046, 0.05, 0.4), Vector3(w * 0.5 + 0.046, 0.9, 0.43), Vector3(w * 0.5 + 0.046, 0.9, 0.47), P.RUST[3])
	# The door burnt through, a plank door hung in the hole.
	var fx := w * 0.5 + 0.005
	var pts: Array[Vector3] = [Vector3(fx, 0.02, -0.02), Vector3(fx, 0.02, -0.52), Vector3(fx, 0.5, -0.56), Vector3(fx, 0.92, -0.5), Vector3(fx, 1.0, -0.3), Vector3(fx, 0.95, -0.05), Vector3(fx, 0.55, 0.0)]
	var centre := Vector3(fx, 0.5, -0.27)
	for i in pts.size():
		k.tri(centre, pts[(i + 1) % pts.size()], pts[i], P.RUST[1])
	door(k, fx + 0.01, -0.27, 0.19, 0.85)
	# A window burnt through on the long side, framed in copper after.
	window(k, fx, 0.55, 0.78, 0.17, 0.3)
	# The original hatch, barred from outside.
	var fz := d * 0.5 + 0.005
	k.quad(Vector3(0.3, 0.3, fz), Vector3(0.9, 0.3, fz), Vector3(0.9, 0.9, fz), Vector3(0.3, 0.9, fz), P.PLATE[1])
	k.quad(Vector3(0.34, 0.34, fz + 0.003), Vector3(0.86, 0.34, fz + 0.003), Vector3(0.86, 0.86, fz + 0.003), Vector3(0.34, 0.86, fz + 0.003), P.PLATE[2])
	k.push(Transform3D(Basis(Vector3.BACK, 0.12), Vector3(0.6, 0.62, fz + 0.03)))
	k.block(0, 0, 0, 0.85, 0.09, 0.04, P.EARTH[2], P.EARTH[3])
	k.pop()
	k.push(Transform3D(Basis(Vector3.BACK, -0.2), Vector3(0.6, 0.45, fz + 0.035)))
	k.block(0, 0, 0, 0.8, 0.08, 0.04, P.EARTH[1], P.EARTH[2])
	k.pop()
	# A louvred vent and a junction box.
	for i in 4:
		k.block(-0.55, 0.45 + i * 0.09, fz + 0.02, 0.4, 0.03, 0.04, dark, lit)
	k.block(-0.2, 0.75, fz + 0.04, 0.16, 0.2, 0.08, dark, plate)
	struck_plate(k, fx + 0.001, 0.62, 0.35)
	# Sods laid along the lid, uneven.
	for i in 5:
		var z := -d * 0.5 + b + 0.2 + i * 0.44
		Craft.rough_box(k, Craft.j(1301, i, 0.08), top - 0.02, z, w - b * 2.0 - 0.2, 0.1, 0.4, P.EARTH[2], P.MOSS[2] if i % 2 else P.MOSS[3], 1300 + i, 0.03)
	# A stone chimney stack, built by hand through the lid.
	Craft.rough_box(k, -0.55, top - 0.2, -0.8, 0.36, 0.95, 0.36, P.STONE[2], P.STONE[1], 1310, 0.03)
	Craft.rough_box(k, -0.55, top + 0.72, -0.8, 0.44, 0.07, 0.44, P.STONE[3], P.STONE[3], 1311, 0.02)
	turf_foot(k, w, d, 1320)
	if c == Country.SNOWFIELD:
		k.block(0, top + 0.08, 0, w - b * 2.0 - 0.1, 0.1, d - b * 2.0, P.RIME[4], P.RIME[5])


## "washed": lime-washed rubble walls, a hipped roof re-laid in weathered plate,
## a cable to a pole.
static func washed(k: MeshKit, c: int) -> void:
	var w := 2.3
	var d := 2.9
	var h := 1.35
	Craft.rough_box(k, 0, 0, 0, w, h, d, P.LINEN[4], P.LINEN[3], 1400, 0.035)
	var fx := w * 0.5 + 0.02
	var fz := d * 0.5 + 0.02
	# Wash off in patches where the roof drips and boots scuff: stone shows.
	for p: Array in [[0.12, 0.9, 0.3, 0.22], [0.0, -1.1, 0.35, 0.3], [1.0, 0.95, 0.25, 0.2]]:
		k.quad(Vector3(fx, p[0], p[1] + p[2]), Vector3(fx, p[0], p[1] - p[2]), Vector3(fx, p[0] + p[3], p[1] - p[2] + 0.05), Vector3(fx, p[0] + p[3], p[1] + p[2]), P.STONE[2])
	k.quad(Vector3(-0.8, 0.0, fz), Vector3(-0.3, 0.0, fz), Vector3(-0.3, 0.28, fz), Vector3(-0.8, 0.22, fz), P.STONE[2])
	# Dirt low on the walls.
	k.quad(Vector3(fx + 0.002, 0.0, d * 0.5), Vector3(fx + 0.002, 0.0, -d * 0.5), Vector3(fx + 0.002, 0.12, -d * 0.5), Vector3(fx + 0.002, 0.08, d * 0.5), P.LINEN[2])
	k.quad(Vector3(-w * 0.5, 0.0, fz + 0.002), Vector3(w * 0.5, 0.0, fz + 0.002), Vector3(w * 0.5, 0.1, fz + 0.002), Vector3(-w * 0.5, 0.13, fz + 0.002), P.LINEN[2])
	door(k, fx + 0.005, 0.35, 0.22, 0.95)
	window(k, fx + 0.005, 0.6, -0.75, 0.2, 0.36)
	k.push(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0.45, 0.0, fz + 0.003)))
	window(k, 0.0, 0.62, 0.0, 0.2, 0.34)
	k.pop()
	struck_plate(k, fx + 0.01, 0.58, -0.25)
	# Roof: courses of plate, a few slates left where they held.
	var ex := w * 0.5 + 0.2
	var ez := d * 0.5 + 0.2
	var y0 := h
	var y1 := h + 1.0
	var rz := d * 0.22
	hipped(k, ex, ez, y0, rz, y1, P.PLATE[3], P.PLATE[2], P.PLATE[3].lerp(P.PLATE[2], 0.5))
	for i in 3:
		var t := 0.25 + i * 0.25
		var a := Vector3(ex, y0, ez).lerp(Vector3(0, y1, rz), t) + Vector3(0.012, 0.01, 0)
		var b := Vector3(ex, y0, -ez).lerp(Vector3(0, y1, -rz), t) + Vector3(0.012, 0.01, 0)
		k.quad(a, b, b + Vector3(-0.05, 0.03, 0), a + Vector3(-0.05, 0.03, 0), P.PLATE[1])
	var s0 := Vector3(ex, y0, 0.2).lerp(Vector3(0, y1, 0.2), 0.12) + Vector3(0.015, 0.012, 0)
	k.quad(s0, s0 + Vector3(0, 0, -0.6), s0 + Vector3(-0.3, 0.29, -0.6), s0 + Vector3(-0.3, 0.29, 0), P.SLATE[2])
	k.block(0, y1 - 0.02, 0, 0.1, 0.06, rz * 2.0 + 0.1, P.PLATE[4])
	Craft.rough_box(k, -0.4, h + 0.3, -d * 0.5 + 0.35, 0.34, 1.05, 0.36, P.STONE[2], P.STONE[1], 1410, 0.03)
	# The cable off the ridge end to a pole beyond.
	Craft.cable(k, Vector3(0, y1, -rz), Vector3(-0.2, 2.0, -d * 0.5 - 1.6), 0.25, 5, 0.018, P.INK[2])
	turf_foot(k, w, d, 1420)
	if c == Country.SNOWFIELD:
		snow_on_hipped(k, ex, ez, y0, rz, y1)


## "slated": a gable house, rubble walls, half its slates, the other half
## replaced in plate course by course.
static func slated(k: MeshKit, c: int) -> void:
	var w := 2.2
	var d := 3.1
	var h := 1.3
	Craft.rough_box(k, 0, 0, 0, w, h, d, P.STONE[2], P.STONE[2], 1500, 0.04)
	var fx := w * 0.5 + 0.03
	var fz := d * 0.5 + 0.03
	# Quoins lighter at the corners.
	for i in 5:
		for zc: float in [d * 0.5 - 0.12, -d * 0.5 + 0.12]:
			k.quad(Vector3(fx, i * 0.26, zc + 0.12 + (i % 2) * 0.06), Vector3(fx, i * 0.26, zc - 0.12), Vector3(fx, i * 0.26 + 0.22, zc - 0.12), Vector3(fx, i * 0.26 + 0.22, zc + 0.12 + (i % 2) * 0.06), P.STONE[3])
	# Rubble courses: a few darker stones.
	for i in 9:
		var zz := -1.2 + fmod(i * 0.77, 2.4)
		var yy := 0.15 + fmod(i * 0.41, 1.0)
		k.quad(Vector3(fx + 0.001, yy, zz + 0.12), Vector3(fx + 0.001, yy, zz - 0.1), Vector3(fx + 0.001, yy + 0.1, zz - 0.1), Vector3(fx + 0.001, yy + 0.09, zz + 0.12), P.SLATE[2] if i % 2 else P.STONE[1])
	door(k, fx + 0.005, -0.5, 0.22, 0.95)
	window(k, fx + 0.005, 0.62, 0.55, 0.2, 0.34)
	struck_plate(k, fx + 0.012, 0.55, 0.0)
	# Gable roof, ridge along z. The front slope: old slate low, plate high.
	var ex := w * 0.5 + 0.22
	var ez := d * 0.5 + 0.12
	var y0 := h
	var y1 := h + 1.05
	var courses := 7
	for i in courses:
		var t0 := float(i) / courses
		var t1 := float(i + 1) / courses
		var a0 := Vector3(lerpf(ex, 0, t0), lerpf(y0, y1, t0), ez)
		var b0 := Vector3(lerpf(ex, 0, t0), lerpf(y0, y1, t0), -ez)
		var a1 := Vector3(lerpf(ex, 0, t1), lerpf(y0, y1, t1), ez)
		var b1 := Vector3(lerpf(ex, 0, t1), lerpf(y0, y1, t1), -ez)
		var col: Color
		if i < 3:
			col = P.SLATE[2] if i % 2 == 0 else P.SLATE[1]
		else:
			col = P.PLATE[3] if i % 2 == 0 else P.PLATE[2]
		k.quad(a0, b0, b1, a1, col)
		# A course edge line.
		k.quad(a0 + Vector3(0.004, 0.004, 0), b0 + Vector3(0.004, 0.004, 0), b0 + Vector3(-0.02, 0.028, 0), a0 + Vector3(-0.02, 0.028, 0), GroundColors.down(col, 0.8))
	# Back slope: mostly plate, one patch of slate.
	k.quad(Vector3(-ex, y0, -ez), Vector3(-ex, y0, ez), Vector3(0, y1, ez), Vector3(0, y1, -ez), P.PLATE[2])
	k.quad(Vector3(-ex, y0, -ez), Vector3(ex, y0, -ez), Vector3(ex, y0, ez), Vector3(-ex, y0, ez), P.INK[2])
	# Gable ends in stone.
	k.tri(Vector3(-w * 0.5, y0, d * 0.5), Vector3(w * 0.5, y0, d * 0.5), Vector3(0, y1 - 0.05, d * 0.5), P.STONE[2])
	k.tri(Vector3(w * 0.5, y0, -d * 0.5), Vector3(-w * 0.5, y0, -d * 0.5), Vector3(0, y1 - 0.05, -d * 0.5), P.STONE[1])
	k.block(0, y1 - 0.03, 0, 0.1, 0.07, ez * 2.0, P.PLATE[4])
	Craft.rough_box(k, 0.0, y1 - 0.4, d * 0.5 - 0.2, 0.42, 0.85, 0.34, P.STONE[2], P.STONE[1], 1510, 0.03)
	turf_foot(k, w, d, 1520)
	if c == Country.SNOWFIELD:
		var lift := Vector3(0, 0.05, 0)
		k.quad(Vector3(ex * 0.8, lerpf(y0, y1, 0.2), ez) + lift, Vector3(ex * 0.8, lerpf(y0, y1, 0.2), -ez) + lift, Vector3(0, y1, -ez) + lift, Vector3(0, y1, ez) + lift, P.RIME[5])


## "long": thatch roped down with cable and weighted with cast discs, built
## against the foot of a lattice pylon.
static func long_house(k: MeshKit, c: int) -> void:
	var w := 2.0
	var d := 3.4
	var h := 0.95
	Craft.rough_box(k, 0, 0, 0.2, w, h, d, P.STONE[2], P.STONE[1], 1600, 0.04)
	var fx := w * 0.5 + 0.03
	door(k, fx + 0.005, 0.6, 0.2, 0.82)
	window(k, fx + 0.005, 0.45, -0.3, 0.18, 0.3)
	struck_plate(k, fx + 0.012, 0.5, 0.15)
	# Thatch: a deep rounded hip with a ragged eave.
	var ex := w * 0.5 + 0.35
	var ez := d * 0.5 + 0.3
	var y0 := h - 0.15
	var y1 := h + 1.25
	var rz := d * 0.3
	hipped(k, ex, ez, y0, rz, y1, P.EARTH[3], P.EARTH[2], P.EARTH[3].lerp(P.SAND[3], 0.4))
	k.push(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.2)))
	for i in 9:
		var zz := -ez + (i + 0.5) * (2.0 * ez / 9.0)
		var drop := 0.08 + fmod(i * 0.37, 0.1)
		k.quad(Vector3(ex + 0.02, y0 - drop, zz + 0.2), Vector3(ex + 0.02, y0 - drop, zz - 0.2), Vector3(ex - 0.15, y0 + 0.14, zz - 0.2), Vector3(ex - 0.15, y0 + 0.14, zz + 0.2), P.EARTH[2] if i % 2 else P.SAND[3])
	k.pop()
	# Weathered bands in the thatch.
	for t: float in [0.35, 0.62]:
		var a := Vector3(ex, y0, ez).lerp(Vector3(0, y1, rz), t) + Vector3(0.02, 0.02, 0.2)
		var b := Vector3(ex, y0, -ez).lerp(Vector3(0, y1, -rz), t) + Vector3(0.02, 0.02, 0.2)
		k.quad(a, b, b + Vector3(-0.08, 0.06, 0), a + Vector3(-0.08, 0.06, 0), P.EARTH[2])
	# Cables over the ridge, a cast disc hanging at each end.
	for i in 4:
		var zz := -1.1 + i * 0.75
		Craft.cable(k, Vector3(ex + 0.05, y0 + 0.05, zz), Vector3(0.0, y1 + 0.04, zz * 0.6 + 0.1), -0.05, 3, 0.018, P.INK[2])
		Craft.cable(k, Vector3(0.0, y1 + 0.04, zz * 0.6 + 0.1), Vector3(-ex - 0.05, y0 + 0.05, zz), -0.05, 3, 0.018, P.INK[2])
		k.strut(Vector3(ex + 0.06, y0 + 0.05, zz), Vector3(ex + 0.1, y0 - 0.3, zz), 0.012, 3, P.INK[2])
		k.push(Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(ex + 0.1, y0 - 0.36, zz)))
		k.prism(0, -0.03, 0, 0.11, 0.03, 0.11, 8, P.STONE[3], P.STONE[4])
		k.pop()
	# The pylon foot it leans on: exact lattice, cut off above the roof.
	var pz := -d * 0.5 - 0.35
	var legs: Array[Vector2] = [Vector2(-0.45, pz - 0.45), Vector2(0.45, pz - 0.45), Vector2(0.45, pz + 0.45), Vector2(-0.45, pz + 0.45)]
	for i in 4:
		var l: Vector2 = legs[i]
		k.strut(Vector3(l.x, 0, l.y), Vector3(l.x * 0.7, 2.6, pz + (l.y - pz) * 0.7), 0.04, 4, P.PLATE[3])
		var n: Vector2 = legs[(i + 1) % 4]
		for yy: float in [0.9, 1.8]:
			var f := 1.0 - yy / 2.6 * 0.3
			k.strut(Vector3(l.x * f, yy, pz + (l.y - pz) * f), Vector3(n.x * f, yy, pz + (n.y - pz) * f), 0.025, 4, P.PLATE[2])
		k.strut(Vector3(l.x, 0.05, l.y), Vector3(n.x * 0.87, 0.9, pz + (n.y - pz) * 0.87), 0.018, 4, P.PLATE[2])
	turf_foot(k, w, d, 1620)
	if c == Country.SNOWFIELD:
		snow_on_hipped(k, ex, ez, y0, rz, y1)


static func ruin(k: MeshKit, v: int, c: int) -> void:
	var stone: Array[Color] = [P.STONE[2], P.SLATE[2], P.STONE[1], P.STONE[3]]
	if c == Country.BONELANDS:
		stone = [P.LINEN[3], P.LINEN[2], P.LINEN[4], P.STONE[3]]
	elif c == Country.BURNING:
		stone = [P.INK[3], P.STONE[0], P.STONE[1], P.INK[2]]
	var s := 1700 + v * 31
	var runs: Array = []
	match v:
		0:
			runs = [[Vector2(-1.0, -0.6), Vector2(1.0, -0.6), 3], [Vector2(-1.0, -0.6), Vector2(-1.0, 0.9), 2]]
		1:
			runs = [[Vector2(-0.9, 0.0), Vector2(0.9, 0.0), 5]]
		_:
			runs = [[Vector2(-1.0, -0.8), Vector2(1.0, -0.8), 1], [Vector2(1.0, -0.8), Vector2(1.0, 0.8), 1], [Vector2(-1.0, 0.8), Vector2(0.2, 0.8), 1], [Vector2(-1.0, -0.8), Vector2(-1.0, 0.8), 2]]
	var idx := 0
	for r: Array in runs:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var courses: int = r[2]
		var n := maxi(2, int(a.distance_to(b) / 0.32))
		var dir := (b - a).normalized()
		for ci in courses:
			for i in n:
				# Courses crumble toward one end.
				if ci > 0 and float(i) / n > 1.0 - float(courses - ci) / courses * 0.9 + Craft.j(s, idx, 0.15):
					idx += 1
					continue
				var t := (i + 0.5 + (ci % 2) * 0.5) / n
				if t > 1.0:
					continue
				var p := a.lerp(b, t)
				var bw := 0.3 + Craft.j(s, idx, 0.05)
				var col: Color = stone[idx % 4]
				k.push(Transform3D(Basis(Vector3.UP, -atan2(dir.y, dir.x) + Craft.j(s, idx + 500, 0.12)), Vector3(p.x, ci * 0.2, p.y)))
				Craft.rough_box(k, 0, 0, 0, bw, 0.19, 0.28, col, col.lightened(0.05), s + idx, 0.025)
				k.pop()
				idx += 1
		if v == 1:
			# The gable end with its window hole.
			k.tri(Vector3(-0.9, 1.0, -0.13), Vector3(0.9, 1.0, -0.13), Vector3(0.1, 1.7, -0.13), stone[0])
			k.tri(Vector3(0.9, 1.0, 0.13), Vector3(-0.9, 1.0, 0.13), Vector3(0.1, 1.7, 0.13), stone[1])
			k.quad(Vector3(-0.2, 0.45, 0.14), Vector3(0.2, 0.45, 0.14), Vector3(0.2, 0.8, 0.14), Vector3(-0.2, 0.8, 0.14), P.INK[1])
	for i in 4:
		Craft.blob(k, -0.8 + i * 0.5, 0.0, 0.3 + Craft.j(s, 900 + i, 0.3), 0.18, 0.18, s + 900 + i, PropModels.sway(P.MOSS[2], 0.2), 5)
	for i in 5:
		k.rock(-0.6 + i * 0.35, -0.03, -0.3 + Craft.j(s, 950 + i, 0.25), 0.12, 0.12, s + 950 + i, stone[i % 4], 5)


static func lamp_post(k: MeshKit) -> void:
	k.push(Transform3D(Basis(Vector3.BACK, 0.04), Vector3.ZERO))
	k.prism(0, 0, 0, 0.06, 1.75, 0.045, 5, P.EARTH[1], Color(0, 0, 0, 0), 0.2)
	k.strut(Vector3(0, 1.62, 0), Vector3(0.36, 1.66, 0.02), 0.025, 4, P.EARTH[1])
	k.strut(Vector3(0, 1.35, 0), Vector3(0.24, 1.64, 0.02), 0.018, 3, P.EARTH[2])
	var lx := 0.36
	k.strut(Vector3(lx, 1.66, 0.02), Vector3(lx, 1.56, 0.02), 0.01, 3, P.INK[2])
	k.block(lx, 1.3, 0.02, 0.2, 0.26, 0.2, P.COPPER[1], P.COPPER[2])
	k.block(lx, 1.33, 0.02, 0.215, 0.2, 0.14, PropModels.lamp(P.COPPER[4], 1.6), P.COPPER[2])
	k.block(lx, 1.33, 0.02, 0.14, 0.2, 0.215, PropModels.lamp(P.LINEN[5], 1.2), P.COPPER[2])
	k.prism(lx, 1.56, 0.02, 0.16, 1.64, 0.02, 4, P.INK[2], Color(0, 0, 0, 0), PI * 0.25)
	k.pop()
	k.rock(0.02, -0.05, 0.0, 0.16, 0.12, 1801, P.STONE[2], 5)


## The fire station: a stone ring, logs, a bed of embers, flames, and a pot on a
## tripod. Readable from across a screen by its glow.
static func fire(k: MeshKit) -> void:
	for i in 9:
		var a := float(i) / 9.0 * TAU + Craft.j(1901, i, 0.15)
		var r := 0.46 + Craft.j(1902, i, 0.04)
		k.rock(cos(a) * r, -0.05, sin(a) * r, 0.13 + Craft.j(1903, i, 0.03), 0.2, 1910 + i, P.STONE[2] if i % 3 else P.STONE[3], 5)
	k.prism(0, -0.02, 0, 0.4, 0.03, 0.38, 9, P.INK[2], P.ASH[1])
	for i in 3:
		var a := float(i) / 3.0 * TAU + 0.3
		k.strut(Vector3(cos(a) * 0.36, 0.04, sin(a) * 0.36), Vector3(cos(a) * 0.05, 0.3, sin(a) * 0.05), 0.045, 5, P.EARTH[1] if i != 1 else P.INK[2])
	for i in 7:
		var a := float(i) * 2.39996
		var r := 0.05 + fmod(i * 0.07, 0.22)
		k.block(cos(a) * r, 0.02, sin(a) * r, 0.09, 0.05, 0.09, PropModels.glow(P.EMBER[3] if i % 2 else P.EMBER[4], 1.2))
	for i in 5:
		var a := float(i) / 5.0 * TAU
		var base := Vector3(cos(a) * 0.1, 0.05, sin(a) * 0.1)
		var tip := Vector3(cos(a) * 0.03, 0.42 + fmod(i * 0.13, 0.2), sin(a) * 0.03)
		Craft.blade(k, base, tip, 0.16, a + 1.2, PropModels.flame(P.EMBER[4]))
		Craft.blade(k, base * 0.5 + Vector3(0, 0.02, 0), tip * Vector3(1, 0.7, 1), 0.08, a + 0.4, PropModels.flame(P.EMBER[5]))
	# Tripod and pot.
	for i in 3:
		var a := float(i) / 3.0 * TAU + 0.9
		k.strut(Vector3(cos(a) * 0.6, 0.0, sin(a) * 0.6), Vector3(0.0, 1.05, 0.0), 0.022, 4, P.EARTH[2])
	k.strut(Vector3(0, 1.05, 0), Vector3(0, 0.72, 0), 0.008, 3, P.INK[2])
	k.prism(0, 0.5, 0, 0.1, 0.72, 0.13, 7, P.INK[2], P.INK[1], 0.0, true)
	k.prism(0, 0.72, 0, 0.14, 0.74, 0.14, 7, P.STONE[1], P.INK[1])


## The workbench: a heavy table with a vice, tools on top, a saw hung on its
## side, and a chopping block with an axe in it.
static func bench(k: MeshKit) -> void:
	var top := 0.72
	for lx: float in [-0.22, 0.22]:
		for lz: float in [-0.62, 0.62]:
			k.strut(Vector3(lx * 1.25, 0.0, lz * 1.08), Vector3(lx, top, lz), 0.045, 4, P.EARTH[2])
	k.block(0, 0.22, 0, 0.5, 0.05, 1.2, P.EARTH[2], P.EARTH[3])
	Craft.rough_box(k, 0, top, 0, 0.62, 0.1, 1.5, P.EARTH[3], P.EARTH[4], 2001, 0.012)
	k.quad(Vector3(0.3, top + 0.104, 0.74), Vector3(0.3, top + 0.104, -0.74), Vector3(0.24, top + 0.104, -0.74), Vector3(0.24, top + 0.104, 0.74), P.EARTH[3])
	# The vice at one end.
	k.block(0.2, top + 0.08, -0.62, 0.14, 0.18, 0.18, P.STONE[1], P.STONE[2])
	k.block(0.33, top + 0.08, -0.62, 0.08, 0.18, 0.18, P.STONE[1], P.STONE[3])
	k.strut(Vector3(0.38, top + 0.16, -0.62), Vector3(0.5, top + 0.16, -0.62), 0.02, 4, P.STONE[3])
	k.strut(Vector3(0.5, top + 0.1, -0.62), Vector3(0.5, top + 0.24, -0.62), 0.015, 4, P.EARTH[3])
	# A hammer and offcuts on top.
	k.strut(Vector3(-0.05, top + 0.13, 0.05), Vector3(0.15, top + 0.13, 0.35), 0.02, 4, P.EARTH[4])
	k.block(-0.06, top + 0.1, 0.03, 0.14, 0.07, 0.07, P.STONE[3], P.STONE[4])
	k.block(-0.1, top + 0.1, 0.45, 0.12, 0.05, 0.3, P.EARTH[4], P.EARTH[5])
	k.block(0.1, top + 0.1, -0.2, 0.2, 0.04, 0.08, P.LINEN[4])
	# The saw hung on the front.
	var sx := 0.33
	k.tri(Vector3(sx, top - 0.05, 0.55), Vector3(sx, top - 0.3, 0.05), Vector3(sx, top - 0.05, 0.05), P.STONE[4])
	k.tri(Vector3(sx - 0.002, top - 0.05, 0.05), Vector3(sx - 0.002, top - 0.3, 0.05), Vector3(sx - 0.002, top - 0.05, 0.55), P.STONE[3])
	k.block(sx, top - 0.14, 0.62, 0.03, 0.14, 0.12, P.EARTH[4])
	# Chopping block with the axe in it.
	k.prism(0.15, 0.0, 1.05, 0.22, 0.38, 0.2, 7, P.EARTH[2], P.EARTH[4])
	k.strut(Vector3(0.18, 0.4, 1.0), Vector3(0.45, 0.72, 1.12), 0.022, 4, P.EARTH[4])
	k.push(Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.BACK, -0.8), Vector3(0.19, 0.41, 1.02)))
	k.block(0, 0, 0, 0.18, 0.05, 0.04, P.STONE[3], P.STONE[4])
	k.pop()
	for i in 6:
		var a := float(i) * 1.9
		k.block(cos(a) * 0.5 + 0.1, 0.005, sin(a) * 0.4 + 0.6, 0.06, 0.01, 0.03, P.LINEN[4])


## The kiln: a brick bottle kiln on the coast, a squat lime kiln on the bones.
## Its mouth glows.
static func kiln(k: MeshKit, v: int) -> void:
	if v == 0:
		var brick := P.RUST[2]
		k.prism(0, 0, 0, 0.72, 0.55, 0.7, 10, brick, brick, 0.1)
		k.prism(0, 0.55, 0, 0.7, 1.25, 0.4, 10, P.RUST[3], P.RUST[3], 0.1)
		k.prism(0, 1.25, 0, 0.4, 1.7, 0.22, 10, brick, P.INK[1], 0.1)
		k.prism(0, 1.7, 0, 0.26, 1.78, 0.26, 10, P.RUST[3], P.INK[0], 0.1)
		# Brick courses.
		for i in 4:
			var y := 0.14 + i * 0.3
			var r := lerpf(0.72, 0.5, y / 1.4) + 0.012
			k.prism(0, y, 0, r, y + 0.03, r, 10, P.RUST[1], P.RUST[1], 0.1)
		# The arched mouth on the front, glowing.
		var fx := 0.72
		k.quad(Vector3(fx, 0.02, 0.24), Vector3(fx, 0.02, -0.24), Vector3(fx, 0.34, -0.24), Vector3(fx, 0.34, 0.24), P.INK[1])
		k.tri(Vector3(fx, 0.34, 0.24), Vector3(fx, 0.34, -0.24), Vector3(fx, 0.5, 0.0), P.INK[1])
		k.quad(Vector3(fx + 0.01, 0.03, 0.17), Vector3(fx + 0.01, 0.03, -0.17), Vector3(fx + 0.01, 0.24, -0.17), Vector3(fx + 0.01, 0.24, 0.17), PropModels.glow(P.EMBER[3], 1.3))
		k.quad(Vector3(fx + 0.012, 0.03, 0.1), Vector3(fx + 0.012, 0.03, -0.1), Vector3(fx + 0.012, 0.13, -0.1), Vector3(fx + 0.012, 0.13, 0.1), PropModels.glow(P.EMBER[4], 1.6))
		k.quad(Vector3(fx - 0.01, 0.5, 0.2), Vector3(fx - 0.01, 0.5, -0.12), Vector3(fx - 0.1, 1.1, -0.06), Vector3(fx - 0.1, 1.1, 0.12), P.INK[2])
		# Fired pots and bricks stacked by the door.
		for i in 3:
			k.prism(0.95, 0.0, 0.55 - i * 0.26, 0.09, 0.2, 0.07, 6, P.RUST[4], P.RUST[3])
		for i in 4:
			k.block(0.9, i * 0.07, -0.6, 0.26, 0.07, 0.13, P.RUST[3] if i % 2 else P.RUST[2])
	else:
		var stone := P.LINEN[3]
		Craft.rough_box(k, 0, 0, 0, 1.4, 1.05, 1.4, stone, P.LINEN[4], 2101, 0.05)
		Craft.rough_box(k, -0.1, 1.0, 0, 1.0, 0.18, 1.0, P.LINEN[2], P.INK[1], 2102, 0.04)
		var fx := 0.72
		k.quad(Vector3(fx, 0.0, 0.26), Vector3(fx, 0.0, -0.26), Vector3(fx, 0.42, -0.26), Vector3(fx, 0.42, 0.26), P.INK[1])
		k.tri(Vector3(fx, 0.42, 0.26), Vector3(fx, 0.42, -0.26), Vector3(fx, 0.66, 0.0), P.INK[1])
		k.quad(Vector3(fx + 0.01, 0.02, 0.16), Vector3(fx + 0.01, 0.02, -0.16), Vector3(fx + 0.01, 0.22, -0.16), Vector3(fx + 0.01, 0.22, 0.16), PropModels.glow(P.EMBER[3], 1.2))
		for i in 5:
			k.rock(1.0 + i * 0.12, -0.05, -0.5 + i * 0.25, 0.14, 0.14, 2110 + i, P.LINEN[4], 5)
		k.quad(Vector3(0.75, 0.005, 0.7), Vector3(1.5, 0.005, 0.5), Vector3(1.5, 0.005, -0.6), Vector3(0.75, 0.005, -0.7), P.LINEN[5])


## FOUND: a lattice mast, exact and symmetric, still carrying.
static func pylon(k: MeshKit) -> void:
	var m := P.PLATE[3]
	var br := P.PLATE[2]
	var top := 3.9
	var legs: Array[Vector2] = [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
	var at := func(l: Vector2, y: float) -> Vector3:
		var f := 1.0 - y / top * 0.76
		return Vector3(l.x * f, y, l.y * f)
	for i in 4:
		var l: Vector2 = legs[i]
		var n: Vector2 = legs[(i + 1) % 4]
		k.strut(at.call(l, 0.0), at.call(l, top), 0.045, 4, m)
		var levels: Array[float] = [0.0, 1.0, 1.9, 2.7, 3.4]
		for li in levels.size():
			var y: float = levels[li]
			if li > 0:
				k.strut(at.call(l, y), at.call(n, y), 0.028, 4, br)
			if li < levels.size() - 1:
				var y2: float = levels[li + 1]
				k.strut(at.call(l, y), at.call(n, y2), 0.02, 4, br)
				k.strut(at.call(n, y), at.call(l, y2), 0.02, 4, br)
		k.prism(l.x, 0.0, l.y, 0.1, 0.12, 0.1, 4, P.STONE[2], P.STONE[3], PI * 0.25)
	for arm: Array in [[3.35, 1.1], [2.65, 0.8]]:
		var y: float = arm[0]
		var hw: float = arm[1]
		k.block(0, y, 0, 0.09, 0.09, hw * 2.0, m, P.PLATE[4])
		for side: float in [-1.0, 1.0]:
			var p := Vector3(0, y, side * (hw - 0.05))
			k.strut(p, p + Vector3(0, -0.28, 0), 0.012, 3, br)
			for d in 3:
				k.prism(p.x, p.y - 0.12 - d * 0.06, p.z, 0.045, p.y - 0.08 - d * 0.06, 0.045, 6, P.COLD[2], P.COLD[3])
			Craft.cable(k, p + Vector3(0, -0.28, 0), p + Vector3(1.6, -0.9, 0), 0.25, 4, 0.012, P.INK[1])
			Craft.cable(k, p + Vector3(0, -0.28, 0), p + Vector3(-1.6, -0.9, 0), 0.25, 4, 0.012, P.INK[1])
	k.prism(0, top, 0, 0.14, top + 0.2, 0.0, 4, P.PLATE[4], Color(0, 0, 0, 0), PI * 0.25)


## FOUND: a pole with a crossarm and two insulators, exact.
static func pole(k: MeshKit) -> void:
	k.prism(0, 0, 0, 0.1, 0.18, 0.1, 8, P.PLATE[1], P.PLATE[2])
	k.prism(0, 0, 0, 0.055, 2.7, 0.045, 8, P.PLATE[3], P.PLATE[4])
	k.block(0, 2.45, 0, 0.07, 0.07, 0.95, P.PLATE[3], P.PLATE[4])
	for side: float in [-0.4, 0.4]:
		k.prism(0, 2.52, side, 0.035, 2.68, 0.035, 6, P.COLD[2], P.COLD[3])
		k.prism(0, 2.58, side, 0.05, 2.6, 0.05, 6, P.COLD[1], P.COLD[2])
		Craft.cable(k, Vector3(0, 2.68, side), Vector3(1.8, 2.3, side), 0.3, 4, 0.01, P.INK[1])
	k.block(0, 1.2, 0.06, 0.1, 0.16, 0.01, P.RIME[5])
