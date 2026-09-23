extends MachineModel
## THE UNBUILDER: the Ruined Metropolis's keeper (docs/VISION.md §3,
## src/core/sentinel/designs/unbuilder.gd). A gantry crane that straddles a
## street on four lattice legs, a box girder across their tops, a cab riding
## the girder and a grab hung from a trolley on two cables. Ten units tall.
##
## Why a GANTRY, and why so tall. The reaper is an arch and the rake a delta on
## stilts, and no two keepers may share a silhouette (VISION §3). This one is
## built out of HEIGHT: the play camera shows fifteen units and a thing of
## height h takes 0.545h of them up the screen, so a ten-unit frame is a
## quarter of the picture standing over the street — a doorway with the sky in
## it from the far end of a block, and at fighting range nothing but legs and a
## grab coming down. It is the only machine in the game a player fights under.
##
## Ruled, like every machine: the legs are two chords and a zigzag on exact
## pitch, the girder is one straight run with its rivets on pitch, and the only
## turned things on it are the sheaves, the winch and the grab's hub. Its colour
## is the KEEPER's ramp (Palette: a machine's colour is its role).
##
## Poses. The frame never walks; what moves is what hangs from it.
## walk   SORTING: the carriage rolls on its bogies and the grab sways with the
##        travel, an exact pendulum
## stand  stopped over a marked tile: the grab wound up under the trolley, its
##        tines shut
## alert  it has you: the trolley runs out over the street, the grab comes down
##        to a person's height and the tines open
## windup the cable pays out — the grab sinks, wide open, and the whole pendulum
##        is drawn back along the street
## strike the grab slams to the ground and the tines snap shut
## hurt   the grab swings off sideways on its cable; nothing flinches
## dead   the legs on one side fold, the girder comes down across the street
##        and the grab is flung out on its cable: the doorway is gone
##
## lights the plan strip on the girder's top (seen from above, always), cold
##        optics on the cab, work lamps low on the front sill washing the
##        street, and one over the winch that goes hot through a windup
## wear   concrete dust up every leg, plate off other kinds patched over the
##        chords, grime down the cab, and rubble caught in the grab

const LEG_X := 1.6
const LEG_Z := 2.5
const SILL_Y := 0.55
const BRIDGE_Y := 9.3
## How far below the trolley's sheaves the grab hangs at rest (the fight's
## height: tines at a person's head). `stand` winds it up, a strike drops it.
const HANG := 5.3
const WHEEL_R := 0.17
## The lower cable is drawn on the grab and runs this far up INSIDE the upper
## cable, thicker, so the grab can drop up to this much and the line stays whole
## (a pose cannot lengthen a cable; two coaxial runs can overlap).
const OVERLAP := 1.6

var _travel := 0.0
var _winch_t := 0.0
var _wheels: Array[Node3D] = []


func build() -> void:
	part_side = &"back"
	# The girder, plus the rail on it: what a tell over this body must clear.
	height = 10.0
	stride = 2.4
	gallery_turn = 30.0
	# A working part the size of a winch drum burns to white at the default and
	# the amber goes out of it (docs/ART.md §5), as the reaper's drum did.
	emission = 0.28
	begin_rig()
	ramp = Palette.MACHINE["warden"]
	disposition = &"wary"
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var carriage := joint(&"carriage", self, Vector3.ZERO)
	_sills(carriage, R, D, DD)
	_winch(carriage, R, D)
	var frame := joint(&"frame", carriage, Vector3.ZERO)
	_legs(frame, R, D, DD)
	var bridge := joint(&"bridge", frame, Vector3(0, BRIDGE_Y, -LEG_Z))
	_girder(bridge, R, D)
	_cab(bridge, R, D)
	var trolley := joint(&"trolley", bridge, Vector3(0, -0.36, LEG_Z - 0.6))
	_trolley(trolley, R, D)
	var hang := joint(&"hang", trolley, Vector3(0, -1.05, 0))
	_cables(hang)
	var grab := joint(&"grab", hang, Vector3(0, -HANG, 0))
	_grab(grab, R, D, DD)
	finish_rig()


