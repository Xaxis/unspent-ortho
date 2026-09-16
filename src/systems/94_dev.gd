extends GameSystem
## Dev mode in a running game (docs/DEV.md).
##   - the active configuration's live rules, applied as the game starts and again
##     whenever one is edited: the clock's rate, the harm a blow does, whether the
##     land puts bodies round the player, the first hour's guide. These hold in
##     every build, dev mode reachable or not.
##   - where dev mode can be reached: its app on the slate (` or home's dev row),
##     the chord that arms it, F2 a note, F3 the readout on the glass's edge, F4 a
##     picture with nothing of the slate on it, and a DEV flag in the corner
##   - what the dev pages hold on (DevSession): fed, unseen, sheltered, the edge hidden
##   - `dev` in a save: whether dev mode touched the game, and what it was made from
## A tool run reaches none of it unless it asks (--dev, --dev=PAGE[:ROW], --config).

const RULES: Array[String] = ["rules.clock", "rules.harm", "rules.hunger", "rules.bodies", "rules.machines", "rules.guide"]
const READOUT_EVERY := 0.25
const FLAG := Vector2i(603, 348)
const VIOLET := Color("#b3a8ea")

var screen: UiDevScreen
var _ui: Node
var _overlay: Control
## Rule id -> the value last put into the game.
var _rules := {}
var _held := {}
var _pending := ""
var _pending_frames := 3
var _readout_in := 0.0
var _pairs: Array = []
## The world before the first app of a run of them opened (a note's picture).
var _world_frame: Image
var _picture_in := -1
var _hud_hidden := false
var _revision := -1
## The spawner's own rate before rules.bodies scaled it (-1: not read yet).
var _spawn_rate := -1.0
## The clock when hunger's pace was last applied (rules.hunger).
var _hunger_at := -INF
var _sheltered := false
## Clean pictures kept this game.
var _pictures := 0


func setup(g: Game) -> void:
	super.setup(g)
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in RULES:
		_rules[id] = ConfigSchema.default_of(id)
	# A game dev mode started keeps its saves apart, and is touched from the start.
	DevMode.touched = DevPlay.dev_started()
	SaveGame.register(&"dev", _save, _load)
	if DevMode.access() == &"off":
		return
	DevMode.ensure_actions()
	for s in g.systems:
		if s.name == "90_ui":
			_ui = s
	if _ui != null:
		screen = UiDevScreen.new()
		_ui.call("add_app", screen)
	var layer := CanvasLayer.new()
	layer.name = "dev"
	layer.layer = 19
	add_child(layer)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	layer.add_child(_overlay)
	Events.screen_changed.connect(_on_screen_changed)
	if DevMode.asked:
		_pending = DevMode.asked_page


func started() -> void:
	_apply_rules()


func _exit_tree() -> void:
	if Events.screen_changed.is_connected(_on_screen_changed):
		Events.screen_changed.disconnect(_on_screen_changed)
	if game != null and game.hud != null and _hud_hidden:
		game.hud.visible = game.open_screens.is_empty()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		DevJobs.stop_serving()


## Every rule whose value changed since it was last put into the game (the first
## time: any the configuration sets away from its default).
func _apply_rules() -> void:
	for id in RULES:
		var v: Variant = GameConfig.value(id)
		if ConfigSchema.same(v, _rules[id]):
			continue
		_rules[id] = v
		match id:
			"rules.clock":
				game.clock.rate = float(v)
			"rules.harm":
				if game.player.hero != null:
					game.player.hero.harm = float(v)
			"rules.bodies":
				var mobs := DevCheats.system(game, "30_mobs")
				var spawner: Variant = mobs.get("spawner") if mobs != null else null
				if spawner is Spawner:
					if _spawn_rate < 0.0:
						_spawn_rate = (spawner as Spawner).rate
					(spawner as Spawner).rate = _spawn_rate * float(v)
			"rules.machines":
				DevCheats.set_spawning(game, bool(v))
			"rules.guide":
				var guide := DevCheats.system(game, "58_guide")
				if guide != null:
					# The guide keeps its own switch (it is off in shots); this sets it.
					guide.set("_off", not bool(v))
		# A configuration's own rules are the game as built; an edit on the slate is a touch.
		if GameConfig.edits.has(id):
			DevMode.touched = true


