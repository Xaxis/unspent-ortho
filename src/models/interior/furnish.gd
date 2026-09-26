extends RefCounted
## WHAT A HOUSEHOLD KEEPS IN ITS ROOMS, drawn (docs/interiors): one builder per
## kind the recipe lays (src/content/interiors/cottage.gd says where each stands
## and why). Made things are in the land's own timber, cloth and clay; what was
## taken off a machine is FOUND, on the metal pen, so a patch of plate on a wall
## and a strip light wired over a bench read as stolen and not as made.
##
## A thing's frame: `at` is where it stands on the floor, `f` the way it faces
## (into the room), `s` along the wall it backs onto. A thing against a wall
## stands `OFF_WALL` out from the wall's line, so the wall's inner face is at
## `BACK` behind `at`.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")
## Behind a wall-standing thing's `at`, the wall's inner face (the recipe's
## OFF_WALL less half the wall).
const BACK := 0.25

var k: Kit
var y0 := 0.0
var wall_h := 2.4
## Colours of this house.
var wood := Color()
var dark_wood := Color()
var wool: Array[Color] = []
var linen := Color()
var clay := Color()
var rope := Color()
var leather := Color()
## Where the lights hang: [position, &"lamp" | &"machine"].
var lights: Array[Array] = []


func _init(kit: Kit, floor_y: float, h: float, dress: BiomeDressing, household: StringName) -> void:
	k = kit
	y0 = floor_y
	wall_h = h
	var t := dress.timber[0] if not dress.timber.is_empty() else Color(0.36, 0.28, 0.21)
	wood = GroundColors.made(t.lerp(Color(0.44, 0.32, 0.22), 0.4), GroundColors.TIMBER)
	dark_wood = GroundColors.made(Kit.tone(t, 0.62), GroundColors.TIMBER)
	# Each household's blankets and rugs are dyed with what it has: the fisher's
	# sea-greys and a faded red, the tinker's rust and oil-dark, the keeper's
	# madder, weld and walnut. All of it old and washed out.
	match household:
		&"fisher":
			wool = [Color(0.36, 0.42, 0.47), Color(0.55, 0.28, 0.24), Color(0.62, 0.6, 0.53), Color(0.25, 0.3, 0.35)]
		&"tinker":
			wool = [Color(0.56, 0.32, 0.2), Color(0.34, 0.38, 0.48), Color(0.66, 0.56, 0.36), Color(0.5, 0.26, 0.22)]
		_:
			wool = [Color(0.58, 0.3, 0.26), Color(0.66, 0.56, 0.3), Color(0.38, 0.28, 0.2), Color(0.5, 0.52, 0.4)]
	for i in wool.size():
		wool[i] = GroundColors.made(wool[i], GroundColors.CLOTH)
	linen = GroundColors.made(Color(0.72, 0.68, 0.6), GroundColors.CLOTH)
	clay = GroundColors.made(Color(0.6, 0.42, 0.3), GroundColors.CLAY)
	rope = GroundColors.made(Color(0.55, 0.47, 0.35), GroundColors.ROPE)
	leather = GroundColors.made(Color(0.26, 0.18, 0.13), GroundColors.HIDE)


func thing(t: Dictionary) -> void:
	var at: Vector2 = t.at
	var f: Vector2 = t.face
	match t.kind:
		&"bed": _bed(at, f)
		&"shelf": _shelf(at, f, &"pots")
		&"jars": _shelf(at, f, &"jars")
		&"shelf_salvage": _shelf(at, f, &"salvage")
		&"chest": _chest(at, f)
		&"patch": _patch(at, f)
		&"boots": _boots(at, f)
		&"rug": _rug(at, f)
		&"lamp": _lamp(at)
		&"nets": _nets(at, f)
		&"floats": _floats(at, f)
		&"oars": _oars(at, f)
		&"creel": _basket(at, f, true)
		&"basket": _basket(at, f, false)
		&"fishline": _fishline(at, f)
		&"workbench": _workbench(at, f)
		&"machine_lamp": _machine_lamp(at, f)
		&"coil": _coil(at, f)
		&"herbs": _herbs(at, f)
		&"chair": _chair(at, f)
		&"pelts": _pelts(at, f)
		&"snares": _snares(at, f)
		&"resin_pots": _resin_pots(at, f)
		&"tallow": _tallow(at, f)
		&"charcoal_sacks": _charcoal_sacks(at, f)
		&"wire_coils": _wire_coils(at, f)
		&"insulators": _insulators(at, f)
		&"snowshoes": _snowshoes(at, f)
		&"core_samples": _core_samples(at, f)
		&"mason_rack": _mason_rack(at, f)
		&"peat_stack": _peat_stack(at, f)
		&"turf_spade": _turf_spade(at, f)
		&"reed_bundles": _reed_bundles(at, f)
		&"eel_traps": _eel_traps(at, f)
		&"salt_cones": _salt_cones(at, f)
		&"salt_rake": _salt_rake(at, f)
		&"lodestones": _lodestones(at, f)
		&"filings_trays": _filings_trays(at, f)
		&"steam_box": _steam_box(at, f)
		&"sulphur_lumps": _sulphur_lumps(at, f)
		&"seed_trays": _seed_trays(at, f)
		&"glass_blades": _glass_blades(at, f)
		&"glass_still": _glass_still(at, f)
		&"slag_lumps": _slag_lumps(at, f)
		&"oil_drums": _oil_drums(at, f)
		&"sorted_bins": _sorted_bins(at, f)


# --- the frame -----------------------------------------------------------------

## A point `u` along the wall, `v` out from `at`, `h` above the floor.
func _p(at: Vector2, f: Vector2, u: float, v: float, h: float) -> Vector3:
	var s := Vector2(-f.y, f.x)
	var q := at + s * u + f * v
	return Vector3(q.x, y0 + h, q.y)


## A block `wu` along the wall and `dv` out, centred `u`, `v` from `at`, from
## `h` up `hh` (Kit.slab is axis-aligned, and a thing's frame always is).
func _block(at: Vector2, f: Vector2, u: float, v: float, h: float, wu: float, dv: float, hh: float, col: Color, seed_value: int, top := Color(0, 0, 0, 0), rough := 0.012) -> void:
	var c := _p(at, f, u, v, h)
	var sx := wu if absf(f.y) > 0.5 else dv
	var sz := dv if absf(f.y) > 0.5 else wu
	k.slab(c.x, c.y, c.z, sx, hh, sz, seed_value, col, top, rough)


