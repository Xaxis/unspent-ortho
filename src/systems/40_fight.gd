extends GameSystem
## The player's two verbs and what comes of them. Reads swing and dodge,
## steps the one simulation (created by 30_mobs) in fixed slices, and turns
## what happened in it into the world: Events, sounds, the hitstop, the
## camera's shake, dust and sparks, the clock's jumps and the lines on screen.
##
## Controls: swing on `swing` (Space, J); dodge on `dodge` (K at once; Shift
## as DodgeInput says, holding it still runs). Held, the swing key pulls.

const HITSTOP_HIT := 0.05
const HITSTOP_HURT := 0.06
const HITSTOP_KILL := 0.08

var sim: FightSim
var dodge_input := DodgeInput.new()
var _stop_until := 0.0
var _mend_from := 0.0
var _last_health := 0
## A shot's held moment: the simulation never steps again.
var _held := false


func setup(g: Game) -> void:
	super.setup(g)
	sim = g.player.sim
	if sim == null:
		return
	_mend_from = g.clock.minutes
	_last_health = g.body.health
	g.player.model.set_held(g.inventory.held)
	if g.options.act != "":
		_play_act(g.options.act)


func _unhandled_input(event: InputEvent) -> void:
	if sim == null or game.input_blocked() or _held:
		return
	if event.is_echo():
		return
	var key := event as InputEventKey
	var shift := key != null and (key.physical_keycode == KEY_SHIFT or key.keycode == KEY_SHIFT)
	if event.is_action_pressed(&"swing"):
		sim.press_swing()
	elif shift:
		var t := Time.get_ticks_msec()
		if key.pressed:
			if dodge_input.shift_pressed(t, _in_fight()):
				sim.press_dodge()
		elif dodge_input.shift_released(t):
			sim.press_dodge()
	elif event.is_action_pressed(&"dodge"):
		sim.press_dodge()


func _in_fight() -> bool:
	if sim.fight_on:
		return true
	for m in sim.mobs:
		if m.alive and m.roused() and Senses.chebyshev(m.pos, sim.hero.pos) <= 8.0:
			return true
	return false


func _physics_process(delta: float) -> void:
	if sim == null:
		return
	var now_s := Time.get_ticks_msec() / 1000.0
	var hero := sim.hero
	var player := game.player
	hero.move = player.intent_move
	hero.run = player.intent_run
	hero.walk_speed = Hero.ground_speed(game.world, hero.pos, false, game.body.move_factor)
	hero.run_speed = Hero.ground_speed(game.world, hero.pos, true, game.body.move_factor)
	sim.hold = _held or now_s < _stop_until
	if not sim.hold:
		sim.real_s = now_s
		sim.step(delta)
	_handle(sim.drain())
	_mend()


func _process(delta: float) -> void:
	if sim == null:
		return
	var frozen := sim.hold
	game.player.sync_view(0.0 if frozen else delta, frozen)
	game.player.draw_swing(sim.now)
	if game.player.model.held != game.inventory.held:
		game.player.model.set_held(game.inventory.held)


## One point of health back per hour of the world's clock, counted from the last hurt.
func _mend() -> void:
	var b := game.body
	if b.health < _last_health:
		_mend_from = game.clock.minutes
	_last_health = b.health
	if b.health >= b.max_health:
		_mend_from = game.clock.minutes
		return
	while game.clock.minutes - _mend_from >= FightRules.MEND_MINUTES and b.health < b.max_health:
		_mend_from += FightRules.MEND_MINUTES
		b.health += 1
	_last_health = b.health


func _stop(seconds: float) -> void:
	_stop_until = maxf(_stop_until, Time.get_ticks_msec() / 1000.0 + seconds)


func _at3(p: Vector2, lift: float = 0.0) -> Vector3:
	return game.world.to_3d(p) + Vector3(0, lift, 0)


func _node_of(f: Fighter) -> Object:
	if f == null:
		return null
	if f == sim.hero:
		return game.player
	return f.node


