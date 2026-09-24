extends RefCounted
## THE RING AS A MESH: a spoked wheel sixty kilometres in radius with a wound in
## it (src/core/orbit/orbit_def.gd), in KILOMETRES, drawn only in its own sky
## layer (src/render/orbit/orbit_layer.gd, orbit.gdshader).
##
## FOUND, never boxy: the rim is a trough SWEPT round the wheel -- a hull with
## chamfered corners, walls with a lip, a floor inside -- smooth along its length
## and hard at its corners, with a heavier frame every ten degrees; the spokes
## are tubes with collars and tethers either side; the hub a lathe with docking
## arms and two radiator sails laid along the axis in panels, each panel tilted a
## hair from its neighbours so the sun catches them one at a time (the flares
## are the renderer's own specular, not a trick).
##
## THE WOUND is where the owner's word "fractured" lives. A sector of the rim is
## gone. Each torn end is RAGGED (every corner of the section stops at its own
## angle), its frames stand out past the plate like ribs, sheets of plate peel
## back off it, and cables trail out of it into the gap. The spoke that met the
## rim there is snapped: its root still hangs off the hub and its outer half is
## loose and turning, with a piece of rim still on it. Fourteen more pieces of
## rim drift in the gap. Every loose piece is a rigid BONE (CUSTOM0.x), posed by
## `bone_rows` off the clock, so the wound moves while it is watched.
##
## WHAT THE VERTICES SAY, for the shader's minimum sizes and its lights:
##   CUSTOM0 = (bone, kind, corner x, corner y)
##   CUSTOM1 = (the point it is laid round, xyz; burn 0..1 for plate, or the lamp's class)
##   COLOR   = albedo, alpha the plate's class (`HULL`, `SAIL`...) or a lamp's colour
## A TUBE's vertices are pushed out from their own centre line until the tube is
## `MIN_PX` wide on the glass (a spoke 0.9 km thick is half a pixel on the
## horizon, a cable a hundredth of one) and let into the air by the share it was
## widened; a LAMP is four vertices at one point, opened into a square facing the
## camera at least `LAMP_PX` across.
##
## Two bodies: `detail` true is L1 (a degree a segment, the full section, the
## frames, the fraying, every lamp row); false is L2 for a ring near the horizon,
## sixty pixels across, where a third of that is already under a pixel.
##
## No class_name (reached by path).

const Def := preload("res://src/core/orbit/orbit_def.gd")

const PLATE := 0
const TUBE := 1
const LAMP := 2

## Lamp classes (CUSTOM1.w of a LAMP), read by orbit.gdshader.
const RIM := 0.0
const BEACON := 1.0
const EMBER := 2.0
const ARC := 3.0
const AMBER := 4.0
const HABITAT := 5.0
const PLUME := 6.0

## Plate classes (COLOR.a of a PLATE or TUBE).
const HULL := 1.0
const INNER := 0.9
const WALL := 0.95
const SAIL := 0.8
const TORN := 0.6
const CABLE := 0.4

## Bone 0 is the wheel; 1..CHUNKS the loose rim; the last the snapped spoke.
const BONES := 16

const C_HULL := Color(0.63, 0.62, 0.67)
const C_INNER := Color(0.36, 0.36, 0.37)
const C_FRAME := Color(0.50, 0.49, 0.55)
const C_SAIL := Color(0.13, 0.13, 0.17)
const C_TORN := Color(0.32, 0.27, 0.26)
const C_CABLE := Color(0.18, 0.18, 0.21)
const L_RIM := Color(0.72, 0.84, 1.0)
const L_HABITAT := Color(0.55, 0.78, 1.0)
const L_BEACON := Color(0.82, 0.74, 1.0)
const L_EMBER := Color(1.0, 0.42, 0.10)
const L_ARC := Color(0.70, 0.86, 1.0)
const L_AMBER := Color(1.0, 0.60, 0.18)
const L_PLUME := Color(0.86, 0.92, 1.0)

const SALT := 72101

## The trough's section as (outward from the rim's radius, along the axis), km,
## round the loop: the hull with its chamfers, the walls, the lips, the floor.
const SECTION: Array[Vector2] = [
	Vector2(0.55, -1.45), Vector2(0.55, 1.45), Vector2(0.40, 1.60), Vector2(-0.45, 1.60),
	Vector2(-0.55, 1.50), Vector2(-0.55, 1.35), Vector2(0.33, 1.35), Vector2(0.42, 1.12),
	Vector2(0.42, -1.12), Vector2(0.33, -1.35), Vector2(-0.55, -1.35), Vector2(-0.55, -1.50),
	Vector2(-0.45, -1.60), Vector2(0.40, -1.60),
]
const SECTION_FAR: Array[Vector2] = [
	Vector2(0.55, -1.6), Vector2(0.55, 1.6), Vector2(-0.55, 1.6), Vector2(-0.55, 1.35),
	Vector2(0.42, 1.35), Vector2(0.42, -1.35), Vector2(-0.55, -1.35), Vector2(-0.55, -1.6),
]
## Which edges of the section are its outer SIDE WALLS (drawn WALL: the faces
## a person on the ground sees when the wheel is turned toward them, where the
## habitat's windows are).
const WALL_EDGES := [2, 12]
const WALL_EDGES_FAR := [1, 7]
## Which edges of SECTION face into the trough (drawn INNER, the floor and the
## walls a person would stand between).
const INNER_EDGES := [5, 6, 7, 8, 9]
const INNER_EDGES_FAR := [3, 4, 5]

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _uv := PackedVector2Array()
var _c0 := PackedFloat32Array()
var _c1 := PackedFloat32Array()
var _i := PackedInt32Array()
var _bone := 0
var _detail := false
var _def: RefCounted
var _seed := 0
## The two sections scaled to the def's own trough (SECTION is drawn at 3.2 by
## 1.1 km, the first numbers; the trough is `trough_wide` by `trough_deep`).
var _near_sec: Array[Vector2] = []
var _far_sec: Array[Vector2] = []
var _hd := 0.55
var _hw := 1.6


