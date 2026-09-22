## `perf lens SECS ROUNDS`: what the LENS costs against the orthographic camera
## at the place the tour stands, for the owner's call on `rules.lock_lens`.
## 98_tour dispatches to it; kept out of 98_tour so its merges stay mechanical.
##
## Three questions, each answered against a control measured the same way in
## the same run, because wall-clock numbers on a loaded box are only honest as
## a comparison:
##   switch   the SWITCH_SECS after the lens is set, first time here (cold: the
##            deeper frustum has never been streamed) and again later (warm),
##            beside a no-op "switch" (the lens set to what it already is)
##   steady   SECS of frames in each projection, ROUNDS times, alternating
##            ortho/lens so any drift in the machine's load falls on both
##   reach    chunks held, chunks still to build, and the half extent the
##            streamer is asked for, against the `near_limit` it is capped at
## The lens is set through `CameraRig.lens` -- the setter 42_target's held Z
## uses -- without the lean's zoom and pitch glide, so this is the cost of the
## projection and the frame it shows, not of the lean.
##
## Frame intervals are wall clock between `frame_post_draw`s, so under vsync
## they come in steps of the refresh: "over 33 ms" is two refreshes missed. The
## renderer's own CPU and GPU times are printed beside them because they are not
## capped by vsync and say how near the edge a frame that made it was.
## It changes nothing and prints numbers; the verdict is the reader's.

const SWITCH_SECS := 2.0
const SETTLE_SECS := 2.0
## What a stall is, by the refresh: two missed, three missed.
const SLOW_MS := 33.3
const STALL_MS := 50.0


static func perf(tour: Node, game: Node, parts: PackedStringArray) -> bool:
	var secs := parts[2].to_float() if parts.size() > 2 else 4.0
	var rounds := parts[3].to_int() if parts.size() > 3 else 3
	var rig: CameraRig = game.get("camera")
	var view: WorldView = game.get("view")
	if rig == null or view == null:
		printerr("tour perf lens: no camera or view in this game")
		return false
	var rid := tour.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var was := rig.lens
	var where: String = "%s" % [game.get("player").get("pos")] if game.get("player") != null else "?"
	print("tour perf lens at %s (%s): near_limit %.0f, switch window %.1f s, %d rounds of %.1f s"
		% [where, RenderingServer.get_current_rendering_method(), view.near_limit, SWITCH_SECS, rounds, secs])
	rig.lens = &"ortho"
	await _wait(tour, SETTLE_SECS)
	_line("switch control (ortho -> ortho)", await _window(tour, rid, view, func() -> void: rig.lens = &"ortho", SWITCH_SECS))
	_line("switch COLD ortho -> lens", await _window(tour, rid, view, func() -> void: rig.lens = &"persp", SWITCH_SECS))
	await _wait(tour, SETTLE_SECS)
	var steady := {&"ortho": [] as Array[Dictionary], &"persp": [] as Array[Dictionary]}
	for r in rounds:
		var order: Array[StringName] = [&"ortho", &"persp"]
		if r % 2 == 1:
			order.reverse()
		for mode: StringName in order:
			rig.lens = mode
			await _wait(tour, SETTLE_SECS)
			var m := await _window(tour, rid, view, Callable(), secs)
			(steady[mode] as Array[Dictionary]).append(m)
			_line("steady %s round %d" % ["lens " if mode == &"persp" else "ortho", r + 1], m)
	rig.lens = &"ortho"
	await _wait(tour, SETTLE_SECS)
	_line("switch warm ortho -> lens", await _window(tour, rid, view, func() -> void: rig.lens = &"persp", SWITCH_SECS))
	_line("switch warm lens -> ortho", await _window(tour, rid, view, func() -> void: rig.lens = &"ortho", SWITCH_SECS))
	for r in rounds:
		var o: Dictionary = steady[&"ortho"][r]
		var p: Dictionary = steady[&"persp"][r]
		print("tour perf lens: round %d lens/ortho  median frame %.2fx  gpu %.2fx  cpu %.2fx  draw calls %.2fx  chunks %.2fx"
			% [r + 1, _ratio(p.median, o.median), _ratio(p.gpu, o.gpu), _ratio(p.cpu, o.cpu), _ratio(p.draws, o.draws), _ratio(p.chunks, o.chunks)])
	rig.lens = was
	return true


## Frames over `secs` after calling `act` (if any), with the numbers that say
## whether any of them stalled and what the streamer was doing meanwhile.
static func _window(tour: Node, rid: RID, view: WorldView, act: Callable, secs: float) -> Dictionary:
	await RenderingServer.frame_post_draw
	var chunks0 := view.chunk_count()
	if act.is_valid():
		act.call()
	var frames: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var draws: Array[float] = []
	var most_pending := 0
	var last := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < until:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		draws.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
		most_pending = maxi(most_pending, view.pending())
	var sorted := frames.duplicate()
	sorted.sort()
	var slow := 0
	var stall := 0
	for f: float in frames:
		slow += 1 if f > SLOW_MS else 0
		stall += 1 if f > STALL_MS else 0
	return {
		"n": frames.size(), "median": _at(sorted, 0.5), "p95": _at(sorted, 0.95), "p99": _at(sorted, 0.99),
		"worst": sorted.back() if not sorted.is_empty() else 0.0, "slow": slow, "stall": stall,
		"cpu": _median(cpu), "gpu": _median(gpu), "draws": _median(draws),
		"chunks0": chunks0, "chunks": view.chunk_count(), "pending": most_pending, "reach": view.view_half_extent(),
	}


static func _line(label: String, m: Dictionary) -> void:
	print("tour perf lens: %-34s %4d frames  median %5.1f  p95 %5.1f  p99 %5.1f  worst %6.1f ms  >%.0fms %d  >%.0fms %d  | cpu %.2f gpu %s  draws %.0f  chunks %d->%d (pending up to %d)  reach %.1f"
		% [label, m.n, m.median, m.p95, m.p99, m.worst, SLOW_MS, m.slow, STALL_MS, m.stall,
		m.cpu, ("%.2f" % m.gpu) if float(m.gpu) > 0.0 else "UNMEASURED", m.draws, m.chunks0, m.chunks, m.pending, m.reach])


static func _wait(tour: Node, secs: float) -> void:
	await tour.get_tree().create_timer(secs).timeout


static func _at(sorted: Array, q: float) -> float:
	if sorted.is_empty():
		return 0.0
	return float(sorted[mini(sorted.size() - 1, int(q * sorted.size()))])


static func _median(list: Array[float]) -> float:
	if list.is_empty():
		return 0.0
	var c := list.duplicate()
	c.sort()
	return c[c.size() / 2]


static func _ratio(a: float, b: float) -> float:
	return a / b if b > 0.0 else 0.0
