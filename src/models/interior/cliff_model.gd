extends "res://src/models/interior/cottage_model.gd"
## A ROOM CUT INTO THE MESA, drawn from inside (docs/interiors; the recipe is
## src/content/interiors/cliff_room.gd). A cottage's bones -- its window, its
## household things (Furnish) -- in a hillside: the front wall is mud brick,
## built, with the door and the window in it; every other wall and the roof is
## the mesa's own rock in its bands, cut back and left, black over the fire.
## The poles of the front roof are let into the rock and hung with what dries.

const P := preload("res://src/render/palette.gd")

var bands: Array[Color] = []
var clay: Color
var clay_dark: Color
var plaster: Color
var pole: Color
var soot: Color
var wool: Array[Color] = []
var chile: Color
var steel: Color


func build(l: InteriorLayout, k: InteriorKind, land: int, mat: Material) -> void:
	var d := BiomeDressing.of(land)
	var st: Array[Color] = d.stone if d.stone.size() >= 3 else [P.RUST[3], P.SAND[3], P.RUST[2]]
	# The mesa's bands, as the scarp outside draws them (props/mesas.gd _strata).
	for c: Color in [st[1], st[0], GroundColors.up(st[0], 0.4), st[0], st[1].lerp(st[2], 0.5)]:
		bands.append(GroundColors.made(c, GroundColors.CUTSTONE))
	var wall: Color = d.walling[0] if not d.walling.is_empty() else P.RUST[3]
	clay = GroundColors.made(wall.lerp(st[0], 0.6), GroundColors.CLAY)
	clay_dark = GroundColors.made(GroundColors.down(wall.lerp(st[0], 0.6), 0.25), GroundColors.CLAY)
	plaster = GroundColors.made(GroundColors.up(wall.lerp(st[0], 0.7), 0.15), GroundColors.CLAY)
	# Silvered, but a pole under a roof of rock is out of the sun: its darker grain.
	pole = GroundColors.made(d.timber[1] if d.timber.size() > 1 else P.EARTH[2], GroundColors.TIMBER)
	soot = GroundColors.made(Color(0.09, 0.07, 0.06), GroundColors.CUTSTONE)
	wool = [GroundColors.made(Color(0.62, 0.22, 0.14), GroundColors.CLOTH), GroundColors.made(Color(0.86, 0.8, 0.66), GroundColors.CLOTH),
		GroundColors.made(Color(0.2, 0.24, 0.32), GroundColors.CLOTH)]
	chile = GroundColors.made(Color(0.58, 0.1, 0.06), GroundColors.CLOTH)
	steel = GroundColors.made(Color(0.22, 0.24, 0.26), GroundColors.TAR)
	super.build(l, k, land, mat)


## Whether an edge is in the built front wall: on the door's own line.
func _front(e: Dictionary) -> bool:
	if e.inner or not (e.out as Vector2).is_equal_approx(layout.door_out):
		return false
	var m: Vector2 = ((e.a as Vector2) + (e.b as Vector2)) * 0.5
	return absf(m.dot(layout.door_out) - layout.door.dot(layout.door_out)) < 0.1


## The front wall is brick, the door and the window in it; the rest is rock.
func _edge(k: Kit, e: Dictionary, h: float, _infill: Color, _frame: Color, top: Color, cut: bool) -> void:
	if _front(e):
		super._edge(k, e, h, clay, pole, top if cut else clay, cut)
		_courses(k, e, h)
		return
	if e.kind == &"inner":
		_rock(k, e, h, cut, 1.45)
		return
	_rock(k, e, h, cut, 0.0)


## Brick courses ruled on the built wall's face, where there is wall.
func _courses(k: Kit, e: Dictionary, h: float) -> void:
	var mid: Vector2 = ((e.a as Vector2) + (e.b as Vector2)) * 0.5
	var out: Vector2 = e.out
	var y := 0.28
	while y < h - 0.05:
		if e.kind == &"wall" or (e.kind == &"window" and (y < 0.9 or y > 1.75)) or (e.kind == &"door" and y > 2.05):
			_on_wall(k, mid, out, -0.55, 0.55, y, y + 0.02, clay_dark, 0.004)
		y += 0.28