static func build(def: RefCounted, detail := false, seed_value := 7) -> ArrayMesh:
	var m: RefCounted = (load("res://src/models/orbit/ring_model.gd") as GDScript).new()
	m._def = def
	m._detail = detail
	m._seed = seed_value
	m._scale_sections()
	m._wheel()
	return m._mesh()


func _scale_sections() -> void:
	var k := Vector2(float(_def.trough_deep) / 1.1, float(_def.trough_wide) / 3.2)
	_hd = 0.55 * k.x
	_hw = 1.6 * k.y
	for q: Vector2 in SECTION:
		_near_sec.append(q * k)
	for q: Vector2 in SECTION_FAR:
		_far_sec.append(q * k)


func _sec() -> Array[Vector2]:
	return _near_sec if _detail else _far_sec


func _mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_CUSTOM0] = _c0
	arrays[Mesh.ARRAY_CUSTOM1] = _c1
	arrays[Mesh.ARRAY_INDEX] = _i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
	return mesh


## One vertex; its index.
func _vert(p: Vector3, nrm: Vector3, col: Color, uv: Vector2, kind: int, centre: Vector3, w: float, corner := Vector2.ZERO) -> int:
	_v.append(p)
	_n.append(nrm)
	_c.append(col)
	_uv.append(uv)
	_c0.append_array([float(_bone), float(kind), corner.x, corner.y])
	_c1.append_array([centre.x, centre.y, centre.z, w])
	return _v.size() - 1


func _quad_i(a: int, b: int, c: int, d: int) -> void:
	# The material draws both faces (orbit.gdshader, cull_disabled), so winding
	# carries no meaning here.
	_i.append_array([a, b, c, a, c, d])


## Where a point of the section lies at angle `alpha` (radians) round the wheel,
## `out` outward from the rim radius and `y` along the axis.
func _at(alpha: float, out: float, y: float) -> Vector3:
	var r: float = float(_def.rim_km) + out
	return Vector3(cos(alpha) * r, y, sin(alpha) * r)


func _radial(alpha: float) -> Vector3:
	return Vector3(cos(alpha), 0.0, sin(alpha))


## THE TROUGH swept from angle a0 to a1 (radians) in `segs` segments. `jag0`
## and `jag1` are per-section-point extra angles at each end (a ragged break),
## or empty for a clean one; `burn0`/`burn1` how scorched each end is.
func _sweep(a0: float, a1: float, segs: int, jag0: PackedFloat32Array, jag1: PackedFloat32Array, burn0: float, burn1: float) -> void:
	var sec: Array[Vector2] = _sec()
	var inner: Array = INNER_EDGES if _detail else INNER_EDGES_FAR
	var np := sec.size()
	var rim: float = _def.rim_km
	var burn_reach := deg_to_rad(4.0)
	for e in np:
		var p0: Vector2 = sec[e]
		var p1: Vector2 = sec[(e + 1) % np]
		var along := p1 - p0
		# Outward normal of the edge in the (out, y) plane: the loop runs so that
		# (along.y, -along.x) points out of the section.
		var en := Vector2(along.y, -along.x).normalized()
		var in_trough := inner.has(e)
		var wall := (WALL_EDGES if _detail else WALL_EDGES_FAR).has(e)
		var col := C_INNER if in_trough else C_HULL
		var cls := INNER if in_trough else (WALL if wall else HULL)
		var v0 := _profile_len(sec, e)
		var v1 := v0 + along.length()
		var row_prev := PackedInt32Array()
		for j in segs + 1:
			var f := float(j) / float(segs)
			var row := PackedInt32Array()
			for side in 2:
				var k := e if side == 0 else (e + 1) % np
				var p := p0 if side == 0 else p1
				var s0 := a0 - (jag0[k] if jag0.size() > k else 0.0)
				var s1 := a1 + (jag1[k] if jag1.size() > k else 0.0)
				var alpha := lerpf(s0, s1, f)
				var nrm := _radial(alpha) * en.x + Vector3.UP * en.y
				var burn := maxf(burn0 * (1.0 - clampf((alpha - a0) / burn_reach, 0.0, 1.0)),
					burn1 * (1.0 - clampf((a1 - alpha) / burn_reach, 0.0, 1.0)))
				var c := col
				c.a = cls
				var at := _at(alpha, p.x, p.y)
				# A tube round the rim's own centre line, so a ring on the horizon
				# still keeps its least width.
				row.append(_vert(at, nrm, c, Vector2(alpha * rim, v0 if side == 0 else v1), TUBE, _at(alpha, 0.0, 0.0), burn))
			if j > 0:
				_quad_i(row_prev[0], row[0], row[1], row_prev[1])
			row_prev = row


