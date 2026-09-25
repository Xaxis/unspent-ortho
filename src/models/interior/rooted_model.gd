extends "res://src/models/interior/lobby_model.gd"
## THE STANDING FLOOR OF A FALLEN TOWER, drawn from inside (docs/interiors; the
## recipe is src/content/interiors/rooted_floor.gd). The lobby's ruin -- water
## run down the frame, weeds through the gaps (`_weeds`, `_streak`) -- gone the
## whole way over to forest: a trunk up through a break in the slab and out of
## a hole in the ceiling, roots over the concrete, moss on everything flat,
## ferns in the cracks, vines hanging from the broken edges. The frame's gaps
## are closed with what the people here could carry up: plate and board.

var bark: Color
var bark_dark: Color
var moss: Array[Color] = []
var leaf: Array[Color] = []
var plate_patch: Array[Color] = []
var board: Color
## The break in the ceiling over the trunk, its half size.
const OPEN := 0.95


func build(l: InteriorLayout, k: InteriorKind, land: int, mat: Material) -> void:
	var d := BiomeDressing.of(land)
	bark = GroundColors.made(Color(0.3, 0.26, 0.2), GroundColors.TIMBER)
	bark_dark = GroundColors.made(Color(0.17, 0.15, 0.12), GroundColors.TIMBER)
	var g: Color = d.growth if d.growth.a > 0.0 else P.MOSS[3]
	moss = [GroundColors.made(g.darkened(0.25), GroundColors.CLOTH), GroundColors.made(g, GroundColors.CLOTH), GroundColors.made(P.MOSS[4], GroundColors.CLOTH)]
	leaf = [GroundColors.made(P.SPRUCE[3], GroundColors.CLOTH), GroundColors.made(P.MOSS[3], GroundColors.CLOTH), GroundColors.made(P.SPRUCE[2], GroundColors.CLOTH)]
	plate_patch = [GroundColors.made(P.PLATE[2], GroundColors.TAR), GroundColors.made(P.RUST[2].lerp(P.PLATE[2], 0.5), GroundColors.TAR)]
	board = GroundColors.made(d.timber[0] if not d.timber.is_empty() else P.EARTH[3], GroundColors.TIMBER)
	super.build(l, k, land, mat)


## Concrete that has been wet and green for a generation: darker, lichened.
func _tint() -> void:
	con = GroundColors.made(Color(0.36, 0.4, 0.34), GroundColors.ENAMEL)
	con_dark = GroundColors.made(Color(0.2, 0.24, 0.2), GroundColors.ENAMEL)
	grit = GroundColors.made(Color(0.1, 0.12, 0.09), GroundColors.CONCRETE)
	stain = GroundColors.made(Color(0.22, 0.28, 0.2), GroundColors.ENAMEL)


func _trunk() -> Vector2:
	for t: Dictionary in layout.things:
		if t.kind == &"trunk":
			return t.at
	return layout.hearth


## The frame's wall: its concrete, closed where it broke with plate and board;
## a gap left open to the canopy with vines hanging in it; the door the
## cottage's, in concrete.
func _edge(k: Kit, e: Dictionary, h: float, _infill: Color, _frame: Color, top: Color, cut: bool) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var mid := (a + b) * 0.5
	var along := (b - a).normalized()
	var out: Vector2 = e.out
	var sd := Rng.hash_ints(int(mid.x * 8.0), int(mid.y * 8.0), 0x6EE0)
	var sx := absf(along.x) * (1.0 + THICK) + absf(along.y) * THICK
	var sz := absf(along.y) * (1.0 + THICK) + absf(along.x) * THICK
	match e.kind:
		&"wall":
			k.slab(mid.x, floor_y, mid.y, sx, h, sz, sd, con, top if cut else con, 0.01)
			if not e.inner:
				# What closed the breaks: a sheet of plate here, boards there.
				if (sd & 3) == 0:
					_on_wall(k, mid, out, -0.4, 0.3, 0.3, minf(1.6, h), plate_patch[(sd >> 2) & 1], 0.012)
				elif (sd & 3) == 1:
					for i in 3:
						var y := 0.5 + 0.28 * float(i)
						if y + 0.24 < h:
							_on_wall(k, mid, out, -0.5, 0.45, y, y + 0.24, Kit.tone(board, 0.85 + 0.1 * float(i)), 0.012)
		&"window":
			var sill := minf(0.6, h)
			k.slab(mid.x, floor_y, mid.y, sx, sill, sz, sd, con, top if cut else con, 0.01)
			if not cut:
				k.slab(mid.x, floor_y + h - 0.4, mid.y, sx, 0.4, sz, sd + 1, con, con, 0.01)
				_posts(k, a, b, along, 0.6, h - 0.4, con_dark, 0.1)
				# Vines hanging down across the gap from the slab.
				for i in 7:
					var u := -0.4 + 0.8 * float(i) / 6.0
					var p := mid + along * u + out * 0.05
					var long := 0.8 + 1.1 * float((sd >> i) & 3) / 3.0
					_vine(k, Vector3(p.x, floor_y + h - 0.35, p.y), long, sd + i)
		_:
			super._edge(k, e, h, con, con_dark, top, cut)


