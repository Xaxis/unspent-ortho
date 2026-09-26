extends "res://src/models/interior/cottage_model.gd"
## A SLUMS TENEMENT, drawn from inside (docs/interiors; the recipe is
## src/content/interiors/tenement.gd). A cottage's bones -- its door onto the
## street, its household things (Furnish) -- in the building the plan keeps: the
## municipal two colours, gloss below the dado and distemper above, a skirting,
## a lino floor squared and polished, doors in the plan's enamel with their
## numbers and their meters, the stair up behind its turnstile, and the plan's
## cold strip lights down the hall and the corridor. Nothing is broken. That is
## the whole of what is wrong with it.

var gloss: Color
var distemper: Color
var dado: Color
var skirting: Color
var lino: Color
var lino_dark: Color
var door_enamel: Color
var brass: Color
var steel: Color
var paper: Color
var ink: Color
var lamp_red: Color


func build(l: InteriorLayout, k: InteriorKind, land: int, mat: Material) -> void:
	gloss = GroundColors.made(Color(0.32, 0.4, 0.36), GroundColors.ENAMEL)
	distemper = GroundColors.made(Color(0.76, 0.72, 0.6), GroundColors.CLAY)
	dado = GroundColors.made(Color(0.16, 0.22, 0.2), GroundColors.ENAMEL)
	skirting = GroundColors.made(Color(0.12, 0.13, 0.13), GroundColors.ENAMEL)
	lino = GroundColors.made(Color(0.47, 0.44, 0.39), GroundColors.ENAMEL)
	lino_dark = GroundColors.made(Color(0.33, 0.31, 0.29), GroundColors.ENAMEL)
	door_enamel = GroundColors.made(Color(0.34, 0.12, 0.11), GroundColors.ENAMEL)
	brass = GroundColors.made(Color(0.62, 0.5, 0.26), GroundColors.ENAMEL)
	steel = GroundColors.made(Color(0.4, 0.42, 0.43), GroundColors.ENAMEL)
	paper = GroundColors.made(Color(0.86, 0.84, 0.78), GroundColors.CLOTH)
	ink = GroundColors.made(Color(0.1, 0.1, 0.12), GroundColors.CLOTH)
	lamp_red = GroundColors.glow(Color(0.9, 0.16, 0.1), 1.2)
	super.build(l, k, land, mat)


## A unit of the building's wall: distemper to the ceiling, gloss below the dado
## rail, the rail itself, the skirting at the foot. A doorway is the cottage's
## posts, painted.
func _edge(k: Kit, e: Dictionary, h: float, _infill: Color, _frame: Color, top: Color, cut: bool) -> void:
	if e.kind != &"wall":
		super._edge(k, e, h, distemper, dado, top, cut)
		return
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var mid := (a + b) * 0.5
	var along := (b - a).normalized()
	var sx := absf(along.x) * (1.0 + THICK) + absf(along.y) * THICK
	var sz := absf(along.y) * (1.0 + THICK) + absf(along.x) * THICK
	var sd := int(mid.x * 7.0 + mid.y * 13.0)
	k.slab(mid.x, floor_y, mid.y, sx, h, sz, sd, distemper, top if cut else distemper, 0.004)
	if e.inner:
		return
	var out: Vector2 = e.out
	_on_wall(k, mid, out, -0.62, 0.62, 0.0, minf(1.05, h), gloss, 0.003)
	if h > 1.05:
		_on_wall(k, mid, out, -0.62, 0.62, 1.03, minf(1.1, h), dado, 0.012)
	_on_wall(k, mid, out, -0.62, 0.62, 0.0, minf(0.12, h), skirting, 0.014)


## Nothing has been let go: no damp, no crack.
func _wear(_k: Kit, _e: Dictionary, _infill: Color, _h: float) -> void:
	pass


func _breast(_k: Kit, _h: float, _stone: Color, _top: Color) -> void:
	pass


