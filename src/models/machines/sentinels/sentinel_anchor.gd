extends MachineModel
## THE ANCHOR: the Mesas' keeper (docs/VISION.md §3, docs/LANDSCAPES.md §6,
## src/core/sentinel/designs/anchor.gd). A four-limbed climber that drives the
## ropeway's bolts into the scarps and keeps them driven: a long low carapace
## slung between four high-kneed legs, each ending in a grapnel of three hooked
## tines, and behind it a long counterweight tail that rises over its back and
## ends in a cast weight. It is built to hang off a wall, so on flat ground it
## stands like something that would rather not.
##
## Why a SPIDER WITH A PENDULUM FOR A TAIL. The Coast's keeper is an arch, the
## flats' a delta on stilts, the crags' a triangle over a pendulum, the city's a
## doorway. Every one of them STANDS; this one CLINGS, so its silhouette is the
## only one in the game whose knees are higher than its back — four peaks and a
## hook over them, read from across a canyon as a thing crouched on the rock and
## not a thing standing on it. The tail is what it balances on a wall with, so it
## is always up, and the weight at its end is the one heavy thing on a thin body.
## The mesas are banded and horizontal; this is angular and vertical, and it sits
## on the strata like a tick on a hide.
##
## Its colour is the KEEPER's ramp (Palette: a machine's colour is its role), and
## the red dust of the place is caked up every leg from the hooks, because it has
## walked nothing but scarp for longer than the ropeway has been strung.
##
## Poses. The legs, the body's height and the tail are the whole vocabulary.
## walk   diagonal pairs step together, the body rides level, the weight lags
## stand  it hangs its weight and lets it swing, slowly, on its own period
## alert  the body drops toward the rock and the tail comes up: it is braced
## windup the tail swings forward over its back and the front rears: the
##        counterweight thrown before it lets go of the wall
## strike the body comes down nose first and the tail slams back: the drop
## hurt   the carapace judders on its legs
## dead   the body goes down flat, the legs fold up over it the way a dead spider
##        curls, and the tail comes down behind with the weight in the dust
##
## lights the plan strip on the head's face, and the amber rings of the bolt
##        driver on its back (the working part while it bolts)
## wear   red dust from the hooks to the knees, sun-bleached plate on its back,
##        a patch of another kind's plate on the carapace, a scorch where the
##        driver fires
## weld   the legs and the tail are welded (MeshKit.smooth_range): a limb is a
##        tube; the carapace, the head and the fittings keep their facets,
##        because a housing is panelled

const BODY_Y := 1.7
## Hips on the carapace's flanks, in the body's frame.
const HIP_X := 0.72
const HIP_Z := 0.46
## Where each foot comes to ground, in the model's frame: splayed wide, because
## what holds it on a wall is how far apart its hooks are.
const FOOT_X := 1.55
const FOOT_Z := 1.95
## How high a knee stands over its hip: the peaks that make the silhouette.
const KNEE_UP := 1.05
## The tail's spine in the tail joint's frame, from the root up to the weight.
## It rises nearly STRAIGHT and hooks forward at the top, because the play
## camera looks down at 57 degrees: a boom raked back at sixty points along the
## view whenever the body faces away and draws as a dot under its own weight
## (the first frame of it did exactly that).
const TAIL: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(-0.48, 0.5, 0.0), Vector3(-0.74, 1.2, 0.0),
	Vector3(-0.76, 1.96, 0.0), Vector3(-0.56, 2.58, 0.0)]
const WEIGHT_R := 0.36

var _t := 0.0


func build() -> void:
	part_side = &"back"
	height = 4.6
	stride = 2.2
	gallery_turn = 30.0
	# A big working part at the default burns to white and the amber goes out of
	# it (docs/ART.md §5), the same reason every keeper turns this down.
	emission = 0.28
	begin_rig()
	ramp = Palette.MACHINE["warden"]
	disposition = &"wary"
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var body := joint(&"body", self, Vector3(0, BODY_Y, 0))
	_carapace(body, R, D, DD)
	_head(body, R, D)
	_legs(body, R, D, DD)
	_tail(body, R, D, DD)
	_driver(body, R, D, DD)
	finish_rig()


