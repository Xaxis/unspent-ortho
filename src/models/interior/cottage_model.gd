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
const Furnish := preload("res://src/models/interior/furnish.gd")
const THICK := 0.22
## Things that hang ON a wall: drawn with that wall, so a wall cut down to its
## section from above does not leave its nets and its plate hanging in the air.
const ON_WALL: Array[StringName] = [&"patch", &"nets", &"floats", &"machine_lamp"]
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
## What a window shows from inside, which 21_doors colours from the live sky and
## the land outside: the sky, and the land's line across the bottom of it.
var pane_mat: StandardMaterial3D
var land_mat: StandardMaterial3D
## Where the house's own lights hang ([position, &"lamp" | &"machine"]).
var lights: Array[Array] = []


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
	pane_mat = _unshaded()
	land_mat = _unshaded()
	var always := Kit.new()
	var furnish := Furnish.new(always, floor_y, k.wall_h, dress, l.dressing)
	for i in DIRS.size():
		var full := Kit.new()
		var cut := Kit.new()
		for e: Dictionary in l.edges:
			if not (e.out as Vector2).is_equal_approx(DIRS[i]):
				continue
			_edge(full, e, k.wall_h, infill, frame, frame, false)
			_edge(cut, e, k.cut, infill, frame, cap, true)
			if e.kind == &"window":
				_mullions(full, e, frame)
			_wear(full, e, infill, k.wall_h)
			_wear(cut, e, infill, k.cut)
		if l.hearth_wall.is_equal_approx(DIRS[i]):
			_breast(full, k.wall_h, stone, stone)
			_breast(cut, k.cut, stone, cap)
			_soot(full, k.wall_h)
			_soot(cut, k.cut)
		# What hangs on this wall hangs in its mesh.
		furnish.k = full
		for t: Dictionary in l.things:
			if ON_WALL.has(t.kind) and (t.face as Vector2).is_equal_approx(-DIRS[i]):
				furnish.thing(t)
		_full.append(_mesh(full, mat, "walls_%d" % i))
		var c := _mesh(cut, mat, "cut_%d" % i)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cut.append(c)
		var sky := Kit.new()
		var land_k := Kit.new()
		for e: Dictionary in l.edges:
			if not (e.out as Vector2).is_equal_approx(DIRS[i]):
				continue
			if e.kind == &"window":
				_pane(sky, land_k, e, 0.9, 1.75, 0.2)
			elif e.kind == &"door":
				_pane(sky, land_k, e, 0.0, 2.05, 0.12)
		var pm := _mesh(sky, pane_mat, "panes_%d" % i)
		pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lm := _mesh(land_k, land_mat, "land")
		remove_child(lm)
		pm.add_child(lm)
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_panes.append(pm)
	furnish.k = always
	for t: Dictionary in l.things:
		if not ON_WALL.has(t.kind):
			furnish.thing(t)
	lights = furnish.lights
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
		var cast := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if drawn \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_full[i].cast_shadow = cast
		for c: Node in _full[i].get_children():
			(c as GeometryInstance3D).cast_shadow = cast
		_cut[i].visible = not drawn
		_panes[i].visible = drawn
	_ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if whole \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## The sky seen through the windows, and the land under it, this frame.
func daylight(sky: Color, land: Color) -> void:
	pane_mat.albedo_color = sky
	land_mat.albedo_color = land


static func _unshaded() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	return m


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


