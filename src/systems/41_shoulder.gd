extends GameSystem
## THE VIEW OVER THE SHOULDER (owner, 2026-09-23: "Should be able to switch to
## true third person perspective (see from behind the players shoulder) ... It
## should be seamless just like targeting ... a key that player has to hold down
## along with a perfectly integrated setting. Should be able to see parts of the
## sky and the horizon.")
##
##   hold L, or the right mouse button   the camera glides down off its perch to
##                                       behind the player's right shoulder
##   the mouse                           turns it, and tips it up to the sky
##   walk away from it                   it eases in behind you when the mouse
##                                       has been left alone
##   hold Z as well                      the lock turns the view onto the body
##   let go                              it glides back up to the land
##
## `playing.shoulder` makes the key a press instead of a hold, and `playing.view`
## opens the game over the shoulder, which turns the key round: held, it looks
## down on the land. `--view=` beats the setting for one run.
##
## This file decides WHEN and WHICH WAY; the rig draws it (`CameraRig`, the
## `shoulder` fields) and the numbers are `Shoulder`'s. It also holds the pointer
## while the view is up, and gives it back the moment a page opens, a
## conversation starts, the window loses the player, or the view is left -- and
## never takes it at all in a shot or a tour, which must not take the mouse from
## whoever is sitting at the machine.

const Shoulder := preload("res://src/core/view/shoulder.gd")
const ACTION := &"shoulder"
const SETTING := &"playing.shoulder"
## The zoom keys move the eye in and out along the view while it is up, between
## these distances; the land's own zoom is left where it was.
const BACK_LEAST := 2.2
const BACK_MOST := 6.0
const BACK_RATE := 1.8

## The game opens over the shoulder (the setting, or `--view=shoulder`).
var opens_over := false
## Whether this system is holding the pointer right now. Kept here rather than
## read back off `Input.mouse_mode`, which a headless run answers VISIBLE whatever
## it was asked, so a test can see what was decided.
var captured := false
var _tool := false
## Seconds since the mouse last turned the view: the follow waits for this.
var _idle := 99.0
## The toggle's own state, kept across a page opening (`HoldToggle.put`).
var _latched := false
var _was_blocked := false
## Prop tops, keyed by template, in the model's own units.
var _tops: Dictionary = {}
var _solids: Array[Vector4] = []


func setup(g: Game) -> void:
	super.setup(g)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_action()
	MouseControls.install()
	# A new game opens with the key let go. The latch is static (HoldToggle), so
	# a view toggled on in the last game came back on in this one, and the first
	# click of the new game took it OFF.
	HoldToggle.put(ACTION, false)
	_tool = g.options.shot != "" or g.options.tour != ""
	var v := g.options.view
	if v == &"":
		# A tool run opens where the game ships, never where the person at the
		# machine last left it (09_view says why: a picture that depends on what
		# ran before it cannot be compared with anything).
		v = &"top" if _tool else StringName(str(PlayerSettings.value(&"playing.view")))
	opens_over = v == &"shoulder"
	# The player can look out to the horizon from the first frame, so the far
	# land's silhouettes are built from the start on the far workers, behind the
	# near chunks, instead of after the first look (world_view `stands_early`).
	if g.view != null:
		g.view.stands_early = true
	var cam := g.camera
	cam.sight_room = room
	cam.shoulder = opens_over
	if opens_over:
		cam.snap_view()


## In project.godot, and ensured here too, so a build that never had it still
## answers to it and a tour can press it.
func _ensure_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_L
	InputMap.action_add_event(ACTION, key)


func _process(delta: float) -> void:
	if game == null or game.camera == null or game.player == null:
		return
	var cam := game.camera
	# A flyover has the picture: the view is the land's, and so are the keys.
	if game.watch.is_finite():
		cam.shoulder = false
		_hold_pointer(false)
		return
	var blocked := game.input_blocked()
	var key := _key(blocked)
	cam.shoulder = Shoulder.wanted(opens_over, key)
	_hold_pointer(Shoulder.capture(cam.shoulder, blocked, _tool, _focused()))
	if blocked or not cam.shoulder:
		return
	_idle += delta
	if not cam.subject.is_finite():
		cam.shoulder_yaw = Shoulder.follow_yaw(cam.shoulder_yaw, game.player.facing,
			game.player.intent_move, _idle, delta)
	var way := 0.0
	if Input.is_action_pressed(&"zoom_in"):
		way -= 1.0
	if Input.is_action_pressed(&"zoom_out"):
		way += 1.0
	if way != 0.0:
		cam.shoulder_back = clampf(cam.shoulder_back * pow(BACK_RATE, way * delta), BACK_LEAST, BACK_MOST)


## The key, under the player's own rule for it. A page opening lets go of every
## latch (42_target calls `HoldToggle.forget` while one is up); a view pressed on
## stays on, so the latch is put back the frame the page closes.
func _key(blocked: bool) -> bool:
	if blocked:
		# The view stays as it was under the page: nothing the player can see
		# behind the glass should move because the glass went up.
		_was_blocked = true
		return _latched
	if _was_blocked:
		_was_blocked = false
		if PlayerSettings.is_set(SETTING, &"toggle"):
			HoldToggle.put(ACTION, _latched)
	var on := HoldToggle.on(ACTION, SETTING)
	_latched = on
	return on


## The zoom keys belong to the shoulder's distance while it is up, so a press is
## not also spent on a height nobody is looking at.
func owns_zoom() -> bool:
	return game != null and game.camera != null and game.camera.shoulder


