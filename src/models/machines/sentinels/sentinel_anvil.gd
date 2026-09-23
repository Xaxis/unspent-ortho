extends MachineModel
## THE ANVIL: the Glass Desert's keeper (docs/LANDSCAPES.md, src/core/sentinel/
## designs/anvil.gd). A tall three-legged mast on wide skates, a copper crown of
## rods at the top, and a heavy shielded core slung low between the legs.
##
## Why a CANDELABRUM ON SKATES. The coast's keeper is an arch, the flats' a delta
## on stilts, the crags' a thin tripod over a pendulum: no two keepers may share
## a silhouette (VISION §3), and this one is built out of the opposite weight
## distribution to all of them. Everything heavy is at the BOTTOM — the core hangs
## a person's height off the glass between three splayed legs — and everything
## above it is a single line drawn eight units up to a spray of copper points.
## On the flattest, brightest, emptiest ground in the game a body reads by what
## it holds up against the sky, and a mast with a crown is the one vertical on a
## landscape whose every other line lies flat. At a hundred tiles it is a pin in
## the glare; at fighting range the core between the skates is where a blow
## counts, and the crown is the tell.
##
## It is drawn by a ruler: the legs are two straight members and a brace each at
## one angle, the mast is one tapered member with a collar and three guys, the
## crown is rods on exact pitch out of a turned cup, and the skates are one
## ruled blade each. Its colour is the KEEPER's ramp (Palette: a machine's colour
## is its role); the crown alone is copper, which is what a thing built to be
## struck by lightning has to be made of.
##
## Poses. The mast is the whole vocabulary: an eight-unit line leaning is enormous
## on screen, and the skates say the rest.
## walk   SKATING: the back skates push alternately, the mast leans into the run
## stand  stopped on the plates: the hub settles, the crown stows a little
## alert  it has you: the hub rises on all three legs, the skates dig in and
##        splay, the mast comes forward over you
## windup the mast REARS BACK and the crown tips to the sky; the front skate
##        lifts off the glass — the strike is called down, not thrown
## strike the whole mast whips forward and the hub drops through its knees
## hurt   the crown slews
## dead   the mast comes down its full length across the glass, the legs go out
##        from under the hub and the core comes to rest on the sand: a fallen
##        candelabrum, which is the one silhouette that says a keeper died here
##
## lights cold lamps at three crown points (the crown that glows white when it
##        calls), a cold slit under the hub reading the sand ahead with a scan,
##        the plan strip on the mast's face where a high camera cannot miss it,
##        and the amber drive at the back of the core: the working part
## wear   sand caked up every skate strut, the left leg scorched where a strike
##        came down its own mast, one crown rod snapped short, plate off another
##        kind patched over the core, a cable run down the mast

## The hub, the mast and the crown: the heights the whole body is ruled from.
const HUB_Y := 3.0
const MAST_H := 4.1
const COLLAR_Y := 2.0
const CORE_DROP := 1.55
## Where the three skates stand: a tile and a half out from the hub's centre.
const FOOT_R := 1.5
const KNEE_R := 1.12
const KNEE_Y := 1.45
const FOOT_Y := 0.36
## A rod's crease: an eight-sided member's facets meet at 45 degrees, so a
## weld at this angle rounds it and leaves the chamfered ends and the caps hard.
const ROUND := 50.0

var _t := 0.0


func build() -> void:
	part_side = &"back"
	# The crown's highest point: a tell drawn over this body has to clear it.
	height = 8.2
	stride = 2.4
	nominal_speed = 2.0
	gallery_turn = 40.0
	# Same reason as the reaper's drum: a big working part at the default burns
	# to white and the amber goes out of it (docs/LOOK.md).
	emission = 0.28
	begin_rig()
	ramp = Palette.MACHINE["warden"]
	disposition = &"wary"
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)

	var hub := joint(&"hub", self, Vector3(0, HUB_Y, 0))
	_hub(hub, R, D)
	_legs(hub, R, D, DD)
	_core(hub, R, D)
	_mast(hub, R, D, DD)
	finish_rig()


