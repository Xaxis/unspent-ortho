extends GameSystem
## The player's two verbs and what comes of them. Reads swing and dodge,
## steps the one simulation (created by 30_mobs) in fixed slices, and turns
## what happened in it into the world: Events, sounds, the hitstop, the
## camera's shake, the ink marks (MobFx), the clock's jumps and the lines on screen.
##
## Controls: swing on `swing` (J, a click), thrown as the key comes up; held
## FightRules.HEAVY_HOLD_MS it is the heavy blow instead, thrown as the hold
## is reached. Dodge on `dodge` (K or the thumb button at once; Shift as
## DodgeInput says, holding it still runs). Pressed while held, swing pulls, at once. The keys are ControlScheme's; a lock (Hero.lock)
## decides where a swing and a dodge go, inside the simulation.

const HITSTOP_HIT := 0.05
const HITSTOP_HURT := 0.06
const HITSTOP_KILL := 0.08
## Seconds a body lies before it gets up after being downed or carried off.
const WAKE_SECONDS := 1.6
## Seconds between the struggle's marks while held.
const STRUGGLE_BEAT := 0.4
## Said the first time in a game a worker warns someone holding it up.
const CROWD_LINE := "It will not go round you. Step out of its path."

var sim: FightSim
var dodge_input := DodgeInput.new()
var _shift_down := false
var _stop_until := 0.0
var _struggle_t := 0.0
var _mend_from := 0.0
var _last_health := 0
## Simulation ms at which a dodge in progress lands (its dust is drawn then), or -1.
var _land_at := -1.0
## A shot's held moment: the simulation never steps again.
var _held := false
## Where a held moment keeps the camera (the game points it at the player every frame).
var _focus := Vector3.ZERO
var _crowd_told := false
## Seconds the swing key has been down, while it is down and nothing is thrown
## yet (-1 otherwise). Counted in the frames' own time, so a hold is the same
## length to the fight whatever the frame rate, a fixed-rate tour's included.
var _swing_held := -1.0
## Simulation ms a heavy blow's drawn-back pose is let go into the strike, or -1.
var _heavy_let_go := -1.0
var _heavy_blow: Blow = null


func setup(g: Game) -> void:
	super.setup(g)
	sim = g.player.sim
	if sim == null:
		return
	_mend_from = g.clock.minutes
	_last_health = g.body.health
	_keep_texel()
	MobFx.warm(g, g.player.position)
	g.player.model.set_held(g.inventory.held)
	if g.options.act != "":
		_play_act(g.options.act)


## Read by polling the actions, not from input events, so the real bindings,
## a tour's pressed actions and a bot all reach the same verbs. Shift's own
## edges are watched for DodgeInput; the dodge action pressed without Shift
## down (K, or an action pressed by a tour) dodges at once.
func _read_input(delta: float) -> void:
	var shift := Input.is_physical_key_pressed(KEY_SHIFT)
	var t := Time.get_ticks_msec()
	var blocked := game.input_blocked() or _held
	if shift != _shift_down:
		_shift_down = shift
		if not blocked:
			if shift:
				if dodge_input.shift_pressed(t, _in_fight()):
					sim.press_dodge()
			elif dodge_input.shift_released(t):
				sim.press_dodge()
	if blocked:
		_swing_held = -1.0
		return
	# A tap is a swing and a hold is the heavy blow, so the swing is thrown when
	# the key comes up, or when the hold is long enough, whichever is first. Over
	# the shoulder it goes where the camera looks (NAN elsewhere, which keeps the
	# swing's own rule). Held by something, the key wrenches at once.
	if Input.is_action_just_pressed(&"swing"):
		if sim.hero.held():
			sim.press_swing()
		else:
			_swing_held = 0.0
	elif _swing_held >= 0.0:
		_swing_held += delta
	if _swing_held >= 0.0:
		if not Input.is_action_pressed(&"swing"):
			_swing_held = -1.0
			sim.press_swing(game.camera.aim())
		elif _swing_held * 1000.0 >= FightRules.HEAVY_HOLD_MS:
			_swing_held = -1.0
			sim.press_heavy(game.camera.aim())
	if Input.is_action_just_pressed(&"dodge") and not shift:
		sim.press_dodge()


func _in_fight() -> bool:
	if sim.fight_on:
		return true
	for m in sim.mobs:
		if m.alive and m.roused() and Senses.chebyshev(m.pos, sim.hero.pos) <= FightRules.AWAY_DISTANCE:
			return true
	return false


