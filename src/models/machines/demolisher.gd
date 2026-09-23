extends MachineModel
## A demolisher: the Ruined Metropolis's own worker (docs/LANDSCAPES.md §4).
## A squat tracked body, a slew ring on its deck, and a long two-piece
## hydraulic boom ending in a crushing jaw. It is taking the city apart for
## what it is made of, one poured wall at a time, and it does not turn for
## anybody: a charge in a line, a boom that goes up and back for most of a
## second, and a bite that throws a body further than anything on tracks.
##
## Why THIS silhouette. Every other worker is a mass with a tool on it; this is
## a tool with a mass under it. The boom is longer than the body and carries the
## jaw well clear of the tracks, so from a hundred tiles it is a hook standing
## up out of the rubble, and from close to the jaw is the whole picture — a pair
## of plates with teeth, opening. Ruled like every machine: the tracks are two
## slabs on exact pitch, the boom and stick are tapered members with their rams
## laid alongside at one angle, and the only turned things are the slew ring
## and the jaw's hinge pins. Its colour is a WORKER's ramp — the hauler's, the
## heaviest worker the plan runs (Palette: a machine's colour is its role).
##
## walk   the tracks roll with distance; the boom is carried low and nods
## stand  stopped at a wall: the boom folded in over the deck, the jaw shut,
##        and every few seconds the jaw WORKS, exactly, on nothing
## alert  it has you: the turret slews to face, the boom comes up, the jaw opens
## windup the boom rises high and back with the jaw wide, the whole body
##        rocking back on its tracks: the tell is the hook against the sky
## strike the boom slams down and forward and the jaw shuts through where you
##        were, the body pitching over its front sprockets
## hurt   the jaw sags open; nothing flinches
## dead   the boom drops across the ground, the turret slews off true, the
##        hull settles on one side: a hook lying in the street it was eating
##
## lights the plan strip on the deck's top face (read from above), a cold optic
##        in the cab with a scan across its slit, work lamps on the hull's nose
##        washing the ground it is about to take, and the pump's own lamp on
##        the back housing that goes hot through a windup
## part   the hydraulic pump at the BACK of the turret, under a louvred grille:
##        what drives the jaw, and what stops it
## wear   concrete dust up the tracks and hull, plate off two other kinds
##        patched over the deck, oil down the rams, and a bar of reinforcement
##        bent double in the jaw with the concrete still on it

const TRACK_Z := 0.5
const TRACK_TOP := 0.36
const HULL_Y := 0.36
const WHEEL_R := 0.1

var _travel := 0.0
var _wheels: Array[Node3D] = []


func build() -> void:
	part_side = &"back"
	# The jaw carried at rest is what a tell over this body has to clear.
	height = 1.6
	stride = 1.3
	gallery_turn = 26.0
	begin_rig()
	# A worker's ramp: what the palette gives a body that works the plan. The
	# hauler's is the heaviest of the four, which is what tracks and a boom are.
	ramp = Palette.MACHINE["hauler"]
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	_tracks(R, D, DD)
	var hull := joint(&"hull", self, Vector3(0, HULL_Y, 0))
	_hull(hull, R, D)
	var turret := joint(&"turret", hull, Vector3(0.05, 0.42, 0))
	_turret(turret, R, D, DD)
	var boom := joint(&"boom", turret, Vector3(0.28, 0.3, 0))
	_boom(boom, R, D)
	var stick := joint(&"stick", boom, Vector3(1.05, 0.95, 0))
	_stick(stick, R, D)
	var jaw := joint(&"jaw", stick, Vector3(0.82, -0.62, 0))
	_jaw(jaw, R, D, DD)
	finish_rig()


