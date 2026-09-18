extends SceneTree
## Which NAMED place each coordinate a tour stages by is nearest to, and how far.
##
## Written for the conversion of `at X,Y` stagings to `place NAME` (CLAUDE.md,
## "Stage by name, never by a coordinate"): a coordinate cannot be converted
## safely until somebody knows what it IS, and guessing is how five frames in
## this repo became pictures of the wrong place for months.
##
##   godot --headless --path . -s tools/gd/probe_places.gd -- --seed=1 --at=200.5,431.5,135,375
##   godot --headless --path . -s tools/gd/probe_places.gd -- --seed=7
##
## With `--at`, prints per coordinate the landscape under it and every named place
## within NEAR tiles, nearest first: a coordinate with a name at distance 0-1 is
## that place written the long way round.
##
## With no `--at`, prints the TABLE -- where every name lands, and how far that is
## from the nearest thing anybody built. Those are two different questions and the
## second is the one that catches a name resolving INTO something: `turf_rows` on
## seed 7 is 0.0 tiles from a depot yard, so every frame staged with it is a
## photograph of the yard, and nothing about the name says so.

## How far a name can be and still be worth offering as what a coordinate meant.
const NEAR := 12.0


func _init() -> void:
	var seed_value := 1
	var coords: Array[Vector2] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = a.trim_prefix("--seed=").to_int()
		elif a.begins_with("--at="):
			var n := a.trim_prefix("--at=").split(",")
			for i in range(0, n.size() - 1, 2):
				coords.append(Vector2(n[i].to_float(), n[i + 1].to_float()))
	var w := BootWorld.world(seed_value, Tuning.WORLD_SIZE)
	var names := _names(w)
	print("probe seed %d: %d names known" % [seed_value, names.size()])
	if coords.is_empty():
		_table(w, names)
		quit()
		return
	for c in coords:
		var land := BiomeRegistry.at(w, c)
		var rows: Array[Dictionary] = []
		for key: String in names:
			var p: Vector2 = names[key]
			if p.x < 0.0:
				continue
			var d := p.distance_to(c)
			if d <= NEAR:
				rows.append({"name": key, "at": p, "d": d})
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.d) < float(b.d))
		var said := ""
		for r: Dictionary in rows.slice(0, 4):
			said += "  %s (%.1f away, at %s)" % [r.name, r.d, str(r.at)]
		print("at %-16s %-12s%s" % [str(c), land.id, said if said != "" else "  -- NOTHING NAMED WITHIN %d TILES" % int(NEAR)])
	quit()


## Where every name lands, and how far that is from the nearest thing anybody
## built. The second column is the point: a name is a promise about what will be
## in the picture, and only this says whether the promise holds.
func _table(w: WorldData, names: Dictionary) -> void:
	# Three columns, not one total, because a LANDMARK name sitting on its own
	# landmark is correct and a total would report it as a hit every time. What
	# no name may sit inside is a village or a depot yard, and those two are
	# where the lies have been.
	var villages: Array[Vector2] = []
	for v: Dictionary in w.villages:
		villages.append(v.pos as Vector2)
	var yards: Array[Vector2] = []
	for s in Works.sites(w):
		yards.append(s.pos)
	var marks: Array[Vector2] = []
	for s in Landmarks.sites(w):
		marks.append(s.pos)
	var keys := names.keys()
	keys.sort()
	for key: String in keys:
		var p: Vector2 = names[key]
		if p.x < 0.0:
			print("name %-18s -- no such place here" % key)
			continue
		var dv := _nearest(villages, p)
		var dy := _nearest(yards, p)
		var dm := _nearest(marks, p)
		var says := ""
		if dv < Works.YARD:
			says = "   <-- IN A VILLAGE"
		elif dy < Works.YARD and not key.begins_with("works"):
			says = "   <-- IN A DEPOT YARD"
		print("name %-18s at %-18s %-16s village %6.1f  yard %6.1f  landmark %6.1f%s" % [
			key, str(p), BiomeRegistry.at(w, p).id, dv, dy, dm, says])


static func _nearest(of: Array[Vector2], p: Vector2) -> float:
	var d := INF
	for q in of:
		d = minf(d, q.distance_to(p))
	return d


## Every name GenPlaces can resolve on this world, to where it resolves.
func _names(w: WorldData) -> Dictionary:
	var out := {}
	for key: String in ["spawn", "river", "cliff", "open"]:
		out[key] = GenPlaces.find(w, key)
	# The marks the machines' survey left (GenWorks): these live in w.landmarks
	# and are named places too, and one of them is how this probe found a tour
	# standing in a depot yard.
	for m: Dictionary in w.landmarks:
		var k := String(m.get("kind", ""))
		if k != "" and not out.has(k):
			out[k] = GenPlaces.find(w, k)
	for d in BiomeRegistry.land_in(w.realm):
		out[String(d.id)] = GenPlaces.find(w, String(d.id))
	for site in Works.sites(w):
		for part: StringName in Works.PART_NAMES:
			var k := "works_" + String(part)
			if not out.has(k):
				out[k] = GenPlaces.find(w, k)
		if not out.has("works"):
			out["works"] = GenPlaces.find(w, "works")
	for s in Landmarks.sites(w):
		var k := String(s.kind)
		if not out.has(k):
			out[k] = GenPlaces.find(w, k)
	return out
