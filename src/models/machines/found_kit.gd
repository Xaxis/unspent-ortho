class_name FoundKit
## Mesh vocabulary for FOUND things (machines and what comes off them), on top of
## MeshKit. Everything here is exact: symmetric, straight, chamfered, riveted.
## MADE things never use it.
##
## Colour follows art-audio-extract §2c on a per-kind ramp `r` (6 values,
## Palette.MACHINE[kind]): body fill v3, lit rim and rubs v4, dark rim v2,
## cavity v0/v1, rivets and fasteners v5. Colour is chosen from the face's
## LOCAL normal, so paint stays on the part when the part moves.
##
## All helpers draw through the MeshKit transform stack (k.push / k.at).

const UP := Vector3.UP


## Chamfered box centred on `c`, full size `s`, chamfer `ch`. `rub` paints one
## upper edge v5 (the rubbed-bright edge of the biggest panel): 0 +X, 1 -X,
## 2 +Z, 3 -Z, -1 none. 44 triangles (12 when ch is 0).
static func cbox(k: MeshKit, c: Vector3, s: Vector3, ch: float, r: Array, rub: int = -1) -> void:
	var h := s * 0.5
	ch = minf(ch, minf(h.x, minf(h.y, h.z)) * 0.9)
	if ch <= 0.0:
		_sharp_box(k, c, h, r)
		return
	var i := h - Vector3(ch, ch, ch)
	# Main faces.
	for a in 3:
		for sa: float in [-1.0, 1.0]:
			var b := (a + 1) % 3
			var d := (a + 2) % 3
			var pts: Array[Vector3] = []
			for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var p := Vector3.ZERO
				p[a] = sa * h[a]
				p[b] = q.x * i[b]
				p[d] = q.y * i[d]
				pts.append(c + p)
			var n := Vector3.ZERO
			n[a] = sa
			face(k, pts, _col(k, n, r), n)
	# Edge bevels.
	for a in 3:
		var b := (a + 1) % 3
		var d := (a + 2) % 3
		for sa: float in [-1.0, 1.0]:
			for sb: float in [-1.0, 1.0]:
				var pts: Array[Vector3] = []
				for sd: float in [-1.0, 1.0]:
					var p := Vector3.ZERO
					p[a] = sa * h[a]
					p[b] = sb * i[b]
					p[d] = sd * i[d]
					pts.append(c + p)
				for sd: float in [1.0, -1.0]:
					var p := Vector3.ZERO
					p[a] = sa * i[a]
					p[b] = sb * h[b]
					p[d] = sd * i[d]
					pts.append(c + p)
				var n := Vector3.ZERO
				n[a] = sa
				n[b] = sb
				var col := _col(k, n, r)
				if rub >= 0 and n.y > 0.0 and _rub_matches(rub, n):
					col = r[5]
				face(k, pts, col, n)
	# Corner triangles.
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var sg := Vector3(sx, sy, sz)
				var pts: Array[Vector3] = []
				for a in 3:
					var p := i * sg
					p[a] = h[a] * sg[a]
					pts.append(c + p)
				face(k, pts, _col(k, sg, r), sg)


static func _rub_matches(rub: int, n: Vector3) -> bool:
	match rub:
		0: return n.x > 0.0
		1: return n.x < 0.0
		2: return n.z > 0.0
		3: return n.z < 0.0
	return false


static func _sharp_box(k: MeshKit, c: Vector3, h: Vector3, r: Array) -> void:
	for a in 3:
		for sa: float in [-1.0, 1.0]:
			var b := (a + 1) % 3
			var d := (a + 2) % 3
			var pts: Array[Vector3] = []
			for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var p := Vector3.ZERO
				p[a] = sa * h[a]
				p[b] = q.x * h[b]
				p[d] = q.y * h[d]
				pts.append(c + p)
			var n := Vector3.ZERO
			n[a] = sa
			face(k, pts, _col(k, n, r), n)


## Body colour for a face by its normal in the kit's current frame (the part's
## own space): tops lit v4, walls v3, undersides v2.
static func _col(k: MeshKit, local_n: Vector3, r: Array) -> Color:
	var n := (k._xf.basis * local_n).normalized()
	if n.y > 0.85:
		return r[3]
	if n.y > 0.25:
		return r[4]
	if n.y < -0.6:
		return r[0]
	if n.y < -0.25:
		return r[1]
	return (r[2] as Color).lerp(r[3], 0.55)


## The ramp stepped down `steps` values: legs and undercarriage only get dirtier.
static func dirty(r: Array, steps: int = 1) -> Array:
	var out: Array = []
	for j in r.size():
		out.append(r[maxi(0, j - steps)])
	return out