## A unit of the mesa's rock, in its bands: each band a slab of its own depth and
## tone, stood a little in or out of the next, so the wall is a stack of strata
## and not a plane. `from` > 0 leaves an opening up to that height (a low
## doorway cut through to the store).
func _rock(k: Kit, e: Dictionary, h: float, cut: bool, from: float) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var mid := (a + b) * 0.5
	var along := (b - a).normalized()
	var out: Vector2 = e.out
	var sd := Rng.hash_ints(int(mid.x * 8.0), int(mid.y * 8.0), 0x3E5A)
	var y := 0.0
	var i := 0
	while y < h - 0.01:
		var bh := minf(0.26 + 0.2 * float((sd >> (i * 2)) & 3) / 3.0, h - y)
		if y + bh > from:
			var y0 := maxf(y, from)
			# Each band sits in or out of the wall line by its own hardness.
			var push := 0.04 * float(((sd >> (i + 3)) & 3)) - 0.06
			var c := mid + out * (THICK * 0.5 + 0.2 - push)
			var col := bands[(i + (sd & 1)) % bands.size()]
			var sx := absf(along.x) * (1.0 + THICK + 0.1) + absf(along.y) * (THICK + 0.4)
			var sz := absf(along.y) * (1.0 + THICK + 0.1) + absf(along.x) * (THICK + 0.4)
			var last := y + bh >= h - 0.01
			# Rough, and no band runs true: it swells and thins along the wall.
			k.slab(c.x, floor_y + y0, c.y, sx, y + bh - y0, sz, sd + i, GroundColors.down(col, 0.08), (top_cap() if cut and last else col), 0.07, 0.0, 0.03 * float(((sd >> (i + 7)) & 3)) - 0.045)
			# Where the rock was cut back: the pick's strokes, short and slanted
			# the same way, a shade darker than the band.
			if not cut:
				for m in 3:
					var ph := Rng.hash_ints(sd, i, m)
					var u := -0.45 + 0.9 * float(ph & 255) / 255.0
					var v := y0 + 0.05 + (y + bh - y0 - 0.1) * float((ph >> 8) & 255) / 255.0
					_wall_poly(k, mid, out, [Vector2(u, v), Vector2(u + 0.02, v), Vector2(u + 0.09, v + 0.12), Vector2(u + 0.07, v + 0.12)] as Array[Vector2], GroundColors.down(col, 0.3), 0.006 - push)
			# Soot where the smoke went up the rock over the fire.
			var near := mid.distance_to(layout.hearth)
			if near < 2.6 and y0 > 1.2 and not cut:
				_on_wall(k, mid, out, -0.6, 0.6, y0, y + bh, Kit.tone(soot, 1.0 + near * 0.6), 0.004 - push)
		y += bh
		i += 1


func top_cap() -> Color:
	return GroundColors.made(Color(0.07, 0.06, 0.06), GroundColors.TAR)


## Rock does not take a damp line.
func _wear(_k: Kit, _e: Dictionary, _infill: Color, _h: float) -> void:
	pass


func _breast(_k: Kit, _h: float, _stone: Color, _top: Color) -> void:
	pass


func _soot(_k: Kit, _h: float) -> void:
	pass


## The fire pit: a ring of flat stones sunk in the floor, the ash in it.
func _hearth_base(k: Kit, _stone: Color) -> void:
	var c := layout.hearth
	k.made.prism(c.x, floor_y - 0.02, c.y, 0.62, floor_y + 0.03, 0.6, 12, clay_dark, GroundColors.made(Color(0.3, 0.28, 0.26), GroundColors.CLAY))


