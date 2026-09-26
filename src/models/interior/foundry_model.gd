extends "res://src/models/interior/weapons_hall_model.gd"
## THE BURNING'S FOUNDRY, drawn (the recipe is src/content/interiors/foundry.gd).
## The weapons hall's bones -- its plate walls, the store's bars, its turrets that
## turn and its strongbox -- round a line that is still pouring: the furnace at
## its head with its mouth lit, the channel running molten the hall's length with
## the moulds riding under it, the quench at its end breathing steam, a crane on
## the ceiling over all of it, and the cooling racks to the ceiling on the south
## side, loaded with what was poured.
##
## The pour is the room's light (lights of kind `working`) and nothing else is:
## the racks' far side, where the quiet way goes, is left in the dark.

const MOLTEN := Color(1.0, 0.52, 0.12)
## What the line pours (InteriorLayout.dressing): drawn on the moulds and racked.
const CASTS := {&"lances": Vector3(1.3, 0.1, 0.12), &"plate": Vector3(0.6, 0.06, 0.45), &"barrels": Vector3(0.9, 0.16, 0.16)}


func _thing(k: Kit, t: Dictionary) -> void:
	var at: Vector2 = t.at
	var f: Vector2 = t.face
	match t.kind:
		&"furnace": _furnace(k, at, f)
		&"line": _line(k, at, f, float(t.long))
		&"quench": _quench(k, at)
		&"crane": _crane(k, at, f, float(t.long))
		&"cast_rack": _cast_rack(k, at, f, float(t.long))
		&"line_panel": _line_panel(k, at, f)
		_: super._thing(k, t)


## Scorched deck: the hall's plate, and slag spattered black-glassed round the
## line where the pour has slopped, and nothing painted -- a machine needs no
## line on the floor to find its way.
func _floor(k: Kit, _tears: Array[Vector2]) -> void:
	for r: Rect2i in layout.rooms:
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var h := Rng.hash_ints(x, y, 0x5AB5)
				var col := GroundColors.made(DECK[1] if (h & 3) != 0 else DECK[2], GroundColors.CONCRETE)
				k.slab(x + 0.5, floor_y, y + 0.5, 0.976, DECK_TOP, 0.976, h, col, col, 0.0)
	var bed := GroundColors.made(Color(0.03, 0.03, 0.04), GroundColors.TAR)
	for r: Rect2i in layout.rooms:
		var lo := Vector2(r.position) - Vector2.ONE * THICK * 0.5
		var hi := Vector2(r.end) + Vector2.ONE * THICK * 0.5
		k.slab((lo.x + hi.x) * 0.5, floor_y, (lo.y + hi.y) * 0.5, hi.x - lo.x, 0.012, hi.y - lo.y, 5, bed, bed, 0.0)
	var slag := GroundColors.made(Color(0.05, 0.045, 0.05), GroundColors.GLASS)
	var line := layout.hearth
	for n in 14:
		var h := Rng.hash_ints(n, 0x51A6)
		var at := line + Vector2((float(h & 255) / 255.0 - 0.5) * 7.4, (float((h >> 8) & 255) / 255.0 - 0.5) * 2.2)
		var sz := 0.15 + 0.35 * float((h >> 16) & 255) / 255.0
		k.slab(at.x, floor_y + DECK_TOP, at.y, sz, 0.004, sz * 0.8, h, slag, slag, 0.0)


func _box(pen: MeshKit, at: Vector2, f: Vector2, u0: float, u1: float, v0: float, v1: float, h0: float, h1: float, col: Color, top := Color(0, 0, 0, 0)) -> void:
	var s := Vector2(-f.y, f.x)
	var a := at + s * u0 + f * v0
	var b := at + s * u1 + f * v1
	pen.box(Vector3(minf(a.x, b.x), floor_y + h0, minf(a.y, b.y)), Vector3(maxf(a.x, b.x), floor_y + h1, maxf(a.y, b.y)), col, top)


