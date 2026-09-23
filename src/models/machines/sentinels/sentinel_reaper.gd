extends MachineModel
## THE REAPER: the Coast's keeper (docs/VISION.md, src/core/sentinel/designs/
## tide_reaper.gd). A reaping gantry — a portal frame on two track units, a ruled
## beam across the top of it, and a drum of amber teeth slung under the front.
##
## Why an ARCH. Every machine in this game is a mass seen from a high camera, and
## the sentinels are meant to be unforgettable in silhouette at 640x360 (VISION §3,
## "look"). The one shape nothing else in the game has is a shape with DAYLIGHT
## THROUGH IT: two legs, a beam, and a gap a player can walk under. At a hundred
## tiles it is a gate standing on the turf where no gate should be; at fighting
## range the gap is where the drum is, which is the one place a blow counts.
##
## It is drawn by a ruler, like every machine: the legs are raked at one angle and
## braced at one more, the beam is a straight run of plate with its lattice on
## exact pitch, and the only curves on it are turned ones (the drum, the winch, the
## chute's mouth). Its colour is the KEEPER's ramp — the deep indigo of the warden,
## because that is what the palette gives a body that holds a site (Palette:
## "the MACHINE ramps run one arc by ROLE") — so it reads as the biggest keeper on
## the coast rather than as a new kind of thing.
##
## Poses. An arch has one enormous advantage: the frame itself can move.
## walk   REAPING: the drum down in the row, the frame rocking on its tracks
## stand  stopped: the drum wound up clear of the ground, the chute cradled back
## alert  it has you: the frame settles, the head comes down and round, both lamp
##        masts run up off the beam, the drum stops dead
## windup the whole arch REARS BACK and the drum swings up and forward into plain
##        sight — the thing about to take you is the thing you have to hit
## strike the arch throws forward over its front axles, drum down and through
## hurt   the drum's light stutters out; nothing flinches
## dead   one leg folds and the beam comes down across the ground: the arch, broken,
##        which is the only silhouette on the coast that says a sentinel died here
##
## lights work lamps on the two masts and under the beam, a cold optic in the head
##        with a scan travelling its slit, and the plan strip along the beam's face
##        where a high camera cannot miss it
## wear   the row it could not swallow jammed in the drum, plate off four other
##        kinds bolted over its legs, a winch cable slung under the beam, salt
##        streaks down everything that faces the sea

## Track units, legs and beam: the numbers the whole body is ruled from.
const TRACK_Z := 1.12
const TRACK_TOP := 0.5
const HULL_Y := 0.52
const BEAM_Y := 2.02
const BEAM_HALF := 1.34
const WHEEL_R := 0.155

var _travel := 0.0
var _drum_t := 0.0
var _wheels: Array[Node3D] = []


func build() -> void:
	part_side = &"front"
	# The beam, not the deck: a tell drawn over this body must clear the arch.
	height = 2.75
	stride = 2.0
	gallery_turn = 34.0
	# A working part this big cannot burn as hard as a comb a hand's width across:
	# at the default it came out of the camera as a bar of white with no amber left
	# in it, and the palette gives the LENS to the machines as their one saturated
	# colour, not as a hole in the page (docs/LOOK.md).
	emission = 0.26
	begin_rig()
	# A keeper's ramp: this is the biggest thing on the coast that HOLDS a place,
	# and the palette says a body's colour is its role (Palette.MACHINE).
	ramp = Palette.MACHINE["warden"]
	disposition = &"wary"
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	_tracks(D, DD, R)
	var hull := joint(&"hull", self, Vector3(0, HULL_Y, 0))
	_carriage(hull, R, D)
	# The frame is the arch: both legs and the beam ride on it, so a pose can rear
	# the whole gantry back on its tracks and the machine still holds together.
	var frame := joint(&"frame", hull, Vector3(0, 0, 0))
	_legs(frame, R, D, DD)
	var beam := joint(&"beam", frame, Vector3(0, BEAM_Y, 0))
	_beam(beam, R, D)
	_head(beam, R, D)
	_masts(beam, D)
	_chute(beam, R, D)
	_drum(frame, R, D)
	finish_rig()


