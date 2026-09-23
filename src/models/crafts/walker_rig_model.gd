extends RefCounted
## A walker rig: a machine's legs, cut off at the hip and bound to a timber cradle
## a person stands in (docs/LOOK.md). The legs, the knee plates, the hip yoke
## and the power pack's amber eye are FOUND — straight members, exact joints,
## violet plate. The cradle, the shoulder bar, the handles and every strap are
## MADE, and the straps go through the holes somebody drilled in the yoke.
##
## Faces +X, stands a body and a half high. Parked, it is the haunting one: an
## empty frame of machine legs standing on the moor with its eye still lit.

const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")

const HIP_Y := 1.04
const TOP_Y := 1.66
## Wide enough that the rig is a FRAME round the body and not a coat on it: at
## 640x360 a figure and a rig the same width are one dark smudge.
const HIP_Z := 0.46


## The machine half: two legs off something that walked, and the yoke they were
## joined to.
static func found(k: MeshKit, broken: bool) -> void:
	k.style = Ink.NONE
	k.style2 = Ink.NONE
	for side: int in [-1, 1]:
		var z := side * HIP_Z
		# Buckled: the port leg folded under the rig and it stands on one knee.
		var down := broken and side < 0
		var knee := Vector3(-0.12, 0.46 if not down else 0.3, z + side * 0.14)
		var foot := Vector3(0.12, 0.05, z + side * 0.1)
		if down:
			knee = Vector3(-0.3, 0.26, z + side * 0.3)
			foot = Vector3(-0.62, 0.04, z + side * 0.42)
		# Thigh, shin: straight members, no taper the eye can argue with.
		k.strut(Vector3(-0.02, HIP_Y - 0.06, z), knee, 0.095, 7, P.PLATE[4])
		k.strut(knee, foot, 0.078, 7, P.PLATE[3])
		# The knee plate, chamfered: the joint the machine turned on.
		k.prism(knee.x, knee.y - 0.1, knee.z, 0.14, knee.y + 0.1, 0.1, 6, P.PLATE[5])
		# The foot: a flat five-sided pad, stamped out of the same plate.
		k.prism(foot.x, 0.0, foot.z, 0.26, 0.08, 0.22, 5, P.PLATE[3], P.PLATE[5])
	# The hip yoke: one cut beam across, the ends left as they were sheared.
	k.quad(Vector3(-0.1, HIP_Y - 0.09, -HIP_Z - 0.09), Vector3(-0.1, HIP_Y - 0.09, HIP_Z + 0.09),
		Vector3(-0.1, HIP_Y + 0.09, HIP_Z + 0.02), Vector3(-0.1, HIP_Y + 0.09, -HIP_Z - 0.02), P.PLATE[3])
	k.quad(Vector3(0.1, HIP_Y + 0.09, -HIP_Z - 0.02), Vector3(0.1, HIP_Y + 0.09, HIP_Z + 0.02),
		Vector3(0.1, HIP_Y - 0.09, HIP_Z + 0.09), Vector3(0.1, HIP_Y - 0.09, -HIP_Z - 0.09), P.PLATE[2])
	k.prism(0.0, HIP_Y - 0.11, 0.0, 0.22, HIP_Y + 0.12, 0.19, 6, P.PLATE[3], P.PLATE[5])
	if not broken:
		# The pack's eye, stood proud of the yoke: the one warm thing on it, and
		# lit from above, which is the only angle this game has.
		k.prism(0.19, HIP_Y + 0.04, 0.0, 0.09, HIP_Y + 0.18, 0.07, 6, Works.WORKING, Works.WORKING)


## The hand's half: the cradle a body stands in, the bar across the shoulders,
## the handles, and the straps through the drilled yoke.
static func made(k: MeshKit, broken: bool) -> void:
	k.style = Ink.HAND
	k.style2 = Ink.HAND
	var list := 0.16 if broken else 0.0
	for side: int in [-1, 1]:
		var z := side * 0.36
		var top := Vector3(-0.04 - list, TOP_Y - (0.2 if broken else 0.0), z + side * list * 0.5)
		# Stood a little in FRONT of the plate, in a wood pale enough to be seen
		# against it: hidden behind the yoke the hand's half of a mended thing is
		# not in the silhouette at all, and then it is not mended (docs/LOOK.md).
		k.strut(Vector3(0.02, HIP_Y + 0.04, z), top, 0.068, 5, P.EARTH[4])
		# Strap through the yoke's drilled hole, over the plate, off true.
		k.strut(Vector3(-0.04, HIP_Y + 0.1, z), Vector3(0.06, HIP_Y - 0.04, z - side * 0.05), 0.028, 4, P.SAND[3])
		k.strut(Vector3(-0.02, HIP_Y - 0.06, z * 0.6), Vector3(0.08, HIP_Y + 0.06, z * 0.9), 0.024, 4, P.SAND[2])
		if broken:
			continue
		# A handle reaching forward, where the hands go.
		k.strut(Vector3(-0.02, TOP_Y - 0.3, z), Vector3(0.5, TOP_Y - 0.36, z * 0.82), 0.054, 5, P.EARTH[4])
		k.strut(Vector3(0.42, TOP_Y - 0.34, z * 0.84), Vector3(0.5, TOP_Y - 0.42, z * 0.82), 0.034, 4, P.SAND[3])
	# The bar across the shoulders, crooked as a bent bough is.
	var bar_y := TOP_Y - (0.2 if broken else 0.0)
	k.strut(Vector3(-0.04 - list, bar_y, -0.42), Vector3(-0.02 - list, bar_y + 0.03, 0.42), 0.062, 5, P.LINEN[3])
	k.strut(Vector3(-0.05 - list, bar_y + 0.05, -0.08), Vector3(-0.01 - list, bar_y - 0.02, 0.1), 0.032, 4, P.SAND[3])
	if broken:
		# A strap sprung loose and hanging down the buckled side.
		k.strut(Vector3(-0.2, HIP_Y, -0.3), Vector3(-0.44, 0.34, -0.5), 0.026, 4, P.SAND[2])
