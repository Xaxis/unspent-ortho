extends Node3D
## THE PLAN'S WEAPONS HALL, drawn (docs/interiors; the recipe that says where
## everything stands is src/content/interiors/weapons_hall.gd). Everything the
## machines made is FOUND, on the metal pen: plated walls on ribs, a ceiling of
## panels on girders with the roof torn through in places, racks, turrets, the
## gantry and what hangs on it, strongboxes, and the strip lights ruled down the
## ceiling. What is poured is the floor: cast slabs, ruled, oil on them.
##
## It answers the calls a cottage's model does (21_doors reads them): `build`,
## `show_for` (from above the walls facing the camera are cut to a section and
## the ceiling only shades; over the shoulder all of it stands), `windows` (a
## hall has none: the day comes in through the tears, as the real sun, because
## the kind's lid is under the line where the sun stops casting), `daylight`
## (nothing to colour), and `lights`, the strips.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")
const THICK := 0.3
## THE MACHINES' OWN METAL: their violet (Palette.MACHINE, the keepers' cold
## indigo) and dark, so the strips' light is what shapes it -- a panel is seen
## by the seam that catches, not by being pale. The amber of a lens or a working
## part is the only hot colour in the hall (LOOK.md).
const HULL: Array[Color] = [Color(0.0838, 0.0781, 0.1264), Color(0.1499, 0.1408, 0.2186), Color(0.1951, 0.1842, 0.2763), Color(0.2501, 0.2370, 0.3481), Color(0.2941, 0.2823, 0.3826)]
## The deck: darker still, near black, the oil darker than that.
const DECK: Array[Color] = [Color(0.06, 0.058, 0.075), Color(0.095, 0.09, 0.115), Color(0.12, 0.115, 0.145)]
## How far the deck stands proud of the pocket's own terrain, which lies at
## exactly `floor_y`: laid level with it, the two fought and the terrain's floor
## treatment came through in a mosaic, measured in a frame.
const DECK_TOP := 0.035
## Stencils are ruled in the machines' pale, never a warm paint.
const STENCIL := Color(0.62, 0.64, 0.7)
const DIRS: Array[Vector2] = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]

var layout: InteriorLayout
var kind: InteriorKind
var floor_y := 1.0
var _full: Array[MeshInstance3D] = []
var _cut: Array[MeshInstance3D] = []
var _ceiling: MeshInstance3D
## Where the hall's own lights hang ([position, &"strip"]).
var lights: Array[Array] = []
## The turrets, in the layout's order: each a node that turns about its mount,
## with its eye as two children (`dim`, `hot`) that `aim_turret` swaps.
var turrets: Array[Node3D] = []


