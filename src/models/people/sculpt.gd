class_name Sculpt
## Solids for figures, drawn the way docs/LOOK.md asks: lofted rings instead of
## boxes, so a limb tapers, a chest swells and a hat brim droops. MADE parts pass
## a `wob` (a few percent of hand irregularity, seeded, so it is the same every
## frame and every build); FOUND parts pass wob 0 and stay exact.
##
## A ring is [y, rx, rz, cx, cz] or [y, rx, rz, cx, cz, fold]: height along the
## part's +Y, radii toward +X (the figure's front) and +Z (its right), and a
## centre offset. Angle 0 points at +X; phase PI/n puts a flat face on the front
## instead of an edge. `fold` (a share of the radius, 0.03 or so) runs soft
## ridges round that ring, so cloth hangs in folds where it is loose and stays
## taut where the ring leaves it out; the walls weld, so a fold is a curve.
## A seventh entry is the ring's SWELLS: an Array of Vector3(angle, width,
## amount), each a smooth rise (or, negative, a hollow) of the radius by
## `amount` of itself round `angle`, falling off over `width` radians -- a
## shoulder blade, the channel of a spine, a brow, a cheekbone. Not mirrored:
## a swell on both sides is written twice. (Pass fold 0.0 to reach it.)
##
##   Sculpt.loft(k, [[0, .1, .1, 0, 0], [.3, .07, .08, 0, 0]], 6, col)
##   Sculpt.limb(k, 0.3, 0.075, 0.06, 6, col, seed)        # hangs along -Y

## How far a lofted WALL may turn and still be one rounded surface. Wider than
## MeshKit's own default on purpose: a six-sided limb turns 60 degrees at every
## corner, so any crease under that leaves it a hexagonal bar.
const WALL_CREASE := 76.0


## Side walls between consecutive rings, optional caps. `cols` is one Color or an
## Array with one Color per band (rings - 1); caps take the end bands' colours.
## `arc` < 1 leaves the ring open (a collar, a hairline), centred on `arc_mid`.
static func loft(k: MeshKit, rings: Array, n: int, cols: Variant, cap_lo: bool = true, cap_hi: bool = true, phase: float = 0.0, wob: float = 0.0, seed_value: int = 0, arc: float = 1.0, arc_mid: float = PI) -> void:
	if rings.size() >= 2 and float(rings[rings.size() - 1][0]) < float(rings[0][0]):
		# Rings listed downward (a limb from its joint): walk them upward so every
		# face still turns outward; the caps and band colours follow.
		rings = rings.duplicate()
		rings.reverse()
		if cols is Array:
			var bands: Array = (cols as Array).duplicate()
			while bands.size() < rings.size() - 1:
				bands.append(bands[bands.size() - 1])
			bands.resize(rings.size() - 1)
			bands.reverse()
			cols = bands
		var t := cap_lo
		cap_lo = cap_hi
		cap_hi = t
	var closed := arc >= 0.999
	var count := n if closed else n + 1
	var pts: Array[PackedVector3Array] = []
	var ridges := float(maxi(2, n / 3))
	var fold_at := Rng.hash01(seed_value, 77) * TAU
	for ri in rings.size():
		var r: Array = rings[ri]
		var fold: float = float(r[5]) if r.size() > 5 else 0.0
		var ring := PackedVector3Array()
		ring.resize(count)
		for i in count:
			var a := phase + float(i) / n * TAU if closed else arc_mid - arc * PI + float(i) / n * arc * TAU
			var j := 1.0
			if wob > 0.0:
				j += (Rng.hash01(seed_value, ri, i % n) - 0.5) * 2.0 * wob
			if fold > 0.0:
				# Ridges drift round the body ring by ring, so a fold slants
				# down the cloth instead of standing as a fluted column.
				j += fold * cos(a * ridges + fold_at + ri * 0.9)
			j += swell(r, a)
			ring[i] = Vector3(float(r[3]) + cos(a) * float(r[1]) * j, float(r[0]), float(r[4]) + sin(a) * float(r[2]) * j)
		pts.append(ring)
	var segs := n
	var wall_from := k.vertex_count()
	for ri in rings.size() - 1:
		var c := _band(cols, ri)
		var lo := pts[ri]
		var hi := pts[ri + 1]
		for i in segs:
			var i2 := (i + 1) % count
			k.quad(lo[i2], lo[i], hi[i], hi[i2], c)
	# THE WALLS ROUND, THE CAPS DO NOT. An arm is a loft of six or eight sides,
	# and a flat normal per side under a real sun makes it a hexagonal bar — the
	# very thing this vocabulary exists to avoid, arrived at from the other
	# direction. Done before the caps are laid, so an end stays a flat end, and a
	# shoulder or a brim that turns harder than the crease stays an edge.
	_weld_walls(k, wall_from, rings.size(), n, closed)
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


