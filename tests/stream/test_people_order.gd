extends TestCase
## The people's things are rows that no other row decides (streamed worldgen
## S4j2): village edges, ways in, road signs, remains, survey sections and
## vignette cells. Laid last to first (`GenWorks.reversing`), the world holds the
## same things in the same places -- only prop ids, which are the order laid,
## differ. A way in keeps off the ways in that outrank it by hash, not the ones
## laid before it, and each region's stolen light is its own lowest-hashed shack.

const SIZE := 512
const SEEDS: Array[int] = [1, 7, 42, 90210]


func test_the_people_s_things_laid_backwards_are_the_same_things() -> void:
	for s in SEEDS:
		var fwd := WorldGen.generate(s, SIZE)
		GenWorks.reversing = true
		var back := WorldGen.generate(s, SIZE)
		GenWorks.reversing = false
		var a := _things(fwd)
		var b := _things(back)
		gt(float(a.size()), 1000.0, "seed %d: things to lay" % s)
		var only_fwd := _minus(a, b)
		var only_back := _minus(b, a)
		eq(only_fwd.size() + only_back.size(), 0, "seed %d: the same things either way (first differing: %s / %s)"
			% [s, only_fwd.slice(0, 3), only_back.slice(0, 3)])


## Every prop as kind, position, turn and scale, and every landmark as kind and
## position, sorted: what the world holds, whatever order laid it.
static func _things(w: WorldData) -> Array:
	var out: Array = []
	for p: WorldProp in w.each_prop():
		out.append("p %d %.3f %.3f %.3f %.3f" % [p.kind, p.pos.x, p.pos.y, p.rot, p.scale])
	for m: Dictionary in w.landmarks:
		out.append("m %s %.3f %.3f" % [m.kind, (m.pos as Vector2).x, (m.pos as Vector2).y])
	out.sort()
	return out


static func _minus(a: Array, b: Array) -> Array:
	var count := {}
	for x: String in b:
		count[x] = int(count.get(x, 0)) + 1
	var out: Array = []
	for x: String in a:
		if int(count.get(x, 0)) > 0:
			count[x] = int(count[x]) - 1
		else:
			out.append(x)
	return out
