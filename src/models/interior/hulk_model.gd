extends "res://src/models/interior/stilt_model.gd"
## THE HOLD OF A HULK, drawn from inside (docs/interiors; the recipe is
## src/content/interiors/hulk_hold.gd). The stilt house's water-keeping things
## (hammock, bilge hatch, buckets, traps) and the cottage's bones under them, in
## a steel hull: ribs standing up both sides and curving in overhead, the plate
## between them riveted and rust-run, portholes along the waterline, deck beams
## overhead and the open hatch in the deck where the day comes down. The hull
## is the machines' age's rolled plate, so its stains are rust and not damp.

const HATCH := Vector2(1.4, 1.1)

var hull: Color
var hull_dark: Color
var rib: Color
var rivet: Color
var rust_run: Color
var deck: Color
var drum: Color
var brass: Color
var _hatch_sky: MeshInstance3D


func build(l: InteriorLayout, k: InteriorKind, land: int, mat: Material) -> void:
	hull = GroundColors.made(P.RUST[1].lerp(P.PLATE[2], 0.45), GroundColors.TAR)
	hull_dark = GroundColors.made(P.RUST[0].lerp(P.PLATE[1], 0.5), GroundColors.TAR)
	rib = GroundColors.made(P.PLATE[1].lerp(P.RUST[1], 0.3), GroundColors.TAR)
	rivet = GroundColors.made(P.PLATE[3], GroundColors.ENAMEL)
	rust_run = GroundColors.made(P.RUST[2], GroundColors.TAR)
	deck = GroundColors.made(P.PLATE[1].lerp(P.INK[2], 0.3), GroundColors.TAR)
	drum = GroundColors.made(Color(0.28, 0.12, 0.08), GroundColors.TAR)
	brass = GroundColors.made(Color(0.62, 0.48, 0.22), GroundColors.ENAMEL)
	super.build(l, k, land, mat)


