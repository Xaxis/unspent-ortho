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
##     and otherwise waits on the nearest.
## Raids, gates and every multi-machine balance number are measured with it.

## How wide the crowd may stand around the player, seen from where they stand,
## before they are flanked and give ground.
const FLANK := deg_to_rad(110.0)
## How far past its reach another body's bite is still worth staying out of.
const OTHER_MARGIN := 0.4


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
	if live.size() > 1 and _flanked(live):
		hero.move = _give_ground(live)
		return
	var target := _open_target(live)
	if target != null:
		_strike(target)
		return
	var near := _nearest()
	if near != null:
		_wait(near)


func _live() -> Array[MobState]:
	var out: Array[MobState] = []
	for m in sim.mobs:
		if m.alive and not m.removed and m.pos.distance_to(sim.hero.pos) < 14.0:
			out.append(m)
	return out


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
		if not ((_open(m) and _open_long_enough(m)) or sim.phase_ready(m)):
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
		if o.stunned(sim.now) or o.spent(sim.now) or (o.machine and o.indifferent()):
			continue
		if _in_box_of(o.bite, o, spot, OTHER_MARGIN):
			return true
	return false
