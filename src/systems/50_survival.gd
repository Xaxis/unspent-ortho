extends GameSystem
## The player's survival in the running game: the strand near the spawn
## (Strand), the `use` key, the start kit, the body's condition every frame,
## regrowth, and the boot options that put the game into a survival state for
## shots (--give --held --use --build --put --hold).
## The rules live in src/core/survival/; this node only feeds them input and time.
##
## Keys: `use` works what is in front (else eats, sleeps or builds a fire, see
## Survival.use). `craft` makes the most sensible thing in reach, but only if no
## screen opened for the same key press (the ui package's crafting screen wins).
## A blow that lands on the player knocks the work out of their hands. Holding
## `use` keeps working the same thing while it still gives (a vein, a mussel rock).
##
## Screens find this node by method: eat(id) -> bool eats one through Survival.

## The start kit's knife is half worn. (source)
const START_EDGE := 5000

## Seconds between one take and the next while `use` is held: long enough to see it land.
const AGAIN_SECONDS := 0.15

var _craft_wait := -1
## Bots and tests hold `use` down without a device.
var scripted_use_held := false
var _again_prop: WorldProp = null
var _again_at := 0.0
var _screen_touched := false
var _screen_frame := -10
var _use_down := false
var _craft_down := false
## A press of `use` made while busy is tried once the hands are free, until this real second.
var _use_buffered_until := -1.0
const USE_BUFFER_SECONDS := 1.5


func setup(g: Game) -> void:
	super.setup(g)
	# The way in within a walk of the spawn, where the generator has not put it.
	Strand.lay(g)
	Crafting.bind(g)
	Survival.fixed_now = 0.0 if g.options.hold >= 0.0 else -1.0
	Survival.fixed_step = 0.0
	var state := SurvivalState.of(g)
	# The body woke an hour before the game opened.
	state.woke_at = g.clock.minutes - 60.0
	var inv := g.inventory
	if inv.has(&"knife") and inv.edge(&"knife") == 10000:
		inv.set_edge(&"knife", START_EDGE)
	# A lamp with one flask in it: the first night is lit, the second needs oil.
	if not inv.has(&"lamp"):
		inv.add(&"lamp")
	state.lamp_at = g.clock.minutes
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
	Events.hit.connect(_on_hit)
	_put_props(o.put)
	if o.build != "":
		Survival.build(g, StringName(o.build), true)
	if o.use:
		# A held shot holds the key too, so a vein can be caught worked right out.
		scripted_use_held = o.hold >= 0.0
		_face_nearest_workable()
		Survival.use(g)
	Survival.update_body(g)


## --put: props the generator may not place yet, set out in front for a shot:
## the first straight ahead in reach, the rest fanned round the player. With
## --taken they stand in a row across the screen instead, already taken, so a
## shot shows what each leaves behind.
func _put_props(kinds: PackedStringArray) -> void:
	var i := 0
	var across := Vector2(1, -1).normalized()
	if game.camera != null:
		var bx := game.camera.global_transform.basis.x
		across = Vector2(bx.x, bx.z).normalized()
	for name in kinds:
		var kind := PropKind.NAMES.find(name.replace("_", " "))
		if kind < 0:
			push_warning("--put: unknown prop kind %s" % name)
			continue
		var at: Vector2
		if game.options.taken:
			at = game.player.pos + across * (i - (kinds.size() - 1) * 0.5) * 1.5 + across.orthogonal() * 1.4
		else:
			var turn := [0.0, 1.1, -1.1, 2.2, -2.2, PI][i % 6] as float
			at = game.player.pos + Vector2.from_angle(game.player.facing + turn) * (0.75 + PropKind.SOLID[kind])
		var prop := Survival.add_prop(game, kind, at)
		if game.options.taken:
			_take_for_shot(prop)
		i += 1


func _take_for_shot(prop: WorldProp) -> void:
	var opts := Takes.options(prop.kind)
	var gone := false
	for o: Dictionary in opts:
		gone = gone or not o.keep
	if gone:
		game.world.depleted[prop.id] = INF
		game.view.refresh_props(prop)
		return
	var state := SurvivalState.of(game)
	for j in opts.size():
		state.spent[SurvivalState.key(prop.id, j)] = INF


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
		Survival.face(game, (best.pos - p).angle())


