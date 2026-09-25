extends "res://src/models/interior/cottage_model.gd"
## A TOWER'S LOBBY, lived in, drawn (docs/interiors; the recipe is
## src/content/interiors/tower_lobby.gd). A cottage's bones -- its windows, its
## household things (Furnish) -- in a dead tower's ground floor: walls of doors
## taken from every floor above, each its own colour and each still with its
## handle, set in the tower's concrete frame; a floor of terrazzo cracked into
## plates, with grit in the cracks; the slab overhead, bare concrete on its
## beams, black over the fire. The counter, the letterboxes, the lift and the
## choked stair are what is left of the place it was.

const P := preload("res://src/render/palette.gd")

var con: Color
var con_dark: Color
var terrazzo: Color
var grit: Color
var door_cols: Array[Color] = []
var cloth: Color
var brass: Color


func build(l: InteriorLayout, k: InteriorKind, land: int, mat: Material) -> void:
	var dress := BiomeDressing.of(land)
	# The frame was painted once, lobby grey: the CONCRETE row's pour texture is
	# pavement-sized and spots a column like a die.
	con = GroundColors.made(Color(0.5, 0.49, 0.47), GroundColors.ENAMEL)
	con_dark = GroundColors.made(Color(0.3, 0.3, 0.29), GroundColors.ENAMEL)
	terrazzo = GroundColors.made(Color(0.58, 0.55, 0.5), GroundColors.CUTSTONE)
	grit = GroundColors.made(Color(0.2, 0.19, 0.18), GroundColors.CONCRETE)
	cloth = GroundColors.made(_pick(dress.pale, Color(0.7, 0.62, 0.5)).lerp(P.EARTH[2], 0.35), GroundColors.CLOTH)
	brass = GroundColors.made(Color(0.52, 0.42, 0.22), GroundColors.ENAMEL)
	door_cols = [GroundColors.made(P.EARTH[2], GroundColors.TIMBER), GroundColors.made(_pick(dress.timber, P.EARTH[3]), GroundColors.TIMBER),
		GroundColors.made(Color(0.32, 0.4, 0.44), GroundColors.ENAMEL), GroundColors.made(Color(0.6, 0.56, 0.48), GroundColors.ENAMEL),
		GroundColors.made(Color(0.46, 0.2, 0.16), GroundColors.ENAMEL), GroundColors.made(P.LINEN[2].lerp(P.EARTH[2], 0.5), GroundColors.TIMBER)]
	super.build(l, k, land, mat)


## A unit of wall: a door taken off its hinges, stood on end in the frame --
## each its own colour, some with their panels, their handle, a number -- and
## over it boards up to the slab. A window is where a door was never found:
## boards across its bottom and top, the day between.
func _edge(k: Kit, e: Dictionary, h: float, _infill: Color, _frame: Color, top: Color, cut: bool) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var mid := (a + b) * 0.5
	var along := (b - a).normalized()
	var out: Vector2 = e.out
	var sd := Rng.hash_ints(int(a.x * 8.0), int(a.y * 8.0), 0x10BB)
	var sx := absf(along.x) * (1.0 + THICK) + absf(along.y) * THICK
	var sz := absf(along.y) * (1.0 + THICK) + absf(along.x) * THICK
	var col: Color = door_cols[sd % door_cols.size()]
	match e.kind:
		&"wall":
			var dh := minf(2.05, h)
			k.slab(mid.x, floor_y, mid.y, sx * 0.97, dh, sz * 0.97, sd, col, top if cut and h <= 2.05 else Kit.tone(col, 0.8), 0.006)
			if not e.inner:
				_panels(k, e, col, sd, minf(dh, h))
			if h > 2.05:
				_boards_over(k, mid, along, sx, sz, 2.05, h, sd, top)
		&"window":
			var sill := minf(0.8, h)
			k.slab(mid.x, floor_y, mid.y, sx, sill, sz, sd, Kit.tone(door_cols[(sd + 2) % door_cols.size()], 0.9), top if cut else con_dark, 0.01)
			if not cut:
				_boards_over(k, mid, along, sx, sz, 1.85, h, sd, top)
				_posts(k, a, b, along, 0.8, 1.85, con_dark, 0.15)
				# Sheeting stretched across half of it, torn.
				_on_wall(k, mid, out, -0.4, 0.1, 0.85, 1.8, GroundColors.made(Color(0.62, 0.64, 0.6), GroundColors.CLOTH), THICK * 0.5 + 0.02)
		_:
			super._edge(k, e, h, con, con_dark, top, cut)


