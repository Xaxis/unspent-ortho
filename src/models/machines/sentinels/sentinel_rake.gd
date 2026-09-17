extends MachineModel
## THE RAKE: the Salt Flats' keeper (docs/VISION.md §3, src/core/sentinel/designs/
## pan_rake.gd). A flat triangular deck carried on four long splayed legs, a rake
## beam dragging behind it, and one mast above it holding a tilting mirror.
##
## Why a DELTA ON STILTS. The Coast's keeper is an arch, and no two sentinels may
## share a silhouette (VISION §3), so this one is built out of the opposite
## material: air under it and a single vertical. On the flattest, brightest ground
## in the game a body reads by its LEGS and by what it holds up, and a mirror on a
## mast is the one thing on the flats that catches the light before anything else
## does — a machine working a place with no shade by throwing the sun at it.
##
## It is drawn by a ruler: the deck is one ruled triangle with a chamfer, the legs
## are two straight members and one brace each at one angle, the rake is a straight
## beam of tines on exact pitch, and the mirror is a turned disc in a ring. Its
## colour is the KEEPER's ramp (Palette: a machine's colour is its role), like the
## Coast's keeper and unlike anything that only works.
##
## Poses. The legs are the whole vocabulary: nothing else in the game stands this
## high off the ground, so lifting and dropping the deck is enormous on screen.
## walk   RAKING: legs stepping in diagonal pairs, the rake dragging behind
## stand  stopped over a pan: the deck low, the mirror stowed flat, the rake up
## alert  it has you: the deck rises, the mirror comes round and up on its mast,
##        the forelegs plant wide and the rake lifts clear
## windup one foreleg comes up and back, high, over the working side
## strike the deck drops forward as that leg comes down
## hurt   the mirror slews off, the tines stop
## dead   the legs splay out from under it and the deck comes down flat on the
##        crust with the mast across it: a wreck lying in its own pan
##
## lights a cold optic under the deck's nose with a scan across it, work lamps at
##        the rake's ends, the plan strip on the deck's top face (the flats are
##        seen from straight above and it is the only plate that matters)
## wear   salt caked up every leg to the knee, mineral stain round the feet, plate
##        off two other kinds patched into the deck, a tine snapped off short

const DECK_Y := 1.34
const HIP := 0.62
const FOOT := 1.16
const RAKE_BACK := 1.12

var _step_t := 0.0


func build() -> void:
	part_side = &"back"
	# The mast, which is what a tell has to clear.
	height = 2.7
	stride = 1.9
	gallery_turn = 38.0
	# Same reason as the reaper's drum: a big working part at the default burns to
	# white and the amber goes out of it (docs/ART.md §5).
	emission = 0.28
	begin_rig()
	ramp = Palette.MACHINE["warden"]
	disposition = &"wary"
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var deck := joint(&"deck", self, Vector3(0, DECK_Y, 0))
	_deck(deck, R, D)
	_legs_of(deck, R, D, DD)
	_nose(deck, R, D)
	_mast(deck, R, D)
	_rake(deck, R, D)
	finish_rig()


