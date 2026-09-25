extends "res://src/models/interior/cottage_model.gd"
## A DROWNED CITY STILT HOUSE, drawn from inside (docs/interiors; the recipe is
## src/content/interiors/stilt_room.gd). A cottage's bones -- the same walls,
## windows, ceiling and household things (Furnish) -- in what the water leaves
## people to build with: upright boards tarred black on their outer face and
## silvered inside, a tide line where the water once came in over the floor,
## the fire in a box of sand under a hood of the machines' own ducting (FOUND),
## and the water itself under the trapdoor, where a ladder goes down to the
## punt. The windows are the cottage's, and what is outside them is the canal.

const P := preload("res://src/render/palette.gd")

var wood: Color
var wood_dark: Color
var tar_board: Color
var weed: Color
var sand: Color
var water: Color
var rope: Color


func build(l: InteriorLayout, k: InteriorKind, land: int, mat: Material) -> void:
	var dress := BiomeDressing.of(land)
	var t: Color = _pick(dress.timber, Color(0.36, 0.3, 0.24))
	# Boards the damp has silvered, never the warm plank of a dry house.
	wood = GroundColors.made(t.lerp(Color(0.5, 0.5, 0.46), 0.35), GroundColors.TIMBER)
	wood_dark = GroundColors.made(Kit.tone(t, 0.7), GroundColors.TIMBER)
	tar_board = GroundColors.made(Color(0.09, 0.09, 0.1), GroundColors.TAR)
	weed = GroundColors.made(Color(0.2, 0.28, 0.18), GroundColors.CLOTH)
	sand = GroundColors.made(Color(0.62, 0.55, 0.42), GroundColors.CLAY)
	water = GroundColors.made(Color(0.05, 0.1, 0.1), GroundColors.GLASS)
	rope = GroundColors.made(Color(0.42, 0.36, 0.26), GroundColors.ROPE)
	super.build(l, k, land, mat)


## A unit of wall in upright boards, each its own width and tone, a rail across
## them at the height of a hand; a window's boards stop at its sill and start
## again over its head; a doorway is the cottage's posts in this timber.
func _edge(k: Kit, e: Dictionary, h: float, _infill: Color, frame: Color, top: Color, cut: bool) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var along := (b - a).normalized()
	var sd := Rng.hash_ints(int(a.x * 8.0), int(a.y * 8.0), 0x5711)
	var spans: Array[Vector2] = []
	match e.kind:
		&"wall":
			spans.append(Vector2(0.0, h))
		&"window":
			spans.append(Vector2(0.0, minf(0.9, h)))
			if not cut:
				spans.append(Vector2(1.75, h))
				_posts(k, a, b, along, 0.9, 1.75, wood_dark, 0.2)
		_:
			super._edge(k, e, h, wood, wood_dark, top, cut)
			return
	var n := 5
	var u := -0.5 - THICK * 0.5
	for i in n:
		var bw := (1.0 + THICK) / float(n)
		var p := a + along * (0.5 + u + bw * 0.5)
		var col := Kit.tone(wood, 0.82 + 0.3 * float((sd >> (i * 3)) & 7) / 7.0)
		for sp: Vector2 in spans:
			if sp.y - sp.x < 0.02:
				continue
			k.slab(p.x, floor_y + sp.x, p.y, absf(along.x) * (bw - 0.015) + absf(along.y) * THICK,
				sp.y - sp.x, absf(along.y) * (bw - 0.015) + absf(along.x) * THICK, sd + i, col, top if cut else col, 0.008)
		u += bw
	if not e.inner and h > 1.05:
		var mid := (a + b) * 0.5 - (e.out as Vector2) * (THICK * 0.5 + 0.03)
		k.slab(mid.x, floor_y + 0.98, mid.y, absf(along.x) * (1.0 + THICK) + absf(along.y) * 0.06, 0.08,
			absf(along.y) * (1.0 + THICK) + absf(along.x) * 0.06, sd + 9, wood_dark, wood_dark, 0.004)


