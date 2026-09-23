extends MachineModel
## THE LISTENER: the Frost Sea's keeper (docs/VISION.md §3, src/core/sentinel/
## designs/listener.gd). A wide, low disc on six splayed legs that end in skis,
## carrying a crown of long hydrophone spears it drives into the ice to hear what
## is under it. A spider holding its needles up.
##
## Why a DISC UNDER A CROWN. The Coast's keeper is an arch and the Flats' a delta
## on stilts, and no two sentinels may share a silhouette (VISION §3). On the
## flattest, whitest ground in the game a body is read by what it puts against
## the sky, so this one is made of the one shape the other two do not own — a
## round mass close to the ground — with every vertical it has bunched into a
## crown of needles that reads from a hundred tiles. Skis, not feet, because it
## slides: the sea is a plain of ice and the plan built a thing that crosses it
## without lifting a foot.
##
## It is drawn by a ruler: the deck is one ruled twelve-sided disc with a chamfer,
## each leg two straight members and a brace, the skis flat bars with an upturned
## nose, the spears square needles on exact pitch round a turned collar. Its
## colour is the KEEPER's ramp (Palette: a machine's colour is its role), like the
## other two keepers and unlike anything that only works.
##
## WELDED, unlike the two keepers before it. Every curved mass here — the deck's
## walls, the leg tubes, the collar, the hydrophone bulbs, the receiver, the saw's
## rim — is bracketed in `smooth_begin`/`smooth_end` so it rounds under the sun,
## and every edge that is meant to be an edge — the deck's chamfers, the square
## needles, the skis' corners, the saw's teeth — is left hard. Six-sided members
## state a crease of 66 because the default 52 does not reach a 60-degree facet
## (tests/models/test_welding.gd carries the arithmetic).
##
## Poses. The crown is the whole vocabulary: eight needles that can be up, down
## in the ice, fanned or cocked are enormous on screen against white.
## stand  LISTENING: the spears driven down into the ice all round it, the deck
##        settled, the saw stowed. A spider crouched.
## walk   the spears up, the legs flexing in threes, the skis hissing
## alert  it has you: the deck rises, the spears snap upright and fan, the saw
##        drops to the ice
## windup the two forward spears cock back over the crown, high, and the deck
##        leans back under them
## strike those two drive forward and down through where you were, the deck
##        lunging after them
## hurt   the crown slews off true; the saw jams
## dead   the deck comes down flat on the ice, the legs splay, the spears fall
##        outward one after another: a wreck with its needles fanned round it
##
## lights a cold slit under the nose with a scan across it, the plan strip on the
##        deck's top face (the sea is seen from straight above, and the disc is
##        the only plate that matters), work lamps either side of the saw
## wear   rime caked up every leg from the ski, a spear snapped off short, plate
##        off two other kinds patched into the deck, a cable spliced from the
##        crown down to the receiver, snow gathered on the deck's lee

const DECK_Y := 0.62
const HIP := 0.9
const SPEAR_RING := 0.56
const SPEAR_LEN := 1.5
## Spears in the crown, on exact pitch.
const SPEARS := 8
## The spear that was snapped off short: the machines are barely functioning.
const SNAPPED := 5
## How far out of vertical a spear leans at rest, and how far it is driven down
## into the ice to listen (radians, outward).
const REST_TILT := 0.18
const DOWN_TILT := 1.95
## Six-sided members weld only past their own 60-degree facet.
const CREASE_SIX := 66.0
## Hips round the deck, radians from +X: two forward, two abeam, two aft.
const HIPS: Array[float] = [-0.45, 0.45, -1.5708, 1.5708, -2.7, 2.7]

var _t := 0.0


func build() -> void:
	part_side = &"back"
	# The spear tips when the crown is up, which is what a tell has to clear.
	height = 2.5
	stride = 2.2
	gallery_turn = 34.0
	# A big working part at the default burns to white and the amber goes out of
	# it (docs/ART.md §5): the two keepers before it found the same number.
	emission = 0.28
	begin_rig()
	ramp = Palette.MACHINE["warden"]
	disposition = &"wary"
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var deck := joint(&"deck", self, Vector3(0, DECK_Y, 0))
	_deck(deck, R, D)
	_legs(deck, R, D, DD)
	_nose(deck, R, D)
	_crown(deck, R, D, DD)
	_saw(deck, R, D, DD)
	_ear(deck, R, D)
	finish_rig()