## Water down the frame, and moss where the water stayed: on the wall's foot and
## up the run of each streak; ivy climbing over it; vines down from its head.
func _wear(k: Kit, e: Dictionary, infill: Color, h: float) -> void:
	super._wear(k, e, infill, h)
	if e.inner or not (e.kind == &"wall" or e.kind == &"window"):
		return
	var m: Vector2 = ((e.a as Vector2) + (e.b as Vector2)) * 0.5
	var o: Vector2 = e.out
	var hs := Rng.hash_ints(int(m.x * 8.0), int(m.y * 8.0), 0x1FE)
	# Ivy: a climbing mass of leaves from the floor, as high as it has got.
	if e.kind == &"wall" and (hs & 1) == 0:
		var reach := minf(h, 0.8 + 1.8 * float((hs >> 1) & 7) / 7.0)
		var n := int(reach * 14.0)
		for i in n:
			var lh := Rng.hash_ints(hs, i, 0x1)
			var v := reach * sqrt(float(lh & 1023) / 1023.0)
			var u := -0.5 + float((lh >> 10) & 1023) / 1023.0 * (1.0 - v / maxf(reach, 0.1) * 0.6)
			var sz := 0.07 + 0.04 * float((lh >> 20) & 3) / 3.0
			_wall_poly(k, m, o, [Vector2(u, v - sz), Vector2(u + sz, v), Vector2(u, v + sz), Vector2(u - sz, v)] as Array[Vector2], leaf[(lh >> 22) % leaf.size()], 0.03 + 0.002 * float(i % 3))
	# Vines down from the wall head, on the whole wall only.
	if h > 2.0:
		for i in 3:
			var u := -0.4 + 0.4 * float(i) + 0.1 * float((hs >> (i + 4)) & 1)
			var p := m - o * (THICK * 0.5 + 0.04) + Vector2(-o.y, o.x) * u
			_vine(k, Vector3(p.x, floor_y + h - 0.05, p.y), 0.4 + 1.2 * float((hs >> (i * 2 + 8)) & 3) / 3.0, hs + i)
	if e.kind != &"wall":
		return
	var mid: Vector2 = ((e.a as Vector2) + (e.b as Vector2)) * 0.5
	var out: Vector2 = e.out
	var sd := Rng.hash_ints(int(mid.x * 8.0), int(mid.y * 8.0), 0x3055)
	for i in 4:
		var u0 := -0.6 + 0.3 * float(i)
		var t0 := 0.15 + 0.25 * float((sd >> (i * 2)) & 3) / 3.0
		var t1 := 0.15 + 0.25 * float((sd >> (i * 2 + 2)) & 3) / 3.0
		_wall_poly(k, mid, out, [Vector2(u0, 0.0), Vector2(u0, minf(t0, h)), Vector2(u0 + 0.3, minf(t1, h)), Vector2(u0 + 0.3, 0.0)] as Array[Vector2], moss[i % 2], 0.034)


## The fire laid on a flat stone somebody carried up.
func _hearth_base(k: Kit, _stone: Color) -> void:
	var c := layout.hearth
	k.slab(c.x, floor_y, c.y, 1.1, 0.07, 0.95, 17, con_dark, GroundColors.made(Color(0.36, 0.34, 0.3), GroundColors.CUTSTONE), 0.03)