## Two track units, short and wide, the sprockets turning with distance.
func _tracks(R: Array, D: Array, DD: Array) -> void:
	var shape: Array[Vector2] = [Vector2(0.78, 0.22), Vector2(0.62, TRACK_TOP), Vector2(-0.66, TRACK_TOP),
		Vector2(-0.8, 0.22), Vector2(-0.8, 0.12), Vector2(-0.66, 0.0), Vector2(0.62, 0.0), Vector2(0.78, 0.12)]
	for sz: float in [-1.0, 1.0]:
		var tk := FoundKit.kit()
		FoundKit.slab(tk, Vector3(0, 0, sz * TRACK_Z), Vector3.RIGHT, Vector3.UP, shape, 0.34, DD, 0.02)
		for j in 7:
			FoundKit.mark(tk, Vector3(-0.6 + j * 0.2, TRACK_TOP + 0.002, sz * TRACK_Z), Vector3.UP, Vector3.BACK, 0.32, 0.05, R[0], 0.002)
		FoundKit.mark(tk, Vector3(-0.02, 0.18, sz * (TRACK_Z + 0.171)), Vector3.BACK * sz, Vector3.UP, 1.3, 0.2, R[0], 0.002)
		FoundKit.rivets(tk, Vector3(-0.6, 0.3, sz * (TRACK_Z + 0.172)), Vector3(0.6, 0.3, sz * (TRACK_Z + 0.172)), Vector3.BACK * sz, 5, R[5])
		body_mesh(tk, self)
		var w := FoundKit.kit()
		FoundKit.dirt_line(w, Vector3(-0.7, 0.05, sz * (TRACK_Z + 0.172)), Vector3(0.7, 0.05, sz * (TRACK_Z + 0.172)), Vector3.BACK * sz, 0.08, R[1])
		var dust: Array = [Palette.ASH[3], Palette.ASH[4], Palette.ASH[3], Palette.ASH[4], Palette.ASH[4], Palette.ASH[4]]
		FoundKit.grime(w, Vector3(0.1, 0.32, sz * (TRACK_Z + 0.172)), Vector3.BACK * sz, 1.1, 0.24, 4, 13 + int(sz), dust)
		wear_mesh(w, self)
		for x: float in [-0.48, 0.0, 0.48]:
			var wheel := Node3D.new()
			wheel.position = Vector3(x, WHEEL_R + 0.02, sz * (TRACK_Z + 0.19))
			add_child(wheel)
			var wk := FoundKit.kit()
			FoundKit.disc(wk, Vector3.ZERO, Vector3.BACK, WHEEL_R, 0.05, 6, 0.01, D, D[2], PI / 6.0)
			FoundKit.spot(wk, Vector3(0, 0, sz * 0.026), Vector3.BACK * sz, 0.035, 6, R[4], 0.002)
			body_mesh(wk, wheel)
			_wheels.append(wheel)


## The hull between the tracks: a low chamfered deck with the plan strip on top
## and the work lamps on its nose, washing the ground ahead of the jaw.
func _hull(hull: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(1.36, 1.02, 0.16)
	FoundKit.loft(k, [FoundKit.ring(plan, -0.14, 0.06), FoundKit.ring(plan, -0.04), FoundKit.ring(plan, 0.34, 0.01), FoundKit.ring(plan, 0.42, 0.1)], R, true, true)
	FoundKit.seam(k, Vector3(-0.5, 0.421, 0.0), Vector3(0.5, 0.421, 0.0), Vector3.UP, R, 4)
	FoundKit.panel(k, Vector3(0.0, 0.421, -0.32), Vector3.UP, Vector3.RIGHT, 0.5, 0.2, R)
	FoundKit.rivets(k, Vector3(0.681, 0.2, -0.3), Vector3(0.681, 0.2, 0.3), Vector3.RIGHT, 4, R[5])
	# The sloped nose plate with the slit: a thing that eats walls looks at them.
	var nose: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.16, 0.03), Vector2(0.12, 0.3), Vector2(0.0, 0.34)]
	FoundKit.slab(k, Vector3(0.66, 0.02, 0.0), Vector3.RIGHT, Vector3.UP, nose, 0.7, R, 0.02)
	body_mesh(k, hull)
	add_lamp(hull, Vector3(0.0, 0.423, 0.28), Vector3.UP, Vector3.RIGHT, 0.07, 0.07, &"status")
	for sz: float in [-1.0, 1.0]:
		add_lamp(hull, Vector3(0.804, 0.12, sz * 0.24), Vector3(0.99, 0.14, 0), Vector3(-0.14, 0.99, 0), 0.06, 0.05, &"work")
	add_beam(hull, Vector3(0.84, 0.08, 0.0), Vector3(1.4, -0.4, 0.0), 2.4, 1.9, &"work")
	day_wear(hull, Vector3(-0.1, 0.424, 0.1), Vector3.UP, Vector3.RIGHT, 0.7, 0.44, 21, 1)
	var w := FoundKit.kit()
	FoundKit.patch(w, Vector3(-0.42, 0.422, -0.24), Vector3.UP, Vector3.RIGHT, 0.26, 0.2, Palette.MACHINE["sweeper"], 22)
	FoundKit.streaks(w, Vector3(0.0, 0.3, -0.512), Vector3.FORWARD, 0.8, 0.26, 4, 23, R[1])
	FoundKit.scorch(w, Vector3(-0.3, 0.2, 0.512), Vector3.BACK, 0.08, 24)
	wear_mesh(w, hull)


