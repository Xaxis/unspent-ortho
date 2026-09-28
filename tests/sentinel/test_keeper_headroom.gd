extends TestCase
## A BODY FITS UNDER ITS OWN ROOF. Every body a roofed landscape fields -- its
## roster, its keeper, and a keeper body keyed `sentinel.<land>` still waiting
## for its design -- stands no taller than that landscape's 80th-percentile
## headroom over its roofed tiles. Taller, and its own move (passable: headroom
## >= tall) shuts it out of most of its halls, and it is drawn through the roof.
## The drip-warden was drawn 5.6 tall for halls of 3 to 9.5.

const SIZE := 256
const SEED := 7
const SHARE := 0.8


## Every roofed world a seed makes, beside the surface.
static func _roofed() -> Array[WorldData]:
	var out: Array[WorldData] = []
	for realm: StringName in Realm.KINDS:
		if realm == Realm.SURFACE or BiomeRegistry.land_in(realm).is_empty():
			continue
		var w := WorldGen.generate(SEED, SIZE, &"", realm)
		if w != null and w.has_overhead():
			out.append(w)
	return out


## The bodies a landscape fields, each a roster key and the height it is drawn at.
static func _bodies(def: BiomeDef) -> Dictionary:
	var out := {}
	for k: StringName in def.roster:
		var over: Dictionary = (def.roster[k] as Dictionary).get("over", {})
		out[k] = float(over.get("height", Roster.row(k).get("height", 1.0)))
	var keeper := Sentinels.for_land(def.id)
	if keeper != null:
		out[keeper.kind] = float(Roster.row(keeper.kind).get("height", 1.0))
	var waiting := StringName("sentinel.%s" % def.id)
	if Roster.DEFS.has(waiting):
		out[waiting] = float(Roster.row(waiting).get("height", 1.0))
	return out


func test_no_body_is_taller_than_most_of_its_landscapes_roof() -> void:
	var worlds := _roofed()
	gt(float(worlds.size()), 0.0, "a seed makes a roofed world")
	var lands := 0
	for w in worlds:
		var rooms := {}
		var defs := {}
		for y in SIZE:
			for x in SIZE:
				if w.level_at(x, y) <= 0 or w.overhead_at(x, y).x < 0:
					continue
				var def := BiomeRegistry.at(w, Vector2(x + 0.5, y + 0.5))
				if def == null:
					continue
				# A packed array is held by value: taken out, grown and put back.
				var got: PackedInt32Array = rooms.get(def.id, PackedInt32Array())
				got.append(w.headroom_at(x, y))
				rooms[def.id] = got
				defs[def.id] = def
		for id: StringName in rooms:
			var got: PackedInt32Array = rooms[id]
			if got.size() < 200:
				continue
			got.sort()
			var most := float(got[int(float(got.size() - 1) * (1.0 - SHARE))]) * WorldData.STEP
			lands += 1
			var bodies := _bodies(defs[id])
			print("  %s: %d roofed tiles, %.0f%% have %.1f or more over them; bodies %s" % [id, got.size(), SHARE * 100.0, most, bodies])
			for k: StringName in bodies:
				check(float(bodies[k]) <= most, "%s: its %s stands %.1f tall, no taller than the %.1f that %.0f%% of its halls give" % [id, k, bodies[k], most, SHARE * 100.0])
	gt(float(lands), 0.0, "a roofed landscape was measured")
