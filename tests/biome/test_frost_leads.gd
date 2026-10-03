extends TestCase
## THE FROST SEA'S LEADS (frost_sea.gd `_surface`): black open water wandering
## through the ice, the sea's signature and the listener's founder ground
## (designs/listener.gd). Asked of five worlds at full size.

const Worlds := preload("res://tests/core/test_world_gen.gd")
const SEEDS: Array[int] = [1, 4, 7, 42, 90210]
## A big region's share of black water, at most: the leads are lines through
## the ice and the sea is walked on. Past this it reads as water with ice in it.
const LEAD_SHARE_MOST := 0.06
## The share of a region's black water that is black water all round (a tile
## in a lake's middle), at most: a lead three tiles wide has a third of its
## tiles there, and a lake most of them.
const LEAD_CORE_MOST := 0.35
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
			print("       seed %d frost sea region %d (%d tiles): %.3f black water, %.2f of it a lake's middle" % [s, id, tiles, share, mid])
			lt(share, LEAD_SHARE_MOST, "seed %d: frost sea region %d keeps its ice the ground (%.3f black water)" % [s, id, share])
			lt(mid, LEAD_CORE_MOST, "seed %d: frost sea region %d's leads are lines (%.2f of them a lake's middle)" % [s, id, mid])
	gt(float(big), 4.0, "five worlds hold big frost sea regions (%d)" % big)