## A floor of earth packed and plastered, cracked where it dried, worn pale on
## the ways people walk; and on it what only a room in a hillside keeps.
func _boards(k: Kit, l: InteriorLayout, _dress: BiomeDressing) -> void:
	for r: Rect2i in l.rooms:
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		k.slab((lo.x + hi.x) * 0.5, floor_y - 0.01, (lo.y + hi.y) * 0.5, hi.x - lo.x, 0.045, hi.y - lo.y, 5, plaster, plaster, 0.004)
		# Cracks in the plaster, a few hairlines each tile.
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var h := Rng.hash_ints(x, y, 0xC4AC)
				if (h & 3) != 0:
					continue
				var p := Vector2(x + 0.2 + 0.6 * float((h >> 2) & 63) / 63.0, y + 0.2 + 0.6 * float((h >> 8) & 63) / 63.0)
				var dir := Vector2.from_angle(float((h >> 14) & 255) / 255.0 * TAU)
				for m in 3:
					var q := p + dir * 0.18
					k.made.strut(Vector3(p.x, floor_y + 0.037, p.y), Vector3(q.x, floor_y + 0.037, q.y), 0.006, 3, clay_dark)
					dir = dir.rotated(0.6 * (float((h >> (20 + m)) & 1) * 2.0 - 1.0))
					p = q
	for wk: PackedVector2Array in l.walks:
		var a := wk[0]
		var b := wk[wk.size() - 1]
		var n := maxi(2, roundi(a.distance_to(b) / 0.4))
		for i in n:
			var p := a.lerp(b, (float(i) + 0.5) / float(n))
			k.made.prism(p.x, floor_y + 0.034, p.y, 0.3, floor_y + 0.037, 0.28, 8, Kit.tone(plaster, 1.1), Kit.tone(plaster, 1.1))
	for t: Dictionary in l.things:
		var at: Vector2 = t.at
		var f: Vector2 = t.face
		match t.kind:
			&"ledge": _ledge(k, at, f, float(t.deep))
			&"deflector": _deflector(k, at, f, float(t.deep))
			&"mat": _mat(k, at, f)
			&"ollas": _ollas(k, at, f)
			&"niche": _niche(k, at, f)
			&"metate": _metate(k, at, f)
			&"ristra": _ristra(k, at, f)
			&"loom": _backstrap(k, at, f)
			&"hanks": _hanks(k, at, f)
			&"cable": _cable(k, at, f)
			&"pulley": _pulley(k, at, f)
			&"wire": _wire(k, at, f, float(t.deep))


func _q(at: Vector2, f: Vector2, u: float, v: float, h: float) -> Vector3:
	var s := Vector2(-f.y, f.x)
	var p := at + s * u + f * v
	return Vector3(p.x, floor_y + h, p.y)


func _box_at(k: Kit, at: Vector2, f: Vector2, u: float, v: float, h: float, wu: float, dv: float, hh: float, col: Color, sd: int, top := Color(0, 0, 0, 0), rough := 0.01) -> void:
	var p := _q(at, f, u, v, h)
	k.made.push(Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.y)), p))
	k.slab(0.0, 0.0, 0.0, wu, hh, dv, sd, col, top, rough)
	k.made.pop()


## Which way from `at` the nearest wall is, across `f` (a thing laid along one).
func _wall_side(at: Vector2, f: Vector2) -> Vector2:
	var s := Vector2(-f.y, f.x)
	var r := layout.rooms[0]
	var c := Vector2(r.position) + Vector2(r.size) * 0.5
	return s if s.dot(at - c) > 0.0 else -s