## One ruled triangle of plate, nose forward: the whole machine seen from above.
func _deck(deck: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	var plan: Array[Vector2] = [Vector2(0.98, 0.0), Vector2(0.72, 0.42), Vector2(-0.6, 0.94),
		Vector2(-0.82, 0.74), Vector2(-0.82, -0.74), Vector2(-0.6, -0.94), Vector2(0.72, -0.42)]
	FoundKit.loft(k, [_ring(plan, -0.16, 0.06), _ring(plan, -0.07), _ring(plan, 0.1, 0.02), _ring(plan, 0.16, 0.09)], R, true)
	FoundKit.seam(k, Vector3(0.9, 0.161, 0.0), Vector3(-0.76, 0.161, 0.0), Vector3.UP, R, 5)
	FoundKit.panel(k, Vector3(-0.3, 0.161, 0.42), Vector3.UP, Vector3.RIGHT, 0.42, 0.34, R)
	FoundKit.panel(k, Vector3(-0.3, 0.161, -0.42), Vector3.UP, Vector3.RIGHT, 0.42, 0.34, R)
	# The hopper it rakes into, low in the middle of the deck: a turned drum,
	# because a triangle with a cylinder let into it is not a triangle any more.
	FoundKit.lathe(k, Vector3(0.1, 0.16, 0.0), Vector3.UP, [Vector2(0.3, -0.02), Vector2(0.34, 0.06), Vector2(0.3, 0.2)], 8, D, PI / 8.0)
	FoundKit.spot(k, Vector3(0.1, 0.361, 0.0), Vector3.UP, 0.26, 8, FoundKit.dark_colour(R[0]), 0.004)
	body_mesh(k, deck)
	# Seen from straight above, on the brightest ground in the game: this plate is
	# the one place a player can count what the machine thinks of them.
	add_lamp(deck, Vector3(-0.56, 0.163, 0.0), Vector3.UP, Vector3.RIGHT, 0.08, 0.08, &"status")
	day_wear(deck, Vector3(0.4, 0.163, 0.2), Vector3.UP, Vector3.RIGHT, 0.6, 0.5, 121, 1)
	day_marks(deck, Vector3(-0.2, 0.163, -0.3), Vector3.UP, Vector3.RIGHT, 0.7, 0.4, 122)
	var w := FoundKit.kit()
	FoundKit.patch(w, Vector3(0.44, 0.162, -0.3), Vector3.UP, Vector3.RIGHT, 0.34, 0.26, Palette.MACHINE["cutter"], 123)
	FoundKit.patch(w, Vector3(-0.62, 0.162, 0.34), Vector3.UP, Vector3.RIGHT, 0.24, 0.3, Palette.MACHINE["hauler"], 124)
	FoundKit.scorch(w, Vector3(-0.1, 0.162, 0.6), Vector3.UP, 0.1, 125)
	FoundKit.cable(w, Vector3(-0.7, 0.2, 0.3), Vector3(-0.2, 0.22, 0.62), 0.06, 0.02, Palette.INK[2], Palette.MACHINE["lineman"], 4)
	wear_mesh(w, deck)


## Four legs, splayed: two straight members and one brace each, at one angle, and
## a broad foot that will not sink in crust. Salt cakes them to the knee.
func _legs_of(deck: Node3D, R: Array, D: Array, DD: Array) -> void:
	var hips := [[0.52, 1.0, &"leg_fr"], [0.52, -1.0, &"leg_fl"], [-0.56, 1.0, &"leg_br"], [-0.56, -1.0, &"leg_bl"]]
	for spec: Array in hips:
		var x: float = spec[0]
		var sz: float = spec[1]
		var jn: StringName = spec[2]
		var leg := joint(jn, deck, Vector3(x, -0.1, sz * HIP))
		var k := FoundKit.kit()
		var knee := Vector3(x * 0.2, -0.66, sz * (FOOT - 0.3) - sz * HIP)
		var foot := Vector3(x * 0.34, -DECK_Y + 0.12, sz * FOOT - sz * HIP)
		FoundKit.tbar(k, Vector3.ZERO, knee, 0.12, 0.085, 6, R, 0.02)
		FoundKit.tbar(k, knee, foot, 0.085, 0.07, 6, D, 0.02)
		FoundKit.tbar(k, Vector3(x * 0.06, -0.24, sz * 0.06), knee.lerp(foot, 0.4), 0.04, 0.032, 4, DD)
		# The foot: a broad turned pad, chamfered, that spreads the weight the crust
		# will just carry — and will not, over a pan.
		FoundKit.lathe(k, foot + Vector3(0, -0.1, 0), Vector3.UP, [Vector2(0.09, 0.0), Vector2(0.2, 0.05), Vector2(0.17, 0.11)], 6, DD, PI / 6.0)
		body_mesh(k, leg)
		var w := FoundKit.kit()
		# Salt: white crust caked up from the foot, the flats' own signature.
		FoundKit.grime(w, foot + Vector3(0, 0.5, 0), (knee - foot).normalized().cross(Vector3.UP).normalized(), 0.14, 0.42, 3, 131 + int(x * 10.0 + sz), [Palette.LINEN[4], Palette.LINEN[5], Palette.LINEN[3], Palette.LINEN[4], Palette.LINEN[5], Palette.LINEN[5]])
		wear_mesh(w, leg)


## The nose: a cold slit under the deck's point, where its optics read the pan in
## front of it. The one cold thing at a person's height on the whole machine.
func _nose(deck: Node3D, R: Array, D: Array) -> void:
	var nose := joint(&"nose", deck, Vector3(0.82, -0.14, 0.0))
	var k := FoundKit.kit()
	var box := FoundKit.plan_oct(0.34, 0.56, 0.1)
	FoundKit.loft(k, [FoundKit.ring(box, -0.22, 0.05), FoundKit.ring(box, -0.14), FoundKit.ring(box, 0.02, 0.01), FoundKit.ring(box, 0.06, 0.06)], R, true)
	FoundKit.visor(k, Vector3(0.171, -0.08, 0.0), Vector3.RIGHT, Vector3.UP, 0.38, 0.045)
	FoundKit.ticks(k, Vector3(0.171, -0.18, -0.16), Vector3(0.171, -0.18, 0.16), Vector3.RIGHT, 4, R[1])
	body_mesh(k, nose)
	add_scan(nose, Vector3(0.173, -0.08, 0.0), Vector3.RIGHT, Vector3.BACK, 0.32, 0.038, 2.2)
	# No wedge off the nose. A beam is aimed to land its far lip at the machine's
	# own feet (MachineModel._aimed), and thrown from a metre and a half up on a
	# body this tall it comes back as a white blot on the deck instead of a wash on
	# the ground. What this one reads the pan with is the slit and the strip.


## The mast and its mirror: a heliostat. On a landscape whose whole mood is glare,
## the keeper's answer is to hold up a disc and work the ground with the sun.
func _mast(deck: Node3D, R: Array, D: Array) -> void:
	var mast := joint(&"mast", deck, Vector3(-0.24, 0.16, 0.0))
	var k := FoundKit.kit()
	FoundKit.tbar(k, Vector3.ZERO, Vector3(0.06, 0.82, 0.0), 0.11, 0.075, 6, R, 0.02)
	FoundKit.tbar(k, Vector3(-0.3, 0.02, 0.24), Vector3(0.02, 0.5, 0.06), 0.04, 0.032, 4, D)
	FoundKit.tbar(k, Vector3(-0.3, 0.02, -0.24), Vector3(0.02, 0.5, -0.06), 0.04, 0.032, 4, D)
	body_mesh(k, mast)
	# The disc sits tipped up and forward at rest, so the glass faces the light and
	# the eye instead of presenting its dark back to a camera that looks down.
	var yoke := joint(&"mirror", mast, Vector3(0.08, 0.96, 0.0), Vector3(0, 0, 0.9))
	var mk := FoundKit.kit()
	# The ring, then the glass: a turned disc in a chamfered rim, set on a yoke.
	FoundKit.lathe(mk, Vector3(-0.03, 0.0, 0.0), Vector3.RIGHT, [Vector2(0.5, 0.0), Vector2(0.55, 0.035), Vector2(0.5, 0.07)], 10, R, PI / 10.0)
	# Mid-value glass, not white. On the one landscape with no headroom left in the
	# page (salt_flats.gd's TONE note), a pale disc under glare clips to paper and
	# reads as a hole with the machine hidden behind it; a step down it reads as
	# glass catching the sun, and the small highlight is what says it is a mirror.
	FoundKit.spot(mk, Vector3(0.04, 0.0, 0.0), Vector3.RIGHT, 0.48, 10, Palette.RIME[3], 0.004)
	FoundKit.spot(mk, Vector3(0.048, 0.06, 0.1), Vector3.RIGHT, 0.2, 8, Palette.RIME[5], 0.004)
	FoundKit.spot(mk, Vector3(-0.045, 0.0, 0.0), Vector3.RIGHT, 0.48, 10, FoundKit.dark_colour(R[0]), 0.004)
	for j in 4:
		var a := j * TAU / 4.0 + PI * 0.25
		FoundKit.tbar(mk, Vector3(-0.04, 0.0, 0.0), Vector3(-0.04, sin(a) * 0.46, cos(a) * 0.46), 0.022, 0.018, 4, D)
	body_mesh(mk, yoke)
	# No beam off the mirror: a wedge thrown from two and a half metres up lands as
	# a white blot on its own deck at this camera's angle, and a heliostat is read
	# by the DISC, not by a cone. What it throws is the glare the flats already are.
	var w := FoundKit.kit()
	FoundKit.streaks(w, Vector3(0.5, 0.6, 0.0), Vector3.RIGHT, 0.18, 0.4, 3, 141, R[1])
	wear_mesh(w, mast)


## The rake: a straight beam of tines dragging behind it on two arms, and the gear
## that drives it — the working part while it rakes, out where a player can reach
## it if they will come round behind a body that is looking at them.
func _rake(deck: Node3D, R: Array, D: Array) -> void:
	var arm := joint(&"rake", deck, Vector3(-0.78, -0.06, 0.0))
	var k := FoundKit.kit()
	for sz: float in [-1.0, 1.0]:
		FoundKit.tbar(k, Vector3(0.0, 0.0, sz * 0.4), Vector3(-RAKE_BACK, -0.44, sz * 0.72), 0.085, 0.065, 6, R, 0.02)
	# The beam across the back, and the tines on exact pitch under it.
	FoundKit.tbar(k, Vector3(-RAKE_BACK, -0.44, -0.78), Vector3(-RAKE_BACK, -0.44, 0.78), 0.075, 0.075, 4, R, 0.02)
	for j in 9:
		var z := -0.68 + j * 0.17
		# One tine snapped off short: the machines are barely functioning.
		var drop := 0.3 if j != 3 else 0.14
		FoundKit.tbar(k, Vector3(-RAKE_BACK, -0.5, z), Vector3(-RAKE_BACK - 0.06, -0.5 - drop, z), 0.028, 0.02, 4, D)
	FoundKit.rivets(k, Vector3(-RAKE_BACK + 0.02, -0.37, -0.7), Vector3(-RAKE_BACK + 0.02, -0.37, 0.7), Vector3.UP, 6, R[5])
	body_mesh(k, arm)
	for sz: float in [-1.0, 1.0]:
		add_lamp(arm, Vector3(-RAKE_BACK - 0.04, -0.3, sz * 0.74), Vector3(-1, 0, 0), Vector3.UP, 0.07, 0.06, &"work", true)
	var w := FoundKit.kit()
	FoundKit.grime(w, Vector3(-RAKE_BACK, -0.38, 0.0), Vector3(-1, 0, 0), 1.4, 0.16, 5, 151, R)
	wear_mesh(w, arm)
	# What it drags up: salt in ridges behind the tines, drawn by the hand.
	var m := FoundKit.matter_kit(Ink.HAND)
	for j in 4:
		var z := -0.5 + j * 0.34
		m.rock(-RAKE_BACK - 0.12, -0.76, z, 0.16, 0.07, 470 + j, Palette.LINEN[5], 5)
	wear_matter(m, arm)

	# The gear that drives the rake, standing PROUD of the deck's tail: the working
	# part. It has to be seen from a camera that looks down, or the halo round it
	# floats over a plate with nothing under it and the one place a blow counts is
	# a white smudge.
	var gear := joint(&"gear", deck, Vector3(-0.66, 0.14, 0.0))
	var gk := FoundKit.kit()
	var barrel: Array = [Palette.LENS[0], Palette.LENS[0], Palette.LENS[1], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2]]
	var amber: Array = [Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3], Palette.LENS[3]]
	FoundKit.lathe(gk, Vector3(0.0, 0.0, -0.34), Vector3.BACK, [Vector2(0.14, 0.0), Vector2(0.2, 0.05), Vector2(0.2, 0.63), Vector2(0.14, 0.68)], 10, barrel, PI / 10.0)
	for j in 10:
		var a := j * TAU / 10.0
		var at := Vector3(cos(a) * 0.2, sin(a) * 0.2, 0.0)
		var out := Vector3(cos(a), sin(a), 0.0)
		FoundKit.slab(gk, at + out * 0.04, out, Vector3.BACK,
			[Vector2(-0.05, 0.05), Vector2(0.09, 0.02), Vector2(0.09, -0.02), Vector2(-0.05, -0.05)], 0.56, amber)
	part_mesh(gk, gear)
	set_part_anchor(deck, Vector3(-0.66, 0.2, 0.0), 0.95)