func build(l: InteriorLayout, k: InteriorKind, _land: int, mat: Material) -> void:
	layout = l
	kind = k
	floor_y = TerrainMesher.level_height(InteriorGen.FLOOR_LEVEL)
	var tears: Array[Vector2] = []
	for t: Dictionary in l.things:
		if t.kind == &"tear":
			tears.append(t.at)
	for i in DIRS.size():
		var full := Kit.new()
		var cut := Kit.new()
		for e: Dictionary in l.edges:
			if not (e.out as Vector2).is_equal_approx(DIRS[i]):
				continue
			_edge(full, e, k.wall_h, false)
			_edge(cut, e, k.cut, true)
		_full.append(_mesh(full, mat, "walls_%d" % i))
		var c := _mesh(cut, mat, "cut_%d" % i)
		_shadow(c, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		_cut.append(c)
	var always := Kit.new()
	_floor(always, tears)
	for t: Dictionary in l.things:
		_thing(always, t)
	_mesh(always, mat, "floor")
	var roof := Kit.new()
	_roof(roof, k.wall_h, tears)
	_ceiling = _mesh(roof, mat, "ceiling")


func show_for(back: Vector2, over: float) -> void:
	var whole := over > 0.5
	for i in DIRS.size():
		var drawn := whole or not DIRS[i].dot(back) > 0.2
		_shadow(_full[i], GeometryInstance3D.SHADOW_CASTING_SETTING_ON if drawn
			else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
		_cut[i].visible = not drawn
	_shadow(_ceiling, GeometryInstance3D.SHADOW_CASTING_SETTING_ON if whole
		else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)


func windows() -> Array[Array]:
	return []


func daylight(_sky: Color, _land: Color) -> void:
	pass


static func _shadow(g: GeometryInstance3D, s: GeometryInstance3D.ShadowCastingSetting) -> void:
	g.cast_shadow = s
	for c: Node in g.get_children():
		(c as GeometryInstance3D).cast_shadow = s


## The made part (the poured floor) under `mat`, and what the machines made as
## a child on the FOUND material, so it hides and shades with it.
func _mesh(k: Kit, mat: Material, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	if k.made.vertex_count() > 0:
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


func _v(p: Vector2, h: float) -> Vector3:
	return Vector3(p.x, floor_y + h, p.y)


# --- walls ---------------------------------------------------------------------

## One unit of wall: plate on a rib at each end, or a doorway's heavy frame, or
## -- where a bay shares its wall with the hall -- bars, so what is kept in the
## cage is seen through them. Cut (`cut`), it stops at `h` with a dark cap.
func _edge(k: Kit, e: Dictionary, h: float, cut: bool) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var o: Vector2 = e.out
	var along := (b - a).normalized()
	var half := o * THICK * 0.5
	var cap := HULL[0]
	var body := HULL[1]
	match e.kind:
		&"door", &"inner":
			var head := minf(2.6, h)
			for p: Vector2 in [a, b]:
				var q := p + along * (0.12 if p == a else -0.12)
				k.found.box(_v(q - along * 0.12 - half * 1.3, 0.0), _v(q + along * 0.12 + half * 1.3, head), HULL[0], cap if cut else HULL[0])
			if not cut and h > 2.6:
				k.found.box(_v(a - half, 2.6), _v(b + half, h), body, body, true)
				k.found.box(_v(a - half * 1.4, 2.45), _v(b + half * 1.4, 2.6), HULL[0], HULL[0], true)
			return
	if e.inner:
		# Bars, floor to head, and a rail along the top.
		var top := minf(2.4, h)
		for n in 5:
			var p := a.lerp(b, (float(n) + 0.5) / 5.0)
			k.rod(_v(p, 0.0), _v(p, top), 0.03, 6, HULL[0])
		k.found.box(_v(a - half * 0.5, top - 0.06), _v(b + half * 0.5, top), HULL[0], cap if cut else HULL[0])
		if not cut and h > 2.4:
			k.found.box(_v(a - half, 2.4), _v(b + half, h), body, body, true)
		return
	k.found.box(_v(a - half, 0.0), _v(b + half, h), body, cap if cut else body)
	# The inner face: a riveted plate, a hair proud, and a rib at the unit's end.
	var f := -o
	var face := -half - o * 0.004
	var p0 := a + face + along * 0.06
	var p1 := b + face - along * 0.06
	var top_h := minf(h, 3.3) - 0.1
	var sd := int(a.x * 7.0 + a.y * 13.0)
	var col := HULL[2] if (sd & 3) != 0 else HULL[3]
	k.plate(_v(p0, 0.12), _v(p0, top_h), _v(p1, top_h), _v(p1, 0.12), col, HULL[0], HULL[4])
	var rib := a + face + f * 0.07
	k.found.box(_v(rib - along * 0.07 - f * 0.07, 0.0), _v(rib + along * 0.07 + f * 0.07, h), HULL[0], cap if cut else HULL[0])
	# CONDUIT, run along the wall high and low, a junction box every few units:
	# the hall is wired, and the runs catch the strip light in lines.
	var run := a + face + f * 0.1
	var run_b := b + face + f * 0.1
	for hh: float in [0.32, minf(h, 3.0) - 0.05]:
		if hh > h - 0.04:
			continue
		k.rod(_v(run, hh), _v(run_b, hh), 0.035, 6, HULL[0])
	if (sd % 3) == 0 and h > 1.5:
		var jb := run.lerp(run_b, 0.5) + f * 0.04
		k.found.box(_v(jb - along * 0.14 - f * 0.06, 1.35), _v(jb + along * 0.14 + f * 0.06, 1.62), HULL[1], HULL[2])
		k.found.box(_v(jb - along * 0.05 + f * 0.065, 1.44), _v(jb + along * 0.05 + f * 0.075, 1.5), P.LENS[1])


# --- the floor and the roof -----------------------------------------------------

## Cast slabs a tile square, each its own grey, with a ruled seam between and oil
## where the machines stand and are worked on; rubble under each tear, where the
## yard came through.
func _floor(k: Kit, tears: Array[Vector2]) -> void:
	# DECK PLATE, a tile square, near black and slick (TAR: the made row with the
	# sheen, because a floor is poured and laid, and FOUND's own panelling, made
	# for a machine's flank, broke a whole floor into a mosaic): the strips' light
	# lies on it in long reflections, and the seams between are ruled dark.
	for r: Rect2i in layout.rooms:
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var h := Rng.hash_ints(x, y, 0x5AB5)
				var col := GroundColors.made(DECK[1] if (h & 3) != 0 else DECK[2], GroundColors.CONCRETE)
				k.slab(x + 0.5, floor_y, y + 0.5, 0.976, DECK_TOP, 0.976, h, col, col, 0.0)
	# Under the plates' seams, the dark they are laid over.
	var bed := GroundColors.made(Color(0.03, 0.03, 0.04), GroundColors.TAR)
	for r: Rect2i in layout.rooms:
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		k.slab((lo.x + hi.x) * 0.5, floor_y, (lo.y + hi.y) * 0.5, hi.x - lo.x, 0.012, hi.y - lo.y, 5, bed, bed, 0.0)
	_stencils(k)
	# Oil where the gantry works: pools darker than the deck, on it, a hair proud.
	var gantry := layout.hearth
	for n in 7:
		var h := Rng.hash_ints(n, 0x0111)
		var at := gantry + Vector2(float(h & 255) / 255.0 - 0.5, float((h >> 8) & 255) / 255.0 - 0.5) * 3.4
		var sz := 0.3 + 0.5 * float((h >> 16) & 255) / 255.0
		# GLASS, the row nearest a mirror: black oil the strips shine in.
		var oil := GroundColors.made(DECK[0], GroundColors.GLASS)
		k.slab(at.x, floor_y + DECK_TOP, at.y, sz, 0.003, sz * 0.7, h, oil, oil, 0.0)
	var rubble := GroundColors.made(Color(0.42, 0.4, 0.37), GroundColors.CONCRETE)
	for i in tears.size():
		var t := tears[i]
		for n in 6:
			var h := Rng.hash_ints(i, n, 0x7EA2)
			var at := t + Vector2(float(h & 255) / 255.0 - 0.5, float((h >> 8) & 255) / 255.0 - 0.5) * 1.1
			k.stone(at.x, floor_y + 0.02, at.y, 0.1 + 0.12 * float((h >> 16) & 255) / 255.0, 0.12, h, rubble, 5)
		# A bent sheet of the roof lying where it came down.
		var s0 := t + Vector2(-0.4, 0.3)
		k.plate(_v(s0, 0.05), _v(s0 + Vector2(0.9, -0.1), 0.05), _v(s0 + Vector2(0.8, 0.5), 0.35), _v(s0 + Vector2(-0.05, 0.45), 0.2),
			HULL[1], HULL[2], HULL[0])


## Panels a tile square on girders, with undersides (a panel is only ever seen
## from below). Where the roof is torn there is no panel, and the edges of the
## hole hang down bent.
func _roof(k: Kit, h: float, tears: Array[Vector2]) -> void:
	var y := floor_y + h
	for r: Rect2i in layout.rooms:
		for x in range(r.position.x, r.end.x):
			for z in range(r.position.y, r.end.y):
				var c := Vector2(x + 0.5, z + 0.5)
				var torn := false
				for t: Vector2 in tears:
					if t.distance_to(c) < 0.1:
						torn = true
				if torn:
					for s: Vector2 in [Vector2(-0.5, 0), Vector2(0.5, 0)]:
						var e0 := c + s + Vector2(0, -0.5)
						var e1 := c + s + Vector2(0, 0.5)
						k.plate(_v(e0, h), _v(e1, h), _v(e1 + s * -0.5, h - 0.45), _v(e0 + s * -0.4, h - 0.3), HULL[1], HULL[1], HULL[0])
					continue
				var shade := HULL[1] if ((x + z) & 1) == 0 else HULL[0].lerp(HULL[1], 0.6)
				# Edge to edge: a seam a hair wide let the sun through as a scatter of
				# pale blobs on the floor (the cottage's ceiling did the same).
				k.found.box(Vector3(x, y, z), Vector3(x + 1.0, y + 0.08, z + 1.0), shade, shade, true)
		# Girders across the short way, every second unit, and the strips' rails.
		for x in range(r.position.x, r.end.x + 1, 2):
			k.found.box(Vector3(x - 0.09, y - 0.32, r.position.y - THICK * 0.5), Vector3(x + 0.09, y, r.end.y + THICK * 0.5), HULL[0], HULL[0], true)


# --- what the hall holds ------------------------------------------------------

func _thing(k: Kit, t: Dictionary) -> void:
	var at: Vector2 = t.at
	var f: Vector2 = t.face
	match t.kind:
		&"rack": _rack(k, at, f)
		&"turret": _turret(at, f)
		&"gantry": _gantry(k, at)
		&"strongbox": _strongbox(k, at, f)
		&"strip": _strip(k, at)
		&"pump": _pump(at, f)
		&"vent": _vent(k, at, f)
		&"post": _post(k, at)


## A rack against the wall: two uprights, three arms, and what hangs on them --
## a blade, a barrel, a cell -- each something that goes on a machine.
func _rack(k: Kit, at: Vector2, f: Vector2) -> void:
	var s := Vector2(-f.y, f.x)
	var back := at - f * 0.3
	for u: float in [-0.4, 0.4]:
		var p := back + s * u
		k.found.box(_v(p - Vector2(0.03, 0.03), 0.0), _v(p + Vector2(0.03, 0.03), 2.2), HULL[0])
	var sd := int(at.x * 17.0 + at.y * 5.0)
	for n in 3:
		var h := 0.55 + 0.6 * float(n)
		k.found.box(_v(back + s * -0.44 - f * 0.02, h - 0.03), _v(back + s * 0.44 + f * 0.18, h), HULL[1], HULL[2])
		var pick := (sd + n * 7) % 4
		var c := back + f * 0.12
		match pick:
			0:
				# A blade, flat to the wall, its edge bright.
				var a := _v(c + s * -0.34, h + 0.05)
				var b := _v(c + s * 0.3, h + 0.05)
				k.found.quad(a, b, b + Vector3.UP * 0.1, a + Vector3.UP * 0.16, HULL[4])
				k.found.quad(a, a + Vector3.UP * 0.16, b + Vector3.UP * 0.1, b, HULL[4])
			1:
				k.rod(_v(c + s * -0.35, h + 0.07), _v(c + s * 0.35, h + 0.07), 0.05, 8, HULL[1])
				k.rod(_v(c + s * 0.35, h + 0.07), _v(c + s * 0.42, h + 0.07), 0.035, 8, HULL[0])
			2:
				for u: float in [-0.22, 0.0, 0.22]:
					var q := c + s * u
					k.chamfer(q.x, floor_y + h, q.y, 0.14, 0.2, 0.14, 0.02, HULL[2])
					k.chamfer(q.x, floor_y + h + 0.2, q.y, 0.06, 0.03, 0.06, 0.01, P.LENS[1])
			_:
				k.cable(_v(c + s * -0.3, h + 0.02), _v(c + s * 0.3, h + 0.02), 0.28, 6, 0.02, HULL[0])


## A turret high in a corner: a mount on the wall, and on it a head that turns
## -- a housing, a barrel and the amber eye it sees with, which burns hot while
## it comes round on somebody (the tell). Its own node, so it can turn.
func _turret(at: Vector2, f: Vector2) -> void:
	var h := kind.wall_h - 0.7
	var mount := Kit.new()
	mount.found.box(Vector3(-0.18, -0.5, -0.18), Vector3(0.18, 0.06, 0.18), HULL[0])
	var head := Kit.new()
	head.chamfer(0.0, 0.06, 0.0, 0.4, 0.26, 0.4, 0.06, HULL[1])
	var muzzle := Vector3(0.0, 0.19, 0.0)
	head.rod(muzzle, muzzle + Vector3(0.55, -0.12, 0.0), 0.04, 8, HULL[0])
	var dim := Kit.new()
	dim.chamfer(0.18, 0.2, 0.0, 0.05, 0.08, 0.08, 0.02, P.LENS[1])
	var hot := Kit.new()
	hot.chamfer(0.18, 0.18, 0.0, 0.09, 0.12, 0.12, 0.02, Works.WORKING)
	# The sighting line: a hair of steady amber, a unit long along +X, stretched
	# to the target and pitched down to it by `aim_turret` while the turret comes
	# round -- the tell, readable at any zoom.
	var sight := Kit.new()
	sight.found.box(Vector3(0.0, -0.008, -0.008), Vector3(1.0, 0.008, 0.008), Works.WORKING)
	var root := Node3D.new()
	root.name = "turret_%d" % turrets.size()
	root.position = _v(at, h)
	root.rotation.y = -f.angle()
	add_child(root)
	for part: Array in [[mount, "mount"], [head, "head"], [dim, "dim"], [hot, "hot"], [sight, "sight"]]:
		var mi := MeshInstance3D.new()
		mi.name = part[1]
		mi.mesh = (part[0] as Kit).found.build()
		mi.material_override = PropModels.found_material()
		root.add_child(mi)
	root.get_node("hot").visible = false
	var sight_node := root.get_node("sight") as Node3D
	sight_node.position = Vector3(0.2, 0.2, 0.0)
	sight_node.visible = false
	turrets.append(root)


## Turn turret `i` to `yaw` (radians, the fight's way: 0 east, turning south),
## burn its eye hot while it is coming round (`hot`) and draw its sighting line
## `reach` long, down to a body's chest.
func aim_turret(i: int, yaw: float, hot: bool, reach := 0.0) -> void:
	if i < 0 or i >= turrets.size():
		return
	var t := turrets[i]
	t.rotation.y = -yaw
	(t.get_node("hot") as Node3D).visible = hot
	(t.get_node("dim") as Node3D).visible = not hot
	var sight := t.get_node("sight") as Node3D
	sight.visible = hot and reach > 0.3
	if sight.visible:
		var drop := kind.wall_h - 0.7 + 0.2 - 1.1
		var along := maxf(0.1, reach - 0.2)
		sight.rotation.z = -atan2(drop, along)
		sight.scale = Vector3(sqrt(along * along + drop * drop), 1.0, 1.0)


## The gantry across the hall's middle, and the machine hung in it half taken
## apart: its shell open, its insides out on cables.
func _gantry(k: Kit, at: Vector2) -> void:
	var top := kind.wall_h - 0.45
	for u: float in [-1.4, 1.4]:
		var p := at + Vector2(u, 0.0)
		k.found.box(_v(p - Vector2(0.1, 0.1), 0.0), _v(p + Vector2(0.1, 0.1), top), HULL[0])
		k.found.box(_v(p - Vector2(0.28, 0.28), 0.0), _v(p + Vector2(0.28, 0.28), 0.1), HULL[0])
	k.found.box(_v(at + Vector2(-1.5, -0.1), top), _v(at + Vector2(1.5, 0.1), top + 0.2), HULL[0], HULL[1], true)
	for u: float in [-0.4, 0.4]:
		k.cable(_v(at + Vector2(u, 0.0), top), _v(at + Vector2(u * 0.6, 0.0), 1.55), 0.02, 3, 0.02, HULL[0])
	# The hull: an opened shell with its plates hanging off.
	var c := _v(at, 0.95)
	k.chamfer(c.x, c.y, c.z, 1.2, 0.6, 0.8, 0.14, (P.MACHINE["cutter"] as Array)[3])
	k.plate(c + Vector3(-0.6, 0.6, -0.4), c + Vector3(0.1, 0.6, -0.4), c + Vector3(0.2, 1.0, -0.7), c + Vector3(-0.5, 0.95, -0.72), HULL[2], HULL[0], HULL[4])
	for n in 4:
		var from := c + Vector3(-0.4 + 0.25 * float(n), 0.2, 0.3)
		k.cable(from, from + Vector3(0.1 * float(n - 2), -0.85, 0.3), 0.08, 5, 0.022, HULL[0] if n % 2 == 0 else HULL[1])
	k.chamfer(c.x + 0.35, c.y + 0.55, c.z + 0.05, 0.12, 0.08, 0.12, 0.03, P.LENS[1])


## A strongbox in a bay: a heavy plate case with a band and a lock that glows.
func _strongbox(k: Kit, at: Vector2, f: Vector2) -> void:
	var s := Vector2(-f.y, f.x)
	var lo := at - s * 0.55 - f * 0.32
	var hi := at + s * 0.55 + f * 0.32
	k.found.box(_v(Vector2(minf(lo.x, hi.x), minf(lo.y, hi.y)), 0.0), _v(Vector2(maxf(lo.x, hi.x), maxf(lo.y, hi.y)), 0.62), HULL[1], HULL[2])
	var band := at + f * 0.33
	k.found.box(_v(band - s * 0.56 - f * 0.01, 0.3), _v(band + s * 0.56 + f * 0.01, 0.38), HULL[0])
	var lock := at + f * 0.34
	k.chamfer(lock.x, floor_y + 0.36, lock.y, 0.08, 0.1, 0.03, 0.01, Works.WORKING)


## A strip light hung under the ceiling on two drops: steady machine light, the
## same strip the depot's own yard carries (works.gd STRIP).
func _strip(k: Kit, at: Vector2) -> void:
	var h := kind.wall_h - 0.55
	var a := _v(at + Vector2(-0.6, 0.0), h)
	var b := _v(at + Vector2(0.6, 0.0), h)
	for p: Vector3 in [a, b]:
		k.rod(p, p + Vector3.UP * 0.5, 0.012, 4, HULL[0])
	k.found.box(a + Vector3(0.0, -0.02, -0.07), b + Vector3(0.0, 0.08, 0.07), HULL[0])
	k.found.box(a + Vector3(0.02, -0.05, -0.04), b + Vector3(-0.02, -0.02, 0.04), Works.STRIP)
	lights.append([(a + b) * 0.5 + Vector3.DOWN * 0.2, &"strip"])


## THE ONE THING WORKING IN THE DARK END: a coolant pump let into the far wall,
## its rotor turning round a core that burns amber -- the only hot light there,
## and the hall's working part (the brightest warm pixels, LOOK.md). Its own
## node, turned by `_process`.
var _rotor: Node3D


func _pump(at: Vector2, f: Vector2) -> void:
	var root := Node3D.new()
	root.name = "pump"
	root.position = _v(at, 1.35)
	root.rotation.y = -f.angle()
	add_child(root)
	var body := Kit.new()
	body.found.box(Vector3(-0.35, -1.35, -0.75), Vector3(0.08, 0.95, 0.75), HULL[1], HULL[2])
	body.hoop(Vector3(0.1, 0.0, 0.0), 0.62, 20, 0.07, HULL[2], Vector3.RIGHT)
	body.hoop(Vector3(0.12, 0.0, 0.0), 0.5, 20, 0.03, HULL[0], Vector3.RIGHT)
	body.rod(Vector3(0.0, 0.95, 0.4), Vector3(0.0, 2.1, 0.4), 0.09, 8, HULL[0])
	body.rod(Vector3(0.0, 0.95, -0.4), Vector3(0.0, 2.1, -0.4), 0.09, 8, HULL[0])
	var core := Kit.new()
	core.chamfer(0.17, -0.2, 0.0, 0.08, 0.4, 0.4, 0.08, Works.WORKING)
	var rotor := Kit.new()
	for n in 5:
		var ang := TAU * float(n) / 5.0
		var tip := Vector3(0.14, sin(ang) * 0.5, cos(ang) * 0.5)
		var side := Vector3(0.0, cos(ang), -sin(ang)) * 0.09
		rotor.found.quad(Vector3(0.14, 0.0, 0.0) + side * 0.4, tip + side, tip - side, Vector3(0.14, 0.0, 0.0) - side * 0.4, HULL[3])
		rotor.found.quad(Vector3(0.14, 0.0, 0.0) - side * 0.4, tip - side, tip + side, Vector3(0.14, 0.0, 0.0) + side * 0.4, HULL[3])
	for part: Array in [[body, "body"], [core, "core"]]:
		var mi := MeshInstance3D.new()
		mi.name = part[1]
		mi.mesh = (part[0] as Kit).found.build()
		mi.material_override = PropModels.found_material()
		root.add_child(mi)
	_rotor = MeshInstance3D.new()
	(_rotor as MeshInstance3D).mesh = rotor.found.build()
	(_rotor as MeshInstance3D).material_override = PropModels.found_material()
	root.add_child(_rotor)
	lights.append([_v(at + f * 0.6, 1.35), &"working"])


func _process(delta: float) -> void:
	if _rotor != null:
		_rotor.rotate_x(delta * 2.6)


## A coolant vent: a pipe down the wall into a cowl, and what it breathes off --
## vapour drifting up into the dark, lit by whatever light reaches it.
func _vent(k: Kit, at: Vector2, f: Vector2) -> void:
	var wall := at - f * 0.3
	k.rod(_v(wall, 3.3), _v(wall, 0.9), 0.07, 8, HULL[0])
	var cowl := at + f * 0.05
	k.chamfer(cowl.x, floor_y + 0.55, cowl.y, 0.34, 0.36, 0.34, 0.06, HULL[1], HULL[2])
	var steam := CPUParticles3D.new()
	steam.name = "vapour"
	steam.amount = 26
	steam.lifetime = 4.5
	steam.preprocess = 4.5
	steam.position = _v(cowl, 0.95)
	steam.direction = Vector3(f.x, 1.6, f.y).normalized()
	steam.spread = 18.0
	steam.initial_velocity_min = 0.25
	steam.initial_velocity_max = 0.45
	steam.gravity = Vector3(0.0, 0.12, 0.0)
	steam.scale_amount_min = 0.7
	steam.scale_amount_max = 1.5
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.3))
	grow.add_point(Vector2(1.0, 1.6))
	steam.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.15, Color(1, 1, 1, 1.0))
	steam.color_ramp = fade
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.55)
	var m := StandardMaterial3D.new()
	# Lit, not glowing: the vapour is seen by the light that reaches it. Drawn at
	# priority 11 with the other lit air (21_doors' beams), after people. Each
	# puff is a soft round falloff, or a quad is a square in the air.
	var puff := GradientTexture2D.new()
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = soft
	m.albedo_texture = puff
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.78, 0.8, 0.86, 0.16)
	m.roughness = 1.0
	m.render_priority = 11
	q.material = m
	steam.mesh = q
	add_child(steam)


