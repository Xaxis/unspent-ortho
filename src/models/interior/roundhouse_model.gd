extends Node3D
## A CRAGS ROUNDHOUSE, drawn from inside (docs/interiors; the recipe that says
## where everything stands is src/content/interiors/roundhouse.gd). Dry stone laid
## by hand in courses, the wall and its piers; a cone of thatch on driftwood
## rafters, black with a hundred winters of peat smoke; a floor of beaten earth
## strewn with rushes and a path of flags to the fire. Nothing wired in: this is
## the one landscape with no stolen light, and the only made thing of the
## machines' in the room is the survey post the crane hangs from.
##
## It answers the calls every room's model does (21_doors reads them): `build`,
## `show_for`, `windows` (none), `daylight` (the sky down the smoke hole and out
## through the door), and `lights`: the day down the smoke hole. The fire is the
## pocket's own FIRE prop, and lights itself.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const DIRS: Array[Vector2] = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
## Floors stand proud of the pocket's terrain (weapons_hall_model).
const DECK_TOP := 0.035
## A course of the wall.
const CH := 0.22
## How deep the wall is, and a pier across.
const DEEP := 0.5
const PIER_W := 0.46
## How far the roof's cone rises over the wall head, and its smoke hole.
const RISE := 2.3
const HOLE := 0.34

var layout: InteriorLayout
var kind: InteriorKind
var floor_y := 1.0
var _full: Array[MeshInstance3D] = []
var _cut: Array[MeshInstance3D] = []
var _ceiling: MeshInstance3D
var _sky_hole: MeshInstance3D
var _outside: MeshInstance3D
var pane_mat: StandardMaterial3D
var land_mat: StandardMaterial3D
## The day down the smoke hole ([position, &"sky"]).
var lights: Array[Array] = []

var centre := Vector2.ZERO
var radius := 3.6
var wall: Array[Color] = []
var cap := GroundColors.made(Color(0.07, 0.06, 0.06), GroundColors.TAR)
var gap := GroundColors.made(Color(0.05, 0.045, 0.04), GroundColors.CUTSTONE)
var earth := GroundColors.made(Color(0.2, 0.15, 0.11), GroundColors.CLAY)
var rush := GroundColors.made(Color(0.55, 0.5, 0.32), GroundColors.THATCH)
var rush_old := GroundColors.made(Color(0.38, 0.32, 0.2), GroundColors.THATCH)
var soot := GroundColors.made(Color(0.07, 0.055, 0.045), GroundColors.THATCH)
var soot_brown := GroundColors.made(Color(0.13, 0.09, 0.06), GroundColors.THATCH)
var drift := GroundColors.made(Color(0.5, 0.47, 0.42), GroundColors.TIMBER)
var drift_dark := GroundColors.made(Color(0.3, 0.27, 0.23), GroundColors.TIMBER)
var fleece := GroundColors.made(Color(0.8, 0.76, 0.66), GroundColors.HIDE)
var fleece_dark := GroundColors.made(Color(0.3, 0.26, 0.22), GroundColors.HIDE)
var heather := GroundColors.made(Color(0.3, 0.2, 0.24), GroundColors.THATCH)
var wool := GroundColors.made(Color(0.46, 0.2, 0.16), GroundColors.CLOTH)
var wool_blue := GroundColors.made(Color(0.24, 0.3, 0.36), GroundColors.CLOTH)
var yarn := GroundColors.made(Color(0.74, 0.7, 0.6), GroundColors.ROPE)
var peat := GroundColors.made(Color(0.2, 0.13, 0.09), GroundColors.CLAY)
var peat_top := GroundColors.made(Color(0.27, 0.18, 0.12), GroundColors.CLAY)
var clay := GroundColors.made(Color(0.42, 0.28, 0.18), GroundColors.CLAY)
var slate := GroundColors.made(P.SLATE[1], GroundColors.SLATE)
var slate_pale := GroundColors.made(P.SLATE[4], GroundColors.SLATE)
var ash := GroundColors.made(Color(0.36, 0.34, 0.32), GroundColors.CLAY)
var iron := GroundColors.made(Color(0.1, 0.1, 0.1), GroundColors.TAR)
var chain := GroundColors.made(Color(0.22, 0.2, 0.19), GroundColors.TAR)
## The chainman's survey post: the machines' marker, painted in their bands.
var post_band := GroundColors.made(Color(0.86, 0.36, 0.1), GroundColors.ENAMEL)
var post_white := GroundColors.made(Color(0.8, 0.8, 0.76), GroundColors.ENAMEL)
var fish := GroundColors.made(Color(0.52, 0.44, 0.32), GroundColors.HIDE)