func _physics_process(delta: float) -> void:
	if sim == null:
		return
	_read_input(delta)
	var now_s := Time.get_ticks_msec() / 1000.0
	var hero := sim.hero
	var player := game.player
	hero.move = player.intent_move
	hero.run = player.intent_run
	hero.walk_speed = Hero.ground_speed(game.world, hero.pos, false, game.body.move_factor, hero.ride)
	hero.run_speed = Hero.ground_speed(game.world, hero.pos, true, game.body.move_factor, hero.ride)
	sim.hold = _held or now_s < _stop_until
	if not sim.hold:
		sim.real_s = now_s
		sim.step(delta)
	_handle(sim.drain())
	_landing()
	_mend()


func _process(delta: float) -> void:
	if sim == null:
		return
	_keep_texel()
	if _held:
		game.camera.snap_to(_focus)
	var frozen := sim.hold
	game.player.sync_view(0.0 if frozen else delta, frozen)
	game.player.draw_swing(sim.now)
	if _heavy_let_go >= 0.0 and sim.now >= _heavy_let_go:
		_let_go()
	if sim.hero.held() and not frozen:
		# The struggle, drawn: a dashed ring at the feet on a beat while something has hold.
		_struggle_t -= delta
		if _struggle_t <= 0.0:
			_struggle_t = STRUGGLE_BEAT
			MobFx.ring(_fx_parent(), _at3(sim.hero.pos), Palette.INK[1], 0.55, 0.28)
	else:
		_struggle_t = 0.0
	if game.player.model.held != game.inventory.held:
		game.player.model.set_held(game.inventory.held)


## Marks are sized in pixels of the frame the camera players actually have, and
## it is the rig's LIVE `size` that says so, never its `view_height`. A target
## lock leans the camera in and out (42_target's LOCK_ZOOM 0.86 and SWEEP_ZOOM
## 1.14), and `size` is what the rig itself divides by rows for its own texel --
## so for the whole time `z` is held, which is exactly when a player is reading a
## machine and deciding whether to fight it, every mark's floor was being worked
## out against a camera nobody was looking through, by up to a seventh either way.
func _keep_texel() -> void:
	if not game.camera.is_inside_tree():
		MobFx.texel = game.camera.view_height / float(UiBase.SIZE.y)
		return
	MobFx.texel = game.camera.units_per_pixel()


## The camera's up on screen, as a world direction (a tell stands above a body along it).
func _screen_up() -> Vector3:
	return game.camera.global_transform.basis.y if game.camera.is_inside_tree() else Vector3.UP


## A dodge's dust is thrown where it lands, after the body has gone from where it
## started: drawn at the start it merged with the speed lines into one glyph.
func _landing() -> void:
	if _land_at < 0.0 or sim.now < _land_at:
		return
	_land_at = -1.0
	var hero := sim.hero
	MobFx.puff(_fx_parent(), _at3(hero.pos + hero.dodge_dir * 0.15), hero.dodge_dir, _dust_colour(hero.pos), 0.5, int(sim.now) + 2)


## The heavy blow's tell, the player's own: the tool held drawn back for the
## extra windup (PersonAnim.heavy_wind: turned away, the arm up and back), a fan
## of strokes thrown up off the body for as long, and the drive's sound. Then it
## is let go into the ordinary strike from the swing's own cock (`_let_go`). No
## ground ring: a ring on the ground is where a machine's bite will land, and
## only that.
func _heavy_windup(b: Blow) -> void:
	var player := game.player
	player.model.play_action(&"heavy", FightRules.HEAVY_WINDUP_MS / 1000.0)
	_heavy_let_go = sim.now + FightRules.HEAVY_WINDUP_MS
	_heavy_blow = b
	Events.sfx.emit(&"windup", player.position)
	MobFx.tell(player, player.model_centre(), _screen_up(), FightRules.HEAVY_WINDUP_MS / 1000.0, int(sim.now), 0.7, MobFx.FLICK_UP)


## The held heavy blow goes: the swing plays on from its cock, unless a hurt took
## the blow away in the meantime, in which case the hurt's own pose stands.
func _let_go() -> void:
	_heavy_let_go = -1.0
	var b := _heavy_blow
	_heavy_blow = null
	if b == null or sim.hero.blow != b:
		return
	Events.sfx.emit(&"swing", game.player.position)
	var light_windup := (b.windup - FightRules.HEAVY_WINDUP_MS) / 1000.0
	var light_len := (b.committed() - FightRules.HEAVY_WINDUP_MS) / 1000.0
	game.player.model.pose_at(&"swing", light_windup, light_len)
	game.player.model.unfreeze()


## One point of health back per hour of the world's clock, counted from the last
## hurt; four an hour by a fire.
func _mend() -> void:
	var b := game.body
	if b.health < _last_health:
		_mend_from = game.clock.minutes
	_last_health = b.health
	if b.health >= b.max_health:
		_mend_from = game.clock.minutes
		return
	var per := FightRules.mend_minutes(Survival.fire_near(game) != null)
	while game.clock.minutes - _mend_from >= per and b.health < b.max_health:
		_mend_from += per
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