func _dust_colour(p: Vector2) -> Color:
	var g := game.world.ground_at(floori(p.x), floori(p.y))
	match g:
		Ground.WATER, Ground.RIVER, Ground.BLACKWATER:
			return Palette.BRINE[4]
		Ground.SNOW, Ground.ICE:
			return Palette.RIME[5]
		Ground.SAND:
			return Palette.SAND[4]
		Ground.ASH, Ground.CLINKER:
			return Palette.ASH[2]
		Ground.GRASS, Ground.MOSS, Ground.HEATH:
			return Palette.SAND[3]
	return Palette.ASH[3]


func _fx_parent() -> Node:
	return game


func _handle(events: Array[Dictionary]) -> void:
	var player := game.player
	var hero := sim.hero
	for e in events:
		match e.type:
			&"swing":
				var b := hero.blow
				Events.sfx.emit(&"swing", player.position)
				if b != null:
					player.model.play_action(&"swing", b.committed() / 1000.0)
			&"whiff":
				Events.sfx.emit(&"whiff", player.position)
			&"dodge":
				Events.sfx.emit(&"dodge", player.position)
				player.model.play_action(&"dodge", FightRules.DODGE_MS / 1000.0)
				MobFx.puff(_fx_parent(), _at3(hero.pos), -hero.dodge_dir, _dust_colour(hero.pos), 3, 0.14, int(sim.now))
			&"evaded":
				MobFx.puff(_fx_parent(), _at3(hero.pos), hero.dodge_dir, _dust_colour(hero.pos), 2, 0.1, int(sim.now) + 1)
			&"grip":
				var by: MobState = e.by
				Events.sfx.emit(&"grip", player.position)
				player.model.play_action(&"hurt", 0.25)
				player.shudder(0.2)
				game.camera.shake(0.08, 0.14)
				_stop(0.04)
				MobFx.ring(_fx_parent(), _at3(hero.pos), _dust_colour(hero.pos), 0.9, 0.35)
				if by != null and by.node is Mob:
					(by.node as Mob).flash(0.05)
			&"pull":
				Events.sfx.emit(&"pull", player.position)
				player.shudder(0.14)
				game.camera.shake(0.04, 0.08)
				var by: MobState = e.by
				var dir := (hero.pos - by.pos) if by != null else Vector2.ZERO
				MobFx.puff(_fx_parent(), _at3(hero.pos), dir, _dust_colour(hero.pos), 3, 0.13, int(sim.now))
			&"loose":
				Events.sfx.emit(&"loose", player.position)
				MobFx.puff(_fx_parent(), _at3(hero.pos), Vector2.ZERO, _dust_colour(hero.pos), 4, 0.15, int(sim.now) + 7)
			&"hit":
				_on_hit(e)
			&"hurt":
				_on_hurt(e)
			&"killed":
				_on_killed(e)
			&"second_act":
				var m: MobState = e.mob
				Events.sfx.emit(&"second_act", _at3(m.pos))
				if m.node is Mob:
					(m.node as Mob).flash(0.12)
				MobFx.spark(_fx_parent(), _at3(m.pos, m.row.get("height", 1.0) * 0.6), [Palette.LENS[3], Palette.EMBER[4]], 10, 0.5, m.id)
				game.camera.shake(0.06, 0.2)
			&"alerted":
				var m: MobState = e.mob
				Events.sfx.emit(StringName("alert_" + String(m.row.get("model", m.kind))), _at3(m.pos))
			&"called":
				var m: MobState = e.mob
				Events.sfx.emit(&"watcher_call", _at3(m.pos))
			&"snatch":
				_on_snatch(e.mob)
			&"filed":
				Snatch.file(game.body)
				Events.message.emit("Somewhere, what it read of you has been put away.")
			&"outcome":
				_on_outcome(e)


