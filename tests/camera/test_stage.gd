extends TestCase
## THE STAGED LOOK (42_stage): the view turns to a thing, holds, turns back; the
## keys are held for it; from above the lens is the eye's for the look and is
## handed back; one look at a time.

const Sx := preload("res://tests/save/save_fixture.gd")


func _wall(secs: float) -> void:
	await tree.create_timer(secs).timeout


func _forward(g: Game) -> Vector3:
	return -g.camera.global_basis.z


func test_a_look_turns_the_view_holds_it_and_gives_it_back() -> void:
	var g := Sx.game(tree, ["--seed=4", "--size=64", "--hour=12", "--weather=clear:0"])
	await process_frames(3)
	var stage: Node = tree.get_first_node_in_group(&"stage")
	check(stage != null, "the stage is in the game")
	eq(g.camera.lens, &"ortho", "from above to begin with")
	var before := _forward(g)
	var dir := Vector3(cos(PI) * cos(0.8), sin(0.8), sin(PI) * cos(0.8))
	var done: Array[StringName] = []
	stage.looked.connect(func(w: StringName) -> void: done.append(w))
	check(bool(stage.call(&"look_bearing", PI, 0.8, 1.5, &"test")), "the look begins")
	check(not bool(stage.call(&"look_bearing", 0.0, 0.5, 1.0, &"other")), "and a second is refused while it is on")
	check(g.input_blocked(), "the keys are held")
	var from := g.player.pos
	Input.action_press(&"move_up")
	await _wall(1.2)
	Input.action_release(&"move_up")
	eq(g.camera.lens, &"persp", "from above the look is the eye's")
	lt(rad_to_deg(_forward(g).angle_to(dir)), 3.0, "turned to the bearing and held there")
	lt(from.distance_to(g.player.pos), 0.05, "and nobody walked under it")
	await _wall(1.8)
	eq(done, [&"test"] as Array[StringName], "the look says it is over")
	check(not g.input_blocked(), "the keys are handed back")
	eq(g.camera.lens, &"ortho", "and the lens")
	# The lens handed back eases its own pitch home, as every change of lens does.
	await _wall(1.0)
	lt(rad_to_deg(_forward(g).angle_to(before)), 1.0, "the view is where it was")
	Sx.end(g)