static func _seed(at: Vector2, n: int) -> int:
	return int(at.x * 37.0) * 131 + int(at.y * 41.0) + n * 7


# --- the builders --------------------------------------------------------------

## A box bed on short legs: a straw tick, a blanket thrown back off the pillow,
## a second folded at the foot, a headboard against the wall's end.
func _bed(at: Vector2, f: Vector2) -> void:
	var sd := _seed(at, 1)
	_block(at, f, 0.0, 0.0, 0.0, 2.0, 0.96, 0.3, wood, sd, Color(0, 0, 0, 0), 0.01)
	_block(at, f, 0.0, 0.0, 0.3, 1.9, 0.86, 0.13, linen, sd + 1, Color(0, 0, 0, 0), 0.03)
	_block(at, f, 0.22, 0.02, 0.4, 1.3, 0.9, 0.07, wool[0], sd + 2, Color(0, 0, 0, 0), 0.04)
	_block(at, f, 0.86, 0.0, 0.47, 0.34, 0.88, 0.07, wool[1], sd + 3, Color(0, 0, 0, 0), 0.02)
	_block(at, f, -0.78, 0.0, 0.43, 0.32, 0.56, 0.09, linen, sd + 4, Color(0, 0, 0, 0), 0.03)
	_block(at, f, -1.02, 0.0, 0.0, 0.08, 0.98, 0.78, dark_wood, sd + 5)


## Shelves against the wall, and what is on them.
func _shelf(at: Vector2, f: Vector2, what: StringName) -> void:
	var sd := _seed(at, 2)
	for u: float in [-0.46, 0.46]:
		_block(at, f, u, -0.06, 0.0, 0.06, 0.3, 1.72, dark_wood, sd + int(u * 10.0))
	for i in 3:
		var h := 0.42 + float(i) * 0.56
		_block(at, f, 0.0, -0.06, h, 1.0, 0.32, 0.04, wood, sd + 3 + i)
		var n := 4 + (sd + i) % 3
		for j in n:
			var u := -0.36 + 0.72 * (float(j) + 0.5) / float(n) + Kit.j(sd, i * 9 + j, 0.04)
			_on_shelf(at, f, u, h + 0.04, what, sd + i * 17 + j)


func _on_shelf(at: Vector2, f: Vector2, u: float, h: float, what: StringName, sd: int) -> void:
	var pick := absi(sd) % 5
	match what:
		&"jars":
			# Jars of what was put up: glass with the colour of what is in it.
			var fill: Array[Color] = [Color(0.55, 0.42, 0.18), Color(0.35, 0.4, 0.22), Color(0.5, 0.22, 0.2), Color(0.62, 0.58, 0.46)]
			var c := GroundColors.made(fill[pick % fill.size()], GroundColors.GLASS)
			var hh := 0.14 + 0.08 * float(pick % 3)
			k.limb(_p(at, f, u, -0.06, h), _p(at, f, u, -0.06, h + hh), 0.055, 0.05, 6, c)
			k.limb(_p(at, f, u, -0.06, h + hh), _p(at, f, u, -0.06, h + hh + 0.03), 0.04, 0.042, 6, dark_wood)
		&"salvage":
			if pick < 2:
				# A part of a machine, kept because it might be something one day.
				k.chamfer(_p(at, f, u, -0.06, h).x, h + y0, _p(at, f, u, -0.06, h).z, 0.14, 0.1, 0.12, 0.02, P.PLATE[2 + pick])
			elif pick < 4:
				k.rod(_p(at, f, u - 0.05, -0.06, h + 0.03), _p(at, f, u + 0.06, -0.02, h + 0.05), 0.025, 6, P.PLATE[3])
			else:
				k.limb(_p(at, f, u, -0.06, h), _p(at, f, u, -0.06, h + 0.16), 0.05, 0.05, 6, clay)
		_:
			# Crocks and bowls.
			if pick < 3:
				k.limb(_p(at, f, u, -0.06, h), _p(at, f, u, -0.06, h + 0.18 + 0.05 * float(pick)), 0.07, 0.05, 7, clay)
			elif pick == 3:
				_block(at, f, u, -0.06, h, 0.16, 0.14, 0.06, clay, sd)
			else:
				_block(at, f, u, -0.06, h, 0.2, 0.2, 0.09, linen, sd)


## A chest with iron bands.
func _chest(at: Vector2, f: Vector2) -> void:
	var sd := _seed(at, 3)
	_block(at, f, 0.0, -0.05, 0.0, 0.9, 0.5, 0.46, wood, sd, Kit.tone(wood, 1.08))
	for u: float in [-0.3, 0.3]:
		_block(at, f, u, -0.05, 0.0, 0.06, 0.52, 0.48, leather, sd + 1)


## A hole in the wall stopped with a machine's plate: riveted, rusting at its
## edges, and plainly off something that walked.
func _patch(at: Vector2, f: Vector2) -> void:
	var back := BACK - 0.012
	var a := _p(at, f, -0.42, -back, 0.95)
	var b := _p(at, f, 0.36, -back, 0.88)
	var c := _p(at, f, 0.4, -back, 1.72)
	var d := _p(at, f, -0.38, -back, 1.66)
	# The hole's ragged edge shows round it as damp, dark daub.
	var edge := GroundColors.made(Color(0.24, 0.2, 0.17), GroundColors.CLAY)
	var mid := (a + c) * 0.5
	# Wound a, d, c, b: MeshKit emits a quad reversed, and these face the room.
	k.face(a + (a - mid) * 0.12, d + (d - mid) * 0.12, c + (c - mid) * 0.12, b + (b - mid) * 0.12, edge)
	var f3 := Vector3(f.x, 0.0, f.y) * 0.01
	k.plate(a + f3, d + f3, c + f3, b + f3, P.PLATE[3], P.RUST[2], P.PLATE[1])


## Boots by the door, one fallen over.
func _boots(at: Vector2, f: Vector2) -> void:
	var sd := _seed(at, 4)
	_block(at, f, -0.1, 0.0, 0.0, 0.12, 0.3, 0.09, leather, sd)
	_block(at, f, -0.1, -0.08, 0.09, 0.12, 0.13, 0.22, leather, sd + 1)
	_block(at, f, 0.12, 0.04, 0.0, 0.3, 0.12, 0.1, leather, sd + 2)