func _soot(_k: Kit, _h: float) -> void:
	pass


func _hearth_base(_k: Kit, _stone: Color) -> void:
	pass


## Lino in squares, laid true and polished, the rooms' edges a dark border; and
## on it what the building and the household keep.
func _boards(k: Kit, l: InteriorLayout, _dress: BiomeDressing) -> void:
	for r: Rect2i in l.rooms:
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var edge := x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1
				var col := lino_dark if edge or (x + y) % 2 == 0 else lino
				k.slab(float(x) + 0.5, floor_y - 0.01, float(y) + 0.5, 0.99, 0.045, 0.99, x * 31 + y, col, col, 0.0)
	for t: Dictionary in l.things:
		var at: Vector2 = t.at
		var f: Vector2 = t.face
		match t.kind:
			&"stair": _stair(k, at, f, float(t.deep))
			&"turnstile": _turnstile(k, at, f)
			&"shift_board": _shift_board(k, at, f)
			&"flat_door": _flat_door(k, at, f, int(t.number))
			&"shoes": _shoes(k, at, f)
			&"stove": _stove(k, at, f)
			&"radio": _radio(k, at, f)
			&"calendar": _calendar(k, at, f)
			&"wardrobe": _wardrobe(k, at, f)
			&"ledgers": _ledgers(k, at)
			&"overalls": _overalls(k, at, f)
			&"key_board": _key_board(k, at, f)
			&"ration_book": _ration_book(k, at)


## The recipe stands a wall-hung thing this far off its wall's line, where a
## body can reach it; drawn, it hangs on the wall's face.
const WALL_GAP := 0.25


func _on(at: Vector2, f: Vector2) -> Vector2:
	return at - f * WALL_GAP


## +1 when `u` along a thing facing `f` runs toward the middle of the stair
## hall, -1 when it runs toward the wall: the stair and its turnstile are laid
## against whichever wall the plan put them by.
func _open(at: Vector2, f: Vector2) -> float:
	var hall := layout.rooms[0]
	var mid := Vector2(hall.position) + Vector2(hall.size) * 0.5
	return 1.0 if Vector2(-f.y, f.x).dot(mid - at) > 0.0 else -1.0


func _q(at: Vector2, f: Vector2, u: float, v: float, h: float) -> Vector3:
	var s := Vector2(-f.y, f.x)
	var p := at + s * u + f * v
	return Vector3(p.x, floor_y + h, p.y)


func _box_at(k: Kit, at: Vector2, f: Vector2, u: float, v: float, h: float, wu: float, dv: float, hh: float, col: Color, sd: int, top := Color(0, 0, 0, 0)) -> void:
	var p := _q(at, f, u, v, h)
	k.made.push(Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.y)), p))
	k.slab(0.0, 0.0, 0.0, wu, hh, dv, sd, col, top, 0.004)
	k.made.pop()


## A panel on a wall, facing `f`, `u` along it, from `h0` to `h1`, `lift` proud.
func _panel(k: Kit, at: Vector2, f: Vector2, u0: float, u1: float, h0: float, h1: float, col: Color, lift: float) -> void:
	var a := _q(at, f, u0, lift, h0)
	var b := _q(at, f, u1, lift, h0)
	var c := _q(at, f, u1, lift, h1)
	var d := _q(at, f, u0, lift, h1)
	k.made.quad(a, b, c, d, col)
	k.made.quad(d, c, b, a, col)


