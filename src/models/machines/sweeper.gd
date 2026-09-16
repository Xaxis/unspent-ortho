extends MachineModel
## A sweeper: a T. A low wide deck with a tall hopper standing over the middle,
## the only silhouette with a corner. It goes along the tracks in the early
## morning behind the wardens, brushes turning, and comes over you, not after
## you. The vent on the back of the hopper glows: the working part.
##
## alert  the hopper lifts on its ram and leans out over the front
## dead   the hopper tips off backwards and what it swept spills out
##
## lights work lamps low on the deck's leading edge, one over the vent that
##        goes hot through a windup, a status lamp on the lid blinking once
## wear   a bone and a stick jutting out from under the lid, needles and grit
##        wound into the roller, a rag caught on the skirt,
##        a plate off another machine on the hopper, grime run down from the
##        lid, a cable spliced up the hopper seam

const WHEEL_R := 0.17
const DECK_Y := 0.22
## The crossbar: short along the way it travels, wide across it.
const DECK_L := 0.42
const DECK_W := 1.56
const WHEEL_Z := 0.86
## The upright: a narrow hopper about a quarter of the deck's width.
const HOP_W := 0.36
const HOP_H := 1.02
const VENT_Y := 0.5
const VENT_H := 0.5

var _travel := 0.0
var _brush_t := 0.0
var _wheels: Array[Node3D] = []
var _roller: Node3D
var _side: Array[Node3D] = []


