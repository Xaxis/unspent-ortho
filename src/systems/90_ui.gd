extends GameSystem
## The slate, wired into a running game.
##   - feeds the HUD (the slate's edge overlay) every frame from Body, Inventory,
##     the clock, the lamp's reserve and the world
##   - records the land the player has seen, for the survey, and saves it
##   - opens apps on their keys (Tab/I carrying, C making, M map, Esc home) and
##     routes menu input to the top one (draw order = input priority); an app's
##     key while another app is up switches the glass to it, and on home opens
##     it over home; gear, machine reads and saves open from home
##   - the slate's power: its glass dims and it whines once when power runs low
## It reads the game's data and acts only through Inventory, Crafting, Survival's
## `eat` / `use_hint`, and SlateFeeds for the apps other packages fill.

var explored: UiExplored
var layer: CanvasLayer
var screens := {}
var stack: Array[UiScreen] = []
var map_data: UiMapData
var power := 1.0
var _places := UiPlaceWatch.new()
var _pending_screen := ""
var _vertical := UiMenu.new()
## Where the player was last frame, so a jump (a teleport, a load, a portal)
## is told from a walk, and the landscape under them read every frame.
var _last_pos := Vector2.INF
## A landscape entered while nobody could read the ping (an app up, a fight on):
## it waits here rather than being lost.
var _pending_place: StringName = &""
## The first hour's guide (58_guide), for the goal line and the key hint, and
## what it last said to want and to teach.
var _guide: Node
var _goal := ""
var _teach: Dictionary = {}
var _guide_in := 0.0
## Real seconds between two readings of the guide.
const GUIDE_EVERY := 0.25
## Which app and opening actions were down last frame, and which went down
## during physics steps since.
var _held := {}
var _seen_down := {}
var _horizontal := UiMenu.new()
## Real seconds until the survey's data is packed in the background: after the
## world's first chunks, so start-up is not slowed, and before anyone opens it.
var _map_build_in := 2.0
var _low := false

## Apps with a key of their own, which switch between each other.
const APPS: Array[StringName] = [&"inventory", &"crafting", &"map", &"loadout", &"reads", &"saves"]


func setup(g: Game) -> void:
	super(g)
	process_mode = Node.PROCESS_MODE_ALWAYS
	explored = UiExplored.new(g.world.size)
	explored.visit(g.player.pos)
	_last_pos = g.player.pos
	map_data = UiMapData.new(g.world)
	if g.options.explore > 0:
		explored.wander(g.world, g.player.pos, g.options.explore, g.options.seed_value)
	# The slate's bezel bakes on a worker now, so the first app opens without a hitch.
	UiSlate.warm()
	layer = CanvasLayer.new()
	layer.name = "screens"
	layer.layer = 20
	add_child(layer)
	_add(UiInventoryScreen.new())
	_add(UiCraftingScreen.new())
	_add(UiMapScreen.new())
	_add(UiLoadoutScreen.new())
	_add(UiReadsScreen.new())
	_add(UiSavesScreen.new())
	_add(UiPauseScreen.new())
	_add(UiSettingsScreen.new())
	_add(UiSheetScreen.new())
	# Survival gives these first when it is loaded; this never adds twice.
	UiRules.apply_give(g.inventory, g.options.give)
	SaveGame.register(&"ui", _save, _load)
	if g.options.ui_demo:
		_demo()
	_pending_screen = g.options.screen


## An app another package brings to the slate (dev mode's, 94_dev): it is owned,
## stacked and routed like the slate's own.
func add_app(s: UiScreen) -> void:
	_add(s)


func _add(s: UiScreen) -> void:
	s.game = game
	s.name = String(s.screen_name)
	layer.add_child(s)
	screens[s.screen_name] = s
	s.closed.connect(_on_closed)
	if s is UiMapScreen:
		(s as UiMapScreen).explored = explored
		(s as UiMapScreen).data = map_data
	if s is UiPauseScreen:
		(s as UiPauseScreen).to_title = func() -> void: UiTitle.replace_game.call_deferred(game)
		(s as UiPauseScreen).open_app = func(n: StringName) -> void: open_screen(n)


func _exit_tree() -> void:
	# A background build reads the world; never let the world go first.
	if map_data != null:
		map_data.wait()
	UiSketch.wait()
	UiSlate.wait()
	if get_tree() != null and stack.has(screens.get(&"pause")):
		get_tree().paused = false


func top() -> UiScreen:
	return stack.back() if not stack.is_empty() else null