func _boards_over(k: Kit, mid: Vector2, along: Vector2, sx: float, sz: float, y0: float, h: float, sd: int, top: Color) -> void:
	var y := y0
	var i := 0
	while y < h - 0.02:
		var bh := minf(0.28 + 0.1 * float((sd >> i) & 1), h - y)
		var col := Kit.tone(door_cols[(sd + i + 1) % door_cols.size()], 0.75)
		k.slab(mid.x, floor_y + y, mid.y, sx, bh - 0.02, sz, sd + 20 + i, col, top if y + bh >= h - 0.02 else col, 0.01)
		y += bh
		i += 1


## A door's face: its panels picked out, a handle, sometimes a brass number.
func _panels(k: Kit, e: Dictionary, col: Color, sd: int, dh: float) -> void:
	var mid: Vector2 = ((e.a as Vector2) + (e.b as Vector2)) * 0.5
	var out: Vector2 = e.out
	var dark := Kit.tone(col, 0.8)
	if (sd & 1) == 0 and dh > 1.9:
		_on_wall(k, mid, out, -0.3, 0.3, 1.1, 1.85, dark, 0.004)
		_on_wall(k, mid, out, -0.3, 0.3, 0.2, 0.95, dark, 0.004)
	if dh > 1.1:
		var s := 0.34 if (sd & 2) == 0 else -0.34
		_on_wall(k, mid, out, s - 0.04, s + 0.04, 0.98, 1.04, brass, 0.02)
	if (sd & 12) == 0 and dh > 1.7:
		_on_wall(k, mid, out, -0.06, 0.06, 1.55, 1.64, brass, 0.008)


## No damp line here: a concrete floor wicks nothing. Grime along the foot.
func _wear(k: Kit, e: Dictionary, _infill: Color, h: float) -> void:
	if e.inner or e.kind != &"wall":
		return
	var mid: Vector2 = ((e.a as Vector2) + (e.b as Vector2)) * 0.5
	_on_wall(k, mid, e.out, -0.55, 0.55, 0.0, minf(0.14, h), grit, 0.01)


func _breast(_k: Kit, _h: float, _stone: Color, _top: Color) -> void:
	pass


func _soot(_k: Kit, _h: float) -> void:
	pass


## A fire laid on the stone floor leaves it scorched in a ring.
func _hearth_base(k: Kit, _stone: Color) -> void:
	var c := layout.hearth
	k.made.prism(c.x, floor_y + 0.03, c.y, 0.8, floor_y + 0.035, 0.75, 12, GroundColors.made(Color(0.12, 0.11, 0.1), GroundColors.CONCRETE), GroundColors.made(Color(0.14, 0.12, 0.11), GroundColors.CONCRETE))


## TERRAZZO: the lobby's floor, poured in squares divided by brass strips, cracked
## into plates since and the grit of the floors above in every crack.
func _boards(k: Kit, l: InteriorLayout, _dress: BiomeDressing) -> void:
	for r: Rect2i in l.rooms:
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var h := Rng.hash_ints(x, y, 0x7E22)
				var col := Kit.tone(terrazzo, 0.86 + 0.18 * float(h & 255) / 255.0)
				if (h >> 8) % 3 == 0:
					# Cracked: two plates, a hair of grit between.
					var cut := 0.25 + 0.5 * float((h >> 10) & 63) / 63.0
					k.slab(x + cut * 0.5, floor_y, y + 0.5, cut - 0.02, 0.035, 0.97, h, col, col, 0.004)
					k.slab(x + cut + (1.0 - cut) * 0.5, floor_y - 0.008, y + 0.5, 1.0 - cut - 0.02, 0.035, 0.97, h + 1, Kit.tone(col, 0.93), Kit.tone(col, 0.93), 0.004)
				else:
					k.slab(x + 0.5, floor_y, y + 0.5, 0.97, 0.035, 0.97, h, col, col, 0.003)
				# Speckle: the chips the stone was poured with.
				for i in 3:
					var sh := Rng.hash_ints(h, i, 0x5BEC)
					var px := x + 0.1 + 0.8 * float(sh & 255) / 255.0
					var pz := y + 0.1 + 0.8 * float((sh >> 8) & 255) / 255.0
					var chip := GroundColors.made(P.SLATE[1] if (sh >> 16) & 1 == 0 else P.RUST[3], GroundColors.CUTSTONE)
					k.slab(px, floor_y + 0.035, pz, 0.05, 0.003, 0.04, sh, chip, chip, 0.0)
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		k.slab((lo.x + hi.x) * 0.5, floor_y - 0.02, (lo.y + hi.y) * 0.5, hi.x - lo.x, 0.03, hi.y - lo.y, 3, grit, grit, 0.0)
	for t: Dictionary in l.things:
		var at: Vector2 = t.at
		var f: Vector2 = t.face
		match t.kind:
			&"column": _column(k, at)
			&"stair": _stair(k, at, f, float(t.deep))
			&"lift": _lift(k, at, f)
			&"counter": _counter(k, at, f, float(t.deep))
			&"letterboxes": _letterboxes(k, at, f)
			&"partition": _partition(k, at, f, float(t.deep))
			&"curtain": _curtain(k, at, f)
			&"mattress": _mattress(k, at, f)
			&"tube_post": _tube_post(k, at, f)
			&"bale": _bale(k, at, f)
			&"trays": _trays(k, at, f)
			&"sign": _sign(k, at, f)


