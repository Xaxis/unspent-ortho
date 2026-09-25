extends Node3D
## THE BUNKER UNDER THE CAST STONES, drawn (docs/interiors; the recipe that says
## where everything stands is src/content/interiors/bunker.gd). People made all
## of it, so it is MADE: poured concrete with the lower half painted the flat
## institutional green such places were painted, steel doors and frames painted
## grey, the tech of 2029 -- a terminal, a rack of servers, a whiteboard -- gone
## dark and stayed where it was left. Paper on the floor. It is lit by the
## emergency lamps still running on their batteries, and by whatever the player
## brought down with them.
##
## It answers the calls a cottage's model does (21_doors reads them): `build`,
## `show_for`, `windows` (none: it is underground), `daylight` (nothing to
## colour), and `lights`, the emergency lamps and the rack's standby light.

const Kit := preload("res://src/models/props/kit.gd")
const THICK := 0.3
const DIRS: Array[Vector2] = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
## The floor stands this far proud of the pocket's own terrain, which lies at
## exactly `floor_y` (laid level with it, the two fight: weapons_hall_model).
const DECK_TOP := 0.035

var layout: InteriorLayout
var kind: InteriorKind
var floor_y := 1.0
var _full: Array[MeshInstance3D] = []
var _cut: Array[MeshInstance3D] = []
var _ceiling: MeshInstance3D
## Where the bunker's own lights hang ([position, &"emergency" | &"standby"]).
var lights: Array[Array] = []

# The palette of the place: poured and painted by people, then left.
var concrete := GroundColors.made(Color(0.5, 0.49, 0.46), GroundColors.CONCRETE)
var concrete_dark := GroundColors.made(Color(0.34, 0.34, 0.32), GroundColors.CONCRETE)
var paint := GroundColors.made(Color(0.36, 0.44, 0.38), GroundColors.ENAMEL)
var paint_band := GroundColors.made(Color(0.22, 0.28, 0.24), GroundColors.ENAMEL)
var steel := GroundColors.made(Color(0.36, 0.38, 0.39), GroundColors.ENAMEL)
var steel_dark := GroundColors.made(Color(0.18, 0.19, 0.2), GroundColors.TAR)
var rust := GroundColors.made(Color(0.4, 0.22, 0.13), GroundColors.TAR)
var paper := GroundColors.made(Color(0.78, 0.76, 0.7), GroundColors.CLOTH)
var screen := GroundColors.made(Color(0.04, 0.05, 0.06), GroundColors.GLASS)
var canvas := GroundColors.made(Color(0.36, 0.38, 0.3), GroundColors.CLOTH)


func build(l: InteriorLayout, k: InteriorKind, _land: int, mat: Material) -> void:
	layout = l
	kind = k
	floor_y = TerrainMesher.level_height(InteriorGen.FLOOR_LEVEL)
	for i in DIRS.size():
		var full := Kit.new()
		var cut := Kit.new()
		for e: Dictionary in l.edges:
			if not (e.out as Vector2).is_equal_approx(DIRS[i]):
				continue
			_edge(full, e, k.wall_h, false)
			_edge(cut, e, k.cut, true)
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


func show_for(back: Vector2, over: float) -> void:
	var whole := over > 0.5
	for i in DIRS.size():
		var drawn := whole or not DIRS[i].dot(back) > 0.2
		_full[i].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if drawn \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_cut[i].visible = not drawn
	_ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if whole \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


func windows() -> Array[Array]:
	return []


func daylight(_sky: Color, _land: Color) -> void:
	pass


