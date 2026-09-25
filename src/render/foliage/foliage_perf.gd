class_name FoliagePerf
extends RefCounted
## What the leaves -- or the grass -- cost, measured inside ONE run (docs/LOOK.md, "measure a layer
## by toggling it inside one run"), the way ForePerf measures the foreground.
##
## `--stats` fps came back at 83 and 63 for one identical command on this machine,
## so nothing here is taken across two runs. Every chunk's `props_leaf` surface is
## hidden and shown in turn, ROUNDS times each, and the MIDDLE of the differences
## decides. A hidden MeshInstance3D neither draws nor casts, so hiding is an
## honest OFF: the same scene, world, camera and frame, less the leaves.
##
## FOLIAGE IS OVERDRAW, and overdraw lands on the GPU, not on draw submission. So
## four halves are reported and they say different things:
##   cpu    render CPU: culling and submission. A chunk's cards are one draw.
##   gpu    the GPU timer. **Metal through MoltenVK does not answer it on this
##          machine**, so when it returns nothing the line says UNMEASURED and
##          never 0.00 ms, which is a number nobody clocked.
##   frame  wall time between two frames with vsync OFF and the GPU made to
##          FINISH every frame before the next is begun (a readback of the frame
##          does it). Not a GPU timer: the readback costs the same on both sides
##          and cancels in the difference, and what is left includes the fill a
##          card costs, which submission time alone never does.
##   draws, primitives  what the renderer was actually handed.

const ROUNDS := 5
## The chunk children each layer toggles: `foliage` the leaf cards, `decor` all
## of Decor (its stones and litter, and its grass), `grass` only what sways.
## `noise` toggles nothing: the same pairs of halves with no change between
## them, which is the floor any other layer's difference has to clear on this
## machine at this load.
## `meadow` is the eye-level meadow ring (18_meadow), and `sward` all the grass:
## the ring and every chunk's.
const LAYERS := {"foliage": ["props_leaf"], "decor": ["decor", "grass", "grass_cast"], "grass": ["grass", "grass_cast"],
	"meadow": [], "sward": ["grass", "grass_cast"], "noise": []}


## `perf foliage|decor SECS [MS]`: the cost of that layer in every loaded chunk
## over SECS of frames. Fails only if nothing was there to measure, or if the
## render CPU cost is over MS (default: no budget, it is a measurement).
## At eye level decor stops at `WorldView.DECOR_TO` by visibility range, so a
## chunk past it costs nothing on either side and the difference is honest.
static func perf(tour: Node, game: Node, parts: PackedStringArray) -> bool:
	var layer := parts[1] if parts.size() > 1 and LAYERS.has(parts[1]) else "foliage"
	var secs := parts[2].to_float() if parts.size() > 2 else 3.0
	var max_ms := parts[3].to_float() if parts.size() > 3 else INF
	var view: WorldView = game.get("view")
	if view == null:
		printerr("tour perf %s: no world view" % layer)
		return false
	var leaves := nodes(game, layer)
	for m in leaves:
		if m is MeadowView:
			var ring := m as MeadowView
			print("tour meadow: reach %.0f density %.2f, %d plants in %d draws" % [ring.reach, ring.density, ring.plants, ring.draws])
	if leaves.is_empty() and layer != "noise":
		printerr("tour perf %s: nothing of it is loaded to measure" % layer)
		return false
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var frame: Array[float] = []
	var draws: Array[float] = []
	var prims: Array[float] = []
	var with: Dictionary = {}
	var without: Dictionary = {}
	for k in ROUNDS:
		for m in leaves:
			m.visible = false
		without = await _measure(tour, secs / float(ROUNDS * 2))
		for m in leaves:
			m.visible = true
		with = await _measure(tour, secs / float(ROUNDS * 2))
		cpu.append(with.cpu - without.cpu)
		gpu.append(with.gpu - without.gpu)
		frame.append(with.frame - without.frame)
		draws.append(with.draws - without.draws)
		prims.append(with.prims - without.prims)
	DisplayServer.window_set_vsync_mode(vsync)
	var ms := _median(cpu)
	var gpu_line := "gpu %.2f ms" % _median(gpu) if float(with.gpu) > 0.0 else "gpu UNMEASURED (no gpu timer here)"
	print(("tour perf %s: %s tier, %s, %d meshes of it: render cpu %.2f -> %.2f ms (%+.2f), %s, "
		+ "frame %.2f -> %.2f ms (%+.2f, vsync off, GPU finished each frame), "
		+ "draw calls %.0f -> %.0f (%+.0f), primitives %.0f -> %.0f (%+.0f)")
		% [layer, Quality.current_id(), RenderingServer.get_current_rendering_method(), leaves.size(),
			without.cpu, with.cpu, ms, gpu_line, without.frame, with.frame, _median(frame),
			without.draws, with.draws, _median(draws), without.prims, with.prims, _median(prims)])
	if ms > max_ms:
		printerr("tour perf %s: %.2f ms of render cpu, budget %.2f" % [layer, ms, max_ms])
		return false
	return true


## What `layer` toggles, loaded and shown now.
static func nodes(game: Node, layer: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var view: WorldView = game.get("view")
	for chunk: Node in view.get_children():
		for part: String in LAYERS[layer]:
			var m := chunk.get_node_or_null(part) as Node3D
			if m != null and m.visible:
				out.append(m)
	if layer == "meadow" or layer == "sward":
		for sys: Node in game.get("systems"):
			var ring: Variant = sys.get(&"meadow")
			if ring is MeadowView and (ring as MeadowView).visible:
				out.append(ring)
	return out


## Medians over SECS of frames.
static func _measure(tour: Node, secs: float) -> Dictionary:
	var vp := tour.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var until := Time.get_ticks_msec() + int(secs * 1000.0)
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var frame: Array[float] = []
	var draws: Array[float] = []
	var prims: Array[float] = []
	var last := Time.get_ticks_usec()
	while Time.get_ticks_msec() < until:
		await RenderingServer.frame_post_draw
		# Blocks until the GPU has drawn this frame, so its fill is in the clock.
		tour.get_viewport().get_texture().get_image()
		var now := Time.get_ticks_usec()
		frame.append((now - last) / 1000.0)
		last = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	return {"cpu": _median(cpu), "gpu": _median(gpu), "frame": _median(frame), "draws": _median(draws), "prims": _median(prims)}


static func _median(list: Array[float]) -> float:
	if list.is_empty():
		return 0.0
	list.sort()
	return list[list.size() / 2]