## Open an app by name. Returns false (and says why) when it cannot open now.
func open_screen(n: StringName, switched: bool = false) -> bool:
	if n == &"controls":
		# What `controls` used to open was a list of letters somebody typed out.
		# It is the settings app's keys page now, which reads the real input map.
		if not open_screen(&"settings"):
			return false
		var s := top() as UiSettingsScreen
		if s != null:
			s.page = "keys"
			s.refresh()
		return true
	if not screens.has(n):
		return false
	var s: UiScreen = screens[n]
	if s.is_open:
		return true
	var why := why_not_open(n)
	if why != "":
		if top() != null:
			# The HUD is hidden under an open app: say it on the glass.
			top().refuse(why)
			return false
		Events.sfx.emit(&"ui_slate_deny", Vector3.ZERO)
		if n == &"crafting" and why != NEAR_LINE:
			Events.message.emit(why)
		else:
			game.hud.say_now(why)
		return false
	if n == &"crafting":
		var here := UiLink.stations_here(game)
		if here.is_empty() and game.options.ui_demo:
			here.append(&"fire")
		(s as UiCraftingScreen).stations = here
	if s is UiPauseScreen:
		(s as UiPauseScreen).seen_share = explored.fraction()
	s.power = power
	s.brightness = UiRules.brightness(power)
	stack.append(s)
	# The newest app is drawn over the rest (gear over home).
	layer.move_child(s, -1)
	s.open(switched)
	_vertical.absorb(_device_dir(&"move_up", &"move_down"))
	_horizontal.absorb(_device_dir(&"move_left", &"move_right"))
	# A direction already down as the app opens is the walk that was going on, not a
	# press on the list: its held state is taken now, so only a fresh press moves it.
	for pair: Array in MOVE_KEYS:
		_held[pair[0]] = Input.is_action_pressed(pair[0])
		_seen_down.erase(pair[0])
	_opened_frame = Engine.get_process_frames()
	if n == &"pause":
		get_tree().paused = true
	game.hud.visible = false
	return true


const NEAR_LINE := "Not with that so close."


## "" if app `n` can open now, else one plain line why not. Home opens beside
## a hostile, and so do the apps that only read (gear, machine reads, saves)
## once home is up; carrying and making never do, however they are reached, or
## home would be a way round the rule (making skips world time; eating works).
func why_not_open(n: StringName) -> String:
	if n == &"dev":
		# Dev mode is for looking at a fight as much as anything else.
		return ""
	# From home, with the world already stopped, an app that only reads is no help
	# to a fight and no harm to one: the journal is kept with the feeds for that.
	var reads_only := (n in SlateFeeds.APPS or n == &"journal") and stack.has(screens.get(&"pause"))
	if n != &"pause" and not reads_only and _hostile_near():
		return NEAR_LINE
	if n == &"crafting":
		var here := UiLink.stations_here(game)
		if here.is_empty() and not game.options.ui_demo:
			return "Nothing here to make things at."
	return ""


## Put app `n` on the glass in place of the app on top, without the slate sleeping.
func switch_to(n: StringName) -> bool:
	var s := top()
	if s == null or s.screen_name == n or not APPS.has(s.screen_name):
		return false
	var why := why_not_open(n)
	if why != "":
		Events.sfx.emit(&"ui_slate_deny", Vector3.ZERO)
		s.refuse(why)
		return false
	s.close(true)
	return open_screen(n, true)


func _on_closed(s: UiScreen) -> void:
	stack.erase(s)
	if s.screen_name == &"pause":
		get_tree().paused = false
	if stack.is_empty():
		game.hud.visible = true


## Keys on an app: action -> what the app is told.
const PAGE_KEYS := [[&"pause", &"back"], [&"use", &"confirm"], [&"swing", &"confirm"], [&"inventory", &"inventory"], [&"craft", &"craft"], [&"map", &"map"], [&"drop", &"drop"]]
## Directions on an app: action -> what the app is told.
const MOVE_KEYS := [[&"move_up", &"up"], [&"move_down", &"down"], [&"move_left", &"left"], [&"move_right", &"right"]]
## The frame the last app opened on: a direction that went down on it is not a press on it.
var _opened_frame := -1
## Keys that open an app from play.
const OPEN_KEYS := {&"inventory": &"inventory", &"craft": &"crafting", &"map": &"map", &"pause": &"pause"}