## An inset panel on a face: a dark frame line with a fastener in each corner.
static func panel(k: MeshKit, c: Vector3, n: Vector3, up: Vector3, w: float, h: float, r: Array) -> void:
	var uu := up.normalized()
	var rr := uu.cross(n.normalized())
	var line := 0.016
	mark(k, c + uu * (h * 0.5), n, uu, w, line, r[2], 0.003)
	mark(k, c - uu * (h * 0.5), n, uu, w, line, r[2], 0.003)
	mark(k, c + rr * (w * 0.5), n, uu, line, h, r[2], 0.003)
	mark(k, c - rr * (w * 0.5), n, uu, line, h, r[2], 0.003)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			mark(k, c + rr * (w * 0.5 - 0.035) * sx + uu * (h * 0.5 - 0.035) * sy, n, uu, 0.028, 0.028, r[5], 0.006)


## A hull from stacked rings of equal point count (bottom first, each ring a
## convex outline around the Y axis): walls between rings, a cap on the last.
## Paint follows the colour rule, so sloped shoulders take the lit rim.
static func loft(k: MeshKit, rings: Array, r: Array, rub_front: bool = false) -> void:
	var centre := Vector3.ZERO
	var count := 0
	for ring: Array in rings:
		for p: Vector3 in ring:
			centre += p
			count += 1
	centre /= maxi(1, count)
	for ri in rings.size() - 1:
		var a: Array = rings[ri]
		var b: Array = rings[ri + 1]
		for j in a.size():
			var j2 := (j + 1) % a.size()
			var pts: Array[Vector3] = [a[j], a[j2], b[j2], b[j]]
			var mid := (pts[0] + pts[1] + pts[2] + pts[3]) * 0.25
			var n := (pts[1] - pts[0]).cross(pts[3] - pts[0]).normalized()
			if n.dot(mid - centre) < 0.0:
				n = -n
			var col := _col(k, n, r)
			if rub_front and ri == rings.size() - 2 and n.x > 0.3:
				col = r[5]
			face(k, pts, col, n)
	var top: Array = rings[rings.size() - 1]
	var tp: Array[Vector3] = []
	for p: Vector3 in top:
		tp.append(p)
	face(k, tp, _col(k, Vector3.UP, r), Vector3.UP)


## A plan outline (x, z points, convex, in order) placed at height y, inset by `inset`.
static func ring(plan: Array[Vector2], y: float, inset: float = 0.0) -> Array:
	var c := Vector2.ZERO
	for p in plan:
		c += p
	c /= plan.size()
	var out: Array = []
	for p in plan:
		var q := p
		if inset > 0.0:
			q = p - (p - c).normalized() * inset
		out.append(Vector3(q.x, y, q.y))
	return out


## A straight member from a to b with a w x d section and a chamfer: legs,
## struts, masts, arms. Its flat sides keep facing +-Z where they can.
static func bar(k: MeshKit, a: Vector3, b: Vector3, w: float, d: float, ch: float, r: Array) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 1e-5:
		return
	var y := axis / length
	var ref := Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	k.push(Transform3D(Basis(x, y, z), a))
	cbox(k, Vector3(0, length * 0.5, 0), Vector3(w, length, d), ch, r)
	k.pop()


## A flat convex polygon, fan-triangulated, wound so its normal agrees with `out`.
static func face(k: MeshKit, pts: Array[Vector3], col: Color, out: Vector3) -> void:
	for t in range(1, pts.size() - 1):
		var a := pts[0]
		var b := pts[t]
		var c := pts[t + 1]
		if (b - a).cross(c - a).dot(out) >= 0.0:
			k.tri(a, b, c, col)
		else:
			k.tri(a, c, b, col)


## A chamfered n-gon slab (disc, wheel, column, hub) centred on `c`, its round
## faces normal to `axis`. Radius `rad`, thickness `th`, chamfer `ch` on both rims.
## `cap` colours the round faces (defaults to the rim rule). 8n triangles with a
## chamfer, 4n without.
static func disc(k: MeshKit, c: Vector3, axis: Vector3, rad: float, th: float, n: int, ch: float, r: Array, cap: Color = Color(0, 0, 0, 0), phase: float = 0.0) -> void:
	var ax := axis.normalized()
	var u := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := ax.cross(u)
	var half := th * 0.5
	ch = minf(ch, minf(half, rad) * 0.9)
	var rings: Array = []
	# Rings from the -axis cap to the +axis cap: [radius, offset along axis].
	var spec: Array[Vector2] = []
	if ch > 0.0:
		spec = [Vector2(rad - ch, -half), Vector2(rad, -half + ch), Vector2(rad, half - ch), Vector2(rad - ch, half)]
	else:
		spec = [Vector2(rad, -half), Vector2(rad, half)]
	for sp: Vector2 in spec:
		var ring: Array[Vector3] = []
		for j in n:
			var a := phase + float(j) / n * TAU
			ring.append(c + ax * sp.y + (u * cos(a) + v * sin(a)) * sp.x)
		rings.append(ring)
	for ri in rings.size() - 1:
		var r0: Array[Vector3] = rings[ri]
		var r1: Array[Vector3] = rings[ri + 1]
		for j in n:
			var j2 := (j + 1) % n
			var mid := (r0[j] + r0[j2] + r1[j] + r1[j2]) * 0.25 - c
			var col := _col(k, mid, r)
			face(k, [r0[j], r0[j2], r1[j2], r1[j]], col, mid)
	for side: int in [0, rings.size() - 1]:
		var ring: Array[Vector3] = rings[side]
		var out := ax * (1.0 if side > 0 else -1.0)
		var col := cap if cap.a > 0.0 else _col(k, out, r)
		face(k, ring, col, out)