## A frame's width of hull: the plate, bowed in a little as it rises, a rib
## standing up at the frame's end with its flange, rivets down the seam; a
## porthole in the plate where there is a window; the companion's opening at
## the way in; the bulkhead's oval door between the hold and the fore cabin.
func _edge(k: Kit, e: Dictionary, h: float, _infill: Color, _frame: Color, top: Color, cut: bool) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var mid := (a + b) * 0.5
	var along := (b - a).normalized()
	var out: Vector2 = e.out
	var sd := Rng.hash_ints(int(mid.x * 8.0), int(mid.y * 8.0), 0x401C)
	var sx := absf(along.x) * (1.0 + THICK) + absf(along.y) * THICK
	var sz := absf(along.y) * (1.0 + THICK) + absf(along.x) * THICK
	var cap := top if cut else hull
	match e.kind:
		&"door":
			# The companion: plate to the deck like the rest, a steel ladder up
			# its inner face to the opening in the deck (`_roof`).
			k.slab(mid.x, floor_y, mid.y, sx, h, sz, sd, hull, cap, 0.0)
			if not cut:
				var foot := mid - out * (THICK * 0.5 + 0.45)
				var head := mid - out * (THICK * 0.5 + 0.12)
				for s: float in [-0.25, 0.25]:
					var r0 := foot + along * s
					var r1 := head + along * s
					k.made.strut(Vector3(r0.x, floor_y, r0.y), Vector3(r1.x, floor_y + h + 0.3, r1.y), 0.025, 5, rib)
				for r in 8:
					var t := (float(r) + 0.5) / 8.0
					var p := foot.lerp(head, t)
					k.made.strut(Vector3(p.x - along.x * 0.25, floor_y + (h + 0.3) * t, p.y - along.y * 0.25), Vector3(p.x + along.x * 0.25, floor_y + (h + 0.3) * t, p.y + along.y * 0.25), 0.015, 4, rivet)
			return
		&"inner":
			# The bulkhead: plate to the deck, an oval door in it hooked open.
			k.slab(mid.x, floor_y + 1.75, mid.y, sx, h - 1.75, sz, sd, hull, cap, 0.0)
			for s: float in [-0.42, 0.42]:
				var p := mid + along * s
				k.slab(p.x, floor_y, p.y, absf(along.x) * 0.16 + absf(along.y) * THICK, minf(h, 1.75), absf(along.y) * 0.16 + absf(along.x) * THICK, sd + 2, hull, cap, 0.0)
			if not cut:
				var coam := mid
				k.slab(coam.x, floor_y, coam.y, absf(along.x) * 0.7 + absf(along.y) * (THICK + 0.06), 0.22, absf(along.y) * 0.7 + absf(along.x) * (THICK + 0.06), sd + 3, rib, rib, 0.0)
				# The door itself, swung back against the plate.
				var hinge := mid + along * 0.42 - out * (THICK * 0.5 + 0.04)
				k.slab(hinge.x + along.x * 0.35, floor_y + 0.25, hinge.y + along.y * 0.35, absf(along.x) * 0.7 + absf(along.y) * 0.05, 1.45, absf(along.y) * 0.7 + absf(along.x) * 0.05, sd + 4, hull_dark, hull_dark, 0.0)
			return
	# Plate: bowed in toward the top, as a hull's side is.
	var lo := minf(h, 1.4)
	k.slab(mid.x, floor_y, mid.y, sx, lo, sz, sd, hull, cap if h <= 1.4 else hull, 0.0)
	if h > 1.4:
		var inb := -out * 0.12
		k.slab(mid.x + inb.x, floor_y + 1.4, mid.y + inb.y, sx, h - 1.4, sz, sd + 5, hull_dark, cap, 0.0, 0.0)
	if e.kind == &"window" and not cut:
		# The porthole's brass ring on the inner face.
		var c := mid - out * (THICK * 0.5 + 0.02)
		k.hoop(Vector3(c.x, floor_y + 1.2, c.y), 0.2, 14, 0.03, brass, Vector3(out.x, 0.0, out.y))
	# The rib at the frame's end, its flange toward the room.
	var at := a - out * (THICK * 0.5 + 0.06)
	var ribh := h if cut else h + 0.01
	k.slab(at.x, floor_y, at.y, absf(along.x) * 0.06 + absf(along.y) * 0.12, ribh, absf(along.y) * 0.06 + absf(along.x) * 0.12, sd + 6, rib, cap, 0.0)
	var fl := a - out * (THICK * 0.5 + 0.12)
	k.slab(fl.x, floor_y, fl.y, absf(along.x) * 0.16 + absf(along.y) * 0.03, ribh, absf(along.y) * 0.16 + absf(along.x) * 0.03, sd + 7, rib, cap, 0.0)


## Rust run down from every seam and rivet line, and the waterline the bilge
## has left on the plate.
func _wear(k: Kit, e: Dictionary, _infill: Color, h: float) -> void:
	if e.inner or not (e.kind == &"wall" or e.kind == &"window"):
		return
	var mid: Vector2 = ((e.a as Vector2) + (e.b as Vector2)) * 0.5
	var out: Vector2 = e.out
	var sd := Rng.hash_ints(int(mid.x * 8.0), int(mid.y * 8.0), 0x2A5)
	# Rivets along the seam at the plate's head and down the frame.
	for i in 6:
		var u := -0.45 + 0.18 * float(i)
		_on_wall(k, mid, out, u - 0.012, u + 0.012, minf(1.36, h - 0.02), minf(1.39, h), rivet, 0.01)
	for j in 2:
		var u := -0.2 + 0.5 * float(j) + 0.1 * float((sd >> j) & 1)
		var top := minf(1.36, h)
		_wall_poly(k, mid, out, [Vector2(u - 0.02, top), Vector2(u + 0.02, top), Vector2(u + 0.012, top - 0.7), Vector2(u - 0.006, top - 0.7)] as Array[Vector2], rust_run, 0.012)
	var wl := minf(0.3, h)
	_on_wall(k, mid, out, -0.61, 0.61, 0.0, wl, Kit.tone(rust_run, 0.7), 0.008)


func _breast(_k: Kit, _h: float, _stone: Color, _top: Color) -> void:
	pass


