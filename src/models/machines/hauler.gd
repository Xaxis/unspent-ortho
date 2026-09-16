extends MachineModel
## A hauler: a line. Two flared ore hoppers on six wheels a side, pivoting on a
## hinge, carrying stone that is never loaded level, with a signal mast standing
## between them. It will not turn for you. The hinge is open on the LEFT flank
## only; the right carries a cover plate with a cold slit, so the body is
## deliberately not mirrored there.
##
## walk   the rear hopper swings on the hinge in an exact sway; wheels turn with distance
## alert  jacks up on its rams and BREAKS at the hinge, squaring the rear hopper
##        round: two boxes in a line are two boxes, and two boxes at an angle to
##        each other are a hauler that has stopped for you
## dead   the mast comes down across the rear hopper, the hinge folds and the
##        rear hopper tips its load out
##
## lights work lamps on the nose, one over the hinge that goes hot through a
##        windup, the plan strip in the mast's route board
## wear   the front hopper carries scrap off dead machines, a plate stood on end
##        and a long bone jutting out over the rim; the rear carries stone and
##        a rib cage standing up out of it; plates off
##        other machines on the hopper flanks; a cable spliced over the hinge;
##        at rest the rear hopper nudges on its hinge, exactly, every few seconds

const WHEEL_R := 0.11
const SEG_L := 1.0
const SEG_W := 0.58

var _travel := 0.0
var _wheels: Array[Node3D] = []


func build() -> void:
	part_side = &"left"
	height = 0.9
	stride = 1.4
	gallery_turn = 20.0
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)

	var front := joint(&"front", self, Vector3(0.6, 0, 0))
	_segment(front, true)
	var rear := joint(&"rear", front, Vector3(-0.62, 0, 0))
	var rear_seg := joint(&"rear_seg", rear, Vector3(-0.6, 0, 0))
	_segment(rear_seg, false)

	# The hinge: a post between the hoppers, open on the left, plated on the right.
	#
	# The post runs on up past both rims into the SIGNAL MAST, a head raked back
	# over the rear hopper on a stay down to its rim. It is the one high thing on
	# a hauler, it is where the plan strip goes so the high camera reads it clear
	# of a load, and it is the only thing in the outline that is not a box: a
	# train of two filled rectangles on wheels filled 0.73 of its own bounding box
	# standing up on its rams, and at any distance that is a skip (art review:
	# the machine silhouette is still a box on a box).
	var hk := FoundKit.kit()
	var mast := joint(&"mast", rear, Vector3(0, 0.12, 0))
	var mk := FoundKit.kit()
	FoundKit.tbar(mk, Vector3.ZERO, Vector3(0, 0.88, 0), 0.07, 0.042, 8, R, 0.02)
	FoundKit.disc(mk, Vector3(0, 0.89, 0), Vector3.UP, 0.075, 0.035, 6, 0.012, R, Color(0, 0, 0, 0), PI / 6.0)
	# The route board on top of it, raked back, with the plan strip let into its
	# upper face where the high camera looks straight down at it.
	var head: Array[Vector2] = [Vector2(-0.23, -0.09), Vector2(0.23, -0.07), Vector2(0.2, 0.09), Vector2(-0.2, 0.08)]
	FoundKit.slab(mk, Vector3(-0.04, 0.95, 0), Vector3.BACK, Vector3(0.97, 0.24, 0).normalized(), head, 0.05, R, 0.012)
	FoundKit.tbar(mk, Vector3(-0.05, 0.88, 0), Vector3(-0.52, 0.48, 0), 0.02, 0.016, 4, D)
	body_mesh(mk, mast)
	FoundKit.disc(hk, Vector3(0, 0.2, 0), Vector3.UP, 0.12, 0.06, 8, 0.015, D, Color(0, 0, 0, 0), PI / 8.0)
	FoundKit.tbar(hk, Vector3(-0.22, 0.16, 0), Vector3(0.22, 0.16, 0), 0.035, 0.035, 6, D)
	# Left: the open socket, a dark frame round the hinge.
	var sock: Array[Vector2] = [Vector2(-0.14, -0.12), Vector2(0.14, -0.12), Vector2(0.17, 0.0), Vector2(0.14, 0.14), Vector2(-0.14, 0.14), Vector2(-0.17, 0.0)]
	FoundKit.slab(hk, Vector3(0, 0.42, -0.2), Vector3.RIGHT, Vector3.UP, sock, 0.1, FoundKit.dirty(R, 2), 0.02)
	# Right: the cover plate, riveted, with its slit.
	var cover: Array[Vector2] = [Vector2(-0.16, -0.16), Vector2(0.16, -0.16), Vector2(0.2, -0.08), Vector2(0.2, 0.12), Vector2(0.14, 0.18), Vector2(-0.14, 0.18), Vector2(-0.2, 0.12), Vector2(-0.2, -0.08)]
	FoundKit.slab(hk, Vector3(0, 0.42, 0.19), Vector3.RIGHT, Vector3.UP, cover, 0.07, R, 0.02)
	FoundKit.visor(hk, Vector3(0, 0.47, 0.226), Vector3.BACK, Vector3.UP, 0.22, 0.03)
	FoundKit.rivets(hk, Vector3(-0.15, 0.3, 0.226), Vector3(0.15, 0.3, 0.226), Vector3.BACK, 4, R[5])
	FoundKit.streaks(hk, Vector3(0, 0.44, 0.226), Vector3.BACK, 0.18, 0.12, 3, 51, R[1])
	body_mesh(hk, rear)
	add_scan(rear, Vector3(0, 0.47, 0.226), Vector3.BACK, Vector3.RIGHT, 0.16, 0.025, 2.0)
	add_lamp(mast, Vector3(-0.04, 0.976, 0), Vector3(-0.24, 0.97, 0), Vector3(0.97, 0.24, 0), 0.07, 0.07, &"status")
	add_lamp(rear, Vector3(0.1, 0.52, -0.251), Vector3.FORWARD, Vector3.UP, 0.05, 0.04, &"work", true)
	var rw := FoundKit.kit()
	FoundKit.cable(rw, Vector3(0.04, 0.64, 0.06), Vector3(0.2, 0.18, 0.14), 0.05, 0.015, Palette.INK[2], Palette.MACHINE["watcher"], 5)
	FoundKit.grime(rw, Vector3(0, 0.36, 0.227), Vector3.BACK, 0.3, 0.12, 4, 53, D)
	wear_mesh(rw, rear)
	var pk := FoundKit.kit()
	FoundKit.optic(pk, Vector3(0, 0.42, -0.251), Vector3.FORWARD, 0.08)
	FoundKit.mark(pk, Vector3(0, 0.42, -0.251), Vector3.FORWARD, Vector3.UP, 0.03, 0.24, Palette.LENS[1], 0.014)
	part_mesh(pk, rear)
	set_part_anchor(rear, Vector3(0, 0.42, -0.27), 0.6)
	finish_rig()


