extends SceneTree
## Top-down world map, one pixel per tile (scaled), for finding places.
##   godot --headless --path . -s tools/gd/map.gd -- --seed=1 --out=shots/map.png [--layer=ground|country|blend|level|props]
## Prints villages, spawn, country shares, a sample tile per country and per
## ecotone pair (for --at= or --place= shots), landmarks and stage timings.

const COUNTRY_COLORS: Array[Color] = [
	Color(0.06, 0.15, 0.25), Color(0.47, 0.66, 0.36), Color(0.26, 0.42, 0.33), Color(0.13, 0.36, 0.28),
	Color(0.87, 0.93, 0.97), Color(0.83, 0.77, 0.6), Color(0.62, 0.25, 0.14),
]


func _initialize() -> void:
	var out := "shots/map.png"
	var layer := "ground"
	var filtered: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--layer="):
			layer = a.trim_prefix("--layer=")
		else:
			filtered.append(a)
	var o := BootOptions.parse(filtered)
	var t0 := Time.get_ticks_msec()
	var w := WorldGen.generate(o.seed_value, o.size)
	var gen_ms := Time.get_ticks_msec() - t0
	if layer == "all":
		for each: String in ["ground", "country", "blend", "level", "props"]:
			_save(w, each, out.get_basename() + "_" + each + ".png")
	else:
		_save(w, layer, out)
	_report(w, gen_ms)
	quit()


func _save(w: WorldData, layer: String, out: String) -> void:
	var img := Image.create(w.size, w.size, false, Image.FORMAT_RGB8)
	var mesher := TerrainMesher.new(w) if layer == "ground" or layer == "props" else null
	for y in w.size:
		for x in w.size:
			img.set_pixel(x, y, _pixel(w, mesher, layer, x, y))
	if layer == "props":
		for p in w.props:
			img.set_pixel(clampi(floori(p.pos.x), 0, w.size - 1), clampi(floori(p.pos.y), 0, w.size - 1), _prop_color(p.kind))
	var scale := 3 if w.size <= 256 else 2
	img.resize(w.size * scale, w.size * scale, Image.INTERPOLATE_NEAREST)
	for line in w.lines:
		var ids: PackedInt32Array = line.props
		var col := Palette.FOUND[4] if line.kind == PropKind.PYLON else Palette.PLATE[4]
		for j in ids.size() - 1:
			_segment(img, w.props[ids[j]].pos * scale, w.props[ids[j + 1]].pos * scale, col)
	for m in w.landmarks:
		var p: Vector2 = m.pos * scale
		if m.kind == &"falls" or m.kind == &"bridge":
			# Small marks: there are many, and they sit on rivers.
			img.fill_rect(Rect2i(int(p.x) - 1, int(p.y) - 1, 3, 3), Palette.RIME[5] if m.kind == &"falls" else Palette.INK[0])
			continue
		img.fill_rect(Rect2i(int(p.x) - 3, int(p.y) - 3, 7, 7), Palette.INK[0])
		img.fill_rect(Rect2i(int(p.x) - 2, int(p.y) - 2, 5, 5), Palette.COPPER[4])
	for v in w.villages:
		var p: Vector2 = v.pos * scale
		img.fill_rect(Rect2i(int(p.x) - 5, int(p.y) - 5, 11, 11), Palette.INK[0])
		img.fill_rect(Rect2i(int(p.x) - 4, int(p.y) - 4, 9, 9), Palette.RUST[4])
	var sp := w.spawn * scale
	img.fill_rect(Rect2i(int(sp.x) - 4, int(sp.y) - 4, 9, 9), Palette.INK[0])
	img.fill_rect(Rect2i(int(sp.x) - 3, int(sp.y) - 3, 7, 7), Color.WHITE)
	_segment(img, sp, sp + Vector2.from_angle(w.spawn_facing) * 18.0, Color.WHITE)
	var path := out if out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("map ", path)