## The stair up: treads climbing from the turnstile to the back wall and on
## through the ceiling, a string, and the handrail on its open side.
func _stair(k: Kit, at: Vector2, f: Vector2, deep: float) -> void:
	var n := 11
	var rise := kind.wall_h / float(n - 2)
	for i in n:
		var v := deep * 0.5 - (float(i) + 0.5) * deep / float(n)
		_box_at(k, at, f, 0.0, v, 0.0, 1.0, deep / float(n) + 0.01, rise * float(i + 1), lino_dark if i % 2 == 0 else lino, 700 + i, steel)
	var side := _open(at, f)
	var foot := _q(at, f, side * 0.5, deep * 0.5, 0.95)
	var head := _q(at, f, side * 0.5, -deep * 0.5, 0.95 + kind.wall_h)
	k.made.strut(foot, head, 0.03, 6, dado)
	for i in 5:
		var t := (float(i) + 0.5) / 5.0
		var p := foot.lerp(head, t)
		k.made.strut(p, p + Vector3.DOWN * 0.9, 0.012, 4, steel)


## The turnstile the plan stands at the foot of the stair: a waist-high steel
## post, its three arms, a card slot and a lamp, red.
func _turnstile(k: Kit, at: Vector2, f: Vector2) -> void:
	var side := _open(at, f)
	_box_at(k, at, f, -side * 0.42, 0.0, 0.0, 0.22, 0.3, 0.95, steel, 801)
	var hub := _q(at, f, -side * 0.28, 0.0, 0.82)
	var across := Vector2(-f.y, f.x) * side
	for i in 3:
		var a := float(i) / 3.0 * TAU
		var arm := Vector3(across.x * cos(a), sin(a) * 0.5, across.y * cos(a)).normalized() * 0.5
		k.made.strut(hub, hub + arm, 0.02, 5, steel)
	var lamp := _q(at, f, -side * 0.42, 0.16, 0.98)
	k.made.prism(lamp.x, lamp.y, lamp.z, 0.03, lamp.y + 0.04, 0.03, 6, lamp_red, lamp_red)
	_panel(k, at, f, -side * 0.48, -side * 0.36, 0.7, 0.76, ink, 0.152)


## Who goes where, when: a board of cards in their rows under a clock.
func _shift_board(k: Kit, at: Vector2, f: Vector2) -> void:
	at = _on(at, f)
	_panel(k, at, f, -0.6, 0.6, 1.0, 1.7, GroundColors.made(Color(0.22, 0.2, 0.18), GroundColors.TIMBER), 0.01)
	for row in 5:
		for col in 6:
			var u := -0.52 + 0.19 * float(col)
			var h := 1.08 + 0.12 * float(row)
			var c := paper if (row * 6 + col) % 7 != 3 else GroundColors.made(Color(0.8, 0.62, 0.3), GroundColors.CLOTH)
			_panel(k, at, f, u, u + 0.15, h, h + 0.09, c, 0.018)
	var clock := _q(at, f, 0.0, 0.03, 1.92)
	k.made.prism(clock.x, clock.y - 0.12, clock.z, 0.12, clock.y + 0.12, 0.12, 14, paper, paper)
	k.made.strut(clock, clock + Vector3(0.0, 0.08, 0.0), 0.008, 3, ink)
	k.made.strut(clock, _q(at, f, 0.06, 0.03, 1.92), 0.008, 3, ink)


## A flat's door on the corridor: the plan's enamel, its number, its meter.
func _flat_door(k: Kit, at: Vector2, f: Vector2, number: int) -> void:
	var lift := THICK * 0.5 + 0.01
	_panel(k, at, f, -0.38, 0.38, 0.0, 2.0, door_enamel, lift)
	_panel(k, at, f, -0.3, -0.02, 1.1, 1.85, Kit.tone(door_enamel, 0.85), lift + 0.004)
	_panel(k, at, f, 0.02, 0.3, 1.1, 1.85, Kit.tone(door_enamel, 0.85), lift + 0.004)
	# The number, in brass, a digit a plate.
	var digits := str(number)
	for i in digits.length():
		var u := -0.08 + 0.1 * float(i)
		_panel(k, at, f, u, u + 0.07, 1.9, 1.98, brass, lift + 0.008)
	_panel(k, at, f, 0.28, 0.33, 0.95, 1.0, brass, lift + 0.01)
	# The meter beside it, its dial.
	_panel(k, at, f, 0.48, 0.66, 1.3, 1.52, steel, lift + 0.03)
	_panel(k, at, f, 0.52, 0.62, 1.36, 1.46, paper, lift + 0.034)


