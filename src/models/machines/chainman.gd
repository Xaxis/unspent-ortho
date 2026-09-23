extends MachineModel
## A CHAINMAN: the crags' one worker of its own (docs/LANDSCAPES.md). It walks
## the survey lines dragging a measuring chain, stops at each stone to set a tiny
## tripod, and goes on. It is not hostile: it shoves whatever is standing on its
## line out of the way (Roles.TURNS: a worker turns on `blocked`), and it drops
## links of its own chain when it goes down.
##
## Why a LOW LONG BODY. Everything else the plan left on the crags is tall and
## thin -- the plumb, the sighting masts -- so this is the opposite: a thing that
## keeps its belly to the ground and its eye on the chain behind it. At fifty
## tiles the two silhouettes cannot be confused, and up close the reel on its
## back reads as the one thing it cares about, because it is.
##
## It is drawn by a ruler: one lofted hull, four straight legs, a turned reel,
## an exact chain. Its colour is a WORKER's ramp (Palette: a machine's colour is
## its role; the lineman's, the trade nearest to stringing a line).
##
## walk   four short legs in diagonal pairs, the reel turning, the chain taut
## stand  stopped at a stone: the tripod swings down off its flank and sets,
##        and the reel pays out on its exact cycle
## alert  the body rises on its legs and the head comes up off the chain
## windup it rears back on its hind legs
## strike and shoves forward: the push that clears its line
## hurt   the reel stutters and nothing else moves
## dead   the legs fold, the hull drops onto its belly, the reel tips and the
##        tripod falls off it
##
## lights a status strip on the head's flank, an optic under the visor, the
##        scan across the visor: it is reading the ground, not you
## wear   peat up the legs, another kind's plate patched over the hull, rust
##        down the reel's cheek
## weld   the legs are welded into tubes; the hull and the reel keep their
##        facets, a housing being panelled and a drum being turned

const BODY_Y := 0.56
const REEL_AT := Vector3(-0.34, 0.24, 0.0)

var _t := 0.0


func build() -> void:
	part_side = &"back"
	height = 1.0
	stride = 0.9
	gallery_turn = 30.0
	begin_rig()
	ramp = Palette.MACHINE["lineman"]
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var body := joint(&"body", self, Vector3(0, BODY_Y, 0))
	_hull(body, R, D, DD)
	_legs(body, R, D, DD)
	_reel(body, R, D)
	_tripod(body, D, DD)
	finish_rig()