## Keys are read from the action state, not from input events, so a tour's
## Input.action_press opens and drives the slate the way a key does. A press
## is the frame an action is first seen down (it may have gone down after this
## node's _process last ran, so "just pressed" alone would miss it).
## Returns true when an app was open (it had the keys this frame).
func _read_keys() -> bool:
	var down := {}
	for pair: Array in PAGE_KEYS:
		down[pair[0]] = _went_down(pair[0])
	var s := top()
	if s != null:
		for pair: Array in PAGE_KEYS:
			if not down[pair[0]]:
				continue
			var target: StringName = OPEN_KEYS.get(pair[0], &"")
			if target != &"" and target != &"pause" and target != s.screen_name and APPS.has(s.screen_name):
				switch_to(target)
			elif target != &"" and target != &"pause" and s.screen_name == &"pause":
				# Home lists carrying, making and the map: their keys open them over it.
				open_screen(target)
			else:
				s.handle(pair[1])
			break
		return true
	for action: StringName in OPEN_KEYS:
		if down[action]:
			open_screen(OPEN_KEYS[action])
			break
	return false


func _went_down(action: StringName) -> bool:
	var just := Input.is_action_just_pressed(action)
	var now := Input.is_action_pressed(action) or _seen_down.has(action) or just
	_seen_down.erase(action)
	var was: bool = _held.get(action, false)
	_held[action] = now
	# Just pressed is a press even if it was let go and taken again between two
	# reads (a tour's second tap of one key; a very fast finger).
	return (now and not was) or just


func _physics_process(_delta: float) -> void:
	# After a slow frame the physics steps catch up several at once, and a short
	# press can go down and up between two _process calls: note it here.
	# Only a press not yet read: a key still held from the last read is not a new one,
	# or its note would outlive the release and swallow the next tap.
	for pair: Array in PAGE_KEYS + MOVE_KEYS:
		if Input.is_action_pressed(pair[0]) and not _held.get(pair[0], false):
			_seen_down[pair[0]] = true


func _process(delta: float) -> void:
	if game == null or game.world == null:
		return
	if _map_build_in > 0.0:
		_map_build_in -= delta
		if _map_build_in <= 0.0:
			map_data.build_async()
			var carried: Array[StringName] = []
			carried.assign(game.inventory.items.keys())
			var stations: Array[StringName] = [&"fire", &"bench", &"kiln", &"hand"]
			UiSketch.warm(carried, UiInventoryScreen.SKETCH, stations, UiCraftingScreen.SKETCH)
			var none: Array[StringName] = []
			UiSketch.warm(none, UiInventoryScreen.SKETCH, stations, UiCraftingScreen.STATION)
	_step_power()
	if _pending_screen != "" and game.scripted_seconds <= 0.0:
		# --screen=NAME or NAME:ROW (a row id to choose, for shots). Staging, not
		# play: it may wait for the bezel's bake so a shot shows it.
		UiSlate.warm()
		UiSlate.wait()
		var parts := _pending_screen.split(":")
		if parts[0] == "lowpower":
			# Shot staging: the lamp nearly dry and no charge carried, then NAME after it.
			SurvivalState.of(game).lamp_oil = UiRules.POWER_LAMP_MINUTES * 0.08
			game.inventory.remove(&"oil", game.inventory.count(&"oil"))
			game.inventory.remove(&"wick", game.inventory.count(&"wick"))
			_step_power()
			parts.remove_at(0)
			if parts.is_empty():
				parts.append("")
		# Gear, reads and saves live under home, as a player reaches them.
		if StringName(parts[0]) in SlateFeeds.APPS:
			open_screen(&"pause")
		if open_screen(StringName(parts[0])):
			top().settle()
			if parts.size() > 1:
				top().select(StringName(parts[1]))
		_pending_screen = ""
	# The landscape under the player is read every frame, app or no app: a page
	# closed after a teleport must not find the watcher still standing at the coast.
	var hostile := _hostile_near()
	_watch_place(delta, hostile)
	if _read_keys():
		var s := top()
		if s == null:
			return
		_step_axis(s, _vertical, &"move_up", &"move_down", delta, &"up", &"down")
		_step_axis(s, _horizontal, &"move_left", &"move_right", delta, &"left", &"right")
		return
	explored.visit(game.player.pos)
	game.hud.set_quiet(hostile)
	_step_guide(delta)
	_feed_hud()