## Two sills the legs stand on, running along the street on bogie wheels, and
## the two cross-sills that tie them into a carriage. The gap between is the
## street, and nothing fills it.
func _sills(carriage: Node3D, R: Array, D: Array, DD: Array) -> void:
	var section: Array[Vector2] = [Vector2(2.3, 0.14), Vector2(2.14, 0.0), Vector2(-2.14, 0.0), Vector2(-2.3, 0.14),
		Vector2(-2.3, SILL_Y - 0.12), Vector2(-2.14, SILL_Y), Vector2(2.14, SILL_Y), Vector2(2.3, SILL_Y - 0.12)]
	for sz: float in [-1.0, 1.0]:
		var k := FoundKit.kit()
		FoundKit.slab(k, Vector3(0, 0, sz * LEG_Z), Vector3.RIGHT, Vector3.UP, section, 0.5, DD, 0.02)
		# Track plates along the top, on exact pitch: the order a machine lays.
		for j in 10:
			FoundKit.mark(k, Vector3(-2.0 + j * 0.44, SILL_Y + 0.002, sz * LEG_Z), Vector3.UP, Vector3.BACK, 0.4, 0.06, R[0], 0.002)
		FoundKit.rivets(k, Vector3(-2.0, 0.42, sz * (LEG_Z + 0.252)), Vector3(2.0, 0.42, sz * (LEG_Z + 0.252)), Vector3.BACK * sz, 8, R[5])
		body_mesh(k, carriage)
		var w := FoundKit.kit()
		FoundKit.dirt_line(w, Vector3(-2.2, 0.08, sz * (LEG_Z + 0.252)), Vector3(2.2, 0.08, sz * (LEG_Z + 0.252)), Vector3.BACK * sz, 0.1, R[1])
		FoundKit.streaks(w, Vector3(0.6 * sz, 0.44, sz * (LEG_Z + 0.252)), Vector3.BACK * sz, 1.6, 0.3, 4, 11 + int(sz), R[1])
		wear_mesh(w, carriage)
		for x: float in [-1.5, 0.0, 1.5]:
			var wheel := Node3D.new()
			wheel.position = Vector3(x, WHEEL_R, sz * (LEG_Z + 0.31))
			carriage.add_child(wheel)
			var wk := FoundKit.kit()
			FoundKit.disc(wk, Vector3.ZERO, Vector3.BACK, WHEEL_R, 0.08, 6, 0.016, D, D[2], PI / 6.0)
			FoundKit.spot(wk, Vector3(0, 0, sz * 0.041), Vector3.BACK * sz, 0.05, 6, R[4], 0.002)
			body_mesh(wk, wheel)
			_wheels.append(wheel)
	# The cross-sills: what the machine is stopped by, and what a body walking
	# the street is stopped by (its roster radius is this carriage).
	var ck := FoundKit.kit()
	for sx: float in [-1.0, 1.0]:
		FoundKit.tbar(ck, Vector3(sx * 2.0, 0.34, -LEG_Z + 0.2), Vector3(sx * 2.0, 0.34, LEG_Z - 0.2), 0.14, 0.14, 6, D, 0.03)
		FoundKit.rivets(ck, Vector3(sx * 2.0, 0.48, -LEG_Z + 0.5), Vector3(sx * 2.0, 0.48, LEG_Z - 0.5), Vector3.UP, 5, R[5])
	body_mesh(ck, carriage)
	# The work lamps, low on the front sill, and the wash they lay on the street
	# ahead: a machine this tall lights the ground from its feet, because a beam
	# thrown from nine units up has to be nine units long to reach anything.
	for sz: float in [-1.0, 1.0]:
		add_lamp(carriage, Vector3(2.145, 0.4, sz * 1.3), Vector3.RIGHT, Vector3.UP, 0.08, 0.07, &"work")
	add_beam(carriage, Vector3(2.2, 0.36, 0.0), Vector3(1.5, -0.4, 0.0), 3.4, 3.0, &"work")
	day_marks(carriage, Vector3(2.0, 0.34, 1.6), Vector3.RIGHT, Vector3.UP, 0.3, 0.2, 21)


