extends RefCounted
## A hover sled: a machine's two lift pods and the plate pan they were cut into,
## with a bed of boards strapped over the top by hand (docs/LOOK.md). The pan,
## the pods with the amber burning round their lips and the raked nose shield are
## FOUND. The bed, the bent yoke a person steers it by and every strap are MADE.
##
## Faces +X. The pods stand out either side of the pan, past the boards, so both
## idioms are in the silhouette from directly above — which is the only angle this
## game has (docs/LOOK.md, the fixed camera at 640x360).

const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")

const LENGTH := 0.86
## Pan half-width, bed half-width: the hand's half sits INSIDE the machine's.
const PAN_Z := 0.44
const BED_Z := 0.26
const PAN_TOP := 0.16
const BED_Y := 0.19
const POD_Z := 0.56
const POD_R := 0.25
const POD_TOP := 0.24


## The machines' own amber (works.gd is the one place that colour is written) at
## the faintest steady strength found.gdshader draws: a duct ticking over, not a
## working part.
static func lift() -> Color:
	return Color(Works.WORKING.r, Works.WORKING.g, Works.WORKING.b, 0.955)


## The machine half: the pan, two lift pods, and the shield somebody raked over
## the bow of it.
static func found(k: MeshKit, broken: bool) -> void:
	k.style = Ink.NONE
	k.style2 = Ink.NONE
	# The pan: a six-sided plate stretched long, chamfered in to its top face, so
	# nothing about it is a box.
	k.at(0.0, 0.0, 0.0, 0.0, Vector3(LENGTH / 0.6, 1.0, PAN_Z / 0.6))
	k.prism(0.0, 0.03, 0.0, 0.54, PAN_TOP, 0.6, 6, P.PLATE[2], P.PLATE[3])
	k.pop()
	for side: int in [-1, 1]:
		# Wrecked: the starboard pod was torn off and is somewhere behind.
		if side > 0 and broken:
			continue
		var z := side * POD_Z
		# The pod: a drum of plate standing out past the bed, riveted at the collar.
		k.prism(0.0, 0.0, z, POD_R, POD_TOP, POD_R - 0.04, 8, P.PLATE[3], P.PLATE[4])
		k.prism(0.0, POD_TOP - 0.01, z, POD_R - 0.09, POD_TOP + 0.05, POD_R - 0.13, 8, P.PLATE[4], P.PLATE[2])
		# The lift, in a thin band round the pod's lip: the machine's own light, and
		# the one warm thing on the craft. Dim, and a finger's width of it — two
		# full rings at a working part's strength were the brightest thing in the
		# frame, which a salvaged duct idling under a sledge has no business being
		# (docs/LOOK.md: the machines get ONE warm read, and this is not it).
		# On a wreck it is out, the way a machine's light goes out when it dies.
		k.prism(0.0, POD_TOP - 0.055, z, POD_R + 0.01, POD_TOP - 0.03, POD_R + 0.01, 8, lift() if not broken else P.PLATE[1])
		# The arm the pod was hung off the pan by.
		k.strut(Vector3(0.0, PAN_TOP - 0.05, side * (PAN_Z - 0.06)), Vector3(0.0, POD_TOP - 0.1, z), 0.07, 6, P.PLATE[2])
	# The nose shield: a cut plate raked back over the bow, one corner taken off,
	# so its face is turned up to the light and reads as plate and not as a hole.
	# (The lit face is the one wound counter-clockwise seen from ABOVE: wound the
	# other way, the shield's dark underside is what the fixed camera gets, and it
	# reads as a hole cut in the bow.)
	var xn := LENGTH + 0.1
	k.quad(Vector3(xn - 0.4, 0.38, -PAN_Z + 0.02), Vector3(xn - 0.4, 0.38, PAN_Z - 0.14),
		Vector3(xn, PAN_TOP - 0.02, PAN_Z - 0.02), Vector3(xn, PAN_TOP - 0.02, -PAN_Z + 0.02),
		P.PLATE[4] if not broken else P.PLATE[2])
	k.quad(Vector3(xn - 0.02, PAN_TOP - 0.04, -PAN_Z + 0.02), Vector3(xn - 0.02, PAN_TOP - 0.04, PAN_Z - 0.02),
		Vector3(xn - 0.42, 0.37, PAN_Z - 0.14), Vector3(xn - 0.42, 0.37, -PAN_Z + 0.02), P.PLATE[1])


## The hand's half: boards over the pan, a bent yoke to steer by, and the straps
## holding both to a plate that was never meant to carry them.
static func made(k: MeshKit, broken: bool) -> void:
	k.style = Ink.HAND
	k.style2 = Ink.HAND
	var boards := 4
	for i in boards:
		var t := float(i) / float(boards - 1)
		var z := lerpf(-BED_Z, BED_Z, t)
		var wobble := sin(float(i) * 2.11) * 0.06
		var lift := BED_Y + sin(float(i) * 1.7) * 0.012
		k.strut(Vector3(-LENGTH + 0.1 + wobble, lift, z), Vector3(LENGTH - 0.16 + wobble * 0.5, lift, z), 0.062, 5,
			P.EARTH[2] if i % 2 == 0 else P.EARTH[3])
	# Straps right across the bed and down over the pan's rim: the join, laid a
	# little off true where it crosses the plate.
	for x: float in [-0.46, 0.1, 0.56]:
		var off := sin(x * 5.0) * 0.04
		k.strut(Vector3(x + off, BED_Y + 0.07, -PAN_Z - 0.02), Vector3(x - off, BED_Y + 0.05, PAN_Z + 0.02), 0.03, 4, P.SAND[3])
	if broken:
		# The yoke snapped at one foot and the bar hangs over the pan.
		k.strut(Vector3(0.36, BED_Y, -0.24), Vector3(0.72, 0.28, -0.32), 0.05, 5, P.EARTH[3])
		k.strut(Vector3(0.72, 0.28, -0.32), Vector3(0.94, 0.12, 0.12), 0.045, 5, P.EARTH[2])
		return
	# The yoke: two bent spars off the bed to a cross bar where the hands go.
	for side: int in [-1, 1]:
		var z := side * 0.24
		k.strut(Vector3(0.3, BED_Y, z), Vector3(0.62, 0.56, z * 0.92), 0.052, 5, P.EARTH[3])
		k.strut(Vector3(0.62, 0.56, z * 0.92), Vector3(0.52, 0.82, z * 0.78), 0.046, 5, P.EARTH[3])
		# Lashed at the foot, with pitch under it.
		k.strut(Vector3(0.3, BED_Y + 0.05, z), Vector3(0.36, PAN_TOP - 0.01, z - side * 0.07), 0.032, 4, P.SAND[2])
	k.strut(Vector3(0.52, 0.82, -0.2), Vector3(0.52, 0.84, 0.2), 0.044, 5, P.LINEN[2])
	k.strut(Vector3(0.5, 0.86, -0.06), Vector3(0.54, 0.82, 0.08), 0.03, 4, P.SAND[3])
