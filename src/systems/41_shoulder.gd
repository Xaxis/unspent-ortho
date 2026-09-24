extends GameSystem
## THE VIEW OVER THE SHOULDER (owner, 2026-09-23: "Should be able to switch to
## true third person perspective (see from behind the players shoulder) ... It
## should be seamless just like targeting ... a key that player has to hold down
## along with a perfectly integrated setting. Should be able to see parts of the
## sky and the horizon.")
##
##   Left Alt/Option (a press, by        the camera glides down off its perch to
##   default), or hold the right mouse   behind the player's right shoulder; the
##   button to peek                      peek lasts as long as the button, and
##                                       lands back wherever the key left it
##   the mouse, or the arrow keys        turns it, and tips it up to the sky
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
## Held, the view is up for as long as it is held and no longer, whatever the
## key's own latch says (owner, 2026-09-24: the right button is "a temporary
## peek"). ControlScheme puts it on the right button where there is a mouse.
const PEEK := &"shoulder_peek"
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
var _boxes: Array[PackedFloat32Array] = []
## Each template's DRAWN footprint, keyed as `_tops`: [lo (x, z), hi (x, z)] in
## the model's own units, what the camera must stand clear of.
var _shapes: Dictionary = {}
## Each prop's probe as it will always be (a Vector4 circle for a thin one, a
## box otherwise), keyed by the prop itself. A prop never moves, so its ground,
## its dealt model and its drawn box have one answer for the life of a world:
## worked out per prop per frame, they were most of what the probe cost.
var _probe_of: Dictionary = {}


func setup(g: Game) -> void:
	super.setup(g)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_action()
	# The scheme's events (the peek on the right button, the arrows' look) are on
	# the map before the first frame reads them, in a test as in a game.
	PlayerSettings.load_once()
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
	key.physical_keycode = KEY_ALT
	key.location = KEY_LOCATION_LEFT
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
	_given_back_by_the_browser()
	var blocked := game.input_blocked()
	var key := _key(blocked)
	cam.shoulder = Shoulder.wanted(opens_over, key)
	_hold_pointer(Shoulder.capture(cam.shoulder, blocked, _tool, _focused()))
	cam.shoulder_clear = Shoulder.CLEAR_TIP if _person_on_the_line(cam) else 0.0
	if blocked or not cam.shoulder:
		return
	_idle += delta
	cam.shoulder_pitch = Shoulder.settle(cam.shoulder_pitch, Shoulder.least_for(_gaze()), delta)
	if not cam.subject.is_finite():
		cam.shoulder_yaw = Shoulder.follow_yaw(cam.shoulder_yaw, game.player.facing,
			game.player.intent_move, _idle, delta)
	if InputMap.has_action(&"look_left"):
		var keys := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
		if keys != Vector2.ZERO:
			var l := Shoulder.key_look(cam.shoulder_yaw, cam.shoulder_pitch, keys, delta, Shoulder.least_for(_gaze()))
			# A lock owns the turn, as it does for the mouse; the tip is still yours.
			if not cam.subject.is_finite():
				cam.shoulder_yaw = l.x
			cam.shoulder_pitch = l.y
			_idle = 0.0
	# A held target key has the zoom (owner's ruling): nothing moves the eye then.
	if _zoom_taken():
		return
	var way := 0.0
	if Input.is_action_pressed(&"zoom_in"):
		way -= 1.0
	if Input.is_action_pressed(&"zoom_out"):
		way += 1.0
	if way != 0.0:
		_move_back(way * delta)


## The eye in or out along the view by `by` (seconds' worth of a held zoom key).
func _move_back(by: float) -> void:
	var cam := game.camera
	cam.shoulder_back = clampf(cam.shoulder_back * pow(BACK_RATE, by), BACK_LEAST, BACK_MOST)


