class_name FoundKit
## Mesh vocabulary for FOUND things (machines and what comes off them), on top of
## MeshKit. Everything here is exact: symmetric, straight, chamfered, riveted.
## MADE things never use it. docs/ART.md §4: a FOUND shape is never a plain box
## at a glance, so the kit's first words are lathes, tapered lofts and extruded
## plates; cbox is for small fittings.
##
## Colour follows art-audio-extract §2c on a per-kind ramp `r` (6 values,
## Palette.MACHINE[kind]), always an exact ramp value, chosen from the face's
## normal in the kit's frame at build time:
##   up faces v3 (body fill)       up-facing bevels and shoulders v4 (lit rim)
##   walls v2 (dark rim)           down-facing bevels v1, undersides v0
## so a machine reads as a dark violet mass ruled with bright chamfer lines.
##   rivets, fasteners and the one rubbed edge v5
##
## All helpers draw through the MeshKit transform stack (k.push / k.at).

const UP := Vector3.UP
## One screen pixel at the camera players have (camera_rig: 14 world units over
## 360 px). Every mark in the daylight vocabulary below is budgeted in these, not
## in world units: a 0.02-wide scribed line is exact, and it is also half a pixel,
## which is why a machine drawn entirely in them says nothing at noon.
const PX := 14.0 / 360.0


## A MeshKit set up for FOUND geometry: no hatch hand, rigid.
static func kit() -> MeshKit:
	var k := MeshKit.new()
	k.style = Ink.NONE
	k.style2 = Ink.NONE
	return k


# -- colour -------------------------------------------------------------------

## Body colour for a face by its normal in the kit's frame.
static func _col(k: MeshKit, local_n: Vector3, r: Array) -> Color:
	return r[_col_index(k, local_n)]


static func _col_index(k: MeshKit, local_n: Vector3) -> int:
	var n := (k._xf.basis * local_n).normalized()
	# Gentle slopes are still the top; only a steep bevel catches the rim light.
	if n.y > 0.8:
		return 3
	if n.y > 0.3:
		return 4
	if n.y < -0.7:
		return 0
	if n.y < -0.3:
		return 1
	return 2


## The ramp stepped down `steps` values: legs and undercarriage only get dirtier.
static func dirty(r: Array, steps: int = 1) -> Array:
	var out: Array = []
	for j in r.size():
		out.append(r[maxi(0, j - steps)])
	return out


## One colour on every face (loads, dark cavities).
static func flat(col: Color) -> Array:
	return [col, col, col, col, col, col]


# -- primitive faces ------------------------------------------------------------

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


