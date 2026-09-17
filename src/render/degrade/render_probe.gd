class_name RenderProbe
extends RefCounted
## What THIS renderer actually does, asked by rendering and never from memory
## (docs/LOOK.md, "Web is the graceful degradation path").
##
## Godot's Compatibility renderer has gained features release to release, so a
## table of what it "has" written from recollection is wrong in a way nobody can
## see. These measurements are played by tours, on the desktop and inside a real
## exported web build (`tools/web.sh --tour=`), and the two logs side by side are
## the table (docs/LOOK.md holds what they said on 4.7.2):
##
##   perf colour            what the renderer does to a value written into ALBEDO,
##                          on a flat unshaded quad, under the game's own pipeline
##                          and under a bare one. The colour door (`sky_linear`,
##                          matter.gdshaderinc) is only as right as this answer.
##   perf features NAME     every expensive thing the desktop frame has, switched
##                          off and on again with the world held still: whether
##                          the frame moves at all, against the noise of the same
##                          switch thrown off twice. A feature that does not move
##                          the frame does not exist here. `frames` keeps both.
##   perf shadowpass        what turning the sun's shadow on does to the frame's
##                          brightness, under bases that each take one thing away
##   perf sunpath           the same on a lit quad with one thing at a time on it:
##                          which light the casting pass counts again
##   perf match REF [sweep[=KEY,..] | ROW;ROW]
##                          the frame against the desktop's frame of the same
##                          moment, and the fit of CompatTrim that walks each
##                          number to where they differ least
##   perf scale LIST SECS   the frame's cost at each render scale in LIST, taken
##                          in turn inside one run, three rounds, median of each
##   perf slate             the slate's bakes and textures on this build, and
##                          whether a bake handed to the WorkerThreadPool holds
##                          this thread (it does, on a build with no threads)
##
## Tours: degrade.tour (colour, features), degrade_cost.tour (scale, slate),
## degrade_fit.tour and degrade_grey.tour (the fit).
##
## Every number is printed with what it was measured against. A clock that did
## not run is printed as UNMEASURED and never as 0.00 (LOOK.md, method 3).

## How many frames a change is given to reach the picture before it is read.
## Glow and the shadow atlas take a frame or two to settle; four is safe on both.
const SETTLE := 4
## Rounds of each render scale. Three, as the crowd's and the fore layer's are.
const ROUNDS := 3
## A feature that moves the frame by less than this over the noise floor is not
## there. Mean absolute channel difference, 0..255.
const THERE := 0.08
## What `perf KIND` this file answers (98_tour dispatches on it).
const KINDS: Array[String] = ["colour", "features", "scale", "shadowpass", "sunpath", "match", "slate"]
## The value the colour probe writes: the one the lit package measured with.
const PROBE := Vector3(0.5, 0.25, 0.125)


static func run(tour: Node, game: Node, parts: PackedStringArray) -> bool:
	match parts[1]:
		"colour":
			return await colour(tour, game)
		"features":
			return await features(tour, game, parts[2] if parts.size() > 2 else "here", parts.size() > 3 and parts[3] == "frames")
		"scale":
			return await scale_curve(tour, parts)
		"shadowpass":
			return await shadow_pass(tour, game)
		"sunpath":
			return await sun_path(tour, game)
		"match":
			return await match_frame(tour, game, parts)
		"slate":
			return await slate_cost(tour)
	printerr("tour perf %s: no such measurement (%s)" % [parts[1], ", ".join(KINDS)])
	return false


static func _renderer() -> String:
	return "forward_plus" if Quality.forward_plus() else "gl_compatibility"


static func _grab(tour: Node, settle: int = SETTLE) -> Image:
	for i in settle:
		await _drawn(tour)
	var img := tour.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


## One drawn frame. A window nobody can see is not always asked to draw (macOS
## stops asking an occluded one), and the world is held still here, so after a
## quarter of a second without one it is drawn by hand, as the tour's own
## shutter does (98_tour `_drawn`). Without this a held world waited forever.
static func _drawn(tour: Node) -> void:
	var seen := [false]
	var mark := func() -> void: seen[0] = true
	RenderingServer.frame_post_draw.connect(mark, CONNECT_ONE_SHOT)
	var nudge := Time.get_ticks_msec() + 250
	while not seen[0]:
		await tour.get_tree().process_frame
		if not seen[0] and Time.get_ticks_msec() >= nudge:
			RenderingServer.force_draw(false)
			nudge = Time.get_ticks_msec() + 250
	if RenderingServer.frame_post_draw.is_connected(mark):
		RenderingServer.frame_post_draw.disconnect(mark)


## Mean absolute channel difference, 0..255, every fourth pixel each way.
static func differ(a: Image, b: Image) -> float:
	if a == null or b == null or a.get_size() != b.get_size():
		return 255.0
	var da := a.get_data()
	var db := b.get_data()
	var w := a.get_width()
	var h := a.get_height()
	var total := 0
	var n := 0
	for y in range(0, h, 4):
		var row := y * w * 3
		for x in range(0, w, 4):
			var i := row + x * 3
			total += absi(da[i] - db[i]) + absi(da[i + 1] - db[i + 1]) + absi(da[i + 2] - db[i + 2])
			n += 3
	return float(total) / maxf(1.0, float(n))


