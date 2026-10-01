class_name BogFen
## How wet the moss's fen lies at a world point (GroundColors.BOG_FLOOR), the same
## numbers as matter.gdshaderinc's `bog_wet`, which draws it: under MARGIN the
## sphagnum's hummocks and lawns, from MARGIN to WATER the sodden margin where the
## sedge and the bog cotton stand, past WATER standing water in a hollow. The
## decor (Decor._fen) reads it so the sedge rings the pools and the cotton drifts
## by them, and nothing grows in the water. On the integer lattice (LatticeNoise)
## so the two agree; tests/render/test_bog_fen.gd holds the constants equal.
##
## A fen is wet in its HOLLOWS: the field is slow (a hollow fifteen strides
## across), with two finer octaves that break a pool's shore into bays and seed
## the small pools beside it, so the water comes in three sizes and its shores
## are ragged where they meet. And the low ground is wetter: water runs down into
## it (`y`, the world height).

## The field's frequency per world unit, and the slower one that bends it.
const SCALE := 0.065
const BEND := 0.025
const BEND_REACH := 3.0
## Where the sodden margin starts and where it is standing water, on the field
## (mean 0.465).
const MARGIN := 0.56
const WATER := 0.605
## The low ground's share: from y = LOW down through DEEP world units the field
## gains SINK, and above LOW it loses as much.
const LOW := 1.5
const DEEP := 3.0
const SINK := 0.04


static func wet(x: float, z: float, y: float) -> float:
	var p := Vector2(x, z)
	var w := Vector2(LatticeNoise.noise(p * BEND + Vector2(5.0, 5.0)), LatticeNoise.noise(p * BEND + Vector2(23.0, 23.0))) - Vector2(0.5, 0.5)
	var d := LatticeNoise.fbm(p * SCALE + w * BEND_REACH)
	return d + clampf((LOW - y) / DEEP, -1.0, 1.0) * SINK
