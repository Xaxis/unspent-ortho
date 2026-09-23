extends MachineModel
## THE LOCKKEEPER: the Drowned City's keeper (docs/VISION.md,
## docs/LANDSCAPES.md, src/core/sentinel/designs/lockkeeper.gd). A long
## barge hull carried on four tall stilt legs, a wheelhouse on its after deck,
## and a lock-gate blade hung under its belly that it drops across a canal.
## About six units to the head of its mast.
##
## Why a BOAT THAT WALKS. The reaper is an arch, the rake a delta on stilts, the
## plumb a triangle over a pendulum, the unbuilder a doorway, and no two keepers
## may share a silhouette (VISION §3). This one is built out of the thing the
## drowned city is made of: a boat, and the streets are canals. A hull is the
## most ordinary shape on that water — every quay has one moored against it —
## so a hull standing up out of the canal on legs is read at once and from a
## long way as the one that is wrong. The legs splay out and down like a water
## strider's, so the hull rides level over the water however deep it is, and
## the blade under it hangs where a keel would be.
##
## Ruled, like every machine: the hull is one lofted plan, the legs are two
## straight members each meeting at a knuckle, the blade is a ruled plate with
## its guides on pitch, and the only turned things on it are the pump's drum,
## the winch and the foot pads. Its colour is the KEEPER's ramp (Palette: a
## machine's colour is its role).
##
## Poses. The legs and the blade are the whole vocabulary.
## walk   WADING: the legs step in diagonal pairs and the hull rides level over
##        them, bobbing on each stride like a thing afloat
## stand  the pump's drum turns under the stern while it keeps its timetable
## alert  it has you: the hull settles lower on bent legs and the blade comes
##        down out of its belly to a person's height
## windup a front stilt comes right up out of the water, and the blade lifts:
##        the leg is the tell, two units of it
## strike the stilt stamps and the blade drops to the bed: a gate across the canal
## hurt   the hull rolls on its legs; nothing else moves
## dead   the after legs fold, the hull goes down stern first into the canal and
##        lies canted on its splayed legs with the blade fallen out under it: a
##        wreck with its bow in the air, which every quay here already has
##
## lights the plan strip on the wheelhouse roof (seen from above, always), cold
##        optics in the wheelhouse front, work lamps under the bow washing the
##        water ahead, and one by the pump that goes hot through a windup
## wear   weed up every leg to the waterline and barnacles along the hull's
##        bottom, streaks down its sides from the scuppers, a plate off another
##        kind patched over the bow: the canal has been climbing it for years
## weld   the legs and the pump's drum are welded (MeshKit.smooth_range); the
##        hull keeps its facets, because a hull is plate and its strakes are
##        what say so

## Where the hull's own origin rides over the ground: its keel sits about half
## a unit under this, its deck half a unit over it.
const HULL_Y := 3.3
const DECK_Y := 0.45
## The four hips, on the hull's sides at its quarters.
const HIP_X := 1.85
const HIP_Z := 0.78
## Where each foot stands, out from the hull's centre line: the legs splay wide
## so the hull rides steady, which is also what makes it a strider and not a pier.
const FOOT_X := 2.35
const FOOT_Z := 1.85
## The blade at rest, drawn up against the belly under the bow third.
const BLADE_X := 0.9
const BLADE_TOP := -0.52
const BLADE_H := 1.5
const BLADE_W := 2.3
## The pump hangs off the transom on its suction pipe to a hand's height.
const PUMP_DROP := 2.2

var _t := 0.0


func build() -> void:
	part_side = &"back"
	height = 6.4
	stride = 2.8
	gallery_turn = 30.0
	# A working part the size of a pump's drum burns to white at the default and
	# the amber goes out of it (docs/LOOK.md), as the reaper's drum did.
	emission = 0.28
	begin_rig()
	ramp = Palette.MACHINE["warden"]
	disposition = &"wary"
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var hull := joint(&"hull", self, Vector3(0, HULL_Y, 0))
	_hull(hull, R, D, DD)
	_wheelhouse(hull, R, D)
	_bow(hull, R, D, DD)
	_legs(hull, R, D, DD)
	_pump(hull, R, D, DD)
	var blade := joint(&"blade", hull, Vector3(BLADE_X, BLADE_TOP, 0))
	_blade(blade, R, D, DD)
	finish_rig()