func build(l: InteriorLayout, k: InteriorKind, land: int, mat: Material) -> void:
	layout = l
	kind = k
	floor_y = TerrainMesher.level_height(InteriorGen.FLOOR_LEVEL)
	centre = l.hearth
	radius = 0.0
	for e: Dictionary in l.edges:
		radius = maxf(radius, centre.distance_to(e.a))
	var dress := BiomeDressing.of(land)
	for i in 4:
		var c: Color = dress.walling[i] if dress.walling.size() > i else P.STONE[2 + i % 3]
		wall.append(GroundColors.made(c, GroundColors.CUTSTONE))
	pane_mat = _unshaded()
	land_mat = _unshaded()
	for i in DIRS.size():
		var full := Kit.new()
		var cut := Kit.new()
		for e: Dictionary in l.edges:
			if _quarter(e.out) != i:
				continue
			_edge(full, e, k.wall_h, false)
			_edge(cut, e, k.cut, true)
		for t: Dictionary in l.things:
			if t.kind == &"pier" and _quarter(-(t.face as Vector2)) == i:
				_pier(full, t, k.wall_h, false)
				_pier(cut, t, k.cut, true)
			elif t.kind == &"loom" and _quarter(-(t.face as Vector2)) == i:
				_loom(full, t.at, t.face, false)
				_loom(cut, t.at, t.face, true)
		_full.append(_mesh(full, mat, "walls_%d" % i))
		var c := _mesh(cut, mat, "cut_%d" % i)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cut.append(c)
	var always := Kit.new()
	_floor(always)
	for t: Dictionary in l.things:
		_thing(always, t)
	_mesh(always, mat, "floor")
	var roof := Kit.new()
	_roof(roof, k.wall_h)
	_ceiling = _mesh(roof, mat, "ceiling")
	# The sky seen up the smoke hole, and the day out through the door.
	var hole := Kit.new()
	var top := _v(centre, k.wall_h + RISE + 0.05)
	for i in 10:
		var a0 := float(i) / 10.0 * TAU
		var a1 := float(i + 1) / 10.0 * TAU
		hole.made.tri(top, top + Vector3(cos(a1), 0.0, sin(a1)) * HOLE, top + Vector3(cos(a0), 0.0, sin(a0)) * HOLE, Color.WHITE)
	_sky_hole = _mesh(hole, pane_mat, "sky_hole")
	_sky_hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var out := Kit.new()
	var land_k := Kit.new()
	_door_pane(out, land_k)
	_outside = _mesh(out, pane_mat, "door_sky")
	_outside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lm := _mesh(land_k, land_mat, "door_land")
	lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lights.append([_v(centre, k.wall_h + RISE - 0.1), &"sky"])


func show_for(back: Vector2, over: float) -> void:
	var whole := over > 0.5
	for i in DIRS.size():
		var drawn := whole or not DIRS[i].dot(back) > 0.2
		_full[i].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if drawn \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_cut[i].visible = not drawn
	_ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if whole \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_sky_hole.visible = whole


func windows() -> Array[Array]:
	return []


func daylight(sky: Color, land: Color) -> void:
	pane_mat.albedo_color = sky
	land_mat.albedo_color = land


static func _unshaded() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	return m


