extends RefCounted
## A player who has learnt the machines: reads the tell and steps out of the
## box, walks round to the working part, swings from there, and pulls when held.
## It only uses what a player can see (poses, where bodies stand and face), so
## if it cannot win, a person cannot either.

var sim: FightSim
## Stand-off when waiting on a body's tell.
var wait_distance := 3.2
var _last_press := -1000.0
var _next_swing := 0.0


func _init(s: FightSim) -> void:
	sim = s


## One decision; call between slices.
func act() -> void:
	var hero := sim.hero
	var now := sim.now
	if hero.held():
		if now - _last_press >= 150.0:
			_last_press = now
			sim.press_swing()
		return
	var m := _nearest()
	if m == null:
		hero.move = Vector2.ZERO
		return
	var to := m.pos - hero.pos
	var d := to.length()
	# Is a bite coming that would reach where I stand?
	if m.blow != null:
		var phase := m.blow_phase(now)
		var until_live := m.blow_at + m.blow.windup - now
		if phase == &"windup" and until_live <= 140.0 and _in_box(m, hero.pos, 0.6):
			# Out of the box by the shorter way: back out of its reach, or aside of its width.
			var fwd := Vector2.from_angle(m.facing)
			var side := fwd.orthogonal()
			var local := (hero.pos - m.pos).rotated(-m.facing)
			if local.y < 0.0:
				side = -side
			var b := m.blow
			var back_need := m.radius + b.reach + hero.radius - local.x
			var side_need := b.width * 0.5 + hero.radius - absf(local.y)
			hero.move = fwd if back_need < side_need else side
			sim.press_dodge()
			return
	if m.charging and _in_box_ahead(m, hero.pos):
		# Meet a front-part charge with a blow as it arrives (it stops the work), but
		# only once in its rhythm; otherwise out of the row.
		var mine := Blow.for_item(hero.inventory.held if hero.inventory != null else &"")
		var local := (hero.pos - m.pos).rotated(-m.facing)
		var in_reach := local.x <= m.radius + hero.radius + mine.reach * 0.9 and absf(local.y) < m.radius
		var tell := m.blow == null or m.blow_phase(now) == &"windup" and now - m.blow_at < m.blow.windup - mine.windup - 40
		if m.part == &"front" and in_reach and tell and now >= m.stall_ready_at and hero.swing_refusal(now) == &"" \
				and sim.reaches_part(m, hero.pos):
			hero.move = Vector2.ZERO
			hero.facing = (m.pos - hero.pos).angle()
			sim.press_swing()
			return
		# Out of the row.
		var side := Vector2.from_angle(m.facing).orthogonal()
		if side.dot(hero.pos - m.pos) < 0.0:
			side = -side
		hero.move = side
		hero.run = true
		return
	hero.run = false
	if hero.wind < FightRules.DODGE_COST and _in_box(m, hero.pos, 1.5):
		# Out of breath: give ground until there is a dodge in you again.
		hero.move = (hero.pos - m.pos).normalized()
		return
	var spot := _part_spot(m)
	var to_spot := spot - hero.pos
	var committed := m.blow != null and m.blow_phase(now) in [&"windup", &"active"]
	if to_spot.length() > 0.35:
		# Go round rather than through its front.
		var dir := to_spot.normalized()
		if m.part != &"front" and _in_box(m, hero.pos + dir * 0.6, 0.8):
			dir = (dir + (hero.pos - m.pos).normalized() * 0.8).normalized()
		hero.move = dir
		return
	hero.move = Vector2.ZERO
	hero.facing = to.angle()
	# Swing only into an opening: its next bite cannot come before this swing is done.
	var mine := Blow.for_item(hero.inventory.held if hero.inventory != null else &"")
	var opening := true
	if m.bite != null and _in_box(m, hero.pos, 0.3):
		var slow_tell := m.bite.windup > mine.committed() + 160
		if committed:
			opening = false
		elif m.blow != null and m.blow_at + m.blow.lockout() - now > mine.committed() + 60.0:
			opening = true
		else:
			# It may bite any moment: swing only if its tell is slower than the swing
			# and there is wind left to get out after.
			opening = slow_tell and hero.wind >= FightRules.DODGE_COST + mine.wind_cost
	# A guarded part is only worth a swing while the machine is open.
	opening = opening and sim.reaches_part(m, hero.pos)
	if opening and now >= _next_swing and hero.swing_refusal(now) == &"":
		_next_swing = now + 60.0
		sim.press_swing()


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


func _part_spot(m: MobState) -> Vector2:
	var hero := sim.hero
	var reach := Blow.for_item(hero.inventory.held if hero.inventory != null else &"").reach
	var dist := m.radius + hero.radius + reach * 0.55
	var off := 0.0
	match m.part:
		&"back": off = PI
		&"left": off = -PI * 0.5
		&"right": off = PI * 0.5
		&"none": off = wrapf((hero.pos - m.pos).angle() - m.facing, -PI, PI)
	return m.pos + Vector2.from_angle(m.facing + off) * dist


func _in_box(m: MobState, p: Vector2, margin: float) -> bool:
	var b := m.blow if m.blow != null else m.bite
	if b == null:
		return false
	return FightRules.box_hits(m.pos, m.facing, m.radius, b, p, sim.hero.radius + margin)


func _in_box_ahead(m: MobState, p: Vector2) -> bool:
	var local := (p - m.pos).rotated(-m.facing)
	return local.x > 0.0 and local.x < 6.0 and absf(local.y) < m.radius + 1.4
