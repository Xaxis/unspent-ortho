class_name FightSim
extends RefCounted
## The one continuous simulation of every body near the player: walking,
## noticing, chasing, blows, grips and how a fight ends. There is no separate
## fight mode and the world clock never stops for it; this runs in fixed 8 ms
## slices of real time (design-extract §7.1) and is pure data, so tests step it
## headless and the game only draws it.
##
## Per slice: presses -> think (64 ms) and moods (100 ms beats) -> move ->
## touching -> land blows -> holding -> retire -> settle.
##
## Everything the rest of the game should hear about goes in `out` as a
## dictionary {type: StringName, ...}; the fight system drains it into Events,
## sounds, effects and world consequences. Types:
##   swing whiff dodge evaded pull loose grip hit(ring) hurt killed second_act
##   alerted called snatch filed removed fight_started outcome

const NAV_EVERY_MS := 240.0
## Tiles/s at most that a standing body eases the player out of itself.
const SHOULDER_SPEED := 4.0

var world: WorldData
var query: WorldQuery
var hero: Hero
var moment: Moment
var mobs: Array[MobState] = []
## Steps to the player over the ground, for chasers that meet a cliff.
var nav: NavField
## Simulation milliseconds.
var now := 0.0
## Real seconds that `now` corresponds to (Body stores real-time seconds).
var real_s := 0.0
var out: Array[Dictionary] = []
## The view is holding still (hitstop, or a held moment for a shot); nothing steps.
var hold := false

var fight_on := false
var fight_started := 0.0
var fight_mobs: Dictionary = {} # id -> MobState
var fight_kills := 0
var last_outcome: StringName = &""
## World minutes when a dart last reached the player (Coast keeps darts away after).
var last_meeting_minutes := -INF
var _far_since := -1.0
var _nav_at := -100000.0
var _far_best := INF
var _best_d := INF
var _best_at := 0.0
var _carry := 0.0
var _swing_until := -1.0
var _dodge_until := -1.0
var _whiff_checked := true


func _init(w: WorldData, q: WorldQuery, h: Hero = null, m: Moment = null) -> void:
	world = w
	query = q
	hero = h if h != null else Hero.new()
	moment = m if m != null else Moment.new()
	nav = NavField.new(w, q) if w != null and q != null else null


func add_mob(kind: StringName, at: Vector2) -> MobState:
	var m := MobState.new(kind, at, moment.seed_value)
	mobs.append(m)
	return m


func living() -> int:
	var n := 0
	for m in mobs:
		if m.alive and not m.removed:
			n += 1
	return n


# --- input -------------------------------------------------------------------

## The swing key. Held, it wrenches against the grip instead (never buffered).
func press_swing() -> void:
	if hero.held():
		_try_pull()
		return
	_swing_until = now + FightRules.BUFFER_MS


func press_dodge() -> void:
	_dodge_until = now + FightRules.BUFFER_MS


# --- stepping ----------------------------------------------------------------

## Advance by real seconds, in whole slices; the remainder carries.
func step(delta_s: float) -> void:
	hero.read_body()
	_carry += minf(delta_s * 1000.0, FightRules.MAX_FRAME_MS)
	while _carry >= FightRules.SLICE_MS:
		_carry -= FightRules.SLICE_MS
		_slice()
	hero.write_body(now, real_s)
	_purge()


## Advance exactly n slices (tests).
func slices(n: int) -> void:
	hero.read_body()
	for i in n:
		_slice()
	hero.write_body(now, real_s)
	_purge()


func _slice() -> void:
	var t0 := now
	now += FightRules.SLICE_MS
	var dt := FightRules.SLICE_MS / 1000.0
	_presses()
	if fmod(now, FightRules.THINK_MS) < FightRules.SLICE_MS:
		for m in mobs:
			Brains.think(m, self)
	if floori(now / FightRules.BEAT_MS) != floori(t0 / FightRules.BEAT_MS):
		_beat()
	_move_hero(dt)
	for m in mobs:
		_move_mob(m, dt)
	_touching()
	_land(t0, now)
	_holding()
	_retire()
	_settle()


func _presses() -> void:
	if _swing_until >= now and not hero.held():
		if hero.swing_refusal(now) == &"":
			_swing_until = -1.0
			_swing()
	if _dodge_until >= now:
		if hero.dodge_refusal(now) == &"":
			_dodge_until = -1.0
			_dodge()


