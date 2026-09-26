extends "res://src/models/interior/weapons_hall_model.gd"
## THE PINEWOOD'S SAW HALL, drawn (the recipe is src/content/interiors/saw_hall.gd).
## The weapons hall's bones -- plate walls, its turret, its strongbox, the post --
## round a line that takes the wood apart: a chain the length of the north wall
## carrying bark-on logs into a gang saw, the saw a frame of blades on a crank,
## and out of it beams so true they stack in cubes. Sawdust drifts pale over the
## black deck. Along the south wall, the docks: a clamp and a charging arm each,
## and a standby point that burns all night. At the east end, the kiln, racked
## with boards, warm.
##
## The line's lights are of kind `working`: 21_doors puts them out at the curfew.

## The pine the chain brought in (InteriorLayout.dressing): its bark and its cut face.
const PINES := {
	&"spruce": [Color(0.24, 0.17, 0.12), Color(0.86, 0.74, 0.54)],
	&"larch": [Color(0.32, 0.18, 0.12), Color(0.9, 0.66, 0.44)],
	&"black_pine": [Color(0.12, 0.1, 0.09), Color(0.8, 0.7, 0.52)],
}
const STANDBY := Color(1.0, 0.62, 0.2)


func _thing(k: Kit, t: Dictionary) -> void:
	var at: Vector2 = t.at
	var f: Vector2 = t.face
	match t.kind:
		&"log_chain": _log_chain(k, at, f, float(t.long))
		&"gang_saw": _gang_saw(k, at, f)
		&"beam_stack": _beam_stack(k, at, f)
		&"saw_panel": _saw_panel(k, at, f)
		&"dock": _dock(k, at, f)
		&"dock_plate": _dock_plate(k, at, f)
		&"kiln_rack": _kiln_rack(k, at, f)
		_: super._thing(k, t)


func _bark() -> Color:
	return GroundColors.made(PINES.get(layout.dressing, PINES[&"spruce"])[0], GroundColors.TIMBER)


func _sawn() -> Color:
	return GroundColors.made(PINES.get(layout.dressing, PINES[&"spruce"])[1], GroundColors.TIMBER)


func _box(pen: MeshKit, at: Vector2, f: Vector2, u0: float, u1: float, v0: float, v1: float, h0: float, h1: float, col: Color, top := Color(0, 0, 0, 0)) -> void:
	var s := Vector2(-f.y, f.x)
	var a := at + s * u0 + f * v0
	var b := at + s * u1 + f * v1
	pen.box(Vector3(minf(a.x, b.x), floor_y + h0, minf(a.y, b.y)), Vector3(maxf(a.x, b.x), floor_y + h1, maxf(a.y, b.y)), col, top)


func _p(at: Vector2, f: Vector2, u: float, v: float, h: float) -> Vector3:
	var s := Vector2(-f.y, f.x)
	return _v(at + s * u + f * v, h)


## The deck, and sawdust: drifts of it pale on the plate round the saw and along
## the chain, thinning out toward the docks.
func _floor(k: Kit, tears: Array[Vector2]) -> void:
	super._floor(k, tears)
	var dust := GroundColors.made(Color(0.72, 0.62, 0.46), GroundColors.CLOTH)
	var saw := layout.hearth
	for n in 26:
		var h := Rng.hash_ints(n, 0x5A3D)
		var along := (float(h & 255) / 255.0 - 0.7) * 9.0
		var off := (float((h >> 8) & 255) / 255.0) * 1.8
		var at := saw + Vector2(along, 0.4 + off * off * 0.6)
		var sz := 0.25 + 0.55 * float((h >> 16) & 255) / 255.0 * (1.0 - off / 2.4)
		k.slab(at.x, floor_y + DECK_TOP, at.y, sz, 0.006, sz * 0.6, h, dust, dust, 0.0)


