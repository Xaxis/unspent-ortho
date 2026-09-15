extends TestCase
## The twelve machines against the FigureModel contract and the art rules:
## weak side per research, poses, hurt holds still, dead is light first,
## regular gait, triangle budget.

const KINDS: Array[StringName] = [&"watcher", &"longlegs", &"harvester", &"cutter", &"hauler", &"warden", &"sweeper", &"dredger", &"lineman", &"flock", &"runner", &"clerk"]
## design-extract §8.1 working part per machine.
const PART_SIDE := {
	&"watcher": &"front", &"longlegs": &"back", &"harvester": &"front", &"cutter": &"back",
	&"hauler": &"left", &"warden": &"front", &"sweeper": &"back", &"dredger": &"front",
	&"lineman": &"front", &"flock": &"none", &"runner": &"back", &"clerk": &"none",
}


static func joint_state(m: MachineModel) -> Array:
	var out: Array = []
	var names: Array = m.joints.keys()
	names.sort()
	for jn: StringName in names:
		var n: Node3D = m.joints[jn]
		out.append([jn, n.position, n.rotation])
	return out


func same_state(a: Array, b: Array, tol: float) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if ((a[i][1] as Vector3) - (b[i][1] as Vector3)).length() > tol:
			return false
		if ((a[i][2] as Vector3) - (b[i][2] as Vector3)).length() > tol:
			return false
	return true


func test_every_kind_creates_as_a_machine() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid)
		check(m is MachineModel, "%s is not a MachineModel (script missing?)" % kid)
		eq(m.kind, kid, "kind")
		gt(m.height, 0.3, "%s height" % kid)
		check(m.get_child_count() > 0, "%s has no geometry" % kid)
		if m is MachineModel:
			check(not (m as MachineModel).joints.is_empty() or kid == &"flock", "%s has no joints" % kid)
			check((m as MachineModel).ramp == Palette.MACHINE[String(kid)], "%s uses its own violet ramp" % kid)
		m.free()


func test_part_side_matches_research() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid)
		eq(m.part_side, PART_SIDE[kid], "%s part_side" % kid)
		m.free()


func test_the_part_sits_on_its_side_of_the_body() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid) as MachineModel
		if m.part_side == &"none":
			check(m.part_anchor == null, "%s has no weak side but has a part" % kid)
			m.free()
			continue
		check(m.part_anchor != null, "%s has no part anchor" % kid)
		if m.part_anchor != null:
			var p := m.model_space(m.part_anchor).origin
			var n := MachineModel.side_normal(m.part_side)
			var flat := Vector3(p.x, 0, p.z)
			gt(flat.normalized().dot(n), 0.8, "%s part is on the %s" % [kid, m.part_side])
		m.free()


func test_all_poses_are_settable_and_unknown_ones_ignored() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid) as MachineModel
		for p: StringName in MachineModel.POSES:
			m.set_pose(p)
			eq(m.pose, p, "%s pose" % kid)
			for i in 20:
				m.animate(1.0 / 30.0, 1.5 if p == &"walk" else 0.0)
			m.settle()
		m.set_pose(&"dance")
		eq(m.pose, &"dead", "%s ignores unknown poses" % kid)
		m.set_pose(&"stand")
		m.flare_part()
		m.set_part_lit(false)
		m.animate(0.1, 0.0)
		m.set_part_lit(true)
		m.animate(1.0, 0.0)
		m.free()


func test_triangle_budget() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid)
		var tris := m.triangle_count()
		lt(tris, 2001.0, "%s triangles" % kid)
		gt(tris, 60.0, "%s is more than a placeholder" % kid)
		m.free()


## Merged by surface kind: body, part, lights, matter, the part's halo, a beam.
func test_draw_call_budget() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid)
		lt(float(m.draw_calls()), 7.0, "%s draw calls" % kid)
		var meshes := m.find_children("*", "GeometryInstance3D", true, false).size()
		lt(float(meshes), 7.0, "%s mesh nodes" % kid)
		m.free()


