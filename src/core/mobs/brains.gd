class_name Brains
## What a body wants to do, every 64 ms (design-extract §7.3, §7.4). A brain
## only sets `want` (tiles/s), `aim` and starts bites; FightSim moves bodies,
## turns them and lands blows. Four approaches:
##   errand  walks its line; closes on you only when you are near, seen clear, and rested
##   charge  commits to a bearing for a run, then stands and comes round (420 ms x turns)
##   rush    a 1000 ms lunge cycle: press in and bite for 620 ms, circle for the rest
##   dart    closes, takes what it came for, and runs until it is clear

const RUN_MS := 900
const TURN_PAUSE_MS := 420
const LUNGE_CYCLE_MS := 1000
const LUNGE_PRESS_MS := 620
const ERRAND_CLOSE_MS := 3000
const ERRAND_REST_MS := 4000
## A run that covers less than this share of its expected distance hit something.
const BLOCKED_SHARE := 0.35


static func think(m: MobState, sim: FightSim) -> void:
	var now := sim.now
	if not m.alive or m.removed:
		m.want = Vector2.ZERO
		return
	if sim.hero.holder == m:
		# Holding on: nothing else to do but keep its mouth where the player is.
		m.want = Vector2.ZERO
		m.aim = (sim.hero.pos - m.pos).angle()
		return
	if m.stunned(now):
		m.want = Vector2.ZERO
		return
	match m.mood:
		MobState.IDLE:
			_idle(m, sim)
		MobState.WORKING:
			_errand(m, sim)
		MobState.ALERTED:
			if m.approach == &"errand":
				_errand(m, sim)
			else:
				m.want = Vector2.ZERO
			m.aim = (_target(m, sim) - m.pos).angle()
		MobState.CHASING:
			match m.approach:
				&"errand": _errand(m, sim)
				&"dart": _dart(m, sim)
				&"charge": _charge(m, sim, m.dash, TURN_PAUSE_MS * 0.25 * int(m.stat("turns", 1)))
				_: _seek(m, sim, _target(m, sim), m.dash)
		MobState.ATTACKING:
			match m.approach:
				&"errand": _errand(m, sim)
				&"dart": _dart(m, sim)
				&"charge": _charge(m, sim, m.quick, TURN_PAUSE_MS * int(m.stat("turns", 1)))
				_: _lunge(m, sim)
		MobState.FLEEING:
			_flee(m, sim)
		_:
			m.want = Vector2.ZERO
	m.last_think_pos = m.pos


## Where it thinks the player is: the player if it has them, else where it last had them.
static func _target(m: MobState, sim: FightSim) -> Vector2:
	return sim.hero.pos if m.lost_beats == 0 else m.last_seen


## Start the bite's tell. The sim says so, so the view can draw what a player learns to read.
static func bite(m: MobState, sim: FightSim) -> void:
	m.start_blow(m.bite, sim.now)
	sim.emit(&"windup", {"mob": m})


static func can_bite(m: MobState, now: float) -> bool:
	return m.bite != null and not m.locked_out(now) and not m.stunned(now)


## Close enough to land a bite: skin + reach x 0.8.
static func strike_range(m: MobState, sim: FightSim) -> float:
	var reach := m.bite.reach if m.bite != null else 0.5
	return m.radius + sim.hero.radius + reach * 0.8


static func _idle(m: MobState, sim: FightSim) -> void:
	if m.machine:
		if m.line_a.distance_squared_to(m.line_b) < 0.01:
			m.want = Vector2.ZERO
			return
		_walk_line(m, m.pace * 0.6)
		return
	# Animals graze about home: a hashed heading for a second in every three.
	var slot := floori(sim.now / 3000.0)
	var h := Rng.hash01(sim.moment.seed_value, m.id, slot)
	var t := fposmod(sim.now, 3000.0)
	if t > 1000.0 or h < 0.3:
		m.want = Vector2.ZERO
		return
	var dir := Vector2.from_angle(h * TAU * 3.0)
	if m.pos.distance_to(m.home) > 3.0:
		dir = (m.home - m.pos).normalized()
	m.want = dir * m.pace * 0.5
	m.aim = dir.angle()


