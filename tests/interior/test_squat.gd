extends TestCase
## A SQUAT IN THE MACHINE CITY (src/content/interiors/squat.gd): rare, dark, no
## fire, and a second way out. Asked of seed 4 at full size and of the room in
## a running game.

const STEP := 0.2
const Sx := preload("res://tests/save/save_fixture.gd")

var _doors := load("res://src/systems/21_doors.gd") as GDScript


func _reach(q: WorldQuery, from: Vector2) -> Dictionary:
	var seen := {Vector2i(roundi(from.x / STEP), roundi(from.y / STEP)): true}
	var todo: Array[Vector2i] = [seen.keys()[0]]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if seen.has(n):
				continue
			var a := Vector2(c) * STEP
			var b := Vector2(n) * STEP
			if q.move_body(a, b - a, Tuning.PLAYER_RADIUS).distance_to(b) < 0.02:
				seen[n] = true
				todo.append(n)
	return seen


## RARE: of the machine city's houses that are not its own forms' rooms, about
## one in eight has somebody in it -- some, and far from all.
func test_only_some_machine_city_houses_are_squats() -> void:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var mc := BiomeRegistry.get_def(&"machine_city")
	var houses := 0
	for p: WorldProp in w.each_prop():
		if p.kind != PropKind.HOUSE or w.country_at(floori(p.pos.x), floori(p.pos.y)) != mc.index:
			continue
		if not mc.interiors.has(StringName("form:%s" % Interiors.form_of(p, w.seed_value, mc.index))):
			houses += 1
	var squats := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind == &"squat":
			squats += 1
			eq(t.land, mc.index, "%s: squats only in the machine city" % t.key)
	gt(float(houses), 8.0, "seed 4 stands machine city houses (%d)" % houses)
	gt(float(squats), 0.0, "somebody squats in a few of them")
	lt(float(squats), float(houses) * 0.3, "and only a few: %d of %d" % [squats, houses])


## PRECARIOUS: no fire, dark, a bedroll, the tarp, the stolen lamp, and the way
## out through the back wall, which a body can reach from the door.
func test_a_squat_is_dark_fireless_and_has_a_way_out_the_back() -> void:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var n := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind != &"squat":
			continue
		n += 1
		var p := InteriorGen.grow(4, t)
		var l := p.layout
		check(p.kind.dark > 0.5, "dark")
		for pr: WorldProp in p.world.each_prop():
			check(pr.kind != PropKind.FIRE, "%s: no fire, whose smoke would be seen" % t.key)
		var kinds := {}
		var crawl := Vector2.INF
		for th: Dictionary in l.things:
			kinds[th.kind] = true
			if th.get("exit", false):
				crawl = (th.at as Vector2) + (th.face as Vector2) * 0.8
		for k: StringName in [&"bedroll", &"tarp", &"machine_lamp", &"crawl_hole"]:
			check(kinds.has(k), "%s: a %s" % [t.key, k])
		var q := WorldQuery.new(p.world)
		q.set_blocks(&"rooms", _doors.call(&"_walls", l) as Array[Vector3])
		var reach := _reach(q, l.inside())
		var c := Vector2i(roundi(crawl.x / STEP), roundi(crawl.y / STEP))
		var got := false
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				got = got or reach.has(c + Vector2i(dx, dy))
		check(got, "%s: the way out the back can be walked to" % t.key)
	gt(float(n), 0.0, "seed 4 has squats to ask")


## THE SECOND WAY OUT, in a running game: crawled through, the player comes out
## behind the house, not in front of its door.
func test_the_crawl_hole_puts_you_out_behind_the_house() -> void:
	Sx.use_root("squat-back")
	var g := Sx.game(tree, ["--seed=4", "--hour=15", "--weather=clear:0"])
	var d := Sx.system(g, "21_doors")
	var p: Vector2 = d.call(&"tour_place", "door:squat")
	check(p != Vector2.INF, "seed 4 has a squat")
	g.player.hero.pos = p
	g.player.sync_view(0.0)
	var t: Threshold = null
	for h: Threshold in d.get("doors"):
		if h.kind == &"squat" and (t == null or h.door.distance_to(p) < t.door.distance_to(p)):
			t = h
	for i in 60:
		await tree.process_frame
	await d.call(&"go_in", t)
	check(bool(d.call(&"tour_seen", &"inside:squat")), "inside the squat")
	await d.call(&"go_out", true)
	for i in 10:
		await tree.process_frame
	var at: Vector2 = g.player.pos
	var front := t.door + t.out * 0.5
	check((at - t.host).dot(t.out) < 0.0, "out behind the house (%s, host %s, facing %s)" % [at, t.host, t.out])
	gt(at.distance_to(front), 2.0, "not at its door")
	check(bool(d.call(&"tour_seen", &"out_back")), "the tour hears of it")
	Sx.end(g)