## The barge plan, bow at +X: a raked bow narrower than the square stern, in
## plan_oct's order so `FoundKit.ring` can loft it.
static func _plan() -> Array[Vector2]:
	return [Vector2(2.75, -0.34), Vector2(2.75, 0.34), Vector2(2.15, 0.84), Vector2(-2.3, 0.86),
		Vector2(-2.6, 0.62), Vector2(-2.6, -0.62), Vector2(-2.3, -0.86), Vector2(2.15, -0.84)]


## The hull: one lofted plan, its bottom drawn in and pulled back so the bow
## rakes up out of the water, a rubbing strake along each side, a bulwark rail
## on the deck edge and rivets on exact pitch down the strakes.
func _hull(hull: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	var plan := _plan()
	FoundKit.loft(k, [
		FoundKit.ring(plan, -0.62, 0.0, Vector2(0.78, 0.55), Vector2(-0.22, 0.0)),
		FoundKit.ring(plan, -0.3, 0.0, Vector2(0.95, 0.88), Vector2(-0.05, 0.0)),
		FoundKit.ring(plan, 0.3),
		FoundKit.ring(plan, DECK_Y, 0.05),
	], D, true, true)
	# The rubbing strakes, the hull's one horizontal line from the bank.
	for sz: float in [-1.0, 1.0]:
		FoundKit.tbar(k, Vector3(2.1, 0.12, sz * 0.86), Vector3(-2.3, 0.12, sz * 0.88), 0.05, 0.05, 4, DD)
		FoundKit.rivets(k, Vector3(1.8, -0.1, sz * 0.83), Vector3(-2.1, -0.1, sz * 0.84), Vector3.BACK * sz, 12, R[5])
		FoundKit.seam(k, Vector3(1.9, 0.3, sz * 0.851), Vector3(-2.2, 0.3, sz * 0.861), Vector3.BACK * sz, R, 6)
		# The bulwark rail on the deck edge, on stanchions at one pitch.
		for j in 7:
			var x := 1.9 - j * 0.66
			FoundKit.tbar(k, Vector3(x, DECK_Y, sz * 0.78), Vector3(x, DECK_Y + 0.32, sz * 0.78), 0.018, 0.016, 4, D)
		FoundKit.tbar(k, Vector3(1.95, DECK_Y + 0.32, sz * 0.78), Vector3(-2.1, DECK_Y + 0.32, sz * 0.78), 0.022, 0.022, 4, D)
	# The hatch covers amidships, ruled: what the ballast is pumped through.
	for j in 3:
		FoundKit.cbox(k, Vector3(0.9 - j * 0.62, DECK_Y + 0.05, 0.0), Vector3(0.5, 0.1, 1.0), 0.02, R, 0)
	body_mesh(k, hull)
	day_wear(hull, Vector3(0.2, DECK_Y + 0.002, 0.0), Vector3.UP, Vector3.RIGHT, 1.4, 1.0, 211, 2)
	var w := FoundKit.kit()
	# Rust run down the sides from the scuppers, and a plate off another kind
	# over the bow where something hit it.
	for sz: float in [-1.0, 1.0]:
		FoundKit.streaks(w, Vector3(0.6, 0.38, sz * 0.852), Vector3.BACK * sz, 3.4, 0.5, 7, 212 + int(sz), R[1])
		# The tide line: a pale band of dried salt where it last sat in the
		# water, and green under it. From the bank it is the one light line on a
		# dark hull, and it is what says this thing floats when it is not walking.
		FoundKit.dirt_line(w, Vector3(1.95, -0.2, sz * 0.785), Vector3(-2.2, -0.2, sz * 0.785), Vector3.BACK * sz, 0.05, Palette.LINEN[3])
		FoundKit.dirt_line(w, Vector3(1.8, -0.3, sz * 0.765), Vector3(-2.15, -0.3, sz * 0.765), Vector3.BACK * sz, 0.12, Palette.SPRUCE[1])
	FoundKit.patch(w, Vector3(2.2, 0.0, 0.62), Vector3(0.55, 0, 0.83).normalized(), Vector3.UP, 0.4, 0.3, Palette.MACHINE["hauler"], 214)
	FoundKit.scorch(w, Vector3(-1.2, 0.05, -0.853), Vector3.FORWARD, 0.12, 215)
	wear_mesh(w, hull)
	# Barnacles along the bottom, where the canal has been at it: the land's own
	# matter on a machine that stands in it.
	var m := FoundKit.matter_kit(Ink.HAND)
	var shell: Array[Color] = [Palette.STONE[3], Palette.LINEN[3], Palette.STONE[2], Palette.SPRUCE[2]]
	for i in 14:
		var x := 1.8 - i * 0.29
		var sz := 1.0 if i % 2 == 0 else -1.0
		m.rock(x, -0.5 + Rng.hash01(221, i, 1) * 0.12, sz * (0.5 + Rng.hash01(221, i, 2) * 0.1), 0.05 + Rng.hash01(221, i, 3) * 0.04, 0.04, 222 + i, shell[i % shell.size()], 5)
	wear_matter(m, hull)


## The wheelhouse on the after deck: a lofted box with a slit window across its
## front and a scan running it, two cold eyes under the slit, the plan strip on
## the roof, and a mast behind it with the aerial that takes the timetable.
func _wheelhouse(hull: Node3D, R: Array, D: Array) -> void:
	var house := joint(&"house", hull, Vector3(-1.45, DECK_Y, 0.0))
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(1.2, 1.2, 0.14)
	FoundKit.loft(k, [FoundKit.ring(plan, 0.0), FoundKit.ring(plan, 0.95), FoundKit.ring(plan, 1.08, 0.08)], R, true)
	FoundKit.visor(k, Vector3(0.601, 0.72, 0.0), Vector3.RIGHT, Vector3.UP, 0.8, 0.07)
	FoundKit.ticks(k, Vector3(0.601, 0.56, -0.34), Vector3(0.601, 0.56, 0.34), Vector3.RIGHT, 7, R[1])
	FoundKit.panel(k, Vector3(0.0, 0.5, 0.601), Vector3.BACK, Vector3.UP, 0.8, 0.6, R)
	FoundKit.panel(k, Vector3(0.0, 0.5, -0.601), Vector3.FORWARD, Vector3.UP, 0.8, 0.6, R)
	FoundKit.rivets(k, Vector3(-0.45, 0.9, 0.602), Vector3(0.45, 0.9, 0.602), Vector3.BACK, 5, R[5])
	FoundKit.rivets(k, Vector3(-0.45, 0.9, -0.602), Vector3(0.45, 0.9, -0.602), Vector3.FORWARD, 5, R[5])
	# The mast and its aerial: the one tall line over the hull, which is how the
	# ferries' calls reach it.
	FoundKit.tbar(k, Vector3(-0.35, 1.08, 0.0), Vector3(-0.35, 2.55, 0.0), 0.05, 0.03, 6, D)
	FoundKit.tbar(k, Vector3(-0.35, 2.2, -0.4), Vector3(-0.35, 2.2, 0.4), 0.02, 0.02, 4, D)
	FoundKit.tbar(k, Vector3(-0.35, 1.85, -0.28), Vector3(-0.35, 1.85, 0.28), 0.02, 0.02, 4, D)
	body_mesh(k, house)
	add_lamp(house, Vector3(0.05, 1.082, 0.0), Vector3.UP, Vector3.RIGHT, 0.08, 0.08, &"status")
	add_scan(house, Vector3(0.603, 0.72, 0.0), Vector3.RIGHT, Vector3.BACK, 0.66, 0.05, 2.8)
	for sz: float in [-1.0, 1.0]:
		add_lamp(house, Vector3(0.603, 0.4, sz * 0.26), Vector3.RIGHT, Vector3.UP, 0.07, 0.06, &"optic")
	day_marks(house, Vector3(-0.1, 1.082, 0.3), Vector3.UP, Vector3.RIGHT, 0.5, 0.4, 231)
	var w := FoundKit.kit()
	FoundKit.streaks(w, Vector3(0.602, 0.95, 0.1), Vector3.RIGHT, 0.8, 0.4, 4, 232, R[1])
	FoundKit.grime(w, Vector3(-0.601, 0.9, 0.0), Vector3.LEFT, 0.8, 0.5, 4, 233, R)
	wear_mesh(w, house)


## The bow: a gantry of two posts over the blade's guides with the winch that
## hoists the blade between them, and the work lamps under the flare washing the
## water ahead. The winch is what the blade guards once it gates.
func _bow(hull: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	for sz: float in [-1.0, 1.0]:
		FoundKit.tbar(k, Vector3(BLADE_X, DECK_Y, sz * 0.6), Vector3(BLADE_X, DECK_Y + 1.0, sz * 0.5), 0.06, 0.05, 6, D, 0.02)
	FoundKit.tbar(k, Vector3(BLADE_X, DECK_Y + 1.0, -0.6), Vector3(BLADE_X, DECK_Y + 1.0, 0.6), 0.06, 0.06, 6, R, 0.02)
	# The winch drum across the gantry's head, and the two falls down to the
	# guides: a hoist, which is the whole of what a lock gate is worked by.
	FoundKit.lathe(k, Vector3(BLADE_X, DECK_Y + 0.8, -0.34), Vector3.BACK, [Vector2(0.1, 0.0), Vector2(0.15, 0.04), Vector2(0.15, 0.64), Vector2(0.1, 0.68)], 8, DD, PI / 8.0)
	var line := FoundKit.flat(Palette.INK[2])
	for sz: float in [-1.0, 1.0]:
		FoundKit.tbar(k, Vector3(BLADE_X + 0.1, DECK_Y + 0.72, sz * 0.24), Vector3(BLADE_X + 0.1, DECK_Y, sz * 0.24), 0.016, 0.016, 3, line)
	body_mesh(k, hull)
	for sz: float in [-1.0, 1.0]:
		add_lamp(hull, Vector3(2.55, -0.1, sz * 0.4), Vector3(0.8, -0.3, sz * 0.5).normalized(), Vector3.UP, 0.07, 0.06, &"work")
	add_beam(hull, Vector3(2.7, -0.2, 0.0), Vector3(1.4, -1.0, 0.0), 3.6, 2.6, &"work")


## Four stilts, each an upper member out from the hull's side to a knuckle and a
## long lower member down to a pad, splayed wide like a water strider's so the
## hull rides level over any depth. Welded into tubes; the knuckles keep their
## facets because they are fittings, not limbs.
func _legs(hull: Node3D, R: Array, D: Array, DD: Array) -> void:
	var specs := [[1.0, 1.0, &"leg_fr"], [1.0, -1.0, &"leg_fl"], [-1.0, 1.0, &"leg_br"], [-1.0, -1.0, &"leg_bl"]]
	var weed: Array = [Palette.SPRUCE[1], Palette.MOSS[2], Palette.SPRUCE[2], Palette.MOSS[1], Palette.SPRUCE[1], Palette.MOSS[2]]
	for spec: Array in specs:
		var sx: float = spec[0]
		var sz: float = spec[1]
		var jn: StringName = spec[2]
		var hip := Vector3(sx * HIP_X, -0.18, sz * HIP_Z)
		var leg := joint(jn, hull, hip)
		var foot := Vector3(sx * FOOT_X, -HULL_Y, sz * FOOT_Z) - hip
		# The knuckle stands out and a little UP from the hip: the strider's bend,
		# which is what lets the hull hang between its legs instead of on top.
		var knee := Vector3(sx * 0.2, 0.35, sz * 0.72)
		var k := FoundKit.kit()
		var s0 := k.vertex_count()
		FoundKit.tbar(k, Vector3.ZERO, knee, 0.11, 0.09, 6, R)
		FoundKit.tbar(k, knee, foot, 0.09, 0.05, 6, D)
		k.smooth_range(s0, k.vertex_count(), 70.0)
		FoundKit.lathe(k, knee, foot - knee, [Vector2(0.1, -0.12), Vector2(0.14, -0.04), Vector2(0.14, 0.12), Vector2(0.1, 0.2)], 6, DD, PI / 6.0)
		FoundKit.lathe(k, Vector3.ZERO, knee, [Vector2(0.13, -0.06), Vector2(0.16, 0.0), Vector2(0.16, 0.16), Vector2(0.12, 0.22)], 6, DD, PI / 6.0)
		# The pad: a broad disc it stands on in the silt, so it does not sink.
		FoundKit.disc(k, foot + Vector3(0, 0.04, 0), Vector3.UP, 0.26, 0.08, 8, 0.02, DD, Color(0, 0, 0, 0), PI / 8.0)
		# A hydraulic ram from the hull side to halfway down the lower member:
		# the one thing on a stilt that says it is driven and not propped.
		FoundKit.tbar(k, Vector3(-sx * 0.05, 0.25, 0.0), knee.lerp(foot, 0.35), 0.04, 0.035, 6, DD)
		body_mesh(k, leg)
		# Weed to the waterline: the canal's own signature, up every stilt from
		# the pad, green where the others are salted, peated or dusted.
		var w := FoundKit.kit()
		var out := Vector3(foot.x, 0.0, foot.z).normalized()
		FoundKit.grime(w, knee.lerp(foot, 0.62), out, 0.14, 1.4, 5, 241 + int(sx * 2.0 + sz), weed)
		FoundKit.grime(w, knee.lerp(foot, 0.75), out.cross(Vector3.UP).normalized(), 0.12, 0.9, 3, 245 + int(sx * 2.0 + sz), weed)
		if sx > 0.0 and sz > 0.0:
			FoundKit.patch(w, knee.lerp(foot, 0.3) + out * 0.09, out, Vector3.UP, 0.14, 0.3, Palette.MACHINE["cutter"], 249)
		wear_mesh(w, leg)


## The ballast pump, hung off the transom on its suction pipe to a hand's
## height: a housing with a turned amber drum in it facing aft. It is the
## working part while it wades, and the only part of this machine a hand
## standing in the canal can reach.
func _pump(hull: Node3D, R: Array, D: Array, DD: Array) -> void:
	var pump := joint(&"pump", hull, Vector3(-2.35, -0.5, 0.0))
	var hk := FoundKit.kit()
	# The suction pipe down from the transom, and its bracket.
	FoundKit.tbar(hk, Vector3.ZERO, Vector3(-0.1, -PUMP_DROP + 0.3, 0.0), 0.08, 0.08, 8, D, 0.02)
	FoundKit.cbox(hk, Vector3(0.05, -0.05, 0.0), Vector3(0.3, 0.2, 0.46), 0.03, R)
	# The housing: two cheeks the drum turns between and a guard over it.
	var at := Vector3(-0.1, -PUMP_DROP, 0.0)
	for sz: float in [-1.0, 1.0]:
		var cheek: Array[Vector2] = [Vector2(-0.3, -0.26), Vector2(0.26, -0.26), Vector2(0.3, 0.0), Vector2(0.26, 0.3), Vector2(-0.3, 0.3), Vector2(-0.34, 0.0)]
		FoundKit.slab(hk, at + Vector3(0, 0, sz * 0.36), Vector3.RIGHT, Vector3.UP, cheek, 0.05, R, 0.01)
	FoundKit.tbar(hk, at + Vector3(0.05, 0.34, -0.4), at + Vector3(0.05, 0.34, 0.4), 0.04, 0.04, 4, D)
	# The outfall, a stub pointing down into the water it pumps.
	FoundKit.tbar(hk, at + Vector3(0.1, -0.2, 0.0), at + Vector3(0.18, -0.5, 0.0), 0.06, 0.07, 6, DD)
	body_mesh(hk, pump)
	add_lamp(pump, at + Vector3(0.0, 0.2, 0.37), Vector3.BACK, Vector3.UP, 0.05, 0.05, &"work", true)
	var w := FoundKit.kit()
	var weed: Array = [Palette.SPRUCE[1], Palette.MOSS[2], Palette.SPRUCE[2], Palette.MOSS[1], Palette.SPRUCE[1], Palette.MOSS[2]]
	FoundKit.grime(w, at + Vector3(0.0, 0.2, 0.37), Vector3.BACK, 0.4, 0.4, 3, 251, weed)
	wear_mesh(w, pump)
	# The drum: turned amber, ribbed, the thing the halo is drawn round, facing
	# aft so the side a player comes at it from is the side it shows.
	var drum := joint(&"drum", pump, at)
	var dk := FoundKit.kit()
	var barrel: Array = [Palette.LENS[0], Palette.LENS[0], Palette.LENS[1], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2]]
	var amber: Array = [Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3], Palette.LENS[3]]
	var s0 := dk.vertex_count()
	FoundKit.lathe(dk, Vector3(0, 0, -0.3), Vector3.BACK, [Vector2(0.14, 0.0), Vector2(0.21, 0.05), Vector2(0.21, 0.55), Vector2(0.14, 0.6)], 10, barrel, PI / 10.0)
	dk.smooth_range(s0, dk.vertex_count(), 40.0)
	for j in 10:
		var a := j * TAU / 10.0
		var n := Vector3(cos(a), sin(a), 0.0)
		FoundKit.mark(dk, n * 0.21, n, Vector3.BACK, 0.05, 0.46, amber[3], 0.004)
	part_mesh(dk, drum)
	set_part_anchor(pump, at + Vector3(-0.22, 0.0, 0.0), 0.95)


