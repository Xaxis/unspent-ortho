extends MachineModel
## A sweeper: a T. A low wide deck with a tall hopper standing over the middle,
## the only silhouette with a corner. It goes along the tracks in the early
## morning behind the wardens, brushes turning, and comes over you, not after
## you. The vent on the back of the hopper glows: the working part.
##
## alert  the hopper lifts on its ram and leans out over the front
## dead   the hopper tips off backwards and what it swept spills out

const WHEEL_R := 0.15

var _travel := 0.0
var _brush_t := 0.0
var _wheels: Array[Node3D] = []
var _roller: Node3D
var _side: Array[Node3D] = []


func build() -> void:
	part_side = &"back"
	height = 1.25
	stride = 1.0
	gallery_turn = 55.0
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var deck := joint(&"deck", self, Vector3(0, 0.24, 0))
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(0.72, 1.22, 0.22)
	FoundKit.loft(k, [FoundKit.ring(plan, -0.08, 0.06), FoundKit.ring(plan, -0.04), FoundKit.ring(plan, 0.03), FoundKit.ring(plan, 0.06, 0.04)], R, true)
	# Mudguards over the wheels, a skirt at the front, rams to the hopper.
	for sz: float in [-1.0, 1.0]:
		var guard: Array[Vector2] = [Vector2(-0.3, 0.0), Vector2(-0.22, 0.12), Vector2(0.06, 0.12), Vector2(0.14, 0.0)]
		FoundKit.slab(k, Vector3(0, 0.02, sz * 0.66), Vector3.RIGHT, Vector3.UP, guard, 0.14, R, 0.015)
		FoundKit.tbar(k, Vector3(-0.02, 0.06, sz * 0.12), Vector3(-0.02, 0.5, sz * 0.12), 0.026, 0.026, 6, D)
		FoundKit.seam(k, Vector3(-0.26, 0.061, sz * 0.36), Vector3(0.26, 0.061, sz * 0.36), Vector3.UP, R, 3)
		FoundKit.streaks(k, Vector3(0.0, 0.0, sz * 0.611), Vector3.BACK * sz, 0.4, 0.06, 4, 101 + int(sz), R[1])
	var skirt: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.1, -0.05), Vector2(0.1, -0.16), Vector2(0.0, -0.14)]
	FoundKit.slab(k, Vector3(0.33, 0.0, 0), Vector3.RIGHT, Vector3.UP, skirt, 1.1, D, 0.01)
	body_mesh(k, deck)
	for sz: float in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(-0.08, WHEEL_R - 0.24, sz * 0.66)
		deck.add_child(w)
		var wk := FoundKit.kit()
		FoundKit.disc(wk, Vector3.ZERO, Vector3.BACK, WHEEL_R, 0.1, 8, 0.018, DD, D[2], PI / 8.0)
		FoundKit.spot(wk, Vector3(0, 0, sz * 0.051), Vector3.BACK * sz, 0.05, 6, R[4], 0.002)
		FoundKit.mark(wk, Vector3(0, 0.1, sz * 0.051), Vector3.BACK * sz, Vector3.UP, 0.03, 0.06, R[1], 0.003)
		body_mesh(wk, w)
		_wheels.append(w)
		# Side brushes turn in mirror at the front corners: a hub and a fan of bristles.
		var sb := Node3D.new()
		sb.position = Vector3(0.36, -0.2, sz * 0.52)
		deck.add_child(sb)
		var bk := FoundKit.kit()
		FoundKit.disc(bk, Vector3.ZERO, Vector3.UP, 0.07, 0.04, 6, 0.01, D)
		for j in 10:
			var a := float(j) / 10.0 * TAU
			FoundKit.tbar(bk, Vector3(cos(a), 0, sin(a)) * 0.05, Vector3(cos(a), -0.4, sin(a)) * 0.2 + Vector3(0, 0.05, 0), 0.01, 0.008, 3, [R[3], R[3], R[4], R[4], R[5], R[5]])
		body_mesh(bk, sb)
		_side.append(sb)
	_roller = Node3D.new()
	_roller.position = Vector3(0.24, -0.13, 0)
	deck.add_child(_roller)
	var rk := FoundKit.kit()
	FoundKit.disc(rk, Vector3.ZERO, Vector3.BACK, 0.1, 0.96, 8, 0.02, DD, D[1], PI / 8.0)
	for j in 8:
		var a := float(j) / 8.0 * TAU
		FoundKit.tbar(rk, Vector3(cos(a) * 0.1, sin(a) * 0.1, -0.44), Vector3(cos(a) * 0.1, sin(a) * 0.1, 0.44), 0.012, 0.012, 3, [R[3], R[3], R[4], R[4], R[5], R[5]])
	body_mesh(rk, _roller)

	var hopper := joint(&"hopper", deck, Vector3(-0.04, 0.06, 0))
	var hk := FoundKit.kit()
	# Tall and narrow at the foot, flaring to a lidded mouth: the upright of the T.
	var hp := FoundKit.plan_oct(0.42, 0.42, 0.12)
	FoundKit.loft(hk, [FoundKit.ring(hp, 0.0, 0.0, Vector2(0.72, 0.72)), FoundKit.ring(hp, 0.6, 0.0, Vector2(0.9, 0.9)), FoundKit.ring(hp, 0.86), FoundKit.ring(hp, 0.92, 0.04)], R, true)
	var lid := FoundKit.plan_oct(0.5, 0.5, 0.14)
	FoundKit.loft(hk, [FoundKit.ring(lid, 0.92, 0.0, Vector2.ONE, Vector2(0.02, 0)), FoundKit.ring(lid, 0.96, 0.0, Vector2.ONE, Vector2(0.02, 0)), FoundKit.ring(lid, 1.0, 0.06, Vector2.ONE, Vector2(0.02, 0))], R)
	FoundKit.visor(hk, Vector3(0.203, 0.72, 0), Vector3.RIGHT, Vector3.UP, 0.24, 0.035)
	FoundKit.streaks(hk, Vector3(0.203, 0.68, 0), Vector3.RIGHT, 0.2, 0.3, 4, 102, R[1])
	FoundKit.ticks(hk, Vector3(0.19, 0.12, 0.16), Vector3(0.19, 0.56, 0.16), Vector3(0.98, 0.1, 0.1).normalized(), 8, R[4], 0.024)
	for sz: float in [-1.0, 1.0]:
		FoundKit.seam(hk, Vector3(-0.06, 0.08, sz * 0.17), Vector3(-0.08, 0.8, sz * 0.2), Vector3(0, -0.08, sz).normalized(), R, 5)
	# The vent: louvres over the glow, rivets under.
	for j in 4:
		FoundKit.mark(hk, Vector3(-0.2, 0.36 + j * 0.07, 0), Vector3.LEFT, Vector3.UP, 0.24, 0.022, R[1], 0.014)
	FoundKit.rivets(hk, Vector3(-0.17, 0.22, -0.1), Vector3(-0.17, 0.22, 0.1), Vector3.LEFT, 3, R[5])
	body_mesh(hk, hopper)
	add_scan(hopper, Vector3(0.203, 0.72, 0), Vector3.RIGHT, Vector3.BACK, 0.18, 0.03, 2.2)
	var pk := FoundKit.kit()
	FoundKit.mark(pk, Vector3(-0.195, 0.47, 0), Vector3.LEFT, Vector3.UP, 0.28, 0.3, Palette.LENS[0], 0.003)
	FoundKit.mark(pk, Vector3(-0.195, 0.47, 0), Vector3.LEFT, Vector3.UP, 0.22, 0.24, Palette.LENS[2], 0.007)
	FoundKit.mark(pk, Vector3(-0.195, 0.47, 0), Vector3.LEFT, Vector3.UP, 0.1, 0.08, Palette.LENS[3], 0.01)
	part_mesh(pk, hopper)
	set_part_anchor(hopper, Vector3(-0.21, 0.47, 0), 0.6)

	# What it swept, only when the hopper has tipped: needles and grit, the land's.
	var spill := Node3D.new()
	add_child(spill)
	var sk := FoundKit.matter_kit(Ink.UPRIGHT)
	var grit: Array[Color] = [Palette.EARTH[2], Palette.EARTH[3], Palette.SPRUCE[2], Palette.EARTH[4]]
	for j in 24:
		var a := PI * (0.55 + Rng.hash01(111, j) * 0.9)
		var dist := 0.3 + Rng.hash01(112, j) * 0.7
		var base := Vector3(-0.35 + cos(a) * dist, 0.02, sin(a) * dist * 0.8)
		var tip := base + Vector3(cos(a * 3.0), 0.0, sin(a * 3.0)) * 0.12
		FoundKit.bar(sk, base, tip, 0.03, 0.025, 0.0, FoundKit.flat(grit[j % 4]))
	sk.rock(-0.72, 0.0, 0.05, 0.18, 0.1, 113, Palette.EARTH[2], 5)
	matter_mesh(sk, spill)
	dead_only(spill, LIGHT_FIRST + 0.6)
	finish_rig()


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"hopper"] = pr(Vector3(0.1, 0.34, 0), Vector3(0, 0, -0.36))
		&"windup":
			d[&"hopper"] = pr(Vector3(-0.04, 0.18, 0), Vector3(0, 0, 0.22))
		&"strike":
			d[&"hopper"] = pr(Vector3(0.18, 0.14, 0), Vector3(0, 0, -0.62))
			d[&"deck"] = pr(Vector3(0.1, 0, 0))
		&"dead":
			d[&"hopper"] = pr(Vector3(-0.32, -0.14, 0.06), Vector3(0.25, 0, 1.25))
			d[&"deck"] = pr(Vector3(0, -0.03, 0), Vector3(0.04, 0, 0))
	return d


func _gait_deltas(phase: float) -> Dictionary:
	return {&"deck": pr(Vector3(0, absf(sin(phase * TAU)) * 0.01, 0)), &"hopper": r(Vector3(sin(phase * TAU) * 0.02, 0, 0))}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	_travel += delta * maxf(speed_now, nominal_speed if pose == &"walk" else 0.0)
	_brush_t += delta
	for w in _wheels:
		w.rotation.z = -_travel / WHEEL_R
	_roller.rotation.z = -_brush_t * 9.0
	_side[0].rotation.y = _brush_t * 6.0
	_side[1].rotation.y = -_brush_t * 6.0