## Mean luma, 0..255, every fourth pixel each way.
static func luma(img: Image) -> float:
	var d := img.get_data()
	var w := img.get_width()
	var total := 0.0
	var n := 0
	for y in range(0, img.get_height(), 4):
		var row := y * w * 3
		for x in range(0, w, 4):
			var i := row + x * 3
			total += 0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2]
			n += 1
	return total / maxf(1.0, float(n))


## The median of (b - a) in luma over every fourth pixel: what most of the frame
## did, which a small region that changed a lot (a shadow) cannot move.
static func median_luma_difference(a: Image, b: Image) -> float:
	var da := a.get_data()
	var db := b.get_data()
	var w := a.get_width()
	var hist := PackedInt32Array()
	hist.resize(511)
	var n := 0
	for y in range(0, a.get_height(), 4):
		var row := y * w * 3
		for x in range(0, w, 4):
			var i := row + x * 3
			var la := 0.2126 * da[i] + 0.7152 * da[i + 1] + 0.0722 * da[i + 2]
			var lb := 0.2126 * db[i] + 0.7152 * db[i + 1] + 0.0722 * db[i + 2]
			hist[clampi(int(round(lb - la)) + 255, 0, 510)] += 1
			n += 1
	var seen := 0
	for v in 511:
		seen += hist[v]
		if seen * 2 >= n:
			return float(v - 255)
	return 0.0


## Keep a frame the way the tour keeps its shots: a file beside them from source,
## a download the harness keeps on the web.
static func _keep(tour: Node, name: String, img: Image) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), name + ".png", "image/png")
		return
	var out: String = tour.get("_out")
	img.save_png(out.path_join(name + ".png"))


static func _srgb(c: float) -> float:
	return c * 12.92 if c <= 0.0031308 else 1.055 * pow(c, 1.0 / 2.4) - 0.055


# ---- colour ---------------------------------------------------------------

## A flat unshaded quad over the whole frame with PROBE written straight into
## ALBEDO, read back off the viewport, under four pipelines: bare (no tonemap,
## glow, adjustments or fog), bare plus glow, bare plus adjustments, and bare at
## a render scale of 1. Compatibility renders to an intermediate buffer for some
## of these and not others, and the answer may differ between them.
static func colour(tour: Node, game: Node) -> bool:
	var cam := tour.get_viewport().get_camera_3d()
	var sky: SkyLight = game.get("sky")
	if cam == null or sky == null or sky.env == null:
		printerr("tour perf colour: no camera or no sky to measure under")
		return false
	var tree := tour.get_tree()
	var was_paused := tree.paused
	tree.paused = true
	var e := sky.env.environment
	var keep := _env_state(e)
	var vp := tour.get_viewport()
	var scale_was := vp.scaling_3d_scale
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(cam.size * 8.0, cam.size * 8.0)
	quad.mesh = mesh
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, fog_disabled, cull_disabled, shadows_disabled;\nuniform vec3 c;\nvoid fragment() { ALBEDO = c; }\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("c", PROBE)
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.extra_cull_margin = 16384.0
	cam.add_child(quad)
	quad.position = Vector3(0.0, 0.0, -(cam.near + 0.02))
	var enc := Vector3(_srgb(PROBE.x), _srgb(PROBE.y), _srgb(PROBE.z))
	var answers: Array[String] = []
	for stage: String in ["bare", "bare+glow", "bare+adjust", "bare@scale1", "game"]:
		_env_restore(e, keep)
		vp.scaling_3d_scale = scale_was
		if stage != "game":
			e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			e.tonemap_exposure = 1.0
			e.tonemap_white = 1.0
			e.glow_enabled = stage == "bare+glow"
			e.adjustment_enabled = stage == "bare+adjust"
			if stage == "bare+adjust":
				e.adjustment_brightness = 1.0
				e.adjustment_contrast = 1.0
				e.adjustment_saturation = 1.0
			e.fog_enabled = false
			e.volumetric_fog_enabled = false
			e.ssao_enabled = false
			e.ssil_enabled = false
		if stage == "bare@scale1":
			vp.scaling_3d_scale = 1.0
		var img: Image = await _grab(tour, SETTLE + 2)
		var got := _patch(img, Vector2(0.27, 0.46))
		var what := "other"
		if (got - PROBE).abs().x < 0.02 and (got - PROBE).abs().y < 0.02 and (got - PROBE).abs().z < 0.02:
			what = "IDENTITY"
		elif (got - enc).abs().x < 0.02 and (got - enc).abs().y < 0.02 and (got - enc).abs().z < 0.02:
			what = "ENCODES"
		answers.append("%s %s" % [stage, what])
		print("tour perf colour (%s, scale %.2f): %-12s ALBEDO %.3f,%.3f,%.3f -> %.3f,%.3f,%.3f  (%s; linear_to_srgb would be %.3f,%.3f,%.3f)"
			% [_renderer(), vp.scaling_3d_scale, stage, PROBE.x, PROBE.y, PROBE.z, got.x, got.y, got.z, what, enc.x, enc.y, enc.z])
	quad.queue_free()
	_env_restore(e, keep)
	vp.scaling_3d_scale = scale_was
	tree.paused = was_paused
	# sky_linear cannot be read back outside the editor; SkyLight writes it from this.
	print("tour perf colour (%s): %s; the colour door decodes here: %s" % [_renderer(), ", ".join(answers),
		SkyLight.decodes()])
	return true