func _mesh(k: Kit, mat: Material, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = k.made.build()
	mi.material_override = mat
	add_child(mi)
	return mi


func _v(p: Vector2, h: float) -> Vector3:
	return Vector3(p.x, floor_y + h, p.y)


## A quad on a wall's inner face, `lift` proud of it, from `u0` to `u1` along
## the wall and `h0` to `h1` up it. Wound to face the room.
func _on_wall(k: Kit, e: Dictionary, u0: float, u1: float, h0: float, h1: float, col: Color, lift: float) -> void:
	var out: Vector2 = e.out
	var mid: Vector2 = ((e.a as Vector2) + (e.b as Vector2)) * 0.5
	var f := -out
	var s := Vector2(-f.y, f.x)
	var q := mid - out * (THICK * 0.5 + lift)
	var pa := q + s * u0
	var pb := q + s * u1
	k.made.quad(Vector3(pa.x, floor_y + h0, pa.y), Vector3(pa.x, floor_y + h1, pa.y),
		Vector3(pb.x, floor_y + h1, pb.y), Vector3(pb.x, floor_y + h0, pb.y), col)


# --- walls ---------------------------------------------------------------------

## A unit of wall: poured concrete, the lower half painted and a dark band at
## the paint's edge, a cable tray along the top. A doorway is a steel frame in
## the concrete; the way in is the foot of the stair. Cut, it stops at `h`.
func _edge(k: Kit, e: Dictionary, h: float, cut: bool) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var mid := (a + b) * 0.5
	var along := (b - a).normalized()
	var sx := absf(along.x) * (1.0 + THICK) + absf(along.y) * THICK
	var sz := absf(along.y) * (1.0 + THICK) + absf(along.x) * THICK
	var top := steel_dark if cut else concrete
	var sd := int(mid.x * 7.0 + mid.y * 13.0)
	match e.kind:
		&"door", &"inner":
			var head := minf(2.1, h)
			for p: Vector2 in [a + along * 0.1, b - along * 0.1]:
				k.slab(p.x, floor_y, p.y, 0.14 if absf(along.x) > 0.5 else THICK * 1.3, head, THICK * 1.3 if absf(along.x) > 0.5 else 0.14, sd, steel, steel_dark if cut else steel, 0.0)
			if not cut:
				k.slab(mid.x, floor_y + 2.1, mid.y, sx, h - 2.1, sz, sd + 1, concrete, concrete, 0.01)
				k.slab(mid.x, floor_y + 1.98, mid.y, sx * 0.98 if absf(along.x) > 0.5 else THICK * 1.3, 0.14,
					sz * 0.98 if absf(along.y) > 0.5 else THICK * 1.3, sd + 2, steel, steel, 0.0)
			if e.kind == &"door":
				_stair(k, e)
			return
	k.slab(mid.x, floor_y, mid.y, sx, h, sz, sd, concrete, top, 0.01)
	if e.inner:
		return
	# The painted lower half, its dark edge, and the stains where water came in.
	var paint_h := minf(1.15, h)
	_on_wall(k, e, -0.5, 0.5, 0.0, paint_h, paint, 0.003)
	if h > 1.2:
		_on_wall(k, e, -0.5, 0.5, 1.12, 1.2, paint_band, 0.005)
	if (sd & 3) == 0 and h > 2.0:
		var st := 0.1 + 0.6 * float((sd >> 3) & 7) / 7.0 - 0.5
		_on_wall(k, e, st - 0.06, st + 0.08, 0.4, h - 0.15, GroundColors.made(Color(0.36, 0.33, 0.28), GroundColors.CONCRETE), 0.006)
	# The cable tray along the top.
	if not cut and h > 2.3:
		var f := -(e.out as Vector2)
		var run := mid + f * (THICK * 0.5 + 0.08)
		k.slab(run.x, floor_y + h - 0.32, run.y, sx if absf(along.x) > 0.5 else 0.14, 0.06, sz if absf(along.y) > 0.5 else 0.14, sd + 5, steel_dark, steel_dark, 0.0)


## The way up: a stairwell beyond the door, climbing into the dark toward the
## hatch, walled and roofed in the same concrete -- so the way out reads as a
## stair and not as a hole onto whatever lies outside a pocket.
func _stair(k: Kit, e: Dictionary) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var o: Vector2 = e.out
	var along := (b - a).normalized()
	var mid := (a + b) * 0.5
	var wide := 0.9
	for n in 8:
		var c := mid + o * (THICK * 0.5 + 0.2 + 0.3 * float(n))
		var sx := absf(along.x) * wide + absf(o.x) * 0.3
		var sz := absf(along.y) * wide + absf(o.y) * 0.3
		k.slab(c.x, floor_y, c.y, sx, 0.02 + 0.28 * float(n + 1), sz, 140 + n, concrete_dark, concrete if n % 2 == 0 else concrete_dark, 0.004)
	var deep := 0.2 + 0.3 * 8.0
	var well := mid + o * (THICK * 0.5 + deep * 0.5)
	for side: float in [-1.0, 1.0]:
		var w := well + along * side * (wide * 0.5 + 0.12)
		k.slab(w.x, floor_y, w.y, absf(along.x) * 0.24 + absf(o.x) * deep, kind.wall_h, absf(along.y) * 0.24 + absf(o.y) * deep, 150, concrete, concrete, 0.01)
	var roof := mid + o * (THICK * 0.5 + deep * 0.5)
	k.made.box(Vector3(roof.x - (absf(along.x) * 0.7 + absf(o.x) * deep * 0.5), floor_y + 2.4, roof.y - (absf(along.y) * 0.7 + absf(o.y) * deep * 0.5)),
		Vector3(roof.x + (absf(along.x) * 0.7 + absf(o.x) * deep * 0.5), floor_y + 2.7, roof.y + (absf(along.y) * 0.7 + absf(o.y) * deep * 0.5)), concrete_dark, concrete_dark, true)
	var end := mid + o * (THICK * 0.5 + deep + 0.1)
	k.slab(end.x, floor_y, end.y, absf(along.x) * 1.2 + absf(o.x) * 0.2, kind.wall_h, absf(along.y) * 1.2 + absf(o.y) * 0.2, 151, concrete_dark, concrete_dark, 0.0)


# --- the floor and the roof -----------------------------------------------------

## Poured floor in bays, proud of the terrain, and paper where it fell.
func _floor(k: Kit) -> void:
	for r: Rect2i in layout.rooms:
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var h := Rng.hash_ints(x, y, 0xB0F)
				var col := concrete_dark if (h & 7) != 0 else GroundColors.made(Color(0.3, 0.3, 0.28), GroundColors.CONCRETE)
				k.slab(x + 0.5, floor_y, y + 0.5, 0.99, DECK_TOP, 0.99, h, col, col, 0.0)
				# Paper, here and there, lying where it fell.
				if (h >> 4) % 5 == 0:
					var px := x + 0.2 + 0.6 * float((h >> 8) & 255) / 255.0
					var pz := y + 0.2 + 0.6 * float((h >> 16) & 255) / 255.0
					k.slab(px, floor_y + DECK_TOP, pz, 0.21, 0.004, 0.29, h, paper, paper, 0.01, 0.0, 0.0)
		# The seams between the pours, dark under them.
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		var bed := GroundColors.made(Color(0.12, 0.12, 0.12), GroundColors.CONCRETE)
		k.slab((lo.x + hi.x) * 0.5, floor_y, (lo.y + hi.y) * 0.5, hi.x - lo.x, 0.02, hi.y - lo.y, 5, bed, bed, 0.0)


## A poured ceiling with its underside, low, and a conduit down the corridor.
func _roof(k: Kit, h: float) -> void:
	var y := floor_y + h
	for r: Rect2i in layout.rooms:
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		k.made.box(Vector3(lo.x, y, lo.y), Vector3(hi.x, y + 0.25, hi.y), concrete_dark, concrete_dark, true)


# --- what was left down here ---------------------------------------------------

func _thing(k: Kit, t: Dictionary) -> void:
	var at: Vector2 = t.at
	var f: Vector2 = t.face
	match t.kind:
		&"cot": _cot(k, at, f)
		&"locker": _locker(k, at, f)
		&"desk": _desk(k, at, f)
		&"whiteboard": _whiteboard(k, at, f)
		&"server_rack": _server_rack(k, at, f)
		&"cabinet": _cabinet(k, at, f)
		&"strongbox": _footlocker(k, at, f)
		&"vault_door": _vault_door(k, at, f)
		&"generator": _generator(k, at, f)
		&"drum": _drum(k, at)
		&"elamp": _elamp(k, at, f)
		&"tube": _tube(k, at)


func _p(at: Vector2, f: Vector2, u: float, v: float, h: float) -> Vector3:
	var s := Vector2(-f.y, f.x)
	var q := at + s * u + f * v
	return Vector3(q.x, floor_y + DECK_TOP + h, q.y)


func _block(k: Kit, at: Vector2, f: Vector2, u: float, v: float, h: float, wu: float, dv: float, hh: float, col: Color, sd: int, top := Color(0, 0, 0, 0)) -> void:
	var c := _p(at, f, u, v, h)
	var sx := wu if absf(f.y) > 0.5 else dv
	var sz := dv if absf(f.y) > 0.5 else wu
	k.slab(c.x, c.y, c.z, sx, hh, sz, sd, col, top, 0.006)


## A steel cot along the wall, the blanket thrown back, the pillow gone flat.
func _cot(k: Kit, at: Vector2, f: Vector2) -> void:
	for u: float in [-0.9, 0.9]:
		for v: float in [-0.35, 0.35]:
			_block(k, at, f, u, v, 0.0, 0.05, 0.05, 0.4, steel, 1)
	_block(k, at, f, 0.0, 0.0, 0.36, 1.9, 0.8, 0.06, steel, 2)
	_block(k, at, f, 0.0, 0.0, 0.42, 1.84, 0.74, 0.1, canvas, 3)
	_block(k, at, f, 0.25, 0.04, 0.5, 1.1, 0.78, 0.05, GroundColors.made(Color(0.3, 0.33, 0.36), GroundColors.CLOTH), 4)
	_block(k, at, f, -0.75, 0.0, 0.52, 0.3, 0.5, 0.06, paper, 5)


## A tall steel locker, one door hanging open.
func _locker(k: Kit, at: Vector2, f: Vector2) -> void:
	_block(k, at, f, 0.0, -0.05, 0.0, 0.6, 0.45, 1.9, steel, 7, steel_dark)
	_block(k, at, f, 0.0, 0.18, 0.1, 0.02, 0.02, 1.7, steel_dark, 8)
	var hinge := _p(at, f, 0.3, 0.18, 0.1)
	var s := Vector3(-f.y, 0.0, f.x)
	var out := Vector3(f.x, 0.0, f.y)
	var tip := hinge + (s * 0.1 + out * 0.28)
	k.made.quad(hinge, hinge + Vector3.UP * 1.7, tip + Vector3.UP * 1.7, tip, steel)
	k.made.quad(tip, tip + Vector3.UP * 1.7, hinge + Vector3.UP * 1.7, hinge, steel)


## A steel desk, the terminal on it dark, a chair pushed back and fallen.
func _desk(k: Kit, at: Vector2, f: Vector2) -> void:
	_block(k, at, f, 0.0, -0.05, 0.72, 1.4, 0.7, 0.05, steel, 11)
	for u: float in [-0.62, 0.62]:
		_block(k, at, f, u, -0.05, 0.0, 0.1, 0.62, 0.72, steel_dark, 12)
	# The terminal: a flat screen gone black, its stand, a keyboard, a mug.
	_block(k, at, f, 0.0, -0.22, 0.77, 0.16, 0.12, 0.2, steel_dark, 13)
	_block(k, at, f, 0.0, -0.2, 0.95, 0.72, 0.04, 0.44, steel_dark, 14)
	_block(k, at, f, 0.0, -0.175, 1.0, 0.64, 0.01, 0.34, screen, 15)
	_block(k, at, f, 0.0, 0.14, 0.77, 0.46, 0.16, 0.025, steel_dark, 16)
	var mug := _p(at, f, 0.5, 0.1, 0.77)
	k.limb(mug, mug + Vector3.UP * 0.1, 0.04, 0.04, 7, GroundColors.made(Color(0.62, 0.6, 0.55), GroundColors.CLAY))
	# Paper stacked and spilled.
	for n in 3:
		_block(k, at, f, -0.45 + 0.12 * float(n), 0.1, 0.77 + 0.004 * float(n), 0.22, 0.3, 0.004, paper, 17 + n)
	# The chair, on its side where it went over.
	var c := _p(at, f, 0.2, 0.8, 0.0)
	k.slab(c.x, c.y, c.z, 0.46, 0.06, 0.46, 20, steel_dark, steel_dark, 0.0)
	k.slab(c.x + f.x * 0.25, c.y, c.z + f.y * 0.25, 0.46 if absf(f.y) > 0.5 else 0.05, 0.42, 0.05 if absf(f.y) > 0.5 else 0.46, 21, canvas, canvas, 0.0)


## A whiteboard on the wall, written over in a hand that got faster.
func _whiteboard(k: Kit, at: Vector2, f: Vector2) -> void:
	var board := GroundColors.made(Color(0.84, 0.84, 0.8), GroundColors.ENAMEL)
	var ink := GroundColors.made(Color(0.1, 0.12, 0.2), GroundColors.ENAMEL)
	var back := 0.4 - THICK * 0.5 - 0.02
	_block(k, at, f, 0.0, -back, 1.0, 1.5, 0.03, 0.9, steel, 25)
	_block(k, at, f, 0.0, -back + 0.02, 1.04, 1.42, 0.01, 0.82, board, 26)
	var sd := int(at.x * 13.0 + at.y * 7.0)
	for n in 7:
		var y := 1.12 + 0.1 * float(n)
		var run := 0.4 + 0.8 * float((sd >> n) & 7) / 7.0
		_block(k, at, f, -0.62 + run * 0.5, -back + 0.03, y, run, 0.005, 0.02, ink, 27 + n)
	# A box drawn round one line, and an arrow out of it: the thing that mattered.
	_block(k, at, f, 0.3, -back + 0.03, 1.5, 0.5, 0.005, 0.015, ink, 40)
	_block(k, at, f, 0.3, -back + 0.03, 1.66, 0.5, 0.005, 0.015, ink, 41)


## A rack of servers gone dark, one standby light still burning on it.
func _server_rack(k: Kit, at: Vector2, f: Vector2) -> void:
	_block(k, at, f, 0.0, -0.05, 0.0, 0.62, 0.62, 2.0, steel_dark, 50, steel_dark)
	for n in 8:
		_block(k, at, f, 0.0, 0.265, 0.2 + 0.22 * float(n), 0.54, 0.01, 0.16, GroundColors.made(Color(0.12, 0.13, 0.14), GroundColors.TAR), 51 + n)
	var led := _p(at, f, 0.22, 0.28, 1.32)
	var glow := GroundColors.marked(Color(1.0, 0.62, 0.2), GroundColors.GLOW + 6)
	k.slab(led.x, led.y, led.z, 0.03, 0.03, 0.03, 60, glow, glow, 0.0)
	lights.append([led + Vector3(f.x, 0.0, f.y) * 0.2, &"standby"])


## A steel filing cabinet, a drawer pulled out.
func _cabinet(k: Kit, at: Vector2, f: Vector2) -> void:
	_block(k, at, f, 0.0, -0.05, 0.0, 0.5, 0.6, 1.3, steel, 70, steel_dark)
	for n in 4:
		_block(k, at, f, 0.0, 0.255, 0.1 + 0.3 * float(n), 0.42, 0.01, 0.24, steel_dark, 71 + n)
	var sd := int(at.x * 5.0 + at.y * 11.0)
	var d := float(sd % 4)
	_block(k, at, f, 0.0, 0.45, 0.12 + 0.3 * d, 0.44, 0.35, 0.22, steel, 80)
	_block(k, at, f, 0.0, 0.45, 0.32 + 0.3 * d, 0.38, 0.3, 0.02, paper, 81)


## A footlocker, strapped, pushed against the wall: what was kept.
func _footlocker(k: Kit, at: Vector2, f: Vector2) -> void:
	_block(k, at, f, 0.0, 0.0, 0.0, 0.9, 0.5, 0.42, GroundColors.made(Color(0.24, 0.28, 0.22), GroundColors.ENAMEL), 90, GroundColors.made(Color(0.28, 0.32, 0.26), GroundColors.ENAMEL))
	for u: float in [-0.28, 0.28]:
		_block(k, at, f, u, 0.0, 0.0, 0.05, 0.52, 0.44, steel_dark, 91)


## The sealed door in the records room's back wall: heavier than anything else
## down here, a wheel on it, and the way further down behind it, shut.
func _vault_door(k: Kit, at: Vector2, f: Vector2) -> void:
	var back := 0.4 - THICK * 0.5 - 0.02
	_block(k, at, f, 0.0, -back, 0.0, 1.3, 0.1, 2.05, steel_dark, 100)
	_block(k, at, f, 0.0, -back + 0.06, 0.1, 1.1, 0.06, 1.85, steel, 101)
	var c := _p(at, f, 0.0, -back + 0.14, 1.05)
	k.made.strut(c + Vector3.UP * 0.26, c - Vector3.UP * 0.26, 0.025, 6, steel_dark)
	var s := Vector3(-f.y, 0.0, f.x)
	k.made.strut(c + s * 0.26, c - s * 0.26, 0.025, 6, steel_dark)
	for n in 12:
		var a := TAU * float(n) / 12.0
		var b := TAU * float(n + 1) / 12.0
		k.made.strut(c + (s * cos(a) + Vector3.UP * sin(a)) * 0.28, c + (s * cos(b) + Vector3.UP * sin(b)) * 0.28, 0.022, 4, steel_dark)
	# Rust in the seam at its foot, where water stood.
	_block(k, at, f, 0.0, -back + 0.1, 0.0, 1.2, 0.02, 0.18, rust, 102)


## A diesel generator, cold, its fuel line off.
func _generator(k: Kit, at: Vector2, f: Vector2) -> void:
	_block(k, at, f, 0.0, 0.0, 0.0, 1.3, 0.8, 0.12, steel_dark, 110)
	_block(k, at, f, -0.15, 0.0, 0.12, 0.9, 0.62, 0.7, GroundColors.made(Color(0.4, 0.34, 0.2), GroundColors.ENAMEL), 111, steel)
	_block(k, at, f, 0.45, 0.0, 0.12, 0.3, 0.5, 0.5, steel, 112)
	var ex := _p(at, f, -0.4, 0.0, 0.82)
	k.made.strut(ex, ex + Vector3.UP * 0.9, 0.05, 6, rust)


func _drum(k: Kit, at: Vector2) -> void:
	var c := Vector3(at.x, floor_y + DECK_TOP, at.y)
	k.limb(c, c + Vector3.UP * 0.86, 0.28, 0.28, 10, GroundColors.made(Color(0.42, 0.14, 0.1), GroundColors.ENAMEL))
	k.made.strut(c + Vector3.UP * 0.3 + Vector3(0.285, 0.0, 0.0), c + Vector3.UP * 0.3 + Vector3(-0.285, 0.0, 0.0), 0.01, 3, rust)


## An emergency lamp on the wall, caged, still running on its battery: the light
## the bunker has, dim and warm. A lamp the renderer lights, and a light of its
## own (21_doors, `&"emergency"`).
func _elamp(k: Kit, at: Vector2, f: Vector2) -> void:
	var back := 0.4 - THICK * 0.5 - 0.02
	var c := _p(at, f, 0.0, -back + 0.06, 2.0)
	k.slab(c.x, c.y - 0.06, c.z, 0.26 if absf(f.y) > 0.5 else 0.1, 0.14, 0.1 if absf(f.y) > 0.5 else 0.26, 120, steel_dark, steel_dark, 0.0)
	var lamp := GroundColors.marked(Color(1.0, 0.56, 0.3), GroundColors.GLOW + 5)
	var l := c + Vector3(f.x, 0.0, f.y) * 0.07
	k.slab(l.x, l.y - 0.04, l.z, 0.16 if absf(f.y) > 0.5 else 0.05, 0.08, 0.05 if absf(f.y) > 0.5 else 0.16, 121, lamp, lamp, 0.0)
	lights.append([l + Vector3(f.x, 0.0, f.y) * 0.15, &"emergency"])


## A strip light in the ceiling, dead.
func _tube(k: Kit, at: Vector2) -> void:
	var y := floor_y + kind.wall_h - 0.12
	k.slab(at.x, y - 0.02, at.y, 0.14, 0.06, 1.2, 130, steel, steel, 0.0)
	k.slab(at.x, y - 0.05, at.y, 0.06, 0.03, 1.1, 131, GroundColors.made(Color(0.62, 0.64, 0.62), GroundColors.GLASS), paper, 0.0)