func _swing() -> void:
	var inv := hero.inventory
	var held: StringName = inv.held if inv != null else &""
	var b := Blow.for_item(held, inv.edge(held) if inv != null and held != &"" else 10000)
	if hero.move.length() > 0.1:
		hero.facing = hero.move.angle()
	# Turn toward a body just off the facing, so a swing that was meant lands where it was meant.
	var best: MobState = null
	var best_off := FightRules.AIM_ASSIST_ANGLE
	for m in mobs:
		if not m.alive or m.removed:
			continue
		var to := m.pos - hero.pos
		if to.length() > hero.radius + b.reach + m.radius + FightRules.AIM_ASSIST_EXTRA:
			continue
		var off := absf(wrapf(to.angle() - hero.facing, -PI, PI))
		if off < best_off:
			best_off = off
			best = m
	if best != null:
		hero.facing = (best.pos - hero.pos).angle()
	var dry := b.wick > 0 and not FightRules.spend_charges(inv, b.wick)
	if dry:
		b.dry()
	hero.start_swing(b, now)
	_whiff_checked = false
	var dulled := FightRules.wear(inv, held, 1)
	emit(&"swing", {"item": held, "dry": dry, "dulled": dulled})


func _dodge() -> void:
	var dir := hero.move
	if dir.length() > 0.1:
		hero.facing = dir.angle()
	else:
		# No direction held: a step back, still facing the trouble.
		dir = -Vector2.from_angle(hero.facing)
	hero.start_dodge(dir, now)
	emit(&"dodge", {})


func _try_pull() -> void:
	var inv := hero.inventory
	var cut: bool = inv != null and Items.def(inv.held).get("verb", &"") == &"cut"
	var holder := hero.holder
	if hero.pull(now, cut):
		emit(&"pull", {"grip": hero.grip, "by": holder})
		if hero.grip == 0:
			emit(&"loose", {"by": holder})


# --- moods (100 ms beats) ----------------------------------------------------

func _beat() -> void:
	for m in mobs:
		if not m.alive or m.removed:
			continue
		var noticed := now >= m.calm_until and Senses.notices(m.row, m.pos, hero.pos, moment, world, query)
		if noticed:
			m.lost_beats = 0
			m.last_seen = hero.pos
		else:
			m.lost_beats += 1
		var d := Senses.chebyshev(m.pos, hero.pos)
		var reach := float(m.stat("reach", 1))
		var beats := int((now - m.mood_at) / FightRules.BEAT_MS)
		match m.mood:
			MobState.IDLE, MobState.WORKING:
				if noticed:
					m.set_mood(MobState.ALERTED, now)
					emit(&"alerted", {"mob": m})
			MobState.ALERTED:
				if m.lost_beats >= int(m.stat("forget", 20)):
					m.set_mood(MobState.WORKING if m.approach == &"errand" else MobState.IDLE, now)
				elif beats >= int(m.stat("ready", 2)):
					if m.approach == &"errand":
						_call(m)
					else:
						m.set_mood(MobState.CHASING, now)
			MobState.CHASING:
				if m.lost_beats >= int(m.stat("forget", 20)):
					m.set_mood(MobState.IDLE, now)
				elif m.approach != &"dart" and m.pos.distance_to(m.home) > float(m.stat("tether", 30)):
					m.flee_home = true
					m.set_mood(MobState.FLEEING, now)
				elif m.approach != &"dart" and d <= reach:
					m.set_mood(MobState.ATTACKING, now)
			MobState.ATTACKING:
				if m.lost_beats >= int(m.stat("forget", 20)):
					m.set_mood(MobState.IDLE, now)
				elif d > reach + 4.0 and not m.committed(now):
					m.charging = false
					m.set_mood(MobState.CHASING, now)
				elif m.pos.distance_to(m.home) > float(m.stat("tether", 30)) + 4.0:
					m.flee_home = true
					m.set_mood(MobState.FLEEING, now)
			MobState.FLEEING:
				if m.flee_home:
					if m.pos.distance_to(m.home) < 2.0:
						m.flee_home = false
						m.calm_until = now + 3000.0
						m.set_mood(MobState.IDLE, now)
				elif d >= float(m.stat("safe", 12)):
					if m.snatched:
						if m.row.get("hits", {}).get("files", false) and not m.reported:
							m.reported = true
							emit(&"filed", {"mob": m})
						remove_mob(m)
					else:
						m.calm_until = now + 4000.0
						m.set_mood(MobState.IDLE, now)


