extends TestCase
## RELIC HEAT (GEAR.md G9, §10 ruling 2): a keeper's power, or any relic, worn is
## a found-tech signature the plan's network reads. Each relic in the loadout
## raises the region the player is in by Interference.CAUSES.carried an hour
## (32_disposition._cool, the cause &"carried"); a made kit raises nothing.
## Through the game, as test_in_game does every cause: the relic fitted by the
## boot's --fit, the hours by the world clock.

func _game(fit: String) -> Game:
	var o := BootOptions.parse(PackedStringArray(["--seed=1", "--size=128", "--hour=11", "--weather=clear:0", "--fit=" + fit]))
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	return g


func _system(g: Game, name: String) -> Node:
	return g.get_node(name)


func test_a_relic_is_counted_and_a_made_kit_is_not() -> void:
	eq(Gear.relics_in([&"mod_lock", &"knife", &"oilskin"]), 1, "the lock is a keeper's relic")
	eq(Gear.relics_in([&"mod_lock", &"mod_listen"]), 2, "two relics, two")
	eq(Gear.relics_in([&"oilskin", &"wrap_warm", &"glide_wing", &"coat_scale"]), 0, "made and mended kit is not")


## An hour on the coast, calm, wearing it: the file warms by the relic's heat
## an hour, and bare it stays cold.
func _hour(fit: String) -> float:
	var g := _game(fit)
	await frames(3)
	var gear: Node = _system(g, "54_gear")
	var worn: Array[StringName] = (gear.get("loadout") as Loadout).all_ids()
	var disp: Node = _system(g, "32_disposition")
	var inter: Interference = disp.get("interference")
	var net := Interference.network(g.world, g.player.pos)
	var before := inter.value(net)
	g.clock.minutes += 60.0
	await frames(3)
	var after := inter.value(net)
	print("  info an hour wearing %s (%s): %.3f -> %.3f" % [fit, worn, before, after])
	g.queue_free()
	await frames(1)
	return after - before


func test_a_worn_relic_warms_the_region_by_the_hour() -> void:
	var relic: float = await _hour("glide_wing,mod_lock")
	var made: float = await _hour("glide_wing,oilskin")
	near(relic, float(Interference.CAUSES[&"carried"]), 0.01, "an hour with the lock worn warms the file by a relic's hour")
	near(made, 0.0, 1e-4, "an hour in made kit does not")


## A player must be able to learn why their region warms: the reads app names
## the cause under its trace while a relic is worn (StoryContent.READS_CAUSE, by
## id; the words are the story's), and says nothing of it in made kit.
func _causes(fit: String) -> Array:
	var g := _game(fit)
	await frames(3)
	var disp: Node = _system(g, "32_disposition")
	var reads: Dictionary = disp.call(&"_reads", g)
	g.queue_free()
	await frames(1)
	return reads.get("causes", [])


func test_the_slate_names_what_you_carry() -> void:
	var worn: Array = await _causes("glide_wing,mod_lock")
	var made: Array = await _causes("glide_wing,oilskin")
	check(worn.has(StoryContent.READS_CAUSE[&"carried"]), "wearing a relic, the reads app names the heat (%s)" % [worn])
	check(not made.has(StoryContent.READS_CAUSE[&"carried"]), "in made kit it does not")
