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
##   upscale        int         Viewport.Scaling3DMode: 0 bilinear, 1 FSR1, 2 FSR2.
##                              Every tier is on 0 today and that is deliberate:
##                              FSR2 is temporal, wants motion vectors and a TAA-
##                              shaped pipeline, and this game has neither yet and
##                              an orthographic camera besides. It is the obvious
##                              thing to try once `lit` lands, which is why the
##                              knob is a column here and not a constant somewhere
##   msaa           int         Viewport.MSAA_* (0 off, 1 2x, 2 4x, 3 8x)
##   orbit          int         the ring's sky layer (src/render/orbit/): how many
##                              of its pixels a frame pixel takes on each side (2
##                              is four samples, the layer's only antialiasing,
##                              because MSAA would pay for the whole target), 1 one,
##                              0 no ring at all. The layer only covers the ring's
##                              own rectangle on the glass, so 2 costs about as
##                              much as a 400 px square.
##   shadow_size    int         the sun's shadow map, px square
##   shadow_filter  int         soft shadow filter quality 0..4 (0 hard, 4 softest)
##   shadow_lights  int         how many LOCAL lights may cast a shadow at once.
##   lamps          int         how many LOCAL lights may EXIST at once, which is
##                              a different and much cheaper question. Casting is
##                              what costs; a non-casting omni is clustered and
##                              nearly free on Forward+, which is why this number
##                              is several times `shadow_lights` on every row.
##
##                              IT USED TO BE SEVEN, EVERYWHERE, and not because
##                              anyone costed it: `15_lights` built
##                              `SkyLight.MAX_LAMPS - 1` nodes, and MAX_LAMPS is 8
##                              because `sky_lamps` packs into two mat4s of four
##                              columns -- a SHADER global sized for the ink pass,
##                              which LANTERN deleted (`sky_pool` is a documented
##                              no-op saying "a real light makes its own pool").
##                              The packing outlived the pass and the count of
##                              real Godot lights was chained to it, so every
##                              settlement in the game has been silently dropping
##                              lights for its whole life: the coast greens have
##                              eleven sources within fourteen tiles and the city
##                              eight. It never showed on the coast because the
##                              coast has a sun. The slums has `LID_SUN` 0.035 and
##                              is lit ONLY by the sources that were being thrown
##                              away, which is why a street of lamps measured 0.2
##                              luma more than no lamps at all.
##
##                              The shader global still takes its eight NEAREST
##                              pools and the player's lantern is still first in
##                              that list; the two numbers are separate now
##                              because they always were two questions.
##                              0 means none may: lamps and fires light, and cast
##                              nothing. The lights package reads this and is its
##                              only enforcer — this file does not hunt for lights
##   fore           int         how many FOREGROUND pieces may hang over the
##                              frame at once (src/render/depth/, docs/LOOK.md
##                              law 3): boughs, snapped lines, eaves, girders.
##                              0 means the layer is off and the world is one
##                              plane again. It is a COUNT and not a bool
##                              because the cost is overdraw and overdraw is
##                              linear in how many of them cross the picture
##   near_focus     bool        the near depth of field that puts a piece a few
##                              units from the eye genuinely out of focus.
##                              Forward+ only, and the one thing in this package
##                              that costs a real screen pass
##   near_stand_in  bool        where `near_focus` is off, the screen-space pass the
##                              tier already runs (shafts.gdshader) blurs what is
##                              nearer than the same focal plane. Compatibility has
##                              no depth of field (measured: switching it on does not
##                              move the frame), and a bough over the web frame was
##                              the sharpest, most faceted thing in the picture
##   volumetric     bool        real volumetric fog (Forward+ only)
##   air_stand_in   float       where `volumetric` is off, how much of a landscape's
##                              volumetric bank (Air.ROWS.bank) the DEPTH fog takes
##                              over: density x (1 + this x (bank - 1)). The bog's
##                              and the Burning's air is thick and the salt's thin,
##                              and on the desktop the volumetrics are what say so;
##                              without them every landscape stood in one air.
##                              Measured, not chosen: fitted against the desktop's
##                              own frames the web's fog wanted 1.5 in the moss,
##                              1.25 in the Burning and 0.5 on the bonelands, which
##                              is its bank with this slope (docs/LOOK.md's
##                              "depth fog for volumetrics")
##   ssao           bool        screen-space ambient occlusion (Forward+ only)
##   ssil           bool        screen-space indirect light (Forward+ only)
##   grass_reach    int         tiles round the player the meadow ring stands at
##                              eye level (MeadowView): grass as thick as grass
##                              grows, handing over to the baked decor's tufts at
##                              its edge. 0 is no ring. The cost is fill, so it
##                              is a distance and not a bool
##   grass_density  float       how thick the ring stands: 1.0 is
##                              Decor.MEADOW_THICK times the decor's plants
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

