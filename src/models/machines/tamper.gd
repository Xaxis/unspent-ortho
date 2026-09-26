extends MachineModel
## A tamper: the dropper (Roster, improvement 3c). A weight on four sprung legs
## that packs ground for the plan by dropping itself on it, and has learnt to
## wait on a ledge over a path and drop on what walks under. An octagonal ram
## block with a tamping plate under it, the legs folded high over it like a
## grasshopper's, knees above the block, and the ram's drive in its face behind
## a guard of bars.
##
## Why THIS silhouette. The scrapwood's and the crags' other bodies are masts,
## walkers and low workers; this is a block with its knees up round it, and on a
## lip it reads as a thing crouched to jump. Ruled like every machine: the block
## is one loft on exact chamfers, the legs are tapered members with a spring
## laid along each shin at one pitch, and the only turned things are the knees
## and the optic. On a hunter's ramp, the runner's: a hunter is what it became.
##
## walk   the legs step in pairs, the block carried level between them
## stand  the knees work, a slow exact flex, as if it were tamping still
## alert  the block rises on straightening legs, the knees go out
## windup crouched on the lip, block low and tipped forward, knees high over
##        it: coiled, for the whole tell, while its shadow grows on the ground
## strike the landing: legs splayed flat, the block down on its plate
## hurt   nothing flinches: the drive's light stutters out
## dead   the legs lie out flat round it and the block settles tipped on its
##        plate: a weight put down
##
## lights the plan strip on the block's top (read from above), a cold optic on
##        the top of its face, a work lamp under the face washing the ground it
##        lands on, and the drive's own lamp that goes hot through a windup
## part   the ram's drive in its FACE behind a guard of bars: what drives the
##        drop and what stops it, and a guard a blow rings off until it is open
## wear   one leg off another kind, soil caked up the plate and the shins, a
##        scorch on the block's shoulder, a plate off a hauler patched on its back

const BODY_Y := 0.46
const KNEE := Vector3(0.26, 0.34, 0.0)
const FOOT := Vector3(0.5, -BODY_Y, 0.0)

var _knees: Array[StringName] = []


func build() -> void:
	part_side = &"front"
	height = 1.1
	stride = 0.9
	gallery_turn = 30.0
	begin_rig()
	ramp = Palette.MACHINE["runner"]
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var body := joint(&"body", self, Vector3(0, BODY_Y, 0))
	_block(body, R, D, DD)
	var i := 0
	for c: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]:
		var yaw := atan2(-c.y, c.x)
		var leg := joint(StringName("leg%d" % i), body, Vector3(c.x * 0.2, 0.08, c.y * 0.2), Vector3(0, yaw, 0))
		_leg(leg, R, D, DD, i == 2)
		_knees.append(StringName("leg%d" % i))
		i += 1
	finish_rig()


