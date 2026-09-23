extends MachineModel
## A ferry: the Drowned City's own machine (docs/LANDSCAPES.md §5). A flat
## barge that runs the canals to a timetable nobody set, carrying salvage
## stripped from the drowned substations out to sea: a low deck stacked with
## what it took, a crane stub amidships to load it, a cabin at the stern, and a
## steel ram on the bow that it runs through whatever is in its lane.
##
## Why THIS silhouette. Everything else the plan runs stands up off the ground
## on legs, tracks or skates; this one lies ON the water and nothing of it is
## taller than a person but the crane. From a bridge it is a long flat shape
## with one hook standing out of it, moving at exactly the same pace down the
## middle of a canal, and the only thing in the frame that goes in a straight
## line on the water. It is a KEEPER, not a worker: it keeps a route, and a raft
## in its lane is trespass on the route (Roles.TURNS). Ruled like every machine:
## the hull is one lofted plan, the ram a wedge on exact lines, the crane a
## tapered post and jib; the only turned things are the slew ring, the sheave
## and the screw. Its colour is the KEEPER's ramp, the lockkeeper's own
## (Palette: a machine's colour is its role).
##
## walk   under way: the hull pitches, slowly, on its own wash; the crane jib
##        swings a little with it
## stand  moored at a stop: the crane slews out over the side and back, loading
## alert  it has you: the crane swings in over the deck and the bow comes round
## windup the stern digs in and the bow lifts: the ram comes up out of the water,
##        which is the tell
## strike it drives forward and the bow comes down through where you were
## hurt   it rolls; nothing flinches
## dead   it settles by the stern and lists, the crane jib down across its
##        cargo: a hulk in the canal, which is how every hulk here got there
##
## lights the plan strip on the cabin roof, a cold optic in the cabin's front
##        with a scan across its slit, work lamps at the bow either side of the
##        ram, and one on the screw housing that goes hot through a windup
## part   the screw at the BACK, in a housing under the stern: what drives it,
##        and what stops it
## wear   weed up the hull to the waterline, a pale tide line above it, plate off
##        another kind patched over the ram, and salvage lashed on the deck:
##        ducting, a cable drum, plate, and a substation's insulators
## weld   the crane post and the screw are welded; the hull and the ram keep
##        their facets, because they are plate

## A figure is FLOATED at the water's surface (Swim), so the model's origin is
## the waterline: the hull goes a little under it and the deck stands over it.
const DECK_Y := 0.34
const BOTTOM_Y := -0.22

var _t := 0.0


func build() -> void:
	part_side = &"back"
	# The crane's head is what a tell over this body has to clear.
	height = 1.9
	stride = 1.6
	gallery_turn = 28.0
	begin_rig()
	# A keeper's ramp: it keeps a route, as the lockkeeper keeps the locks.
	ramp = Palette.MACHINE["warden"]
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var hull := joint(&"hull", self, Vector3.ZERO)
	_hull(hull, R, D, DD)
	_ram(hull, R, D, DD)
	_cabin(hull, R, D)
	_cargo(hull, R, D, DD)
	_screw(hull, R, D, DD)
	var crane := joint(&"crane", hull, Vector3(0.15, DECK_Y, 0.0))
	_crane(crane, R, D, DD)
	finish_rig()


## A long flat barge plan, bow at +X: square-ended, the bow chamfered to take
## the ram.
static func _plan() -> Array[Vector2]:
	return [Vector2(1.55, -0.34), Vector2(1.55, 0.34), Vector2(1.25, 0.62), Vector2(-1.45, 0.64),
		Vector2(-1.65, 0.48), Vector2(-1.65, -0.48), Vector2(-1.45, -0.64), Vector2(1.25, -0.62)]


