extends MachineModel
## A sorter: the Middens' own worker (Roster, improvement 3b). It picks the tipped
## refuse over through a shaking grille on its back and throws what the plan has
## no use for up onto the canyon walls, which is what the walls are made of. Two
## big wheels under a short chassis, a skid dragging behind, an open hopper on
## its back, and a throwing arm longer than the whole body on a post at the
## front, with a basket at its end and a counterweight of lashed plate at the
## short end.
##
## Why THIS silhouette. The middens' other workers are masses low on the ground;
## this is a lever standing over one. At rest the arm lies forward along the
## nose; cocked, it stands up and back over the hopper, a hook against the strip
## of sky, and that shape at the end of a canyon is the thing to learn. Ruled
## like every machine: the arm is one tapered member, the counterweight slabs
## are on exact pitch, the only turned things are the wheels and the pivot. On a
## worker's ramp, the sweeper's, the other body that works these floors.
##
## walk   the wheels roll with distance; the arm is carried forward, nodding
## stand  the grille over the hopper shakes on an exact beat: it is sorting
## alert  the arm comes up off the nose, the basket turned toward you
## windup the arm swings right back over the hopper, the basket down into it
##        for a load, the chassis rocking back on its wheels: the tell is the
##        arm standing up behind it, and it holds there the whole windup
## strike the arm whips over and forward and the chassis pitches onto its nose
## hurt   nothing flinches: the hopper's light stutters out
## dead   the arm falls forward across the ground, the chassis settles over on
##        one wheel with the skid in the air: a lever lying in the refuse
##
## lights the plan strip on the chassis top (read from above), a cold optic
##        under a hood at the front with a scan across its slit, work lamps on
##        the nose washing the ground it throws down, and the hopper's own lamp
##        on the back that goes hot through a windup
## part   the feed throat at the foot of the hopper, on the BACK: where the next
##        load comes from, and what stops it
## wear   refuse heaped in the hopper, a replacement wheel off another kind,
##        rust run down from the hopper's seams

const WHEEL_R := 0.28
const WHEEL_Z := 0.4
const BODY_Y := 0.34
const ARM_LEN := 1.3
const ARM_SHORT := 0.3

var _travel := 0.0
var _wheels: Array[Node3D] = []


func build() -> void:
	part_side = &"back"
	height = 1.5
	stride = 1.1
	gallery_turn = 34.0
	begin_rig()
	ramp = Palette.MACHINE["sweeper"]
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var body := joint(&"body", self, Vector3(0, BODY_Y, 0))
	_chassis(body, R, D, DD)
	var sieve := joint(&"sieve", body, Vector3(-0.2, 0.62, 0))
	_sieve(sieve, R, D)
	var arm := joint(&"arm", body, Vector3(0.24, 0.5, 0))
	_arm(arm, R, D, DD)
	_wheels_and_skid(R, D, DD)
	finish_rig()