func _process(delta: float) -> void:
	if game == null or game.world == null:
		return
	if GameConfig.revision != _revision:
		_revision = GameConfig.revision
		_apply_rules()
	_pace_hunger()
	if screen == null:
		return
	_hold_session()
	_read_keys()
	_stage(delta)
	if _picture_in >= 0:
		_picture_in -= 1
		if _picture_in < 0:
			_take_picture()
	_readout_in -= delta
	if _readout_in <= 0.0:
		_readout_in = READOUT_EVERY
		_pairs = DevReadout.pairs(game) if DevMode.readout and DevMode.reachable() else []
		_overlay.queue_redraw()


## rules.hunger: hunger is the clock running past the last meal (Body.fed_until),
## so a pace other than one moves that meal along with the clock: at half pace,
## half of every world minute is given back; at none, all of it. Sleep and every
## other jump count, as they would in the body. Nothing when the pace is one.
func _pace_hunger() -> void:
	var now := game.clock.minutes
	var pace := float(GameConfig.value("rules.hunger"))
	if _hunger_at > -INF and now > _hunger_at and not is_equal_approx(pace, 1.0):
		game.body.fed_until += (now - _hunger_at) * (1.0 - pace)
	_hunger_at = now


## What the dev pages hold on, written again over whatever the game wrote this frame.
func _hold_session() -> void:
	var now := game.clock.minutes
	if DevSession.fed:
		game.body.fed_until = maxf(game.body.fed_until, now + 60.0)
	if DevSession.unseen:
		game.body.spoof_until = maxf(game.body.spoof_until, now + 5.0)
	if DevSession.sheltered:
		DevCheats.shelter(game)
		_sheltered = true
	elif _sheltered:
		_sheltered = false
		var gear := DevCheats.system(game, "54_gear")
		if gear != null:
			gear.call("_refit")
	# The ui system shows the edge whenever the last app closes; hidden is held over that.
	if DevSession.hud_hidden and game.hud.visible:
		game.hud.visible = false
	elif not DevSession.hud_hidden and _hud_hidden and game.open_screens.is_empty():
		game.hud.visible = true
	_hud_hidden = DevSession.hud_hidden


func _went_down(action: StringName) -> bool:
	var now := InputMap.has_action(action) and Input.is_action_pressed(action)
	var was: bool = _held.get(action, false)
	_held[action] = now
	return (now and not was) or (InputMap.has_action(action) and Input.is_action_just_pressed(action))


func _read_keys() -> void:
	var toggle := _went_down(&"dev_toggle")
	var note := _went_down(&"dev_note")
	var readout := _went_down(&"dev_readout")
	var picture := _went_down(&"dev_picture")
	if screen.editing():
		return
	if toggle:
		if not DevMode.reachable():
			if DevMode.chord(Time.get_ticks_msec()):
				Events.sfx.emit(&"ui_slate_ping", Vector3.ZERO)
				open()
			return
		if screen.is_open:
			screen.handle(&"dev_toggle")
		else:
			open()
		return
	if not DevMode.reachable():
		return
	if note:
		open(&"notes")
		screen.select(&"words")
		screen.handle(&"confirm")
	elif readout:
		DevMode.set_readout(not DevMode.readout)
		_readout_in = 0.0
	elif picture:
		picture_soon()


## Open the dev app (at a page), over whatever app is up.
func open(page: StringName = &"") -> bool:
	if _ui == null:
		return false
	if not screen.is_open and not bool(_ui.call("open_screen", &"dev")):
		return false
	screen.settle()
	if page != &"":
		screen.open_at(page)
	return true


## --dev=PAGE[:ROW] and --dev=readout: staged once the scripted walk is over.
func _stage(_delta: float) -> void:
	if _pending == "" or game.scripted_seconds > 0.0:
		return
	_pending_frames -= 1
	if _pending_frames > 0:
		return
	var parts := _pending.split(":", true, 1)
	_pending = ""
	if parts[0] == "readout":
		DevMode.readout = true
		_readout_in = 0.0
		return
	UiSlate.warm()
	UiSlate.wait()
	open(StringName(parts[0]) if parts[0] != "home" else &"")
	if parts.size() > 1:
		screen.select(StringName(parts[1]))


func _on_screen_changed(n: StringName, open_now: bool) -> void:
	if not open_now or screen == null:
		return
	# The game notes the open app before this runs: one open means it is the first.
	if game.open_screens.size() == 1:
		_world_frame = _frame()
	if n == &"dev":
		screen.picture = _world_frame