func _soot(_k: Kit, _h: float) -> void:
	pass


func _hearth_base(_k: Kit, _stone: Color) -> void:
	pass


## A porthole: the day as a round of sky and water, not a window's rectangle.
func _pane(sky: Kit, land: Kit, e: Dictionary, lo: float, hi: float, inset: float) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var out: Vector2 = e.out
	var mid := (a + b) * 0.5 + out * (THICK * 0.5 + 0.01)
	var along := (b - a).normalized()
	if e.kind == &"door":
		# The day up the companion is in the deck (`_roof`), not in this wall.
		return
	var c := Vector3(mid.x, floor_y + 1.2, mid.y)
	var n := 14
	for i in n:
		var a0 := float(i) / float(n) * TAU
		var a1 := float(i + 1) / float(n) * TAU
		var p0 := c + Vector3(along.x * cos(a0), sin(a0), along.y * cos(a0)) * 0.19
		var p1 := c + Vector3(along.x * cos(a1), sin(a1), along.y * cos(a1)) * 0.19
		# The water across the bottom of the round, the sky above it.
		var pen := land if sin(a0) + sin(a1) < -0.4 else sky
		pen.made.tri(c, p0, p1, Color(0.9, 0.9, 0.9))
		pen.made.tri(c, p1, p0, Color(0.9, 0.9, 0.9))


## The deck overhead: beams across, the plate over them, the hatch open in the
## middle with the sky in it and the day coming down.
func _roof(k: Kit, h: float, _frame: Color) -> void:
	var hc := layout.table
	for r: Rect2i in layout.rooms:
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		var y := floor_y + h
		var hl := hc - HATCH * 0.5
		var hh := hc + HATCH * 0.5
		if Rect2(lo, hi - lo).has_point(hc):
			k.made.box(Vector3(lo.x, y, lo.y), Vector3(hi.x, y + 0.08, hl.y), deck, deck, true)
			k.made.box(Vector3(lo.x, y, hh.y), Vector3(hi.x, y + 0.08, hi.y), deck, deck, true)
			k.made.box(Vector3(lo.x, y, hl.y), Vector3(hl.x, y + 0.08, hh.y), deck, deck, true)
			k.made.box(Vector3(hh.x, y, hl.y), Vector3(hi.x, y + 0.08, hh.y), deck, deck, true)
			# The coaming round the hatch.
			for s: float in [-1.0, 1.0]:
				k.made.box(Vector3(hl.x, y - 0.18, hc.y + s * HATCH.y * 0.5 - 0.05), Vector3(hh.x, y, hc.y + s * HATCH.y * 0.5 + 0.05), rib, rib, true)
				k.made.box(Vector3(hc.x + s * HATCH.x * 0.5 - 0.05, y - 0.18, hl.y), Vector3(hc.x + s * HATCH.x * 0.5 + 0.05, y, hh.y), rib, rib, true)
		else:
			k.made.box(Vector3(lo.x, y, lo.y), Vector3(hi.x, y + 0.08, hi.y), deck, deck, true)
		# Beams across the hold at every frame, and the knees at their ends.
		for x in range(r.position.x, r.end.x + 1):
			if absf(float(x) - hc.x) < HATCH.x * 0.5 and Rect2(lo, hi - lo).has_point(hc):
				continue
			k.made.box(Vector3(float(x) - 0.06, y - 0.22, lo.y), Vector3(float(x) + 0.06, y, hi.y), rib, rib, true)
	var sky := Kit.new()
	var top := Vector3(hc.x, floor_y + h + 0.1, hc.y)
	sky.made.quad(top + Vector3(-HATCH.x, 0.0, -HATCH.y) * 0.5, top + Vector3(HATCH.x, 0.0, -HATCH.y) * 0.5,
		top + Vector3(HATCH.x, 0.0, HATCH.y) * 0.5, top + Vector3(-HATCH.x, 0.0, HATCH.y) * 0.5, Color.WHITE)
	# The companion's opening over the ladder's head, a rim of coaming round it.
	var cm := layout.door - layout.door_out * (THICK * 0.5 + 0.3)
	var ca := Vector2(-layout.door_out.y, layout.door_out.x)
	var cy := floor_y + h - 0.01
	var c0 := cm - ca * 0.4 - layout.door_out * 0.3
	var c1 := cm + ca * 0.4 + layout.door_out * 0.3
	var lo2 := Vector2(minf(c0.x, c1.x), minf(c0.y, c1.y))
	var hi2 := Vector2(maxf(c0.x, c1.x), maxf(c0.y, c1.y))
	sky.made.quad(Vector3(lo2.x, cy, lo2.y), Vector3(hi2.x, cy, lo2.y), Vector3(hi2.x, cy, hi2.y), Vector3(lo2.x, cy, hi2.y), Color.WHITE)
	k.made.box(Vector3(lo2.x - 0.06, cy - 0.14, lo2.y - 0.06), Vector3(hi2.x + 0.06, cy - 0.02, lo2.y), rib, rib, true)
	k.made.box(Vector3(lo2.x - 0.06, cy - 0.14, hi2.y), Vector3(hi2.x + 0.06, cy - 0.02, hi2.y + 0.06), rib, rib, true)
	_hatch_sky = _mesh(sky, pane_mat, "hatch_sky")
	_hatch_sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lights.append([Vector3(hc.x, floor_y + h, hc.y), &"sky"])


