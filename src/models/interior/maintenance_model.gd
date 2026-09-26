extends "res://src/models/interior/cottage_model.gd"
## A MACHINE CITY MAINTENANCE BAY, drawn from inside (the recipe is
## src/content/interiors/maintenance_bay.gd). A cottage's bones -- its edges, its
## cut walls for the camera -- in a room built for a machine: walls of plate in
## exact one-tile panels with their seams inked, a deck of plate with the guide
## line painted down it, a ceiling of plate with the gantry's rail. The room's
## shell is `made` (painted plate); what the machines use -- the cradle, the
## gantry, the racks, the panel -- is `found`, their own material. It is lit by
## nothing a person needs: a charge lamp, a panel, standby points.
##
## The hatch is the way in, and it is lower than a person stands. The gap into
## the niche is a panel taken out, not a doorway: no jambs, a torn edge.

const P := preload("res://src/render/palette.gd")

var plate: Color
var plate_dark: Color
var seam: Color
var deck: Color
var deck_dark: Color
var hazard: Color
var ceiling: Color
var chalk: Color
var standby: Color
var charge: Color

## The hatch's head: under a person's height, over a machine's.
const HATCH_H := 1.4
## Where the recipe stands a wall-hung thing off its wall's line; drawn, it is
## on the wall's face.
const WALL_GAP := 0.25


func build(l: InteriorLayout, k: InteriorKind, land: int, mat: Material) -> void:
	plate = GroundColors.made(Color(0.36, 0.39, 0.42), GroundColors.ENAMEL)
	plate_dark = GroundColors.made(Color(0.24, 0.27, 0.3), GroundColors.ENAMEL)
	seam = GroundColors.made(Color(0.06, 0.07, 0.08), GroundColors.TAR)
	deck = GroundColors.made(Color(0.29, 0.31, 0.33), GroundColors.ENAMEL)
	deck_dark = GroundColors.made(Color(0.2, 0.22, 0.24), GroundColors.ENAMEL)
	hazard = GroundColors.made(Color(0.86, 0.66, 0.12), GroundColors.ENAMEL)
	ceiling = GroundColors.made(Color(0.14, 0.15, 0.17), GroundColors.ENAMEL)
	chalk = GroundColors.made(Color(0.82, 0.8, 0.74), GroundColors.CLAY)
	standby = GroundColors.glow(Color(1.0, 0.56, 0.16), 1.1)
	charge = GroundColors.glow(Color(0.5, 0.62, 1.0), 1.2)
	super.build(l, k, land, mat)


## A unit of wall: one plate, its seams inked at both ends and across it at the
## height the panels are joined, a kick plate at its foot. The hatch, low, with
## its hazard band. The niche's gap, a panel gone.
func _edge(k: Kit, e: Dictionary, h: float, _infill: Color, _frame: Color, top: Color, cut: bool) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var mid := (a + b) * 0.5
	var along := (b - a).normalized()
	var sx := absf(along.x) * (1.0 + THICK) + absf(along.y) * THICK
	var sz := absf(along.y) * (1.0 + THICK) + absf(along.x) * THICK
	var sd := int(mid.x * 7.0 + mid.y * 13.0)
	match e.kind:
		&"wall":
			k.slab(mid.x, floor_y, mid.y, sx, h, sz, sd, plate, top if cut else plate, 0.0)
			if e.inner:
				return
			var out: Vector2 = e.out
			for u: float in [-0.5, 0.5]:
				_on_wall(k, mid, out, u - 0.012, u + 0.012, 0.0, h, seam, 0.004)
			if h > 1.16:
				_on_wall(k, mid, out, -0.5, 0.5, 1.14, 1.16, seam, 0.004)
			_on_wall(k, mid, out, -0.5, 0.5, 0.0, minf(0.18, h), plate_dark, 0.012)
		&"door":
			# Jambs to the hatch's head and the wall whole above it.
			for p: Vector2 in [a + along * 0.08, b - along * 0.08]:
				k.slab(p.x, floor_y, p.y, 0.16, minf(HATCH_H, h), 0.16, int(p.x * 11.0 + p.y), plate_dark, top if cut else plate_dark, 0.0)
			if not cut:
				k.slab(mid.x, floor_y + HATCH_H, mid.y, sx, h - HATCH_H, sz, sd + 2, plate, plate, 0.0)
				var out: Vector2 = e.out
				for i in 8:
					var u0 := -0.5 + float(i) / 8.0
					_on_wall(k, mid, out, u0, u0 + 1.0 / 8.0, HATCH_H, HATCH_H + 0.14, hazard if i % 2 == 0 else seam, 0.012)
		&"inner":
			# A panel taken out: the plate stands above it, and the cut is ragged.
			if not cut:
				k.slab(mid.x, floor_y + 1.95, mid.y, sx, h - 1.95, sz, sd + 3, plate, plate, 0.0)
			for i in 4:
				var p := a.lerp(b, 0.04 + 0.92 * float(i % 2)) + along * (0.03 if i % 2 == 0 else -0.03)
				var y0 := 0.35 + 0.45 * float(i / 2)
				k.slab(p.x, floor_y + y0, p.y, 0.05, 0.3, 0.05, sd + 10 + i, plate_dark, plate_dark, 0.02)


