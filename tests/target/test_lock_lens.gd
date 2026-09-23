extends TestCase
## A held Z answered with the lens (#120), behind `rules.lock_lens`, which is ON by
## default: the owner kept the lens and made it the default once a quiet re-run of
## its cost cleared the slums and the works depot (docs/ROADMAP.md, DECIDED 1).
## Off, a lock leaves the camera exactly as it was; on, a lock takes
## the lens and letting go gives back what the camera had -- without the switch
## tipping the picture, and with every reader of the lens agreeing.

var _game: Game


## The fixture test_target_system.gd uses: a fresh input frame, a small real game,
## a runner put out and the key forced.
func _make() -> Node:
	await tree.process_frame
	var args := PackedStringArray(["--size=64", "--seed=4", "--hour=11", "--weather=clear:0",
		"--spawn=runner", "--target"])
	_game = Game.new()
	tree.root.add_child(_game)
	_game.setup(BootOptions.parse(args))
	for s in _game.systems:
		if s.name == "42_target":
			return s
	return null


func _done() -> void:
	for a: StringName in [&"target", &"ability_scan", &"move_left", &"move_right"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	GameConfig.forget_edits()
	_game.free()


func _pitch_of(cam: CameraRig) -> float:
	return -rad_to_deg(cam.rotation.x)


func test_the_row_is_on_unless_somebody_turns_it_off() -> void:
	eq(ConfigSchema.default_of("rules.lock_lens"), true, "held Z takes the lens by default")


func test_with_the_row_off_a_lock_leaves_the_camera_as_it_was() -> void:
	# Off by hand now that it is on by default, before the game exists: this is
	# the row's other half.
	GameConfig.set_value("rules.lock_lens", false)
	var sys := await _make()
	var cam := _game.camera
	sys.call("_process", 0.1)
	check(sys.get("locked") != null, "a body is locked")
	eq(cam.lens, &"ortho", "the lens is not taken")
	eq(cam.projection, Camera3D.PROJECTION_ORTHOGONAL, "and the projection is the flat one")
	sys.set("_forced", false)
	sys.call("_process", 0.1)
	eq(cam.lens, &"ortho", "and letting go changes nothing either")
	_done()


func test_with_the_row_on_a_lock_takes_the_lens_and_letting_go_gives_it_back() -> void:
	var sys := await _make()
	var cam := _game.camera
	GameConfig.set_value("rules.lock_lens", true)
	sys.call("_process", 0.1)
	check(sys.get("locked") != null, "a body is locked")
	eq(cam.lens, &"persp", "the lock takes the lens")
	# THE ONE DOOR: before this, `lens` could change while the projection stayed
	# orthographic, and half the readers asked one and half the other.
	eq(cam.projection, Camera3D.PROJECTION_PERSPECTIVE, "and the projection goes with it")
	sys.set("_forced", false)
	sys.call("_process", 0.1)
	eq(cam.lens, &"ortho", "letting go gives the flat camera back")
	eq(cam.projection, Camera3D.PROJECTION_ORTHOGONAL, "projection and all")
	_done()


## The two lenses stand seventeen degrees apart. A switch that took the new pitch
## at once would tip the whole picture in one frame; the difference is carried in
## the lean's own eased offset instead, and glides home.
func test_the_switch_does_not_tip_the_picture() -> void:
	# The switch is measured from OFF to on, so the row starts off by hand now that
	# it is on by default -- before the game exists, so nothing can meet it on.
	GameConfig.set_value("rules.lock_lens", false)
	var sys := await _make()
	var cam := _game.camera
	for i in 40:
		cam._process(0.05)
	var before := _pitch_of(cam)
	near(before, CameraRig.PITCH_DEG, 0.5, "square before the lock")
	GameConfig.set_value("rules.lock_lens", true)
	sys.call("_process", 0.1)
	cam._process(0.0001)
	near(_pitch_of(cam), before, 0.5, "the frame after the switch is at the pitch the frame before was")
	for i in 80:
		cam._process(0.05)
	near(_pitch_of(cam), CameraRig.LENS_PITCH + cam.lean_pitch, 0.5, "and it glides to the lens's own pitch")
	gt(_pitch_of(cam), CameraRig.LENS_FOV * 0.5, "without the lean taking the top edge over the horizon")
	sys.set("_forced", false)
	sys.call("_process", 0.1)
	var at_release := _pitch_of(cam)
	cam._process(0.0001)
	near(_pitch_of(cam), at_release, 0.5, "and letting go does not tip it back either")
	_done()
