extends TestCase
## Animals: every kind, every pose, budgets, variation by seed.

const KINDS: Array[StringName] = [&"dog", &"sheep", &"bull", &"rat", &"gull"]


func _colours(m: AnimalModel) -> PackedColorArray:
	return m.rig.body.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]


func test_every_kind_loads_as_an_animal() -> void:
	for k in KINDS:
		var m := FigureModel.create(k)
		check(m is AnimalModel, "%s is an AnimalModel" % k)
		eq(m.kind, k)
		gt(m.height, 0.05, "%s has a height" % k)
		m.free()


func test_every_pose_applies_and_animates() -> void:
	for k in KINDS:
		var m := FigureModel.create(k) as AnimalModel
		for p: StringName in [&"stand", &"idle", &"walk", &"alert", &"flee", &"windup", &"strike", &"attack", &"hurt", &"dead", &"fly", &"nonsense"]:
			m.set_pose(p)
			for i in 20:
				m.animate(1.0 / 30.0, 3.0 if p == &"walk" else 0.0)
		eq(m.pose, &"fly", "%s ignores unknown poses" % k)
		m.set_part_lit(false)
		m.flare_part()
		m.free()


func test_triangle_budget() -> void:
	for k in KINDS:
		for s in 4:
			var m := FigureModel.create(k) as AnimalModel
			m.vary(s)
			lt(m.rig.triangle_count(), 801, "%s seed %d" % [k, s])
			m.free()


func test_animals_vary_by_seed() -> void:
	for k in KINDS:
		var m := FigureModel.create(k) as AnimalModel
		var looks := {}
		var heights := {}
		for s in 8:
			m.vary(s * 13 + 1)
			looks[_colours(m)] = true
			heights[snappedf(m.height, 0.001)] = true
		gt(looks.size(), 2, "%s coats differ" % k)
		gt(heights.size(), 2, "%s sizes differ" % k)
		m.vary(5)
		var a := _colours(m)
		m.vary(5)
		eq(_colours(m), a, "%s: same seed, same animal" % k)
		m.free()


func test_dead_lies_down() -> void:
	for k in KINDS:
		var m := FigureModel.create(k) as AnimalModel
		m.set_pose(&"dead")
		for i in 60:
			m.animate(1.0 / 30.0, 0.0)
		var root := m.rig.skeleton.get_bone_pose_rotation(m.rig.find(&"root")).get_euler()
		gt(absf(root.x) + absf(root.z), 1.2, "%s rolled over" % k)
		m.free()


func test_a_fleeing_gull_takes_to_the_air() -> void:
	var m := FigureModel.create(&"gull") as AnimalModel
	m.set_pose(&"flee")
	for i in 40:
		m.animate(1.0 / 30.0, 0.0)
	var root := m.rig.skeleton.get_bone_pose_position(m.rig.find(&"root"))
	gt(root.y, 0.8, "airborne")
	var wing_a := m.rig.skeleton.get_bone_pose_rotation(m.rig.find(&"wing_l"))
	m.animate(0.08, 0.0)
	check(not wing_a.is_equal_approx(m.rig.skeleton.get_bone_pose_rotation(m.rig.find(&"wing_l"))), "wings beat")
	m.free()


func test_dog_windup_crouches_and_strike_lunges() -> void:
	var m := FigureModel.create(&"dog") as AnimalModel
	var body := m.rig.find(&"body")
	m.set_pose(&"windup")
	for i in 30:
		m.animate(1.0 / 30.0, 0.0)
	var crouch := m.rig.skeleton.get_bone_pose_position(body) - m.rig.rest[body]
	lt(crouch.y, -0.03, "crouched")
	m.set_pose(&"strike")
	for i in 8:
		m.animate(1.0 / 30.0, 0.0)
	var lunge := m.rig.skeleton.get_bone_pose_position(body) - m.rig.rest[body]
	gt(lunge.x, 0.08, "lunges forward")
	m.free()
