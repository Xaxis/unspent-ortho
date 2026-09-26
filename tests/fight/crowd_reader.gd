extends "res://tests/fight/reader.gd"
## The reader in a crowd: the same human limits (a tell seen react_ms late, a
## walk, a swing only from where it reaches the part), and the four things a
## good player does against more than one machine that the one-machine reader
## does not:
##   - answers ANY tell whose box covers them, not only the nearest body's;
##   - keeps the crowd on one side: when bodies stand on both sides of them
##     (flanked: wider than FLANK apart as seen from the player), backs away
##     from the middle of the crowd until they are in front again;
##   - fights at the edge: strikes only a body that is open and whose part can
##     be reached from a spot no other roused body's bite covers;
##   - picks off the one that is open (spent, stalled), the nearest such first,
##     and otherwise waits on the nearest;
## and plays like a skilled player, not a first-hour one:
##   - sprints to close a window it would miss at a walk (the swing plus the
##     run fit where the swing plus a walk would not);
##   - uses the heavy blow when the opening is long enough for its tell
##     (Reader.heavy) and no other body could come in while it is told;
##   - walks in on a machine that will not close (a watcher, a thrower keeping
##     its distance): one that has not thrown a blow for STANDOFF_MS and is not
##     winding up is struck like an open one;
##   - and when walking in has not landed a blow in PRESS_MS (a thrower backing
##     off and turning to keep its plate to them), stands off BAIT_MS instead
##     and lets it throw: the throw is what opens it.
## With an undertow fitted (FightKit.undertow) it hauls in a machine that stands
## off out of reach, when the grapple is ready, there is breath for it, and it
## is the only roused body near.
## Raids, gates and every multi-machine balance number are measured with it.

## How wide the crowd may stand around the player, seen from where they stand,
## before they are flanked and give ground.
const FLANK := deg_to_rad(110.0)
## How far past its reach another body's bite is still worth staying out of.
const OTHER_MARGIN := 0.4
## A machine that has not thrown a blow for this long is not going to come:
## walk in and make it commit.
const STANDOFF_MS := 2500.0
## Walking in on one that will not close, this long without a blow landing
## means it is keeping its plate to the player: stand off this long instead.
const PRESS_MS := 3000.0
const BAIT_MS := 3000.0


func _init(s: FightSim) -> void:
	super(s)
	heavy = true


func act() -> void:
	var hero := sim.hero
	var now := sim.now
	hero.run = false
	if hero.held():
		if now - _last_pull >= 160.0:
			_last_pull = now
			sim.press_swing()
		return
	var live := _live()
	if live.is_empty():
		hero.move = Vector2.ZERO
		return
	if now < _escape_until:
		hero.move = _escape
		return
	for m in live:
		if _tell_to_answer(m):
			return
	for m in live:
		if _charge_to_leave(m):
			return
	if _haul(live):
		return
	if live.size() > 1 and _flanked(live):
		hero.move = _give_ground(live)
		return
	var target := _open_target(live)
	if target != null and _pressed_out(target):
		target = null
	if target != null:
		_strike(target)
		# A window a walk would miss: sprint to it.
		if hero.move != Vector2.ZERO and hero.pos.distance_to(_part_spot(target, _blow().reach)) > 0.6:
			hero.run = true
		return
	var near := _nearest()
	if near != null:
		_wait(near)


## Bodies on both sides: the widest angle between any two, seen from the player.
func _flanked(live: Array[MobState]) -> bool:
	var hero := sim.hero
	for i in live.size():
		for j in range(i + 1, live.size()):
			var a := (live[i].pos - hero.pos).angle()
			var b := (live[j].pos - hero.pos).angle()
			if absf(wrapf(a - b, -PI, PI)) > FLANK and live[i].pos.distance_to(hero.pos) < 6.0 and live[j].pos.distance_to(hero.pos) < 6.0:
				return true
	return false


## Away from the middle of the crowd, and a little to the side it is thinner on.
func _give_ground(live: Array[MobState]) -> Vector2:
	var hero := sim.hero
	var mid := Vector2.ZERO
	for m in live:
		mid += m.pos
	mid /= float(live.size())
	var away := hero.pos - mid
	if away.length() < 0.05:
		away = Vector2.from_angle(hero.facing + PI)
	return away.normalized()


## The nearest body that is open long enough, and whose part is reached from a
## spot no other roused body's bite covers.
func _open_target(live: Array[MobState]) -> MobState:
	var best: MobState = null
	var bd := INF
	var reach := _blow().reach
	for m in live:
		if not ((_open(m) and _open_long_enough_running(m)) or sim.phase_ready(m) or _standing_off(m)):
			continue
		var spot := _part_spot(m, reach)
		if _covered_by_other(spot, m, live):
			continue
		var d := m.pos.distance_to(sim.hero.pos)
		if d < bd:
			bd = d
			best = m
	return best