## The winch that pays the grab's cable out, low on the back cross-sill: the
## working part while it sorts, at a hand's height where a blow can reach it.
func _winch(carriage: Node3D, R: Array, D: Array) -> void:
	var winch := joint(&"winch", carriage, Vector3(-2.0, 0.78, 0.0))
	var hk := FoundKit.kit()
	# The housing: two cheeks the drum turns between, and a guard over it.
	for sz: float in [-1.0, 1.0]:
		var cheek: Array[Vector2] = [Vector2(-0.34, -0.3), Vector2(0.3, -0.3), Vector2(0.36, 0.0), Vector2(0.3, 0.34), Vector2(-0.34, 0.34), Vector2(-0.4, 0.0)]
		FoundKit.slab(hk, Vector3(0, 0, sz * 0.66), Vector3.RIGHT, Vector3.UP, cheek, 0.06, R, 0.012)
	FoundKit.tbar(hk, Vector3(0.1, 0.4, -0.7), Vector3(0.1, 0.4, 0.7), 0.05, 0.05, 4, D)
	FoundKit.tbar(hk, Vector3(0, -0.3, 0), Vector3(0, -0.48, 0), 0.16, 0.2, 6, D)
	# The back plate between the cheeks: what the lamp is let into and what a
	# blow from behind lands on, so the working part has a face and not a gap.
	var back: Array[Vector2] = [Vector2(-0.62, -0.28), Vector2(0.62, -0.28), Vector2(0.62, 0.3), Vector2(-0.62, 0.3)]
	FoundKit.slab(hk, Vector3(-0.38, 0.02, 0.0), Vector3.BACK, Vector3.UP, back, 0.04, R, 0.01)
	FoundKit.rivets(hk, Vector3(-0.401, -0.2, -0.5), Vector3(-0.401, -0.2, 0.5), Vector3.LEFT, 4, R[5])
	body_mesh(hk, winch)
	add_lamp(winch, Vector3(-0.401, 0.12, 0.0), Vector3.LEFT, Vector3.UP, 0.07, 0.06, &"work", true)
	var w := FoundKit.kit()
	FoundKit.grime(w, Vector3(-0.401, 0.3, 0.0), Vector3.LEFT, 0.5, 0.3, 3, 31, R)
	wear_mesh(w, winch)
	# The drum itself: turned amber, ribbed with the cable's own lay, and the
	# thing the halo is drawn round. A working part on a body this size that
	# reads as three pixels is a part nobody aims at.
	var drum := joint(&"drum", winch, Vector3.ZERO)
	var dk := FoundKit.kit()
	var barrel: Array = [Palette.LENS[0], Palette.LENS[0], Palette.LENS[1], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2]]
	var amber: Array = [Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3], Palette.LENS[3]]
	FoundKit.lathe(dk, Vector3(0, 0, -0.6), Vector3.BACK, [Vector2(0.2, 0.0), Vector2(0.27, 0.05), Vector2(0.27, 1.15), Vector2(0.2, 1.2)], 10, barrel, PI / 10.0)
	for j in 6:
		var z := -0.5 + j * 0.2
		FoundKit.lathe(dk, Vector3(0, 0, z), Vector3.BACK, [Vector2(0.28, 0.0), Vector2(0.3, 0.03), Vector2(0.28, 0.06)], 10, amber, PI / 10.0)
	part_mesh(dk, drum)
	set_part_anchor(winch, Vector3(-0.42, 0.0, 0.0), 1.0)


