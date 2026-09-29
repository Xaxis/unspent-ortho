class_name Burnt
## A HOUSE THE HUNTERS BURNED (Vera: "We break their works. They burn a village";
## 48_raids, Reprisal). Drawn from the house it was, in its own landscape's form,
## so a burned village still reads as that village. It has to read at eye level,
## over the shoulder, and not only from above: from there a shell cut flat and
## blacked is a dark box with a window in it. So:
##
##  - the walls stand to a RAGGED line, high at one corner and down to the sill
##    at the next, and a few charred rafters still reach up off them into the sky
##    where the roof was;
##  - soot licks up the wall from every window head, where the fire came out;
##  - one stove pipe stands alone above it all;
##  - the ground round it is scorched, the floor inside is charcoal;
##  - nothing on it is lit: every window, lamp and wired neon the house had is out.
##
## Only a colour's RGB is charred and its material mark kept; a LIGHT mark (made
## codes 1..35, found alpha under 0.5) is put out instead of kept (kit.gd).

const Kit := preload("res://src/models/props/kit.gd")

## Above this share of the house's height, whatever faces the sky (a roof's
## pitch, a floor, a sill) burned and fell. A height cut alone keeps a tall
## form's whole roof.
const ROOF_FROM := 0.3
## Walls stand to between these shares of the house's height, by a ragged line
## dealt cell by cell along them (CELL units): a flat cut reads as a box.
const WALL_LOW := 0.28
const WALL_RISE := 0.42
const CELL := 0.7
## A face is a wall when its normal is this near level.
const WALL := 0.35
## Beams that fell in, lying from a wall's top to the floor, and rafters still
## reaching up off the walls: the broken line of the roof against the sky.
const BEAMS := 3
const RAFTERS := 2
## What a fire takes whole: made marks of the soft stuff (GroundColors).
static var SOFT: Array[int] = [GroundColors.THATCH, GroundColors.CLOTH, GroundColors.ROPE]
## Wall triangles are split to this edge (units) before the wall line cuts them:
## a form whose wall is one great triangle would otherwise stand whole or go.
const SPLIT := 0.22
## How far over the ground the charcoal floor lies, and how far over it a
## ruled piece has to reach to be seen above the ash (`_found_pieces`).
const ASH_TOP := 0.07
const BURIED := 0.07
## Outside the walls, what is left stands no higher than this share.
const OUTSIDE_TO := 0.2
## How far up the wall the soot licks from a window head.
const TONGUE := 0.75
## Soot is the pen's own darkest ink and never under it (tests/render/
## test_dark_floor): a char darker than the ink floor is a hole, not a wall.
static var SOOT: Color = Palette.INK[0]
## Iron that has been through a fire: a stove pipe.
const IRON := Color(0.2, 0.16, 0.14, 1.0)