## Whether something else holds the zoom keys right now (a held lock).
func _zoom_taken() -> bool:
	for s in game.systems:
		if s != self and s.has_method(&"owns_zoom") and bool(s.call(&"owns_zoom")):
			return true
	return false


## A scroll or a pinch while the view is up moves the eye, not the land's zoom
## (08_pointer offers it; a held lock was offered it first).
func take_scroll(steps: Vector2) -> bool:
	if game == null or game.camera == null or not game.camera.shoulder:
		return false
	_move_back(steps.y * SCROLL_SECONDS)
	return true


## How much of a held zoom key one notch of scroll is worth.
const SCROLL_SECONDS := 0.12


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
	# A peek is added to the latch, never written into it, so every order of the
	# two comes out right: toggled on and peeked stays on when the button comes
	# up; toggled off and peeked goes back down; toggled while peeking keeps the
	# toggle's answer once the peek ends.
	return on or (InputMap.has_action(PEEK) and Input.is_action_pressed(PEEK))


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
	var l := Shoulder.look(cam.shoulder_yaw, cam.shoulder_pitch, mm.screen_relative, Shoulder.least_for(_gaze()))
	# A lock owns the turn; the mouse may still tip the view up or down.
	if not cam.subject.is_finite():
		cam.shoulder_yaw = l.x
	cam.shoulder_pitch = l.y
	_idle = 0.0


## Whether somebody stands between the eye and what a lock holds, over the
## shoulder (`Shoulder.in_line`). The villagers are 35_folk's rows; one indoors
## is nowhere on the line.
func _person_on_the_line(cam: CameraRig) -> bool:
	if not cam.shoulder or not cam.subject.is_finite():
		return false
	var folk := _folk()
	if folk == null:
		return false
	var people: Array[Vector2] = []
	for row: Dictionary in folk.get("folk"):
		if StringName(str(row.get("state", &"out"))) == &"in":
			continue
		var at: Variant = row.get("pos")
		if at is Vector2:
			people.append(at)
	var eye := cam.global_position
	return Shoulder.in_line(Vector2(eye.x, eye.z), Vector2(cam.subject.x, cam.subject.z), people)


## 35_folk renames its own node, so it is found by its script.
func _folk() -> Node:
	for s in game.systems:
		var script := s.get_script() as Script
		if script != null and script.resource_path.ends_with("35_folk.gd"):
			return s
	return null


## How much of a colossus the view is turned toward: whatever walks them says so
## on the group `&"colossi"` (19_colossi `gaze`), so this knows nothing of them.
func _gaze() -> float:
	var g := 0.0
	for n: Node in get_tree().get_nodes_in_group(&"colossi"):
		g = maxf(g, float(n.get(&"gaze")))
	return g


## Whether the window has the player, or what a test says it has: a headless
## window never has focus, so without this nothing could show the pointer being
## taken and given back.
var focus_check := Callable()


func _focused() -> bool:
	if focus_check.is_valid():
		return bool(focus_check.call())
	var w := get_window()
	return w != null and w.has_focus()


## Whether the pointer really is held right now, or what a test says: a
## headless run answers VISIBLE whatever was asked.
var mode_check := Callable()
## Whether this is a browser, or what a test says.
var web_check := Callable()
## The browser has been seen holding the pointer since this system asked for it.
var _lock_seen := false