## The walls' welded normals, worked out from the loft's own topology instead
## of `MeshKit.smooth_range`'s search for coincident corners: the same rule
## (each corner averages, area-weighted, the triangles meeting there that turn
## less than WALL_CREASE from its own), without a dictionary per vertex. A
## village builds its people on the main thread, and the search was most of
## what a rounder figure cost.
static func _weld_walls(k: MeshKit, from: int, ring_count: int, n: int, closed: bool) -> void:
	var bands := ring_count - 1
	var count := n if closed else n + 1
	var v := k.verts
	# Area-weighted and unit normals per wall triangle. Per quad (band ri,
	# segment i) the stored triangles are A (lo i2, hi i, lo i) and
	# B (lo i2, hi i2, hi i).
	var tris := bands * n * 2
	var wn := PackedVector3Array()
	var un := PackedVector3Array()
	wn.resize(tris)
	un.resize(tris)
	for t in tris:
		var b := from + t * 3
		var raw := (v[b + 1] - v[b + 2]).cross(v[b] - v[b + 2])
		wn[t] = raw * 0.5
		un[t] = k.normals[b]
	var limit := cos(deg_to_rad(WALL_CREASE))
	# Which triangles meet at ring vertex (ri, i).
	var touch := PackedInt32Array()
	for ri in ring_count:
		for i in count:
			touch.clear()
			var prev := i - 1
			if closed:
				prev = (i + n - 1) % n
			if ri < bands:
				# This ring is the LOW ring of band ri.
				if i < n or closed:
					touch.append(((ri * n + (i % n)) * 2))
				if prev >= 0 and prev < n:
					touch.append((ri * n + prev) * 2)
					touch.append((ri * n + prev) * 2 + 1)
			if ri > 0:
				# ...and the HIGH ring of band ri - 1.
				if i < n or closed:
					touch.append(((ri - 1) * n + (i % n)) * 2)
					touch.append(((ri - 1) * n + (i % n)) * 2 + 1)
				if prev >= 0 and prev < n:
					touch.append(((ri - 1) * n + prev) * 2 + 1)
			for own: int in touch:
				var acc := Vector3.ZERO
				for other: int in touch:
					if other == own or un[own].dot(un[other]) >= limit:
						acc += wn[other]
				if acc.length_squared() < 1e-24:
					continue
				var nv := acc.normalized()
				# The slot in triangle `own` that is this ring vertex.
				var q := own / 2
				var seg := q % n
				var high := (q / n) != ri
				var at := i if seg == i % n and (i < n or closed) else -1
				var b := from + own * 3
				var slot := -1
				if own % 2 == 0:
					# A: lo i2, hi i, lo i
					if high:
						slot = 1
					else:
						slot = 2 if at >= 0 else 0
				else:
					# B: lo i2, hi i2, hi i
					if high:
						slot = 2 if at >= 0 else 1
					else:
						slot = 0
				k.normals[b + slot] = nv


## How much a ring's swells lift its radius at angle `a` (0 = none).
static func swell(r: Array, a: float) -> float:
	if r.size() <= 6:
		return 0.0
	var out := 0.0
	for b: Vector3 in r[6]:
		var da := wrapf(a - b.x, -PI, PI) / b.y
		out += b.z * exp(-da * da)
	return out


## Where a ring's surface is at angle `a`, swells included, without the hand's
## wobble or the folds: what a thing laid ON a lofted surface reads.
static func ring_point(r: Array, a: float) -> Vector3:
	var j := 1.0 + swell(r, a)
	return Vector3(float(r[3]) + cos(a) * float(r[1]) * j, float(r[0]), float(r[4]) + sin(a) * float(r[2]) * j)


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


## An open loft seen from both sides: a coat skirt split at the front, a hood.
## The inside faces take `lining` (usually one step darker).
static func skirt(k: MeshKit, rings: Array, n: int, col: Variant, lining: Color, arc: float, arc_mid: float = PI, wob: float = 0.0, seed_value: int = 0) -> void:
	var t := MeshKit.new()
	loft(t, rings, n, col, false, false, 0.0, wob, seed_value, arc, arc_mid)
	# The loft welded its walls; `tri` would lay a flat normal back on every
	# face, and a coat skirt seen from behind is the largest cloth on screen. So
	# the welded normals are carried across, turned for whatever `k` has pushed,
	# and the lining takes them reversed.
	var nb := k._xf.basis.inverse().transposed()
	for i in range(0, t.verts.size(), 3):
		var at := k.normals.size()
		k.tri(t.verts[i], t.verts[i + 2], t.verts[i + 1], t.colors[i])
		k.tri(t.verts[i], t.verts[i + 1], t.verts[i + 2], lining)
		for c in 3:
			var o := (nb * t.normals[i + c]).normalized()
			k.normals[at + c] = o
		k.normals[at + 3] = -k.normals[at]
		k.normals[at + 4] = -k.normals[at + 2]
		k.normals[at + 5] = -k.normals[at + 1]