## The median colour of a 17x17 patch centred at `at` (0..1 of the frame).
static func _patch(img: Image, at: Vector2) -> Vector3:
	var cx := int(at.x * img.get_width())
	var cy := int(at.y * img.get_height())
	var rs: Array[float] = []
	var gs: Array[float] = []
	var bs: Array[float] = []
	for y in range(cy - 8, cy + 9):
		for x in range(cx - 8, cx + 9):
			var c := img.get_pixel(x, y)
			rs.append(c.r)
			gs.append(c.g)
			bs.append(c.b)
	return Vector3(_median(rs), _median(gs), _median(bs))


const ENV_KEYS: Array[String] = ["tonemap_mode", "tonemap_exposure", "tonemap_white", "glow_enabled",
	"adjustment_enabled", "adjustment_brightness", "adjustment_contrast", "adjustment_saturation",
	"fog_enabled", "volumetric_fog_enabled", "ssao_enabled", "ssil_enabled", "reflected_light_source",
	"ambient_light_energy"]


static func _env_state(e: Environment) -> Dictionary:
	var out := {}
	for k in ENV_KEYS:
		out[k] = e.get(k)
	return out


static func _env_restore(e: Environment, state: Dictionary) -> void:
	for k: String in state:
		e.set(k, state[k])


# ---- features -------------------------------------------------------------

## Each row: a name and a Callable(on: bool) that switches one thing. Built
## against the live game, so what is switched is what the frame really has.
static func _switches(tour: Node, game: Node) -> Array[Array]:
	var sky: SkyLight = game.get("sky")
	var e := sky.env.environment
	var cam := tour.get_viewport().get_camera_3d()
	var vp := tour.get_viewport()
	var lights_sys: Node = null
	var fore: Node3D = null
	for s: Node in game.get("systems"):
		if s.get("lantern_light") is OmniLight3D:
			lights_sys = s
		if s.get("view") is ForeView:
			fore = s.get("view")
	var out: Array[Array] = []
	out.append(["sun shadow", func(on: bool) -> void: sky.sun.shadow_enabled = on])
	out.append(["sun penumbra (angular size 3.2 vs 0)", func(on: bool) -> void:
		sky.sun.light_angular_distance = 3.2 if on else 0.0])
	out.append(["soft shadow filter (ultra vs hard)", func(on: bool) -> void:
		RenderingServer.directional_soft_shadow_filter_set_quality(
			RenderingServer.SHADOW_QUALITY_SOFT_ULTRA if on else RenderingServer.SHADOW_QUALITY_HARD)
		RenderingServer.positional_soft_shadow_filter_set_quality(
			RenderingServer.SHADOW_QUALITY_SOFT_ULTRA if on else RenderingServer.SHADOW_QUALITY_HARD)])
	out.append(["shadow opacity (1.0 vs 0.3)", func(on: bool) -> void:
		sky.sun.shadow_opacity = 1.0 if on else 0.3])
	if lights_sys != null:
		var ll: OmniLight3D = lights_sys.get("lantern_light")
		out.append(["local lights (all shown vs hidden)", func(on: bool) -> void:
			for l: OmniLight3D in lights_sys.get("lights"):
				l.set_meta(&"probe_vis", l.get_meta(&"probe_vis", l.visible))
				l.visible = bool(l.get_meta(&"probe_vis")) if on else false
			ll.set_meta(&"probe_vis", ll.get_meta(&"probe_vis", ll.visible))
			ll.visible = bool(ll.get_meta(&"probe_vis")) if on else false])
		out.append(["local light shadows (every shown light casts vs none)", func(on: bool) -> void:
			for l: OmniLight3D in lights_sys.get("lights"):
				l.shadow_enabled = on
			ll.shadow_enabled = on])
	out.append(["volumetric fog", func(on: bool) -> void:
		e.volumetric_fog_enabled = on
		if on:
			e.volumetric_fog_density = maxf(e.volumetric_fog_density, SkyLight.VOLUME_DENSITY * 2.0)])
	out.append(["depth fog", func(on: bool) -> void: e.fog_enabled = on])
	out.append(["glow / bloom", func(on: bool) -> void: e.glow_enabled = on])
	out.append(["tonemapper (filmic vs linear)", func(on: bool) -> void:
		e.tonemap_mode = SkyLight.TONEMAP if on else Environment.TONE_MAPPER_LINEAR])
	out.append(["adjustments (the grade)", func(on: bool) -> void:
		e.adjustment_enabled = on
		e.adjustment_brightness = 0.8 if on else 1.0
		e.adjustment_contrast = 1.2 if on else 1.0])
	out.append(["SSAO", func(on: bool) -> void:
		e.ssao_enabled = on
		e.ssao_intensity = 4.0])
	out.append(["SSIL", func(on: bool) -> void:
		e.ssil_enabled = on
		e.ssil_intensity = 2.0])
	out.append(["sky reflections (sky vs none)", func(on: bool) -> void:
		e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if on else Environment.REFLECTION_SOURCE_DISABLED])
	out.append(["near depth of field", func(on: bool) -> void:
		if on:
			var a := CameraAttributesPractical.new()
			a.auto_exposure_enabled = false
			a.dof_blur_near_enabled = true
			a.dof_blur_near_distance = 60.0
			a.dof_blur_near_transition = 30.0
			a.dof_blur_amount = 0.3
			cam.attributes = a
		else:
			cam.attributes = null])
	out.append(["MSAA 4x", func(on: bool) -> void:
		vp.msaa_3d = Viewport.MSAA_4X if on else Viewport.MSAA_DISABLED])
	# Compatibility refuses this one out loud (a warning, which a web run counts
	# as a console error), so it is not thrown there: the refusal is the answer.
	out.append(["screen-space AA (FXAA)", func(on: bool) -> void:
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if on else Viewport.SCREEN_SPACE_AA_DISABLED,
		Quality.forward_plus()])
	var shafts := cam.get_node_or_null("shaft_pass") as MeshInstance3D
	if shafts != null:
		out.append(["screen-space shafts (the web pass)", func(on: bool) -> void: shafts.visible = on])
	if fore != null:
		out.append(["foreground layer", func(on: bool) -> void:
			for c: Node in fore.get_children():
				if c is MeshInstance3D:
					(c as MeshInstance3D).set_meta(&"probe_vis", c.get_meta(&"probe_vis", (c as MeshInstance3D).visible))
					(c as MeshInstance3D).visible = bool(c.get_meta(&"probe_vis")) if on else false])
	return out