func _wear(_k: Kit, _e: Dictionary, _infill: Color, _h: float) -> void:
	pass


func _breast(_k: Kit, _h: float, _stone: Color, _top: Color) -> void:
	pass


func _soot(_k: Kit, _h: float) -> void:
	pass


func _hearth_base(_k: Kit, _stone: Color) -> void:
	pass


## The deck: plate in exact squares with their seams, the guide line painted
## down the bay, the niche's floor left bare where the parts were dragged out;
## and on it what the machines use and what the trespasser keeps.
func _boards(k: Kit, l: InteriorLayout, _dress: BiomeDressing) -> void:
	for ri in l.rooms.size():
		var r := l.rooms[ri]
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var col := deck if ri == 0 else deck_dark
				k.slab(float(x) + 0.5, floor_y - 0.01, float(y) + 0.5, 0.97, 0.04, 0.97, x * 31 + y, col, col, 0.0)
	var bay := l.rooms[0]
	var cx := float(bay.position.x) + float(bay.size.x) * 0.5
	k.slab(cx, floor_y + 0.03, float(bay.position.y) + float(bay.size.y) * 0.5, 0.08, 0.004, float(bay.size.y) - 0.4, 900, hazard, hazard, 0.0)
	for t: Dictionary in l.things:
		var at: Vector2 = t.at
		var f: Vector2 = t.face
		match t.kind:
			&"gantry": _gantry(k, at, f, float(t.deep))
			&"tool_head": _tool_head(k, at)
			&"drain": _drain(k, at)
			&"diag_panel": _diag_panel(k, at, f)
			&"cradle": _cradle(k, at, f, float(t.deep))
			&"bins": _bins(k, at, f, float(t.long))
			&"rack": _rack(k, at, f, float(t.long))
			&"sort_bench": _sort_bench(k, at, f, float(t.long))
			&"tally": _tally(k, at, f)
			&"tin": _tin(k, at)
			&"bedroll": _bedroll(k, at, f)


## Across a thing facing `f`: `u` along its wall, `v` out from it, `h` up.
func _q(at: Vector2, f: Vector2, u: float, v: float, h: float) -> Vector3:
	var s := Vector2(-f.y, f.x)
	var p := at + s * u + f * v
	return Vector3(p.x, floor_y + h, p.y)


func _box(pen: MeshKit, at: Vector2, f: Vector2, u0: float, u1: float, v0: float, v1: float, h0: float, h1: float, col: Color, top := Color(0, 0, 0, 0)) -> void:
	var a := _q(at, f, u0, v0, h0)
	var b := _q(at, f, u1, v1, h1)
	pen.box(Vector3(minf(a.x, b.x), a.y, minf(a.z, b.z)), Vector3(maxf(a.x, b.x), b.y, maxf(a.z, b.z)), col, top)


## The gantry's rail the bay's length under the ceiling, and its hangers.
func _gantry(k: Kit, at: Vector2, f: Vector2, deep: float) -> void:
	var y := kind.wall_h - 0.18
	_box(k.found, at, f, -0.08, 0.08, -deep * 0.5, deep * 0.5, y, y + 0.14, P.PLATE[1], P.PLATE[2])
	for i in 4:
		var v := -deep * 0.5 + 0.3 + (deep - 0.6) * float(i) / 3.0
		k.found.strut(_q(at, f, 0.0, v, y + 0.14), _q(at, f, 0.0, v, kind.wall_h), 0.02, 4, P.PLATE[0])


