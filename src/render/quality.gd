class_name Quality
extends RefCounted
## What a frame is allowed to cost (docs/LOOK.md). LANTERN's floor is 1920x1080
## and Forward+, and the web is the SAME look on a worse night — so degrading is
## expressed here, as named tiers, and never as a second game.
##
## The one idea this file exists to hold: **a tier spends render scale, not
## window size.** The slate and the HUD are canvas items and are drawn at the full
## 1920x1080 base on every tier; only the 3D image is rendered at a fraction of it
## and upscaled (project.godot `rendering/scaling_3d`). So the cheapest tier and
## the dearest differ in how sharp the WORLD is, and in nothing a player reads.
##
## A ROW. Five builders read these; nothing here decides anything on its own.
##
##   id             StringName  the tier's name, as `--quality=` and both settings doors give it
##   label          String      what a settings row calls it
##   note           String      one plain line for the slate's panel
##   render_scale   float       fraction of the 1920x1080 base the 3D renders at
##                              (1.0 native, 0.5 a quarter of the pixels)
##   upscale        int         Viewport.Scaling3DMode: SCALING_3D_MODE_BILINEAR or
##                              _FSR2. FSR2 needs Forward+; Compatibility ignores it
##   msaa           int         Viewport.MSAA_* (0 off, 1 2x, 2 4x, 3 8x)
##   shadow_size    int         the sun's shadow map, px square
##   shadow_filter  int         soft shadow filter quality 0..4 (0 hard, 4 softest)
##   shadow_lights  int         how many LOCAL lights may cast a shadow at once.
##                              0 means none may: lamps and fires light, and cast
##                              nothing. The lights package reads this and is its
##                              only enforcer — this file does not hunt for lights
##   volumetric     bool        real volumetric fog (Forward+ only)
##   ssao           bool        screen-space ambient occlusion (Forward+ only)
##   ssil           bool        screen-space indirect light (Forward+ only)
##   forward_only   bool        the tier asks for things Compatibility cannot do,
##                              so it is never chosen on the web
##
## WHO APPLIES WHAT. `apply()` writes the four knobs that live in project.godot's
## `[rendering]` block and on the root Viewport, because those are this package's:
## render scale, upscale mode, MSAA and the sun's shadow. Everything else is
## DECLARED here and applied by whoever owns it — `volumetric`, `ssao` and `ssil`
## belong to the Environment the lighting package builds, and `shadow_lights` to
## the lights system. Read the row, do not re-derive the number.
##
## CHOOSING ONE. `detect()` at boot: the web always gets `web`; a machine running
## Compatibility on the desktop gets `medium` (it can do no better); Forward+ gets
## `high`. `--quality=NAME` overrides it for one run, the player's picture setting
## overrides it for their device, and the owner's master configuration can pin one
## into a stamped build.

## The tiers, dearest first. `web` is last on purpose: it is not "low", it is the
## Compatibility path, and it may differ from `low` in kind and not only in degree.
const ROWS: Array[Dictionary] = [
	{
		"id": &"ultra", "label": "ultra",
		"note": "Native 1920x1080, every light casts, real volumetric air.",
		"render_scale": 1.0, "upscale": 0, "msaa": 3,
		"shadow_size": 8192, "shadow_filter": 4, "shadow_lights": 16,
		"volumetric": true, "ssao": true, "ssil": true, "forward_only": true,
	},
	{
		"id": &"high", "label": "high",
		"note": "Native, the lights that matter cast, volumetric air.",
		"render_scale": 1.0, "upscale": 0, "msaa": 2,
		"shadow_size": 4096, "shadow_filter": 2, "shadow_lights": 8,
		"volumetric": true, "ssao": true, "ssil": false, "forward_only": true,
	},
	{
		"id": &"medium", "label": "medium",
		"note": "A little under native, fewer lights cast, no indirect light.",
		"render_scale": 0.85, "upscale": 0, "msaa": 1,
		"shadow_size": 4096, "shadow_filter": 1, "shadow_lights": 4,
		"volumetric": true, "ssao": true, "ssil": false, "forward_only": false,
	},
	{
		"id": &"low", "label": "low",
		"note": "Two thirds of the pixels, upscaled; the sun casts and little else.",
		"render_scale": 0.67, "upscale": 0, "msaa": 0,
		"shadow_size": 2048, "shadow_filter": 0, "shadow_lights": 2,
		"volumetric": false, "ssao": false, "ssil": false, "forward_only": false,
	},
	{
		"id": &"web", "label": "web",
		"note": "The Compatibility path: the same place, on a worse night.",
		"render_scale": 0.75, "upscale": 0, "msaa": 0,
		"shadow_size": 2048, "shadow_filter": 0, "shadow_lights": 0,
		"volumetric": false, "ssao": false, "ssil": false, "forward_only": false,
	},
]