## A rag rug: strips of whatever cloth was spent, in bands.
func _rug(at: Vector2, f: Vector2) -> void:
	var sd := _seed(at, 5)
	var n := 7
	for i in n:
		var v := -0.5 + (float(i) + 0.5) / float(n)
		_block(at, f, 0.0, v * 0.95, 0.02, 1.5 - 0.06 * float(i % 2), 0.95 / float(n) + 0.002, 0.016, wool[(i + sd) % wool.size()], sd + i, Color(0, 0, 0, 0), 0.004)


## A lantern hung from the beam on a chain: a tin cap and base, four corner
## posts, and between them the glass its flame is behind -- a lamp the renderer
## lights after dark, and a light of its own (21_doors).
func _lamp(at: Vector2) -> void:
	var top := y0 + wall_h - 0.2
	var h := y0 + 1.74
	var tin := GroundColors.made(Color(0.22, 0.2, 0.19), GroundColors.TAR)
	k.made.strut(Vector3(at.x, top, at.y), Vector3(at.x, h + 0.26, at.y), 0.01, 3, tin)
	var glass := GroundColors.marked(Color(0.98, 0.78, 0.45), GroundColors.LAMP + 10)
	k.slab(at.x, h + 0.02, at.y, 0.1, 0.14, 0.1, 11, glass, glass, 0.0)
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var q := at + c * 0.058
		k.slab(q.x, h, q.y, 0.018, 0.2, 0.018, 14, tin, tin, 0.0)
	k.slab(at.x, h + 0.18, at.y, 0.15, 0.06, 0.15, 12, tin, tin, 0.0, 0.55)
	k.slab(at.x, h - 0.02, at.y, 0.14, 0.03, 0.14, 13, tin, tin, 0.0)
	k.hoop(Vector3(at.x, h + 0.27, at.y), 0.03, 8, 0.006, P.PLATE[1], Vector3.RIGHT)
	lights.append([Vector3(at.x, h + 0.09, at.y), &"lamp"])


## Nets hung on the wall to mend: a sag of mesh, corks along its head rope.
func _nets(at: Vector2, f: Vector2) -> void:
	var back := BACK - 0.03
	var cols := 7
	for i in cols:
		var u := -0.7 + 1.4 * float(i) / float(cols - 1)
		var drop := 0.9 + 0.25 * sin(float(i) * 1.7)
		k.made.strut(_p(at, f, u, -back, 1.95), _p(at, f, u * 0.8, -back + 0.06, 1.95 - drop), 0.008, 3, rope)
	for r in 4:
		var h := 1.85 - float(r) * 0.24
		k.sag(_p(at, f, -0.7 + float(r) * 0.03, -back + 0.02 * float(r), h), _p(at, f, 0.7 - float(r) * 0.05, -back + 0.02 * float(r), h - 0.05), 0.12, 6, 0.008, rope)
	k.sag(_p(at, f, -0.75, -back, 1.97), _p(at, f, 0.75, -back, 1.97), 0.05, 6, 0.016, rope)
	var cork := GroundColors.made(Color(0.62, 0.48, 0.3), GroundColors.TIMBER)
	for i in 5:
		var u := -0.6 + 0.3 * float(i)
		k.limb(_p(at, f, u - 0.05, -back + 0.02, 1.96), _p(at, f, u + 0.05, -back + 0.02, 1.96), 0.035, 0.035, 5, cork)


## Glass floats in a string of rope, the colours the sea has worn them to.
func _floats(at: Vector2, f: Vector2) -> void:
	var back := BACK - 0.08
	var hues: Array[Color] = [Color(0.34, 0.5, 0.44), Color(0.3, 0.42, 0.5), Color(0.55, 0.52, 0.3)]
	k.sag(_p(at, f, -0.5, -back, 1.7), _p(at, f, 0.5, -back, 1.72), 0.35, 8, 0.01, rope)
	for i in 4:
		var t := (float(i) + 0.5) / 4.0
		var u := -0.5 + t
		var h := 1.7 - 0.35 * 4.0 * t * (1.0 - t) - 0.09
		var c := GroundColors.made(hues[i % hues.size()], GroundColors.GLASS)
		k.stone(_p(at, f, u, -back + 0.02, h).x, _p(at, f, u, -back, h).y - 0.08, _p(at, f, u, -back + 0.02, h).z, 0.08, 0.16, _seed(at, 6) + i, c, 7)


## Two oars leant against the wall.
func _oars(at: Vector2, f: Vector2) -> void:
	for i in 2:
		var u := -0.2 + 0.32 * float(i)
		var foot := _p(at, f, u, 0.12, 0.0)
		var head := _p(at, f, u + 0.12, -BACK + 0.05, 2.05)
		k.made.strut(foot, head, 0.025, 4, wood)
		var blade := foot.lerp(head, 0.18)
		k.limb(foot, blade, 0.07, 0.05, 4, Kit.tone(wood, 0.9))


## A basket: a creel for the fish, or a keeper's for roots.
func _basket(at: Vector2, f: Vector2, creel: bool) -> void:
	var sd := _seed(at, 7)
	var weave := GroundColors.made(Color(0.52, 0.42, 0.27), GroundColors.THATCH)
	var c := _p(at, f, 0.0, 0.0, 0.0)
	k.stone(c.x, c.y, c.z, 0.26, 0.42 if creel else 0.26, sd, weave, 8, 0.0, Kit.tone(weave, 0.55))
	if creel:
		k.made.strut(_p(at, f, -0.2, -0.05, 0.4), _p(at, f, 0.2, -0.05, 0.4), 0.015, 3, leather)
	else:
		for i in 3:
			k.limb(_p(at, f, -0.1 + 0.1 * float(i), 0.0, 0.2), _p(at, f, -0.12 + 0.12 * float(i), 0.04, 0.34), 0.03, 0.01, 4,
				GroundColors.made(Color(0.5, 0.36, 0.2), GroundColors.THATCH))


## Fish split and hung on a line across the hearth corner to dry in its smoke.
func _fishline(at: Vector2, f: Vector2) -> void:
	var a := _p(at, f, -1.0, 0.0, 1.95)
	var b := _p(at, f, 1.0, 0.0, 1.95)
	k.sag(a, b, 0.12, 8, 0.008, rope)
	var skin := GroundColors.made(Color(0.62, 0.56, 0.44), GroundColors.HIDE)
	for i in 6:
		var t := (float(i) + 0.5) / 6.0
		var p := a.lerp(b, t) + Vector3.DOWN * (0.12 * 4.0 * t * (1.0 - t))
		k.limb(p, p + Vector3.DOWN * 0.3, 0.05, 0.015, 4, skin)


