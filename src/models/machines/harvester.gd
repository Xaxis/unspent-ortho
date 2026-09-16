extends MachineModel
## A harvester: a slab with an arm out. Wide, low and square on two tracks,
## working a field row by row to the headland and back. Across its front a hood
## runs down to a row of pointed dividers with an amber comb between them: the
## dangerous end and the working part at once. It never stops combing.
##
## What names it from a hundred tiles is the UNLOADING SPOUT swung out over its
## flank — a ruled arm braced back to the deck with a chute turned down at the
## end, which fills a hauler running alongside — and two unequal stacks standing
## clear of the deck behind it. Without those the machine was a filled black
## lozenge whose stand, alert and windup were the same lozenge (art review,
## wave A): a slab seen from a high camera has no outline of its own.
##
## Its poses are shapes, not lights: a slab has no limbs to throw, so everything
## is said by where the header sits and how the hull rides on its tracks.
## walk   CUTTING: the header down in the row, the hull pitching and yawing on
##        an exact cycle
## stand  stopped at the headland: the header up out of the row, stacks upright,
##        the hull high on unloaded springs
## alert  it has seen you: the hull settles, the header comes down on the ground
##        and stops, two lamp masts run up out of the hull
## windup the hull rears back and the hood tips OPEN, bringing the comb up into
##        plain sight — the side about to take you is the side the eye is sent to
## strike the whole slab is thrown forward, header down
## hurt   lamps out, comb stops
## dead   lists onto one track, intake on the ground, the comb dropped askew in
##        front of it, lamps and stacks folded; the row spills out
##
## lights work lamps on the two masts and under the hood lip, lit while it
##        works and hot at night; they flare with the comb through a windup; a
##        status lamp on the housing blinks once (indifferent)
## wear   the intake clogged with the row: straw lying over the comb ends, a
##        rag dragged up the hood, a long bone across the dividers sticking out
##        past the end; plates off other machines on the hull and hood; a
##        cable spliced from the stacks; soot round the stack foot

const WHEEL_R := 0.13
const HULL_Y := 0.5
const TRACK_Z := 1.06

var _travel := 0.0
var _comb_t := 0.0
var _wheels: Array[Node3D] = []