func _covered_by_other(spot: Vector2, target: MobState, live: Array[MobState]) -> bool:
	for o in live:
		if o == target or o.bite == null:
			continue
		if o.stunned(sim.now) or o.spent(sim.now) or not o.roused():
			continue
		if _in_box_of(o.bite, o, spot, OTHER_MARGIN):
			return true
	return false


## `_open_long_enough`, for a player who will sprint to the spot: the walk out
## of its next bite is measured at a run.
func _open_long_enough_running(m: MobState) -> bool:
	var now := sim.now
	var b := _blow()
	var travel := maxf(0.0, sim.hero.pos.distance_to(_part_spot(m, b.reach)) - 0.3) / maxf(sim.hero.run_speed, 0.1) * 1000.0
	var need := float(b.windup + b.active) + travel + _walk_out_ms(m) * sim.hero.walk_speed / maxf(sim.hero.run_speed, 0.1)
	var left := INF
	if m.stunned(now):
		left = m.stun_until - now
	if m.machine and m.spent(now) and m.blow != null:
		left = maxf(left if left != INF else 0.0, m.blow_at + m.blow.lockout() - now)
	return left >= need


## A machine holding off: roused, no blow thrown for STANDOFF_MS, not winding
## up now, and not charging.
func _standing_off(m: MobState) -> bool:
	if not m.machine or m.indifferent() or m.charging:
		return false
	var now := sim.now
	if m.blow != null and m.blow_phase(now) in [&"windup", &"active"]:
		return false
	return now - m.blow_at > STANDOFF_MS and now - _seen_since.get(m.id, now) > STANDOFF_MS


## Another body nearer than this could be on the player while a heavy is told.
const HEAVY_CLEAR := 5.0


func _heavy_fits(m: MobState) -> bool:
	if not super(m):
		return false
	for o in _live():
		if o == m or o.stunned(sim.now) or o.spent(sim.now) or not o.roused():
			continue
		if o.pos.distance_to(sim.hero.pos) < HEAVY_CLEAR:
			return false
	return true


var _seen_since := {}
var _haul_ready_at := 0.0
## Roused bodies nearer than this, more than one, and it does not haul.
const HAUL_ALONE := 8.0
var hauls := 0


## The grapple on a machine that stands off out of reach, as AbilityGrapple does
## it: ahead of the player (turned to it), in RANGE, for UNDERTOW_WIND x its wind,
## on its cooldown.
func _haul(live: Array[MobState]) -> bool:
	var hero := sim.hero
	if hero.kit == null or not hero.kit.undertow or sim.now < _haul_ready_at:
		return false
	var cost := AbilityGrapple.WIND * FightKit.UNDERTOW_WIND
	if hero.wind < cost + FightRules.DODGE_COST:
		return false
	# One body hauled into a crowd is one more at the player's side: a player
	# hauls a machine they are facing alone.
	var roused := 0
	for m in live:
		roused += int(m.roused() and m.pos.distance_to(hero.pos) < HAUL_ALONE)
	if roused > 1:
		return false
	for m in live:
		if not m.machine or m.stunned(sim.now) or (m.blow != null and m.blow_phase(sim.now) == &"active"):
			continue
		var d := m.pos.distance_to(hero.pos)
		if d < m.radius + hero.radius + _blow().reach + 1.0 or d > AbilityGrapple.RANGE:
			continue
		hero.facing = (m.pos - hero.pos).angle()
		if sim.undertow(m):
			hero.wind -= cost
			_haul_ready_at = sim.now + AbilityGrapple.COOLDOWN * 1000.0
			hauls += 1
			hero.move = Vector2.ZERO
			return true
	return false
## Per body walked in on: [since, its health then, last pressed]; and until
## when it is baited.
var _press := {}
var _bait_until := {}


## Walking in on a body only because it stands off, and that has landed nothing
## for PRESS_MS: bait it for BAIT_MS instead.
func _pressed_out(m: MobState) -> bool:
	var now := sim.now
	if (_open(m) and _open_long_enough_running(m)) or sim.phase_ready(m):
		_press.erase(m.id)
		return false
	if now < float(_bait_until.get(m.id, -INF)):
		return true
	var p: Array = _press.get(m.id, [])
	if p.is_empty() or int(p[1]) != m.health or now - float(p[2]) > 250.0:
		_press[m.id] = [now, m.health, now]
		return false
	p[2] = now
	if now - float(p[0]) > PRESS_MS:
		_press.erase(m.id)
		_bait_until[m.id] = now + BAIT_MS
		return true
	return false


func _live() -> Array[MobState]:
	var out: Array[MobState] = []
	for m in sim.mobs:
		if m.alive and not m.removed and m.pos.distance_to(sim.hero.pos) < 14.0:
			out.append(m)
			if not _seen_since.has(m.id):
				_seen_since[m.id] = sim.now
	return out
