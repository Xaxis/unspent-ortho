class_name ShoreSward
## How thick the heather grows on the coast's heath (GroundColors.SHORE_HEATH), at
## a world point: 0 the cropped grass between the drifts, 1 a drift's heart. The
## same numbers as matter.gdshaderinc's `shore_thick`, which draws the drifts on
## the ground, so the decor's heather (Decor) stands in those drifts and nowhere
## else. Both run on the integer lattice (LatticeNoise) for that reason.
##
## Pure and safe on a worker thread. Keep every constant here and in the shader
## the same; tests/render/test_shore_sward.gd reads the shader to hold them.

## The bearing the sea wind combs the drifts out along (world x, z).
const WIND := Vector2(0.5, -0.866)
## The drift field's frequency along the wind and across it, per world unit.
const ALONG := 0.04
const ACROSS := 0.1
## The slower field that bends the drifts, its frequency and its reach.
const BEND := 0.03
const BEND_REACH := 2.4
## Where the heather starts and where it is a drift's heart, on the field (whose
## mean is 0.465).
const THIN := 0.44
const THICK := 0.58
## The high ground holds more of it: from y = LOW up through EXPOSED world units
## the field gains RISE, less SINK at the bottom.
const LOW := 1.5
const EXPOSED := 8.0
const RISE := 0.1
const SINK := 0.04


static func thick(x: float, z: float, y: float) -> float:
	var p := Vector2(x, z)
	var w := Vector2(LatticeNoise.noise(p * BEND + Vector2(3.0, 3.0)), LatticeNoise.noise(p * BEND + Vector2(17.0, 17.0))) - Vector2(0.5, 0.5)
	var a := Vector2(p.dot(WIND), p.dot(Vector2(-WIND.y, WIND.x)))
	var d := LatticeNoise.fbm(Vector2(a.x * ALONG, a.y * ACROSS) + w * BEND_REACH)
	d += clampf((y - LOW) / EXPOSED, 0.0, 1.0) * RISE - SINK
	return smoothstep(THIN, THICK, d)