## An errand that works by eye has registered the player: every machine within
## its racket that is not already roused is told where the player stood.
func _call(watcher: MobState) -> void:
	var calls: float = watcher.stat("calls", 0)
	if calls <= 0.0 or now < watcher.call_ready_at:
		return
	watcher.call_ready_at = now + 30000.0
	var told := 0
	for m in mobs:
		if m == watcher or not m.alive or m.removed or m.approach == &"errand" or not m.machine:
			continue
		if m.mood != MobState.IDLE:
			continue
		if m.pos.distance_to(watcher.pos) <= calls:
			m.last_seen = hero.pos
			m.lost_beats = 1
			m.set_mood(MobState.ALERTED, now)
			told += 1
	emit(&"called", {"mob": watcher, "told": told})


# --- movement ----------------------------------------------------------------

func _move_hero(dt: float) -> void:
	var v := Vector2.ZERO
	var since_dodge := now - hero.dodge_at
	var running := false
	if hero.held():
		var h := hero.holder
		if h != null:
			var mouth := h.pos + Vector2.from_angle(h.facing) * (h.radius + hero.radius * 0.6)
			var to := mouth - hero.pos
			v = to.limit_length(1.5) * 3.0
			hero.facing = (h.pos - hero.pos).angle()
	elif hero.stunned(now):
		v = Vector2.ZERO
	elif since_dodge < FightRules.DODGE_MS:
		v = hero.dodge_dir * FightRules.dodge_speed(since_dodge)
	else:
		var can_run := not fight_on or hero.wind > FightRules.RUN_WIND_FLOOR
		running = hero.run and can_run and hero.move.length() > 0.1
		var s := hero.run_speed if running else hero.walk_speed
		if hero.committed(now):
			s *= hero.blow.creep
		v = hero.move.limit_length(1.0) * s
		if not hero.committed(now) and hero.move.length() > 0.1:
			hero.facing = hero.move.angle()
	v += hero.throw_velocity(now)
	v += _shouldered(dt)
	var before := hero.pos
	if v.length_squared() > 0.0:
		hero.pos = query.move_body(hero.pos, v * dt, hero.radius) if query != null else hero.pos + v * dt
	hero.speed = before.distance_to(hero.pos) / dt
	# Wind: spent on dodges, swings and running in a fight; back at 500/s otherwise.
	if running and fight_on:
		hero.wind = maxf(0.0, hero.wind - FightRules.RUN_WIND_COST * dt)
	elif since_dodge >= FightRules.DODGE_MS:
		hero.wind = minf(hero.max_wind, hero.wind + FightRules.WIND_REGEN * dt)


## Bodies are solid to the player, so no one stands hidden in a machine's
## middle on no side of it. A standing body eases the player out of itself; a
## moving one (a charge coming on, a sweeper along its track) never changes
## course for the player: it shoulders them aside, off its line. A dodge goes
## through; a holder keeps what it holds; darts only brush past.
func _shouldered(dt: float) -> Vector2:
	if now - hero.dodge_at < FightRules.DODGE_MS:
		return Vector2.ZERO
	var push := Vector2.ZERO
	for m in mobs:
		if not m.alive or m.removed or m.approach == &"dart" or hero.holder == m:
			continue
		var away := hero.pos - m.pos
		var d := away.length()
		var inside := m.radius + hero.radius * 0.5 - d
		if inside <= 0.0:
			continue
		var dir := away / d if d > 1e-4 else Vector2.from_angle(m.facing + PI * 0.5)
		if m.speed > 1.0:
			var along := Vector2.from_angle(m.facing)
			var side := along.orthogonal()
			if side.dot(away) < 0.0:
				side = -side
			push += side * SHOULDER_SPEED * 1.5
		else:
			push += dir * minf(inside / dt, SHOULDER_SPEED)
	return push