## One ruled twelve-sided disc, a little longer than it is wide so it has a bow:
## the whole machine seen from above.
func _deck(deck: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	var plan: Array[Vector2] = []
	for j in 12:
		var a := float(j) / 12.0 * TAU
		plan.append(Vector2(cos(a) * 1.08, sin(a) * 0.96))
	k.smooth_begin()
	FoundKit.loft(k, [FoundKit.ring(plan, -0.16, 0.14), FoundKit.ring(plan, -0.08), FoundKit.ring(plan, 0.08), FoundKit.ring(plan, 0.14, 0.12)], R, true, true)
	k.smooth_end()
	# Ruled seams from the bow back, and two inset panels either side of the crown:
	# the plate a keeper is read on, seen from straight above.
	FoundKit.seam(k, Vector3(0.9, 0.141, 0.0), Vector3(-0.8, 0.141, 0.0), Vector3.UP, R, 6)
	FoundKit.panel(k, Vector3(0.36, 0.141, 0.5), Vector3.UP, Vector3.RIGHT, 0.4, 0.26, R)
	FoundKit.panel(k, Vector3(0.36, 0.141, -0.5), Vector3.UP, Vector3.RIGHT, 0.4, 0.26, R)
	FoundKit.rivets(k, Vector3(0.2, 0.141, 0.78), Vector3(-0.6, 0.141, 0.78), Vector3.UP, 5, R[5])
	FoundKit.rivets(k, Vector3(0.2, 0.141, -0.78), Vector3(-0.6, 0.141, -0.78), Vector3.UP, 5, R[5])
	# The sounding drum let into the deck ahead of the crown: the reel its
	# hydrophone line pays out from, turned.
	k.smooth_begin()
	FoundKit.lathe(k, Vector3(0.52, 0.14, 0.0), Vector3.UP, [Vector2(0.2, -0.02), Vector2(0.24, 0.05), Vector2(0.22, 0.14)], 10, D, PI / 10.0)
	k.smooth_end()
	FoundKit.spot(k, Vector3(0.52, 0.281, 0.0), Vector3.UP, 0.17, 10, FoundKit.dark_colour(R[0]), 0.004)
	body_mesh(k, deck)
	# What the machine thinks of you, read off the one plate the camera sees.
	add_lamp(deck, Vector3(0.08, 0.143, 0.62), Vector3.UP, Vector3.RIGHT, 0.07, 0.07, &"status")
	day_wear(deck, Vector3(-0.3, 0.143, 0.4), Vector3.UP, Vector3.RIGHT, 0.5, 0.4, 211, 1)
	day_marks(deck, Vector3(-0.2, 0.143, -0.45), Vector3.UP, Vector3.RIGHT, 0.6, 0.36, 212)
	var w := FoundKit.kit()
	FoundKit.patch(w, Vector3(-0.5, 0.142, 0.42), Vector3.UP, Vector3.RIGHT, 0.3, 0.24, Palette.MACHINE["lineman"], 213)
	FoundKit.patch(w, Vector3(0.6, 0.142, -0.36), Vector3.UP, Vector3.RIGHT, 0.22, 0.28, Palette.MACHINE["dredger"], 214)
	FoundKit.scorch(w, Vector3(-0.72, 0.142, -0.2), Vector3.UP, 0.09, 215)
	wear_mesh(w, deck)
	# Snow gathered on the deck's lee, where the wind leaves it: drawn by the hand.
	var m := FoundKit.matter_kit(Ink.HAND)
	for j in 4:
		var a := 2.3 + j * 0.34
		m.rock(cos(a) * 0.82, 0.14, sin(a) * 0.72, 0.12 + j * 0.02, 0.05, 520 + j, Palette.RIME[5], 5)
	wear_matter(m, deck)


## Six legs, splayed: two straight members and a brace each, the knee above the
## hip like a spider's, and a ski under every foot running fore and aft, because
## the machine slides and never steps. Rime cakes them from the ski up.
func _legs(deck: Node3D, R: Array, D: Array, DD: Array) -> void:
	for i in HIPS.size():
		var a := HIPS[i]
		# Each leg is built with local +X pointing OUT from the disc; the joint's
		# yaw puts that outward line on its own bearing.
		var leg := joint(StringName("leg_%d" % i), deck, Vector3(cos(a) * HIP, -0.1, sin(a) * HIP), Vector3(0, -a, 0))
		var knee := Vector3(0.42, 0.22, 0.0)
		var foot := Vector3(0.86, -DECK_Y + 0.14, 0.0)
		var k := FoundKit.kit()
		k.smooth_begin()
		FoundKit.tbar(k, Vector3.ZERO, knee, 0.1, 0.075, 6, R, 0.02)
		FoundKit.tbar(k, knee, foot, 0.075, 0.055, 6, D, 0.02)
		# The ankle: a turned pivot the ski swings on.
		FoundKit.lathe(k, foot, Vector3.RIGHT, [Vector2(0.06, -0.06), Vector2(0.08, -0.02), Vector2(0.08, 0.02), Vector2(0.06, 0.06)], 6, DD, PI / 6.0)
		k.smooth_end(CREASE_SIX)
		FoundKit.tbar(k, Vector3(0.08, -0.06, 0.0), knee.lerp(foot, 0.35), 0.03, 0.026, 4, DD)
		# The ski: a flat bar under the foot along the machine's own fore-and-aft
		# line, whatever bearing the leg is on, with its nose turned up. Left hard:
		# a ski's corners are what say it is a ski and not a paddle.
		var fwd := Vector3(cos(a), 0.0, -sin(a))
		var sole := Vector3(foot.x, -DECK_Y + 0.035, foot.z)
		FoundKit.bar(k, sole - fwd * 0.42, sole + fwd * 0.48, 0.05, 0.16, 0.012, DD)
		# The toe is a slab and not a second bar: `bar` picks its section's frame
		# off the member's own slope, and on the abeam legs a member climbing this
		# steeply came out as a fin standing on edge.
		FoundKit.slab(k, sole + fwd * 0.46, fwd, Vector3.UP,
			[Vector2(0.0, -0.025), Vector2(0.2, 0.1), Vector2(0.2, 0.15), Vector2(0.0, 0.025)], 0.16, DD)
		FoundKit.tbar(k, sole + Vector3(0, 0.02, 0), foot - Vector3(0, 0.05, 0), 0.05, 0.05, 4, DD)
		body_mesh(k, leg)
		var w := FoundKit.kit()
		# Rime: ice caked up from the ski, the sea's own signature, the way salt
		# cakes the rake's legs to the knee.
		FoundKit.grime(w, foot + Vector3(0, 0.34, 0), (knee - foot).normalized().cross(Vector3.BACK).normalized(), 0.12, 0.36, 3, 231 + i,
			[Palette.RIME[4], Palette.RIME[5], Palette.RIME[3], Palette.RIME[5], Palette.RIME[5], Palette.RIME[4]])
		FoundKit.streaks(w, sole + Vector3(0, 0.03, 0.08), Vector3.BACK, 0.3, 0.12, 2, 241 + i, Palette.RIME[5])
		wear_mesh(w, leg)


## The nose: a stubby turned snout on the bow with a cold slit across its face,
## where its optics read the ice ahead. It sees little; that is the design.
func _nose(deck: Node3D, R: Array, D: Array) -> void:
	var nose := joint(&"nose", deck, Vector3(1.0, -0.02, 0.0))
	var k := FoundKit.kit()
	k.smooth_begin()
	FoundKit.lathe(k, Vector3.ZERO, Vector3.RIGHT, [Vector2(0.2, 0.0), Vector2(0.25, 0.08), Vector2(0.23, 0.3), Vector2(0.15, 0.36)], 8, R, PI / 8.0)
	k.smooth_end()
	FoundKit.visor(k, Vector3(0.362, 0.04, 0.0), Vector3.RIGHT, Vector3.UP, 0.22, 0.034)
	FoundKit.ticks(k, Vector3(0.362, -0.08, -0.1), Vector3(0.362, -0.08, 0.1), Vector3.RIGHT, 4, R[1])
	body_mesh(k, nose)
	add_scan(nose, Vector3(0.364, 0.04, 0.0), Vector3.RIGHT, Vector3.BACK, 0.18, 0.03, 2.8)
	var w := FoundKit.kit()
	FoundKit.streaks(w, Vector3(0.3, 0.2, 0.0), Vector3.UP, 0.2, 0.3, 3, 251, Palette.RIME[5])
	wear_mesh(w, nose)


## The crown: a turned collar on the deck and eight square needles standing off
## it on exact pitch, each with the hydrophone bulb it listens through near its
## foot. Every needle is its own joint, because the crown IS the pose vocabulary.
func _crown(deck: Node3D, R: Array, D: Array, DD: Array) -> void:
	var crown := joint(&"crown", deck, Vector3(-0.12, 0.14, 0.0))
	var k := FoundKit.kit()
	k.smooth_begin()
	FoundKit.lathe(k, Vector3.ZERO, Vector3.UP, [Vector2(0.64, 0.0), Vector2(0.68, 0.05), Vector2(0.62, 0.14), Vector2(0.5, 0.18)], 12, R, PI / 12.0)
	k.smooth_end()
	FoundKit.ticks(k, Vector3(0.0, 0.1, -0.66), Vector3(0.0, 0.1, 0.66), Vector3.RIGHT, 6, R[5], 0.02)
	body_mesh(k, crown)
	for j in SPEARS:
		var a := (float(j) + 0.5) / SPEARS * TAU
		# Yawed onto its bearing and leaning a little out: a Z offset in a pose
		# then tilts it radially, down into the ice or up over the deck.
		var spear := joint(StringName("spear_%d" % j), crown, Vector3(cos(a) * SPEAR_RING, 0.16, sin(a) * SPEAR_RING), Vector3(0, -a, -REST_TILT))
		var sk := FoundKit.kit()
		var length := SPEAR_LEN if j != SNAPPED else 0.62
		FoundKit.lathe(sk, Vector3.ZERO, Vector3.UP, [Vector2(0.05, -0.03), Vector2(0.06, 0.0), Vector2(0.05, 0.06)], 6, D, PI / 6.0)
		FoundKit.tbar(sk, Vector3(0, 0.05, 0), Vector3(0, length, 0), 0.028, 0.012, 4, R)
		if j != SNAPPED:
			FoundKit.tbar(sk, Vector3(0, length, 0), Vector3(0, length + 0.14, 0), 0.012, 0.0, 4, D)
		else:
			# Snapped: a stub with its end bent over.
			FoundKit.tbar(sk, Vector3(0, length, 0), Vector3(0.05, length + 0.06, 0.02), 0.012, 0.006, 4, DD)
		# The hydrophone: a turned bulb a third of the way up, welded, with a
		# ruled band round its waist.
		sk.smooth_begin()
		FoundKit.lathe(sk, Vector3(0, 0.34, 0), Vector3.UP, [Vector2(0.03, 0.0), Vector2(0.07, 0.06), Vector2(0.07, 0.16), Vector2(0.03, 0.22)], 6, DD, PI / 6.0)
		sk.smooth_end(CREASE_SIX)
		FoundKit.rivets(sk, Vector3(0.07, 0.42, -0.02), Vector3(0.07, 0.42, 0.02), Vector3.RIGHT, 2, R[5], FoundKit.PX * 1.2)
		body_mesh(sk, spear)
	# The cable that carries what the crown hears down to the receiver, spliced.
	var w := FoundKit.kit()
	FoundKit.cable(w, Vector3(-0.4, 0.16, 0.2), Vector3(-0.86, -0.02, 0.1), 0.05, 0.016, Palette.INK[2], Palette.MACHINE["lineman"], 4)
	wear_mesh(w, crown)


## The saw under its left flank: the ring it cuts round a player is the ground
## that will take it (the design's founder way). Stowed just clear of the ice at
## rest, dropped on alert. The blade is its own joint so it can spin.
func _saw(deck: Node3D, R: Array, D: Array, DD: Array) -> void:
	var saw := joint(&"saw", deck, Vector3(0.1, -0.08, -0.74))
	var k := FoundKit.kit()
	k.smooth_begin()
	FoundKit.tbar(k, Vector3(0.0, 0.0, 0.0), Vector3(0.0, -0.1, -0.26), 0.07, 0.06, 6, R, 0.02)
	FoundKit.tbar(k, Vector3(0.0, -0.1, -0.26), Vector3(0.0, 0.02, -0.4), 0.06, 0.05, 6, D, 0.02)
	k.smooth_end(CREASE_SIX)
	FoundKit.tbar(k, Vector3(0.3, 0.0, 0.0), Vector3(0.0, -0.1, -0.26), 0.03, 0.026, 4, DD)
	FoundKit.tbar(k, Vector3(-0.3, 0.0, 0.0), Vector3(0.0, -0.1, -0.26), 0.03, 0.026, 4, DD)
	body_mesh(k, saw)
	for sx: float in [-1.0, 1.0]:
		add_lamp(saw, Vector3(sx * 0.14, -0.02, -0.3), Vector3.FORWARD, Vector3.UP, 0.06, 0.05, &"work")
	var blade := joint(&"blade", saw, Vector3(0.0, 0.02, -0.44))
	var bk := FoundKit.kit()
	bk.smooth_begin()
	FoundKit.disc(bk, Vector3.ZERO, Vector3.BACK, 0.34, 0.03, 16, 0.0, D)
	bk.smooth_end()
	# Teeth on exact pitch round the rim, hard-edged, the one on the ground side
	# bright where the ice has rubbed it.
	for j in 12:
		var a := float(j) / 12.0 * TAU
		var out := Vector3(cos(a), sin(a), 0.0)
		FoundKit.slab(bk, out * 0.36, out, Vector3.BACK,
			[Vector2(-0.03, 0.03), Vector2(0.06, 0.01), Vector2(0.06, -0.02), Vector2(-0.03, -0.03)], 0.026, DD)
	FoundKit.spot(bk, Vector3(0.0, 0.0, -0.017), Vector3.FORWARD, 0.1, 8, R[5], 0.003)
	body_mesh(bk, blade)


## The receiver at its back: a turned amber drum with a grille of ribs, the
## working part while it listens. It stands PROUD of the deck's stern, because a
## camera that looks down has to see the one place a blow counts.
func _ear(deck: Node3D, R: Array, D: Array) -> void:
	var ear := joint(&"ear", deck, Vector3(-1.02, 0.02, 0.0))
	var gk := FoundKit.kit()
	var barrel: Array = [Palette.LENS[0], Palette.LENS[0], Palette.LENS[1], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2]]
	var amber: Array = [Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3], Palette.LENS[3]]
	gk.smooth_begin()
	FoundKit.lathe(gk, Vector3.ZERO, Vector3.LEFT, [Vector2(0.16, 0.0), Vector2(0.3, 0.1), Vector2(0.3, 0.34), Vector2(0.2, 0.42)], 10, barrel, PI / 10.0)
	gk.smooth_end()
	for j in 6:
		var a := float(j) / 6.0 * TAU + PI / 6.0
		var out := Vector3(0.0, sin(a), cos(a))
		FoundKit.slab(gk, Vector3(-0.44, 0.0, 0.0) + out * 0.11, out, Vector3.LEFT,
			[Vector2(-0.09, 0.03), Vector2(0.1, 0.02), Vector2(0.1, -0.02), Vector2(-0.09, -0.03)], 0.03, amber)
	FoundKit.spot(gk, Vector3(-0.44, 0.0, 0.0), Vector3.LEFT, 0.09, 8, Palette.LENS[3], 0.004)
	part_mesh(gk, ear)
	set_part_anchor(deck, Vector3(-1.1, 0.12, 0.0), 0.95)
	var w := FoundKit.kit()
	FoundKit.grime(w, Vector3(-0.2, 0.3, 0.0), Vector3.UP, 0.3, 0.2, 3, 261, D)
	wear_mesh(w, ear)


