## `perf cost NAME SECS [VALUE]`: what one renderer setting costs the GPU, thrown
## off and on in turn inside ONE run (FoliagePerf's rounds, halves and medians),
## and put back as the game had it. A layer probe takes something out of the
## scene; this changes how the same scene is drawn, which is where the look
## trade-offs live (docs/LOOK.md: the owner rules on those, so this measures and
## changes nothing that stays).
##
## "on" is always what the game has now and "off" the cheaper alternative, so the
## difference printed is what the current setting costs over it:
##   msaa          the tier's MSAA against none
##   msaa_half     the tier's MSAA against one step down (4x against 2x)
##   shadow_half   the sun's shadow atlas at the tier's size against half of it
##   ssao, ssil    the Environment's ambient occlusion / indirect light against none
##   volumetric    volumetric air against none
##   dof           the near depth of field against none
##   scale         the tier's render scale against VALUE (default 0.85)
##   omni_mode     every omni's shadow drawn the way it is now against the other way
##                 (a cube is six views, the engine's default; dual paraboloid two)
##   stand_in_lights  01_warm_lights' black omni, spot and directional shown against
##                 hidden (FoliagePerf `stand_ins` only takes them off the
##                 geometry's mask, which leaves them in the light clusters)
## Lights and settings another system writes every frame are not offered: the
## switch would be undone between the halves.

const NAMES: Array[String] = ["msaa", "msaa_half", "shadow_half", "ssao", "ssil", "volumetric", "dof",
	"scale", "omni_mode", "stand_in_lights"]


static func perf(tour: Node, game: Node, parts: PackedStringArray) -> bool:
	var name := parts[2] if parts.size() > 2 else ""
	if not name in NAMES:
		printerr("tour perf cost: one of %s" % ", ".join(NAMES))
		return false
	var secs := parts[3].to_float() if parts.size() > 3 else 6.0
	var value := parts[4].to_float() if parts.size() > 4 else 0.85
	var flip := _switch(tour, game, name, value)
	if flip.is_null():
		printerr("tour perf cost %s: nothing here to switch" % name)
		return false
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Each way drawn before the rounds: a first draw in a new state may build a
	# pipeline, and that is a different question (01_warm_lights').
	for prime in 2:
		flip.call(prime == 1)
		for f in 8:
			await RenderingServer.frame_post_draw
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var prims: Array[float] = []
	var with: Dictionary = {}
	var without: Dictionary = {}
	for k in FoliagePerf.ROUNDS:
		flip.call(false)
		without = await FoliagePerf._measure(tour, secs / float(FoliagePerf.ROUNDS * 2))
		flip.call(true)
		with = await FoliagePerf._measure(tour, secs / float(FoliagePerf.ROUNDS * 2))
		gpu.append(with.gpu - without.gpu)
		cpu.append(with.cpu - without.cpu)
		prims.append(with.prims - without.prims)
	DisplayServer.window_set_vsync_mode(vsync)
	var gpu_line := "gpu %.2f -> %.2f ms (%+.2f)" % [without.gpu, with.gpu, FoliagePerf._median(gpu)] if float(with.gpu) > 0.0 \
		else "gpu UNMEASURED (no gpu timer here)"
	print("tour perf cost %s: %s tier, %s: %s, render cpu %.2f -> %.2f ms (%+.2f), primitives %.0f -> %.0f (%+.0f)"
		% [name, Quality.current_id(), RenderingServer.get_current_rendering_method(), gpu_line,
			without.cpu, with.cpu, FoliagePerf._median(cpu), without.prims, with.prims, FoliagePerf._median(prims)])
	return true


## The setting as a switch: `call(true)` is what the game had, `call(false)` the
## cheaper alternative. Null when there is nothing of it here.
static func _switch(tour: Node, game: Node, name: String, value: float) -> Callable:
	var vp := tour.get_viewport()
	var sky: SkyLight = game.get("sky")
	var e: Environment = sky.env.environment if sky != null and sky.env != null else null
	var cam := vp.get_camera_3d()
	var q := Quality.current()
	match name:
		"msaa":
			var had := vp.msaa_3d
			return func(on: bool) -> void: vp.msaa_3d = had if on else Viewport.MSAA_DISABLED
		"msaa_half":
			var had := vp.msaa_3d
			if had == Viewport.MSAA_DISABLED:
				return Callable()
			return func(on: bool) -> void: vp.msaa_3d = had if on else (int(had) - 1) as Viewport.MSAA
		"shadow_half":
			var size := int(q.shadow_size)
			return func(on: bool) -> void: RenderingServer.directional_shadow_atlas_set_size(size if on else size / 2, true)
		"ssao":
			if e == null or not e.ssao_enabled:
				return Callable()
			return func(on: bool) -> void: e.ssao_enabled = on
		"ssil":
			if e == null or not e.ssil_enabled:
				return Callable()
			return func(on: bool) -> void: e.ssil_enabled = on
		"volumetric":
			if e == null or not e.volumetric_fog_enabled:
				return Callable()
			return func(on: bool) -> void: e.volumetric_fog_enabled = on
		"dof":
			var a := cam.attributes as CameraAttributesPractical if cam != null else null
			if a == null or not a.dof_blur_near_enabled:
				return Callable()
			return func(on: bool) -> void: a.dof_blur_near_enabled = on
		"scale":
			var had := vp.scaling_3d_scale
			return func(on: bool) -> void: vp.scaling_3d_scale = had if on else value
		"omni_mode":
			var omnis: Array[OmniLight3D] = []
			for n: Node in game.find_children("*", "OmniLight3D", true, false):
				var o := n as OmniLight3D
				if o.light_color != Color.BLACK:
					omnis.append(o)
			if omnis.is_empty():
				return Callable()
			var had := omnis[0].omni_shadow_mode
			var other := OmniLight3D.SHADOW_CUBE if had == OmniLight3D.SHADOW_DUAL_PARABOLOID else OmniLight3D.SHADOW_DUAL_PARABOLOID
			print("tour perf cost omni_mode: on is %s, off is %s, over %d omnis" % [
				"cube" if had == OmniLight3D.SHADOW_CUBE else "dual paraboloid",
				"cube" if other == OmniLight3D.SHADOW_CUBE else "dual paraboloid", omnis.size()])
			return func(on: bool) -> void:
				for o in omnis:
					if is_instance_valid(o):
						o.omni_shadow_mode = had if on else other
		"stand_in_lights":
			var black: Array[Light3D] = []
			for n: Node in game.find_children("*", "Light3D", true, false):
				if (n as Light3D).light_color == Color.BLACK and (n as Light3D).visible:
					black.append(n as Light3D)
			if black.is_empty():
				return Callable()
			return func(on: bool) -> void:
				for l in black:
					l.visible = on
	return Callable()