## Dust is the ground's own wash thrown up, a step paler.
func _dust_colour(p: Vector2) -> Color:
	var g := game.world.ground_at(floori(p.x), floori(p.y))
	match g:
		Ground.WATER, Ground.RIVER, Ground.BLACKWATER, Ground.DEEP_WATER:
			return Palette.BRINE[5]
		Ground.SNOW, Ground.ICE:
			return Palette.RIME[5]
		Ground.SAND, Ground.SHINGLE:
			return Palette.SAND[5]
		Ground.ASH, Ground.CLINKER:
			return Palette.ASH[3]
		Ground.LIMESTONE, Ground.BONE:
			return Palette.LINEN[5]
		Ground.MUD, Ground.PEAT, Ground.NEEDLES, Ground.ROAD:
			return Palette.EARTH[4]
		Ground.GRASS, Ground.MOSS, Ground.HEATH:
			return Palette.SAND[4]
	return Palette.STONE[4]


func _fx_parent() -> Node:
	return game


## The working part's place in the world, or the body's middle.
func _part_at(m: MobState) -> Vector3:
	if m.node is Mob:
		return (m.node as Mob).part_position()
	return _at3(m.pos, float(m.row.get("height", 1.0)) * 0.5)


func _handle(events: Array[Dictionary]) -> void:
	var player := game.player
	var hero := sim.hero
	var fx := _fx_parent()
	for e in events:
		match e.type:
			&"swing":
				var b := hero.blow
				if b != null and b.heavy:
					_heavy_windup(b)
				else:
					Events.sfx.emit(&"swing", player.position)
					if b != null:
						player.model.play_action(&"swing", b.committed() / 1000.0)
			&"drop_strike":
				# Came down on it: the swing is thrown from the landing, and the ground
				# under the feet takes the weight in one ring of its own dust.
				var b := hero.blow
				Events.sfx.emit(&"swing", player.position)
				if b != null:
					player.model.play_action(&"swing", b.committed() / 1000.0)
				MobFx.ring(fx, _at3(hero.pos), _dust_colour(hero.pos), 0.9, 0.3)
				game.camera.shake(0.05, 0.1)
			&"dulled":
				Events.message.emit(FightRules.DULL_LINE)
			&"opened":
				# Its bite went past: the drive lets go audibly and the part catches the
				# light, so the window to strike is heard and seen, not only timed.
				var m: MobState = e.mob
				Events.sfx.emit(&"loose", _at3(m.pos))
				MobFx.glint(fx, _part_at(m), Palette.LENS[3], m.id + int(sim.now), 0.55)
			&"crowded":
				# A worker stopped by someone standing in its way: it says so before it acts.
				var m: MobState = e.mob
				Events.sfx.emit(&"alert", _at3(m.pos))
				if not _crowd_told:
					# The first time in a game, said as it stops, with the time to act on it.
					_crowd_told = true
					Events.message.emit(CROWD_LINE)
			&"crowd_warning":
				# Half way to taking it as interference: its part flares and a ring goes out from it.
				var m: MobState = e.mob
				Events.sfx.emit(&"alert", _at3(m.pos))
				MobFx.glint(fx, _part_at(m), Palette.LENS[3], m.id + int(sim.now), 0.7)
				MobFx.ring(fx, _at3(m.pos), Palette.INK[1], m.radius + 0.9, 0.4)
				if m.node is Mob:
					(m.node as Mob).flash(0.08)
			&"disturbed":
				var m: MobState = e.mob
				Events.sfx.emit(&"second_act", _at3(m.pos))
				MobFx.glint(fx, _part_at(m), Palette.LENS[3], m.id, 0.7)
			&"whiff":
				Events.sfx.emit(&"whiff", player.position)
			&"dodge":
				Events.sfx.emit(&"dodge", player.position)
				player.model.play_action(&"dodge", FightRules.DODGE_MS / 1000.0)
				# The lines trail from one body width behind where it set off: the
				# body shoots away from them, and nothing else is drawn there.
				MobFx.streak(fx, _at3(hero.pos - hero.dodge_dir * hero.radius * 2.0, 0.5), hero.dodge_dir, game.camera.yaw_now(), game.camera.pitch_deg, int(sim.now))
				_land_at = sim.now + FightRules.DODGE_MS
			&"evaded":
				# Heard, not drawn (a mark here lands on the speed lines): its blow met air.
				var by: MobState = e.by
				Events.sfx.emit(&"whiff", _at3(by.pos) if by != null else player.position)
			&"grip":
				var by: MobState = e.by
				Events.sfx.emit(&"grip", player.position)
				player.model.play_action(&"hurt", 0.25)
				player.shudder(0.2)
				game.camera.shake(0.08, 0.14)
				_stop(0.04)
				MobFx.ring(fx, _at3(hero.pos), Palette.INK[1], 0.8, 0.3)
				if by != null:
					# The jaw closing is drawn like a blow, though it does no harm.
					var jaw := by.pos + Vector2.from_angle(by.facing) * by.radius
					MobFx.burst(fx, _at3(jaw.lerp(hero.pos, 0.4), 0.35), 0.8, by.id + int(sim.now))
					MobFx.puffs(fx, _at3(by.pos.lerp(hero.pos, 0.6)), hero.pos - by.pos, _dust_colour(hero.pos), 3, 0.6, by.id)
					if by.node is Mob:
						(by.node as Mob).flash(0.05)
			&"pull":
				Events.sfx.emit(&"pull", player.position)
				player.shudder(0.14)
				game.camera.shake(0.04, 0.08)
				var by: MobState = e.by
				var dir := (hero.pos - by.pos) if by != null else Vector2.ZERO
				MobFx.puff(fx, _at3(hero.pos), dir, _dust_colour(hero.pos), 0.5, int(sim.now))
			&"loose":
				Events.sfx.emit(&"loose", player.position)
				MobFx.puffs(fx, _at3(hero.pos), Vector2.ZERO, _dust_colour(hero.pos), 3, 0.55, int(sim.now) + 7)
			&"hit":
				_on_hit(e)
			&"struck":
				_on_struck(e)
			&"rake":
				_rake_marks(e)
			&"grip_failed":
				# The anchor held (FightKit.anchor): the grip rang off a body that
				# would not be taken, and the ground round the feet says why.
				_grip_failed_at = Time.get_ticks_msec() / 1000.0
				MobFx.clang(fx, _at3(hero.pos, 0.9), int(sim.now))
				MobFx.ring(fx, _at3(hero.pos), Palette.STONE[4], hero.radius + 0.5, 0.4)
				Events.sfx.emit(&"hit_plate", player.position)
			&"hurt":
				_on_hurt(e)
			&"killed":
				_on_killed(e)
			&"second_act":
				var m: MobState = e.mob
				Events.sfx.emit(&"second_act", _at3(m.pos))
				if m.node is Mob:
					(m.node as Mob).flash(0.12)
				MobFx.glint(fx, _part_at(m), Palette.LENS[3], m.id, 0.8)
				MobFx.ring(fx, _at3(m.pos), Palette.INK[1], m.radius + 1.2, 0.45)
				game.camera.shake(0.06, 0.2)
			&"alerted":
				var m: MobState = e.mob
				Events.sfx.emit(&"alert", _at3(m.pos))
				if m.row.get("sight_only", false):
					# The lens catches the light as it finds you: the only warning it gives by eye.
					MobFx.glint(fx, _part_at(m), Palette.LENS[3], m.id, 0.6)
			&"windup":
				var m: MobState = e.mob
				Events.sfx.emit(&"windup", _at3(m.pos))
				if m.blow != null and m.node is Mob:
					# Over the WORKING PART, flicked down at it. The tell has to
					# send the eye to the side that opens — the side that hurts
					# you and the side you have to hit; three ticks floating over
					# the hull sent it to the roof while the comb was at the floor.
					# Hung on the MODEL, which is the thing that turns (Mob keeps the
					# lean and the heave; the model carries the facing). On the mob
					# node the mark would sit still while the machine swung round to
					# face you, and end up over its back.
					var mob := m.node as Mob
					var up := _screen_up()
					var on: Node = mob.model if mob.model != null else mob
					MobFx.tell(on, _part_at(m), up, m.blow.windup / 1000.0, m.id, 0.6 + m.radius * 0.5, MobFx.FLICK_DOWN)
				if m.blow != null:
					# And on the ground, where it will land: the pose is small over the
					# shoulder and a ring reads from above and behind alike. It lasts the
					# windup, so it is gone the instant the bite is down.
					# A thrown blow is told by its lane: a ring that long would mark the
					# ground either side of it, which is where a player has to go.
					if m.blow.area and m.drop_at.is_finite():
						# Coming down from above: its shadow, growing where it lands.
						var spot := FightRules.tell_drop(m.drop_at, m.radius, m.blow, sim.hero.radius)
						MobFx.tell_drop(fx, _at3(Vector2(spot.x, spot.y)), Palette.LINEN[5], spot.z, m.blow.windup / 1000.0)
					elif FightRules.throws(m.blow):
						var lane := FightRules.tell_lane(m.pos, m.radius, m.blow, sim.hero.radius)
						MobFx.tell_line(fx, _at3(Vector2(lane.x, lane.y)), m.facing, lane.z, lane.w, Palette.LINEN[5], m.blow.windup / 1000.0)
					else:
						var ring := FightRules.tell_ring(m.pos, m.facing, m.radius, m.blow)
						MobFx.tell_ring(fx, _at3(Vector2(ring.x, ring.y)), Palette.LINEN[5], ring.z, m.blow.windup / 1000.0)
			&"charge":
				var m: MobState = e.mob
				MobFx.puffs(fx, _at3(m.pos - m.bearing * m.radius), -m.bearing, _dust_colour(m.pos), 2, 0.5 + m.radius * 0.4, m.id + int(sim.now))
			&"called":
				var m: MobState = e.mob
				Events.sfx.emit(&"watcher_call", _at3(m.pos))
			&"snatch":
				_on_snatch(e.mob)
			&"filed":
				# Nothing is said: machines seeing further is what the player notices.
				Snatch.file(game.body)
			&"holding":
				if bool(e.get("seen", false)):
					Events.ring_held.emit((e.mob as MobState).kind)
			&"outcome":
				_on_outcome(e)