## The chain: a steel bed on legs the length of the wall, a chain of dogs along
## it, and the logs riding it into the saw, bark on, one after another.
func _log_chain(k: Kit, at: Vector2, f: Vector2, long: float) -> void:
	var half := long * 0.5
	for i in int(long) + 1:
		var u := -half + float(i) * long / float(int(long))
		for v: float in [-0.32, 0.32]:
			_box(k.found, at, f, u - 0.05, u + 0.05, v - 0.05, v + 0.05, 0.0, 0.6, HULL[0])
	_box(k.found, at, f, -half, half, -0.38, 0.38, 0.6, 0.7, HULL[1], HULL[2])
	for i in int(long / 0.5):
		var u := -half + 0.25 + float(i) * 0.5
		_box(k.found, at, f, u - 0.03, u + 0.03, -0.06, 0.06, 0.7, 0.78, HULL[3])
	var bark := _bark()
	var cut := _sawn()
	var n := int(long / 1.4)
	for i in n:
		var u0 := -half + 0.2 + float(i) * long / float(n)
		var u1 := u0 + long / float(n) - 0.25
		var r := 0.2 + 0.05 * float(Rng.hash_ints(i, 0x106) & 3)
		k.made.strut(_p(at, f, u0, 0.0, 0.7 + r), _p(at, f, u1, 0.0, 0.7 + r), r, 8, bark)
		# The end the bucking saw left, pale.
		_box(k.made, at, f, u1, u1 + 0.015, -r * 0.8, r * 0.8, 0.7 + r * 0.2, 0.7 + r * 1.8, cut)
	for i in 3:
		var u := -half + 1.0 + float(i) * (long - 2.0) / 2.0
		lights.append([_p(at, f, u, 0.6, 2.0), &"working"])


## The gang saw: a frame to the height of the hall's lights, a sash of blades
## hung in it on a crank, the flywheel beside it, and the throat the logs go in.
func _gang_saw(k: Kit, at: Vector2, f: Vector2) -> void:
	for u: float in [-0.85, 0.85]:
		_box(k.found, at, f, u - 0.12, u + 0.12, -0.5, 0.5, 0.0, 2.8, HULL[1], HULL[2])
	_box(k.found, at, f, -0.97, 0.97, -0.5, 0.5, 2.8, 3.05, HULL[0], HULL[1])
	_box(k.found, at, f, -0.97, 0.97, -0.55, 0.55, 0.0, 0.62, HULL[0], HULL[1])
	# The sash and its blades, bright where the teeth are.
	_box(k.found, at, f, -0.72, 0.72, -0.08, 0.08, 1.7, 1.85, HULL[3])
	_box(k.found, at, f, -0.72, 0.72, -0.08, 0.08, 0.66, 0.78, HULL[3])
	var steel := GroundColors.made(Color(0.66, 0.68, 0.72), GroundColors.ENAMEL)
	for i in 7:
		var u := -0.6 + 0.2 * float(i)
		_box(k.made, at, f, u - 0.012, u + 0.012, -0.07, 0.07, 0.78, 1.7, steel)
	# The flywheel on the west side, in the plane of the wall the saw stands
	# along: a rim, four spokes, and the crank rod up to the sash.
	var wheel := _p(at, f, -1.3, 0.0, 1.3)
	var n := 16
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		k.found.strut(_p(at, f, -1.3, cos(a0) * 0.62, 1.3 + sin(a0) * 0.62), _p(at, f, -1.3, cos(a1) * 0.62, 1.3 + sin(a1) * 0.62), 0.06, 4, HULL[2])
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		k.found.strut(wheel, _p(at, f, -1.3, cos(a) * 0.6, 1.3 + sin(a) * 0.6), 0.03, 4, HULL[1])
	k.found.strut(wheel, _p(at, f, -0.85, 0.0, 1.78), 0.04, 4, HULL[3])
	# A beam half out of the throat on the far side.
	var cut := _sawn()
	_box(k.made, at, f, 0.95, 2.2, -0.14, 0.14, 0.62, 0.9, cut, cut)
	lights.append([_p(at, f, 0.0, 0.9, 2.2), &"working"])