## The crown says everything; the legs and the saw say the rest.
func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"stand":
			# Listening: every spear driven down into the ice round it, the deck
			# settled on its skis, the saw stowed. A spider crouched.
			d[&"deck"] = pr(Vector3(0, -0.06, 0))
			for j in SPEARS:
				d[_spear(j)] = r(Vector3(0, 0, -(DOWN_TILT - REST_TILT)))
		&"walk":
			d[&"crown"] = r(Vector3(0, 0, 0.12))
		&"alert":
			# It has you: the deck rises on all six, the spears snap up and fan,
			# the saw comes down to the ice.
			d[&"deck"] = pr(Vector3(-0.04, 0.14, 0))
			for j in SPEARS:
				d[_spear(j)] = r(Vector3(0, 0, -0.36))
			d[&"saw"] = r(Vector3(-0.42, 0, 0))
			d[&"leg_0"] = r(Vector3(0, 0, 0.1))
			d[&"leg_1"] = r(Vector3(0, 0, 0.1))
		&"windup":
			# The two forward spears cock back over the crown, high, and the deck
			# leans back under them: the tell is the pair of needles.
			d[&"deck"] = pr(Vector3(-0.12, 0.2, 0), Vector3(0, 0, 0.16))
			d[_spear(0)] = r(Vector3(0, 0, 0.9))
			d[_spear(SPEARS - 1)] = r(Vector3(0, 0, 0.9))
			for j in range(1, SPEARS - 1):
				d[_spear(j)] = r(Vector3(0, 0, -0.3))
			d[&"saw"] = r(Vector3(-0.42, 0, 0))
			d[&"crown"] = r(Vector3(0, 0, 0.1))
		&"strike":
			# They drive forward and down through where you were, the deck lunging
			# after them.
			d[&"deck"] = pr(Vector3(0.3, -0.08, 0), Vector3(0, 0, -0.2))
			d[_spear(0)] = r(Vector3(0, 0, -2.1))
			d[_spear(SPEARS - 1)] = r(Vector3(0, 0, -2.1))
			for j in range(1, SPEARS - 1):
				d[_spear(j)] = r(Vector3(0, 0, -0.5))
			d[&"saw"] = r(Vector3(-0.42, 0, 0))
		&"hurt":
			d[&"crown"] = r(Vector3(0.22, 0, -0.18))
			d[&"saw"] = r(Vector3(0.3, 0, 0))
		&"dead":
			# The deck comes down flat on the ice, the legs splay, and the spears
			# fall outward one after another: a wreck with its needles round it.
			d[&"deck"] = pr(Vector3(0, -DECK_Y + 0.2, 0.1), Vector3(0.1, 0, 0.14))
			for i in HIPS.size():
				var sx := 1.0 if i % 2 == 0 else -1.0
				d[StringName("leg_%d" % i)] = r(Vector3(0, 0, -0.5 - 0.15 * sx))
			for j in SPEARS:
				d[_spear(j)] = r(Vector3(0, 0, -1.25 - 0.18 * float(j % 3)))
			d[&"crown"] = r(Vector3(0.3, 0, 0.4))
			d[&"saw"] = r(Vector3(-0.9, 0, 0))
			d[&"ear"] = pr(Vector3(-0.1, -0.06, 0), Vector3(0, 0.3, 0.4))
			d[&"nose"] = r(Vector3(0, 0, -0.3))
	return d


