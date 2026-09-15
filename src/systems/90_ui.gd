extends GameSystem
## The notebook and the quiet layer, wired into a running game.
##   - feeds the HUD every frame from Body, Inventory, the clock and the world
##   - records the land the player has seen, for the map
##   - opens screens on their keys (Tab/I carrying, C making, M map, Esc pause)
##     and routes menu input to the top one (draw order = input priority)
## It reads the game's data and acts only through Inventory, Crafting and a
## survival system's `eat` / `use_hint` when one offers them.

var explored: UiExplored
var layer: CanvasLayer
var screens := {}
var stack: Array[UiScreen] = []
var map_data: UiMapData
var _pending_screen := ""
var _vertical := UiMenu.new()
var _horizontal := UiMenu.new()
## Real seconds until the map's data is packed in the background: after the
## world's first chunks, so start-up is not slowed, and before anyone opens it.
var _map_build_in := 2.0


func setup(g: Game) -> void:
	super(g)
	process_mode = Node.PROCESS_MODE_ALWAYS
	explored = UiExplored.new(g.world.size)
	explored.visit(g.player.pos)
	map_data = UiMapData.new(g.world)
	if g.options.explore > 0:
		explored.wander(g.world, g.player.pos, g.options.explore, g.options.seed_value)
	layer = CanvasLayer.new()
	layer.name = "screens"
	layer.layer = 20
	add_child(layer)
	_add(UiInventoryScreen.new())
	_add(UiCraftingScreen.new())
	_add(UiMapScreen.new())
	_add(UiPauseScreen.new())
	_add(UiSheetScreen.new())
	if g.options.give != "":
		UiRules.apply_give(g.inventory, UiRules.parse_give(g.options.give))
	if g.options.ui_demo:
		_demo()
	_pending_screen = g.options.screen


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


func _exit_tree() -> void:
	# A background build reads the world; never let the world go first.
	if map_data != null:
		map_data.wait()
	if get_tree() != null and stack.has(screens.get(&"pause")):
		get_tree().paused = false


func top() -> UiScreen:
	return stack.back() if not stack.is_empty() else null


## Open a screen by name. Returns false (and says why) when it cannot open now.
func open_screen(n: StringName) -> bool:
	if n == &"controls":
		# The keys live one level down the pause page.
		if not open_screen(&"pause"):
			return false
		(screens[&"pause"] as UiPauseScreen).page = "keys"
		top().queue_redraw()
		return true
	if not screens.has(n):
		return false
	var s: UiScreen = screens[n]
	if s.is_open:
		return true
	if n != &"pause" and _hostile_near():
		Events.sfx.emit(&"refused", Vector3.ZERO)
		Events.message.emit("Not with that so close.")
		return false
	if n == &"crafting":
		var station := UiRules.station_near(game.query, game.player.pos)
		if station == &"" and game.options.ui_demo:
			station = &"fire"
		if station == &"":
			Events.sfx.emit(&"refused", Vector3.ZERO)
			Events.message.emit("Nothing to make things at here.")
			return false
		(s as UiCraftingScreen).station = station
	stack.append(s)
	s.open()
	_vertical.absorb(_device_dir(&"move_up", &"move_down"))
	_horizontal.absorb(_device_dir(&"move_left", &"move_right"))
	if n == &"pause":
		get_tree().paused = true
	game.hud.visible = false
	return true


func _on_closed(s: UiScreen) -> void:
	stack.erase(s)
	if s.screen_name == &"pause":
		get_tree().paused = false
	if stack.is_empty():
		game.hud.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var s := top()
	if s != null:
		for pair: Array in [[&"pause", &"back"], [&"use", &"confirm"], [&"swing", &"confirm"], [&"inventory", &"inventory"], [&"craft", &"craft"], [&"map", &"map"]]:
			if event.is_action_pressed(pair[0]):
				s.handle(pair[1])
				break
		get_viewport().set_input_as_handled()
		return
	var opens := {&"inventory": &"inventory", &"craft": &"crafting", &"map": &"map", &"pause": &"pause"}
	for action: StringName in opens:
		if event.is_action_pressed(action):
			open_screen(opens[action])
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	if game == null or game.world == null:
		return
	if _map_build_in > 0.0:
		_map_build_in -= delta
		if _map_build_in <= 0.0:
			map_data.build_async()
	if _pending_screen != "" and game.scripted_seconds <= 0.0:
		# --screen=NAME or NAME:ROW (a row id to choose, for shots).
		var parts := _pending_screen.split(":")
		if open_screen(StringName(parts[0])) and parts.size() > 1:
			top().select(StringName(parts[1]))
		_pending_screen = ""
	var s := top()
	if s != null:
		_repeat(s, _vertical, _device_dir(&"move_up", &"move_down"), delta, &"up", &"down")
		_repeat(s, _horizontal, _device_dir(&"move_left", &"move_right"), delta, &"left", &"right")
		return
	explored.visit(game.player.pos)
	_feed_hud()


func _repeat(s: UiScreen, r: UiMenu, dir: int, delta: float, neg: StringName, pos: StringName) -> void:
	for i in r.hold(dir, delta):
		s.handle(pos if dir > 0 else neg)


func _device_dir(neg: StringName, pos: StringName) -> int:
	return int(Input.is_action_pressed(pos)) - int(Input.is_action_pressed(neg))


func _feed_hud() -> void:
	var hud := game.hud
	var b := game.body
	hud.set_body(b.health, b.max_health, b.wind, b.max_wind)
	hud.set_held(game.inventory.held)
	hud.set_needs(UiRules.needs(b, game.clock.minutes, game.inventory.bulk()))
	var busy := Time.get_ticks_msec() / 1000.0 < b.busy_until
	if not UiRules.hint_allowed(busy, game.input_blocked(), get_tree().get_nodes_in_group(&"mobs"), game.player.pos):
		hud.set_hint("")
		return
	for sys in game.systems:
		if sys != self and sys.has_method("use_hint"):
			var h: Variant = sys.call("use_hint")
			if h is Dictionary:
				hud.set_hint(String(h.get("text", "")), String(h.get("key", "e")))
				return
	var prop := UiRules.use_target(game.query, game.player.pos, game.player.facing)
	if prop == null:
		hud.set_hint("")
	else:
		hud.set_hint(UiRules.prop_hint(prop.kind), UiRules.hint_key(prop.kind))


func _hostile_near() -> bool:
	return UiRules.hostile_near(get_tree().get_nodes_in_group(&"mobs"), game.player.pos)


## Shot staging for --ui-demo: a message on the line, a body that has been in
## a fight and gone without food, so every quiet element is visible.
func _demo() -> void:
	var b := game.body
	b.health = 8
	b.wind = 1500.0
	b.fed_until = game.clock.minutes - 240.0
	b.wet = 0.5
	if game.options.walk_seconds <= 0.0:
		_stand_by_something(24.0)
	game.hud.show_message("Took 2 timber.")
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
