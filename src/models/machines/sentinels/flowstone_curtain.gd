extends RefCounted
## THE WARDEN'S CURTAIN (FightSim.curtains): the lime slurry the Limestone Caves'
## drip-warden sprays across a gap, set as flowstone sets over centuries, in the
## time of its tell. Fluted drapes standing floor to lip across the way, taller
## than the way is wide, each hung with drips at its hem and standing in a rim of
## the lime that ran off it.
##
## DRAWN AS THE CAVE'S OWN WALL: its vertices carry the cave strata's mark
## (GroundColors.STRATA + STRATA_CAVE), so world.gdshader lays the wall's drapes,
## its wet streaks and the lamp's sheen on it, and so it reads as the flowstone the
## halls are hung with and not as a painted slab. And as land it is never opened
## by the sight cut (mark_land): it is the thing the player must see in the way.

## How tall it stands: well over a person, under most of a hall's roof (4.5).
const H := 3.1
## The wall's mark, on every vertex.
const MARK := GroundColors.STRATA + GroundColors.STRATA_CAVE


static func _lime() -> Array:
	var a := float(MARK) / 255.0
	var out := []
	for c: Color in [Palette.LINEN[3], Palette.LINEN[4], Palette.LINEN[5], Palette.SAND[5], Palette.LINEN[4], Palette.LINEN[5]]:
		out.append(Color(c.r, c.g, c.b, a))
	return out


## The curtain across `from`..`to` (world space, ground height), local to their
## middle; `seed_value` varies the drapes, one curtain from the next.
static func mesh(from: Vector3, to: Vector3, seed_value: int) -> ArrayMesh:
	var mid := (from + to) * 0.5
	var a := from - mid
	var b := to - mid
	a.y = 0.0
	b.y = 0.0
	var lime := _lime()
	var k := FoundKit.matter_kit(Ink.NONE)
	var across := b - a
	var out := across.normalized().cross(Vector3.UP)
	# Drapes a hand apart, each set a little in or out of the line, so the face
	# is fluted and not a fence of posts.
	var folds := maxi(5, ceili(across.length() / 0.16) + 2)
	for i in folds:
		var t := float(i) / float(folds - 1)
		var p := a.lerp(b, t) + out * (Rng.hash01(seed_value, i, 70) - 0.5) * 0.14
		var r := 0.1 + Rng.hash01(seed_value, i, 71) * 0.06
		var top := H * (0.8 + Rng.hash01(seed_value, i, 72) * 0.2)
		var prof: Array[Vector2] = [Vector2(r * 1.8, 0.0), Vector2(r * 1.25, top * 0.12), Vector2(r * 1.0, top * 0.45),
			Vector2(r * 0.85, top * 0.8), Vector2(r * 0.55, top * 0.96), Vector2(0.0, top)]
		FoundKit.lathe(k, p, Vector3.UP, prof, 7, lime, Rng.hash01(seed_value, i, 73) * TAU)
		# Its hem: drips hung off the swell a hand up, and nubs grown under them.
		for j in 2:
			var ang := Rng.hash01(seed_value, i * 7 + j, 76) * TAU
			var at := p + Vector3(cos(ang), 0.0, sin(ang)) * r * 1.3 + Vector3(0, top * 0.12, 0)
			var len := 0.12 + Rng.hash01(seed_value, i * 7 + j, 77) * 0.18
			FoundKit.lathe(k, at, Vector3.DOWN, [Vector2(0.035, 0.0), Vector2(0.018, len * 0.6), Vector2(0.0, len)], 5, lime)
			k.rock(at.x, 0.0, at.z, 0.05 + Rng.hash01(seed_value, i * 7 + j, 78) * 0.04, 0.08, seed_value * 13 + i * 7 + j, lime[4], 5)
	# The lip where the drapes meet the way's top, and the drips run off it.
	var lip := H * 0.84
	FoundKit.tbar(k, a + Vector3(0, lip, 0), b + Vector3(0, lip, 0), 0.13, 0.13, 7, lime)
	for j in folds * 2:
		var t := (float(j) + 0.5) / float(folds * 2)
		var at := a.lerp(b, t) + Vector3(0, lip - 0.1, 0) + out * (Rng.hash01(seed_value, j, 79) - 0.5) * 0.2
		var len := 0.18 + Rng.hash01(seed_value, j, 74) * 0.45
		FoundKit.lathe(k, at, Vector3.DOWN, [Vector2(0.05, 0.0), Vector2(0.025, len * 0.6), Vector2(0.0, len)], 5, lime)
	# The rim it stands in: the slurry that ran off it and set.
	for j in folds:
		var t := float(j) / float(folds - 1)
		var at := a.lerp(b, t)
		for side: float in [-1.0, 1.0]:
			var q := at + out * side * (0.22 + Rng.hash01(seed_value, j, 80) * 0.12)
			k.rock(q.x, 0.0, q.z, 0.2 + Rng.hash01(seed_value, j, 75) * 0.1, 0.07, seed_value * 31 + j * 2 + int(side > 0.0), lime[3 + j % 2], 7)
	return k.build()