## THE WATER CAME IN ONCE: a tide line on the boards, dark to a wavering height
## and green at its top where weed dried on.
func _wear(k: Kit, e: Dictionary, _infill: Color, h: float) -> void:
	if e.inner or not (e.kind == &"wall" or e.kind == &"window"):
		return
	var mid: Vector2 = ((e.a as Vector2) + (e.b as Vector2)) * 0.5
	var out: Vector2 = e.out
	var ph := float(Rng.hash_ints(int(mid.x * 8.0), int(mid.y * 8.0), 0x71DE) & 255) / 40.0
	var damp := Kit.tone(wood, 0.62)
	for i in 8:
		var u0 := -0.61 + 1.22 * float(i) / 8.0
		var u1 := -0.61 + 1.22 * float(i + 1) / 8.0
		var t0 := minf(0.42 + 0.05 * sin(u0 * 3.1 + ph) + 0.03 * sin(u0 * 9.0), h)
		var t1 := minf(0.42 + 0.05 * sin(u1 * 3.1 + ph) + 0.03 * sin(u1 * 9.0), h)
		_wall_poly(k, mid, out, [Vector2(u0, 0.0), Vector2(u0, t0), Vector2(u1, t1), Vector2(u1, 0.0)], damp, 0.004)
		if t0 < h and t1 < h:
			_wall_poly(k, mid, out, [Vector2(u0, t0 - 0.04), Vector2(u0, t0 + 0.02), Vector2(u1, t1 + 0.02), Vector2(u1, t1 - 0.04)], weed, 0.006)


## No chimney breast: a hood of the machines' ducting over the sand box, its
## flue up through the ceiling. Taken, so FOUND.
func _breast(k: Kit, h: float, _stone: Color, _top: Color) -> void:
	if h < 1.3:
		return
	var c := layout.hearth + layout.hearth_wall * 0.1
	var across := Vector2(-layout.hearth_wall.y, layout.hearth_wall.x)
	var f := -layout.hearth_wall
	var y0 := floor_y + 1.25
	var y1 := floor_y + 1.65
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p := c + across * s.x * 0.6 + f * s.y * 0.45
		var q := c + across * s.x * 0.16 + f * s.y * 0.14
		lo.append(Vector3(p.x, y0, p.y))
		hi.append(Vector3(q.x, y1, q.y))
	for i in 4:
		var j := (i + 1) % 4
		k.found.quad(lo[i], lo[j], hi[j], hi[i], P.PLATE[2 + (i % 2)])
		k.found.quad(hi[i], hi[j], lo[j], lo[i], P.PLATE[1])
	k.found.strut(Vector3(c.x, y1, c.y), Vector3(c.x, floor_y + h + 0.2, c.y), 0.13, 8, P.PLATE[2])
	# Its seams and the bands that hold it.
	k.found.strut(Vector3(c.x, y1 + 0.2, c.y), Vector3(c.x, y1 + 0.24, c.y), 0.145, 8, P.PLATE[4])
	for i in 4:
		k.found.strut(lo[i], lo[(i + 1) % 4], 0.012, 4, P.PLATE[4])


## Soot on the boards behind the hood.
func _soot(k: Kit, h: float) -> void:
	var hw := layout.hearth_wall
	var sooty := GroundColors.made(Color(0.1, 0.09, 0.08), GroundColors.TIMBER)
	# A plume: narrow over the sand, spreading up to the hood's mouth.
	var top := minf(1.25, h)
	_wall_poly(k, layout.hearth + hw * 0.75, hw, [Vector2(-0.18, 0.2), Vector2(-0.5, top), Vector2(0.5, top), Vector2(0.18, 0.2)] as Array[Vector2], sooty, 0.012)


## The sand box the fire is laid in: a kerb of boards, the sand, a few bricks.
func _hearth_base(k: Kit, _stone: Color) -> void:
	var c := layout.hearth + layout.hearth_wall * 0.05
	var across := Vector2(-layout.hearth_wall.y, layout.hearth_wall.x)
	k.slab(c.x, floor_y, c.y, absf(across.x) * 1.3 + absf(across.y) * 1.0, 0.1, absf(across.y) * 1.3 + absf(across.x) * 1.0, 17, wood_dark, sand, 0.01)
	for i in 3:
		var p := c + across * (-0.4 + 0.4 * float(i)) - layout.hearth_wall * 0.38
		k.slab(p.x, floor_y + 0.1, p.y, 0.2, 0.06, 0.1, 18 + i, GroundColors.made(Color(0.46, 0.22, 0.16), GroundColors.CLAY), Color(0, 0, 0, 0), 0.01)


