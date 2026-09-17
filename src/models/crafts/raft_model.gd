extends RefCounted
## A raft: driftwood spars lashed over two float drums cut out of a machine's
## tanks (docs/ART.md §12). The drums, the transom plate and the tell-tale that
## still burns on it are FOUND — ruled, riveted, unhatched. The deck, the pole and
## every cord are MADE — hatched, crooked, earth and sand. The drawing is the
## join: each lashing crosses a drum's rivet row and sits a little off true.
##
## Faces +X (its bow). Two tiles long, a tile and a quarter across: low in the
## water, and read at 640x360 by the pole standing up off the stern.

const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")

const LENGTH := 1.05
## The deck is NARROWER than the drums under it on purpose: the machine half has
## to be in the silhouette, not hidden under the hand's half (docs/ART.md §12).
const HALF_W := 0.42
const DRUM_R := 0.2
const DRUM_Z := 0.52
const DECK_Y := 0.34


## The machine half: two float drums, their rivet bands, a cut transom and one
## amber tell-tale nobody has been able to switch off.
static func found(k: MeshKit, broken: bool) -> void:
	k.style = Ink.NONE
	k.style2 = Ink.NONE
	for side: int in [-1, 1]:
		# Wrecked: the port drum is gone and the deck lies in the water.
		if side < 0 and broken:
			continue
		var z := side * DRUM_Z
		k.strut(Vector3(-LENGTH + 0.05, DRUM_R, z), Vector3(LENGTH - 0.02, DRUM_R, z), DRUM_R, 10, P.PLATE[3])
		# Rivet bands: the rows the drum was cut through, still in line.
		for i in 3:
			var x := -0.55 + 0.55 * i
			k.strut(Vector3(x, DRUM_R, z), Vector3(x + 0.035, DRUM_R, z), DRUM_R + 0.022, 10, P.PLATE[2])
		# The cut end, capped with the same plate, chamfered off the bow.
		k.strut(Vector3(LENGTH - 0.02, DRUM_R, z), Vector3(LENGTH + 0.1, DRUM_R + 0.04, z), DRUM_R * 0.7, 8, P.PLATE[4])
	# The transom: one plate across the stern, its top corner cut away, with a
	# folded lip along the top so the eye catches it from above.
	var x0 := -LENGTH + 0.02
	var top := DECK_Y + 0.3
	# The face the camera gets is the one turned east (+X): the plate's own step
	# goes there, and the dark step on the side nobody sees. Drawn the other way
	# round the stern reads as a hole in the raft.
	k.quad(Vector3(x0, 0.06, -DRUM_Z - 0.06), Vector3(x0, 0.06, DRUM_Z + 0.06),
		Vector3(x0, top, DRUM_Z - 0.16), Vector3(x0, top, -DRUM_Z - 0.06), P.PLATE[1])
	k.quad(Vector3(x0 - 0.03, top, -DRUM_Z - 0.06), Vector3(x0 - 0.03, top, DRUM_Z - 0.16),
		Vector3(x0 - 0.03, 0.06, DRUM_Z + 0.06), Vector3(x0 - 0.03, 0.06, -DRUM_Z - 0.06), P.PLATE[3])
	# The lip is folded back along the top: the one horizontal face on it, and
	# what the eye finds from above.
	k.quad(Vector3(x0 - 0.08, top, -DRUM_Z - 0.06), Vector3(x0 + 0.04, top, -DRUM_Z - 0.06),
		Vector3(x0 + 0.04, top, DRUM_Z - 0.16), Vector3(x0 - 0.08, top, DRUM_Z - 0.16), P.PLATE[4])
	if not broken:
		# A tell-tale off some drowned hull, wired into nothing, still amber.
		k.prism(x0 - 0.02, top, -0.04, 0.075, top + 0.1, 0.055, 6, Works.WORKING, Works.WORKING)


## The hand's half: the deck, the battens under it, the lashings that hold the
## whole thing together, and the pole it is driven with.
static func made(k: MeshKit, broken: bool) -> void:
	k.style = Ink.HAND
	k.style2 = Ink.HAND
	var spars := 7
	for i in spars:
		var t := float(i) / float(spars - 1)
		var z := lerpf(-HALF_W, HALF_W, t)
		# Crooked on purpose: every spar a different length, none quite level.
		var wobble := sin(float(i) * 2.399) * 0.055
		var lift := DECK_Y + sin(float(i) * 1.117) * 0.012
		var sprung := broken and i >= spars - 2
		var a := Vector3(-LENGTH + 0.08 + wobble * 0.5, lift, z)
		var b := Vector3(LENGTH - 0.06 + wobble, lift + (0.16 if sprung else 0.0), z + (0.2 if sprung else 0.0))
		k.strut(a, b, 0.072, 5, P.EARTH[2] if i % 2 == 0 else P.EARTH[3])
	for x: float in [-0.62, 0.0, 0.58]:
		k.strut(Vector3(x, DECK_Y - 0.08, -HALF_W + 0.04), Vector3(x + 0.03, DECK_Y - 0.08, HALF_W - 0.04), 0.055, 5, P.EARTH[1])
	# The join, and the reason to look at the thing: a cord laid right across the
	# deck and down round both drums, crossing the rivet rows it was never meant
	# to, a little off true at every station because a hand put it there.
	for i in 3:
		var x := -0.5 + 0.55 * i
		var off := sin(float(i) * 3.1) * 0.035
		var far := -DRUM_Z - 0.14 if not broken else -DRUM_Z + 0.1
		k.strut(Vector3(x + off, DECK_Y + 0.08, far), Vector3(x - off, DECK_Y + 0.06, DRUM_Z + 0.14), 0.033, 4,
			P.SAND[3] if i % 2 == 0 else P.SAND[2])
		for side: int in [-1, 1]:
			if side < 0 and broken:
				continue
			var z := side * DRUM_Z
			k.strut(Vector3(x - off * side, DECK_Y + 0.06, z + side * 0.12), Vector3(x + off * 0.5, 0.04, z + side * 0.2), 0.026, 4, P.SAND[2])
	if broken:
		# What is left of the pole, snapped off short across the deck.
		k.strut(Vector3(-0.5, DECK_Y + 0.1, 0.42), Vector3(0.15, DECK_Y + 0.14, -0.1), 0.045, 5, P.EARTH[3])
		return
	# The pole: leant on the transom, the one thing that stands up off a raft.
	k.strut(Vector3(-0.86, DECK_Y + 0.06, 0.26), Vector3(0.34, 1.3, -0.02), 0.08, 6, P.EARTH[4])
	k.strut(Vector3(-0.9, DECK_Y + 0.04, 0.28), Vector3(-1.02, DECK_Y - 0.08, 0.34), 0.066, 6, P.EARTH[3])
	# Cord whipped round the pole where it rests.
	k.strut(Vector3(-0.78, DECK_Y + 0.26, 0.2), Vector3(-0.7, DECK_Y + 0.2, 0.32), 0.036, 4, P.SAND[3])