## The tier a run is on. Written once at boot by `apply()`; read with `current()`.
static var _now: StringName = &""


## Every tier's id, dearest first, for a settings row's options.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for r: Dictionary in ROWS:
		out.append(r.id)
	return out


## The row named `id`, or `{}` when nothing is called that.
static func row(id: StringName) -> Dictionary:
	for r: Dictionary in ROWS:
		if r.id == id:
			return r
	return {}


## Whether a tier exists. Both settings doors check with this rather than keeping
## their own copy of the list, so a tier added here is offered everywhere at once.
static func has(id: StringName) -> bool:
	return not row(id).is_empty()


## The row in force. Falls back to what `detect()` would say, so a reader that
## runs before `apply()` still gets a truthful answer rather than an empty one.
static func current() -> Dictionary:
	return row(_now if _now != &"" else detect())


## The id in force.
static func current_id() -> StringName:
	return _now if _now != &"" else detect()


## Whether this run is really on Forward+. Compatibility has no RenderingDevice,
## which is the only honest question to ask: the project setting says what was
## ASKED for, and a machine that cannot do Vulkan silently gets something else.
static func forward_plus() -> bool:
	return RenderingServer.get_rendering_device() != null


## The tier this machine should boot at when nobody has said otherwise.
static func detect() -> StringName:
	if OS.has_feature("web"):
		return &"web"
	return &"high" if forward_plus() else &"medium"


## Put a tier in force. Writes only what this package owns: the root viewport's
## render scale, upscale mode and MSAA, and the sun's shadow map and filter. The
## lighting and lights packages read `current()` for the rest.
##
## `tree` is where the root viewport is found; a headless run has none and only
## the bookkeeping happens, so a test may call this without a display.
static func apply(id: StringName, tree: SceneTree = null) -> void:
	var r := row(id)
	if r.is_empty():
		push_warning("no quality tier called %s; keeping %s" % [id, current_id()])
		return
	# A tier that wants Forward+ on a machine that has not got it would ask for
	# volumetrics and SSAO that silently do nothing, and read as a broken build
	# rather than an unavailable one. Step down instead, and say so.
	if bool(r.forward_only) and not forward_plus():
		var down := &"web" if OS.has_feature("web") else &"medium"
		push_warning("quality %s needs Forward+; this run is Compatibility, so %s" % [id, down])
		r = row(down)
	_now = r.id
	if tree == null or tree.root == null:
		return
	var vp := tree.root as Viewport
	vp.scaling_3d_scale = float(r.render_scale)
	vp.scaling_3d_mode = int(r.upscale) as Viewport.Scaling3DMode
	vp.msaa_3d = int(r.msaa) as Viewport.MSAA
	RenderingServer.directional_shadow_atlas_set_size(int(r.shadow_size), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		int(r.shadow_filter) as RenderingServer.ShadowQuality)
	RenderingServer.positional_soft_shadow_filter_set_quality(
		int(r.shadow_filter) as RenderingServer.ShadowQuality)


## What the 3D image is actually rendered at on this tier, in pixels. The UI is
## drawn at `UiBase.SIZE` whatever this says.
static func render_pixels(id: StringName = &"") -> Vector2i:
	var r := row(id) if id != &"" else current()
	if r.is_empty():
		return UiBase.SIZE
	return Vector2i(Vector2(UiBase.SIZE) * float(r.render_scale))
