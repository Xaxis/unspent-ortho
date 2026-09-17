class_name Broken
## A thing the taking has worked DOWN (owner, 2026-09-17; docs/DESIGN.md §Taking,
## as it is seen). A boulder half quarried is not a smaller boulder: it is the same
## boulder with a piece off it, standing as wide as it ever did, with a fresh
## unweathered face where the hammer went. This is the geometry of that, over any
## model at all: the mesh is cut at the height what is left reaches, everything
## above goes, and the cut is capped.
##
##   Broken.work_down(kit, share, seed)     cut a built MeshKit down to `share` left
##   Broken.bucket(share) / share_of(b)     the five steps a worked thing is drawn in
##
## Five steps, not a continuum, because every step is a template the world view
## bakes and caches: a rock worked three times is drawn three times, not once a
## frame. `PropModels.template` keys on the bucket.
##
## It replaces the interim shrink (`Harvest.apply_shown` scaled the prop, which
## drew a seam with a third left as a pebble). What did not change is the rule:
## `Harvest.shown` is still how much of the thing is left, and this only draws it.

## How many steps a worked thing is drawn in, whole included.
const BUCKETS := 5
## Nothing is cut below this share of its own height: a stump of a boulder is still
## a boulder, and the last take is what takes it away.
const LEAST := 0.22
## Points this close together are the same point when the cut's rim is walked.
const WELD := 0.004
## How far the work's rim stands above the bottom of what it opened, as a share of
## the whole thing's height. A flat cut reads as a machined table top, so the
## surface the work leaves is a shallow BOWL: a lip of the old weathered crust all
## round the outside, opened deepest in the middle, where the tool went.
const LIP := 0.15


## The step `share` (0..1 left) is drawn in: BUCKETS - 1 is whole.
static func bucket(share: float) -> int:
	return clampi(ceili(clampf(share, 0.0, 1.0) * float(BUCKETS)) - 1, 0, BUCKETS - 1)


## The share a step is drawn at.
static func share_of(b: int) -> float:
	return float(clampi(b, 0, BUCKETS - 1) + 1) / float(BUCKETS)


## How far up its own height a thing with `share` left still reaches. Ground under
## a rounded thing is wider than its top, so taking half its bulk takes more than
## half its height.
static func height_for(share: float) -> float:
	return clampf(pow(clampf(share, 0.0, 1.0), 0.8), LEAST, 1.0)


## Cut `kit` down to what `share` leaves. Everything above the cut goes; triangles
## across it are clipped; the rim left is capped with a face in the thing's own
## colour, lightened, because what the hammer opens has not been weathered.
static func work_down(kit: MeshKit, share: float, seed_value: int = 0) -> void:
	if kit == null or share >= 1.0 or kit.verts.size() < 3:
		return
	var lo := INF
	var hi := -INF
	for v: Vector3 in kit.verts:
		lo = minf(lo, v.y)
		hi = maxf(hi, v.y)
	if hi <= lo:
		return
	# The middle of the cut, low enough that the bowl takes as much as a flat cut
	# at `height_for` would have.
	var rise := (hi - lo) * LIP
	var cut := lo + (hi - lo) * height_for(share) - rise * 0.45
	var mid := Vector2.ZERO
	for v: Vector3 in kit.verts:
		mid += Vector2(v.x, v.z)
	mid /= float(kit.verts.size())
	var radius := 0.0
	for v: Vector3 in kit.verts:
		radius = maxf(radius, (Vector2(v.x, v.z) - mid).length())
	# The height of the cut under every vertex, worked out once: the classing, the
	# clipping and the cap all have to agree about where the surface is.
	var at := PackedFloat32Array()
	at.resize(kit.verts.size())
	for i in kit.verts.size():
		at[i] = _cut_at(kit.verts[i], mid, radius, cut, rise, seed_value)
	var keep := _Buffers.new()
	# Every piece of rim the work leaves, as pairs of points on that surface.
	var rim: Array[Vector3] = []
	var opened := false
	for t in range(0, kit.verts.size() - 2, 3):
		var under := 0
		for i in 3:
			if kit.verts[t + i].y <= at[t + i]:
				under += 1
		if under == 3:
			for i in 3:
				keep.take(kit, t + i)
			continue
		if under == 0:
			continue
		# A triangle the work runs through: keep the part under it, in the order it
		# was wound, and remember the edge it left.
		opened = true
		var poly: Array = []
		var edge: Array[Vector3] = []
		for i in 3:
			var a := t + i
			var b := t + (i + 1) % 3
			var a_in := kit.verts[a].y <= at[a]
			var b_in := kit.verts[b].y <= at[b]
			if a_in:
				poly.append([a, -1, 0.0])
			if a_in != b_in:
				# The edge and the surface both run straight along the edge, so one
				# division still says where they meet.
				var slope := (kit.verts[b].y - kit.verts[a].y) - (at[b] - at[a])
				var f := 0.5
				if absf(slope) > 1e-6:
					f = clampf((at[a] - kit.verts[a].y) / slope, 0.0, 1.0)
				poly.append([a, b, f])
				edge.append(kit.verts[a].lerp(kit.verts[b], f))
		if edge.size() == 2:
			rim.append(edge[0])
			rim.append(edge[1])
		for i in range(1, poly.size() - 1):
			for j: Array in [poly[0], poly[i], poly[i + 1]]:
				keep.take(kit, int(j[0]), int(j[1]), float(j[2]))
	if opened:
		_cap(keep, kit, rim, cut, _fresh_of(keep), seed_value)
	keep.into(kit)


