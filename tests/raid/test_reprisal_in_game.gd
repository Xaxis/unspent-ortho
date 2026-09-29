extends TestCase
## WE BREAK THEIR WORKS, THEY BURN A VILLAGE, in a real game and by the player's
## own hands: a housing opened with a steel edge under the held key puts the
## yard's hunters on the road to the nearest roof, and ninety minutes on the
## houses there have burned; put the whole yard dark before then and nothing does.


func _game() -> Game:
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(BootOptions.parse(PackedStringArray(["--seed=1", "--size=256", "--hour=11", "--weather=clear:0",
		"--place=works", "--held=axe_felling"])))
	return g


func _stand(g: Game, p: Vector2) -> void:
	g.player.hero.pos = p
	g.player.hero.move = Vector2.ZERO
	g.player.pos = p
	g.player.position = g.world.to_3d(p)


## Hold `use` at housing `i` until it opens, as a player does.
func _open(g: Game, site: WorksSite, i: int) -> bool:
	var works := g.get_node("34_works")
	# Where housing `i` is the one under the hand, as 49_story's `_at_housing`
	# finds it for a tour: a tile to stand on, in the housing's reach, with no
	# other workable thing nearer (a bush there takes the key instead).
	var at := Vector2.INF
	var part := site.part(i)
	for r: float in [0.8, 1.2, 1.6, 2.0]:
		for k in 12:
			var p := part + Vector2.from_angle(TAU * float(k) / 12.0) * r
			if not g.query.standable(floori(p.x), floori(p.y)):
				continue
			var stand := Vector2(floorf(p.x) + 0.5, floorf(p.y) + 0.5)
			var clear := stand.distance_to(part) <= Works.PART_REACH and Works.part_near(site, stand) == i
			for q in g.query.props_near(stand, 4.0):
				if clear and Takes.workable(q.kind) and not g.world.depleted.has(q.id) \
						and q.pos.distance_to(stand) < part.distance_to(stand):
					clear = false
			if clear:
				at = stand
				break
		if at.is_finite():
			break
	if not at.is_finite():
		return false
	_stand(g, at)
	await frames(2)
	works.call(&"tour_forget", &"works_part")
	Input.action_press(&"use")
	var got := false
	for f in 400:
		await frames(1)
		if works.call(&"tour_seen", "works_part"):
			got = true
			break
	Input.action_release(&"use")
	return got


func _raids(g: Game) -> Node:
	return g.get_node("48_raids")


func test_a_housing_opened_burns_the_nearest_roof_ninety_minutes_on() -> void:
	var g := _game()
	await frames(4)
	var site: WorksSite = g.get_node("34_works").call(&"here")
	check(site != null, "the player stands on a depot's ground")
	if site == null:
		g.queue_free()
		await frames(1)
		return
	var roof := Reprisal.nearest_roof(g.query.props_near(site.pos, Reprisal.REACH), site.pos)
	check(roof.is_finite(), "a roof inside the hunters' reach of this yard")
	check(await _open(g, site, 0), "a housing came open under the held key and a steel edge")
	var raids := _raids(g)
	var r: Reprisal = raids.get("reprisal")
	check(r.marching.has(site.region), "and the yard's hunters are on the road")
	eq((raids.get("burned") as Dictionary).size(), 0, "nothing has burned yet")
	g.clock.skip(Reprisal.MARCH_MINUTES + 1.0)
	raids.call(&"sweep")
	var burned: Dictionary = raids.get("burned")
	gt(float(burned.size()), 0.0, "ninety minutes on, the houses at the nearest roof have burned")
	for id: int in burned:
		lt(g.world.prop(id).pos.distance_to(roof), raids.get("BURN_REACH") + 0.01, "each of them at that roof")
	g.queue_free()
	await frames(1)


func test_a_yard_put_dark_in_time_burns_nothing() -> void:
	var g := _game()
	await frames(4)
	var site: WorksSite = g.get_node("34_works").call(&"here")
	if site == null:
		g.queue_free()
		await frames(1)
		return
	for i in Works.PART_NAMES.size():
		check(await _open(g, site, i), "housing %d opened" % i)
	var raids := _raids(g)
	check(not (raids.get("reprisal") as Reprisal).marching.has(site.region), "the yard is dark: its hunters are called back")
	g.clock.skip(Reprisal.MARCH_MINUTES + 1.0)
	raids.call(&"sweep")
	eq((raids.get("burned") as Dictionary).size(), 0, "and nothing burns")
	g.queue_free()
	await frames(1)
