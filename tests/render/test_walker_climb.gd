extends TestCase
## THE CLIMB UP A WALKER (WalkerClimb, ROADMAP slice 3 step 7), headless: the
## gait carries him, the holds are the seed's, breath is the grip, his leg's
## swing forbids a move and drains him, a set-down shakes a spent climber off, a
## fall is caught and never kills, and a climber who reads the gait reaches the
## hub inside the set piece's time.

const Def := preload("res://src/core/colossus/colossus_def.gd")
const Route := preload("res://src/core/colossus/colossus_route.gd")
const Walk := preload("res://src/core/colossus/colossus_walk.gd")

const SIZE := 1300
const SEED := 1


func _def() -> RefCounted:
	return Def.tripod(&"C")


func _route(d: RefCounted) -> RefCounted:
	return Route.make(d, SEED, SIZE)


## The first minute from `from` at which leg `k` is (or is not) in the air.
func _minute(d: RefCounted, r: RefCounted, k: int, in_air: bool, from := 0.0) -> float:
	var m := from
	for i in 4000:
		var p: Dictionary = Walk.pose(d, r, m)
		if (int(p.swinging) == k) == in_air:
			return m
		m += 1.0
	return -1.0


func test_a_planted_foot_holds_him_still_and_a_swing_carries_him() -> void:
	var d := _def()
	var r := _route(d)
	var c := WalkerClimb.begin(0, SEED)
	var up := _minute(d, r, 0, true)
	var down := _minute(d, r, 0, false, up)
	check(up >= 0.0 and down > up, "leg 0 swings and sets down (%.0f, %.0f)" % [up, down])
	var a := c.world_pos(d, Walk.pose(d, r, down + 1.0))
	var b := c.world_pos(d, Walk.pose(d, r, down + 150.0))
	lt(a.distance_to(b), 0.01, "on a planted foot's drum he does not move: %.3f m" % a.distance_to(b))
	var mid := c.world_pos(d, Walk.pose(d, r, _minute(d, r, 0, true, down) + 70.0))
	gt(mid.distance_to(b), 1000.0, "the next swing carries him with the foot: %.0f m" % mid.distance_to(b))
	eq([c.pitch, c.hold], [0, 0], "and he has not moved on it")


func test_the_holds_are_the_seeds_and_every_ledge_is_in_reach() -> void:
	var a := WalkerClimb.begin(0, SEED)
	var b := WalkerClimb.begin(0, SEED)
	var other := WalkerClimb.begin(0, SEED + 1)
	var differs := false
	for p in WalkerClimb.PITCHES.size():
		eq(int(WalkerClimb.PITCHES[p].levels) % WalkerClimb.STANCE_EVERY, 0, "pitch %d ends on a ledge" % p)
		check(a.is_stance(0) and a.is_stance(a.holds_in(p) - 1), "pitch %d starts and ends on a ledge" % p)
		for i in a.holds_in(p):
			eq(a.hold_at(p, i), b.hold_at(p, i), "one seed, one hold (%d, %d)" % [p, i])
			differs = differs or a.hold_at(p, i) != other.hold_at(p, i)
	check(differs, "another seed sets other holds")
	# A full breath climbs further than the gap between two ledges.
	lt(Climb.WIND_PER_LEVEL * WalkerClimb.STANCE_EVERY, FightRules.WIND, "ledge to ledge on one breath")


