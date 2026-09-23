extends TestCase
## The Mesas' own bodies against the FigureModel contract (docs/LANDSCAPES.md
## §6): the anchor, its keeper. It is not one of the twelve `test_machines.gd`
## walks and the sentinel tests build it only for its ramp, so without this a
## fault in its `build()` would surface only in a gallery frame.

const KINDS: Array[StringName] = [&"sentinel_anchor"]
const PART_SIDE := {&"sentinel_anchor": &"back"}


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
	var keeper := FigureModel.create(&"sentinel_anchor") as MachineModel
	eq(keeper.ramp, Palette.MACHINE["warden"], "the anchor wears the keeper's indigo")
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


## The silhouette that names it is four knees over its back and a tail over
## those; dead, it lies flat and nothing on it stands as tall as it did.
func test_a_dead_anchor_lies_flat() -> void:
	var m := FigureModel.create(&"sentinel_anchor") as MachineModel
	m.set_pose(&"stand")
	m.settle()
	var standing := m.top_toward(Vector3.UP).y
	gt(standing, 4.0, "standing, the tail's weight is over everything (%.1f)" % standing)
	m.set_pose(&"dead")
	m.settle()
	var fallen := m.top_toward(Vector3.UP).y
	lt(fallen, standing * 0.7, "dead, it lies low (%.1f from %.1f)" % [fallen, standing])
	m.free()


## It climbs because its row says so, and only while a phase lets it: the ride
## FightSim moves it with steps four levels, and the grounded phase puts it back
## on a walker's one.
func test_it_climbs_until_it_is_grounded() -> void:
	var row := Roster.row(&"sentinel.mesas").duplicate(true)
	var ride := FightSim.climber(row)
	check(ride != null, "the anchor moves as a climber")
	if ride != null:
		eq(ride.levels, 4, "four levels a move")
	check(FightSim.climber(Roster.row(&"harvester")) == null, "a worker takes the one level every body takes")
	var def := Sentinels.by_id(&"anchor")
	check(def != null, "the anchor's design is found")
	if def == null:
		return
	var last: SentinelPhase = def.phases[def.phases.size() - 1]
	row.merge(last.row_patch(), true)
	check(FightSim.climber(row) == null, "grounded, it cannot climb")

