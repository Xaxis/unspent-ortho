extends TestCase
## The Drowned City's own bodies against the FigureModel contract
## (docs/LANDSCAPES.md §5): the lockkeeper, its keeper. It is not one of the
## twelve `test_machines.gd` walks, so without this a fault in its `build()`
## would surface only in a gallery frame somebody happened to shoot.

const KINDS: Array[StringName] = [&"sentinel_lockkeeper"]
const PART_SIDE := {&"sentinel_lockkeeper": &"back"}


func test_each_creates_as_a_machine_on_a_ramp_of_its_role() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid)
		check(m is MachineModel, "%s is a MachineModel" % kid)
		if not m is MachineModel:
			m.free()
			continue
		var mm := m as MachineModel
		check(not mm.joints.is_empty(), "%s has joints" % kid)
		gt(mm.height, 1.0, "%s stands up" % kid)
		check(mm.get_child_count() > 0, "%s has geometry" % kid)
		mm.free()
	var keeper := FigureModel.create(&"sentinel_lockkeeper") as MachineModel
	eq(keeper.ramp, Palette.MACHINE["warden"], "the lockkeeper wears the keeper's indigo")
	keeper.free()


func test_the_part_sits_on_its_side_of_the_body_within_reach() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid) as MachineModel
		eq(m.part_side, PART_SIDE[kid], "%s part_side" % kid)
		check(m.part_anchor != null, "%s has a part anchor" % kid)
		if m.part_anchor != null:
			var p := m.model_space(m.part_anchor).origin
			var n := MachineModel.side_normal(m.part_side)
			var flat := Vector3(p.x, 0, p.z)
			gt(flat.normalized().dot(n), 0.8, "%s part is on the %s" % [kid, m.part_side])
			# A hull carried three units up is out of reach; the pump is hung
			# down off the transom so a hand in the canal can get at it.
			lt(p.y, 1.6, "%s's part is within reach (%.2f up)" % [kid, p.y])
		m.free()


func test_every_pose_settles_and_the_body_stays_within_its_draw_budget() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid) as MachineModel
		for p: StringName in MachineModel.POSES:
			m.set_pose(p)
			eq(m.pose, p, "%s takes pose %s" % [kid, p])
			for i in 20:
				m.animate(1.0 / 30.0, 1.5 if p == &"walk" else 0.0)
			m.settle()
		check(m.draw_calls() <= 6, "%s draws in %d calls (budget 6)" % [kid, m.draw_calls()])
		m.free()


func test_the_lockkeeper_is_a_boat_carried_over_the_water_and_a_wreck_in_it_when_dead() -> void:
	# The silhouette that names it is a hull held up on stilts: standing, the
	# hull rides well over a body's head; dead, it has gone down into the canal.
	var m := FigureModel.create(&"sentinel_lockkeeper") as MachineModel
	m.set_pose(&"stand")
	m.settle()
	var hull_up := m.model_space(m.joints[&"hull"]).origin.y
	gt(hull_up, 2.8, "standing, the hull is carried over the water (%.1f)" % hull_up)
	var blade_up := m.model_space(m.joints[&"blade"]).origin.y
	m.set_pose(&"strike")
	m.settle()
	var blade_down := m.model_space(m.joints[&"blade"]).origin.y
	lt(blade_down, blade_up - 1.0, "the strike drops the gate blade (%.1f from %.1f)" % [blade_down, blade_up])
	m.set_pose(&"dead")
	m.settle()
	var hull_down := m.model_space(m.joints[&"hull"]).origin.y
	lt(hull_down, 1.5, "dead, the hull has gone down into the canal (%.1f)" % hull_down)
	m.free()


func test_its_body_row_walks_the_deep() -> void:
	# The canals are the streets here: a keeper the waterline stopped would
	# leave the one place worth keeping to anybody with a raft (src/core/swim.gd).
	check(Swim.crosses(Roster.row(&"sentinel.drowned")) == &"swim", "the lockkeeper goes in after you")