func _input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm == null or game == null or game.camera == null:
		return
	var cam := game.camera
	if not cam.shoulder or cam.shoulder_share() <= 0.0 or game.input_blocked():
		return
	# SCREEN pixels, never the viewport's: `relative` is scaled by the stretch, so
	# the same hand would turn the view twice as far in a window half the size
	# (and a tool run's window, one pixel across, turned it by the whole clamp).
	var l := Shoulder.look(cam.shoulder_yaw, cam.shoulder_pitch, mm.screen_relative)
	# A lock owns the turn; the mouse may still tip the view up or down.
	if not cam.subject.is_finite():
		cam.shoulder_yaw = l.x
	cam.shoulder_pitch = l.y
	_idle = 0.0


## Whether the window has the player, or what a test says it has: a headless
## window never has focus, so without this nothing could show the pointer being
## taken and given back.
var focus_check := Callable()


func _focused() -> bool:
	if focus_check.is_valid():
		return bool(focus_check.call())
	var w := get_window()
	return w != null and w.has_focus()


func _hold_pointer(on: bool) -> void:
	if on == captured:
		return
	captured = on
	# Only ever what THIS system took: a pointer it never held is not its to let go.
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_hold_pointer(false)


func _exit_tree() -> void:
	_hold_pointer(false)


## How far back the eye may stand, for the rig (`CameraRig.sight_room`): the line
## from the head to the eye, walked against the drawn land and against everything
## that stops a body. A solid prop stands as high as its model does; a wall
## somebody else handed the query (`set_blocks`: a landmark's tower, a depot's
## deck) is taken as reaching the sky, because nothing records how high it goes
## and a camera inside a tower is the failure this exists to prevent.
func room(head: Vector3, eye: Vector3) -> float:
	if game == null or game.world == null or game.query == null:
		return 1.0
	_solids.clear()
	var mid := Vector2((head.x + eye.x) * 0.5, (head.z + eye.z) * 0.5)
	var reach := Vector2(head.x - eye.x, head.z - eye.z).length() * 0.5 + 3.0
	for p: WorldProp in game.query.props_near(mid, reach):
		if p.solid <= 0.0 or game.world.depleted.has(p.id):
			continue
		var base := game.view.surface_height(p.pos) if game.view != null else game.world.height_at(p.pos)
		_solids.append(Vector4(p.pos.x, p.pos.y, p.solid, base + _top(p)))
	var seen := {}
	for i in Shoulder.STEPS + 1:
		var q := head.lerp(eye, float(i) / float(Shoulder.STEPS))
		for c: Vector3 in game.query.blocks_at(Vector2(q.x, q.z)):
			if seen.has(c):
				continue
			seen[c] = true
			_solids.append(Vector4(c.x, c.y, c.z, INF))
	var ground := func(p: Vector2) -> float:
		return game.view.surface_height(p) if game.view != null else game.world.height_at(p)
	return Shoulder.room(head, eye, ground, _solids)


## How high a prop's own model stands, off its template (built and cached when
## its chunk was baked, and guarded by PropModels' own lock).
func _top(p: WorldProp) -> float:
	var country := maxi(Country.COAST, game.world.country_at(floori(p.pos.x), floori(p.pos.y)))
	var variant := PropModels.variant_of(p, game.world.seed_value, country)
	var key := (p.kind * PropModels.MAX_VARIANTS + variant) * BiomeRegistry.SLOTS + country
	if not _tops.has(key):
		var t := PropModels.template(p.kind, variant, country)
		var top := 0.0
		for v: Vector3 in t.made_v:
			top = maxf(top, v.y)
		for v: Vector3 in t.found_v:
			top = maxf(top, v.y)
		_tops[key] = top
	return float(_tops[key]) * p.scale


## What a tour may ask of the view. All read off the live camera.
func tour_seen(what: StringName) -> bool:
	var cam := game.camera if game != null else null
	if cam == null:
		return false
	match what:
		&"shoulder":
			return cam.over_shoulder() and cam.projection == Camera3D.PROJECTION_PERSPECTIVE
		&"shoulder_gliding":
			return cam.shoulder_share() > 0.0 and not cam.over_shoulder()
		&"top_view":
			return cam.shoulder_share() <= 0.0 and not cam.shoulder
		# The eye is standing nearer than the pose asked for: something was in
		# the way and the camera came in rather than go into it.
		&"shoulder_pulled":
			return cam.over_shoulder() and cam.get("_room") < 0.95
		# Turned off the land's own bearing by the mouse or the follow.
		&"shoulder_turned":
			return cam.over_shoulder() and absf(Shoulder.turn(cam.yaw_deg, cam.yaw_now())) > 10.0
		# A lock framed over the shoulder: the view looks within 20 degrees of it.
		&"shoulder_locked":
			if not cam.over_shoulder() or not cam.subject.is_finite():
				return false
			var to := Vector2(cam.subject.x - game.player.position.x, cam.subject.z - game.player.position.z)
			return absf(Shoulder.turn(cam.yaw_now(), Shoulder.yaw_along(to))) < 20.0
		# Looking toward the sun the light comes from (within 25 degrees of its
		# bearing), so a frame can show shadows falling back toward the eye.
		&"shoulder_sun":
			if not cam.over_shoulder() or game.sky == null or game.sky.sun == null:
				return false
			var to_sun := game.sky.sun.global_transform.basis.z
			return absf(Shoulder.turn(cam.yaw_now(), Shoulder.yaw_along(Vector2(to_sun.x, to_sun.z)))) < 25.0
		&"sky_in_frame":
			# The top edge of the picture looks above the horizon.
			return cam.over_shoulder() and cam.shoulder_pitch < cam.fov * 0.5
	return false