## Two track units, wide apart, with road wheels that turn: the arch stands on
## them and they never pitch with it.
func _tracks(D: Array, DD: Array, R: Array) -> void:
	var shape: Array[Vector2] = [Vector2(1.06, 0.3), Vector2(0.88, TRACK_TOP), Vector2(-0.92, TRACK_TOP),
		Vector2(-1.1, 0.3), Vector2(-1.1, 0.16), Vector2(-0.92, 0.0), Vector2(0.88, 0.0), Vector2(1.06, 0.16)]
	for sz: float in [-1.0, 1.0]:
		var tk := FoundKit.kit()
		FoundKit.slab(tk, Vector3(0, 0, sz * TRACK_Z), Vector3.RIGHT, Vector3.UP, shape, 0.46, DD, 0.02)
		# The track plates, on exact pitch: the order a machine lays down.
		for j in 9:
			FoundKit.mark(tk, Vector3(-0.84 + j * 0.21, TRACK_TOP + 0.002, sz * TRACK_Z), Vector3.UP, Vector3.BACK, 0.44, 0.05, R[0], 0.002)
		FoundKit.mark(tk, Vector3(-0.02, 0.24, sz * (TRACK_Z + 0.231)), Vector3.BACK * sz, Vector3.UP, 1.8, 0.28, R[0], 0.002)
		FoundKit.rivets(tk, Vector3(-0.86, 0.42, sz * (TRACK_Z + 0.232)), Vector3(0.86, 0.42, sz * (TRACK_Z + 0.232)), Vector3.BACK * sz, 7, R[5])
		body_mesh(tk, self)
		var sw := FoundKit.kit()
		FoundKit.streaks(sw, Vector3(0.0, 0.44, sz * (TRACK_Z + 0.232)), Vector3.BACK * sz, 1.5, 0.3, 5, 11 + int(sz), R[1])
		FoundKit.dirt_line(sw, Vector3(-1.0, 0.06, sz * (TRACK_Z + 0.232)), Vector3(1.0, 0.06, sz * (TRACK_Z + 0.232)), Vector3.BACK * sz, 0.09, R[1])
		wear_mesh(sw, self)
		for x: float in [-0.66, 0.0, 0.66]:
			var w := Node3D.new()
			w.position = Vector3(x, 0.25, sz * (TRACK_Z + 0.25))
			add_child(w)
			var wk := FoundKit.kit()
			FoundKit.disc(wk, Vector3.ZERO, Vector3.BACK, WHEEL_R, 0.06, 6, 0.014, D, D[2], PI / 6.0)
			FoundKit.spot(wk, Vector3(0, 0, sz * 0.031), Vector3.BACK * sz, 0.05, 6, R[4], 0.002)
			body_mesh(wk, w)
			_wheels.append(w)