## Four lattice legs, each two chords and a zigzag on exact pitch, leaning in a
## little toward the girder, and the braces that tie each pair into a portal.
## Across the STREET there is no brace at all: the gap is the drawing.
func _legs(frame: Node3D, R: Array, D: Array, DD: Array) -> void:
	var rise := BRIDGE_Y - 0.4 - SILL_Y
	var specs := [[1.0, 1.0, &"leg_fr"], [1.0, -1.0, &"leg_fl"], [-1.0, 1.0, &"leg_br"], [-1.0, -1.0, &"leg_bl"]]
	for spec: Array in specs:
		var sx: float = spec[0]
		var sz: float = spec[1]
		var jn: StringName = spec[2]
		var leg := joint(jn, frame, Vector3(sx * LEG_X, SILL_Y, sz * LEG_Z))
		var k := FoundKit.kit()
		# The top leans in, so the four legs read as a frame and not four posts.
		var top := Vector3(-sx * 0.22, rise, -sz * 0.32)
		var off := Vector3(0, 0, -sz * 0.36)
		FoundKit.tbar(k, Vector3.ZERO, top, 0.11, 0.08, 6, R, 0.03)
		FoundKit.tbar(k, off, top + off, 0.11, 0.08, 6, R, 0.03)
		# The zigzag between the chords, one pitch the whole way up.
		var steps := 9
		for j in steps:
			var t0 := float(j) / steps
			var t1 := float(j + 1) / steps
			var a := Vector3.ZERO.lerp(top, t0) + (off if j % 2 == 0 else Vector3.ZERO)
			var b := Vector3.ZERO.lerp(top, t1) + (Vector3.ZERO if j % 2 == 0 else off)
			FoundKit.tbar(k, a, b, 0.035, 0.035, 4, DD)
			if j % 2 == 0:
				FoundKit.tbar(k, Vector3.ZERO.lerp(top, t0), Vector3.ZERO.lerp(top, t0) + off, 0.03, 0.03, 4, D)
		# The foot: a cast shoe on the sill, bolted down.
		FoundKit.lathe(k, Vector3(0, -0.02, -sz * 0.18), Vector3.UP, [Vector2(0.3, 0.0), Vector2(0.34, 0.08), Vector2(0.24, 0.2)], 6, D, PI / 6.0)
		FoundKit.rivets(k, Vector3(0.24, 0.201, -sz * 0.18), Vector3(-0.24, 0.201, -sz * 0.18), Vector3.UP, 3, R[5])
		body_mesh(k, leg)
		var w := FoundKit.kit()
		# Concrete dust caked up the chords from the street it works: the city's
		# own signature on it, pale where the flats' keeper is salted.
		var dust: Array = [Palette.ASH[3], Palette.ASH[4], Palette.ASH[3], Palette.ASH[4], Palette.ASH[4], Palette.ASH[4]]
		FoundKit.grime(w, Vector3.ZERO.lerp(top, 0.2) + Vector3(sx * 0.11, 0, 0), Vector3(sx, 0, 0), 0.2, 1.4, 3, 41 + int(sx * 2.0 + sz), dust)
		if sx > 0.0:
			FoundKit.patch(w, Vector3.ZERO.lerp(top, 0.5 + 0.1 * sz) + Vector3(0.11, 0, 0), Vector3.RIGHT, Vector3.UP, 0.22, 0.4,
				Palette.MACHINE["hauler"] if sz > 0.0 else Palette.MACHINE["cutter"], 43 + int(sz))
		wear_mesh(w, leg)
	# The braces, on the frame: one horizontal and one long diagonal per side of
	# the street, at one angle each, and a low tie the bogies share.
	var bk := FoundKit.kit()
	for sz: float in [-1.0, 1.0]:
		var zz := sz * (LEG_Z - 0.18)
		for y: float in [2.6, 5.4]:
			var lean := (y - SILL_Y) / rise
			FoundKit.tbar(bk, Vector3(LEG_X - 0.22 * lean, y, zz), Vector3(-LEG_X + 0.22 * lean, y, zz), 0.055, 0.055, 4, D)
		FoundKit.tbar(bk, Vector3(-LEG_X, SILL_Y + 0.4, zz), Vector3(LEG_X - 0.2, BRIDGE_Y - 1.0, zz), 0.045, 0.045, 4, DD)
	body_mesh(bk, frame)