## The tool head, parked on the rail: a carriage, a wrist, a head of tools
## folded, down to a person's shoulder.
func _tool_head(k: Kit, at: Vector2) -> void:
	var y := kind.wall_h - 0.18
	k.found.box(Vector3(at.x - 0.16, floor_y + y - 0.16, at.y - 0.2), Vector3(at.x + 0.16, floor_y + y, at.y + 0.2), P.PLATE[2], P.PLATE[3])
	var wrist := Vector3(at.x, floor_y + y - 0.16, at.y)
	var head := wrist + Vector3(0.0, -0.22, 0.0)
	k.found.strut(wrist, head, 0.05, 6, P.PLATE[1])
	k.found.prism(head.x, head.y - 0.12, head.z, 0.12, head.y, 0.09, 8, P.PLATE[3], P.PLATE[2])
	for i in 3:
		var a := float(i) / 3.0 * TAU
		k.found.strut(head + Vector3(0, -0.12, 0), head + Vector3(cos(a) * 0.12, -0.26, sin(a) * 0.12), 0.012, 3, P.PLATE[4])


func _drain(k: Kit, at: Vector2) -> void:
	k.made.box(Vector3(at.x - 0.3, floor_y + 0.03, at.y - 0.3), Vector3(at.x + 0.3, floor_y + 0.035, at.y + 0.3), seam, seam)
	for i in 5:
		var x := at.x - 0.24 + 0.12 * float(i)
		k.made.box(Vector3(x - 0.02, floor_y + 0.035, at.y - 0.28), Vector3(x + 0.02, floor_y + 0.045, at.y + 0.28), deck_dark, deck)


## The diagnostic panel, low on the wall where a machine's sensor comes: a plate,
## a port, a column of status points, one of them lit.
func _diag_panel(k: Kit, at: Vector2, f: Vector2) -> void:
	var w := at - f * WALL_GAP
	_box(k.found, w, f, -0.26, 0.26, 0.0, 0.05, 0.28, 0.72, P.PLATE[1], P.PLATE[2])
	_box(k.found, w, f, -0.08, 0.08, 0.05, 0.07, 0.42, 0.52, P.INK[0])
	for i in 4:
		var hh := 0.34 + 0.08 * float(i)
		_box(k.made, w, f, 0.14, 0.18, 0.05, 0.07, hh, hh + 0.04, charge if i == 2 else seam)
	lights.append([_q(w, f, 0.16, 0.25, 0.46), &"machine"])


## The cradle a machine is backed into and charged in: two rails, the contacts
## at its head, a lamp that says it is empty.
func _cradle(k: Kit, at: Vector2, f: Vector2, deep: float) -> void:
	for u: float in [-0.46, 0.46]:
		_box(k.found, at, f, u - 0.07, u + 0.07, -deep * 0.5, deep * 0.5, 0.0, 0.34, P.PLATE[2], P.PLATE[3])
	_box(k.found, at, f, -0.55, 0.55, -deep * 0.5 - 0.1, -deep * 0.5 + 0.08, 0.0, 1.3, P.PLATE[1], P.PLATE[2])
	for u: float in [-0.2, 0.2]:
		_box(k.found, at, f, u - 0.05, u + 0.05, -deep * 0.5 + 0.08, -deep * 0.5 + 0.2, 0.7, 0.8, P.COPPER[3])
	_box(k.made, at, f, -0.04, 0.04, -deep * 0.5 + 0.08, -deep * 0.5 + 0.1, 1.12, 1.18, charge)
	lights.append([_q(at, f, 0.0, -deep * 0.5 + 0.3, 1.15), &"machine"])


## Bins of spares in exact rows against the wall, each with its standby point.
func _bins(k: Kit, at: Vector2, f: Vector2, long: float) -> void:
	var w := at - f * 0.03
	var n := int(long / 0.36)
	for row in 3:
		for i in n:
			var u := -long * 0.5 + (float(i) + 0.5) * long / float(n)
			var h0 := 0.05 + 0.42 * float(row)
			_box(k.found, w, f, u - 0.15, u + 0.15, -0.2, 0.2, h0, h0 + 0.36, P.PLATE[2] if (i + row) % 2 == 0 else P.PLATE[1], P.PLATE[3])
			_box(k.made, w, f, u + 0.08, u + 0.12, 0.2, 0.21, h0 + 0.26, h0 + 0.3, standby)
	lights.append([_q(w, f, 0.0, 0.4, 0.8), &"standby"])