func _q(at: Vector2, f: Vector2, u: float, v: float, h: float) -> Vector3:
	var s := Vector2(-f.y, f.x)
	var p := at + s * u + f * v
	return Vector3(p.x, floor_y + h, p.y)


func _box_at(k: Kit, at: Vector2, f: Vector2, u: float, v: float, h: float, wu: float, dv: float, hh: float, col: Color, sd: int, top := Color(0, 0, 0, 0), rough := 0.01) -> void:
	var p := _q(at, f, u, v, h)
	k.made.push(Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.y)), p))
	k.slab(0.0, 0.0, 0.0, wu, hh, dv, sd, col, top, rough)
	k.made.pop()


## A column of the tower's frame, to the slab, its cladding gone at the foot.
func _column(k: Kit, at: Vector2) -> void:
	var h := kind.wall_h
	k.slab(at.x, floor_y, at.y, 0.46, h, 0.46, int(at.x * 7.0 + at.y), con, con, 0.01)
	var sd := int(at.x * 13.0 + at.y * 3.0)
	# Its marble cladding still on above a man's height, and a bite out of it.
	k.slab(at.x, floor_y + 1.9, at.y, 0.52, h - 2.2, 0.52, sd, GroundColors.made(Color(0.7, 0.68, 0.64), GroundColors.CUTSTONE), Color(0, 0, 0, 0), 0.004)
	k.slab(at.x, floor_y + h - 0.3, at.y, 0.6, 0.3, 0.6, sd + 1, con_dark, con_dark, 0.01)


## The stair up, choked: its first flight of treads and then the rubble that came
## down it filling the well to the slab, rebar standing out of it.
func _stair(k: Kit, at: Vector2, f: Vector2, deep: float) -> void:
	for i in 5:
		_box_at(k, at, f, 0.0, deep * 0.5 - 0.2 - 0.28 * float(i), 0.0, 1.2, 0.3, 0.18 * float(i + 1), con, 200 + i, Kit.tone(con, 1.08))
	var sd := int(at.x * 9.0 + at.y * 17.0)
	for i in 14:
		var h := Rng.hash_ints(sd, i, 0x2B)
		var u := -0.55 + 1.1 * float(h & 255) / 255.0
		var v := -deep * 0.5 + (deep * 0.9) * float((h >> 8) & 255) / 255.0
		var y := 0.6 + 2.0 * float((h >> 16) & 255) / 255.0 * (1.0 - (v + deep * 0.5) / deep * 0.5)
		var p := _q(at, f, u, v - 0.2, 0.0)
		k.stone(p.x, floor_y + y * 0.5, p.z, 0.22 + 0.14 * float((h >> 24) & 7) / 7.0, y * 0.6, h, con_dark if i % 3 == 0 else con, 6)
	for i in 3:
		var p := _q(at, f, -0.3 + 0.3 * float(i), -0.3, 1.2)
		k.made.strut(p, p + Vector3(0.2 * float(i - 1), 0.8, 0.1), 0.014, 4, P.RUST[2])