func _shoes(k: Kit, at: Vector2, f: Vector2) -> void:
	for side: float in [-0.07, 0.07]:
		_box_at(k, at, f, side, 0.0, 0.0, 0.1, 0.26, 0.08, GroundColors.made(Color(0.12, 0.1, 0.09), GroundColors.HIDE), 820)


## The stove the plan issues: an enamelled range, its firebox open at the front
## where the fire is laid (the FIRE prop draws it), a hood and a flue.
func _stove(k: Kit, at: Vector2, f: Vector2) -> void:
	var cream := GroundColors.made(Color(0.84, 0.8, 0.7), GroundColors.ENAMEL)
	for side: float in [-0.62, 0.62]:
		_box_at(k, at, f, side, -0.05, 0.0, 0.14, 0.9, 0.9, cream, 830)
	_box_at(k, at, f, 0.0, -0.46, 0.0, 1.38, 0.1, 0.9, cream, 831)
	_box_at(k, at, f, 0.0, -0.05, 0.9, 1.4, 0.92, 0.06, steel, 832)
	_box_at(k, at, f, 0.0, -0.1, 1.55, 1.1, 0.7, 0.22, cream, 833)
	var flue := _q(at, f, 0.0, -0.1, 1.77)
	k.made.strut(flue, Vector3(flue.x, floor_y + kind.wall_h + 0.1, flue.z), 0.08, 8, steel)


func _radio(k: Kit, at: Vector2, f: Vector2) -> void:
	at = at - f * 0.15
	_box_at(k, at, f, 0.0, 0.0, 1.2, 0.5, 0.2, 0.04, GroundColors.made(Color(0.3, 0.24, 0.18), GroundColors.TIMBER), 840)
	_box_at(k, at, f, 0.0, 0.0, 1.24, 0.34, 0.16, 0.24, GroundColors.made(Color(0.36, 0.28, 0.2), GroundColors.TIMBER), 841)
	_panel(k, at, f, -0.12, 0.06, 1.3, 1.42, GroundColors.made(Color(0.52, 0.46, 0.34), GroundColors.CLOTH), 0.085)
	_panel(k, at, f, 0.08, 0.14, 1.33, 1.39, GroundColors.glow(Color(0.95, 0.7, 0.3), 0.6), 0.086)


## The month's shifts, the days gone crossed through.
func _calendar(k: Kit, at: Vector2, f: Vector2) -> void:
	at = _on(at, f)
	_panel(k, at, f, -0.2, 0.2, 1.2, 1.7, paper, 0.02)
	for i in 20:
		var u := -0.17 + 0.07 * float(i % 5)
		var h := 1.24 + 0.1 * float(i / 5)
		if i < 13:
			k.made.strut(_q(at, f, u, 0.025, h), _q(at, f, u + 0.05, 0.025, h + 0.07), 0.004, 3, ink)


func _wardrobe(k: Kit, at: Vector2, f: Vector2) -> void:
	var wood := GroundColors.made(Color(0.34, 0.24, 0.16), GroundColors.TIMBER)
	_box_at(k, at, f, 0.0, 0.0, 0.0, 0.9, 0.5, 1.9, wood, 850)
	_panel(k, at, f, -0.01, 0.01, 0.2, 1.8, Kit.tone(wood, 0.6), 0.26)


func _ledgers(k: Kit, at: Vector2) -> void:
	for i in 4:
		var c := GroundColors.made(Color(0.2, 0.26, 0.34), GroundColors.CLOTH) if i % 2 == 0 else GroundColors.made(Color(0.34, 0.14, 0.12), GroundColors.CLOTH)
		k.slab(at.x, floor_y + 0.78 + 0.04 * float(i), at.y, 0.3, 0.035, 0.22, 860 + i, c, paper, 0.0)


