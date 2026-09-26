extends "res://src/models/interior/cottage_model.gd"
## A GROWER'S HOUSE IN THE GREY ORCHARDS, drawn (the recipe is
## src/content/interiors/laid_table.gd). A cottage's bones in a house nobody has
## let go of, because the machines keep it: no damp, no soot, no crack; the table
## laid for four with the places set fresh; the food hatch in the kitchen wall
## with a tray waiting behind its glass; the plate that says when; a lamp over
## the table that is never out; the beds made; and at the door a seal that hums.

const P := preload("res://src/render/palette.gd")

var linen: Color
var china: Color
var steel: Color
var ready_glow: Color
var pencil: Color
var table_wood: Color
## What the hatch has out, in its own mesh (`tray_N`, N counting the serving
## things) so 21_doors can take it away when the meal is taken.
var trays: Array[Kit] = []


func build(l: InteriorLayout, k: InteriorKind, land: int, mat: Material) -> void:
	linen = GroundColors.made(Color(0.84, 0.84, 0.8), GroundColors.CLOTH)
	china = GroundColors.made(Color(0.9, 0.9, 0.88), GroundColors.ENAMEL)
	steel = GroundColors.made(Color(0.5, 0.53, 0.55), GroundColors.ENAMEL)
	ready_glow = GroundColors.glow(Color(0.5, 1.0, 0.6), 1.0)
	pencil = GroundColors.made(Color(0.2, 0.2, 0.24), GroundColors.CLOTH)
	table_wood = GroundColors.made(Color(0.42, 0.32, 0.22), GroundColors.TIMBER)
	super.build(l, k, land, mat)
	for i in trays.size():
		_mesh(trays[i], mat, "tray_%d" % i)


## Kept: nothing is let go.
func _wear(_k: Kit, _e: Dictionary, _infill: Color, _h: float) -> void:
	pass


func _breast(_k: Kit, _h: float, _stone: Color, _top: Color) -> void:
	pass


func _soot(_k: Kit, _h: float) -> void:
	pass


func _hearth_base(_k: Kit, _stone: Color) -> void:
	pass


func _boards(k: Kit, l: InteriorLayout, dress: BiomeDressing) -> void:
	super._boards(k, l, dress)
	for t: Dictionary in l.things:
		var at: Vector2 = t.at
		var f: Vector2 = t.face
		match t.kind:
			&"laid_table": _laid_table(k, at, f, float(t.long))
			&"food_hatch": _food_hatch(k, at, f)
			&"schedule_plate": _schedule_plate(k, at, f)
			&"height_marks": _height_marks(k, at, f)
			&"dresser": _dresser(k, at, f)
			&"sink": _sink(k, at, f)
			&"cot": _cot(k, at, f)
			&"door_seal": _door_seal(k, at, f)


func _q(at: Vector2, f: Vector2, u: float, v: float, h: float) -> Vector3:
	var s := Vector2(-f.y, f.x)
	var p := at + s * u + f * v
	return Vector3(p.x, floor_y + h, p.y)


func _box(k: Kit, at: Vector2, f: Vector2, u0: float, u1: float, v0: float, v1: float, h0: float, h1: float, col: Color, top := Color(0, 0, 0, 0)) -> void:
	var a := _q(at, f, u0, v0, h0)
	var b := _q(at, f, u1, v1, h1)
	k.made.box(Vector3(minf(a.x, b.x), a.y, minf(a.z, b.z)), Vector3(maxf(a.x, b.x), b.y, maxf(a.z, b.z)), col, top)


## The table, laid: a cloth, and at each place a plate, a cup, a knife and a
## spoon squared to its edge, and bread on a board in the middle. For a couple,
## the third place is set and its chair drawn in.
func _laid_table(k: Kit, at: Vector2, f: Vector2, long: float) -> void:
	var half := long * 0.5
	for u: float in [-half + 0.08, half - 0.08]:
		for v: float in [-0.36, 0.36]:
			_box(k, at, f, u - 0.04, u + 0.04, v - 0.04, v + 0.04, 0.0, 0.74, table_wood)
	_box(k, at, f, -half, half, -0.45, 0.45, 0.74, 0.78, table_wood, table_wood)
	_box(k, at, f, -half + 0.05, half - 0.05, -0.42, 0.42, 0.78, 0.785, linen, linen)
	for p: Vector2 in [Vector2(-0.45, -0.28), Vector2(0.45, -0.28), Vector2(-0.45, 0.28), Vector2(0.45, 0.28)]:
		var c := _q(at, f, p.x, p.y, 0.785)
		k.made.prism(c.x, c.y, c.z, 0.12, c.y + 0.015, 0.12, 12, china, china)
		var cup := _q(at, f, p.x + 0.17, p.y * 0.7, 0.785)
		k.made.prism(cup.x, cup.y, cup.z, 0.035, cup.y + 0.07, 0.04, 8, china, china)
		_box(k, at, f, p.x - 0.16, p.x - 0.15, p.y - 0.08, p.y + 0.08, 0.785, 0.79, steel)
	_box(k, at, f, -0.14, 0.14, -0.08, 0.08, 0.785, 0.8, table_wood)
	var loaf := _q(at, f, 0.0, 0.0, 0.8)
	k.made.prism(loaf.x, loaf.y, loaf.z, 0.09, loaf.y + 0.07, 0.07, 8, GroundColors.made(Color(0.62, 0.44, 0.24), GroundColors.CLOTH))
	var lamp := _q(at, f, 0.0, 0.0, kind.wall_h - 0.55)
	k.made.prism(lamp.x, lamp.y, lamp.z, 0.24, lamp.y + 0.14, 0.07, 10, steel, steel)
	k.made.strut(lamp + Vector3.UP * 0.14, Vector3(lamp.x, floor_y + kind.wall_h, lamp.z), 0.01, 3, pencil)
	lights.append([lamp, &"lamp"])


