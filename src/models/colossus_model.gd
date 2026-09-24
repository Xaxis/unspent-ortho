extends RefCounted
## THE FAR BODY OF A COLOSSUS (L2): one surface, one draw, a few thousand
## triangles, for everything further than the land itself reaches -- which, for
## a machine whose hub stands fifty-five kilometres up, is every frame this slice
## draws it in.
##
## FOUND, and the FOUND idiom is the rule for its shape: exact, symmetric, ruled,
## tapered and jointed. Nothing here is a box. The hub is a lathed hull with a
## hanging keel, a belt and two rims, a plated tower going up out of it with
## collars and ribs, and a spire; each leg is a tapered thigh with a sleeve and a
## tendon strut along its inner face, a faceted knee, a shin that narrows to an
## ankle ninety metres across, and a foot of three toes on pads. A person could
## walk between those toes; at this distance nobody will ever see them, and they
## are here so the nearer bodies later slices build are the same machine.
##
## THE BODY IS RIGID AND SKINNED BY PART. Every vertex carries the bone it rides
## on in CUSTOM0.x -- 0 the hub, then thigh, shin and foot per leg -- and is
## authored in that bone's own frame (colossus_walk.gd `pose().bones`: origin at
## the joint, Y along the bone, X outward). The shader moves each part by its
## bone, so walking costs a handful of uniforms a frame and never a rebuilt mesh.
##
## Faces are flat: a machine is panels, and a lathe smoothed round would read as
## moulded rather than assembled. Rings are laid dense where the shader's air
## changes fastest -- near the ground and up the shins -- because the air is
## worked out per fragment from the TRUE position, and a thirty-kilometre
## triangle would interpolate it across the whole leg in compressed space.
##
## Colours are the FOUND ramp, with the amber LENS as the one warm, saturated
## thing on it (docs/LOOK.md: a machine is a dark mass by day). Vertex alpha
## under 0.98 marks light, as it does on every FOUND model.

## How many rigid parts the mesh is skinned to: the hub, then three per leg.
const BONES := 10
const LEGS := 3

const BODY := Color(0.2290, 0.1981, 0.3137)
const PLATE := Color(0.1687, 0.1962, 0.2518)
const DARK := Color(0.1042, 0.0902, 0.1412)
const RIM := Color(0.3176, 0.2695, 0.4413)
## Light is marked in vertex alpha, as on every FOUND model, and the three
## codes are read by colossus.gdshader: the lens (0.80, amber, always), a cold
## strip (0.70, lit as the light goes) and a beacon (0.36, blinking on the
## machines' beat). The strip and beacon colours are works.gd's STRIP and
## BEACON, the plan's own light.
const LENS := Color(0.9098, 0.7608, 0.2275, 0.80)
const STRIP := Color(0.7451, 0.7294, 0.8745, 0.70)
const BEACON := Color(0.7098, 0.5176, 0.6118, 0.36)

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _b := PackedFloat32Array()
var _bone := 0
## What the vertices being laid are, for the shader's minimum sizes (CUSTOM0.y):
## 0 plate, 1 a strip (a ring round the local Y axis at height `_lc.y`), 2 a
## beacon and 3 the lens (a lamp round the point `_lc`). A light a kilometre
## wide fifty kilometres off is a pixel; the shader keeps each at least a few
## pixels, by kind, so the machine's own light reads however far off it walks.
var _kind := 0
var _detail := false
var _lc := Vector3.ZERO


## `detail` builds L1, the body for a walker near enough that its legs are
## tens of pixels wide (under `ColossusView.NEAR_LOD`): the same silhouette,
## with more flats to the plate and the machinery a leg that size is made of
## -- cable runs, pistons across the knee, the hip's drive ring. L2 leaves them
## out because past it they are under a pixel and only cost.
static func build(def: RefCounted, detail := false) -> ArrayMesh:
	var m: RefCounted = (load("res://src/models/colossus_model.gd") as GDScript).new()
	m._detail = detail
	m._hub(def)
	for k in LEGS:
		m._leg(def, k)
	return m._mesh()


func _mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	arrays[Mesh.ARRAY_CUSTOM0] = _b
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return mesh


## One flat triangle, authored counter-clockwise from outside and emitted
## reversed, because Godot's front faces are clockwise (MeshKit does the same).
func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() <= 0.0:
		return
	n = n.normalized()
	for p: Vector3 in [a, c, b]:
		_v.append(p)
		_n.append(n)
		_c.append(col)
		_b.append_array([float(_bone), float(_kind), _lc.y, _lc.x])


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(a, b, c, col)
	_tri(a, c, d, col)