## Switch every feature off and on with the world held still. The noise floor is
## two frames with nothing switched (TIME still runs in the water and the sway,
## and paused or not, a shader's clock does not stop).
static func features(tour: Node, game: Node, label: String, keep_frames: bool = false) -> bool:
	var sky: SkyLight = game.get("sky")
	if sky == null or sky.env == null:
		printerr("tour perf features: no sky")
		return false
	var tree := tour.get_tree()
	var was_paused := tree.paused
	tree.paused = true
	var e := sky.env.environment
	var keep := _env_state(e)
	keep["volumetric_fog_density"] = e.volumetric_fog_density
	keep["ssao_intensity"] = e.ssao_intensity
	keep["ssil_intensity"] = e.ssil_intensity
	var vp := tour.get_viewport()
	var cam := vp.get_camera_3d()
	var keep_sun := [sky.sun.shadow_enabled, sky.sun.light_angular_distance, sky.sun.shadow_opacity]
	var keep_vp := [vp.msaa_3d, vp.screen_space_aa if Quality.forward_plus() else 0]
	var keep_attr := cam.attributes
	var q := Quality.current()
	var a: Image = await _grab(tour)
	var b: Image = await _grab(tour)
	var noise := differ(a, b)
	print("tour perf features %s (%s, quality %s): noise floor %.3f (two frames, nothing switched)"
		% [label, _renderer(), Quality.current_id(), noise])
	var there: Array[String] = []
	var absent: Array[String] = []
	for row: Array in _switches(tour, game):
		var name: String = row[0]
		var flip: Callable = row[1]
		if row.size() > 2 and not bool(row[2]):
			absent.append(name)
			print("tour perf features %s: %-52s not offered by this renderer (the engine refuses it)" % [label, name])
			continue
		flip.call(false)
		var off: Image = await _grab(tour)
		flip.call(true)
		var on: Image = await _grab(tour)
		flip.call(false)
		var off2: Image = await _grab(tour)
		# The noise HERE: the same switch thrown off twice. A shader's clock runs
		# while the world is held, and at night the lamp's flame and the rain do
		# not stand still, so one floor for the whole run undercounts it.
		var here := maxf(noise, differ(off, off2))
		var d := differ(off, on)
		var real := d > here * 2.0 + THERE
		(there if real else absent).append(name)
		print("tour perf features %s: %-52s off/on differ by %6.3f (noise %.3f), luma %6.2f -> %6.2f  -> %s"
			% [label, name, d, here, luma(off), luma(on), "CHANGES THE FRAME" if real else "no change"])
		if keep_frames:
			var slug := name.get_slice(" (", 0).replace(" / ", "-").replace(" ", "-").to_lower()
			_keep(tour, "probe-%s-%s-off" % [label, slug], off)
			_keep(tour, "probe-%s-%s-on" % [label, slug], on)
		# Back to what the game had, not to "on": the game may have had it off.
		_env_restore(e, keep)
		sky.sun.shadow_enabled = keep_sun[0]
		sky.sun.light_angular_distance = keep_sun[1]
		sky.sun.shadow_opacity = keep_sun[2]
		vp.msaa_3d = keep_vp[0]
		if Quality.forward_plus():
			vp.screen_space_aa = keep_vp[1]
		cam.attributes = keep_attr
		RenderingServer.directional_soft_shadow_filter_set_quality(int(q.shadow_filter) as RenderingServer.ShadowQuality)
		RenderingServer.positional_soft_shadow_filter_set_quality(int(q.shadow_filter) as RenderingServer.ShadowQuality)
	# The lights and the fore layer put back their own visibility.
	for row: Array in _switches(tour, game):
		if String(row[0]).begins_with("local lights") or String(row[0]) == "foreground layer":
			(row[1] as Callable).call(true)
	_clear_marks(game)
	# The lights system decides which lights cast every frame; it takes that back
	# once the world runs again.
	tree.paused = was_paused
	print("tour perf features %s (%s): changes the frame: %s" % [label, _renderer(), ", ".join(there)])
	print("tour perf features %s (%s): no change: %s" % [label, _renderer(), ", ".join(absent) if not absent.is_empty() else "none"])
	return true