## Read the landscape under the player and ping its name when someone can read
## it. A walked border settles (UiPlaceWatch.SETTLE); a jump is said at once.
## A name entered under an open app or in a fight waits until there is a HUD
## to say it on, rather than being swallowed — and is dropped if the ground has
## changed under it while it waited: the caption says where the player stands,
## or it says nothing.
func _watch_place(delta: float, hostile: bool) -> void:
	var p := game.player.pos
	var jumped := _last_pos.is_finite() and UiPlaceWatch.jumped(_last_pos, p)
	_last_pos = p
	var under := BiomeRegistry.at(game.world, p).id
	var entered := _places.step(under, delta, jumped)
	if entered != &"":
		_pending_place = entered
	if _pending_place == &"" or not stack.is_empty() or hostile:
		return
	if _pending_place != under:
		# It waited for a glass nobody could read, and the ground has changed
		# under it since (a border crossed in a fight, then crossed back): the
		# name is no longer true, so it is dropped and the land they are actually
		# standing in is read again from nothing and said next frame.
		_pending_place = &""
		_places.announced = &""
		return
	game.hud.show_place(BiomeRegistry.get_def(_pending_place).display_name)
	Events.sfx.emit(&"ui_slate_ping", Vector3.ZERO)
	_pending_place = &""


## The slate's power from the lamp's reserve and the charges carried: the glass
## dims with it, and it whines once each time it runs low.
func _step_power() -> void:
	power = UiRules.slate_power(Survival.lamp_oil(game), game.inventory.count(&"wick"))
	var low := power < UiSlate.LOW_POWER
	if low and not _low:
		Events.sfx.emit(&"ui_slate_whine", Vector3.ZERO)
	# It must come back a little over the line before it can whine again.
	if low:
		_low = true
	elif power >= UiSlate.LOW_POWER + 0.05:
		_low = false
	game.hud.set_power(power)
	# Every open app, not just the top: home under gear shows as soon as gear closes.
	for s in stack:
		if not is_equal_approx(s.power, power):
			s.power = power
			# Its setter redraws the glass layer, where the dimming is drawn.
			s.brightness = UiRules.brightness(power)
			s.queue_redraw()


## A direction moves the list once on the frame it goes down, then repeats while
## held (UiMenu.hold). A tap struck and let go between two frames (a quick finger,
## a browser's key event, a slow frame) is never seen held, so the press is what
## moves and the hold only repeats.
func _step_axis(s: UiScreen, r: UiMenu, neg_action: StringName, pos_action: StringName, delta: float, neg: StringName, pos: StringName) -> void:
	var tap := int(_went_down(pos_action)) - int(_went_down(neg_action))
	var held := _device_dir(neg_action, pos_action)
	if tap != 0 and Engine.get_process_frames() != _opened_frame:
		s.handle(pos if tap > 0 else neg)
		# The press moved it: the hold takes over from here, for repeats only.
		r.hold(tap, 0.0)
		if held != tap:
			r.hold(0, 0.0)
		return
	_repeat(s, r, held, delta, neg, pos)


func _repeat(s: UiScreen, r: UiMenu, dir: int, delta: float, neg: StringName, pos: StringName) -> void:
	for i in r.hold(dir, delta):
		s.handle(pos if dir > 0 else neg)


func _device_dir(neg: StringName, pos: StringName) -> int:
	return int(Input.is_action_pressed(pos)) - int(Input.is_action_pressed(neg))


func _feed_hud() -> void:
	var hud := game.hud
	var b := game.body
	var inv := game.inventory
	hud.set_body(b.health, b.max_health, b.wind, b.max_wind)
	hud.set_held(inv.held)
	hud.set_charge(UiRules.charge_shown(inv.held), inv.count(&"wick"))
	hud.set_pressures(UiRules.pressures(b, game.clock.minutes, inv.bulk(), UiLink.creel(inv, b), Survival.lamp_oil(game), b.lamp_lit))
	hud.set_goal(_goal)
	var busy := Time.get_ticks_msec() / 1000.0 < b.busy_until
	if not UiRules.hint_allowed(busy, game.input_blocked(), get_tree().get_nodes_in_group(&"mobs"), game.player.pos):
		hud.set_hint("")
		return
	var said := UiLink.use_hint(game)
	if said != "":
		hud.set_hint(said, "e")
		return
	var here := UiLink.stations_here(game)
	if not here.is_empty() and here[0] != &"hand":
		hud.set_hint("%s - make" % here[0], "c")
		return
	# Nothing to work here: the row teaches the key the guide has not retired yet.
	if _teach.is_empty():
		hud.set_hint("")
	else:
		hud.set_hint(String(_teach.line), String(_teach.key))


## What to want and what to teach: both walk the fires, the recipes and the
## bodies about, and neither changes inside a frame. They are asked for a few
## times a second, not sixty (a standing line does not need more).
func _step_guide(delta: float) -> void:
	_guide_in -= delta
	if _guide_in > 0.0:
		return
	_guide_in = GUIDE_EVERY
	_goal = Guide.goal(game) if _guided() else ""
	_teach = _guide_hint()


