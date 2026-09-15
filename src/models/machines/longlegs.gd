extends MachineModel
## A long-legs: a gantry. A flat slab slung between four legs that rise above it
## at the knee before they come down to the ground, so what you see first, over a
## dyke, is the legs; and then the daylight under the body. It comes on without
## changing course. The hub where the legs' conduits meet is its working part, on
## the back.
##
## walk   diagonal pairs; the swinging pair lifts at the knee
## alert  stands taller: knees straighten and the legs splay
## dead   the knees give, the shins telescope shut, and the slab lands flat
##        between four bent legs whose feet have not moved
##
## lights a hunter runs dark: a status lamp burning low and steady on the spine,
##        two eyes either side of the slit that lock bright when it has you
## wear   a fence post dragged off a boundary, wired to a shin, a long
##        pale rag caught on a knee, a plate from another machine over the slab, the plumb
##        swinging its exact arc as it waits

const BODY_Y := 1.5
const HIP := Vector2(0.44, 0.3)
## Knee and foot relative to the hip, in the leg's own frame (+X outward).
const KNEE := Vector3(0.3, 0.78, 0.0)
const FOOT_OUT := 0.42
## Knee to foot, in the shin's frame at rest.
const FOOT := Vector3(FOOT_OUT, -(BODY_Y + 0.02 + KNEE.y), 0.0)
## Where each telescope stage of the shin starts, as a fraction of knee to foot
## (the last runs to 0.97 and ends in a point).
const STAGES := [0.0, 0.25, 0.49, 0.73, 0.97]
## How far each stage runs up into the sleeve when the legs give.
const COLLAPSE := [0.0, 0.22, 0.44, 0.66]