## One lofted hull, low and long, with the head hung off its front.
func _hull(body: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(0.92, 0.52, 0.1)
	FoundKit.loft(k, [FoundKit.ring(plan, -0.14, 0.05), FoundKit.ring(plan, -0.06), FoundKit.ring(plan, 0.12, 0.01), FoundKit.ring(plan, 0.18, 0.07)], R, true)
	FoundKit.seam(k, Vector3(-0.4, 0.181, 0.0), Vector3(0.4, 0.181, 0.0), Vector3.UP, R, 4)
	FoundKit.panel(k, Vector3(0.1, 0.02, 0.261), Vector3.BACK, Vector3.UP, 0.4, 0.2, R)
	FoundKit.panel(k, Vector3(0.1, 0.02, -0.261), Vector3.FORWARD, Vector3.UP, 0.4, 0.2, R)
	FoundKit.rivets(k, Vector3(-0.36, 0.14, 0.262), Vector3(0.36, 0.14, 0.262), Vector3.BACK, 5, R[5])
	# The chain: from the reel down to the ground and taut behind it, with the
	# stake it is dragging at the end. Rigid with the hull, which is what a
	# chain under tension is.
	var ink := FoundKit.flat(Palette.INK[2])
	FoundKit.tbar(k, Vector3(-0.42, 0.1, 0.0), Vector3(-0.9, -BODY_Y + 0.03, 0.05), 0.018, 0.018, 4, ink)
	FoundKit.tbar(k, Vector3(-0.9, -BODY_Y + 0.03, 0.05), Vector3(-1.5, -BODY_Y + 0.03, 0.12), 0.018, 0.018, 4, ink)
	for i in 5:
		FoundKit.disc(k, Vector3(-0.98 - i * 0.12, -BODY_Y + 0.03, 0.06 + i * 0.014), Vector3.RIGHT, 0.035, 0.02, 6, 0.0, DD)
	FoundKit.tbar(k, Vector3(-1.5, -BODY_Y + 0.0, 0.12), Vector3(-1.56, -BODY_Y + 0.26, 0.14), 0.02, 0.014, 4, D)
	body_mesh(k, body)
	day_wear(body, Vector3(0.05, 0.183, 0.1), Vector3.UP, Vector3.RIGHT, 0.5, 0.24, 191, 1)
	var w := FoundKit.kit()
	FoundKit.patch(w, Vector3(-0.2, 0.182, -0.12), Vector3.UP, Vector3.RIGHT, 0.22, 0.16, Palette.MACHINE["hauler"], 192)
	FoundKit.streaks(w, Vector3(0.2, 0.1, 0.262), Vector3.BACK, 0.2, 0.2, 3, 193, R[1])
	FoundKit.scorch(w, Vector3(-0.3, 0.0, -0.262), Vector3.FORWARD, 0.07, 194)
	wear_mesh(w, body)

	var head := joint(&"head", body, Vector3(0.52, 0.1, 0.0))
	var hk := FoundKit.kit()
	var hp := FoundKit.plan_oct(0.34, 0.3, 0.07)
	FoundKit.loft(hk, [FoundKit.ring(hp, -0.1, 0.04), FoundKit.ring(hp, -0.04), FoundKit.ring(hp, 0.08, 0.01), FoundKit.ring(hp, 0.12, 0.05)], R, true)
	FoundKit.visor(hk, Vector3(0.171, 0.02, 0.0), Vector3.RIGHT, Vector3.UP, 0.22, 0.035)
	FoundKit.ticks(hk, Vector3(0.171, -0.05, -0.1), Vector3(0.171, -0.05, 0.1), Vector3.RIGHT, 5, R[5])
	body_mesh(hk, head)
	add_scan(head, Vector3(0.173, 0.02, 0.0), Vector3.RIGHT, Vector3.BACK, 0.18, 0.03, 3.0)
	add_lamp(head, Vector3(0.175, -0.05, 0.0), Vector3.RIGHT, Vector3.UP, 0.05, 0.03, &"optic")
	add_lamp(head, Vector3(0.02, 0.06, 0.151), Vector3.BACK, Vector3.UP, 0.05, 0.045, &"status")


## Four short legs, each two straight members welded into tubes, on a pad that
## sinks into peat.
func _legs(body: Node3D, R: Array, D: Array, DD: Array) -> void:
	var peat: Array = [Palette.EARTH[1], Palette.EARTH[2], Palette.SPRUCE[1], Palette.EARTH[1], Palette.EARTH[2], Palette.EARTH[1]]
	var specs := [[0.3, 1.0, &"leg_fr"], [0.3, -1.0, &"leg_fl"], [-0.3, 1.0, &"leg_br"], [-0.3, -1.0, &"leg_bl"]]
	for spec: Array in specs:
		var x: float = spec[0]
		var sz: float = spec[1]
		var jn: StringName = spec[2]
		var leg := joint(jn, body, Vector3(x, -0.12, sz * 0.22))
		var knee := Vector3(x * 0.1, -0.2, sz * 0.09)
		var foot := Vector3(x * 0.16, -BODY_Y + 0.12 + 0.02, sz * 0.12)
		var k := FoundKit.kit()
		var s0 := k.vertex_count()
		FoundKit.tbar(k, Vector3.ZERO, knee, 0.05, 0.042, 6, R)
		FoundKit.tbar(k, knee, foot, 0.042, 0.034, 6, D)
		k.smooth_range(s0, k.vertex_count(), 70.0)
		FoundKit.lathe(k, knee, foot - knee, [Vector2(0.055, -0.03), Vector2(0.062, 0.0), Vector2(0.062, 0.07), Vector2(0.05, 0.1)], 6, DD, PI / 6.0)
		FoundKit.lathe(k, foot, Vector3.DOWN, [Vector2(0.04, -0.02), Vector2(0.08, 0.0), Vector2(0.07, 0.05)], 6, DD, PI / 6.0)
		body_mesh(k, leg)
		var w := FoundKit.kit()
		FoundKit.grime(w, knee.lerp(foot, 0.5), Vector3(0.0, 0.0, sz), 0.08, 0.2, 2, 201 + int(x * 10.0 + sz), peat)
		wear_mesh(w, leg)


## The reel on its back: the working part, amber, turning while it works. The
## chain runs off it, so a blow into it is a blow into the survey.
func _reel(body: Node3D, R: Array, D: Array) -> void:
	var bk := FoundKit.kit()
	for sz: float in [-1.0, 1.0]:
		FoundKit.tbar(bk, REEL_AT + Vector3(0.0, -0.1, sz * 0.14), REEL_AT + Vector3(0.0, 0.0, sz * 0.2), 0.03, 0.026, 4, D)
	body_mesh(bk, body)
	var reel := joint(&"reel", body, REEL_AT)
	var gk := FoundKit.kit()
	var barrel: Array = [Palette.LENS[0], Palette.LENS[0], Palette.LENS[1], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2]]
	var amber: Array = [Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3], Palette.LENS[3]]
	FoundKit.lathe(gk, Vector3.ZERO, Vector3.BACK, [Vector2(0.11, -0.19), Vector2(0.17, -0.15), Vector2(0.17, 0.15), Vector2(0.11, 0.19)], 10, barrel, PI / 10.0)
	for j in 8:
		var a := j * TAU / 8.0
		var n := Vector3(cos(a), sin(a), 0.0)
		FoundKit.mark(gk, n * 0.17, n, Vector3.BACK, 0.05, 0.22, amber[3], 0.004)
	part_mesh(gk, reel)
	set_part_anchor(body, REEL_AT + Vector3(-0.1, 0.0, 0.0), 0.6)
	var w := FoundKit.kit()
	FoundKit.streaks(w, REEL_AT + Vector3(0.0, 0.12, 0.2), Vector3.BACK, 0.1, 0.14, 2, 211, R[1])
	wear_mesh(w, body)