func _frame() -> Image:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return null
	var tex := get_viewport().get_texture()
	return tex.get_image() if tex != null else null


# --- a clean picture -----------------------------------------------------------------------

## The next frames with nothing of the slate on them: every app shut, the edge
## and the flag hidden, then the picture.
func picture_soon() -> void:
	if screen.is_open:
		screen.close()
	game.hud.visible = false
	_overlay.visible = false
	_picture_in = 2


func _take_picture() -> void:
	await RenderingServer.frame_post_draw
	var img := _frame()
	game.hud.visible = not DevSession.hud_hidden and game.open_screens.is_empty()
	_overlay.visible = true
	if img == null:
		return
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var name := "picture-%s.png" % Time.get_datetime_string_from_system(false, false).replace("-", "").replace(":", "").replace("T", "-")
	if DevMode.web():
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), name, "image/png")
		game.hud.say_now("Downloading %s." % name)
		return
	var dir := DevMode.project_path("shots/dev") if DevMode.local() else ProjectSettings.globalize_path("user://dev/pictures")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name))
	_pictures += 1
	game.hud.say_now("Picture kept: %s." % name)
	print("dev picture %s" % dir.path_join(name))


## What a tour may await of dev mode: dev_armed (the chord took), dev_readout (on
## the glass's edge), dev_noted (a note kept in the last minute), dev_touched,
## dev_clock:N (the running clock's rate is N), dev_picture (a clean picture kept),
## dev_job:done and dev_job:ok (the slate's background job has ended, and well).
func tour_seen(what: StringName) -> bool:
	match what:
		&"dev_armed":
			return DevMode.armed
		&"dev_readout":
			return DevMode.readout and not _pairs.is_empty()
		&"dev_noted":
			var notes := DevNotes.list()
			return not notes.is_empty() and Time.get_unix_time_from_system() - float(notes[0].get("at", 0)) < 60.0
		&"dev_touched":
			return DevMode.touched
		&"dev_picture":
			return _pictures > 0
	if what == &"dev_job:ok" or what == &"dev_job:done":
		DevJobs.poll()
		return not DevJobs.job.is_empty() and not DevJobs.running() and (what == &"dev_job:done" or int(DevJobs.job.code) == 0)
	if String(what).begins_with("dev_clock:"):
		return is_equal_approx(game.clock.rate, String(what).trim_prefix("dev_clock:").to_float())
	return false


# --- saving -------------------------------------------------------------------------------

func _save() -> Variant:
	return {"touched": DevMode.touched, "config": GameConfig.active, "build": DevReadout.build_line()}


func _load(v: Variant) -> void:
	if v is Dictionary and bool((v as Dictionary).get("touched", false)):
		DevMode.touched = true


# --- the flag and the readout ------------------------------------------------------------------

func _draw_overlay() -> void:
	if not DevMode.reachable() or not game.open_screens.is_empty() or _hud_hidden:
		return
	# The flag: a violet cap in the corner, so no frame of play is mistaken for a
	# player's while dev mode can be reached. Touched: a point beside it.
	var cap := Rect2i(FLAG.x, FLAG.y, 19, 9)
	UiDraw.rect(_overlay, cap.grow(1), UiTheme.RIM)
	UiDraw.frame(_overlay, cap, UiTheme.MACHINE[1])
	UiDraw.text(_overlay, Vector2i(cap.position.x + 2, cap.position.y - 1), "DEV", VIOLET)
	if DevMode.touched:
		UiDraw.rect(_overlay, Rect2i(cap.position.x - 5, cap.position.y + 3, 2, 2), VIOLET)
	if _pairs.is_empty():
		return
	var h := _pairs.size() * UiTheme.LINE + 6
	var r := Rect2i(14, 360 - 40 - h, 214, h)
	Hud.clip(_overlay, r, true)
	var y := r.position.y + 3
	for pair: Array in _pairs:
		UiDraw.text(_overlay, Vector2i(r.position.x + 4, y), pair[0], UiTheme.MACHINE[2])
		UiDraw.text(_overlay, Vector2i(r.position.x + 44, y), DevPage._fit(str(pair[1]), r.size.x - 48), UiTheme.TEXT)
		y += UiTheme.LINE
