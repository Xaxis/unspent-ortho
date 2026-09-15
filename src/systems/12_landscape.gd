extends GameSystem
## The landscape's live inputs: wind for everything that sways (from Weather
## once the sky package lands it), and --stats, which prints what a frame cost
## just before a shot is taken.


var _frames := 0
var _wind := 0.35


func setup(g: Game) -> void:
	super.setup(g)


func _process(delta: float) -> void:
	if game == null or game.view == null:
		return
	_frames += 1
	var target := clampf(float(Weather.at(game.world.seed_value, game.clock.minutes).get("wind", 0.35)), 0.0, 1.0)
	_wind = lerpf(_wind, target, 1.0 - exp(-0.5 * delta))
	RenderingServer.global_shader_parameter_set("wind_strength", _wind)
	if game.options.stats and _frames == maxi(3, game.options.frames - 1):
		print(stats_line(game.view))


static func stats_line(view: WorldView) -> String:
	var n := maxf(1.0, view.build_count)
	var pr := view.stage_usec()
	return "world stats: draw calls %d, objects %d, primitives %d, chunks %d, chunk build avg %.1f ms max %.1f ms over %d (main thread avg %.1f max %.1f; mesher fill %.1f shore %.1f tiles %.1f lattice %.1f cells %.1f water %.1f arrays %.1f), fps %d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		view.chunk_count(), view.build_ms / n, view.build_ms_max, view.build_count,
		view.main_ms / n, view.main_ms_max,
		pr[0] / 1000.0 / n, pr[1] / 1000.0 / n, pr[2] / 1000.0 / n, pr[7] / 1000.0 / n, pr[3] / 1000.0 / n, pr[4] / 1000.0 / n, pr[5] / 1000.0 / n,
		Performance.get_monitor(Performance.TIME_FPS)]
