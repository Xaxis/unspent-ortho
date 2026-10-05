extends TestCase
## WE BREAK THEIR WORKS, THEY BURN A VILLAGE, IN EVERY LAND THAT KEEPS A DEPOT
## (#67). test_reprisal_in_game proves it on one coast yard at 256; a landscape's
## yard stands on its own ground, and six first yards across seeds 1, 7 and 42
## had no roof in REACH, so breaking them cost nobody. On a world of the shipped
## size, from each landscape's first yard, a housing opened by the player's own
## hands sends the yard's hunters (48_raids `_target_for`: the nearest roof in
## REACH, else on the yard's own body, else his own fire there), and when their
## march is done that roof has burned. A yard whose body holds no roof and no
## fire of his sends nobody, and says so by name. A new game has no camp of his,
## so here a yard with no roof is the named skip; tests/raid/test_reprisal_in_game
## burns his camp and his holding. Each land prints its yard,
## its roof, the march and what burned.



func _stand(g: Game, p: Vector2) -> void:
	g.player.hero.pos = p
	g.player.hero.move = Vector2.ZERO
	g.player.pos = p
	g.player.position = g.world.to_3d(p)


## Hold `use` at housing `i` until it opens, as a player does: from a stand in
## its reach facing it, once nothing holds the keys (a landscape's arrival or
## a greeting is staged first), and only where the key would break it (the
## hint says "housing - break"; a sign beside it, or a person nearer, takes the
## key instead and the player would step round). False, with why, when no stand
## by it takes the key.
func _open(g: Game, site: WorksSite, i: int) -> bool:
	var works := g.get_node("34_works")
	var part := site.part(i)
	var why := "no standable tile in reach"
	for r: float in [0.8, 1.2, 1.6, 2.0]:
		for k in 12:
			var p := part + Vector2.from_angle(TAU * float(k) / 12.0) * r
			if not g.query.standable(floori(p.x), floori(p.y)):
				continue
			var stand := Vector2(floorf(p.x) + 0.5, floorf(p.y) + 0.5)
			if stand.distance_to(part) > Works.PART_REACH or Works.part_near(site, stand) != i:
				continue
			_stand(g, stand)
			Survival.face(g, (part - stand).angle())
			for f in 600:
				if not g.input_blocked():
					break
				await frames(1)
			await frames(2)
			var line: String = works.call(&"use_line")
			if line != "housing - break":
				var front: Dictionary = g.get_node("49_story").call(&"_what_is_in_front")
				var named := ""
				if front.has("prop"):
					var fp: WorldProp = front.prop
					named = "%s at %s" % [PropKind.NAMES[fp.kind], fp.pos]
				elif front.has("person"):
					named = "person %s" % [(front.person as Dictionary).get("id", "?")]
				elif front.has("slot"):
					named = "slot %s" % [front.slot]
				why = "the key there says '%s' (words in front %s: %s, talking %s, staged %s)" % [line, Survival.words_in_front(g), named, g.talking, g.staged]
				continue
			works.call(&"tour_forget", &"works_part")
			Input.action_press(&"use")
			var got := false
			for f in 1500:
				await frames(1)
				if works.call(&"tour_seen", "works_part"):
					got = true
					break
			Input.action_release(&"use")
			if got:
				return true
			why = "held 1500 frames at %s and it did not open" % stand
	print("    %s: housing %d (%s at %s) never opened: %s" % [site.land, i, site.part_name(i), part, why])
	return false


## Seed 1's slag yard, seed 7's soundings and stack, and seed 42's soundings and
## breaking yard had no roof in REACH; seed 42's bonelands quarry feed housing
## had a survey stake 1.25 behind it that took every press (#67).
func test_every_first_yard_on_seed_1_burns_a_roof_or_has_none() -> void:
	await _every_land(1)


func test_every_first_yard_on_seed_7_burns_a_roof_or_has_none() -> void:
	await _every_land(7)


func test_every_first_yard_on_seed_42_burns_a_roof_or_has_none() -> void:
	await _every_land(42)


func _every_land(world_seed: int) -> void:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=%d" % world_seed, "--hour=11", "--weather=clear:0", "--held=axe_felling"])))
	await frames(4)
	var raids := g.get_node("48_raids")
	var r: Reprisal = raids.get("reprisal")
	var firsts := {}
	for site: WorksSite in Works.sites(g.world):
		if not firsts.has(site.land):
			firsts[site.land] = site
	gt(float(firsts.size()), 0.0, "seed %d keeps depots" % world_seed)
	# Three full-size worlds, two minutes each on the gate, whose hang guard
	# (tools/check.sh) reads ten silent minutes as a hang: a line per world and per
	# yard keeps a slow file from being killed as a stuck one.
	print("  info every land: seed %d raised, %d first yards" % [world_seed, firsts.size()])
	for land: StringName in firsts:
		var site: WorksSite = firsts[land]
		_stand(g, site.pos)
		await frames(6)
		var target: Dictionary = raids.call(&"_target_for", site.pos)
		var roof: Vector2 = target.at
		var opened := await _open(g, site, 0)
		var sent := r.marching.has(site.region)
		var march := float(r.marching[site.region].get("minutes", Reprisal.MARCH_MINUTES)) if sent else 0.0
		var before: int = (raids.get("burned") as Dictionary).size()
		g.clock.skip(maxf(march, Reprisal.MARCH_MINUTES) + 1.0)
		raids.call(&"sweep")
		var burned: Dictionary = raids.get("burned")
		var here := 0
		for id: int in burned:
			if roof.is_finite() and g.world.prop(id).pos.distance_to(roof) <= float(raids.get("BURN_REACH")) + 0.01:
				here += 1
		check(opened, "%s: a housing comes open under the held key" % land)
		if not roof.is_finite():
			print("  seed %d %s: yard %s (%s): NOBODY: no roof on its body and no fire of his there; nothing sent" % [world_seed, land, site.pos, site.trade])
			eq(target.kind, Reprisal.NONE, "%s: with no roof and no fire of his, the hunters are sent for nothing" % land)
			check(not sent, "%s: and nobody is sent" % land)
			continue
		print("  seed %d %s: yard %s (%s), roof %.0f tiles off, march %.0f min, opened %s, sent %s, %d houses burned there (%d in all)" % [
			world_seed, land, site.pos, site.trade, roof.distance_to(site.pos), march, opened, sent, here, burned.size() - before])
		check(sent, "%s: and the yard's hunters take the road" % land)
		gt(float(here), 0.0, "%s: when the march is done, houses at that roof have burned" % land)
	g.queue_free()
	await frames(2)