## The carapace: one long lofted octagon, narrow at the keel and flat on top,
## with a spine seam down it, a sheave arm standing off its shoulders (what it
## rides the cable by) and plate panels down each flank.
func _carapace(body: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(2.1, 0.96, 0.26)
	FoundKit.loft(k, [FoundKit.ring(plan, -0.34, 0.2), FoundKit.ring(plan, -0.16), FoundKit.ring(plan, 0.18, 0.02),
		FoundKit.ring(plan, 0.32, 0.14)], R, true, true)
	FoundKit.seam(k, Vector3(-0.8, 0.321, 0.0), Vector3(0.8, 0.321, 0.0), Vector3.UP, R, 6)
	for sz: float in [-1.0, 1.0]:
		var n := Vector3(0, 0, sz)
		for x: float in [-0.5, 0.05, 0.55]:
			FoundKit.panel(k, Vector3(x, 0.0, sz * 0.481), n, Vector3.UP, 0.4, 0.26, R)
		FoundKit.rivets(k, Vector3(-0.8, 0.13, sz * 0.482), Vector3(0.8, 0.13, sz * 0.482), n, 7, R[5])
	# The sheave arm: a short mast off the shoulders with a grooved wheel at its
	# head and a hook under it, what it hangs off a cable by when it swings.
	var mast_a := Vector3(0.35, 0.3, 0.0)
	var mast_b := Vector3(0.55, 1.02, 0.0)
	var s0 := k.vertex_count()
	FoundKit.tbar(k, mast_a, mast_b, 0.07, 0.05, 6, D)
	k.smooth_range(s0, k.vertex_count(), 70.0)
	FoundKit.disc(k, mast_b + Vector3(0.0, 0.12, 0.0), Vector3.BACK, 0.2, 0.08, 12, 0.012, D, DD[2], PI / 12.0)
	FoundKit.disc(k, mast_b + Vector3(0.0, 0.12, 0.0), Vector3.BACK, 0.09, 0.12, 8, 0.0, DD)
	FoundKit.tbar(k, mast_b + Vector3(0.0, 0.12, 0.0), mast_b + Vector3(0.16, 0.3, 0.0), 0.03, 0.022, 4, DD)
	FoundKit.tbar(k, mast_b + Vector3(0.16, 0.3, 0.0), mast_b + Vector3(0.3, 0.22, 0.0), 0.022, 0.016, 4, DD)
	body_mesh(k, body)
	day_wear(body, Vector3(-0.2, 0.322, 0.0), Vector3.UP, Vector3.RIGHT, 1.1, 0.42, 211, 2)
	var w := FoundKit.kit()
	FoundKit.patch(w, Vector3(0.3, 0.322, 0.16), Vector3.UP, Vector3.RIGHT, 0.34, 0.22, Palette.MACHINE["cutter"], 212)
	FoundKit.streaks(w, Vector3(0.4, 0.1, 0.482), Vector3.BACK, 0.5, 0.3, 4, 213, R[1])
	FoundKit.streaks(w, Vector3(-0.3, 0.1, -0.482), Vector3.FORWARD, 0.5, 0.3, 4, 214, R[1])
	# The mesa's own dust banked along the keel: it lies down on a wall to rest.
	var dust: Array = _dust()
	FoundKit.grime(w, Vector3(0.0, -0.18, 0.47), Vector3.BACK, 1.4, 0.18, 5, 215, dust)
	FoundKit.grime(w, Vector3(0.0, -0.18, -0.47), Vector3.FORWARD, 1.4, 0.18, 5, 216, dust)
	wear_mesh(w, body)


## The mesas' red dust, as a ramp for the wear.
static func _dust() -> Array:
	return [Palette.RUST[1], Palette.RUST[2], Palette.EARTH[2], Palette.RUST[2], Palette.RUST[3], Palette.SAND[3]]


## The head: a low wedge on the carapace's nose with a sighting slit across its
## face and the plan strip under it, where a player facing it reads what it
## thinks of them.
func _head(body: Node3D, R: Array, D: Array) -> void:
	var head := joint(&"head", body, Vector3(1.12, 0.02, 0.0))
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(0.52, 0.62, 0.14)
	FoundKit.loft(k, [FoundKit.ring(plan, -0.24, 0.08), FoundKit.ring(plan, -0.12), FoundKit.ring(plan, 0.14, 0.02),
		FoundKit.ring(plan, 0.22, 0.12)], R, true, true)
	FoundKit.visor(k, Vector3(0.261, 0.05, 0.0), Vector3.RIGHT, Vector3.UP, 0.4, 0.045)
	FoundKit.ticks(k, Vector3(0.261, 0.14, -0.2), Vector3(0.261, 0.14, 0.2), Vector3.RIGHT, 7, R[5])
	FoundKit.rivets(k, Vector3(0.0, 0.1, 0.312), Vector3(0.2, 0.1, 0.312), Vector3.BACK, 3, R[5])
	FoundKit.rivets(k, Vector3(0.0, 0.1, -0.312), Vector3(0.2, 0.1, -0.312), Vector3.FORWARD, 3, R[5])
	body_mesh(k, head)
	add_lamp(head, Vector3(0.262, -0.1, 0.0), Vector3.RIGHT, Vector3.UP, 0.05, 0.05, &"status")
	add_scan(head, Vector3(0.262, 0.05, 0.0), Vector3.RIGHT, Vector3.BACK, 0.34, 0.04, 2.8)


## Four legs, each two straight members meeting at a high knee and ending in a
## grapnel: three tines that curl back up into hooks, which is what finds a
## crack in rock and nothing at all in sand.
func _legs(body: Node3D, R: Array, D: Array, DD: Array) -> void:
	var specs := [[1.0, 1.0, &"leg_fr"], [1.0, -1.0, &"leg_fl"], [-1.0, 1.0, &"leg_br"], [-1.0, -1.0, &"leg_bl"]]
	var dust := _dust()
	var i := 0
	for spec: Array in specs:
		var sx: float = spec[0]
		var sz: float = spec[1]
		var jn: StringName = spec[2]
		var hip := Vector3(sx * HIP_X, -0.02, sz * HIP_Z)
		var leg := joint(jn, body, hip)
		# The foot's place in the leg's own frame: where it comes to ground,
		# less where the hip is.
		var foot := Vector3(sx * FOOT_X, -BODY_Y, sz * FOOT_Z) - hip
		var out := Vector3(foot.x, 0.0, foot.z).normalized()
		var knee := Vector3(foot.x * 0.42, KNEE_UP, foot.z * 0.42)
		var k := FoundKit.kit()
		var s0 := k.vertex_count()
		FoundKit.tbar(k, Vector3.ZERO, knee, 0.1, 0.075, 6, R)
		FoundKit.tbar(k, knee, foot + Vector3(0.0, 0.14, 0.0), 0.075, 0.034, 6, D)
		k.smooth_range(s0, k.vertex_count(), 70.0)
		# The hip's drum and the knee's collar keep their facets: fittings.
		FoundKit.lathe(k, Vector3(0.0, 0.0, -sz * 0.1), Vector3(0, 0, sz), [Vector2(0.12, 0.0), Vector2(0.15, 0.04), Vector2(0.15, 0.2), Vector2(0.12, 0.24)], 8, DD, PI / 8.0)
		FoundKit.lathe(k, knee - (knee - foot).normalized() * 0.1, foot - knee, [Vector2(0.09, 0.0), Vector2(0.11, 0.04), Vector2(0.11, 0.18), Vector2(0.09, 0.22)], 6, DD, PI / 6.0)
		# A ram along the upper member: what straightens the leg to haul the
		# body up a face.
		FoundKit.tbar(k, knee * 0.18 + Vector3(0.0, 0.12, 0.0), knee * 0.78 + Vector3(0.0, 0.1, 0.0), 0.034, 0.03, 4, DD)
		_grapnel(k, foot, out, D, DD)
		body_mesh(k, leg)
		# Red dust caked up from the hooks: the one signature it carries of the
		# place it keeps.
		var w := FoundKit.kit()
		FoundKit.grime(w, knee.lerp(foot, 0.6), out, 0.14, 0.9, 4, 221 + i * 7, dust)
		FoundKit.grime(w, knee.lerp(foot, 0.75), out.cross(Vector3.UP).normalized(), 0.1, 0.6, 3, 222 + i * 7, dust)
		wear_mesh(w, leg)
		i += 1


## Three tines round the foot's collar, each out and down and then curled back
## up into a hook. Welded, because a forged hook is a curve.
func _grapnel(k: MeshKit, foot: Vector3, out: Vector3, D: Array, DD: Array) -> void:
	FoundKit.lathe(k, foot + Vector3(0.0, 0.06, 0.0), Vector3.UP, [Vector2(0.1, 0.0), Vector2(0.12, 0.05), Vector2(0.1, 0.14), Vector2(0.05, 0.18)], 6, DD, PI / 6.0)
	var side := out.cross(Vector3.UP).normalized()
	for a: float in [-0.9, 0.0, 0.9]:
		var dir := (out * cos(a) + side * sin(a)).normalized()
		var s0 := k.vertex_count()
		var p0 := foot + Vector3(0.0, 0.08, 0.0)
		var p1 := foot + dir * 0.2 + Vector3(0.0, -0.02, 0.0)
		var p2 := foot + dir * 0.34 + Vector3(0.0, 0.06, 0.0)
		var p3 := foot + dir * 0.36 + Vector3(0.0, 0.2, 0.0)
		FoundKit.tbar(k, p0, p1, 0.034, 0.03, 5, D)
		FoundKit.tbar(k, p1, p2, 0.03, 0.024, 5, D)
		FoundKit.tbar(k, p2, p3, 0.024, 0.008, 5, DD)
		k.smooth_range(s0, k.vertex_count(), 70.0)


## The counterweight tail: a boom in four tapering members rising back and up
## over the rear, collared at each joint, with a cable run along its back, and a
## cast weight at its end — the one heavy thing on a thin body, and what it
## balances on a wall with.
func _tail(body: Node3D, R: Array, D: Array, DD: Array) -> void:
	var tail := joint(&"tail", body, Vector3(-0.98, 0.16, 0.0))
	var k := FoundKit.kit()
	var s0 := k.vertex_count()
	var radii: Array[float] = [0.13, 0.11, 0.09, 0.07, 0.06]
	for j in TAIL.size() - 1:
		FoundKit.tbar(k, TAIL[j], TAIL[j + 1], radii[j], radii[j + 1], 6, R if j % 2 == 0 else D)
	k.smooth_range(s0, k.vertex_count(), 70.0)
	for j in range(1, TAIL.size() - 1):
		var along := (TAIL[j + 1] - TAIL[j - 1]).normalized()
		FoundKit.lathe(k, TAIL[j] - along * 0.07, along, [Vector2(radii[j] + 0.02, 0.0), Vector2(radii[j] + 0.04, 0.03), Vector2(radii[j] + 0.04, 0.11), Vector2(radii[j] + 0.02, 0.14)], 6, DD, PI / 6.0)
	# The cable that pays the weight in and out, along the top of the boom.
	for j in TAIL.size() - 1:
		var lift := Vector3(0.05, 0.07, 0.0)
		FoundKit.tbar(k, TAIL[j] + lift, TAIL[j + 1] + lift, 0.018, 0.018, 4, FoundKit.flat(Palette.INK[2]))
	body_mesh(k, tail)
	var weight := joint(&"weight", tail, TAIL[TAIL.size() - 1])
	var wk := FoundKit.kit()
	var ws := wk.vertex_count()
	# A cast bell hung point-down off the boom's end: turned, so it is welded.
	FoundKit.lathe(wk, Vector3.ZERO, Vector3.DOWN, [Vector2(0.06, -0.04), Vector2(0.16, 0.06), Vector2(WEIGHT_R, 0.22),
		Vector2(WEIGHT_R, 0.52), Vector2(0.24, 0.66), Vector2(0.05, 0.72)], 12, R, PI / 12.0)
	wk.smooth_range(ws, wk.vertex_count(), 40.0)
	FoundKit.rivets(wk, Vector3(WEIGHT_R + 0.001, -0.3, -0.12), Vector3(WEIGHT_R + 0.001, -0.3, 0.12), Vector3.RIGHT, 3, R[5])
	FoundKit.ticks(wk, Vector3(-WEIGHT_R - 0.001, -0.24, -0.12), Vector3(-WEIGHT_R - 0.001, -0.24, 0.12), Vector3.LEFT, 5, R[5])
	body_mesh(wk, weight)
	var w := FoundKit.kit()
	FoundKit.streaks(w, Vector3(WEIGHT_R, -0.22, 0.0), Vector3.RIGHT, 0.2, 0.3, 3, 231, R[1])
	FoundKit.patch(w, Vector3(0.0, -0.4, WEIGHT_R), Vector3.BACK, Vector3.UP, 0.18, 0.16, Palette.MACHINE["hauler"], 232)
	wear_mesh(w, weight)


## The bolt driver: a ram slung under the rear of the carapace, pointed back and
## down at the rock behind it, with a magazine of bolts along its side. Amber
## rings on its barrel, and it is the working part while it bolts: low on the
## back, at a hand's height, where a player who has walked round it can reach.
func _driver(body: Node3D, R: Array, D: Array, DD: Array) -> void:
	var at := Vector3(-1.02, -0.28, 0.0)
	var aim := Vector3(-0.8, -0.6, 0.0).normalized()
	var bk := FoundKit.kit()
	FoundKit.tbar(bk, Vector3(-0.72, -0.2, 0.0), at, 0.1, 0.1, 6, D)
	# The magazine: a row of bolt heads along a rail on its right.
	FoundKit.tbar(bk, at + Vector3(0.14, 0.02, 0.16), at + aim * 0.36 + Vector3(0.06, 0.02, 0.16), 0.035, 0.035, 4, DD)
	for j in 5:
		var p := (at + Vector3(0.14, 0.02, 0.16)).lerp(at + aim * 0.36 + Vector3(0.06, 0.02, 0.16), (j + 0.5) / 5.0)
		FoundKit.disc(bk, p + Vector3(0.0, 0.0, 0.04), Vector3.BACK, 0.028, 0.02, 6, 0.0, DD)
	body_mesh(bk, body)
	var ram := joint(&"ram", body, at)
	var gk := FoundKit.kit()
	var barrel: Array = [Palette.LENS[0], Palette.LENS[0], Palette.LENS[1], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2]]
	var amber: Array = [Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3], Palette.LENS[3]]
	FoundKit.lathe(gk, Vector3.ZERO, aim, [Vector2(0.12, 0.0), Vector2(0.16, 0.05), Vector2(0.16, 0.34), Vector2(0.1, 0.4), Vector2(0.05, 0.52)], 10, barrel, PI / 10.0)
	for j in 3:
		FoundKit.lathe(gk, aim * (0.1 + j * 0.1), aim, [Vector2(0.165, 0.0), Vector2(0.175, 0.02), Vector2(0.165, 0.04)], 10, amber, PI / 10.0)
	part_mesh(gk, ram)
	set_part_anchor(body, at + aim * 0.26, 0.8)
	var w := FoundKit.kit()
	FoundKit.scorch(w, Vector3(-1.07, -0.08, 0.0), Vector3.LEFT, 0.12, 241)
	wear_mesh(w, body)


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			# Braced: the body drops toward the rock and the tail comes up.
			d[&"body"] = pr(Vector3(0.0, -0.18, 0.0))
			d[&"tail"] = r(Vector3(0.0, 0.0, -0.18))
			d[&"head"] = r(Vector3(0.0, 0.0, -0.08))
		&"windup":
			# The counterweight is thrown forward over its back and the front
			# rears: the tell is the whole tail, and it is the longest in the fight.
			d[&"tail"] = r(Vector3(0.0, 0.0, -0.62))
			d[&"body"] = pr(Vector3(-0.1, 0.12, 0.0), Vector3(0.0, 0.0, 0.16))
			d[&"leg_fr"] = r(Vector3(0.0, 0.0, 0.14))
			d[&"leg_fl"] = r(Vector3(0.0, 0.0, 0.14))
		&"strike":
			# And it comes down: nose first, the tail slammed back behind it.
			d[&"tail"] = r(Vector3(0.0, 0.0, 0.34))
			d[&"body"] = pr(Vector3(0.3, -0.32, 0.0), Vector3(0.0, 0.0, -0.2))
			d[&"leg_br"] = r(Vector3(0.0, 0.0, -0.12))
			d[&"leg_bl"] = r(Vector3(0.0, 0.0, -0.12))
		&"hurt":
			d[&"body"] = pr(Vector3(0.0, -0.08, 0.0), Vector3(0.08, 0.0, 0.0))
			d[&"tail"] = r(Vector3(0.1, 0.0, 0.08))
		&"dead":
			# It goes down flat and the legs curl up over it the way a dead
			# spider's do; the tail comes down behind with the weight in the dust.
			d[&"body"] = pr(Vector3(0.0, -1.24, 0.0), Vector3(0.12, 0.0, 0.05))
			d[&"leg_fr"] = r(Vector3(-0.85, 0.0, 0.0))
			d[&"leg_br"] = r(Vector3(-0.7, 0.0, 0.0))
			d[&"leg_fl"] = r(Vector3(0.85, 0.0, 0.0))
			d[&"leg_bl"] = r(Vector3(0.7, 0.0, 0.0))
			d[&"tail"] = r(Vector3(0.0, 0.2, 0.95))
			d[&"head"] = r(Vector3(0.25, 0.0, 0.18))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead":
		if j == &"body":
			return Vector2(LIGHT_FIRST, 0.45)
		if j == &"tail" or j == &"weight":
			return Vector2(LIGHT_FIRST + 0.2, 0.8)
	return super(p, j)