static func _profile_len(sec: Array[Vector2], upto: int) -> float:
	var l := 0.0
	for e in upto:
		l += (sec[(e + 1) % sec.size()] - sec[e]).length()
	return l


## A heavier FRAME round the section at `alpha`: the section grown by `grow`,
## `wide` km long, capped both faces.
func _frame(alpha: float, grow: float, wide: float) -> void:
	var sec: Array[Vector2] = _near_sec
	var np := sec.size()
	var half := wide * 0.5 / float(_def.rim_km)
	var rim: float = _def.rim_km
	for e in np:
		var p0: Vector2 = sec[e]
		var p1: Vector2 = sec[(e + 1) % np]
		if INNER_EDGES.has(e):
			continue
		var along := p1 - p0
		var en := Vector2(along.y, -along.x).normalized()
		var q0 := p0 + en * grow
		var q1 := p1 + en * grow
		var ids: Array[int] = []
		for a: float in [alpha - half, alpha + half]:
			var nrm := _radial(a) * en.x + Vector3.UP * en.y
			var c := C_FRAME
			c.a = HULL
			for q: Vector2 in [q0, q1]:
				ids.append(_vert(_at(a, q.x, q.y), nrm, c, Vector2(a * rim, q.y * 3.0), TUBE, _at(a, 0.0, 0.0), 0.0))
		_quad_i(ids[0], ids[1], ids[3], ids[2])
		# The two faces of the frame standing proud of the plate.
		for side in 2:
			var a: float = alpha - half if side == 0 else alpha + half
			var tn := Vector3(-sin(a), 0.0, cos(a)) * (-1.0 if side == 0 else 1.0)
			var c := C_FRAME
			c.a = HULL
			var f0 := _vert(_at(a, p0.x, p0.y), tn, c, Vector2(0.0, 0.0), TUBE, _at(a, 0.0, 0.0), 0.0)
			var f1 := _vert(_at(a, p1.x, p1.y), tn, c, Vector2(1.0, 0.0), TUBE, _at(a, 0.0, 0.0), 0.0)
			var f2 := _vert(_at(a, q1.x, q1.y), tn, c, Vector2(1.0, 1.0), TUBE, _at(a, 0.0, 0.0), 0.0)
			var f3 := _vert(_at(a, q0.x, q0.y), tn, c, Vector2(0.0, 1.0), TUBE, _at(a, 0.0, 0.0), 0.0)
			_quad_i(f0, f1, f2, f3)


## A TUBE from `a` to `b`, `r` km thick, `sides` flats, `col` with its class in
## alpha; pushed out to the least width round its own centre line.
func _tube(a: Vector3, b: Vector3, r0: float, r1: float, sides: int, col: Color, burn := 0.0) -> void:
	var y := b - a
	var l := y.length()
	if l <= 1e-5:
		return
	y /= l
	var x := (Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).cross(y).normalized()
	var z := y.cross(x)
	var ids: Array[int] = []
	for end in 2:
		var o := a if end == 0 else b
		var r := r0 if end == 0 else r1
		for s in sides + 1:
			var t := TAU * float(s) / float(sides)
			var nrm := x * cos(t) + z * sin(t)
			ids.append(_vert(o + nrm * r, nrm, col, Vector2(float(s) / float(sides) * TAU * r, l * float(end)), TUBE, o, burn))
	for s in sides:
		_quad_i(ids[s], ids[s + 1], ids[sides + 1 + s + 1], ids[sides + 1 + s])


## A bent line of tube through `pts` (a cable, a frayed rib).
func _line(pts: Array[Vector3], r: float, sides: int, col: Color, burn := 0.0) -> void:
	for i in pts.size() - 1:
		_tube(pts[i], pts[i + 1], r, r, sides, col, burn)


## A LAMP: four vertices at one point, opened on the glass by the shader.
## `size` is a least half-width in km (0: a point, opened to LAMP_PX only).
func _lamp(at: Vector3, col: Color, cls: float, size := 0.0) -> void:
	var nrm := Vector3.UP
	var ids: Array[int] = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		ids.append(_vert(at, nrm, col, Vector2(size, 0.0), LAMP, at, cls, corner))
	_quad_i(ids[0], ids[1], ids[2], ids[3])


## A lathe about the local Y axis through `centre`: `profile` (radius, y).
func _lathe(centre: Vector3, profile: Array[Vector2], sides: int, col: Color) -> void:
	for i in profile.size() - 1:
		var p0 := profile[i]
		var p1 := profile[i + 1]
		var d := p1 - p0
		var en := Vector2(d.y, -d.x).normalized()
		if en.x < 0.0:
			en = -en
		var ids: Array[int] = []
		for s in sides + 1:
			var t := TAU * float(s) / float(sides)
			var rad := Vector3(cos(t), 0.0, sin(t))
			var nrm := (rad * en.x + Vector3.UP * en.y).normalized()
			for p: Vector2 in [p0, p1]:
				ids.append(_vert(centre + rad * p.x + Vector3.UP * p.y, nrm, col, Vector2(t * 2.0, p.y), TUBE, centre + Vector3.UP * p.y, 0.0))
		for s in sides:
			_quad_i(ids[s * 2], ids[s * 2 + 1], ids[s * 2 + 3], ids[s * 2 + 2])


