extends Node3D
## A COTTAGE'S INSIDE, drawn (docs/interiors): the walls on the layout's edges,
## the door and window frames, the chimney breast over the hearth and a ceiling,
## all in the land's own matter (BiomeDressing) and on the MADE pen, so the room
## is lit by the renderer like everything outside it.
##
## TWO WAYS TO LOOK IN, and the model answers both (`show_for`):
##   from above   every wall that faces the camera is CUT at `kind.cut` with an
##                inked cap, the section a drawn plan makes, so no room is ever
##                hidden by its own near wall; the whole wall and the ceiling
##                still cast their shadows without being drawn, so the sun does
##                not flood a room over its cut walls and the light comes in where
##                it should -- the windows and the hearth
##   over the     every wall stands whole, and so does the ceiling
##   shoulder
## Built once per pocket, from the layout alone: the same house, the same room.

const Kit := preload("res://src/models/props/kit.gd")
const THICK := 0.22
const DIRS: Array[Vector2] = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]

var layout: InteriorLayout
var kind: InteriorKind
var floor_y := 1.0
## Per way a wall faces (DIRS index): the whole wall and the cut one.
var _full: Array[MeshInstance3D] = []
var _cut: Array[MeshInstance3D] = []
var _ceiling: MeshInstance3D
## Per way a wall faces: the daylight in its windows, drawn with the whole wall.
var _panes: Array[MeshInstance3D] = []
## What a window shows from inside, which 21_doors colours from the live sky.
var pane_mat: StandardMaterial3D


func build(l: InteriorLayout, k: InteriorKind, land: int, mat: Material) -> void:
	layout = l
	kind = k
	floor_y = TerrainMesher.level_height(InteriorGen.FLOOR_LEVEL)
	var dress := BiomeDressing.of(land)
	var wash := _pick(dress.pale, Color(0.80, 0.76, 0.68))
	var infill := GroundColors.made(Kit.tone(wash, 1.04), GroundColors.CLAY)
	var frame := GroundColors.made(_pick(dress.timber, Color(0.36, 0.28, 0.21)), GroundColors.TIMBER)
	var stone := GroundColors.made(_pick(dress.walling, Color(0.52, 0.5, 0.47)), GroundColors.CUTSTONE)
	# The section's inked cap: TAR, the darkest made row, where the wall is cut.
	var cap := GroundColors.made(Color(0.07, 0.06, 0.06), GroundColors.TAR)
	# The window's daylight is not a surface the sun lights but the sky seen
	# through a hole, so it is unshaded and coloured by the hour (`daylight`).
	pane_mat = StandardMaterial3D.new()
	pane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pane_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in DIRS.size():
		var full := Kit.new()
		var cut := Kit.new()
		for e: Dictionary in l.edges:
			if not (e.out as Vector2).is_equal_approx(DIRS[i]):
				continue
			_edge(full, e, k.wall_h, infill, frame, frame, false)
			_edge(cut, e, k.cut, infill, frame, cap, true)
		if l.hearth_wall.is_equal_approx(DIRS[i]):
			_breast(full, k.wall_h, stone, stone)
			_breast(cut, k.cut, stone, cap)
		_full.append(_mesh(full, mat, "walls_%d" % i))
		var c := _mesh(cut, mat, "cut_%d" % i)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cut.append(c)
		var pane := Kit.new()
		for e: Dictionary in l.edges:
			if not (e.out as Vector2).is_equal_approx(DIRS[i]):
				continue
			if e.kind == &"window":
				_pane(pane, e, 0.9, 1.75)
			elif e.kind == &"door":
				_pane(pane, e, 0.0, 2.05)
		var pm := _mesh(pane, pane_mat, "panes_%d" % i)
		pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_panes.append(pm)
	var always := Kit.new()
	_hearth_base(always, stone)
	_boards(always, l, dress)
	_mesh(always, mat, "floor")
	var roof := Kit.new()
	_roof(roof, k.wall_h, frame)
	_ceiling = _mesh(roof, mat, "ceiling")


## Which walls stand and whether the ceiling is drawn, for the camera as it is:
## `back` is the way from the room toward the eye on the ground, and `over` how
## far the view is over the shoulder (CameraRig.shoulder_share).
func show_for(back: Vector2, over: float) -> void:
	var whole := over > 0.5
	for i in DIRS.size():
		var faces := DIRS[i].dot(back) > 0.2
		var drawn := whole or not faces
		_full[i].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if drawn \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_cut[i].visible = not drawn
		_panes[i].visible = drawn
	_ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if whole \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## The sky seen through the windows, this frame.
func daylight(c: Color) -> void:
	pane_mat.albedo_color = c


