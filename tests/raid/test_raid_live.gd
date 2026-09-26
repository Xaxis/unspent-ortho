extends TestCase
## A PLAYED RAID, FOUGHT LIVE (SETTLE.md S7). The same probe, sent at the same
## line on the same seed and run on the real frames: with the player idle in
## the yard, a holding that answered its warning (a palisade ring with a gate,
## and three turrets covering each other) holds, at a cost at worst, and an open
## one is broken; with the player fighting, both hold. Measured, not assumed:
## the outcome is whatever the plan writes when the step is over.

const Sx := preload("res://tests/save/save_fixture.gd")

## Frames between the plan's looks; and how many looks before the step's own
## hours are let go by.
const EVERY := 30
const LOOKS := 60


func _probe(holding: String, fight: bool, prepared: bool) -> Dictionary:
	Sx.use_root("raid_live")
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--held=axe_felling",
		"--holding=" + holding, "--attention=0.5"])
	await frames(3)
	var mobs := Sx.system(g, "30_mobs")
	var coast: Coast = mobs.get("coast")
	coast.spawning = false
	coast.rounds = false
	g.player.sim.clear_mobs()
	var sys := Sx.system(g, "48_raids")
	var s: Settlement = Sx.system(g, "46_settlements").call("here")
	if prepared:
		_prepare(Sx.system(g, "46_settlements"), s)
	# Something read the place: nothing is ever sent for a holding nothing has read.
	(sys.call("book", s.id) as Dictionary)["last_read"] = g.clock.minutes
	var plan: RaidPlan = null
	for i in 24:
		if bool(sys.call("tour_seen", "party")):
			break
		g.clock.skip(15.0)
		sys.call("pass_now")
	for p: RaidPlan in (sys.get("plans") as Array):
		if not p.over():
			plan = p
	var out := {"stage": plan.stage if plan != null else &"", "outcome": &"", "looks": 0}
	if plan == null:
		Sx.end(g)
		Sx.finish()
		return out
	var whole := 0.0
	for p in s.pieces:
		whole += p.health
	var sim: FightSim = g.player.sim
	var next_swing := -INF
	for i in LOOKS:
		for f in EVERY:
			await frames(1)
			if fight and sim.now >= next_swing and sim.hero.swing_refusal(sim.now) == &"":
				var m := _nearest_raider(sim, s)
				if m != null:
					_stand_to_strike(g, m)
					sim.press_swing()
					next_swing = sim.now + 60.0
		sys.call("pass_now")
		out.looks = i + 1
		if plan.over():
			break
	if not plan.over():
		g.clock.skip(RaidStage.minutes(plan.stage) + 5.0)
		sys.call("pass_now")
	var after := 0.0
	for p in s.pieces:
		after += p.health
	out.outcome = plan.outcome
	out.lost = whole - after
	Sx.end(g)
	Sx.finish()
	return out



## What a holding that answered its warning stands behind: a palisade ring with
## a gate in it, and three turrets covering each other in the yard.
const RING := 5.0
const GUNS := 3


func _prepare(h: Node, s: Settlement) -> void:
	h.call("wall_in", s, RING, 0.0)
	for k in GUNS:
		var gun: Structure = h.call("place_piece", s, StructureKind.TURRET,
			s.centre + Vector2.from_angle(TAU * k / float(GUNS)) * 1.6, 0.0)
		gun.powered = true


func test_a_prepared_holding_holds_a_probe_and_an_open_one_is_broken() -> void:
	var kit := "hut,plot,store,battery_stack,battery_stack,solar_array"
	var ready: Dictionary = await _probe(kit, false, true)
	var open: Dictionary = await _probe("hut,plot,store,radio_mast", false, false)
	eq(ready.stage, RaidStage.PROBE, "a probe came for the prepared one")
	eq(open.stage, RaidStage.PROBE, "and for the open one")
	check(ready.outcome in [&"held", RaidResolve.HELD_AT_COST], "the prepared holding held, the player idle (%s after %d looks, lost %.1f)" % [ready.outcome, ready.looks, ready.lost])
	eq(open.outcome, &"broken", "the open one was broken (%s after %d looks, lost %.1f)" % [open.outcome, open.looks, open.lost])