## The floor: the storey's concrete in its bays, split where the roots came
## through, moss over it thick by the trunk and the walls, ferns in every crack;
## and on it what the people and the forest keep.
func _boards(k: Kit, l: InteriorLayout, _dress: BiomeDressing) -> void:
	var trunk := _trunk()
	for r: Rect2i in l.rooms:
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var h := Rng.hash_ints(x, y, 0x600F)
				var p := Vector2(x + 0.5, y + 0.5)
				var near := p.distance_to(trunk)
				var tilt := 0.0
				if near < 1.6:
					# Heaved by the roots: the bay lifted and tipped.
					tilt = 0.08 * (1.0 - near / 1.6)
				var col := Kit.tone(con_dark, 0.9 + 0.2 * float(h & 255) / 255.0)
				k.slab(p.x, floor_y - 0.01 + tilt, p.y, 0.97, 0.045, 0.97, h, col, col, 0.004, 0.0, tilt * 0.5)
				# Moss: thick by the trunk and the walls, patchy between.
				var edge := mini(mini(x - r.position.x, r.end.x - 1 - x), mini(y - r.position.y, r.end.y - 1 - y))
				var want := 0.97 if near < 2.2 else (0.85 if edge == 0 else 0.45)
				for mm in 2:
					if Rng.hash01(h, 3 + mm) < want and not _walked(l, p):
						k.clump(p.x + Kit.j(h, 1 + mm * 7, 0.3), floor_y + 0.02 + tilt, p.y + Kit.j(h, 2 + mm * 7, 0.3), 0.42 + 0.14 * float(mm), 0.04, h + mm, moss[(h + mm) % 3], 8)
				# Leaves down from the canopy through the hole, over everything.
				for lf in 4:
					var lh := Rng.hash_ints(h, lf, 0x1EAF)
					var lp := p + Vector2(float(lh & 255) / 255.0 - 0.5, float((lh >> 8) & 255) / 255.0 - 0.5)
					var la := float((lh >> 16) & 255) / 255.0 * TAU
					var lc: Color = [leaf[1], leaf[0], GroundColors.made(Color(0.42, 0.34, 0.16), GroundColors.CLOTH)][(lh >> 24) % 3]
					var lv := Vector3(cos(la), 0.0, sin(la)) * 0.06
					var lq := Vector3(lp.x, floor_y + 0.045 + tilt, lp.y)
					k.made.quad(lq - lv, lq + Vector3(-lv.z, 0.0, lv.x) * 0.5, lq + lv, lq - Vector3(-lv.z, 0.0, lv.x) * 0.5, lc)
				if (h >> 12) % 4 == 0 and not _walked(l, p):
					_fern(k, p + Vector2(Kit.j(h, 4, 0.3), Kit.j(h, 5, 0.3)), h)
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		k.slab((lo.x + hi.x) * 0.5, floor_y - 0.02, (lo.y + hi.y) * 0.5, hi.x - lo.x, 0.03, hi.y - lo.y, 3, grit, grit, 0.0)
	for t: Dictionary in l.things:
		var at: Vector2 = t.at
		var f: Vector2 = t.face
		match t.kind:
			&"trunk": _trunk_draw(k, at)
			&"roots": _roots(k, at)
			&"vines": _trunk_vines(k, at)
			&"nest": _nest(k, at, f, float(t.deep))
			&"basin": _basin(k, at)
			&"gourds": _gourds(k, at, f)
			&"seedlings": _seedlings(k, at, f)
			&"pegs": _pegs(k, at)


## A fern: a spray of fronds arching out of a crack.
func _fern(k: Kit, at: Vector2, sd: int) -> void:
	for i in 6:
		var a := float(i) / 6.0 * TAU + Kit.j(sd, i, 0.4)
		var tip := Vector3(at.x + cos(a) * 0.32, floor_y + 0.22 + Kit.j(sd, i + 8, 0.06), at.y + sin(a) * 0.32)
		k.blade(Vector3(at.x, floor_y + 0.02, at.y), tip, 0.09, a + PI * 0.5, leaf[i % leaf.size()])


## A vine from `top` down `long`, a few leaves on it.
func _vine(k: Kit, top: Vector3, long: float, sd: int) -> void:
	var bottom := top + Vector3(Kit.j(sd, 1, 0.08), -long, Kit.j(sd, 2, 0.08))
	k.made.strut(top, bottom, 0.008, 3, leaf[2])
	for i in 4:
		var p := top.lerp(bottom, (float(i) + 0.5) / 4.0)
		k.blade(p, p + Vector3(0.08 * (float(i % 2) * 2.0 - 1.0), -0.05, 0.03), 0.06, float(i), leaf[i % 2])