## The ledge left in the rock along a wall: its own bands, a sheepskin and a
## blanket on it, a folded one at its head.
func _ledge(k: Kit, at: Vector2, f: Vector2, deep: float) -> void:
	var w := _wall_side(at, f)
	var sd := int(at.x * 7.0 + at.y * 11.0)
	var c := at + w * 0.05
	k.made.push(Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.y)), Vector3(c.x, floor_y, c.y)))
	k.slab(0.0, 0.0, 0.0, 0.82, 0.3, deep, sd, bands[1], bands[2], 0.02)
	k.slab(0.0, 0.3, 0.0, 0.82, 0.16, deep, sd + 1, bands[0], bands[3], 0.03)
	k.made.pop()
	var bl := at - w * 0.02
	k.made.push(Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.y)), Vector3(bl.x, floor_y + 0.46, bl.y)))
	k.slab(0.0, 0.0, 0.1, 0.66, 0.06, deep * 0.62, sd + 2, wool[0], wool[0], 0.01)
	for i in 5:
		var z := -deep * 0.3 + deep * 0.6 * float(i) / 4.0
		k.slab(0.0, 0.061, 0.1 + z * 0.62, 0.66, 0.004, 0.05, sd + 3 + i, wool[1 + i % 2], wool[1 + i % 2], 0.0)
	k.slab(0.0, 0.0, -deep * 0.42, 0.5, 0.14, 0.3, sd + 9, wool[2], wool[1], 0.02)
	k.made.pop()


## The slab stood between the fire and the door against the draught.
func _deflector(k: Kit, at: Vector2, f: Vector2, deep: float) -> void:
	k.made.push(Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.y)), Vector3(at.x, floor_y, at.y)))
	k.slab(0.0, -0.05, 0.0, 0.12, 0.72, deep, 61, bands[0], bands[2], 0.03, 0.08)
	k.made.pop()


func _mat(k: Kit, at: Vector2, f: Vector2) -> void:
	_box_at(k, at, f, 0.0, 0.0, 0.035, 1.3, 0.8, 0.012, GroundColors.made(P.SAND[3], GroundColors.THATCH), 71)
	for i in 4:
		_box_at(k, at, f, 0.0, -0.3 + 0.2 * float(i), 0.047, 1.28, 0.03, 0.002, GroundColors.made(P.SAND[2], GroundColors.THATCH), 72 + i)


## Water jars: tall round-shouldered ollas, a gourd dipper on one.
func _ollas(k: Kit, at: Vector2, f: Vector2) -> void:
	var s := Vector2(-f.y, f.x)
	for i in 2:
		var p := at + s * (-0.14 + 0.3 * float(i))
		var r := 0.15 + 0.03 * float(i)
		var hh := 0.46 + 0.1 * float(i)
		var col := Kit.tone(clay, 0.9 + 0.15 * float(i))
		k.made.prism(p.x, floor_y, p.y, r * 0.6, floor_y + hh * 0.55, r, 10, col, col)
		k.made.prism(p.x, floor_y + hh * 0.55, p.y, r, floor_y + hh, r * 0.45, 10, col, clay_dark)
		k.made.prism(p.x, floor_y + hh, p.y, r * 0.45, floor_y + hh + 0.05, r * 0.5, 10, col, GroundColors.made(Color(0.05, 0.05, 0.05), GroundColors.CLAY))


## A niche cut into the rock: a dark hollow with a pot and a bundle in it.
func _niche(k: Kit, at: Vector2, f: Vector2) -> void:
	var back := at - f * 0.2
	var s := Vector2(-f.y, f.x)
	var lo := 1.0
	var hi := 1.45
	var hole := GroundColors.made(Color(0.1, 0.07, 0.05), GroundColors.CUTSTONE)
	var pa := back + s * 0.3 + f * 0.1
	var pb := back - s * 0.3 + f * 0.1
	k.made.quad(Vector3(pb.x, floor_y + lo, pb.y), Vector3(pb.x, floor_y + hi, pb.y), Vector3(pa.x, floor_y + hi, pa.y), Vector3(pa.x, floor_y + lo, pa.y), hole)
	k.made.quad(Vector3(pa.x, floor_y + lo, pa.y), Vector3(pa.x, floor_y + hi, pa.y), Vector3(pb.x, floor_y + hi, pb.y), Vector3(pb.x, floor_y + lo, pb.y), hole)
	var sill := back + f * 0.18
	k.slab(sill.x, floor_y + lo - 0.03, sill.y, 0.62 * absf(s.x) + 0.2 * absf(f.x), 0.04, 0.62 * absf(s.y) + 0.2 * absf(f.y), 81, bands[2], bands[3], 0.01)
	var pot := back + f * 0.2 + s * 0.1
	k.made.prism(pot.x, floor_y + lo, pot.y, 0.07, floor_y + lo + 0.14, 0.06, 8, clay, clay_dark)
	k.clump(pot.x - s.x * 0.22, floor_y + lo, pot.y - s.y * 0.22, 0.09, 0.08, 83, wool[1], 6)