## `FoundKit.ring` with the deck's own plan: a helper so the loft reads as one
## shape and not as four lines of numbers.
func _ring(plan: Array[Vector2], y: float, inset: float = 0.0) -> Array:
	return FoundKit.ring(plan, y, inset)


## Everything is said with the legs and the mirror, because a flat deck seen from
## above says nothing at all on its own.
func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"stand":
			# Stopped over a pan: the deck settles, the mirror stows flat over the
			# mast, the rake lifts clear of the crust.
			d[&"deck"] = pr(Vector3(0, -0.18, 0))
			d[&"mirror"] = r(Vector3(0, 0, -1.3))
			d[&"rake"] = r(Vector3(0, 0, 0.3))
			d[&"mast"] = r(Vector3(0, 0, 0.08))
		&"alert":
			# It has you: the deck rises on all four legs, the mirror comes round and
			# up, the forelegs plant wide, and the rake comes off the ground.
			d[&"deck"] = pr(Vector3(-0.04, 0.2, 0))
			d[&"mirror"] = r(Vector3(0, 0, 0.34))
			d[&"mast"] = r(Vector3(0, 0, -0.1))
			d[&"rake"] = r(Vector3(0, 0, 0.26))
			d[&"leg_fr"] = pr(Vector3(0.1, 0, 0.14), Vector3(0.18, 0, 0))
			d[&"leg_fl"] = pr(Vector3(0.1, 0, -0.14), Vector3(-0.18, 0, 0))
		&"windup":
			# A foreleg comes up and back, high over the side about to be used: the
			# tell is the leg, and the eye goes with it.
			d[&"deck"] = pr(Vector3(-0.1, 0.26, 0), Vector3(0, 0, 0.12))
			d[&"leg_fr"] = pr(Vector3(-0.16, 0.44, 0.12), Vector3(0.3, 0, -0.7))
			d[&"leg_fl"] = pr(Vector3(0.06, 0, -0.1), Vector3(-0.1, 0, 0))
			d[&"mirror"] = r(Vector3(0, 0, 0.5))
			d[&"rake"] = r(Vector3(0, 0, 0.4))
		&"strike":
			# The deck drops forward as that leg comes down through where you were.
			d[&"deck"] = pr(Vector3(0.24, -0.12, 0), Vector3(0, 0, -0.14))
			d[&"leg_fr"] = pr(Vector3(0.3, -0.06, 0.04), Vector3(0.1, 0, 0.24))
			d[&"mirror"] = r(Vector3(0, 0, 0.2))
		&"hurt":
			d[&"mirror"] = r(Vector3(0.4, 0, -0.5))
		&"dead":
			# The legs splay out from under it and the deck comes down flat on the
			# crust, the mast across it: a wreck lying in its own pan.
			d[&"deck"] = pr(Vector3(0, -1.06, 0.1), Vector3(0.12, 0, 0.16))
			d[&"leg_fr"] = r(Vector3(1.0, 0, -0.3))
			d[&"leg_fl"] = r(Vector3(-1.1, 0, -0.2))
			d[&"leg_br"] = r(Vector3(0.9, 0, 0.4))
			d[&"leg_bl"] = r(Vector3(-0.8, 0, 0.5))
			d[&"mast"] = r(Vector3(0, 0, 1.35))
			d[&"mirror"] = pr(Vector3(0, -0.1, 0.1), Vector3(0.5, 0, -0.9))
			d[&"rake"] = pr(Vector3(0, -0.1, 0), Vector3(0.2, 0.2, -0.3))
	return d


## Diagonal pairs, exactly out of phase: the gait of a thing that wades a pan.
func _gait_deltas(phase: float) -> Dictionary:
	var a := sin(phase * TAU)
	var b := sin(phase * TAU + PI)
	return {
		&"deck": pr(Vector3(0, absf(a) * 0.05, 0), Vector3(0, 0, a * 0.02)),
		&"leg_fr": pr(Vector3(a * 0.16, maxf(0.0, a) * 0.14, 0)),
		&"leg_bl": pr(Vector3(a * 0.14, maxf(0.0, a) * 0.12, 0)),
		&"leg_fl": pr(Vector3(b * 0.16, maxf(0.0, b) * 0.14, 0)),
		&"leg_br": pr(Vector3(b * 0.14, maxf(0.0, b) * 0.12, 0)),
		&"rake": r(Vector3(0, 0, a * 0.03)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	# The mirror hunts the sun on its own exact cycle while it works, and holds
	# dead still the moment it has the player (locked).
	_step_t += delta
	var yoke := joints[&"mirror"] as Node3D
	yoke.rotation.y = 0.0 if locked() else sin(_step_t * 0.5) * 0.5
	(joints[&"gear"] as Node3D).rotation.z = _step_t * 3.4