## The trunk: up out of the break in the slab below and out of the hole above,
## buttressed where it took the floor, its bark ridged.
func _trunk_draw(k: Kit, at: Vector2) -> void:
	var foot := Vector3(at.x, floor_y - 0.6, at.y)
	var head := Vector3(at.x + 0.08, floor_y + kind.wall_h + 2.2, at.y - 0.05)
	k.limb(foot, head, 0.56, 0.4, 10, bark, Vector3(0.1, 0.0, 0.05), Kit.GROWN)
	# Ridges down the bark.
	for i in 8:
		var a := float(i) / 8.0 * TAU
		var o := Vector3(cos(a), 0.0, sin(a))
		k.made.strut(foot + o * 0.56 + Vector3.UP * 0.6, head + o * 0.41 + Vector3.DOWN * 0.2, 0.025, 3, bark_dark)
	# Buttresses flaring into the floor.
	for i in 5:
		var a := float(i) / 5.0 * TAU + 0.3
		var o := Vector3(cos(a), 0.0, sin(a))
		k.limb(Vector3(at.x, floor_y + 1.0, at.y) + o * 0.4, Vector3(at.x, floor_y - 0.05, at.y) + o * 1.05, 0.2, 0.1, 5, bark, Vector3.ZERO, Kit.GROWN)
	# The slab broken round it: plates of the floor tipped up against the trunk.
	for i in 6:
		var a := float(i) / 6.0 * TAU + 0.1
		var p := at + Vector2(cos(a), sin(a)) * 0.95
		k.made.push(Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, 0.35), Vector3(p.x, floor_y, p.y)))
		k.slab(0.0, -0.05, 0.0, 0.5, 0.1, 0.45, 150 + i, con_dark, con, 0.03)
		k.made.pop()


## Roots out over the concrete from the trunk's foot, half sunk, splitting it.
func _roots(k: Kit, at: Vector2) -> void:
	for i in 7:
		var h := Rng.hash_ints(i, 0x2007)
		var a := float(i) / 7.0 * TAU + Kit.j(h, 1, 0.3)
		var long := 1.6 + 1.2 * float(h & 255) / 255.0
		var o := Vector3(cos(a), 0.0, sin(a))
		var start := Vector3(at.x, floor_y + 0.02, at.y) + o * 0.9
		var end := start + o * long + Vector3(Kit.j(h, 2, 0.4), -0.06, Kit.j(h, 3, 0.4))
		k.limb(start, end, 0.12, 0.03, 5, bark_dark, Vector3(0.0, 0.05, 0.0), Kit.GROWN)


## Vines from the ceiling's broken edge round the trunk, and up the bark.
func _trunk_vines(k: Kit, at: Vector2) -> void:
	for i in 10:
		var a := float(i) / 10.0 * TAU
		var p := at + Vector2(cos(a), sin(a)) * (OPEN + 0.05)
		_vine(k, Vector3(p.x, floor_y + kind.wall_h - 0.05, p.y), 0.6 + 1.3 * float(Rng.hash_ints(i, 0x71E) & 7) / 7.0, 300 + i)


## The sleeping platform: poles lashed on salvage legs, a weave of split cane
## on them, a blanket and a rolled one.
func _nest(k: Kit, at: Vector2, f: Vector2, deep: float) -> void:
	var s := Vector2(-f.y, f.x)
	for u: float in [-1.0, 1.0]:
		for v: float in [-1.0, 1.0]:
			var p := at + f * v * (deep * 0.5 - 0.1) + s * u * 0.4
			k.made.strut(Vector3(p.x, floor_y, p.y), Vector3(p.x, floor_y + 0.5, p.y), 0.035, 5, plate_patch[0])
	for u: float in [-0.42, 0.42]:
		var a := at + s * u - f * deep * 0.55
		var b := at + s * u + f * deep * 0.55
		k.limb(Vector3(a.x, floor_y + 0.5, a.y), Vector3(b.x, floor_y + 0.5, b.y), 0.04, 0.035, 5, bark, Vector3.ZERO, Kit.SAWN)
	var weave := GroundColors.made(P.SAND[3], GroundColors.THATCH)
	for i in 9:
		var v := -deep * 0.5 + deep * float(i) / 8.0
		var a := at + f * v - s * 0.44
		var b := at + f * v + s * 0.44
		k.made.strut(Vector3(a.x, floor_y + 0.54, a.y), Vector3(b.x, floor_y + 0.54, b.y), 0.03, 4, Kit.tone(weave, 0.9 + 0.1 * float(i % 2)))
	_box_at(k, at, f, 0.0, 0.1, 0.56, 0.8, deep * 0.7, 0.05, GroundColors.made(Color(0.24, 0.36, 0.3), GroundColors.CLOTH), 401)
	_box_at(k, at, f, 0.0, -deep * 0.38, 0.56, 0.7, 0.24, 0.14, GroundColors.made(Color(0.6, 0.5, 0.36), GroundColors.CLOTH), 402)