func _move_mob(m: MobState, dt: float) -> void:
	if m.removed:
		return
	if not m.alive:
		m.speed = 0.0
		return
	if not m.committed(now):
		m.facing = rotate_toward(m.facing, m.aim, m.turn_rate * dt)
	var v := m.want
	if m.stunned(now):
		v = Vector2.ZERO
	else:
		# Close bites read as a tell and a lunge; charges come on through them.
		var phase := m.blow_phase(now)
		if m.approach != &"charge" and phase != &"":
			match phase:
				&"windup": v *= 0.2
				# A small follow-through: enough to see, never enough to outreach its box.
				&"active": v = Vector2.from_angle(m.facing) * m.quick * 0.5
				&"recovery": v *= 0.3
	v += m.throw_velocity(now)
	# Hostiles keep a tile apart from each other; never from the player.
	for o in mobs:
		if o == m or not o.alive or o.removed:
			continue
		var sep := m.pos - o.pos
		var d := sep.length()
		if d < 1.0 and d > 1e-4:
			v += sep / d * (1.0 - d) * 4.0
	if not m.row.get("through", false):
		var to := hero.pos - m.pos
		var d := to.length()
		var skin := (m.radius + hero.radius) * 0.9
		if d < skin + 0.05 and d > 1e-4:
			var inward := v.dot(to / d)
			if inward > 0.0:
				v -= to / d * inward
	if v.length_squared() < 1e-6:
		m.speed = 0.0
		return
	var before := m.pos
	var next := query.move_body(m.pos, v * dt, minf(m.radius, 0.45)) if query != null else m.pos + v * dt
	var keeps: Array = m.row.get("keeps_to", [])
	if not keeps.is_empty() and world != null:
		if not _ground_in(next, keeps):
			var nx := Vector2(next.x, m.pos.y)
			var ny := Vector2(m.pos.x, next.y)
			next = nx if _ground_in(nx, keeps) else (ny if _ground_in(ny, keeps) else m.pos)
	m.pos = next
	m.speed = before.distance_to(m.pos) / dt


func _ground_in(p: Vector2, names: Array) -> bool:
	var g := world.ground_at(floori(p.x), floori(p.y))
	return Spawner.ground_matches(g, names)


static func rotate_toward(from: float, to: float, max_step: float) -> float:
	var diff := wrapf(to - from, -PI, PI)
	if absf(diff) <= max_step:
		return to
	return from + signf(diff) * max_step


# --- contact and blows -------------------------------------------------------

func _touching() -> void:
	for m in mobs:
		var touch: int = m.stat("touch", 0)
		if touch <= 0 or not m.alive or m.removed or m.bite != null:
			continue
		if m.pos.distance_to(hero.pos) > m.radius + hero.radius:
			continue
		if hero.invulnerable(now):
			continue
		_hurt_hero(m, touch, hero.pos - m.pos, 4.0, 200)


func _land(t0: float, t1: float) -> void:
	var b := hero.blow
	if b != null and b.live_in(hero.blow_at, t0, t1):
		for m in mobs:
			if not m.alive or m.removed or hero.struck.has(m.id):
				continue
			if not FightRules.box_hits(hero.pos, hero.facing, hero.radius, b, m.pos, m.radius):
				continue
			hero.struck[m.id] = true
			if not FightRules.reaches(m.part, m.pos, m.facing, hero.pos, b.cuts):
				hero.throw(hero.pos - m.pos, FightRules.RING_RECOIL, FightRules.RING_RECOIL_MS, now)
				emit(&"hit", {"attacker": hero, "target": m, "damage": 0, "plate": true, "at": m.pos})
				_wake(m)
				continue
			if m.invulnerable(now):
				continue
			_hurt_mob(m, b)
	if b != null and not _whiff_checked and t1 >= hero.blow_at + b.windup + b.active:
		_whiff_checked = true
		if hero.struck.is_empty():
			emit(&"whiff", {})
	for m in mobs:
		if not m.alive or m.removed or m.blow == null or m.struck.has(&"hero"):
			continue
		if not m.blow.live_in(m.blow_at, t0, t1):
			continue
		if not FightRules.box_hits(m.pos, m.facing, m.radius, m.blow, hero.pos, hero.radius):
			continue
		m.struck[&"hero"] = true
		if hero.invulnerable(now):
			# Slipped: a blow met first inside the window is spent. The source let the
			# rest of the live window land, which made a dodge read right into a hit
			# whenever the box outlasted 90 ms; the timing is the skill, not the luck.
			emit(&"evaded", {"by": m, "dodge": FightRules.dodge_invulnerable(now - hero.dodge_at)})
			continue
		if m.blow.grip > 0:
			if hero.seize(m, m.blow.grip, now):
				hero.blow = null
				emit(&"grip", {"by": m, "grip": hero.grip})
			continue
		_hurt_hero(m, m.blow.dmg, Vector2.from_angle(m.facing) + (hero.pos - m.pos).normalized(), m.blow.knock, m.blow.knock_ms)