static func _clear_marks(game: Node) -> void:
	for s: Node in game.get("systems"):
		var lights: Variant = s.get("lights")
		if lights is Array:
			for l: Variant in lights:
				if l is Node and (l as Node).has_meta(&"probe_vis"):
					(l as Node).remove_meta(&"probe_vis")
		var ll: Variant = s.get("lantern_light")
		if ll is Node and (ll as Node).has_meta(&"probe_vis"):
			(ll as Node).remove_meta(&"probe_vis")
		var v: Variant = s.get("view")
		if v is ForeView:
			for c: Node in (v as Node).get_children():
				if c.has_meta(&"probe_vis"):
					c.remove_meta(&"probe_vis")


# ---- the sun's shadow pass -------------------------------------------------

## Compose the sky with CompatTrim held at `row` (or let go when empty), so a
## measurement sees the renderer's own light, or a candidate's, through exactly
## the code a player's frame goes through.
static func _hold_trim(game: Node, row: Dictionary) -> void:
	# The lamps are lit by 15_lights, which does not run while the world is held,
	# so they are scaled here from what they were before any trim was held.
	var lamps: Array[OmniLight3D] = []
	for s: Node in game.get("systems"):
		var list: Variant = s.get("lights")
		if s.get("lantern_light") is OmniLight3D and list is Array:
			for l: OmniLight3D in list:
				lamps.append(l)
			lamps.append(s.get("lantern_light"))
			if s.get("reach_light") is OmniLight3D:
				lamps.append(s.get("reach_light"))
	for l in lamps:
		if not l.has_meta(&"trim_base"):
			l.set_meta(&"trim_base", l.light_energy / maxf(CompatTrim.lamp_gain(), 0.001))
	CompatTrim.override = row
	for l in lamps:
		l.light_energy = float(l.get_meta(&"trim_base")) * CompatTrim.lamp_gain()
		if row.is_empty():
			l.remove_meta(&"trim_base")
	var sky: SkyLight = game.get("sky")
	sky.compose()


## What turning the sun's shadow on does to the frame's brightness, under bases
## that each take one thing away, with no trim. On the desktop the frame gets a
## little darker (a shadow is less light). On Compatibility it gets BRIGHTER, and
## no base makes that go away: it is the light, not the air or the curve.
static func shadow_pass(tour: Node, game: Node) -> bool:
	var sky: SkyLight = game.get("sky")
	var tree := tour.get_tree()
	var was_paused := tree.paused
	tree.paused = true
	_hold_trim(game, CompatTrim.IDENTITY.duplicate())
	var e := sky.env.environment
	var keep := _env_state(e)
	var vp := tour.get_viewport()
	var scale_was := vp.scaling_3d_scale
	var sun_keep := [sky.sun.shadow_enabled, sky.sun.shadow_opacity]
	var bases := ["game", "no fog", "no glow", "linear tonemap", "no grade", "bare", "game, scale 1",
		"game, no sky reflection", "game, no ambient", "game, no ambient or emission"]
	for base: String in bases:
		_env_restore(e, keep)
		vp.scaling_3d_scale = scale_was
		RenderingServer.global_shader_parameter_set("sky_emission", 1.0)
		if base == "no fog" or base == "bare":
			e.fog_enabled = false
		if base == "no glow" or base == "bare":
			e.glow_enabled = false
		if base == "linear tonemap" or base == "bare":
			e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			e.tonemap_exposure = 1.0
		if base == "no grade" or base == "bare":
			e.adjustment_enabled = false
		if base == "game, scale 1":
			vp.scaling_3d_scale = 1.0
		if base == "game, no sky reflection":
			e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		if base.begins_with("game, no ambient"):
			e.ambient_light_energy = 0.0
		if base == "game, no ambient or emission":
			RenderingServer.global_shader_parameter_set("sky_emission", 0.0)
		sky.sun.shadow_enabled = false
		var off: Image = await _grab(tour)
		sky.sun.shadow_enabled = true
		var on: Image = await _grab(tour)
		print("tour perf shadowpass (%s): %-30s sun shadow off -> on: luma %6.2f -> %6.2f (%+.2f), median pixel %+.0f"
			% [_renderer(), base, luma(off), luma(on), luma(on) - luma(off), median_luma_difference(off, on)])
	_env_restore(e, keep)
	vp.scaling_3d_scale = scale_was
	sky.sun.shadow_enabled = sun_keep[0]
	sky.sun.shadow_opacity = sun_keep[1]
	_hold_trim(game, {})
	tree.paused = was_paused
	return true