## The sky up the hatch and the companion is seen only from under the deck.
func show_for(back: Vector2, over: float) -> void:
	super.show_for(back, over)
	if _hatch_sky != null:
		_hatch_sky.visible = over > 0.5


## The stilt house's floor and its water-keeping things, and what only a hulk
## keeps on top of them.
func _boards(k: Kit, l: InteriorLayout, dress: BiomeDressing) -> void:
	super._boards(k, l, dress)
	for t: Dictionary in l.things:
		var at: Vector2 = t.at
		var f: Vector2 = t.face
		match t.kind:
			&"stove": _stove(k, at, f)
			&"lamp_tube": _lamp_tube(k, at, f)
			&"builders_plate": _builders_plate(k, at, f)
			&"helmet": _helmet(k, at, f)
			&"tins": _tins(k, at, f)


## The fire's brazier: an oil drum cut down to its bottom third on three legs,
## the world's own fire laid in it (the FIRE prop draws the flames), and over it
## a hood of the same plate with its pipe out through the deck.
func _stove(k: Kit, at: Vector2, _f: Vector2) -> void:
	var p := Vector3(at.x, floor_y, at.y)
	const R := 0.5
	for i in 3:
		var a := float(i) / 3.0 * TAU + 0.4
		k.made.strut(p + Vector3(cos(a), 0.0, sin(a)) * R * 0.8, p + Vector3(cos(a), 0.0, sin(a)) * R * 0.9 + Vector3(0, 0.12, 0), 0.025, 4, rib)
	# The drum's cut-down wall, open-topped, its rim ragged where it was cut.
	var n := 16
	for i in n:
		var a0 := float(i) / float(n) * TAU
		var a1 := float(i + 1) / float(n) * TAU
		var top := 0.3 + 0.03 * float(Rng.hash_ints(i, 0xB7A) & 3)
		var p0 := p + Vector3(cos(a0), 0.0, sin(a0)) * R
		var p1 := p + Vector3(cos(a1), 0.0, sin(a1)) * R
		k.made.quad(p0 + Vector3(0, 0.1, 0), p0 + Vector3(0, top, 0), p1 + Vector3(0, top, 0), p1 + Vector3(0, 0.1, 0), drum)
		k.made.quad(p1 + Vector3(0, 0.1, 0), p1 + Vector3(0, top, 0), p0 + Vector3(0, top, 0), p0 + Vector3(0, 0.1, 0), GroundColors.down(drum, 0.4))
	k.hoop(p + Vector3(0, 0.2, 0), R + 0.01, 16, 0.014, rib)
	# The hood, and its pipe up through the deck.
	var h := kind.wall_h
	k.made.prism(p.x, p.y + 1.5, p.z, R + 0.05, p.y + 1.85, 0.12, 12, hull_dark, hull_dark)
	k.made.strut(p + Vector3(0, 1.85, 0), p + Vector3(0, h + 0.3, 0), 0.1, 8, drum)
