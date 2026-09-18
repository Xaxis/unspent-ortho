extends TestCase
## What a Mob asks of its figure, and in what order. The machines' figure draws
## a flare only on a part that is lit and not in the hurt pose, so a real hit
## must flare first and go dark after, or the flare is never seen.

const F := preload("res://tests/fight/fixture.gd")


## A figure that draws nothing and writes down every call with the sim time.
class Recorder:
	extends FigureModel
	var calls: Array[Dictionary] = []
	var now := 0.0
	var lit := true

	func build() -> void:
		pass

	func set_pose(p: StringName) -> void:
		pose = p
		calls.append({"at": now, "call": &"set_pose", "arg": p})

	func set_part_lit(on: bool) -> void:
		lit = on
		calls.append({"at": now, "call": &"set_part_lit", "arg": on})

	func flare_part() -> void:
		calls.append({"at": now, "call": &"flare_part", "lit": lit, "pose": pose})

	func first(call: StringName, arg: Variant = null) -> Dictionary:
		for c in calls:
			if c.call == call and (arg == null or c.get("arg") == arg):
				return c
		return {}


func _hit_a_harvester_and_watch() -> Recorder:
	var sim := F.make_sim()
	var at := Vector2(30.5, 20.5)
	var m := F.still(sim, &"harvester", at, PI)
	sim.hero.pos = at + Vector2(-1, 0) * (m.radius + sim.hero.radius + 0.3)
	sim.hero.facing = 0.0
	var fig := Recorder.new()
	var mob := Mob.new()
	mob.setup(m, sim.world, null, fig)
	sim.press_swing()
	var hit_seen := false
	for i in 120:
		sim.slices(1)
		fig.now = sim.now
		var events := sim.drain()
		if not hit_seen and F.count(events, &"hit") > 0:
			hit_seen = true
			# The hitstop's first frame holds the pose: delta 0.
			mob.sync_view(0.0, sim.now)
		else:
			mob.sync_view(FightRules.SLICE_MS / 1000.0, sim.now)
	check(hit_seen, "the blow reached the part")
	# The recorder outlives the view it recorded (the caller frees it).
	fig.get_parent().remove_child(fig)
	mob.free()
	return fig


func test_a_real_hit_flares_the_part_while_it_is_still_lit() -> void:
	var fig := _hit_a_harvester_and_watch()
	var flare := fig.first(&"flare_part")
	check(not flare.is_empty(), "the part was flared")
	if flare.is_empty():
		fig.free()
		return
	eq(flare.lit, true, "on a lit part")
	check(flare.pose != &"hurt", "not in the hurt pose (%s)" % flare.pose)
	fig.free()


func test_the_part_goes_dark_only_after_the_flare_has_shown() -> void:
	var fig := _hit_a_harvester_and_watch()
	var calls := fig.calls
	var flare := fig.first(&"flare_part")
	var dark := fig.first(&"set_part_lit", false)
	var hurt := fig.first(&"set_pose", &"hurt")
	fig.free()
	check(not dark.is_empty(), "the part went dark")
	check(not hurt.is_empty(), "the body took the hurt pose")
	if flare.is_empty() or dark.is_empty() or hurt.is_empty():
		return
	gt(float(dark.at) - float(flare.at), 119.0, "lit for at least 120 ms of flare")
	gt(float(hurt.at) - float(flare.at), 119.0, "and not hurt before then")
	var relit := {}
	for c in calls:
		if c.call == &"set_part_lit" and c.arg == true and float(c.at) > float(dark.at):
			relit = c
			break
	check(not relit.is_empty(), "and lights again after")
	if not relit.is_empty():
		near(float(relit.at) - float(dark.at), FightRules.PART_DARK_MS, FightRules.SLICE_MS + 0.1, "dark for its time")


func test_a_spent_bite_flares_the_part_once_while_it_is_lit() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 40.5))
	var m := F.still(sim, &"runner", Vector2(20.5, 20.5), 0.0)
	var fig := Recorder.new()
	var mob := Mob.new()
	mob.setup(m, sim.world, null, fig)
	m.start_blow(m.bite, sim.now)
	var opened_at := -1.0
	for i in 160:
		sim.slices(1)
		fig.now = sim.now
		if opened_at < 0.0 and F.count(sim.drain(), &"opened") > 0:
			opened_at = sim.now
		mob.sync_view(FightRules.SLICE_MS / 1000.0, sim.now)
	check(opened_at > 0.0, "the bite went spent")
	var flares := fig.calls.filter(func(c: Dictionary) -> bool: return c.call == &"flare_part")
	eq(flares.size(), 1, "one flare for one opening")
	if flares.size() == 1:
		eq(flares[0].lit, true, "on a lit part")
		check(flares[0].pose != &"hurt", "not in the hurt pose (%s)" % flares[0].pose)
		lt(absf(float(flares[0].at) - opened_at), FightRules.SLICE_MS * 2.0 + 0.1, "as it opens")
	check(not fig.first(&"set_pose", &"stand").is_empty(), "and it stands spent")
	fig.get_parent().remove_child(fig)
	mob.free()
	fig.free()


func test_a_creature_has_no_flare_and_is_hurt_at_once() -> void:
	var sim := F.make_sim()
	var at := Vector2(30.5, 20.5)
	var m := F.still(sim, &"dog.yard", at, PI)
	sim.hero.pos = at + Vector2(-1, 0) * (m.radius + sim.hero.radius + 0.3)
	sim.hero.facing = 0.0
	sim.press_swing()
	for i in 60:
		sim.slices(1)
		if m.last_hit_at > 0.0:
			break
	check(m.last_hit_at > 0.0, "struck")
	check(not m.part_flaring(sim.now), "no flare")
	check(m.part_dark(sim.now), "hurt now")


