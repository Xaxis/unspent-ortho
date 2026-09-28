extends TestCase
## A SHAFT'S START IS SHORT (S5e). The way down a shaft is a press the player
## waits on: `20_realms.enter` onto the world under this one. Its once-per-world
## work (the sky's maps, the light index, the treads crushed into the land, the
## works map) is done beside the world on the raise's worker (RealmWarm), and the
## view builds only the chunk underfoot on the press (ARRIVE_CHUNKS). Asked at
## the real size on seed 7: the enter onto a world raised for it is under the
## bar, in yardsticks; the same enter onto the same world grown afresh, with
## nothing got ready beside it, is over it (that is the bar seeing the work).
##
## BAR: 2 s on the laptop the start was measured on (a yardstick there is about
## 34 us), where the enter was 9.3 s before and is 1.0 s now.

const Sx := preload("res://tests/save/save_fixture.gd")
const BAR := 58000.0


func test_the_way_down_a_shaft_starts_short() -> void:
	Sx.use_root("crossing-start")
	var g := Sx.game(tree, ["--seed=7", "--hour=10"])
	var r := Sx.system(g, "20_realms")
	var shafts: Array = r.get("here")
	check(not shafts.is_empty(), "seed 7 has a shaft")
	if shafts.is_empty():
		Sx.end(g)
		Sx.finish()
		return
	var shaft: Portal = shafts[0]
	# Raised as a player's walk to the shaft raises it: its work beside it.
	var below := RealmWorlds.take(g.options.seed_value, g.world.size, Realm.UNDERGROUND)
	await frames(3)
	var yard := TestCase.yardstick_us()
	r.call("cross", shaft)
	var ms: Dictionary = (r.get("enter_ms") as Dictionary).duplicate()
	var ready_us := float(ms.get("total", INF)) * 1000.0
	eq(g.world, below, "down the shaft, onto the world raised for it")
	# Back up, then the same world grown afresh with nothing got ready beside it.
	r.call("cross", (r.get("here") as Array)[0])
	await frames(3)
	var bare := BootWorld.world(Realm.seed_for(g.options.seed_value, Realm.UNDERGROUND), g.world.size, Realm.UNDERGROUND)
	var at := Portals.paired(below, shaft.id).pos
	r.call("enter", bare, Realm.UNDERGROUND, at)
	var bare_us := float((r.get("enter_ms") as Dictionary).get("total", INF)) * 1000.0
	print("  crossing start: %.0f ms raised beside, %.0f ms bare; ms by step %s" % [ready_us / 1000.0, bare_us / 1000.0, ms])
	yard_lt(ready_us, bare_us, yard, BAR, "the enter down a shaft, onto a world got ready beside it")
	Sx.end(g)
	Sx.finish()