## The gate blade: a ruled plate hung across the canal under the bow third,
## drawn up against the belly at rest, its face on exact pitch with stiffeners
## and a darker cutting edge along its foot, and two guides up into the hull.
## A pose drops it; the guides are drawn tall so they never show their ends.
func _blade(blade: Node3D, R: Array, D: Array, DD: Array) -> void:
	var k := FoundKit.kit()
	var face: Array[Vector2] = [Vector2(-BLADE_W * 0.5, -BLADE_H), Vector2(BLADE_W * 0.5, -BLADE_H), Vector2(BLADE_W * 0.5, 0.0), Vector2(-BLADE_W * 0.5, 0.0)]
	FoundKit.slab(k, Vector3.ZERO, Vector3.BACK, Vector3.UP, face, 0.1, D, 0.015)
	# Stiffeners across it, the lock gate's own ruling, both faces.
	for j in 3:
		var y := -0.3 - j * 0.45
		for sx: float in [-1.0, 1.0]:
			FoundKit.tbar(k, Vector3(sx * 0.06, y, -BLADE_W * 0.47), Vector3(sx * 0.06, y, BLADE_W * 0.47), 0.03, 0.03, 4, R)
	FoundKit.rivets(k, Vector3(0.052, -0.12, -BLADE_W * 0.44), Vector3(0.052, -0.12, BLADE_W * 0.44), Vector3.RIGHT, 9, R[5])
	# The cutting edge along its foot, darker: what comes down on a raft.
	FoundKit.tbar(k, Vector3(0, -BLADE_H, -BLADE_W * 0.5), Vector3(0, -BLADE_H, BLADE_W * 0.5), 0.05, 0.05, 4, DD)
	# The guides it rides up and down on, into the hull.
	for sz: float in [-1.0, 1.0]:
		FoundKit.tbar(k, Vector3(0, -0.1, sz * 0.62), Vector3(0, 1.1, sz * 0.62), 0.04, 0.04, 6, DD)
	body_mesh(k, blade)
	day_marks(blade, Vector3(0.052, -0.8, 0.0), Vector3.RIGHT, Vector3.UP, 1.6, 0.9, 261)
	var w := FoundKit.kit()
	var weed: Array = [Palette.SPRUCE[1], Palette.MOSS[2], Palette.SPRUCE[2], Palette.MOSS[1], Palette.SPRUCE[1], Palette.MOSS[2]]
	FoundKit.grime(w, Vector3(0.053, -1.0, 0.0), Vector3.RIGHT, 2.0, 0.5, 6, 262, weed)
	FoundKit.grime(w, Vector3(-0.053, -1.0, 0.0), Vector3.LEFT, 2.0, 0.5, 5, 263, weed)
	wear_mesh(w, blade)