func _on_hit(e: Dictionary) -> void:
	var target: Fighter = e.target
	var attacker: Fighter = e.attacker
	var at: Vector2 = e.at
	var m := target as MobState
	var h: float = m.row.get("height", 1.0) if m != null else 1.0
	var from_dir := (target.pos - attacker.pos).normalized()
	# Where the blow met the body: the near edge of it, at the height of the blow.
	var gap := attacker.pos.distance_to(target.pos)
	var meet := attacker.pos + from_dir * clampf(gap - target.radius, attacker.radius, gap)
	var impact := _at3(meet, clampf(h * 0.5, 0.35, 0.7))
	var fx := _fx_parent()
	Events.hit.emit(_node_of(attacker), _node_of(target), int(e.damage), bool(e.plate), _at3(at))
	if e.plate:
		Events.sfx.emit(&"hit_plate", impact)
		MobFx.clang(fx, impact, int(sim.now), target.radius * 2.0)
		game.camera.shake(0.025, 0.07)
		return
	Events.sfx.emit(&"hit_flesh", impact)
	_stop(HITSTOP_HIT)
	game.camera.shake(0.06, 0.12)
	if m != null and m.machine:
		# The blow is in the working part: the burst is drawn over it, and it flares
		# (Mob). A machine is not knocked about, so no dust: one mark, read at a glance.
		# Lifted a little up the screen, so the swinger's own body is not under it.
		MobFx.burst(fx, _part_at(m) + _screen_up() * MobFx.pen_px(6.0), 1.1, int(sim.now), Palette.LENS[3], m.radius * 2.0)
	else:
		MobFx.burst(fx, impact, 0.8, int(sim.now), Color(0, 0, 0, 0), target.radius * 2.0)
		MobFx.puff(fx, _at3(target.pos), from_dir, _dust_colour(target.pos), 0.6, int(sim.now) + 3)
	if target.node is Mob:
		# The part's flare follows from the state (Mob.sync_view), in its order.
		(target.node as Mob).flash(0.06)