## The made part under `mat`, and what was taken off a machine as a child on the
## FOUND material, so it hides and shadows with what it hangs on.
func _mesh(k: Kit, mat: Material, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = k.made.build()
	mi.material_override = mat
	add_child(mi)
	if k.found.vertex_count() > 0:
		var fm := MeshInstance3D.new()
		fm.name = "found"
		fm.mesh = k.found.build()
		fm.material_override = PropModels.found_material()
		mi.add_child(fm)
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


## A quad on the room side of a wall's inner face, `lift` proud of it: `u` along
## the wall from its middle, `h` above the floor. `out` is the wall's way out of
## the room and `base` a point on the wall's line. Wound so it faces the room.
func _on_wall(k: Kit, base: Vector2, out: Vector2, u0: float, u1: float, h0: float, h1: float, col: Color, lift: float) -> void:
	var f := -out
	var s := Vector2(-f.y, f.x)
	var q := base - out * (THICK * 0.5 + lift)
	var pa := q + s * u0
	var pb := q + s * u1
	k.made.quad(Vector3(pa.x, floor_y + h0, pa.y), Vector3(pa.x, floor_y + h1, pa.y),
		Vector3(pb.x, floor_y + h1, pb.y), Vector3(pb.x, floor_y + h0, pb.y), col)


## A four-cornered patch on a wall's inner face, corners given as (u, h) and
## wound so it faces the room whatever order the edge runs in.
func _wall_poly(k: Kit, base: Vector2, out: Vector2, c: Array[Vector2], col: Color, lift: float) -> void:
	var f := -out
	var s := Vector2(-f.y, f.x)
	var q := base - out * (THICK * 0.5 + lift)
	var v: Array[Vector3] = []
	for uh: Vector2 in c:
		var pt := q + s * uh.x
		v.append(Vector3(pt.x, floor_y + uh.y, pt.y))
	k.made.quad(v[0], v[1], v[2], v[3], col)


## THE WALL HAS BEEN LIVED BESIDE: damp climbing from the floor in a tide line
## that is never level, and here and there a crack. Laid on both the whole wall
## and its cut, clipped to the cut's height, so the section keeps its damp.
func _wear(k: Kit, e: Dictionary, infill: Color, h: float) -> void:
	if e.inner:
		return
	var mid: Vector2 = ((e.a as Vector2) + (e.b as Vector2)) * 0.5
	var out: Vector2 = e.out
	var sd := Rng.hash_ints(int(mid.x * 8.0), int(mid.y * 8.0), 0xDA3F)
	var damp := GroundColors.made(Kit.tone(infill, 0.9).lerp(Color(0.5, 0.48, 0.38), 0.18), GroundColors.CLAY)
	var deep := GroundColors.made(Kit.tone(infill, 0.8).lerp(Color(0.42, 0.4, 0.3), 0.22), GroundColors.CLAY)
	var top_h := 0.0
	match e.kind:
		&"wall":
			top_h = 0.9
		&"window":
			top_h = 0.85
		_:
			return
	# The tide line: damp wicked up from the floor, its top edge wandering in a
	# slow wave (two sines on the wall's own hash), a paler stain over a darker
	# one, never a level band and never a step.
	var ph := float(sd & 255) / 40.0
	var tide := func(u: float, scale: float) -> float:
		var w := 0.5 + 0.3 * sin(u * 5.3 + ph) + 0.2 * sin(u * 13.1 + ph * 2.7)
		return minf((0.12 + 0.36 * w) * scale, minf(h, top_h))
	var n := 8
	for i in n:
		var u0 := -0.61 + 1.22 * float(i) / float(n)
		var u1 := -0.61 + 1.22 * float(i + 1) / float(n)
		_wall_poly(k, mid, out, [Vector2(u0, 0.0), Vector2(u0, tide.call(u0, 1.0)), Vector2(u1, tide.call(u1, 1.0)), Vector2(u1, 0.0)], damp, 0.004)
		_wall_poly(k, mid, out, [Vector2(u0, 0.0), Vector2(u0, tide.call(u0 + 0.4, 0.4)), Vector2(u1, tide.call(u1 + 0.4, 0.4)), Vector2(u1, 0.0)], deep, 0.006)
	# A crack, on about one wall in four, running down from under the head: a
	# hair-thin line that wanders, thinning as it goes.
	if e.kind == &"wall" and (sd & 3) == 0 and h > 1.4:
		var crack := GroundColors.made(Kit.tone(infill, 0.6), GroundColors.CLAY)
		var at := Vector2(-0.3 + 0.6 * float((sd >> 7) & 15) / 15.0, 2.25)
		var wid := 0.009
		for m in 6:
			var nxt := at + Vector2(0.09 * (float((sd >> (11 + m * 2)) & 3) - 1.5) / 1.5, -0.13 - 0.04 * float(m % 2))
			var nrm := Vector2(-(nxt - at).y, (nxt - at).x).normalized() * wid
			_wall_poly(k, mid, out, [at - nrm, nxt - nrm * 0.8, nxt + nrm * 0.8, at + nrm], crack, 0.007)
			at = nxt
			wid *= 0.8


## Soot: the breast above the fire blackened in a plume that spreads as it
## climbs, and the ceiling over it.
func _soot(k: Kit, h: float) -> void:
	var hw := layout.hearth_wall
	# The breast's face, as a wall line `deep` in from the hearth wall's.
	var face := layout.hearth + hw * 0.35 - hw * (0.275 - THICK * 0.5)
	var sooty: Array[Color] = [
		GroundColors.made(Color(0.14, 0.12, 0.11), GroundColors.CUTSTONE),
		GroundColors.made(Color(0.24, 0.21, 0.19), GroundColors.CUTSTONE),
		GroundColors.made(Color(0.34, 0.31, 0.28), GroundColors.CUTSTONE)]
	var bands: Array[Vector3] = [Vector3(1.1, 1.45, 0.34), Vector3(1.45, 1.9, 0.5), Vector3(1.9, 2.4, 0.66)]
	for i in bands.size():
		var b := bands[i]
		if b.x >= h:
			break
		_on_wall(k, face, hw, -b.z, b.z, b.x, minf(b.y, h), sooty[i], 0.006)


## A window's glazing bars: a cross of timber in the opening.
func _mullions(k: Kit, e: Dictionary, frame: Color) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var mid := (a + b) * 0.5
	var along := (b - a).normalized()
	var sx := absf(along.x) * 0.62 + absf(along.y) * 0.05
	var sz := absf(along.y) * 0.62 + absf(along.x) * 0.05
	k.slab(mid.x, floor_y + 1.3, mid.y, sx, 0.045, sz, 41, frame, frame, 0.0)
	k.slab(mid.x, floor_y + 0.9, mid.y, absf(along.x) * 0.05 + absf(along.y) * 0.05, 0.85, absf(along.y) * 0.05 + absf(along.x) * 0.05, 42, frame, frame, 0.0)
	# The sill inside, deeper than the wall, where things are put down.
	var o: Vector2 = e.out
	var sill := mid - o * (THICK * 0.5 + 0.03)
	k.slab(sill.x, floor_y + 0.86, sill.y, absf(along.x) * 0.86 + absf(along.y) * 0.14, 0.05, absf(along.y) * 0.86 + absf(along.x) * 0.14, 43, frame, frame, 0.0)


## THE DAY OUTSIDE AN OPENING, seen from inside: the sky, and across the bottom
## of it the host land's line (21_doors colours both from the live sky and the
## land the house stands in), behind dirty glass -- a rim of grime and smears,
## in the vertex colour the two unshaded materials multiply by. A doorway has no
## glass. Drawn at the wall's outer face, `inset` in from each jamb.
func _pane(sky: Kit, land: Kit, e: Dictionary, lo: float, hi: float, inset: float) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var along := (b - a).normalized()
	var o: Vector2 = (e.out as Vector2) * (THICK * 0.5 + 0.01)
	var pa := a + along * inset + o
	var pb := b - along * inset + o
	var glass: bool = e.kind == &"window"
	var sd := Rng.hash_ints(int(a.x * 8.0), int(a.y * 8.0), 0x61A55)
	var p3 := func(t: float, h: float, lift: float) -> Vector3:
		var q := pa.lerp(pb, t) - (e.out as Vector2) * lift
		return Vector3(q.x, floor_y + h, q.y)
	# Sky: a clean middle and a grimed rim, as quads of flat grey.
	var clean := Color(0.9, 0.9, 0.9) if glass else Color.WHITE
	var grime := Color(0.58, 0.56, 0.52)
	sky.made.quad(p3.call(0.0, lo, 0.0), p3.call(1.0, lo, 0.0), p3.call(1.0, hi, 0.0), p3.call(0.0, hi, 0.0), clean)
	if glass:
		var rim := 0.07
		var hr := rim * (hi - lo)
		for q: Array in [[0.0, rim, lo, hi], [1.0 - rim, 1.0, lo, hi], [rim, 1.0 - rim, lo, lo + hr], [rim, 1.0 - rim, hi - hr, hi]]:
			sky.made.quad(p3.call(q[0], q[2], 0.004), p3.call(q[1], q[2], 0.004), p3.call(q[1], q[3], 0.004), p3.call(q[0], q[3], 0.004), grime)
		# A smear or two where a sleeve has wiped it.
		for n in 2:
			var t := 0.2 + 0.5 * float((sd >> (n * 6)) & 63) / 63.0
			var h := lo + (hi - lo) * (0.25 + 0.5 * float((sd >> (n * 6 + 3)) & 7) / 7.0)
			sky.made.quad(p3.call(t, h, 0.004), p3.call(t + 0.18, h, 0.004), p3.call(t + 0.18, h + 0.09, 0.004), p3.call(t, h + 0.09, 0.004), Color(0.76, 0.75, 0.72))
	# THE LAND OUTSIDE, in depth: far hills drawn in the sky's own colour a step
	# down (air between the eye and them), and the near ground under them in the
	# land's colour, low and darker. Neither is ever level. A doorway, whose
	# bottom is the ground itself, shows more of the near ground than a window.
	var span := hi - lo
	var far_top := lo + span * (0.42 if glass else 0.4)
	var near_top := lo + span * (0.2 if glass else 0.26)
	var cols := 10
	var haze := Color(0.8, 0.82, 0.86) if glass else Color(0.84, 0.86, 0.9)
	var shade := Color(0.86, 0.86, 0.86) if glass else Color.WHITE
	var ridge := func(t: float, top: float, amp: float, phase: float) -> float:
		return top + span * amp * (0.55 * sin(t * 6.1 + phase) + 0.3 * sin(t * 15.7 + phase * 1.9) + 0.15 * sin(t * 31.0 + phase))
	var phase := float(sd & 1023) / 97.0
	for c in cols:
		var t0 := float(c) / float(cols)
		var t1 := float(c + 1) / float(cols)
		sky.made.quad(p3.call(t0, lo, 0.001), p3.call(t1, lo, 0.001), p3.call(t1, ridge.call(t1, far_top, 0.07, phase), 0.001),
			p3.call(t0, ridge.call(t0, far_top, 0.07, phase), 0.001), haze)
		land.made.quad(p3.call(t0, lo, 0.002), p3.call(t1, lo, 0.002), p3.call(t1, ridge.call(t1, near_top, 0.035, phase + 2.0), 0.002),
			p3.call(t0, ridge.call(t0, near_top, 0.035, phase + 2.0), 0.002), shade)


## THE FLOOR IS BOARDS, not the ground the pocket is grown on: the terrain's own
## floor is a landscape's ground treatment (stippled, cold) and its terrace edge
## rounds off short of the walls, which drew a strip of the void round every
## room. Boards run the room's long way and under the walls, in lengths butted
## end to end, each its own tone of the land's timber -- and PALER AND GREYER
## WHERE PEOPLE WALK (the layout's `walks`), door to hearth, door to table, door
## to bed, so a room says where its life is without anyone in it.
func _boards(k: Kit, l: InteriorLayout, dress: BiomeDressing) -> void:
	# The land's timber, but a floor indoors is not sea-weathered: warmer.
	var wood := Kit.tone(_pick(dress.timber, Color(0.36, 0.28, 0.21)).lerp(Color(0.46, 0.33, 0.22), 0.45), 1.3)
	var worn_to := Color(0.6, 0.55, 0.47)
	const W := 0.26
	for r: Rect2i in l.rooms:
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		var along_x := r.size.x >= r.size.y
		var span := (hi.y - lo.y) if along_x else (hi.x - lo.x)
		var run := (hi.x - lo.x) if along_x else (hi.y - lo.y)
		var n := ceili(span / W)
		for i in n:
			var t0 := float(i) * span / float(n)
			var w := span / float(n) - 0.012
			var h := Rng.hash_ints(r.position.x * 131 + r.position.y, i, 0x80A2D5, 0, 0)
			# Lengths of 1.4 to 2.6, the first cut short by where the board began.
			var at := -float(h % 97) / 97.0 * 1.4
			var piece := 0
			while at < run:
				var ph := Rng.hash_ints(h, piece, 0x0B0A)
				var length := 1.4 + 1.2 * float(ph & 255) / 255.0
				var s0 := maxf(at, 0.0)
				var s1 := minf(at + length, run)
				at += length
				piece += 1
				if s1 - s0 < 0.05:
					continue
				var tone := 0.84 + 0.26 * float((ph >> 8) & 1023) / 1023.0
				var cross := lo.y + t0 + w * 0.5 if along_x else lo.x + t0 + w * 0.5
				var c0 := (lo.x if along_x else lo.y) + s0
				var c1 := (lo.x if along_x else lo.y) + s1 - 0.01
				var mid := Vector2((c0 + c1) * 0.5, cross) if along_x else Vector2(cross, (c0 + c1) * 0.5)
				var worn := 0.0
				for wk: PackedVector2Array in l.walks:
					var dist := Geometry2D.get_closest_point_to_segment(mid, wk[0], wk[1]).distance_to(mid)
					worn = maxf(worn, clampf(1.0 - dist / 0.75, 0.0, 1.0))
				var col := Kit.tone(wood, tone).lerp(worn_to, 0.38 * worn)
				col = GroundColors.made(col, GroundColors.TIMBER)
				var cx := (c0 + c1) * 0.5 if along_x else cross
				var cz := cross if along_x else (c0 + c1) * 0.5
				var sx := (c1 - c0) if along_x else w
				var sz := w if along_x else (c1 - c0)
				k.slab(cx, floor_y - 0.01, cz, sx, 0.045, sz, ph, col, col, 0.004)
	# The doorstep: a stone sill across the way in, worn hollow.
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