func test_hurt_puts_the_light_out_and_nothing_flinches() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid) as MachineModel
		m.set_pose(&"walk")
		for i in 17:
			m.animate(1.0 / 30.0, 2.0)
		gt(m.light_level(), 0.9, "%s lit while walking" % kid)
		m.set_pose(&"hurt")
		var before := joint_state(m)
		for i in 30:
			m.animate(1.0 / 30.0, 2.0)
		eq(m.light_level(), 0.0, "%s light out when hurt" % kid)
		check(same_state(before, joint_state(m), 1e-5), "%s flinched when hurt" % kid)
		# And it comes back on after.
		m.set_pose(&"stand")
		for i in 30:
			m.animate(1.0 / 30.0, 0.0)
		eq(m.light_level(), 1.0, "%s relit after hurt" % kid)
		m.free()


func test_dead_is_light_first_then_the_collapse() -> void:
	for kid in KINDS:
		if kid == &"flock":
			continue
		var m := FigureModel.create(kid) as MachineModel
		m.set_pose(&"stand")
		m.settle()
		var standing := joint_state(m)
		m.set_pose(&"dead")
		m.animate(0.1, 0.0)
		# The working part is the last light to go ...
		gt(m.light_level(), 0.0, "%s part still lit as the other lights go" % kid)
		for i in 8:
			m.animate(1.0 / 30.0, 0.0)
		# ... and it is out before anything falls.
		lt(m.pose_time, MachineModel.LIGHT_FIRST, "%s still inside the light sequence" % kid)
		eq(m.light_level(), 0.0, "%s part out before the collapse" % kid)
		check(same_state(standing, joint_state(m), 1e-4), "%s moved before its lights went out" % kid)
		for i in 90:
			m.animate(1.0 / 30.0, 0.0)
		check(not same_state(standing, joint_state(m), 0.05), "%s never collapsed" % kid)
		m.free()


func test_flare_is_brighter_and_brief() -> void:
	var m := FigureModel.create(&"watcher") as MachineModel
	m.settle()
	var base := m.part_emission()
	gt(base, 0.0, "part glows")
	m.flare_part()
	m.animate(0.02, 0.0)
	gt(m.part_emission(), base * 2.0, "flare")
	for i in 30:
		m.animate(1.0 / 30.0, 0.0)
	near(m.part_emission(), base, 0.01, "flare over")
	m.free()


func test_the_part_dims_when_the_camera_sees_the_far_side() -> void:
	for kid in KINDS:
		var m := FigureModel.create(kid) as MachineModel
		if m.part_anchor == null:
			m.free()
			continue
		# Face the part straight at the camera, then straight away from it.
		var n := MachineModel.side_normal(m.part_side)
		m.rotation.y = -PI * 0.25 - atan2(-n.z, n.x)
		m.settle()
		var near_side := m.part_emission()
		m.rotation.y += PI
		m.settle()
		var far_side := m.part_emission()
		gt(near_side, far_side * 1.8, "%s part dims on the far side" % kid)
		m.free()


func test_gait_is_perfectly_regular() -> void:
	for kid in KINDS:
		if kid == &"flock":
			continue
		var m := FigureModel.create(kid) as MachineModel
		m.set_pose(&"walk")
		m.walk_w = 1.0
		m.gait = 0.3
		m.settle()
		var a := joint_state(m)
		m.gait = 7.3
		m.settle()
		check(same_state(a, joint_state(m), 1e-4), "%s: one stride differs from the next" % kid)
		m.free()


func test_walk_moves_the_body() -> void:
	for kid in KINDS:
		if kid == &"flock":
			continue
		var m := FigureModel.create(kid) as MachineModel
		m.set_pose(&"walk")
		m.walk_w = 1.0
		m.gait = 0.0
		m.settle()
		var a := joint_state(m)
		m.gait = 0.25
		m.settle()
		check(not same_state(a, joint_state(m), 0.01), "%s does not move when it walks" % kid)
		m.free()


func test_helpers_beside_the_kinds_are_never_created_as_kinds() -> void:
	for helper: StringName in [&"machine_model", &"found_kit", &"machine_gallery"]:
		var m := FigureModel.create(helper)
		check(m != null, "%s gives a placeholder" % helper)
		check(m.get_script() == FigureModel or helper == &"machine_model", "%s is not a kind" % helper)
		eq(m.kind, helper, "kind")
		m.set_pose(&"dead")
		m.animate(0.1, 0.0)
		m.free()