## A lathe about the local Y axis through `centre`: `profile` is (radius, y)
## bottom to top, `cols` one colour per band (or one for all). `turn` rotates the
## facets so a rib or a slot can sit on a flat rather than an edge. `lean` is a
## direction the axis leans along, per unit of y.
func _lathe(centre: Vector3, profile: Array, sides: int, cols: Array, turn := 0.0, lean := Vector3.ZERO) -> void:
	for i in profile.size() - 1:
		var p0: Vector2 = profile[i]
		var p1: Vector2 = profile[i + 1]
		var col: Color = cols[mini(i, cols.size() - 1)]
		for s in sides:
			var a0 := turn + TAU * float(s) / float(sides)
			var a1 := turn + TAU * float(s + 1) / float(sides)
			var o0 := centre + Vector3(0.0, p0.y, 0.0) + lean * p0.y
			var o1 := centre + Vector3(0.0, p1.y, 0.0) + lean * p1.y
			var q00 := o0 + Vector3(cos(a0), 0.0, sin(a0)) * p0.x
			var q01 := o0 + Vector3(cos(a1), 0.0, sin(a1)) * p0.x
			var q10 := o1 + Vector3(cos(a0), 0.0, sin(a0)) * p1.x
			var q11 := o1 + Vector3(cos(a1), 0.0, sin(a1)) * p1.x
			# Outward, counter-clockwise from outside: up the seam, across, down.
			if p0.x > 0.0 and p1.x > 0.0:
				_quad(q00, q10, q11, q01, col)
			elif p1.x > 0.0:
				_tri(o0, q10, q11, col)
			elif p0.x > 0.0:
				_tri(q00, o1, q01, col)


## A tapered strut from `a` to `b` in the current bone's frame, `sides` flats.
func _strut(a: Vector3, b: Vector3, r0: float, r1: float, sides: int, col: Color) -> void:
	var y := (b - a).normalized()
	var x := Vector3.UP.cross(y)
	if x.length() < 1e-3:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y)
	var len := a.distance_to(b)
	for s in sides:
		var a0 := TAU * float(s) / float(sides)
		var a1 := TAU * float(s + 1) / float(sides)
		var d0 := x * cos(a0) + z * sin(a0)
		var d1 := x * cos(a1) + z * sin(a1)
		_quad(a + d0 * r0, a + y * len + d0 * r1, a + y * len + d1 * r1, a + d1 * r0, col)
	# Caps, so a strut seen end-on is closed.
	for s in sides:
		var a0 := TAU * float(s) / float(sides)
		var a1 := TAU * float(s + 1) / float(sides)
		var d0 := x * cos(a0) + z * sin(a0)
		var d1 := x * cos(a1) + z * sin(a1)
		_tri(b, b + d1 * r1, b + d0 * r1, col)
		_tri(a, a + d0 * r0, a + d1 * r0, col)


