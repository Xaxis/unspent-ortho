extends GameSystem
## The landscape's live inputs: --stats, which prints what a frame cost just
## before a shot is taken. Wind for everything that sways (wind_strength) is the
## sky's: SkyLight is its one writer, so a storm's sway is never overwritten.


var _frames := 0
## Every frame's own milliseconds, for the distribution `--stats` reports. An
## AVERAGE cannot see a hitch and a hitch is what a player calls jumpy: 72 fps
## with one frame in twenty at 40 ms reads as stutter and averages as fine.
var _ms := PackedFloat32Array()
var _proc := PackedFloat32Array()
var _phys := PackedFloat32Array()


func setup(g: Game) -> void:
	super.setup(g)


func _process(_delta: float) -> void:
	if game == null or game.view == null:
		return
	_tell_camera_how_tall_it_builds()
	_frames += 1
	if game.options.stats:
		_ms.append(_delta * 1000.0)
		_proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	# The renderer does not time itself unless asked, and it must be asked BEFORE
	# the frame that is read: `stats_line` runs at frames-1, so switching this on
	# here gives it several frames of measurement to report.
	if game.options.stats and _frames == 1:
		var vp := game.view.get_viewport()
		if vp != null:
			RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
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
		print(frame_line(_ms))


## The camera's near focus clears the tallest thing a landscape BUILDS, and only
## this file is in a position to say what that is: the camera package may not know
## about landscapes and the biome package may not know about cameras.
##
## The TALLEST of what can be in frame, not what is underfoot, and the difference
## is the whole point: the buildings this rule is about stand at the near edge of
## the picture, which on a border is the other landscape. Asking the tile the
## player is standing on would keep the city's towers blurred until they had
## walked past them, which is exactly the frame that started this.
##
## Five samples round the frame's own reach — cheap, and it cannot be wrong about
## a landscape it can see. The camera eases the change itself, so the number
## arriving a little early and leaving a little late is also the pull that reads
## best walking in.
const LOOK_ROUND := 16.0

func _tell_camera_how_tall_it_builds() -> void:
	if game.camera == null or game.world == null:
		return
	var w := game.world
	var p: Vector2 = game.player.pos if game.player != null else w.spawn
	var high := 0.0
	for d: Vector2 in [Vector2.ZERO, Vector2(LOOK_ROUND, 0.0), Vector2(-LOOK_ROUND, 0.0),
			Vector2(0.0, LOOK_ROUND), Vector2(0.0, -LOOK_ROUND)]:
		var x := clampi(floori(p.x + d.x), 0, w.size - 1)
		var y := clampi(floori(p.y + d.y), 0, w.size - 1)
		high = maxf(high, BiomeForms.of(w.country_at(x, y)).tallest())
	game.camera.clear_lift = high


## **AN INSTRUMENT THAT CANNOT REPORT ITS OWN GAP FAILS TOWARD GREEN**, which is
## the whole reason `unaccounted` is on this line. The mesher profiles its seven
## stages and nothing profiled `Decor.build_arrays` or `bake_props`, which are
## WorldView's work and not the mesher's — so the line named 36 ms of a 46 ms
## build and read as complete. Somebody (me) then quoted those six stages as the
## cost of a chunk and planned an afternoon against them. The residual is what
## makes that impossible: if everything is named it is ~0, and if it is not, the
## line says so instead of quietly summing to less than the total.
## **AND THE `fps` THIS LINE USED TO END WITH WAS THE SAME MISTAKE IN ITS OWN
## LAST FIELD.** `Performance.TIME_FPS` is frames in the last SECOND, and a shot
## renders a handful of frames after a twelve-second world gen, so it printed
## `fps 1` for a frame carrying 165 draw calls. It is not wrong about itself --
## the process really did render about one frame in that second -- it is
## answering a question nobody asked, and it reads exactly like a framerate.
## Believing it cost an hour hunting a stall that was not there, on the same
## night `ForePerf`'s header already said in writing that this number lies.
##
## **AND THE LINE NOW ACCOUNTS FOR THE WHOLE FRAME, not just the chunks**, which
## is the same rule as `unaccounted` one paragraph up. `proc` and `phys` are what
## the main thread spent on every node and every physics tick. They are here
## because the night this field was fixed, play was at 5 fps with `proc` at 88 ms
## and render CPU at 0.40 -- and nothing printed said so, so the chase started at
## the renderer, which was the one part doing its job. A line that reports only
## the part you own will send the next person to the part you own.
##
## The honest replacement is the one thing a shot CAN know: what the renderer
## measured for the frame it just drew. The GPU half is left off because Metal
## through MoltenVK answers zero here (`ForePerf` again), and a nought is worse
## than a silence -- the next person would believe it.
static func stats_line(view: WorldView) -> String:
	var n := maxf(1.0, view.build_count)
	var pr := view.stage_usec()
	# prof 0,1,2,3,4,5,7 are times; 6 is the vertex count, which was collected
	# on every chunk since the mesher was written and read by nothing.
	var mesher_ms := (pr[0] + pr[1] + pr[2] + pr[3] + pr[4] + pr[5] + pr[7]) / 1000.0
	var gap := view.build_ms - view.main_ms - mesher_ms - view.decor_ms - view.props_ms
	return "world stats: draw calls %d, objects %d, primitives %d, chunks %d (parked %d, far %d/%d avg %.1f ms), chunk build avg %.1f ms max %.1f ms over %d (main thread avg %.1f max %.1f; mesher fill %.1f shore %.1f tiles %.1f lattice %.1f cells %.1f water %.1f arrays %.1f decor %.1f props %.1f unaccounted %.1f), verts %d, frame: proc %.1f ms, phys %.1f ms, render cpu %s" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		view.chunk_count(), view.parked_count(),
		view.far.block_count() if view.far != null else 0, view.far_wanted(),
		view.far_ms / maxf(1.0, view.far_count),
		view.build_ms / n, view.build_ms_max, view.build_count,
		view.main_ms / n, view.main_ms_max,
		pr[0] / 1000.0 / n, pr[1] / 1000.0 / n, pr[2] / 1000.0 / n, pr[7] / 1000.0 / n, pr[3] / 1000.0 / n, pr[4] / 1000.0 / n, pr[5] / 1000.0 / n,
		view.decor_ms / n, view.props_ms / n, gap / n, int(pr[6] / n),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		_render_cpu(view)]


