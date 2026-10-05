extends TestCase
## THE DROWNED FLOOR'S PUDDLES HAVE ONE WATERLINE EACH (world.gdshader
## `tide_pool`). Read straight off the world's axes, with a shore wobble as large
## as the edge band, every shore that lay flat broke into square islands a few
## hundredths of a tile across: from above, a stepped dither round each puddle
## (seed 1's drowned city at noon). The field is mirrored here line for line and
## measured on a grid: specks of water or of dry floor under a twentieth of a tile.

const SHADER := "res://src/render/world.gdshader"
## Sample step and span, in tiles, and where the patch lies (clear of the
## lattice's symmetry about the origin).
const STEP := 0.08
const SPAN := 48.0
const AT := Vector2(300.0, 700.0)
const SPECK := 0.05


static func _hash(p: Vector2) -> float:
	var q := Vector2(fposmod(p.x * 0.1031, 1.0), fposmod(p.y * 0.1030, 1.0))
	var d := q.dot(Vector2(q.y, q.x) + Vector2(33.33, 33.33))
	q += Vector2(d, d)
	return fposmod((q.x + q.y) * q.x, 1.0)


## ink_vnoise.
static func _vnoise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	return lerpf(lerpf(_hash(i), _hash(i + Vector2(1, 0)), u.x), lerpf(_hash(i + Vector2(0, 1)), _hash(i + Vector2(1, 1)), u.x), u.y)


## matter_fbm.
static func _fbm(p: Vector2) -> float:
	var rot := Transform2D(Vector2(0.8, 0.6), Vector2(-0.6, 0.8), Vector2.ZERO)
	var v := _vnoise(p) * 0.5
	p = rot * p * 2.07 + Vector2(19.0, 19.0)
	v += _vnoise(p) * 0.28
	p = rot * p * 2.13 + Vector2(41.0, 41.0)
	v += _vnoise(p) * 0.15
	p = rot * p * 2.03 + Vector2(7.0, 7.0)
	v += _vnoise(p) * 0.07
	return v


## rag.
static func _rag(p: Vector2) -> float:
	return (_vnoise(p * 7.1 + Vector2(3.0, 3.0)) - 0.5) * 0.06


## tide_pool on ground under the old high water.
static func pool(p: Vector2) -> float:
	var q := Transform2D(Vector2(0.857, 0.515), Vector2(-0.515, 0.857), Vector2.ZERO) * p
	var bend := Vector2(_vnoise(q * 0.06 + Vector2(5.0, 5.0)), _vnoise(q * 0.06 + Vector2(29.0, 29.0))) - Vector2(0.5, 0.5)
	var f := _fbm(q * 0.09 + bend * 1.6 + Vector2(17.0, 17.0)) + _rag(q) * 0.15
	return smoothstep(0.56, 0.58, f)


func test_the_shader_draws_this_field() -> void:
	var src := FileAccess.get_file_as_string(SHADER)
	for want: String in [
			"const mat2 TIDE_TURN = mat2(vec2(0.857, 0.515), vec2(-0.515, 0.857));",
			"vec2 bend = vec2(ink_vnoise(q * 0.06 + 5.0), ink_vnoise(q * 0.06 + 29.0)) - 0.5;",
			"return matter_fbm(q * 0.09 + bend * 1.6 + 17.0) + rag(q) * 0.15;",
			"return smoothstep(0.56, 0.58, f) * max(tide_under(y), 0.6);"]:
		check(src.contains(want), "world.gdshader's tide_pool says `%s`, as the mirror here does" % want)


func test_each_puddle_has_one_waterline() -> void:
	var n := int(SPAN / STEP)
	var wet := PackedByteArray()
	wet.resize(n * n)
	var share := 0
	for y in n:
		for x in n:
			var w := 1 if pool(AT + Vector2(x, y) * STEP) > 0.5 else 0
			wet[y * n + x] = w
			share += w
	var seen := PackedByteArray()
	seen.resize(n * n)
	var parts := 0
	var specks := 0
	for s in n * n:
		if seen[s] == 1:
			continue
		var kind := wet[s]
		var todo: Array[int] = [s]
		seen[s] = 1
		var area := 0
		while not todo.is_empty():
			var c: int = todo.pop_back()
			area += 1
			var cx := c % n
			for o: int in [c - 1 if cx > 0 else -1, c + 1 if cx < n - 1 else -1, c - n, c + n]:
				if o >= 0 and o < n * n and seen[o] == 0 and wet[o] == kind:
					seen[o] = 1
					todo.append(o)
		parts += 1
		if area * STEP * STEP < SPECK:
			specks += 1
	var cover := float(share) / (n * n)
	print("  info tide pools over %d x %d tiles: %.2f under water, %d puddles and islands, %d specks" % [int(SPAN), int(SPAN), cover, parts, specks])
	# The drowned floor keeps its puddles: about two fifths of it lies under them.
	gt(cover, 0.3, "the floor holds its puddles (%.2f)" % cover)
	lt(cover, 0.5, "and is not one sheet of water (%.2f)" % cover)
	# Measured: 890 specks with the old field, 13 with this one.
	lt(float(specks), 40.0, "a puddle's shore is one line, not a field of islands (%d specks)" % specks)