## A rack the length of the wall: uprights, three shelves, parts on them in
## exact rows -- and a gap in one, the width of a hand.
func _rack(k: Kit, at: Vector2, f: Vector2, long: float) -> void:
	var w := at
	var posts := int(long / 0.9) + 1
	for i in posts:
		var u := -long * 0.5 + long * float(i) / float(posts - 1)
		for v: float in [-0.22, 0.22]:
			_box(k.found, w, f, u - 0.03, u + 0.03, v - 0.03, v + 0.03, 0.0, 2.0, P.PLATE[0])
	for row in 3:
		var h := 0.35 + 0.6 * float(row)
		_box(k.found, w, f, -long * 0.5, long * 0.5, -0.25, 0.25, h, h + 0.04, P.PLATE[1], P.PLATE[2])
		var n := int(long / 0.3)
		for i in n:
			if row == 1 and i == n / 3:
				continue
			var u := -long * 0.5 + (float(i) + 0.5) * long / float(n)
			_box(k.found, w, f, u - 0.09, u + 0.09, -0.15, 0.15, h + 0.04, h + 0.24, P.PLATE[3] if i % 3 != 0 else P.RUST[3], P.PLATE[4])
	_box(k.made, w, f, long * 0.5 - 0.1, long * 0.5 - 0.06, 0.26, 0.27, 1.6, 1.64, standby)
	lights.append([_q(w, f, long * 0.5 - 0.1, 0.4, 1.6), &"standby"])


## The bench the parts are sorted on, across the bay's end: a plate on legs, a
## chute, a row of trays.
func _sort_bench(k: Kit, at: Vector2, f: Vector2, long: float) -> void:
	_box(k.found, at, f, -long * 0.5, long * 0.5, -0.3, 0.3, 0.78, 0.84, P.PLATE[2], P.PLATE[3])
	for u: float in [-long * 0.5 + 0.1, long * 0.5 - 0.1]:
		for v: float in [-0.24, 0.24]:
			_box(k.found, at, f, u - 0.03, u + 0.03, v - 0.03, v + 0.03, 0.0, 0.78, P.PLATE[0])
	for i in 5:
		var u := -long * 0.5 + 0.3 + (long - 0.6) * float(i) / 4.0
		_box(k.found, at, f, u - 0.16, u + 0.16, -0.2, 0.1, 0.84, 0.92, P.PLATE[1], P.PLATE[3])
	_box(k.found, at, f, -0.2, 0.2, -0.3, -0.25, 0.84, 1.9, P.PLATE[1])


## THE COUNT. Scratched into the niche's back plate with something hard, in
## fives, row under row, by someone who kept on counting.
func _tally(k: Kit, at: Vector2, f: Vector2) -> void:
	var w := at - f * WALL_GAP
	var n := 0
	for row in 6:
		var marks := 22 if row < 5 else 9
		for i in marks:
			n += 1
			var u := -0.55 + 0.05 * float(i) + 0.06 * float(i / 5)
			var h := 1.55 - 0.16 * float(row)
			var a := _q(w, f, u, 0.006, h)
			var b := _q(w, f, u, 0.006, h + 0.12)
			# Every fifth struck across the four before it.
			if n % 5 == 0:
				b = _q(w, f, u - 0.22, 0.006, h + 0.1)
				a = _q(w, f, u + 0.02, 0.006, h + 0.02)
			k.made.strut(a, b, 0.006, 3, chalk)


## A tin, opened with a blade and eaten from.
func _tin(k: Kit, at: Vector2) -> void:
	k.made.prism(at.x, floor_y, at.y, 0.05, floor_y + 0.11, 0.05, 10, GroundColors.made(Color(0.62, 0.6, 0.56), GroundColors.ENAMEL), GroundColors.made(Color(0.3, 0.28, 0.26), GroundColors.ENAMEL))


## A bedroll pushed into the gap, a coat rolled for a pillow.
func _bedroll(k: Kit, at: Vector2, f: Vector2) -> void:
	var cloth := GroundColors.made(Color(0.3, 0.27, 0.22), GroundColors.CLOTH)
	_box(k.made, at, f, -0.35, 0.35, -0.8, 0.7, 0.0, 0.08, cloth, Kit.tone(cloth, 1.1))
	k.made.strut(_q(at, f, -0.3, -0.72, 0.13), _q(at, f, 0.3, -0.72, 0.13), 0.1, 8, GroundColors.made(Color(0.22, 0.24, 0.2), GroundColors.CLOTH))


## The ceiling: plate, and nothing hung from it but the gantry.
func _roof(k: Kit, h: float, _frame: Color) -> void:
	for r: Rect2i in layout.rooms:
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		k.made.box(Vector3(lo.x, floor_y + h, lo.y), Vector3(hi.x, floor_y + h + 0.12, hi.y), ceiling, ceiling, true)
