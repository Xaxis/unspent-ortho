extends RefCounted
## A first-hour player who has been told one rule and has human limits: see the
## tell, get out of its way, and strike the working side while the machine is
## spent. Unlike bot.gd (who has learnt every machine and times dodges to the
## slice), this one:
##   - sees a tell only react_ms after it starts, and presses the dodge then,
##     never timed to the invulnerable window;
##   - walks (never runs) and swings only from where the blow reaches the part;
##   - reads only what a player can see: the windup and strike poses, a body
##     that has overrun and stands spent, where it stands and which way it faces.
## If this player cannot beat a first-hour machine with the half-worn start
## knife, a person meeting it for the first time cannot either.

var react_ms := 220.0
## How long after the bite's live window the escape keeps being held.
const ESCAPE_HOLD_MS := 60.0

var sim: FightSim
var swings := 0
var dodges := 0
var _answered := -1.0
var _escape := Vector2.ZERO
var _escape_until := -1.0
var _last_pull := -1000.0


func _init(s: FightSim) -> void:
	sim = s


func act() -> void:
	var hero := sim.hero
	var now := sim.now
	hero.run = false
	if hero.held():
		if now - _last_pull >= 160.0:
			_last_pull = now
			sim.press_swing()
		return
	var m := _nearest()
	if m == null:
		hero.move = Vector2.ZERO
		return
	if now < _escape_until:
		hero.move = _escape
		return
	if _tell_to_answer(m):
		return
	if _charge_to_leave(m):
		return
	if _open(m):
		_strike(m)
		return
	_wait(m)


## A windup the player has had time to see, whose box covers where they stand:
## dodge out of it the shorter way and keep going that way until it has passed.
func _tell_to_answer(m: MobState) -> bool:
	var now := sim.now
	var hero := sim.hero
	if m.blow == null or m.blow_phase(now) != &"windup" or m.blow_at == _answered:
		return false
	if now - m.blow_at < react_ms:
		return false
	_answered = m.blow_at
	if not _in_box(m, hero.pos, 0.5):
		return false
	var b := m.blow
	var local := (hero.pos - m.pos).rotated(-m.facing)
	var fwd := Vector2.from_angle(m.facing)
	var side := Vector2.from_angle(m.facing + PI * 0.5) * (1.0 if local.y >= 0.0 else -1.0)
	var back_need := m.radius + b.reach + hero.radius - local.x
	var side_need := b.width * 0.5 + hero.radius - absf(local.y)
	# Aside is where the spent body can be got round; back is only for a narrow miss.
	_escape = side if side_need < back_need + 0.6 else fwd
	hero.move = _escape
	sim.press_dodge()
	dodges += 1
	_escape_until = m.blow_at + b.windup + b.active + ESCAPE_HOLD_MS
	return true


## A machine coming on at a run with the player in its row: out of the row.
func _charge_to_leave(m: MobState) -> bool:
	var hero := sim.hero
	if not m.charging:
		return false
	var local := (hero.pos - m.pos).rotated(-m.facing)
	if local.x <= 0.0 or local.x > 6.0 or absf(local.y) > m.radius + hero.radius + 0.9:
		return false
	var side := Vector2.from_angle(m.facing + PI * 0.5) * (1.0 if local.y >= 0.0 else -1.0)
	hero.move = side
	return true


## What a player reads as a chance: a machine spent after its bite or stopped
## by a blow, a charger standing between runs, a worker not yet roused, or a
## creature (no plate: any side, any time it is not biting).
func _open(m: MobState) -> bool:
	var now := sim.now
	if m.stunned(now):
		return true
	if not m.machine:
		return m.blow == null or m.blow_phase(now) in [&"recovery", &"cooldown", &""]
	if m.indifferent():
		return true
	if m.spent(now):
		return true
	# A charger standing between runs turns badly: that is the whole answer to one.
	return m.approach == &"charge" and not m.charging and (now < m.pause_until or m.part != &"front")