## The cottage's boards (worn where people walk), and on them what only a house
## over water keeps.
func _boards(k: Kit, l: InteriorLayout, dress: BiomeDressing) -> void:
	super._boards(k, l, dress)
	for t: Dictionary in l.things:
		var at: Vector2 = t.at
		var f: Vector2 = t.face
		match t.kind:
			&"trapdoor": _trapdoor(k, at, f)
			&"hammock": _hammock(k, at, f, float(t.deep))
			&"gauge": _gauge(k, at, f)
			&"bucket": _bucket(k, at)
			&"eeltrap": _eeltrap(k, at, f)
			&"pole": _pole(k, at, f)


func _q(at: Vector2, f: Vector2, u: float, v: float, h: float) -> Vector3:
	var s := Vector2(-f.y, f.x)
	var p := at + s * u + f * v
	return Vector3(p.x, floor_y + h, p.y)


## The trapdoor, open: a square hole framed in the boards, the canal black and
## glinting under it, the ladder's rails and top rungs going down, the lid
## stood up on its hinges, a rope made fast to a cleat and gone down to the punt.
func _trapdoor(k: Kit, at: Vector2, f: Vector2) -> void:
	const HALF := 0.42
	var top := 0.04
	k.made.quad(_q(at, f, -HALF, -HALF, top), _q(at, f, HALF, -HALF, top), _q(at, f, HALF, HALF, top), _q(at, f, -HALF, HALF, top), water)
	k.made.quad(_q(at, f, -HALF, HALF, top), _q(at, f, HALF, HALF, top), _q(at, f, HALF, -HALF, top), _q(at, f, -HALF, -HALF, top), water)
	# The hole's frame, a rim of dark boards.
	for side in 4:
		var d := Vector2(1, 0).rotated(float(side) * PI * 0.5)
		var c := at + (Vector2(-f.y, f.x) * d.x + f * d.y) * (HALF + 0.05)
		var long := absf(d.x) < 0.5
		var along := Vector2(-f.y, f.x) if long else f
		var sx := absf(along.x) * (HALF * 2.0 + 0.2) + absf(along.y) * 0.1
		var sz := absf(along.y) * (HALF * 2.0 + 0.2) + absf(along.x) * 0.1
		k.slab(c.x, floor_y, c.y, sx, 0.06, sz, 70 + side, wood_dark, wood_dark, 0.004)
	# The ladder's rails, and a rung or two above the water.
	for u: float in [-0.2, 0.2]:
		k.made.strut(_q(at, f, u, HALF - 0.08, top - 0.3), _q(at, f, u, HALF - 0.04, 0.32), 0.022, 5, wood)
	k.made.strut(_q(at, f, -0.2, HALF - 0.05, 0.16), _q(at, f, 0.2, HALF - 0.05, 0.16), 0.016, 4, wood)
	# The lid, up on its hinges against the back.
	var h0 := _q(at, f, -HALF, -HALF - 0.04, 0.05)
	var h1 := _q(at, f, HALF, -HALF - 0.04, 0.05)
	var l0 := h0 + Vector3(-f.x, 0.0, -f.y) * 0.18 + Vector3.UP * 0.82
	var l1 := h1 + Vector3(-f.x, 0.0, -f.y) * 0.18 + Vector3.UP * 0.82
	k.made.quad(h0, h1, l1, l0, wood)
	k.made.quad(l0, l1, h1, h0, wood_dark)
	# The cleat, and the rope from it down through the hole.
	var cleat := _q(at, f, HALF + 0.14, 0.1, 0.05)
	k.slab(cleat.x, cleat.y, cleat.z, 0.14, 0.05, 0.05, 79, wood_dark, wood_dark, 0.004)
	k.sag(cleat + Vector3.UP * 0.05, _q(at, f, 0.25, 0.1, -0.2), 0.02, 4, 0.012, rope)