## What the opened face is drawn in: the colour of what is LEFT, lightened. The
## weathered crust is what the work took off, so a face that inherited the colour
## of the triangles it cut through came out the green-grey of the lichen it broke
## rather than the stone under it. Marked colours (a window, a tube of neon) are
## left out: their alpha is a code, not a colour, and nothing is inside a lamp.
static func _fresh_of(keep: _Buffers) -> Color:
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for c: Color in keep.colors:
		var code := roundi(c.a * 255.0)
		if code != 0 and code != 255:
			continue
		sum += c
		n += 1
	# Not lightened. The face is the thing's OWN colour and the whole of what
	# tells it apart is that no wear has settled on it (GroundColors.FRESH): on
	# the salt, where the wear blooms white, lightening it as well made a boulder
	# read as a slab of ice, and on every land it made the face glow.
	var fresh := sum / float(maxi(n, 1)) if n > 0 else Color(0.62, 0.60, 0.57)
	# The alpha is the mark the shader reads: nothing has settled on a face opened
	# a moment ago, whatever bog it stands in (GroundColors.FRESH).
	fresh.a = float(GroundColors.FRESH) / 255.0
	return fresh


## The face the work left: the rim walked into loops and each loop filled from its
## own middle, so a thing with two stacks on it is opened twice and never bridged.
## The middle sits below the rim it is fanned to, so the face is a hollow light
## falls across and not a plate.
static func _cap(keep: _Buffers, kit: MeshKit, rim: Array[Vector3], cut: float, fresh: Color, seed_value: int) -> void:
	for loop: PackedVector3Array in loops(rim):
		if loop.size() < 3:
			continue
		var middle := Vector3.ZERO
		for p: Vector3 in loop:
			middle += p
		middle /= float(loop.size())
		var across := 0.0
		for p: Vector3 in loop:
			across = maxf(across, (Vector2(p.x, p.z) - Vector2(middle.x, middle.z)).length())
		# Off centre, because nobody hits a rock in the middle: a hollow fanned from
		# the exact centre of its own rim is a pinwheel, and a pinwheel is a pattern.
		var lean := Rng.hash01(seed_value, loop.size(), 29) * TAU
		middle += Vector3(cos(lean), 0.0, sin(lean)) * across * 0.22
		middle.y = cut - across * 0.16 * (0.8 + 0.4 * Rng.hash01(seed_value, loop.size(), 31))
		# A ring part of the way in, each point at its own depth, so the hollow is
		# a handful of facets the light breaks across. A single fan from the middle
		# is one smooth cone, and a cone under one sun is a plate.
		var inner := PackedVector3Array()
		var ph := Rng.hash01(seed_value, loop.size(), 0x1f) * TAU
		for i in loop.size():
			var q := middle.lerp(loop[i], 0.45)
			# The depth runs in waves round the ring, never point by point: a rim of
			# forty points each dipped on its own is forty near-vertical slivers,
			# which is a spiky mess and not a broken face.
			var ang := atan2(loop[i].z - middle.z, loop[i].x - middle.x)
			q.y += across * 0.09 * (sin(ang * 4.0 + ph) + 0.6 * sin(ang * 7.0 - ph))
			inner.append(q)
		for i in loop.size():
			var j := (i + 1) % loop.size()
			keep.face(inner[i], loop[i], loop[j], fresh, kit)
			keep.face(inner[i], loop[j], inner[j], fresh, kit)
			keep.face(middle, inner[i], inner[j], fresh, kit)


