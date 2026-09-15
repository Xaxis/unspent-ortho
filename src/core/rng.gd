class_name Rng
## Seeded randomness. Nothing in the game calls randf() or randi(): a seed is a
## world, and a world must come out the same on every machine and in every test.
##
## Positional randomness uses hash()/hash01() (stateless, any number of ints).
## Sequences use make(), a RandomNumberGenerator seeded from a hash.

const MASK := 0xFFFFFFFF


## 32-bit integer hash of up to six integers. Stable across platforms.
static func hash_ints(a: int, b: int = 0, c: int = 0, d: int = 0, e: int = 0, f: int = 0) -> int:
	var h := 0x811c9dc5
	for n: int in [a, b, c, d, e, f]:
		h = ((h ^ (n & MASK)) * 0x01000193) & MASK
		h ^= h >> 15
		h = (h * 0x2c1b3c6d) & MASK
		h ^= h >> 12
	h = ((h ^ (h >> 16)) * 0x297a2d39) & MASK
	return (h ^ (h >> 15)) & MASK


## Hash to a float in [0, 1).
static func hash01(a: int, b: int = 0, c: int = 0, d: int = 0, e: int = 0, f: int = 0) -> float:
	return float(hash_ints(a, b, c, d, e, f)) / 4294967296.0


## A RandomNumberGenerator for a (seed, salt) pair.
static func make(seed_value: int, salt: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash_ints(seed_value, salt, 0x5eed)
	return r


static func shuffle(r: RandomNumberGenerator, xs: Array) -> Array:
	for i in range(xs.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t: Variant = xs[i]
		xs[i] = xs[j]
		xs[j] = t
	return xs