## The stolen tube: a machine's strip light wired to a battery on a beam.
func _lamp_tube(k: Kit, at: Vector2, f: Vector2) -> void:
	var y := floor_y + kind.wall_h - 0.3
	var a := Vector3(at.x, y, at.y) - Vector3(f.x, 0.0, f.y) * 0.45
	var b := Vector3(at.x, y, at.y) + Vector3(f.x, 0.0, f.y) * 0.45
	k.found.strut(a, b, 0.03, 6, GroundColors.glow(Color(0.7, 0.86, 1.0), 1.4))
	k.found.strut(a + Vector3.UP * 0.05, b + Vector3.UP * 0.05, 0.045, 4, P.PLATE[2])
	lights.append([(a + b) * 0.5 + Vector3.DOWN * 0.1, &"strip"])


## The hull's builder's plate, riveted by the ladder: a name and a number.
func _builders_plate(k: Kit, at: Vector2, f: Vector2) -> void:
	var s := Vector2(-f.y, f.x)
	var c := at + f * 0.01
	var q := func(u: float, v: float) -> Vector3:
		var p := c + s * u
		return Vector3(p.x, floor_y + v, p.y)
	k.made.quad(q.call(0.2, 1.3), q.call(0.2, 1.55), q.call(-0.2, 1.55), q.call(-0.2, 1.3), brass)
	for i in 3:
		var y := 1.35 + 0.07 * float(i)
		var c2 := c + f * 0.004
		var p0 := c2 - s * (0.14 - 0.03 * float(i % 2))
		var p1 := c2 + s * (0.14 - 0.02 * float(i))
		k.made.strut(Vector3(p0.x, floor_y + y, p0.y), Vector3(p1.x, floor_y + y, p1.y), 0.006, 3, hull_dark)


## A diving helmet on a hook: a brass dome, its front glass, the hose coiled.
func _helmet(k: Kit, at: Vector2, f: Vector2) -> void:
	var c := Vector3(at.x, floor_y + 1.35, at.y) - Vector3(f.x, 0.0, f.y) * 0.05
	k.made.prism(c.x, c.y - 0.2, c.z, 0.2, c.y, 0.22, 12, brass, brass)
	k.made.prism(c.x, c.y, c.z, 0.22, c.y + 0.18, 0.08, 12, brass, brass)
	var g := c + Vector3(f.x, 0.0, f.y) * 0.21
	k.made.prism(g.x, g.y - 0.08, g.z, 0.07, g.y + 0.06, 0.07, 10, GroundColors.made(Color(0.1, 0.14, 0.16), GroundColors.GLASS), GroundColors.made(Color(0.1, 0.14, 0.16), GroundColors.GLASS))
	k.hoop(Vector3(at.x, floor_y + 0.1, at.y) + Vector3(f.x, 0.0, f.y) * 0.1, 0.2, 14, 0.025, GroundColors.made(Color(0.16, 0.16, 0.14), GroundColors.TAR))


## Greens in tins, set out on a crate where the hatch's light reaches.
func _tins(k: Kit, at: Vector2, f: Vector2) -> void:
	k.slab(at.x, floor_y, at.y, 0.5, 0.3, 0.4, int(at.x * 5.0), wood_dark, wood, 0.01)
	var leaf := GroundColors.made(P.MOSS[3], GroundColors.CLOTH)
	for i in 3:
		var s := Vector2(-f.y, f.x) * (-0.15 + 0.15 * float(i))
		var p := Vector3(at.x + s.x, floor_y + 0.3, at.y + s.y)
		k.made.prism(p.x, p.y, p.z, 0.06, p.y + 0.1, 0.06, 8, P.RUST[2], P.RUST[3])
		k.clump(p.x, p.y + 0.1, p.z, 0.09, 0.12, 131 + i, leaf, 6, 0.2)
