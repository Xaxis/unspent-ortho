extends "res://src/models/interior/cliff_model.gd"
## THE FACE SETTLEMENT, drawn (src/content/interiors/face_hold.gd says where
## everything stands). A cut room's bones, cut into the heap and not a mesa:
## the walls are the heap's own bands, and the built front along the slot is
## shored with what came out of it. Inside, the long sort table heaped with
## what was dug out that day, the words room's shelves of phones, drives and
## paper, each labelled in chalk, and a brazier at the sort's side.
##
## The LOOKOUT stands on its own floor (InteriorLayout.room_level), so walls,
## floors, roof and windows are each drawn from the floor of the room they
## belong to; the riser up to it is rock, a ladder bolted to it.

## Salvaged panels the front is shored with: doors, signs, sheet, in the
## middens' dulled paint.
const SALVAGE: Array[Color] = [
	Color(0.3, 0.13, 0.09), Color(0.14, 0.18, 0.24), Color(0.36, 0.33, 0.28), Color(0.2, 0.22, 0.18),
]
## Chalk on the labels.
const CHALK := Color(0.78, 0.76, 0.7)
const Recipe := preload("res://src/content/interiors/face_hold.gd")

var _base := 0.0


func build(l: InteriorLayout, k: InteriorKind, land: int, mat: Material) -> void:
	_base = TerrainMesher.level_height(InteriorGen.FLOOR_LEVEL)
	super.build(l, k, land, mat)
	floor_y = _base


## Draw what follows from room `i`'s own floor.
func _at_room(i: int) -> void:
	var lv := layout.room_level[i] if i >= 0 and i < layout.room_level.size() else 0
	floor_y = TerrainMesher.level_height(InteriorGen.FLOOR_LEVEL + lv)


func _room_at(p: Vector2) -> int:
	for i in layout.rooms.size():
		if Rect2(layout.rooms[i]).has_point(p):
			return i
	return -1


func _edge_room(e: Dictionary) -> int:
	return _room_at(((e.a as Vector2) + (e.b as Vector2)) * 0.5 - (e.out as Vector2) * 0.25)


func _edge(k: Kit, e: Dictionary, h: float, infill: Color, frame: Color, top: Color, cut: bool) -> void:
	var room := _edge_room(e)
	_at_room(room)
	# A RISER: the sort meets the lookout's floor. Rock from the lower floor to
	# the upper one, whole, cut or not; the ladder is on it.
	if e.kind == &"inner":
		var other := _room_at(((e.a as Vector2) + (e.b as Vector2)) * 0.5 + (e.out as Vector2) * 0.25)
		var lo := layout.room_level[room] if room >= 0 else 0
		var hi := layout.room_level[other] if other >= 0 else lo
		if hi != lo:
			_at_room(room if lo < hi else other)
			_rock(k, e, float(absi(hi - lo)) * WorldData.STEP, false, 0.0)
			floor_y = _base
			return
	if _front(e):
		_shored(k, e, h, cut)
	else:
		super._edge(k, e, h, infill, frame, top, cut)
	floor_y = _base


## The built front, shored with salvage: a panel of whatever came out of the
## heap to each unit, its own paint, a lintel of cable over the mouth, and at
## the window the slit between two panels.
func _shored(k: Kit, e: Dictionary, h: float, cut: bool) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var mid := (a + b) * 0.5
	var along := (b - a).normalized()
	var out: Vector2 = e.out
	var sd := Rng.hash_ints(int(mid.x * 4.0), int(mid.y * 4.0), 0x5A1)
	var col := GroundColors.made(SALVAGE[sd % SALVAGE.size()], GroundColors.ENAMEL)
	var sx := absf(along.x) * 1.02 + absf(along.y) * THICK
	var sz := absf(along.y) * 1.02 + absf(along.x) * THICK
	var cap := top_cap() if cut else col
	match e.kind:
		&"door":
			# The mouth: hung with cloth, a cable over it.
			var cloth := GroundColors.made(Color(0.32, 0.27, 0.2), GroundColors.CLOTH)
			var head := minf(h, 2.0)
			if h > head:
				k.slab(mid.x, floor_y + head, mid.y, sx, h - head, sz, sd, col, cap, 0.02)
			for s: float in [-0.42, 0.42]:
				var p := mid + along * s + out * 0.06
				k.slab(p.x, floor_y + head - 0.9, p.y, absf(along.x) * 0.16 + 0.03, 0.9, absf(along.y) * 0.16 + 0.03, sd + 3, cloth, cloth, 0.0)
		&"window":
			# The slit: panel to the sill, a hand's gap, panel over.
			k.slab(mid.x, floor_y, mid.y, sx, 1.3, sz, sd, col, col, 0.02)
			if h > 1.45:
				k.slab(mid.x, floor_y + 1.45, mid.y, sx, h - 1.45, sz, sd + 1, col, cap, 0.02)
		_:
			k.slab(mid.x, floor_y, mid.y, sx, h, sz, sd, col, cap, 0.02)
			# A sign or a door's handle on some panels: what they were.
			if not cut and (sd & 3) == 0:
				var plate := GroundColors.made(Color(0.62, 0.6, 0.52), GroundColors.ENAMEL)
				var p := mid - out * (THICK * 0.5 + 0.01)
				k.slab(p.x, floor_y + 1.2, p.y, absf(along.x) * 0.5 + 0.02, 0.22, absf(along.y) * 0.5 + 0.02, sd + 2, plate, plate, 0.0)


