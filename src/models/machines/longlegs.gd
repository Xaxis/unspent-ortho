extends MachineModel
## A long-legs: a gantry. A flat slab carried on four thin legs at its corners,
## so you see daylight under it before you see anything else. It comes on without
## changing course. The hub where the legs' conduits meet is its working part,
## on the back.
##
## walk   diagonal pairs; the swinging pair retracts its shins to clear the ground
## alert  stands taller on extended shins and splays
## dead   the legs splay outward and the slab drops flat

const BODY_Y := 1.78
const LEG := 1.62
const CORNERS := [Vector2(0.5, -0.36), Vector2(0.5, 0.36), Vector2(-0.5, -0.36), Vector2(-0.5, 0.36)]


func build() -> void:
	part_side = &"back"
	height = 2.0
	stride = 2.4
	nominal_speed = 3.0
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)

	var body := joint(&"body", self, Vector3(0, BODY_Y, 0))
	var k := MeshKit.new()
	FoundKit.cbox(k, Vector3(0, 0.0, 0), Vector3(1.22, 0.24, 0.9), 0.06, R, 2)
	FoundKit.cbox(k, Vector3(-0.04, 0.16, 0), Vector3(0.74, 0.1, 0.38), 0.035, R)
	FoundKit.cbox(k, Vector3(0.0, -0.16, 0), Vector3(0.9, 0.08, 0.5), 0.03, D)
	FoundKit.seam(k, Vector3(-0.56, 0.121, -0.3), Vector3(0.56, 0.121, -0.3), Vector3.UP, R, 5)
	FoundKit.seam(k, Vector3(-0.56, 0.121, 0.3), Vector3(0.56, 0.121, 0.3), Vector3.UP, R, 5)
	FoundKit.panel(k, Vector3(-0.04, 0.211, 0), Vector3.UP, Vector3.RIGHT, 0.6, 0.26, R)
	# Conduits from each corner into the hub at the back.
	for c: Vector2 in CORNERS:
		FoundKit.bar(k, Vector3(c.x * 0.9, 0.135, c.y * 0.9), Vector3(-0.56, 0.135, c.y * 0.25), 0.03, 0.03, 0.0, D)
	# Front: the plated face with its visor slit, streaks running down from it.
	FoundKit.visor(k, Vector3(0.611, 0.02, 0), Vector3.RIGHT, Vector3.UP, 0.5, 0.05)
	FoundKit.streaks(k, Vector3(0.611, -0.03, 0), Vector3.RIGHT, 0.4, 0.08, 5, 21, R[2])
	FoundKit.rivets(k, Vector3(0.611, -0.07, -0.38), Vector3(0.611, -0.07, 0.38), Vector3.RIGHT, 6, R[5])
	FoundKit.streaks(k, Vector3(0.3, -0.121, 0.451), Vector3.BACK, 0.9, 0.09, 6, 22, R[2])
	# The hub: a drum on the back face.
	FoundKit.disc(k, Vector3(-0.66, 0.0, 0), Vector3.RIGHT, 0.2, 0.14, 8, 0.03, R, R[2], PI / 8.0)
	FoundKit.rivets(k, Vector3(-0.611, 0.1, -0.3), Vector3(-0.611, 0.1, 0.3), Vector3.LEFT, 5, R[5])
	body_mesh(k, body)
	add_scan(body, Vector3(0.611, 0.02, 0), Vector3.RIGHT, Vector3.BACK, 0.4, 0.04, 3.2)

	var pk := MeshKit.new()
	FoundKit.disc(pk, Vector3(-0.735, 0.0, 0), Vector3.RIGHT, 0.13, 0.02, 8, 0.0, R, Palette.LENS[1], PI / 8.0)
	FoundKit.mark(pk, Vector3(-0.746, 0, 0), Vector3.LEFT, Vector3.UP, 0.16, 0.05, Palette.LENS[2], 0.002)
	FoundKit.mark(pk, Vector3(-0.746, 0, 0), Vector3.LEFT, Vector3.UP, 0.05, 0.16, Palette.LENS[2], 0.003)
	FoundKit.mark(pk, Vector3(-0.746, 0, 0), Vector3.LEFT, Vector3.UP, 0.06, 0.06, Palette.LENS[3], 0.004)
	var hub := joint(&"hub", body, Vector3.ZERO)
	part_mesh(pk, hub)
	set_part_anchor(body, Vector3(-0.76, 0, 0), 0.8)

	for i in 4:
		var c: Vector2 = CORNERS[i]
		var sz := signf(c.y)
		var sx := signf(c.x)
		var leg := joint(StringName("leg%d" % i), body, Vector3(c.x, -0.08, c.y))
		var lk := MeshKit.new()
		FoundKit.cbox(lk, Vector3(0, 0, 0), Vector3(0.14, 0.14, 0.14), 0.035, R)
		FoundKit.bar(lk, Vector3(0, 0, 0), Vector3(sx * 0.06, -LEG * 0.62, sz * 0.08), 0.06, 0.06, 0.012, R)
		FoundKit.cbox(lk, Vector3(sx * 0.06, -LEG * 0.62, sz * 0.08), Vector3(0.085, 0.07, 0.085), 0.02, R)
		body_mesh(lk, leg)
		var shin := joint(StringName("shin%d" % i), leg, Vector3(sx * 0.06, -LEG * 0.62, sz * 0.08))
		var sk := MeshKit.new()
		FoundKit.bar(sk, Vector3(0, 0.1, 0), Vector3(sx * 0.04, -LEG * 0.38, sz * 0.05), 0.04, 0.04, 0.008, D)
		FoundKit.cbox(sk, Vector3(sx * 0.04, -LEG * 0.38 + 0.02, sz * 0.05), Vector3(0.1, 0.04, 0.1), 0.012, FoundKit.dirty(R, 2))
		body_mesh(sk, shin)
	finish_rig()


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"body"] = pr(Vector3(0, 0.26, 0))
			for i in 4:
				var c: Vector2 = CORNERS[i]
				d[StringName("leg%d" % i)] = r(Vector3(-signf(c.y) * 0.16, 0, signf(c.x) * 0.12))
				d[StringName("shin%d" % i)] = pr(Vector3(0, -0.3, 0))
		&"windup":
			d[&"body"] = pr(Vector3(-0.1, 0.12, 0), Vector3(0, 0, 0.14))
			for i in 4:
				var c: Vector2 = CORNERS[i]
				if c.x > 0.0:
					d[StringName("leg%d" % i)] = r(Vector3(0, 0, 0.42))
					d[StringName("shin%d" % i)] = pr(Vector3(0, 0.22, 0))
				else:
					d[StringName("leg%d" % i)] = r(Vector3(0, 0, -0.14))
		&"strike":
			d[&"body"] = pr(Vector3(0.22, -0.12, 0), Vector3(0, 0, -0.12))
			for i in 4:
				var c: Vector2 = CORNERS[i]
				if c.x > 0.0:
					d[StringName("leg%d" % i)] = r(Vector3(0, 0, 0.16))
					d[StringName("shin%d" % i)] = pr(Vector3(0, -0.12, 0))
				else:
					d[StringName("leg%d" % i)] = r(Vector3(0, 0, 0.18))
		&"dead":
			d[&"body"] = pr(Vector3(0, -BODY_Y + 0.3, 0), Vector3(0.05, 0, -0.03))
			for i in 4:
				var c: Vector2 = CORNERS[i]
				d[StringName("leg%d" % i)] = r(Vector3(-signf(c.y) * 1.35, 0, signf(c.x) * 0.35))
				d[StringName("shin%d" % i)] = r(Vector3(-signf(c.y) * 0.22, 0, 0))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead" and j == &"body":
		return Vector2(LIGHT_FIRST + 0.08, 0.5)
	return super(p, j)


## Diagonal pairs swing together; the pair in the air draws its shins up.
func _gait_deltas(phase: float) -> Dictionary:
	var d := {}
	var s := sin(phase * TAU)
	for i in 4:
		var pair := 1.0 if i == 0 or i == 3 else -1.0
		var sw := s * pair
		d[StringName("leg%d" % i)] = r(Vector3(0, 0, sw * 0.26))
		var lift := maxf(0.0, cos(phase * TAU) * pair)
		d[StringName("shin%d" % i)] = pr(Vector3(0, lift * 0.16, 0))
	d[&"body"] = pr(Vector3(0, -absf(s) * 0.05, 0))
	return d