func build() -> void:
	part_side = &"front"
	# The spout, not the deck, is the top of this machine now: a tell drawn over
	# the silhouette must clear the arm, not sit inside it.
	height = 1.5
	stride = 1.6
	gallery_turn = 35.0
	begin_rig()
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	# Tracks and road wheels ride on the root: they never pitch with the hull.
	var track: Array[Vector2] = [Vector2(0.98, 0.3), Vector2(0.82, 0.46), Vector2(-0.86, 0.46), Vector2(-1.02, 0.3), Vector2(-1.02, 0.16), Vector2(-0.86, 0.0), Vector2(0.82, 0.0), Vector2(0.98, 0.16)]
	for sz: float in [-1.0, 1.0]:
		var tk := FoundKit.kit()
		FoundKit.slab(tk, Vector3(0, 0, sz * TRACK_Z), Vector3.RIGHT, Vector3.UP, track, 0.42, DD, 0.02)
		for j in 8:
			FoundKit.mark(tk, Vector3(-0.78 + j * 0.218, 0.462, sz * TRACK_Z), Vector3.UP, Vector3.BACK, 0.4, 0.05, R[0], 0.002)
		FoundKit.mark(tk, Vector3(-0.02, 0.23, sz * (TRACK_Z + 0.211)), Vector3.BACK * sz, Vector3.UP, 1.64, 0.26, R[0], 0.002)
		body_mesh(tk, self)
		for x: float in [-0.66, -0.02, 0.62]:
			var w := Node3D.new()
			w.position = Vector3(x, 0.23, sz * (TRACK_Z + 0.23))
			add_child(w)
			var wk := FoundKit.kit()
			FoundKit.disc(wk, Vector3.ZERO, Vector3.BACK, WHEEL_R, 0.05, 6, 0.012, D, D[2], PI / 6.0)
			FoundKit.spot(wk, Vector3(0, 0, sz * 0.026), Vector3.BACK * sz, 0.045, 6, R[4], 0.002)
			body_mesh(wk, w)
			_wheels.append(w)

	var hull := joint(&"hull", self, Vector3(0, HULL_Y, 0))
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(1.86, 1.72, 0.34)
	FoundKit.loft(k, [FoundKit.ring(plan, -0.22, 0.05), FoundKit.ring(plan, -0.14), FoundKit.ring(plan, 0.22, 0.01), FoundKit.ring(plan, 0.3, 0.09)], R, true)
	# Skirts over the tracks.
	for sz: float in [-1.0, 1.0]:
		var skirt: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(0.9, 0.06), Vector2(-0.9, 0.06), Vector2(-1.04, 0.0), Vector2(-0.98, -0.04), Vector2(0.94, -0.04)]
		FoundKit.slab(k, Vector3(0, 0.0, sz * TRACK_Z), Vector3.RIGHT, Vector3.BACK * sz, skirt, 0.05, R)
		FoundKit.rivets(k, Vector3(-0.8, 0.04, sz * (TRACK_Z + 0.03)), Vector3(0.8, 0.04, sz * (TRACK_Z + 0.03)), Vector3.UP, 6, R[5])
		FoundKit.streaks(k, Vector3(0.1, 0.12, sz * 0.861), Vector3.BACK * sz, 1.3, 0.2, 5, 31 + int(sz), R[1])
	# The rear housing: low, so the whole stays a slab; a cold slit across its
	# face like a cab window with nobody behind it, louvres on top.
	var cab := FoundKit.plan_oct(0.66, 1.26, 0.2)
	FoundKit.loft(k, [FoundKit.ring(cab, 0.28, 0.0, Vector2.ONE, Vector2(-0.5, 0)), FoundKit.ring(cab, 0.42, 0.02, Vector2.ONE, Vector2(-0.5, 0)), FoundKit.ring(cab, 0.47, 0.07, Vector2.ONE, Vector2(-0.5, 0))], R)
	FoundKit.visor(k, Vector3(-0.169, 0.36, 0), Vector3.RIGHT, Vector3.UP, 0.7, 0.04)
	FoundKit.streaks(k, Vector3(-0.169, 0.33, 0), Vector3.RIGHT, 0.64, 0.05, 5, 33, R[1])
	for j in 7:
		FoundKit.mark(k, Vector3(-0.5, 0.472, -0.39 + j * 0.13), Vector3.UP, Vector3.RIGHT, 0.36, 0.03, R[1], 0.002)
	FoundKit.seam(k, Vector3(-0.12, 0.301, 0), Vector3(0.66, 0.301, 0), Vector3.UP, R, 3)
	FoundKit.panel(k, Vector3(0.3, 0.301, 0.46), Vector3.UP, Vector3.RIGHT, 0.5, 0.36, R)
	body_mesh(k, hull)
	# The deck the sun falls on all day and the hood it pushes into a field: the
	# two plates the camera sees most of, and the two that said nothing at noon.
	day_wear(hull, Vector3(0.3, 0.303, -0.46), Vector3.UP, Vector3.RIGHT, 0.58, 0.44, 45, 1)
	# The plan strip runs across the housing roof, the plate the high camera can
	# never miss: what it thinks of you, counted, from as far off as the slab itself.
	add_lamp(hull, Vector3(-0.34, 0.473, 0.0), Vector3.UP, Vector3.RIGHT, 0.075, 0.075, &"status")
	var hw := FoundKit.kit()
	FoundKit.patch(hw, Vector3(0.36, 0.302, -0.02), Vector3.UP, Vector3.RIGHT, 0.34, 0.22, Palette.MACHINE["cutter"], 41)
	FoundKit.patch(hw, Vector3(-0.62, 0.473, -0.34), Vector3.UP, Vector3.RIGHT, 0.2, 0.26, Palette.MACHINE["watcher"], 42)
	FoundKit.scorch(hw, Vector3(-0.74, 0.473, 0.22), Vector3.UP, 0.09, 43)
	FoundKit.scorch(hw, Vector3(-0.74, 0.473, -0.22), Vector3.UP, 0.07, 44)
	FoundKit.cable(hw, Vector3(-0.8, 0.52, 0.5), Vector3(-0.42, 0.48, 0.58), 0.05, 0.018, Palette.INK[2], Palette.MACHINE["sweeper"], 4)
	for sz: float in [-1.0, 1.0]:
		FoundKit.dirt_line(hw, Vector3(-0.9, -0.1, sz * 0.862), Vector3(0.85, -0.1, sz * 0.862), Vector3.BACK * sz, 0.07, R[1])
	wear_mesh(hw, hull)
	add_scan(hull, Vector3(-0.169, 0.36, 0), Vector3.RIGHT, Vector3.BACK, 0.6, 0.035, 3.0)
	# Two stacks behind the housing on a hinged foot, the way a stack is made to
	# fold for a low bridge; dead, they fold. They are UNEQUAL and they stand
	# clear of the hull's top line, because a slab whose outline is one unbroken
	# ridge is a slab like any other slab: at 0.32 they cleared the deck by two
	# screen pixels and the whole machine read as a box (art review, wave A).
	var stacks := joint(&"stacks", hull, Vector3(-0.8, 0.3, 0))
	var sk2 := FoundKit.kit()
	FoundKit.tbar(sk2, Vector3(0, 0.0, -0.56), Vector3(0, 0.0, 0.56), 0.03, 0.03, 6, D)
	var stack_h := {-1.0: 0.46, 1.0: 0.66}
	for sz: float in [-1.0, 1.0]:
		var sh: float = stack_h[sz]
		FoundKit.tbar(sk2, Vector3(0, 0.0, sz * 0.5), Vector3(0, sh, sz * 0.5), 0.05, 0.042, 6, R, 0.015)
		FoundKit.spot(sk2, Vector3(0, sh + 0.001, sz * 0.5), Vector3.UP, 0.03, 6, R[0], 0.002)
		# A collar low on each, and on the tall one the rain cap that was bolted
		# back on askew: the two stacks never read as a pair.
		if sz > 0.0:
			FoundKit.disc(sk2, Vector3(0, sh * 0.42, sz * 0.5), Vector3.UP, 0.07, 0.028, 6, 0.008, D, Color(0, 0, 0, 0), PI / 6.0)
			FoundKit.tbar(sk2, Vector3(0, sh + 0.02, sz * 0.5), Vector3(0.055, sh + 0.13, sz * 0.5), 0.016, 0.014, 4, D)
			FoundKit.slab(sk2, Vector3(0.055, sh + 0.13, sz * 0.5), Vector3.RIGHT, Vector3(0.3, 1, 0).normalized(),
				[Vector2(-0.07, -0.06), Vector2(0.07, -0.06), Vector2(0.07, 0.06), Vector2(-0.07, 0.06)], 0.018, D)
	body_mesh(sk2, stacks)

	# The unloading spout: what a harvester is FOR, and the one thing on it that
	# leaves the slab. A ruled arm swung out over the flank with a down-turned
	# chute at its end, braced back to the deck — it fills a hauler running
	# alongside. Everything else about this machine is a rectangle seen from a
	# high camera, and four poses of it were four identical black lozenges (art
	# review, wave A); this is the piece a player can name it by at a hundred
	# tiles, and where it is says whether the machine is working or stopped.
	# Sized in SCREEN pixels, not in taste: a member a tenth of a tile across is
	# under a pixel at play zoom and does nothing for an outline. The tube is
	# almost a fifth of the hull's width, and the arm carries its chute a full
	# hull's depth out over the flank, so there is daylight between arm and deck.
	var spout := joint(&"spout", hull, Vector3(-0.46, 0.4, -0.42))
	var pk := FoundKit.kit()
	# The turret it swings in, then the arm out along -Z, forward and up. The
	# side is not arbitrary: the game's camera never rotates, and on it a metre
	# out toward the viewer costs more screen height than a metre up gains, so an
	# arm thrown over the near flank sinks back into the hull it came off. Over
	# the FAR flank the two add, and the chute stands against the sky.
	FoundKit.tbar(pk, Vector3(0, -0.06, 0), Vector3(0.02, 0.34, -0.04), 0.17, 0.115, 6, R, 0.03)
	var arm_a := Vector3(0.02, 0.34, -0.06)
	var arm_b := Vector3(0.34, 0.92, -1.5)
	FoundKit.tbar(pk, arm_a, arm_b, 0.15, 0.115, 6, R, 0.03)
	# The join is the drawing: a straight brace off the turret to the arm's
	# middle, pinned at both ends, and a flight seam up the tube.
	FoundKit.tbar(pk, Vector3(-0.14, 0.08, -0.16), arm_a.lerp(arm_b, 0.5) + Vector3(-0.1, -0.1, 0), 0.042, 0.03, 4, D)
	FoundKit.seam(pk, arm_a + Vector3(0.0, 0.14, 0), arm_b + Vector3(0.0, 0.13, 0), Vector3.UP, R, 2)
	# The chute: a cone turned down at the end of the arm, flaring at the mouth.
	FoundKit.lathe(pk, arm_b + Vector3(0.04, 0.0, -0.1), Vector3.DOWN, [Vector2(0.13, -0.1), Vector2(0.21, 0.08), Vector2(0.185, 0.38)], 6, R, PI / 6.0)
	body_mesh(pk, spout)
	var pw := FoundKit.kit()
	FoundKit.cable(pw, Vector3(0.1, 0.16, 0.1), arm_a.lerp(arm_b, 0.72) + Vector3(0.0, 0.12, 0), 0.08, 0.018, Palette.INK[2], Palette.MACHINE["lineman"], 3)
	FoundKit.patch(pw, arm_a.lerp(arm_b, 0.34) + Vector3(0.0, 0.15, 0), Vector3.UP, Vector3(0.22, 0.0, -0.97), 0.38, 0.2, Palette.MACHINE["hauler"], 61)
	FoundKit.grime(pw, arm_b + Vector3(0.04, -0.34, -0.1), Vector3(0.1, -0.2, -1.0), 0.3, 0.16, 2, 62, D)
	wear_mesh(pw, spout)
	# What it last poured, caked in the chute's lip and hanging out of it.
	var straw: Array = [Palette.SAND[4], Palette.LINEN[4], Palette.SAND[5], Palette.MOSS[4]]
	var chute := FoundKit.matter_kit(Ink.HAND)
	FoundKit.chaff(chute, arm_b + Vector3(0.04, -0.4, -0.1), Vector3(0.09, 0.03, 0.09), 3, 63, straw, 0.1, 0.05)
	wear_matter(chute, spout)

	for sz: float in [-1.0, 1.0]:
		var lamp := joint(&"lamp_r" if sz > 0 else &"lamp_l", hull, Vector3(0.62, 0.1, sz * 0.66))
		var mk := FoundKit.kit()
		FoundKit.tbar(mk, Vector3(0, -0.1, 0), Vector3(0, 0.3, 0), 0.026, 0.022, 6, D)
		FoundKit.lathe(mk, Vector3(0, 0.34, 0), Vector3.RIGHT, [Vector2(0.04, -0.07), Vector2(0.07, -0.02), Vector2(0.07, 0.05)], 6, R)
		body_mesh(mk, lamp)
		add_lamp(lamp, Vector3(0.051, 0.34, 0), Vector3.RIGHT, Vector3.UP, 0.075, 0.07, &"work", true)

	var intake := joint(&"intake", hull, Vector3(0.86, 0.22, 0))
	var ik := FoundKit.kit()
	var hood: Array[Vector2] = [Vector2(0.0, 0.08), Vector2(0.5, -0.36), Vector2(0.5, -0.52), Vector2(0.08, -0.5)]
	# The hood is the biggest plate on it: body fill, so the lit rim stays on bevels.
	var hood_r: Array = [R[0], R[1], R[2], R[3], R[3], R[5]]
	FoundKit.slab(ik, Vector3.ZERO, Vector3.RIGHT, Vector3.UP, hood, 2.46, hood_r, 0.03)
	FoundKit.rivets(ik, Vector3(0.1, 0.01, -1.1), Vector3(0.1, 0.01, 1.1), Vector3(0.66, 0.75, 0), 6, R[5])
	for sz: float in [-1.0, 1.0]:
		FoundKit.seam(ik, Vector3(0.1, 0.0, sz * 0.4), Vector3(0.46, -0.32, sz * 0.4), Vector3(0.66, 0.75, 0), R, 3)
	# Pointed dividers along the lip: the saw-edge you see coming.
	for j in 6:
		var z := -1.02 + j * 0.41
		FoundKit.lathe(ik, Vector3(0.44, -0.46, z), Vector3(1, -0.22, 0), [Vector2(0.075, 0.0), Vector2(0.06, 0.06), Vector2(0.0, 0.22)], 4, R, PI * 0.25)
	body_mesh(ik, intake)
	for sz: float in [-1.0, 1.0]:
		add_lamp(intake, Vector3(0.501, -0.4, sz * 0.54), Vector3.RIGHT, Vector3.UP, 0.07, 0.05, &"work", true)
	# The lamps' wash on the row ahead, starting past the comb's teeth; hung on
	# the hull so it stays on the ground when the intake pitches.
	add_beam(hull, Vector3(1.72, -0.22, 0), Vector3(1.3, -0.18, 0), 1.5, 2.8, &"work", true)
	var iw := FoundKit.kit()
	FoundKit.grime(iw, Vector3(0.45, -0.3, 0.0), Vector3(0.66, 0.75, 0), 1.8, 0.12, 6, 45, hood_r)
	FoundKit.patch(iw, Vector3(0.22, -0.12, -0.7), Vector3(0.66, 0.75, 0), Vector3(0.75, -0.66, 0), 0.26, 0.2, Palette.MACHINE["lineman"], 46)
	wear_mesh(iw, intake)
	day_wear(intake, Vector3(0.24, -0.15, 0.06), Vector3(0.66, 0.75, 0), Vector3(0.75, -0.66, 0), 2.0, 0.46, 51, 2)
	# The row it could not swallow, jammed in the dividers and lying over the comb
	# at both ends where the camera sees it: straw, a rag dragged up the hood, and
	# a long bone caught across the dividers that sticks out past the end.
	var jam := FoundKit.matter_kit(Ink.HAND)
	# Wads, each a matted heap with stalks standing out of it.
	jam.rock(0.6, -0.45, -0.8, 0.2, 0.16, 470, Palette.SAND[4], 5)
	jam.rock(0.5, -0.4, -0.58, 0.13, 0.12, 471, Palette.LINEN[4], 5)
	jam.rock(0.6, -0.45, 0.5, 0.16, 0.13, 472, Palette.SAND[4], 5)
	FoundKit.chaff(jam, Vector3(0.6, -0.36, -0.78), Vector3(0.12, 0.04, 0.22), 5, 47, straw, 0.12, 0.042)
	FoundKit.chaff(jam, Vector3(0.62, -0.38, 0.48), Vector3(0.1, 0.03, 0.14), 3, 48, straw, 0.11, 0.04)
	FoundKit.bone(jam, Vector3(0.34, -0.34, 0.62), Vector3(0.82, -0.3, 1.32), 0.045, 49)
	# The rag lies up the hood's slope from the lip, the way it was dragged in.
	jam.push(Transform3D(Basis(Vector3.BACK, 0.85), Vector3(0.14, -0.02, -0.18) + Vector3(0.66, 0.75, 0.0) * 0.02))
	FoundKit.rag(jam, Vector3.ZERO, 0.46, 0.24, Palette.LINEN[5], 50, Vector3(0.15, 0, 1))
	jam.pop()
	wear_matter(jam, intake)

	# The comb: long amber teeth running out past the dividers, lit on top, so the
	# dangerous end reads as the soft one from wherever you stand.
	var comb := joint(&"comb", intake, Vector3(0.5, -0.5, 0))
	var ck2 := FoundKit.kit()
	var amber: Array = [Palette.LENS[0], Palette.LENS[1], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3], Palette.LENS[3]]
	for j in 13:
		var z := -1.08 + j * 0.18
		var tooth: Array[Vector2] = [Vector2(-0.04, 0.05), Vector2(0.3, 0.012), Vector2(0.3, -0.012), Vector2(-0.04, -0.05)]
		FoundKit.slab(ck2, Vector3(0, 0, z), Vector3.RIGHT, Vector3.BACK, tooth, 0.045, amber)
	FoundKit.tbar(ck2, Vector3(-0.03, 0, -1.12), Vector3(-0.03, 0, 1.12), 0.035, 0.035, 4, [Palette.LENS[0], Palette.LENS[0], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[2]])
	part_mesh(ck2, comb)
	set_part_anchor(intake, Vector3(0.7, -0.48, 0), 1.0)

	# The row it was cutting, only once it is dead: made of the field, drawn by the hand.
	var spill := Node3D.new()
	add_child(spill)
	var sk := FoundKit.matter_kit(Ink.HAND)
	var stalk: Array[Color] = [Palette.SAND[3], Palette.SAND[4], Palette.MOSS[3], Palette.LINEN[3]]
	for j in 16:
		var a := Rng.hash01(71, j) * TAU
		var dist := 0.2 + Rng.hash01(72, j) * 0.7
		var base := Vector3(1.75 + cos(a) * dist * 0.6, 0.03, sin(a) * dist * 1.5)
		var tip := base + Vector3(cos(a + 1.3), 0.02, sin(a + 1.3)) * (0.22 + Rng.hash01(73, j) * 0.16)
		sk.push(Transform3D(Basis.IDENTITY, Vector3.ZERO))
		FoundKit.bar(sk, base, tip, 0.035, 0.03, 0.0, FoundKit.flat(stalk[j % 4]))
		sk.pop()
	matter_mesh(sk, spill)
	dead_only(spill, LIGHT_FIRST + 0.5)
	finish_rig()