## A blow that was not the player's (FightSim.strike: a turret). Seen and heard
## where it landed and nowhere else: no hitstop and no shake, because the
## player's hands did nothing, and no `Events.hit`, because every reader of that
## signal means the player struck something.
## A lattice discharge (FightKit.lattice): a crackle from the body struck to the
## one it jumped to, three kinked strokes of cold light for a fifth of a second,
## so the player sees why a machine they never touched took the hit. A line
## (MobFx.line) keeps its pixel width at both cameras.
func _crackle(from: Vector2, m: MobState, h: float) -> void:
	var fx := _fx_parent()
	var y := clampf(h * 0.5, 0.35, 0.7)
	var a := _at3(from, y)
	var b := _at3(m.pos, y)
	var side := Vector3(-(b - a).z, 0.0, (b - a).x).normalized()
	var pts: Array[Vector3] = [a]
	for k in 2:
		var t := (float(k) + 1.0) / 3.0
		var kink := (Rng.hash01(m.id, int(sim.now), k) - 0.5) * 0.7
		pts.append(a.lerp(b, t) + side * kink + Vector3(0.0, kink * 0.3, 0.0))
	pts.append(b)
	for k in 3:
		MobFx.line(fx, pts[k], pts[k + 1], Palette.COLD[3], 0.2)


## Real second the last rake was drawn, and the last grip failed on an anchored
## player, for the tour's `raked` and `grip_failed`.
var _raked_at := -INF
var _grip_failed_at := -INF


## `raked`: a rake's tines are on the ground now (they stand 0.35 s);
## `grip_failed`: a grip rang off a rooted player just now.
func tour_seen(what: StringName) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	match what:
		&"raked":
			return now - _raked_at < 0.35
		&"grip_failed":
			return now - _grip_failed_at < 0.4
	return false


