extends GameSystem
## Puts machines and creatures on the coast around the player and takes them
## off again: the spawner's rolls, culling past 24 tiles, clearing the coast
## when the clock jumps, and a Mob node for every body in the simulation.
## The simulation itself (FightSim) is created here and stepped by 40_fight.

## A jump in the clock longer than this clears the coast (design-extract §7.4).
const JUMP_CLEARS := 30.0

var sim: FightSim
var moment: Moment
var spawner: Spawner
var coast: Coast
var _told_ms := -Racket.QUIET_MS
var _layer: Node3D


func setup(g: Game) -> void:
	super.setup(g)
	moment = Moment.new()
	moment.seed_value = g.world.seed_value
	_read_moment()
	var hero := Hero.new()
	hero.body = g.body
	hero.inventory = g.inventory
	hero.pos = g.player.pos
	hero.facing = g.player.facing
	sim = FightSim.new(g.world, g.query, hero, moment)
	sim.real_s = Time.get_ticks_msec() / 1000.0
	g.player.hero = hero
	g.player.sim = sim
	spawner = Spawner.new()
	spawner.view_height = g.camera.view_height
	_layer = Node3D.new()
	_layer.name = "mobs"
	g.add_child(_layer)
	coast = Coast.new(sim, spawner)
	coast.spawning = g.options.spawn.is_empty()
	Events.time_skipped.connect(_on_time_skipped)
	for k: String in g.options.spawn:
		place_near_player(Roster.resolve(k.strip_edges()))
	_ensure_nodes()


func _physics_process(_delta: float) -> void:
	if sim == null:
		return
	_read_moment()
	coast.tick()
	_listen()
	_ensure_nodes()


func _process(delta: float) -> void:
	if sim == null:
		return
	_ensure_nodes()
	var frozen := sim.hold
	for c in _layer.get_children():
		var mob := c as Mob
		if mob == null:
			continue
		if mob.state.removed:
			if not mob.state.alive and sim.now - mob.state.dead_at >= float(mob.state.stat("linger", 30.0)) * 1000.0 - 50.0:
				# A body that has lain its time comes apart where it lay, not in a blink.
				var dust := Palette.STONE[4] if mob.state.machine else Palette.SAND[4]
				MobFx.puffs(game, mob.global_position, Vector2.ZERO, dust, 3, 0.5 + mob.state.radius * 0.6, mob.state.id)
			mob.queue_free()
			continue
		mob.sync_view(0.0 if frozen else delta, sim.now, sim.hero.holder == mob.state)


## A machine heard and not yet seen: say so, once (Racket).
func _listen() -> void:
	var now_ms := float(Time.get_ticks_msec())
	var aerial := FightRules.wears(game.inventory, &"aerial")
	for m in sim.mobs:
		var visible := spawner.in_view(sim.hero.pos, m.pos, 0.0)
		if Racket.should_tell(m, sim.hero.pos, visible, aerial, now_ms, _told_ms):
			m.heard_told = true
			_told_ms = now_ms
			Events.message.emit(Racket.line_for(m))
		elif visible:
			# Seen first: nothing to tell about this one later.
			m.heard_told = true


func _ensure_nodes() -> void:
	for m in sim.mobs:
		if m.node == null and not m.removed:
			var mob := Mob.new()
			_layer.add_child(mob)
			mob.setup(m, game.world, game.view.world_material())


func _read_moment() -> void:
	moment.minutes = game.clock.minutes
	moment.lamp_lit = game.body.lamp_lit
	moment.filed = game.body.filed
	moment.laden_tier = FightRules.laden_tier(game.body.load)
	moment.running = game.player.intent_run and game.player.intent_move.length() > 0.1
	moment.read_weather()


func _on_time_skipped(minutes: float, _reason: StringName) -> void:
	if minutes > JUMP_CLEARS and sim != null:
		sim.clear_mobs()


## Put a body where the camera shows it, in front of the player, on ground it
## may stand on; facing the player. Used by --spawn for shots and by tests.
func place_near_player(kind: StringName) -> MobState:
	if kind == &"":
		return null
	var row := Roster.row(kind)
	var w := game.world
	var hp := sim.hero.pos
	var index := sim.mobs.size()
	var r: float = row.get("radius", 0.5)
	# Screen up and right of the player (world north): the body faces back toward
	# the camera side, so its front and the player's blow are both in view; several fan out.
	var ang := -PI * 0.5 + index * 0.9
	if float(row.get("height", 1.0)) < 1.0:
		# Low bodies go screen right instead, or the player would stand in front of them.
		ang = -PI * 0.25 + index * 0.9
	var dist := 1.6 + r + Tuning.PLAYER_RADIUS + 0.4
	if row.get("where", {}).get("rise", false):
		dist = 4.5
	var best := hp + Vector2.from_angle(ang) * dist
	var best_score := INF
	var keeps: Array = row.get("keeps_to", [])
	for ring in range(0, 24):
		for i in 24:
			var a := ang + float(i) / 24.0 * TAU
			var p := hp + Vector2.from_angle(a) * (dist + ring * 0.5)
			var tx := floori(p.x)
			var ty := floori(p.y)
			if not game.query.standable(tx, ty):
				continue
			if not keeps.is_empty() and not Spawner.ground_matches(w.ground_at(tx, ty), keeps):
				continue
			if keeps.is_empty() and Ground.is_water(w.ground_at(tx, ty)):
				continue
			var score := p.distance_to(hp + Vector2.from_angle(ang) * dist)
			if not keeps.is_empty() and Ground.is_water(w.ground_at(tx, ty)):
				score -= 8.0
			if row.get("where", {}).get("rise", false) and Spawner.is_rise(w, tx, ty):
				score -= 20.0
			if score < best_score:
				best_score = score
				best = p
	var m := sim.add_mob(kind, best)
	m.facing = (hp - best).angle()
	m.aim = m.facing
	return m
