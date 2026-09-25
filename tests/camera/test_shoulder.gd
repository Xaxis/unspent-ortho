extends TestCase
## The view over the shoulder (41_shoulder, CameraRig, src/core/view/shoulder.gd).
##
## What is held here is what the owner asked for in so many words: that it is
## SEAMLESS (no frame where the picture jumps, either way, across the projection
## change), that it SEES THE SKY, that the keys walk where the camera looks, that
## the pointer is only ever held while the view is up and the keys are the
## game's, and that the camera never stands inside the land or a house.

const Shoulder := preload("res://src/core/view/shoulder.gd")
const F := preload("res://tests/fight/fixture.gd")
const DT := 1.0 / 60.0

var _game: Game


func _make(extra: Array[String] = []) -> Game:
	await tree.process_frame
	var args := PackedStringArray(["--size=64", "--seed=4", "--hour=11", "--weather=clear:0"])
	args.append_array(PackedStringArray(extra))
	_game = Game.new()
	tree.root.add_child(_game)
	_game.setup(BootOptions.parse(args))
	return _game


func _system(g: Game) -> Node:
	for s in g.systems:
		if s.name == "41_shoulder":
			return s
	return null


func _done() -> void:
	for a: StringName in [&"shoulder", &"target", &"shoulder_peek", &"look_right", &"look_up"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	GameConfig.forget_edits()
	_game.free()


func _step(cam: CameraRig, n: int) -> void:
	for i in n:
		cam._process(DT)


func _pitch_of(cam: CameraRig) -> float:
	return -rad_to_deg(cam.rotation.x)


# --- the glide ---------------------------------------------------------------

func test_the_glide_reaches_both_ends() -> void:
	var g := await _make()
	var cam := g.camera
	cam.sight_room = Callable()
	_step(cam, 30)
	eq(cam.projection, Camera3D.PROJECTION_ORTHOGONAL, "it opens looking down on the land")
	cam.shoulder = true
	_step(cam, ceili(Shoulder.BLEND_SECS / DT) + 2)
	check(cam.over_shoulder(), "the glide arrives")
	eq(cam.projection, Camera3D.PROJECTION_PERSPECTIVE, "under the lens")
	near(cam.fov, Shoulder.FOV, 0.01, "at the shoulder's own field of view")
	near(_pitch_of(cam), Shoulder.PITCH, 0.01, "and its own pitch")
	near(cam.near, Shoulder.NEAR, 0.001, "with the near plane pulled in")
	var head := g.player.position + Vector3(0.0, 1.0, 0.0)
	lt(cam.global_position.distance_to(head), Shoulder.BACK + 1.5, "standing at the player's shoulder")
	cam.shoulder = false
	_step(cam, ceili(Shoulder.BLEND_SECS / DT) + 2)
	near(cam.shoulder_share(), 0.0, 1e-6, "and it glides all the way back")
	eq(cam.lens, &"ortho", "giving the lens up")
	eq(cam.projection, Camera3D.PROJECTION_ORTHOGONAL, "projection and all")
	_step(cam, 200)
	near(_pitch_of(cam), cam.pitch_deg, 0.3, "and the land's own pitch comes home")
	_done()


## The top edge of the frame is above the horizon: sky and the far land are in
## the picture, which is the whole of what the view was asked for.
func test_the_sky_is_in_the_frame() -> void:
	var g := await _make()
	var cam := g.camera
	cam.sight_room = Callable()
	cam.shoulder = true
	_step(cam, 40)
	var top := cam.project_ray_normal(Vector2(cam.get_viewport().get_visible_rect().size.x * 0.5, 0.0))
	gt(top.y, 0.1, "the ray through the top of the frame goes up")
	_done()


## NO FRAME JUMPS. Every frame of the way down and back, measured on the picture:
## where the player's head lands on screen, where a point out on the land lands,
## and how far the eye itself moves. A pop is hundreds of pixels in a frame; the
## glide at its steepest is a few tens.
func test_no_frame_of_the_glide_jumps() -> void:
	var g := await _make()
	var cam := g.camera
	cam.sight_room = Callable()
	_step(cam, 60)
	var head := g.player.position + Vector3(0.0, 1.6, 0.0)
	var feet := g.player.position
	var worst_head := 0.0
	var worst_feet := 0.0
	var worst_eye := 0.0
	var worst_turn := 0.0
	var last_head := cam.unproject_position(head)
	var last_feet := cam.unproject_position(feet)
	var last_eye := cam.global_position
	var last_basis := cam.global_transform.basis
	var switched := 0
	var last_proj := cam.projection
	for leg: bool in [true, false]:
		cam.shoulder = leg
		for i in 50:
			cam._process(DT)
			# An orthographic camera's place along its own axis moves nothing in
			# the picture, so the eye is only compared between two lens frames.
			var both_lens := cam.projection == Camera3D.PROJECTION_PERSPECTIVE \
				and last_proj == Camera3D.PROJECTION_PERSPECTIVE
			if cam.projection != last_proj:
				switched += 1
				last_proj = cam.projection
			var h := cam.unproject_position(head)
			var f := cam.unproject_position(feet)
			worst_head = maxf(worst_head, h.distance_to(last_head))
			worst_feet = maxf(worst_feet, f.distance_to(last_feet))
			if both_lens:
				worst_eye = maxf(worst_eye, cam.global_position.distance_to(last_eye))
			var b := cam.global_transform.basis
			worst_turn = maxf(worst_turn, rad_to_deg(acos(clampf(b.z.dot(last_basis.z), -1.0, 1.0))))
			last_head = h
			last_feet = f
			last_eye = cam.global_position
			last_basis = b
	print("  glide, worst frame: feet %.1f px, head %.1f px, turn %.2f deg, eye %.2f" % [worst_feet, worst_head, worst_turn, worst_eye])
	eq(switched, 2, "the projection changed once each way")
	lt(worst_feet, 45.0, "the player's feet never jump on screen")
	lt(worst_head, 60.0, "nor their head")
	lt(worst_turn, 4.0, "the view never turns more than a few degrees in a frame")
	lt(worst_eye, 1.2, "and the eye never leaps")
	_done()


## Holding Z first and then the shoulder, and letting go in either order: a lock
## held while the shoulder is left lands on the lock's lens; the last to let go
## hands back the flat camera.
func test_the_lens_is_held_by_whoever_still_wants_it() -> void:
	var g := await _make()
	var cam := g.camera
	cam.sight_room = Callable()
	cam.hold_lens(&"target", true)
	cam.shoulder = true
	_step(cam, 40)
	cam.shoulder = false
	_step(cam, 40)
	eq(cam.lens, &"persp", "left while a lock still wants it, the lens stays")
	near(cam.fov, CameraRig.LENS_FOV, 0.01, "and it is the lens's pose, not the shoulder's")
	cam.hold_lens(&"target", false)
	eq(cam.lens, &"ortho", "and the last to let go hands back the flat camera")
	cam.shoulder = true
	_step(cam, 40)
	cam.hold_lens(&"target", true)
	cam.hold_lens(&"target", false)
	eq(cam.lens, &"persp", "a lock let go under the shoulder leaves the shoulder its lens")
	_done()


# --- the keys ----------------------------------------------------------------

## Up on the keys walks where the camera looks, at any yaw the mouse can put it
## at: asked of the camera's own transform, not of the number it was given.
func test_the_keys_walk_where_the_camera_looks() -> void:
	var g := await _make()
	var cam := g.camera
	cam.sight_room = Callable()
	cam.shoulder = true
	_step(cam, 40)
	for yaw: float in [45.0, 130.0, -100.0, 200.0]:
		cam.shoulder_yaw = yaw
		cam._process(DT)
		var ahead := -cam.global_transform.basis.z
		var look := Vector2(ahead.x, ahead.z).normalized()
		var up := Player.screen_to_world(Vector2(0.0, -1.0), cam.yaw_now())
		var right := Player.screen_to_world(Vector2(1.0, 0.0), cam.yaw_now())
		var side := cam.global_transform.basis.x
		near(up.dot(look), 1.0, 1e-3, "up walks where the camera looks at yaw %s" % yaw)
		near(right.dot(Vector2(side.x, side.z).normalized()), 1.0, 1e-3, "right walks to the screen's right at yaw %s" % yaw)
	_done()


## The mouse turns the view: right turns it right, and the view's own forward
## turns with it.
func test_the_mouse_turns_the_view() -> void:
	var l := Shoulder.look(45.0, Shoulder.PITCH, Vector2(100.0, 0.0))
	var before := Shoulder.forward(45.0)
	var after := Shoulder.forward(l.x)
	var right_of := Vector2(cos(deg_to_rad(45.0)), -sin(deg_to_rad(45.0)))
	gt(after.dot(right_of), before.dot(right_of) + 0.1, "moving the mouse right turns the view right")
	var up := Shoulder.look(45.0, Shoulder.PITCH, Vector2(0.0, -1000.0))
	near(up.y, Shoulder.PITCH_LEAST, 1e-4, "and it tips up only so far")
	var down := Shoulder.look(45.0, Shoulder.PITCH, Vector2(0.0, 1000.0))
	near(down.y, Shoulder.PITCH_MOST, 1e-4, "and down only so far")


## Left alone, the view eases in behind a player walking away from it, and does
## not swing for a strafe or spin for a walk back toward it.
func test_the_view_follows_a_walk_away_and_not_a_strafe() -> void:
	var yaw := 45.0
	var facing := Shoulder.aim_of(90.0)
	var away := Shoulder.forward(90.0)
	var moved := Shoulder.follow_yaw(yaw, facing, away, 5.0, 0.5)
	lt(absf(Shoulder.turn(moved, 90.0)), absf(Shoulder.turn(yaw, 90.0)), "it comes round behind")
	eq(Shoulder.follow_yaw(yaw, facing, away, 0.1, 0.5), yaw, "not while the mouse was just used")
	var strafe := Vector2(cos(deg_to_rad(45.0)), -sin(deg_to_rad(45.0)))
	near(Shoulder.follow_yaw(yaw, strafe.angle(), strafe, 5.0, 0.5), yaw, 1e-4, "not for a strafe")
	var back := -Shoulder.forward(45.0)
	near(Shoulder.follow_yaw(yaw, back.angle(), back, 5.0, 0.5), yaw, 1e-4, "and not for a walk toward it")


## A swing goes where the camera looks, whichever way the body was facing.
func test_a_swing_faces_where_the_camera_looks() -> void:
	var sim := F.make_sim()
	sim.hero.facing = 0.0
	var aim := Shoulder.aim_of(200.0)
	sim.press_swing(aim)
	F.ms(sim, 40)
	near(wrapf(sim.hero.facing - aim, -PI, PI), 0.0, 1e-3, "the swing turned to the camera's aim")
	var plain := F.make_sim()
	plain.hero.facing = 0.3
	plain.press_swing()
	F.ms(plain, 40)
	near(plain.hero.facing, 0.3, 1e-4, "and a swing with no aim keeps the body's own facing")


# --- the pointer -------------------------------------------------------------

func test_the_pointer_is_held_only_while_the_view_is_up() -> void:
	check(Shoulder.capture(true, false, false, true), "over the shoulder, playing, focused: held")
	check(not Shoulder.capture(false, false, false, true), "not over the shoulder: free")
	check(not Shoulder.capture(true, true, false, true), "a page up: free")
	check(not Shoulder.capture(true, false, true, true), "a shot or a tour: never held")
	check(not Shoulder.capture(true, false, false, false), "the window lost the player: free")


## The system's own decision, frame by frame: taken when the view comes up, given
## back the moment a page opens (the pause page is a page), taken again when it
## closes, and given back when the view is left.
func test_the_pointer_is_given_back_on_a_page_and_on_leaving() -> void:
	# Held, so letting go is leaving (the view is a press by default now).
	PlayerSettings.forget_for_test()
	PlayerSettings.set_value(&"playing.shoulder", &"hold")
	var g := await _make()
	var sys := _system(g)
	check(sys != null, "41_shoulder is loaded from src/systems")
	sys.set("focus_check", func() -> bool: return true)
	sys.set("_tool", false)
	sys.call("_process", DT)
	eq(sys.get("captured"), false, "looking down on the land the pointer is free")
	Input.action_press(&"shoulder")
	sys.call("_process", DT)
	eq(sys.get("captured"), true, "the key held: the pointer is the view's")
	g.open_screens[&"pause"] = true
	sys.call("_process", DT)
	eq(sys.get("captured"), false, "the pause page up: given back")
	g.open_screens.erase(&"pause")
	sys.call("_process", DT)
	eq(sys.get("captured"), true, "the page closed with the key still held: taken again")
	Input.action_release(&"shoulder")
	sys.call("_process", DT)
	eq(sys.get("captured"), false, "the key let go: given back")
	PlayerSettings.forget_for_test()
	_done()


## Pressed on under the toggle setting, the view survives a page opening, which
## lets go of every other latch.
func test_a_toggled_view_survives_a_page() -> void:
	PlayerSettings.forget_for_test()
	PlayerSettings.set_value(&"playing.shoulder", &"toggle")
	var g := await _make()
	var sys := _system(g)
	Input.action_press(&"shoulder")
	sys.call("_process", DT)
	Input.action_release(&"shoulder")
	await tree.process_frame
	sys.call("_process", DT)
	check(g.camera.shoulder, "pressed once, it stays on")
	g.open_screens[&"inventory"] = true
	HoldToggle.forget()
	sys.call("_process", DT)
	g.open_screens.erase(&"inventory")
	await tree.process_frame
	sys.call("_process", DT)
	check(g.camera.shoulder, "and it is still on after a page")
	PlayerSettings.forget_for_test()
	_done()


## The player's own setting opens the game over the shoulder, and the key then
## looks down on the land while it is held.
func test_opening_over_the_shoulder_turns_the_key_round() -> void:
	check(Shoulder.wanted(true, false), "opening over the shoulder: there with no key")
	check(not Shoulder.wanted(true, true), "and the key held looks down")
	check(Shoulder.wanted(false, true), "opening on the land, the key comes down")
	var g := await _make(["--view=shoulder"])
	check(g.camera.over_shoulder(), "--view=shoulder opens there with no glide")
	eq(g.camera.projection, Camera3D.PROJECTION_PERSPECTIVE, "under the lens")
	_done()


# --- never inside a solid ----------------------------------------------------

func _flat(h: float) -> Callable:
	return func(_p: Vector2) -> float: return h


func test_a_clear_line_keeps_the_whole_distance() -> void:
	var none: Array[Vector4] = []
	near(Shoulder.room(Vector3(0, 1.45, 0), Vector3(3.6, 2.0, 0), _flat(0.0), none), 1.0, 1e-6, "nothing in the way")


func test_the_eye_stops_short_of_a_hill() -> void:
	var head := Vector3(0.0, 1.45, 0.0)
	var eye := Vector3(3.6, 2.1, 0.0)
	var hill := func(p: Vector2) -> float: return 3.0 if p.x > 2.0 else 0.0
	var none: Array[Vector4] = []
	var share := Shoulder.room(head, eye, hill, none)
	lt(share, 1.0, "the hill pulls the eye in")
	var at := head.lerp(eye, share)
	lt(at.x, 2.0, "and it stands on the player's side of the hill")
	for i in 21:
		var q := head.lerp(at, float(i) / 20.0)
		gt(q.y, float(hill.call(Vector2(q.x, q.z))), "no point of the line it keeps is under the land")


func test_the_eye_stops_short_of_a_house_and_not_of_a_stone() -> void:
	var head := Vector3(0.0, 1.45, 0.0)
	var eye := Vector3(3.6, 2.1, 0.0)
	var house: Array[Vector4] = [Vector4(2.4, 0.0, 0.8, 2.8)]
	var share := Shoulder.room(head, eye, _flat(0.0), house)
	lt(head.lerp(eye, share).x, 2.4 - 0.8, "a house between: the eye stays out of its walls")
	var stone: Array[Vector4] = [Vector4(2.4, 0.0, 0.5, 0.6)]
	near(Shoulder.room(head, eye, _flat(0.0), stone), 1.0, 1e-6, "a stone lower than the line: nothing moves")


func test_the_eye_never_comes_into_the_head() -> void:
	var head := Vector3(0.0, 1.45, 0.0)
	var eye := Vector3(3.6, 2.1, 0.0)
	var wall: Array[Vector4] = [Vector4(0.4, 0.0, 0.3, 50.0)]
	var share := Shoulder.room(head, eye, _flat(0.0), wall)
	gt(head.distance_to(head.lerp(eye, share)), Shoulder.LEAST_BACK - 1e-3, "at least LEAST_BACK back")


## A POLE IS NOT A WALL. `--place=pinewood --view=shoulder --put=pipe,barricade,pole`
## stood a 0.12-wide pole 0.8 behind the player, on the line to the eye, and the
## camera came all the way in to LEAST_BACK and drew the side of the player's
## head across the whole frame. A thing narrower than `Shoulder.THIN` is seen
## past, the way a trunk is: it only moves the eye when the eye would stand in it.
func test_a_pole_on_the_line_does_not_pull_the_eye_in() -> void:
	var head := Vector3(0.0, 1.45, 0.0)
	var eye := Vector3(3.6, 2.1, 0.0)
	var pole: Array[Vector4] = [Vector4(0.8, 0.0, 0.12, 2.9)]
	near(Shoulder.room(head, eye, _flat(0.0), pole), 1.0, 1e-6, "a pole across the line: the eye keeps its distance")
	var trunk: Array[Vector4] = [Vector4(2.0, 0.0, 0.3, 9.0)]
	near(Shoulder.room(head, eye, _flat(0.0), trunk), 1.0, 1e-6, "a pine's trunk across the line: the same")


func test_an_eye_that_would_stand_in_a_pole_stops_in_front_of_it() -> void:
	var head := Vector3(0.0, 1.45, 0.0)
	var eye := Vector3(3.6, 2.1, 0.0)
	var pole: Array[Vector4] = [Vector4(3.6, 0.0, 0.12, 2.9)]
	var at := head.lerp(eye, Shoulder.room(head, eye, _flat(0.0), pole))
	lt(at.x, 3.6 - 0.12, "the eye stands on the player's side of the pole")
	gt(at.x, 2.5, "and no nearer than the pole asks")


## THE PLAYER'S HEAD IS NEVER THE PICTURE. However hard the eye is pulled in,
## it comes in along the line it looks down, toward the point over the right
## shoulder, so the head stays beside the middle of the frame and never fills it.
## Asked of the live camera with every step of the line refused.
func test_a_pulled_in_eye_looks_past_the_head() -> void:
	var g := await _make()
	var cam := g.camera
	cam.shoulder = true
	# Every step of the line behind is refused; the short leg from the head to
	# the shoulder point (under a unit) is clear, as it is beside any wall behind.
	cam.sight_room = func(a: Vector3, b: Vector3) -> float: return 1.0 if a.distance_to(b) < 1.0 else 0.0
	_step(cam, 40)
	var d := PersonBody.dims(&"man")
	var feet := cam.get("_smoothed") as Vector3
	var skull := feet + Vector3(0.0, float(d.hip_y) + float(d.torso) + float(d.head) * 0.5, 0.0)
	var r := float(d.head) * 0.5
	var dist := cam.global_position.distance_to(skull)
	gt(dist, r * 2.0, "the eye is well outside the skull")
	# The head's height as a share of the frame's.
	var share := (2.0 * r / dist) / (2.0 * tan(deg_to_rad(cam.fov * 0.5)))
	lt(share, 0.35, "the head is a third of the frame at most (%.2f)" % share)
	var ahead := -cam.global_transform.basis.z
	var to := skull - cam.global_position
	var off := (to - ahead * to.dot(ahead)).length()
	gt(off, r * 1.2, "the middle of the frame looks past the head, not through it")
	_done()


## The rig stands the eye where the room says: asked in a running game with a
## wall put across the line, of the live camera.
func test_the_rig_stands_where_the_room_allows() -> void:
	var g := await _make()
	var cam := g.camera
	cam.shoulder = true
	cam.sight_room = func(_h: Vector3, _e: Vector3) -> float: return 1.0
	_step(cam, 40)
	var head := cam.get("_smoothed") as Vector3 + Vector3(0.0, Shoulder.HEAD_UP, 0.0)
	var full := cam.global_position.distance_to(head)
	cam.sight_room = func(_h: Vector3, _e: Vector3) -> float: return 0.3
	cam._process(DT)
	near(cam.global_position.distance_to(head), full * 0.3, 0.05, "pulled in at once, the same frame")
	cam.sight_room = func(_h: Vector3, _e: Vector3) -> float: return 1.0
	cam._process(DT)
	lt(cam.global_position.distance_to(head), full * 0.5, "and let back out gently, not snapped")
	_done()


# --- the web's near blur -------------------------------------------------------

## THE WEB'S NEAR BLUR IS THE ORTHOGRAPHIC FRAME'S AND NOBODY ELSE'S. It is a
## plane in the rig's shaft pass worked out from the flat frame's depth (about
## 25 units), and the pass draws over whatever camera is current: under the lens
## and over the shoulder it blurred everything within 25 units of the eye, and
## under 96_eye's stand the same. Asked of the pass's own uniform.
func test_the_web_near_blur_stands_down_under_the_lens() -> void:
	Quality._now = &"web"
	var g := await _make()
	var cam := g.camera
	cam.sight_room = Callable()
	var pass_ := cam.get_node_or_null("shaft_pass") as MeshInstance3D
	check(pass_ != null, "the web tier runs the shaft pass")
	if pass_ == null:
		Quality._now = &""
		_done()
		return
	var m := pass_.material_override as ShaderMaterial
	_step(cam, 10)
	gt(float(m.get_shader_parameter("near_begin")), 0.0, "from above, the near blur is on")
	cam.shoulder = true
	_step(cam, 40)
	lt(float(m.get_shader_parameter("near_begin")), 0.0, "over the shoulder it is off")
	cam.shoulder = false
	_step(cam, 40)
	gt(float(m.get_shader_parameter("near_begin")), 0.0, "and back on from above")
	var other := Camera3D.new()
	g.add_child(other)
	other.make_current()
	_step(cam, 2)
	lt(float(m.get_shader_parameter("near_begin")), 0.0, "and off while another camera draws")
	other.queue_free()
	Quality._now = &""
	_done()


# --- breath in the cold ----------------------------------------------------------

## The breath put out since the last count, freed as counted: marks (from
## above) and soft air on the fire's own puff mesh (under the close eye).
## `air` collects, per puff, whether it is depth-tested air.
func _breaths(g: Game, air: Array = []) -> int:
	var n := 0
	for c: Node in g.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.is_queued_for_deletion():
			continue
		var is_air := mi.mesh == FireModel.smoke_mesh()
		var is_mark := false
		if mi.material_override is ShaderMaterial:
			var mode: Variant = (mi.material_override as ShaderMaterial).get_shader_parameter(&"mode")
			is_mark = mode != null and int(mode) == MobFx.VAPOUR
		if not (is_air or is_mark):
			continue
		var m := mi.material_override as StandardMaterial3D
		air.append(is_air and m != null and not m.no_depth_test)
		n += 1
		mi.queue_free()
	return n


## UNDER THE CLOSE EYE BREATH IS AIR, NOT A MARK. A mark draws over everything:
## from behind at eye level the puff in front of the mouth landed on the back of
## the head, and near the lens it was a white speckled cloud beside it. So over
## the shoulder it is the fire's soft puff, depth-tested, drawn from every side
## -- the head hides it the way a head would -- and never held to a frame-pixel
## floor. From above it is the reviewed mark, as ever.
func test_breath_is_depth_tested_air_at_every_angle() -> void:
	var g := await _make()
	var cam := g.camera
	cam.sight_room = Callable()
	var hz: Node = null
	for s in g.systems:
		if s.name == "52_hazards":
			hz = s
	check(hz != null, "the hazards system runs")
	var cue := HazardCues.cue(&"cold")
	_breaths(g)
	var from_above: Array = []
	hz.call("_draw_cue", &"cold", cue, 0.7)
	eq(_breaths(g, from_above), 2, "from above, two puffs")
	check(not from_above.has(true), "and from above they are the reviewed marks")
	var depth: Array = []
	cam.shoulder = true
	cam.snap_view()
	cam.shoulder_yaw = Shoulder.yaw_behind(g.player.facing)
	_step(cam, 2)
	check(MobFx.close_eye(g), "over the shoulder the eye is close")
	hz.call("_draw_cue", &"cold", cue, 0.7)
	eq(_breaths(g, depth), 2, "from behind the head, two puffs, which the head hides")
	for d: bool in depth:
		check(d, "every puff over the shoulder is depth-tested air, so it never draws over the head")
	# Under the close eye a puff keeps its own size, not the frame's floor.
	MobFx.breath(g, g.player.global_position + Vector3.UP, Color.WHITE, 0.2, 1.0, Vector2.ZERO, 1)
	var big := 0.0
	for c: Node in g.get_children():
		var mi := c as MeshInstance3D
		if mi != null and mi.mesh == FireModel.smoke_mesh() and not mi.is_queued_for_deletion():
			big = maxf(big, mi.scale.x)
	lt(big, 0.2, "a 0.2 puff under the close eye starts under 0.2 across, not the floor's %.2f" % (MobFx.VAPOUR_PX * MobFx.texel))
	_breaths(g)
	_done()


# --- the right button ------------------------------------------------------------

func _right(down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


## THE RIGHT BUTTON IS A PEEK (owner, 2026-09-24): the view is up while it is
## held and lands back wherever the key left it, in every order the two can be
## pressed. The view's own key is a press by default in every scheme.
func _peek_game() -> Array:
	PlayerSettings.forget_for_test()
	PlayerSettings.set_value(PlayerSettings.SCHEME, ControlScheme.MOUSE)
	var g := await _make()
	return [g, _system(g)]


func _toggle_key(sys: Node) -> void:
	Input.action_press(&"shoulder")
	sys.call("_process", DT)
	Input.action_release(&"shoulder")
	await tree.process_frame
	sys.call("_process", DT)


func test_the_view_is_a_press_by_default() -> void:
	PlayerSettings.forget_for_test()
	eq(PlayerSettings.value(&"playing.shoulder"), &"toggle", "pressed once, not held")
	PlayerSettings.forget_for_test()


func test_the_right_button_peeks_and_lands_back_down() -> void:
	var made: Array = await _peek_game()
	var g: Game = made[0]
	var sys: Node = made[1]
	_right(true)
	check(Input.is_action_pressed(&"shoulder_peek"), "the right button says `shoulder_peek`")
	check(not Input.is_action_pressed(&"shoulder"), "and not the view's own key")
	sys.call("_process", DT)
	check(g.camera.shoulder, "held, the view is up")
	_right(false)
	await tree.process_frame
	sys.call("_process", DT)
	check(not g.camera.shoulder, "let go, it is back on the land")
	PlayerSettings.forget_for_test()
	_done()


## LOOKING UP AT A COLOSSUS, THE PLAYER GETS OUT OF THE WAY. Tipped past the
## ordinary limit the orbit would carry the eye under the body and fill the
## frame with the back of the head; instead the eye comes to the face and the
## figure is stippled away by the same share. Measured on the picture: at the
## gaze's full tip no part of the body projects inside the frame, and the share
## handed to the shaders is whole; at the ordinary pitch it is nothing.
func test_looking_up_the_body_leaves_the_frame() -> void:
	var g := await _make()
	var cam := g.camera
	cam.sight_room = Callable()
	cam.shoulder = true
	_step(cam, 40)
	near(cam.yield_share, 0.0, 1e-6, "at the ordinary pitch the body is whole")
	cam.shoulder_pitch = Shoulder.GAZE_LEAST
	_step(cam, 3)
	near(cam.yield_share, 1.0, 1e-4, "tipped all the way up it is gone")
	var rect := cam.get_viewport().get_visible_rect()
	var feet := g.player.position
	var seen := 0
	for y: float in [0.1, 0.5, 0.9, 1.2, 1.45]:
		for side: float in [-0.25, 0.0, 0.25]:
			var p := feet + Vector3(side, y, side)
			if cam.is_position_behind(p):
				continue
			if rect.has_point(cam.unproject_position(p)):
				seen += 1
	eq(seen, 0, "no point of the body below the head is on the glass")
	for pitch: float in [Shoulder.PITCH_LEAST - 2.0, -22.0, Shoulder.YIELD_FULL]:
		cam.shoulder_pitch = pitch
		_step(cam, 2)
		var w := cam.yield_share
		near(w, Shoulder.rise(pitch), 1e-4, "the stipple follows the eye at %.0f" % pitch)
	_done()


## A COLOSSUS LANDING IS FELT BY WHICHEVER CAMERA IS DRAWING: the quake sways
## the staged eye (`--eye`, 96_eye) as it does the rig. Measured on the eye
## itself: its position with a quake running is not its position without one,
## by about the quake's own size, and it comes back when the quake is spent.
func test_a_quake_reaches_the_staged_eye() -> void:
	var g := await _make(["--eye=1.7,5"])
	var eye_sys: Node = null
	for s in g.systems:
		if s.name == "96_eye":
			eye_sys = s
	check(eye_sys != null, "the stand is loaded")
	g.systems.map(func(s: Node) -> void: if s.has_method(&"started"): s.started())
	var cam := _drawing_camera(g)
	check(cam != null and cam != g.camera, "the stand is the camera drawing")
	eye_sys._process(DT)
	var still := cam.global_position
	g.camera.quake(0.35, 2.5, 1.0)
	var most := 0.0
	for i in 60:
		g.camera._process(DT)
		eye_sys._process(DT)
		most = maxf(most, cam.global_position.distance_to(still))
	gt(most, 0.1, "the eye sways (%.3f)" % most)
	lt(most, 1.0, "by about the quake's size")
	for i in 200:
		g.camera._process(DT)
	eye_sys._process(DT)
	lt(cam.global_position.distance_to(still), 1e-3, "and stands still again")
	_done()


func _drawing_camera(g: Game) -> Camera3D:
	return g.get_viewport().get_camera_3d()


func test_a_peek_over_a_view_already_up_leaves_it_up() -> void:
	var made: Array = await _peek_game()
	var g: Game = made[0]
	var sys: Node = made[1]
	await _toggle_key(sys)
	check(g.camera.shoulder, "pressed on")
	_right(true)
	await tree.process_frame
	sys.call("_process", DT)
	_right(false)
	await tree.process_frame
	sys.call("_process", DT)
	check(g.camera.shoulder, "a peek and back: still up, because the key put it there")
	PlayerSettings.forget_for_test()
	_done()


func test_the_key_pressed_during_a_peek_keeps_the_view_after_it() -> void:
	var made: Array = await _peek_game()
	var g: Game = made[0]
	var sys: Node = made[1]
	_right(true)
	sys.call("_process", DT)
	await _toggle_key(sys)
	_right(false)
	await tree.process_frame
	sys.call("_process", DT)
	check(g.camera.shoulder, "the key pressed while peeking: the view stays once the button is up")
	PlayerSettings.forget_for_test()
	_done()


## THE ARROWS ARE THE KEYBOARD'S LOOK (C6): over the shoulder they turn the view;
## under a lock they may tip it but the turn is the lock's.
func test_the_arrows_turn_the_view_and_a_lock_keeps_the_turn() -> void:
	var made: Array = await _peek_game()
	var g: Game = made[0]
	var sys: Node = made[1]
	await _toggle_key(sys)
	var cam := g.camera
	var yaw := cam.shoulder_yaw
	var pitch := cam.shoulder_pitch
	Input.action_press(&"look_right")
	Input.action_press(&"look_up")
	for i in 20:
		sys.call("_process", DT)
	Input.action_release(&"look_right")
	Input.action_release(&"look_up")
	lt(cam.shoulder_yaw, yaw - 10.0, "right turns the view right (%.1f from %.1f)" % [cam.shoulder_yaw, yaw])
	lt(cam.shoulder_pitch, pitch - 10.0, "up tips it up (%.1f from %.1f)" % [cam.shoulder_pitch, pitch])
	cam.subject = Vector3(g.player.position.x + 5.0, 0.0, g.player.position.z)
	yaw = cam.shoulder_yaw
	Input.action_press(&"look_right")
	for i in 20:
		sys.call("_process", DT)
	Input.action_release(&"look_right")
	eq(cam.shoulder_yaw, yaw, "under a lock the arrows do not fight it for the turn")
	cam.subject = Vector3.INF
	PlayerSettings.forget_for_test()
	_done()


## A BROWSER TAKES THE POINTER BACK ON ESC, and the engine never hears the key:
## over the shoulder the first Esc did nothing. Once the lock was seen held, a
## pointer handed back is the pause the player asked for.
func test_the_browser_giving_the_pointer_back_pauses() -> void:
	var made: Array = await _peek_game()
	var g: Game = made[0]
	var sys: Node = made[1]
	var held := [false]
	sys.set("focus_check", func() -> bool: return true)
	sys.set("web_check", func() -> bool: return true)
	sys.set("mode_check", func() -> bool: return held[0])
	sys.set("_tool", false)
	await _toggle_key(sys)
	eq(sys.get("captured"), true, "the view up: the pointer is asked for")
	sys.call("_process", DT)
	check(not g.open_screens.has(&"pause"), "asked for and not yet granted is not a release")
	held[0] = true
	sys.call("_process", DT)
	check(not g.open_screens.has(&"pause"), "held: nothing to answer")
	held[0] = false
	sys.call("_process", DT)
	check(g.open_screens.has(&"pause"), "handed back by the browser: the pause page is up")
	eq(sys.get("captured"), false, "and the pointer is the player's")
	PlayerSettings.forget_for_test()
	_done()


func test_a_desktop_keeps_its_capture_through_esc() -> void:
	var made: Array = await _peek_game()
	var g: Game = made[0]
	var sys: Node = made[1]
	sys.set("focus_check", func() -> bool: return true)
	sys.set("web_check", func() -> bool: return false)
	sys.set("mode_check", func() -> bool: return false)
	sys.set("_tool", false)
	await _toggle_key(sys)
	for i in 3:
		sys.call("_process", DT)
	check(not g.open_screens.has(&"pause"), "off the web nothing takes the pointer, so nothing pauses")
	PlayerSettings.forget_for_test()
	_done()


func _key(code: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


## The arrows walk from above -- and every page of the slate is steered by the
## walk -- and over the shoulder they turn the view instead of walking (C6).
func test_over_the_shoulder_the_arrows_look_and_do_not_walk() -> void:
	var made: Array = await _peek_game()
	var g: Game = made[0]
	var sys: Node = made[1]
	_key(KEY_RIGHT, true)
	g._physics_process(DT)
	gt(g.player.intent_move.length(), 0.5, "from above the arrow walks")
	_key(KEY_RIGHT, false)
	await _toggle_key(sys)
	check(g.camera.shoulder, "over the shoulder")
	_key(KEY_RIGHT, true)
	g._physics_process(DT)
	lt(g.player.intent_move.length(), 0.01, "there the arrow does not walk")
	_key(KEY_RIGHT, false)
	_key(KEY_D, true)
	g._physics_process(DT)
	gt(g.player.intent_move.length(), 0.5, "and D still does")
	_key(KEY_D, false)
	PlayerSettings.forget_for_test()
	_done()


# --- people on the line to a lock ------------------------------------------------

func test_a_person_counts_only_between_the_eye_and_the_lock() -> void:
	var eye := Vector2(0.0, 0.0)
	var target := Vector2(6.0, 0.0)
	var on: Array[Vector2] = [Vector2(3.0, 0.3)]
	check(Shoulder.in_line(eye, target, on), "half way along and a body's width off: on the line")
	var beside: Array[Vector2] = [Vector2(3.0, 1.2)]
	check(not Shoulder.in_line(eye, target, beside), "a stride to the side is not")
	var behind: Array[Vector2] = [Vector2(-1.0, 0.0)]
	check(not Shoulder.in_line(eye, target, behind), "behind the eye is not")
	var past: Array[Vector2] = [Vector2(6.5, 0.0)]
	check(not Shoulder.in_line(eye, target, past), "and neither is standing at or past the lock")


## A villager walks between the eye and a locked body: the eye rises over them,
## the lock stays where it was in the frame, and no frame jumps on the way.
func test_the_eye_rises_over_a_person_on_the_line_and_the_lock_holds() -> void:
	var g := await _make(["--view=shoulder", "--folk=1"])
	var sys := _system(g)
	var cam := g.camera
	var folk: Node = sys.call("_folk")
	check(folk != null and not (folk.get("folk") as Array).is_empty(), "a villager to stand on the line")
	# The village's own people as well as the one booted: all indoors but one,
	# and that one off the line first, so the view is a lock alone.
	for r: Dictionary in folk.get("folk"):
		r["state"] = &"in"
	_step(cam, 30)
	var ahead := Shoulder.forward(cam.shoulder_yaw)
	var here := g.player.position
	cam.subject = here + Vector3(ahead.x, 0.0, ahead.y) * 5.0
	var row: Dictionary = (folk.get("folk") as Array)[0]
	row["pos"] = Vector2(here.x, here.z) + Vector2(-ahead.y, ahead.x) * 6.0
	row["state"] = &"out"
	for i in 150:
		sys.call("_process", DT)
		cam._process(DT)
	var clear_y := cam.global_position.y
	near(cam.clear_tip(), 0.0, 0.05, "nobody on the line: no tip")
	# Now half way along the line from the eye to the lock.
	var eye := Vector2(cam.global_position.x, cam.global_position.z)
	row["pos"] = eye.lerp(Vector2(cam.subject.x, cam.subject.z), 0.45)
	var last := cam.global_position
	var biggest := 0.0
	for i in 90:
		sys.call("_process", DT)
		cam._process(DT)
		biggest = maxf(biggest, cam.global_position.distance_to(last))
		last = cam.global_position
	gt(cam.clear_tip(), Shoulder.CLEAR_TIP * 0.9, "the view has tipped to look over them")
	gt(cam.global_position.y, clear_y + 0.6, "and the eye stands higher (%.2f from %.2f)" % [cam.global_position.y, clear_y])
	lt(biggest, 0.12, "eased, never a jump (largest step %.3f)" % biggest)
	check(bool(sys.call("tour_seen", &"shoulder_locked")), "and the lock is still framed")
	cam.subject = Vector3.INF
	_done()


# --- the spring arm's margin -------------------------------------------------------

## A solid is probed by the box its model is DRAWN in, turned as the chunk bakes
## it (`Basis(UP, -rot).scaled(scale)`). Asked at many points and turns against
## that transform itself, so a wrong sign on the turn cannot pass.
func test_a_drawn_box_is_turned_as_the_chunk_turns_the_model() -> void:
	var lo := Vector2(-0.3, -1.2)
	var hi := Vector2(0.4, 0.9)
	var centre := Vector2(5.0, 7.0)
	var scale := 1.3
	var wrong := 0
	var inside := 0
	for rot: float in [0.0, 0.6, -1.1, 2.4, PI]:
		var box := Shoulder.box_of(centre, rot, scale, lo, hi, 4.0)
		var b := Basis(Vector3.UP, -rot).scaled(Vector3.ONE * scale)
		for i in 400:
			var p := centre + Vector2(fmod(i * 0.37, 4.0) - 2.0, fmod(i * 0.61, 4.0) - 2.0)
			var local := b.inverse() * Vector3(p.x - centre.x, 0.0, p.y - centre.y)
			var m := Shoulder.CLEAR / scale
			var want := local.x > lo.x - m and local.x < hi.x + m and local.z > lo.y - m and local.z < hi.y + m
			var got := Shoulder._in_box(Vector3(p.x, 1.0, p.y), box, Shoulder.CLEAR)
			# The margin is CLEAR in the world, so it is CLEAR / scale in the model:
			# compare away from the rim, where the two may round differently.
			var rim := absf(local.x - lo.x) < 0.05 or absf(local.x - hi.x) < 0.05 \
				or absf(local.z - lo.y) < 0.05 or absf(local.z - hi.y) < 0.05
			if rim:
				continue
			if want != got:
				wrong += 1
			if got:
				inside += 1
	eq(wrong, 0, "every point agrees with the model's own transform")
	gt(float(inside), 50.0, "and the test asked plenty of points inside (%d)" % inside)


## A house drawn wider than the circle a body walks round: the eye would stand in
## its drawn corner, clear of the circle and its margin, and only what is drawn
## pulls it in.
func test_the_eye_is_kept_out_of_a_drawn_corner_the_walking_circle_misses() -> void:
	var low := func(_p: Vector2) -> float: return 0.0
	var head := Vector3(0.0, 1.8, 0.0)
	var eye := Vector3(2.6, 1.8, -0.3)
	# Drawn from x 1.1 to 2.9 and z -2.1 to -0.1: the eye stands just inside it.
	var house := Shoulder.box_of(Vector2(2.0, -1.1), 0.0, 1.0, Vector2(-0.9, -1.0), Vector2(0.9, 1.0), 3.0)
	var circle: Array[Vector4] = [Vector4(2.0, -1.1, 0.5, 3.0)]
	eq(Shoulder.room(head, eye, low, circle), 1.0, "its walking circle alone lets the eye stand in the corner")
	lt(Shoulder.room(head, eye, low, [] as Array[Vector4], [house] as Array[PackedFloat32Array]), 0.9,
		"what is drawn keeps it out")


## A line that starts beside a wall and heads away from it passes through
## nothing: a player standing under a house's eave keeps the whole view, where
## a margin asked all along the line pulled the eye into his head.
func test_a_line_leaving_a_wall_is_not_pulled_in() -> void:
	var low := func(_p: Vector2) -> float: return 0.0
	var house := Shoulder.box_of(Vector2(0.0, -1.05), 0.0, 1.0, Vector2(-2.0, -1.0), Vector2(2.0, 1.0), 3.0)
	# Drawn to z -0.05, just behind the shoulder, as an eave overhangs a player
	# standing under it: the walk's first steps are inside the margin. The eye is
	# 4 tiles out and away.
	var head := Vector3(0.0, 1.8, 0.0)
	var eye := Vector3(0.0, 2.2, 4.0)
	eq(Shoulder.room(head, eye, low, [] as Array[Vector4], [house] as Array[PackedFloat32Array]), 1.0,
		"the whole distance, the wall at its back")


## The probe is as wide as the near plane: a terrace riser a tenth of a tile
## beside the line, higher than the eye, stops it, where the line alone passed.
func test_a_riser_beside_the_line_stops_the_eye() -> void:
	var riser := func(p: Vector2) -> float: return 4.0 if p.y < -0.1 else 0.0
	var head := Vector3(0.0, 1.8, 0.0)
	var eye := Vector3(4.0, 1.8, 0.0)
	lt(Shoulder.room(head, eye, riser, [] as Array[Vector4]), 0.9, "the riser the near plane would slice stops it")
	var away := func(p: Vector2) -> float: return 4.0 if p.y < -0.5 else 0.0
	eq(Shoulder.room(head, eye, away, [] as Array[Vector4]), 1.0, "one half a tile off is left alone")


## THE PROBE RUNS EVERY FRAME. Among a village's houses, the two walks the rig
## makes a frame (head to shoulder, shoulder to eye) cost well under 0.2 ms at the
## worst of eight bearings, measured as the cheapest of repeated runs.
func test_the_probe_is_cheap_among_houses() -> void:
	var g := await _make(["--village=0", "--view=shoulder"])
	var sys := _system(g)
	var head := g.player.position + Vector3(0.0, Shoulder.HEAD_UP, 0.0)
	var worst := 0.0
	var boxes := 0
	for k in 8:
		var yaw := k * 45.0
		var back := Shoulder.forward(yaw) * -Shoulder.BACK
		var right := Vector2(cos(deg_to_rad(yaw)), -sin(deg_to_rad(yaw))) * Shoulder.RIGHT
		var focus := head + Vector3(right.x, 0.0, right.y)
		var eye := focus + Vector3(back.x, 0.6, back.y)
		var us := TestCase.best_of(30, func() -> void:
			sys.call("room", head, focus)
			sys.call("room", focus, eye))
		worst = maxf(worst, us)
		boxes = maxi(boxes, (sys.get("_boxes") as Array).size())
	print("probe: worst of 8 bearings %.1f us a frame, %d drawn boxes in reach" % [worst, boxes])
	gt(float(boxes), 0.0, "the village's buildings were in the probe (%d)" % boxes)
	cost_lt(worst, 100.0, "two probe walks a frame among houses (us)")
	_done()


## The probe asks the drawn ground nothing above a ceiling worked out from the
## tile levels. If the drawn surface ever rose past that ceiling, the eye would
## stand in a hill with nothing noticing, so it is held across a whole island:
## every tile, at points across it, against the ceiling for that very point.
func test_the_ground_ceiling_is_never_under_the_drawn_ground() -> void:
	var g := await _make(["--seed=4", "--size=64"])
	var sys := _system(g)
	var over := 0
	var worst := -INF
	var n := 0
	for ty in range(0, 64):
		for tx in range(0, 64):
			for k in 3:
				var p := Vector2(tx + 0.17 + 0.31 * k, ty + 0.83 - 0.29 * k)
				var h := g.view.surface_height(p)
				var q := Vector3(p.x, h, p.y)
				var top := float(sys.call("_ground_top", q, q))
				worst = maxf(worst, h - top)
				n += 1
				if h > top:
					over += 1
	eq(over, 0, "no drawn ground stands over its ceiling (%d points, closest %.3f under)" % [n, -worst])
	_done()


## A plain wall, corners only at its foot and its top, stands in EVERY slice
## between: sliced by vertex the middle ones were empty and the eye could stand
## inside it. Two triangles, 2.5 high, in slices of 0.5.
func test_a_tall_face_fills_every_slice_it_crosses() -> void:
	var wall := PackedVector3Array([
		Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(1.0, 2.5, 0.0),
		Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 2.5, 0.0), Vector3(-1.0, 2.5, 0.0)])
	var s := Shoulder.slices_of(wall, 2.5, 0.5)
	eq(s.size() / 4, 5, "five slices up a wall 2.5 high")
	for j in s.size() / 4:
		near(s[j * 4], -1.0, 1e-5, "slice %d reaches the wall's left end" % j)
		near(s[j * 4 + 2], 1.0, 1e-5, "and its right end")


## Sight past what is drawn (a fresh lock): through a house or under a hill it is
## not seen; with nothing between, or a line that only passes NEAR a wall, it is.
func test_sight_is_stopped_by_what_is_drawn_and_by_the_ground() -> void:
	var flat := func(_p: Vector2) -> float: return 0.0
	var a := Vector3(0.0, 1.45, 0.0)
	var b := Vector3(8.0, 0.6, 0.0)
	var none: Array[PackedFloat32Array] = []
	check(Shoulder.sees(a, b, flat, none), "nothing between: seen")
	var house := Shoulder.box_of(Vector2(4.0, 0.0), 0.3, 1.0, Vector2(-1.0, -1.0), Vector2(1.0, 1.0), 3.0)
	check(not Shoulder.sees(a, b, flat, [house] as Array[PackedFloat32Array]), "a house between: not seen")
	var aside := Shoulder.box_of(Vector2(4.0, 1.25), 0.0, 1.0, Vector2(-1.0, -1.0), Vector2(1.0, 1.0), 3.0)
	check(Shoulder.sees(a, b, flat, [aside] as Array[PackedFloat32Array]), "a wall a quarter tile off the line: seen")
	var hill := func(p: Vector2) -> float: return 2.0 if p.x > 3.0 and p.x < 5.0 else 0.0
	check(not Shoulder.sees(a, b, hill, none), "a rise between: not seen")