## A bench of salvage: a plank top on trestles, a vice, machine parts opened up
## to see what is in them, and cable.
func _workbench(at: Vector2, f: Vector2) -> void:
	var sd := _seed(at, 8)
	_block(at, f, 0.0, 0.0, 0.8, 1.6, 0.66, 0.07, wood, sd, Kit.tone(wood, 1.1))
	for u: float in [-0.66, 0.66]:
		_block(at, f, u, 0.0, 0.0, 0.08, 0.58, 0.8, dark_wood, sd + int(u * 10.0))
	_block(at, f, 0.0, -0.1, 0.25, 1.4, 0.44, 0.03, dark_wood, sd + 3)
	var top := 0.87
	var shell := _p(at, f, -0.35, 0.02, top)
	k.chamfer(shell.x, shell.y, shell.z, 0.34, 0.2, 0.26, 0.05, P.PLATE[2])
	var lens := _p(at, f, -0.35, 0.16, top + 0.1)
	k.hoop(lens, 0.07, 10, 0.02, P.PLATE[4], Vector3(f.x, 0.0, f.y))
	k.chamfer(lens.x, lens.y - 0.05, lens.z, 0.1, 0.1, 0.03, 0.02, P.LENS[1])
	k.rod(_p(at, f, 0.1, -0.1, top + 0.02), _p(at, f, 0.5, 0.12, top + 0.04), 0.03, 6, P.PLATE[3])
	k.cable(_p(at, f, 0.2, -0.2, top + 0.01), _p(at, f, 0.72, 0.3, 0.02), 0.25, 6, 0.018, P.PLATE[0])
	_block(at, f, 0.55, -0.1, top, 0.12, 0.2, 0.12, P.RUST[2], sd + 4)


## A strip light off a machine, wired to the wall over the bench. It is the one
## cold light in the house, and it hums (steady FOUND light, works.gd STRIP).
func _machine_lamp(at: Vector2, f: Vector2) -> void:
	var back := BACK - 0.03
	var c := _p(at, f, 0.0, -back, 1.85)
	var s := Vector3(-f.y, 0.0, f.x)
	var out := Vector3(f.x, 0.0, f.y)
	k.chamfer(c.x, c.y - 0.06, c.z, absf(s.x) * 0.9 + absf(out.x) * 0.1, 0.12, absf(s.z) * 0.9 + absf(out.z) * 0.1, 0.03, P.PLATE[1])
	var sc := c + out * 0.055
	k.chamfer(sc.x, sc.y - 0.03, sc.z, absf(s.x) * 0.76 + absf(out.x) * 0.03, 0.05, absf(s.z) * 0.76 + absf(out.z) * 0.03, 0.01, Works.STRIP)
	k.cable(c + s * 0.4, _p(at, f, 0.55, -back + 0.02, 0.1), 0.2, 8, 0.014, P.PLATE[0])
	lights.append([c + out * 0.2, &"machine"])


## A coil of cable cut out of something.
func _coil(at: Vector2, f: Vector2) -> void:
	var c := _p(at, f, 0.0, 0.0, 0.0)
	for i in 4:
		k.hoop(c + Vector3.UP * (0.03 + 0.035 * float(i)), 0.2 - 0.012 * float(i), 12, 0.02, P.PLATE[i % 2])


## Herbs hung to dry from the beam by the hearth, in bundles tied at the stem.
func _herbs(at: Vector2, f: Vector2) -> void:
	var dried: Array[Color] = [Color(0.4, 0.4, 0.27), Color(0.47, 0.4, 0.29), Color(0.34, 0.35, 0.27), Color(0.46, 0.32, 0.28)]
	var h := wall_h - 0.2
	var a := _p(at, f, -1.1, 0.0, h - 0.02)
	var b := _p(at, f, 1.1, 0.0, h - 0.02)
	k.sag(a, b, 0.04, 6, 0.008, rope)
	for i in 7:
		var t := (float(i) + 0.5) / 7.0
		var p := a.lerp(b, t) + Vector3.DOWN * 0.05
		var drop := 0.3 + 0.12 * float((i * 5) % 3)
		var c := GroundColors.made(dried[i % dried.size()], GroundColors.THATCH)
		# Tied tight at the top, full through the middle, the tips drooping in:
		# a bundle, not a cone.
		var tie := p + Vector3.DOWN * 0.06
		var belly := p + Vector3.DOWN * (drop * 0.55)
		k.limb(p, tie, 0.012, 0.02, 4, rope)
		k.limb(tie, belly, 0.025, 0.07, 5, c)
		k.limb(belly, p + Vector3.DOWN * drop, 0.07, 0.03, 5, Kit.tone(c, 0.9))


## A chair drawn up to the fire, turned toward it.
func _chair(at: Vector2, f: Vector2) -> void:
	var sd := _seed(at, 9)
	var back := -f
	_block(at, f, 0.0, 0.0, 0.42, 0.46, 0.44, 0.05, wood, sd)
	for u: float in [-0.18, 0.18]:
		for v: float in [-0.17, 0.17]:
			_block(at, f, u, v, 0.0, 0.05, 0.05, 0.42, dark_wood, sd + int(u * 10.0 + v * 100.0))
	_block(at, back, 0.0, 0.2, 0.47, 0.46, 0.05, 0.5, dark_wood, sd + 7)
	_block(at, f, 0.0, 0.02, 0.47, 0.4, 0.36, 0.05, wool[2], sd + 8, Color(0, 0, 0, 0), 0.02)


# --- the pieces other landscapes' households keep (BiomeDef.home) ----------------

## Hides pinned flat to the wall to dry, stretched on their pegs, the fur side in.
func _pelts(at: Vector2, f: Vector2) -> void:
	var back := BACK - 0.02
	var furs: Array[Color] = [GroundColors.made(Color(0.42, 0.36, 0.3), GroundColors.HIDE), GroundColors.made(Color(0.56, 0.52, 0.46), GroundColors.HIDE), GroundColors.made(Color(0.3, 0.25, 0.22), GroundColors.HIDE)]
	for i in 3:
		var u := -0.5 + 0.5 * float(i)
		var h := 1.1 + 0.12 * float(i % 2)
		var a := _p(at, f, u - 0.2, -back, h)
		var b := _p(at, f, u - 0.16, -back, h + 0.62)
		var c := _p(at, f, u + 0.18, -back, h + 0.6)
		var d := _p(at, f, u + 0.2, -back, h + 0.04)
		k.made.quad(a, b, c, d, furs[i])
		k.made.quad(d, c, b, a, furs[i])


