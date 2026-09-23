extends MachineModel
## THE PLUMB: the Crags' keeper (docs/VISION.md §3, docs/LANDSCAPES.md §1,
## src/core/sentinel/designs/plumb.gd). A tripod seven units tall: three thin
## legs under a head with no lamp in it, and a plumb-weight on a chain hanging
## from the head down to a person's height. It is a survey instrument that never
## finished surveying, and it is still surveying.
##
## Why a TRIANGLE OVER A PENDULUM. The Coast's keeper is an arch and the flats'
## a delta on stilts, and no two sentinels may share a silhouette (VISION §3).
## This one is built out of what the crags do not have: a straight line. Every
## other shape on that landscape is fog, lichen and stone broken by hand, so
## three ruled legs meeting at a point read from across a valley as the one thing
## there that somebody drew with a ruler — and a weight hanging dead still under
## it is the only vertical in the frame. It is tall because a sighting
## instrument has to see over the crags, and thin because it was never built to
## fight: it was built to measure, and it is measuring you.
##
## It is drawn by a ruler: the head is one lofted octagon, each leg two straight
## members meeting at a collar, the spreaders are six exact rods, the weight is a
## turned bob. Its colour is the KEEPER's ramp (Palette: a machine's colour is
## its role). There is NO LAMP ON THE HEAD, on purpose: the crags are the one
## landscape with no machine light in it, and this keeper reads the ground with a
## slit and a scale, not an optic. Its plan strip is on the winch, at a person's
## height, where a player looking at the thing they can reach will see it.
##
## Poses. The legs and the weight are the whole vocabulary.
## walk   the legs step in turn, a third of a stride apart, and the weight lags
## stand  it has stopped over a station: the weight swings on its exact period
##        while it works, and hangs DEAD STILL the moment it has you (locked)
## alert  the legs plant wider and the head cants down to sight
## windup the weight swings out wide to one side, high
## strike it comes through in an arc: the sweep
## hurt   the chain judders; nothing else moves
## dead   the back leg buckles, the tripod goes over forwards and the head comes
##        down on the peat with the legs behind it and the weight thrown out to
##        one side at the end of its chain: an instrument lying in a bog
##
## lights the plan strip on the winch's end face and nothing else
## wear   peat up every leg from the point, a patch of another kind's plate on the
##        head, rain streaked down its front, lichen grown on its top: it has
##        stood in the fog longer than anything else the plan left
## weld   the legs and the bob are welded (MeshKit.smooth_range); the head and
##        the collars keep their facets, because a housing is panelled and a leg
##        is a tube

const HEAD_Y := 6.3
const HIP_R := 0.32
const HIP_DROP := 0.24
const FOOT_R := 2.3
## The chain from the sheave under the head to the bob's cap. The bob's point
## clears the ground by a hand.
const CHAIN := 5.0
const BOB := 0.9
## Where along a leg, hip to foot, the register and the winch sit: both at a
## person's height on a six-unit leg.
const REGISTER_AT := 0.8
const WINCH_AT := 0.73

var _t := 0.0


func build() -> void:
	part_side = &"back"
	height = 7.0
	stride = 2.6
	gallery_turn = 30.0
	# Same reason as the reaper's drum and the rake's gear: a big working part at
	# the default burns to white and the amber goes out of it (docs/ART.md §5).
	emission = 0.28
	begin_rig()
	ramp = Palette.MACHINE["warden"]
	disposition = &"wary"
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var head := joint(&"head", self, Vector3(0, HEAD_Y, 0))
	_head(head, R, D)
	_legs(head, R, D, DD)
	_pendulum(head, R, D, DD)
	finish_rig()