## Weld the shape pushed since `from`: the same triangles, told where they curve.
static func _weld(k: MeshKit, from: int, crease: float = ROUND) -> void:
	k.smooth_range(from, k.vertex_count(), crease)


## The knot the three legs, the mast and the core all hang off, with the slit it
## reads the sand through under its front lip.
func _hub(hub: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	var s := k.vertex_count()
	FoundKit.lathe(k, Vector3.ZERO, Vector3.UP, [Vector2(0.24, -0.32), Vector2(0.4, -0.2), Vector2(0.42, 0.14), Vector2(0.3, 0.26), Vector2(0.2, 0.3)], 10, R, PI / 10.0)
	_weld(k, s)
	FoundKit.visor(k, Vector3(0.41, -0.04, 0.0), Vector3.RIGHT, Vector3.UP, 0.34, 0.04)
	FoundKit.rivets(k, Vector3(0.41, 0.1, -0.14), Vector3(0.41, 0.1, 0.14), Vector3.RIGHT, 4, R[5])
	FoundKit.seam(k, Vector3(-0.2, 0.15, -0.34), Vector3(-0.2, 0.15, 0.34), Vector3.UP, R, 4)
	body_mesh(k, hub)
	add_scan(hub, Vector3(0.412, -0.04, 0.0), Vector3.RIGHT, Vector3.BACK, 0.28, 0.034, 2.0)
	day_wear(hub, Vector3(0.0, 0.27, 0.0), Vector3.UP, Vector3.RIGHT, 0.4, 0.4, 201, 1)
	var w := FoundKit.kit()
	FoundKit.grime(w, Vector3(-0.28, 0.1, 0.24), Vector3(-0.6, 0, 0.8).normalized(), 0.2, 0.3, 3, 202, D)
	wear_mesh(w, hub)


## Three legs off the hub, one leading and two behind, each two straight members
## and a brace, ending in a SKATE: a ruled blade along the line of travel with a
## turned-up toe, on a chamfered bridge. Sand cakes the struts to the knee; the
## left leg is scorched down its length where its own strike ran down it.
func _legs(hub: Node3D, R: Array, D: Array, DD: Array) -> void:
	var sand: Array = [Palette.SAND[2], Palette.SAND[3], Palette.SAND[4], Palette.SAND[3], Palette.SAND[4], Palette.SAND[5]]
	var specs := [[0.0, &"leg_f"], [TAU / 3.0, &"leg_r"], [-TAU / 3.0, &"leg_l"]]
	for i in specs.size():
		var a: float = specs[i][0]
		var jn: StringName = specs[i][1]
		var u := Vector3(cos(a), 0.0, sin(a))
		var leg := joint(jn, hub, u * 0.3 + Vector3(0, -0.12, 0))
		var knee := u * (KNEE_R - 0.3) + Vector3(0, KNEE_Y - HUB_Y + 0.12, 0)
		var foot := u * (FOOT_R - 0.3) + Vector3(0, FOOT_Y - HUB_Y + 0.12, 0)
		var k := FoundKit.kit()
		var s := k.vertex_count()
		FoundKit.tbar(k, Vector3.ZERO, knee, 0.13, 0.1, 8, R, 0.02)
		_weld(k, s)
		s = k.vertex_count()
		FoundKit.tbar(k, knee, foot, 0.1, 0.075, 8, D, 0.02)
		_weld(k, s)
		FoundKit.tbar(k, u * 0.08 + Vector3(0, -0.36, 0), knee.lerp(foot, 0.35), 0.04, 0.03, 4, DD)
		FoundKit.disc(k, knee, u.cross(Vector3.UP).normalized(), 0.13, 0.1, 8, 0.015, D)
		body_mesh(k, leg)
		# The skate: every blade points down the line of travel whatever leg it is
		# on, because that is what makes three legs glide instead of walk.
		var skate := joint(StringName(String(jn).replace("leg", "skate")), leg, foot)
		var sk := FoundKit.kit()
		FoundKit.cbox(sk, Vector3(0.0, -0.06, 0.0), Vector3(0.36, 0.12, 0.14), 0.02, D, 0)
		var blade: Array[Vector2] = [Vector2(-0.72, -0.36), Vector2(0.7, -0.36), Vector2(0.8, -0.24),
			Vector2(0.6, -0.12), Vector2(-0.5, -0.12), Vector2(-0.76, -0.24)]
		FoundKit.slab(sk, Vector3.ZERO, Vector3.RIGHT, Vector3.UP, blade, 0.07, DD, 0.012)
		FoundKit.rivets(sk, Vector3(-0.4, -0.16, 0.04), Vector3(0.4, -0.16, 0.04), Vector3.BACK, 4, R[5], FoundKit.PX * 1.4)
		body_mesh(sk, skate)
		var w := FoundKit.kit()
		var n := u.cross(Vector3.UP).normalized()
		FoundKit.grime(w, foot + Vector3(0, 0.46, 0), n, 0.14, 0.4, 3, 211 + i, sand)
		if jn == &"leg_l":
			# Its own lightning, once, down the wrong leg: the phase-three side.
			FoundKit.scorch(w, knee.lerp(foot, 0.5) + n * 0.09, n, 0.12, 215)
			FoundKit.streaks(w, knee + n * 0.1, n, 0.12, 0.6, 4, 216, Palette.INK[1])
		wear_mesh(w, leg)
		# Drift sand banked against the skate's heel, drawn by the hand.
		var m := FoundKit.matter_kit(Ink.HAND)
		m.rock(-0.5, -0.36, 0.0, 0.16, 0.06, 470 + i, Palette.LINEN[4], 5)
		wear_matter(m, skate)


## The core, hung low between the skates on three hangers: a turned drum with a
## charge shield bolted over its face and the amber DRIVE standing proud of its
## back — the working part, out where a player has to come round behind a body
## that is looking at them.
func _core(hub: Node3D, R: Array, D: Array) -> void:
	var core := joint(&"core", hub, Vector3(0, -CORE_DROP, 0))
	var k := FoundKit.kit()
	var s := k.vertex_count()
	FoundKit.lathe(k, Vector3.ZERO, Vector3.UP, [Vector2(0.3, -0.5), Vector2(0.48, -0.38), Vector2(0.52, 0.3), Vector2(0.42, 0.44), Vector2(0.24, 0.5)], 10, R, PI / 10.0)
	_weld(k, s)
	for j in 3:
		var a := j * TAU / 3.0 + PI / 3.0
		var top := Vector3(cos(a) * 0.2, CORE_DROP - 0.3, sin(a) * 0.2)
		FoundKit.tbar(k, Vector3(cos(a) * 0.3, 0.42, sin(a) * 0.3), top, 0.045, 0.04, 6, D)
	# The charge shield: one ruled plate over the face, riveted, which is what a
	# blow rings off while it calls.
	var shield: Array[Vector2] = [Vector2(-0.36, -0.3), Vector2(0.36, -0.3), Vector2(0.44, 0.0),
		Vector2(0.36, 0.3), Vector2(-0.36, 0.3), Vector2(-0.44, 0.0)]
	FoundKit.slab(k, Vector3(0.6, 0.0, 0.0), Vector3.UP, Vector3.BACK, shield, 0.06, R, 0.01)
	FoundKit.rivets(k, Vector3(0.635, 0.24, -0.26), Vector3(0.635, 0.24, 0.26), Vector3.RIGHT, 5, R[5])
	FoundKit.rivets(k, Vector3(0.635, -0.24, -0.26), Vector3(0.635, -0.24, 0.26), Vector3.RIGHT, 5, R[5])
	FoundKit.seam(k, Vector3(0.0, 0.51, -0.3), Vector3(0.0, 0.51, 0.3), Vector3.UP, R, 3)
	FoundKit.panel(k, Vector3(0.0, 0.0, 0.53), Vector3.BACK, Vector3.UP, 0.4, 0.5, R)
	body_mesh(k, core)
	day_wear(core, Vector3(0.64, 0.0, 0.0), Vector3.RIGHT, Vector3.UP, 0.5, 0.5, 221, 1)
	day_marks(core, Vector3(0.0, 0.0, -0.53), Vector3.FORWARD, Vector3.UP, 0.6, 0.5, 222)
	var w := FoundKit.kit()
	FoundKit.patch(w, Vector3(0.1, 0.12, 0.53), Vector3.BACK, Vector3.UP, 0.3, 0.26, Palette.MACHINE["hauler"], 223)
	FoundKit.grime(w, Vector3(0.0, -0.2, -0.5), Vector3.FORWARD, 0.6, 0.24, 5, 224, D)
	wear_mesh(w, core)
	# The drive: a turned amber barrel with its vanes, standing proud of the back.
	var drive := joint(&"drive", core, Vector3(-0.5, 0.0, 0.0))
	var dk := FoundKit.kit()
	var barrel: Array = [Palette.LENS[0], Palette.LENS[0], Palette.LENS[1], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2]]
	var amber: Array = [Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3], Palette.LENS[3]]
	FoundKit.lathe(dk, Vector3.ZERO, Vector3.LEFT, [Vector2(0.14, 0.0), Vector2(0.22, 0.05), Vector2(0.22, 0.24), Vector2(0.14, 0.3)], 10, barrel, PI / 10.0)
	for j in 8:
		var a := j * TAU / 8.0
		var at := Vector3(-0.15, cos(a) * 0.22, sin(a) * 0.22)
		var out := Vector3(0.0, cos(a), sin(a))
		FoundKit.slab(dk, at + out * 0.04, out, Vector3.LEFT,
			[Vector2(-0.05, 0.04), Vector2(0.08, 0.02), Vector2(0.08, -0.02), Vector2(-0.05, -0.04)], 0.2, amber)
	part_mesh(dk, drive)
	set_part_anchor(core, Vector3(-0.7, 0.0, 0.0), 1.0)


