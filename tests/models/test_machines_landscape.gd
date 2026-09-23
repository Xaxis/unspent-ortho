extends TestCase
## Every machine the roster names PAST the coast's twelve -- a landscape's own
## worker, a keeper -- against the contract `test_machines.gd` holds the twelve
## to. The twelve are a fixed list there, so a kind added with a landscape had
## nothing asking whether its model built at all: `FigureModel.create` hands back
## a bare placeholder for a script that is missing or fails to parse, and
## nothing raises. This asks the script that answered to be the kind's own.

const TWELVE: Array[StringName] = [&"watcher", &"longlegs", &"harvester", &"cutter", &"hauler", &"warden",
	&"sweeper", &"dredger", &"lineman", &"flock", &"runner", &"clerk"]


## [model id, roster kind] for every machine row whose model is not one of the
## twelve, each model once.
static func others() -> Array:
	var out: Array = []
	var seen := {}
	for kind: StringName in Roster.DEFS:
		var row: Dictionary = Roster.DEFS[kind]
		if not row.get("machine", false):
			continue
		var model := StringName(str(row.get("model", &"")))
		if TWELVE.has(model) or seen.has(model):
			continue
		seen[model] = true
		out.append([model, kind])
	return out


func test_every_landscapes_machine_is_drawn_by_its_own_script() -> void:
	var kinds := others()
	gt(float(kinds.size()), 0.0, "the landscapes have machines of their own")
	for pair: Array in kinds:
		var model: StringName = pair[0]
		var kind: StringName = pair[1]
		var m := FigureModel.create(model)
		var script: Script = m.get_script()
		var by := script.resource_path.get_file().get_basename() if script != null else ""
		eq(by, String(model), "%s is drawn by its own script; the placeholder means it is missing or does not parse" % model)
		gt(m.height, 0.3, "%s has a height" % model)
		check(m.get_child_count() > 0, "%s has geometry" % model)
		if m is MachineModel:
			var mm := m as MachineModel
			check(not mm.joints.is_empty(), "%s has joints to pose" % model)
			gt(float(mm.ramp.size()), 0.0, "%s is on a ramp" % model)
			var part := StringName(str(Roster.row(kind).get("part", &"front")))
			if part != &"none":
				eq(m.part_side, part, "%s's model and its roster row agree about its working side" % model)
				check(mm.part_anchor != null, "%s draws its working part" % model)
			for p: StringName in MachineModel.POSES:
				mm.set_pose(p)
				mm.settle()
			lt(float(m.draw_calls()), 7.0, "%s is within a machine's draw budget (%d)" % [model, m.draw_calls()])
		m.free()