## A four-legged gait on diagonal pairs, so there are always two hooks on the
## rock; the body rides level between them and the weight lags.
func _gait_deltas(phase: float) -> Dictionary:
	var a := sin(phase * TAU)
	var lift_a := maxf(0.0, a) * 0.16
	var lift_b := maxf(0.0, -a) * 0.16
	return {
		&"leg_fr": r(Vector3(-lift_a, a * 0.14, 0.0)),
		&"leg_bl": r(Vector3(lift_a, a * 0.14, 0.0)),
		&"leg_fl": r(Vector3(lift_b, -a * 0.14, 0.0)),
		&"leg_br": r(Vector3(-lift_b, -a * 0.14, 0.0)),
		&"body": pr(Vector3(0.0, absf(a) * 0.04, 0.0)),
		&"tail": r(Vector3(0.0, 0.0, a * 0.04)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	_t += delta
	# The weight swings on its own slow period while it hangs, and holds still
	# the moment it has the player: it is braced.
	var weight := joints[&"weight"] as Node3D
	weight.rotation.x = 0.0 if locked() else sin(_t * 0.7) * 0.12
	# The driver cycles while it works: the ram draws back and fires.
	var ram := joints[&"ram"] as Node3D
	ram.rotation.z = sin(_t * 2.2) * 0.05