## The tiny tripod it sets at each stone, folded along its flank between stones.
func _tripod(body: Node3D, D: Array, DD: Array) -> void:
	var tripod := joint(&"tripod", body, Vector3(0.0, 0.16, 0.3))
	var k := FoundKit.kit()
	for i in 3:
		var off := Vector3(0.0, 0.02 * i, 0.03 * (i - 1))
		FoundKit.tbar(k, Vector3(-0.28, 0.0, 0.0) + off, Vector3(0.26, 0.04, 0.0) + off, 0.012, 0.01, 4, DD)
	FoundKit.lathe(k, Vector3(0.27, 0.05, 0.0), Vector3.RIGHT, [Vector2(0.03, 0.0), Vector2(0.045, 0.02), Vector2(0.045, 0.07), Vector2(0.02, 0.09)], 6, D, PI / 6.0)
	body_mesh(k, tripod)


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"stand":
			# Stopped at a stone: the tripod swings down off the flank and sets.
			d[&"tripod"] = pr(Vector3(0.0, -0.3, 0.16), Vector3(0.0, 0.0, -1.2))
		&"alert":
			# Up on its legs, the head off the chain.
			d[&"body"] = pr(Vector3(0.0, 0.08, 0.0))
			d[&"head"] = r(Vector3(0.0, 0.0, 0.3))
			d[&"leg_fr"] = r(Vector3(0.0, 0.0, 0.12))
			d[&"leg_fl"] = r(Vector3(0.0, 0.0, 0.12))
			d[&"leg_br"] = r(Vector3(0.0, 0.0, -0.12))
			d[&"leg_bl"] = r(Vector3(0.0, 0.0, -0.12))
		&"windup":
			# It rears back on its hind legs.
			d[&"body"] = pr(Vector3(-0.1, 0.1, 0.0), Vector3(0.0, 0.0, 0.32))
			d[&"head"] = r(Vector3(0.0, 0.0, -0.2))
			d[&"leg_fr"] = r(Vector3(0.0, 0.0, -0.5))
			d[&"leg_fl"] = r(Vector3(0.0, 0.0, -0.5))
		&"strike":
			# And shoves: the push that clears its line.
			d[&"body"] = pr(Vector3(0.22, -0.04, 0.0), Vector3(0.0, 0.0, -0.12))
			d[&"head"] = r(Vector3(0.0, 0.0, 0.1))
			d[&"leg_fr"] = r(Vector3(0.0, 0.0, 0.3))
			d[&"leg_fl"] = r(Vector3(0.0, 0.0, 0.3))
		&"hurt":
			d[&"reel"] = r(Vector3(0.0, 0.0, 0.3))
		&"dead":
			# The legs fold, the hull drops onto its belly, the reel tips and the
			# tripod falls off its flank.
			d[&"body"] = pr(Vector3(0.0, -0.36, 0.04), Vector3(0.1, 0.0, 0.05))
			d[&"leg_fr"] = r(Vector3(0.3, 0.0, 1.2))
			d[&"leg_fl"] = r(Vector3(-0.3, 0.0, 1.2))
			d[&"leg_br"] = r(Vector3(0.3, 0.0, -1.2))
			d[&"leg_bl"] = r(Vector3(-0.3, 0.0, -1.2))
			d[&"reel"] = pr(Vector3(-0.06, 0.0, 0.08), Vector3(0.6, 0.0, 0.0))
			d[&"tripod"] = pr(Vector3(0.1, -0.25, 0.3), Vector3(0.0, 0.5, -1.4))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead" and (j == &"body" or j == &"tripod"):
		return Vector2(LIGHT_FIRST + 0.15, 0.6)
	return super(p, j)