## One lofted octagon with a slit across its front and a scale under it: the
## sighting head. A sheave under it that the chain runs over, and a vernier ring
## on top. No optic, no beam: it sights by the slit.
func _head(head: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(0.84, 0.72, 0.16)
	FoundKit.loft(k, [FoundKit.ring(plan, -0.3, 0.07), FoundKit.ring(plan, -0.2), FoundKit.ring(plan, 0.12, 0.01), FoundKit.ring(plan, 0.2, 0.08)], R, true)
	FoundKit.visor(k, Vector3(0.421, 0.0, 0.0), Vector3.RIGHT, Vector3.UP, 0.44, 0.045)
	FoundKit.ticks(k, Vector3(0.421, -0.11, -0.2), Vector3(0.421, -0.11, 0.2), Vector3.RIGHT, 9, R[5])
	FoundKit.seam(k, Vector3(-0.36, 0.201, 0.0), Vector3(0.36, 0.201, 0.0), Vector3.UP, R, 4)
	FoundKit.panel(k, Vector3(0.0, 0.0, 0.361), Vector3.BACK, Vector3.UP, 0.5, 0.3, R)
	FoundKit.panel(k, Vector3(0.0, 0.0, -0.361), Vector3.FORWARD, Vector3.UP, 0.5, 0.3, R)
	FoundKit.rivets(k, Vector3(-0.3, 0.16, 0.362), Vector3(0.3, 0.16, 0.362), Vector3.BACK, 5, R[5])
	FoundKit.rivets(k, Vector3(-0.3, 0.16, -0.362), Vector3(0.3, 0.16, -0.362), Vector3.FORWARD, 5, R[5])
	# The vernier: the turned ring it sights by, on top where the sun finds it.
	FoundKit.disc(k, Vector3(0, 0.24, 0), Vector3.UP, 0.26, 0.06, 12, 0.012, D, Color(0, 0, 0, 0), PI / 12.0)
	FoundKit.ticks(k, Vector3(-0.2, 0.271, 0.0), Vector3(0.2, 0.271, 0.0), Vector3.UP, 9, R[5])
	# The sheave the chain hangs over, under the head's middle.
	FoundKit.disc(k, Vector3(0, -0.34, 0), Vector3.BACK, 0.16, 0.07, 10, 0.01, D)
	body_mesh(k, head)
	day_wear(head, Vector3(0.0, 0.203, 0.14), Vector3.UP, Vector3.RIGHT, 0.5, 0.28, 161, 1)
	var w := FoundKit.kit()
	FoundKit.patch(w, Vector3(-0.2, 0.202, -0.16), Vector3.UP, Vector3.RIGHT, 0.26, 0.2, Palette.MACHINE["lineman"], 162)
	FoundKit.streaks(w, Vector3(0.421, 0.12, 0.1), Vector3.RIGHT, 0.3, 0.3, 4, 163, R[1])
	FoundKit.streaks(w, Vector3(-0.421, 0.12, 0.0), Vector3.LEFT, 0.3, 0.3, 3, 164, R[1])
	FoundKit.scorch(w, Vector3(0.0, 0.1, 0.362), Vector3.BACK, 0.09, 165)
	wear_mesh(w, head)
	# Lichen on the top of the head: it has stood in the wet longer than anything
	# else the plan left here, and the crags grow on whatever stands still.
	var m := FoundKit.matter_kit(Ink.HAND)
	m.rock(0.12, 0.2, -0.2, 0.09, 0.05, 471, Palette.MOSS[2], 5)
	m.rock(-0.24, 0.2, 0.14, 0.11, 0.06, 472, Palette.MOSS[2].lerp(Palette.STONE[3], 0.4), 5)
	m.rock(0.26, 0.2, 0.2, 0.07, 0.04, 473, Palette.MOSS[3], 5)
	wear_matter(m, head)


## Three legs, each two straight members meeting at a collar and ending in a
## POINT, which is why the peat takes it. The register that counts its bores is
## on the back leg at a person's height (the working part while it sights); the
## winch that hauls the weight is on the left leg (the working part while it
## plumbs). Six exact rods spread the knees.
func _legs(head: Node3D, R: Array, D: Array, DD: Array) -> void:
	# Back, right (+Z), left (-Z): the model faces +X.
	var specs := [[PI, &"leg_b"], [PI / 3.0, &"leg_r"], [-PI / 3.0, &"leg_l"]]
	var hips: Array[Vector3] = []
	var knees: Array[Vector3] = []
	var feet: Array[Vector3] = []
	for spec: Array in specs:
		var a: float = spec[0]
		var dir := Vector3(cos(a), 0.0, sin(a))
		var hip := Vector3(0, HEAD_Y - HIP_DROP, 0) + dir * HIP_R
		var foot := dir * FOOT_R
		hips.append(hip)
		feet.append(foot)
		knees.append(hip.lerp(foot, 0.52) + dir * 0.12)
	var peat: Array = [Palette.EARTH[1], Palette.EARTH[2], Palette.SPRUCE[1], Palette.EARTH[1], Palette.EARTH[2], Palette.EARTH[1]]
	for i in specs.size():
		var jn: StringName = specs[i][1]
		var hip := hips[i]
		var leg := joint(jn, head, hip - Vector3(0, HEAD_Y, 0))
		var knee := knees[i] - hip
		var foot := feet[i] - hip
		var out := Vector3(feet[i].x, 0.0, feet[i].z).normalized()
		var k := FoundKit.kit()
		# The two members, welded into tubes: a six-sided bar's facets meet at
		# sixty degrees, over the default crease, so left alone every leg reads
		# as a hexagonal pencil under the sun.
		var s0 := k.vertex_count()
		FoundKit.tbar(k, Vector3.ZERO, knee, 0.09, 0.075, 6, R)
		FoundKit.tbar(k, knee, foot, 0.075, 0.028, 6, D)
		k.smooth_range(s0, k.vertex_count(), 70.0)
		# The collar at the knee keeps its facets: it is a fitting, not a limb.
		FoundKit.lathe(k, knee, foot - knee, [Vector2(0.1, -0.08), Vector2(0.115, 0.0), Vector2(0.115, 0.14), Vector2(0.095, 0.2)], 6, DD, PI / 6.0)
		# The hip fitting where the leg meets the head.
		FoundKit.lathe(k, Vector3.ZERO, knee, [Vector2(0.11, -0.06), Vector2(0.125, 0.0), Vector2(0.125, 0.16), Vector2(0.1, 0.22)], 6, DD, PI / 6.0)
		# Half a spreader toward each neighbour's knee: they meet in the middle
		# while it stands and come apart when it does not.
		for j in specs.size():
			if j == i:
				continue
			var mid := knees[i].lerp(knees[j], 0.5) - hip
			FoundKit.tbar(k, knee, mid, 0.035, 0.03, 4, DD)
		if jn == &"leg_l":
			_winch(k, leg, hip.lerp(feet[i], WINCH_AT) - hip, out, R, D, DD)
		body_mesh(k, leg)
		if jn == &"leg_b":
			_register(leg, hip.lerp(feet[i], REGISTER_AT) - hip, out, R, D)
		# Peat caked up from the point: the crags' own signature on a thing that
		# stands in their bottoms.
		var w := FoundKit.kit()
		FoundKit.grime(w, knee.lerp(foot, 0.55), out, 0.16, 0.9, 4, 171 + i * 7, peat)
		FoundKit.grime(w, knee.lerp(foot, 0.7), out.cross(Vector3.UP).normalized(), 0.12, 0.7, 3, 172 + i * 7, peat)
		wear_mesh(w, leg)


## The winch: a drum across the left leg with a crank on its end, and the chain
## running up the leg from it to the head. Its end face carries the plan strip.
func _winch(k: MeshKit, leg: Node3D, at: Vector3, out: Vector3, R: Array, D: Array, DD: Array) -> void:
	FoundKit.lathe(k, at, out, [Vector2(0.12, 0.0), Vector2(0.17, 0.05), Vector2(0.17, 0.3), Vector2(0.12, 0.36)], 8, D, PI / 8.0)
	FoundKit.tbar(k, at + out * 0.37, at + out * 0.37 + Vector3(0.22, 0.06, 0.0), 0.024, 0.02, 4, DD)
	FoundKit.tbar(k, at + out * 0.37 + Vector3(0.22, 0.06, 0.0), at + out * 0.37 + Vector3(0.22, 0.06, 0.0) + out * 0.1, 0.02, 0.02, 4, DD)
	# The chain from the drum up to the head, outside the leg.
	FoundKit.tbar(k, at + out * 0.18 + Vector3(0.06, 0.1, 0.0), out * 0.16 + Vector3(0.04, -0.1, 0.0), 0.024, 0.024, 6, FoundKit.flat(Palette.INK[2]))
	# The one lamp on the whole machine, at a person's height on the thing a
	# player is meant to reach: what the plan thinks of you, counted.
	add_lamp(leg, at + out * 0.362, out, Vector3.UP, 0.05, 0.05, &"status")


## The register: the drum on the back leg that tallies bores it has cut, and the
## working part while it sights. Amber, and turning while it works.
func _register(leg: Node3D, at: Vector3, out: Vector3, R: Array, D: Array) -> void:
	var bk := FoundKit.kit()
	FoundKit.tbar(bk, at, at + out * 0.18, 0.04, 0.04, 4, D)
	body_mesh(bk, leg)
	var reg := joint(&"register", leg, at + out * 0.3)
	var gk := FoundKit.kit()
	var barrel: Array = [Palette.LENS[0], Palette.LENS[0], Palette.LENS[1], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2]]
	var amber: Array = [Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3], Palette.LENS[3]]
	FoundKit.lathe(gk, Vector3.ZERO, Vector3.BACK, [Vector2(0.13, -0.17), Vector2(0.19, -0.12), Vector2(0.19, 0.12), Vector2(0.13, 0.17)], 10, barrel, PI / 10.0)
	for j in 10:
		var a := j * TAU / 10.0
		var n := Vector3(cos(a), sin(a), 0.0)
		FoundKit.mark(gk, n * 0.19, n, Vector3.BACK, 0.05, 0.16, amber[3], 0.004)
	part_mesh(gk, reg)
	set_part_anchor(leg, at + out * 0.3, 0.9)