static func _walk_line(m: MobState, speed: float) -> void:
	var target := m.line_b if m.line_to_b else m.line_a
	var to := target - m.pos
	if to.length() < 0.3 or (m.pos.distance_to(m.last_think_pos) < speed * 0.064 * 0.2 and m.speed < 0.05 and m.want.length() > 0.0):
		m.line_to_b = not m.line_to_b
		target = m.line_b if m.line_to_b else m.line_a
		to = target - m.pos
	if to.length() < 0.05:
		m.want = Vector2.ZERO
		return
	m.want = to.normalized() * speed
	m.aim = to.angle()


## Errands never chase. They walk `stretch` each way along their line and
## close on the player only within max(1, reach), seen clear, rest window up.
static func _errand(m: MobState, sim: FightSim) -> void:
	var now := sim.now
	var hero := sim.hero
	var to := hero.pos - m.pos
	var close_at := maxf(1.0, float(m.stat("reach", 1)))
	if m.closing_since >= 0.0:
		if now - m.closing_since > ERRAND_CLOSE_MS or Senses.chebyshev(m.pos, hero.pos) > close_at + 2.0:
			m.closing_since = -1.0
			m.rest_until = now + ERRAND_REST_MS
		else:
			m.want = to.normalized() * m.pace if to.length() > m.radius + hero.radius * 0.5 else Vector2.ZERO
			m.aim = to.angle()
			return
	# One that works by eye must have registered the player first.
	var registered: bool = m.mood == MobState.ALERTED or not m.row.get("sight_only", false)
	if registered and now >= m.rest_until and Senses.chebyshev(m.pos, hero.pos) <= close_at \
			and Senses.line_clear(sim.world, sim.query, m.pos, hero.pos):
		m.closing_since = now
		m.want = to.normalized() * m.pace
		m.aim = to.angle()
		return
	if m.line_a.distance_squared_to(m.line_b) < 0.01:
		m.want = Vector2.ZERO
		return
	_walk_line(m, m.pace)


## Commit to a bearing for a run; biting when the player is in range ahead.
## A run stopped by a wall, or run out, stands and comes round for `pause_ms`.
static func _charge(m: MobState, sim: FightSim, speed: float, pause_ms: float) -> void:
	var now := sim.now
	var hero := sim.hero
	var to := hero.pos - m.pos
	if now < m.pause_until:
		m.want = Vector2.ZERO
		m.aim = to.angle()
		return
	if m.charging and (now >= m.run_until or _run_blocked(m, speed, now)):
		# The run is over (or a wall ended it): stand and come round before the next.
		m.charging = false
		m.run_until = minf(m.run_until, now)
		m.pause_until = now + pause_ms
		m.want = Vector2.ZERO
		m.aim = to.angle()
		return
	if not m.charging:
		var off := wrapf(to.angle() - m.facing, -PI, PI)
		if absf(off) > 0.6:
			# Not yet round: keep turning.
			m.want = Vector2.ZERO
			m.aim = to.angle()
			return
		# Commit along the way it actually faces, corrected a little toward the player.
		m.bearing = Vector2.from_angle(m.facing + clampf(off, -0.35, 0.35))
		m.charging = true
		m.run_until = now + RUN_MS
		m.run_from = m.pos
		m.last_think_pos = m.pos
		sim.emit(&"charge", {"mob": m})
	m.want = m.bearing * speed
	m.aim = m.bearing.angle()
	var ahead := to.normalized().dot(m.bearing) > 0.3
	# Timed to arrive: the tell starts while the player is still a windup's run
	# away, so the blow is live as the front of it gets there, not after it has
	# gone over them.
	var lead := speed * m.bite.windup / 1000.0 * 0.9 if m.bite != null else 0.0
	if ahead and to.length() <= strike_range(m, sim) + lead and can_bite(m, now):
		bite(m, sim)