static func burn(k: Kit, seed_value: int) -> void:
	var m := k.made
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for v: Vector3 in m.verts:
		lo = lo.min(v)
		hi = hi.max(v)
	if not lo.is_finite():
		return
	var base := lo.y
	var span := maxf(hi.y - lo.y, 0.001)
	# The footprint is the house walls', not the whole kit's: a yard's stones and
	# fences lie outside the rooms the floor belongs to, and stand lower.
	var tall := base + span * ROOF_FROM
	var fa := Vector2(INF, INF)
	var fb := Vector2(-INF, -INF)
	for t in range(0, m.verts.size() - 2, 3):
		var a := m.verts[t]
		var b := m.verts[t + 1]
		var c := m.verts[t + 2]
		if _is_wall(a, b, c) and maxf(a.y, maxf(b.y, c.y)) > tall:
			for v: Vector3 in [a, b, c]:
				fa = fa.min(Vector2(v.x, v.z))
				fb = fb.max(Vector2(v.x, v.z))
	var windows := _windows(m)
	# Only the made pen's walls are torn fine: a ruled sheet split small leaves
	# slivers behind the made wall in front of it that nothing ever sees
	# (tests/render/test_found_drawn); whole, it stands or goes as one.
	_split_walls(m, SPLIT)
	# The footprint's walls, and a hair round them for their own thickness.
	var inside := Rect2(fa - Vector2(0.12, 0.12), fb - fa + Vector2(0.24, 0.24)) if fa.is_finite() else Rect2()
	_char(m, seed_value, base, span, false, inside)
	_char(k.found, seed_value, base, span, true, inside)
	# Thatch, turf and the green on a roof burn first and leave nothing.
	k.leaf = MeshKit.new()
	if not fa.is_finite():
		return
	var floor_y := maxf(base, 0.0)
	_scorch(m, seed_value, (fa + fb) * 0.5, (fb - fa) * 0.5, floor_y + 0.03)
	# The floor inside is its boards burned to charcoal.
	var ash := GroundColors.made(SOOT, GroundColors.TIMBER)
	var a := Vector3(lerpf(fa.x, fb.x, 0.04), floor_y + ASH_TOP, lerpf(fa.y, fb.y, 0.04))
	var b := Vector3(lerpf(fa.x, fb.x, 0.96), a.y, lerpf(fa.y, fb.y, 0.96))
	m.quad(a, Vector3(a.x, a.y, b.z), b, Vector3(b.x, a.y, a.z), ash)
	for w: Dictionary in windows:
		_tongue(m, w, _cut_at(seed_value, base, span, w.top as Vector3))
	var beam := GroundColors.made(SOOT.lightened(0.1), GroundColors.TIMBER)
	for i in BEAMS:
		var u := Rng.hash01(seed_value, i, 0xB6)
		var side := Rng.hash01(seed_value, i, 0xB7) < 0.5
		var on := Vector3(lerpf(a.x, b.x, u), 0.0, a.z if side else b.z)
		on.y = _cut_at(seed_value, base, span, on) - 0.05
		var to := Vector3(lerpf(a.x, b.x, Rng.hash01(seed_value, i, 0xB8)), a.y + 0.08, lerpf(a.z, b.z, 0.5))
		m.strut(on, to, 0.06, 4, beam)
	# Rafters still pitched off the wall tops, broken short against the sky.
	var mid := Vector3((fa.x + fb.x) * 0.5, 0.0, (fa.y + fb.y) * 0.5)
	for i in RAFTERS:
		var u := 0.15 + 0.7 * Rng.hash01(seed_value, i, 0xB9)
		var side := Rng.hash01(seed_value, i, 0xBA) < 0.5
		var foot := Vector3(lerpf(a.x, b.x, u), 0.0, a.z if side else b.z)
		foot.y = _cut_at(seed_value, base, span, foot)
		var toward := Vector3(foot.x, 0.0, mid.z) - Vector3(foot.x, 0.0, foot.z)
		# Short, at the roof's own pitch: what is left of a rafter, not a spar.
		var reach := (0.3 + 0.3 * Rng.hash01(seed_value, i, 0xBB)) * maxf(toward.length(), 0.4)
		var tip := foot + toward.normalized() * reach * 0.8 + Vector3.UP * reach * 0.6
		m.strut(foot, tip, 0.05, 4, beam)
	# One stove pipe, left standing where the stove was, above everything.
	var at := Vector3(lerpf(a.x, b.x, 0.3 + 0.4 * Rng.hash01(seed_value, 0xBC, 1)), floor_y,
		lerpf(a.z, b.z, 0.25 + 0.5 * Rng.hash01(seed_value, 0xBC, 2)))
	var lean := Vector3(Rng.hash01(seed_value, 0xBD, 1) - 0.5, 0.0, Rng.hash01(seed_value, 0xBD, 2) - 0.5) * 0.16
	var head := at + Vector3.UP * span * 0.82 + lean
	k.found.strut(at, head, 0.065, 6, IRON)
	k.found.strut(head, head + Vector3(0.18, 0.1, 0.0).rotated(Vector3.UP, TAU * Rng.hash01(seed_value, 0xBE, 1)), 0.06, 6, IRON)


## How high the wall stands at `p`: a ragged line, dealt at the corners of
## CELL squares and eased between them, so what hung off a wall (a hook, a
## lamp bracket) is cut where the wall beside it was, not by a cell of its own.
static func _cut_at(seed_value: int, base: float, span: float, p: Vector3) -> float:
	var gx := p.x / CELL
	var gz := p.z / CELL
	var ix := floori(gx)
	var iz := floori(gz)
	var fx := smoothstep(0.0, 1.0, gx - float(ix))
	var fz := smoothstep(0.0, 1.0, gz - float(iz))
	var h := lerpf(
		lerpf(Rng.hash01(seed_value, ix, iz, 0xB5), Rng.hash01(seed_value, ix + 1, iz, 0xB5), fx),
		lerpf(Rng.hash01(seed_value, ix, iz + 1, 0xB5), Rng.hash01(seed_value, ix + 1, iz + 1, 0xB5), fx), fz)
	return base + span * (WALL_LOW + WALL_RISE * h * h)


