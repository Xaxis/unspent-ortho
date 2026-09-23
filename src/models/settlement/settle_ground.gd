extends RefCounted
## Food and water: the plot people turn over by hand, and the sheet of machine
## plate that catches the rain for it (docs/VISION.md).
##
## The plot is the one piece of a holding that shows the season and whether
## anybody is tending it (docs/LOOK.md), so its ridges curve, its crop sways,
## and a plot left alone is stalks.

const Parts := preload("res://src/models/settlement/settle_parts.gd")
const P := preload("res://src/render/palette.gd")


## Ridges turned by hand: they curve, they are not the same length, and the row
## of stones lifted out of them is piled along one edge. Nothing in here is
## straight, because a ruled field belongs to the machines (docs/LOOK.md).
static func plot(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var rows := 4
	for r in rows:
		var x := lerpf(-0.72, 0.72, (float(r) + 0.5) / float(rows)) + Parts.lean(v, 10 + r, 0.07)
		var length := 0.8 + Parts.wob(v, 20 + r) * 0.35
		var bow := Parts.lean(v, 30 + r, 0.2)
		# The ridge is one unbroken pull of a mattock, bowed along its own run: a
		# line of separate lumps is a grid of blobs, which is the one thing the
		# ground in this game may never be (law 1).
		var soil := P.EARTH[2] if r % 2 else P.EARTH[1]
		# Sunk, so only the crown of the ridge stands above the ground: a round
		# spar laid on the turf reads as felled timber, and a plot is not a
		# woodpile. What shows is a low, wide, hand-hoed mound.
		var a0 := Vector3(x, -0.1, -length)
		var mid := Vector3(x + bow, -0.07, 0.0)
		var a1 := Vector3(x - bow * 0.4, -0.1, length)
		k.strut(a0, mid, 0.19 + Parts.wob(v, 40 + r) * 0.04, 6, soil)
		k.strut(mid, a1, 0.18 + Parts.wob(v, 44 + r) * 0.04, 6, soil)
		var tufts := 5
		for i in tufts:
			var t := (float(i) + 0.5) / float(tufts)
			var on: Vector3 = a0.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(a1, (t - 0.5) * 2.0)
			on.y = 0.0
			if ruined:
				# Burnt: black stalks and nothing on them (docs/LOOK.md).
				k.sway = 0.35
				k.sway_phase = Parts.wob(v, 60 + r * 5 + i) * TAU
				k.strut(Vector3(on.x, 0.08, on.z), Vector3(on.x + Parts.lean(v, 70 + r * 5 + i, 0.07), 0.26, on.z), 0.02, 3, P.INK[2])
				k.sway = 0.0
				continue
			# The crop: a few leaves a hand high, moving with the wind. They are
			# the whole of what says somebody is tending this.
			k.sway = 0.5
			k.sway_phase = Parts.wob(v, 60 + r * 5 + i) * TAU
			for leaf in 3:
				var a := TAU * float(leaf) / 3.0 + Parts.wob(v, 80 + r * 5 + i) * TAU
				k.strut(Vector3(on.x, 0.1, on.z), Vector3(on.x + cos(a) * 0.11, 0.26 + Parts.wob(v, 90 + leaf) * 0.1, on.z + sin(a) * 0.11),
					0.03, 4, P.MOSS[3] if (r + leaf) % 2 else P.MOSS[4])
			k.sway = 0.0
	# The stones lifted out of the ground, piled along the edge nobody digs.
	for i in 5:
		var z := lerpf(-0.9, 0.9, (float(i) + 0.5) / 5.0)
		Parts.stone(k, Vector3(-0.95 + Parts.lean(v, 100 + i, 0.06), 0.0, z), 0.12, v, 110 + i)
	if ruined:
		return
	# Two sticks and a cord: what a row of beans is grown up.
	for side: int in [-1, 1]:
		var z := side * (0.55 + Parts.wob(v, 120 + side) * 0.2)
		k.strut(Vector3(0.62, 0.0, z), Vector3(0.58 + Parts.lean(v, 130 + side, 0.08), 0.64, z + Parts.lean(v, 140 + side, 0.05)),
			0.022, 4, Parts.pick(Parts.TIMBER, v, 150 + side))
	Parts.lash(k, Vector3(0.58, 0.58, -0.55), Vector3(0.58, 0.55, 0.55), v, 160, 0.018)


## A canted sheet of plate on two legs, feeding a drum cut off a machine's tank.
## The join is the drawing: the cord crosses the rivet row, and the hose is
## pushed into a hole somebody drilled.
static func catchment_made(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.hand(k)
	var high := 0.86 if not ruined else 0.32
	for side: int in [-1, 1]:
		var z := side * 0.34
		Parts.post(k, Vector3(-0.3, 0.0, z), Vector3(-0.28 + Parts.lean(v, 10 + side, 0.05), high, z), 0.05,
			Parts.pick(Parts.TIMBER, v, 20 + side))
		Parts.post(k, Vector3(0.24, 0.0, z), Vector3(0.24, high * 0.55, z), 0.045, Parts.pick(Parts.TIMBER, v, 30 + side))
		Parts.stone(k, Vector3(-0.3, 0.0, z), 0.1, v, 40 + side)
	# The lashings that hold the sheet on, crossing where the rivets run.
	for side: int in [-1, 1]:
		Parts.lash(k, Vector3(-0.28, high - 0.04, side * 0.34), Vector3(-0.16, high - 0.12, side * 0.28), v, 50 + side)
		Parts.lash(k, Vector3(0.24, high * 0.55 - 0.03, side * 0.34), Vector3(0.14, high * 0.5, side * 0.3), v, 52 + side)
	if ruined:
		return
	# A hose of gut and rag from the low corner into the drum.
	k.strut(Vector3(0.2, high * 0.5, 0.0), Vector3(0.42, 0.42, 0.06), 0.03, 4, Parts.CORD_DARK)


static func catchment_found(k: MeshKit, v: int, ruined: bool) -> void:
	Parts.ruled(k)
	var high := 0.86 if not ruined else 0.32
	# The sheet, canted so the rain runs off its low corner into the drum. It
	# stands on the low pair of legs and leans back over the high pair.
	var rise := high - high * 0.55
	Parts.panel(k, Vector3(0.24, high * 0.55, 0.0), atan2(rise, 0.52))
	Parts.plate(k, 0.36, sqrt(rise * rise + 0.52 * 0.52), v, 60)
	k.pop()
	if ruined:
		return
	# The drum: one end of a tank, cut off and stood up, its bands still on it.
	k.prism(0.46, 0.0, 0.08, 0.2, 0.46, 0.19, 9, P.PLATE[3], P.PLATE[4])
	for i in 2:
		var y := 0.14 + 0.18 * float(i)
		k.strut(Vector3(0.46, y, 0.08), Vector3(0.46, y + 0.03, 0.08), 0.206, 9, P.PLATE[2])
