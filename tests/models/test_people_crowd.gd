extends TestCase
## What a village of people costs: a crowd poses on a stepped, staggered clock,
## skips what nobody can see, keeps its timers exact between steps, and draws a
## shadow twin only while the sun casts one.

const FRAME := 1.0 / 60.0


func _crowd(n: int, hz: float) -> Array[PersonModel]:
	var out: Array[PersonModel] = []
	var tools: Array[StringName] = [&"", &"pick", &"axe_felling", &"billhook", &"mattock"]
	var i := 0
	for spec: Dictionary in PersonLook.villagers(12, n, BiomeRegistry.get_def(&"coast").hazards):
		var p := PersonModel.make(spec, tools[i % tools.size()])
		p.pose_hz = hz
		if i % 3 == 0:
			p.play_action(&"work", 0.0)
		out.append(p)
		i += 1
	return out


func _free(crowd: Array[PersonModel]) -> void:
	for p in crowd:
		p.free()


func test_a_crowd_poses_on_a_stepped_staggered_clock() -> void:
	var crowd := _crowd(24, PersonModel.CROWD_HZ)
	var start: Array[int] = []
	for p in crowd:
		start.append(p.poses_applied)
	var busiest := 0
	for f in 60:
		var posed := 0
		for i in crowd.size():
			var before := crowd[i].poses_applied
			crowd[i].animate(1.2 if i % 2 else 0.0, FRAME)
			posed += crowd[i].poses_applied - before
		busiest = maxi(busiest, posed)
	for i in crowd.size():
		var n := crowd[i].poses_applied - start[i]
		check(n >= 10 and n <= 13, "about 12 poses a second, got %d" % n)
	# 24 people at 12 Hz over 60 frames is ~4.8 a frame; staggered, no frame takes them all.
	lt(busiest, 11, "a staggered crowd never poses all at once (busiest frame %d)" % busiest)
	_free(crowd)


func test_the_player_poses_every_frame() -> void:
	var p := PersonModel.make({}, &"knife")
	eq(p.pose_hz, 0.0, "the player's figure is not stepped")
	var before := p.poses_applied
	for f in 30:
		p.animate(3.0, FRAME)
	eq(p.poses_applied - before, 30, "a pose on every frame")
	p.free()


func test_timers_stay_exact_between_steps() -> void:
	var p := PersonModel.make({}, &"knife")
	p.pose_hz = PersonModel.CROWD_HZ
	p.play_action(&"swing", 0.3)
	for f in 9:
		p.animate(0.0, FRAME)
	near(p.action_progress(), 0.5, 0.02, "progress runs between poses")
	for f in 12:
		p.animate(0.0, FRAME)
	check(not p.busy(), "the action ends on time, not on the next step")
	p.free()


func test_hidden_offscreen_and_frozen_figures_are_not_posed() -> void:
	var hidden := PersonModel.make({})
	hidden.pose_hz = PersonModel.CROWD_HZ
	tree.root.add_child(hidden)
	hidden.visible = false
	var before := hidden.poses_applied
	for f in 30:
		hidden.animate(1.0, FRAME)
	eq(hidden.poses_applied, before, "indoors, nobody poses")
	hidden.visible = true
	for f in 30:
		hidden.animate(1.0, FRAME)
	gt(hidden.poses_applied, before, "back out, posing again")

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 10.0
	tree.root.add_child(cam)
	cam.make_current()
	cam.position = Vector3(0, 10, 10)
	cam.look_at(Vector3.ZERO)
	var away := PersonModel.make({})
	away.pose_hz = PersonModel.CROWD_HZ
	tree.root.add_child(away)
	away.position = Vector3(200, 0, 0)
	var seen := PersonModel.make({})
	seen.pose_hz = PersonModel.CROWD_HZ
	tree.root.add_child(seen)
	var away0 := away.poses_applied
	var seen0 := seen.poses_applied
	for f in 30:
		away.animate(1.0, FRAME)
		seen.animate(1.0, FRAME)
	eq(away.poses_applied, away0, "off camera, not posed")
	gt(seen.poses_applied, seen0, "in view, posed")

	var frozen := PersonModel.make({}, &"knife")
	frozen.pose_hz = PersonModel.CROWD_HZ
	frozen.pose_at(&"swing", 0.1)
	var f0 := frozen.poses_applied
	for f in 30:
		frozen.animate(0.0, FRAME)
	eq(frozen.poses_applied, f0, "a frozen pose already on the skeleton is left alone")
	frozen.play_action(&"", 0.0)
	for f in 30:
		frozen.animate(0.0, FRAME)
	gt(frozen.poses_applied, f0, "released from the freeze, it poses again on its steps")
	frozen.free()
	for n: Node in [hidden, cam, away, seen]:
		n.queue_free()
	await frames(1)