## A flat regular polygon on a face (round lenses, hub caps, bolt heads).
static func spot(k: MeshKit, c: Vector3, n: Vector3, rad: float, sides: int, col: Color, lift: float = 0.004, phase: float = 0.0) -> void:
	var nn := n.normalized()
	var u := nn.cross(UP if absf(nn.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := nn.cross(u)
	var pts: Array[Vector3] = []
	for j in sides:
		var a := phase + float(j) / sides * TAU
		pts.append(c + nn * lift + (u * cos(a) + v * sin(a)) * rad)
	face(k, pts, col, nn)


# -- solids ---------------------------------------------------------------------

## Chamfered box centred on `c`, full size `s`, chamfer `ch`. `rub` paints one
## upper edge v5 (the rubbed-bright edge of the biggest panel): 0 +X, 1 -X,
## 2 +Z, 3 -Z, -1 none. 44 triangles (12 when ch is 0). For fittings only.
static func cbox(k: MeshKit, c: Vector3, s: Vector3, ch: float, r: Array, rub: int = -1) -> void:
	var h := s * 0.5
	ch = minf(ch, minf(h.x, minf(h.y, h.z)) * 0.9)
	if ch <= 0.0:
		_sharp_box(k, c, h, r)
		return
	var i := h - Vector3(ch, ch, ch)
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


## Rings turned about an axis: the machines' main solid. `spec` lists
## Vector2(radius, offset along axis) from one end to the other; `squash`
## scales the section (x across, y the other way) for oval and flat sections.
## Walls between rings, caps on both ends where the radius is not 0. `rub_ring`
## paints the band after that ring index v5 on its upper side, facing `rub_dir`.
static func lathe(k: MeshKit, c: Vector3, axis: Vector3, spec: Array[Vector2], n: int, r: Array, phase: float = 0.0, squash: Vector2 = Vector2.ONE, cap_col: Color = Color(0, 0, 0, 0), rub_ring: int = -1, caps: bool = true, rub_dir: Vector3 = Vector3.RIGHT) -> void:
	var ax := axis.normalized()
	var u := ax.cross(UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := ax.cross(u)
	var rings: Array = []
	for sp: Vector2 in spec:
		var ring: Array[Vector3] = []
		for j in n:
			var a := phase + float(j) / n * TAU
			ring.append(c + ax * sp.y + (u * cos(a) * squash.x + v * sin(a) * squash.y) * sp.x)
		rings.append(ring)
	for ri in rings.size() - 1:
		var r0: Array[Vector3] = rings[ri]
		var r1: Array[Vector3] = rings[ri + 1]
		var mid_axis := c + ax * (spec[ri].y + spec[ri + 1].y) * 0.5
		for j in n:
			var j2 := (j + 1) % n
			var pts: Array[Vector3] = [r0[j], r0[j2], r1[j2], r1[j]]
			var nrm := _quad_normal(pts, mid_axis)
			if nrm == Vector3.ZERO:
				continue
			var col := _col(k, nrm, r)
			# One rubbed edge, on one side: where the thing is handled or knocked.
			if ri == rub_ring and (k._xf.basis * nrm).y > 0.2 and nrm.dot(rub_dir) > 0.5:
				col = r[5]
			face(k, _dedupe(pts), col, nrm)
	for end: int in [0, rings.size() - 1]:
		if not caps or spec[end].x <= 0.0:
			continue
		var ring: Array[Vector3] = rings[end]
		var out := ax * (1.0 if end > 0 else -1.0)
		if spec.size() > 1:
			out = ax * signf(spec[end].y - spec[1 if end == 0 else end - 1].y)
		var col := cap_col if cap_col.a > 0.0 else _col(k, out, r)
		face(k, ring, col, out)


static func _quad_normal(pts: Array[Vector3], centre: Vector3) -> Vector3:
	var nrm := (pts[1] - pts[0]).cross(pts[3] - pts[0])
	if nrm.length_squared() < 1e-12:
		nrm = (pts[2] - pts[1]).cross(pts[3] - pts[1])
	if nrm.length_squared() < 1e-12:
		return Vector3.ZERO
	nrm = nrm.normalized()
	var mid := (pts[0] + pts[1] + pts[2] + pts[3]) * 0.25
	return nrm if nrm.dot(mid - centre) >= 0.0 else -nrm


static func _dedupe(pts: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in pts:
		if out.is_empty() or (out[out.size() - 1] - p).length_squared() > 1e-12:
			out.append(p)
	if out.size() > 1 and (out[0] - out[out.size() - 1]).length_squared() < 1e-12:
		out.pop_back()
	return out


## A straight member from a to b: an n-sided section tapering from r0 to r1,
## capped. Legs, masts, struts, arms. `ch` > 0 chamfers both ends.
static func tbar(k: MeshKit, a: Vector3, b: Vector3, r0: float, r1: float, n: int, r: Array, ch: float = 0.0) -> void:
	var length := (b - a).length()
	if length < 1e-5:
		return
	var spec: Array[Vector2] = []
	if ch > 0.0:
		ch = minf(ch, length * 0.3)
		spec = [Vector2(r0 - ch * 0.6, 0.0), Vector2(r0, ch), Vector2(r1, length - ch), Vector2(r1 - ch * 0.6, length)]
	else:
		spec = [Vector2(r0, 0.0), Vector2(r1, length)]
	lathe(k, a, b - a, spec, n, r, PI / n)


## A member with a flat w x d section and a chamfer (plated struts, brackets).
## Its flat sides keep facing +-Z where they can.
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


## A chamfered n-gon slab (disc, wheel, drum, hub) centred on `c`, its round
## faces normal to `axis`. Radius `rad`, thickness `th`, chamfer `ch` on both rims.
static func disc(k: MeshKit, c: Vector3, axis: Vector3, rad: float, th: float, n: int, ch: float, r: Array, cap: Color = Color(0, 0, 0, 0), phase: float = 0.0) -> void:
	var half := th * 0.5
	ch = minf(ch, minf(half, rad) * 0.9)
	var spec: Array[Vector2] = []
	if ch > 0.0:
		spec = [Vector2(rad - ch, -half), Vector2(rad, -half + ch), Vector2(rad, half - ch), Vector2(rad - ch, half)]
	else:
		spec = [Vector2(rad, -half), Vector2(rad, half)]
	lathe(k, c, axis, spec, n, r, phase, Vector2.ONE, cap)


## A convex outline `poly` (points in the plane of u, v about `o`) extruded
## `th` along u x v, centred on the plane: fins, lids, brackets, blades.
static func slab(k: MeshKit, o: Vector3, u: Vector3, v: Vector3, poly: Array[Vector2], th: float, r: Array, bevel: float = 0.0) -> void:
	var nn := u.cross(v).normalized()
	var front: Array[Vector3] = []
	var back: Array[Vector3] = []
	var centre := Vector2.ZERO
	for p in poly:
		centre += p
	centre /= poly.size()
	for p in poly:
		var q := p
		if bevel > 0.0:
			q = p - (p - centre).normalized() * bevel
		front.append(o + u * q.x + v * q.y + nn * (th * 0.5))
		back.append(o + u * q.x + v * q.y - nn * (th * 0.5))
	if bevel > 0.0:
		var mid_f: Array[Vector3] = []
		var mid_b: Array[Vector3] = []
		for p in poly:
			mid_f.append(o + u * p.x + v * p.y + nn * (th * 0.5 - bevel))
			mid_b.append(o + u * p.x + v * p.y - nn * (th * 0.5 - bevel))
		_band(k, front, mid_f, r)
		_band(k, mid_f, mid_b, r)
		_band(k, mid_b, back, r)
	else:
		_band(k, front, back, r)
	face(k, front, _col(k, nn, r), nn)
	face(k, back, _col(k, -nn, r), -nn)


static func _band(k: MeshKit, a: Array[Vector3], b: Array[Vector3], r: Array) -> void:
	var centre := Vector3.ZERO
	for p in a:
		centre += p
	for p in b:
		centre += p
	centre /= (a.size() + b.size())
	for j in a.size():
		var j2 := (j + 1) % a.size()
		var pts: Array[Vector3] = [a[j], a[j2], b[j2], b[j]]
		var nrm := _quad_normal(pts, centre)
		if nrm != Vector3.ZERO:
			face(k, pts, _col(k, nrm, r), nrm)


## A hull from stacked rings of equal point count (bottom first, each ring a
## convex outline around the Y axis): walls between rings, a cap on the last,
## and on the first when `bottom`. Sloped shoulders take the lit rim.
static func loft(k: MeshKit, rings: Array, r: Array, rub_front: bool = false, bottom: bool = false) -> void:
	for ri in rings.size() - 1:
		var a: Array = rings[ri]
		var b: Array = rings[ri + 1]
		var ring_c := Vector3.ZERO
		for p: Vector3 in a:
			ring_c += p
		for p: Vector3 in b:
			ring_c += p
		ring_c /= (a.size() + b.size())
		for j in a.size():
			var j2 := (j + 1) % a.size()
			var pts: Array[Vector3] = [a[j], a[j2], b[j2], b[j]]
			var n := _quad_normal(pts, ring_c)
			if n == Vector3.ZERO:
				continue
			var col := _col(k, n, r)
			if rub_front and ri == rings.size() - 2 and n.x > 0.3:
				col = r[5]
			face(k, _dedupe(pts), col, n)
	var top: Array = rings[rings.size() - 1]
	var tp: Array[Vector3] = []
	for p: Vector3 in top:
		tp.append(p)
	face(k, tp, _col(k, Vector3.UP, r), Vector3.UP)
	if bottom:
		var bp: Array[Vector3] = []
		for p: Vector3 in rings[0]:
			bp.append(p)
		face(k, bp, _col(k, Vector3.DOWN, r), Vector3.DOWN)


## A plan outline (x, z points, convex, in order) placed at height y, inset by
## `inset` toward its centre, then scaled by `s` about it and moved by `shift`.
static func ring(plan: Array[Vector2], y: float, inset: float = 0.0, s: Vector2 = Vector2.ONE, shift: Vector2 = Vector2.ZERO) -> Array:
	var c := Vector2.ZERO
	for p in plan:
		c += p
	c /= plan.size()
	var out: Array = []
	for p in plan:
		var q := p
		if inset > 0.0:
			q = p - (p - c).normalized() * inset
		q = c + (q - c) * s + shift
		out.append(Vector3(q.x, y, q.y))
	return out


## A chamfered rectangle plan w (x) by d (z): eight points in order from +X.
static func plan_oct(w: float, d: float, ch: float) -> Array[Vector2]:
	var hx := w * 0.5
	var hz := d * 0.5
	ch = minf(ch, minf(hx, hz) * 0.95)
	return [Vector2(hx, -hz + ch), Vector2(hx, hz - ch), Vector2(hx - ch, hz), Vector2(-hx + ch, hz), Vector2(-hx, hz - ch), Vector2(-hx, -hz + ch), Vector2(-hx + ch, -hz), Vector2(hx - ch, -hz)]


# -- the idiom: fittings and marks ------------------------------------------------

## An inset panel on a face: a dark frame line with a fastener in each corner.
## The frame is two screen pixels and the fasteners one and a half, so the panel
## is still there at the camera players have and not only in a review close-up.
static func panel(k: MeshKit, c: Vector3, n: Vector3, up: Vector3, w: float, h: float, r: Array) -> void:
	var uu := up.normalized()
	var rr := uu.cross(n.normalized())
	var line := PX * 2.0
	mark(k, c + uu * (h * 0.5), n, uu, w, line, r[1], 0.003)
	mark(k, c - uu * (h * 0.5), n, uu, w, line, r[1], 0.003)
	mark(k, c + rr * (w * 0.5), n, uu, line, h, r[1], 0.003)
	mark(k, c - rr * (w * 0.5), n, uu, line, h, r[1], 0.003)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			mark(k, c + rr * (w * 0.5 - PX * 1.4) * sx + uu * (h * 0.5 - PX * 1.4) * sy, n, uu, PX * 1.6, PX * 1.6, r[5], 0.006)


## A row of `count` rivets from a to b on a face with normal n. A rivet is never
## thinner than a screen pixel and a half: a row of them should read as a ruled
## line of fasteners, not as a faint dither along an edge.
static func rivets(k: MeshKit, a: Vector3, b: Vector3, n: Vector3, count: int, col: Color, size: float = PX * 1.6) -> void:
	size = maxf(size, PX * 1.5)
	var up := (b - a).normalized() if (b - a).length() > 1e-5 else UP
	if absf(up.dot(n.normalized())) > 0.9:
		up = UP if absf(n.normalized().y) < 0.9 else Vector3.RIGHT
	for j in count:
		var t := 0.5 if count == 1 else float(j) / (count - 1)
		mark(k, a.lerp(b, t), n, up, size, size, col, 0.006)


## A seam: a dark line from a to b with a rivet each side at every step.
static func seam(k: MeshKit, a: Vector3, b: Vector3, n: Vector3, r: Array, count: int = 4) -> void:
	var along := b - a
	var up := along.normalized()
	mark(k, (a + b) * 0.5, n, up, PX * 2.0, along.length(), r[1], 0.003)
	var side := up.cross(n.normalized()) * (PX * 2.2)
	for j in count:
		var t := (float(j) + 0.5) / count
		var p := a.lerp(b, t)
		mark(k, p + side, n, up, PX * 1.6, PX * 1.6, r[5], 0.006)
		mark(k, p - side, n, up, PX * 1.6, PX * 1.6, r[5], 0.006)


## Downward wear streaks under a feature: `count` dark columns from `top` spread
## across `w`, lengths hashed from `seed_value` so every copy of a kind carries
## the same streaks ("off the same line").
static func streaks(k: MeshKit, top: Vector3, n: Vector3, w: float, max_len: float, count: int, seed_value: int, col: Color) -> void:
	var nn := n.normalized()
	var across := UP.cross(nn).normalized()
	for j in count:
		var t := 0.5 if count == 1 else float(j) / (count - 1) - 0.5
		var length := maxf(PX * 2.0, max_len * (0.35 + 0.65 * Rng.hash01(seed_value, j, 77)))
		mark(k, top + across * (t * w) - UP * length * 0.5, nn, UP, PX * 1.8, length, col, 0.003)


## Graduations along a member, as on a rule: short ticks with every fifth long.
## The machines were drawn with one and still carry it.
static func ticks(k: MeshKit, a: Vector3, b: Vector3, n: Vector3, count: int, col: Color, w: float = 0.03) -> void:
	var along := (b - a).normalized()
	var across := along.cross(n.normalized())
	for j in count:
		var t := float(j) / maxi(1, count - 1)
		var length := w * (1.8 if j % 5 == 0 else 1.0)
		mark(k, a.lerp(b, t) + across * (length * 0.5 - w * 0.5), n, across, 0.014, length, col, 0.004)


## The COLD visor slit on a plated face: a dark socket with the slit in COLD 1/2.
## "Armour, nothing to reach." The moving scan highlight is a separate node.
static func visor(k: MeshKit, c: Vector3, n: Vector3, up: Vector3, w: float, h: float) -> void:
	mark(k, c, n, up, w + 0.05, h + 0.045, Palette.INK[1], 0.003)
	mark(k, c, n, up, w, h, Palette.COLD[1], 0.006)
	mark(k, c + up.normalized() * h * 0.25, n, up, w * 0.94, h * 0.34, Palette.COLD[2], 0.008)


## An amber cavity: a dark recessed frame with the LENS core and a hot centre.
## Built into the PART mesh so the light can go out.
static func lens(k: MeshKit, c: Vector3, n: Vector3, up: Vector3, w: float, h: float) -> void:
	mark(k, c, n, up, w + 0.06, h + 0.06, Palette.LENS[0], 0.004)
	mark(k, c, n, up, w, h, Palette.LENS[2], 0.008)
	mark(k, c, n, up, w * 0.45, h * 0.45, Palette.LENS[3], 0.012)


## A round amber optic: bezel, core, hot centre. Part mesh.
static func optic(k: MeshKit, c: Vector3, n: Vector3, rad: float) -> void:
	spot(k, c, n, rad * 1.35, 8, Palette.LENS[0], 0.003, PI / 8.0)
	spot(k, c, n, rad, 8, Palette.LENS[2], 0.007, PI / 8.0)
	spot(k, c, n, rad * 0.45, 6, Palette.LENS[3], 0.011)


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
	d.uvs = k.uvs.duplicate()
	d.uv2s = k.uv2s.duplicate()
	d.custom0 = k.custom0.duplicate()
	d.colors = PackedColorArray()
	for col in k.colors:
		d.colors.append(dark_colour(col))
	return d


## Natural matter a machine carries or spills (ore, spoil, sweepings, a cut
## row) is not FOUND: it is drawn by the hand on the world material. A kit for it.
static func matter_kit(hatch: int = Ink.CONTOUR) -> MeshKit:
	var k := MeshKit.new()
	k.style = hatch
	k.style2 = hatch
	return k


# -- wear: what the years and the other machines did ---------------------------
# The machines were drawn exact and have been running ever since. Wear is still
# FOUND (ramp values, INK and COLD only) and still ruled: a patch is a straight
# plate set a few degrees off the panel grid, a cable is a clean line that sags.
# Pieces of wear go on a model's `wear` holders (MachineModel.wear_mesh), so a
# test can take them off and find the machine as built still mirror-exact.

## Down a face with normal n (the face's own down, for walls and slopes).
static func _down_on(n: Vector3) -> Vector3:
	var d := Vector3.DOWN - n * Vector3.DOWN.dot(n)
	return d.normalized() if d.length() > 0.1 else Vector3.LEFT


## Grime run down a face from `top`: `count` drips across `w`, lengths hashed
## from `seed_value`, each a dark column narrowing to a darker bead at its foot.
## Widths are held to at least two screen pixels: a one-pixel drip is a dither
## speck, and what a player should read here is that the machine is filthy.
static func grime(k: MeshKit, top: Vector3, n: Vector3, w: float, max_len: float, count: int, seed_value: int, r: Array) -> void:
	var nn := n.normalized()
	var down := _down_on(nn)
	var across := down.cross(nn).normalized()
	for j in count:
		var t := 0.0 if count == 1 else float(j) / (count - 1) - 0.5
		t += (Rng.hash01(seed_value, j, 5) - 0.5) * 0.3 / maxf(1.0, count)
		var length := maxf(PX * 2.0, max_len * (0.3 + 0.7 * Rng.hash01(seed_value, j, 6)))
		var width := PX * (2.0 + 1.6 * Rng.hash01(seed_value, j, 7))
		var p := top + across * (t * w)
		mark(k, p + down * length * 0.3, nn, -down, width, length * 0.6, r[1], 0.003)
		mark(k, p + down * length * 0.8, nn, -down, width * 0.7, length * 0.4, r[0], 0.0035)
		mark(k, p + down * length, nn, -down, width * 1.2, PX * 1.4, r[0], 0.004)


## A band of dirt along the lower edge of a face, from a to b, `h` deep.
static func dirt_line(k: MeshKit, a: Vector3, b: Vector3, n: Vector3, h: float, col: Color) -> void:
	var along := b - a
	mark(k, (a + b) * 0.5, n, along, h, along.length(), col, 0.0025)


## A plate welded over damage by another machine: its own ramp `rp` one value
## off the face it covers, set a few degrees off the panel grid, a dark weld
## line round it and a bead at three corners (the fourth was never done).
static func patch(k: MeshKit, c: Vector3, n: Vector3, up: Vector3, w: float, h: float, rp: Array, seed_value: int, lift: float = 0.005) -> void:
	var nn := n.normalized()
	var u := up.normalized().rotated(nn, (Rng.hash01(seed_value, 1) - 0.5) * 0.22)
	var rr := u.cross(nn)
	var idx := clampi(_col_index(k, nn) + (1 if Rng.hash01(seed_value, 2) > 0.5 else -1), 1, 4)
	mark(k, c, nn, u, w + 0.028, h + 0.028, Palette.INK[1], lift)
	mark(k, c, nn, u, w, h, rp[idx], lift + 0.003)
	var skip := int(Rng.hash01(seed_value, 3) * 4.0)
	var corner := 0
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			if corner != skip:
				mark(k, c + rr * (w * 0.5 - 0.03) * sx + u * (h * 0.5 - 0.03) * sy, nn, u, 0.028, 0.028, rp[5], lift + 0.006)
			corner += 1


## A burn: an uneven dark octagon on a face, blacker at its heart.
static func scorch(k: MeshKit, c: Vector3, n: Vector3, rad: float, seed_value: int) -> void:
	var nn := n.normalized()
	var u := nn.cross(UP if absf(nn.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := nn.cross(u)
	for layer in 2:
		var pts: Array[Vector3] = []
		var sc := 1.0 if layer == 0 else 0.5
		for j in 8:
			var a := float(j) / 8.0 * TAU
			var rr := rad * sc * (0.6 + 0.4 * Rng.hash01(seed_value, j, layer))
			pts.append(c + nn * (0.004 + layer * 0.002) + (u * cos(a) + v * sin(a)) * rr)
		face(k, pts, Palette.INK[2 - layer], nn)


## A cable run from a to b sagging `sag` at its middle, in `col`, clamped at
## both ends; `sleeve` (a ramp, or empty) is the splice another machine made.
static func cable(k: MeshKit, a: Vector3, b: Vector3, sag: float, rad: float, col: Color, sleeve: Array = [], segments: int = 4) -> void:
	var pts: Array[Vector3] = []
	for i in segments + 1:
		var t := float(i) / segments
		pts.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	var line := flat(col)
	for i in segments:
		lathe(k, pts[i], pts[i + 1] - pts[i], [Vector2(rad, 0.0), Vector2(rad, (pts[i + 1] - pts[i]).length())], 4, line, PI / 4.0, Vector2.ONE, Color(0, 0, 0, 0), -1, false)
	var clamp_r: Array = dirty(sleeve, 1) if not sleeve.is_empty() else flat(Palette.INK[2])
	for end: int in [0, segments]:
		var dir := (pts[1] - pts[0]) if end == 0 else (pts[segments] - pts[segments - 1])
		dir = dir.normalized()
		tbar(k, pts[end] - dir * rad * 2.0, pts[end] + dir * rad * 2.0, rad * 2.0, rad * 2.0, 4, clamp_r)
	if not sleeve.is_empty():
		var m := int(segments * 0.5)
		var d2 := (pts[m + 1] - pts[m]).normalized()
		tbar(k, pts[m] - d2 * rad * 3.5, pts[m] + d2 * rad * 3.5, rad * 1.9, rad * 1.9, 4, sleeve)


## Wire wound round a member from a to b: `turns` turns at radius `rad`, a barb
## standing off every few steps when `barbed` (fence wire a hunter dragged away).
static func coil(k: MeshKit, a: Vector3, b: Vector3, rad: float, turns: float, wire_r: float, col: Color, barbed: bool = false) -> void:
	var ax := b - a
	var span := ax.length()
	if span < 1e-5:
		return
	var axn := ax / span
	var u := axn.cross(UP if absf(axn.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axn.cross(u)
	var steps := maxi(6, int(turns * 5.0))
	var prev := a + u * rad
	var line := flat(col)
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var ang := t * turns * TAU
		var p := a + axn * span * t + (u * cos(ang) + v * sin(ang)) * rad
		lathe(k, prev, p - prev, [Vector2(wire_r, 0.0), Vector2(wire_r, (p - prev).length())], 3, line, 0.0, Vector2.ONE, Color(0, 0, 0, 0), -1, false)
		if barbed and i % 3 == 0:
			var out := (p - (a + axn * span * t)).normalized()
			tbar(k, p, p + out * 0.04 + axn * 0.012, wire_r * 0.9, 0.0, 3, line)
		prev = p


# -- daylight: what a plate says when none of it is lit -------------------------
# found.gdshader gives a FOUND face one flat wash and ONE hard shade step, so at
# noon a big plate is a single value and the machine is a box. Night is not the
# problem; the lamps do that work. These are the marks that make a plate speak by
# day, and they are ruled like everything else FOUND: plates at neighbouring ramp
# values divided by straight channels, wells of shadow with a lip on the light's
# side, and grime in dead-straight runs.

## A shadowed recess in a plate: a dark well, a ruled lip along the light's side.
## Value is ink (ART law 2) — the well is a flat dark wash, never a gradient.
##
## `floor_px` is the smallest the well may be, in screen pixels. Three is right on
## a hull, where a well any smaller is lost in the middle of a wide flat wash. The
## thin kinds — a watcher's drum, a warden's cap, a runner's chest — have no face
## three pixels wide to spare, and on them a well is framed by the machine's own
## edges instead: they pass a smaller floor rather than go without.
static func recess(k: MeshKit, c: Vector3, n: Vector3, up: Vector3, w: float, h: float, r: Array, lift: float = 0.005, floor_px: float = 3.0) -> void:
	var nn := n.normalized()
	var uu := up.normalized()
	w = maxf(w, PX * floor_px)
	h = maxf(h, PX * floor_px)
	mark(k, c, nn, uu, w + PX * 1.6, h + PX * 1.6, r[1], lift)
	mark(k, c, nn, uu, w, h, r[0], lift + 0.002)
	# The key light is up the screen and to the left, so that edge is the one the
	# machined lip catches: one bright line is what says "this is a hole".
	mark(k, c + uu * (h * 0.5 + PX * 0.8), nn, uu, w + PX * 1.6, PX * 1.3, r[4], lift + 0.004)


## A plate laid on a plate: its own face value stepped by `step`, inside a ruled
## channel, so one big face reads as two or three plates instead of one slab.
## Step 5 is reserved for rivets and the one rubbed edge: a plate that took it
## would be a bright field, and the compressed top exists to stop exactly that.
static func plate(k: MeshKit, c: Vector3, n: Vector3, up: Vector3, w: float, h: float, r: Array, step: int, lift: float = 0.004) -> void:
	var nn := n.normalized()
	var uu := up.normalized()
	var idx := _col_index(k, nn)
	var want := clampi(idx + step, 0, 4)
	if want == idx:
		return
	mark(k, c, nn, uu, w + PX * 2.2, h + PX * 2.2, r[1], lift)
	mark(k, c, nn, uu, w, h, r[want], lift + 0.002)


## Everything above over one w x h patch of a face, composed from `seed_value`:
## a dirtier plate across most of it, a rubbed-bright strip along one edge,
## `wells` shadowed recesses, and grime running off the lower lip. Every copy of
## a kind carries the same years, and no two kinds wear the same way.
static func day_wear(k: MeshKit, c: Vector3, n: Vector3, up: Vector3, w: float, h: float, r: Array, seed_value: int, wells: int = 1) -> void:
	var nn := n.normalized()
	var uu := up.normalized()
	var rr := uu.cross(nn)
	var side := 1.0 if Rng.hash01(seed_value, 1) > 0.5 else -1.0
	# The big dirty plate: most of the patch, set square, its channel ruled round it.
	var pw := w * (0.62 + 0.16 * Rng.hash01(seed_value, 2))
	var ph := h * (0.58 + 0.2 * Rng.hash01(seed_value, 3))
	var pc := c + rr * ((w - pw) * 0.5 - PX) * side + uu * ((h - ph) * 0.5 - PX) * -side
	plate(k, pc, nn, uu, pw, ph, r, -2)
	# A strip along the far edge, rubbed a step brighter where the weather runs off.
	var sh := maxf(h * 0.14, PX * 2.5)
	plate(k, c - uu * (h * 0.5 - sh * 0.5) * side, nn, uu, w * 0.86, sh, r, 1, 0.008)
	for i in wells:
		var t := (float(i) + 0.5) / maxf(1.0, float(wells)) - 0.5
		var jitter := (Rng.hash01(seed_value, i, 4) - 0.5) * 0.2
		recess(k, pc + rr * (pw * (t + jitter)) + uu * ph * (0.12 - 0.3 * Rng.hash01(seed_value, i, 5)),
			nn, uu, minf(pw * 0.3, maxf(PX * 5.0, h * 0.3)), maxf(PX * 4.0, h * 0.24), r, 0.012)
	grime(k, pc - uu * (ph * 0.5) + rr * (pw * 0.12 * side), nn, pw * 0.7, h * 0.55, 3 + (seed_value % 3), seed_value + 7, r)


## The same three things on a face too small for day_wear: one plate step, one
## shadowed well, one run of grime, every one of them a fraction of the face
## instead of a hull's fixed size.
##
## day_wear composes for a harvester's deck — half a tile across — and its wells
## are floored at a hull's five screen pixels. A watcher's drum, a warden's cap, a
## runner's chest and a lineman's lid are a fifth of that, and the same call would
## put one well where the whole plate belongs, or nothing at all. Without this the
## thin kinds got no daylight at all: at noon they were a body with chamfer lines
## and no other thing on them to read.
static func day_marks(k: MeshKit, c: Vector3, n: Vector3, up: Vector3, w: float, h: float, r: Array, seed_value: int, floor_px: float = 2.2) -> void:
	var nn := n.normalized()
	var uu := up.normalized()
	var rr := uu.cross(nn)
	var side := 1.0 if Rng.hash01(seed_value, 1) > 0.5 else -1.0
	# Two plates where the ruler drew one, the bigger of them a step dirtier.
	var pw := maxf(PX * 2.0, w * 0.6)
	var ph := maxf(PX * 2.0, h * 0.7)
	var pc := c + rr * ((w - pw) * 0.5) * side
	plate(k, pc, nn, uu, pw, ph, r, -2)
	# The one rubbed edge, down the far side, where the weather runs off it.
	var sw := maxf(w * 0.18, PX * 1.2)
	plate(k, c - rr * (w - sw) * 0.5 * side, nn, uu, sw, h * 0.7, r, 1, 0.008)
	# One well, as big as the face can hold and never smaller than the floor.
	var well := clampf(minf(pw, ph) * 0.42, PX * floor_px, maxf(PX * floor_px, minf(pw, ph) - PX * 1.6))
	recess(k, pc + uu * ph * 0.14 - rr * pw * 0.14 * side, nn, uu, well, well, r, 0.012, floor_px)
	grime(k, pc - uu * (ph * 0.5) + rr * (pw * 0.2 * side), nn, pw * 0.6, h * 0.5, 2, seed_value + 5, r)


## A tag of FOUND stock hung on a wire from `at`: seals, records, plates cut
## off other machines. `turn` swings the plate about the wire.
static func tag(k: MeshKit, at: Vector3, drop: float, w: float, h: float, r: Array, turn: float = 0.0) -> void:
	tbar(k, at, at + Vector3.DOWN * drop, 0.006, 0.006, 3, flat(Palette.INK[2]))
	k.push(Transform3D(Basis(Vector3.UP, turn), at + Vector3.DOWN * (drop + h * 0.5)))
	cbox(k, Vector3.ZERO, Vector3(0.014, h, w), 0.0, r)
	k.pop()


# -- matter the machines carry: the land's and the dead's, drawn by the hand ----

## A long bone from a to b, knuckled at both ends.
static func bone(k: MeshKit, a: Vector3, b: Vector3, rad: float, seed_value: int) -> void:
	k.strut(a, b, rad, 4, Palette.LINEN[4])
	for i in 2:
		var p := a if i == 0 else b
		k.rock(p.x, p.y - rad * 1.6, p.z, rad * 2.2, rad * 3.2, seed_value + i, Palette.LINEN[5], 4)


## A rib or a jaw: a bow of thin bone through `count` joints from `a` bulging
## toward `bulge`.
static func rib(k: MeshKit, a: Vector3, b: Vector3, bulge: Vector3, rad: float) -> void:
	var prev := a
	for i in range(1, 4):
		var t := i / 3.0
		var p := a.lerp(b, t) + bulge * 4.0 * t * (1.0 - t)
		k.strut(prev, p, rad * (1.0 - t * 0.4), 3, Palette.LINEN[4])
		prev = p


## A torn strip of cloth hanging from `at`, kinked by seed, visible from both sides.
static func rag(k: MeshKit, at: Vector3, drop: float, w: float, col: Color, seed_value: int, across: Vector3 = Vector3.BACK) -> void:
	var side := across.normalized()
	var pts: Array[Vector3] = []
	var widths := [w, w * 0.85, w * 0.45]
	for i in 3:
		var t := i / 2.0
		var j := Vector3((Rng.hash01(seed_value, i) - 0.5) * 0.08, 0.0, (Rng.hash01(seed_value, i, 1) - 0.5) * 0.04) * t
		pts.append(at + Vector3.DOWN * drop * t + j)
	for i in 2:
		var a0: Vector3 = pts[i] - side * float(widths[i]) * 0.5
		var a1: Vector3 = pts[i] + side * float(widths[i]) * 0.5
		var b0: Vector3 = pts[i + 1] - side * float(widths[i + 1]) * 0.5
		var b1: Vector3 = pts[i + 1] + side * float(widths[i + 1]) * 0.5
		var c2 := col if i == 0 else col.darkened(0.12)
		k.quad(a0, a1, b1, b0, c2)
		k.quad(a0, b0, b1, a1, c2)


## Chaff jammed into something: `count` stalks scattered in a box of half-size
## `spread` round `c`, in field colours, `reach` to twice that long, `thick`
## across (a wad that must read from the game's camera wants 0.04 or more).
static func chaff(k: MeshKit, c: Vector3, spread: Vector3, count: int, seed_value: int, cols: Array, reach: float = 0.1, thick: float = 0.024) -> void:
	for j in count:
		var p := c + Vector3((Rng.hash01(seed_value, j, 0) - 0.5) * 2.0 * spread.x, (Rng.hash01(seed_value, j, 1) - 0.5) * 2.0 * spread.y, (Rng.hash01(seed_value, j, 2) - 0.5) * 2.0 * spread.z)
		var a := Rng.hash01(seed_value, j, 3) * TAU
		var tip := p + Vector3(cos(a), (Rng.hash01(seed_value, j, 4) - 0.3) * 0.8, sin(a)).normalized() * (reach + Rng.hash01(seed_value, j, 5) * reach * 1.4)
		bar(k, p, tip, thick, thick * 0.84, 0.0, flat(cols[j % cols.size()]))

