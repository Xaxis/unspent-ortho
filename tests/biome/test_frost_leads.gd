extends TestCase
## THE FROST SEA'S LEADS (frost_sea.gd `_surface`): black open water wandering
## through the ice, the sea's signature and the listener's founder ground
## (designs/listener.gd). Asked of five worlds at full size.

const Worlds := preload("res://tests/core/test_world_gen.gd")
const Scan := preload("res://tests/stream/whole_world_scan.gd")
const SEEDS: Array[int] = [1, 4, 7, 42, 90210]
## A big region's share of black water, at most: the leads are lines through
## the ice and the sea is walked on. Past this it reads as water with ice in it.
const LEAD_SHARE_MOST := 0.06
## The share of a region's black water that is black water all round (a tile
## in a lake's middle), at most: a lead three tiles wide has a third of its
## tiles there, and a lake most of them.
const LEAD_CORE_MOST := 0.35
## A lead is a line: black water joined corner to corner this far at the least,
## half the 48-tile wavelength of the field it follows, so it runs on past the
## gap between two. Shorter is a hole in the ice, not a lead.
const LINE_LEAST := 24
## The share of a big region's black water in lines, at the least: leads cut
## from the rise's low tail were rings round pits, 3-18% of their tiles in a
## line, and passed LEAD_CORE_MOST as easily as lines do.
const LINE_SHARE_LEAST := 0.7
## A region this big is printed and held to the bounds above.
const BIG := 2000

## The worlds test_world_gen does not keep, made once each.
static var _made := {}


func _world(s: int) -> WorldData:
	if Worlds.WORLD_SEEDS.has(s):
		return Worlds.world(s)
	if not _made.has(s):
		_made[s] = WorldGen.generate(s)
	return _made[s]


## EVERY FROST REGION KEEPS FOUNDER GROUND IN THE LISTENER'S REACH: a room in it
## keeps every way its ground answers (Sentinels.ground_den), the founder way on
## the leads. With no leads, seed 1's 13936-tile region 22 and 90210's 3328-tile
## region 27 held no black water at all, and the listener could not be sunk. A
## sliver under BIG tiles is printed, as the station rule's guard holds them
## (tests/sentinel/test_station_ways.gd SLIVER_MOST): 432-736 tiles at the
## sea's edge, too small to hold a lead's low ground.
func test_every_frost_region_keeps_founder_ground_in_reach() -> void:
	var def := Sentinels.by_id(&"listener")
	var asked := 0
	for s: int in SEEDS:
		var w := _world(s)
		var landings: Array[Vector2] = []
		for row: Dictionary in w.continents:
			if bool(row.get("landfall", false)) and row.has("from"):
				landings.append(row["from"] as Vector2)
		for r: Dictionary in w.regions:
			if StringName(str(r.get("type", &""))) != &"frost_sea" or int(r.get("tiles", 0)) < Sentinels.MIN_TILES:
				continue
			var id := int(r.get("id", -1))
			var den := Sentinels.ground_den(w, r, def, landings)
			var kept := den.is_finite() and w.region_at(floori(den.x), floori(den.y)) == id
			if int(r.get("tiles", 0)) < BIG:
				print("       seed %d frost sea region %d (%d tiles), a sliver: %s" % [s, id, int(r.get("tiles", 0)), "keeps founder ground" if kept else "keeps none"])
				continue
			asked += 1
			check(kept, "seed %d: frost sea region %d (%d tiles) keeps a room with black water in the listener's reach (%s)" % [s, id, int(r.get("tiles", 0)), den])
	gt(float(asked), 4.0, "five worlds hold big frost sea regions (%d)" % asked)


## THE ICE STAYS THE GROUND. Every big frost region's share of black water,
## printed and held to LEAD_SHARE_MOST, and its leads held to lines: few of
## their tiles are black water all round.
func test_the_leads_are_lines_through_walkable_ice() -> void:
	var big := 0
	for s: int in SEEDS:
		var w := _world(s)
		for r: Dictionary in w.regions:
			if StringName(str(r.get("type", &""))) != &"frost_sea" or int(r.get("tiles", 0)) < BIG:
				continue
			big += 1
			var id := int(r.get("id", -1))
			var b: Rect2 = r.get("bounds", Rect2())
			var tiles := 0
			var black := 0
			var core := 0
			for y in range(floori(b.position.y), ceili(b.end.y)):
				for x in range(floori(b.position.x), ceili(b.end.x)):
					if w.region_at(x, y) != id:
						continue
					tiles += 1
					if w.ground_at(x, y) != Ground.BLACKWATER:
						continue
					black += 1
					var all := true
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							if w.ground_at(x + dx, y + dy) != Ground.BLACKWATER:
								all = false
					core += int(all)
			var share := float(black) / maxf(1.0, float(tiles))
			var mid := float(core) / maxf(1.0, float(black))
			var lines := _in_lines(w, id, b)
			var lined := float(lines.x) / maxf(1.0, float(black))
			print("       seed %d frost sea region %d (%d tiles): %.3f black water, %.2f of it a lake's middle, %.2f in lines, the longest %d tiles, %.1f wide" % [s, id, tiles, share, mid, lined, lines.y, _width(w, id, b)])
			lt(share, LEAD_SHARE_MOST, "seed %d: frost sea region %d keeps its ice the ground (%.3f black water)" % [s, id, share])
			lt(mid, LEAD_CORE_MOST, "seed %d: frost sea region %d's leads are lines, not lakes (%.2f of them a lake's middle)" % [s, id, mid])
			gt(lined, LINE_SHARE_LEAST, "seed %d: frost sea region %d's leads are lines, not holes (%.2f of its black water in lines of %d)" % [s, id, lined, LINE_LEAST])
	gt(float(big), 4.0, "five worlds hold big frost sea regions (%d)" % big)