## The chassis and the hopper on its back. The hopper is open: what is in it is
## drawn in the world's own hand, because it is the world.
func _chassis(body: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(0.84, 0.56, 0.12)
	FoundKit.loft(k, [FoundKit.ring(plan, -0.12, 0.05), FoundKit.ring(plan, -0.06), FoundKit.ring(plan, 0.2, 0.0), FoundKit.ring(plan, 0.26, 0.06)], R, true, true)
	FoundKit.seam(k, Vector3(-0.3, 0.261, 0.0), Vector3(0.36, 0.261, 0.0), Vector3.UP, R, 4)
	# The hood over the optic, forward of the arm's post.
	var hood: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.14, 0.02), Vector2(0.12, 0.16), Vector2(-0.02, 0.2)]
	FoundKit.slab(k, Vector3(0.36, 0.06, 0.0), Vector3.RIGHT, Vector3.UP, hood, 0.34, D, 0.015)
	FoundKit.visor(k, Vector3(0.471, 0.12, 0), Vector3.RIGHT, Vector3.UP, 0.22, 0.035)
	# The arm's post: two cheeks the pivot pins between.
	for sz: float in [-1.0, 1.0]:
		var cheek: Array[Vector2] = [Vector2(-0.12, 0.0), Vector2(0.12, 0.0), Vector2(0.06, 0.28), Vector2(-0.06, 0.28)]
		FoundKit.slab(k, Vector3(0.24, 0.24, sz * 0.13), Vector3.RIGHT, Vector3.UP, cheek, 0.04, D, 0.01)
	FoundKit.disc(k, Vector3(0.24, 0.5, 0.0), Vector3.BACK, 0.05, 0.34, 8, 0.01, D, D[3], PI / 8.0)
	# The hopper: wider at the mouth than at the throat, open at the top.
	var hop := FoundKit.plan_oct(0.5, 0.52, 0.08)
	var at := Vector2(-0.2, 0.0)
	FoundKit.loft(k, [FoundKit.ring(hop, 0.24, 0.08, Vector2(0.8, 0.8), at), FoundKit.ring(hop, 0.3, 0.0, Vector2(0.8, 0.8), at),
		FoundKit.ring(hop, 0.62, 0.0, Vector2(1.1, 1.1), at)], R)
	for sz: float in [-1.0, 1.0]:
		FoundKit.rivets(k, Vector3(-0.44, 0.34, sz * 0.25), Vector3(0.04, 0.34, sz * 0.25), Vector3.BACK * sz, 4, R[5])
	body_mesh(k, body)
	add_lamp(body, Vector3(0.12, 0.263, 0.2), Vector3.UP, Vector3.RIGHT, 0.05, 0.05, &"status")
	add_lamp(body, Vector3(0.472, 0.12, 0), Vector3.RIGHT, Vector3.UP, 0.05, 0.04, &"optic")
	add_scan(body, Vector3(0.473, 0.12, 0), Vector3.RIGHT, Vector3.BACK, 0.18, 0.03, 2.0)
	for sz: float in [-1.0, 1.0]:
		add_lamp(body, Vector3(0.43, -0.02, sz * 0.2), Vector3(0.98, -0.2, 0), Vector3(0.2, 0.98, 0), 0.06, 0.045, &"work")
	add_beam(body, Vector3(0.46, -0.04, 0.0), Vector3(1.0, -0.26, 0.0), 2.2, 1.0, &"work")
	add_lamp(body, Vector3(-0.47, 0.44, 0.16), Vector3.LEFT, Vector3.UP, 0.05, 0.04, &"work", true)
	day_marks(body, Vector3(0.12, 0.262, -0.1), Vector3.UP, Vector3.RIGHT, 0.24, 0.2, 61)
	var w := FoundKit.kit()
	FoundKit.streaks(w, Vector3(-0.2, 0.6, 0.29), Vector3.BACK, 0.4, 0.34, 4, 62, Palette.RUST[2])
	FoundKit.streaks(w, Vector3(-0.2, 0.6, -0.29), Vector3.FORWARD, 0.4, 0.3, 3, 63, Palette.RUST[1])
	FoundKit.patch(w, Vector3(0.1, 0.1, 0.281), Vector3.BACK, Vector3.UP, 0.22, 0.14, Palette.MACHINE["hauler"], 64)
	FoundKit.dirt_line(w, Vector3(-0.4, -0.1, 0.281), Vector3(0.4, -0.1, 0.281), Vector3.BACK, 0.05, Palette.ASH[2])
	wear_mesh(w, body)
	# The feed throat: a lens in a collar at the foot of the hopper's back face.
	var pk := FoundKit.kit()
	FoundKit.lens(pk, Vector3(-0.461, 0.16, 0.0), Vector3.LEFT, Vector3.UP, 0.2, 0.16)
	for j in 3:
		FoundKit.mark(pk, Vector3(-0.462, 0.1 + j * 0.05, 0.0), Vector3.LEFT, Vector3.UP, 0.22, 0.012, Palette.LENS[0], 0.012)
	part_mesh(pk, body)
	set_part_anchor(body, Vector3(-0.48, 0.16, 0.0), 0.5)
	# What it is sorting: refuse heaped proud of the hopper's mouth.
	var heap := FoundKit.matter_kit(Ink.HAND)
	var refuse: Array[Color] = [Palette.RUST[2], Palette.ASH[2], Palette.LINEN[2], Palette.STONE[2]]
	for j in 6:
		var a := float(j) / 6.0 * TAU
		heap.rock(-0.2 + cos(a) * 0.14, 0.6, sin(a) * 0.14, 0.09 + Rng.hash01(65, j) * 0.05, 0.08, 650 + j, refuse[j % 4], 4)
	wear_matter(heap, body)


