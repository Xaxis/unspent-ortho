extends TestCase
## A GROWER'S HOUSE IN THE GREY ORCHARDS (src/content/interiors/laid_table.gd):
## the table laid for four, a hot meal through the hatch at every mealtime, and
## nothing in it that hunts. Asked of every one the world grows on seed 4, with
## the real query and the room's real blocks, and of the hatch in a running game.

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


func _reached(reach: Dictionary, at: Vector2) -> bool:
	var c := Vector2i(roundi(at.x / STEP), roundi(at.y / STEP))
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if reach.has(c + Vector2i(dx, dy)):
				return true
	return false


## EVERY GROWER'S DOOR OPENS. Each house standing in the grey orchards on seed 4
## opens on a house the machines keep, and nothing in any of them hunts.
func test_every_grey_orchards_house_opens_on_a_laid_table() -> void:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var houses := 0
	for p: WorldProp in w.props:
		if p.kind != PropKind.HOUSE:
			continue
		var d := BiomeRegistry.by_index(w.country_at(floori(p.pos.x), floori(p.pos.y)))
		if d != null and d.id == &"grey_orchards":
			houses += 1
	gt(float(houses), 0.0, "seed 4 has houses in the grey orchards")
	var doors := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind == &"laid_table":
			doors += 1
			var l := InteriorGen.grow(4, t).layout
			eq(l.residents.size(), 0, "%s: nobody keeps it but the machines outside" % t.key)
			for th: Dictionary in l.things:
				check(th.kind != &"turret", "%s: nothing in it watches" % t.key)
	eq(doors, houses, "one door per house")


## THE TABLE, THE HATCH, THE BEDS. From the door a body gets to the hatch, to a
## side of the table, to the plate by the hatch, to the height marks, and into
## the bedroom to the side of each bed.
func test_every_laid_table_can_be_walked_through() -> void:
	var w := BootWorld.world(4, Tuning.WORLD_SIZE)
	var n := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind != &"laid_table":
			continue
		n += 1
		var p := InteriorGen.grow(4, t)
		var l := p.layout
		var q := WorldQuery.new(p.world)
		q.set_blocks(&"rooms", _doors.call(&"_walls", l) as Array[Vector3])
		var reach := _reach(q, l.inside())
		var goals := {}
		for th: Dictionary in l.things:
			var off := {&"food_hatch": 0.8, &"schedule_plate": 0.7, &"height_marks": 0.7, &"bed": 0.85}
			if off.has(th.kind):
				goals["%s@%s" % [th.kind, th.at]] = (th.at as Vector2) + (th.face as Vector2) * float(off[th.kind])
		for g: String in goals:
			check(_reached(reach, goals[g]), "%s: the %s cannot be walked to from the door" % [t.key, g])
		var sat := false
		for d: Vector2 in [Vector2(0, 0.8), Vector2(0, -0.8), Vector2(0.95, 0), Vector2(-0.95, 0)]:
			sat = sat or _reached(reach, l.table + d)
		check(sat, "%s: a place at the table" % t.key)
	gt(float(n), 0.0, "seed 4 has a grower's house to walk")


## THE MACHINES' SCHEDULE: seven, noon and six. Before seven it is still last
## night's supper; the first morning of all, nothing yet.
func test_the_hatch_keeps_the_machines_schedule() -> void:
	var hours := [7, 12, 18]
	var at := func(day: int, h: float) -> int: return int(_doors.call(&"meal_at", hours, (day * 24.0 + h) * 60.0))
	eq(at.call(0, 6.0), -1, "the first morning of all, before seven: nothing yet")
	eq(at.call(0, 7.5), 0, "breakfast")
	eq(at.call(0, 12.0), 1, "noon, on the hour: lunch")
	eq(at.call(0, 23.0), 2, "supper, until the next morning")
	eq(at.call(1, 3.0), 2, "still last night's supper before seven")
	eq(at.call(1, 7.0), 8, "the next day's breakfast is a new meal")


## A MEAL IS TAKEN ONCE, AND PUT OUT AGAIN AT THE NEXT, in a running game: at the
## hatch of a grower's house, the tray comes out with soup and bread; pressed
## again, the hatch is shut and its tray gone; at the next mealtime it serves again; and a save
## keeps which meal was taken.
func test_the_hatch_serves_once_a_meal_in_a_running_game() -> void:
	Sx.use_root("laid-table-hatch")
	var g := Sx.game(tree, ["--seed=4", "--hour=12.5", "--weather=clear:0"])
	var d := Sx.system(g, "21_doors")
	var p: Vector2 = d.call(&"tour_place", "door:laid_table")
	check(p != Vector2.INF, "seed 4 has a grower's door")
	g.player.hero.pos = p
	g.player.sync_view(0.0)
	var t: Threshold = null
	for h: Threshold in d.get("doors"):
		if h.kind == &"laid_table" and (t == null or h.door.distance_to(p) < t.door.distance_to(p)):
			t = h
	for i in 60:
		await tree.process_frame
	await d.call(&"go_in", t)
	check(bool(d.call(&"tour_seen", &"inside:laid_table")), "inside")
	var tray := (d.get("_model") as Node3D).get_node_or_null("tray_0") as Node3D
	check(tray != null, "the hatch's tray is its own node")
	d.call(&"_show_trays")
	check(tray.visible, "at noon the tray stands behind the glass")
	var soup := g.inventory.count(&"soup")
	var bread := g.inventory.count(&"bread")
	d.call(&"_take_meal", 0)
	eq(g.inventory.count(&"soup"), soup + 1, "the tray: soup")
	eq(g.inventory.count(&"bread"), bread + 1, "and bread")
	d.call(&"_show_trays")
	check(not tray.visible, "and the tray is gone from behind the glass")
	d.call(&"_take_meal", 0)
	eq(g.inventory.count(&"soup"), soup + 1, "pressed again for the same meal, the hatch is shut")
	var saved: Variant = d.call(&"_save")
	d.call(&"_load", saved)
	d.call(&"_take_meal", 0)
	eq(g.inventory.count(&"soup"), soup + 1, "and a save keeps that it was taken")
	g.clock.skip(6.0 * 60.0)
	d.call(&"_take_meal", 0)
	eq(g.inventory.count(&"soup"), soup + 2, "at supper it serves again")
	g.clock.skip(1.0)
	d.call(&"_show_trays")
	check(not tray.visible, "and the supper tray is gone too, once taken")
	g.clock.skip(13.0 * 60.0)
	d.call(&"_show_trays")
	check(tray.visible, "and in the morning a tray is out again")
	Sx.end(g)