## Snares: wire loops hung on pegs in a row, each with its running noose.
func _snares(at: Vector2, f: Vector2) -> void:
	var back := BACK - 0.03
	var wire := GroundColors.made(Color(0.5, 0.5, 0.52), GroundColors.ENAMEL)
	k.made.box(_p(at, f, -0.6, -back - 0.02, 1.52), _p(at, f, 0.6, -back + 0.02, 1.56), dark_wood)
	for i in 5:
		var u := -0.48 + 0.24 * float(i)
		k.hoop(_p(at, f, u, -back + 0.04, 1.38), 0.09 + 0.02 * float(i % 2), 10, 0.006, wire, Vector3(f.x, 0.0, f.y))


## The resin crop: clay pots in a row on a plank, each skinned amber at the top.
func _resin_pots(at: Vector2, f: Vector2) -> void:
	var amber := GroundColors.made(Color(0.92, 0.56, 0.1), GroundColors.GLASS)
	# Within its unit of wall: a neighbour stands on the next.
	k.made.box(_p(at, f, -0.44, -0.2, 0.0), _p(at, f, 0.44, 0.2, 0.08), dark_wood)
	for i in 3:
		var c := _p(at, f, -0.28 + 0.28 * float(i), 0.0, 0.08)
		k.made.prism(c.x, c.y, c.z, 0.11, c.y + 0.3, 0.13, 12, clay, clay)
		k.made.prism(c.x, c.y + 0.28, c.z, 0.12, c.y + 0.35, 0.09, 12, amber, amber)
	# The spiles the trees are tapped with, a bundle leant at the end.
	for j in 5:
		var b := _p(at, f, 0.4, -0.12 + 0.05 * float(j), 0.08)
		k.made.strut(b, b + Vector3.UP * 0.5 + Vector3(f.x, 0.0, f.y) * -0.06, 0.012, 4, wood)


## Tallow candles dipped and hung to harden from a stick across two pegs.
func _tallow(at: Vector2, f: Vector2) -> void:
	var back := BACK - 0.05
	var wax := GroundColors.made(Color(0.86, 0.82, 0.7), GroundColors.CLAY)
	k.made.strut(_p(at, f, -0.5, -back + 0.08, 1.8), _p(at, f, 0.5, -back + 0.08, 1.8), 0.015, 5, dark_wood)
	for i in 8:
		var u := -0.42 + 0.12 * float(i)
		k.made.strut(_p(at, f, u, -back + 0.08, 1.8), _p(at, f, u, -back + 0.08, 1.62 - 0.03 * float(i % 3)), 0.014, 5, wax)


## Sacks of charcoal slumped against the wall, black spilling from one.
func _charcoal_sacks(at: Vector2, f: Vector2) -> void:
	var sack := GroundColors.made(Color(0.36, 0.3, 0.24), GroundColors.CLOTH)
	var coal := GroundColors.made(Color(0.06, 0.06, 0.06), GroundColors.TAR)
	for i in 2:
		var c := _p(at, f, -0.2 + 0.4 * float(i), -0.02, 0.0)
		k.clump(c.x, c.y, c.z, 0.2, 0.5 - 0.08 * float(i), 11 + i, sack, 6)
	for i in 5:
		var c := _p(at, f, 0.1 + 0.08 * float(i), 0.22 + 0.04 * float(i % 2), 0.0)
		k.stone(c.x, c.y, c.z, 0.05, 0.04, 30 + i, coal, 5)


## Wire stripped off the pylons, coiled and hung on pegs: what the line carried.
func _wire_coils(at: Vector2, f: Vector2) -> void:
	var back := BACK - 0.06
	var copper := GroundColors.made(Color(0.62, 0.36, 0.2), GroundColors.ENAMEL)
	var bright := GroundColors.made(Color(0.76, 0.5, 0.3), GroundColors.ENAMEL)
	for i in 3:
		var c := _p(at, f, -0.42 + 0.42 * float(i), -back + 0.06, 1.3 + 0.1 * float(i % 2))
		for r in 6:
			_ring(c + Vector3.DOWN * 0.008 * float(r) + Vector3(f.x, 0.0, f.y) * 0.012 * float(r), 0.17 - 0.008 * float(r), 16, 0.016, copper if r % 2 == 0 else bright, f)
		k.found.strut(c + Vector3.UP * 0.17, c + Vector3.UP * 0.22 + Vector3(f.x, 0.0, f.y) * -0.05, 0.014, 4, P.PLATE[0])


## Glass insulators off the line, kept on a shelf, the only glass in the house.
func _insulators(at: Vector2, f: Vector2) -> void:
	var glass := GroundColors.made(Color(0.52, 0.68, 0.62), GroundColors.GLASS)
	k.made.box(_p(at, f, -0.5, -0.15, 1.05), _p(at, f, 0.5, 0.15, 1.09), dark_wood)
	for i in 5:
		var c := _p(at, f, -0.4 + 0.2 * float(i), 0.0, 1.09)
		k.made.prism(c.x, c.y, c.z, 0.07, c.y + 0.1, 0.035, 10, glass, glass)
		k.made.prism(c.x, c.y + 0.1, c.z, 0.04, c.y + 0.14, 0.03, 8, glass, glass)


## Snowshoes: two bent frames laced across, hung by the door on a peg.
func _snowshoes(at: Vector2, f: Vector2) -> void:
	var back := BACK - 0.04
	for i in 2:
		var c := _p(at, f, -0.16 + 0.32 * float(i), -back + 0.05, 1.2)
		_ring(c, 0.18, 12, 0.018, dark_wood, f)
		for r in 3:
			var h := -0.1 + 0.1 * float(r)
			k.made.strut(c + Vector3(0, h, 0) + _side(f) * -0.15, c + Vector3(0, h, 0) + _side(f) * 0.15, 0.006, 3, leather)


## Cores from the machines' drill grids, pulled out of the clints: limestone
## cylinders racked on pegs like bottles, one split to show its bands.
func _core_samples(at: Vector2, f: Vector2) -> void:
	var lime := GroundColors.made(Color(0.78, 0.76, 0.7), GroundColors.CUTSTONE)
	var band := GroundColors.made(Color(0.6, 0.58, 0.54), GroundColors.CUTSTONE)
	for r in 3:
		var h := 0.5 + 0.4 * float(r)
		k.found.box(_p(at, f, -0.55, -0.22, h - 0.03), _p(at, f, 0.55, 0.12, h), P.PLATE[0])
		for i in 5:
			var u := -0.44 + 0.22 * float(i)
			k.made.strut(_p(at, f, u, -0.2, h + 0.05), _p(at, f, u, 0.1, h + 0.05), 0.045, 8, band if (i + r) % 3 == 0 else lime)


