class_name Brains
## What a body wants to do, every 64 ms (design-extract §7.3, §7.4). A brain
## only sets `want` (tiles/s), `aim` and starts bites; FightSim moves bodies,
## turns them and lands blows. Six approaches:
##   errand  walks its line; closes on you only when you are near, seen clear, and rested
##   charge  commits to a bearing for a run, then stands and comes round (420 ms x turns)
##   rush    a 1000 ms lunge cycle: press in and bite for 620 ms, circle for the rest
##   dart    closes, takes what it came for, and runs until it is clear
##   throw   keeps a lane's length off, throws down it when squarely aimed, and
##           stands to reload after (FightRules.throws: its bite IS the lane)
##   drop    waits on a ledge over you and comes down on where you stood; once
##           down among you it fights at close quarters, as a rush does

const RUN_MS := 900
const TURN_PAUSE_MS := 420
const LUNGE_CYCLE_MS := 1000
const LUNGE_PRESS_MS := 620
const ERRAND_CLOSE_MS := 3000
const ERRAND_REST_MS := 4000
## A run that covers less than this share of its expected distance hit something.
const BLOCKED_SHARE := 0.35
## Radians off its facing a machine's close bite may be thrown at.
const FACING_BITE := 0.6
## A worker goes round someone standing on its round this far ahead (tiles),
## passing them with this much room past both bodies.
const GO_ROUND_AHEAD := 6.0
const GO_ROUND_CLEAR := 0.9
const VIA_RETRY_MS := 4000.0
## A thrower comes on until the player is inside this share of its lane, and
## gives ground to one inside the near share of it.
const THROW_FAR := 0.85
const THROW_NEAR := 0.45
## Radians off the player it throws at. A load goes where the arm faces, and a
## lane is half a tile wide five tiles out: any looser and a player standing
## still is missed, which is not a thrower.
const THROW_AIM := 0.05
## A dropper leads a moving player by this share of its windup (Brains._drop_spot).
const DROP_LEAD := 0.8
const DROP_LEAD_MAX := 2.5


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
	if m.machine and (m.mood == MobState.IDLE or m.mood == MobState.WORKING) and _listening(m, sim):
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
				&"throw": _throw(m, sim)
				&"drop": _drop(m, sim)
				_: _seek(m, sim, _target(m, sim), m.dash)
		MobState.ATTACKING:
			match m.approach:
				&"errand": _errand(m, sim)
				&"dart": _dart(m, sim)
				&"charge": _charge(m, sim, m.quick, TURN_PAUSE_MS * int(m.stat("turns", 1)))
				&"throw": _throw(m, sim)
				&"drop": _drop(m, sim)
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


## A machine at its work that heard something: it stands and puts its optics on
## where the noise came from until it is satisfied. Told on the body alone (the
## whole machine turns; its part flickers with the suspicion), never in words.
## Nothing else in the plan stops for it: it goes back to its round after.
static func _listening(m: MobState, sim: FightSim) -> bool:
	if sim.now >= m.look_until:
		return false
	m.want = Vector2.ZERO
	m.aim = (m.heard_at - m.pos).angle() if m.heard_at.distance_squared_to(m.pos) > 1e-4 else m.facing
	return true


## A body whose whole trade is reading the land sweeps its cone across and back
## on an exact period (StealthQuery.sweep). The rhythm is the point: a patrol
## that never varies leaves a gap a player can learn and walk through.
static func _sweeping(m: MobState, sim: FightSim) -> bool:
	if not StealthQuery.sweeps(m.row):
		return false
	m.want = Vector2.ZERO
	m.aim = StealthQuery.sweep(m.bearing.angle(), sim.now / 1000.0, m.phase_ms / 1000.0)
	return true


static func _idle(m: MobState, sim: FightSim) -> void:
	if m.machine and m.at_work():
		if FightSim.in_way_of(m, sim.hero.pos, sim.hero.radius):
			# Held up by someone right in front of it: it stands and faces them. A
			# glance does not stop or turn it; only being in its way does.
			m.want = Vector2.ZERO
			m.aim = (sim.hero.pos - m.pos).angle()
			return
		_go_round(m, sim)
	if m.machine:
		if m.line_a.distance_squared_to(m.line_b) < 0.01:
			if not _sweeping(m, sim):
				m.want = Vector2.ZERO
			return
		_walk_line(m, m.pace * 0.6, sim.now)
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


## Someone standing on its round further ahead: a worker goes round them, by a
## point beside them on the side they are not, on ground it can stand on. It is
## only held up (and only then takes it amiss) by someone who steps right in
## front of it.
static func _go_round(m: MobState, sim: FightSim) -> void:
	if m.via.is_finite():
		if m.pos.distance_to(m.via) < 0.4:
			m.via = Vector2.INF
		return
	if sim.now < m.via_retry_at:
		return
	var dir := m.path_dir()
	if dir == Vector2.ZERO:
		return
	var hero := sim.hero
	var off := hero.pos - m.pos
	var along := off.dot(dir)
	var across := off.dot(dir.orthogonal())
	var near := m.radius + hero.radius + FightSim.CROWD_AHEAD
	if along <= near or along > GO_ROUND_AHEAD or absf(across) >= m.radius + hero.radius + GO_ROUND_CLEAR:
		return
	var clear := m.radius + hero.radius + GO_ROUND_CLEAR
	var first := -1.0 if across > 0.0 else 1.0
	for side: float in [first, -first]:
		var p := hero.pos + dir.orthogonal() * side * clear + dir * (m.radius + 0.5)
		var t := Vector2i(floori(p.x), floori(p.y))
		if sim.world != null and (not sim.world.in_bounds(t.x, t.y) or Ground.is_water(sim.world.ground_at(t.x, t.y))):
			continue
		if sim.query != null and not sim.query.standable(t.x, t.y):
			continue
		m.via = p
		return


