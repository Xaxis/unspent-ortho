extends TestCase
## The Ruined Metropolis's own bodies against the FigureModel contract
## (docs/LANDSCAPES.md): the demolisher, a worker found nowhere else, and
## the unbuilder, its keeper. Neither is one of the twelve `test_machines.gd`
## walks, so without this a fault in either's `build()` would surface only in a
## gallery frame somebody happened to shoot.

const KINDS: Array[StringName] = [&"demolisher", &"sentinel_unbuilder"]
const PART_SIDE := {&"demolisher": &"back", &"sentinel_unbuilder": &"back"}


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
	# A worker on a worker's ramp, a keeper on the keeper's: the palette gives a
	# machine its role's colour and nothing else (Palette.MACHINE).
	var worker := FigureModel.create(&"demolisher") as MachineModel
	eq(worker.ramp, Palette.MACHINE["hauler"], "the demolisher wears a worker's violet")
	eq(worker.disposition, &"indifferent", "and starts at its work")
	worker.free()
	var keeper := FigureModel.create(&"sentinel_unbuilder") as MachineModel
	eq(keeper.ramp, Palette.MACHINE["warden"], "the unbuilder wears the keeper's indigo")
	gt(keeper.height, 9.0, "and it is the tallest keeper (%.1f)" % keeper.height)
	keeper.free()


func test_the_part_sits_on_its_side_of_the_body() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid) as MachineModel
		eq(m.part_side, PART_SIDE[kid], "%s part_side" % kid)
		check(m.part_anchor != null, "%s has a part anchor" % kid)
		if m.part_anchor != null:
			var p := m.model_space(m.part_anchor).origin
			var n := MachineModel.side_normal(m.part_side)
			var flat := Vector3(p.x, 0, p.z)
			gt(flat.normalized().dot(n), 0.8, "%s part is on the %s" % [kid, m.part_side])
			# And at a hand's height, on a body a player fights on foot: a part
			# nine units up is a part nobody can reach with a knife.
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


func test_a_dead_unbuilder_is_no_longer_a_doorway() -> void:
	# The silhouette that names it is the girder over the street; dead, the
	# girder is down on it and nothing on the body stands as tall as it did.
	var m := FigureModel.create(&"sentinel_unbuilder") as MachineModel
	m.set_pose(&"stand")
	m.settle()
	var standing := m.top_toward(Vector3.UP).y
	var girder_up := m.model_space(m.joints[&"bridge"]).origin.y
	gt(girder_up, 9.0, "standing, the girder is over the street (%.1f)" % girder_up)
	m.set_pose(&"dead")
	m.settle()
	var fallen := m.top_toward(Vector3.UP).y
	var girder_down := m.model_space(m.joints[&"bridge"]).origin.y
	lt(girder_down, 4.0, "dead, the girder has come down (%.1f)" % girder_down)
	lt(fallen, standing * 0.85, "and the whole wreck stands lower (%.1f from %.1f)" % [fallen, standing])
	m.free()