## The ram block and its plate, the guard over the drive in its face.
func _block(body: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(0.56, 0.52, 0.12)
	FoundKit.loft(k, [FoundKit.ring(plan, -0.12, 0.04), FoundKit.ring(plan, -0.08), FoundKit.ring(plan, 0.2, 0.0), FoundKit.ring(plan, 0.26, 0.08)], R, true, true)
	# The tamping plate under it, wider than the block.
	var foot := FoundKit.plan_oct(0.66, 0.62, 0.1)
	FoundKit.loft(k, [FoundKit.ring(foot, -0.2, 0.02), FoundKit.ring(foot, -0.17), FoundKit.ring(foot, -0.12, 0.03)], DD, false, true)
	FoundKit.seam(k, Vector3(-0.2, 0.261, 0.0), Vector3(0.2, 0.261, 0.0), Vector3.UP, R, 3)
	FoundKit.rivets(k, Vector3(-0.2, 0.1, 0.261), Vector3(0.2, 0.1, 0.261), Vector3.BACK, 4, R[5])
	FoundKit.rivets(k, Vector3(-0.2, 0.1, -0.261), Vector3(0.2, 0.1, -0.261), Vector3.FORWARD, 4, R[5])
	# The guard over the drive: bars across the face, the drive's lens behind.
	for j in 4:
		FoundKit.tbar(k, Vector3(0.3, -0.04 + j * 0.07, -0.16), Vector3(0.3, -0.04 + j * 0.07, 0.16), 0.014, 0.014, 4, D)
	body_mesh(k, body)
	add_lamp(body, Vector3(-0.05, 0.263, 0.1), Vector3.UP, Vector3.RIGHT, 0.045, 0.045, &"status")
	add_lamp(body, Vector3(0.262, 0.2, 0.0), Vector3.RIGHT, Vector3.UP, 0.06, 0.04, &"optic")
	add_scan(body, Vector3(0.263, 0.2, 0.0), Vector3.RIGHT, Vector3.BACK, 0.2, 0.03, 1.8)
	add_lamp(body, Vector3(0.28, -0.1, 0.0), Vector3(0.95, -0.3, 0), Vector3(0.3, 0.95, 0), 0.06, 0.04, &"work")
	add_beam(body, Vector3(0.3, -0.12, 0.0), Vector3(0.8, -0.6, 0.0), 1.6, 1.2, &"work")
	add_lamp(body, Vector3(0.281, 0.16, 0.14), Vector3.RIGHT, Vector3.UP, 0.04, 0.035, &"work", true)
	day_marks(body, Vector3(-0.05, 0.262, -0.08), Vector3.UP, Vector3.RIGHT, 0.24, 0.2, 81)
	var w := FoundKit.kit()
	var soil: Array = [Palette.LINEN[1], Palette.LINEN[2], Palette.LINEN[2], Palette.LINEN[3], Palette.LINEN[3], Palette.LINEN[3]]
	FoundKit.grime(w, Vector3(0.0, -0.13, 0.311), Vector3.BACK, 0.5, 0.06, 4, 82, soil)
	FoundKit.grime(w, Vector3(0.0, -0.13, -0.311), Vector3.FORWARD, 0.5, 0.06, 4, 83, soil)
	FoundKit.scorch(w, Vector3(-0.24, 0.18, 0.2), Vector3(-0.7, 0.2, 0.7).normalized(), 0.07, 84)
	FoundKit.patch(w, Vector3(-0.281, 0.06, 0.0), Vector3.LEFT, Vector3.UP, 0.2, 0.14, Palette.MACHINE["hauler"], 85)
	wear_mesh(w, body)
	var pk := FoundKit.kit()
	FoundKit.lens(pk, Vector3(0.281, 0.07, 0.0), Vector3.RIGHT, Vector3.UP, 0.22, 0.18)
	part_mesh(pk, body)
	set_part_anchor(body, Vector3(0.29, 0.07, 0.0), 0.5)


## One leg, built pointing out along +X from its hip: a thigh up to a knee
## over the block, a shin down to a foot, a spring along the shin. `odd`: the
## one off another kind.
func _leg(leg: Node3D, R: Array, D: Array, DD: Array, odd: bool) -> void:
	var LR: Array = FoundKit.dirty(Palette.MACHINE["lineman"]) if odd else D
	var lk := FoundKit.kit()
	FoundKit.disc(lk, Vector3.ZERO, Vector3.BACK, 0.05, 0.06, 6, 0.01, R)
	FoundKit.tbar(lk, Vector3.ZERO, KNEE, 0.035, 0.03, 6, LR)
	FoundKit.disc(lk, KNEE, Vector3.BACK, 0.045, 0.07, 6, 0.01, R, R[4], PI / 6.0)
	FoundKit.tbar(lk, KNEE, FOOT, 0.03, 0.02, 6, LR)
	FoundKit.cbox(lk, FOOT + Vector3(0.02, 0.015, 0.0), Vector3(0.1, 0.03, 0.08), 0.008, DD)
	# The spring along the shin, a coil at one pitch.
	FoundKit.coil(lk, KNEE.lerp(FOOT, 0.2) + Vector3(0, 0, 0.04), KNEE.lerp(FOOT, 0.75) + Vector3(0, 0, 0.04), 0.025, 5.0, 0.006, R[4])
	body_mesh(lk, leg)
	var w := FoundKit.kit()
	var soil: Array = [Palette.LINEN[2], Palette.LINEN[3], Palette.LINEN[3], Palette.LINEN[3], Palette.LINEN[4], Palette.LINEN[4]]
	FoundKit.tbar(w, KNEE.lerp(FOOT, 0.7), FOOT, 0.032, 0.024, 4, soil)
	wear_mesh(w, leg)


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			d[&"body"] = pr(Vector3(0, 0.08, 0))
			for jn in _knees:
				d[jn] = r(Vector3(0, 0, -0.18))
		&"windup":
			# Coiled on the lip: low, tipped forward, the knees high over it.
			d[&"body"] = pr(Vector3(0.02, -0.16, 0), Vector3(0, 0, -0.14))
			for jn in _knees:
				d[jn] = r(Vector3(0, 0, 0.36))
		&"strike":
			# The landing: legs splayed flat, the block down on its plate.
			d[&"body"] = pr(Vector3(0, -0.22, 0))
			for jn in _knees:
				d[jn] = r(Vector3(0, 0, 0.5))
		&"dead":
			d[&"body"] = pr(Vector3(0, -0.2, 0), Vector3(0.1, 0, 0.06))
			for jn in _knees:
				d[jn] = r(Vector3(0, 0, 0.55))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"windup":
		# It settles into the crouch slowly enough to be seen coiling.
		return Vector2(0.0, 0.4)
	return super(p, j)


## The legs step in diagonal pairs; the block rides level.
func _gait_deltas(phase: float) -> Dictionary:
	var d := {}
	for li in _knees.size():
		var pair := 1.0 if li % 2 == 0 else -1.0
		var lift := maxf(0.0, sin(phase * TAU) * pair)
		d[_knees[li]] = r(Vector3(0, sin(phase * TAU) * pair * 0.18, lift * 0.2))
	d[&"body"] = pr(Vector3(0, absf(sin(phase * TAU)) * 0.015, 0))
	return d


func _routine(_delta: float, on: bool) -> void:
	if not on or pose != &"stand":
		return
	# Tamping still: the knees flex together on an exact slow beat.
	var t := fposmod(clock, 2.4)
	var flex := 0.12 * (smoothstep(1.6, 1.9, t) - smoothstep(2.0, 2.3, t))
	(joints[&"body"] as Node3D).position.y -= flex * 0.3
	for jn in _knees:
		(joints[jn] as Node3D).rotation.z += flex