func _mesh(k: Kit, mat: Material, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = k.made.build()
	mi.material_override = mat
	add_child(mi)
	return mi


func _v(p: Vector2, h: float) -> Vector3:
	return Vector3(p.x, floor_y + h, p.y)


## Which of the four quarters a wall facing `out` is drawn and cut with.
static func _quarter(out: Vector2) -> int:
	var best := 0
	for i in DIRS.size():
		if DIRS[i].dot(out) > DIRS[best].dot(out):
			best = i
	return best


## Stones laid along a run from `a` to `b` in the floor plan, their inner face on
## the line and `deep` behind it (toward `back`), in courses up to `h`: two or
## three stones a course, the joints broken course to course, each stone its own
## tone and a hair in or out of the face, the dark of the wall's heart behind.
func _courses(k: Kit, a: Vector2, b: Vector2, back: Vector2, deep: float, h: float, cut: bool, sd: int) -> void:
	var run := b - a
	var along := run.normalized()
	var th := atan2(-along.y, along.x)
	var sgn := signf(Vector2(-along.y, along.x).dot(back))
	var y := 0.0
	var course := 0
	while y < h - 0.02:
		var ch := minf(CH + Kit.j(sd, course, 0.03), h - y)
		var n := 2 + ((sd + course) & 1)
		var cuts: Array[float] = [0.0]
		for i in range(1, n):
			cuts.append((float(i) + Kit.j(sd + course, i, 0.25)) / float(n))
		cuts.append(1.0)
		var last := y + ch >= h - 0.02
		for i in n:
			var u0 := cuts[i] * run.length()
			var u1 := cuts[i + 1] * run.length()
			var hh := sd * 31 + course * 7 + i
			var col: Color = wall[(hh & 0x7fffffff) % 4]
			col = Kit.tone(col, 0.86 + 0.24 * Rng.hash01(hh, 3, 0x5C))
			var p := a + along * (u0 + u1) * 0.5
			var inset := Kit.j(hh, 9, 0.03)
			k.made.push(Transform3D(Basis(Vector3.UP, th), Vector3(p.x, floor_y + y, p.y)))
			k.slab(0.0, 0.0, sgn * (deep * 0.5 + inset), u1 - u0 - 0.035, ch - 0.03, deep, hh, GroundColors.down(col, 0.1),
				cap if (cut and last) else col, 0.025, 0.04, 0.0)
			k.made.pop()
		y += ch
		course += 1
	# The heart of the wall, dark in the joints.
	var mid := (a + b) * 0.5 + back * deep * 0.6
	k.made.push(Transform3D(Basis(Vector3.UP, th), Vector3(mid.x, floor_y, mid.y)))
	k.slab(0.0, 0.0, 0.0, run.length(), h - 0.01, deep * 0.6, sd, gap, cap if cut else gap, 0.0)
	k.made.pop()


## A chord of the wall; the way in is two tall stones set on end, a lintel over
## them, the passage through the wall's depth and the door standing open in it.
func _edge(k: Kit, e: Dictionary, h: float, cut: bool) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var out: Vector2 = e.out
	var sd := int(a.x * 13.0 + a.y * 29.0)
	if e.kind != &"door":
		_courses(k, a, b, out, DEEP, h, cut, sd)
		return
	var along := (b - a).normalized()
	var th := atan2(-along.y, along.x)
	var head := minf(1.42, h)
	for side: float in [-1.0, 1.0]:
		var jamb := (a if side < 0.0 else b) - along * side * 0.06
		k.made.push(Transform3D(Basis(Vector3.UP, th), Vector3(jamb.x, floor_y, jamb.y)))
		k.slab(0.0, 0.0, DEEP * 0.5, 0.2, head, DEEP + 0.1, sd + int(side * 3.0), wall[1], cap if cut else wall[1], 0.02, 0.03)
		k.made.pop()
		# The passage's side walls, out through the wall's depth.
		var s0 := (a if side < 0.0 else b) + out * (DEEP + 0.05)
		_courses(k, s0, s0 + out * 0.7, -along * side, 0.3, h, cut, sd + 40 + int(side))
	if h > head + 0.05:
		var mid := (a + b) * 0.5
		k.made.push(Transform3D(Basis(Vector3.UP, th), Vector3(mid.x, floor_y + head, mid.y)))
		k.slab(0.0, 0.0, DEEP * 0.5, (b - a).length() + 0.3, 0.18, DEEP + 0.12, sd + 5, wall[2], wall[2], 0.02)
		k.made.pop()
		k.made.push(Transform3D(Basis.IDENTITY, Vector3(0.0, head + 0.18, 0.0)))
		_courses(k, a, b, out, DEEP, h - head - 0.18, cut, sd + 9)
		k.made.pop()
	# The door, of salvaged planks, standing open against the passage wall.
	var hinge := a + out * (DEEP + 0.55) + along * 0.05
	var leaf := hinge - out * 0.66
	var leaf_col := drift_dark
	for i in 3:
		var u := (float(i) + 0.5) / 3.0
		var p := hinge.lerp(leaf, u)
		k.made.push(Transform3D(Basis(Vector3.UP, atan2(out.y, -out.x)), Vector3(p.x, floor_y, p.y)))
		k.slab(0.0, 0.03, 0.0, 0.21, minf(head - 0.08, h) - 0.03 * float(i % 2), 0.05, sd + 60 + i, drift if i == 1 else leaf_col, drift, 0.01)
		k.made.pop()
	# The passage's floor, trodden earth, out to where the day is.
	if not cut:
		var pf := (a + b) * 0.5 + out * (DEEP + 0.8) * 0.5
		k.made.push(Transform3D(Basis(Vector3.UP, th), Vector3(pf.x, floor_y - 0.3, pf.y)))
		k.slab(0.0, 0.0, 0.0, (b - a).length() + 0.3, 0.3 + DECK_TOP, DEEP + 0.8, sd + 71, earth, earth, 0.0)
		k.made.pop()
	# A threshold stone, worn.
	var th_at := (a + b) * 0.5 + out * DEEP * 0.5
	k.made.push(Transform3D(Basis(Vector3.UP, th), Vector3(th_at.x, floor_y, th_at.y)))
	k.slab(0.0, -0.02, 0.0, (b - a).length() - 0.2, 0.07, DEEP + 0.2, sd + 70, wall[3], GroundColors.up(wall[3], 0.12), 0.01)
	k.made.pop()


## The day out through the doorway: land low, sky above, at the passage's end.
func _door_pane(sky: Kit, land: Kit) -> void:
	for e: Dictionary in layout.edges:
		if e.kind != &"door":
			continue
		var a: Vector2 = e.a
		var b: Vector2 = e.b
		var out: Vector2 = e.out
		var pa := a + out * (DEEP + 0.8)
		var pb := b + out * (DEEP + 0.8)
		land.made.quad(_v(pa, 0.0), _v(pa, 0.5), _v(pb, 0.5), _v(pb, 0.0), Color.WHITE)
		sky.made.quad(_v(pa, 0.5), _v(pa, 1.5), _v(pb, 1.5), _v(pb, 0.5), Color.WHITE)


## A pier: a spoke of coursed stone from the wall into the room, its capstone
## level with the wall head.
func _pier(k: Kit, t: Dictionary, h: float, cut: bool) -> void:
	var at: Vector2 = t.at
	var f: Vector2 = t.face
	var deep := float(t.deep)
	var s := Vector2(-f.y, f.x)
	var inner := at + f * deep * 0.5
	var outer := at - f * (deep * 0.5 + 0.15)
	var sd := int(at.x * 17.0 + at.y * 23.0)
	# Its two faces are each a run of stones laid back toward the spoke's line,
	# and its nose a short run across the end.
	var half := PIER_W * 0.5
	_courses(k, outer + s * half, inner + s * half, -s, half, h, cut, sd)
	_courses(k, inner - s * half, outer - s * half, s, half, h, cut, sd + 3)
	_courses(k, inner - s * half, inner + s * half, -f, 0.2, h, cut, sd + 5)
	if not cut:
		# Two rough stones across its head, carrying the rafters' feet.
		for i in 2:
			var c := outer.lerp(inner, 0.28 + 0.46 * float(i))
			k.made.push(Transform3D(Basis(Vector3.UP, atan2(-f.y, f.x)), Vector3(c.x, floor_y + h, c.y)))
			var col := Kit.tone(wall[(sd + i) & 3], 0.8)
			k.slab(0.0, 0.0, 0.0, deep * 0.5 + 0.1, 0.16, PIER_W + 0.06, sd + 8 + i, col, col, 0.05, 0.1)
			k.made.pop()


# --- the floor and the roof -----------------------------------------------------

## Beaten earth, rushes strewn thick by the walls and trodden thin in the middle,
## the flags of the paths, and the fire's kerb with its ash.
func _floor(k: Kit) -> void:
	k.made.prism(centre.x, floor_y - 0.02, centre.y, radius + 0.2, floor_y + DECK_TOP, radius + 0.2, 28, earth, earth)
	# Outside the wall, out to the square of tiles the room stands in: the
	# rubble the wall is packed in, black, so no floor shows beyond it.
	const N := 32
	for i in N:
		var a0 := float(i) / N * TAU
		var a1 := float(i + 1) / N * TAU
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		# Not across the way in: the passage has its own floor.
		if (d0 + d1).normalized().dot(layout.door_out) > 0.93:
			continue
		# To the edge of the tiles the room stands on, and no further: beyond them
		# the pocket drops away into its own dark.
		var p0 := _v(centre + d0 * (radius + DEEP * 0.8), 0.05)
		var p1 := _v(centre + d1 * (radius + DEEP * 0.8), 0.05)
		var q0 := _v(centre + d0 * _to_edge(d0), 0.05)
		var q1 := _v(centre + d1 * _to_edge(d1), 0.05)
		k.made.quad(p0, p1, q1, q0, cap)
		k.made.quad(q0, q1, p1, p0, cap)
	for i in 260:
		var h := Rng.hash_ints(i, 0x5A5, 0x2B)
		var a := float(h & 1023) / 1024.0 * TAU
		# More of them further out: trodden away where people walk.
		var r := sqrt(float((h >> 10) & 1023) / 1024.0) * (radius - 0.25)
		if r < 0.9:
			continue
		var p := centre + Vector2(cos(a), sin(a)) * r
		var lay := float((h >> 20) & 255) / 255.0 * PI
		var long := 0.12 + 0.14 * float((h >> 28) & 7) / 7.0
		var col := Kit.tone(rush_old if (h & 3) != 0 else rush, 0.75 + 0.2 * float((h >> 4) & 7) / 7.0)
		k.made.push(Transform3D(Basis(Vector3.UP, lay), Vector3(p.x, floor_y + DECK_TOP, p.y)))
		k.slab(0.0, 0.0, 0.0, long, 0.012, 0.025, h, col, col, 0.004)
		k.made.pop()
	for w: PackedVector2Array in layout.walks:
		var a := w[0]
		var b := w[w.size() - 1]
		var n := maxi(2, roundi(a.distance_to(b) / 0.5))
		for i in n:
			var p := a.lerp(b, (float(i) + 0.5) / float(n))
			var h := Rng.hash_ints(roundi(p.x * 8.0), roundi(p.y * 8.0), 0xF1A)
			var col: Color = Kit.tone(wall[h % 4], 0.8)
			k.stone(p.x + Kit.j(h, 1, 0.08), floor_y - 0.02, p.y + Kit.j(h, 2, 0.08), 0.22 + Kit.j(h, 3, 0.04), 0.07, h, col, 6, 0.0, GroundColors.up(col, 0.1))
	# The hearth: a kerb of stones, the ash bed inside it.
	k.made.prism(centre.x, floor_y, centre.y, 0.56, floor_y + DECK_TOP + 0.015, 0.54, 14, ash, ash)
	for i in 11:
		var a := float(i) / 11.0 * TAU
		var p := centre + Vector2(cos(a), sin(a)) * 0.64
		var h := Rng.hash_ints(i, 0xCE, 0x11)
		k.stone(p.x, floor_y, p.y, 0.13 + Kit.j(h, 1, 0.02), 0.13, h, wall[i % 4], 6)


## A cone of thatch from the wall head to the smoke hole, seen from under it:
## soot-black between driftwood rafters, rings of withies binding them.
func _roof(k: Kit, h: float) -> void:
	const N := 22
	var eave := radius + DEEP * 0.4
	var y0 := h
	var y1 := h + RISE
	var stations: Array[float] = [0.0, 0.34, 0.66, 1.0]
	for si in stations.size() - 1:
		var v0: float = stations[si]
		var v1: float = stations[si + 1]
		var r0 := lerpf(eave, HOLE, v0)
		var r1 := lerpf(eave, HOLE, v1)
		for i in N:
			var a0 := float(i) / N * TAU
			var a1 := float(i + 1) / N * TAU
			var p00 := _v(centre + Vector2(cos(a0), sin(a0)) * r0, lerpf(y0, y1, v0) - 0.02)
			var p01 := _v(centre + Vector2(cos(a1), sin(a1)) * r0, lerpf(y0, y1, v0) - 0.02)
			var p10 := _v(centre + Vector2(cos(a0), sin(a0)) * r1, lerpf(y0, y1, v1))
			var p11 := _v(centre + Vector2(cos(a1), sin(a1)) * r1, lerpf(y0, y1, v1))
			var hh := Rng.hash_ints(i, si, 0x7E)
			var col := soot if (hh & 3) != 0 else soot_brown
			col = Kit.tone(col, 0.85 + 0.3 * float((hh >> 4) & 255) / 255.0)
			k.made.quad(p00, p01, p11, p10, col)
			k.made.quad(p10, p11, p01, p00, col)
			# The ends of the thatch hanging below the lap, in tufts.
			if si == 0 and (hh >> 12) & 1 == 0:
				var m := (p00 + p01) * 0.5
				k.made.strut(m, m + Vector3(0.0, -0.18, 0.0), 0.05, 3, soot_brown)
	# The rafters: driftwood, the only dry timber there ever was here.
	for i in 11:
		var a := float(i) / 11.0 * TAU + 0.12
		var foot := _v(centre + Vector2(cos(a), sin(a)) * (radius + 0.1), y0 - 0.05)
		var head := _v(centre + Vector2(cos(a), sin(a)) * (HOLE + 0.05), y1 + 0.05)
		k.limb(foot + Vector3.DOWN * 0.06, head + Vector3.DOWN * 0.06, 0.07, 0.045, 5, drift if i % 3 != 0 else drift_dark, Vector3(0.0, -0.05, 0.0), Kit.GROWN)
	# Withies binding them round, and the ring at the hole.
	for v: float in [0.33, 0.66, 0.97]:
		var r := lerpf(eave, HOLE, v) - 0.03
		var y := lerpf(y0, y1, v) - 0.1
		for i in 18:
			var a0 := float(i) / 18.0 * TAU
			var a1 := float(i + 1) / 18.0 * TAU
			k.made.strut(_v(centre + Vector2(cos(a0), sin(a0)) * r, y - 0.0), _v(centre + Vector2(cos(a1), sin(a1)) * r, y), 0.025, 4, drift_dark)
	# The wall head: the last course under the eave, turfed.
	for i in N:
		var a0 := float(i) / N * TAU
		var a1 := float(i + 1) / N * TAU
		var p0 := _v(centre + Vector2(cos(a0), sin(a0)) * radius, y0 - 0.03)
		var p1 := _v(centre + Vector2(cos(a1), sin(a1)) * radius, y0 - 0.03)
		var q0 := _v(centre + Vector2(cos(a0), sin(a0)) * eave, y0 - 0.03)
		var q1 := _v(centre + Vector2(cos(a1), sin(a1)) * eave, y0 - 0.03)
		k.made.quad(p0, p1, q1, q0, soot)
		k.made.quad(q0, q1, p1, p0, soot)


# --- what the household keeps ---------------------------------------------------

func _thing(k: Kit, t: Dictionary) -> void:
	var at: Vector2 = t.at
	var f: Vector2 = t.face
	match t.kind:
		&"bed": _bed(k, at, f)
		&"fleece": _fleece(k, at, f)
		&"quern": _quern(k, at, f)
		&"sack": _sack(k, at)
		&"kist": _kist(k, at, f)
		&"crocks": _crocks(k, at, f)
		&"peat": _peat(k, at, f)
		&"slates": _slates(k, at, f)
		&"crane": _crane(k, at, f)
		&"hang": _hang(k, at, f)


func _p(at: Vector2, f: Vector2, u: float, v: float, h: float) -> Vector3:
	var s := Vector2(-f.y, f.x)
	var q := at + s * u + f * v
	return Vector3(q.x, floor_y + h, q.y)


## How far from the middle along `d` the edge of the room's tiles is: the
## middle is not the square's (roundhouse.gd stands it on the door's edge).
func _to_edge(d: Vector2) -> float:
	var r := layout.rooms[0]
	var lo := Vector2(r.position)
	var hi := Vector2(r.end)
	var t := INF
	if absf(d.x) > 1e-4:
		t = minf(t, ((hi.x if d.x > 0.0 else lo.x) - centre.x) / d.x)
	if absf(d.y) > 1e-4:
		t = minf(t, ((hi.y if d.y > 0.0 else lo.y) - centre.y) / d.y)
	return maxf(t, radius + DEEP)


## A block turned to face `f`, `u` across and `v` out from `at`, `h` up.
func _block(k: Kit, at: Vector2, f: Vector2, u: float, v: float, h: float, wu: float, dv: float, hh: float, col: Color, sd: int, top := Color(0, 0, 0, 0), rough := 0.02) -> void:
	var p := _p(at, f, u, v, h)
	k.made.push(Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.y)), p))
	k.slab(0.0, 0.0, 0.0, wu, hh, dv, sd, col, top, rough)
	k.made.pop()