## A slab has no limbs to throw, so every pose is told by where the header sits
## and how the hull rides on its tracks. The rest rig is the machine CUTTING (the
## header down in the row), which is what a walk shows; a harvester stopped, a
## harvester that has seen you and a harvester about to take you are three
## different shapes before any lamp is read.
func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"stand":
			# Stopped: the header lifts out of the row and the stacks stand up.
			# The spout swings in and is cradled back over the deck — a machine at
			# the headland is a machine with nothing under its chute, and the
			# stopped outline is a different outline before any lamp is read.
			d[&"intake"] = pr(Vector3(-0.04, 0.2, 0), Vector3(0, 0, 0.42))
			d[&"hull"] = pr(Vector3(0, 0.05, 0))
			d[&"stacks"] = r(Vector3(0, 0, -0.08))
			d[&"spout"] = r(Vector3(-0.62, 1.46, 0.0))
		&"alert":
			# It has seen you: the header comes down on the ground and stops dead,
			# the hull settles on its springs, two lamp masts run up out of it,
			# and the spout comes round and UP with them: the arm stops being
			# about the field and starts being about you.
			d[&"intake"] = pr(Vector3(0.02, -0.03, 0), Vector3(0, 0, -0.06))
			d[&"hull"] = pr(Vector3(-0.03, -0.13, 0))
			d[&"lamp_l"] = pr(Vector3(0, 0.52, 0))
			d[&"lamp_r"] = pr(Vector3(0, 0.52, 0))
			d[&"spout"] = r(Vector3(0.4, -0.3, 0.0))
		&"windup":
			# The hull rears back on its tracks and the header tips up and OPEN:
			# the side about to take you is the side the eye is sent to.
			# Far enough that the hood's lip clears the hull's own top line: the
			# machine gapes, and the comb comes up with it into plain sight.
			d[&"intake"] = pr(Vector3(0.05, 0.16, 0), Vector3(0, 0, 0.62))
			d[&"hull"] = pr(Vector3(-0.12, 0.09, 0), Vector3(0, 0, 0.13))
			d[&"stacks"] = r(Vector3(0, 0, -0.24))
			d[&"lamp_l"] = pr(Vector3(0, 0.44, 0))
			d[&"lamp_r"] = pr(Vector3(0, 0.44, 0))
			d[&"spout"] = r(Vector3(0.66, -0.48, 0.0))
		&"strike":
			# And throws the whole slab forward: the body moves, not just the hood.
			d[&"intake"] = pr(Vector3(0.12, 0.01, 0), Vector3(0, 0, -0.08))
			d[&"hull"] = pr(Vector3(0.3, -0.05, 0), Vector3(0, 0, -0.04))
			d[&"lamp_l"] = pr(Vector3(0, 0.3, 0), Vector3(0, 0, -0.3))
			d[&"lamp_r"] = pr(Vector3(0, 0.3, 0), Vector3(0, 0, -0.3))
			d[&"spout"] = r(Vector3(0.52, -0.36, 0.0))
		&"dead":
			# Settles listing onto one track; the intake comes down on the ground,
			# the comb drops off it askew, lamps and stacks fold over.
			d[&"hull"] = pr(Vector3(-0.04, -0.1, 0), Vector3(0.17, 0.05, 0.06))
			d[&"intake"] = pr(Vector3(0.02, 0.05, 0), Vector3(-0.1, 0, -0.14))
			d[&"comb"] = pr(Vector3(0.22, 0.2, 0.1), Vector3(-0.03, 0.28, 0.21))
			d[&"lamp_l"] = r(Vector3(-0.7, 0, 0.25))
			d[&"lamp_r"] = r(Vector3(0.45, 0, -0.35))
			d[&"stacks"] = r(Vector3(0, 0, 1.2))
			# The arm comes down where it was, chute into the ground: the wreck
			# keeps the shape that named the machine, broken.
			d[&"spout"] = pr(Vector3(0, -0.06, 0), Vector3(-0.62, 0.34, 0.16))
	return d


func _gait_deltas(phase: float) -> Dictionary:
	return {&"hull": pr(Vector3(0, absf(sin(phase * TAU)) * 0.015, 0), Vector3(0, cos(phase * TAU) * 0.02, sin(phase * TAU) * 0.025))}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	var v := maxf(speed_now, nominal_speed if pose == &"walk" else 0.0)
	_travel += delta * v
	for w in _wheels:
		w.rotation.z = -_travel / WHEEL_R
	_comb_t += delta
	(joints[&"comb"] as Node3D).position.z = (0.05 if fposmod(_comb_t, 0.34) < 0.17 else -0.05)
