extends TestCase
## HIS OWN ROOF, BURNED (`holding_burned`, after #96). A broken yard's hunters burn
## his holding's beds as they would any village's roof (48_raids `_burn_his`), and
## he learns it the way he learns a village's price: by coming to it. The beat
## lands when he next comes within sight of a holding a march burned (49_story,
## BURNED_SIGHT), once, from that holding only, after a save as before it, and
## never from a camp's wrecking or from any other damage to his beds.

const Sx := preload("res://tests/save/save_fixture.gd")
const BEAT := &"holding_burned"


func _game(args: Array = []) -> Game:
	var g := Sx.game(tree, ["--seed=1", "--size=256", "--hour=11", "--weather=clear:0", "--place=works",
		"--held=axe_felling"] + args)
	return g


func _stand(g: Game, p: Vector2) -> void:
	g.player.hero.pos = p
	g.player.hero.move = Vector2.ZERO
	g.player.pos = p
	g.player.position = g.world.to_3d(p)


func _raids(g: Game) -> Node:
	return Sx.system(g, "48_raids")


func _holdings(g: Game) -> Node:
	return Sx.system(g, "46_settlements")


## Every house on the island gone, as burned houses are, so the yard's hunters
## have only his places to go to.
func _no_roofs(g: Game, site: WorksSite) -> void:
	for q in g.query.props_near(site.pos, float(g.world.size) * 1.5):
		if q.kind == PropKind.HOUSE:
			g.world.depleted[q.id] = INF


## His place, a fire and a lean-to, on the first standable ground off `from` at
## one of `radii`, clear of every yard, with `people` living in it; null when no
## ground for it.
func _place(g: Game, site: WorksSite, from: Vector2, people: int, radii: Array[float]) -> Settlement:
	var yards := Works.sites(g.world)
	var at := Vector2.INF
	for r: float in radii:
		for k in 16:
			var p := from + Vector2.from_angle(TAU * float(k) / 16.0) * r
			if g.query.standable(floori(p.x), floori(p.y)) and g.world.same_body(site.pos, p) and Works.at(yards, p) == null:
				at = Vector2(floorf(p.x) + 0.5, floorf(p.y) + 0.5)
				break
		if at.is_finite():
			break
	check(at.is_finite(), "ground for his place")
	if not at.is_finite():
		return null
	var h := _holdings(g)
	var home: Settlement = h.call(&"found", Realm.SURFACE, at)
	@warning_ignore("return_value_discarded")
	h.call(&"place_piece", home, StructureKind.HEARTH, at, 0.0)
	@warning_ignore("return_value_discarded")
	h.call(&"place_piece", home, StructureKind.LEAN_TO, at + Vector2(2, 0), 0.0)
	for n in people:
		home.people.append(home.take_person_id())
	return home


## Somewhere to stand far out of sight of `p`.
func _away(g: Game, p: Vector2) -> Vector2:
	for r: float in [70.0, 80.0, 90.0, 100.0]:
		for k in 16:
			var q := p + Vector2.from_angle(TAU * float(k) / 16.0) * r
			if g.query.standable(floori(q.x), floori(q.y)):
				return Vector2(floorf(q.x) + 0.5, floorf(q.y) + 0.5)
	return p + Vector2(80, 0)


## A march of `kind` from the yard to `home`, sent and arrived with him far off.
func _burned(g: Game, site: WorksSite, home: Settlement, kind: StringName) -> void:
	_stand(g, _away(g, home.centre))
	await frames(2)
	var raids := _raids(g)
	var r: Reprisal = raids.get("reprisal")
	check(r.send(site.region, home.centre, g.clock.minutes, site.pos, kind), "the yard's hunters are sent for his %s" % kind)
	g.clock.skip(Reprisal.march_minutes(site.pos, home.centre) + 1.0)
	raids.call(&"sweep")
	await frames(45)


## How many times the beat's words were said among `said`.
func _times(said: Array[String]) -> int:
	var line := StoryContent.beat_says(BEAT)
	return said.filter(func(t: String) -> bool: return line != "" and t == line).size()


func test_he_learns_it_coming_home_to_the_burned_beds() -> void:
	Story.forget()
	var g := _game()
	await frames(4)
	var site: WorksSite = Sx.system(g, "34_works").call(&"here")
	check(site != null, "the player stands on a depot's ground")
	if site != null:
		_no_roofs(g, site)
		var home := _place(g, site, site.pos, 1, [20.0, 24.0, 28.0, 32.0])
		if home != null:
			var said: Array[String] = []
			var hear := func(t: String) -> void: said.append(t)
			Events.message.connect(hear)
			await _burned(g, site, home, Reprisal.HOLDING)
			check(home.beds() == 0, "the march burned the beds at his holding")
			check(not Story.landed(BEAT), "out of sight of it, nothing is known yet")
			_stand(g, home.centre + Vector2(0, 3))
			await frames(45)
			check(Story.landed(BEAT), "come home to the burned beds, it is known")
			eq(_times(said), 1, "and said once on the glass")
			_stand(g, _away(g, home.centre))
			await frames(45)
			_stand(g, home.centre + Vector2(0, 3))
			await frames(45)
			eq(_times(said), 1, "and not again for coming back")
			Events.message.disconnect(hear)
	Sx.end(g)
	Story.forget()


