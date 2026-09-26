extends TestCase
## THE CAVES ARE ROOFED (GenAbove, docs/ABOVE.md S3): the limestone caves grow a
## lid of rock, terraced, with room for a person everywhere under it, open over
## every shaft's mouth and every tear the day comes down through; and the surface
## grows none.

const SIZE := 256
const SEED := 7
static var _w: WorldData


static func _caves() -> WorldData:
	if _w == null:
		_w = WorldGen.generate(SEED, SIZE, &"", Realm.UNDERGROUND)
	return _w


func test_the_caves_are_mostly_roofed_and_the_surface_not_at_all() -> void:
	var w := _caves()
	check(w.has_overhead(), "the caves have a roof")
	var land := 0
	var roofed := 0
	for y in SIZE:
		for x in SIZE:
			if w.level_at(x, y) > 0:
				land += 1
				if w.overhead_at(x, y).x >= 0:
					roofed += 1
	gt(float(roofed) / float(land), 0.6, "most of the halls are under rock (%d of %d)" % [roofed, land])
	check(not WorldGen.generate(SEED, SIZE).has_overhead(), "the surface grows none")


func test_a_person_has_room_everywhere_under_the_roof() -> void:
	var w := _caves()
	var least := 1 << 20
	for y in SIZE:
		for x in SIZE:
			if w.overhead_at(x, y).x >= 0:
				least = mini(least, w.headroom_at(x, y))
	gt(float(least), float(FightSim.HERO_TALL) + 0.5, "the lowest headroom is more than a person (%d levels)" % least)


func test_every_shaft_and_every_tear_is_open_to_the_sky() -> void:
	var w := _caves()
	var shafts := Portals.in_world(w)
	gt(float(shafts.size()), 0.0, "the caves have shafts")
	for p: Portal in shafts:
		for d: Vector2 in [Vector2.ZERO, Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5)]:
			var q := p.pos + d
			check(w.overhead_at(floori(q.x), floori(q.y)).x < 0, "open over the shaft at %s" % q)
	var tears := 0
	for cy in ceili(float(SIZE) / Dome.CELL):
		for cx in ceili(float(SIZE) / Dome.CELL):
			var t := Dome.tear_in(w.seed_value, cx, cy)
			if t == Vector2.INF or t.x < 0 or t.y < 0 or t.x >= SIZE or t.y >= SIZE:
				continue
			tears += 1
			check(w.overhead_at(floori(t.x), floori(t.y)).x < 0, "open under the tear at %s" % t)
	gt(float(tears), 5.0, "and there were tears to leave open (%d)" % tears)


## TERRACED (the cost target): most roofed tiles stand in a three by three of one
## underside and one top, which the span mesher draws as a few quads.
func test_the_roof_is_terraced_into_plateaus() -> void:
	var w := _caves()
	var roofed := 0
	var core := 0
	for y in range(1, SIZE - 1):
		for x in range(1, SIZE - 1):
			var o := w.overhead_at(x, y)
			if o.x < 0:
				continue
			roofed += 1
			var same := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if w.overhead_at(x + dx, y + dy) != o:
						same = false
			if same:
				core += 1
	gt(float(core) / float(roofed), 0.6, "most of the roof is plateau (%d of %d)" % [core, roofed])


func test_the_same_seed_grows_the_same_roof() -> void:
	var a := _caves()
	var b := WorldGen.generate(SEED, SIZE, &"", Realm.UNDERGROUND)
	for i in 400:
		var x := (i * 37) % SIZE
		var y := (i * 91) % SIZE
		eq(b.overhead_at(x, y), a.overhead_at(x, y), "the same at %d,%d" % [x, y])