## The furnace at the line's head: a squat stack of plate against the west wall,
## banded, its mouth open toward the line and burning, its flue into the roof.
func _furnace(k: Kit, at: Vector2, f: Vector2) -> void:
	_box(k.found, at, f, -0.75, 0.75, -0.7, 0.62, 0.0, 2.5, HULL[1], HULL[2])
	for h: float in [0.4, 1.3, 2.2]:
		_box(k.found, at, f, -0.8, 0.8, -0.72, 0.66, h, h + 0.1, HULL[0])
	var glow := GroundColors.glow(MOLTEN, 2.4)
	_box(k.made, at, f, -0.32, 0.32, 0.6, 0.64, 0.55, 1.15, glow)
	_box(k.found, at, f, -0.42, 0.42, 0.62, 0.72, 1.15, 1.25, HULL[0])
	var flue := _v(at, 2.5)
	k.found.box(flue + Vector3(-0.22, 0.0, -0.22), flue + Vector3(0.22, kind.wall_h - 2.5, 0.22), HULL[0], HULL[1])
	lights.append([_v(at + f * 1.0, 0.9), &"working"])


## The line: a trough on legs the hall's length, running molten, a spout over
## its head, and under it the moulds on their conveyor, each holding what is
## being poured.
func _line(k: Kit, at: Vector2, f: Vector2, long: float) -> void:
	var half := long * 0.5
	# Along the hall is across this thing's face.
	var cast: Vector3 = CASTS.get(layout.dressing, CASTS[&"lances"])
	for i in int(long) + 1:
		var u := -half + float(i) * long / float(int(long))
		for v: float in [-0.28, 0.28]:
			_box(k.found, at, f, u - 0.05, u + 0.05, v - 0.05, v + 0.05, 0.0, 0.78, HULL[0])
	_box(k.found, at, f, -half, half, -0.34, 0.34, 0.2, 0.28, HULL[1], HULL[2])
	_box(k.found, at, f, -half, half, -0.3, 0.3, 0.78, 0.92, HULL[1], HULL[0])
	var molten := GroundColors.glow(MOLTEN, 2.0)
	_box(k.made, at, f, -half + 0.1, half - 0.1, -0.16, 0.16, 0.9, 0.93, molten)
	# The moulds on the conveyor bed, a cast in every other one.
	var n := int(long / 0.9)
	for i in n:
		var u := -half + (float(i) + 0.5) * long / float(n)
		_box(k.found, at, f, u - 0.36, u + 0.36, -0.3, 0.3, 0.28, 0.42, HULL[2], HULL[3])
		if i % 2 == 0:
			var c := GroundColors.glow(MOLTEN, 0.9) if i < n / 2 else GroundColors.made(Color(0.16, 0.14, 0.15), GroundColors.GLASS)
			_box(k.made, at, f, u - cast.x * 0.25, u + cast.x * 0.25, -cast.z, cast.z, 0.42, 0.42 + cast.y, c)
	# The spout at the head, over the first mould, and the lights of the pour.
	_box(k.found, at, f, -half - 0.1, -half + 0.4, -0.12, 0.12, 0.92, 1.6, HULL[1])
	for i in 4:
		var u := -half + 0.8 + float(i) * (long - 1.6) / 3.0
		var s := Vector2(-f.y, f.x)
		lights.append([_v(at + s * u, 1.2), &"working"])


## The quench at the line's end: a tank of black water, steam standing off it.
func _quench(k: Kit, at: Vector2) -> void:
	k.found.box(_v(at - Vector2(0.5, 0.5), 0.0), _v(at + Vector2(0.5, 0.5), 0.9), HULL[1], HULL[0])
	var water := GroundColors.made(Color(0.03, 0.035, 0.05), GroundColors.GLASS)
	k.made.box(_v(at - Vector2(0.42, 0.42), 0.86), _v(at + Vector2(0.42, 0.42), 0.88), water, water)
	var steam := GroundColors.made(Color(0.62, 0.6, 0.6), GroundColors.CLOTH)
	for i in 5:
		var h := Rng.hash_ints(i, 0x57EA)
		var p := at + Vector2(float(h & 255) / 255.0 - 0.5, float((h >> 8) & 255) / 255.0 - 0.5) * 0.6
		k.made.strut(_v(p, 0.9), _v(p + Vector2(0.05, -0.03), 1.4 + 0.4 * float(i % 3)), 0.012, 3, steam)