## A LIT quad over the frame, bare pipeline, no trim: what the sun's shadow does
## to a surface that has only diffuse, or diffuse and one other thing. The row
## whose "on" moves is what the casting pass lights a second time.
static func sun_path(tour: Node, game: Node) -> bool:
	var cam := tour.get_viewport().get_camera_3d()
	var sky: SkyLight = game.get("sky")
	var tree := tour.get_tree()
	var was_paused := tree.paused
	tree.paused = true
	_hold_trim(game, CompatTrim.IDENTITY.duplicate())
	var e := sky.env.environment
	var keep := _env_state(e)
	var sun_keep := [sky.sun.shadow_enabled, sky.sun.light_energy]
	e.fog_enabled = false
	e.glow_enabled = false
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.tonemap_exposure = 1.0
	e.tonemap_white = 1.0
	e.adjustment_enabled = false
	var head := "render_mode cull_disabled, fog_disabled"
	var body := "uniform vec3 c;\nvoid fragment() { ALBEDO = c; METALLIC = 0.0; "
	var variants := {
		"diffuse only": head + ", specular_disabled, ambient_light_disabled;\n" + body + "ROUGHNESS = 1.0; }",
		"+ ambient": head + ", specular_disabled;\n" + body + "ROUGHNESS = 1.0; }",
		"+ specular": head + ", ambient_light_disabled;\n" + body + "ROUGHNESS = 0.8; SPECULAR = 0.5; }",
		"+ emission": head + ", specular_disabled, ambient_light_disabled;\n" + body + "ROUGHNESS = 1.0; EMISSION = vec3(0.1); }",
		"+ normal": head + ", specular_disabled, ambient_light_disabled;\n" + body + "ROUGHNESS = 1.0; NORMAL = normalize(NORMAL + vec3(0.1, 0.2, 0.0)); }",
		"world-like": "render_mode cull_disabled;\n" + body + "ROUGHNESS = 0.9; SPECULAR = 0.3; }",
	}
	sky.sun.light_energy = 0.3
	for vname: String in variants:
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(cam.size * 8.0, cam.size * 8.0)
		quad.mesh = mesh
		var sh := Shader.new()
		sh.code = "shader_type spatial;\n" + String(variants[vname]) + "\n"
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("c", PROBE)
		quad.material_override = mat
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		quad.extra_cull_margin = 16384.0
		cam.add_child(quad)
		quad.position = Vector3(0.0, 0.0, -(cam.near + 0.02))
		sky.sun.shadow_enabled = false
		var off := _patch(await _grab(tour, SETTLE + 2), Vector2(0.27, 0.46))
		sky.sun.shadow_enabled = true
		var on := _patch(await _grab(tour, SETTLE + 2), Vector2(0.27, 0.46))
		print("tour perf sunpath (%s): %-14s sun 0.30  shadow off %.3f,%.3f,%.3f  on %.3f,%.3f,%.3f  (on-off %+.3f,%+.3f,%+.3f)"
			% [_renderer(), vname, off.x, off.y, off.z, on.x, on.y, on.z, on.x - off.x, on.y - off.y, on.z - off.z])
		quad.free()
	_env_restore(e, keep)
	sky.sun.shadow_enabled = sun_keep[0]
	sky.sun.light_energy = sun_keep[1]
	_hold_trim(game, {})
	tree.paused = was_paused
	return true


# ---- the fit ---------------------------------------------------------------