# ---------------------------------------------------------------------------


func _wheel() -> void:
	var rng := Rng.make(_seed, SALT)
	var gap := deg_to_rad(float(_def.gap_deg))
	var gap_c := deg_to_rad(float(_def.gap_at))
	# The rim runs from the far torn end round to the near one.
	var a0 := gap_c + gap * 0.5
	var a1 := gap_c - gap * 0.5 + TAU
	var sec_n := _sec().size()
	var jag0 := PackedFloat32Array()
	var jag1 := PackedFloat32Array()
	for k in sec_n:
		jag0.append(deg_to_rad(rng.randf_range(-1.6, 1.4)))
		jag1.append(deg_to_rad(rng.randf_range(-1.6, 1.4)))
	var seg_deg := 1.25 if _detail else 3.0
	var segs := int(ceil(rad_to_deg(a1 - a0) / seg_deg))
	_bone = 0
	_sweep(a0, a1, segs, jag0, jag1, 1.0, 1.0)
	if _detail:
		var fa := ceilf(rad_to_deg(a0) / 5.0) * 5.0
		while deg_to_rad(fa) < a1 - deg_to_rad(3.0):
			if deg_to_rad(fa) > a0 + deg_to_rad(3.0):
				var major := int(fa) % 15 == 0
				_frame(deg_to_rad(fa), _hd * (0.28 if major else 0.14), 0.9 if major else 0.5)
			fa += 5.0
		_tanks(a0, a1)
		_fray(a0, -1.0, jag0, rng)
		_fray(a1, 1.0, jag1, rng)
	_deck(a0, a1, gap_c, gap)
	_hub()
	_spokes(gap_c, rng)
	_lamps(a0, a1, rng)
	_chunks(gap_c)


## A TORN END at angle `a` (the rim runs away from it on the `-dir` side):
## frames standing out past the plate, sheets peeling back, cables trailing into
## the gap, embers along the break and the odd arc.
func _fray(a: float, dir: float, jag: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var rim: float = _def.rim_km
	var sec: Array[Vector2] = _near_sec
	# Ribs: the frames the plate was hung on, bare past the break.
	for i in 7:
		var k := rng.randi_range(0, sec.size() - 1)
		var p: Vector2 = sec[k]
		var start_a := a + dir * jag[k]
		var reach := rng.randf_range(1.2, 4.5) / rim
		var pts: Array[Vector3] = []
		for s in 4:
			var f := float(s) / 3.0
			var al := start_a + dir * reach * f
			var bend := Vector2(p.x * (1.0 + 0.5 * f * f), p.y * (1.0 - 0.25 * f * f)) + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)) * f
			pts.append(_at(al, bend.x, bend.y))
		var c := C_TORN
		c.a = TORN
		_line(pts, 0.16, 4, c, 1.0)
	# Sheets of plate peeled back off the hull, curling out and away.
	for i in 5:
		var y0 := rng.randf_range(-0.8, 0.5) * _hw
		var wide := rng.randf_range(0.3, 0.75) * _hw
		var out0 := _hd if rng.randf() < 0.6 else -_hd
		var curl := rng.randf_range(1.2, 2.6) * signf(out0)
		var ids := PackedInt32Array()
		var rows := 5
		var start_a := a + dir * deg_to_rad(rng.randf_range(-0.5, 0.3))
		var length := rng.randf_range(1.5, 3.5)
		for rr in rows + 1:
			var f := float(rr) / float(rows)
			var ang := f * curl
			for side in 2:
				var y := y0 + wide * float(side)
				var along := sin(ang) / maxf(absf(curl), 0.01) * length
				var up := (1.0 - cos(ang)) / maxf(absf(curl), 0.01) * length
				var al := start_a + dir * absf(along) / rim
				var at := _at(al, out0 + up * signf(out0) * 0.8, y)
				var tan_v := Vector3(-sin(al), 0.0, cos(al)) * dir
				var nrm := (_radial(al) * cos(ang) - tan_v * sin(ang) * signf(out0)).normalized()
				var c := C_HULL.lerp(C_TORN, f)
				c.a = TORN
				ids.append(_vert(at, nrm, c, Vector2(f * length, float(side) * wide), PLATE, at, f))
		for rr in rows:
			_quad_i(ids[rr * 2], ids[rr * 2 + 1], ids[rr * 2 + 3], ids[rr * 2 + 2])
		# The peeled edge still hot.
		_lamp(_v[ids[rows * 2]], L_EMBER, EMBER)
	# Cables trailing out into the gap, sagging and turning.
	for i in 6:
		var k := rng.randi_range(0, sec.size() - 1)
		var p: Vector2 = sec[k]
		var reach := rng.randf_range(5.0, 16.0)
		var sag := rng.randf_range(1.0, 5.0) * (1.0 if rng.randf() < 0.7 else -1.0)
		var twist := rng.randf_range(-2.0, 2.0)
		var pts: Array[Vector3] = []
		var n := 12
		for s in n + 1:
			var f := float(s) / float(n)
			var al := a + dir * (jag[k] * 0.5 + reach * f / rim)
			pts.append(_at(al, p.x + sag * f * f, p.y + twist * f + sin(f * 5.0 + float(i)) * 0.3 * f))
		var c := C_CABLE
		c.a = CABLE
		_line(pts, 0.03, 3, c, 0.3)
	# VENT PLUMES: air and water still bleeding out of the torn habitat, frozen
	# into crystal as it goes, a fan of puffs growing and thinning away from the
	# break. They have no light of their own: they are seen only where the sun
	# is on them (orbit.gdshader PLUME), white against the dark and gone in the
	# Earth's shadow.
	for i in 2:
		var p: Vector2 = sec[rng.randi_range(0, sec.size() - 1)]
		var outv := Vector2(rng.randf_range(0.3, 1.0), rng.randf_range(-0.6, 0.6))
		for k in 8:
			var f := float(k + 1) / 8.0
			var reach := f * rng.randf_range(10.0, 18.0)
			var at := _at(a + dir * (jag[0] + reach * 0.35 / rim), p.x + outv.x * reach, p.y + outv.y * reach)
			_lamp(at, L_PLUME, PLUME, lerpf(0.5, 3.4, f))
	# Embers along the break itself, and the arcs.
	for k in sec.size():
		var p: Vector2 = sec[k]
		_lamp(_at(a + dir * jag[k], p.x, p.y), L_EMBER, EMBER)
		var mid: Vector2 = (p + sec[(k + 1) % sec.size()]) * 0.5
		if rng.randf() < 0.6:
			_lamp(_at(a + dir * (jag[k] + jag[(k + 1) % sec.size()]) * 0.5, mid.x, mid.y), L_EMBER, EMBER)
	for i in 3:
		var p: Vector2 = sec[rng.randi_range(0, sec.size() - 1)]
		_lamp(_at(a + dir * deg_to_rad(rng.randf_range(0.2, 1.5)), p.x * 1.4, p.y * 1.1), L_ARC, ARC)