## A flat mark lying on a face: centre `c`, facing `n`, `up` along the face,
## size w (across) x h (along up), lifted a hair off the surface. 2 triangles.
static func mark(k: MeshKit, c: Vector3, n: Vector3, up: Vector3, w: float, h: float, col: Color, lift: float = 0.004) -> void:
	var nn := n.normalized()
	var uu := up.normalized()
	var rr := uu.cross(nn)
	var o := c + nn * lift
	var hw := rr * (w * 0.5)
	var hh := uu * (h * 0.5)
	face(k, [o - hw - hh, o + hw - hh, o + hw + hh, o - hw + hh], col, nn)


## A row of `count` rivets from a to b on a face with normal n (v5 heads).
static func rivets(k: MeshKit, a: Vector3, b: Vector3, n: Vector3, count: int, col: Color, size: float = 0.035) -> void:
	var up := (b - a).normalized()
	if absf(up.dot(n.normalized())) > 0.9:
		up = Vector3.UP
	for j in count:
		var t := 0.5 if count == 1 else float(j) / (count - 1)
		mark(k, a.lerp(b, t), n, up, size, size, col, 0.006)


## A seam: a dark line from a to b with a rivet each side at every `count` step.
static func seam(k: MeshKit, a: Vector3, b: Vector3, n: Vector3, r: Array, count: int = 4) -> void:
	var along := b - a
	var up := along.normalized()
	mark(k, (a + b) * 0.5, n, up, 0.018, along.length(), r[1], 0.003)
	var side := up.cross(n.normalized()) * 0.035
	for j in count:
		var t := (float(j) + 0.5) / count
		var p := a.lerp(b, t)
		mark(k, p + side, n, up, 0.03, 0.03, r[5], 0.006)
		mark(k, p - side, n, up, 0.03, 0.03, r[5], 0.006)


## Downward wear streaks under a feature: `count` dark columns starting at `top`
## (a point on the face) spread across `w`, lengths hashed from `seed_value` so
## every copy of a kind carries the same streaks ("off the same line").
static func streaks(k: MeshKit, top: Vector3, n: Vector3, w: float, max_len: float, count: int, seed_value: int, col: Color) -> void:
	var nn := n.normalized()
	var across := Vector3.UP.cross(nn).normalized()
	for j in count:
		var t := 0.5 if count == 1 else float(j) / (count - 1) - 0.5
		var length := max_len * (0.35 + 0.65 * Rng.hash01(seed_value, j, 77))
		var x := t * w
		mark(k, top + across * x - Vector3.UP * length * 0.5, nn, Vector3.UP, 0.022, length, col, 0.003)


## The COLD visor slit on a plated face: a dark socket with the slit in COLD 1/2.
## "Armour, nothing to reach." The moving scan highlight is a separate node.
static func visor(k: MeshKit, c: Vector3, n: Vector3, up: Vector3, w: float, h: float) -> void:
	mark(k, c, n, up, w + 0.05, h + 0.05, Palette.INK[1], 0.003)
	mark(k, c, n, up, w, h, Palette.COLD[1], 0.006)
	mark(k, c + up.normalized() * h * 0.25, n, up, w, h * 0.3, Palette.COLD[2], 0.008)


## An amber cavity: a dark recessed frame with the LENS core and a hot centre.
## Built into the PART mesh so the light can go out.
static func lens(k: MeshKit, c: Vector3, n: Vector3, up: Vector3, w: float, h: float) -> void:
	mark(k, c, n, up, w + 0.06, h + 0.06, Palette.LENS[0], 0.004)
	mark(k, c, n, up, w, h, Palette.LENS[2], 0.008)
	mark(k, c, n, up, w * 0.45, h * 0.45, Palette.LENS[3], 0.012)


## The same part with its light out: amber goes to the cavity's dead values.
static func dark_colour(col: Color) -> Color:
	if col == Palette.LENS[3]:
		return Palette.LENS[1]
	if col == Palette.LENS[2]:
		return Palette.LENS[0]
	if col == Palette.LENS[1] or col == Palette.LENS[0]:
		return Palette.INK[1]
	if col == Palette.COLD[3] or col == Palette.COLD[2]:
		return Palette.COLD[0]
	return col


## Copy a kit with every lit colour swapped for its dark value.
static func darkened(k: MeshKit) -> MeshKit:
	var d := MeshKit.new()
	d.verts = k.verts.duplicate()
	d.normals = k.normals.duplicate()
	d.colors = PackedColorArray()
	for col in k.colors:
		d.colors.append(dark_colour(col))
	return d