## Diagonal pairs, exactly out of phase: a low body that never rocks.
func _gait_deltas(phase: float) -> Dictionary:
	var a := sin(phase * TAU)
	var b := sin(phase * TAU + PI)
	return {
		&"leg_fr": r(Vector3(0.0, 0.0, a * 0.4)),
		&"leg_bl": r(Vector3(0.0, 0.0, a * 0.4)),
		&"leg_fl": r(Vector3(0.0, 0.0, b * 0.4)),
		&"leg_br": r(Vector3(0.0, 0.0, b * 0.4)),
		&"body": pr(Vector3(0.0, absf(a) * 0.015, 0.0)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	_t += delta
	# The reel pays out on its own exact cycle while it works, and stops dead
	# the moment it has the player.
	(joints[&"reel"] as Node3D).rotation.z = 0.0 if locked() else _t * 1.6


## Its own gallery rows: every pose that changes its shape, since it is not
## one of the twelve in `MachineGallery.KINDS` (those are the coast's roster).
##
##   tools/shot.sh shots/x.png --scene=gallery --filter=chainman
const MG := preload("res://src/models/machines/machine_gallery.gd")


static func gallery() -> Array:
	var out: Array = []
	for p: StringName in [&"stand", &"walk", &"alert", &"windup", &"strike", &"dead"]:
		var item: FigureModel = MG.make(&"chainman", p, 0.3)
		var holder := Node3D.new()
		holder.add_child(item)
		MG._label_later(holder, "chainman %s" % p, Vector3(0.7, 0.0, 0.7))
		out.append({"name": "chainman %s" % p, "node": holder})
	return out