func _overalls(k: Kit, at: Vector2, f: Vector2) -> void:
	at = _on(at, f)
	var blue := GroundColors.made(Color(0.22, 0.28, 0.38), GroundColors.CLOTH)
	_panel(k, at, f, -0.22, 0.22, 0.7, 1.6, blue, 0.06)
	_panel(k, at, f, -0.22, -0.02, 0.1, 0.7, Kit.tone(blue, 0.9), 0.06)
	_panel(k, at, f, 0.02, 0.22, 0.1, 0.7, Kit.tone(blue, 0.9), 0.06)


## The plan's ration book, buff card with its stamp, open on the table.
func _ration_book(k: Kit, at: Vector2) -> void:
	var buff := GroundColors.made(Color(0.74, 0.66, 0.46), GroundColors.CLOTH)
	k.slab(at.x - 0.08, floor_y + 0.78, at.y, 0.15, 0.012, 0.21, 870, buff, buff, 0.0)
	k.slab(at.x + 0.08, floor_y + 0.78, at.y, 0.15, 0.012, 0.21, 871, buff, paper, 0.0)
	k.slab(at.x + 0.1, floor_y + 0.793, at.y - 0.04, 0.05, 0.002, 0.05, 872, lamp_red, lamp_red, 0.0)


## The keeper's board: a hook and a tag for every door in the building.
func _key_board(k: Kit, at: Vector2, f: Vector2) -> void:
	at = _on(at, f)
	_panel(k, at, f, -0.35, 0.35, 1.2, 1.7, GroundColors.made(Color(0.24, 0.2, 0.16), GroundColors.TIMBER), 0.01)
	for i in 12:
		var u := -0.28 + 0.11 * float(i % 6)
		var h := 1.3 + 0.2 * float(i / 6)
		_panel(k, at, f, u, u + 0.04, h - 0.08, h, brass, 0.02)


## The ceiling: the cottage's boards would be a house's. Plaster, flat and
## white, and the plan's strip lights in their cages down the hall and the
## corridor; a shade over the household's table.
func _roof(k: Kit, h: float, _frame: Color) -> void:
	var plaster := GroundColors.made(Color(0.8, 0.78, 0.72), GroundColors.CLAY)
	for r: Rect2i in layout.rooms:
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		k.made.box(Vector3(lo.x, floor_y + h, lo.y), Vector3(hi.x, floor_y + h + 0.12, hi.y), plaster, plaster, true)
	for ri in 2:
		var r := layout.rooms[ri]
		var c := Vector2(r.position) + Vector2(r.size) * 0.5
		var long := Vector2(1, 0) if r.size.x >= r.size.y else Vector2(0, 1)
		var n := maxi(1, int(maxf(r.size.x, r.size.y) / 3.0))
		for i in n:
			var p := c + long * (float(i) - float(n - 1) * 0.5) * 3.0
			var a := Vector3(p.x - long.x * 0.5, floor_y + h - 0.12, p.y - long.y * 0.5)
			var b := Vector3(p.x + long.x * 0.5, floor_y + h - 0.12, p.y + long.y * 0.5)
			k.made.strut(a, b, 0.05, 6, GroundColors.glow(Color(0.86, 0.9, 1.0), 1.2))
			lights.append([(a + b) * 0.5, &"strip"])
	var shade := Vector3(layout.table.x, floor_y + h - 0.5, layout.table.y)
	k.made.prism(shade.x, shade.y, shade.z, 0.26, shade.y + 0.16, 0.08, 10, dado, dado)
	k.made.strut(shade + Vector3.UP * 0.16, Vector3(shade.x, floor_y + h, shade.z), 0.01, 3, ink)
	lights.append([shade, &"lamp"])
