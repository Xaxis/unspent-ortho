extends TestCase
## The Mesas' own bodies against the FigureModel contract (docs/LANDSCAPES.md
## §6): the anchor, its keeper, and the kite, its watcher. Neither is one of the
## twelve `test_machines.gd` walks and the sentinel tests build the keeper only
## for its ramp, so without this a fault in either's `build()` would surface
## only in a gallery frame.

const KINDS: Array[StringName] = [&"sentinel_anchor", &"kite"]
const PART_SIDE := {&"sentinel_anchor": &"back", &"kite": &"front"}


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
	var watcher := FigureModel.create(&"kite") as MachineModel
	eq(watcher.ramp, Palette.MACHINE["watcher"], "the kite wears a watcher's cold indigo")
	eq(watcher.disposition, &"observant", "and starts watching")
	watcher.free()


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


## The frame flies; the body does not. What the fight strikes is the winch on
## the ground, so the part is at a hand's height and the frame is up its line.
func test_the_kite_is_up_its_line_and_its_part_is_on_the_ground() -> void:
	var m := FigureModel.create(&"kite") as MachineModel
	m.set_pose(&"stand")
	m.settle()
	gt(m.model_space(m.joints[&"frame"]).origin.y, 4.0, "the frame flies over the winch")
	lt(m.part_position().y, 1.0, "the line is cut at the winch, on the ground")
	m.set_pose(&"dead")
	m.settle()
	lt(m.model_space(m.joints[&"frame"]).origin.y, 1.0, "cut, the frame is down on the rock")
	m.free()


## Stood down until something in the game flies: no landscape rolls it and no
## hour of any day fits it (docs/LANDSCAPES.md, shared system 6).
func test_the_kite_is_stood_down_until_flying_lands() -> void:
	var row := Roster.row(&"kite")
	eq(Swim.crosses(row), Swim.FLY, "it goes over water")
	for d: BiomeDef in BiomeRegistry.all():
		check(not d.roster.has(&"kite"), "%s does not put a kite out yet" % d.id)
	var m := Moment.new()
	for h in 24:
		m.minutes = h * 60.0
		check(not Spawner.moment_fits(row, m), "the kite is never rolled at %d:00" % h)
