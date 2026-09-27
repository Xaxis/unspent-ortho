extends RefCounted
## THE WARDEN'S CURTAIN (FightSim.curtains): the lime slurry the Limestone Caves'
## drip-warden sprays across a gap, set as flowstone sets over centuries, in the
## time of its tell. A row of pale folds standing floor to lip across the way,
## the lip joining them with its drips run back down, a skirt of lime lumped at
## the foot where the slurry ran out. Natural matter, drawn by the hand on the
## world material (FoundKit.matter_kit), as the lime on the warden's own legs is:
## the same stuff, so a player who has seen its knees reads a curtain as its.

## How tall it stands: over a person's head, under most of a hall's roof.
const H := 2.4


## The curtain across `from`..`to` (world space, ground height), local to their
## middle; `seed_value` varies the folds, one curtain from the next.
static func mesh(from: Vector3, to: Vector3, seed_value: int) -> ArrayMesh:
	var mid := (from + to) * 0.5
	var a := from - mid
	var b := to - mid
	a.y = 0.0
	b.y = 0.0
	var lime := [Palette.LINEN[3], Palette.LINEN[4], Palette.LINEN[5], Palette.SAND[5], Palette.LINEN[5], Palette.LINEN[5]]
	var k := FoundKit.matter_kit(Ink.NONE)
	var across := b - a
	var folds := maxi(3, ceili(across.length() / 0.28) + 1)
	# The folds: each a lumped column, fattest at the foot, thinning to the lip.
	for i in folds:
		var t := float(i) / float(folds - 1)
		var p := a.lerp(b, t)
		var r := 0.15 + Rng.hash01(seed_value, i, 71) * 0.09
		var top := H * (0.86 + Rng.hash01(seed_value, i, 72) * 0.16)
		var prof: Array[Vector2] = [Vector2(r * 1.35, 0.0), Vector2(r * 1.05, top * 0.28), Vector2(r * 0.9, top * 0.7),
			Vector2(r * 0.62, top * 0.94), Vector2(0.0, top)]
		FoundKit.lathe(k, p, Vector3.UP, prof, 6, lime, Rng.hash01(seed_value, i, 73) * TAU)
	# The lip across the top, and its drips.
	var lip := H * 0.9
	FoundKit.tbar(k, a + Vector3(0, lip, 0), b + Vector3(0, lip, 0), 0.11, 0.11, 6, lime)
	for j in folds * 2:
		var t := (float(j) + 0.5) / float(folds * 2)
		var at := a.lerp(b, t) + Vector3(0, lip - 0.08, 0)
		var len := 0.14 + Rng.hash01(seed_value, j, 74) * 0.3
		FoundKit.lathe(k, at, Vector3.DOWN, [Vector2(0.045, 0.0), Vector2(0.022, len * 0.6), Vector2(0.0, len)], 5, lime)
	# The skirt it ran out into.
	for j in folds:
		var t := float(j) / float(folds - 1)
		var at := a.lerp(b, t)
		k.rock(at.x, 0.0, at.z, 0.34 + Rng.hash01(seed_value, j, 75) * 0.12, 0.1, seed_value * 31 + j, lime[3 + j % 2], 7)
	return k.build()
