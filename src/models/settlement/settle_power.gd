extends RefCounted
## Power and the one piece that shouts (docs/VISION.md §9): a spinner bodged out
## of plate blades on a lashed mast, cells stolen off a machine and strapped to a
## rack, and a mast that puts a person's voice on the machines' own air.
##
## These are the pieces a machine comes for, and they are drawn so a player can
## see that from a hillside: the spinner turns when there is wind in it, the
## cells' tell-tale burns when there is charge, and the mast is the tallest thing
## a holding has.

const Parts := preload("res://src/models/settlement/settle_parts.gd")
const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")

## Where a spinner's hub sits, so the model can hang its rotor there.
const HUB := Vector3(0.26, 2.48, 0.0)
const HUB_RUINED := Vector3(0.22, 1.24, 0.0)


# --- wind spinner -----------------------------------------------------------

## Three spars lashed into one tapering mast, guyed to pegs. It leans, because
## nobody had a plumb line.
static func spinner_made(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var top := (HUB_RUINED if ruined else HUB) + Vector3(0.0, -0.06, 0.0)
	for i in 3:
		var a := TAU * float(i) / 3.0 + Parts.lean(v, 10 + i, 0.3)
		var foot := Vector3(cos(a) * 0.3, 0.0, sin(a) * 0.3)
		Parts.post(k, foot, top + Vector3(Parts.lean(v, 20 + i, 0.03), 0.0, Parts.lean(v, 30 + i, 0.03)), 0.055,
			Parts.pick(Parts.TIMBER, v, 40 + i))
		Parts.stone(k, foot, 0.1, v, 50 + i)
	# The bands that hold the three together, a third and two thirds of the way up.
	for band in 2:
		var y := top.y * (0.34 + 0.34 * float(band))
		for i in 3:
			var a := TAU * float(i) / 3.0
			var b := TAU * float(i + 1) / 3.0
			var r := lerpf(0.3, 0.05, y / maxf(top.y, 0.01))
			Parts.lash(k, Vector3(cos(a) * r, y, sin(a) * r), Vector3(cos(b) * r, y, sin(b) * r), v, 60 + band * 3 + i, 0.024)
	if ruined:
		return
	# Guy cords out to two pegs, and the tail of rag that keeps it into the wind.
	for side: int in [-1, 1]:
		var peg := Vector3(-0.7, 0.0, side * 0.62)
		Parts.lash(k, top + Vector3(-0.04, -0.2, 0.0), peg, v, 70 + side, 0.02)
		k.strut(peg, peg + Vector3(0.0, 0.16, 0.0), 0.028, 4, Parts.pick(Parts.TIMBER, v, 80 + side))
	k.sway = 0.6
	k.sway_phase = Parts.wob(v, 90) * TAU
	var vane := Parts.pick(Parts.CLOTH, v, 91)
	Parts.flag(k, Vector3(-0.1, top.y - 0.16, 0.0), Vector3(-0.44, top.y - 0.12, -0.02),
		Vector3(-0.42, top.y + 0.04, -0.02), Vector3(-0.1, top.y + 0.02, 0.0), vane, P.SAND[1])
	k.sway = 0.0


## The hub: a bearing cut out of something that used to turn for the machines.
static func spinner_found(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.ruled(k)
	var hub := HUB_RUINED if ruined else HUB
	k.prism(hub.x - 0.06, hub.y - 0.09, hub.z, 0.11, hub.y + 0.09, 0.09, 8, P.PLATE[2], P.PLATE[3])
	k.strut(Vector3(hub.x - 0.1, hub.y, hub.z), Vector3(hub.x + 0.06, hub.y, hub.z), 0.05, 8, P.PLATE[4])
	if not ruined and Parts.wob(v, 100) < 0.6:
		Parts.tell_tale(k, Vector3(hub.x - 0.12, hub.y - 0.04, hub.z + 0.08), 0.03)


## The blades, drawn round the origin in the plane the wind turns them in, so the
## model can hang this on its own node and spin it. Mismatched on purpose: every
## one was cut off something different (docs/ART.md §10, nothing prefabricated).
static func spinner_rotor(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.ruled(k)
	var blades := 4 if Parts.wob(v, 110) < 0.5 else 5
	if ruined:
		blades = 2
	for i in blades:
		# Half a step round, so no blade stands straight down into the mast it is
		# bolted to and the cross is read whole.
		var a := TAU * (float(i) + 0.5) / float(blades)
		var length := 0.62 + Parts.wob(v, 120 + i) * 0.18
		var wide := 0.12 + Parts.wob(v, 130 + i) * 0.07
		var dir := Vector3(0.0, cos(a), sin(a))
		var side := Vector3(0.0, -sin(a), cos(a))
		# Salvaged sheet, not a machine's body: the lighter steps of the ramp, so a
		# rotor reads against a dark sky as well as against the turf under it.
		var col := P.PLATE[3 + i % 3]
		# A blade is a long tapered plate set at a pitch nobody agreed on. It is
		# drawn both ways round because a rotor turns through the camera.
		var pitch := 0.07 + Parts.wob(v, 140 + i) * 0.06
		Parts.flag(k, side * wide - Vector3(pitch * 0.3, 0, 0), side * -wide + Vector3(pitch * 0.3, 0, 0),
			dir * length - side * (wide * 0.45) + Vector3(pitch, 0, 0),
			dir * length + side * (wide * 0.45) - Vector3(pitch, 0, 0), col, P.PLATE[2])
		# The rib the blade was cut with, ruled along it.
		k.strut(dir * 0.1, dir * (length - 0.04), 0.018, 4, P.PLATE[4])


# --- battery stack ----------------------------------------------------------

## A rack of timber with stolen cells strapped to it: the hand's frame, the
## machine's cans, and the straps crossing the rivet rows.
static func battery_made(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var high := 0.72 if not ruined else 0.3
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			var foot := Vector3(sx * 0.24, 0.0, sz * 0.2)
			Parts.post(k, foot, foot + Vector3(Parts.lean(v, 10 + sx + sz, 0.04), high, 0.0), 0.048,
				Parts.pick(Parts.TIMBER, v, 20 + sx * 2 + sz))
	for i in 2:
		var y := high * (0.35 + 0.6 * float(i))
		k.strut(Vector3(-0.26, y, -0.2), Vector3(0.26, y + 0.01, -0.2), 0.04, 4, Parts.pick(Parts.TIMBER, v, 30 + i))
		k.strut(Vector3(-0.26, y, 0.2), Vector3(0.26, y - 0.01, 0.2), 0.04, 4, Parts.pick(Parts.TIMBER, v, 32 + i))
	Parts.stone(k, Vector3(-0.28, 0.0, 0.0), 0.11, v, 40)
	if ruined:
		return
	# The straps over the cans, crossing where their bands run.
	for i in 3:
		var x := lerpf(-0.17, 0.17, (float(i) + 0.5) / 3.0)
		Parts.lash(k, Vector3(x, 0.14, -0.22), Vector3(x, 0.52, 0.22), v, 50 + i, 0.025)


static func battery_found(k: MeshKit, v: int, ruined: bool, lit: bool) -> void:
	Parts.ruled(k)
	if ruined:
		# Split open and cold: what a raid leaves of a power stack.
		k.prism(0.0, 0.0, 0.0, 0.14, 0.2, 0.15, 8, P.PLATE[1], P.PLATE[1])
		k.prism(0.26, 0.0, 0.1, 0.12, 0.14, 0.13, 7, P.PLATE[1], P.PLATE[1])
		return
	for i in 3:
		var x := lerpf(-0.17, 0.17, (float(i) + 0.5) / 3.0)
		var h := 0.42 + Parts.wob(v, 60 + i) * 0.1
		k.prism(x, 0.1, Parts.lean(v, 70 + i, 0.03), 0.09, 0.1 + h, 0.085, 8, P.PLATE[3], P.PLATE[4])
		# Two bands round each can, where it was cut out of its bay.
		for band in 2:
			var y := 0.18 + h * (0.3 + 0.45 * float(band))
			k.strut(Vector3(x, y, 0.0), Vector3(x, y + 0.025, 0.0), 0.095, 8, P.PLATE[2])
		# The cable, spliced and run along the outside of the rack.
		k.strut(Vector3(x, 0.1 + h, 0.0), Vector3(x + 0.03, 0.1 + h + 0.07, 0.1), 0.02, 5, P.PLATE[1])
	k.strut(Vector3(-0.2, 0.62, 0.1), Vector3(0.3, 0.58, 0.12), 0.022, 5, P.PLATE[1])
	# The tell-tale: amber while there is charge in it, a dead lens when there is not.
	if lit:
		Parts.tell_tale(k, Vector3(0.3, 0.6, 0.12), 0.035)
	else:
		k.prism(0.3, 0.6, 0.12, 0.035, 0.66, 0.025, 6, P.LENS[0], P.LENS[0])


# --- radio mast -------------------------------------------------------------

## The tallest thing a holding has, and the loudest. Three spars, guys to three
## pegs, a vane off a relay at the top and a box at the foot that blinks.
static func mast_made(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var top := (1.3 if ruined else 3.0) + Parts.wob(v, 1) * 0.2
	var head := Vector3(Parts.lean(v, 2, 0.08), top, Parts.lean(v, 3, 0.08))
	for i in 3:
		var a := TAU * float(i) / 3.0 + Parts.lean(v, 10 + i, 0.25)
		var foot := Vector3(cos(a) * 0.24, 0.0, sin(a) * 0.24)
		Parts.post(k, foot, head + Vector3(cos(a) * 0.04, 0.0, sin(a) * 0.04), 0.045, Parts.pick(Parts.TIMBER, v, 20 + i))
	# Cross-lashings up the mast: the rungs somebody climbs it on.
	var bands := 4 if not ruined else 2
	for band in bands:
		var t := (float(band) + 0.6) / float(bands + 1)
		var y := top * t
		var r := lerpf(0.24, 0.05, t)
		for i in 3:
			var a := TAU * float(i) / 3.0
			var b := TAU * float(i + 1) / 3.0
			Parts.lash(k, Vector3(cos(a) * r, y, sin(a) * r), Vector3(cos(b) * r, y, sin(b) * r), v, 30 + band * 3 + i, 0.022)
	if ruined:
		return
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.5
		var peg := Vector3(cos(a) * 0.95, 0.0, sin(a) * 0.95)
		Parts.lash(k, head + Vector3(0.0, -0.3, 0.0), peg, v, 50 + i, 0.018)
		k.strut(peg, peg + Vector3(0.0, 0.14, 0.0), 0.026, 4, Parts.pick(Parts.TIMBER, v, 60 + i))


static func mast_found(k: MeshKit, v: int, ruined: bool, lit: bool) -> void:
	Parts.ruled(k)
	var top := (1.3 if ruined else 3.0) + Parts.wob(v, 1) * 0.2
	if ruined:
		# The vane down in the grass beside the stump of its own mast.
		Parts.panel(k, Vector3(0.6, 0.02, 0.3), PI * 0.46)
		Parts.plate(k, 0.16, 0.34, v, 70)
		k.pop()
		return
	# The vane: a relay's ear, cut off square and bolted on askew, because a
	# person put it there and nobody told them which way it should look.
	Parts.panel_facing(k, Vector3(0.0, top - 0.06, 0.0), Vector3(0.8, 0.0, 0.3))
	Parts.plate(k, 0.17, 0.42, v, 71)
	k.pop()
	k.strut(Vector3(0.0, top - 0.1, 0.0), Vector3(0.0, top + 0.34, 0.0), 0.022, 6, P.PLATE[4])
	# The box at the foot, and its lamp: on when the mast has power in it.
	k.prism(0.22, 0.0, 0.16, 0.12, 0.3, 0.1, 7, P.PLATE[2], P.PLATE[3])
	k.strut(Vector3(0.22, 0.3, 0.16), Vector3(0.06, 0.9, 0.04), 0.018, 5, P.PLATE[1])
	if lit:
		Parts.tell_tale(k, Vector3(0.22, 0.3, 0.1), 0.032)
		Parts.strip(k, Vector3(0.0, top + 0.3, 0.0), Vector3(0.0, top + 0.36, 0.0), 0.03)
	else:
		k.prism(0.22, 0.3, 0.1, 0.032, 0.36, 0.024, 6, P.LENS[0], P.LENS[0])


# --- solar array ------------------------------------------------------------

## The spinner's opposite number: panels cut off something that used to power the
## machines, raked up to the sun on a frame somebody knocked together.
##
## It must not read as a plate wall lying down, so the frame is a visible RAKE —
## legs short at the front and long at the back, braced, holding the panels
## clearly ABOVE the ground and clearly at an angle. The panels are mismatched,
## as every found thing here is: they came off three different machines and
## nobody had a saw that would true them.
const RAKE := 0.62
## The front and back lip of the array's face, so the made half and the found
## half cannot drift apart.
const PANEL_LOW := 0.34
const PANEL_HIGH := 0.92


static func solar_made(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var half := 0.56 + Parts.wob(v, 1) * 0.08
	var low := PANEL_LOW if not ruined else 0.12
	var high := PANEL_HIGH if not ruined else 0.34
	for side: int in [-1, 1]:
		var z := side * half
		var front := Vector3(RAKE * 0.5, 0.0, z)
		var back := Vector3(-RAKE * 0.5, 0.0, z)
		# The short front leg and the long back one: the rake, read from the side.
		Parts.post(k, front, Vector3(front.x + Parts.lean(v, 10 + side, 0.03), low, z), 0.05,
			Parts.pick(Parts.TIMBER, v, 20 + side))
		Parts.post(k, back, Vector3(back.x + Parts.lean(v, 12 + side, 0.04), high, z), 0.05,
			Parts.pick(Parts.TIMBER, v, 22 + side))
		Parts.stone(k, front, 0.1, v, 30 + side)
		Parts.stone(k, back, 0.1, v, 32 + side)
		# The rail the panels are bolted to, and the brace under it.
		k.strut(Vector3(front.x, low, z), Vector3(back.x, high, z), 0.04, 4, Parts.pick(Parts.TIMBER, v, 40 + side))
		k.strut(Vector3(front.x, low * 0.45, z), Vector3(back.x * 0.2, high * 0.62, z), 0.03, 4,
			Parts.pick(Parts.TIMBER, v, 42 + side))
	if ruined:
		return
	# Cross-pieces between the two rails, and lashings at the head: nothing here
	# was bolted, because nobody had bolts that fitted.
	for i in 2:
		var t := 0.22 + 0.5 * float(i)
		var y := lerpf(low, high, t)
		var x := lerpf(RAKE * 0.5, -RAKE * 0.5, t)
		k.strut(Vector3(x, y, -half), Vector3(x, y + 0.01, half), 0.03, 4, Parts.pick(Parts.TIMBER, v, 50 + i))
	for side: int in [-1, 1]:
		Parts.lash(k, Vector3(-RAKE * 0.5, high, side * half), Vector3(-RAKE * 0.5 - 0.06, high - 0.12, side * half),
			v, 60 + side, 0.022)


## The panels themselves, and the box they run into. `lit` is the holding having
## charge to show for it — the same tell-tale the battery stack and the mast
## carry, so a player reads all three the same way.
static func solar_found(k: MeshKit, v: int, ruined: bool, lit: bool) -> void:
	Parts.ruled(k)
	var half := 0.56 + Parts.wob(v, 1) * 0.08
	if ruined:
		# Off the frame and face down, one corner still hanging on.
		Parts.panel(k, Vector3(0.24, 0.03, -0.2), PI * 0.47)
		Parts.plate(k, 0.3, 0.34, v, 70)
		k.pop()
		Parts.panel(k, Vector3(-0.3, 0.05, 0.3), PI * 0.42, -1)
		Parts.plate(k, 0.22, 0.26, v, 71)
		k.pop()
		return
	# Three panels along the rake, each a different size and none of them square
	# to the next, drawn as a face on the slope the frame makes.
	for i in 3:
		var t0 := float(i) / 3.0
		var t1 := float(i + 1) / 3.0 - 0.02
		var z0 := lerpf(-half + 0.04, half - 0.04, t0)
		var z1 := lerpf(-half + 0.04, half - 0.04, t1)
		var mid := (z0 + z1) * 0.5
		# A shade of its own: they were cut off three different machines.
		var face := P.PLATE[2 + i % 3]
		var lip := 0.03 + Parts.wob(v, 80 + i) * 0.04
		# Wound so the face looks at the SKY. `MeshKit.tri` authors CCW and takes its
		# normal from `(c - b).cross(a - b)`; the order that reads naturally here puts
		# it face down, and a face-down panel is not dark, it is culled and absent.
		var a := Vector3(RAKE * 0.5 - lip, PANEL_LOW + 0.03, z1)
		var b := Vector3(RAKE * 0.5 - lip, PANEL_LOW + 0.03, z0)
		var c := Vector3(-RAKE * 0.5 + 0.02, PANEL_HIGH + 0.03, z0)
		var d := Vector3(-RAKE * 0.5 + 0.02, PANEL_HIGH + 0.03, z1)
		k.quad(a, b, c, d, face)
		# The cell rows, ruled down the panel: what says this is machine work and
		# not a sheet of plate laid on a frame.
		for row in 3:
			var t := 0.22 + 0.29 * float(row)
			k.strut(a.lerp(d, t), b.lerp(c, t), 0.012, 4, P.PLATE[4])
		# The bracket holding its low edge down to the rail.
		k.strut(Vector3(RAKE * 0.5 - lip, PANEL_LOW + 0.03, mid), Vector3(RAKE * 0.5, PANEL_LOW - 0.06, mid),
			0.018, 5, P.PLATE[1])
	# The junction box at the high end, and the cable run back up to the panels.
	k.prism(-RAKE * 0.5 - 0.1, 0.0, half * 0.5, 0.1, 0.28, 0.08, 7, P.PLATE[2], P.PLATE[3])
	k.strut(Vector3(-RAKE * 0.5 - 0.1, 0.28, half * 0.5), Vector3(-RAKE * 0.5 + 0.02, PANEL_HIGH - 0.02, half * 0.3),
		0.02, 5, P.PLATE[1])
	if lit:
		Parts.tell_tale(k, Vector3(-RAKE * 0.5 - 0.1, 0.28, half * 0.5 - 0.08), 0.032)
	else:
		k.prism(-RAKE * 0.5 - 0.1, 0.28, half * 0.5 - 0.08, 0.032, 0.34, 0.024, 6, P.LENS[0], P.LENS[0])