## The lift: its doors prised apart on a black shaft, the cables hanging in it.
func _lift(k: Kit, at: Vector2, f: Vector2) -> void:
	var steel := GroundColors.made(Color(0.5, 0.52, 0.52), GroundColors.ENAMEL)
	k.made.quad(_q(at, f, -0.5, 0.0, 0.0), _q(at, f, 0.5, 0.0, 0.0), _q(at, f, 0.5, 0.0, 2.1), _q(at, f, -0.5, 0.0, 2.1), GroundColors.made(Color(0.02, 0.02, 0.02), GroundColors.TAR))
	for side: float in [-1.0, 1.0]:
		_box_at(k, at, f, side * 0.62, 0.04, 0.0, 0.34, 0.05, 2.1, steel, 300 + int(side), steel)
	_box_at(k, at, f, 0.0, 0.03, 2.1, 1.5, 0.08, 0.3, brass, 303, brass)
	for u: float in [-0.12, 0.08]:
		k.made.strut(_q(at, f, u, -0.1, 2.1), _q(at, f, u + 0.05, -0.12, 0.3), 0.012, 4, GroundColors.made(Color(0.14, 0.13, 0.12), GroundColors.TAR))


## The counter people once waited at: stone-topped, its front panelled. A pot,
## a pan and a plate on it now, and a water can.
func _counter(k: Kit, at: Vector2, f: Vector2, deep: float) -> void:
	# `f` runs along it; its front faces the room.
	var s := Vector2(-f.y, f.x)
	var into := s if s.dot(Vector2(layout.rooms[0].size) * 0.5 + Vector2(layout.rooms[0].position) - at) > 0.0 else -s
	var face := into
	k.made.push(Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.y)), Vector3(at.x, floor_y, at.y)))
	k.slab(0.0, 0.0, 0.0, 0.62, 1.0, deep, 400, GroundColors.made(Color(0.4, 0.32, 0.24), GroundColors.TIMBER), Color(0, 0, 0, 0), 0.005)
	k.slab(0.0, 1.0, 0.0, 0.72, 0.06, deep + 0.1, 401, GroundColors.made(Color(0.2, 0.2, 0.22), GroundColors.CUTSTONE), GroundColors.made(Color(0.3, 0.3, 0.32), GroundColors.CUTSTONE), 0.003)
	k.made.pop()
	var pot := _q(at, face, 0.0, 0.0, 1.06)
	var iron := GroundColors.made(Color(0.1, 0.1, 0.1), GroundColors.TAR)
	k.made.prism(pot.x + f.x * 0.5, pot.y, pot.z + f.y * 0.5, 0.14, pot.y + 0.16, 0.15, 10, iron, iron)
	k.made.prism(pot.x - f.x * 0.4, pot.y, pot.z - f.y * 0.4, 0.12, pot.y + 0.03, 0.14, 10, GroundColors.made(Color(0.7, 0.68, 0.62), GroundColors.CLAY), Color(0, 0, 0, 0))
	k.made.prism(pot.x - f.x * 0.8, pot.y, pot.z - f.y * 0.8, 0.09, pot.y + 0.3, 0.09, 6, GroundColors.made(Color(0.3, 0.44, 0.36), GroundColors.ENAMEL), Color(0, 0, 0, 0))


## The letterboxes: a wall of little brass doors, some hanging open.
func _letterboxes(k: Kit, at: Vector2, f: Vector2) -> void:
	_box_at(k, at, f, 0.0, 0.0, 0.9, 1.3, 0.2, 1.0, GroundColors.made(Color(0.3, 0.26, 0.2), GroundColors.TIMBER), 500)
	for row in 5:
		for c in 6:
			var h := Rng.hash_ints(row, c, 0x1E7)
			var u := -0.54 + 0.216 * float(c)
			var y := 0.95 + 0.19 * float(row)
			var open := (h & 7) == 0
			var col := Kit.tone(brass, 0.8 + 0.3 * float((h >> 3) & 7) / 7.0)
			if open:
				k.made.quad(_q(at, f, u - 0.08, 0.11, y), _q(at, f, u - 0.08, 0.2, y), _q(at, f, u - 0.08, 0.2, y + 0.15), _q(at, f, u - 0.08, 0.11, y + 0.15), col)
				k.made.quad(_q(at, f, u - 0.08, 0.101, y), _q(at, f, u + 0.08, 0.101, y), _q(at, f, u + 0.08, 0.101, y + 0.15), _q(at, f, u - 0.08, 0.101, y + 0.15), GroundColors.made(Color(0.03, 0.03, 0.03), GroundColors.TAR))
			else:
				k.made.quad(_q(at, f, u - 0.08, 0.102, y), _q(at, f, u + 0.08, 0.102, y), _q(at, f, u + 0.08, 0.102, y + 0.15), _q(at, f, u - 0.08, 0.102, y + 0.15), col)