## The height of the surface the work leaves under `p`: `cut` in the middle,
## rising to a lip at the outside, and never a circle — three slow waves round the
## rim, phased off the thing's own seed, so no two are opened the same way.
static func _cut_at(p: Vector3, mid: Vector2, radius: float, cut: float, rise: float, seed_value: int) -> float:
	var d := Vector2(p.x, p.z) - mid
	var r := clampf(d.length() / maxf(radius, 0.001), 0.0, 1.0)
	var ang := atan2(d.y, d.x)
	var wob := 0.72 + 0.20 * sin(ang * 3.0 + Rng.hash01(seed_value, 7, 0x8a) * TAU) \
		+ 0.14 * sin(ang * 5.0 + Rng.hash01(seed_value, 8, 0x8a) * TAU)
	return cut + rise * r * r * wob


## The rim's segments walked into closed loops, each a ring of points.
static func loops(rim: Array[Vector3]) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	var points: Array[Vector3] = []
	var links: Array[PackedInt32Array] = []
	var index := {}
	for p: Vector3 in rim:
		var key := "%d,%d" % [roundi(p.x / WELD), roundi(p.z / WELD)]
		if not index.has(key):
			index[key] = points.size()
			points.append(p)
			links.append(PackedInt32Array())
	for i in range(0, rim.size() - 1, 2):
		var a: int = index["%d,%d" % [roundi(rim[i].x / WELD), roundi(rim[i].z / WELD)]]
		var b: int = index["%d,%d" % [roundi(rim[i + 1].x / WELD), roundi(rim[i + 1].z / WELD)]]
		if a == b:
			continue
		if not (links[a] as PackedInt32Array).has(b):
			links[a].append(b)
		if not (links[b] as PackedInt32Array).has(a):
			links[b].append(a)
	var seen := {}
	for start in points.size():
		if seen.has(start) or (links[start] as PackedInt32Array).is_empty():
			continue
		var loop := PackedVector3Array()
		var at := start
		var from := -1
		while not seen.has(at):
			seen[at] = true
			loop.append(points[at])
			var next := -1
			for n: int in links[at]:
				if n != from and not seen.has(n):
					next = n
					break
			if next < 0:
				break
			from = at
			at = next
		if loop.size() >= 3:
			out.append(loop)
	return out


## The arrays of a mesh being rebuilt one vertex at a time, keeping every channel
## a vertex carried (the ink styles, the sway, the ecotone wash) rather than
## rebuilding them from a MeshKit's current state, which the cut knows nothing about.
class _Buffers:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var custom0 := PackedFloat32Array()

	## Vertex `a` of `kit`, or the point `f` of the way from `a` to `b`.
	func take(kit: MeshKit, a: int, b: int = -1, f: float = 0.0) -> void:
		verts.append(kit.verts[a] if b < 0 else kit.verts[a].lerp(kit.verts[b], f))
		normals.append(kit.normals[a] if b < 0 else kit.normals[a].lerp(kit.normals[b], f).normalized())
		colors.append(kit.colors[a] if b < 0 else kit.colors[a].lerp(kit.colors[b], f))
		uvs.append(kit.uvs[a])
		uv2s.append(kit.uv2s[a] if b < 0 else kit.uv2s[a].lerp(kit.uv2s[b], f))
		for c in 4:
			custom0.append(kit.custom0[a * 4 + c])

	## One face of the cap, wound so that it faces up whichever way its rim runs.
	func face(a: Vector3, b: Vector3, c: Vector3, col: Color, kit: MeshKit) -> void:
		# MeshKit stores a triangle as (a, c, b) and lights it by (c - b) x (a - b);
		# the same rule decides the way round these three go.
		var n := (c - b).cross(a - b)
		var ring: Array[Vector3] = [a, c, b]
		if n.y < 0.0:
			ring = [a, b, c]
			n = -n
		# Its own normal, not a flat UP: the hollow only reads as one if the light
		# falls differently on the side of it nearest the sun.
		var up := n.normalized() if n.length() > 1e-9 else Vector3.UP
		for p: Vector3 in ring:
			verts.append(p)
			normals.append(up)
			colors.append(col)
			uvs.append(kit.uvs[0] if kit.uvs.size() > 0 else Vector2.ZERO)
			uv2s.append(Vector2.ZERO)
			for i in 4:
				custom0.append(kit.custom0[i] if kit.custom0.size() >= 4 else 0.0)

	func into(kit: MeshKit) -> void:
		kit.verts = verts
		kit.normals = normals
		kit.colors = colors
		kit.uvs = uvs
		kit.uv2s = uv2s
		kit.custom0 = custom0