## THE DECK (orbit_def.gd `deck_km`): panels in the wheel's plane inside the
## trough, three bands deep, some missing -- more toward the wound, where the
## last of them stand out ragged -- and the radial girders they hang on.
func _deck(a0: float, a1: float, gap_c: float, gap: float) -> void:
	var rim: float = _def.rim_km
	var inner_r := rim - _hd
	var deck: float = _def.deck_km
	var bands := 3 if _detail else 1
	var seg_deg := 2.0 if _detail else 6.0
	var segs := int(ceil(rad_to_deg(a1 - a0) / seg_deg))
	var fc := C_FRAME
	fc.a = HULL
	for j in segs:
		var s0 := lerpf(a0, a1, float(j) / float(segs))
		var s1 := lerpf(a0, a1, float(j + 1) / float(segs))
		var mid := (s0 + s1) * 0.5
		# How near the wound this is, 0..1: the rim is torn at both ends of
		# [a0, a1], so the nearer end counts.
		var from_wound := minf(mid - a0, a1 - mid)
		var near_wound := 1.0 - clampf(from_wound / deg_to_rad(18.0), 0.0, 1.0)
		for b in bands:
			var r0 := inner_r - deck * float(b) / float(bands)
			var r1 := inner_r - deck * float(b + 1) / float(bands)
			var miss := Rng.hash01(_seed, SALT + 21, j, b)
			if miss < 0.03 + near_wound * near_wound * 0.7 + float(b) * 0.06:
				continue
			# A panel lifts and sags a little off the plane, never flat as a sheet.
			var lift := (Rng.hash01(_seed, SALT + 22, j, b) - 0.5) * 0.03
			var c := C_HULL.lerp(C_FRAME, Rng.hash01(_seed, SALT + 23, j, b) * 0.07)
			c.a = HULL
			var ids: Array[int] = []
			var gap_s := 0.0
			for q: Vector2 in [Vector2(s0 + gap_s, r0), Vector2(s1 - gap_s, r0), Vector2(s1 - gap_s, r1), Vector2(s0 + gap_s, r1)]:
				var p := Vector3(cos(q.x) * q.y, lift, sin(q.x) * q.y)
				ids.append(_vert(p, Vector3.UP, c, Vector2(q.x * rim, q.y), PLATE, p, near_wound * 0.7))
			_quad_i(ids[0], ids[1], ids[2], ids[3])
		# A girder every few segments, under the panels, bare where they are gone.
		if _detail and j % 3 == 0:
			_tube(Vector3(cos(s0) * inner_r, -0.12, sin(s0) * inner_r), Vector3(cos(s0) * (inner_r - deck), -0.12, sin(s0) * (inner_r - deck)), 0.07, 0.07, 3, fc)
	if _detail:
		# The deck's inner edge: a rail the whole way round.
		var n := int(ceil(rad_to_deg(a1 - a0) / 4.0))
		for j in n:
			var s0 := lerpf(a0, a1, float(j) / float(n))
			var s1 := lerpf(a0, a1, float(j + 1) / float(n))
			var r := inner_r - deck
			_tube(Vector3(cos(s0) * r, 0.0, sin(s0) * r), Vector3(cos(s1) * r, 0.0, sin(s1) * r), 0.1, 0.1, 4, fc)