## A run of doors stood on edge, lashed to posts: what walls a stall off.
func _partition(k: Kit, at: Vector2, f: Vector2, deep: float) -> void:
	var n := maxi(2, roundi(deep / 0.75))
	for i in n:
		var v := -deep * 0.5 + (float(i) + 0.5) * deep / float(n)
		var h := Rng.hash_ints(int(at.x * 4.0), i, 0xD00)
		var col: Color = door_cols[h % door_cols.size()]
		var tall := 1.95 + 0.1 * float((h >> 4) & 3) / 3.0
		k.made.push(Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.y) + 0.03 * float(i % 2)), _q(at, f, 0.0, v, 0.0)))
		k.slab(0.0, 0.0, 0.0, 0.05, tall, deep / float(n) - 0.03, h, col, Kit.tone(col, 0.8), 0.006)
		k.made.pop()
	for v: float in [-deep * 0.5, deep * 0.5]:
		k.made.strut(_q(at, f, 0.0, v, 0.0), _q(at, f, 0.0, v, 2.2), 0.04, 5, con_dark)


## Cloth on a wire across a stall's opening, drawn half back.
func _curtain(k: Kit, at: Vector2, f: Vector2) -> void:
	var span := 1.25
	var rod := GroundColors.made(Color(0.3, 0.3, 0.3), GroundColors.TAR)
	k.made.strut(_q(at, Vector2(-f.y, f.x), 0.0, 0.0, 2.0), _q(at + f * span, Vector2(-f.y, f.x), 0.0, 0.0, 2.0), 0.01, 3, rod)
	var n := 6
	for i in n:
		var t0 := float(i) / float(n) * 0.6
		var t1 := float(i + 1) / float(n) * 0.6
		var w := 0.05 * (1.0 if i % 2 == 0 else -1.0)
		var s := Vector2(-f.y, f.x)
		var a := at + f * span * t0
		var b := at + f * span * t1 + s * w
		var col := Kit.tone(cloth, 0.85 + 0.15 * float(i % 2))
		k.made.quad(Vector3(a.x, floor_y + 0.05, a.y), Vector3(b.x, floor_y + 0.05, b.y), Vector3(b.x, floor_y + 2.0, b.y), Vector3(a.x, floor_y + 2.0, a.y), col)
		k.made.quad(Vector3(a.x, floor_y + 2.0, a.y), Vector3(b.x, floor_y + 2.0, b.y), Vector3(b.x, floor_y + 0.05, b.y), Vector3(a.x, floor_y + 0.05, a.y), col)


## A mattress on pallets, its blankets.
func _mattress(k: Kit, at: Vector2, f: Vector2) -> void:
	var pal := GroundColors.made(Color(0.5, 0.42, 0.3), GroundColors.TIMBER)
	_box_at(k, at, f, 0.0, 0.0, 0.0, 1.9, 1.0, 0.14, pal, 600, pal)
	_box_at(k, at, f, 0.0, 0.0, 0.14, 1.8, 0.9, 0.16, GroundColors.made(Color(0.62, 0.6, 0.54), GroundColors.CLOTH), 601)
	_box_at(k, at, f, 0.25, 0.0, 0.3, 1.2, 0.92, 0.05, GroundColors.made(Color(0.36, 0.3, 0.4), GroundColors.CLOTH), 602)


## THE STOLEN LIGHT: a tube off the machines' street furniture, strapped to a
## column, its cable running to a battery on the floor. Cold, and the only
## light here but the fire.
func _tube_post(k: Kit, at: Vector2, f: Vector2) -> void:
	var a := _q(at, f, -0.3, 0.0, 2.45)
	var b := _q(at, f, 0.3, 0.0, 2.45)
	k.found.strut(a, b, 0.035, 6, GroundColors.glow(Color(0.7, 0.86, 1.0), 1.4))
	k.found.strut(a + Vector3.UP * 0.05, b + Vector3.UP * 0.05, 0.05, 4, P.PLATE[2])
	var bat := _q(at, f, 0.2, 0.25, 0.0)
	k.found.box(bat - Vector3(0.14, 0.0, 0.1), bat + Vector3(0.14, 0.2, 0.1), P.PLATE[1], P.PLATE[3])
	k.cable(a, bat + Vector3.UP * 0.2, 0.3, 6, 0.012, P.INK[2])
	lights.append([(a + b) * 0.5 + Vector3(f.x, 0.0, f.y) * 0.1 + Vector3.DOWN * 0.1, &"strip"])