func _strike(m: MobState) -> void:
	var hero := sim.hero
	var reach := _blow().reach
	var spot := _part_spot(m, reach)
	var to_mob := m.pos - hero.pos
	var from_spot := hero.pos.distance_to(spot)
	# Squarely on the side, not at the edge of it: a turning body carries an edge
	# swing onto plate before it lands.
	var square := m.part == &"none" or absf(wrapf((hero.pos - m.pos).angle() - (spot - m.pos).angle(), -PI, PI)) < 0.55
	var reaches := square and sim.reaches_part(m, hero.pos) \
			and FightRules.box_hits(hero.pos, to_mob.angle(), hero.radius, _blow(), m.pos, m.radius)
	if reaches:
		hero.move = Vector2.ZERO
		hero.facing = to_mob.angle()
		if hero.swing_refusal(sim.now) == &"":
			sim.press_swing()
			swings += 1
		return
	if from_spot < 0.08:
		hero.move = to_mob.normalized() * 0.3
		return
	hero.move = _round_to(m, spot)


## Stand and let it come (the bite is what opens it), closing in only when it
## hangs back, and out of a charger's row.
func _wait(m: MobState) -> void:
	var hero := sim.hero
	var away := hero.pos - m.pos
	var d := away.length()
	var b := m.bite
	var keep := m.radius + hero.radius + (b.reach if b != null else 0.6) + 0.7
	var dir := Vector2.ZERO
	if d < m.radius + hero.radius + 0.2:
		dir = away / maxf(d, 0.001)
	elif d > keep + 2.0:
		dir = -away / d
	if m.approach == &"charge":
		var local := away.rotated(-m.facing)
		if local.x > 0.0 and absf(local.y) < m.radius + hero.radius + 0.6:
			dir += Vector2.from_angle(m.facing + PI * 0.5) * (1.0 if local.y >= 0.0 else -1.0)
	hero.move = dir.limit_length(1.0)


func _round_to(m: MobState, spot: Vector2) -> Vector2:
	var hero := sim.hero
	var dir := (spot - hero.pos).normalized()
	var to_mob := m.pos - hero.pos
	var clear := m.radius + hero.radius + 0.25
	var far_side := (hero.pos - m.pos).normalized().dot((spot - m.pos).normalized()) < 0.5
	if far_side and to_mob.length() < clear + 0.9 and dir.dot(to_mob.normalized()) > 0.2:
		var tangent := to_mob.normalized().orthogonal()
		if tangent.dot(spot - hero.pos) < 0.0:
			tangent = -tangent
		# Round it close in, where walking gains on its turning fastest.
		dir = (tangent + to_mob.normalized() * clampf(to_mob.length() - clear, -0.6, 0.6)).normalized()
	if m.bite != null and _in_box_of(m.bite, m, hero.pos + dir * 0.4, 0.2) and m.part != &"front" and not m.stunned(sim.now):
		dir = (dir - to_mob.normalized() * 0.6).normalized()
	return dir


func _part_spot(m: MobState, reach: float) -> Vector2:
	var hero := sim.hero
	var off := 0.0
	match m.part:
		&"back": off = PI
		&"left": off = -PI * 0.5
		&"right": off = PI * 0.5
		&"none": off = wrapf((hero.pos - m.pos).angle() - m.facing, -PI, PI)
	return m.pos + Vector2.from_angle(m.facing + off) * (m.radius + hero.radius + reach * 0.5)


func _blow() -> Blow:
	var inv := sim.hero.inventory
	var held: StringName = inv.held if inv != null else &""
	return Blow.for_item(held, inv.edge(held) if inv != null and held != &"" else 10000)


func _nearest() -> MobState:
	var best: MobState = null
	var bd := INF
	for m in sim.mobs:
		if m.alive and not m.removed:
			var d := m.pos.distance_to(sim.hero.pos)
			if d < bd:
				bd = d
				best = m
	return best


func _in_box(m: MobState, p: Vector2, margin: float) -> bool:
	var b := m.blow if m.blow != null else m.bite
	return b != null and _in_box_of(b, m, p, margin)


func _in_box_of(b: Blow, m: MobState, p: Vector2, margin: float) -> bool:
	return FightRules.box_hits(m.pos, m.facing, m.radius, b, p, sim.hero.radius + margin)