## The hub, its tower and spire, the hip sockets, the ribs and the lens.
func _hub(d: RefCounted) -> void:
	_bone = 0
	var base: float = d.hip_height
	var lo: float = d.hub_low - base
	var hi: float = d.hub_high - base
	var top: float = d.spire_top - base
	var r: float = d.hub_radius
	# Keel, belly, belt and rims: the hull the legs hang from.
	var hull := [
		Vector2(0.0, lo - 400.0), Vector2(260.0, lo - 380.0), Vector2(420.0, lo),
		Vector2(r * 0.42, lo + 500.0), Vector2(r * 0.66, lo + 1200.0), Vector2(r * 0.86, lo + 2000.0),
		Vector2(r * 0.97, -350.0), Vector2(r * 1.04, 0.0), Vector2(r * 1.04, 380.0),
		Vector2(r * 0.95, 520.0), Vector2(r * 0.98, 900.0), Vector2(r * 1.08, 1050.0),
		Vector2(r * 0.90, 1350.0), Vector2(r * 0.78, 1700.0),
	]
	_lathe(Vector3.ZERO, hull, 16, [DARK, DARK, DARK, BODY, BODY, BODY, BODY, RIM, PLATE, BODY, RIM, PLATE, BODY], PI / 16.0)
	# The hub ring: a cold strip round the belt, under the rim.
	_strip(r * 0.97, -420.0, 16, 1.07, 360.0)
	# The tower: plated courses narrowing up to the crown, a collar between each.
	var tower := [Vector2(r * 0.78, 1700.0)]
	var courses := 5
	for i in courses:
		var t0 := float(i) / float(courses)
		var t1 := float(i + 1) / float(courses)
		var y0 := lerpf(1700.0, hi - 600.0, t0)
		var y1 := lerpf(1700.0, hi - 600.0, t1)
		var w0 := lerpf(r * 0.78, r * 0.36, t0)
		var w1 := lerpf(r * 0.78, r * 0.36, t1)
		tower.append(Vector2(w0 * 0.96, y0 + 180.0))
		tower.append(Vector2(w1 * 0.98, y1 - 160.0))
		tower.append(Vector2(w1 * 1.10, y1 - 40.0))
		tower.append(Vector2(w1 * 1.10, y1 + 60.0))
	tower.append(Vector2(r * 0.30, hi - 200.0))
	tower.append(Vector2(r * 0.16, hi))
	var tc: Array = []
	for i in tower.size():
		tc.append(RIM if i % 4 == 3 else BODY)
	_lathe(Vector3.ZERO, tower, 12, tc, PI / 12.0)
	# The spire: to the edge of the air, narrowing to a needle, with collars.
	var spire := [Vector2(r * 0.16, hi), Vector2(420.0, hi + 900.0)]
	for i in 4:
		var y := lerpf(hi + 900.0, top - 1200.0, float(i + 1) / 4.0)
		var w := lerpf(420.0, 60.0, float(i + 1) / 4.0)
		spire.append(Vector2(w, y - 300.0))
		spire.append(Vector2(w * 1.7, y - 120.0))
		spire.append(Vector2(w * 1.7, y))
		spire.append(Vector2(w, y + 160.0))
	spire.append(Vector2(22.0, top - 200.0))
	spire.append(Vector2(0.0, top))
	var sc: Array = []
	for i in spire.size():
		sc.append(PLATE if i % 4 == 2 else BODY)
	_lathe(Vector3.ZERO, spire, 8, sc)
	# A beacon at the top of the air, and one on every spire collar.
	_lamp(2, Vector3(0.0, top - 400.0, 0.0))
	_ball(Vector3(0.0, top - 400.0, 0.0), 140.0, 6, BEACON, BEACON)
	_lamp(0)
	for i in 4:
		var y := lerpf(hi + 900.0, top - 1200.0, float(i + 1) / 4.0)
		var w := lerpf(420.0, 60.0, float(i + 1) / 4.0)
		_strip(w * 1.45, y - 90.0, 8, 1.2, 60.0)
	# Ribs up the tower's flanks, between the hips: the ruled lines that say this
	# was made to a drawing.
	for i in 6:
		var a := TAU * (float(i) + 0.5) / 6.0 + deg_to_rad(float(d.slots[0]))
		var dir := Vector3(cos(a), 0.0, sin(a))
		_strut(dir * (r * 0.95) + Vector3(0.0, 1100.0, 0.0), dir * (r * 0.42) + Vector3(0.0, hi - 800.0, 0.0), 160.0, 70.0, 4, PLATE)
	# The hip sockets: a faceted ball on an outrigger at each slot.
	for k in LEGS:
		var a := deg_to_rad(float(d.slots[k]))
		var dir := Vector3(cos(a), 0.0, sin(a))
		var at := dir * float(d.hip_ring)
		_strut(dir * (r * 0.7) + Vector3(0.0, 300.0, 0.0), at + Vector3(0.0, 200.0, 0.0), 700.0, 520.0, 6, BODY)
		_strut(dir * (r * 0.5) + Vector3(0.0, 1500.0, 0.0), at + Vector3(0.0, 500.0, 0.0), 240.0, 180.0, 4, PLATE)
		_ball(at, 1350.0, 10, BODY, RIM)
	# The lens: one amber eye on the belt, facing the way it walks.
	var eye := [Vector2(0.0, 260.0), Vector2(520.0, 180.0), Vector2(760.0, 40.0), Vector2(800.0, 0.0)]
	_bone = 0
	_lamp(3, Vector3(r * 1.03, 180.0, 0.0))
	_eye(Vector3(r * 1.03, 180.0, 0.0), eye)
	_lamp(0)