## Bales of wire stripped from the towers, bound with more of it.
func _bale(k: Kit, at: Vector2, f: Vector2) -> void:
	var cu := GroundColors.made(P.COPPER[2], GroundColors.ENAMEL)
	_box_at(k, at, f, 0.0, 0.0, 0.0, 0.6, 0.5, 0.45, cu, 700, Kit.tone(cu, 1.2), 0.05)
	_box_at(k, at, f, 0.05, 0.02, 0.45, 0.5, 0.42, 0.35, Kit.tone(cu, 0.85), 701, Kit.tone(cu, 1.1), 0.05)


## Trays of greens under the tube: boxes of soil, the leaves.
func _trays(k: Kit, at: Vector2, f: Vector2) -> void:
	var box := GroundColors.made(Color(0.42, 0.34, 0.24), GroundColors.TIMBER)
	var leaf := GroundColors.made(P.MOSS[3], GroundColors.CLOTH)
	for i in 2:
		_box_at(k, at, f, -0.2 + 0.4 * float(i), 0.0, 0.25 * float(i), 0.5, 0.5, 0.2, box, 710 + i, GroundColors.made(P.EARTH[1], GroundColors.CLAY))
		var p := _q(at, f, -0.2 + 0.4 * float(i), 0.0, 0.25 * float(i) + 0.2)
		k.clump(p.x, p.y, p.z, 0.22, 0.14, 720 + i, leaf, 7, 0.2)


## A sign off the building's own front, kept: letters of a name nobody reads.
func _sign(k: Kit, at: Vector2, f: Vector2) -> void:
	_box_at(k, at, f, 0.0, -0.05, 0.0, 1.0, 0.06, 0.7, GroundColors.made(Color(0.14, 0.16, 0.2), GroundColors.ENAMEL), 800, Color(0, 0, 0, 0), 0.0)
	for i in 5:
		_box_at(k, at, f, -0.36 + 0.18 * float(i), -0.01, 0.3, 0.1, 0.02, 0.16, brass, 801 + i, brass, 0.0)


## The slab over the lobby: bare concrete on its beams, and over the fire a
## plume of soot spreading across it.
func _roof(k: Kit, h: float, _frame: Color) -> void:
	for r: Rect2i in layout.rooms:
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		var y := floor_y + h
		k.made.box(Vector3(lo.x, y, lo.y), Vector3(hi.x, y + 0.3, hi.y), con, con, true)
		# The beams run along the columns' lines, each column to its nearest
		# neighbour and on to the walls.
		var cols: Array[Vector2] = []
		for t: Dictionary in layout.things:
			if t.kind == &"column":
				cols.append(t.at)
		var done := {}
		for c: Vector2 in cols:
			var near := Vector2.INF
			for o: Vector2 in cols:
				if o != c and (near == Vector2.INF or c.distance_to(o) < c.distance_to(near)):
					near = o
			if near == Vector2.INF:
				continue
			var along_x := absf((near - c).x) > absf((near - c).y)
			var key := "x%.1f" % c.y if along_x else "y%.1f" % c.x
			if done.has(key):
				continue
			done[key] = true
			if along_x:
				k.made.box(Vector3(lo.x, y - 0.4, c.y - 0.2), Vector3(hi.x, y, c.y + 0.2), con_dark, con_dark, true)
			else:
				k.made.box(Vector3(c.x - 0.2, y - 0.4, lo.y), Vector3(c.x + 0.2, y, hi.y), con_dark, con_dark, true)
	var c := layout.hearth
	var soot := GroundColors.made(Color(0.08, 0.075, 0.07), GroundColors.CONCRETE)
	for i in 3:
		var r := 0.6 + 0.5 * float(i)
		k.made.prism(c.x, floor_y + h - 0.01 - 0.003 * float(i), c.y, r, floor_y + h - 0.005 - 0.003 * float(i), r, 10, Kit.tone(soot, 1.0 + 0.4 * float(i)), Kit.tone(soot, 1.0 + 0.4 * float(i)), 0.3 * float(i), true)