## Everything is said with the legs, the hull's height and the blade. The
## pump's turn rides on the drum in `_routine`, so the two never fight.
func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"alert":
			# The hull settles on bent legs and the blade comes down out of the
			# belly: it has you, and it is closing the canal.
			d[&"hull"] = pr(Vector3(0.0, -0.35, 0.0), Vector3(0.0, 0.0, -0.04))
			d[&"blade"] = pr(Vector3(0.0, -0.45, 0.0))
			d[&"leg_fr"] = r(Vector3(-0.06, 0.0, 0.0))
			d[&"leg_fl"] = r(Vector3(0.06, 0.0, 0.0))
			d[&"leg_br"] = r(Vector3(-0.06, 0.0, 0.0))
			d[&"leg_bl"] = r(Vector3(0.06, 0.0, 0.0))
		&"windup":
			# A front stilt comes right up out of the water and the blade lifts
			# with it: two units of leg in the air is the tell.
			d[&"leg_fr"] = r(Vector3(-0.25, 0.0, 0.75))
			d[&"hull"] = pr(Vector3(-0.15, 0.1, 0.0), Vector3(0.1, 0.0, 0.08))
			d[&"blade"] = pr(Vector3(0.0, 0.1, 0.0))
		&"strike":
			# It stamps, and the blade drops to the bed: a wall across the canal.
			d[&"leg_fr"] = r(Vector3(0.05, 0.0, -0.12))
			d[&"hull"] = pr(Vector3(0.1, -0.25, 0.0), Vector3(-0.04, 0.0, -0.06))
			d[&"blade"] = pr(Vector3(0.15, -1.35, 0.0))
		&"hurt":
			d[&"hull"] = r(Vector3(0.12, 0.0, 0.0))
		&"dead":
			# The after legs fold and the hull goes down stern first into the
			# canal, canted over on its splayed legs with the blade fallen out
			# under it and its bow in the air.
			d[&"hull"] = pr(Vector3(-0.2, -2.35, 0.3), Vector3(0.22, 0.0, 0.3))
			d[&"leg_br"] = r(Vector3(-1.05, 0.0, -0.35))
			d[&"leg_bl"] = r(Vector3(1.1, 0.0, -0.3))
			d[&"leg_fr"] = r(Vector3(-0.7, 0.0, 0.2))
			d[&"leg_fl"] = r(Vector3(0.8, 0.0, 0.25))
			d[&"blade"] = pr(Vector3(0.25, -0.45, 0.2), Vector3(0.4, 0.0, 0.55))
			d[&"pump"] = r(Vector3(0.0, 0.0, 0.5))
	return d