func _hub() -> void:
	var c := C_HULL
	c.a = HULL
	var fc := C_FRAME
	fc.a = HULL
	var sides := 14 if _detail else 8
	var hl: float = float(_def.hub_long) * 0.5
	var hr: float = _def.hub_r
	# A spindle with a waist: the drum the spokes meet, collars stepping down to
	# the docking ends, so the middle of the wheel is a mass and not a point.
	var prof: Array[Vector2] = [
		Vector2(0.0, -hl), Vector2(hr * 0.45, -hl), Vector2(hr * 0.6, -hl * 0.92), Vector2(hr * 0.72, -hl * 0.78),
		Vector2(hr * 0.72, -hl * 0.62), Vector2(hr * 0.9, -hl * 0.56), Vector2(hr * 0.9, -hl * 0.36),
		Vector2(hr * 1.35, -hl * 0.3), Vector2(hr * 1.5, -hl * 0.14), Vector2(hr * 1.5, hl * 0.14), Vector2(hr * 1.35, hl * 0.3),
		Vector2(hr * 0.9, hl * 0.36), Vector2(hr * 0.9, hl * 0.56), Vector2(hr * 0.72, hl * 0.62),
		Vector2(hr * 0.72, hl * 0.78), Vector2(hr * 0.6, hl * 0.92), Vector2(hr * 0.45, hl), Vector2(0.0, hl),
	]
	_lathe(Vector3.ZERO, prof, sides, c)
	# Docking arms at both ends, four each, with a berth on each.
	for end: float in [-1.0, 1.0]:
		for k in 4:
			var t := TAU * float(k) / 4.0 + 0.4
			var o := Vector3(cos(t), 0.0, sin(t))
			var base := Vector3(0.0, end * hl * 0.84, 0.0) + o * hr * 0.6
			var tip := base + o * hr * 1.5 + Vector3(0.0, end * hr * 0.3, 0.0)
			_tube(base, tip, hr * 0.12, hr * 0.09, 6 if _detail else 4, fc)
			if _detail:
				_tube(tip - Vector3(0.0, end * hr * 0.2, 0.0), tip + Vector3(0.0, end * hr * 0.6, 0.0), hr * 0.18, hr * 0.18, 6, fc)
		_lamp(Vector3(0.0, end * (hl + 0.3), 0.0), L_BEACON, BEACON)
	# The radiator sails, along the axis past each end: panels in two columns on
	# a spine, each a hair off its neighbours so they catch the sun one at a time.
	var sail: Vector2 = _def.sail
	var rng := Rng.make(_seed, SALT + 7)
	var sc := C_SAIL
	sc.a = SAIL
	var along_n := 12 if _detail else 4
	for end: float in [-1.0, 1.0]:
		var y0 := end * (hl + 0.6)
		_tube(Vector3(0.0, end * hl, 0.0), Vector3(0.0, y0 + end * sail.x, 0.0), hr * 0.14, hr * 0.08, 6 if _detail else 4, fc)
		for col in 2:
			var x0 := (0.35 if col == 0 else -0.35 - sail.y * 0.5)
			for j in along_n:
				var ya := y0 + end * sail.x * float(j) / float(along_n)
				var yb := y0 + end * sail.x * float(j + 1) / float(along_n) - end * 0.3
				var tilt := deg_to_rad(rng.randf_range(-7.0, 7.0))
				var nrm := Vector3(sin(tilt), 0.0, cos(tilt))
				var xc := x0 + sail.y * 0.25
				var ids: Array[int] = []
				for q: Vector2 in [Vector2(x0, ya), Vector2(x0 + sail.y * 0.5, ya), Vector2(x0 + sail.y * 0.5, yb), Vector2(x0, yb)]:
					var p := Vector3(q.x, q.y, -(q.x - xc) * sin(tilt))
					ids.append(_vert(p, nrm, sc, Vector2(q.x, q.y), PLATE, p, 0.0))
				_quad_i(ids[0], ids[1], ids[2], ids[3])
		_lamp(Vector3(0.0, y0 + end * (sail.x + 0.3), 0.0), L_BEACON, BEACON)


## THE SPOKES AS TRUSSES: four longerons round a lift shaft, laced with
## diagonals bay by bay, with pods at a third and two thirds -- a structure
## tens of kilometres long and two across, not a line. The snapped one keeps
## its root on the hub, its longerons splayed where they parted.
func _spokes(gap_c: float, rng: RandomNumberGenerator) -> void:
	var n: int = _def.spokes
	var rim: float = _def.rim_km
	var hr: float = float(_def.hub_r) * 1.4
	var fc := C_FRAME
	fc.a = HULL
	var cc := C_CABLE
	cc.a = CABLE
	for k in n:
		var al := gap_c + TAU * float(k) / float(n)
		var o := _radial(al)
		var inner := o * hr
		var outer := o * (rim - _hd)
		if k == 0:
			var brk := o * (rim * 0.43)
			_truss(inner, brk, o, 1.0, rng)
			var tc := C_TORN
			tc.a = TORN
			for i in 7:
				var off := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * float(_def.spoke_thick) * 0.5
				_tube(brk + off * 0.5, brk + o * rng.randf_range(0.8, 3.0) + off, 0.08, 0.05, 3, tc, 1.0)
			_lamp(brk + o * 0.3, L_EMBER, EMBER)
			_lamp(brk + o * 0.6 + Vector3(0.0, 0.5, 0.0), L_EMBER, EMBER)
			continue
		_truss(inner, outer, o, 1.0, rng)