## The pendulum: a chain from the sheave down to a turned bob whose point clears
## the ground by a hand. The chain is drawn from the bob UP, past the sheave and
## into the head, so no pose ever shows its end.
func _pendulum(head: Node3D, R: Array, D: Array, DD: Array) -> void:
	var pend := joint(&"pend", head, Vector3(0, -0.34, 0))
	var weight := joint(&"weight", pend, Vector3(0, -CHAIN, 0))
	var wk := FoundKit.kit()
	var ink := FoundKit.flat(Palette.INK[2])
	FoundKit.tbar(wk, Vector3.ZERO, Vector3(0, CHAIN + 0.5, 0), 0.026, 0.026, 6, ink)
	for i in 9:
		FoundKit.disc(wk, Vector3(0, 0.45 + i * 0.5, 0), Vector3.UP, 0.055, 0.03, 6, 0.0, DD)
	# The bob, welded: a turned mass and not a gem. Forty degrees keeps the neck
	# and the shoulder hard while the ten-sided body rounds.
	var s0 := wk.vertex_count()
	FoundKit.lathe(wk, Vector3.ZERO, Vector3.UP, [Vector2(0.03, -BOB), Vector2(0.3, -0.5), Vector2(0.3, -0.3), Vector2(0.17, -0.2), Vector2(0.17, -0.04), Vector2(0.08, 0.0)], 10, R, PI / 10.0)
	wk.smooth_range(s0, wk.vertex_count(), 40.0)
	FoundKit.rivets(wk, Vector3(0.3, -0.4, -0.1), Vector3(0.3, -0.4, 0.1), Vector3.RIGHT, 3, R[5])
	body_mesh(wk, weight)
	var w := FoundKit.kit()
	FoundKit.streaks(w, Vector3(0.3, -0.3, 0.0), Vector3.RIGHT, 0.2, 0.3, 3, 181, R[1])
	FoundKit.patch(w, Vector3(-0.3, -0.4, 0.0), Vector3.LEFT, Vector3.UP, 0.16, 0.12, Palette.MACHINE["hauler"], 182)
	wear_mesh(w, weight)