func _hurt_mob(m: MobState, b: Blow) -> void:
	m.health -= b.dmg
	m.invuln_until = now + m.mob_iframes()
	m.last_hit_at = now
	# A creature has no part to flare: it is hurt at once.
	m.flare_until = now + (FightRules.PART_FLARE_MS if m.machine else 0.0)
	m.dark_until = m.flare_until + FightRules.PART_DARK_MS
	if m.row.get("stagger", false):
		m.throw(m.pos - hero.pos, b.knock, b.knock_ms, now)
		if m.blow_phase(now) == &"windup":
			m.blow = null
	elif m.machine and now >= m.stall_ready_at:
		# A machine never flinches, but a blow in its working part stops the work:
		# the light goes out, a tell in progress is lost, and it stands a moment.
		# Once in a while only, so it is an opening and not a lock.
		m.stall_ready_at = now + FightRules.STALL_EVERY_MS
		m.stun_until = maxf(m.stun_until, now + FightRules.STALL_MS)
		m.charging = false
		if m.blow_phase(now) == &"windup":
			m.blow = null
	emit(&"hit", {"attacker": hero, "target": m, "damage": b.dmg, "plate": false, "at": m.pos})
	if m.health <= 0:
		_kill(m)
		return
	if m.row.has("then") and not m.second_act and m.health_fraction() <= float(m.row.get("then_at", 0.0)):
		m.second_act = true
		m.bite = Roster.second_bite(m.kind)
		if m.blow_phase(now) == &"windup":
			m.blow = null
		if hero.holder == m:
			hero.release()
			emit(&"loose", {"by": m})
		emit(&"second_act", {"mob": m})
	var nerve: int = m.stat("nerve", 100)
	if nerve < 100 and m.health_fraction() * 100.0 <= nerve:
		m.flee_home = false
		m.set_mood(MobState.FLEEING, now)
		return
	_wake(m)


## Struck, a body that was not pressing turns on whoever struck it (errands only look).
func _wake(m: MobState) -> void:
	m.last_seen = hero.pos
	m.lost_beats = 0
	m.calm_until = 0.0
	if m.mood == MobState.IDLE or m.mood == MobState.WORKING or m.mood == MobState.ALERTED:
		if m.approach == &"errand":
			m.set_mood(MobState.ALERTED, now)
		elif m.approach != &"dart":
			m.set_mood(MobState.ATTACKING, now)


func _hurt_hero(by: MobState, dmg: int, dir: Vector2, knock: float, knock_ms: int) -> void:
	hero.health -= dmg
	hero.invuln_until = now + FightRules.HURT_IFRAMES_MS
	hero.throw(dir, knock, knock_ms, now)
	hero.last_hit_by = by
	hero.last_hit_at = now
	if hero.committed(now):
		hero.blow = null
	emit(&"hurt", {"attacker": by, "target": hero, "damage": dmg, "at": hero.pos})


func _kill(m: MobState) -> void:
	m.health = 0
	m.alive = false
	m.blow = null
	m.want = Vector2.ZERO
	m.dead_at = now
	m.set_mood(MobState.DEAD, now)
	if fight_mobs.has(m.id):
		fight_kills += 1
	if hero.holder == m:
		hero.release()
		emit(&"loose", {"by": m})
	emit(&"killed", {"mob": m, "at": m.pos})


## A dart reached the player: it takes what it came for and runs.
func snatch(m: MobState) -> void:
	if m.snatched:
		return
	m.snatched = true
	if moment != null:
		last_meeting_minutes = moment.minutes
	m.flee_home = false
	m.set_mood(MobState.FLEEING, now)
	emit(&"snatch", {"mob": m})


func _holding() -> void:
	if not hero.held():
		return
	var h := hero.holder as MobState
	if h == null or not h.alive or h.removed:
		hero.release()
		emit(&"loose", {"by": h})
		return
	if now - hero.grip_since >= FightRules.HOLD_LIMIT_MS:
		_end(&"carried")


func _retire() -> void:
	for m in mobs:
		if m.alive or m.removed:
			continue
		if now - m.dead_at >= float(m.stat("linger", 30.0)) * 1000.0:
			remove_mob(m)


func remove_mob(m: MobState) -> void:
	if m.removed:
		return
	m.removed = true
	if hero.holder == m:
		hero.release()
		emit(&"loose", {"by": m})
	emit(&"removed", {"mob": m})


## Take every body off the coast (a bad end, a jump in time).
func clear_mobs() -> void:
	for m in mobs:
		remove_mob(m)
	fight_mobs.clear()


func _purge() -> void:
	var keep: Array[MobState] = []
	for m in mobs:
		if not m.removed:
			keep.append(m)
	mobs = keep


# --- how a fight ends --------------------------------------------------------