func _on_hit(e: Dictionary) -> void:
	var target: Fighter = e.target
	var attacker: Fighter = e.attacker
	var at: Vector2 = e.at
	var m := target as MobState
	var h: float = m.row.get("height", 1.0) if m != null else 1.0
	var from_dir := (target.pos - attacker.pos).normalized()
	var impact := _at3(target.pos - from_dir * target.radius * 0.8, h * 0.5)
	Events.hit.emit(_node_of(attacker), _node_of(target), int(e.damage), bool(e.plate), _at3(at))
	if e.plate:
		Events.sfx.emit(&"hit_plate", impact)
		MobFx.spark(_fx_parent(), impact, [Palette.COLD[3], Palette.COLD[2], Palette.STONE[5]], 5, 0.25, int(sim.now))
		game.camera.shake(0.025, 0.07)
		return
	Events.sfx.emit(&"hit_flesh", impact)
	_stop(HITSTOP_HIT)
	game.camera.shake(0.06, 0.12)
	var warm: Array[Color] = [Palette.LENS[3], Palette.LENS[2], Palette.LINEN[5]]
	if m != null and not m.machine:
		warm = [Palette.LINEN[5], Palette.FLESH[4], Palette.LINEN[4]]
	MobFx.spark(_fx_parent(), impact, warm, 7, 0.34, int(sim.now))
	MobFx.puff(_fx_parent(), _at3(target.pos), from_dir, _dust_colour(target.pos), 4, 0.17, int(sim.now) + 3)
	if target.node is Mob:
		var mob := target.node as Mob
		mob.flash(0.06)
		mob.flare()


func _on_hurt(e: Dictionary) -> void:
	var by: MobState = e.attacker
	var hero := sim.hero
	var player := game.player
	var dir := (hero.pos - by.pos).normalized() if by != null else Vector2.ZERO
	Events.hit.emit(_node_of(by), player, int(e.damage), false, _at3(hero.pos))
	Events.sfx.emit(&"hit_flesh", player.position)
	player.model.play_action(&"hurt", 0.3)
	player.flash(0.08)
	_stop(HITSTOP_HURT)
	game.camera.shake(0.12, 0.18)
	MobFx.puff(_fx_parent(), _at3(hero.pos), dir, _dust_colour(hero.pos), 5, 0.18, int(sim.now) + 5)
	MobFx.spark(_fx_parent(), _at3(hero.pos, 0.7), [Palette.LINEN[5], Palette.RUST[4]], 5, 0.3, int(sim.now) + 9)


func _on_killed(e: Dictionary) -> void:
	var m: MobState = e.mob
	var at := _at3(m.pos)
	Events.killed.emit(m.kind, at)
	Events.sfx.emit(&"killed", at)
	_stop(HITSTOP_KILL)
	game.camera.shake(0.1, 0.22)
	MobFx.puff(_fx_parent(), at, Vector2.ZERO, _dust_colour(m.pos), 7, 0.24, m.id)
	MobFx.ring(_fx_parent(), at, _dust_colour(m.pos), 1.4, 0.4)
	var drops: int = m.row.get("drops", 0)
	if m.machine and drops > 0:
		game.inventory.add(&"scrap", drops)
		Events.took.emit(&"scrap", drops)


func _on_snatch(m: MobState) -> void:
	var r := Snatch.apply(m.kind, game.body, game.inventory, game.clock.minutes)
	Events.sfx.emit(StringName("snatch_" + String(m.row.get("model", m.kind))), _at3(sim.hero.pos))
	if String(r.line) != "":
		Events.message.emit(String(r.line))
	if r.took != &"":
		Events.took.emit(r.took, -1)
	if float(r.minutes) > 0.0:
		var reason: StringName = &"arrested" if m.row.get("hits", {}).get("arrest", false) else &"snatched"
		game.clock.skip(float(r.minutes))
		Events.time_skipped.emit(float(r.minutes), reason)


func _on_outcome(e: Dictionary) -> void:
	var outcome: StringName = e.outcome
	var by: MobState = e.get("by", null)
	var player := game.player
	var hero := sim.hero
	Events.fight_ended.emit(outcome)
	match outcome:
		&"downed":
			var r := Outcomes.downed(game.body, game.clock, by.kind if by != null else &"")
			hero.health = game.body.health
			player.model.play_action(&"downed", 1.2)
			Events.time_skipped.emit(float(r.minutes), &"downed")
			Events.message.emit(String(r.line))
		&"carried":
			var r := Outcomes.carried(game.body, game.inventory, game.clock, game.world, game.query, hero.pos)
			hero.pos = r.pos
			hero.facing = r.facing
			hero.throw_until = 0.0
			player.sync_view(0.0)
			game.view.ensure_near(hero.pos)
			game.camera.snap_to(player.position)
			player.model.play_action(&"carried", 1.2)
			Events.time_skipped.emit(float(r.minutes), &"carried")
			Events.message.emit(String(r.line))


