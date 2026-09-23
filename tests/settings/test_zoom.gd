extends TestCase
## The player's own zoom (owner, 2026-09-19: "it shouldnt have to be dev mode,
## just in normal play a user can press + or - to zoom in and out").
##
## The thing worth a test here is the SEAM, not the arithmetic: `picture.zoom`'s
## default is a bare `0.24` in `PlayerSettings.ROWS`, and what it MEANS is
## `09_view.level_of(CameraRig.VIEW_HEIGHT)`. ROWS is a const so it cannot call
## that, and a system's file name cannot be a `class_name` so nothing can call it
## through one either — which is exactly the shape that drifts. This asks the
## real function.

const VIEW := preload("res://src/systems/09_view.gd")


func test_the_setting_opens_the_camera_where_the_play_camera_has_always_been() -> void:
	var want: float = VIEW.level_of(CameraRig.VIEW_HEIGHT)
	near(float(PlayerSettings.default_of(&"picture.zoom")), want, 0.005,
		"picture.zoom's default is level_of(VIEW_HEIGHT) — if you moved CLOSE, FAR or VIEW_HEIGHT, move it too")
	# And round trip, or the level and the height are two scales.
	near(VIEW.height_of(want), CameraRig.VIEW_HEIGHT, 0.001, "and it maps back")


func test_the_range_holds_the_play_camera_and_is_a_readable_one() -> void:
	gt(CameraRig.VIEW_HEIGHT, VIEW.CLOSE, "the play height is inside the range")
	lt(CameraRig.VIEW_HEIGHT, VIEW.FAR, "the play height is inside the range")
	# The far end is a READABILITY bound now that the coarse world means pulling
	# back costs no building. A person is about a tile; at FAR the frame is this
	# many tiles across, and past about seventy they stop being people.
	var across := VIEW.FAR * (16.0 / 9.0)
	lt(across, 70.0, "at the far end a body is still a body (%.0f tiles across)" % across)
	gt(across, 40.0, "and far enough out to be worth the key")


func test_the_level_is_clamped_at_both_ends_so_a_held_key_cannot_run_away() -> void:
	eq(VIEW.level_of(-100.0), 0.0)
	eq(VIEW.level_of(1e9), 1.0)
	near(VIEW.height_of(0.0), VIEW.CLOSE, 0.001)
	near(VIEW.height_of(1.0), VIEW.FAR, 0.001)


## Two systems read `+` and `-`. The flyover answers `owns_zoom()` while it is
## flying and the play zoom stands down for anything that does — asked as a
## capability, so the next thing that takes the camera is covered without this
## file knowing it exists.
func test_only_one_thing_owns_the_zoom_keys_at_a_time() -> void:
	var src := FileAccess.get_file_as_string("res://src/systems/09_view.gd")
	check(src.contains('has_method(&"owns_zoom")'),
		"the play zoom stands down for whoever owns the camera")
	var fly := FileAccess.get_file_as_string("res://src/systems/95_flyover.gd")
	check(fly.contains("func owns_zoom() -> bool:"), "and the flyover answers it")
	check(fly.contains("return flying"), "with whether it is actually up")


## A key may only do one thing (PlayerSettings), and these are a player's keys
## now rather than dev mode's, so they have to be on the keys page to rebind.
func test_the_keys_are_the_players_and_are_rebindable() -> void:
	var on_page := false
	for r: Dictionary in PlayerSettings.BINDABLE:
		if r.action == &"zoom_in":
			on_page = true
	check(on_page, "zoom_in is on the keys page")
	check(InputMap.has_action(&"zoom_in") and InputMap.has_action(&"zoom_out"),
		"and both actions ship in the InputMap, not built at runtime by dev mode")


## The shadow range used to be 50.0 set once at `_ready`, so past about
## view_height 62 the far edge of the frame stopped casting — which a
## player-facing zoom walks straight into.
func test_the_suns_shadow_range_follows_the_camera() -> void:
	var src := FileAccess.get_file_as_string("res://src/render/sky_light.gd")
	check(src.contains("sun.directional_shadow_max_distance = _cam_distance()"),
		"the shadow range is derived from the live camera, not written once")
	# At the play camera it must still be what the constant said, or every canon
	# frame moves for a reason nobody asked for.
	var at_play: float = 30.0 + Air.frame_depth(CameraRig.VIEW_HEIGHT, CameraRig.PITCH_DEG) + SkyLight.SHADOW_ROOM
	near(at_play, 50.0, 0.3, "and at the play camera it is still about fifty")
	# And it really does grow, or the derivation is decoration.
	var far_out: float = 30.0 + Air.frame_depth(VIEW.FAR, CameraRig.PITCH_DEG) + SkyLight.SHADOW_ROOM
	gt(far_out, at_play + 5.0, "zoomed out, the split reaches further")


## A TOOL RUN OPENS AT THE SHIPPED ZOOM AND WRITES NOTHING BACK, and a player's
## zoom still persists. A tour's `zoom 9` used to be saved to the tool settings
## file like a player's own keys, so the next shot or tour opened there -- and
## `user://` is per PROJECT, so every session's tours leaked into every other's
## pictures, the canon's frames 1-17 included.
func _view_game(tool: bool) -> Array:
	var g := Game.new()
	g.options = BootOptions.new()
	if tool:
		g.options.tour = "tours/canon.tour"
	g.camera = CameraRig.new()
	var v: GameSystem = VIEW.new()
	v.setup(g)
	return [g, v]


func _zoom_in_and_let_go(v: GameSystem) -> void:
	v.call(&"set_height", VIEW.CLOSE)
	for i in 30:
		v.call(&"_process", 0.1)


func test_a_tool_run_opens_at_the_shipped_zoom_and_writes_nothing() -> void:
	var was: Variant = PlayerSettings.value(&"picture.zoom")
	PlayerSettings.set_value(&"picture.zoom", 0.6)
	var gv := _view_game(true)
	var g: Game = gv[0]
	near(g.camera.view_height, VIEW.height_of(float(PlayerSettings.default_of(&"picture.zoom"))), 0.001,
		"a tour opens at the shipped zoom, not at what the settings file holds")
	_zoom_in_and_let_go(gv[1])
	near(float(PlayerSettings.value(&"picture.zoom")), 0.6, 0.001, "and a tour's own zoom is never written back")
	(gv[1] as Node).free()
	g.camera.free()
	g.free()
	PlayerSettings.set_value(&"picture.zoom", was)


func test_a_players_zoom_still_persists() -> void:
	var was: Variant = PlayerSettings.value(&"picture.zoom")
	PlayerSettings.set_value(&"picture.zoom", 0.6)
	var gv := _view_game(false)
	var g: Game = gv[0]
	near(g.camera.view_height, VIEW.height_of(0.6), 0.001, "a player's game opens where they left it")
	_zoom_in_and_let_go(gv[1])
	near(float(PlayerSettings.value(&"picture.zoom")), 0.0, 0.001, "and where they zoom to is kept")
	(gv[1] as Node).free()
	g.camera.free()
	g.free()
	PlayerSettings.set_value(&"picture.zoom", was)