func build() -> void:
	part_side = &"back"
	height = BODY_Y + 0.85
	stride = 2.4
	nominal_speed = 3.0
	gallery_turn = 40.0
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)

	var body := joint(&"body", self, Vector3(0, BODY_Y, 0))
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(1.24, 0.9, 0.24)
	FoundKit.loft(k, [FoundKit.ring(plan, -0.13, 0.1), FoundKit.ring(plan, -0.07), FoundKit.ring(plan, 0.07), FoundKit.ring(plan, 0.1, 0.035)], R, true, true)
	# The spine plate, the conduits from each hip to the hub, rivets along the lip.
	var spine := FoundKit.plan_oct(0.74, 0.28, 0.08)
	FoundKit.loft(k, [FoundKit.ring(spine, 0.11), FoundKit.ring(spine, 0.16, 0.03)], R)
	FoundKit.panel(k, Vector3(0.0, 0.161, 0), Vector3.UP, Vector3.RIGHT, 0.54, 0.16, R)
	for sz: float in [-1.0, 1.0]:
		FoundKit.tbar(k, Vector3(HIP.x - 0.08, 0.14, sz * (HIP.y - 0.05)), Vector3(-0.5, 0.14, sz * 0.08), 0.018, 0.018, 4, D)
		FoundKit.tbar(k, Vector3(-HIP.x + 0.08, 0.14, sz * (HIP.y - 0.05)), Vector3(-0.52, 0.14, sz * 0.05), 0.018, 0.018, 4, D)
		FoundKit.rivets(k, Vector3(-0.36, 0.0, sz * 0.451), Vector3(0.36, 0.0, sz * 0.451), Vector3.BACK * sz, 7, R[5])
		FoundKit.streaks(k, Vector3(0.0, -0.06, sz * 0.451), Vector3.BACK * sz, 0.7, 0.06, 6, 21 + int(sz), R[2])
	# Front: the plated face with its visor slit, streaks running down from it.
	FoundKit.visor(k, Vector3(0.621, 0.0, 0), Vector3.RIGHT, Vector3.UP, 0.3, 0.045)
	FoundKit.streaks(k, Vector3(0.621, -0.04, 0), Vector3.RIGHT, 0.26, 0.08, 4, 22, R[2])
	# The hub: a drum on the back face.
	FoundKit.disc(k, Vector3(-0.66, 0.0, 0), Vector3.RIGHT, 0.17, 0.1, 8, 0.03, R, R[2], PI / 8.0)
	body_mesh(k, body)
	add_lamp(body, Vector3(0.3, 0.162, 0), Vector3.UP, Vector3.RIGHT, 0.04, 0.04, &"status")
	for sz: float in [-1.0, 1.0]:
		add_lamp(body, Vector3(0.622, 0.0, sz * 0.22), Vector3.RIGHT, Vector3.UP, 0.04, 0.032, &"optic")
	var ww := FoundKit.kit()
	FoundKit.patch(ww, Vector3(-0.32, 0.101, 0.28), Vector3.UP, Vector3.RIGHT, 0.26, 0.2, Palette.MACHINE["hauler"], 31)
	FoundKit.patch(ww, Vector3(0.34, 0.101, -0.3), Vector3.UP, Vector3.RIGHT, 0.14, 0.12, Palette.FOUND, 32)
	FoundKit.scorch(ww, Vector3(-0.5, 0.101, -0.2), Vector3.UP, 0.08, 33)
	for sz: float in [-1.0, 1.0]:
		FoundKit.grime(ww, Vector3(0.1, -0.03, sz * 0.452), Vector3.BACK * sz, 0.8, 0.09, 4, 34 + int(sz), D)
	# A conduit cut and spliced back by another machine.
	FoundKit.cable(ww, Vector3(-HIP.x + 0.1, 0.19, 0.2), Vector3(-0.3, 0.19, 0.1), 0.02, 0.016, Palette.INK[2], Palette.MACHINE["lineman"], 4)
	wear_mesh(ww, body)
	# A plumb weight hung under the slab on a line; when the slab comes down it
	# is laid flat underneath it.
	var plumb := joint(&"plumb", body, Vector3(0, -0.12, 0))
	var bk := FoundKit.kit()
	FoundKit.tbar(bk, Vector3.ZERO, Vector3(0, -0.24, 0), 0.008, 0.008, 4, D)
	FoundKit.lathe(bk, Vector3(0, -0.24, 0), Vector3.DOWN, [Vector2(0.0, -0.02), Vector2(0.05, 0.03), Vector2(0.0, 0.14)], 6, R)
	body_mesh(bk, plumb)
	add_scan(body, Vector3(0.621, 0.0, 0), Vector3.RIGHT, Vector3.BACK, 0.2, 0.035, 3.2)

	var hub := joint(&"hub", body, Vector3(-0.715, 0, 0))
	var pk := FoundKit.kit()
	FoundKit.optic(pk, Vector3.ZERO, Vector3.LEFT, 0.1)
	FoundKit.mark(pk, Vector3.ZERO, Vector3.LEFT, Vector3.UP, 0.02, 0.26, Palette.LENS[1], 0.014)
	FoundKit.mark(pk, Vector3.ZERO, Vector3.LEFT, Vector3.UP, 0.26, 0.02, Palette.LENS[1], 0.015)
	part_mesh(pk, hub)
	set_part_anchor(body, Vector3(-0.73, 0, 0), 0.7)

	for i in 4:
		var sx := 1.0 if i < 2 else -1.0
		var sz := -1.0 if i % 2 == 0 else 1.0
		var yaw := atan2(-sz * 0.8, sx)
		var leg := joint(StringName("leg%d" % i), body, Vector3(sx * HIP.x, 0.02, sz * HIP.y), Vector3(0, yaw, 0))
		var lk := FoundKit.kit()
		FoundKit.disc(lk, Vector3.ZERO, Vector3.UP, 0.075, 0.09, 6, 0.018, R)
		FoundKit.tbar(lk, Vector3(0, 0.02, 0), KNEE, 0.042, 0.03, 6, R)
		FoundKit.disc(lk, KNEE, Vector3.BACK, 0.055, 0.07, 6, 0.015, R)
		FoundKit.mark(lk, KNEE + Vector3(0, 0, 0.036), Vector3.BACK, Vector3.UP, 0.03, 0.03, R[5], 0.003)
		FoundKit.mark(lk, KNEE - Vector3(0, 0, 0.036), Vector3.FORWARD, Vector3.UP, 0.03, 0.03, R[5], 0.003)
		body_mesh(lk, leg)
		# The shin is a telescope in four stages, each thinner than the last and
		# graduated like a rule; when the legs give they run up inside the sleeve.
		var shin := joint(StringName("shin%d" % i), leg, KNEE)
		var sk := FoundKit.kit()
		FoundKit.tbar(sk, Vector3.ZERO, FOOT * STAGES[1], 0.03, 0.029, 6, D)
		FoundKit.disc(sk, FOOT * STAGES[1], FOOT.normalized(), 0.036, 0.03, 6, 0.008, R)
		body_mesh(sk, shin)
		for st in range(1, 4):
			var tube := joint(StringName("tube%d_%d" % [i, st]), shin, Vector3.ZERO)
			var tk := FoundKit.kit()
			var rad := 0.03 - st * 0.0045
			var a: float = STAGES[st] - 0.03
			var b: float = STAGES[st + 1]
			FoundKit.tbar(tk, FOOT * a, FOOT * b, rad, rad * 0.94, 6, D if st < 3 else FoundKit.dirty(R, 2))
			if st < 3:
				FoundKit.disc(tk, FOOT * b, FOOT.normalized(), rad + 0.005, 0.024, 6, 0.0, R)
			FoundKit.ticks(tk, FOOT * (a + 0.06) + Vector3(0, 0, rad), FOOT * (b - 0.03) + Vector3(0, 0, rad), Vector3.BACK, 4, R[4], 0.018)
			if st == 3:
				FoundKit.tbar(tk, FOOT * b, FOOT * (b + 0.03), rad, 0.0, 6, FoundKit.dirty(R, 2))
			body_mesh(tk, tube)
		if i == 2:
			# A fence post it walked through, still wired to the shin by its fence wire.
			var fw := FoundKit.kit()
			FoundKit.coil(fw, FOOT * 0.06, FOOT * 0.2, 0.07, 2.5, 0.016, Palette.INK[1], true)
			wear_mesh(fw, shin)
			var post := FoundKit.matter_kit(Ink.HAND)
			post.strut(FOOT * 0.02 + Vector3(0.06, 0.0, 0.07), FOOT * 0.23 + Vector3(0.08, 0.0, 0.08), 0.045, 4, Palette.EARTH[4])
			wear_matter(post, shin)
		if i == 3:
			# A rag caught on a knee, above the slab: the first thing seen over a dyke.
			var rk := FoundKit.matter_kit(Ink.HAND)
			rk.strut(KNEE + Vector3(-0.02, 0.05, -0.06), KNEE + Vector3(0.05, 0.05, 0.07), 0.05, 5, Palette.LINEN[3])
			FoundKit.rag(rk, KNEE + Vector3(0.06, 0.03, 0.06), 0.44, 0.2, Palette.LINEN[5], 37, Vector3(1, 0, 0.3))
			wear_matter(rk, leg)
	finish_rig()


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"body"] = pr(Vector3(0, 0.36, 0))
			for i in 4:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, -0.28))
				d[StringName("shin%d" % i)] = r(Vector3(0, 0, 0.22))
		&"windup":
			d[&"body"] = pr(Vector3(-0.12, 0.1, 0), Vector3(0, 0, 0.16))
			for i in 4:
				if i < 2:
					d[StringName("leg%d" % i)] = r(Vector3(0, 0, 0.3))
					d[StringName("shin%d" % i)] = r(Vector3(0, 0, -0.2))
				else:
					# The hind rods take up the pitch.
					d[StringName("leg%d" % i)] = r(Vector3(0, 0, -0.12))
					d[StringName("tube%d_3" % i)] = pr(-FOOT * 0.055)
		&"strike":
			d[&"body"] = pr(Vector3(0.26, -0.18, 0), Vector3(0, 0, -0.14))
			for i in 4:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, 0.14))
				d[StringName("shin%d" % i)] = r(Vector3(0, 0, 0.1 if i < 2 else -0.08))
				if i < 2:
					d[StringName("tube%d_3" % i)] = pr(-FOOT * 0.09)
		&"dead":
			# The slab comes down flat. Every stage of every shin runs up into its
			# sleeve and the knees give outward, low and bent, feet tucked in.
			d[&"body"] = pr(Vector3(0, -BODY_Y + 0.15, 0), Vector3(0.0, 0, -0.015))
			d[&"plumb"] = pr(Vector3(0, 0.05, 0), Vector3(0, 0, 1.5))
			for i in 4:
				d[StringName("leg%d" % i)] = r(Vector3(0, 0, -0.85))
				d[StringName("shin%d" % i)] = r(Vector3(0, 0, -0.28))
				for st in range(1, 4):
					d[StringName("tube%d_%d" % [i, st])] = pr(-FOOT * float(COLLAPSE[st]))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead":
		if j == &"body" or String(j).begins_with("tube"):
			return Vector2(LIGHT_FIRST + 0.1, 0.5)
		if j == &"plumb":
			return Vector2(LIGHT_FIRST + 0.35, 0.3)
	return super(p, j)


## The plumb swings its exact arc while it waits; nothing else moves.
func _routine(_delta: float, on: bool) -> void:
	if not on or pose != &"stand":
		return
	(joints[&"plumb"] as Node3D).rotation.x += sin(clock * 2.1) * 0.12


## Diagonal pairs swing together; the pair in the air lifts at the knee.
func _gait_deltas(phase: float) -> Dictionary:
	var d := {}
	var s := sin(phase * TAU)
	for i in 4:
		var pair := 1.0 if i == 0 or i == 3 else -1.0
		var sx := 1.0 if i < 2 else -1.0
		d[StringName("leg%d" % i)] = r(Vector3(0, s * pair * 0.3 * sx, 0))
		var lift := maxf(0.0, cos(phase * TAU) * pair)
		d[StringName("shin%d" % i)] = r(Vector3(0, 0, -lift * 0.14))
	d[&"body"] = pr(Vector3(0, -absf(s) * 0.05, 0))
	return d