## One truss from `a` to `b` along `o`: `w` scales its width.
func _truss(a: Vector3, b: Vector3, o: Vector3, w: float, rng: RandomNumberGenerator) -> void:
	var fc := C_FRAME
	fc.a = HULL
	var half: float = float(_def.spoke_thick) * 0.5 * w
	var up := Vector3.UP
	var side := o.cross(up).normalized()
	if not _detail:
		_tube(a, b, half * 0.8, half * 0.7, 4, fc)
		return
	var corners: Array[Vector3] = [up * half + side * half, up * half - side * half, -up * half - side * half, -up * half + side * half]
	for c: Vector3 in corners:
		_tube(a + c, b + c * 0.85, half * 0.13, half * 0.11, 4, fc)
	_tube(a, b, half * 0.3, half * 0.26, 6, fc)
	var length := a.distance_to(b)
	var bays := maxi(2, int(length / (half * 3.2)))
	for i in bays:
		var f0 := float(i) / float(bays)
		var f1 := float(i + 1) / float(bays)
		var sh0 := lerpf(1.0, 0.85, f0)
		var sh1 := lerpf(1.0, 0.85, f1)
		for f in 4:
			var c0 := corners[f]
			var c1 := corners[(f + 1) % 4]
			var from := a.lerp(b, f0) + (c0 if i % 2 == 0 else c1) * sh0
			var to := a.lerp(b, f1) + (c1 if i % 2 == 0 else c0) * sh1
			_tube(from, to, half * 0.06, half * 0.06, 3, fc)
	# Pods on the shaft, a third and two thirds out, lit where they still are.
	for f: float in [0.33, 0.66]:
		var p := a.lerp(b, f)
		_tube(p - o * half * 1.6, p + o * half * 1.6, half * 1.5, half * 1.5, 8, fc)
		if Rng.hash01(_seed, SALT + 31, int(f * 10.0), int(p.x)) > 0.3:
			_lamp(p + up * half * 1.6, L_RIM, RIM)


## TANKS along the outer hull: clusters of cylinders laid along the rim every few
## degrees, so the hull's line is broken by mass the way a real hull is.
func _tanks(a0: float, a1: float) -> void:
	var fc := C_FRAME
	fc.a = HULL
	var step := deg_to_rad(6.0)
	var al := a0 + step * 0.7
	var i := 0
	while al < a1 - step * 0.7:
		var n := 2 + int(Rng.hash01(_seed, SALT + 41, i) * 2.0)
		var span := deg_to_rad(1.4 + Rng.hash01(_seed, SALT + 42, i) * 1.8)
		for t in n:
			var y := (float(t) - float(n - 1) * 0.5) * _hw * 0.55
			var r := _hw * 0.22
			var s0 := al - span * 0.5
			var s1 := al + span * 0.5
			_tube(_at(s0, _hd + r * 0.9, y), _at(s1, _hd + r * 0.9, y), r, r, 6, fc)
		al += step
		i += 1


func _lamps(a0: float, a1: float, rng: RandomNumberGenerator) -> void:
	var step := deg_to_rad(0.6 if _detail else 2.4)
	var al := a0 + step
	var i := 0
	while al < a1 - step * 0.5:
		# Whole runs of the rim are dark, and single lamps within a lit run.
		var run := floori(rad_to_deg(al) / 7.0)
		var run_dead := Rng.hash01(_seed, SALT + 1, run) < 0.32
		if not run_dead:
			for side: float in [-1.0, 1.0]:
				if Rng.hash01(_seed, SALT + 2, i, int(side)) > 0.22:
					_lamp(_at(al, _hd + 0.05, side * (_hw - 0.1)), L_RIM, RIM)
			if _detail and i % 2 == 0:
				for side: float in [-1.0, 1.0]:
					if Rng.hash01(_seed, SALT + 3, i, int(side)) > 0.4:
						_lamp(_at(al, -_hd - 0.05, side * (_hw - 0.05)), L_RIM, RIM)
		if _detail and i % 3 == 0 and Rng.hash01(_seed, SALT + 4, i) > 0.8:
			_lamp(_at(al, _hd * 0.7, rng.randf_range(-0.5, 0.5) * _hw), L_HABITAT, HABITAT)
		al += step
		i += 1
	# ONE WARM POINT on the whole wheel, a little way round from the wound: the
	# only light up there anybody could have lit by hand.
	_lamp(_at(a0 + deg_to_rad(23.0), -_hd - 0.03, 0.55 * _hw), L_AMBER, AMBER)