## Everything is said with the legs and the weight. The pendulum's own swing
## rides on `pend`'s Z in `_routine`; the poses use its X, so the two never fight.
func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			# The legs plant wider and the head comes down a little to sight.
			d[&"head"] = pr(Vector3(0.0, -0.16, 0.0), Vector3(0.0, 0.0, -0.05))
			d[&"leg_b"] = r(Vector3(0.0, 0.0, -0.07))
			d[&"leg_r"] = r(Vector3(-0.09, 0.0, 0.0))
			d[&"leg_l"] = r(Vector3(0.09, 0.0, 0.0))
		&"windup":
			# The weight goes out wide to the left and high: the tell is the whole
			# pendulum, three units of it, and there is nothing slower in the game.
			d[&"pend"] = r(Vector3(0.75, 0.0, 0.0))
			d[&"head"] = pr(Vector3(0.0, -0.1, 0.0), Vector3(0.06, 0.0, 0.0))
			d[&"leg_r"] = r(Vector3(-0.12, 0.0, 0.0))
		&"strike":
			# And comes through: the sweep.
			d[&"pend"] = r(Vector3(-0.6, 0.0, 0.0))
			d[&"head"] = r(Vector3(-0.05, 0.0, 0.0))
		&"hurt":
			d[&"pend"] = r(Vector3(0.1, 0.0, 0.0))
			d[&"weight"] = r(Vector3(0.0, 0.0, 0.12))
		&"dead":
			# The back leg buckles and the tripod goes over forwards: the head
			# comes down on the peat with the legs lying behind it and the weight
			# thrown out to one side at the end of its chain.
			d[&"head"] = pr(Vector3(2.0, -5.85, 0.25), Vector3(0.15, 0.0, -1.5))
			d[&"leg_b"] = r(Vector3(0.0, 0.0, 0.9))
			d[&"leg_r"] = r(Vector3(-0.55, 0.0, 0.1))
			d[&"leg_l"] = r(Vector3(0.5, 0.0, 0.1))
			d[&"pend"] = r(Vector3(0.9, 0.0, 0.0))
			d[&"weight"] = r(Vector3(0.4, 0.0, 0.0))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead":
		if j == &"leg_b":
			return Vector2(LIGHT_FIRST, 0.4)
		if j == &"head" or j == &"pend" or j == &"weight":
			return Vector2(LIGHT_FIRST + 0.25, 0.9)
	return super(p, j)


## A tripod's gait: each leg a third of a stride behind the one before it, so
## there are always two on the ground. The weight lags the head.
func _gait_deltas(phase: float) -> Dictionary:
	var a := sin(phase * TAU)
	var b := sin(phase * TAU + TAU / 3.0)
	var c := sin(phase * TAU + 2.0 * TAU / 3.0)
	return {
		&"leg_b": r(Vector3(0.0, 0.0, a * 0.12)),
		&"leg_r": r(Vector3(0.0, 0.0, b * 0.12)),
		&"leg_l": r(Vector3(0.0, 0.0, c * 0.12)),
		&"head": pr(Vector3(0.0, (absf(a) + absf(b) + absf(c)) * 0.02, 0.0)),
		&"pend": r(Vector3(-a * 0.05, 0.0, 0.0)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	_t += delta
	# The weight swings on its own exact period while it works, and hangs dead
	# still the moment it has the player: a plumb is a thing that stops.
	var pend := joints[&"pend"] as Node3D
	pend.rotation.z = 0.0 if locked() else sin(_t * 0.8) * 0.16
	(joints[&"register"] as Node3D).rotation.z = _t * 1.4