## A made colour carrying a light mark: a lit window, a lamp, a glow, a neon.
static func _lit(c: Color) -> bool:
	var code := roundi(c.a * 255.0)
	return code >= 1 and code <= GroundColors.FAILING


## The windows of the house as it stood, from its lit glass: each one's head
## (the middle of its top edge), its half width along the wall and the way the
## wall faces.
static func _windows(m: MeshKit) -> Array[Dictionary]:
	var groups := {}
	for t in range(0, m.verts.size() - 2, 3):
		if not _lit(m.colors[t]) or not _is_wall(m.verts[t], m.verts[t + 1], m.verts[t + 2]):
			continue
		var cen := (m.verts[t] + m.verts[t + 1] + m.verts[t + 2]) / 3.0
		var key := Vector3i(roundi(cen.x * 2.0), roundi(cen.y * 2.0), roundi(cen.z * 2.0))
		var g: Dictionary = groups.get(key, {"lo": Vector3(INF, INF, INF), "hi": -Vector3(INF, INF, INF), "n": m.normals[t]})
		for j in 3:
			g.lo = (g.lo as Vector3).min(m.verts[t + j])
			g.hi = (g.hi as Vector3).max(m.verts[t + j])
		groups[key] = g
	var out: Array[Dictionary] = []
	for key: Vector3i in groups:
		var g: Dictionary = groups[key]
		var lo: Vector3 = g.lo
		var hi: Vector3 = g.hi
		var n: Vector3 = g.n
		n.y = 0.0
		if n.length() < 0.01:
			continue
		var half := Vector2(hi.x - lo.x, hi.z - lo.z).length() * 0.5
		out.append({"top": Vector3((lo.x + hi.x) * 0.5, hi.y, (lo.z + hi.z) * 0.5), "half": maxf(half, 0.12), "n": n.normalized()})
	return out


## Soot licked up the wall from a window head, as far as the wall still stands.
static func _tongue(m: MeshKit, w: Dictionary, wall_top: float) -> void:
	var top: Vector3 = w.top
	var n: Vector3 = w.n
	var along := Vector3(-n.z, 0.0, n.x)
	var half: float = w.half * 1.15
	var rise := minf(TONGUE, wall_top - top.y - 0.03)
	if rise < 0.12:
		return
	var foot := top + n * 0.035
	var soot := GroundColors.made(SOOT, GroundColors.CLAY)
	var bl := foot - along * half
	var br := foot + along * half
	var apex := foot + Vector3.UP * rise + along * half * 0.2
	# Both faces, since which way the house's wall winds is the form's own.
	m.tri(bl, br, apex, soot)
	m.tri(br, bl, apex, soot)
	# And a second, lower lick beside it, so it reads as flame and not a sign.
	var apex2 := foot + Vector3.UP * rise * 0.6 - along * half * 0.55
	m.tri(bl, foot, apex2, soot)
	m.tri(foot, bl, apex2, soot)


## The ground round a burned house, scorched out past its walls in a ragged ring.
static func _scorch(m: MeshKit, seed_value: int, centre: Vector2, half: Vector2, y: float) -> void:
	var n := 18
	var c := Vector3(centre.x, y, centre.y)
	var burnt := GroundColors.made(Color(0.13, 0.1, 0.085), GroundColors.CLAY)
	var pts: Array[Vector3] = []
	for i in n:
		var ang := -TAU * float(i) / float(n)
		# An ellipse over the footprint, torn at its edge.
		var k := 0.8 + 0.4 * Rng.hash01(seed_value, i, 0xBF)
		pts.append(c + Vector3(cos(ang) * (half.x + 0.9) * k, 0.0, sin(ang) * (half.y + 0.9) * k))
	for i in n:
		m.tri(c, pts[i], pts[(i + 1) % n], burnt)