func windows() -> Array[Array]:
	var out: Array[Array] = []
	for e: Dictionary in layout.edges:
		if e.kind == &"window":
			_at_room(_edge_room(e))
			var mid: Vector2 = ((e.a as Vector2) + (e.b as Vector2)) * 0.5
			out.append([Vector3(mid.x, floor_y + 1.37, mid.y), -(e.out as Vector2)])
	floor_y = _base
	return out


func _pane(sky: Kit, land: Kit, e: Dictionary, lo: float, hi: float, inset: float) -> void:
	_at_room(_edge_room(e))
	# The slit is a hand high.
	if e.kind == &"window":
		super._pane(sky, land, e, 1.3, 1.45, inset)
	else:
		super._pane(sky, land, e, lo, hi, inset)
	floor_y = _base


func _mullions(_k: Kit, _e: Dictionary, _frame: Color) -> void:
	pass


func _roof(k: Kit, h: float, _frame: Color) -> void:
	for i in layout.rooms.size():
		_at_room(i)
		var r := layout.rooms[i]
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var hs := Rng.hash_ints(x, y, 0x40CF)
				var drop := 0.05 * float(hs & 7) / 7.0
				var near := Vector2(x + 0.5, y + 0.5).distance_to(layout.hearth)
				var col := GroundColors.down(bands[[0, 1, 3][(hs >> 4) % 3]], 0.35)
				if near < 2.4:
					col = Kit.tone(soot, 1.0 + near * 0.9)
				k.made.box(Vector3(float(x) - 0.02, floor_y + h - drop, float(y) - 0.02), Vector3(float(x) + 1.02, floor_y + h + 0.3, float(y) + 1.02), col, col, true)
	floor_y = _base


func _boards(k: Kit, l: InteriorLayout, _dress: BiomeDressing) -> void:
	# The floor, room by room from its own level, as a cut room's.
	for i in l.rooms.size():
		_at_room(i)
		var r := l.rooms[i]
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		k.slab((lo.x + hi.x) * 0.5, floor_y - 0.01, (lo.y + hi.y) * 0.5, hi.x - lo.x, 0.045, hi.y - lo.y, 5 + i, plaster, plaster, 0.004)
	floor_y = _base
	for t: Dictionary in l.things:
		var at: Vector2 = t.at
		var f: Vector2 = t.face
		match t.kind:
			&"ladder":
				_at_room(_room_at(at + f * 0.25))
				_ladder(k, at, -f)
				floor_y = _base
			&"sort_table": _sort_table(k, at, f, float(t.get("long", 4.0)))
			&"words_shelves": _words(k, at, f, float(t.get("wide", 2.6)))
			&"desk": _desk(k, at, f)


## A ladder bolted to the riser, its rails on up past the lip as handholds.
func _ladder(k: Kit, at: Vector2, up: Vector2) -> void:
	var s := Vector2(-up.y, up.x)
	var off := at - up * (THICK * 0.5 + 0.08)
	var top := float(Recipe.RISE) * WorldData.STEP + 0.9
	var rail := GroundColors.made(Color(0.1, 0.1, 0.11), GroundColors.ENAMEL)
	var rung := GroundColors.made(Color(0.42, 0.4, 0.37), GroundColors.ENAMEL)
	for u: float in [-0.24, 0.24]:
		k.rod(Vector3(off.x + s.x * u, floor_y, off.y + s.y * u), Vector3(off.x + s.x * u, floor_y + top, off.y + s.y * u), 0.028, 6, rail)
	for i in int((top - 0.9) / 0.3):
		var y := floor_y + 0.3 * float(i + 1)
		k.rod(Vector3(off.x - s.x * 0.24, y, off.y - s.y * 0.24), Vector3(off.x + s.x * 0.24, y, off.y + s.y * 0.24), 0.018, 5, rung)


