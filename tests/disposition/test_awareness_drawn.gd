extends TestCase
## Awareness is drawn on the machine and nowhere else (VISION §2): the working
## part catches as suspicion grows, the body stands and looks where a noise
## came from, and the alert pose snaps when it is sure.

const F := preload("res://tests/fight/fixture.gd")


## A figure that draws nothing and writes down what it was asked to do.
class Recorder:
	extends FigureModel
	var flares := 0
	var poses: Array[StringName] = []

	func build() -> void:
		pass

	func set_pose(p: StringName) -> void:
		pose = p
		poses.append(p)

	func flare_part() -> void:
		flares += 1


## What the figure was asked to do over `ms` of simulation: {flares, poses}.
## Read out before the node goes, because freeing the mob frees the figure.
func _watch(m: MobState, sim: FightSim, ms: float) -> Dictionary:
	var fig := Recorder.new()
	var mob := Mob.new()
	mob.setup(m, sim.world, null, fig)
	var step := 16.0
	var t := 0.0
	while t < ms:
		F.ms(sim, step)
		t += step
		mob.sync_view(step / 1000.0, sim.now)
	var out := {"flares": fig.flares, "poses": fig.poses.duplicate()}
	mob.free()
	return out


func test_a_body_with_nothing_to_wonder_about_never_flares() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var h := F.still(sim, &"harvester", Vector2(40.5, 20.5), 0.0)
	var fig := _watch(h, sim, 2000.0)
	eq(h.suspicion, 0.0, "it has no reason to look up")
	eq(int(fig.flares), 0, "and its part is steady")


func test_the_working_part_catches_faster_the_surer_it_gets() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var h := F.still(sim, &"harvester", Vector2(32.5, 20.5), PI)
	h.calm_until = 0.0
	h.suspicion = 0.15
	var slow := _watch(h, sim, 1600.0)
	var sim2 := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var h2 := F.still(sim2, &"harvester", Vector2(32.5, 20.5), PI)
	h2.calm_until = 0.0
	h2.suspicion = 0.95
	var fast := _watch(h2, sim2, 1600.0)
	gt(float(slow.flares), 0.0, "at the first stir the part catches now and then")
	gt(float(fast.flares), float(slow.flares) * 1.5, "nearly sure, it catches much faster")


func test_a_noise_stands_the_body_up_and_puts_its_optics_on_the_place() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var h := F.still(sim, &"harvester", Vector2(30.5, 20.5), 0.0)
	h.calm_until = 0.0
	var bang := Vector2(22.0, 20.5)
	sim.make_noise(bang, 24.0)
	# It was looking the other way: turning a harvester round takes it a moment.
	var fig := _watch(h, sim, 2400.0)
	check((fig.poses as Array).has(&"alert"), "it stops and stands up: %s" % [fig.poses])
	var toward := (bang - h.pos).angle()
	lt(absf(wrapf(h.facing - toward, -PI, PI)), 0.5, "and it has turned to where the noise came from")


func test_when_it_is_sure_the_alert_snaps_and_it_settles_back_when_nothing_comes() -> void:
	var sim := F.make_sim(F.flat_world(64), Vector2(20.5, 20.5))
	var r := F.still(sim, &"runner", Vector2(26.5, 20.5), PI)
	r.calm_until = 0.0
	var fig := Recorder.new()
	var mob := Mob.new()
	mob.setup(r, sim.world, null, fig)
	for i in 20:
		F.ms(sim, 16)
		mob.sync_view(0.016, sim.now)
	check(fig.poses.has(&"alert"), "sure of the player, it snaps into its alert silhouette")
	check(mob.aware, "and says so to everyone that reads a mob")
	# Gone: it loses them, forgets, and goes back to standing.
	sim.hero.pos = Vector2(200.0, 200.0)
	for i in 400:
		F.ms(sim, 16)
		mob.sync_view(0.016, sim.now)
	eq(r.suspicion, 0.0, "nothing there any more")
	check(not mob.aware, "it has settled back")
	eq(fig.poses[fig.poses.size() - 1], &"stand", "standing again: %s" % [fig.poses])
	mob.free()