## `found`: the ruled pen, whose alpha under 0.5 is a beacon (kit.gd) rather than
## the made pen's mark codes.
## `inside`: the walls' footprint; out past it (an eave's hooks, a gutter, a
## fence) nothing stands above OUTSIDE_TO of the house's height, since what it
## hung from or leaned on is gone.
static func _char(kit: MeshKit, seed_value: int, base: float, span: float, found: bool, inside: Rect2) -> void:
	var n := kit.verts.size()
	if n < 3:
		return
	var per_vertex_custom := kit.custom0.size() == n * 4
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var custom := PackedFloat32Array()
	# The ruled pen's fittings are whole pieces (a bracket, a mast, a plate): each
	# stands whole or goes whole, since one cut part-way leaves a stub that hangs
	# in the air or hides behind the wall's stump where nothing ever sees it
	# (tests/render/test_found_drawn).
	var whole := _found_pieces(kit, seed_value, base, span, inside) if found else PackedByteArray()
	for t in range(0, n - 2, 3):
		if found:
			if whole[t / 3] == 0:
				continue
		elif not _stands(kit, t, seed_value, base, span, inside):
			continue
		for j in 3:
			var i := t + j
			var v := kit.verts[i]
			var up := clampf((v.y - base) / span, 0.0, 1.0)
			var c := kit.colors[i]
			var burnt: Color
			if found and c.a < 0.5:
				# A beacon or a wired lamp on the machine's own power: dead.
				burnt = Color(c.r * 0.3, c.g * 0.28, c.b * 0.26, 1.0)
			elif not found and _lit(c):
				# A window, a lamp, a tube: out, and black where it was.
				burnt = GroundColors.made(SOOT, GroundColors.TIMBER)
			else:
				# Soot climbs: the foot of a wall keeps a trace of its stone or timber.
				# Scorched, not painted black: the lower wall still reads as what it was.
				burnt = Color(c.r * 0.62, c.g * 0.56, c.b * 0.5).lerp(SOOT, 0.12 + 0.88 * pow(up / 0.7, 1.6) if up < 0.7 else 1.0)
				burnt.a = c.a
			# Never under the pen, channel by channel, whatever the wall was.
			burnt = Color(maxf(burnt.r, SOOT.r), maxf(burnt.g, SOOT.g), maxf(burnt.b, SOOT.b), burnt.a)
			verts.append(v)
			normals.append(kit.normals[i])
			colors.append(burnt)
			uvs.append(kit.uvs[i])
			uv2s.append(kit.uv2s[i])
			if per_vertex_custom:
				for q in 4:
					custom.append(kit.custom0[i * 4 + q])
	kit.verts = verts
	kit.normals = normals
	kit.colors = colors
	kit.uvs = uvs
	kit.uv2s = uv2s
	if per_vertex_custom:
		kit.custom0 = custom


## Whether triangle `t` still stands after the fire, by where it is.
static func _stands(kit: MeshKit, t: int, seed_value: int, base: float, span: float, inside: Rect2) -> bool:
	var cen := (kit.verts[t] + kit.verts[t + 1] + kit.verts[t + 2]) / 3.0
	# Thatch, cloth and rope burn first and leave nothing, wherever they hung.
	if SOFT.has(roundi(kit.colors[t].a * 255.0)):
		return false
	# Nothing stands above the wall line where it is (a hook off an eave that
	# fell hangs in the air), and nothing that faced the sky above the roof.
	if cen.y > _cut_at(seed_value, base, span, cen):
		return false
	if cen.y > base + span * ROOF_FROM and not _is_wall(kit.verts[t], kit.verts[t + 1], kit.verts[t + 2]):
		return false
	if inside.has_area() and not inside.has_point(Vector2(cen.x, cen.z)) and cen.y > base + span * OUTSIDE_TO:
		return false
	return true