## The grinding stone and its hand stone, meal spilled round it, a basket.
func _metate(k: Kit, at: Vector2, f: Vector2) -> void:
	k.made.push(Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.y)) * Basis(Vector3.RIGHT, -0.12), Vector3(at.x, floor_y + 0.06, at.y)))
	k.slab(0.0, 0.0, 0.0, 0.42, 0.14, 0.62, 91, bands[1], GroundColors.up(bands[1], 0.18), 0.02)
	k.slab(0.0, 0.14, -0.05, 0.36, 0.06, 0.12, 92, bands[3], GroundColors.up(bands[3], 0.2), 0.01)
	k.made.pop()
	var meal := GroundColors.made(Color(0.9, 0.82, 0.5), GroundColors.CLAY)
	var p := _q(at, f, 0.0, 0.45, 0.035)
	k.made.prism(p.x, p.y, p.z, 0.2, p.y + 0.01, 0.18, 8, meal, meal)


## Chiles strung to dry, hung from a peg in the rock.
func _ristra(k: Kit, at: Vector2, f: Vector2) -> void:
	var top := _q(at, f, 0.0, -0.05, 1.9)
	k.made.strut(top, top + Vector3.DOWN * 1.0, 0.01, 3, GroundColors.made(P.SAND[2], GroundColors.ROPE))
	for i in 16:
		var y := 0.1 + 0.055 * float(i)
		var a := float(i) * 2.2
		var p := top + Vector3.DOWN * y + Vector3(cos(a), 0.0, sin(a)) * 0.06
		k.made.prism(p.x, p.y - 0.09, p.z, 0.005, p.y, 0.028, 5, Kit.tone(chile, 0.8 + 0.3 * float(i % 3) / 2.0), chile)


## A backstrap loom: its far bar tied to a peg in the rock, the warp running to
## the near bar on the floor, a hand of cloth woven.
func _backstrap(k: Kit, at: Vector2, f: Vector2) -> void:
	var far_l := _q(at, f, -0.3, -0.1, 1.2)
	var far_r := _q(at, f, 0.3, -0.1, 1.2)
	var near_l := _q(at, f, -0.3, 0.9, 0.25)
	var near_r := _q(at, f, 0.3, 0.9, 0.25)
	k.made.strut(far_l, far_r, 0.02, 5, pole)
	k.made.strut(near_l, near_r, 0.02, 5, pole)
	for i in 12:
		var t := float(i) / 11.0
		k.made.strut(far_l.lerp(far_r, t), near_l.lerp(near_r, t), 0.004, 3, wool[1])
	var c0 := far_l.lerp(near_l, 0.6)
	var c1 := far_r.lerp(near_r, 0.6)
	var c2 := far_r.lerp(near_r, 0.95)
	var c3 := far_l.lerp(near_l, 0.95)
	k.made.quad(c0, c1, c2, c3, wool[0])
	k.made.quad(c3, c2, c1, c0, wool[0])


func _hanks(k: Kit, at: Vector2, f: Vector2) -> void:
	for i in 3:
		var p := _q(at, f, -0.2 + 0.2 * float(i), 0.0, 0.0)
		k.clump(p.x, p.y, p.z, 0.12, 0.14, 101 + i, wool[i % 3], 7, 0.2)


## What the rigger took off the span: a coil of the machines' cable.
func _cable(k: Kit, at: Vector2, f: Vector2) -> void:
	for i in 5:
		var c := _q(at, f, 0.0, 0.0, 0.04 + 0.05 * float(i))
		k.hoop(c, 0.24 - 0.01 * float(i), 16, 0.022, steel)
		k.made.prism(c.x, c.y - 0.02, c.z, 0.2, c.y + 0.02, 0.2, 12, steel, steel)