## The basin under the drip: a hubcap of a machine, set in the moss.
func _basin(k: Kit, at: Vector2) -> void:
	k.found.prism(at.x, floor_y + 0.01, at.y, 0.22, floor_y + 0.08, 0.3, 12, P.PLATE[2], P.PLATE[3])
	k.made.prism(at.x, floor_y + 0.06, at.y, 0.26, floor_y + 0.07, 0.26, 12, GroundColors.made(Color(0.1, 0.14, 0.14), GroundColors.GLASS), GroundColors.made(Color(0.1, 0.14, 0.14), GroundColors.GLASS))


func _gourds(k: Kit, at: Vector2, f: Vector2) -> void:
	var col := GroundColors.made(Color(0.7, 0.56, 0.28), GroundColors.CLAY)
	for i in 3:
		var p := _q(at, f, -0.2 + 0.2 * float(i), 0.05 * float(i % 2), 0.0)
		k.made.prism(p.x, p.y, p.z, 0.08, p.y + 0.12, 0.13, 10, col, col)
		k.made.prism(p.x, p.y + 0.12, p.z, 0.13, p.y + 0.24, 0.05, 10, col, Kit.tone(col, 0.7))


## Seedlings in whatever holds earth: tins, a helmet, a boot.
func _seedlings(k: Kit, at: Vector2, f: Vector2) -> void:
	for i in 3:
		var p := _q(at, f, -0.2 + 0.2 * float(i), 0.0, 0.0)
		k.made.prism(p.x, p.y, p.z, 0.08, p.y + 0.12, 0.08, 8, plate_patch[i % 2], GroundColors.made(P.EARTH[1], GroundColors.CLAY))
		k.clump(p.x, p.y + 0.12, p.z, 0.08, 0.12, 411 + i, leaf[i % leaf.size()], 6, 0.3)


## Pegs driven up the trunk, a rope hanging from the top one.
func _pegs(k: Kit, at: Vector2) -> void:
	for i in 7:
		var a := float(i) * 2.4
		var y := 0.5 + 0.34 * float(i)
		var o := Vector3(cos(a), 0.0, sin(a))
		var p := Vector3(at.x, floor_y + y, at.y) + o * 0.5
		k.made.strut(p, p + o * 0.2, 0.02, 4, bark_dark)
	var top := Vector3(at.x, floor_y + 2.6, at.y) + Vector3(0.5, 0, 0)
	k.made.strut(top, top + Vector3(0.05, -2.4, 0.08), 0.012, 3, GroundColors.made(P.SAND[2], GroundColors.ROPE))


## The slab over the storey, the hole the trunk went out of broken through it,
## chunks hanging on their bars at its edge, and the sky up it.
func _roof(k: Kit, h: float, _frame: Color) -> void:
	var c := _trunk()
	var y := floor_y + h
	for r: Rect2i in layout.rooms:
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		var hl := c - Vector2.ONE * OPEN
		var hh := c + Vector2.ONE * OPEN
		k.made.box(Vector3(lo.x, y, lo.y), Vector3(hi.x, y + 0.3, hl.y), con, con, true)
		k.made.box(Vector3(lo.x, y, hh.y), Vector3(hi.x, y + 0.3, hi.y), con, con, true)
		k.made.box(Vector3(lo.x, y, hl.y), Vector3(hl.x, y + 0.3, hh.y), con, con, true)
		k.made.box(Vector3(hh.x, y, hl.y), Vector3(hi.x, y + 0.3, hh.y), con, con, true)
	for i in 8:
		var a := float(i) / 8.0 * TAU
		var p := c + Vector2(cos(a), sin(a)) * OPEN
		k.slab(p.x, y - 0.14, p.y, 0.3, 0.16, 0.24, 500 + i, con_dark, con_dark, 0.04)
		k.made.strut(Vector3(p.x, y, p.y), Vector3(p.x + 0.12 * cos(a + 1.0), y - 0.4, p.y + 0.12 * sin(a + 1.0)), 0.01, 4, P.RUST[2])
	var sky := Kit.new()
	var top := Vector3(c.x, y + 0.32, c.y)
	sky.made.quad(top + Vector3(-OPEN, 0.0, -OPEN), top + Vector3(OPEN, 0.0, -OPEN), top + Vector3(OPEN, 0.0, OPEN), top + Vector3(-OPEN, 0.0, OPEN), Color.WHITE)
	_slab_sky = _mesh(sky, pane_mat, "slab_sky")
	_slab_sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lights.append([Vector3(c.x + 0.7, y + 0.2, c.y + 0.3), &"sky"])