## The crane on its rail under the ceiling, over the line, its hook parked.
func _crane(k: Kit, at: Vector2, f: Vector2, long: float) -> void:
	var y := kind.wall_h - 0.3
	_box(k.found, at, f, -long * 0.5 - 0.5, long * 0.5 + 0.5, -0.1, 0.1, y, y + 0.16, HULL[0])
	var s := Vector2(-f.y, f.x)
	var hook := at + s * (long * 0.25)
	_box(k.found, hook, f, -0.3, 0.3, -0.25, 0.25, y - 0.3, y, HULL[1], HULL[2])
	k.found.strut(_v(hook, y - 0.3), _v(hook, 1.9), 0.015, 3, HULL[0])
	k.found.box(_v(hook - Vector2(0.08, 0.08), 1.75), _v(hook + Vector2(0.08, 0.08), 1.9), HULL[2])


## THE COOLING RACKS, to the ceiling: uprights, shelves, and on every shelf what
## was poured, in rows -- a wall of it between the line and the south wall, and
## behind it the dark.
func _cast_rack(k: Kit, at: Vector2, f: Vector2, long: float) -> void:
	var half := long * 0.5
	var top := kind.wall_h - 0.1
	var cast: Vector3 = CASTS.get(layout.dressing, CASTS[&"lances"])
	var bays := int(long / 1.0)
	for i in bays + 1:
		var u := -half + long * float(i) / float(bays)
		for v: float in [-0.26, 0.26]:
			_box(k.found, at, f, u - 0.04, u + 0.04, v - 0.04, v + 0.04, 0.0, top, HULL[0])
	var shelves := 5
	for sh in shelves:
		var h := 0.25 + float(sh) * (top - 0.4) / float(shelves - 1)
		_box(k.found, at, f, -half, half, -0.28, 0.28, h, h + 0.04, HULL[1], HULL[2])
		var n := int(long / (cast.x * 0.6 + 0.08))
		for i in n:
			if (i * 7 + sh * 3) % 11 == 0:
				continue
			var u := -half + (float(i) + 0.5) * long / float(n)
			var col := GroundColors.made(Color(0.13, 0.12, 0.13), GroundColors.GLASS) if (i + sh) % 3 != 0 else HULL[2]
			_box(k.found, at, f, u - cast.x * 0.25, u + cast.x * 0.25, -cast.z, cast.z, h + 0.04, h + 0.04 + cast.y, col)
	# Plate backing its whole height on the far side, away from the line: from the
	# pour it is shelves of castings, and behind it a wall, which is what the
	# turrets cannot see through (21_doors `_screens`).
	_box(k.found, at, f, -half, half, -0.29, -0.26, 0.0, top, HULL[0])


## The line's panel on the north wall, at a machine's sensor height: a plate, a
## slot, a row of points reading the pour, one lit.
func _line_panel(k: Kit, at: Vector2, f: Vector2) -> void:
	var w := at - f * 0.24
	_box(k.found, w, f, -0.3, 0.3, 0.0, 0.05, 0.3, 0.8, HULL[1], HULL[2])
	_box(k.found, w, f, -0.12, 0.12, 0.05, 0.07, 0.55, 0.62, HULL[0])
	for i in 5:
		var u := -0.2 + 0.1 * float(i)
		_box(k.made, w, f, u - 0.02, u + 0.02, 0.05, 0.07, 0.4, 0.44, GroundColors.glow(MOLTEN, 1.0) if i == 3 else GroundColors.made(Color(0.05, 0.05, 0.06), GroundColors.TAR))
