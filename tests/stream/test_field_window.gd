extends TestCase
## The surface's fields over a section (streamed worldgen S4f): `smooth` and a
## noise `field` asked over one rectangle of the world give the whole-world
## values tile for tile -- at its corners and edges, where the whole-world
## images clamp, as well as inside.

const SIZE := 480
const RECTS: Array[Rect2i] = [Rect2i(0, 0, 97, 97), Rect2i(150, 90, 130, 111), Rect2i(383, 383, 97, 97),
	Rect2i(420, 0, 60, 200), Rect2i(-20, 300, 90, 90), Rect2i(460, 470, 50, 40)]


func test_a_rectangle_of_a_smoothed_field_is_the_world_s() -> void:
	var v := PackedFloat32Array()
	v.resize(SIZE * SIZE)
	for i in v.size():
		v[i] = Rng.hash01(7, i % SIZE, i / SIZE, 0x5F) * 12.0
	for levels: int in [2, 3, 4]:
		var whole := GenFields.smooth(v, SIZE, levels)
		for r in RECTS:
			eq(_differs(whole, GenFields.smooth_rect(v, SIZE, levels, r.position.x, r.position.y, r.size.x, r.size.y), r), 0,
				"smooth %d over %s" % [levels, r])


func test_a_rectangle_of_a_noise_field_is_the_world_s() -> void:
	var noise := GenFields.noise(42, 501, 1.0 / 48.0, 2)
	var warped := GenFields.noise(42, 503, 1.0 / 22.0, 2)
	warped.domain_warp_enabled = true
	warped.domain_warp_amplitude = 18.0
	warped.domain_warp_frequency = 1.0 / 40.0
	for n: FastNoiseLite in [noise, warped]:
		for step: int in [1, 2, 4, 8]:
			var whole: PackedFloat32Array = GenFields.batch(SIZE, [[GenFields.FIELD, n, step]])[0]
			for r in RECTS:
				eq(_differs(whole, GenFields.field_rect(n, SIZE, step, r.position.x, r.position.y, r.size.x, r.size.y), r), 0,
					"field step %d over %s" % [step, r])


## Tiles of the rectangle inside the world whose value differs from the world's.
static func _differs(whole: PackedFloat32Array, part: PackedFloat32Array, r: Rect2i) -> int:
	var bad := 0
	for y in r.size.y:
		for x in r.size.x:
			var wx := r.position.x + x
			var wy := r.position.y + y
			if wx < 0 or wy < 0 or wx >= SIZE or wy >= SIZE:
				continue
			if part[y * r.size.x + x] != whole[wy * SIZE + wx]:
				bad += 1
	return bad
