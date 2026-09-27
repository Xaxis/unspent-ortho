extends TestCase
## The surface is a section's to lay (streamed worldgen S4f). From a world's plan
## (`WorldGen.plan`), its sections laid one by one (`WorldGen.section`) -- in rows,
## backwards, shuffled, one at a time or all at once on the worker pool -- give
## the surface the whole world lays, byte for byte: ground, recipe, rise, forest
## and the steps from the sea.

const SIZE := 512
const SEEDS: Array[int] = [1, 42]
## Sections smaller than the stream's, so a 512 world has sixteen of them and
## most of its surface lies near a section's edge.
const CORE := 128


func test_sections_in_any_order_lay_the_whole_world_s_surface() -> void:
	for s in SEEDS:
		var c := WorldGen.plan(s, SIZE)
		check(not c.finished, "seed %d: the plan leaves the surface to lay" % s)
		GenSurface.run(c)
		var whole := _digest(c)
		var cores: Array[Rect2i] = []
		for sy in SIZE / CORE:
			for sx in SIZE / CORE:
				cores.append(Rect2i(sx * CORE, sy * CORE, CORE, CORE))
		var backwards := cores.duplicate()
		backwards.reverse()
		var shuffled := cores.duplicate()
		var rng := Rng.make(s, 0x5EC)
		for i in range(shuffled.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: Rect2i = shuffled[i]
			shuffled[i] = shuffled[j]
			shuffled[j] = tmp
		for order: Array in [cores, backwards, shuffled]:
			WorldGen.begin_sections(c)
			# Nothing of the whole-world surface is left for a section to lean on.
			c.w.ground.fill(255)
			for r: Rect2i in order:
				WorldGen.section(c, r)
			eq(_digest(c), whole, "seed %d: sections one at a time, from %s, lay the world's surface" % [s, order[0]])
		# All at once, each on a worker of its own.
		WorldGen.begin_sections(c)
		c.w.ground.fill(255)
		var at_once: Array = shuffled
		var group := WorkerThreadPool.add_group_task(func(i: int) -> void: WorldGen.section(c, at_once[i]), at_once.size())
		WorkerThreadPool.wait_for_group_task_completion(group)
		eq(_digest(c), whole, "seed %d: sections on the worker pool lay the world's surface" % s)


static func _digest(c: GenContext) -> String:
	var parts := PackedStringArray()
	parts.append(c.w.ground.hex_encode().md5_text().substr(0, 8))
	parts.append(c.recipe.hex_encode().md5_text().substr(0, 8))
	parts.append(c.rise.to_byte_array().hex_encode().md5_text().substr(0, 8))
	parts.append(c.forest.to_byte_array().hex_encode().md5_text().substr(0, 8))
	parts.append(c.sea_steps.hex_encode().md5_text().substr(0, 8))
	return " ".join(parts)
