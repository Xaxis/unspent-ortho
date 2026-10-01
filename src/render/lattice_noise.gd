class_name LatticeNoise
## Value noise on an integer lattice, the same numbers on the CPU as
## matter.gdshaderinc's lattice_hash / lattice_noise / lattice_fbm draw on the
## GPU: a float `sin` hash (ink_hash) is a different number on each. For a field
## the ground draws that something placed on the CPU has to agree with: the
## coast's heather drifts (ShoreSward), the moss's wet hollows (BogFen). Pure and
## safe on a worker thread; tests/render/test_shore_sward.gd holds the two sides
## to the same constants.

const _MASK := 0xFFFFFFFF
const _K1 := 2654435761
const _K2 := 2246822519
const _K3 := 2246822507
const _WEIGHT: Array[float] = [0.5, 0.28, 0.15]
const _SCALE: Array[float] = [2.07, 2.13]
const _OFFSET: Array[float] = [19.0, 41.0]


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