## The grille over the hopper's mouth, which shakes while it sorts.
func _sieve(sieve: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	for j in 5:
		FoundKit.tbar(k, Vector3(-0.22 + j * 0.11, 0.02, -0.26), Vector3(-0.22 + j * 0.11, 0.02, 0.26), 0.014, 0.014, 4, D)
	FoundKit.tbar(k, Vector3(-0.26, 0.03, -0.22), Vector3(0.24, 0.03, -0.22), 0.016, 0.016, 4, R)
	FoundKit.tbar(k, Vector3(-0.26, 0.03, 0.22), Vector3(0.24, 0.03, 0.22), 0.016, 0.016, 4, R)
	body_mesh(k, sieve)


## The throwing arm, built lying forward along +X from its pivot: one tapered
## member, a basket at the long end with a load in it, and lashed plate at the
## short end for a counterweight.
func _arm(arm: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	# A truss, not a pole: two chords tapering to the basket with ties across on
	# an exact pitch, so the arm reads as a made thing at the end of a canyon.
	for sz: float in [-1.0, 1.0]:
		FoundKit.bar(k, Vector3(-ARM_SHORT, 0.0, sz * 0.07), Vector3(ARM_LEN, 0.0, sz * 0.045), 0.07, 0.035, 0.01, R)
	for j in 6:
		var x := 0.05 + j * 0.22
		var zw := lerpf(0.07, 0.045, (x + ARM_SHORT) / (ARM_LEN + ARM_SHORT))
		FoundKit.bar(k, Vector3(x, 0.0, -zw), Vector3(x, 0.0, zw), 0.03, 0.03, 0.005, D)
	# The counterweight: three plates of other machines on exact pitch.
	for j in 3:
		FoundKit.cbox(k, Vector3(-ARM_SHORT + 0.04 + j * 0.07, -0.08, 0.0), Vector3(0.06, 0.2, 0.26), 0.01, DD)
	# The basket: one squat box at the tip with the load proud of it.
	FoundKit.cbox(k, Vector3(ARM_LEN + 0.06, -0.02, 0.0), Vector3(0.24, 0.12, 0.24), 0.02, D)
	body_mesh(k, arm)
	var lump := FoundKit.matter_kit(Ink.HAND)
	lump.rock(ARM_LEN + 0.06, 0.04, 0.0, 0.09, 0.08, 720, Palette.RUST[3], 4)
	wear_matter(lump, arm)


## Two big wheels on one axle and a skid dragging behind. The right wheel came
## off another kind: fewer spokes, another ramp.
func _wheels_and_skid(R: Array, D: Array, DD: Array) -> void:
	for sz: float in [-1.0, 1.0]:
		var wheel := Node3D.new()
		wheel.position = Vector3(0.06, WHEEL_R, sz * WHEEL_Z)
		add_child(wheel)
		var odd := sz > 0.0
		var WR: Array = FoundKit.dirty(Palette.MACHINE["runner"]) if odd else D
		var wk := FoundKit.kit()
		FoundKit.disc(wk, Vector3.ZERO, Vector3.BACK, WHEEL_R, 0.08, 10, 0.015, WR, WR[1], PI / 10.0)
		FoundKit.disc(wk, Vector3(0, 0, sz * 0.045), Vector3.BACK, 0.07, 0.03, 6, 0.01, R, R[4], PI / 6.0)
		for j in (3 if odd else 5):
			var a := float(j) / (3.0 if odd else 5.0) * TAU
			FoundKit.mark(wk, Vector3(cos(a), sin(a), 0) * 0.16 + Vector3(0, 0, sz * 0.041), Vector3.BACK * sz, Vector3(cos(a), sin(a), 0), 0.03, 0.18, WR[4], 0.002)
		body_mesh(wk, wheel)
		_wheels.append(wheel)
	var sk := FoundKit.kit()
	FoundKit.tbar(sk, Vector3(-0.36, BODY_Y - 0.06, 0.0), Vector3(-0.62, 0.03, 0.0), 0.03, 0.025, 5, DD)
	FoundKit.cbox(sk, Vector3(-0.66, 0.02, 0.0), Vector3(0.16, 0.03, 0.18), 0.008, DD)
	body_mesh(sk, self)


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"stand", &"walk":
			# Carried forward along the nose, basket low.
			d[&"arm"] = r(Vector3(0, 0, -0.32))
		&"alert":
			d[&"arm"] = r(Vector3(0, 0, 0.5))
			d[&"body"] = pr(Vector3(0, 0.03, 0), Vector3(0, 0, 0.04))
		&"windup":
			# Right back over the hopper, the basket down in it for a load: the
			# lever standing up behind the body, held for the whole tell.
			d[&"arm"] = r(Vector3(0, 0, 1.95))
			d[&"body"] = pr(Vector3(-0.04, 0.02, 0), Vector3(0, 0, 0.09))
		&"strike":
			# Whipped over and forward, the chassis pitched onto its nose.
			d[&"arm"] = r(Vector3(0, 0, 0.12))
			d[&"body"] = pr(Vector3(0.06, -0.03, 0), Vector3(0, 0, -0.14))
		&"dead":
			# The arm across the ground ahead, the chassis over on one wheel.
			d[&"arm"] = r(Vector3(0.1, 0, -0.26))
			d[&"body"] = pr(Vector3(0.0, -0.15, 0.04), Vector3(0.16, 0.0, -0.08))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"windup" and j == &"arm":
		# Swung back slowly enough to be seen going: most of a second's tell.
		return Vector2(0.0, 0.45)
	if p == &"dead" and j == &"arm":
		return Vector2(LIGHT_FIRST + 0.25, 0.5)
	return super(p, j)


func _gait_deltas(phase: float) -> Dictionary:
	var a := sin(phase * TAU)
	return {
		&"body": pr(Vector3(0, absf(a) * 0.012, 0), Vector3(0, 0, a * 0.015)),
		&"arm": r(Vector3(0, 0, a * 0.04)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	_travel += delta * maxf(speed_now, nominal_speed if pose == &"walk" else 0.0)
	for w in _wheels:
		w.rotation.z = -_travel / WHEEL_R
	var sieve := joints[&"sieve"] as Node3D
	if pose == &"stand":
		# It sorts on an exact beat: three shakes, a rest.
		var t := fposmod(clock, 1.6)
		sieve.position.x += 0.02 * sin(t * TAU * 5.0) * (1.0 - smoothstep(0.6, 0.7, t))
