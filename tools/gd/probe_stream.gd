extends SceneTree
## WHAT A STREAMED WORLD WOULD COST, measured on the world we make today, so
## the streaming design's guesses are numbers before a slice leans on them.
##
##   godot --headless --path . -s tools/gd/probe_stream.gd -- [--seeds=1,7] [--size=N] [--section=256]
##
## Per seed:
##   stage    ms per `WorldGen` stage, tagged by the design's split: plan (runs
##            once, up front), local (runs per section) or mixed (both)
##   memory   static memory at the start, the peak while growing, and after
##   engine   the engine's own memory monitors after growing: the figure to
##            compare between builds (a browser's heap is only a sanity check)
##   tile     bytes per tile the WorldData keeps in its per-tile arrays
##   section  per `--section` square: land share and props; how many hold land
##   prop     bytes one WorldProp costs resident (made and measured here)
##   plan     what the resident plan would hold, from this world's counts: the
##            coarse grid, the half-res shape, polylines and anchor rows
##   margin   the reaches a section's margin M has to cover, from the registry

const SECTION := 256
## The design's split of each stage (docs of record: the streaming design, §1).
const CLASS := {
	&"shape": "plan+local", &"layout": "plan", &"form": "plan", &"relief": "mixed",
	&"tiles": "mixed", &"rivers": "mixed", &"terrace": "local", &"straits": "plan",
	&"still": "mixed", &"settle": "mixed", &"access": "mixed", &"surface": "local",
	&"props": "mixed", &"treads": "mixed",
}


func _init() -> void:
	var seeds: Array[int] = [1, 7]
	var size := Tuning.WORLD_SIZE
	var section := SECTION
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds.clear()
			for s: String in a.trim_prefix("--seeds=").split(","):
				seeds.append(s.to_int())
		elif a.begins_with("--size="):
			size = a.trim_prefix("--size=").to_int()
		elif a.begins_with("--section="):
			section = a.trim_prefix("--section=").to_int()
	print("stream size %d section %d" % [size, section])
	_prop_bytes()
	_margin()
	for s in seeds:
		_one(s, size, section)
	quit()


func _one(s: int, size: int, section: int) -> void:
	var m0 := OS.get_static_memory_usage()
	var t0 := Time.get_ticks_msec()
	var w := WorldGen.generate(s, size)
	var ms := Time.get_ticks_msec() - t0
	var m1 := OS.get_static_memory_usage()
	var peak := 0
	for row: Array in WorldGen.last_memory:
		peak = maxi(peak, int(row[2]))
	print("stream seed %d total %d ms" % [s, ms])
	var plan_ms := 0.0
	for k: StringName in WorldGen.last_timings:
		if k == &"total":
			continue
		var cls: String = CLASS.get(k, "?")
		var v: float = WorldGen.last_timings[k]
		if cls == "plan":
			plan_ms += v
		print("stream stage %-10s %-10s %8.0f ms" % [k, cls, v])
	print("stream stage plan-only sum %.0f ms of %.0f" % [plan_ms, float(WorldGen.last_timings.get(&"total", 0.0))])
	print("stream memory start %d MB peak %d MB after %d MB (kept %d MB)" % [m0 >> 20, peak >> 20, m1 >> 20, (m1 - m0) >> 20])
	# Measured inside the engine, which gives the same number for the same build
	# every run; a browser's heap grows in steps and wanders by ~200 MB.
	print("stream engine static %d MB static_max %d MB objects %d" % [int(Performance.get_monitor(Performance.MEMORY_STATIC)) >> 20,
		int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)) >> 20, int(Performance.get_monitor(Performance.OBJECT_COUNT))])
	var n := size * size
	var tile := w.level.size() * 4 + w.ground.size() + w.country.size() + w.country2.size() \
		+ w.blend.size() * 4 + w.region.size() * 4 + w.moisture.size() * 4 + w.temperature.size() * 4 \
		+ w.road.size() + w.recipe.size() + w.continent.size()
	print("stream tile %.1f B/tile, %d MB for the world, %.2f MB per %d² section" % [float(tile) / n, tile >> 20, float(tile) / n * section * section / 1048576.0, section])
	var across := ceili(float(size) / section)
	var land := PackedInt32Array()
	land.resize(across * across)
	var props := PackedInt32Array()
	props.resize(across * across)
	for y in size:
		for x in size:
			if w.level[y * size + x] > 0:
				land[(y / section) * across + x / section] += 1
	for p: WorldProp in w.props:
		var sx := clampi(floori(p.pos.x / section), 0, across - 1)
		var sy := clampi(floori(p.pos.y / section), 0, across - 1)
		props[sy * across + sx] += 1
	var with_land := 0
	var counts: Array[int] = []
	for i in across * across:
		if land[i] > 0:
			with_land += 1
			counts.append(props[i])
	counts.sort()
	print("stream section %d of %d hold land; props per land section min %d median %d max %d; props total %d" % [
		with_land, across * across, counts[0], counts[counts.size() / 2], counts[counts.size() - 1], w.props.size()])
	# The plan, from this world's own counts. Coarse cells at STEP; per cell:
	# continent 1, top-two types and weight 3, relief params 6x2, level 1,
	# inland 2, forest 1, region 4 = 24 B. Half-res shape: lf int16 + land 1.
	var cw := ceili(float(size) / GenContext.STEP)
	var coarse := cw * cw * 24
	var half := (size / 2) * (size / 2) * 3
	var verts := 0
	for r: PackedVector2Array in w.rivers:
		verts += r.size()
	for r: PackedVector2Array in w.roads:
		verts += r.size()
	var rows := w.villages.size() + w.landmarks.size() + w.regions.size() + w.lines.size()
	var plan := coarse + half + verts * 12 + rows * 96
	_hot(w)
	print("stream plan coarse %d² %.1f MB, half-res %.1f MB, polylines %d verts %.1f MB, rows %d %.2f MB: %.1f MB" % [
		cw, coarse / 1048576.0, half / 1048576.0, verts, verts * 12 / 1048576.0, rows, rows * 96 / 1048576.0, plan / 1048576.0])