## A box bed: kerb stones round a mattress of heather, fleeces and a blanket.
func _bed(k: Kit, at: Vector2, f: Vector2) -> void:
	var sd := int(at.x * 11.0 + at.y * 7.0)
	for side: float in [-1.0, 1.0]:
		_block(k, at, f, side * 0.92, 0.0, 0.0, 0.16, 0.9, 0.5, wall[2], sd + int(side), wall[2], 0.03)
	_block(k, at, f, 0.0, 0.4, 0.0, 1.9, 0.14, 0.34, wall[1], sd + 3, wall[1], 0.03)
	_block(k, at, f, 0.0, -0.02, 0.0, 1.7, 0.8, 0.3, heather, sd + 4, heather, 0.04)
	_block(k, at, f, 0.2, -0.02, 0.3, 1.2, 0.76, 0.07, wool, sd + 5, wool, 0.03)
	for i in 2:
		var p := _p(at, f, -0.55 + 0.3 * float(i), -0.05, 0.3)
		k.clump(p.x, p.y, p.z, 0.3, 0.1, sd + 6 + i, fleece if i == 0 else fleece_dark, 7)


func _fleece(k: Kit, at: Vector2, f: Vector2) -> void:
	var p := _p(at, f, 0.0, 0.0, DECK_TOP)
	k.clump(p.x, p.y - 0.02, p.z, 0.42, 0.05, int(at.x * 5.0 + at.y * 3.0), fleece, 8)