## A COLD RING round the local Y axis: a FLANGE standing `proud` of a plate of
## radius `plate` at height `y`, `tall` metres deep, closed underneath (the
## side every eye on the ground sees; the top is never seen and not built). A
## band alone showed only its near half -- the far half is behind the leg -- and
## read as a thin arc; a flange is seen from below as its whole underside, a
## full ellipse of light round the leg. Its outer radius rides in the lamp
## centre's x (CUSTOM0.w), so the shader can keep the ring standing past a leg
## it has widened to a pixel (colossus.gdshader, kind 1).
const STRIP_PROUD := 1.24
const STRIP_TALL := 300.0
func _strip(plate: float, y: float, sides: int, proud := STRIP_PROUD, tall := STRIP_TALL) -> void:
	var w := plate * proud
	var inner := plate * 0.96
	_lamp(1, Vector3(w, y + tall * 0.5, 0.0))
	_lathe(Vector3.ZERO, [Vector2(inner, y), Vector2(w, y), Vector2(w, y + tall)], sides, [STRIP], PI / float(sides))
	_lamp(0)


func _lamp(kind: int, centre := Vector3.ZERO) -> void:
	_kind = kind
	_lc = centre


## A beacon standing proud of the plate at `at`.
func _beacon(at: Vector3, radius: float) -> void:
	_lamp(2, at)
	# A beacon is a point of light: a few facets are all a pixel or two can hold.
	_ball(at, radius, 4, BEACON, BEACON, 2)
	_lamp(0)


## THE THIGH'S MACHINERY (L1), on the thigh's own bone. Where it meets the hip,
## a drive ring: a flange wider than the leg with ribs across it, the thing the
## whole leg turns in. Down its length, cable runs in pairs on the flanks, held
## in clamps every few kilometres. At the knee, the cylinders of the pistons
## that bend it -- their rods are on the shin (`_shin_works`), so the two halves
## slide into each other as the knee opens and closes.
func _thigh_works(d: RefCounted) -> void:
	var l1: float = d.thigh
	var t_r: Vector2 = d.thigh_r
	_lathe(Vector3.ZERO, [Vector2(t_r.x * 1.05, 250.0), Vector2(t_r.x * 1.55, 450.0), Vector2(t_r.x * 1.55, 900.0), Vector2(t_r.x * 1.08, 1100.0)], 16, [RIM, PLATE, BODY], PI / 16.0)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		_strut(dir * t_r.x * 1.5 + Vector3(0.0, 500.0, 0.0), dir * t_r.x * 1.05 + Vector3(0.0, 2600.0, 0.0), 150.0, 90.0, 4, PLATE)
	for side: float in [1.0, -1.0]:
		for off: float in [-0.18, 0.18]:
			var a := side * PI * 0.5 + off
			var dir := Vector3(cos(a), 0.0, sin(a))
			_strut(dir * t_r.x * 1.07 + Vector3(0.0, 1200.0, 0.0), dir * t_r.y * 1.08 + Vector3(0.0, l1 * 0.93, 0.0), 70.0, 60.0, 4, DARK)
		for c in 5:
			var y := lerpf(2500.0, l1 * 0.9, float(c) / 4.0)
			var w := lerpf(t_r.x, t_r.y, y / l1)
			var dir := Vector3(0.0, 0.0, side)
			_strut(dir * w * 0.98 + Vector3(0.0, y - 120.0, 0.0), dir * w * 1.14 + Vector3(0.0, y + 120.0, 0.0), 160.0, 160.0, 4, RIM)
	# Piston cylinders across the knee, on the outer face.
	for off: float in [-0.35, 0.35]:
		var dir := Vector3(cos(off), 0.0, sin(off))
		_strut(dir * t_r.y * 1.25 + Vector3(0.0, l1 * 0.70, 0.0), dir * t_r.y * 1.3 + Vector3(0.0, l1 * 0.985, 0.0), 260.0, 240.0, 6, BODY)
	# The knee's own collar, standing off the ball.
	_lathe(Vector3.ZERO, [Vector2(float(d.knee_r) * 0.9, l1 - 520.0), Vector2(float(d.knee_r) * 1.14, l1 - 380.0), Vector2(float(d.knee_r) * 1.14, l1 - 220.0), Vector2(float(d.knee_r) * 0.9, l1 - 80.0)], 12, [RIM, PLATE, RIM], PI / 12.0)