## The hatch the machines serve through: a steel frame let into the wall, a
## glass door, behind it a tray with a covered dish and a loaf, and the light
## that says a meal is waiting.
func _food_hatch(k: Kit, at: Vector2, f: Vector2) -> void:
	var w := at - f * 0.25
	_box(k, w, f, -0.36, 0.36, 0.0, 0.05, 0.8, 1.35, steel, steel)
	_box(k, w, f, -0.3, 0.3, 0.02, 0.06, 0.86, 1.28, GroundColors.made(Color(0.08, 0.09, 0.1), GroundColors.TAR))
	_box(k, w, f, -0.25, 0.25, 0.06, 0.2, 0.86, 0.9, steel, steel)
	var tray := Kit.new()
	trays.append(tray)
	var dish := _q(w, f, -0.08, 0.13, 0.9)
	tray.made.prism(dish.x, dish.y, dish.z, 0.1, dish.y + 0.08, 0.04, 12, steel, steel)
	var loaf := _q(w, f, 0.13, 0.13, 0.9)
	tray.made.prism(loaf.x, loaf.y, loaf.z, 0.06, loaf.y + 0.05, 0.05, 8, GroundColors.made(Color(0.62, 0.44, 0.24), GroundColors.CLOTH))
	_box(tray, w, f, 0.28, 0.33, 0.05, 0.065, 1.28, 1.32, ready_glow)
	lights.append([_q(w, f, 0.0, 0.4, 1.1), &"machine"])


## When: an enamel plate with the three hours on it, and names.
func _schedule_plate(k: Kit, at: Vector2, f: Vector2) -> void:
	var w := at - f * 0.25
	_box(k, w, f, -0.22, 0.22, 0.0, 0.02, 1.1, 1.5, china)
	for i in 3:
		var h := 1.4 - 0.1 * float(i)
		_box(k, w, f, -0.18, -0.02, 0.02, 0.025, h, h + 0.035, pencil)
		_box(k, w, f, 0.02, 0.18, 0.02, 0.025, h, h + 0.035, GroundColors.made(Color(0.3, 0.42, 0.34), GroundColors.ENAMEL))


## The child's height, in pencil, up the door frame: a line and a date each time,
## and then no more lines.
func _height_marks(k: Kit, at: Vector2, f: Vector2) -> void:
	var w := at - f * 0.25
	for i in 7:
		var h := 0.7 + 0.09 * float(i) + 0.02 * float(i % 2)
		_box(k, w, f, -0.1, 0.06, 0.0, 0.01, h, h + 0.012, pencil)
		_box(k, w, f, 0.08, 0.16, 0.0, 0.01, h - 0.01, h + 0.02, GroundColors.made(Color(0.45, 0.45, 0.5), GroundColors.CLOTH))


func _dresser(k: Kit, at: Vector2, f: Vector2) -> void:
	_box(k, at, f, -0.45, 0.45, -0.22, 0.22, 0.0, 0.9, table_wood, table_wood)
	_box(k, at, f, -0.45, 0.45, -0.22, -0.12, 0.9, 1.9, table_wood)
	for i in 2:
		var h := 1.2 + 0.4 * float(i)
		_box(k, at, f, -0.45, 0.45, -0.22, 0.0, h, h + 0.03, table_wood, table_wood)
		for j in 4:
			var u := -0.36 + 0.24 * float(j)
			var c := _q(at, f, u, -0.1, h + 0.03)
			k.made.prism(c.x, c.y, c.z, 0.08, c.y + 0.16, 0.08, 10, china, china)


func _sink(k: Kit, at: Vector2, f: Vector2) -> void:
	_box(k, at, f, -0.4, 0.4, -0.25, 0.25, 0.0, 0.86, china, steel)
	var tap := _q(at, f, 0.0, -0.2, 0.86)
	k.made.strut(tap, tap + Vector3.UP * 0.22, 0.015, 4, steel)


## A child's cot, made, a blanket squared on it.
func _cot(k: Kit, at: Vector2, f: Vector2) -> void:
	_box(k, at, f, -0.4, 0.4, -0.25, 0.25, 0.0, 0.5, table_wood)
	_box(k, at, f, -0.36, 0.36, -0.22, 0.22, 0.5, 0.56, linen, GroundColors.made(Color(0.6, 0.66, 0.74), GroundColors.CLOTH))


## The seal round the door that keeps the spore mist out, a thin strip lit along
## the frame.
func _door_seal(k: Kit, at: Vector2, f: Vector2) -> void:
	var w := at + f * (THICK * 0.5 + 0.02)
	var glow := GroundColors.glow(Color(0.6, 0.9, 0.75), 0.6)
	for u: float in [-0.5, 0.5]:
		_box(k, w, f, u - 0.02, u + 0.02, 0.0, 0.02, 0.0, 2.05, glow)
	_box(k, w, f, -0.5, 0.5, 0.0, 0.02, 2.03, 2.07, glow)