## A pulley block off the span, its sheave and hook.
func _pulley(k: Kit, at: Vector2, f: Vector2) -> void:
	var c := _q(at, f, 0.0, 0.0, 0.0)
	k.slab(c.x, c.y, c.z, 0.2, 0.36, 0.1, 111, steel, steel, 0.0)
	k.made.prism(c.x, c.y + 0.12, c.z, 0.14, c.y + 0.2, 0.14, 12, P.RUST[2], P.RUST[3])
	k.made.strut(c + Vector3(0, 0.36, 0), c + Vector3(0.05, 0.5, 0), 0.02, 4, steel)


## A line of the span's wire across the room between two pegs, hung with what dries.
func _wire(k: Kit, at: Vector2, f: Vector2, deep: float) -> void:
	var a := _q(at, f, 0.0, -deep * 0.5, 1.95)
	var b := _q(at, f, 0.0, deep * 0.5, 1.95)
	k.sag(a, b, 0.08, 10, 0.006, steel)
	for i in 4:
		var t := 0.2 + 0.2 * float(i)
		var p := a.lerp(b, t) + Vector3.DOWN * 0.08 * 4.0 * t * (1.0 - t)
		var col: Color = wool[i % 3] if i != 2 else chile
		k.made.quad(p + Vector3(-f.x * 0.15, 0.0, -f.y * 0.15), p + Vector3(f.x * 0.15, 0.0, f.y * 0.15),
			p + Vector3(f.x * 0.15, -0.35, f.y * 0.15), p + Vector3(-f.x * 0.15, -0.35, -f.y * 0.15), col)
		k.made.quad(p + Vector3(-f.x * 0.15, -0.35, -f.y * 0.15), p + Vector3(f.x * 0.15, -0.35, f.y * 0.15),
			p + Vector3(f.x * 0.15, 0.0, f.y * 0.15), p + Vector3(-f.x * 0.15, 0.0, -f.y * 0.15), col)


## The roof: the rock over every room, in its bands' undersides and blackened
## over the fire, and at the front the poles of the built roof let into it.
func _roof(k: Kit, h: float, _frame: Color) -> void:
	for r: Rect2i in layout.rooms:
		for x in range(r.position.x - 1, r.end.x + 1):
			for y in range(r.position.y - 1, r.end.y + 1):
				var hs := Rng.hash_ints(x, y, 0x40CF)
				var drop := 0.05 * float(hs & 7) / 7.0
				var p := Vector2(x + 0.5, y + 0.5)
				var near := p.distance_to(layout.hearth)
				# The underside of the rock: its darker bands, in its own shadow.
				var col := GroundColors.down(bands[[0, 1, 3][(hs >> 4) % 3]], 0.35)
				if near < 2.4:
					col = Kit.tone(soot, 1.0 + near * 0.9)
				k.made.box(Vector3(float(x) - 0.02, floor_y + h - drop, float(y) - 0.02), Vector3(float(x) + 1.02, floor_y + h + 0.3, float(y) + 1.02), col, col, true)
	# The poles, along the room's depth from the front wall, their butts in the rock.
	var r0 := layout.rooms[0]
	var across := Vector2(-layout.door_out.y, layout.door_out.x)
	var front := layout.door.dot(layout.door_out)
	for i in 6:
		var t := (float(i) + 0.5) / 6.0
		var c := Vector2(r0.position) + Vector2(r0.size) * 0.5
		var off := across * (t - 0.5) * (absf(across.x) * float(r0.size.x) + absf(across.y) * float(r0.size.y))
		var fr := c + off + layout.door_out * (front - c.dot(layout.door_out) - 0.05)
		var bk := fr - layout.door_out * 1.6
		k.limb(Vector3(fr.x, floor_y + h - 0.12, fr.y), Vector3(bk.x, floor_y + h - 0.1, bk.y), 0.06, 0.05, 5, pole, Vector3.ZERO, Kit.SAWN)
