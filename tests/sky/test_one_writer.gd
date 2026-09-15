extends TestCase
## One writer for the sky's globals, once a frame: two systems writing
## wind_strength lost a storm's sway, and set_hour composing twice a frame did
## the work twice with the first pass stale.

const SkySystem := preload("res://src/systems/10_sky.gd")
## Globals SkyLight owns. Anything else writing them is a second writer.
const OWNED: Array[String] = ["wind_strength", "sky_", "neon_grade", "neon_wet", "neon_lamp_rgb", "glint_rgb"]


func test_only_sky_light_writes_the_sky_globals() -> void:
	var offenders: Array[String] = []
	for path in _scripts("res://src"):
		if path == "res://src/render/sky_light.gd":
			continue
		var text := FileAccess.get_file_as_string(path)
		var at := text.find("global_shader_parameter_set(")
		while at >= 0:
			var arg := text.substr(at + 28, 40).strip_edges().trim_prefix("\"").trim_prefix("&\"")
			for owned in OWNED:
				if arg.begins_with(owned):
					offenders.append("%s: %s" % [path, arg.get_slice("\"", 0)])
			at = text.find("global_shader_parameter_set(", at + 1)
	eq(offenders.size(), 0, "second writers: %s" % [offenders])


func test_a_running_game_composes_the_sky_once_a_frame_with_the_storm_sway() -> void:
	var o := BootOptions.new()
	o.size = 64
	o.hour = 12.0
	o.weather = "storm:1"
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	check(g.sky.driven, "the sky system drives the sky")
	await frames(3)
	var before := g.sky.compose_count
	var f0 := Engine.get_process_frames()
	await frames(10)
	var frames_run := Engine.get_process_frames() - f0
	eq(g.sky.compose_count - before, frames_run, "once per process frame")
	# The sway a storm asks for is what SkyLight writes to wind_strength, and
	# nothing else writes it (test_only_sky_light_writes_the_sky_globals).
	gt(g.sky.sway, 0.6, "a storm bends things hard")
	g.queue_free()
	await frames(1)
	Weather.unforce()


func test_an_undriven_sky_composes_at_once() -> void:
	var sky := SkyLight.new()
	tree.root.add_child(sky)
	var n := sky.compose_count
	sky.set_hour(13.0)
	eq(sky.compose_count, n + 1, "the title and gallery see the hour straight away")
	sky.driven = true
	sky.set_hour(14.0)
	eq(sky.compose_count, n + 1, "driven: recorded, composed in the frame's late pass")
	await frames(2)
	gt(float(sky.compose_count), float(n + 1), "and composed")
	sky.queue_free()
	await frames(1)


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	return out
