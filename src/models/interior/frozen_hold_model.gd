extends "res://src/models/interior/cottage_model.gd"
## THE FROZEN HOLD, drawn (the recipe is src/content/interiors/frozen_hold.gd).
## A cottage's bones made a ship's: the walls are her tarred planking with a
## frame at every unit, rimed white; the ice has come in through her seams along
## the low side in a bank against the planks and hangs from the deck beams over
## it. The galley stove, cold iron, its pipe up through the deck; the crew's
## table with its fiddle rails and the mugs frozen where they were set down; the
## fish room's boxes, iced into one block; the bunks forward, and the board over
## them. Down the middle, the machines' cable: from a clamp under the deck, taut,
## straight down into a hole cut through her bottom, black water in it, a skin
## of new ice at its rim, and on the frame beside it their panel.
##
## THE STOVE LIGHTS (`stove_lit`, called by 21_doors when it is fed or found
## lit): its grate glows and a warm light fills the hold from it.

var tar: Color
var rime: Color
var ice: Color
var iron: Color
var black_water: Color
var plank: Color
var _stoves: Array[Node3D] = []
var _stove_glow: Array[MeshKit] = []


func build(l: InteriorLayout, k: InteriorKind, land: int, mat: Material) -> void:
	tar = GroundColors.made(Color(0.16, 0.13, 0.11), GroundColors.TIMBER)
	plank = GroundColors.made(Color(0.3, 0.24, 0.19), GroundColors.TIMBER)
	rime = GroundColors.made(Color(0.82, 0.86, 0.9), GroundColors.CLOTH)
	ice = GroundColors.made(Color(0.62, 0.74, 0.82), GroundColors.GLASS)
	iron = GroundColors.made(Color(0.14, 0.14, 0.15), GroundColors.ENAMEL)
	black_water = GroundColors.made(Color(0.02, 0.03, 0.04), GroundColors.GLASS)
	super.build(l, k, land, mat)
	for i in _stoves.size():
		var n := _stoves[i]
		var mi := MeshInstance3D.new()
		mi.mesh = _stove_glow[i].build()
		mi.material_override = mat
		n.add_child(mi)
		n.name = "stove_fire_%d" % i
		n.visible = false
		add_child(n)


## Lit: the grate glows and the hold is warm with it.
func stove_lit(i: int) -> void:
	if i >= 0 and i < _stoves.size():
		_stoves[i].visible = true


func _wear(_k: Kit, _e: Dictionary, _infill: Color, _h: float) -> void:
	pass


func _breast(_k: Kit, _h: float, _stone: Color, _top: Color) -> void:
	pass


func _soot(_k: Kit, _h: float) -> void:
	pass


func _hearth_base(_k: Kit, _stone: Color) -> void:
	pass


## Her side: tarred planks the wall's height, the seams between them ruled
## dark, a frame standing proud at the unit's end, and rime up the lower planks.
func _edge(k: Kit, e: Dictionary, h: float, infill: Color, frame: Color, top: Color, cut: bool) -> void:
	if e.kind != &"wall":
		super._edge(k, e, h, infill, frame, top, cut)
		return
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var out: Vector2 = e.out
	var mid := (a + b) * 0.5
	var along := (b - a).normalized()
	var w := 1.0 + THICK
	var sx := absf(along.x) * w + absf(along.y) * THICK
	var sz := absf(along.y) * w + absf(along.x) * THICK
	var sd := int(mid.x * 7.0 + mid.y * 13.0)
	k.slab(mid.x, floor_y, mid.y, sx, h, sz, sd, plank, top, 0.01)
	var seam := GroundColors.made(Color(0.07, 0.06, 0.05), GroundColors.TAR)
	var y := 0.24
	while y < h - 0.05:
		_on_wall(k, mid, out, -0.5, 0.5, y, y + 0.014, seam, 0.004)
		y += 0.24
	_on_wall(k, mid, out, -0.5, 0.5, 0.0, 0.35 + 0.25 * float(sd & 3) / 3.0, rime, 0.006)
	var rib := a - out * (THICK * 0.5 + 0.07)
	k.slab(rib.x, floor_y, rib.y, 0.14, h, 0.14, sd + 5, tar, top, 0.01)


func _boards(k: Kit, l: InteriorLayout, dress: BiomeDressing) -> void:
	super._boards(k, l, dress)
	for t: Dictionary in l.things:
		var at: Vector2 = t.at
		var f: Vector2 = t.face
		match t.kind:
			&"stove": _stove(k, at, f)
			&"galley_table": _galley_table(k, at, f, float(t.long))
			&"sounding_well": _sounding_well(k, at, float(t.solid))
			&"cable_panel": _cable_panel(k, at, f)
			&"fish_boxes": _fish_boxes(k, at, f)
			&"ice_seam": _ice_seam(k, at, f, float(t.long))
			&"bunk": _bunk(k, at, f)
			&"bunk_board": _bunk_board(k, at, f)
			&"strongbox": _sea_chest(k, at, f)


func _q(at: Vector2, f: Vector2, u: float, v: float, h: float) -> Vector3:
	var s := Vector2(-f.y, f.x)
	var p := at + s * u + f * v
	return Vector3(p.x, floor_y + h, p.y)


