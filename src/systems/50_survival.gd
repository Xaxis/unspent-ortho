extends GameSystem
## The player's survival in the running game: the `use` key, the start kit,
## the body's condition every frame, regrowth, and the boot options that put
## the game into a survival state for shots (--give --held --use --build).
## The rules live in src/core/survival/; this node only feeds them input and time.
##
## Keys: `use` works what is in front (else sleeps, eats or builds a fire, see
## Survival.use). `craft` makes the most sensible thing in reach, but only if no
## screen opened for the same key press (the ui package's crafting screen wins).

## The start kit's knife is half worn. (source)
const START_EDGE := 5000

var _craft_wait := -1
var _screen_touched := false


func setup(g: Game) -> void:
	super.setup(g)
	var state := SurvivalState.of(g)
	# The body woke an hour before the game opened.
	state.woke_at = g.clock.minutes - 60.0
	var inv := g.inventory
	if inv.has(&"knife") and inv.edge(&"knife") == 10000:
		inv.set_edge(&"knife", START_EDGE)
	var o := g.options
	for id: StringName in o.give:
		if Items.def(id).is_empty():
			push_warning("--give: unknown item %s" % id)
			continue
		inv.add(id, int(o.give[id]))
	if o.held != "":
		var h := StringName(o.held)
		if not Items.def(h).is_empty() and not inv.has(h):
			inv.add(h)
		Survival.hold(g, h)
	elif g.player.model != null:
		g.player.model.set_held(inv.held)
	inv.changed.connect(_on_inventory_changed)
	Events.screen_changed.connect(_on_screen_changed)
	if o.build != "":
		Survival.build(g, StringName(o.build), true)
	if o.use:
		_face_nearest_workable()
		Survival.use(g)
	Survival.update_body(g)


func _face_nearest_workable() -> void:
	var p := game.player.pos
	var best: WorldProp = null
	var best_d := INF
	var only := PropKind.NAMES.find(game.options.use_kind) if game.options.use_kind != "" else -1
	for q in game.query.props_near(p, 3.0):
		if not Takes.workable(q.kind) or game.world.depleted.has(q.id) or (only >= 0 and q.kind != only):
			continue
		var d := q.pos.distance_to(p) - q.solid
		if d < best_d:
			best_d = d
			best = q
	if best != null:
		game.player.facing = (best.pos - p).angle()
		game.player.drive(Vector2.ZERO, false, 0.0)


func _on_screen_changed(_screen: StringName, _open: bool) -> void:
	_screen_touched = true


func _on_inventory_changed() -> void:
	if game.player.model != null and game.player.model.held != game.inventory.held:
		game.player.model.set_held(game.inventory.held)


func _unhandled_input(event: InputEvent) -> void:
	if game == null or game.input_blocked() or event.is_echo():
		return
	if event.is_action_pressed("use"):
		Survival.use(game)
	elif event.is_action_pressed("craft"):
		_craft_wait = 2
		_screen_touched = false


func _process(delta: float) -> void:
	if game == null:
		return
	if _craft_wait >= 0:
		_craft_wait -= 1
		# Only if no screen opened or closed on the same press: a crafting screen owns the key.
		if _craft_wait < 0 and not _screen_touched and not game.input_blocked() and not Survival.busy(game):
			var r := Crafting.suggest(game)
			if not r.is_empty():
				Crafting.make_in(game, r)
	Survival.tick(game, delta)