## The cross member between the tracks, low down: what the legs stand on.
func _carriage(hull: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	# Narrow, and set back: the gap under the arch is the whole drawing, so the
	# carriage crosses behind the legs and nothing fills the middle.
	var plan := FoundKit.plan_oct(0.86, 2.4, 0.18)
	var back := Vector2(-0.52, 0.0)
	FoundKit.loft(k, [FoundKit.ring(plan, -0.16, 0.05, Vector2.ONE, back), FoundKit.ring(plan, -0.06, 0.0, Vector2.ONE, back),
		FoundKit.ring(plan, 0.1, 0.02, Vector2.ONE, back), FoundKit.ring(plan, 0.16, 0.1, Vector2.ONE, back)], R, true)
	FoundKit.seam(k, Vector3(-0.52, 0.161, -0.9), Vector3(-0.52, 0.161, 0.9), Vector3.UP, R, 4)
	FoundKit.panel(k, Vector3(-0.3, 0.161, 0.0), Vector3.UP, Vector3.RIGHT, 0.4, 0.7, R)
	# The winch drum that lifts the reaping head, turned and ribbed, on the deck.
	FoundKit.lathe(k, Vector3(-0.52, 0.22, 0.0), Vector3.BACK, [Vector2(0.11, -0.34), Vector2(0.14, -0.28), Vector2(0.14, 0.28), Vector2(0.11, 0.34)], 8, D, PI / 8.0)
	body_mesh(k, hull)
	day_wear(hull, Vector3(-0.4, 0.163, -0.6), Vector3.UP, Vector3.RIGHT, 0.5, 0.5, 63, 1)
	var w := FoundKit.kit()
	FoundKit.patch(w, Vector3(-0.5, 0.162, 0.66), Vector3.UP, Vector3.RIGHT, 0.34, 0.3, Palette.MACHINE["hauler"], 64)
	FoundKit.scorch(w, Vector3(-0.8, 0.162, -0.5), Vector3.UP, 0.12, 65)
	wear_mesh(w, hull)


## Two raked legs a side, braced: the uprights of the arch. Rake and brace are at
## ONE angle each, because the FOUND is ruler-straight and the eye reads the repeat.
func _legs(frame: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	for sz: float in [-1.0, 1.0]:
		var foot_f := Vector3(0.44, 0.0, sz * TRACK_Z)
		var foot_b := Vector3(-0.5, 0.0, sz * TRACK_Z)
		var top_f := Vector3(0.2, BEAM_Y - 0.06, sz * (BEAM_HALF - 0.16))
		var top_b := Vector3(-0.22, BEAM_Y - 0.06, sz * (BEAM_HALF - 0.16))
		FoundKit.tbar(k, foot_f, top_f, 0.15, 0.1, 6, R, 0.03)
		FoundKit.tbar(k, foot_b, top_b, 0.15, 0.1, 6, R, 0.03)
		# One brace across the pair, and one diagonal: the lattice the ruler drew.
		FoundKit.tbar(k, foot_f.lerp(top_f, 0.46), foot_b.lerp(top_b, 0.46), 0.055, 0.055, 4, D)
		FoundKit.tbar(k, foot_f.lerp(top_f, 0.14), foot_b.lerp(top_b, 0.7), 0.04, 0.04, 4, DD)
		FoundKit.rivets(k, foot_f + Vector3(0, 0.1, 0), top_f - Vector3(0, 0.2, 0), Vector3.RIGHT, 5, R[5])
	# And one brace across the gap, high up under the beam, so the arch is a frame
	# and not two posts: it also stops the gap reading as empty sky at play zoom.
	FoundKit.tbar(k, Vector3(-0.12, BEAM_Y - 0.3, -BEAM_HALF + 0.2), Vector3(-0.12, BEAM_Y - 0.3, BEAM_HALF - 0.2), 0.05, 0.05, 4, D)
	body_mesh(k, frame)
	var w := FoundKit.kit()
	for sz: float in [-1.0, 1.0]:
		FoundKit.streaks(w, Vector3(0.44, 1.2, sz * (TRACK_Z + 0.01)), Vector3.RIGHT, 0.2, 0.5, 3, 71 + int(sz), R[1])
	FoundKit.patch(w, Vector3(0.28, 0.9, TRACK_Z + 0.09), Vector3.BACK, Vector3.UP, 0.3, 0.34, Palette.MACHINE["cutter"], 72)
	FoundKit.patch(w, Vector3(-0.36, 1.1, -TRACK_Z - 0.09), Vector3.FORWARD, Vector3.UP, 0.26, 0.3, Palette.MACHINE["lineman"], 73)
	wear_mesh(w, frame)


## The beam: one straight run of plate across the top, its lattice on exact pitch,
## with the plan strip along the face the camera always sees.
func _beam(beam: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	var section: Array[Vector2] = [Vector2(0.3, 0.2), Vector2(0.34, 0.1), Vector2(0.3, -0.16), Vector2(-0.3, -0.2), Vector2(-0.34, 0.06), Vector2(-0.3, 0.2)]
	FoundKit.slab(k, Vector3.ZERO, Vector3.RIGHT, Vector3.UP, section, BEAM_HALF * 2.0, R, 0.04)
	# The web under it: uprights on exact pitch between the two chords.
	for j in 9:
		var z := -BEAM_HALF + 0.2 + j * ((BEAM_HALF * 2.0 - 0.4) / 8.0)
		FoundKit.tbar(k, Vector3(0.24, -0.18, z), Vector3(-0.24, -0.18, z), 0.035, 0.035, 4, D)
	FoundKit.tbar(k, Vector3(0.0, -0.2, -BEAM_HALF + 0.1), Vector3(0.0, -0.2, BEAM_HALF - 0.1), 0.06, 0.06, 4, D)
	FoundKit.seam(k, Vector3(0.0, 0.201, -BEAM_HALF + 0.1), Vector3(0.0, 0.201, BEAM_HALF - 0.1), Vector3.UP, R, 6)
	for sz: float in [-1.0, 1.0]:
		FoundKit.rivets(k, Vector3(0.28, 0.18, sz * (BEAM_HALF - 0.3)), Vector3(-0.28, 0.18, sz * (BEAM_HALF - 0.3)), Vector3.UP, 4, R[5])
	body_mesh(k, beam)
	# What the plan thinks of you, counted in lit segments, on the top face of the
	# beam: the one plate a high camera can never miss on this body.
	add_lamp(beam, Vector3(0.06, 0.203, 0.5), Vector3.UP, Vector3.RIGHT, 0.085, 0.085, &"status")
	day_wear(beam, Vector3(0.0, 0.204, -0.5), Vector3.UP, Vector3.RIGHT, 0.5, 0.5, 81, 1)
	var w := FoundKit.kit()
	FoundKit.grime(w, Vector3(0.341, 0.1, 0.0), Vector3.RIGHT, 2.2, 0.16, 6, 82, R)
	FoundKit.cable(w, Vector3(0.2, -0.18, -BEAM_HALF + 0.3), Vector3(0.2, -0.18, BEAM_HALF - 0.3), 0.14, 0.022, Palette.INK[2], Palette.MACHINE["lineman"], 5)
	wear_mesh(w, beam)


## The head: a cold slit hung under the middle of the beam, with a highlight that
## travels it. It is the only part of the machine at a person's height.
func _head(beam: Node3D, R: Array, D: Array) -> void:
	var head := joint(&"head", beam, Vector3(0.1, -0.3, 0.0))
	var k := FoundKit.kit()
	var box := FoundKit.plan_oct(0.44, 0.7, 0.12)
	FoundKit.loft(k, [FoundKit.ring(box, -0.3, 0.06), FoundKit.ring(box, -0.2), FoundKit.ring(box, 0.0, 0.01), FoundKit.ring(box, 0.06, 0.07)], R, true)
	FoundKit.visor(k, Vector3(0.221, -0.12, 0.0), Vector3.RIGHT, Vector3.UP, 0.46, 0.05)
	FoundKit.ticks(k, Vector3(0.221, -0.24, -0.2), Vector3(0.221, -0.24, 0.2), Vector3.RIGHT, 5, R[1])
	body_mesh(k, head)
	add_scan(head, Vector3(0.223, -0.12, 0.0), Vector3.RIGHT, Vector3.BACK, 0.4, 0.04, 2.8)
	var w := FoundKit.kit()
	FoundKit.streaks(w, Vector3(0.222, -0.06, 0.0), Vector3.RIGHT, 0.4, 0.22, 3, 91, R[1])
	wear_mesh(w, head)


## Two lamp masts standing off the beam's ends: what runs up when it has you.
func _masts(beam: Node3D, D: Array) -> void:
	for sz: float in [-1.0, 1.0]:
		var mast := joint(&"mast_r" if sz > 0.0 else &"mast_l", beam, Vector3(0.1, 0.16, sz * (BEAM_HALF - 0.42)))
		var k := FoundKit.kit()
		FoundKit.tbar(k, Vector3(0, -0.1, 0), Vector3(0, 0.34, 0), 0.035, 0.028, 6, D)
		FoundKit.lathe(k, Vector3(0, 0.38, 0), Vector3.RIGHT, [Vector2(0.05, -0.08), Vector2(0.085, -0.02), Vector2(0.085, 0.06)], 6, D)
		body_mesh(k, mast)
		add_lamp(mast, Vector3(0.061, 0.38, 0), Vector3.RIGHT, Vector3.UP, 0.08, 0.075, &"work", true)
	# The wash those lamps lay on the row ahead of the drum, on the ground.
	add_beam(beam, Vector3(1.5, -1.3, 0.0), Vector3(1.4, -0.5, 0.0), 2.6, 3.2, &"work", true)


## The spoil chute over its back: a ruled arm off the beam with the mouth turned
## down, which is what fills a hauler running behind it. It is also what makes the
## arch asymmetrical from every angle, so the two sides of it never read the same.
func _chute(beam: Node3D, R: Array, D: Array) -> void:
	var chute := joint(&"chute", beam, Vector3(-0.26, 0.04, 0.0))
	var k := FoundKit.kit()
	var a := Vector3(0.0, 0.1, 0.0)
	var b := Vector3(-0.85, 0.62, -0.95)
	FoundKit.tbar(k, Vector3(0.1, -0.1, 0.0), a, 0.17, 0.13, 6, R, 0.03)
	FoundKit.tbar(k, a, b, 0.14, 0.11, 6, R, 0.03)
	FoundKit.tbar(k, Vector3(0.12, -0.08, -0.2), a.lerp(b, 0.55) + Vector3(0.06, -0.1, 0.0), 0.04, 0.032, 4, D)
	FoundKit.seam(k, a + Vector3(0, 0.12, 0), b + Vector3(0, 0.11, 0), Vector3.UP, R, 3)
	FoundKit.lathe(k, b + Vector3(-0.04, 0.0, -0.08), Vector3.DOWN, [Vector2(0.12, -0.08), Vector2(0.2, 0.08), Vector2(0.175, 0.34)], 6, R, PI / 6.0)
	body_mesh(k, chute)
	var w := FoundKit.kit()
	FoundKit.grime(w, b + Vector3(-0.04, -0.3, -0.08), Vector3(0.1, -0.2, -1.0), 0.3, 0.16, 2, 95, D)
	wear_mesh(w, chute)
	# What it last poured, caked in the mouth and hanging out of it: the turf of
	# the coast, drawn by the hand, on a machine drawn by a ruler.
	var straw: Array = [Palette.SAND[4], Palette.LINEN[4], Palette.MOSS[4], Palette.SAND[5]]
	var m := FoundKit.matter_kit(Ink.HAND)
	FoundKit.chaff(m, b + Vector3(-0.04, -0.36, -0.08), Vector3(0.1, 0.03, 0.1), 3, 96, straw, 0.11, 0.05)
	wear_matter(m, chute)


## The drum: the reaping head slung under the front of the arch on its own arm,
## a turned barrel of amber teeth. The working part, the dangerous end and the
## softest-looking thing on the machine, all at once.
func _drum(frame: Node3D, R: Array, D: Array) -> void:
	# Slung off the FRONT of the arch, not inside it: the gap between the legs is
	# the whole silhouette and nothing may fill it. The drum hangs where a reaping
	# head hangs, out in front of the tracks and low enough to take a person.
	var arm := joint(&"arm", frame, Vector3(0.86, 1.46, 0.0))
	var k := FoundKit.kit()
	for sz: float in [-1.0, 1.0]:
		FoundKit.tbar(k, Vector3(-0.12, 0.08, sz * 0.86), Vector3(0.28, -1.1, sz * 1.0), 0.1, 0.075, 6, R, 0.02)
		FoundKit.tbar(k, Vector3(-0.1, -0.5, sz * 0.9), Vector3(0.3, -0.62, sz * 1.0), 0.04, 0.032, 4, D)
	# The hood over the drum: a plate that keeps the amber a slot of light and not
	# a bare cylinder, and the thing a blow into the front actually rings off.
	var hood: Array[Vector2] = [Vector2(-0.16, -0.5), Vector2(0.4, -0.86), Vector2(0.4, -1.1), Vector2(-0.2, -0.96)]
	FoundKit.slab(k, Vector3(0.0, 0.0, 0.0), Vector3.RIGHT, Vector3.UP, hood, 2.0, R, 0.03)
	for sz: float in [-1.0, 1.0]:
		FoundKit.seam(k, Vector3(-0.06, -0.64, sz * 0.5), Vector3(0.34, -0.9, sz * 0.5), Vector3(0.55, 0.84, 0), R, 3)
	FoundKit.rivets(k, Vector3(-0.1, -0.62, -0.92), Vector3(-0.1, -0.62, 0.92), Vector3(0.55, 0.84, 0), 8, R[5])
	# Pointed dividers along its lip: the saw-edge you see coming.
	for j in 7:
		var z := -0.9 + j * 0.3
		FoundKit.lathe(k, Vector3(0.38, -1.16, z), Vector3(1, -0.3, 0), [Vector2(0.075, 0.0), Vector2(0.06, 0.07), Vector2(0.0, 0.24)], 4, R, PI * 0.25)
	body_mesh(k, arm)
	day_wear(arm, Vector3(0.1, -0.74, 0.1), Vector3(0.55, 0.84, 0), Vector3(0.84, -0.55, 0), 1.7, 0.36, 101, 2)
	var w := FoundKit.kit()
	FoundKit.grime(w, Vector3(0.3, -0.86, 0.0), Vector3(0.55, 0.84, 0), 1.6, 0.14, 5, 102, R)
	FoundKit.patch(w, Vector3(0.02, -0.66, -0.6), Vector3(0.55, 0.84, 0), Vector3(0.84, -0.55, 0), 0.28, 0.2, Palette.MACHINE["dredger"], 103)
	wear_mesh(w, arm)
	# The row it could not swallow, jammed in the dividers where the camera sees it.
	var jam := FoundKit.matter_kit(Ink.HAND)
	jam.rock(0.36, -1.12, -0.72, 0.18, 0.14, 470, Palette.SAND[4], 5)
	jam.rock(0.34, -1.08, 0.58, 0.14, 0.12, 471, Palette.LINEN[4], 5)
	FoundKit.chaff(jam, Vector3(0.36, -1.04, -0.7), Vector3(0.11, 0.04, 0.2), 5, 472, [Palette.SAND[4], Palette.MOSS[4], Palette.LINEN[4], Palette.SAND[5]], 0.12, 0.042)
	FoundKit.bone(jam, Vector3(0.16, -1.02, 0.5), Vector3(0.56, -0.96, 1.15), 0.05, 473)
	wear_matter(jam, arm)

	# The drum itself: a turned barrel of amber, big enough to be the thing the eye
	# goes to on a machine this size. It is the working part, and at 640x360 a
	# working part that reads as three pixels is a working part nobody aims at.
	var drum := joint(&"drum", arm, Vector3(0.3, -1.2, 0.0))
	var dk := FoundKit.kit()
	# The barrel takes the DARK end of the amber and the teeth the bright end, so
	# the drum reads as ribbed light and not as one blown bar.
	var barrel: Array = [Palette.LENS[0], Palette.LENS[0], Palette.LENS[1], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2]]
	var amber: Array = [Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3], Palette.LENS[3]]
	FoundKit.lathe(dk, Vector3(0, 0, -0.92), Vector3.BACK, [Vector2(0.16, 0.0), Vector2(0.21, 0.07), Vector2(0.21, 1.77), Vector2(0.16, 1.84)], 8, barrel, PI / 8.0)
	# Teeth in rows round it: what makes the drum read as a drum and not a tube.
	for j in 6:
		var a := j * TAU / 6.0
		for i in 4:
			var z := -0.6 + i * 0.4
			var at := Vector3(cos(a) * 0.21, sin(a) * 0.21, z)
			var out := Vector3(cos(a), sin(a), 0.0)
			FoundKit.slab(dk, at + out * 0.06, out, Vector3.BACK,
				[Vector2(-0.06, 0.05), Vector2(0.12, 0.014), Vector2(0.12, -0.014), Vector2(-0.06, -0.05)], 0.05, amber)
	part_mesh(dk, drum)
	set_part_anchor(arm, Vector3(0.5, -1.2, 0.0), 1.1)


## A slab has no limbs; an arch has the whole frame. Every pose here is the gantry
## itself moving, so the shape says what it is doing before any lamp is read.
func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"stand":
			# Stopped at the headland: the drum wound up clear of the ground, the
			# chute cradled back in over the deck, the frame high on its springs.
			d[&"arm"] = pr(Vector3(-0.06, 0.34, 0), Vector3(0, 0, 0.5))
			d[&"frame"] = pr(Vector3(0, 0.04, 0))
			d[&"chute"] = r(Vector3(0.0, 1.3, 0.0))
			d[&"head"] = r(Vector3(0, 0, 0.12))
		&"alert":
			# It has you: the frame settles, the head comes down and round, both
			# masts run up off the beam, and the drum stops dead on the ground.
			d[&"frame"] = pr(Vector3(-0.04, -0.1, 0))
			d[&"arm"] = pr(Vector3(0.04, -0.04, 0), Vector3(0, 0, -0.08))
			d[&"head"] = pr(Vector3(0.06, -0.14, 0), Vector3(0, 0, -0.1))
			d[&"mast_l"] = pr(Vector3(0, 0.5, 0))
			d[&"mast_r"] = pr(Vector3(0, 0.5, 0))
			d[&"chute"] = r(Vector3(0.0, 0.34, 0.0))
		&"windup":
			# The arch rears back on its tracks and the drum swings UP and forward
			# into plain sight: the eye is sent to the side that is about to take
			# it, which is also the side that has to be hit.
			d[&"frame"] = pr(Vector3(-0.16, 0.1, 0), Vector3(0, 0, 0.16))
			d[&"arm"] = pr(Vector3(0.16, 0.3, 0), Vector3(0, 0, 0.66))
			d[&"head"] = pr(Vector3(0.0, -0.08, 0), Vector3(0, 0, -0.18))
			d[&"mast_l"] = pr(Vector3(0, 0.42, 0))
			d[&"mast_r"] = pr(Vector3(0, 0.42, 0))
			d[&"chute"] = r(Vector3(0.0, 0.5, 0.0))
		&"strike":
			# And throws the whole gantry forward over its front axles.
			d[&"frame"] = pr(Vector3(0.34, -0.06, 0), Vector3(0, 0, -0.1))
			d[&"arm"] = pr(Vector3(0.1, -0.1, 0), Vector3(0, 0, -0.16))
			d[&"mast_l"] = pr(Vector3(0, 0.26, 0), Vector3(0, 0, -0.3))
			d[&"mast_r"] = pr(Vector3(0, 0.26, 0), Vector3(0, 0, -0.3))
		&"hurt":
			d[&"head"] = r(Vector3(0, 0, 0.1))
		&"dead":
			# One leg folds and the beam comes down across the ground: the arch is
			# broken, and the gap that named the machine is gone.
			d[&"frame"] = pr(Vector3(-0.1, -0.24, 0.2), Vector3(0.34, 0.06, 0.4))
			d[&"arm"] = pr(Vector3(0.1, -0.3, 0), Vector3(-0.1, 0, -0.5))
			d[&"drum"] = pr(Vector3(0.1, -0.16, 0.14), Vector3(0.2, 0.3, 0.2))
			d[&"chute"] = pr(Vector3(0, -0.1, 0), Vector3(-0.3, 0.9, 0.2))
			d[&"mast_l"] = r(Vector3(-0.8, 0, 0.3))
			d[&"mast_r"] = r(Vector3(0.5, 0, -0.4))
			d[&"head"] = r(Vector3(0, 0, 0.5))
	return d


func _gait_deltas(phase: float) -> Dictionary:
	return {
		&"frame": pr(Vector3(0, absf(sin(phase * TAU)) * 0.018, 0), Vector3(0, cos(phase * TAU) * 0.018, sin(phase * TAU) * 0.022)),
		&"arm": r(Vector3(0, 0, sin(phase * TAU + 1.0) * 0.03)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	var v := maxf(speed_now, nominal_speed if pose == &"walk" else 0.0)
	_travel += delta * v
	for w in _wheels:
		w.rotation.z = -_travel / WHEEL_R
	# The drum never stops turning while there is power in it: exact, not noisy.
	_drum_t += delta
	(joints[&"drum"] as Node3D).rotation.z = _drum_t * 5.5