## The warp-weighted loom: two uprights leaning on the wall, the warp hanging
## from the beam to a row of stones, a hand of cloth woven at its head.
func _loom(k: Kit, at: Vector2, f: Vector2, cut: bool) -> void:
	var top_h := 1.62 if not cut else 0.78
	var sd := int(at.x * 19.0 + at.y * 5.0)
	var lean := 0.34
	for side: float in [-1.0, 1.0]:
		var foot := _p(at, f, side * 0.62, lean, 0.0)
		var head := _p(at, f, side * 0.62, -0.02, top_h)
		k.limb(foot, head, 0.045, 0.035, 5, drift, Vector3.ZERO, Kit.SAWN)
	if cut:
		return
	var beam_l := _p(at, f, -0.72, 0.0, 1.56)
	var beam_r := _p(at, f, 0.72, 0.0, 1.56)
	k.made.strut(beam_l, beam_r, 0.05, 6, drift_dark)
	# The cloth woven so far, rolled at the beam.
	var c0 := _p(at, f, -0.52, 0.03, 1.2)
	var c1 := _p(at, f, 0.52, 0.03, 1.2)
	var c2 := _p(at, f, 0.52, 0.01, 1.52)
	var c3 := _p(at, f, -0.52, 0.01, 1.52)
	k.made.quad(c0, c1, c2, c3, wool_blue)
	k.made.quad(c3, c2, c1, c0, wool_blue)
	# The warp and the stones it hangs from.
	for i in 14:
		var u := -0.5 + float(i) / 13.0
		var from := _p(at, f, u, 0.05, 1.2)
		var to := _p(at, f, u * 0.98, lean * 0.62 + 0.04, 0.42)
		k.made.strut(from, to, 0.006, 3, yarn)
		if i % 2 == 0:
			var w := _p(at, f, u, lean * 0.62 + 0.05, 0.33)
			k.stone(w.x, w.y, w.z, 0.05, 0.1, sd + i, wall[i % 4], 5)
	# The shed rod across the warp.
	k.made.strut(_p(at, f, -0.6, 0.14, 0.95), _p(at, f, 0.6, 0.14, 0.95), 0.02, 5, drift)