## The mason's tools on their board, and at its foot a squared stone, half cut.
func _mason_rack(at: Vector2, f: Vector2) -> void:
	var back := BACK - 0.03
	var iron := GroundColors.made(Color(0.3, 0.3, 0.32), GroundColors.ENAMEL)
	k.made.box(_p(at, f, -0.45, -back - 0.02, 1.0), _p(at, f, 0.45, -back + 0.02, 1.5), dark_wood)
	for i in 5:
		var u := -0.34 + 0.17 * float(i)
		k.made.strut(_p(at, f, u, -back + 0.04, 1.42), _p(at, f, u, -back + 0.04, 1.14), 0.012, 4, iron)
	var st := _p(at, f, 0.0, 0.05, 0.0)
	k.slab(st.x, st.y, st.z, 0.44, 0.34, 0.36, 77, GroundColors.made(Color(0.8, 0.78, 0.72), GroundColors.CUTSTONE), Color(0, 0, 0, 0), 0.01)


## Peat, cut in bricks and stacked to dry in a crib against the wall, the
## top course laid crosswise.
func _peat_stack(at: Vector2, f: Vector2) -> void:
	var peat := GroundColors.made(Color(0.24, 0.17, 0.12), GroundColors.CLAY)
	var dry := GroundColors.made(Color(0.5, 0.4, 0.3), GroundColors.CLAY)
	for course in 5:
		var h := 0.13 * float(course)
		for j in 3:
			var u := -0.3 + 0.3 * float(j)
			if course % 2 == 0:
				k.made.box(_p(at, f, u - 0.13, -0.18, h), _p(at, f, u + 0.13, 0.18, h + 0.12), peat, dry)
			else:
				k.made.box(_p(at, f, -0.42, -0.18 + 0.12 * float(j), h), _p(at, f, 0.42, -0.08 + 0.12 * float(j), h + 0.12), peat, dry)


## The turf spade, its winged blade worn bright, leant at the wall by a bucket.
func _turf_spade(at: Vector2, f: Vector2) -> void:
	var back := BACK - 0.05
	var iron := GroundColors.made(Color(0.42, 0.42, 0.44), GroundColors.ENAMEL)
	var foot := _p(at, f, -0.1, -back + 0.25, 0.0)
	var top := _p(at, f, -0.2, -back + 0.02, 1.45)
	k.made.strut(foot + Vector3.UP * 0.3, top, 0.025, 5, wood)
	k.made.box(_p(at, f, -0.2, -back + 0.22, 0.0), _p(at, f, 0.0, -back + 0.28, 0.32), iron)
	var b := _p(at, f, 0.25, 0.0, 0.0)
	k.made.prism(b.x, b.y, b.z, 0.14, b.y + 0.3, 0.16, 10, dark_wood, dark_wood)


## Reeds cut and bound in bundles, stood up to dry, heads and all.
func _reed_bundles(at: Vector2, f: Vector2) -> void:
	var reed := GroundColors.made(Color(0.66, 0.58, 0.38), GroundColors.ROPE)
	var head := GroundColors.made(Color(0.44, 0.34, 0.26), GroundColors.ROPE)
	for i in 4:
		var u := -0.36 + 0.24 * float(i)
		var lean := 0.08 * (float(i) - 1.5)
		for j in 6:
			var o := Vector2(cos(float(j)), sin(float(j))) * 0.04
			var b := _p(at, f, u + o.x, -0.05 + o.y, 0.0)
			var t := _p(at, f, u + o.x * 2.0 + lean, -0.12 + o.y * 2.0, 1.5 + 0.06 * float(j % 3))
			k.made.strut(b, t, 0.008, 3, reed)
			k.made.strut(t, t + (t - b).normalized() * 0.12, 0.018, 4, head)
		k.made.strut(_p(at, f, u - 0.05, -0.05, 0.6), _p(at, f, u + 0.05, -0.05, 0.6), 0.03, 5, rope)


## Eel traps: long willow baskets, funnel-mouthed, hung on the wall to dry.
func _eel_traps(at: Vector2, f: Vector2) -> void:
	var back := BACK - 0.12
	var willow := GroundColors.made(Color(0.5, 0.4, 0.26), GroundColors.ROPE)
	for i in 2:
		var h := 1.1 + 0.4 * float(i)
		var a := _p(at, f, -0.5, -back + 0.1, h)
		var b := _p(at, f, 0.5, -back + 0.1, h - 0.06)
		for r in 5:
			var t := float(r) / 4.0
			var c := a.lerp(b, t)
			_ring(c, 0.12 - 0.06 * t, 8, 0.008, willow, Vector2(-f.y, f.x))
		k.made.strut(a, b, 0.006, 3, willow)


## Salt, raked into cones on a board and some sacked, white as the flat.
func _salt_cones(at: Vector2, f: Vector2) -> void:
	var salt := GroundColors.made(Color(0.92, 0.92, 0.88), GroundColors.CLAY)
	k.made.box(_p(at, f, -0.44, -0.2, 0.0), _p(at, f, 0.44, 0.2, 0.06), dark_wood)
	for i in 3:
		var c := _p(at, f, -0.28 + 0.28 * float(i), 0.0, 0.06)
		k.made.prism(c.x, c.y, c.z, 0.13, c.y + 0.26 - 0.04 * float(i % 2), 0.0, 10, salt, salt)


## The salt rake: a wide wooden head on a long shaft, crusted white, on pegs.
func _salt_rake(at: Vector2, f: Vector2) -> void:
	var back := BACK - 0.04
	var crust := GroundColors.made(Color(0.86, 0.86, 0.82), GroundColors.CLAY)
	k.made.strut(_p(at, f, -0.6, -back + 0.05, 1.6), _p(at, f, 0.6, -back + 0.05, 1.3), 0.02, 5, wood)
	k.made.box(_p(at, f, 0.5, -back, 1.1), _p(at, f, 0.62, -back + 0.1, 1.5), wood, crust)
	for j in 6:
		var h := 1.14 + 0.06 * float(j)
		k.made.box(_p(at, f, 0.62, -back + 0.02, h), _p(at, f, 0.66, -back + 0.08, h + 0.02), crust)