func test_with_the_player_fighting_both_hold() -> void:
	var ready: Dictionary = await _probe("hut,plot,store,battery_stack,battery_stack,solar_array", true, true)
	var open: Dictionary = await _probe("hut,plot,store,radio_mast", true, false)
	check(ready.outcome in [&"held", RaidResolve.HELD_AT_COST], "the prepared one held (%s, lost %.1f)" % [ready.outcome, ready.lost])
	check(open.outcome in [&"held", RaidResolve.HELD_AT_COST], "and the open one (%s, lost %.1f)" % [open.outcome, open.lost])


## What the party broke by hand is part of how the step ended. A raid that put
## blows into a piece in the yard and then ran its course was written down as
## `held` whenever the paper settle of what it had left over broke nothing.
func test_a_blow_struck_live_is_not_written_off_as_held() -> void:
	Sx.use_root("raid_live")
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=10", "--holding=hut,plot,store"])
	await frames(3)
	var sys := Sx.system(g, "48_raids")
	var s: Settlement = Sx.system(g, "46_settlements").call("here")
	var plan := RaidPlan.new()
	plan.id = 91
	plan.settlement_id = s.id
	plan.stage = RaidStage.PROBE
	plan.state = &"under_way"
	(sys.get("plans") as Array).append(plan)
	var hut: Structure = s.structures_of(StructureKind.HUT)[0]
	@warning_ignore("return_value_discarded")
	s.damage_structure(hut.id, 2.0)
	plan.broke.append(hut.id)
	# Nothing left over to spend: the paper settle breaks nothing.
	sys.call("_settle_raid", plan, s, 0.0)
	eq(plan.outcome, RaidResolve.HELD_AT_COST, "a hut struck in the yard and left standing is held at a cost, not held")
	Sx.end(g)
	Sx.finish()


## GRADED OUTCOMES (SETTLE.md S7). `broken` is the raid getting what its role
## came for: a piece ruined, or people taken. A piece struck and still standing,
## with the party down or gone, is `held at cost`: the damage stays, and the
## slate says what wants mending. The paper settle and the live path grade alike
## because both end through RaidResolve.outcome_of.
func test_a_struck_piece_left_standing_is_held_at_cost() -> void:
	var s := Settlement.new(1, Realm.SURFACE, Vector2(20, 20))
	var hut := s.add(StructureKind.HUT, Vector2(21, 20))
	var mast := s.add(StructureKind.RADIO_MAST, Vector2(19, 20))
	eq(RaidResolve.outcome_of(s, {}), &"held", "nothing struck: held")
	@warning_ignore("return_value_discarded")
	s.damage_structure(hut.id, 2.0)
	eq(RaidResolve.outcome_of(s, {"broke": [hut.id]}), RaidResolve.HELD_AT_COST, "struck and standing: held at cost")
	s.destroy_structure(mast.id)
	eq(RaidResolve.outcome_of(s, {"broke": [hut.id, mast.id], "ruined": [mast.id]}), &"broken", "a piece ruined: broken")
	eq(RaidResolve.outcome_of(s, {"took": [3]}), &"broken", "somebody taken: broken")


func _nearest_raider(sim: FightSim, s: Settlement) -> MobState:
	var best: MobState = null
	for m in sim.mobs:
		if m.raider and m.alive and not m.removed and m.pos.distance_to(s.centre) < 14.0:
			if best == null or m.pos.distance_to(sim.hero.pos) < best.pos.distance_to(sim.hero.pos):
				best = m
	return best


## Where a swing reaches this body's working part, facing it (FightRules.side_of).
func _stand_to_strike(g: Game, m: MobState) -> void:
	var turn := 0.0
	match m.part:
		&"back": turn = PI
		&"left": turn = -PI * 0.5
		&"right": turn = PI * 0.5
	var at := m.pos + Vector2.from_angle(m.facing + turn) * (m.radius + g.player.hero.radius * 0.5)
	g.player.pos = at
	g.player.hero.pos = at
	g.player.hero.facing = (m.pos - at).angle()