## Beams stacked in an exact cube, courses laid crosswise, the ends sawn square.
func _beam_stack(k: Kit, at: Vector2, f: Vector2) -> void:
	var cut := _sawn()
	var face := GroundColors.made(PINES.get(layout.dressing, PINES[&"spruce"])[1] * Color(0.82, 0.8, 0.76), GroundColors.TIMBER)
	for course in 6:
		var h := float(course) * 0.22
		for j in 5:
			var w := -0.55 + 0.275 * float(j)
			if course % 2 == 0:
				_box(k.made, at, f, w - 0.12, w + 0.12, -0.6, 0.6, h, h + 0.2, face, cut)
			else:
				_box(k.made, at, f, -0.6, 0.6, w - 0.12, w + 0.12, h, h + 0.2, face, cut)


## The saw's panel, at a sensor's height: a plate, a slot, a row of points.
func _saw_panel(k: Kit, at: Vector2, f: Vector2) -> void:
	var w := at - f * 0.24
	_box(k.found, w, f, -0.3, 0.3, 0.0, 0.05, 0.3, 0.8, HULL[1], HULL[2])
	_box(k.found, w, f, -0.12, 0.12, 0.05, 0.07, 0.55, 0.62, HULL[0])
	for i in 5:
		var u := -0.2 + 0.1 * float(i)
		_box(k.made, w, f, u - 0.02, u + 0.02, 0.05, 0.07, 0.4, 0.44, GroundColors.glow(STANDBY, 1.0) if i == 1 else GroundColors.made(Color(0.05, 0.05, 0.06), GroundColors.TAR))


## A dock: two side plates out from the wall, a clamp between them at a hauler's
## back, a charging arm down from the wall, and the standby point that says
## whether it is home.
func _dock(k: Kit, at: Vector2, f: Vector2) -> void:
	var w := at - f * 0.2
	for u: float in [-0.95, 0.95]:
		_box(k.found, w, f, u - 0.04, u + 0.04, 0.0, 1.2, 0.0, 1.4, HULL[1], HULL[2])
	_box(k.found, w, f, -0.5, 0.5, 0.0, 0.18, 0.5, 0.9, HULL[0], HULL[1])
	var arm := _p(w, f, 0.0, 0.05, 2.1)
	k.found.strut(arm, _p(w, f, 0.0, 0.55, 1.35), 0.035, 4, HULL[3])
	_box(k.made, w, f, 0.62, 0.72, 0.0, 0.04, 1.55, 1.65, GroundColors.glow(STANDBY, 1.2))
	# The charge it sleeps under: a strip from the ceiling straight down into
	# the bay, so a docked body lies in a pool of it, seen from across the dark
	# hall. It shows the sleeper, not the player: it is no `glare`.
	lights.append([_p(w, f, 0.0, 0.6, kind.wall_h - 0.15), &"strip"])


## The plate over the docks, stencilled.
func _dock_plate(k: Kit, at: Vector2, f: Vector2) -> void:
	var w := at - f * 0.24
	_box(k.found, w, f, -0.4, 0.4, 0.0, 0.03, 1.9, 2.25, HULL[2], HULL[3])
	var ink := GroundColors.made(STENCIL, GroundColors.ENAMEL)
	for i in 3:
		var h := 2.16 - 0.1 * float(i)
		_box(k.made, w, f, -0.32, 0.1 + 0.08 * float(i % 2), 0.03, 0.035, h, h + 0.04, ink)


## The kiln's rack: boards on stickers to the ceiling, drying, and the heat
## under them.
func _kiln_rack(k: Kit, at: Vector2, f: Vector2) -> void:
	var cut := _sawn()
	for course in 9:
		var h := 0.2 + float(course) * 0.3
		_box(k.found, at, f, -1.3, 1.3, -0.3, 0.3, h, h + 0.04, HULL[0])
		for j in 6:
			var u := -1.15 + 0.46 * float(j)
			_box(k.made, at, f, u - 0.2, u + 0.2, -0.28, 0.28, h + 0.04, h + 0.1, cut, cut)
	_box(k.made, at, f, -1.2, 1.2, 0.3, 0.36, 0.05, 0.12, GroundColors.glow(Color(1.0, 0.45, 0.15), 0.8))
	# The kiln's heat, low and red, day and night.
	lights.append([_p(at, f, 0.0, 1.0, 0.5), &"emergency"])