## How many of region `id`'s black-water tiles lie in a patch of it, joined
## corner to corner through the frost sea, of LINE_LEAST tiles or more (a lead
## running on into the next frost region is still a line), and the most tiles
## in one: (in lines, longest).
func _in_lines(w: WorldData, id: int, b: Rect2) -> Vector2i:
	var frost := w.country_at(floori(b.get_center().x), floori(b.get_center().y))
	for y in range(floori(b.position.y), ceili(b.end.y)):
		for x in range(floori(b.position.x), ceili(b.end.x)):
			if w.region_at(x, y) == id:
				frost = w.country_at(x, y)
				break
	var size := w.size
	var seen := {}
	var lined := 0
	var longest := 0
	for y in range(floori(b.position.y), ceili(b.end.y)):
		for x in range(floori(b.position.x), ceili(b.end.x)):
			var i := y * size + x
			if seen.has(i) or w.region_at(x, y) != id or w.ground_at(x, y) != Ground.BLACKWATER:
				continue
			seen[i] = true
			var q: Array[Vector2i] = [Vector2i(x, y)]
			var mine := 0
			var h := 0
			while h < q.size():
				var t := q[h]
				h += 1
				if w.region_at(t.x, t.y) == id:
					mine += 1
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var u := t + Vector2i(dx, dy)
						if not w.in_bounds(u.x, u.y) or seen.has(u.y * size + u.x):
							continue
						if w.country_at(u.x, u.y) != frost or w.ground_at(u.x, u.y) != Ground.BLACKWATER:
							continue
						seen[u.y * size + u.x] = true
						q.append(u)
			longest = maxi(longest, q.size())
			if q.size() >= LINE_LEAST:
				lined += mine
	return Vector2i(lined, longest)


## How wide region `id`'s black water runs, on the mean: twice its tiles over
## its edges with the ice, which for a strip is its width.
func _width(w: WorldData, id: int, b: Rect2) -> float:
	var black := 0
	var edges := 0
	for y in range(floori(b.position.y), ceili(b.end.y)):
		for x in range(floori(b.position.x), ceili(b.end.x)):
			if w.region_at(x, y) != id or w.ground_at(x, y) != Ground.BLACKWATER:
				continue
			black += 1
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if w.ground_at(x + d.x, y + d.y) != Ground.BLACKWATER:
					edges += 1
	return 2.0 * float(black) / maxf(1.0, float(edges))

## Where black water once decided whether a walker's foot could come down: the
## treads, the pools and the surface.
const LEAD_READERS_IN: Array[String] = [
	"res://src/core/worldgen/gen_treads.gd",
	"res://src/core/worldgen/gen_water.gd",
	"res://src/core/worldgen/gen_surface.gd",
]
## The readers there that may take a lead for water, and why.
const AS_WATER := {
	"gen_treads.gd::_press_ring": "the pressed band is not laid on water, and a lead stays a lead",
	"gen_treads.gd::_shore": "no scree band along water's edge, a lead's edge as much as a pool's",
	"gen_treads.gd::_put": "thrown plate comes down on dry ground, never in a lead",
	"gen_surface.gd::window": "water a recipe laid is fixed against the tidy, so a lead stays as `_surface` laid it",
}


## BiomeDef.leads HAS ONE COST: a stage that reads black water without asking
## it takes a lead for a pool. GenTreads did, and kept seed 1's lame tread off
## ice its foot could come down on. So every function in the treads, pools and
## surface code that reads black water (names BLACKWATER, or asks Ground.is_water
## or is_shallow) asks `leads`, or is named in AS_WATER with why a lead is water
## to it. A new reader fails until it does one or the other, and a name in
## AS_WATER that reads none any more fails too. Text, not a parser, the way
## tests/stream/whole_world_scan.gd reads: comments are not code.
func test_every_black_water_reader_in_the_treads_and_surface_asks_leads() -> void:
	var reads := RegEx.create_from_string("\\bBLACKWATER\\b|\\bGround\\.is_(?:water|shallow)\\(")
	var asks := RegEx.create_from_string("\\.leads\\b")
	var head := RegEx.create_from_string("^\\s*(?:static\\s+)?func\\s+(\\w+)")
	var reading := {}
	var asking := {}
	for path: String in LEAD_READERS_IN:
		var fn := "(class)"
		for raw: String in FileAccess.get_file_as_string(path).split("\n"):
			var line := Scan._code(raw)
			var m := head.search(line)
			if m != null:
				fn = m.get_string(1)
			var key := "%s::%s" % [path.get_file(), fn]
			if reads.search(line) != null:
				reading[key] = true
			if asks.search(line) != null:
				asking[key] = true
	check(reading.has("gen_treads.gd::_never") and asking.has("gen_treads.gd::_never"),
		"the scan sees GenTreads._never read black water and ask leads (%s)" % [reading.keys()])
	for key: String in reading:
		if not asking.has(key):
			check(AS_WATER.has(key), "%s reads black water without asking BiomeDef.leads: ask it, or name it in AS_WATER with why a lead is water there" % key)
	for key: String in AS_WATER:
		check(reading.has(key) and not asking.has(key), "%s is in AS_WATER but reads no black water unasked: take it out" % key)