## The mast: one tapered member from the hub to the crown, a collar with three
## guys down to the knees, graduations a survey would read, and the plan strip
## on its face. The CROWN on top of it: a turned cup and seven copper rods on
## exact pitch, one snapped short, with cold points at three of them.
func _mast(hub: Node3D, R: Array, D: Array, DD: Array) -> void:
	var mast := joint(&"mast", hub, Vector3(0, 0.22, 0))
	var k := FoundKit.kit()
	var s := k.vertex_count()
	FoundKit.tbar(k, Vector3.ZERO, Vector3(0, MAST_H, 0), 0.17, 0.11, 8, R, 0.02)
	_weld(k, s)
	s = k.vertex_count()
	FoundKit.lathe(k, Vector3(0, COLLAR_Y, 0), Vector3.UP, [Vector2(0.15, -0.1), Vector2(0.24, -0.03), Vector2(0.24, 0.08), Vector2(0.15, 0.15)], 8, D, PI / 8.0)
	_weld(k, s)
	FoundKit.ticks(k, Vector3(0.17, 0.3, 0.0), Vector3(0.14, COLLAR_Y - 0.2, 0.0), Vector3.RIGHT, 10, R[5], 0.03)
	for j in 3:
		var a := j * TAU / 3.0
		var u := Vector3(cos(a), 0.0, sin(a))
		var knee := u * KNEE_R + Vector3(0, KNEE_Y - HUB_Y - 0.22, 0)
		FoundKit.tbar(k, u * 0.22 + Vector3(0, COLLAR_Y, 0), knee, 0.022, 0.018, 4, DD)
	body_mesh(k, mast)
	# The strip on the mast's face: seen from a high camera on the brightest
	# ground in the game, the one plate a player counts its mind off.
	add_lamp(mast, Vector3(0.155, 0.9, 0.0), Vector3.RIGHT, Vector3.UP, 0.07, 0.08, &"status")
	day_wear(mast, Vector3(0.0, 1.2, -0.15), Vector3.FORWARD, Vector3.UP, 0.2, 0.9, 231, 1)
	var w := FoundKit.kit()
	FoundKit.cable(w, Vector3(-0.2, COLLAR_Y - 0.1, 0.1), Vector3(-0.24, 0.1, 0.24), 0.08, 0.02, Palette.INK[2], Palette.MACHINE["lineman"], 5)
	FoundKit.streaks(w, Vector3(0.14, COLLAR_Y - 0.12, 0.0), Vector3.RIGHT, 0.16, 0.7, 3, 232, R[1])
	wear_mesh(w, mast)

	var crown := joint(&"crown", mast, Vector3(0, MAST_H, 0))
	var ck := FoundKit.kit()
	s = ck.vertex_count()
	FoundKit.lathe(ck, Vector3.ZERO, Vector3.UP, [Vector2(0.11, 0.0), Vector2(0.3, 0.1), Vector2(0.34, 0.26), Vector2(0.24, 0.34)], 8, R, PI / 8.0)
	_weld(ck, s)
	# Copper: what a thing built to be struck has to be made of. The darker steps
	# of the ramp, so the crown reads as bronze under the sun and the amber drive
	# stays the one saturated thing on the machine (Palette, the machine ramps).
	var copper: Array = [Palette.COPPER[0], Palette.COPPER[1], Palette.COPPER[1], Palette.COPPER[2], Palette.COPPER[3], Palette.COPPER[3]]
	FoundKit.tbar(ck, Vector3(0, 0.3, 0), Vector3(0, 0.9, 0), 0.04, 0.0, 6, copper)
	for j in 7:
		var a := j * TAU / 7.0
		var dir := Vector3(cos(a) * 0.55, 0.8, sin(a) * 0.55).normalized()
		var root := Vector3(cos(a) * 0.2, 0.3, sin(a) * 0.2)
		# One rod snapped short: the machines are barely functioning.
		var run := 0.6 if j != 4 else 0.22
		FoundKit.tbar(ck, root, root + dir * run, 0.035, 0.022, 6, copper)
		if j == 0 or j == 2 or j == 5:
			var tip := root + dir * run
			add_lamp(crown, tip, dir, dir.cross(Vector3.UP).normalized(), 0.05, 0.05, &"work", false, Palette.COLD[3])
	body_mesh(ck, crown)
	var cw := FoundKit.kit()
	FoundKit.scorch(cw, Vector3(0.0, 0.35, 0.0), Vector3.UP, 0.14, 241)
	wear_mesh(cw, crown)


