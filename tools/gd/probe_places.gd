extends SceneTree
## Which NAMED place each coordinate a tour stages by is nearest to, and how far.
##
## Written for the conversion of `at X,Y` stagings to `place NAME` (CLAUDE.md,
## "Stage by name, never by a coordinate"): a coordinate cannot be converted
## safely until somebody knows what it IS, and guessing is how five frames in
## this repo became pictures of the wrong place for months.
##
##   godot --headless --path . -s tools/gd/probe_places.gd -- --seed=1 --at=200.5,431.5,135,375
##
## Prints, per coordinate, the landscape under it and every named place within
## NEAR tiles, nearest first. A coordinate with a name at distance 0-1 is that
## place written the long way round.

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


## Every name GenPlaces can resolve on this world, to where it resolves.
func _names(w: WorldData) -> Dictionary:
	var out := {}
	for key: String in ["spawn", "river", "cliff"]:
		out[key] = GenPlaces.find(w, key)
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