## THE SHIN'S MACHINERY (L1): the piston rods that meet the thigh's cylinders,
## a flange where it leaves the knee, cable runs down to the ankle, and a cage of
## struts round the ankle block the whole weight comes down through.
func _shin_works(d: RefCounted, shin: Array) -> void:
	var l2: float = d.shin
	var s_r: Vector2 = d.shin_r
	var t_r: Vector2 = d.thigh_r
	for off: float in [-0.35, 0.35]:
		var dir := Vector3(cos(off), 0.0, sin(off))
		_strut(dir * t_r.y * 1.28 + Vector3(0.0, -600.0, 0.0), dir * s_r.x * 1.3 + Vector3(0.0, l2 * 0.22, 0.0), 110.0, 110.0, 4, PLATE)
	_lathe(Vector3.ZERO, [Vector2(s_r.x * 1.02, 300.0), Vector2(s_r.x * 1.4, 480.0), Vector2(s_r.x * 1.4, 800.0), Vector2(s_r.x * 1.03, 980.0)], 12, [RIM, BODY, RIM], PI / 12.0)
	for side: float in [1.0, -1.0]:
		var dir := Vector3(0.0, 0.0, side)
		var top := _radius_near(shin, 1500.0, 300.0)
		var low := _radius_near(shin, l2 * 0.9, 300.0)
		_strut(dir * top * 1.06 + Vector3(0.0, 1500.0, 0.0), dir * low * 1.12 + Vector3(0.0, l2 * 0.9, 0.0), 55.0, 30.0, 4, DARK)
	for i in 6:
		var a := TAU * float(i) / 6.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		_strut(dir * s_r.y * 1.1 + Vector3(0.0, l2 * 0.93, 0.0), dir * s_r.y * 2.2 + Vector3(0.0, l2 - 20.0, 0.0), 24.0, 30.0, 4, PLATE)


## Four beacons round a part at `at` (on its axis), `out` from it: whichever
## side of the leg the player sees, a light is on it.
func _beacons(at: Vector3, out: float, radius: float) -> void:
	for i in 4:
		var a := TAU * float(i) / 4.0
		_beacon(at + Vector3(cos(a), 0.0, sin(a)) * out, radius)


## The widest the lathed `profile` (radius, y) is within `reach` of height `y`,
## counting the straight run between samples, which is what is really drawn.
static func _radius_near(profile: Array, y: float, reach: float) -> float:
	var most := 0.0
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		if b.y < y - reach or a.y > y + reach:
			continue
		most = maxf(most, maxf(a.x, b.x))
	return most


## A faceted ball about `at`: a lathe of a sphere with `sides` flats.
func _ball(at: Vector3, radius: float, sides: int, col: Color, band: Color, rows := 6) -> void:
	var prof: Array = []

	for i in rows + 1:
		var a := -PI * 0.5 + PI * float(i) / float(rows)
		prof.append(Vector2(cos(a) * radius, sin(a) * radius))
	var cols: Array = []
	for i in rows:
		cols.append(band if i == rows / 2 or i == rows / 2 - 1 else col)
	_lathe(at, prof, sides, cols, PI / float(sides))


## The eye: a shallow dome lathed about +X (the heading), set into the belt.
func _eye(at: Vector3, prof: Array) -> void:
	var sides := 12
	for i in prof.size() - 1:
		var p0: Vector2 = prof[i]
		var p1: Vector2 = prof[i + 1]
		for s in sides:
			var a0 := TAU * float(s) / float(sides)
			var a1 := TAU * float(s + 1) / float(sides)
			var q00 := at + Vector3(p0.y, cos(a0) * p0.x, sin(a0) * p0.x)
			var q01 := at + Vector3(p0.y, cos(a1) * p0.x, sin(a1) * p0.x)
			var q10 := at + Vector3(p1.y, cos(a0) * p1.x, sin(a0) * p1.x)
			var q11 := at + Vector3(p1.y, cos(a1) * p1.x, sin(a1) * p1.x)
			var col := LENS if i < prof.size() - 2 else DARK
			if p0.x <= 0.0:
				_tri(q00, q10, q11, col)
			else:
				_quad(q00, q10, q11, q01, col)