static func _walk_line(m: MobState, speed: float, now: float = 0.0) -> void:
	if m.via.is_finite():
		var to_via := m.via - m.pos
		if m.pos.distance_to(m.last_think_pos) < speed * 0.064 * 0.2 and m.speed < 0.05 and m.want.length() > 0.0:
			# Something stops it going round: it stands a beat, then keeps to its round
			# (turning back if that is blocked too) and does not try again for a while.
			m.via = Vector2.INF
			m.via_retry_at = now + VIA_RETRY_MS
			m.want = Vector2.ZERO
			return
		m.want = to_via.normalized() * speed if to_via.length() > 0.05 else Vector2.ZERO
		m.aim = to_via.angle()
		return
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
		if not _sweeping(m, sim):
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
		if m.machine and m.locked_out(now):
			# Spent after a bite: no new run until the drive has wound back. It stands
			# and grinds round (slowly, FightSim), and whatever side it bit with is open.
			m.want = Vector2.ZERO
			m.aim = to.angle()
			return
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
	if m.machine and m.spent(now):
		# Overrun and winding back (FightSim carries it on through the recovery):
		# it neither presses nor circles until the bite's cooldown is over.
		m.want = Vector2.ZERO
		return
	if d > maxf(1.9 * skin, strike) + 0.8:
		_seek(m, sim, hero.pos, m.quick)
		return
	var cyc := fposmod(now + m.phase_ms, LUNGE_CYCLE_MS)
	if cyc < LUNGE_PRESS_MS:
		m.want = dir * m.quick if d > skin * 0.95 else Vector2.ZERO
		# Only a bite it faces: a machine turning slowly with the player at its back
		# does not snap at the air in front of it.
		var off := absf(wrapf(to.angle() - m.facing, -PI, PI))
		if d <= strike and (off < FACING_BITE or not m.machine) and can_bite(m, now):
			bite(m, sim)
	else:
		var side := 1.0 if m.id % 2 == 0 else -1.0
		var inout := sin((cyc - LUNGE_PRESS_MS) / 380.0 * PI) * 0.35
		var want_d := strike + 0.4
		var radial := clampf(d - want_d, -1.0, 1.0)
		m.want = (dir.orthogonal() * side * 0.8 + dir * (radial * 0.6 - inout)).normalized() * m.quick * 0.6


## Throw: come on to a lane's length, turn square on and throw down the lane.
## Once thrown, whether it landed or not, it stands and reloads through the
## blow's recovery and cooldown, coming round only slowly (FightRules.RECOVER_TURN):
## the one time to close on it. Inside the near part of its lane it backs off
## at its close-quarters pace, slower than a player walks, before it throws.
static func _throw(m: MobState, sim: FightSim) -> void:
	var now := sim.now
	var to := sim.hero.pos - m.pos
	var d := to.length()
	m.aim = to.angle()
	if m.locked_out(now):
		m.want = Vector2.ZERO
		return
	var lane := m.radius + (m.bite.reach if m.bite != null else 1.0)
	if d > lane * THROW_FAR:
		_seek(m, sim, _target(m, sim), m.dash)
		return
	# Too close to throw down a lane, it backs off first, unless backing off has
	# stopped against something: then it throws from where it is.
	var backing := d < lane * THROW_NEAR
	if backing and m.want != Vector2.ZERO and m.pos.distance_to(m.last_think_pos) < m.quick * FightRules.THINK_MS / 1000.0 * BLOCKED_SHARE:
		backing = false
	if not backing and absf(wrapf(to.angle() - m.facing, -PI, PI)) < THROW_AIM and can_bite(m, now):
		bite(m, sim)
		return
	m.want = -to / maxf(d, 1e-4) * m.quick if backing else Vector2.ZERO


## Drop: from a ledge a blow cannot cross (FightRules.LEDGE_LEVELS or more over
## the player) it waits, watching, until the player is within DROP_REACH of
## under it; then it tells, and comes down on where they stood when it told
## (MobState.drop_at, set here and never moved). Down among them it is a close
## fighter like any rush. Nothing here climbs it back up: that is its legs'
## business on the way to wherever it is chasing.
static func _drop(m: MobState, sim: FightSim) -> void:
	var now := sim.now
	var to := sim.hero.pos - m.pos
	m.aim = to.angle()
	if m.locked_out(now):
		m.want = Vector2.ZERO
		return
	if sim.level_of(m.pos) - sim.level_of(sim.hero.pos) >= FightRules.LEDGE_LEVELS:
		m.want = Vector2.ZERO
		if m.drop != null and to.length() <= FightRules.DROP_REACH and not m.stunned(now):
			m.drop_from = m.pos
			m.drop_at = _drop_spot(m, sim)
			m.start_blow(m.drop, now)
			sim.emit(&"windup", {"mob": m})
		return
	_lunge(m, sim)


## Where a dropper comes down: where the player will be if they keep on as they
## are going for DROP_LEAD of its windup, no more than DROP_LEAD_MAX tiles on,
## and never onto other ground than theirs. So walking on under it is walking
## into it, and reading the shadow and leaving it is the answer.
static func _drop_spot(m: MobState, sim: FightSim) -> Vector2:
	var hero := sim.hero
	var on := hero.move.limit_length(1.0) * hero.speed * m.drop.windup / 1000.0 * DROP_LEAD
	var spot := hero.pos + on.limit_length(DROP_LEAD_MAX)
	if sim.level_of(spot) != sim.level_of(hero.pos):
		return hero.pos
	return spot


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