func test_his_beds_broken_any_other_way_teach_nothing() -> void:
	Story.forget()
	var g := _game()
	await frames(4)
	var site: WorksSite = Sx.system(g, "34_works").call(&"here")
	check(site != null, "the player stands on a depot's ground")
	if site != null:
		var home := _place(g, site, site.pos, 1, [20.0, 24.0, 28.0, 32.0])
		if home != null:
			var h := _holdings(g)
			for p: Structure in home.pieces:
				if StructureKind.sleeps(p.kind) > 0:
					@warning_ignore("return_value_discarded")
					h.call(&"damage", home.id, p.id, p.health + 1.0)
			check(home.beds() == 0, "his beds are down, but no yard's hunters did it")
			_stand(g, home.centre + Vector2(0, 3))
			await frames(45)
			check(not Story.landed(BEAT), "a ruined bed he stands by is not a march's burning")
	Sx.end(g)
	Story.forget()


func test_a_camp_wrecked_lands_nothing() -> void:
	Story.forget()
	var g := _game()
	await frames(4)
	var site: WorksSite = Sx.system(g, "34_works").call(&"here")
	check(site != null, "the player stands on a depot's ground")
	if site != null:
		_no_roofs(g, site)
		var home := _place(g, site, site.pos, 0, [20.0, 24.0, 28.0, 32.0])
		if home != null:
			await _burned(g, site, home, Reprisal.CAMP)
			var standing := home.pieces.filter(func(p: Structure) -> bool: return not p.ruined)
			check(standing.is_empty(), "the march wrecked his camp")
			_stand(g, home.centre + Vector2(0, 3))
			await frames(45)
			check(not Story.landed(BEAT), "a camp is nobody's beds, and lands no holding's price")
	Sx.end(g)
	Story.forget()


func test_only_the_holding_that_burned_teaches_it() -> void:
	Story.forget()
	var g := _game()
	await frames(4)
	var site: WorksSite = Sx.system(g, "34_works").call(&"here")
	check(site != null, "the player stands on a depot's ground")
	if site != null:
		_no_roofs(g, site)
		var burned := _place(g, site, site.pos, 1, [20.0, 24.0, 28.0, 32.0])
		var other: Settlement = null
		if burned != null:
			other = _place(g, site, burned.centre, 1, [40.0, 48.0, 56.0])
		if burned != null and other != null:
			await _burned(g, site, burned, Reprisal.HOLDING)
			check(other.beds() > 0, "the march burned one holding, not the other")
			_stand(g, other.centre + Vector2(0, 3))
			await frames(45)
			check(not Story.landed(BEAT), "at the holding that stands, nothing is known")
			_stand(g, burned.centre + Vector2(0, 3))
			await frames(45)
			check(Story.landed(BEAT), "at the one that burned, it is")
	Sx.end(g)
	Story.forget()


func test_a_save_between_the_burning_and_coming_home_keeps_it() -> void:
	Story.forget()
	Sx.use_root("holding-burned")
	var a := _game()
	await frames(4)
	var site: WorksSite = Sx.system(a, "34_works").call(&"here")
	check(site != null, "the player stands on a depot's ground")
	var at := Vector2.INF
	if site != null:
		_no_roofs(a, site)
		var home := _place(a, site, site.pos, 1, [20.0, 24.0, 28.0, 32.0])
		if home != null:
			await _burned(a, site, home, Reprisal.HOLDING)
			at = home.centre
			check(not Story.landed(BEAT), "burned while he was away, not yet known")
			eq(Sx.system(a, "05_save").call("save_to", 2), "", "saved to slot 2")
	Sx.end(a)
	Story.forget()
	if at.is_finite():
		var o := BootOptions.new()
		eq(SaveSlots.options_for(2, o), "", "slot 2 boots")
		var b := Sx.game(tree, [], o)
		await frames(4)
		check(not Story.landed(BEAT), "loaded far off, still not known")
		_stand(b, at + Vector2(0, 3))
		await frames(45)
		check(Story.landed(BEAT), "come home after the load, it is known")
		Sx.end(b)
	Story.forget()