func _quern(k: Kit, at: Vector2, f: Vector2) -> void:
	var p := _p(at, f, 0.0, 0.0, DECK_TOP)
	k.clump(p.x, p.y - 0.02, p.z, 0.4, 0.04, int(at.x * 3.0), fleece_dark, 7)
	k.made.prism(p.x, p.y + 0.02, p.z, 0.24, p.y + 0.15, 0.23, 12, wall[0], GroundColors.up(wall[0], 0.12))
	k.made.prism(p.x, p.y + 0.15, p.z, 0.22, p.y + 0.26, 0.2, 12, wall[1], GroundColors.up(wall[1], 0.1))
	k.made.prism(p.x, p.y + 0.26, p.z, 0.04, p.y + 0.27, 0.04, 6, gap, gap)
	var peg := _p(at, f, 0.16, 0.0, 0.24)
	k.made.strut(peg, peg + Vector3(0.0, 0.2, 0.0), 0.02, 5, drift_dark)


func _sack(k: Kit, at: Vector2) -> void:
	k.clump(at.x, floor_y, at.y, 0.2, 0.38, int(at.x * 7.0 + at.y), GroundColors.made(Color(0.52, 0.44, 0.32), GroundColors.CLOTH), 7, 0.1)


## A kist: a box of four stones on edge and a lid.
func _kist(k: Kit, at: Vector2, f: Vector2) -> void:
	var sd := int(at.x * 9.0 + at.y * 13.0)
	_block(k, at, f, 0.0, 0.0, 0.0, 0.78, 0.5, 0.42, wall[3], sd, wall[3], 0.03)
	_block(k, at, f, 0.0, 0.0, 0.42, 0.86, 0.58, 0.07, wall[1], sd + 1, GroundColors.up(wall[1], 0.12), 0.02)