## A rake (FightKit.rake): the tines drawn across the ground ahead, five short
## strokes fanned over the arc, and a glint on the part of every body it holds
## open, so the player sees what the heavy has opened before it comes down.
func _rake_marks(e: Dictionary) -> void:
	_raked_at = Time.get_ticks_msec() / 1000.0
	var fx := _fx_parent()
	var from: Vector2 = e.from
	var facing: float = e.facing
	for k in 5:
		var a := facing + FightKit.RAKE_ARC * (float(k) / 2.0 - 1.0)
		var dir := Vector2.from_angle(a)
		MobFx.line(fx, _at3(from + dir * 1.0, 0.06), _at3(from + dir * FightKit.RAKE_REACH, 0.06), Palette.LINEN[4], 0.35)
	for m: MobState in (e.bodies as Array):
		MobFx.glint(fx, _part_at(m), Palette.LENS[3], m.id, 0.7)
	Events.sfx.emit(&"hit_plate", _at3(from))


func _on_struck(e: Dictionary) -> void:
	var m := e.target as MobState
	if m == null:
		return
	var from: Vector2 = e.from
	var fx := _fx_parent()
	var h: float = m.row.get("height", 1.0)
	if bool(e.get("arc", false)):
		_crackle(from, m, h)
	var dir := (m.pos - from).normalized()
	var impact := _at3(m.pos - dir * m.radius, clampf(h * 0.5, 0.35, 0.7))
	if e.plate:
		Events.sfx.emit(&"hit_plate", impact)
		MobFx.clang(fx, impact, int(sim.now), m.radius * 2.0)
		return
	Events.sfx.emit(&"hit_flesh", impact)
	if m.machine:
		MobFx.burst(fx, _part_at(m), 0.9, int(sim.now), Palette.LENS[3])
	else:
		MobFx.burst(fx, impact, 0.7, int(sim.now))
	if m.node is Mob:
		(m.node as Mob).flash(0.06)


func _on_hurt(e: Dictionary) -> void:
	var by: MobState = e.attacker
	var hero := sim.hero
	var player := game.player
	var fx := _fx_parent()
	var dir := (hero.pos - by.pos).normalized() if by != null else Vector2.ZERO
	Events.hit.emit(_node_of(by), player, int(e.damage), false, _at3(hero.pos))
	Events.sfx.emit(&"hit_flesh", player.position)
	player.model.play_action(&"hurt", 0.3)
	# Where the blow came from, so the flash goes hot on the side it landed on
	# rather than over the whole body (Player.flash).
	player.flash(0.08, _at3(hero.pos - dir * 0.35, 0.9))
	_stop(HITSTOP_HURT)
	game.camera.shake(0.12, 0.18)
	MobFx.burst(fx, _at3(hero.pos - dir * 0.15, 0.75), 0.9, int(sim.now) + 9)
	MobFx.puffs(fx, _at3(hero.pos), dir, _dust_colour(hero.pos), 2, 0.6, int(sim.now) + 5)


func _on_killed(e: Dictionary) -> void:
	var m: MobState = e.mob
	var at := _at3(m.pos)
	var fx := _fx_parent()
	Events.killed.emit(m.kind, at)
	if m.machine:
		Events.sfx.emit(&"machine_down", at)
		# Its light goes out with a click and a puff of its own smoke off the part:
		# heard and seen apart from the blow that did it.
		Events.sfx.emit(&"lamp_off", _part_at(m))
		MobFx.puff(fx, _part_at(m), Vector2.ZERO, Palette.STONE[3], 0.7, m.id + 11)
	var by_player := bool(e.get("by_player", true))
	if by_player:
		_stop(HITSTOP_KILL)
		game.camera.shake(0.1, 0.22)
	MobFx.puffs(fx, at, Vector2.ZERO, _dust_colour(m.pos), 5, 0.5 + m.radius * 0.6, m.id)
	MobFx.ring(fx, at, Palette.INK[1], m.radius + 1.0, 0.4)
	var drops: int = m.row.get("drops", 0)
	# A kill somebody else made (a turret in the yard) puts nothing in the
	# player's hands: what is left of it lies where it fell.
	if m.machine and drops > 0 and by_player:
		game.inventory.add(&"scrap", drops)
		Events.took.emit(&"scrap", drops)


func _on_snatch(m: MobState) -> void:
	var r := Snatch.apply(m.kind, game.body, game.inventory, game.clock.minutes)
	Events.sfx.emit(&"snatch", _at3(sim.hero.pos))
	# It came in close and went: dust where it turned, and a flicker over the player.
	var fx := _fx_parent()
	MobFx.puffs(fx, _at3(m.pos.lerp(sim.hero.pos, 0.5)), m.pos - sim.hero.pos, _dust_colour(sim.hero.pos), 2, 0.5, m.id)
	MobFx.tell(game.player, game.player.global_position + Vector3(0, 1.7, 0), _screen_up(), 0.25, m.id, 0.7)
	if String(r.line) != "":
		Events.message.emit(String(r.line))
	var arrest: bool = m.row.get("hits", {}).get("arrest", false)
	if float(r.minutes) > 0.0:
		var reason: StringName = &"arrested" if arrest else &"snatched"
		game.clock.skip(float(r.minutes))
		Events.time_skipped.emit(float(r.minutes), reason)
	if arrest:
		# Stood at the side of the track, as the line says: the hours pass off it.
		var off := Outcomes.off_the_track(game.world, game.query, sim.hero.pos)
		if off.moved:
			_put_hero(off.pos, sim.hero.facing)