## `horizon_near` is how far the NEAR chunks reach, in tiles, while the camera
## sees the horizon (SkyLight.sees_horizon). A frame out to the horizon asks for
## every chunk to `WorldView.near_limit`, 36 of them and 3.1 million primitives on
## seed 7, where the orthographic frame holds six; past this the far world's
## silhouettes carry the land. The orthographic game never reads it.
##
## `eye_shadow_reach` is how far out, in tiles from an eye-level camera, the near
## chunks still cast into the sun's shadow (WorldView `_shadow_reach`); 0 is
## everything the splits reach. It exists because the shadow passes were most of
## an eye-level frame's primitives on the web path. `eye_shadow_full` is how far
## a chunk's props cast from their full models before they cast from their SHADE
## ones (FarModels.SHADE); at 0 even the chunk underfoot does, which on the web's
## 2048 shadow atlas is a texel the thinned crown cannot be told apart in. The
## orthographic game never reads either.
##
## The tiers, dearest first. `web` is last on purpose: it is not "low", it is the
## Compatibility path, and it may differ from `low` in kind and not only in degree.
const ROWS: Array[Dictionary] = [
	{
		"id": &"ultra", "label": "ultra", "grass_reach": 28, "grass_density": 1.0, "orbit": 2, "horizon_near": 110, "eye_shadow_reach": 0, "eye_shadow_full": 30,
		"note": "Native 1920x1080, every light casts, real volumetric air.",
		"render_scale": 1.0, "upscale": 0, "msaa": 3,
		"shadow_size": 8192, "shadow_filter": 4, "shadow_lights": 16, "lamps": 32,
		"fore": 28, "near_focus": true, "near_stand_in": false,
		"volumetric": true, "air_stand_in": 0.0, "ssao": true, "ssil": true, "forward_only": true,
	},
	{
		"id": &"high", "label": "high", "grass_reach": 24, "grass_density": 0.8, "orbit": 2, "horizon_near": 110, "eye_shadow_reach": 0, "eye_shadow_full": 30,
		"note": "Native, the lights that matter cast, volumetric air.",
		"render_scale": 1.0, "upscale": 0, "msaa": 2,
		"shadow_size": 4096, "shadow_filter": 2, "shadow_lights": 8, "lamps": 24,
		"fore": 20, "near_focus": true, "near_stand_in": false,
		"volumetric": true, "air_stand_in": 0.0, "ssao": true, "ssil": false, "forward_only": true,
	},
	{
		"id": &"medium", "label": "medium", "grass_reach": 18, "grass_density": 0.55, "orbit": 2, "horizon_near": 80, "eye_shadow_reach": 72, "eye_shadow_full": 24,
		"note": "A little under native, fewer lights cast, no indirect light.",
		"render_scale": 0.85, "upscale": 0, "msaa": 1,
		"shadow_size": 4096, "shadow_filter": 1, "shadow_lights": 4, "lamps": 16,
		"fore": 14, "near_focus": false, "near_stand_in": false,
		# COMPATIBILITY COLUMNS, because this is the tier a Compatibility desktop
		# LANDS on: `detect()` returns it whenever the renderer is not Forward+,
		# and `apply()` steps every Forward+-only tier down to it. It used to ask
		# for volumetric fog and SSAO -- the exact two things `apply()`'s own
		# comment says a step-down exists to avoid, four lines above the row that
		# asked for them. The cost was three ways to have no air at once: the
		# renderer cannot do volumetrics, `camera_rig` only builds the screen-space
		# shaft pass when `volumetric` is FALSE so the stand-in was never built
		# either, and `air_stand_in` at 0.0 meant the depth fog did not take the
		# landscape's bank. `web` had the right shape all along.
		"volumetric": false, "air_stand_in": 1.3, "ssao": false, "ssil": false, "forward_only": false,
	},
	{
		"id": &"low", "label": "low", "grass_reach": 12, "grass_density": 0.35, "orbit": 1, "horizon_near": 64, "eye_shadow_reach": 48, "eye_shadow_full": 0,
		"note": "Two thirds of the pixels, upscaled; the sun casts and little else.",
		"render_scale": 0.67, "upscale": 0, "msaa": 0,
		"shadow_size": 2048, "shadow_filter": 0, "shadow_lights": 2, "lamps": 12,
		"fore": 9, "near_focus": false, "near_stand_in": false,
		# The stand-in is a FOG DENSITY, not a cost, so refusing volumetrics is no
		# reason to refuse it too: at 0.0 this tier's landscapes lost their air
		# rather than degrading it, which is the one thing docs/LOOK.md's whole
		# degradation table exists to prevent.
		"volumetric": false, "air_stand_in": 1.3, "ssao": false, "ssil": false, "forward_only": false,
	},
	{
		"id": &"web", "label": "web", "grass_reach": 14, "grass_density": 0.4, "orbit": 1, "horizon_near": 64, "eye_shadow_reach": 48, "eye_shadow_full": 0,
		"note": "The Compatibility path: the same place, on a worse night.",
		"render_scale": 0.75, "upscale": 0, "msaa": 0,
		"shadow_size": 2048, "shadow_filter": 0, "shadow_lights": 0, "lamps": 8,
		"fore": 7, "near_focus": false, "near_stand_in": true,
		"volumetric": false, "air_stand_in": 1.3, "ssao": false, "ssil": false, "forward_only": false,
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


## How many LOCAL lights may exist at once on the tier in force, never fewer than
## the shader pool can carry so the two can never disagree about the nearest ones.
## `15_lights` builds its pool from this; `shadow_lights` still says how many of
## them may CAST, which is the expensive half.
static func lamp_count() -> int:
	return maxi(int(current().get("lamps", SkyLight.MAX_LAMPS)), SkyLight.MAX_LAMPS)


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