## One leg: thigh, knee and shin, and the foot, each on its own bone.
func _leg(d: RefCounted, k: int) -> void:
	var l1: float = d.thigh
	var l2: float = d.shin
	var t_r: Vector2 = d.thigh_r
	var s_r: Vector2 = d.shin_r
	# THIGH (bone 1 + 3k): tapered, with a sleeve at the hip and one mid-way, and
	# a tendon strut along its inner face (local -X is toward the body).
	_bone = 1 + 3 * k
	var thigh: Array = []
	var bands := [0.0, 0.04, 0.07, 0.10, 0.22, 0.36, 0.46, 0.49, 0.53, 0.56, 0.70, 0.84, 0.94, 1.0]
	var cols: Array = []
	for i in bands.size():
		var t: float = bands[i]
		var w := lerpf(t_r.x, t_r.y, t)
		# Sleeves: a band stands proud where two courses of plate meet.
		if i == 2 or i == 8:
			w *= 1.14
		thigh.append(Vector2(w, t * l1))
		cols.append(RIM if i == 1 or i == 7 else (PLATE if i % 3 == 0 else BODY))
	thigh[0] = Vector2(t_r.x * 0.8, 0.0)
	var sides := 12 if _detail else 8
	_lathe(Vector3.ZERO, thigh, sides, cols, PI / float(sides))
	if _detail:
		_thigh_works(d)
	_strut(Vector3(-t_r.x * 1.05, l1 * 0.12, 0.0), Vector3(-t_r.y * 1.1, l1 * 0.86, 0.0), 180.0, 120.0, 4, PLATE)
	# And up the thigh, so the pulse that climbs the shin goes on to the hip.
	for t: float in [0.22, 0.48, 0.74]:
		_strip(_radius_near(thigh, t * l1, 600.0), t * l1, sides)
	# The knee rides the thigh's end.
	_ball(Vector3(0.0, l1, 0.0), float(d.knee_r), 10, BODY, RIM)
	# Beacons down the outer face of the leg: on the knee, and half way down the
	# thigh, so a walker at night is drawn in points of its own light.
	_beacons(Vector3(0.0, l1, 0.0), float(d.knee_r) * 0.97, 200.0)
	_beacons(Vector3(0.0, l1 * 0.5, 0.0), lerpf(t_r.x, t_r.y, 0.5) * 1.02, 160.0)
	# SHIN (bone 2 + 3k): long, narrowing to the ankle, ringed densest near the
	# ground where the air thickens fastest.
	_bone = 2 + 3 * k
	var shin: Array = []
	var sc: Array = []
	var n := 18
	for i in n + 1:
		var t := 1.0 - pow(1.0 - float(i) / float(n), 1.6)
		var w := lerpf(s_r.x, s_r.y, pow(t, 0.8))
		if i == 3 or i == 9:
			w *= 1.18
		shin.append(Vector2(w, t * l2))
		sc.append(RIM if i == 2 or i == 8 else (PLATE if i % 4 == 0 else BODY))
	_lathe(Vector3.ZERO, shin, sides, sc, PI / float(sides))
	if _detail:
		_shin_works(d, shin)
	# Cold rings up the shin, the plan's own light running up the leg at night,
	# densest toward the ground where a person stands under them. Set to the plate
	# the profile really draws there, sleeves included (`_radius_near`), or a
	# ring sits inside a sleeve's chord and is never seen.
	for t: float in [0.14, 0.34, 0.54, 0.72, 0.88]:
		_strip(_radius_near(shin, t * l2, 400.0), t * l2, sides)
	_beacons(Vector3(0.0, l2 * 0.965, 0.0), s_r.y * 1.4, 110.0)
	# FOOT (bone 3 + 3k): the ankle block, its arch, and three toes on pads.
	_bone = 3 + 3 * k
	var up: float = d.ankle_up
	_lathe(Vector3.ZERO, [Vector2(s_r.y * 1.05, 0.0), Vector2(s_r.y * 1.3, -30.0), Vector2(s_r.y * 1.25, -60.0), Vector2(s_r.y * 0.7, -up * 0.55)], 6, [PLATE, BODY, DARK], PI / 6.0)
	var reach: float = d.toe_reach
	var pad: float = d.pad
	for toe in 3:
		var a := TAU * float(toe) / 3.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var knuckle := dir * (reach * 0.45) + Vector3(0.0, -up * 0.35, 0.0)
		var tip := dir * reach + Vector3(0.0, -up + pad * 0.5, 0.0)
		_strut(Vector3(0.0, -up * 0.3, 0.0), knuckle, 34.0, 26.0, 4, BODY)
		_strut(knuckle, tip, 26.0, 18.0, 4, BODY)
		_lathe(tip + Vector3(0.0, -pad * 0.5, 0.0), [Vector2(0.0, 0.0), Vector2(pad, 0.0), Vector2(pad * 0.8, pad * 0.6), Vector2(0.0, pad * 0.7)], 6, [DARK])