func test_breath_is_the_grip() -> void:
	var d := _def()
	var r := _route(d)
	var pose: Dictionary = Walk.pose(d, r, _minute(d, r, 0, false))
	var c := WalkerClimb.begin(0, SEED)
	@warning_ignore("return_value_discarded")
	c.step(0.1, pose, true)
	eq(c.breath, FightRules.WIND - Climb.WIND_PER_LEVEL * WalkerClimb.HOLD_EVERY, "a move up costs its levels")
	var moved := false
	for i in 30:
		moved = moved or c.step(0.1, pose, false).has(&"moved")
	check(moved and c.hold == 1, "and he reaches the next hold")
	var before := c.breath
	@warning_ignore("return_value_discarded")
	c.step(1.0, pose, false)
	near(c.breath, before - WalkerClimb.HANG_DRAIN, 0.01, "hanging off a ledge drains him")
	c.breath = 1.0
	var out := c.step(1.0, pose, false)
	check(out.has(&"slipped") and c.hold == 0, "spent, he slides to the ledge below")
	@warning_ignore("return_value_discarded")
	c.step(2.0, pose, false)
	near(c.breath, WalkerClimb.STANCE_REGEN * 2.0, 0.01, "and a ledge gives breath back")


func test_no_move_while_his_leg_swings_and_the_swing_drains_him() -> void:
	var d := _def()
	var r := _route(d)
	var swing: Dictionary = Walk.pose(d, r, _minute(d, r, 0, true) + 5.0)
	var c := WalkerClimb.begin(0, SEED)
	c.hold = 1
	@warning_ignore("return_value_discarded")
	c.step(1.0, swing, true)
	eq(c.busy, 0.0, "his leg in the air, no move")
	near(c.breath, FightRules.WIND - WalkerClimb.HANG_DRAIN * WalkerClimb.SWING_DRAIN_TIMES, 0.01, "and holding on costs more")


func test_a_set_down_shakes_a_spent_climber_off_and_the_cable_catches_him() -> void:
	var d := _def()
	var r := _route(d)
	var up := _minute(d, r, 0, true)
	var c := WalkerClimb.begin(0, SEED)
	c.hold = 3
	c.breath = WalkerClimb.SLIP_BELOW - 1.0
	@warning_ignore("return_value_discarded")
	c.step(0.1, Walk.pose(d, r, up + 5.0), false)
	var out := c.step(0.1, Walk.pose(d, r, _minute(d, r, 0, false, up)), false)
	check(out.has(&"quake") and out.has(&"fell"), "his leg sets down and throws him: %s" % [out])
	eq(c.hold, 0, "caught at the pitch's foot")
	check(c.wound >= 1 and c.wound <= WalkerClimb.WOUND_MOST, "wounded, not killed: %d" % c.wound)
	gt(c.lost_minutes, 0.0, "and time passes on the cable")
	eq(c.state, WalkerClimb.CLIMB, "and he climbs on")


## A climber who rests to a full breath on each ledge and sets off only when his
## leg will stand for the next section reaches the hub, in the 15-20 minutes the
## set piece is ruled at, less a human's looking about (owner ruling 2026-09-30).
func test_a_climber_who_reads_the_gait_reaches_the_hub_in_the_set_piece_time() -> void:
	var d := _def()
	var r := _route(d)
	var c := WalkerClimb.begin(0, SEED)
	var m := _minute(d, r, 0, false)
	var t := 0.0
	var dt := 0.25
	var section := float(WalkerClimb.STANCE_EVERY) / Climb.RATE + 2.0
	var falls := 0
	while c.state != WalkerClimb.DONE and t < 3600.0:
		var pose: Dictionary = Walk.pose(d, r, m)
		var soon: Dictionary = Walk.pose(d, r, m + section * Tuning.MINUTES_PER_SECOND)
		var go := not c.is_stance(c.hold) or (c.breath >= FightRules.WIND - 1.0 and int(soon.swinging) != 0)
		var out := c.step(dt, pose, go)
		if out.has(&"fell"):
			falls += 1
		t += dt
		m += dt * Tuning.MINUTES_PER_SECOND
	eq(c.state, WalkerClimb.DONE, "he reaches the hub")
	eq(falls, 0, "reading the gait, he never falls")
	print("  the climb: %.1f real minutes" % (t / 60.0))
	check(t >= 10.0 * 60.0 and t <= 20.0 * 60.0, "inside the set piece's time: %.1f min" % (t / 60.0))
