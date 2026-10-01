class_name ShoreSward
## How thick the heather grows on the coast's heath (GroundColors.SHORE_HEATH), at
## a world point: 0 the cropped grass between the drifts, 1 a drift's heart. The
## same numbers as matter.gdshaderinc's `shore_thick`, which draws the drifts on
## the ground, so the decor's heather (Decor) stands in those drifts and nowhere
## else. Both run on an integer lattice hash for that reason: a float `sin` hash
## (ink_hash) is a different number on the GPU from the CPU.
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

const _MASK := 0xFFFFFFFF
const _K1 := 2654435761
const _K2 := 2246822519
const _K3 := 2246822507
const _WEIGHT: Array[float] = [0.5, 0.28, 0.15]
const _SCALE: Array[float] = [2.07, 2.13]
const _OFFSET: Array[float] = [19.0, 41.0]


static func thick(x: float, z: float, y: float) -> float:
	var p := Vector2(x, z)
	var w := Vector2(noise(p * BEND + Vector2(3.0, 3.0)), noise(p * BEND + Vector2(17.0, 17.0))) - Vector2(0.5, 0.5)
	var a := Vector2(p.dot(WIND), p.dot(Vector2(-WIND.y, WIND.x)))
	var d := fbm(Vector2(a.x * ALONG, a.y * ACROSS) + w * BEND_REACH)
	d += clampf((y - LOW) / EXPOSED, 0.0, 1.0) * RISE - SINK
	return smoothstep(THIN, THICK, d)


## Three octaves of value noise, each turned off the last, weighted as
## matter_fbm's first three are (0..0.93).
static func fbm(p: Vector2) -> float:
	var v := 0.0
	for o in 3:
		v += noise(p) * _WEIGHT[o]
		if o < 2:
			# mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p: columns, as GLSL reads it.
			p = Vector2(0.8 * p.x - 0.6 * p.y, 0.6 * p.x + 0.8 * p.y) * _SCALE[o] + Vector2(_OFFSET[o], _OFFSET[o])
	return v


static func noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var ix := int(i.x)
	var iy := int(i.y)
	var a := lattice(ix, iy)
	var b := lattice(ix + 1, iy)
	var c := lattice(ix, iy + 1)
	var d := lattice(ix + 1, iy + 1)
	return lerpf(lerpf(a, b, u.x), lerpf(c, d, u.x), u.y)


## 0..1 from a lattice point, in 32-bit unsigned arithmetic as the shader's is.
## Each product is taken in two halves so it never leaves 64 signed bits.
static func lattice(ix: int, iy: int) -> float:
	var x := ix & _MASK
	var y := iy & _MASK
	var h := ((x * (_K1 & 0xFFFF) + (((x * (_K1 >> 16)) & 0xFFFF) << 16)) & _MASK) \
		^ ((y * (_K2 & 0xFFFF) + (((y * (_K2 >> 16)) & 0xFFFF) << 16)) & _MASK)
	h ^= h >> 15
	h = (h * (_K3 & 0xFFFF) + (((h * (_K3 >> 16)) & 0xFFFF) << 16)) & _MASK
	h ^= h >> 13
	return float(h & 0xFFFFFF) / 16777215.0
