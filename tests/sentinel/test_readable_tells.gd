extends TestCase
## EVERY KEEPER BITE IS READ IN TIME BY A PERSON (FightRules.readable_windup):
## each phase's bite is told long enough for a player who sees it start at the
## slow end of a person's reaction to dodge and walk out of its box from the
## middle of it. Read off the declarations, so a new keeper, or a phase tuned
## later, is held to it with no row added here. A floor, not a target: a keeper's
## threat comes from its rhythm and from catching a player committed to a
## swing, never from a tell a free person cannot answer.


func test_every_keeper_bite_gives_a_person_time_to_get_out() -> void:
	var short: Array[String] = []
	for d: SentinelDef in Sentinels.all():
		for i in d.phases.size():
			var b := Blow.from_dict(d.phase(i).bite)
			var need := FightRules.readable_windup(b, Tuning.PLAYER_RADIUS)
			if b.windup < need:
				short.append("%s phase %d: %d ms, needs %d" % [d.land, i, b.windup, need])
	check(short.is_empty(), "every keeper bite is read in time (%s)" % "; ".join(short))


func test_the_rule_is_what_a_dodge_and_a_walk_can_do() -> void:
	# A box a dodge clears from its middle asks a reaction and a dodge.
	var narrow := Blow.from_dict({"swing": [100, 100, 100, 100], "reach": 1.0, "width": 0.4})
	eq(FightRules.readable_windup(narrow, Tuning.PLAYER_RADIUS), int(FightRules.READ_REACT_MS) + FightRules.DODGE_MS, "a narrow bite asks a reaction and a dodge")
	# A tile past what the dodge carries is a tile walked.
	var width := 2.0 * (FightRules.dodge_reach() - Tuning.PLAYER_RADIUS + Tuning.WALK_SPEED)
	var wide := Blow.from_dict({"swing": [100, 100, 100, 100], "reach": 1.0, "width": width})
	near(float(FightRules.readable_windup(wide, Tuning.PLAYER_RADIUS)), FightRules.READ_REACT_MS + FightRules.DODGE_MS + 1000.0, 1.5, "a second of walking past the dodge")
	# A drop is cleared from under its middle, by its reach.
	var drop := Blow.from_dict({"swing": [100, 100, 100, 100], "reach": FightRules.dodge_reach() + Tuning.WALK_SPEED * 0.5, "width": 0.1, "area": true})
	near(float(FightRules.readable_windup(drop, Tuning.PLAYER_RADIUS)), FightRules.READ_REACT_MS + FightRules.DODGE_MS + 500.0, 1.5, "half a second of walking out from under a drop")
	# The dodge it counts on is the dodge the sim gives.
	var carried := 0.0
	for ms in FightRules.DODGE_MS:
		carried += FightRules.dodge_speed(float(ms) + 0.5) / 1000.0
	near(FightRules.dodge_reach(), carried, 0.01, "a dodge carries what its burst covers")