## One hopper: chassis, wheels, rams, the flared hopper on its hinge, and its load.
func _segment(seg: Node3D, is_front: bool) -> void:
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)
	var tag := "f" if is_front else "r"
	var ck := FoundKit.kit()
	var beam := FoundKit.plan_oct(SEG_L * 0.92, 0.3, 0.08)
	FoundKit.loft(ck, [FoundKit.ring(beam, 0.09), FoundKit.ring(beam, 0.16, 0.02)], DD)
	for x: float in [-0.3, 0.3]:
		FoundKit.tbar(ck, Vector3(x, 0.14, 0), Vector3(x, 0.3, 0), 0.04, 0.04, 6, D)
		# The jack's ram, sleeved inside the hopper until it runs out.
		FoundKit.tbar(ck, Vector3(x, 0.28, 0), Vector3(x, 0.58, 0), 0.024, 0.024, 6, R)
		FoundKit.ticks(ck, Vector3(x + 0.024, 0.32, 0), Vector3(x + 0.024, 0.56, 0), Vector3.RIGHT, 5, R[5], 0.02)
	FoundKit.tbar(ck, Vector3(0, WHEEL_R, -SEG_W * 0.5 - 0.02), Vector3(0, WHEEL_R, SEG_W * 0.5 + 0.02), 0.02, 0.02, 4, DD)
	body_mesh(ck, seg)
	for x: float in [-0.34, 0.0, 0.34]:
		for sz: float in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(x, WHEEL_R, sz * (SEG_W * 0.5 + 0.02))
			seg.add_child(w)
			var wk := FoundKit.kit()
			FoundKit.disc(wk, Vector3.ZERO, Vector3.BACK, WHEEL_R, 0.06, 6, 0.0, DD, D[2], PI / 6.0)
			FoundKit.spot(wk, Vector3(0, 0, sz * 0.031), Vector3.BACK * sz, 0.04, 6, R[4], 0.002)
			FoundKit.mark(wk, Vector3(0, 0.07, sz * 0.031), Vector3.BACK * sz, Vector3.UP, 0.02, 0.04, R[1], 0.003)
			body_mesh(wk, w)
			_wheels.append(w)

	# The hopper pivots on its right bottom edge, so it can tip over that edge.
	var box := joint(StringName("box_" + tag), seg, Vector3(0, 0.26, SEG_W * 0.5))
	var bk := FoundKit.kit()
	bk.push(Transform3D(Basis.IDENTITY, Vector3(0, 0, -SEG_W * 0.5)))
	var plan := FoundKit.plan_oct(SEG_L, SEG_W, 0.12)
	FoundKit.loft(bk, [FoundKit.ring(plan, 0.0, 0.0, Vector2(0.82, 0.8)), FoundKit.ring(plan, 0.04, 0.0, Vector2(0.86, 0.84)), FoundKit.ring(plan, 0.32), FoundKit.ring(plan, 0.36, 0.035)], R, is_front)
	FoundKit.mark(bk, Vector3(0, 0.362, 0), Vector3.UP, Vector3.RIGHT, SEG_W - 0.1, SEG_L - 0.14, R[0], 0.002)
	for sz: float in [-1.0, 1.0]:
		var n := Vector3(0, -0.16, sz).normalized()
		for x: float in [-0.26, 0.0, 0.26]:
			FoundKit.mark(bk, Vector3(x, 0.18, sz * 0.265), n, Vector3(0, 1, sz * 0.16), 0.022, 0.26, R[1], 0.003)
		FoundKit.rivets(bk, Vector3(-0.4, 0.3, sz * 0.291), Vector3(0.4, 0.3, sz * 0.291), n, 6, R[5], 0.03)
		FoundKit.streaks(bk, Vector3(0.13, 0.28, sz * 0.285), n, 0.16, 0.14, 3, 52 + int(sz) + int(is_front) * 4, R[1])
	if is_front:
		# A sloped nose plate with the slit.
		var nose: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.14, 0.02), Vector2(0.1, 0.26), Vector2(0.0, 0.3)]
		FoundKit.slab(bk, Vector3(SEG_L * 0.5 - 0.02, 0.02, 0), Vector3.RIGHT, Vector3.UP, nose, SEG_W * 0.8, R, 0.02)
		FoundKit.visor(bk, Vector3(SEG_L * 0.5 + 0.1, 0.18, 0), Vector3(0.99, 0.16, 0), Vector3(-0.16, 0.99, 0), 0.3, 0.035)
	# The ram's rod under the hopper, running down into the sleeve.
	for x: float in [-0.3, 0.3]:
		FoundKit.tbar(bk, Vector3(x, 0.02, 0), Vector3(x, -0.18, 0), 0.034, 0.034, 6, D)
	bk.pop()
	body_mesh(bk, box)
	if is_front:
		for sz: float in [-1.0, 1.0]:
			add_lamp(box, Vector3(0.614, 0.09, -SEG_W * 0.5 + sz * 0.16), Vector3(0.99, 0.16, 0), Vector3(-0.16, 0.99, 0), 0.06, 0.05, &"work")
		add_beam(box, Vector3(0.66, 0.06, -SEG_W * 0.5), Vector3(1.4, -0.4, 0), 2.3, 1.7, &"work")
	var sw := FoundKit.kit()
	var flank := Vector3(0, -0.16, -1.0).normalized()
	FoundKit.patch(sw, Vector3(-0.2 if is_front else 0.16, 0.2, -SEG_W * 0.5 - 0.265), flank, Vector3(0, 1, -0.16), 0.24, 0.14, Palette.MACHINE["harvester"] if is_front else Palette.MACHINE["sweeper"], 54 + int(is_front))
	FoundKit.scorch(sw, Vector3(0.28, 0.12, -SEG_W * 0.5 - 0.25), flank, 0.06, 56 + int(is_front))
	var far := Vector3(0, -0.16, 1.0).normalized()
	FoundKit.dirt_line(sw, Vector3(-0.42, 0.06, -SEG_W * 0.5 + 0.25), Vector3(0.42, 0.06, -SEG_W * 0.5 + 0.25), far, 0.05, R[1])
	wear_mesh(sw, box)
	if is_front:
		# The lead hopper's camera-side flank: a metre of flared plate carrying
		# nothing but a dirt line at its foot, and the first thing a player meets
		# of a hauler. It takes the years in plate steps and a well of shadow.
		# Only this one: the hauler is the heaviest kind in the roster and the
		# second hopper's worth of marks puts it over the triangle budget, while
		# the rear already carries a patch, a burn and its own dirt line.
		day_marks(box, Vector3(0.12, 0.2, -SEG_W * 0.5 + 0.265), far, Vector3(0, 1, 0.16).normalized(), 0.34, 0.15, 57)
	if is_front:
		add_scan(box, Vector3(SEG_L * 0.5 + 0.1, 0.18, -SEG_W * 0.5), Vector3(0.99, 0.16, 0), Vector3.BACK, 0.24, 0.03, 2.6)

	# The load, never level: the front carries scrap off dead machines and bones
	# that were in the way; the rear carries stone and a rib cage.
	var ld := joint(StringName("load_" + tag), box, Vector3(0, 0.36, -SEG_W * 0.5))
	var lk := FoundKit.matter_kit(Ink.CONTOUR)
	var sgn := 1.0 if is_front else -1.0
	if is_front:
		var scrap := FoundKit.kit()
		var bent: Array[Vector2] = [Vector2(-0.16, -0.08), Vector2(0.14, -0.1), Vector2(0.18, 0.06), Vector2(-0.12, 0.1)]
		FoundKit.slab(scrap, Vector3(-0.12, 0.1, 0.02), Vector3(0.9, 0.35, 0.2).normalized(), Vector3(-0.2, 0.3, 0.93).normalized(), bent, 0.02, Palette.MACHINE["runner"])
		# A plate off a warden stood on end in the load, over the rim.
		FoundKit.slab(scrap, Vector3(0.2, 0.2, -0.1), Vector3(0.95, 0.0, 0.3).normalized(), Vector3(-0.1, 0.9, -0.42).normalized(), bent, 0.024, Palette.MACHINE["warden"])
		FoundKit.disc(scrap, Vector3(0.02, 0.14, 0.1), Vector3(0.3, 1.0, 0.4), 0.11, 0.04, 6, 0.0, FoundKit.dirty(Palette.MACHINE["sweeper"]), Palette.MACHINE["sweeper"][1], PI / 6.0)
		FoundKit.tbar(scrap, Vector3(-0.3, 0.06, -0.1), Vector3(0.28, 0.2, 0.14), 0.025, 0.025, 4, Palette.MACHINE["lineman"])
		wear_mesh(scrap, ld)
		var bones := FoundKit.matter_kit(Ink.HAND)
		# A long bone jammed in the scrap, jutting up and out past the rim.
		FoundKit.bone(bones, Vector3(-0.22, 0.12, -0.12), Vector3(0.22, 0.46, 0.5), 0.046, 58)
		FoundKit.bone(bones, Vector3(0.1, 0.2, 0.14), Vector3(0.4, 0.18, -0.06), 0.034, 59)
		FoundKit.rib(bones, Vector3(0.2, 0.08, -0.14), Vector3(0.36, 0.1, 0.1), Vector3(0.0, 0.2, 0.0), 0.026)
		wear_matter(bones, ld)
	else:
		var ribs := FoundKit.matter_kit(Ink.HAND)
		# A rib cage standing up out of the stone, taller than the rim.
		for j in 3:
			var x := -0.16 + j * 0.11
			FoundKit.rib(ribs, Vector3(x, 0.24, -0.16), Vector3(x + 0.04, 0.24, 0.17), Vector3(0.02, 0.24, 0.0), 0.026)
		FoundKit.bone(ribs, Vector3(-0.26, 0.3, 0.0), Vector3(0.14, 0.34, 0.0), 0.03, 60)
		wear_matter(ribs, ld)
	for j in (4 if is_front else 7):
		var a := float(j) / 7.0 * TAU
		var rx := cos(a) * 0.3
		var rz := sin(a) * 0.15 + sgn * 0.04
		var hgt := 0.12 + 0.12 * (0.5 + 0.5 * sin(a * sgn + 0.6)) + Rng.hash01(61, j, int(is_front)) * 0.05
		lk.rock(rx, -0.02, rz, 0.14, hgt, 600 + j * 3 + int(is_front), Palette.STONE[2] if j % 3 == 0 else Palette.STONE[3], 5)
	lk.rock(0.03 * sgn, -0.02, sgn * 0.06, 0.22, 0.28, 640 + int(is_front), Palette.STONE[4], 6)
	matter_mesh(lk, ld)


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			# Jacks up on its rams, and the two hoppers break apart at the hinge,
			# each tipped its own way: nothing on it is level.
			d[&"front"] = pr(Vector3(0, 0.05, 0), Vector3(0, 0, 0.08))
			d[&"rear"] = r(Vector3(0, 0.52, -0.2))
			d[&"box_f"] = pr(Vector3(0, 0.46, 0), Vector3(-0.16, 0, 0.14))
			d[&"box_r"] = pr(Vector3(0, 0.4, 0), Vector3(0.12, 0, -0.18))
			d[&"load_f"] = r(Vector3(0.1, 0, 0.08))
			d[&"load_r"] = r(Vector3(-0.08, 0, -0.1))
		&"windup":
			# It jack-knifes. The hinge is the side that opens and the side that
			# takes you, so the hinge is what moves, wide enough to be the shape
			# of the machine and not a detail on it.
			d[&"front"] = pr(Vector3(-0.1, 0.12, 0), Vector3(0, 0, 0.16))
			d[&"box_f"] = pr(Vector3(0, 0.28, 0), Vector3(-0.12, 0, 0.16))
			d[&"box_r"] = pr(Vector3(0, 0.12, 0), Vector3(0.1, 0, -0.1))
			d[&"rear"] = r(Vector3(0, -0.38, -0.22))
		&"strike":
			d[&"front"] = pr(Vector3(0.22, -0.02, 0), Vector3(0, 0, -0.06))
			d[&"box_f"] = pr(Vector3(0, 0.1, 0))
			d[&"rear"] = r(Vector3(0, 0, 0.06))
		&"dead":
			d[&"rear"] = r(Vector3(0, 0.78, 0))
			# The mast comes down with it: a hauler that is finished is a hauler
			# whose board is lying across its own rear hopper.
			d[&"mast"] = r(Vector3(0, 0, -1.35))
			d[&"box_r"] = pr(Vector3(0, -0.2, 0.04), Vector3(1.3, 0, 0))
			d[&"load_r"] = pr(Vector3(0.05, 0.39, 0.37), Vector3(-1.2, 0.4, 0))
			d[&"box_f"] = pr(Vector3(0, -0.095, 0), Vector3(0.05, 0, 0.03))
			d[&"load_f"] = pr(Vector3(0, -0.06, 0), Vector3(0.06, 0, 0))
			d[&"front"] = r(Vector3(-0.03, 0, 0))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead":
		match j:
			&"mast": return Vector2(LIGHT_FIRST + 0.25, 0.5)
			&"box_r": return Vector2(LIGHT_FIRST + 0.45, 0.45)
			&"load_r": return Vector2(LIGHT_FIRST + 0.7, 0.4)
	return super(p, j)


func _gait_deltas(phase: float) -> Dictionary:
	return {
		&"rear": r(Vector3(0, sin(phase * TAU) * 0.06, 0)),
		&"box_f": pr(Vector3(0, absf(sin(phase * TAU * 2.0)) * 0.012, 0)),
		&"box_r": pr(Vector3(0, absf(cos(phase * TAU * 2.0)) * 0.012, 0)),
		&"load_f": r(Vector3(sin(phase * TAU * 2.0) * 0.03, 0, 0)),
		&"load_r": r(Vector3(cos(phase * TAU * 2.0) * 0.03, 0, 0)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	if pose == &"stand":
		# Every five seconds the rear hopper takes up its hinge, exactly, and lets it back.
		var t := fposmod(clock, 5.0)
		(joints[&"rear"] as Node3D).rotation.y += 0.07 * (smoothstep(4.2, 4.4, t) - smoothstep(4.6, 4.8, t))
	_travel += delta * maxf(speed_now, nominal_speed if pose == &"walk" else 0.0)
	for w in _wheels:
		w.rotation.z = -_travel / WHEEL_R
