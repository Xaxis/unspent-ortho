extends TestCase
## A PLAYED RAID, FOUGHT LIVE (SETTLE.md S7): how a step that was fought in the
## yard is written down when it is over.

const Sx := preload("res://tests/save/save_fixture.gd")


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
	eq(plan.outcome, &"broken", "a hut struck in the yard is a broken holding, not a held one")
	Sx.end(g)
	Sx.finish()