func test_marks_are_never_smaller_than_their_screen_size() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var was := MobFx.texel
	# The camera players get: 15 world units over the BASE's own rows. It read
	# `15.0 / 360.0` here — three times too generous — so every floor below was
	# met by a quad three times the size the game really draws, which is how a
	# floor a third of its intended reach went on passing its own test.
	MobFx.texel = 15.0 / float(UiBase.SIZE.y)
	MobFx.burst(root, Vector3.ZERO, 0.1, 1)
	MobFx.tell(root, Vector3(0, 1, 0), Vector3.UP, 0.4, 2, 0.1)
	var quads: Array[MeshInstance3D] = []
	for c in root.get_children():
		quads.append(c as MeshInstance3D)
	eq(quads.size(), 2, "two marks")
	if quads.size() == 2:
		# A mark's quad is 2 units, scaled by half its size.
		gt(quads[0].scale.x * 2.0 / MobFx.texel, MobFx.BURST_PX - 0.01, "a burst at least %d px across" % MobFx.BURST_PX)
		gt(quads[1].scale.x * 2.0 / MobFx.texel, MobFx.TELL_PX - 0.01, "a tell at least %d px" % MobFx.TELL_PX)
		gt(quads[1].position.y, 1.0 + MobFx.pen_px(3.0) - 0.001, "the tell stands clear above the top it was given")
	# Zoomed in, a mark keeps its world size when that is the larger.
	MobFx.texel = 15.0 / float(UiBase.SIZE.y) * 0.25
	MobFx.burst(root, Vector3.ZERO, 1.2, 3)
	var last := root.get_child(root.get_child_count() - 1) as MeshInstance3D
	near(last.scale.x * 2.0, 1.2, 0.001, "world size when close")
	MobFx.texel = was
	root.queue_free()
	await frames(1)


func test_a_body_reports_the_top_of_its_whole_silhouette() -> void:
	var w := F.flat_world(32)
	var s := MobState.new(&"harvester", Vector2(10.5, 10.5), 7)
	var fig := FigureModel.create(&"no_such_figure")
	var mob := Mob.new()
	tree.root.add_child(mob)
	mob.setup(s, w, null, fig)
	var up := Vector3(0.0, 0.545, -0.839).normalized()
	var top := mob.screen_top(up)
	var base := mob.global_position.dot(up)
	gt(top.dot(up), base + 0.5, "the top is above the feet on screen")
	mob.queue_free()
	await frames(1)


func test_a_mob_says_when_it_has_noticed_and_tells_its_machine_it_hunts() -> void:
	var w := F.flat_world(32)
	var s := MobState.new(&"runner", Vector2(10.5, 10.5), 9)
	var mob := Mob.new()
	tree.root.add_child(mob)
	mob.setup(s, w, null)
	var machine := mob.model as MachineModel
	check(machine != null, "a runner is drawn by its machine")
	check(not mob.aware and not machine.hunting, "idle: nothing noticed, nothing hunted")
	s.mood = MobState.ALERTED
	mob.sync_view(0.016, 0.0)
	check(mob.aware, "alerted: it has noticed")
	check(not machine.hunting, "but it is not running anyone down yet")
	s.mood = MobState.CHASING
	mob.sync_view(0.016, 16.0)
	check(mob.aware and machine.hunting, "chasing: aware, and its eyes lock on the hunt")
	s.mood = MobState.IDLE
	mob.sync_view(0.016, 32.0)
	check(not mob.aware and not machine.hunting, "given up: neither")
	mob.queue_free()
	await frames(1)

## A kill reads from the camera above: within FOLD_MS the body is over on its
## side and flat, its light is out, and it is in the dead pose; it never stands
## as it did alive.
func test_a_killed_machine_folds_flat_and_its_light_goes_out() -> void:
	var sim := F.make_sim()
	var m := F.still(sim, &"runner", Vector2(24.5, 20.5), PI)
	var fig := Recorder.new()
	var mob := Mob.new()
	mob.setup(m, sim.world, null, fig)
	mob.sync_view(0.016, sim.now)
	near(mob.pivot.scale.y, 1.0, 0.001, "alive, it stands full height")
	m.health = 1
	sim._hurt_mob(m, Blow.for_item(&"knife", 5000))
	check(not m.alive, "killed")
	fig.now = sim.now
	mob.sync_view(0.016, sim.now)
	eq(fig.pose, &"dead", "the dead pose at once")
	check(not fig.lit, "its light is out at once")
	F.ms(sim, Mob.FOLD_MS * 0.5)
	mob.sync_view(0.016, sim.now)
	var half := mob.pivot.scale.y
	check(half < 1.0 and half > Mob.FOLD_FLAT, "half way down at half the fold (%.2f)" % half)
	F.ms(sim, Mob.FOLD_MS * 0.5 + 16)
	mob.sync_view(0.016, sim.now)
	near(mob.pivot.scale.y, Mob.FOLD_FLAT, 0.001, "flat within %d ms" % Mob.FOLD_MS)
	gt(absf(mob.pivot.quaternion.get_angle()), Mob.FOLD_ROLL * 0.9, "and over on its side")
	lt(mob.pivot.position.y, -Mob.FOLD_SINK * 0.9, "and down in the grass")
	fig.get_parent().remove_child(fig)
	fig.free()
	mob.free()