func _box(pen: MeshKit, at: Vector2, f: Vector2, u0: float, u1: float, v0: float, v1: float, h0: float, h1: float, col: Color, top := Color(0, 0, 0, 0)) -> void:
	var a := _q(at, f, u0, v0, h0)
	var b := _q(at, f, u1, v1, h1)
	pen.box(Vector3(minf(a.x, b.x), a.y, minf(a.z, b.z)), Vector3(maxf(a.x, b.x), b.y, maxf(a.z, b.z)), col, top)


## The galley stove: an iron box on feet, its hob, the grate in its door, a
## kettle left on it, and the pipe up through the deck. Its fire is its own
## node, shown when it is lit.
func _stove(k: Kit, at: Vector2, f: Vector2) -> void:
	for u: float in [-0.3, 0.3]:
		for v: float in [-0.22, 0.22]:
			_box(k.made, at, f, u - 0.04, u + 0.04, v - 0.04, v + 0.04, 0.0, 0.14, iron)
	_box(k.made, at, f, -0.38, 0.38, -0.3, 0.3, 0.14, 0.78, iron, GroundColors.made(Color(0.22, 0.21, 0.22), GroundColors.ENAMEL))
	_box(k.made, at, f, -0.2, 0.2, 0.3, 0.32, 0.26, 0.5, GroundColors.made(Color(0.05, 0.05, 0.05), GroundColors.TAR))
	var kettle := _q(at, f, 0.14, -0.05, 0.78)
	k.made.prism(kettle.x, kettle.y, kettle.z, 0.11, kettle.y + 0.16, 0.08, 10, iron, iron)
	var pipe := _q(at, f, -0.2, -0.12, 0.78)
	k.made.strut(pipe, Vector3(pipe.x, floor_y + kind.wall_h, pipe.z), 0.07, 8, iron)
	# Rime on the cold iron, as on everything.
	_box(k.made, at, f, -0.36, 0.36, -0.28, 0.28, 0.78, 0.79, rime)
	var fire := Node3D.new()
	var glow := MeshKit.new()
	var g := GroundColors.glow(Color(1.0, 0.5, 0.16), 2.2)
	var a := _q(at, f, -0.18, 0.325, 0.28)
	var b := _q(at, f, 0.18, 0.335, 0.48)
	glow.box(Vector3(minf(a.x, b.x), a.y, minf(a.z, b.z)), Vector3(maxf(a.x, b.x), b.y, maxf(a.z, b.z)), g)
	_stove_glow.append(glow)
	var o := OmniLight3D.new()
	o.position = _q(at, f, 0.0, 0.7, 0.6)
	o.light_color = Color(1.0, 0.62, 0.3)
	o.light_energy = 1.8
	o.omni_range = 5.5
	o.omni_attenuation = 1.1
	o.shadow_enabled = false
	fire.add_child(o)
	_stoves.append(fire)


## The crew's table, bolted down, with fiddle rails round it, and the mugs
## frozen to it where they were set down.
func _galley_table(k: Kit, at: Vector2, f: Vector2, long: float) -> void:
	var half := long * 0.5
	for u: float in [-half + 0.08, half - 0.08]:
		_box(k.made, at, f, u - 0.05, u + 0.05, -0.05, 0.05, 0.0, 0.72, tar)
	_box(k.made, at, f, -half, half, -0.35, 0.35, 0.72, 0.76, plank, plank)
	for v: float in [-0.35, 0.35]:
		_box(k.made, at, f, -half, half, v - 0.015, v + 0.015, 0.76, 0.81, tar)
	for u: float in [-0.35, 0.1, 0.4]:
		var c := _q(at, f, u, 0.1 * signf(u), 0.76)
		k.made.prism(c.x, c.y, c.z, 0.045, c.y + 0.1, 0.05, 8, GroundColors.made(Color(0.66, 0.66, 0.62), GroundColors.ENAMEL), rime)
	# A bench along it.
	_box(k.made, at, f, -half, half, 0.55, 0.8, 0.0, 0.44, plank, plank)


## The well: a ragged hole cut through her bottom, black water in it, new ice at
## its rim, and the cable taut from a clamp under the deck straight down into it.
func _sounding_well(k: Kit, at: Vector2, r: float) -> void:
	k.made.prism(at.x, floor_y - 0.2, at.y, r * 0.86, floor_y + 0.02, r * 0.86, 14, black_water, black_water)
	for i in 14:
		var h := Rng.hash_ints(i, 0x3E11)
		var ang := TAU * float(i) / 14.0
		var p := at + Vector2.from_angle(ang) * r * 0.92
		k.slab(p.x, floor_y, p.y, 0.26 + 0.12 * float(h & 3) / 3.0, 0.05 + 0.06 * float((h >> 2) & 3) / 3.0, 0.18, h, ice, rime, 0.02)
	var top := Vector3(at.x, floor_y + kind.wall_h, at.y)
	k.made.strut(top, Vector3(at.x, floor_y - 0.6, at.y), 0.035, 6, GroundColors.made(Color(0.06, 0.06, 0.07), GroundColors.TAR))
	k.made.box(top + Vector3(-0.16, -0.3, -0.16), top + Vector3(0.16, 0.0, 0.16), iron, iron)
	var eye := top + Vector3(0.0, -0.22, 0.17)
	k.made.box(eye + Vector3(-0.03, -0.03, 0.0), eye + Vector3(0.03, 0.03, 0.01), GroundColors.glow(Color(0.5, 0.8, 1.0), 1.2))