static func _run_blocked(m: MobState, speed: float, now: float) -> bool:
	if now - (m.run_until - RUN_MS) < FightRules.THINK_MS:
		return false
	var expected := speed * FightRules.THINK_MS / 1000.0
	return m.pos.distance_to(m.last_think_pos) < expected * BLOCKED_SHARE


## Lunge: approach from far; in close, press in and bite for 620 ms of every
## 1000, and circle the rest, always facing the player.
static func _lunge(m: MobState, sim: FightSim) -> void:
	var now := sim.now
	var hero := sim.hero
	var to := hero.pos - m.pos
	var d := to.length()
	var dir := to / maxf(d, 1e-5)
	var skin := m.radius + hero.radius
	var strike := strike_range(m, sim)
	m.aim = to.angle()
	if d > maxf(1.9 * skin, strike) + 0.8:
		_seek(m, sim, hero.pos, m.quick)
		return
	var cyc := fposmod(now + m.phase_ms, LUNGE_CYCLE_MS)
	if cyc < LUNGE_PRESS_MS:
		m.want = dir * m.quick if d > skin * 0.95 else Vector2.ZERO
		if d <= strike and can_bite(m, now):
			bite(m, sim)
	else:
		var side := 1.0 if m.id % 2 == 0 else -1.0
		var inout := sin((cyc - LUNGE_PRESS_MS) / 380.0 * PI) * 0.35
		var want_d := strike + 0.4
		var radial := clampf(d - want_d, -1.0, 1.0)
		m.want = (dir.orthogonal() * side * 0.8 + dir * (radial * 0.6 - inout)).normalized() * m.quick * 0.6


static func _dart(m: MobState, sim: FightSim) -> void:
	if m.snatched:
		_flee(m, sim)
		return
	var to := sim.hero.pos - m.pos
	m.aim = to.angle()
	var reach := float(m.stat("reach", 1))
	if to.length() <= m.radius + sim.hero.radius + reach * 0.5:
		sim.snatch(m)
		return
	_seek(m, sim, sim.hero.pos, m.dash)


static func _flee(m: MobState, sim: FightSim) -> void:
	var away := m.pos - sim.hero.pos
	if m.flee_home:
		away = m.home - m.pos
	if away.length() < 1e-4:
		away = Vector2.from_angle(m.facing)
	var dir := away.normalized()
	if sim.now < m.detour_until:
		dir = (dir + m.detour).normalized()
	elif m.pos.distance_to(m.last_think_pos) < m.dash * 0.064 * BLOCKED_SHARE and m.speed < m.dash * 0.3:
		m.detour = dir.orthogonal() * (1.0 if m.id % 2 == 0 else -1.0) * 1.5
		m.detour_until = sim.now + 500.0
	m.want = dir * m.dash
	m.aim = dir.angle()


## Straight at a point, stepping round whatever stops it for half a second.
static func _seek(m: MobState, sim: FightSim, target: Vector2, speed: float) -> void:
	var to := target - m.pos
	if to.length() < 0.2:
		m.want = Vector2.ZERO
		return
	var dir := to.normalized()
	# Going for the player where the straight line meets a cliff or the sea: take
	# the ground's way round instead.
	if sim.nav != null and target.distance_squared_to(sim.hero.pos) < 0.25 \
			and not NavField.line_walkable(sim.world, m.pos, sim.hero.pos, minf(m.radius, 0.45)):
		sim.refresh_nav()
		var way := sim.nav.direction(m.pos)
		if way != Vector2.ZERO:
			m.want = way * speed
			m.aim = way.angle()
			return
	if sim.now < m.detour_until:
		dir = (dir * 0.4 + m.detour).normalized()
	elif m.want.length() > 0.1 and m.pos.distance_to(m.last_think_pos) < speed * 0.064 * BLOCKED_SHARE:
		var side := 1.0 if Rng.hash01(m.id, floori(sim.now / 1000.0)) < 0.5 else -1.0
		m.detour = dir.orthogonal() * side
		m.detour_until = sim.now + 500.0
	m.want = dir * speed
	m.aim = to.angle()