## Everything is said with the mast and the skates: a line eight units long
## leaning is the biggest gesture any machine in the game can make.
func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"stand":
			# Stopped on the plates: the hub settles on its legs, the crown stows.
			d[&"hub"] = pr(Vector3(0, -0.06, 0))
			d[&"crown"] = r(Vector3(0, 0, 0.08))
			d[&"leg_f"] = r(Vector3(0, 0, 0.04))
		&"alert":
			# It has you: the hub rises on all three legs, the skates dig in and
			# splay, and the mast comes forward over you.
			d[&"hub"] = pr(Vector3(0.02, 0.14, 0))
			d[&"mast"] = r(Vector3(0, 0, -0.06))
			d[&"crown"] = r(Vector3(0, 0, -0.14))
			d[&"leg_f"] = pr(Vector3(0.08, 0, 0), Vector3(0, 0, -0.12))
			d[&"leg_l"] = r(Vector3(0.16, 0, 0.06))
			d[&"leg_r"] = r(Vector3(-0.16, 0, 0.06))
		&"windup":
			# The mast REARS BACK and the crown tips to the sky: the strike is
			# called down, and the front skate lifts off the glass.
			d[&"hub"] = pr(Vector3(-0.06, 0.2, 0))
			d[&"mast"] = r(Vector3(0, 0, 0.24))
			d[&"crown"] = r(Vector3(0, 0, 0.3))
			d[&"core"] = pr(Vector3(-0.1, 0.1, 0))
			d[&"leg_f"] = pr(Vector3(0, 0.16, 0), Vector3(0, 0, 0.2))
			d[&"leg_l"] = r(Vector3(0.1, 0, 0))
			d[&"leg_r"] = r(Vector3(-0.1, 0, 0))
		&"strike":
			# And the whole mast whips forward as the hub drops through its knees.
			d[&"hub"] = pr(Vector3(0.12, -0.24, 0))
			d[&"mast"] = r(Vector3(0, 0, -0.3))
			d[&"crown"] = r(Vector3(0, 0, -0.34))
			d[&"core"] = pr(Vector3(0.16, -0.16, 0))
			d[&"leg_f"] = pr(Vector3(0.2, -0.04, 0), Vector3(0, 0, -0.16))
		&"hurt":
			d[&"crown"] = r(Vector3(0.2, 0, 0.1))
			d[&"mast"] = r(Vector3(0.06, 0, 0))
		&"dead":
			# The mast comes down its full length across the glass, the legs go
			# out from under the hub and the core comes to rest on the sand.
			d[&"hub"] = pr(Vector3(0.2, -1.9, 0.1), Vector3(0.1, 0, -0.2))
			d[&"mast"] = r(Vector3(0.1, 0, -1.4))
			d[&"crown"] = r(Vector3(0.3, 0, -0.4))
			d[&"core"] = pr(Vector3(0.1, 1.2, 0), Vector3(0.2, 0, 0.1))
			d[&"leg_f"] = r(Vector3(0, 0, -0.9))
			d[&"leg_l"] = r(Vector3(0.9, 0, 0.3))
			d[&"leg_r"] = r(Vector3(-0.9, 0, 0.3))
			d[&"skate_f"] = r(Vector3(0, 0, 0.6))
			d[&"skate_l"] = r(Vector3(-0.5, 0, 0))
			d[&"skate_r"] = r(Vector3(0.5, 0, 0))
	return d