func _pointer_held() -> bool:
	if mode_check.is_valid():
		return bool(mode_check.call())
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## A BROWSER TAKES THE POINTER BACK ON ESC (docs/CONTROLS.md, web checks). Every
## browser releases a pointer lock on Escape, and the engine has no listener for
## that, so the Esc a player pressed to pause was spent on the lock and the game
## never heard it: over the shoulder the first Esc did nothing. Once the lock has
## been seen held, a pointer handed back while this system still holds it is the
## browser answering Esc (or the page losing the player), and the answer is the
## pause page -- which also gives the view's keys back. Only on the web: a desktop
## window keeps its capture through Esc.
func _given_back_by_the_browser() -> void:
	var web: bool = bool(web_check.call()) if web_check.is_valid() else OS.has_feature("web")
	if not web or not captured:
		_lock_seen = false
		return
	if _pointer_held():
		_lock_seen = true
		return
	if not _lock_seen:
		return  # asked for, not yet granted: a lock arrives a frame or more later
	_lock_seen = false
	_hold_pointer(false)
	if game.open_screens.has(&"pause") or Input.is_action_pressed(&"pause"):
		return
	for s in game.systems:
		if s.has_method(&"open_screen") and s.name == "90_ui":
			s.call(&"open_screen", &"pause")
			return


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
	_boxes.clear()
	var mid := Vector2((head.x + eye.x) * 0.5, (head.z + eye.z) * 0.5)
	var reach := Vector2(head.x - eye.x, head.z - eye.z).length() * 0.5 + 3.0
	for p: WorldProp in game.query.props_near(mid, reach):
		if p.solid <= 0.0 or game.world.depleted.has(p.id):
			continue
		var probe: Variant = _probe_of.get(p)
		if probe == null:
			probe = _probe(p)
			_probe_of[p] = probe
		if probe is Vector4:
			_solids.append(probe)
		else:
			_boxes.append(probe)
	var seen := {}
	var steps := Shoulder.steps_for(head.distance_to(eye))
	# Once per TILE the line crosses: the walls are stamped by tile, and a step
	# is a fraction of one, so asking at every step asked most tiles five times.
	var last := Vector2i(-99999, -99999)
	for i in steps + 1:
		var q := head.lerp(eye, float(i) / float(steps))
		var cell := Vector2i(floori(q.x), floori(q.z))
		if cell == last:
			continue
		last = cell
		for c: Vector3 in game.query.blocks_at(Vector2(q.x, q.z)):
			if seen.has(c):
				continue
			seen[c] = true
			_solids.append(Vector4(c.x, c.y, c.z, INF))
	var ground := func(p: Vector2) -> float:
		return game.view.surface_height(p) if game.view != null else game.world.height_at(p)
	return Shoulder.room(head, eye, ground, _solids, _boxes, _ground_top(head, eye))


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


## No drawn ground within reach of the line from `a` to `b` stands higher than
## this: one level above the highest tile level within two tiles of it. The
## drawn surface rounds a smoothed field of the levels round a point and adds a
## shore lift and a bump that together stay under a level (TerrainMesher:
## BANK_LIFT 0.36, bumps under 0.1, STEP 0.5). Plain array reads, where a lookup
## of the drawn surface is a chunk search and an interpolation.
func _ground_top(a: Vector3, b: Vector3) -> float:
	var w := game.world
	var x0 := maxi(0, floori(minf(a.x, b.x)) - 2)
	var x1 := mini(w.size - 1, floori(maxf(a.x, b.x)) + 2)
	var y0 := maxi(0, floori(minf(a.z, b.z)) - 2)
	var y1 := mini(w.size - 1, floori(maxf(a.z, b.z)) + 2)
	var top := 0
	for y in range(y0, y1 + 1):
		var row := y * w.size
		for x in range(x0, x1 + 1):
			top = maxi(top, w.level[row + x])
	return float(top + 1) * WorldData.STEP


## A prop's probe: a thin one as the circle it always was (seen past,
## Shoulder.THIN), anything wider as the box its model is DRAWN in, which stands
## up to 1.3 tiles past the circle a body walks round at a house's corners and
## eaves (Shoulder.room says why).
func _probe(p: WorldProp) -> Variant:
	var base := game.view.surface_height(p.pos) if game.view != null else game.world.height_at(p.pos)
	var top := base + _top(p)
	if p.solid < Shoulder.THIN:
		return Vector4(p.pos.x, p.pos.y, p.solid, top)
	return Shoulder.sliced_box_of(p.pos, p.rot, p.scale, base, SLICE, _shape(p), top)


