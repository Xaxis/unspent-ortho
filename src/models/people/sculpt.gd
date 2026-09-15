class_name Sculpt
## Solids for figures, drawn the way docs/ART.md asks: lofted rings instead of
## boxes, so a limb tapers, a chest swells and a hat brim droops. MADE parts pass
## a `wob` (a few percent of hand irregularity, seeded, so it is the same every
## frame and every build); FOUND parts pass wob 0 and stay exact.
##
## A ring is [y, rx, rz, cx, cz]: height along the part's +Y, radii toward +X
## (the figure's front) and +Z (its right), and a centre offset. Angle 0 points
## at +X; phase PI/n puts a flat face on the front instead of an edge.
##
##   Sculpt.loft(k, [[0, .1, .1, 0, 0], [.3, .07, .08, 0, 0]], 6, col)
##   Sculpt.limb(k, 0.3, 0.075, 0.06, 6, col, seed)        # hangs along -Y


## Side walls between consecutive rings, optional caps. `cols` is one Color or an
## Array with one Color per band (rings - 1); caps take the end bands' colours.
## `arc` < 1 leaves the ring open (a collar, a hairline), centred on `arc_mid`.
static func loft(k: MeshKit, rings: Array, n: int, cols: Variant, cap_lo: bool = true, cap_hi: bool = true, phase: float = 0.0, wob: float = 0.0, seed_value: int = 0, arc: float = 1.0, arc_mid: float = PI) -> void:
	var closed := arc >= 0.999
	var count := n if closed else n + 1
	var pts: Array[PackedVector3Array] = []
	for ri in rings.size():
		var r: Array = rings[ri]
		var ring := PackedVector3Array()
		ring.resize(count)
		for i in count:
			var a := phase + float(i) / n * TAU if closed else arc_mid - arc * PI + float(i) / n * arc * TAU
			var j := 1.0
			if wob > 0.0:
				j += (Rng.hash01(seed_value, ri, i % n) - 0.5) * 2.0 * wob
			ring[i] = Vector3(float(r[3]) + cos(a) * float(r[1]) * j, float(r[0]), float(r[4]) + sin(a) * float(r[2]) * j)
		pts.append(ring)
	var segs := n
	for ri in rings.size() - 1:
		var c := _band(cols, ri)
		var lo := pts[ri]
		var hi := pts[ri + 1]
		for i in segs:
			var i2 := (i + 1) % count
			k.quad(lo[i2], lo[i], hi[i], hi[i2], c)
	if closed and cap_lo:
		var c0 := _centre(rings[0])
		var lo := pts[0]
		for i in n:
			k.tri(c0, lo[i], lo[(i + 1) % n], _band(cols, 0))
	if closed and cap_hi:
		var last := rings.size() - 1
		var c1 := _centre(rings[last])
		var hi := pts[last]
		for i in n:
			k.tri(c1, hi[(i + 1) % n], hi[i], _band(cols, last - 1))


static func _centre(r: Array) -> Vector3:
	return Vector3(float(r[3]), float(r[0]), float(r[4]))


static func _band(cols: Variant, i: int) -> Color:
	if cols is Color:
		return cols
	var a: Array = cols
	return a[clampi(i, 0, a.size() - 1)]


## A limb hanging from its joint along -Y: wide at the joint, tapering, with an
## optional swell part way down (a calf, a forearm). Capped both ends, so a bent
## knee or elbow shows a solid end rather than a hole.
static func limb(k: MeshKit, length: float, r0: float, r1: float, n: int, cols: Variant, seed_value: int, swell: float = 0.0, flat: float = 1.0, swell_at: float = 0.4) -> void:
	var rings: Array = [[r0 * 0.25, r0 * 0.7 * flat, r0 * 0.7, 0.0, 0.0], [0.0, r0 * flat, r0, 0.0, 0.0]]
	if swell > 0.0:
		var rm := lerpf(r0, r1, swell_at) * (1.0 + swell)
		rings.append([-length * swell_at, rm * flat, rm, 0.0, 0.0])
	rings.append([-length, r1 * flat, r1, 0.0, 0.0])
	loft(k, rings, n, cols, true, true, PI / n, 0.05, seed_value)


## Push a transform whose +Y runs from `a` toward `b` (and +X leans toward `front`).
static func aim(k: MeshKit, a: Vector3, b: Vector3, front: Vector3 = Vector3(1, 0, 0)) -> float:
	var y := b - a
	var length := y.length()
	y = y / maxf(length, 1e-5)
	var x := front - y * front.dot(y)
	if x.length() < 1e-3:
		x = Vector3(0, 0, 1).cross(y)
	x = x.normalized()
	var z := x.cross(y)
	k.push(Transform3D(Basis(x, y, z), a))
	return length


## A flat outline extruded both ways along Z by `t`: blades, plates, straps.
## `pts` is a convex polygon in the XY plane, counter-clockwise.
static func slab(k: MeshKit, pts: PackedVector2Array, t: float, col: Color, rim: Color = Color(0, 0, 0, 0)) -> void:
	var rc := col if rim.a == 0.0 else rim
	var n := pts.size()
	var f := PackedVector3Array()
	var b := PackedVector3Array()
	for p in pts:
		f.append(Vector3(p.x, p.y, t))
		b.append(Vector3(p.x, p.y, -t))
	for i in range(1, n - 1):
		k.tri(f[0], f[i], f[i + 1], col)
		k.tri(b[0], b[i + 1], b[i], col)
	for i in n:
		var j := (i + 1) % n
		k.quad(b[i], b[j], f[j], f[i], rc)


## A lumpy clump: a faceted blob for fleece, hair tufts and bundles. Seeded.
static func clump(k: MeshKit, c: Vector3, r: Vector3, col: Color, seed_value: int, n: int = 5) -> void:
	var rings: Array = [
		[c.y - r.y, r.x * 0.35, r.z * 0.35, c.x, c.z],
		[c.y - r.y * 0.35, r.x, r.z, c.x, c.z],
		[c.y + r.y * 0.45, r.x * 0.85, r.z * 0.85, c.x, c.z],
		[c.y + r.y, r.x * 0.3, r.z * 0.3, c.x, c.z],
	]
	loft(k, rings, n, col, true, true, Rng.hash01(seed_value, 5) * TAU, 0.16, seed_value)


## A single-sided quad that faces `out`, whatever order its corners come in.
static func card(k: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, out: Vector3) -> void:
	if (c - b).cross(a - b).dot(out) >= 0.0:
		k.quad(a, b, c, d, col)
	else:
		k.quad(d, c, b, a, col)