## The windows: where each one is in the world, and the way into the room.
func windows() -> Array[Array]:
	var out: Array[Array] = []
	for e: Dictionary in layout.edges:
		if e.kind == &"window":
			var mid: Vector2 = (e.a + e.b) * 0.5
			out.append([Vector3(mid.x, floor_y + 1.3, mid.y), -(e.out as Vector2)])
	return out


static func _pick(cs: Array[Color], fallback: Color) -> Color:
	return cs[0] if not cs.is_empty() else fallback


func _mesh(k: Kit, mat: Material, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = k.made.build()
	mi.material_override = mat
	add_child(mi)
	return mi


## One unit edge of wall, `h` high: plain, a window's sill and head with a frame,
## or a doorway's posts and lintel. Cut (`cut`), it stops at `h` with an inked top.
func _edge(k: Kit, e: Dictionary, h: float, infill: Color, frame: Color, top: Color, cut: bool) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var mid := (a + b) * 0.5
	var along := (b - a).normalized()
	var w := 1.0 + THICK
	var sx := absf(along.x) * w + absf(along.y) * THICK
	var sz := absf(along.y) * w + absf(along.x) * THICK
	var seed_value := int(mid.x * 7.0 + mid.y * 13.0)
	match e.kind:
		&"wall":
			k.slab(mid.x, floor_y, mid.y, sx, h, sz, seed_value, infill, top, 0.02)
		&"window":
			var sill := minf(0.9, h)
			k.slab(mid.x, floor_y, mid.y, sx, sill, sz, seed_value, infill, top if cut else frame, 0.02)
			if not cut:
				k.slab(mid.x, floor_y + 1.75, mid.y, sx, h - 1.75, sz, seed_value + 1, infill, top, 0.02)
				_posts(k, a, b, along, 0.9, 1.75, frame, 0.2)
		&"door", &"inner":
			var head := 2.05
			var post_top := minf(head, h)
			_posts(k, a, b, along, 0.0, post_top, frame, 0.12)
			if not cut:
				k.slab(mid.x, floor_y + head, mid.y, sx, h - head, sz, seed_value + 2, infill, top, 0.02)
				k.slab(mid.x, floor_y + head - 0.12, mid.y, sx * 0.98 if absf(along.x) > 0.5 else THICK * 1.3,
					0.14, sz * 0.98 if absf(along.y) > 0.5 else THICK * 1.3, seed_value + 3, frame, frame, 0.01)


## The two jambs of an opening from `y0` to `y1` above the floor.
func _posts(k: Kit, a: Vector2, b: Vector2, along: Vector2, y0: float, y1: float, frame: Color, inset: float) -> void:
	if y1 <= y0:
		return
	for p: Vector2 in [a + along * inset, b - along * inset]:
		k.slab(p.x, floor_y + y0, p.y, 0.16, y1 - y0, 0.16, int(p.x * 11.0 + p.y), frame, frame, 0.01)


## The chimney breast over the hearth: two stone jambs either side of the fire
## and the breast above them to the ceiling, against the hearth wall.
func _breast(k: Kit, h: float, stone: Color, top: Color) -> void:
	var c := layout.hearth + layout.hearth_wall * 0.35
	var across := Vector2(-layout.hearth_wall.y, layout.hearth_wall.x)
	var deep := 0.55
	var jamb_h := minf(1.1, h)
	for s: float in [-0.62, 0.62]:
		var p := c + across * s
		var wx := absf(across.x) * 0.28 + absf(across.y) * deep
		var wz := absf(across.y) * 0.28 + absf(across.x) * deep
		k.slab(p.x, floor_y, p.y, wx, jamb_h, wz, int(p.x * 5.0 + p.y), stone, top, 0.04)
	if h > 1.1:
		var bx := absf(across.x) * 1.52 + absf(across.y) * deep
		var bz := absf(across.y) * 1.52 + absf(across.x) * deep
		k.slab(c.x, floor_y + 1.1, c.y, bx, h - 1.1, bz, int(c.x * 3.0 + c.y), stone, top, 0.04, 0.12)


## The day outside an opening, from `lo` to `hi` above the floor: a quad across it
## at the wall's outer face. A doorway takes one too, or the way out is a black
## hole into the void the pocket stands in.
func _pane(k: Kit, e: Dictionary, lo: float, hi: float) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var o: Vector2 = (e.out as Vector2) * (THICK * 0.5 + 0.01)
	var y0 := floor_y + lo
	var y1 := floor_y + hi
	k.made.quad(Vector3(a.x + o.x, y0, a.y + o.y), Vector3(b.x + o.x, y0, b.y + o.y),
		Vector3(b.x + o.x, y1, b.y + o.y), Vector3(a.x + o.x, y1, a.y + o.y), Color.WHITE)


## THE FLOOR IS BOARDS, not the ground the pocket is grown on: the terrain's own
## floor is a landscape's ground treatment (stippled, cold) and its terrace edge
## rounds off short of the walls, which drew a strip of the void round every
## room. Each board runs the room's long way and under the walls, so no seam
## shows at the foot of one, and each is its own worn tone of the land's timber.
func _boards(k: Kit, l: InteriorLayout, dress: BiomeDressing) -> void:
	# The land's timber, but a floor indoors is not sea-weathered: warmer, and
	# lighter where feet have worn it.
	var wood := Kit.tone(_pick(dress.timber, Color(0.36, 0.28, 0.21)).lerp(Color(0.46, 0.33, 0.22), 0.45), 1.3)
	const W := 0.26
	for r: Rect2i in l.rooms:
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		var along_x := r.size.x >= r.size.y
		var span := (hi.y - lo.y) if along_x else (hi.x - lo.x)
		var n := ceili(span / W)
		for i in n:
			var t0 := float(i) * span / float(n)
			var w := span / float(n) - 0.012
			var h := Rng.hash_ints(r.position.x * 131 + r.position.y, i, 0x80A2D5, 0, 0)
			var tone := 0.86 + 0.24 * float(h & 1023) / 1023.0
			var col := GroundColors.made(Kit.tone(wood, tone), GroundColors.TIMBER)
			var cx := (lo.x + hi.x) * 0.5 if along_x else lo.x + t0 + w * 0.5
			var cz := lo.y + t0 + w * 0.5 if along_x else (lo.y + hi.y) * 0.5
			var sx := (hi.x - lo.x) if along_x else w
			var sz := w if along_x else (hi.y - lo.y)
			k.slab(cx, floor_y - 0.01, cz, sx, 0.045, sz, h, col, col, 0.004)
	# The doorstep: a stone sill across the way in.
	var across := Vector2(-l.door_out.y, l.door_out.x)
	var sill := l.door + l.door_out * 0.02
	k.slab(sill.x, floor_y - 0.01, sill.y, absf(across.x) * 1.0 + absf(across.y) * (THICK + 0.1), 0.07,
		absf(across.y) * 1.0 + absf(across.x) * (THICK + 0.1), 23, GroundColors.made(Color(0.5, 0.48, 0.45), GroundColors.CUTSTONE), Color(0, 0, 0, 0), 0.01)


## The hearth's floor: a stone apron the fire stands on.
func _hearth_base(k: Kit, stone: Color) -> void:
	var p := layout.hearth + layout.hearth_wall * 0.05
	k.slab(p.x, floor_y, p.y, 1.5, 0.08, 1.2, 17, stone, stone, 0.03)


## A plank ceiling over every room, on beams across the shorter way.
## Drawn with their UNDERSIDES, because under the shoulder that is the only side
## anybody sees: a slab has none, and the room was open to the sky between beams.
func _roof(k: Kit, h: float, frame: Color) -> void:
	var boards := Kit.tone(frame, 1.18)
	for r: Rect2i in layout.rooms:
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		var y := floor_y + h
		var across_x := r.size.x <= r.size.y
		# Boards run along the beams' length, beams across the shorter way.
		var span := (hi.y - lo.y) if not across_x else (hi.x - lo.x)
		var n := ceili(span / 0.3)
		for i in n:
			var a := float(i) * span / float(n)
			var b := float(i + 1) * span / float(n) - 0.01
			var col := Kit.tone(boards, 0.9 + 0.08 * float(i % 3))
			if across_x:
				k.made.box(Vector3(lo.x + a, y, lo.y), Vector3(lo.x + b, y + 0.1, hi.y), col, col, true)
			else:
				k.made.box(Vector3(lo.x, y, lo.y + a), Vector3(hi.x, y + 0.1, lo.y + b), col, col, true)
		# A solid backing over the boards: the seams between them are a hair wide,
		# and under the sun's soft shadow a hair of light leaking through each
		# came out on the floor as a scatter of pale blobs, measured.
		k.made.box(Vector3(lo.x, y + 0.1, lo.y), Vector3(hi.x, y + 0.16, hi.y), boards, boards, true)
		var m := maxi(2, (r.size.y if across_x else r.size.x))
		for i in m:
			var t := (float(i) + 0.5) / float(m)
			var p := Vector2(r.position) + (Vector2(r.size.x * 0.5, r.size.y * t) if across_x else Vector2(r.size.x * t, r.size.y * 0.5))
			var hx := float(r.size.x) * 0.5 if across_x else 0.09
			var hz := 0.09 if across_x else float(r.size.y) * 0.5
			k.made.box(Vector3(p.x - hx, y - 0.2, p.y - hz), Vector3(p.x + hx, y, p.y + hz), frame, frame, true)