## Their panel on the frame by the well, at a sensor's height: a plate, a slot,
## a row of points reading the cable, one lit cold.
func _cable_panel(k: Kit, at: Vector2, f: Vector2) -> void:
	var w := at - f * 0.24
	_box(k.made, w, f, -0.28, 0.28, 0.0, 0.05, 0.4, 0.86, iron, iron)
	for i in 5:
		var u := -0.2 + 0.1 * float(i)
		_box(k.made, w, f, u - 0.02, u + 0.02, 0.05, 0.07, 0.5, 0.54, GroundColors.glow(Color(0.5, 0.8, 1.0), 1.0) if i == 2 else GroundColors.made(Color(0.05, 0.05, 0.06), GroundColors.TAR))
	k.made.strut(_q(w, f, 0.0, 0.05, 0.4), _q(w, f, 0.0, 0.05, 0.0), 0.012, 4, iron)


## The last catch: fish boxes stacked three high, iced into one block.
func _fish_boxes(k: Kit, at: Vector2, f: Vector2) -> void:
	for row in 3:
		var h := 0.3 * float(row)
		for j in 2:
			var u := -0.3 + 0.6 * float(j)
			_box(k.made, at, f, u - 0.28, u + 0.28, -0.42, 0.42, h, h + 0.28, plank, rime)
	_box(k.made, at, f, -0.6, 0.6, -0.46, 0.46, 0.0, 0.08, ice, ice)


## The ice come in along the low side: a bank of it against the planks, humped,
## and icicles from the deck beams over it.
func _ice_seam(k: Kit, at: Vector2, f: Vector2, long: float) -> void:
	var half := long * 0.5
	var n := int(long / 0.45)
	for i in n:
		var h := Rng.hash_ints(i, 0x1CE5)
		var u := -half + (float(i) + 0.5) * long / float(n)
		var tall := 0.25 + 0.55 * float(h & 255) / 255.0
		var c := _q(at, f, u, 0.05, 0.0)
		k.slab(c.x, floor_y, c.z, 0.5, tall, 0.36 + 0.2 * float((h >> 8) & 3) / 3.0, h, ice, rime, 0.06)
		if ((h >> 10) & 1) == 0:
			var top := _q(at, f, u, 0.2, kind.wall_h)
			k.made.prism(top.x, top.y - 0.35 - 0.3 * float((h >> 11) & 3) / 3.0, top.z, 0.0, top.y, 0.05, 5, ice, ice)


## A bunk, boxed in timber, its blanket frozen stiff where somebody threw it back.
func _bunk(k: Kit, at: Vector2, f: Vector2) -> void:
	_box(k.made, at, f, -0.95, 0.95, -0.42, 0.42, 0.0, 0.5, plank, plank)
	_box(k.made, at, f, -0.9, 0.9, -0.38, 0.38, 0.5, 0.58, GroundColors.made(Color(0.36, 0.34, 0.4), GroundColors.CLOTH), rime)
	_box(k.made, at, f, 0.2, 0.9, -0.36, 0.2, 0.58, 0.66, GroundColors.made(Color(0.42, 0.3, 0.26), GroundColors.CLOTH), rime)


## The board over the bunks: a plank screwed to the frame, a tally cut into it
## in fives, running out.
func _bunk_board(k: Kit, at: Vector2, f: Vector2) -> void:
	var w := at - f * 0.24
	_box(k.made, w, f, -0.5, 0.5, 0.0, 0.04, 1.2, 1.55, plank, plank)
	var cut := GroundColors.made(Color(0.62, 0.5, 0.36), GroundColors.TIMBER)
	for g in 6:
		for s in 5:
			var u := -0.44 + 0.15 * float(g) + 0.025 * float(s)
			if s == 4:
				_box(k.made, w, f, u - 0.1, u, 0.04, 0.045, 1.33, 1.345, cut)
			else:
				_box(k.made, w, f, u - 0.005, u + 0.005, 0.04, 0.045, 1.27, 1.42, cut)


## The sea chest: a timber box with rope beckets, its lid rimed shut.
func _sea_chest(k: Kit, at: Vector2, f: Vector2) -> void:
	_box(k.made, at, f, -0.45, 0.45, -0.28, 0.28, 0.0, 0.5, plank, rime)
	_box(k.made, at, f, -0.46, 0.46, -0.29, 0.29, 0.44, 0.47, tar)
	for u: float in [-0.47, 0.47]:
		_box(k.made, at, f, u - 0.02, u + 0.02, -0.08, 0.08, 0.3, 0.38, GroundColors.made(Color(0.6, 0.52, 0.38), GroundColors.CLOTH))