func _hull(hull: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	var plan := _plan()
	FoundKit.loft(k, [
		FoundKit.ring(plan, BOTTOM_Y, 0.0, Vector2(0.9, 0.8)),
		FoundKit.ring(plan, 0.12),
		FoundKit.ring(plan, DECK_Y, 0.04),
	], D, true, true)
	for sz: float in [-1.0, 1.0]:
		# The rubbing strake, and the coaming the cargo sits inside.
		FoundKit.tbar(k, Vector3(1.2, 0.2, sz * 0.63), Vector3(-1.45, 0.2, sz * 0.645), 0.035, 0.035, 4, DD)
		FoundKit.tbar(k, Vector3(0.9, DECK_Y + 0.08, sz * 0.5), Vector3(-0.8, DECK_Y + 0.08, sz * 0.5), 0.04, 0.04, 4, D)
		FoundKit.rivets(k, Vector3(1.1, 0.06, sz * 0.622), Vector3(-1.35, 0.06, sz * 0.64), Vector3.BACK * sz, 9, R[5])
		# Bollards at the quarters: it moors, like any boat on this water.
		for x: float in [1.05, -1.2]:
			FoundKit.lathe(k, Vector3(x, DECK_Y, sz * 0.48), Vector3.UP, [Vector2(0.05, 0.0), Vector2(0.05, 0.09), Vector2(0.07, 0.11), Vector2(0.04, 0.14)], 6, DD, PI / 6.0)
	body_mesh(k, hull)
	day_wear(hull, Vector3(0.1, DECK_Y + 0.002, 0.0), Vector3.UP, Vector3.RIGHT, 1.3, 0.8, 311, 2)
	var w := FoundKit.kit()
	var weed: Array = [Palette.SPRUCE[1], Palette.MOSS[2], Palette.SPRUCE[2], Palette.MOSS[1], Palette.SPRUCE[1], Palette.MOSS[2]]
	for sz: float in [-1.0, 1.0]:
		# The tide line: dried salt where the wash reaches and weed under it.
		FoundKit.dirt_line(w, Vector3(1.2, 0.07, sz * 0.63), Vector3(-1.4, 0.07, sz * 0.645), Vector3.BACK * sz, 0.035, Palette.LINEN[3])
		FoundKit.grime(w, Vector3(-0.1, 0.03, sz * 0.63), Vector3.BACK * sz, 2.4, 0.2, 7, 312 + int(sz), weed)
		FoundKit.streaks(w, Vector3(0.2, DECK_Y - 0.02, sz * 0.64), Vector3.BACK * sz, 2.2, 0.2, 6, 314 + int(sz), R[1])
	wear_mesh(w, hull)


## The ram: a steel wedge on the bow, raked back from the waterline to the deck,
## its edge darker where it has been run through things, and the two work lamps
## either side of it washing the water ahead. What it does to a raft's hull is
## the crafts package's to say (Roster, `ferry`).
func _ram(hull: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	var side: Array[Vector2] = [Vector2(1.5, BOTTOM_Y + 0.04), Vector2(2.05, 0.02), Vector2(1.95, 0.12), Vector2(1.55, DECK_Y)]
	FoundKit.slab(k, Vector3.ZERO, Vector3.RIGHT, Vector3.UP, side, 0.34, D, 0.02)
	# The cutting edge, and a cheek plate each side riveted on.
	FoundKit.tbar(k, Vector3(2.05, 0.02, 0.0), Vector3(1.5, BOTTOM_Y + 0.04, 0.0), 0.035, 0.03, 4, DD)
	for sz: float in [-1.0, 1.0]:
		FoundKit.rivets(k, Vector3(1.6, 0.12, sz * 0.172), Vector3(1.9, 0.08, sz * 0.172), Vector3.BACK * sz, 4, R[5])
	body_mesh(k, hull)
	for sz: float in [-1.0, 1.0]:
		add_lamp(hull, Vector3(1.47, 0.24, sz * 0.46), Vector3(0.8, 0.0, sz * 0.6).normalized(), Vector3.UP, 0.06, 0.05, &"work")
	add_beam(hull, Vector3(1.9, 0.2, 0.0), Vector3(1.5, -0.5, 0.0), 2.6, 1.8, &"work")
	var w := FoundKit.kit()
	FoundKit.patch(w, Vector3(1.75, 0.14, 0.173), Vector3.BACK, Vector3.UP, 0.18, 0.12, Palette.MACHINE["cutter"], 321)
	FoundKit.scorch(w, Vector3(1.8, 0.05, -0.173), Vector3.FORWARD, 0.07, 322)
	wear_mesh(w, hull)


## The cabin at the stern: a low lofted box with a slit across its front and a
## scan running it, the plan strip on its roof, and a stub of exhaust.
func _cabin(hull: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(0.62, 0.84, 0.1)
	var at := Vector3(-1.12, DECK_Y, 0.0)
	var rings: Array = []
	for rg: Array in [FoundKit.ring(plan, 0.0), FoundKit.ring(plan, 0.52), FoundKit.ring(plan, 0.6, 0.06)]:
		var moved: Array = []
		for p: Vector3 in rg:
			moved.append(p + at)
		rings.append(moved)
	FoundKit.loft(k, rings, R, true)
	FoundKit.visor(k, at + Vector3(0.311, 0.38, 0.0), Vector3.RIGHT, Vector3.UP, 0.56, 0.05)
	FoundKit.panel(k, at + Vector3(0.0, 0.28, 0.421), Vector3.BACK, Vector3.UP, 0.4, 0.34, R)
	FoundKit.panel(k, at + Vector3(0.0, 0.28, -0.421), Vector3.FORWARD, Vector3.UP, 0.4, 0.34, R)
	FoundKit.tbar(k, at + Vector3(-0.18, 0.6, 0.22), at + Vector3(-0.18, 0.98, 0.22), 0.05, 0.045, 6, D)
	body_mesh(k, hull)
	add_lamp(hull, at + Vector3(0.02, 0.602, 0.0), Vector3.UP, Vector3.RIGHT, 0.06, 0.06, &"status")
	add_scan(hull, at + Vector3(0.313, 0.38, 0.0), Vector3.RIGHT, Vector3.BACK, 0.46, 0.04, 2.6)
	add_lamp(hull, at + Vector3(0.313, 0.2, 0.0), Vector3.RIGHT, Vector3.UP, 0.06, 0.05, &"optic")
	var w := FoundKit.kit()
	FoundKit.streaks(w, at + Vector3(0.312, 0.55, 0.05), Vector3.RIGHT, 0.5, 0.3, 3, 331, R[1])
	FoundKit.scorch(w, at + Vector3(-0.18, 0.99, 0.22), Vector3.UP, 0.06, 332)
	wear_mesh(w, hull)


## What it is carrying out to sea: salvage stripped from the drowned
## substations, lashed inside the coaming. Ducting, a cable drum, a stack of
## plate and a string of insulators: the plan's cargo, FOUND, on the plan's boat.
func _cargo(hull: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	var cable := Palette.MACHINE["lineman"]
	FoundKit.lathe(k, Vector3(0.62, DECK_Y + 0.26, -0.26), Vector3.BACK, [Vector2(0.24, 0.0), Vector2(0.24, 0.05), Vector2(0.16, 0.06), Vector2(0.16, 0.4), Vector2(0.24, 0.41), Vector2(0.24, 0.46)], 10, DD, PI / 10.0)
	FoundKit.lathe(k, Vector3(0.62, DECK_Y + 0.26, -0.21), Vector3.BACK, [Vector2(0.19, 0.0), Vector2(0.19, 0.36)], 10, cable, PI / 10.0)
	for i in 3:
		FoundKit.cbox(k, Vector3(-0.3 + i * 0.03, DECK_Y + 0.05 + i * 0.07, 0.22 - i * 0.02), Vector3(0.7, 0.06, 0.42), 0.015, D if i % 2 == 0 else R)
	FoundKit.tbar(k, Vector3(-0.55, DECK_Y + 0.12, -0.3), Vector3(0.25, DECK_Y + 0.12, -0.34), 0.11, 0.11, 8, cable)
	# Insulators off a substation, a string of discs still on their pin.
	for i in 4:
		FoundKit.disc(k, Vector3(0.12 + i * 0.1, DECK_Y + 0.28, 0.3), Vector3.RIGHT, 0.08, 0.04, 8, 0.01, FoundKit.flat(Palette.LINEN[3]))
	FoundKit.tbar(k, Vector3(0.05, DECK_Y + 0.28, 0.3), Vector3(0.48, DECK_Y + 0.28, 0.3), 0.015, 0.015, 4, DD)
	# The lashing, over all of it.
	for x: float in [0.5, -0.1]:
		FoundKit.cable(k, Vector3(x, DECK_Y + 0.08, 0.5), Vector3(x + 0.05, DECK_Y + 0.08, -0.5), -0.34, 0.012, Palette.INK[2], [], 5)
	body_mesh(k, hull)


## The screw at the stern, in a housing under the counter, and its lamp. It is
## the working part: amber, turning while it is under way, and the thing the
## halo is drawn round, at the waterline where a pole or a blade from a raft
## reaches it.
func _screw(hull: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	var at := Vector3(-1.72, 0.02, 0.0)
	FoundKit.cbox(k, Vector3(-1.6, 0.12, 0.0), Vector3(0.24, 0.3, 0.6), 0.03, D)
	FoundKit.lathe(k, at, Vector3.LEFT, [Vector2(0.2, -0.06), Vector2(0.22, 0.0), Vector2(0.22, 0.14), Vector2(0.18, 0.18)], 10, DD, PI / 10.0)
	body_mesh(k, hull)
	add_lamp(hull, Vector3(-1.721, 0.3, 0.2), Vector3.LEFT, Vector3.UP, 0.05, 0.05, &"work", true)
	var screw := joint(&"screw", hull, at + Vector3(-0.1, 0.0, 0.0))
	var sk := FoundKit.kit()
	var barrel: Array = [Palette.LENS[0], Palette.LENS[0], Palette.LENS[1], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2]]
	var amber: Array = [Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3], Palette.LENS[3]]
	var s0 := sk.vertex_count()
	FoundKit.lathe(sk, Vector3.ZERO, Vector3.LEFT, [Vector2(0.06, 0.0), Vector2(0.09, 0.04), Vector2(0.07, 0.14), Vector2(0.02, 0.18)], 8, barrel, PI / 8.0)
	sk.smooth_range(s0, sk.vertex_count(), 45.0)
	for j in 3:
		var a := j * TAU / 3.0
		var dir := Vector3(0.0, cos(a), sin(a))
		FoundKit.slab(sk, Vector3(-0.05, 0, 0) + dir * 0.1, Vector3.LEFT, dir, [Vector2(-0.05, -0.06), Vector2(0.05, -0.06), Vector2(0.04, 0.08), Vector2(-0.04, 0.08)], 0.02, amber)
	part_mesh(sk, screw)
	set_part_anchor(hull, at + Vector3(-0.12, 0.0, 0.0), 0.6)


## The crane stub: a slew ring, a short tapered post, a jib out over the side,
## and a hook on its fall. It is the one thing standing up off the deck, and it
## swings: out over the side to load, in over the deck when it has you.
func _crane(crane: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	FoundKit.disc(k, Vector3(0, 0.05, 0), Vector3.UP, 0.2, 0.1, 10, 0.02, DD, Color(0, 0, 0, 0), PI / 10.0)
	var s0 := k.vertex_count()
	FoundKit.tbar(k, Vector3(0, 0.1, 0), Vector3(0, 1.3, 0), 0.09, 0.065, 8, R)
	k.smooth_range(s0, k.vertex_count(), 50.0)
	FoundKit.tbar(k, Vector3(-0.1, 1.2, 0), Vector3(0.9, 1.5, 0.0), 0.05, 0.035, 6, D, 0.01)
	FoundKit.tbar(k, Vector3(0, 0.6, 0), Vector3(0.55, 1.38, 0.0), 0.03, 0.03, 4, DD)
	FoundKit.disc(k, Vector3(0.9, 1.47, 0.0), Vector3.BACK, 0.07, 0.05, 8, 0.01, DD)
	var line := FoundKit.flat(Palette.INK[2])
	FoundKit.tbar(k, Vector3(0.93, 1.44, 0.0), Vector3(0.93, 0.85, 0.0), 0.012, 0.012, 3, line)
	FoundKit.tbar(k, Vector3(0.93, 0.85, 0.0), Vector3(0.96, 0.74, 0.0), 0.03, 0.02, 4, DD)
	body_mesh(k, crane)
	var w := FoundKit.kit()
	FoundKit.grime(w, Vector3(0.09, 0.6, 0.0), Vector3.RIGHT, 0.14, 0.5, 3, 341, R)
	wear_mesh(w, crane)


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"stand":
			# Moored at a stop: the jib out over the side, loading.
			d[&"crane"] = r(Vector3(0.0, 1.2, 0.0))
		&"alert":
			# It has you: the jib swings in over the deck.
			d[&"crane"] = r(Vector3(0.0, -0.3, 0.0))
			d[&"hull"] = pr(Vector3(0.0, 0.02, 0.0), Vector3(0.0, 0.0, 0.02))
		&"windup":
			# The stern digs in and the ram comes up out of the water.
			d[&"hull"] = pr(Vector3(-0.1, 0.04, 0.0), Vector3(0.0, 0.0, 0.16))
			d[&"crane"] = r(Vector3(0.0, -0.3, 0.0))
		&"strike":
			# And it drives through, the bow coming down.
			d[&"hull"] = pr(Vector3(0.35, -0.04, 0.0), Vector3(0.0, 0.0, -0.08))
		&"hurt":
			d[&"hull"] = r(Vector3(0.14, 0.0, 0.0))
		&"dead":
			# Down by the stern and listing, the jib across the cargo.
			d[&"hull"] = pr(Vector3(0.0, -0.18, 0.0), Vector3(0.2, 0.0, 0.14))
			d[&"crane"] = r(Vector3(0.9, -0.8, 0.0))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead" and j == &"crane":
		return Vector2(LIGHT_FIRST + 0.2, 0.7)
	return super(p, j)


## Under way: a slow pitch on its own wash, and the jib swinging with it.
func _gait_deltas(phase: float) -> Dictionary:
	var a := sin(phase * TAU)
	return {
		&"hull": pr(Vector3(0.0, a * 0.015, 0.0), Vector3(0.0, 0.0, a * 0.025)),
		&"crane": r(Vector3(0.0, a * 0.08, 0.0)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	_t += delta
	# The screw turns while it is under way or keeping its stop, and stops the
	# moment it has you: a ferry that has seen you is waiting to be sure.
	if not locked():
		(joints[&"screw"] as Node3D).rotation.x = _t * 5.0