## The loose pieces: `Chunk` rows from `chunk_list`, each a short piece of rim on
## its own bone, and the snapped spoke's outer half on the last.
func _chunks(gap_c: float) -> void:
	var rim: float = _def.rim_km
	var list := chunk_list(_def, _seed)
	for ci in list.size():
		var ch: Dictionary = list[ci]
		_bone = ci + 1
		if ch.has("spoke"):
			var o := _radial(gap_c)
			var fc := C_FRAME
			fc.a = HULL
			var a: Vector3 = o * (rim * 0.48)
			var b: Vector3 = o * (rim - _hd)
			_truss(a, b, o, 1.0, Rng.make(_seed, SALT + 51))
			var jag := PackedFloat32Array()
			_sweep(gap_c - deg_to_rad(1.8), gap_c + deg_to_rad(1.2), 3 if _detail else 1, jag, jag, 1.0, 1.0)
			_lamp(a, L_EMBER, EMBER)
			continue
		var c0: float = ch.a0
		var c1: float = ch.a1
		var n := _sec().size()
		var j0 := PackedFloat32Array()
		var j1 := PackedFloat32Array()
		var r := Rng.make(_seed, SALT + 11 + ci)
		for k in n:
			j0.append(deg_to_rad(r.randf_range(-0.5, 0.5)))
			j1.append(deg_to_rad(r.randf_range(-0.5, 0.5)))
		_sweep(c0, c1, 3 if _detail else 1, j0, j1, 1.0, 1.0)
		if _detail and r.randf() < 0.5:
			_lamp(_at(c1, _hd, r.randf_range(-0.75, 0.75) * _hw), L_EMBER, EMBER)
	_bone = 0


## THE LOOSE PIECES, pure off the seed: each a stretch of rim (a0..a1 radians)
## round its own centre `c`, drifting along `drift` by up to `amp` km over
## `drift_min` world minutes and turning about `axis` once every `turn_min`.
## The last is the snapped spoke's outer half.
static func chunk_list(def: RefCounted, seed_value: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng := Rng.make(seed_value, SALT + 99)
	var gap := deg_to_rad(float(def.gap_deg))
	var gap_c := deg_to_rad(float(def.gap_at))
	var rim: float = def.rim_km
	for i in int(def.chunks):
		# Spread through the gap, most near the torn ends where they came from.
		var t := rng.randf()
		t = 0.5 + (0.5 - 0.5 * pow(1.0 - absf(t * 2.0 - 1.0), 1.6)) * signf(t - 0.5)
		var mid := gap_c - gap * 0.5 + gap * clampf(t, 0.04, 0.96)
		var span := deg_to_rad(rng.randf_range(0.6, 3.6))
		var out_km := rng.randf_range(0.0, 7.0)
		var c := Vector3(cos(mid) * (rim + out_km), rng.randf_range(-2.5, 2.5), sin(mid) * (rim + out_km))
		out.append({"a0": mid - span * 0.5, "a1": mid + span * 0.5,
			"c": Vector3(cos(mid) * rim, 0.0, sin(mid) * rim), "at": c,
			"axis": Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(),
			"turn_min": rng.randf_range(240.0, 900.0) * (1.0 if rng.randf() < 0.5 else -1.0),
			"start": rng.randf() * TAU,
			"drift": Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.4), rng.randf_range(-1, 1)).normalized(),
			"amp": rng.randf_range(0.5, 2.5), "drift_min": rng.randf_range(600.0, 1400.0)})
	var sc := Vector3(cos(gap_c), 0.0, sin(gap_c)) * (rim * 0.74)
	out.append({"spoke": true, "c": sc, "at": sc + Vector3(cos(gap_c), 0.0, sin(gap_c)) * 3.5 + Vector3(0.0, 4.0, 0.0),
		"axis": Vector3(0.3, 0.2, 1.0).normalized(), "turn_min": 700.0, "start": 0.6,
		"drift": Vector3(0.0, 1.0, 0.0), "amp": 1.5, "drift_min": 1100.0})
	return out


## The bones at `minutes`: three rows each (basis row, origin), BONES of them.
## `list` is `chunk_list(def, seed_value)` if the caller keeps it, which a
## caller asking every frame should.
static func bone_rows(def: RefCounted, seed_value: int, minutes: float, list: Array[Dictionary] = []) -> PackedVector4Array:
	var rows := PackedVector4Array()
	rows.resize(BONES * 3)
	var id := Transform3D.IDENTITY
	_put(rows, 0, id)
	if list.is_empty():
		list = chunk_list(def, seed_value)
	for i in list.size():
		var ch: Dictionary = list[i]
		var b := Basis((ch.axis as Vector3), float(ch.start) + TAU * minutes / float(ch.turn_min))
		var c: Vector3 = ch.c
		var at: Vector3 = ch.at
		var drift: Vector3 = (ch.drift as Vector3) * float(ch.amp) * sin(TAU * minutes / float(ch.drift_min) + float(i))
		var t := Transform3D(b, at + drift) * Transform3D(Basis.IDENTITY, -c)
		_put(rows, i + 1, t)
	for i in range(list.size() + 1, BONES):
		_put(rows, i, id)
	return rows


static func _put(rows: PackedVector4Array, bone: int, t: Transform3D) -> void:
	for r in 3:
		rows[bone * 3 + r] = Vector4(t.basis[0][r], t.basis[1][r], t.basis[2][r], t.origin[r])