func _crocks(k: Kit, at: Vector2, f: Vector2) -> void:
	for i in 3:
		var p := _p(at, f, -0.2 + 0.2 * float(i), 0.08 * float(i % 2), 0.0)
		var r := 0.1 + 0.03 * float((i + 1) % 3)
		var hh := 0.22 + 0.08 * float(i % 2)
		var col := Kit.tone(clay, 0.8 + 0.12 * float(i))
		k.made.prism(p.x, p.y, p.z, r * 0.75, p.y + hh * 0.5, r, 9, col, col)
		k.made.prism(p.x, p.y + hh * 0.5, p.z, r, p.y + hh, r * 0.6, 9, col, gap)


## The winter's peat, stacked in a herringbone against the wall.
func _peat(k: Kit, at: Vector2, f: Vector2) -> void:
	var sd := int(at.x * 21.0 + at.y * 3.0)
	for row in 4:
		for i in 4 - (row >> 1):
			var u := -0.36 + 0.24 * float(i) + 0.12 * float(row % 2)
			var p := _p(at, f, u, 0.0, float(row) * 0.1)
			k.made.push(Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.y) + (0.5 if row % 2 == 0 else -0.5)), p))
			k.slab(0.0, 0.0, 0.0, 0.12, 0.1, 0.34, sd + row * 8 + i, peat, peat_top, 0.02)
			k.made.pop()