## Eat one `id` from the creel (the inventory screen calls this when it finds it).
func eat(id: StringName) -> bool:
	return Survival.eat(game, id)


func _on_hit(_attacker: Object, target: Object, damage: int, _plate: bool, _at: Vector3) -> void:
	if game == null or target == null or damage <= 0:
		return
	if target == game.player or target == game.player.hero:
		Survival.interrupt(game)


func _exit_tree() -> void:
	if Events.hit.is_connected(_on_hit):
		Events.hit.disconnect(_on_hit)
	if Events.screen_changed.is_connected(_on_screen_changed):
		Events.screen_changed.disconnect(_on_screen_changed)


func _on_screen_changed(_screen: StringName, _open: bool) -> void:
	_screen_touched = true
	_screen_frame = Engine.get_process_frames()


func _on_inventory_changed() -> void:
	if game.player.model != null and game.player.model.held != game.inventory.held:
		game.player.model.set_held(game.inventory.held)


## The keys are read as the edge of the action's held state, not from input events
## or "just pressed", so a press made by a device and one made by a tour
## (Input.action_press, at any point in a frame) take the same path. A press on the
## frame a screen opened or closed belongs to that screen.
func _read_keys() -> void:
	var use_down := Input.is_action_pressed("use")
	var craft_down := Input.is_action_pressed("craft")
	var use_pressed := use_down and not _use_down
	var craft_pressed := craft_down and not _craft_down
	_use_down = use_down
	_craft_down = craft_down
	if game.input_blocked() or Engine.get_process_frames() - _screen_frame <= 1:
		return
	if use_pressed:
		if Survival.busy(game) and game.body.grip <= 0:
			# Pressed while a take plays out: kept for the moment the hands are free.
			_use_buffered_until = Survival.now_real() + USE_BUFFER_SECONDS
		else:
			Survival.use(game)
	elif craft_pressed:
		_craft_wait = 2
		_screen_touched = false


func _process(delta: float) -> void:
	if game == null:
		return
	_read_keys()
	if _use_buffered_until > 0.0 and not Survival.busy(game) and not game.input_blocked():
		if Survival.now_real() <= _use_buffered_until:
			Survival.use(game)
		_use_buffered_until = -1.0
	if _craft_wait >= 0:
		_craft_wait -= 1
		# Only if no screen opened or closed on the same press: a crafting screen owns the
		# key; and never with a hostile close (the page refused already and said why).
		if _craft_wait < 0 and not _screen_touched and not game.input_blocked() and not Survival.busy(game) \
				and not Survival.threat_near(game):
			var r := Crafting.suggest(game)
			if not r.is_empty():
				Crafting.make_in(game, r)
	var hold := game.options.hold
	if hold >= 0.0:
		# A held shot: every frame is 1/60 s however long it took to draw, until the moment.
		Survival.fixed_step = minf(1.0 / 60.0, maxf(0.0, hold - Survival.fixed_now))
		Survival.fixed_now += Survival.fixed_step
		delta = Survival.fixed_step
	Survival.tick(game, delta)
	_again((scripted_use_held or Input.is_action_pressed("use")) and not game.input_blocked())


## Held `use`: once a take finishes, work the same prop again if it is still in
## front and will still give. Anything else (a refusal, a new target) ends it quietly.
func _again(held: bool) -> void:
	var job := SurvivalState.of(game).job
	if not job.is_empty():
		_again_prop = job.prop
		_again_at = Survival.now_real() + AGAIN_SECONDS
		return
	if _again_prop == null:
		return
	if not held:
		_again_prop = null
		return
	if Survival.now_real() < _again_at or Survival.busy(game):
		return
	var prop := _again_prop
	_again_prop = null
	if Survival.use_target(game) == prop and Survival.can_work(game, prop):
		Survival.work(game, prop)