func test_twenty_four_villagers_cost_about_a_millisecond_each() -> void:
	var crowd := _crowd(24, PersonModel.CROWD_HZ)
	# Settle the pose cache first, as a village that has stood a while has.
	for f in 30:
		for i in crowd.size():
			crowd[i].animate(1.2 if i % 2 else 0.0, FRAME)
	var frames_n := 120
	var poses0 := 0
	for p in crowd:
		poses0 += p.poses_applied
	var t0 := Time.get_ticks_usec()
	for f in frames_n:
		for i in crowd.size():
			crowd[i].animate(1.2 if i % 2 else 0.0, FRAME)
	var stepped := float(Time.get_ticks_usec() - t0) / frames_n / crowd.size()
	var poses := 0
	for p in crowd:
		poses += p.poses_applied
	# Counted, not timed: a loaded machine can make any one timing lie.
	lt(float(poses - poses0), frames_n * crowd.size() * 0.25, "a stepped crowd poses a fifth as often as the frames (%d of %d)" % [poses - poses0, frames_n * crowd.size()])
	print("  crowd of 24 (script): %.3f ms a person a frame stepped" % (stepped / 1000.0))
	lt(stepped, 1000.0, "a stepped villager's animate is under a millisecond (%.0f us)" % stepped)

	# Whole frames with the crowd standing in the tree, so the engine's skeleton
	# and skin updates count too, against the same frames with nobody there.
	var stage := Node3D.new()
	tree.root.add_child(stage)
	for f in 20:
		await tree.process_frame
	var empty := await _frame_usec(crowd, false, 90)
	for p in crowd:
		p.pose_hz = PersonModel.CROWD_HZ
		stage.add_child(p)
	for f in 20:
		for i in crowd.size():
			crowd[i].animate(1.2 if i % 2 else 0.0, FRAME)
		await tree.process_frame
	var full := await _frame_usec(crowd, true, 90)
	var each := maxf(0.0, full - empty) / crowd.size()
	print("  crowd of 24 (frames): %.3f ms a person a frame (frame %.2f ms, empty %.2f ms)" % [each / 1000.0, full / 1000.0, empty / 1000.0])
	lt(each, 1000.0, "an animated villager costs under a millisecond a frame (%.0f us)" % each)
	stage.free()


## Mean microseconds per frame over `n` frames, animating the crowd first when `live`.
func _frame_usec(crowd: Array[PersonModel], live: bool, n: int) -> float:
	var t0 := Time.get_ticks_usec()
	for f in n:
		if live:
			for i in crowd.size():
				crowd[i].animate(1.2 if i % 2 else 0.0, FRAME)
		await tree.process_frame
	return float(Time.get_ticks_usec() - t0) / n


func test_the_shadow_twin_shows_only_while_the_sun_casts() -> void:
	var stage := Node3D.new()
	tree.root.add_child(stage)
	var sky := SkyLight.new()
	stage.add_child(sky)
	var p := PersonModel.make({})
	stage.add_child(p)
	check(p.rig.shadow != null, "people have a shadow twin")
	p.sun = sky.sun
	sky.set_hour(12.0)
	p.animate(0.0, 0.3)
	eq(p.rig.shadow.visible, sky.sun.shadow_enabled, "at noon the twin follows the sun")
	check(p.rig.shadow.visible, "and the noon sun casts")
	sky.set_hour(23.5)
	p.animate(0.0, 0.3)
	eq(p.rig.shadow.visible, sky.sun.shadow_enabled, "at night too")
	check(not p.rig.shadow.visible, "no shadow drawn under the moon")
	stage.queue_free()
	await frames(1)