## Hush slate, split thin: a stack, and one stood against the wall with marks
## scratched pale on it that somebody meant to keep.
func _slates(k: Kit, at: Vector2, f: Vector2) -> void:
	var sd := int(at.x * 5.0 + at.y * 31.0)
	for i in 6:
		_block(k, at, f, Kit.j(sd, i, 0.05) - 0.2, Kit.j(sd, i + 9, 0.05), float(i) * 0.03, 0.4, 0.3, 0.028, slate, sd + i, GroundColors.up(slate, 0.1), 0.01)
	var foot := _p(at, f, 0.28, -0.3, 0.0)
	var face := [foot, _p(at, f, 0.72, -0.3, 0.0), _p(at, f, 0.72, -0.44, 0.62), _p(at, f, 0.28, -0.44, 0.62)]
	k.made.quad(face[0], face[1], face[2], face[3], slate)
	k.made.quad(face[3], face[2], face[1], face[0], slate)
	for i in 5:
		var y := 0.14 + 0.09 * float(i)
		var v := -0.3 - 0.14 * (y / 0.62) + 0.012
		var u0 := 0.34 + Kit.j(sd, i + 20, 0.03)
		var u1 := 0.66 - 0.1 * float(i % 2) + Kit.j(sd, i + 30, 0.03)
		k.made.strut(_p(at, f, u0, v, y), _p(at, f, u1, v, y + Kit.j(sd, i + 40, 0.02)), 0.006, 3, slate_pale)


## The crane over the fire: one of the chainman's survey posts, pulled up where
## it was planted and stood here, still in the machines' bands, an arm lashed
## to it and a chain down to the pot.
func _crane(k: Kit, at: Vector2, f: Vector2) -> void:
	var foot := _v(at, 0.0)
	var h := 1.95
	for i in 8:
		var y0 := float(i) * h / 8.0
		var col := post_band if i % 2 == 0 else post_white
		if i < 2:
			col = Kit.tone(col, 0.55)
		k.made.prism(foot.x, foot.y + y0, foot.z, 0.05, foot.y + y0 + h / 8.0, 0.05, 6, col, col)
	k.stone(foot.x, foot.y, foot.z, 0.14, 0.1, int(at.x * 3.0), wall[2], 6)
	var arm_end := _v(at + f * 0.95, 1.7)
	k.limb(_v(at, 1.72), arm_end, 0.04, 0.032, 5, drift_dark, Vector3.ZERO, Kit.SAWN)
	var pot := _v(at + f * 0.95, 0.42)
	for i in 6:
		var a := arm_end + (pot - arm_end) * (float(i) / 6.0)
		var b := arm_end + (pot - arm_end) * (float(i + 1) / 6.0)
		k.made.strut(a, b, 0.012 if i % 2 == 0 else 0.016, 4, chain)
	k.made.prism(pot.x, pot.y - 0.3, pot.z, 0.16, pot.y - 0.1, 0.26, 12, iron, iron)
	k.made.prism(pot.x, pot.y - 0.1, pot.z, 0.26, pot.y, 0.24, 12, iron, GroundColors.made(Color(0.04, 0.035, 0.03), GroundColors.TAR))


## A line across the rafters over the fire, fish hung on it in the smoke.
func _hang(k: Kit, at: Vector2, f: Vector2) -> void:
	var y := kind.wall_h + 0.5
	var a := _v(at - f * 1.25, y + 0.25)
	var b := _v(at + f * 1.25, y + 0.25)
	k.sag(a, b, 0.1, 8, 0.008, GroundColors.made(Color(0.32, 0.27, 0.2), GroundColors.ROPE))
	for i in 7:
		var u := (float(i) + 0.8) / 8.5
		var p := a.lerp(b, u) + Vector3.DOWN * 0.4 * u * (1.0 - u)
		k.made.push(Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.y)), p + Vector3.DOWN * 0.03))
		k.slab(0.0, -0.3, 0.0, 0.07, 0.3, 0.02, i + 3, fish, Kit.tone(fish, 0.7), 0.01, 0.5)
		k.made.pop()
