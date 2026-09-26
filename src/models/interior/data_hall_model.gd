extends "res://src/models/interior/weapons_hall_model.gd"
## THE DATA HALL UNDER THE SERVER FIELDS' SUMP, drawn (the recipe is
## src/content/interiors/data_hall.gd). The weapons hall's bones -- its plate
## walls, the tape room's bars, its turrets that turn, its strongbox -- round
## aisles of racks to the ceiling, each face a field of status points, the
## only light there is; a raised floor of perforated tiles with the cold coming
## up through the grates in the cold aisles; the console at the head; and in the
## tape room a shelf of paper nobody here has ever read.

## The status points, per the aisle's dressing: `cold` all one blue-white, `warm`
## run hot, amber among the blue.
const POINT_COLD := Color(0.55, 0.78, 1.0)
const POINT_WARM := Color(1.0, 0.62, 0.22)
const POINT_OFF := Color(0.05, 0.06, 0.08)


func _thing(k: Kit, t: Dictionary) -> void:
	var at: Vector2 = t.at
	var f: Vector2 = t.face
	match t.kind:
		&"rack_row": _rack_row(k, at, f, float(t.long))
		&"restore_bay": _restore_bay(k, at, f)
		&"grate": _grate(k, at, f, float(t.long))
		&"console": _console(k, at, f)
		&"paper_log": _paper_log(k, at, f)
		_: super._thing(k, t)


## A raised floor: square tiles, each perforated, on a void you can see the dark
## of through them. Nothing painted.
func _floor(k: Kit, _tears: Array[Vector2]) -> void:
	var bed := GroundColors.made(Color(0.02, 0.02, 0.03), GroundColors.TAR)
	for r: Rect2i in layout.rooms:
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		k.slab((lo.x + hi.x) * 0.5, floor_y, (lo.y + hi.y) * 0.5, hi.x - lo.x, 0.012, hi.y - lo.y, 5, bed, bed, 0.0)
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var h := Rng.hash_ints(x, y, 0xDA7A)
				var col := GroundColors.made(DECK[1] if (h & 3) != 0 else DECK[2], GroundColors.ENAMEL)
				for q in 4:
					var qx := float(x) + 0.25 + 0.5 * float(q % 2)
					var qz := float(y) + 0.25 + 0.5 * float(q / 2)
					k.slab(qx, floor_y, qz, 0.47, DECK_TOP, 0.47, h + q, col, col, 0.0)


func _box(pen: MeshKit, at: Vector2, f: Vector2, u0: float, u1: float, v0: float, v1: float, h0: float, h1: float, col: Color, top := Color(0, 0, 0, 0)) -> void:
	var s := Vector2(-f.y, f.x)
	var a := at + s * u0 + f * v0
	var b := at + s * u1 + f * v1
	pen.box(Vector3(minf(a.x, b.x), floor_y + h0, minf(a.y, b.y)), Vector3(maxf(a.x, b.x), floor_y + h1, maxf(a.y, b.y)), col, top)


func _point(i: int, j: int, salt: int) -> Color:
	var h := Rng.hash01(i, j, salt, 0x57A7)
	if h < 0.22:
		return GroundColors.made(POINT_OFF, GroundColors.TAR)
	var warm := layout.dressing == &"warm" and h > 0.82
	return GroundColors.glow(POINT_WARM if warm else POINT_COLD, 0.9 if h > 0.6 else 0.5)


## A row of racks to the ceiling, its two faces east and west: cabinet after
## cabinet of dark plate, every unit's status points in a column, the only light.
func _rack_row(k: Kit, at: Vector2, f: Vector2, long: float) -> void:
	var top := kind.wall_h - 0.05
	var half := long * 0.5
	_box(k.found, at, f, -half, half, -0.3, 0.3, 0.0, top, HULL[0], HULL[1])
	var cabinets := int(long / 0.6)
	for side: float in [-1.0, 1.0]:
		var face := f * side
		for c in cabinets:
			var u := -half + (float(c) + 0.5) * long / float(cabinets)
			# The cabinet's seam, and its units: thin plates with their points.
			_box(k.found, at, face, u + 0.29 - 0.01, u + 0.29 + 0.01, 0.3, 0.32, 0.05, top - 0.1, HULL[2])
			for unit in 14:
				var h := 0.25 + float(unit) * 0.19
				_box(k.found, at, face, u - 0.26, u + 0.26, 0.3, 0.31, h, h + 0.15, HULL[1] if unit % 3 != 0 else HULL[2])
				for p in 3:
					var pu := u - 0.2 + 0.05 * float(p)
					_box(k.made, at, face, pu, pu + 0.025, 0.31, 0.318, h + 0.06, h + 0.085, _point(c * 7 + unit, p + int(side) * 3, int(at.x * 13.0)))
	# The row's own faint light: what its points throw on the aisle floor.
	for side: float in [-1.0, 1.0]:
		lights.append([_v(at + f * side * 0.7, 1.2), &"standby"])