func _settle() -> void:
	if hero.health <= 0:
		if not fight_on:
			_begin()
		_end(&"downed")
		return
	var engaged := false
	for m in mobs:
		if _pressing(m):
			engaged = true
			if fight_on and not fight_mobs.has(m.id):
				fight_mobs[m.id] = m
	if not fight_on:
		if engaged:
			_begin()
		return
	var nearest := INF
	var pressing := false
	for id: int in fight_mobs:
		var m: MobState = fight_mobs[id]
		if not m.alive or m.removed:
			continue
		nearest = minf(nearest, ground_distance(m.pos))
		if m.engaged() or hero.holder == m:
			pressing = true
	if nearest == INF:
		_end(&"won" if fight_kills > 0 else &"away")
		return
	if not pressing:
		_end(&"away")
		return
	# Left behind: far off for a while and not closing. Something still coming
	# round a cliff to you is closing, and is still a fight.
	if nearest > FightRules.AWAY_DISTANCE:
		if _far_since < 0.0 or nearest < _far_best - 0.5:
			_far_since = now
			_far_best = nearest
		elif now - _far_since >= FightRules.AWAY_MS:
			_end(&"away")
			return
	else:
		_far_since = -1.0
		_far_best = INF
	if nearest > 3.0:
		if nearest < _best_d - 0.5:
			_best_d = nearest
			_best_at = now
		elif now - _best_at >= FightRules.NO_PROGRESS_MS:
			_end(&"away")
	else:
		_best_d = nearest
		_best_at = now


## Bring the ground field to the player's tile, at most every NAV_EVERY_MS: a
## field a tile stale still leads round the same cliff, and a build is not free.
func refresh_nav() -> void:
	if nav == null:
		return
	if nav.builds > 0 and now - _nav_at < NAV_EVERY_MS:
		return
	var before := nav.builds
	nav.update(hero.pos)
	if nav.builds != before:
		_nav_at = now


## Tiles to the player over the ground (the way round a cliff, not through it),
## or the straight Chebyshev distance where the ground field does not reach.
func ground_distance(p: Vector2) -> float:
	var straight := Senses.chebyshev(p, hero.pos)
	if nav == null or straight > NavField.RADIUS or NavField.line_walkable(world, p, hero.pos):
		return straight
	refresh_nav()
	var s := nav.steps(floori(p.x), floori(p.y))
	if s >= NavField.FAR:
		return straight
	return maxf(straight, float(s) / NavField.STRAIGHT)


## Pressing the player closely enough to count as a fight. Something coming from
## the edge of sight is not a fight yet: it would count as left behind before it
## ever arrived, and the player's run would cost wind for a walk.
func _pressing(m: MobState) -> bool:
	if hero.holder == m:
		return true
	return m.engaged() and Senses.chebyshev(m.pos, hero.pos) <= FightRules.AWAY_DISTANCE


func _begin() -> void:
	fight_on = true
	fight_started = now
	fight_kills = 0
	fight_mobs.clear()
	for m in mobs:
		if _pressing(m):
			fight_mobs[m.id] = m
	_far_since = -1.0
	_far_best = INF
	_best_d = INF
	_best_at = now
	emit(&"fight_started", {})


func _end(outcome: StringName) -> void:
	fight_on = false
	last_outcome = outcome
	var by := hero.last_hit_by as MobState
	if outcome == &"carried":
		by = hero.holder as MobState
	match outcome:
		&"downed", &"carried":
			hero.release()
			hero.blow = null
			hero.stun_until = now
			hero.throw_until = now
			if outcome == &"downed":
				hero.health = FightRules.DOWNED_WAKE_HEALTH
			emit(&"outcome", {"outcome": outcome, "by": by, "ms": now - fight_started})
			clear_mobs()
			return
		&"away":
			for id: int in fight_mobs:
				var m: MobState = fight_mobs[id]
				if not m.alive or m.removed:
					continue
				m.charging = false
				m.closing_since = -1.0
				m.calm_until = now + 6000.0
				var nerve: int = m.stat("nerve", 100)
				if nerve < 100 and m.health < m.max_health:
					m.set_mood(MobState.FLEEING, now)
				else:
					m.set_mood(MobState.WORKING if m.approach == &"errand" else MobState.IDLE, now)
	fight_mobs.clear()
	emit(&"outcome", {"outcome": outcome, "by": by, "ms": now - fight_started})


func emit(type: StringName, data: Dictionary) -> void:
	data["type"] = type
	out.append(data)


## Take the events since the last drain.
func drain() -> Array[Dictionary]:
	var o := out
	out = []
	return o