# --- held moments for shots (--act) -------------------------------------------

## Plays a moment of a fight against the first body --spawn placed, then holds
## it still so a shot shows it: swing (a blow reaching the working part),
## grip (a seizing bite closed and a pull against it), hurt, dodge (through a
## live bite), alert (the body registering the player).
func _play_act(spec: String) -> void:
	var parts := spec.split(":")
	var act := parts[0]
	var ms := parts[1].to_float() if parts.size() > 1 else -1.0
	var hero := sim.hero
	var target: MobState = sim.mobs[0] if not sim.mobs.is_empty() else null
	MobFx.hold = true
	if target != null:
		for m in sim.mobs:
			m.calm_until = INF
		hero.facing = (target.pos - hero.pos).angle()
		game.player.facing = hero.facing
	match act:
		"swing":
			if target != null:
				_stand_on_part_side(target)
			sim.press_swing()
			sim.slices(1)
			var b := hero.blow
			var until := ms if ms >= 0.0 else (b.windup + b.active * 0.6 if b != null else 100.0)
			_run_for(until)
		"grip":
			if target != null and target.bite != null:
				_bring_to_bite(target)
				target.start_blow(target.bite, sim.now)
				_run_for(target.bite.windup + target.bite.active)
				sim.slices(40)
				sim.press_swing()
				_run_for(ms if ms >= 0.0 else 60.0)
		"hurt":
			if target != null and target.bite != null:
				_bring_to_bite(target)
				target.start_blow(target.bite, sim.now)
				_run_for((target.bite.windup + target.bite.active * 0.5) + (ms if ms >= 0.0 else 40.0))
		"dodge":
			if target != null and target.bite != null:
				_bring_to_bite(target)
				target.start_blow(target.bite, sim.now)
				_run_for(maxf(0.0, target.bite.windup - 60.0))
				hero.move = Vector2.from_angle(hero.facing + PI * 0.5)
				sim.press_dodge()
				_run_for(ms if ms >= 0.0 else 90.0)
		"alert":
			for m in sim.mobs:
				m.calm_until = 0.0
			_run_for(ms if ms >= 0.0 else 1200.0)
		_:
			push_warning("unknown --act %s" % act)
	_handle(sim.drain())
	game.player.sync_view(0.0, true)
	_held = true
	sim.hold = true


func _run_for(ms: float) -> void:
	var n := maxi(0, roundi(ms / FightRules.SLICE_MS))
	var hero := sim.hero
	var move := hero.move
	for i in n:
		hero.move = move
		sim.slices(1)
		_handle(sim.drain())


## Put the player where the blow will reach the working part, facing the body.
func _stand_on_part_side(m: MobState) -> void:
	var hero := sim.hero
	var side := {&"front": 0.0, &"right": PI * 0.5, &"back": PI, &"left": -PI * 0.5}
	var off: float = side.get(m.part, 0.0)
	var dist := m.radius + hero.radius + Blow.for_item(game.inventory.held).reach * 0.6
	var cam_side := hero.pos - m.pos
	if m.part == &"none":
		off = wrapf(cam_side.angle() - m.facing, -PI, PI)
	var at := m.pos + Vector2.from_angle(m.facing + off) * dist
	if game.query.standable(floori(at.x), floori(at.y)):
		hero.pos = at
	hero.facing = (m.pos - hero.pos).angle()


## Face a body at the player and close to where its bite lands.
func _bring_to_bite(m: MobState) -> void:
	var hero := sim.hero
	var to := hero.pos - m.pos
	var d := m.radius + hero.radius + m.bite.reach * 0.6
	var at := m.pos + to.normalized() * d
	if game.query.standable(floori(at.x), floori(at.y)):
		hero.pos = at
	m.facing = (hero.pos - m.pos).angle()
	m.aim = m.facing
	hero.facing = (m.pos - hero.pos).angle()