## Per triangle, 1 where its connected piece of the ruled pen stands whole: none
## of it above the roof or the wall line, and some of it above the charcoal.
static func _found_pieces(kit: MeshKit, seed_value: int, base: float, span: float, inside: Rect2) -> PackedByteArray:
	var tris := kit.verts.size() / 3
	var parent := PackedInt32Array()
	parent.resize(tris)
	for i in tris:
		parent[i] = i
	var first := {}
	for t in tris:
		for j in 3:
			var v := kit.verts[t * 3 + j]
			var key := Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))
			if first.has(key):
				var a := _root(parent, t)
				var b := _root(parent, int(first[key]))
				if a != b:
					parent[a] = b
			else:
				first[key] = t
	var fails := {}
	var top := {}
	var roof := base + span * ROOF_FROM
	for t in tris:
		var r := _root(parent, t)
		var hi := maxf(kit.verts[t * 3].y, maxf(kit.verts[t * 3 + 1].y, kit.verts[t * 3 + 2].y))
		top[r] = maxf(float(top.get(r, -INF)), hi)
		var cen := (kit.verts[t * 3] + kit.verts[t * 3 + 1] + kit.verts[t * 3 + 2]) / 3.0
		if cen.y > roof or not _stands(kit, t * 3, seed_value, base, span, inside):
			fails[r] = true
	var ash := maxf(base, 0.0) + ASH_TOP + BURIED
	var out := PackedByteArray()
	out.resize(tris)
	for t in tris:
		var r := _root(parent, t)
		out[t] = 0 if fails.has(r) or float(top[r]) < ash else 1
	return out


static func _root(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


## Split every upright triangle with an edge longer than `edge` into four, over
## and over, carrying each vertex's attributes across, so the ragged wall line
## has pieces small enough to tear along.
static func _split_walls(kit: MeshKit, edge: float) -> void:
	var n := kit.verts.size()
	if n < 3:
		return
	var custom := kit.custom0.size() == n * 4
	var out := MeshKit.new()
	var e2 := edge * edge
	var stack: Array[Array] = []
	for t in range(0, n - 2, 3):
		var tri: Array = []
		for j in 3:
			tri.append(_vertex(kit, t + j, custom))
		if not _is_wall(kit.verts[t], kit.verts[t + 1], kit.verts[t + 2]):
			_put(out, tri, custom)
			continue
		stack.append(tri)
		while not stack.is_empty():
			var cur: Array = stack.pop_back()
			var a: Dictionary = cur[0]
			var b: Dictionary = cur[1]
			var c: Dictionary = cur[2]
			var pa: Vector3 = a.v
			var pb: Vector3 = b.v
			var pc: Vector3 = c.v
			if pa.distance_squared_to(pb) <= e2 and pb.distance_squared_to(pc) <= e2 and pc.distance_squared_to(pa) <= e2:
				_put(out, cur, custom)
				continue
			var ab := _mid(a, b)
			var bc := _mid(b, c)
			var ca := _mid(c, a)
			stack.append([a, ab, ca])
			stack.append([ab, b, bc])
			stack.append([ca, bc, c])
			stack.append([ab, bc, ca])
	kit.verts = out.verts
	kit.normals = out.normals
	kit.colors = out.colors
	kit.uvs = out.uvs
	kit.uv2s = out.uv2s
	if custom:
		kit.custom0 = out.custom0


static func _vertex(kit: MeshKit, i: int, custom: bool) -> Dictionary:
	var d := {"v": kit.verts[i], "n": kit.normals[i], "c": kit.colors[i], "uv": kit.uvs[i], "uv2": kit.uv2s[i]}
	if custom:
		d["x"] = Color(kit.custom0[i * 4], kit.custom0[i * 4 + 1], kit.custom0[i * 4 + 2], kit.custom0[i * 4 + 3])
	return d


## Halfway between two vertices; a colour's mark (alpha) is the first's, never
## blended, since a mark between two codes is a third thing.
static func _mid(a: Dictionary, b: Dictionary) -> Dictionary:
	var ca: Color = a.c
	var cb: Color = b.c
	var c := ca.lerp(cb, 0.5)
	c.a = ca.a
	var d := {"v": (a.v as Vector3).lerp(b.v, 0.5), "n": ((a.n as Vector3) + (b.n as Vector3)).normalized(), "c": c,
		"uv": a.uv, "uv2": a.uv2}
	if a.has("x"):
		d["x"] = a.x
	return d


static func _put(out: MeshKit, tri: Array, custom: bool) -> void:
	for d: Dictionary in tri:
		out.verts.append(d.v)
		out.normals.append(d.n)
		out.colors.append(d.c)
		out.uvs.append(d.uv)
		out.uv2s.append(d.uv2)
		if custom:
			var x: Color = d.x
			out.custom0.append_array(PackedFloat32Array([x.r, x.g, x.b, x.a]))


## A face that stands upright: a wall, a chimney's side, a post.
static func _is_wall(a: Vector3, b: Vector3, c: Vector3) -> bool:
	var face := (b - a).cross(c - a)
	return face.length() > 0.000001 and absf(face.normalized().y) < WALL