## Where the warden stands its watch: a square ruled on the deck.
func _post(k: Kit, at: Vector2) -> void:
	for sd: Vector2 in [Vector2(1, 0), Vector2(0, 1)]:
		for side: float in [-0.55, 0.55]:
			var c := at + Vector2(sd.y, sd.x) * side
			var ext := Vector2(0.57 * sd.x + 0.025 * sd.y, 0.57 * sd.y + 0.025 * sd.x)
			var paint := GroundColors.made(STENCIL, GroundColors.ENAMEL)
			k.slab(c.x, floor_y + DECK_TOP, c.y, ext.x * 2.0, 0.004, ext.y * 2.0, 3, paint, paint, 0.0)


## HAZARD STENCILS ruled on the deck: bands across each bay's doorway and a
## chevron run round the gantry's working ground, in the machines' pale.
func _stencils(k: Kit) -> void:
	for e: Dictionary in layout.edges:
		if e.kind != &"inner":
			continue
		var a: Vector2 = e.a
		var b: Vector2 = e.b
		var o: Vector2 = e.out
		for n in 3:
			var off := -o * (0.35 + 0.18 * float(n))
			var p0 := a + off
			var p1 := b + off
			var paint := GroundColors.made(STENCIL, GroundColors.ENAMEL)
			var c0 := (p0 + p1) * 0.5
			k.slab(c0.x, floor_y + DECK_TOP, c0.y, absf(p1.x - p0.x) + 0.06, 0.004, absf(p1.y - p0.y) + 0.06, n, paint, paint, 0.0)
	var g := layout.hearth
	for n in 8:
		var x := g.x - 1.75 + float(n) * 0.5
		for yy: float in [g.y - 0.9, g.y + 0.9]:
			var c := Vector2(x, yy)
			if (n % 2) == 0:
				var paint := GroundColors.made(STENCIL, GroundColors.ENAMEL)
				k.slab(c.x, floor_y + DECK_TOP, c.y, 0.32, 0.004, 0.16, n, paint, paint, 0.0)