func build() -> void:
	part_side = &"back"
	height = 1.42
	stride = 1.0
	# Deck across the screen, vent three-quarters on: the T at its plainest.
	gallery_turn = 25.0
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)
	var pale: Array = [R[3], R[3], R[4], R[4], R[5], R[5]]

	# The crossbar: a deck much wider across than it is long, thin, on a wheel at
	# each end, brushes under its leading edge.
	var deck := joint(&"deck", self, Vector3(0, DECK_Y, 0))
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(DECK_L, DECK_W, 0.12)
	FoundKit.loft(k, [FoundKit.ring(plan, -0.06, 0.03), FoundKit.ring(plan, -0.035), FoundKit.ring(plan, 0.035), FoundKit.ring(plan, 0.06, 0.03)], R, true, true)
	for sz: float in [-1.0, 1.0]:
		# Mudguard over each wheel, a seam and rivets along the deck, streaks off the ends.
		var guard: Array[Vector2] = [Vector2(-0.24, 0.0), Vector2(-0.17, 0.1), Vector2(0.17, 0.1), Vector2(0.24, 0.0)]
		FoundKit.slab(k, Vector3(0, 0.04, sz * WHEEL_Z), Vector3.RIGHT, Vector3.UP, guard, 0.16, R, 0.015)
		FoundKit.seam(k, Vector3(0.0, 0.061, sz * 0.24), Vector3(0.0, 0.061, sz * 0.62), Vector3.UP, R, 3)
		FoundKit.streaks(k, Vector3(0.0, 0.02, sz * (DECK_W * 0.5 + 0.001)), Vector3.BACK * sz, 0.26, 0.05, 3, 101 + int(sz), R[1])
	FoundKit.rivets(k, Vector3(-0.211, 0.0, -0.6), Vector3(-0.211, 0.0, 0.6), Vector3.LEFT, 9, R[5])
	# The collar the hopper stands in, and the skirt across the front.
	FoundKit.disc(k, Vector3(0, 0.08, 0), Vector3.UP, 0.2, 0.05, 8, 0.015, D, Color(0, 0, 0, 0), PI / 8.0)
	var skirt: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.07, -0.04), Vector2(0.07, -0.13), Vector2(0.0, -0.11)]
	FoundKit.slab(k, Vector3(DECK_L * 0.5 - 0.02, 0.0, 0), Vector3.RIGHT, Vector3.UP, skirt, DECK_W - 0.3, D, 0.01)
	# Two rams that lift the hopper, hidden inside it until it rises.
	for sz: float in [-1.0, 1.0]:
		FoundKit.tbar(k, Vector3(0, 0.08, sz * 0.07), Vector3(0, 0.62, sz * 0.07), 0.026, 0.026, 6, D)
	body_mesh(k, deck)
	for sz: float in [-1.0, 1.0]:
		add_lamp(deck, Vector3(0.212, 0.0, sz * 0.46), Vector3.RIGHT, Vector3.UP, 0.07, 0.035, &"work")
	add_beam(deck, Vector3(0.3, -0.04, 0), Vector3(1.2, -0.18, 0), 1.3, 2.0, &"work")
	var dw := FoundKit.kit()
	FoundKit.dirt_line(dw, Vector3(0.212, -0.03, -0.66), Vector3(0.212, -0.03, 0.66), Vector3.RIGHT, 0.02, R[0])
	FoundKit.scorch(dw, Vector3(-0.1, 0.061, -0.5), Vector3.UP, 0.07, 71)
	wear_mesh(dw, deck)
	var rag := FoundKit.matter_kit(Ink.HAND)
	FoundKit.rag(rag, Vector3(DECK_L * 0.5 + 0.05, -0.06, 0.3), 0.1, 0.1, Palette.EARTH[2], 72, Vector3(0.1, 0, 1))
	wear_matter(rag, deck)
	for sz: float in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(0.0, WHEEL_R - DECK_Y, sz * WHEEL_Z)
		deck.add_child(w)
		var wk := FoundKit.kit()
		FoundKit.disc(wk, Vector3.ZERO, Vector3.BACK, WHEEL_R, 0.11, 8, 0.02, DD, D[2], PI / 8.0)
		FoundKit.spot(wk, Vector3(0, 0, sz * 0.056), Vector3.BACK * sz, 0.055, 6, R[4], 0.002)
		FoundKit.mark(wk, Vector3(0, 0.11, sz * 0.056), Vector3.BACK * sz, Vector3.UP, 0.03, 0.07, R[1], 0.003)
		body_mesh(wk, w)
		_wheels.append(w)
		# Side brushes turn in mirror at the front corners: a hub and a fan of bristles.
		var sb := Node3D.new()
		sb.position = Vector3(0.2, -0.13, sz * 0.62)
		deck.add_child(sb)
		var bk := FoundKit.kit()
		FoundKit.disc(bk, Vector3.ZERO, Vector3.UP, 0.06, 0.04, 6, 0.01, D)
		for j in 10:
			var a := float(j) / 10.0 * TAU
			FoundKit.tbar(bk, Vector3(cos(a), 0, sin(a)) * 0.045, Vector3(cos(a) * 0.2, -0.08, sin(a) * 0.2), 0.01, 0.008, 3, pale)
		body_mesh(bk, sb)
		_side.append(sb)
	_roller = Node3D.new()
	_roller.position = Vector3(0.17, -0.12, 0)
	deck.add_child(_roller)
	var rk := FoundKit.kit()
	FoundKit.disc(rk, Vector3.ZERO, Vector3.BACK, 0.08, DECK_W - 0.5, 8, 0.02, DD, D[1], PI / 8.0)
	for j in 8:
		var a := float(j) / 8.0 * TAU
		FoundKit.tbar(rk, Vector3(cos(a) * 0.08, sin(a) * 0.08, -(DECK_W - 0.56) * 0.5), Vector3(cos(a) * 0.08, sin(a) * 0.08, (DECK_W - 0.56) * 0.5), 0.011, 0.011, 3, pale)
	body_mesh(rk, _roller)
	# What the bristles could not let go of.
	var clog := FoundKit.matter_kit(Ink.UPRIGHT)
	FoundKit.chaff(clog, Vector3.ZERO, Vector3(0.07, 0.07, 0.45), 12, 73, [Palette.EARTH[2], Palette.SPRUCE[2], Palette.EARTH[3]])
	wear_matter(clog, _roller)

	# The upright: a tall narrow hopper standing out of the collar, a lidded mouth
	# on top, the vent down its back.
	var hopper := joint(&"hopper", deck, Vector3(0, 0.09, 0))
	var hk := FoundKit.kit()
	var hp := FoundKit.plan_oct(HOP_W, HOP_W, 0.09)
	FoundKit.loft(hk, [FoundKit.ring(hp, 0.0, 0.0, Vector2(0.78, 0.78)), FoundKit.ring(hp, 0.1, 0.0, Vector2(0.78, 0.78)), FoundKit.ring(hp, 0.16), FoundKit.ring(hp, HOP_H - 0.06), FoundKit.ring(hp, HOP_H, 0.03)], R, false, true)
	var lid := FoundKit.plan_oct(HOP_W + 0.1, HOP_W + 0.1, 0.12)
	FoundKit.loft(hk, [FoundKit.ring(lid, HOP_H, 0.0, Vector2.ONE, Vector2(0.03, 0)), FoundKit.ring(lid, HOP_H + 0.04, 0.0, Vector2.ONE, Vector2(0.03, 0)), FoundKit.ring(lid, HOP_H + 0.08, 0.05, Vector2.ONE, Vector2(0.03, 0))], R, true)
	var face := HOP_W * 0.5 + 0.001
	FoundKit.visor(hk, Vector3(face, HOP_H - 0.2, 0), Vector3.RIGHT, Vector3.UP, 0.22, 0.035)
	FoundKit.streaks(hk, Vector3(face, HOP_H - 0.24, 0), Vector3.RIGHT, 0.2, 0.3, 4, 102, R[1])
	FoundKit.ticks(hk, Vector3(face, 0.24, 0.12), Vector3(face, 0.64, 0.12), Vector3.RIGHT, 8, R[4], 0.024)
	for sz: float in [-1.0, 1.0]:
		FoundKit.seam(hk, Vector3(0.0, 0.2, sz * face), Vector3(0.0, HOP_H - 0.1, sz * face), Vector3.BACK * sz, R, 5)
	FoundKit.rivets(hk, Vector3(-face, 0.2, -0.1), Vector3(-face, 0.2, 0.1), Vector3.LEFT, 3, R[5])
	body_mesh(hk, hopper)
	# The hopper lid: the one big flat thing on it, and the one the sun finds.
	day_wear(hopper, Vector3(0.03, 1.106, 0), Vector3.UP, Vector3.RIGHT, 0.34, 0.34, 130, 1)
	add_scan(hopper, Vector3(face, HOP_H - 0.2, 0), Vector3.RIGHT, Vector3.BACK, 0.16, 0.03, 2.2)
	add_lamp(hopper, Vector3(0.03, HOP_H + 0.081, 0.1), Vector3.UP, Vector3.RIGHT, 0.045, 0.045, &"status")
	add_lamp(hopper, Vector3(-face - 0.002, VENT_Y + VENT_H * 0.5 + 0.1, 0), Vector3.LEFT, Vector3.UP, 0.12, 0.035, &"work", true)
	var hw := FoundKit.kit()
	FoundKit.patch(hw, Vector3(0.02, 0.44, face + 0.001), Vector3.BACK, Vector3.UP, 0.18, 0.22, Palette.MACHINE["dredger"], 74)
	FoundKit.grime(hw, Vector3(0.0, HOP_H - 0.02, -face - 0.001), Vector3.FORWARD, 0.26, 0.4, 5, 75, D)
	FoundKit.cable(hw, Vector3(0.1, HOP_H - 0.1, -face - 0.015), Vector3(0.1, 0.2, -face - 0.015), 0.0, 0.013, Palette.INK[2], Palette.MACHINE["watcher"], 4)
	wear_mesh(hw, hopper)
	# What it swept up and could not swallow: a long bone out from under the lid.
	var swept := FoundKit.matter_kit(Ink.HAND)
	FoundKit.bone(swept, Vector3(-0.08, HOP_H + 0.02, -0.06), Vector3(0.14, HOP_H + 0.12, 0.44), 0.052, 76)
	swept.strut(Vector3(0.06, HOP_H + 0.04, -0.1), Vector3(-0.12, HOP_H + 0.1, -0.4), 0.026, 4, Palette.EARTH[3])
	wear_matter(swept, hopper)
	# The vent: a tall amber grille down the back, louvres ruled across it.
	var pk := FoundKit.kit()
	var vc := Vector3(-face - 0.002, VENT_Y, 0)
	FoundKit.mark(pk, vc, Vector3.LEFT, Vector3.UP, HOP_W - 0.06, VENT_H + 0.06, Palette.LENS[0], 0.003)
	FoundKit.mark(pk, vc, Vector3.LEFT, Vector3.UP, HOP_W - 0.1, VENT_H, Palette.LENS[2], 0.007)
	FoundKit.mark(pk, vc, Vector3.LEFT, Vector3.UP, HOP_W - 0.18, VENT_H * 0.5, Palette.LENS[3], 0.01)
	part_mesh(pk, hopper)
	var lk := FoundKit.kit()
	for j in 5:
		FoundKit.mark(lk, vc + Vector3(0, (j - 2) * VENT_H / 5.0, 0), Vector3.LEFT, Vector3.UP, HOP_W - 0.08, 0.02, R[1], 0.014)
	body_mesh(lk, hopper)
	set_part_anchor(hopper, vc + Vector3(-0.01, 0, 0), 0.7)

	# What it swept, only when the hopper has tipped: needles and grit, the land's.
	var spill := Node3D.new()
	add_child(spill)
	var sk := FoundKit.matter_kit(Ink.UPRIGHT)
	var grit: Array[Color] = [Palette.EARTH[2], Palette.EARTH[3], Palette.SPRUCE[2], Palette.EARTH[4]]
	for j in 24:
		var a := PI * (0.6 + Rng.hash01(111, j) * 0.8)
		var dist := 0.3 + Rng.hash01(112, j) * 0.6
		var base := Vector3(-0.9 + cos(a) * dist * 0.6, 0.02, sin(a) * dist * 0.9)
		var tip := base + Vector3(cos(a * 3.0), 0.0, sin(a * 3.0)) * 0.12
		FoundKit.bar(sk, base, tip, 0.03, 0.025, 0.0, FoundKit.flat(grit[j % 4]))
	sk.rock(-1.25, 0.0, 0.05, 0.16, 0.09, 113, Palette.EARTH[2], 5)
	matter_mesh(sk, spill)
	dead_only(spill, LIGHT_FIRST + 0.6)
	finish_rig()


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			# Up on its rams and leaning out over you: comes over you, not after you.
			d[&"hopper"] = pr(Vector3(0.05, 0.42, 0), Vector3(0, 0, -0.22))
		&"windup":
			d[&"hopper"] = pr(Vector3(-0.04, 0.22, 0), Vector3(0, 0, 0.24))
		&"strike":
			d[&"hopper"] = pr(Vector3(0.14, 0.2, 0), Vector3(0, 0, -0.6))
			d[&"deck"] = pr(Vector3(0.1, 0, 0))
		&"dead":
			# The hopper goes off the back and lies behind the deck, spilling.
			d[&"hopper"] = pr(Vector3(-0.24, -0.1, 0.04), Vector3(0.18, 0, 1.42))
			d[&"deck"] = pr(Vector3(0, 0.01, 0), Vector3(0.035, 0, 0))
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