## The hammock: a net slung between two posts, a blanket in it.
func _hammock(k: Kit, at: Vector2, f: Vector2, deep: float) -> void:
	var half := deep * 0.5
	for v: float in [-half, half]:
		k.made.strut(_q(at, f, 0.0, v, 0.0), _q(at, f, 0.0, v, 1.35), 0.045, 6, wood_dark)
	var n := 8
	var prev_l := _q(at, f, -0.28, -half + 0.05, 1.05)
	var prev_r := _q(at, f, 0.28, -half + 0.05, 1.05)
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var dip := 0.45 * 4.0 * t * (1.0 - t)
		var l := _q(at, f, -0.28, -half + 0.05 + (deep - 0.1) * t, 1.05 - dip)
		var r := _q(at, f, 0.28, -half + 0.05 + (deep - 0.1) * t, 1.05 - dip)
		var col := Kit.tone(rope, 0.9 + 0.1 * float(i % 2))
		k.made.quad(prev_l, prev_r, r, l, col)
		k.made.quad(l, r, prev_r, prev_l, col)
		prev_l = l
		prev_r = r
	var mid := _q(at, f, 0.05, 0.1, 0.62)
	k.clump(mid.x, mid.y, mid.z, 0.3, 0.12, 91, GroundColors.made(Color(0.3, 0.34, 0.4), GroundColors.CLOTH), 7)


## The post by the door the water's heights are scratched on, the highest cut
## at a child's head and a date nobody alive remembers the meaning of.
func _gauge(k: Kit, at: Vector2, f: Vector2) -> void:
	k.made.strut(_q(at, f, 0.0, 0.0, 0.0), _q(at, f, 0.0, 0.0, 2.2), 0.06, 6, wood_dark)
	var cut := GroundColors.made(Color(0.72, 0.68, 0.58), GroundColors.TIMBER)
	for i in 6:
		var y := 0.2 + 0.16 * float(i) + 0.05 * float(i % 2)
		var w := 0.09 if i == 5 else 0.06
		k.made.strut(_q(at, f, -w, 0.062, y), _q(at, f, w, 0.062, y), 0.007, 3, cut)


func _bucket(k: Kit, at: Vector2) -> void:
	var p := Vector3(at.x, floor_y, at.y)
	k.made.prism(p.x, p.y, p.z, 0.14, p.y + 0.26, 0.17, 10, wood_dark, water)
	k.made.strut(p + Vector3(-0.16, 0.26, 0.0), p + Vector3(0.0, 0.42, 0.0), 0.008, 3, rope)
	k.made.strut(p + Vector3(0.0, 0.42, 0.0), p + Vector3(0.16, 0.26, 0.0), 0.008, 3, rope)


## An eel trap: a long basket, wide at its mouth and narrowing, lying on its side.
func _eeltrap(k: Kit, at: Vector2, f: Vector2) -> void:
	var s := Vector2(-f.y, f.x)
	var a := Vector3(at.x - s.x * 0.4, floor_y + 0.2, at.y - s.y * 0.4)
	var b := Vector3(at.x + s.x * 0.4, floor_y + 0.12, at.y + s.y * 0.4)
	k.limb(a, b, 0.2, 0.1, 8, rope, Vector3.ZERO, Kit.SAWN)
	for i in 4:
		var t := float(i) / 3.0
		k.made.strut(a.lerp(b, t) + Vector3.UP * (0.19 - 0.08 * t), a.lerp(b, t) + Vector3.UP * (0.2 - 0.08 * t), lerpf(0.21, 0.11, t), 8, wood_dark)


## A punt pole leaning in the corner by its wall.
func _pole(k: Kit, at: Vector2, f: Vector2) -> void:
	k.made.strut(_q(at, f, 0.1, 0.1, 0.0), _q(at, f, -0.1, -0.2, 2.25), 0.03, 5, wood)
