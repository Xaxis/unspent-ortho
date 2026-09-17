extends GameSystem
## The landscape's live inputs: --stats, which prints what a frame cost just
## before a shot is taken. Wind for everything that sways (wind_strength) is the
## sky's: SkyLight is its one writer, so a storm's sway is never overwritten.


var _frames := 0


func setup(g: Game) -> void:
	super.setup(g)


func _process(_delta: float) -> void:
	if game == null or game.view == null:
		return
	_frames += 1
	if game.options.stats and _frames == maxi(3, game.options.frames - 1):
		# What the frame was actually drawn by, before what it cost: a tier that
		# quietly stepped down, or a machine that never got Forward+, changes every
		# number on the next line and is invisible otherwise (docs/LOOK.md).
		# "world " first: tools/shot.sh only forwards lines that begin `world ` or
		# `shot `, so a line named anything else is printed and thrown away.
		var px := Quality.render_pixels()
		print("world render: %s, quality %s, world %dx%d of %dx%d, slate pitch %d, caps %d" % [
			"forward_plus" if Quality.forward_plus() else "gl_compatibility",
			Quality.current_id(), px.x, px.y, UiBase.SIZE.x, UiBase.SIZE.y,
			UiBase.PITCH, UiFont.CAP])
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