func _on_outcome(e: Dictionary) -> void:
	var outcome: StringName = e.outcome
	var by: MobState = e.get("by", null)
	var player := game.player
	var hero := sim.hero
	Events.fight_ended.emit(outcome)
	if game.options.fail_downed and (outcome == &"downed" or outcome == &"carried"):
		printerr("ERROR fight: the player was %s (--fail-downed)" % outcome)
		get_tree().quit(1)
	match outcome:
		&"downed":
			var r := Outcomes.downed(game.body, game.clock, by.kind if by != null else &"")
			hero.health = game.body.health
			_wake()
			Events.sfx.emit(&"downed", player.position)
			Events.time_skipped.emit(float(r.minutes), &"downed")
			Events.message.emit(String(r.line))
		&"carried":
			var taken_at := hero.pos
			var r := Outcomes.carried(game.body, game.inventory, game.clock, game.world, game.query, hero.pos)
			var bag := Survival.leave_bag(game, taken_at)
			var home := Outcomes.home_hearth(_holdings(), taken_at, game.world, game.query)
			if not home.is_empty():
				r.pos = home.pos
				r.facing = home.facing
				r.line = HOME_LINE
			hero.pos = r.pos
			hero.facing = r.facing
			hero.throw_until = 0.0
			player.sync_view(0.0)
			game.view.ensure_near(hero.pos)
			game.camera.snap_to(player.position)
			_wake()
			Events.time_skipped.emit(float(r.minutes), &"carried")
			Events.message.emit(String(r.line))
			if bag != null:
				Events.message.emit(Survival.BAG_LINE)


## `near bag`: beside the heap the last bad end left (Survival.leave_bag), a
## step off it toward the camera, facing it, in reach of `use`.
const TOUR_PLACES: Array[String] = ["bag"]


func tour_place(what: String) -> Vector2:
	var heap := _last_bag()
	if what != "bag" or heap == null:
		return Vector2.INF
	return heap.pos + Vector2(0.9, 0.5)


func tour_face(what: String) -> float:
	var heap := _last_bag()
	if what != "bag" or heap == null:
		return NAN
	return (heap.pos - (heap.pos + Vector2(0.9, 0.5))).angle()


func _last_bag() -> WorldProp:
	var state := SurvivalState.of(game)
	var best := -1
	for id: int in state.bags:
		if best < 0 or float(state.bags[id]) >= float(state.bags[best]):
			best = id
	return game.world.prop(best) if best >= 0 else null


const HOME_LINE := "You wake by your own fire, hands raw. The lamp is out."


## The player's holdings in the realm they are in, from whichever system keeps
## them (46_settlements), found by its `places` rather than its name.
func _holdings() -> Array:
	for sys in game.systems:
		if sys.get(&"places") is Array and sys.has_method(&"realm_here") and sys.has_method(&"all"):
			return sys.call(&"all", sys.call(&"realm_here"))
	return []


## Moved while the hours went by: the player, the land about them and the camera all at once.
func _put_hero(at: Vector2, facing: float) -> void:
	var hero := sim.hero
	hero.pos = at
	hero.facing = facing
	hero.throw_until = 0.0
	hero.move = Vector2.ZERO
	game.player.sync_view(0.0)
	game.view.ensure_near(hero.pos)
	game.camera.snap_to(game.player.position)