## One WorldProp's resident cost: many made, the static memory they took.
func _prop_bytes() -> void:
	var keep: Array[WorldProp] = []
	var m0 := OS.get_static_memory_usage()
	for i in 20000:
		keep.append(WorldProp.new(i, 0, Vector2(i, i), 0.0, 1.0))
	var m1 := OS.get_static_memory_usage()
	print("stream prop %d B each (20000 made)" % [(m1 - m0) / 20000])
	keep.clear()


## The reaches a section's margin has to cover, from what the registry declares.
func _margin() -> void:
	var out_reach := 0.0
	var in_reach := 0.0
	var tongue := 0.0
	for d: BiomeDef in BiomeRegistry.all():
		out_reach = maxf(out_reach, d.reach_out_high.x)
		in_reach = maxf(in_reach, d.reach_in_low.x)
		for k: Variant in d.tongues:
			tongue = maxf(tongue, (d.tongues[k] as Vector2).x)
	print("stream margin ecotone out %.1f in %.1f tongue %.1f tidy patch %d tiles" % [out_reach, in_reach, tongue, GenTidy.MIN_PATCH])


## THE HOT PATHS PROPS ARE READ ON, timed, so moving props into packed columns
## can be held to "no slower" (the design's S7: over ~10% and a loop reads the
## columns directly). Collision-style asks round points near props, a far-view
## walk over every prop, and id lookups.
func _hot(w: WorldData) -> void:
	var q := WorldQuery.new(w)
	var n := w.prop_count()
	var t0 := Time.get_ticks_usec()
	var acc := 0.0
	for k in 50000:
		var p := w.prop_at(int(Rng.hash01(w.seed_value, k, 1, 0x40) * n))
		for o in q.props_near(p.pos + Vector2(0.7, -0.4), 1.5):
			acc += o.solid + o.pos.x + float(o.id & 1)
	var near_ms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	for i in n:
		var o := w.prop_at(i)
		acc += o.pos.x + o.kind + o.variant + o.scale + o.rot + float(o.id & 1)
	var walk_ms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	for k in 200000:
		var o := w.prop(w.prop_at(int(Rng.hash01(w.seed_value, k, 2, 0x40) * n)).id)
		acc += o.pos.y
	var id_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("stream hot near %.0f ms (50k asks) walk %.0f ms (%d props) ids %.0f ms (200k) [%d]" % [near_ms, walk_ms, n, id_ms, int(acc) & 1])