func _report(w: WorldData, gen_ms: int) -> void:
	for v in w.villages:
		var p: Vector2 = v.pos
		print("village %-2d %-13s %-10s at %d,%d level %d" % [v.id, v.name, BiomeRegistry.name_of(v.country), p.x, p.y, v.level])
	print("spawn at %d,%d (%s) facing %d deg" % [w.spawn.x, w.spawn.y, BiomeRegistry.name_of(w.country_at(int(w.spawn.x), int(w.spawn.y))), roundi(rad_to_deg(w.spawn_facing))])
	var counts := PackedInt32Array()
	counts.resize(BiomeRegistry.count())
	var land := 0
	for i in w.country.size():
		if w.level[i] > 0:
			counts[w.country[i]] += 1
			land += 1
	var shares := ""
	for c: int in BiomeRegistry.land_indices():
		shares += "%s %.1f%%  " % [BiomeRegistry.name_of(c), 100.0 * counts[c] / maxf(1.0, land)]
	print("shares ", shares)
	for c: int in BiomeRegistry.land_indices():
		var s := GenPlaces.country_sample(w, c)
		print("country %-10s sample at %d,%d" % [BiomeRegistry.name_of(c), s.x, s.y])
	for a: int in BiomeRegistry.land_indices():
		for b: int in BiomeRegistry.land_indices():
			if b <= a:
				continue
			var s := GenPlaces.ecotone_sample(w, a, b)
			if s.x >= 0.0:
				print("ecotone %-20s at %d,%d" % ["%s-%s" % [BiomeRegistry.name_of(a), BiomeRegistry.name_of(b)], s.x, s.y])
	var by_kind := {}
	for m in w.landmarks:
		if not by_kind.has(m.kind):
			by_kind[m.kind] = []
		by_kind[m.kind].append("%d,%d" % [m.pos.x, m.pos.y])
	for kind: StringName in by_kind:
		var at: Array = by_kind[kind]
		print("landmarks %-13s %3d  %s%s" % [kind, at.size(), "  ".join(PackedStringArray(at.slice(0, 8))), "  ..." if at.size() > 8 else ""])
	var r := GenPlaces.river_sample(w)
	var cl := GenPlaces.cliff_sample(w)
	print("places river at %d,%d  cliff at %d,%d  rivers %d  roads %d  lines %d  props %d" % [r.x, r.y, cl.x, cl.y, w.rivers.size(), w.roads.size(), w.lines.size(), w.props.size()])
	var timing := ""
	for k: StringName in WorldGen.last_timings:
		timing += "%s %.0f  " % [k, WorldGen.last_timings[k]]
	print("timings gen %d ms: %s" % [gen_ms, timing])
	# The FINE marks too, biggest first. `GenContext.mark` collects about forty-five
	# of these and `WorldGen.last_detail` keeps them, and this printed only the
	# eleven coarse ones -- so the number that says WHICH PART of a stage costs
	# what was thrown away on every run, and had to be gone and got with a
	# throwaway test every time anybody wanted it.
	var fine: Array = []
	for k: StringName in WorldGen.last_detail:
		fine.append([float(WorldGen.last_detail[k]), String(k)])
	fine.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var detail := ""
	for row: Array in fine:
		if row[0] >= 1.0:
			detail += "%s %.0f  " % [row[1], row[0]]
	print("timings detail: %s" % detail)


func _pixel(w: WorldData, mesher: TerrainMesher, layer: String, x: int, y: int) -> Color:
	var i := y * w.size + x
	var l := w.level[i]
	if l <= 0 and layer != "level":
		return Palette.BRINE[2 if l == 0 else 1]
	var shade := 1.0
	if x > 0 and y > 0:
		# Light from the north-west: faces toward it bright, away dark.
		var d := (w.level[i - 1] + w.level[i - w.size]) - 2 * l
		shade = clampf(1.0 - d * 0.07, 0.72, 1.18)
	match layer:
		"country":
			var c := COUNTRY_COLORS[w.country[i]].lerp(COUNTRY_COLORS[w.country2[i]], w.blend[i])
			return (c * shade).lightened(l * 0.012)
		"blend":
			var b := w.blend[i] * 2.0
			var c := COUNTRY_COLORS[w.country[i]].darkened(0.55)
			return c.lerp(Color(1, 0.9, 0.5), b) * shade
		"level":
			if l < 0:
				return Palette.BRINE[0]
			if l == 0:
				return Palette.BRINE[2]
			var t := l / float(GenRelief.MAX_LEVEL)
			var c := Palette.MOSS[3].lerp(Palette.EARTH[4], clampf(t * 1.6, 0.0, 1.0)).lerp(Palette.RIME[5], clampf(t * 2.0 - 1.0, 0.0, 1.0))
			return c * shade
		"props":
			return (mesher.top_color(x, y) * shade).darkened(0.45)
	return mesher.top_color(x, y) * shade


func _prop_color(kind: int) -> Color:
	match kind:
		PropKind.PINE, PropKind.SNOW_PINE, PropKind.BROADLEAF:
			return Palette.SPRUCE[4]
		PropKind.BUSH, PropKind.GORSE, PropKind.REEDS:
			return Palette.MOSS[5]
		PropKind.DEAD_TREE, PropKind.DRIFTWOOD, PropKind.WRACK, PropKind.PEAT_BANK:
			return Palette.EARTH[4]
		PropKind.BOULDER, PropKind.CLINTS, PropKind.MUSSEL_ROCK, PropKind.STANDING_STONE, PropKind.CAIRN:
			return Palette.STONE[4]
		PropKind.STONE_ORE, PropKind.IRON_ORE, PropKind.COPPER_ORE, PropKind.COAL_ORE, PropKind.TIN_ORE:
			return Palette.COPPER[4]
		PropKind.VENT:
			return Palette.EMBER[4]
		PropKind.PYLON, PropKind.POLE, PropKind.TIP, PropKind.WRECK:
			return Palette.FOUND[4]
	return Palette.RUST[4]


func _segment(img: Image, a: Vector2, b: Vector2, col: Color) -> void:
	var steps := maxi(1, ceili(a.distance_to(b)))
	for s in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		var x := int(p.x)
		var y := int(p.y)
		if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
			img.set_pixel(x, y, col)