func _timing(p: StringName, j: StringName) -> Vector2:
	if p == &"dead":
		if j == &"leg_br" or j == &"leg_bl":
			return Vector2(LIGHT_FIRST, 0.45)
		if j == &"hull" or j == &"blade":
			return Vector2(LIGHT_FIRST + 0.2, 1.0)
	return super(p, j)


## A strider's gait: the legs step in diagonal pairs, front-right with
## back-left, and the hull bobs a little on each stride like a thing afloat.
func _gait_deltas(phase: float) -> Dictionary:
	var a := sin(phase * TAU)
	return {
		&"leg_fr": r(Vector3(0.0, 0.0, a * 0.16)),
		&"leg_bl": r(Vector3(0.0, 0.0, a * 0.16)),
		&"leg_fl": r(Vector3(0.0, 0.0, -a * 0.16)),
		&"leg_br": r(Vector3(0.0, 0.0, -a * 0.16)),
		&"hull": pr(Vector3(0.0, absf(a) * 0.06, 0.0), Vector3(a * 0.02, 0.0, 0.0)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	_t += delta
	# The pump keeps its timetable while it works and stops the moment it has
	# the player: a keeper that is watching you is not pumping.
	if not locked():
		(joints[&"drum"] as Node3D).rotation.z = _t * 1.6