## Lodestones hung on strings from a beam, each turned the one way: the dead
## field still in the iron pulls them round.
func _lodestones(at: Vector2, f: Vector2) -> void:
	var back := BACK - 0.2
	var stone := GroundColors.made(Color(0.22, 0.2, 0.2), GroundColors.CUTSTONE)
	k.made.strut(_p(at, f, -0.5, -back, 1.9), _p(at, f, 0.5, -back, 1.9), 0.02, 5, dark_wood)
	for i in 5:
		var u := -0.4 + 0.2 * float(i)
		var bottom := _p(at, f, u + 0.05, -back + 0.02, 1.3 + 0.08 * float(i % 2))
		k.made.strut(_p(at, f, u, -back, 1.9), bottom, 0.004, 3, rope)
		k.stone(bottom.x, bottom.y - 0.1, bottom.z, 0.05, 0.1, 50 + i, stone, 5)


## Trays of iron filings on a bench, combed into arcs by nothing anyone sees.
func _filings_trays(at: Vector2, f: Vector2) -> void:
	k.made.box(_p(at, f, -0.44, -0.24, 0.0), _p(at, f, 0.44, 0.24, 0.7), dark_wood, wood)
	var iron := GroundColors.made(Color(0.2, 0.2, 0.22), GroundColors.ENAMEL)
	for i in 2:
		var c := _p(at, f, -0.2 + 0.4 * float(i), 0.0, 0.7)
		# A pale bed of sand under the iron, so the arcs show.
		k.made.box(c + Vector3(-0.17, 0.0, -0.17), c + Vector3(0.17, 0.025, 0.17), dark_wood)
		k.made.box(c + Vector3(-0.15, 0.025, -0.15), c + Vector3(0.15, 0.03, 0.15), linen)
		# Arcs round one end of the tray, as round a pole nobody put there.
		var pole := c + Vector3(0, 0.034, 0) - Vector3(f.x, 0.0, f.y) * 0.12
		for a in 5:
			var r := 0.05 + 0.03 * float(a)
			var n := 8
			for j in n:
				var t0 := PI * float(j) / float(n) - PI * 0.5
				var t1 := PI * float(j + 1) / float(n) - PI * 0.5
				var p0 := pole + (_side(f) * sin(t0) + Vector3(f.x, 0.0, f.y) * cos(t0)) * r
				var p1 := pole + (_side(f) * sin(t1) + Vector3(f.x, 0.0, f.y) * cos(t1)) * r
				k.made.strut(p0, p1, 0.006, 3, iron)


## The steam box: a lidded crate over a pipe let up through the floor from the
## warm ground, where the food is cooked with no fire at all.
func _steam_box(at: Vector2, f: Vector2) -> void:
	var pipe := GroundColors.made(Color(0.5, 0.42, 0.2), GroundColors.ENAMEL)
	k.made.box(_p(at, f, -0.35, -0.2, 0.0), _p(at, f, 0.35, 0.2, 0.55), dark_wood, wood)
	k.made.box(_p(at, f, -0.37, -0.22, 0.55), _p(at, f, 0.37, 0.22, 0.6), wood, wood)
	# The pipe out of its side and down into the floor, a crusted collar where
	# it goes into the warm ground.
	var side_out := _p(at, f, 0.35, 0.0, 0.3)
	var elbow := _p(at, f, 0.55, 0.0, 0.3)
	var ground := _p(at, f, 0.55, 0.0, 0.0)
	k.made.strut(side_out, elbow, 0.045, 8, pipe)
	k.made.strut(elbow, ground, 0.045, 8, pipe)
	var collar := GroundColors.made(Color(0.9, 0.78, 0.18), GroundColors.CLAY)
	k.made.prism(ground.x, ground.y, ground.z, 0.12, ground.y + 0.05, 0.08, 10, collar, collar)
	# Steam off the vent in the lid, standing up in soft heaps and thinning.
	var steam := GroundColors.made(Color(0.84, 0.84, 0.8), GroundColors.CLOTH)
	var v := _p(at, f, -0.12, 0.0, 0.6)
	for i in 9:
		var t := float(i) / 8.0
		var q := v + Vector3.UP * (0.05 + 0.1 * float(i)) + _side(f) * (0.05 * sin(float(i) * 1.3))
		k.clump(q.x, q.y, q.z, 0.05 + 0.07 * sin(t * PI), 0.14, 90 + i, steam, 7)
	# The vent's crust creeps up everything it warms: the box's foot and lid.
	var crust := GroundColors.made(Color(0.9, 0.78, 0.18), GroundColors.CLAY)
	for i in 5:
		var q := _p(at, f, -0.3 + 0.15 * float(i), 0.24, 0.0)
		k.stone(q.x, q.y, q.z, 0.07, 0.06, 70 + i, crust, 5)
	k.made.box(_p(at, f, -0.37, -0.22, 0.6), _p(at, f, 0.37, -0.1, 0.63), crust)
	k.made.box(_p(at, f, -0.37, 0.12, 0.6), _p(at, f, 0.1, 0.22, 0.62), crust)


## Lumps of sulphur, knocked off the vents' crust, in a basket and on the floor.
func _sulphur_lumps(at: Vector2, f: Vector2) -> void:
	var yellow := GroundColors.made(Color(0.9, 0.78, 0.18), GroundColors.CLAY)
	var c := _p(at, f, 0.0, 0.0, 0.0)
	k.made.prism(c.x, c.y, c.z, 0.26, c.y + 0.32, 0.3, 10, rope, rope)
	for i in 7:
		var h := Rng.hash_ints(i, 0x5071)
		var o := Vector2(float(h & 255) / 255.0 - 0.5, float((h >> 8) & 255) / 255.0 - 0.5) * 0.36
		k.stone(c.x + o.x, c.y + 0.24, c.z + o.y, 0.06, 0.08, h, yellow, 5)