## The spears fall one after another, and the crown last.
func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead":
		for i in SPEARS:
			if j == _spear(i):
				return Vector2(LIGHT_FIRST + 0.5 + 0.09 * float(i), 0.4)
		if j == &"crown":
			return Vector2(LIGHT_FIRST + 1.3, 0.35)
	elif p == &"alert":
		# The needles snap up together, a beat after the deck has risen.
		for i in SPEARS:
			if j == _spear(i):
				return Vector2(0.08, 0.14)
	return super(p, j)


## Skis do not step. The legs flex in threes, exactly out of phase, and the deck
## rides the flex: the gait of a thing that slides.
func _gait_deltas(phase: float) -> Dictionary:
	var d := {}
	for i in HIPS.size():
		var ph := phase * TAU + float(i % 3) * TAU / 3.0
		d[StringName("leg_%d" % i)] = pr(Vector3(0, absf(sin(ph)) * 0.03, 0), Vector3(0, 0, sin(ph) * 0.05))
	var a := sin(phase * TAU * 3.0)
	d[&"deck"] = pr(Vector3(0, absf(a) * 0.02, 0), Vector3(a * 0.015, 0, 0))
	d[&"crown"] = r(Vector3(0, 0, a * 0.02))
	return d


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	_t += delta
	# The crown turns slowly, hunting for sound, and holds dead still the moment
	# it has the player (locked); the blade spins whenever the machine runs.
	var crown := joints[&"crown"] as Node3D
	crown.rotation.y = 0.0 if locked() else sin(_t * 0.35) * 0.4
	(joints[&"blade"] as Node3D).rotation.z = _t * 5.2


static func _spear(i: int) -> StringName:
	return StringName("spear_%d" % i)