## What the renderer measured for the frame it just drew, asked of the view's own
## viewport so it is the world being drawn and not some other one.
##
## **A clock that is not running says so.** Godot only times a viewport that was
## asked to (`viewport_set_measure_render_time`), and on this machine the GPU half
## answers zero even then -- so a bare `%.2f` here would print `0.00 ms` for a
## frame carrying 165 draw calls, which is the same lie as `fps 1` wearing better
## units. `ForePerf` learned this first and its header says why: saying nought
## when the clock is stopped is worse than saying nothing, because the next
## person believes a number.
static func _render_cpu(view: WorldView) -> String:
	var vp := view.get_viewport()
	if vp == null:
		return "unmeasured"
	var ms := RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid())
	return "%.2f ms" % ms if ms > 0.0 else "unmeasured"


## The frame budgets, and docs/PERF.md is why each one is the number it is. The
## headline: BotW targets a 33.3 ms frame, so OUR WORST MAY NOT EXCEED THEIR
## TARGET -- our worst frame no worse than their best.
const P50_MS := 8.3
const P95_MS := 13.9
const P99_MS := 16.7
const WORST_MS := 33.3
## A frame four times its neighbours reads as a jolt however fast they were.
const WORST_OVER_P50 := 4.0

## WHAT A PLAYER CALLS JUMPY, stated as a distribution rather than an average.
## The worst frames are the whole complaint: a run that sits at 8 ms and spikes
## to 60 four times a second is unplayable and has a fine mean. Percentiles are
## taken over every frame of the run, and the count is printed so a short run
## cannot pretend to be evidence.
static func frame_line(ms: PackedFloat32Array) -> String:
	if ms.size() < 4:
		return "world frames: too few to say (%d)" % ms.size()
	var a := Array(ms)
	a.sort()
	var pick := func(q: float) -> float: return float(a[clampi(int(q * (a.size() - 1)), 0, a.size() - 1)])
	var over := 0
	for v: float in a:
		if v > 16.7:
			over += 1
	# WHERE the slow frames fall decides what kind of problem it is: bunched at the
	# start is warm-up a player sees once, spread through the run is a hitch they
	# live with. An average cannot tell those apart and they want opposite fixes.
	var where := PackedStringArray()
	for i in ms.size():
		if ms[i] > 16.7:
			where.append("%d:%.0f" % [i, ms[i]])
	# JUDGED, not just reported. docs/PERF.md sets the budgets and the reason the
	# headline is the WORST frame: BotW's target frame is 33.3 ms, so ours may
	# never exceed it -- our worst no worse than their best. A line that prints a
	# number and leaves the reader to know whether it is good is half an
	# instrument.
	var p50: float = pick.call(0.5)
	var p95: float = pick.call(0.95)
	var p99: float = pick.call(0.99)
	var worst := float(a[-1])
	var bad := PackedStringArray()
	if p50 > P50_MS:
		bad.append("p50")
	if p95 > P95_MS:
		bad.append("p95")
	if p99 > P99_MS:
		bad.append("p99")
	if worst > WORST_MS:
		bad.append("worst")
	if p50 > 0.0 and worst / p50 > WORST_OVER_P50:
		bad.append("worst/p50")
	return "world frames: n %d, p50 %.1f ms, p95 %.1f, p99 %.1f, worst %.1f, worst/p50 %.1fx, over 16.7 ms: %d (%.0f%%) -- %s\nworld slow frames (index:ms): %s" % [
		a.size(), p50, p95, p99, worst, (worst / p50 if p50 > 0.0 else 0.0),
		over, 100.0 * over / a.size(),
		("PERF OK" if bad.is_empty() else "PERF FAIL: " + ", ".join(bad)),
		" ".join(where)]