## Seed trays on a rack, green already: here everything grows twice as fast.
func _seed_trays(at: Vector2, f: Vector2) -> void:
	var green := GroundColors.made(Color(0.36, 0.56, 0.24), GroundColors.CLOTH)
	var earth := GroundColors.made(Color(0.24, 0.18, 0.12), GroundColors.CLAY)
	for r in 3:
		var h := 0.3 + 0.45 * float(r)
		k.made.box(_p(at, f, -0.45, -0.2, h), _p(at, f, 0.45, 0.2, h + 0.04), dark_wood)
		k.made.box(_p(at, f, -0.42, -0.17, h + 0.04), _p(at, f, 0.42, 0.17, h + 0.09), earth)
		for i in 9:
			var q := _p(at, f, -0.36 + 0.09 * float(i), 0.05 * float((i + r) % 3 - 1), h + 0.09)
			k.made.strut(q, q + Vector3.UP * (0.1 + 0.08 * float((i * 7 + r) % 3)), 0.012, 3, green)
	for u: float in [-0.45, 0.45]:
		k.made.box(_p(at, f, u - 0.02, -0.2, 0.0), _p(at, f, u + 0.02, -0.16, 1.3), dark_wood)


## Blades knapped from the desert's fused plate, laid out on a cloth by edge.
func _glass_blades(at: Vector2, f: Vector2) -> void:
	var glass := GroundColors.made(Color(0.62, 0.8, 0.64), GroundColors.GLASS)
	k.made.box(_p(at, f, -0.44, -0.24, 0.0), _p(at, f, 0.44, 0.24, 0.7), dark_wood, wood)
	k.made.box(_p(at, f, -0.42, -0.22, 0.7), _p(at, f, 0.42, 0.22, 0.705), leather)
	for i in 3:
		var u := -0.26 + 0.24 * float(i)
		var a := _p(at, f, u, -0.19, 0.706)
		var b := _p(at, f, u + 0.04, 0.19 - 0.05 * float(i % 2), 0.706)
		# Tilted up off the cloth on one edge, so a face catches the light.
		var a2 := a + Vector3.UP * 0.05 + _side(f) * 0.13
		var b2 := b + Vector3.UP * 0.03 + _side(f) * 0.05
		k.made.quad(a, a2, b2, b, glass)
		k.made.quad(b, b2, a2, a, glass)


## A still: a glass pane over a dish, the drops running down it to a jar, the
## only water here that is not bought.
func _glass_still(at: Vector2, f: Vector2) -> void:
	var glass := GroundColors.made(Color(0.6, 0.72, 0.7), GroundColors.GLASS)
	var c := _p(at, f, 0.0, 0.0, 0.0)
	k.made.prism(c.x, c.y, c.z, 0.34, c.y + 0.12, 0.34, 12, clay, GroundColors.made(Color(0.2, 0.26, 0.28), GroundColors.GLASS))
	k.made.quad(_p(at, f, -0.34, -0.3, 0.12), _p(at, f, -0.34, 0.0, 0.5), _p(at, f, 0.34, 0.0, 0.5), _p(at, f, 0.34, -0.3, 0.12), glass)
	k.made.quad(_p(at, f, 0.34, 0.3, 0.12), _p(at, f, 0.34, 0.0, 0.5), _p(at, f, -0.34, 0.0, 0.5), _p(at, f, -0.34, 0.3, 0.12), glass)
	var j := _p(at, f, 0.45, 0.2, 0.0)
	k.made.prism(j.x, j.y, j.z, 0.08, j.y + 0.2, 0.06, 10, glass, glass)


## Slag glass picked from the runs, black and blue-green, heaped in a basket.
func _slag_lumps(at: Vector2, f: Vector2) -> void:
	var slag: Array[Color] = [GroundColors.made(Color(0.08, 0.1, 0.12), GroundColors.GLASS), GroundColors.made(Color(0.14, 0.3, 0.3), GroundColors.GLASS)]
	var c := _p(at, f, 0.0, 0.0, 0.0)
	k.made.prism(c.x, c.y, c.z, 0.26, c.y + 0.3, 0.3, 10, rope, rope)
	for i in 8:
		var h := Rng.hash_ints(i, 0x51A9)
		var o := Vector2(float(h & 255) / 255.0 - 0.5, float((h >> 8) & 255) / 255.0 - 0.5) * 0.4
		k.stone(c.x + o.x, c.y + 0.22, c.z + o.y, 0.06, 0.09, h, slag[i % 2], 5)


## Drums of oil siphoned off the refineries, stood against the wall, one on
## its side with a tap in it and a pan under.
func _oil_drums(at: Vector2, f: Vector2) -> void:
	for i in 2:
		var c := _p(at, f, -0.22 + 0.44 * float(i), -0.02, 0.0)
		k.found.prism(c.x, c.y, c.z, 0.2, c.y + 0.62, 0.2, 12, P.PLATE[i % 2], P.PLATE[1])
		k.hoop(c + Vector3.UP * 0.2, 0.205, 12, 0.015, P.PLATE[0])
		k.hoop(c + Vector3.UP * 0.44, 0.205, 12, 0.015, P.PLATE[0])
	var pan := _p(at, f, 0.0, 0.3, 0.0)
	k.made.prism(pan.x, pan.y, pan.z, 0.12, pan.y + 0.04, 0.12, 10, GroundColors.made(Color(0.05, 0.05, 0.05), GroundColors.GLASS), GroundColors.made(Color(0.05, 0.05, 0.05), GroundColors.GLASS))


## Bins of what the middens give up, sorted: screws, boards, cells, glass, each
## its own bin, labelled in chalk.
func _sorted_bins(at: Vector2, f: Vector2) -> void:
	var chalk := GroundColors.made(Color(0.86, 0.84, 0.78), GroundColors.CLAY)
	for r in 2:
		for i in 3:
			var u := -0.3 + 0.3 * float(i)
			var h := 0.45 * float(r)
			k.made.box(_p(at, f, u - 0.14, -0.2, h), _p(at, f, u + 0.14, 0.2, h + 0.4), dark_wood, wood)
			k.made.box(_p(at, f, u - 0.08, 0.2, h + 0.25), _p(at, f, u + 0.08, 0.205, h + 0.3), chalk)
			var bits := P.PLATE[(i + r) % 2]
			for b in 4:
				var q := _p(at, f, u - 0.08 + 0.05 * float(b), 0.0, h + 0.4)
				k.found.box(q, q + Vector3(0.03, 0.02, 0.03), bits)


func _side(f: Vector2) -> Vector3:
	return Vector3(-f.y, 0.0, f.x)


## A ring of made things (bent wood, rope) standing in the wall's plane.
func _ring(c: Vector3, r: float, n: int, thick: float, col: Color, f: Vector2) -> void:
	var s := _side(f)
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		k.made.strut(c + (s * cos(a0) + Vector3.UP * sin(a0)) * r, c + (s * cos(a1) + Vector3.UP * sin(a1)) * r, thick, 4, col)