## The turret on its slew ring: the boom's foot, a cab off the left side, and
## the pump housing at the back with its louvred grille — the working part.
func _turret(turret: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	FoundKit.disc(k, Vector3(0, 0.03, 0), Vector3.UP, 0.44, 0.06, 12, 0.012, D, D[2], PI / 12.0)
	var plan := FoundKit.plan_oct(0.98, 0.72, 0.12)
	FoundKit.loft(k, [FoundKit.ring(plan, 0.06, 0.04), FoundKit.ring(plan, 0.12), FoundKit.ring(plan, 0.5, 0.0), FoundKit.ring(plan, 0.58, 0.08)], R, true)
	FoundKit.panel(k, Vector3(0.0, 0.581, 0.0), Vector3.UP, Vector3.RIGHT, 0.5, 0.36, R)
	# The boom's foot: two cheeks the boom pins between.
	for sz: float in [-1.0, 1.0]:
		var cheek: Array[Vector2] = [Vector2(-0.1, -0.02), Vector2(0.34, -0.02), Vector2(0.4, 0.26), Vector2(0.14, 0.42), Vector2(-0.12, 0.3)]
		FoundKit.slab(k, Vector3(0.14, 0.4, sz * 0.2), Vector3.RIGHT, Vector3.UP, cheek, 0.05, D, 0.01)
	# The cab, hung off the left flank, with the slit facing forward.
	var cab := FoundKit.plan_oct(0.44, 0.4, 0.08)
	FoundKit.loft(k, [FoundKit.ring(cab, 0.12, 0.03, Vector2.ONE, Vector2(-0.2, -0.54)), FoundKit.ring(cab, 0.2, 0.0, Vector2.ONE, Vector2(-0.2, -0.54)),
		FoundKit.ring(cab, 0.62, 0.0, Vector2.ONE, Vector2(-0.2, -0.54)), FoundKit.ring(cab, 0.7, 0.06, Vector2.ONE, Vector2(-0.2, -0.54))], R, true)
	FoundKit.visor(k, Vector3(0.021, 0.5, -0.54), Vector3.RIGHT, Vector3.UP, 0.28, 0.04)
	body_mesh(k, turret)
	add_scan(turret, Vector3(0.023, 0.5, -0.54), Vector3.RIGHT, Vector3.BACK, 0.2, 0.03, 2.2)
	add_lamp(turret, Vector3(0.022, 0.34, -0.54), Vector3.RIGHT, Vector3.UP, 0.05, 0.045, &"optic")
	day_marks(turret, Vector3(-0.2, 0.4, 0.361), Vector3.BACK, Vector3.UP, 0.5, 0.3, 31)
	var w := FoundKit.kit()
	FoundKit.patch(w, Vector3(0.1, 0.36, 0.361), Vector3.BACK, Vector3.UP, 0.22, 0.18, Palette.MACHINE["cutter"], 32)
	FoundKit.grime(w, Vector3(-0.2, 0.68, -0.54), Vector3.LEFT, 0.3, 0.3, 3, 33, R)
	wear_mesh(w, turret)
	# The pump housing on the back, and the grille over it: the part.
	var pk := FoundKit.kit()
	var housing := FoundKit.plan_oct(0.36, 0.56, 0.06)
	FoundKit.loft(pk, [FoundKit.ring(housing, 0.1, 0.02, Vector2.ONE, Vector2(-0.6, 0.0)), FoundKit.ring(housing, 0.16, 0.0, Vector2.ONE, Vector2(-0.6, 0.0)),
		FoundKit.ring(housing, 0.5, 0.0, Vector2.ONE, Vector2(-0.6, 0.0)), FoundKit.ring(housing, 0.56, 0.05, Vector2.ONE, Vector2(-0.6, 0.0))], D, false)
	body_mesh(pk, turret)
	add_lamp(turret, Vector3(-0.781, 0.5, 0.18), Vector3.LEFT, Vector3.UP, 0.05, 0.045, &"work", true)
	var lk := FoundKit.kit()
	FoundKit.lens(lk, Vector3(-0.781, 0.33, -0.06), Vector3.LEFT, Vector3.UP, 0.22, 0.2)
	for j in 4:
		FoundKit.mark(lk, Vector3(-0.782, 0.26 + j * 0.05, -0.06), Vector3.LEFT, Vector3.UP, 0.24, 0.014, Palette.LENS[0], 0.013)
	part_mesh(lk, turret)
	set_part_anchor(turret, Vector3(-0.8, 0.33, -0.06), 0.62)


## The main boom: a tapered member up and forward off the turret, its lifting
## ram laid alongside at one angle.
func _boom(boom: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	var tip := Vector3(1.05, 0.95, 0)
	FoundKit.tbar(k, Vector3.ZERO, tip, 0.13, 0.1, 6, R, 0.03)
	FoundKit.seam(k, Vector3(0.1, 0.22, 0.0), Vector3(0.9, 0.95, 0.0), Vector3(-0.67, 0.74, 0), R, 4)
	# The ram: cylinder and rod, from the turret's foot to the boom's middle.
	FoundKit.tbar(k, Vector3(-0.1, -0.22, 0.14), Vector3(0.3, 0.2, 0.14), 0.05, 0.05, 6, D)
	FoundKit.tbar(k, Vector3(0.3, 0.2, 0.14), Vector3(0.58, 0.48, 0.14), 0.026, 0.026, 6, [R[4], R[4], R[5], R[5], R[5], R[5]])
	body_mesh(k, boom)
	var w := FoundKit.kit()
	FoundKit.grime(w, Vector3(0.44, 0.52, 0.08), Vector3(0.67, -0.74, 0), 0.3, 0.2, 2, 41, R)
	wear_mesh(w, boom)


## The stick: down and forward off the boom's head, with the jaw's ram on top.
func _stick(stick: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	var tip := Vector3(0.82, -0.62, 0)
	FoundKit.tbar(k, Vector3(-0.08, 0.06, 0), tip, 0.1, 0.075, 6, R, 0.02)
	FoundKit.lathe(k, Vector3.ZERO, Vector3.BACK, [Vector2(0.09, -0.16), Vector2(0.11, -0.12), Vector2(0.11, 0.12), Vector2(0.09, 0.16)], 8, D, PI / 8.0)
	FoundKit.tbar(k, Vector3(0.0, 0.14, -0.12), Vector3(0.4, -0.1, -0.12), 0.042, 0.042, 6, D)
	FoundKit.tbar(k, Vector3(0.4, -0.1, -0.12), Vector3(0.66, -0.3, -0.12), 0.022, 0.022, 6, [R[4], R[4], R[5], R[5], R[5], R[5]])
	body_mesh(k, stick)
	var w := FoundKit.kit()
	FoundKit.streaks(w, Vector3(0.3, -0.2, 0.1), Vector3.BACK, 0.2, 0.2, 2, 51, R[1])
	wear_mesh(w, stick)


## The jaw: an upper plate fixed to the stick and a lower one on a hinge, both
## toothed, so a pose opens and shuts it. What it last closed on is still in it.
func _jaw(jaw: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	FoundKit.lathe(k, Vector3.ZERO, Vector3.BACK, [Vector2(0.08, -0.2), Vector2(0.1, -0.16), Vector2(0.1, 0.16), Vector2(0.08, 0.2)], 8, D, PI / 8.0)
	var upper: Array[Vector2] = [Vector2(-0.06, 0.12), Vector2(0.56, 0.02), Vector2(0.62, -0.1), Vector2(0.1, -0.16)]
	FoundKit.slab(k, Vector3(0.0, 0.0, 0.0), Vector3.RIGHT, Vector3.UP, upper, 0.36, R, 0.02)
	for j in 3:
		FoundKit.lathe(k, Vector3(0.24 + j * 0.16, -0.14, 0.0), Vector3(0.1, -1.0, 0), [Vector2(0.05, 0.0), Vector2(0.035, 0.06), Vector2(0.0, 0.14)], 4, DD, PI * 0.25)
	body_mesh(k, jaw)
	var lower := joint(&"jaw_lo", jaw, Vector3(0.02, -0.14, 0))
	var lk := FoundKit.kit()
	var plate: Array[Vector2] = [Vector2(-0.02, 0.02), Vector2(0.52, -0.06), Vector2(0.48, -0.26), Vector2(0.0, -0.2)]
	FoundKit.slab(lk, Vector3(0.0, 0.0, 0.0), Vector3.RIGHT, Vector3.UP, plate, 0.32, R, 0.02)
	for j in 3:
		FoundKit.lathe(lk, Vector3(0.14 + j * 0.16, 0.0, 0.0), Vector3(0.1, 1.0, 0), [Vector2(0.045, 0.0), Vector2(0.03, 0.06), Vector2(0.0, 0.13)], 4, DD, PI * 0.25)
	FoundKit.rivets(lk, Vector3(0.1, -0.12, 0.161), Vector3(0.4, -0.16, 0.161), Vector3.BACK, 3, R[5])
	body_mesh(lk, lower)
	# Reinforcement bent double in the jaw with the concrete still on it: what it
	# was eating when you met it.
	var bars := FoundKit.kit()
	FoundKit.tbar(bars, Vector3(0.1, -0.06, -0.22), Vector3(0.5, -0.1, 0.1), 0.014, 0.014, 3, FoundKit.flat(Palette.RUST[2]))
	FoundKit.tbar(bars, Vector3(0.5, -0.1, 0.1), Vector3(0.7, 0.08, 0.26), 0.014, 0.014, 3, FoundKit.flat(Palette.RUST[3]))
	wear_mesh(bars, jaw)
	var lump := FoundKit.matter_kit(Ink.HAND)
	lump.rock(0.34, -0.14, 0.04, 0.12, 0.1, 470, Palette.ASH[3], 5)
	wear_matter(lump, jaw)


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"stand":
			# Stopped at a wall: the boom folded in over the deck, the jaw shut.
			d[&"boom"] = r(Vector3(0, 0, 0.2))
			d[&"stick"] = r(Vector3(0, 0, -0.5))
			d[&"jaw_lo"] = r(Vector3(0, 0, 0.06))
		&"alert":
			# The turret slews to face, the boom comes up, the jaw opens.
			d[&"turret"] = r(Vector3(0, 0.06, 0))
			d[&"boom"] = r(Vector3(0, 0, 0.36))
			d[&"stick"] = r(Vector3(0, 0, -0.2))
			d[&"jaw_lo"] = r(Vector3(0, 0, -0.5))
		&"windup":
			# The hook goes up against the sky, wide open, the body rocking back.
			d[&"hull"] = pr(Vector3(-0.06, 0.03, 0), Vector3(0, 0, 0.07))
			d[&"boom"] = r(Vector3(0, 0, 0.8))
			d[&"stick"] = r(Vector3(0, 0, 0.16))
			d[&"jaw_lo"] = r(Vector3(0, 0, -0.95))
		&"strike":
			# And comes down through where you were, the jaw shutting on it.
			d[&"hull"] = pr(Vector3(0.14, -0.03, 0), Vector3(0, 0, -0.1))
			d[&"turret"] = pr(Vector3(0.08, 0, 0))
			d[&"boom"] = r(Vector3(0, 0, -0.5))
			d[&"stick"] = r(Vector3(0, 0, -0.42))
			d[&"jaw_lo"] = r(Vector3(0, 0, 0.1))
		&"hurt":
			d[&"jaw_lo"] = r(Vector3(0, 0, -0.34))
		&"dead":
			# The boom drops across the ground, the turret slews off true and the
			# hull settles on one side: a hook lying in the street it was eating.
			d[&"hull"] = pr(Vector3(0, -0.1, 0.06), Vector3(0.14, 0, 0.04))
			d[&"turret"] = r(Vector3(0, 0.55, 0))
			d[&"boom"] = r(Vector3(0.05, 0, -0.62))
			d[&"stick"] = r(Vector3(0, 0, -0.34))
			d[&"jaw_lo"] = r(Vector3(0, 0, -0.6))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead":
		match j:
			&"boom": return Vector2(LIGHT_FIRST + 0.2, 0.55)
			&"stick", &"jaw_lo": return Vector2(LIGHT_FIRST + 0.45, 0.5)
	return super(p, j)


func _gait_deltas(phase: float) -> Dictionary:
	var a := sin(phase * TAU)
	return {
		&"hull": pr(Vector3(0, absf(a) * 0.014, 0), Vector3(0, 0, a * 0.02)),
		&"boom": r(Vector3(0, 0, a * 0.03)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	_travel += delta * maxf(speed_now, nominal_speed if pose == &"walk" else 0.0)
	for w in _wheels:
		w.rotation.z = -_travel / WHEEL_R
	if pose == &"stand":
		# Every four seconds the jaw works, exactly, on nothing: a machine
		# chewing is what it is for, and it does not stop for you.
		var t := fposmod(clock, 4.0)
		(joints[&"jaw_lo"] as Node3D).rotation.z += -0.3 * (smoothstep(3.0, 3.3, t) - smoothstep(3.5, 3.8, t))