## Height of a slice of a model's drawn shape, in the model's own units.
const SLICE := 0.5


## Where a prop's model is drawn, slice by slice up its height, in the model's
## own units (`Shoulder.slices_of`): everything the chunk bakes, MADE and FOUND.
func _shape(p: WorldProp) -> PackedFloat32Array:
	var country := maxi(Country.COAST, game.world.country_at(floori(p.pos.x), floori(p.pos.y)))
	var variant := PropModels.variant_of(p, game.world.seed_value, country)
	var key := (p.kind * PropModels.MAX_VARIANTS + variant) * BiomeRegistry.SLOTS + country
	if not _shapes.has(key):
		var t := PropModels.template(p.kind, variant, country)
		var verts: PackedVector3Array = t.made_v + t.found_v
		var top := 0.0
		for v: Vector3 in verts:
			top = maxf(top, v.y)
		var s := Shoulder.slices_of(verts, top, SLICE)
		_shapes[key] = s
	return _shapes[key]


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
		# A lock framed over the shoulder, asked of the PICTURE: the locked body
		# is in front of the eye and inside the middle of the frame.
		# A bearing measured from the shoulder swings wildly at arm's length,
		# where the frame is exactly right, so an angle cannot be the claim.
		&"shoulder_locked":
			if not cam.over_shoulder() or not cam.subject.is_finite():
				return false
			# Any part of the body, feet to head, in the middle seven tenths: asked of
			# ONE point at 0.8 up, a swing that stepped the eye at the instant of the
			# shutter failed the claim under load while the frame itself was framed
			# (teammate1, 2026-09-24: the cutter at x 0.39, the claim refused).
			var rect := cam.get_viewport().get_visible_rect().size
			for up: float in [0.2, 0.8, 1.4]:
				var p := cam.subject + Vector3(0.0, up, 0.0)
				if cam.is_position_behind(p):
					continue
				var at := cam.unproject_position(p)
				if at.x > rect.x * 0.15 and at.x < rect.x * 0.85 and at.y > 0.0 and at.y < rect.y:
					return true
			return false
		# Somebody stands on the line from the eye to the lock, whatever the view
		# did about it: what a frame of the problem claims.
		&"person_on_line":
			return cam.over_shoulder() and _person_on_the_line(cam)
		# Somebody is on the line to the lock and the view has tipped to look over
		# them (Shoulder.in_line).
		&"shoulder_clearing":
			return cam.over_shoulder() and _person_on_the_line(cam) and cam.clear_tip() > Shoulder.CLEAR_TIP * 0.8
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


## Whether `a` sees `b` past what is drawn (Shoulder.sees): the same drawn boxes
## the eye is kept out of, so a wall that stops the camera stops sight. Asked by
## 42_target for a lock taken fresh; answered here because the boxes are here.
func sight_clear(a: Vector3, b: Vector3) -> bool:
	if game == null or game.world == null or game.query == null:
		return true
	var boxes: Array[PackedFloat32Array] = []
	var mid := Vector2((a.x + b.x) * 0.5, (a.z + b.z) * 0.5)
	var reach := Vector2(a.x - b.x, a.z - b.z).length() * 0.5 + 3.0
	for p: WorldProp in game.query.props_near(mid, reach):
		if p.solid <= 0.0 or game.world.depleted.has(p.id):
			continue
		var probe: Variant = _probe_of.get(p)
		if probe == null:
			probe = _probe(p)
			_probe_of[p] = probe
		if probe is PackedFloat32Array:
			boxes.append(probe)
	var ground := func(p: Vector2) -> float:
		return game.view.surface_height(p) if game.view != null else game.world.height_at(p)
	return Shoulder.sees(a, b, ground, boxes, _ground_top(a, b))


## Another world's props are other objects; the old island's probes go with it.
func realm_changed(_from: StringName, _to: StringName) -> void:
	_probe_of.clear()