## The guide system, while the game has one that is speaking (it is off in
## single-frame shots, so a canon frame stays as it was).
func _guided() -> bool:
	if _guide == null or not is_instance_valid(_guide):
		_guide = null
		for sys in game.systems:
			if sys.name == "58_guide":
				_guide = sys
	return _guide != null and not bool(_guide.get("_off"))


## The first hint the guide would teach that names a key, or {}.
func _guide_hint() -> Dictionary:
	if not _guided():
		return {}
	var retired: Dictionary = _guide.get("retired")
	var h := Guide.hint_for(game, retired)
	# A line with no key of its own is said, not shown on a key row.
	return h if not h.is_empty() and String(h.get("key", "")) != "" else {}


func _hostile_near() -> bool:
	return UiRules.hostile_near(get_tree().get_nodes_in_group(&"mobs"), game.player.pos)


## Tours ask what is on the glass: the location ping standing on its own scrap
## of glass, a badge that has just answered for a line the glass did not say in
## words, and whether the bottom middle is clear of text at all.
func tour_seen(what: StringName) -> bool:
	match what:
		&"ping":
			return game.hud.place_alpha() > 0.0 and game.hud.place != ""
		&"badge_answered":
			return game.hud.answering()
		&"quiet_glass":
			return game.hud.messages.visible().is_empty()
	return false


## What the slate keeps in a save: the land seen and the way walked (JSON-safe).
func _save() -> Variant:
	var trail := PackedFloat32Array()
	for p in explored.trail:
		trail.append(p.x)
		trail.append(p.y)
	return {
		"size": explored.size,
		"seen": Marshalls.raw_to_base64(explored.mask.compress(FileAccess.COMPRESSION_DEFLATE)),
		"trail": Marshalls.raw_to_base64(trail.to_byte_array().compress(FileAccess.COMPRESSION_DEFLATE)),
		"trail_n": explored.trail.size(),
		"bounds": [explored.bounds.position.x, explored.bounds.position.y, explored.bounds.size.x, explored.bounds.size.y],
		"place": String(_places.announced),
	}


func _load(v: Variant) -> void:
	if not (v is Dictionary) or int(v.get("size", 0)) != explored.size:
		return
	var n := explored.size * explored.size
	var mask := Marshalls.base64_to_raw(String(v.get("seen", ""))).decompress(n, FileAccess.COMPRESSION_DEFLATE)
	if mask.size() == n:
		explored.mask = mask
	var tn := int(v.get("trail_n", 0))
	var raw := Marshalls.base64_to_raw(String(v.get("trail", ""))).decompress(tn * 8, FileAccess.COMPRESSION_DEFLATE).to_float32_array()
	explored.trail = PackedVector2Array()
	for i in range(0, raw.size() - 1, 2):
		explored.trail.append(Vector2(raw[i], raw[i + 1]))
	var b: Array = v.get("bounds", [0, 0, 0, 0])
	explored.bounds = Rect2i(int(b[0]), int(b[1]), int(b[2]), int(b[3]))
	_places.announced = StringName(v.get("place", ""))


## Shot staging for --ui-demo: a message on the line, a body that has been in
## a fight and gone without food, so every quiet readout is visible.
func _demo() -> void:
	var b := game.body
	b.health = 8
	b.wind = 1500.0
	b.fed_until = game.clock.minutes - 240.0
	b.wet = 0.5
	if game.options.walk_seconds <= 0.0:
		_stand_by_something(24.0)
	game.hud.show_message("Took 2 timber.")
	var here := _places.step(BiomeRegistry.at(game.world, game.player.pos).id, 0.0)
	if here != &"":
		game.hud.show_place(BiomeRegistry.get_def(here).display_name)
	_feed_hud()
	game.hud.settle()


## Put the player beside the nearest thing that can be worked, facing it, so
## the use hint shows in a shot.
func _stand_by_something(r: float) -> void:
	var p := game.player
	var kinds: Array[int] = []
	for k: int in UiRules.PROP_VERBS:
		kinds.append(k)
	var target := game.query.nearest_prop(p.pos, r, kinds)
	if target == null:
		return
	for a in 8:
		var dir := Vector2.from_angle(a * TAU / 8.0)
		var spot := target.pos - dir * (target.solid + 0.7)
		if game.query.standable(floori(spot.x), floori(spot.y)):
			p.pos = spot
			p.facing = dir.angle()
			p.drive(Vector2.ZERO, false, 0.0)
			return