## Coming round after a bad end: the body lies a moment and gets up before it
## will walk, so the hours that went by are felt and not skipped past.
func _wake() -> void:
	# The hours lost were lost lying there: they mend nothing. Mending counts from waking.
	_mend_from = game.clock.minutes
	_last_health = game.body.health
	game.player.model.play_action(&"downed", WAKE_SECONDS)
	game.body.busy_until = maxf(game.body.busy_until, Time.get_ticks_msec() / 1000.0 + WAKE_SECONDS)


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
			# Held to its spot: a machine at idle would walk its beat out of the picture.
			m.line_a = m.pos
			m.line_b = m.pos
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
				Brains.bite(target, sim)
				_run_for(target.bite.windup + target.bite.active)
				# Just taken: the jaw has closed and the first pull is thrown, before it has hauled you in.
				_run_for(24.0)
				sim.press_swing()
				_run_for(ms if ms >= 0.0 else 60.0)
		"windup":
			if target != null and target.bite != null:
				_bring_to_bite(target)
				Brains.bite(target, sim)
				_run_for(ms if ms >= 0.0 else target.bite.windup * 0.6)
		"hurt":
			if target != null and target.bite != null:
				_bring_to_bite(target)
				Brains.bite(target, sim)
				_run_for((target.bite.windup + target.bite.active * 0.5) + (ms if ms >= 0.0 else 40.0))
		"dodge":
			if target != null and target.bite != null:
				_bring_to_bite(target)
				Brains.bite(target, sim)
				_run_for(maxf(0.0, target.bite.windup - 60.0))
				hero.move = Vector2.from_angle(hero.facing + PI * 0.5)
				sim.press_dodge()
				_run_for(ms if ms >= 0.0 else 90.0)
		"fx":
			# Every mark about the player, held at MS/1000 of its life (review only).
			MobFx.hold_at = clampf(ms / 1000.0, 0.0, 0.99) if ms >= 0.0 else 0.3
			var p3 := game.player.position
			var dust := _dust_colour(sim.hero.pos)
			MobFx.burst(game, p3 + Vector3(2.0, 0.6, -2.0), 1.0, 3, Palette.LENS[3])
			MobFx.burst(game, p3 + Vector3(-2.0, 0.6, -2.0), 0.8, 4)
			MobFx.puff(game, p3 + Vector3(2.0, 0, 0), Vector2.RIGHT, dust, 0.6, 5)
			MobFx.puffs(game, p3 + Vector3(0, 0, -2.5), Vector2.ZERO, dust, 4, 0.55, 6)
			MobFx.ring(game, p3 + Vector3(-2.0, 0, 0), Palette.INK[1], 1.0, 0.3)
			MobFx.clang(game, p3 + Vector3(0, 0.6, 2.0), 7)
			MobFx.glint(game, p3 + Vector3(-2.0, 0.6, 2.0), Palette.LENS[3], 9, 0.6)
			MobFx.streak(game, p3 + Vector3(2.0, 0.6, 2.0), Vector2(1, -1), game.camera.yaw_now(), game.camera.pitch_deg, 10)
			MobFx.tell(game, p3 + Vector3(0, 0.3, 0) + Vector3(-1.2, 0, 1.2) * 2.0, _screen_up(), 0.4, 11)
			MobFx.breath(game, p3 + Vector3(-2.0, 1.3, -2.0), Palette.RIME[2], 0.4, 1.6, Vector2.ZERO, 12)
			# And one burst on the BODY, at that body's own width, because the rule
			# that sizes it (MobFx.on_body) cannot be seen in marks laid on grass:
			# every mark above is drawn with no body under it and takes the plain
			# floor. This is the one a player actually gets on a machine.
			if target != null:
				MobFx.burst(game, _part_at(target), 1.1, 13, Palette.LENS[3], target.radius * 2.0)
		"alert":
			for m in sim.mobs:
				m.calm_until = 0.0
			_run_for(ms if ms >= 0.0 else 1200.0)
		_:
			push_warning("unknown --act %s" % act)
	_handle(sim.drain())
	game.player.sync_view(0.0, true)
	# Framed on the meeting: between the player and the body, so a watcher on its
	# rise four tiles off is in the picture with the one it watches.
	var focus := game.player.position
	if target != null and target.node is Mob:
		focus = focus.lerp((target.node as Mob).global_position, 0.5)
	_focus = focus
	game.camera.snap_to(focus)
	_held = true
	sim.hold = true


func _run_for(ms: float) -> void:
	var n := maxi(0, roundi(ms / FightRules.SLICE_MS))
	var hero := sim.hero
	var move := hero.move
	var dt := FightRules.SLICE_MS / 1000.0
	for i in n:
		hero.move = move
		sim.slices(1)
		_handle(sim.drain())
		_landing()
		# The bodies are drawn along with it, so a held moment shows its poses
		# (a windup blended in, a swing half thrown) and not the first frame of each.
		game.player.sync_view(dt)
		for m in sim.mobs:
			if m.node is Mob:
				(m.node as Mob).sync_view(dt, sim.now, hero.holder == m)


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


## Face a body at the player and close to where its bite lands: beside it on
## the screen where there is ground, so neither hides the other in the shot.
func _bring_to_bite(m: MobState) -> void:
	var hero := sim.hero
	var d := m.radius + hero.radius + m.bite.reach * 0.6
	var tries: Array[Vector2] = [Vector2(1, -1).normalized(), Vector2(-1, 1).normalized(), (hero.pos - m.pos).normalized()]
	for dir in tries:
		var at := m.pos + dir * d
		if game.query.standable(floori(at.x), floori(at.y)):
			hero.pos = at
			break
	m.facing = (hero.pos - m.pos).angle()
	m.aim = m.facing
	hero.facing = (m.pos - hero.pos).angle()