## The candidates each CompatTrim key is tried at, as multipliers.
const FIT_STEPS := {
	"lamps": [0.15, 0.2, 0.3, 0.35, 0.45, 0.55, 0.7, 1.0],
	"sun": [0.1, 0.125, 0.15, 0.175, 0.2, 0.25, 0.35, 0.5, 0.65, 0.8, 1.0],
	"ambient": [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.15],
	"exposure": [0.6, 0.7, 0.8, 0.85, 0.9, 0.95, 1.0, 1.1],
	"glow": [0.0, 0.25, 0.5, 0.75, 1.0],
	"fog": [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
	"emission": [0.5, 1.0, 1.5],
	"contrast": [0.8, 0.85, 0.9, 0.95, 1.0, 1.05],
	"saturation": [0.7, 0.8, 0.85, 0.9, 0.95, 1.0, 1.1],
}


## `perf match REF [KEY=V,KEY=V...]`: this frame against the desktop's frame of
## the same moment (REF, a canon frame at 1x or 2x). With values, prints how far
## that trim is from it. Without, walks CompatTrim's keys one at a time, three times
## round, each to the candidate that differs least, and prints the path and the
## row it ends on. The distance is the mean absolute channel difference, 0..255.
static func match_frame(tour: Node, game: Node, parts: PackedStringArray) -> bool:
	if parts.size() < 3:
		printerr("tour perf match: give the desktop's frame, e.g. perf match shots/degrade/before/desktop/01-spawn-morning.png")
		return false
	var path := parts[2] if parts[2].is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(parts[2])
	var ref := Image.load_from_file(path)
	if ref == null or ref.is_empty():
		printerr("tour perf match: cannot read %s" % path)
		return false
	ref.convert(Image.FORMAT_RGB8)
	var size := tour.get_viewport().get_texture().get_size()
	if ref.get_size() != Vector2i(size):
		ref.resize(int(size.x), int(size.y), Image.INTERPOLATE_BILINEAR)
	var label := parts[2].get_file().get_basename()
	var tree := tour.get_tree()
	var was_paused := tree.paused
	tree.paused = true
	var sky: SkyLight = game.get("sky")
	var row: Dictionary = CompatTrim.IDENTITY.duplicate()
	if parts.size() > 3 and parts[3].begins_with("sweep"):
		# One step of a JOINT fit: every candidate of every key, the rest held at
		# the row that is in force here (CompatTrim.row, as SkyLight composed it).
		# Summed over the places by whoever reads the log, the best value per key
		# is the step.
		var centre: Dictionary = CompatTrim.row(sky.sun.shadow_enabled, maxf(Weather.night_fall(sky.clock_hour), sky.closed)).duplicate()
		var here := await _distance(tour, game, centre, ref)
		print("tour perf match %s (%s): sweep centre %s -> distance %.2f" % [label, _renderer(), _row_text(centre), here])
		# `sweep=KEY,KEY` sweeps only those.
		var only := parts[3].get_slice("=", 1).split(",", false) if parts[3].contains("=") else PackedStringArray()
		for key: String in CompatTrim.KEYS:
			if not only.is_empty() and not only.has(key):
				continue
			for v: float in FIT_STEPS[key]:
				var trial: Dictionary = centre.duplicate()
				trial[key] = v
				print("tour perf match %s (%s): sweep %s=%.2f distance %.3f" % [label, _renderer(), key, v, await _distance(tour, game, trial, ref)])
	elif parts.size() > 3:
		# Whole rows, `;` between them: each one's distance, for choosing between
		# rows the one-key-at-a-time sweep cannot tell apart.
		for text in parts[3].split(";", false):
			var cand: Dictionary = CompatTrim.IDENTITY.duplicate()
			for kv in text.split(",", false):
				cand[kv.get_slice("=", 0)] = kv.get_slice("=", 1).to_float()
			var d := await _distance(tour, game, cand, ref)
			print("tour perf match %s (%s): row %s -> distance %.3f" % [label, _renderer(), _row_text(cand), d])
	else:
		var start := await _distance(tour, game, row, ref)
		print("tour perf match %s (%s, the sun %s): untrimmed, distance %.2f"
			% [label, _renderer(), "casts" if sky.sun.shadow_enabled else "does not cast", start])
		var best := start
		for round in 3:
			for key: String in CompatTrim.KEYS:
				var pick: float = row[key]
				for v: float in FIT_STEPS[key]:
					var trial: Dictionary = row.duplicate()
					trial[key] = v
					var d := await _distance(tour, game, trial, ref)
					if d < best - 0.01:
						best = d
						pick = v
				row[key] = pick
			print("tour perf match %s (%s): round %d -> %s, distance %.2f" % [label, _renderer(), round + 1, _row_text(row), best])
		# And the obvious alternative, so the fit has something to beat: no sun
		# shadow at all on this renderer, untrimmed.
		_hold_trim(game, CompatTrim.IDENTITY.duplicate())
		sky.sun.shadow_enabled = false
		var bare: Image = await _grab(tour)
		print("tour perf match %s (%s): for comparison, no sun shadow and no trim -> distance %.2f" % [label, _renderer(), differ(bare, ref)])
	_hold_trim(game, {})
	tree.paused = was_paused
	return true


static func _distance(tour: Node, game: Node, row: Dictionary, ref: Image) -> float:
	_hold_trim(game, row)
	var img: Image = await _grab(tour, 3)
	return differ(img, ref)


static func _row_text(row: Dictionary) -> String:
	var bits: Array[String] = []
	for k: String in CompatTrim.KEYS:
		bits.append("%s=%.2f" % [k, float(row[k])])
	return ",".join(bits)


# ---- the slate ---------------------------------------------------------------

## `perf slate`: what the slate's baked device costs on THIS build. Each bake is
## timed on this thread (the CPU it costs wherever it runs), the texture made
## from it is measured by the renderer's own counter rather than by width times
## height, and one bake is handed to the WorkerThreadPool the way UiSlate hands
## it, to see whether the frames go on while it runs: on a build with no threads
## there is no worker to hand it to, and the frame it lands in is the bake.
static func slate_cost(tour: Node) -> bool:
	var tree := tour.get_tree()
	var jobs := [["game device", "d", UiSlate.DEVICE.size], ["game marks", "m", UiSlate.DEVICE.size],
		["spare panel", "s", UiSlate.SPARE.size], ["title device", "d", UiTitleMenu.DEVICE.size],
		["title marks", "m", UiTitleMenu.DEVICE.size]]
	var total_ms := 0.0
	var total_mb := 0.0
	var game_ms := 0.0
	print("tour perf slate (%s, threads %s, quality %s): the slate's bakes, each on this thread"
		% [_renderer(), OS.has_feature("threads"), Quality.current_id()])
	for job: Array in jobs:
		var t0 := Time.get_ticks_usec()
		var img := UiSlate._bake(job[1], job[2])
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		await RenderingServer.frame_post_draw
		var before := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
		var t1 := Time.get_ticks_usec()
		var tex := ImageTexture.create_from_image(img)
		var upload_ms := (Time.get_ticks_usec() - t1) / 1000.0
		await RenderingServer.frame_post_draw
		var mb := (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) - before) / 1048576.0
		total_ms += ms
		total_mb += mb
		if String(job[0]).begins_with("game") or job[0] == "spare panel":
			game_ms += ms
		print("tour perf slate: %-13s %dx%d  bake %7.1f ms  texture %5.2f MB (counted by the renderer), made in %.1f ms"
			% [job[0], img.get_width(), img.get_height(), ms, mb, upload_ms])
		tex = null
	print("tour perf slate: all five %.0f ms of bake and %.1f MB of texture; the game's own three %.0f ms"
		% [total_ms, total_mb, game_ms])
	# One real hand-over, as UiSlate.warm makes it: how long the add itself held
	# this thread, and the longest frame while the worker ran.
	var t2 := Time.get_ticks_usec()
	var id := WorkerThreadPool.add_task(func() -> void: UiSlate._bake("d", UiSlate.DEVICE.size))
	var add_ms := (Time.get_ticks_usec() - t2) / 1000.0
	var worst := 0.0
	var frames := 0
	var last := Time.get_ticks_usec()
	var give_up := Time.get_ticks_msec() + 30000
	while not WorkerThreadPool.is_task_completed(id) and Time.get_ticks_msec() < give_up:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
	WorkerThreadPool.wait_for_task_completion(id)
	var held := (Time.get_ticks_usec() - t2) / 1000.0
	print("tour perf slate: handed to the WorkerThreadPool, the add held this thread %.1f ms; the bake took %.0f ms over %d frames, the longest %.1f ms"
		% [add_ms, held, frames, worst])
	print("tour perf slate: in the game now, %.1f MB of texture and %.1f MB of video memory"
		% [Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	return true


# ---- scale ----------------------------------------------------------------

## `perf scale 1.0,0.85,0.75 SECS`: each scale in turn, ROUNDS times, SECS of
## frames each. The frame interval is the honest number on the web (the page's
## own clock between two drawn frames, which is where the GPU's cost lands when
## the browser is not holding frames to the display); render CPU is Godot's own;
## the GPU timer is printed only if it ran.
static func scale_curve(tour: Node, parts: PackedStringArray) -> bool:
	if parts.size() < 3:
		printerr("tour perf scale: give the scales, e.g. perf scale 1.0,0.75,0.5 2")
		return false
	var scales: Array[float] = []
	for s in parts[2].split(",", false):
		scales.append(s.to_float())
	var secs := parts[3].to_float() if parts.size() > 3 else 2.0
	var vp := tour.get_viewport()
	var was := vp.scaling_3d_scale
	var rid := vp.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var frame: Dictionary = {}
	var cpu: Dictionary = {}
	var gpu: Dictionary = {}
	for s in scales:
		frame[s] = [] as Array[float]
		cpu[s] = [] as Array[float]
		gpu[s] = [] as Array[float]
	for r in ROUNDS:
		for s in scales:
			vp.scaling_3d_scale = s
			for i in 8:
				await RenderingServer.frame_post_draw
			var m: Vector3 = await _measure(tour, rid, secs)
			(frame[s] as Array[float]).append(m.x)
			(cpu[s] as Array[float]).append(m.y)
			(gpu[s] as Array[float]).append(m.z)
	vp.scaling_3d_scale = was
	print("tour perf scale (%s, quality %s, base %dx%d): %d rounds of %.1f s each, median of the rounds' medians"
		% [_renderer(), Quality.current_id(), UiBase.SIZE.x, UiBase.SIZE.y, ROUNDS, secs])
	for s in scales:
		var g := _median(gpu[s])
		var px := Vector2i(Vector2(UiBase.SIZE) * s)
		print("tour perf scale %.2f (%dx%d): frame %.2f ms (%.0f fps), render cpu %.2f ms, gpu %s"
			% [s, px.x, px.y, _median(frame[s]), 1000.0 / maxf(0.001, _median(frame[s])), _median(cpu[s]),
			("%.2f ms" % g) if g > 0.0 else "UNMEASURED"])
	return true


## Median frame interval, render CPU and GPU over SECS.
static func _measure(tour: Node, rid: RID, secs: float) -> Vector3:
	var until := Time.get_ticks_msec() + int(secs * 1000.0)
	var frames: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	await RenderingServer.frame_post_draw
	var last := Time.get_ticks_usec()
	while Time.get_ticks_msec() < until:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	return Vector3(_median(frames), _median(cpu), _median(gpu))


static func _median(list: Array[float]) -> float:
	if list.is_empty():
		return 0.0
	var c := list.duplicate()
	c.sort()
	return c[c.size() / 2]
