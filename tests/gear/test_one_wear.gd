extends TestCase
## ONE WAY TO WEAR. Kit (plate, brace, rig, lens, aerial) was worn one piece at a
## time outside the gear slots, so the gear page said "body: empty" over plate
## armour and an oilskin and plate could both be on the body. Kit now takes a
## slot like anything worn, the slot decides, and the fight reads what is on.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_kit_takes_a_slot_like_anything_worn() -> void:
	Sx.use_root("one-wear")
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=11", "--weather=clear:0"])
	await tree.process_frame
	var gear := g.get_node_or_null(^"54_gear")
	var loadout: Loadout = gear.get("loadout")
	g.inventory.add(&"kit_plate")
	eq(loadout.item(&"body"), &"kit_plate", "plate picked up goes on, on the body")
	check(g.inventory.wears(&"plate"), "and the body is plated")
	g.player.hero.read_body()
	check(g.player.hero.plated, "which the fight reads")
	g.inventory.add(&"oilskin")
	UiLink.put_on(g, &"oilskin")
	eq(loadout.item(&"body"), &"oilskin", "an oilskin on the body is in plate's place")
	check(not g.inventory.wears(&"plate"), "and the plate is off: one thing on the body")
	g.inventory.add(&"kit_brace")
	eq(loadout.item(&"hands"), &"kit_brace", "a brace goes on the hands, beside it")
	check(g.inventory.wears(&"brace"), "and the body is braced")
	UiLink.put_on(g, &"oilskin")
	eq(loadout.item(&"body"), &"", "taken off, the body is bare")
	g.inventory.add(&"kit_rig")
	eq(loadout.item(&"body"), &"", "and picking up more does not put the plate back on")
	eq(loadout.item(&"back"), &"kit_rig", "though the rig goes on, on the back")
	UiLink.put_on(g, &"kit_plate")
	check(g.inventory.wears(&"plate"), "plate put back on from the pack")
	g.player.hero.read_body()
	check(g.player.hero.plated, "and the fight reads it again")
	Sx.end(g)