## The box girder across the leg tops: one straight run, its rivets on pitch,
## the rails the trolley runs on under it, and the plan strip on its top face —
## the one plate on this body a high camera can never miss.
func _girder(bridge: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	var section: Array[Vector2] = [Vector2(0.3, 0.3), Vector2(0.34, 0.14), Vector2(0.3, -0.3), Vector2(-0.3, -0.3), Vector2(-0.34, 0.14), Vector2(-0.3, 0.3)]
	FoundKit.slab(k, Vector3(0, 0, LEG_Z), Vector3.RIGHT, Vector3.UP, section, LEG_Z * 2.0 + 0.4, R, 0.04)
	FoundKit.seam(k, Vector3(0.0, 0.301, 0.3), Vector3(0.0, 0.301, LEG_Z * 2.0 - 0.3), Vector3.UP, R, 8)
	for j in 7:
		var z := 0.4 + j * (LEG_Z * 2.0 - 0.8) / 6.0
		FoundKit.panel(k, Vector3(0.341, 0.0, z), Vector3.RIGHT, Vector3.UP, 0.42, 0.4, R)
	FoundKit.rivets(k, Vector3(0.341, 0.24, 0.3), Vector3(0.341, 0.24, LEG_Z * 2.0 - 0.3), Vector3.RIGHT, 12, R[5])
	# The rails, under the girder, and the walkway rail along its back.
	for sx: float in [-1.0, 1.0]:
		FoundKit.tbar(k, Vector3(sx * 0.28, -0.36, 0.2), Vector3(sx * 0.28, -0.36, LEG_Z * 2.0 - 0.2), 0.04, 0.04, 4, D)
	for j in 6:
		var z := 0.5 + j * (LEG_Z * 2.0 - 1.0) / 5.0
		FoundKit.tbar(k, Vector3(-0.3, 0.3, z), Vector3(-0.3, 0.72, z), 0.018, 0.016, 4, D)
	FoundKit.tbar(k, Vector3(-0.3, 0.72, 0.5), Vector3(-0.3, 0.72, LEG_Z * 2.0 - 0.5), 0.02, 0.02, 4, D)
	body_mesh(k, bridge)
	add_lamp(bridge, Vector3(0.1, 0.303, LEG_Z), Vector3.UP, Vector3.RIGHT, 0.09, 0.09, &"status")
	day_wear(bridge, Vector3(0.0, 0.304, LEG_Z - 1.6), Vector3.UP, Vector3.BACK, 0.5, 1.2, 51, 2)
	var w := FoundKit.kit()
	FoundKit.grime(w, Vector3(0.342, 0.1, LEG_Z + 0.8), Vector3.RIGHT, 2.4, 0.2, 6, 52, R)
	FoundKit.cable(w, Vector3(0.2, -0.3, 0.6), Vector3(0.2, -0.3, LEG_Z * 2.0 - 0.8), 0.16, 0.02, Palette.INK[2], Palette.MACHINE["lineman"], 6)
	wear_mesh(w, bridge)


## The cab that rides the girder: hung under its far end, a slit facing along
## the street with a highlight travelling it, and two cold eyes beneath. The
## only part of the machine that looks at anything.
func _cab(bridge: Node3D, R: Array, D: Array) -> void:
	var cab := joint(&"cab", bridge, Vector3(0.0, -0.3, LEG_Z * 2.0 - 1.0))
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(1.0, 0.9, 0.14)
	FoundKit.loft(k, [FoundKit.ring(plan, -1.0, 0.08), FoundKit.ring(plan, -0.88), FoundKit.ring(plan, -0.1, 0.01), FoundKit.ring(plan, 0.0, 0.09)], R, true, true)
	FoundKit.visor(k, Vector3(0.501, -0.34, 0.0), Vector3.RIGHT, Vector3.UP, 0.62, 0.06)
	FoundKit.ticks(k, Vector3(0.501, -0.5, -0.28), Vector3(0.501, -0.5, 0.28), Vector3.RIGHT, 5, R[1])
	FoundKit.panel(k, Vector3(0.0, -0.5, 0.451), Vector3.BACK, Vector3.UP, 0.6, 0.5, R)
	body_mesh(k, cab)
	add_scan(cab, Vector3(0.503, -0.34, 0.0), Vector3.RIGHT, Vector3.BACK, 0.5, 0.045, 3.0)
	for sz: float in [-1.0, 1.0]:
		add_lamp(cab, Vector3(0.502, -0.72, sz * 0.26), Vector3.RIGHT, Vector3.UP, 0.07, 0.06, &"optic")
	day_marks(cab, Vector3(0.0, -0.5, -0.451), Vector3.FORWARD, Vector3.UP, 0.6, 0.5, 61)
	var w := FoundKit.kit()
	FoundKit.streaks(w, Vector3(0.502, -0.2, 0.0), Vector3.RIGHT, 0.7, 0.4, 4, 62, R[1])
	FoundKit.scorch(w, Vector3(0.0, -0.3, 0.452), Vector3.BACK, 0.11, 63)
	wear_mesh(w, cab)


## The trolley under the rails, deep enough to hide a wound-up cable, with the
## two sheaves the cables come off at its foot.
func _trolley(trolley: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(0.9, 1.0, 0.12)
	FoundKit.loft(k, [FoundKit.ring(plan, -1.0, 0.1), FoundKit.ring(plan, -0.9), FoundKit.ring(plan, -0.1), FoundKit.ring(plan, 0.0, 0.06)], D, false, true)
	for sx: float in [-1.0, 1.0]:
		FoundKit.disc(k, Vector3(sx * 0.3, -1.02, 0.0), Vector3.RIGHT, 0.2, 0.07, 8, 0.012, R, R[1], PI / 8.0)
		FoundKit.rivets(k, Vector3(sx * 0.451, -0.8, -0.3), Vector3(sx * 0.451, -0.8, 0.3), Vector3.RIGHT * sx, 3, R[5])
	body_mesh(k, trolley)


## The two cables, on the pendulum they swing with: from the sheaves in to the
## grab. Drawn in ink like every cable in the game.
func _cables(hang: Node3D) -> void:
	var k := FoundKit.kit()
	var line := FoundKit.flat(Palette.INK[2])
	for sx: float in [-1.0, 1.0]:
		FoundKit.tbar(k, Vector3(sx * 0.3, 0.0, 0.0), Vector3(sx * 0.14, -2.4, 0.0), 0.022, 0.022, 3, line)
		FoundKit.tbar(k, Vector3(sx * 0.14, -2.4, 0.0), Vector3(sx * 0.14, -HANG, 0.0), 0.022, 0.022, 3, line)
	body_mesh(k, hang)


## The grab: a turned hub with the ram on top and four tines hung off its rim,
## each on its own hinge so a pose can open and shut the whole hand. The cable's
## lower run is drawn here, coaxial with the upper and thicker, so the grab may
## drop OVERLAP without the line parting (see the constant).
func _grab(grab: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	var line := FoundKit.flat(Palette.INK[2])
	for sx: float in [-1.0, 1.0]:
		FoundKit.tbar(k, Vector3(sx * 0.14, 0.0, 0.0), Vector3(sx * 0.14, OVERLAP, 0.0), 0.03, 0.03, 3, line)
	FoundKit.lathe(k, Vector3.ZERO, Vector3.UP, [Vector2(0.3, -0.5), Vector2(0.42, -0.36), Vector2(0.42, 0.3), Vector2(0.3, 0.45)], 8, R, PI / 8.0)
	FoundKit.lathe(k, Vector3(0, 0.45, 0), Vector3.UP, [Vector2(0.11, 0.0), Vector2(0.13, 0.08), Vector2(0.13, 0.5), Vector2(0.09, 0.56)], 6, D, PI / 6.0)
	FoundKit.seam(k, Vector3(0.421, -0.2, 0.0), Vector3(0.421, 0.2, 0.0), Vector3.RIGHT, R, 2)
	FoundKit.rivets(k, Vector3(0.3, 0.451, -0.2), Vector3(0.3, 0.451, 0.2), Vector3.UP, 3, R[5])
	body_mesh(k, grab)
	var w := FoundKit.kit()
	FoundKit.grime(w, Vector3(0.421, 0.2, 0.0), Vector3.RIGHT, 0.5, 0.5, 3, 71, R)
	FoundKit.patch(w, Vector3(0.0, 0.1, -0.421), Vector3.FORWARD, Vector3.UP, 0.3, 0.3, Palette.MACHINE["dredger"], 72)
	wear_mesh(w, grab)
	for i in 4:
		var a := i * TAU / 4.0 + PI * 0.25
		# Turned so the tine's own +X is its radial: a pose then opens it about
		# its own z, which is the hinge (MachineModel poses add eulers).
		var tine := joint(StringName("tine_%d" % i), grab, Vector3(cos(a) * 0.36, -0.42, sin(a) * 0.36), Vector3(0, -a, 0))
		var tk := FoundKit.kit()
		FoundKit.tbar(tk, Vector3.ZERO, Vector3(0.34, -0.55, 0), 0.09, 0.07, 5, R, 0.02)
		FoundKit.tbar(tk, Vector3(0.34, -0.55, 0), Vector3(0.24, -1.05, 0), 0.07, 0.05, 5, R)
		# The point curls in under the load, and it is the one rubbed-bright edge
		# on the whole machine: what it has been dragging over concrete.
		FoundKit.tbar(tk, Vector3(0.24, -1.05, 0), Vector3(-0.06, -1.3, 0), 0.05, 0.015, 5, [R[0], R[1], R[2], R[3], R[5], R[5]])
		FoundKit.rivets(tk, Vector3(0.1, -0.14, 0.05), Vector3(0.26, -0.44, 0.05), Vector3.BACK, 2, R[5])
		body_mesh(tk, tine)
	# What it last closed on, still in it: concrete with the reinforcement out of
	# it, the land's own rubble drawn by the hand on a machine drawn by a ruler.
	var jam := FoundKit.matter_kit(Ink.HAND)
	jam.rock(0.12, -1.0, -0.1, 0.24, 0.2, 470, Palette.ASH[3], 5)
	jam.rock(-0.16, -0.95, 0.14, 0.18, 0.16, 471, Palette.STONE[3], 5)
	wear_matter(jam, grab)
	var bars := FoundKit.kit()
	FoundKit.tbar(bars, Vector3(-0.3, -0.9, -0.3), Vector3(0.45, -0.7, 0.35), 0.016, 0.016, 3, FoundKit.flat(Palette.RUST[2]))
	FoundKit.tbar(bars, Vector3(0.1, -1.1, 0.4), Vector3(-0.2, -0.6, -0.5), 0.014, 0.014, 3, FoundKit.flat(Palette.RUST[3]))
	wear_mesh(bars, grab)


## Nothing on the frame walks; the poses are the grab and the trolley.
func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"stand":
			# Stopped: the grab wound up under the trolley, shut.
			d[&"grab"] = pr(Vector3(0, 1.2, 0))
			_tines(d, -0.12)
		&"alert":
			# It has you: the trolley runs out over the street, the grab comes
			# down to a person's height and opens, and the cab leans to look.
			d[&"trolley"] = pr(Vector3(0, 0, 0.7))
			d[&"hang"] = r(Vector3(0, 0, -0.14))
			d[&"cab"] = r(Vector3(0, 0, -0.1))
			_tines(d, 0.45)
		&"windup":
			# The cable pays out: the grab sinks, wide open, and the pendulum is
			# drawn back along the street, so the thing about to come down is the
			# thing in plain sight.
			d[&"trolley"] = pr(Vector3(0, 0, 0.7))
			d[&"hang"] = r(Vector3(0, 0, 0.34))
			d[&"grab"] = pr(Vector3(0, -0.8, 0))
			d[&"bridge"] = r(Vector3(0, 0, 0.012))
			d[&"cab"] = r(Vector3(0, 0, -0.16))
			_tines(d, 0.9)
		&"strike":
			# And slams to the ground, the tines snapping shut, the whole frame
			# dipping on its bogies as the load comes off the cable.
			d[&"trolley"] = pr(Vector3(0, 0, 0.7))
			d[&"hang"] = r(Vector3(0, 0, -0.3))
			d[&"grab"] = pr(Vector3(0, -OVERLAP + 0.2, 0))
			d[&"frame"] = pr(Vector3(0.06, -0.08, 0))
			d[&"cab"] = r(Vector3(0, 0, -0.06))
			_tines(d, -0.2)
		&"hurt":
			d[&"hang"] = r(Vector3(0.28, 0, 0))
			d[&"cab"] = r(Vector3(0, 0, 0.08))
		&"dead":
			# The legs on the right fold, the left pair lean after them, the
			# girder comes down across the street and the grab is flung out on
			# its cable: the doorway that named it is gone.
			d[&"leg_fr"] = r(Vector3(-1.25, 0, 0.1))
			d[&"leg_br"] = r(Vector3(-1.2, 0, -0.08))
			d[&"leg_fl"] = r(Vector3(0.42, 0, 0.06))
			d[&"leg_bl"] = r(Vector3(0.38, 0, -0.05))
			d[&"bridge"] = pr(Vector3(0.2, -6.6, 0.9), Vector3(0.28, 0, 0.1))
			d[&"cab"] = pr(Vector3(0.4, -0.5, 0.3), Vector3(0.3, 0.2, 0.5))
			d[&"hang"] = r(Vector3(1.45, 0, 0))
			d[&"trolley"] = pr(Vector3(0, 0, -0.4), Vector3(0, 0, 0.2))
			d[&"winch"] = r(Vector3(0, 0, -0.4))
			_tines(d, 0.7)
	return d


func _tines(d: Dictionary, open: float) -> void:
	for i in 4:
		d[StringName("tine_%d" % i)] = r(Vector3(0, 0, open))


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead":
		match j:
			&"bridge", &"cab", &"trolley": return Vector2(LIGHT_FIRST + 0.35, 0.6)
			&"hang", &"tine_0", &"tine_1", &"tine_2", &"tine_3": return Vector2(LIGHT_FIRST + 0.6, 0.5)
	return super(p, j)


## The carriage rolls and the grab sways with the travel: an exact pendulum.
func _gait_deltas(phase: float) -> Dictionary:
	var a := sin(phase * TAU)
	return {
		&"frame": pr(Vector3(0, absf(a) * 0.012, 0), Vector3(0, 0, a * 0.006)),
		&"hang": r(Vector3(0, 0, a * 0.05)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	var v := maxf(speed_now, nominal_speed if pose == &"walk" else 0.0)
	_travel += delta * v
	for w in _wheels:
		w.rotation.z = -_travel / WHEEL_R
	# The winch turns while there is power in it, and never wanders.
	_winch_t += delta
	(joints[&"drum"] as Node3D).rotation.z = _winch_t * 2.2
	if pose == &"stand":
		# Every few seconds the trolley takes up its slack along the rail and
		# lets it back, exactly.
		var t := fposmod(clock, 6.0)
		(joints[&"trolley"] as Node3D).position.z += 0.05 * (smoothstep(4.8, 5.1, t) - smoothstep(5.4, 5.7, t))
