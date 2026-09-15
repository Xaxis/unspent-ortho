extends SceneTree
## Top-down world map, one pixel per tile (scaled), for finding places.
##   godot --headless --path . -s tools/gd/map.gd -- --seed=1 --out=shots/map.png
## Prints villages, spawn and one sample tile per country.

func _initialize() -> void:
	var o := BootOptions.new()
	var out := "shots/map.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var filtered: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--out="):
			filtered.append(a)
	o = BootOptions.parse(filtered)
	var w := WorldGen.generate(o.seed_value, o.size)
	var mesher := TerrainMesher.new(w)
	var img := Image.create(w.size, w.size, false, Image.FORMAT_RGB8)
	for y in w.size:
		for x in w.size:
			var c := mesher.top_color(x, y) if w.level[y * w.size + x] > 0 else Palette.BRINE[2 if w.level[y * w.size + x] == 0 else 1]
			c = c.lightened(clampf(w.level[y * w.size + x], 0, 12) * 0.03)
			img.set_pixel(x, y, c)
	for v in w.villages:
		var p: Vector2 = v.pos
		img.fill_rect(Rect2i(int(p.x) - 2, int(p.y) - 2, 5, 5), Palette.RUST[4])
		print("village %-14s %-10s at %d,%d" % [v.name, Country.NAMES[v.country], p.x, p.y])
	img.fill_rect(Rect2i(int(w.spawn.x) - 1, int(w.spawn.y) - 1, 3, 3), Color.WHITE)
	print("spawn at %d,%d (%s)" % [w.spawn.x, w.spawn.y, Country.NAMES[w.country_at(int(w.spawn.x), int(w.spawn.y))]])
	# A sample walkable tile deep inside each country: the one farthest from its border.
	for c: int in Country.LAND:
		var best := Vector2i(-1, -1)
		var best_score := -1.0
		for y in range(4, w.size - 4, 3):
			for x in range(4, w.size - 4, 3):
				if w.country_at(x, y) != c or w.level_at(x, y) <= 0:
					continue
				var s := 0.0
				for r: int in [4, 8, 12]:
					for d: Vector2i in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
						if w.country_at(x + d.x, y + d.y) == c:
							s += 1.0
				if s > best_score:
					best_score = s
					best = Vector2i(x, y)
		print("country %-10s sample at %d,%d" % [Country.NAMES[c], best.x, best.y])
	img.resize(w.size * 3, w.size * 3, Image.INTERPOLATE_NEAREST)
	var path := out if out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("map ", path)
	quit()
