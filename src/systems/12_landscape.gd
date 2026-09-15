extends GameSystem
## The landscape's live inputs: wind for everything that sways (from Weather
## once the sky package lands it), and --stats, which prints what a frame cost
## just before a shot is taken.

const WEATHER := "res://src/core/weather.gd"

var _frames := 0
var _weather: GDScript
var _wind := 0.35


func setup(g: Game) -> void:
	super.setup(g)
	if ResourceLoader.exists(WEATHER):
		_weather = load(WEATHER) as GDScript


func _process(delta: float) -> void:
	if game == null or game.view == null:
		return
	_frames += 1
	var target := 0.35
	if _weather != null:
		var wx: Variant = _weather.call("at", game.world.seed_value, game.clock.minutes)
		if wx is Dictionary and (wx as Dictionary).has("wind"):
			target = clampf(float((wx as Dictionary)["wind"]), 0.0, 1.0)
	_wind = lerpf(_wind, target, 1.0 - exp(-0.5 * delta))
	RenderingServer.global_shader_parameter_set("wind_strength", _wind)
	if game.options.stats and _frames == maxi(3, game.options.frames - 1):
		print(stats_line(game.view))


static func stats_line(view: WorldView) -> String:
	var avg := view.build_ms / maxf(1.0, view.build_count)
	return "world stats: draw calls %d, objects %d, primitives %d, chunks %d, chunk build avg %.1f ms max %.1f ms over %d, fps %d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		view.chunk_count(), avg, view.build_ms_max, view.build_count,
		Performance.get_monitor(Performance.TIME_FPS)]
