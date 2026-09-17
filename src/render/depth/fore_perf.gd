class_name ForePerf
extends RefCounted
## What the foreground layer costs, measured the way this repository already
## measures a crowd (`src/systems/tour/tour_people.gd`) and for the same reason.
##
## WHY NOT `--stats` AND ITS FPS. Because it lies under load, and this machine is
## never not under load: two runs of one identical command, back to back, came
## back at 83 and 63 fps. A number that moves 30% between two runs of the same
## thing cannot tell anyone what a bough costs.
##
## So the layer is SHOWN and HIDDEN inside one run, three times each, and the
## MIDDLE of the three differences decides. Anything else the machine is doing
## moves both sides alike, and the median throws away the hitch. A whole frame's
## process time swings by more than this layer costs whenever anything else in
## the game runs, so what is judged is the difference and never the total.
##
## BOTH HALVES ARE REPORTED, because for this package they say different things.
## The CPU side is culling and draw submission, and twenty shared meshes barely
## touch it. The GPU side is the one the layer's cost actually lands on and the
## one worth knowing: a foreground piece is OVERDRAW -- every needle is shaded
## over ground that was already shaded, and it is drawn twice, once for the
## picture and once into the sun's shadow map.
##
## **The GPU timer returns zero on this machine** (Metal through MoltenVK does
## not answer `viewport_get_measured_render_time_gpu`), so the fill cost is
## reported as unmeasured rather than as nought. Saying "0.00 ms of fill" when
## the clock is not running is worse than saying nothing: it is a number the
## next person would believe.
##
## A hidden MeshInstance3D neither draws nor casts, so hiding is an honest OFF:
## it is the same scene, the same world, the same camera, the same frame.

## How many times each side is measured. Three, as the crowd's is.
const ROUNDS := 3


## `perf fore SECS DRAWS MS`: the layer's cost over SECS of frames, failing if it
## is over the budget. Returns whether it passed.
static func perf(tour: Node, game: Node, parts: PackedStringArray) -> bool:
	var secs := parts[2].to_float() if parts.size() > 2 else 3.0
	var max_draws := parts[3].to_float() if parts.size() > 3 else 40.0
	var max_ms := parts[4].to_float() if parts.size() > 4 else 3.0
	var view: ForeView = null
	for s: Node in game.get("systems"):
		if s.get("view") is ForeView:
			view = s.get("view")
			break
	if view == null or view.drawn <= 0:
		printerr("tour perf fore: nothing is hung over this frame to measure")
		return false
	var pieces: Array[MeshInstance3D] = []
	for i in view.drawn:
		var m := view.get_child(i) as MeshInstance3D
		if m != null and m.visible:
			pieces.append(m)
	var n := pieces.size()
	if n <= 0:
		printerr("tour perf fore: the layer says %d pieces and none are visible" % view.drawn)
		return false
	var with := Vector4.ZERO
	var without := Vector4.ZERO
	var cpu_diffs: Array[float] = []
	var gpu_diffs: Array[float] = []
	var draw_diffs: Array[float] = []
	for k in ROUNDS:
		for m in pieces:
			m.visible = false
		without = await _measure(tour, secs / float(ROUNDS * 2))
		for m in pieces:
			m.visible = true
		with = await _measure(tour, secs / float(ROUNDS * 2))
		cpu_diffs.append(with.z - without.z)
		gpu_diffs.append(with.w - without.w)
		draw_diffs.append(with.y - without.y)
	var ms := _median(cpu_diffs)
	var gpu := _median(gpu_diffs)
	var draws := _median(draw_diffs)
	var fill := "%.2f ms of fill" % gpu if with.w > 0.0 else "fill UNMEASURED (no gpu timer here)"
	print("tour perf fore: %d pieces over the frame: render cpu %.2f -> %.2f ms (whole frame %.1f -> %.1f ms), draw calls %.0f -> %.0f; the layer costs %.2f ms of cpu, %s, %.0f draw calls"
		% [n, without.z, with.z, without.x, with.x, without.y, with.y, ms, fill, draws])
	if draws > max_draws:
		printerr("tour perf fore: %.0f draw calls, budget %.0f" % [draws, max_draws])
		return false
	if ms > max_ms:
		printerr("tour perf fore: %.2f ms, budget %.2f" % [ms, max_ms])
		return false
	return true


## Median over SECS of frames: x ms of process and render CPU, y draw calls,
## z render CPU alone, w GPU. Same shape and reasoning as TourPeople's, plus the
## GPU, which is where a layer of overdraw actually lands.
static func _measure(tour: Node, secs: float) -> Vector4:
	var vp := tour.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await RenderingServer.frame_post_draw
	var until := Time.get_ticks_msec() + int(secs * 1000.0)
	var ms: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var draws: Array[float] = []
	while Time.get_ticks_msec() < until:
		await RenderingServer.frame_post_draw
		var r := RenderingServer.viewport_get_measured_render_time_cpu(vp)
		ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 + r)
		cpu.append(r)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	return Vector4(_median(ms), _median(draws), _median(cpu), _median(gpu))


static func _median(list: Array[float]) -> float:
	if list.is_empty():
		return 0.0
	list.sort()
	return list[list.size() / 2]