## The sort table: doors laid on trestles, the length of the room, heaped with
## what was dug out today, read and sorted into piles along it.
func _sort_table(k: Kit, at: Vector2, f: Vector2, long: float) -> void:
	var top := GroundColors.made(Color(0.3, 0.22, 0.15), GroundColors.TIMBER)
	var leg := GroundColors.made(Color(0.18, 0.13, 0.09), GroundColors.TIMBER)
	_box_at(k, at, f, 0.0, 0.0, 0.74, long, 0.9, 0.06, top, 301, top)
	for u: float in [-long * 0.5 + 0.2, long * 0.5 - 0.2]:
		for v: float in [-0.35, 0.35]:
			_box_at(k, at, f, u, v, 0.0, 0.06, 0.06, 0.74, leg, 302)
	var piles: Array[Color] = [Color(0.62, 0.6, 0.52), Color(0.14, 0.14, 0.16), Color(0.36, 0.2, 0.12), Color(0.24, 0.3, 0.26)]
	var n := int(long / 0.7)
	for i in n:
		var u := -long * 0.5 + 0.45 + float(i) * (long - 0.9) / maxf(1.0, float(n - 1))
		var c := piles[Rng.hash_ints(int(at.x * 3.0), i, 0x50F7) % piles.size()]
		var p := _q(at, f, u, -0.1 + 0.2 * float(i % 2), 0.8)
		k.stone(p.x, p.y, p.z, 0.2, 0.08, 400 + i, GroundColors.made(c, GroundColors.CLAY), 6)


## The words room's shelves: planks on bricks the width of the wall, and on them
## phones, drives and paper in rows, each shelf's label chalked on its edge.
func _words(k: Kit, at: Vector2, f: Vector2, wide: float) -> void:
	var plank := GroundColors.made(Color(0.26, 0.19, 0.12), GroundColors.TIMBER)
	var chalk := GroundColors.made(CHALK, GroundColors.CLAY)
	var things: Array[Color] = [Color(0.1, 0.1, 0.11), Color(0.62, 0.58, 0.48), Color(0.2, 0.24, 0.3), Color(0.5, 0.46, 0.38)]
	for row in 4:
		var y := 0.3 + 0.45 * float(row)
		_box_at(k, at, f, 0.0, 0.0, y, wide, 0.34, 0.04, plank, 500 + row, plank)
		_box_at(k, at, f, -wide * 0.3, 0.17, y - 0.1, 0.3, 0.01, 0.07, chalk, 510 + row)
		var n := int(wide / 0.16)
		for i in n:
			var h := Rng.hash_ints(row, i, int(at.x * 5.0), 0x3D5)
			if (h & 7) == 0:
				continue
			var tall := 0.08 + 0.2 * float((h >> 3) & 3) / 3.0
			_box_at(k, at, f, -wide * 0.5 + 0.1 + float(i) * 0.16, 0.0, y + 0.04, 0.1, 0.24, tall, GroundColors.made(things[(h >> 6) % things.size()], GroundColors.ENAMEL), 520 + i)


## The reader's desk: a door on crates, a lamp, and papers weighed down.
func _desk(k: Kit, at: Vector2, f: Vector2) -> void:
	var top := GroundColors.made(Color(0.28, 0.21, 0.14), GroundColors.TIMBER)
	var crate := GroundColors.made(Color(0.2, 0.15, 0.1), GroundColors.TIMBER)
	var paper := GroundColors.made(Color(0.66, 0.62, 0.52), GroundColors.CLOTH)
	_box_at(k, at, f, 0.0, 0.0, 0.7, 1.2, 0.6, 0.05, top, 601, top)
	for u: float in [-0.45, 0.45]:
		_box_at(k, at, f, u, 0.0, 0.0, 0.3, 0.5, 0.7, crate, 602)
	_box_at(k, at, f, 0.1, 0.05, 0.75, 0.3, 0.22, 0.02, paper, 603)
	lights.append([_q(at, f, -0.4, 0.1, 1.1), &"lamp"])