## The mast is the last thing to come down: the legs go first, then it falls.
func _timing(p: StringName, j: StringName) -> Vector2:
	match p:
		&"dead":
			match j:
				&"mast": return Vector2(LIGHT_FIRST + 0.6, 0.45)
				&"crown": return Vector2(LIGHT_FIRST + 0.7, 0.4)
	return super(p, j)


## Skating: the two back skates push out and back in turn, the hub rolls with
## them, and the mast leans into the run.
func _gait_deltas(phase: float) -> Dictionary:
	var a := sin(phase * TAU)
	var b := sin(phase * TAU + PI)
	return {
		&"hub": pr(Vector3(0, absf(a) * 0.03, 0), Vector3(a * 0.03, 0, -0.03)),
		&"mast": r(Vector3(0, 0, -0.04 + absf(a) * 0.02)),
		&"crown": r(Vector3(0, 0, a * 0.03)),
		&"leg_l": r(Vector3(maxf(0.0, a) * 0.14, 0, a * 0.05)),
		&"leg_r": r(Vector3(-maxf(0.0, b) * 0.14, 0, b * 0.05)),
		&"leg_f": r(Vector3(0, 0, absf(a) * 0.04)),
	}


func _routine(delta: float, on: bool) -> void:
	if not on:
		return
	# The crown hunts the sky on its own slow cycle while it works and holds dead
	# still the moment it has the player (locked); the drive never stops turning.
	_t += delta
	(joints[&"crown"] as Node3D).rotation.y = 0.0 if locked() else _t * 0.35
	(joints[&"drive"] as Node3D).rotation.x = _t * 3.8