## The one bay in all of it with nothing in: a rack end with its slot open, the
## rails bare, a label plate on its lintel.
func _restore_bay(k: Kit, at: Vector2, f: Vector2) -> void:
	var back := at - f * 0.06
	_box(k.found, back, f, -0.28, 0.28, 0.0, 0.03, 0.9, 1.5, POINT_OFF)
	for u: float in [-0.26, 0.26]:
		_box(k.found, back, f, u - 0.015, u + 0.015, 0.0, 0.08, 0.9, 1.5, HULL[3])
	_box(k.made, back, f, -0.18, 0.18, 0.03, 0.04, 1.55, 1.62, GroundColors.made(Color(0.78, 0.76, 0.7), GroundColors.ENAMEL))


## A floor grate down a cold aisle, and the cold standing up off it.
func _grate(k: Kit, at: Vector2, f: Vector2, long: float) -> void:
	var s := Vector2(-f.y, f.x)
	for i in int(long / 0.6):
		var c := at + s * 0.0 + f * (-long * 0.5 + 0.3 + float(i) * 0.6)
		k.made.box(_v(c - Vector2(0.22, 0.22), DECK_TOP), _v(c + Vector2(0.22, 0.22), DECK_TOP + 0.004), GroundColors.made(Color(0.04, 0.05, 0.06), GroundColors.TAR))
		var h := Rng.hash_ints(int(c.x * 10.0), int(c.y * 10.0), 0xC01D)
		if h % 3 == 0:
			var mist := GroundColors.made(Color(0.62, 0.68, 0.74), GroundColors.CLOTH)
			k.made.strut(_v(c, 0.05), _v(c + Vector2(0.04, -0.03), 0.5 + 0.3 * float(h % 5) / 4.0), 0.01, 3, mist)


## The console at the aisles' head, at a machine's sensor height: a slab of
## plate, a screen the colour of the points, a column of keys nobody presses.
func _console(k: Kit, at: Vector2, f: Vector2) -> void:
	var w := at - f * 0.24
	_box(k.found, w, f, -0.5, 0.5, 0.0, 0.2, 0.0, 0.85, HULL[1], HULL[2])
	_box(k.made, w, f, -0.36, 0.36, 0.2, 0.21, 0.4, 0.75, GroundColors.glow(POINT_COLD, 0.7))
	for i in 5:
		var u := -0.3 + 0.15 * float(i)
		_box(k.made, w, f, u, u + 0.08, 0.21, 0.215, 0.62 - 0.03 * float(i % 3), 0.64 - 0.03 * float(i % 3), GroundColors.made(Color(0.05, 0.1, 0.16), GroundColors.TAR))
	lights.append([_v(w + f * 0.6, 0.8), &"machine"])


## Paper on a steel shelf in the tape room: binders, a stack, a pencil -- a log
## a person kept here, in the one form the racks never read.
func _paper_log(k: Kit, at: Vector2, f: Vector2) -> void:
	var w := at - f * 0.1
	_box(k.found, w, f, -0.5, 0.5, -0.1, 0.2, 0.0, 0.05, HULL[0])
	_box(k.found, w, f, -0.5, 0.5, -0.1, 0.2, 0.78, 0.82, HULL[1], HULL[2])
	for side: float in [-0.48, 0.48]:
		_box(k.found, w, f, side - 0.02, side + 0.02, -0.1, 0.2, 0.0, 1.5, HULL[0])
	var paper := GroundColors.made(Color(0.82, 0.8, 0.72), GroundColors.CLOTH)
	for i in 6:
		var u := -0.4 + 0.12 * float(i)
		var c := GroundColors.made(Color(0.18, 0.22, 0.3) if i % 2 == 0 else Color(0.3, 0.16, 0.14), GroundColors.CLOTH)
		_box(k.made, w, f, u, u + 0.09, -0.05, 0.16, 0.82, 1.1, c, paper)
	_box(k.made, w, f, 0.15, 0.4, -0.05, 0.15, 0.05, 0.18, paper, paper)
