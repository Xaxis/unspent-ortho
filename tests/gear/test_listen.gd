extends TestCase
## THE LISTENER'S EAR (GEAR.md G4): the frost sea listener's core on the jig,
## worn on the head. A machine's tell is heard where it cannot be seen: behind
## the player, past a wall, out of the eye's cone, its ring on the ground drawn
## through whatever stands between. Its cost: the player is heard as far as they
## hear, every noise they make LISTEN_NOISE as loud.



func test_the_listeners_core_becomes_the_ear_on_the_jig() -> void:
	check(Gear.is_module(&"mod_listen"), "the ear is a module")
	eq(Items.def(&"mod_listen").get("fits", []), [&"head"], "worn on the head")
	eq(GearTree.row(&"mod_listen").get("grade", &""), &"relic", "a keeper's power is a relic")
	eq(GearTree.made_of(&"mod_listen"), &"listener_core", "made of the listener's core")
	check(ModifierTable.costs(&"mod_listen") != "", "it says what it costs")
	check(FightKit.of([&"mod_listen"]).listen, "the kit reads it")
	eq(UiRules.core_uses(&"listener_core").size(), 2, "the listener's core reads as a choice")
	eq(GearEconomy.problems(), PackedStringArray(), "and the economy still holds")


func test_the_ear_is_heard_back() -> void:
	near(FightKit.of([]).noise_scale(), 1.0, 1e-6, "bare, a noise is as loud as it is")
	near(FightKit.of([&"mod_listen"]).noise_scale(), FightKit.LISTEN_NOISE, 1e-6, "with the ear, it carries as far as the ear hears")
