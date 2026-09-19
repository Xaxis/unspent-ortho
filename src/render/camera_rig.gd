class_name CameraRig
extends Camera3D
## The fixed orthographic camera: 45 degrees of yaw, a steep pitch, following a
## target, snapped to whole texels so the picture never crawls. Also owns the
## full-screen shaft pass, on the tiers that have no volumetric air.

@export var yaw_deg := 45.0
## As with VIEW_HEIGHT below: a test rasterising a model the way the play camera
## sees it asks for this rather than writing 57 down a second time.
const PITCH_DEG := 57.0
@export var pitch_deg := PITCH_DEG
## Vertical extent of the view in world units. The const is here so anything
## sizing itself against the play camera off-screen — a test, a mark's floor —
## can ASK for it instead of writing 15 down a second time (docs/LOOK.md: name a
## number where it is drawn).
const VIEW_HEIGHT := 15.0
@export var view_height := VIEW_HEIGHT
## How far the camera stands back along its view axis. Orthographic, so it only
## has to clear the tallest land in front of the focus; close keeps the depth
## range (and the sun's shadow range, SkyLight) tight.
@export var distance := 30.0
@export var follow_rate := 10.0

var target := Vector3.ZERO

## What a target lock does to the camera (42_target, docs/DESIGN.md §Targeting):
## degrees of yaw and pitch added to the fixed angles, a factor on the view's
## height, and a bias of the frame from the player toward what they are reading.
## The system says where it wants them; the rig eases them, so only one place
## knows how a lean moves. Everything else about the camera is unchanged: the
## angles are fixed, the projection orthographic, the grid snapped to texels.
var lean_yaw := 0.0
var lean_pitch := 0.0
var lean_zoom := 1.0
var lean_bias := Vector3.ZERO
## Eased per second: in quickly enough to feel like a lean, out more gently.
const LEAN_IN := 7.0
const LEAN_OUT := 4.5
## Under these the lean is nothing and the camera is square again.
const LEAN_STILL := 0.01

var _smoothed := Vector3.ZERO
var _outline: MeshInstance3D
var _yaw := 0.0
var _pitch := 0.0
var _zoom := 1.0
var _bias := Vector3.ZERO


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	keep_aspect = KEEP_HEIGHT
	size = view_height
	near = 1.0
	far = 250.0
	rotation = Vector3(deg_to_rad(-pitch_deg), deg_to_rad(yaw_deg), 0.0)
	_near_focus()
	# The screen-space light shafts, and ONLY on a tier with no volumetric air:
	# where the renderer can do real volumetrics a lamp throws a real cone and
	# this quad would draw a second, worse one over it. LOOK.md's degradation
	# table is the authority and Quality.ROWS is where it is written down; this
	# reads the row rather than deciding anything (docs/LOOK.md, Quality).
	if not bool(Quality.current().get("volumetric", false)):
		_outline = MeshInstance3D.new()
		_outline.name = "shaft_pass"
		var q := QuadMesh.new()
		q.size = Vector2(2, 2)
		q.flip_faces = true
		_outline.mesh = q
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://src/render/shafts.gdshader")
		_outline.material_override = mat
		_outline.extra_cull_margin = 16384.0
		_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_outline)


## NEAR DEPTH OF FIELD (docs/LOOK.md law 3), where the tier allows it.
##
## An orthographic camera draws a thing at depth 10 and a thing at depth 50 at
## exactly the same size and moves them across the screen by exactly the same
## number of pixels. Focus is the one cue it CANNOT flatten: a lens has one
## focal plane whatever the projection, so a bough eight units in front of the
## place is soft and the place is sharp, and the eye reads that as distance
## before it reads anything else in the frame.
##
## Only the NEAR side is blurred. A far blur would soften the land at the top of
## the picture, which is the air's job (`Air`) and which fog does in colour
## rather than in focus -- and softening what a player is walking toward is how
## a depth cue becomes a readability failure.
##
## WHERE IT MAY BEGIN IS A READABILITY QUESTION, and it is the hard part.
##
## The frame is only about ten units deep, and the foreground layer lives in the
## SAME depths the world's tall things do: a piece at four units over ground at
## depth 26 is at depth 22.6, and so is a four-unit tower standing at the near
## edge. Blur cannot tell them apart, so a near plane chosen for the boughs also
## softens whatever is standing at the bottom of the frame -- which is where
## something comes at you from. Measured at a near plane of 25.4: a machine at
## the bottom edge went soft, and that is the package's own rule broken by its
## prettiest feature.
##
## So the plane is not a constant. It is the nearest ground the frame holds, less
## the height a thing may stand there and still be SHARP: nothing under
## DOF_CLEAR_LIFT off the ground is ever touched, anywhere in the picture. What
## is left to blur is what is genuinely overhead, which is what this is for.
##
## 2.6 units is a machine (about 1.8) with room over it, so a hunter at the very
## bottom edge of the frame is crisp. It is the FLOOR now rather than the answer:
## see `clear_lift`.
const DOF_CLEAR_LIFT := 2.6
## How far past the plane the blur reaches full, in world units.
const DOF_RAMP := 4.5
const DOF_AMOUNT := 0.14
## How fast the clear lift crosses a border, per second. Slow enough that walking
## into the city pulls focus rather than snapping it.
const CLEAR_EASE := 1.6

## HOW TALL A THING MAY BE AT THE NEAR EDGE AND STAY SHARP, set by whoever knows
## what this landscape builds (`12_landscape`, off `BiomeForms.tallest`).
##
## Measured, in the city, and it is the same shape as every other long-lived bug
## in this project: a correct rule whose premise moved. DOF_CLEAR_LIFT was fitted
## to a stock of one-storey buildings — the tallest thing anybody raised was 2.8
## — so "2.6 clears a machine with room over it" cleared everything there was.
## Then a landscape was allowed to build a 14.3 tower and a 16.3 spire, and the
## two tallest buildings in the Slums came out as unreadable smears at the bottom
## of the frame: the near blur was eating precisely what makes a city a city.
##
## The rule itself was never wrong. It just stopped being asked of the right
## number, and a constant cannot notice that. So the height belongs to the stock
## that decides it, and this is only where the camera keeps the answer.
var clear_lift := DOF_CLEAR_LIFT

var _dof_size := -1.0
var _clear_now := DOF_CLEAR_LIFT
var _dof_clear := -1.0


## How much of the frame's height the web pass's near blur spreads a pixel over
## at full blur (`near_stand_in`). Matched by eye and by frame against the
## desktop's CameraAttributesPractical at DOF_AMOUNT, on the canon's pinewood
## bough: the same softness at the same place.
const NEAR_STAND_IN_REACH := 0.015


## Where the near blur begins, in view depth, for the picture as it is shown: the
## nearest ground the frame holds, less the height a thing may stand there and
## stay sharp. One answer for the real blur and for the web's stand-in, so the two
## soften exactly the same things.
func near_plane(shown: float) -> float:
	var near_ground := distance - Air.frame_depth(shown, pitch_deg + _pitch)
	var begin := near_ground - _clear_now * sin(deg_to_rad(pitch_deg + _pitch))
	return maxf(near + 1.0, begin)


## Put the near blur on, or take it off, by the tier's own row. Never re-derived:
## `Quality.ROWS` is the one place that says what a tier may spend.
##
## Compatibility draws no depth of field at all (measured: `perf features`, the
## frame does not move), so a tier with `near_stand_in` hands the same plane to
## the screen-space pass it already runs for shafts (shafts.gdshader), which
## blurs what is nearer than it out of the frame it already reads.
func _near_focus() -> void:
	if not bool(Quality.current().get("near_focus", false)):
		attributes = null
		if _outline != null and bool(Quality.current().get("near_stand_in", false)):
			var shown_web := size
			if not is_equal_approx(shown_web, _dof_size):
				_dof_size = shown_web
				var m := _outline.material_override as ShaderMaterial
				m.set_shader_parameter("near_begin", near_plane(shown_web))
				m.set_shader_parameter("near_ramp", DOF_RAMP)
				m.set_shader_parameter("near_reach", NEAR_STAND_IN_REACH)
			return
		_dof_size = -1.0
		return
	var a := attributes as CameraAttributesPractical
	if a == null:
		a = CameraAttributesPractical.new()
		# Auto exposure would fight the one tonemapper SkyLight owns, and a second
		# thing deciding how bright the frame is is exactly the failure LOOK.md's
		# ceiling rule exists to stop.
		a.auto_exposure_enabled = false
		a.exposure_multiplier = 1.0
		# Only the near side. A far blur would soften the land at the top of the
		# picture, which is the AIR's job (`Air`) and which fog does in colour
		# rather than in focus -- and softening what a player is walking toward is
		# how a depth cue becomes a readability failure.
		a.dof_blur_far_enabled = false
		a.dof_blur_near_enabled = true
		a.dof_blur_amount = DOF_AMOUNT
		attributes = a
	var shown := size
	# Both inputs, or a landscape that changes how tall it builds without changing
	# the zoom leaves the plane where the last one put it.
	if is_equal_approx(shown, _dof_size) and is_equal_approx(_clear_now, _dof_clear):
		return
	_dof_size = shown
	_dof_clear = _clear_now
	# The nearest ground the frame holds, from the camera that is really drawing
	# -- so a zoom or a target lean moves the plane with the picture instead of
	# quietly blurring the near half of a zoomed-out frame.
	a.dof_blur_near_distance = near_plane(shown)
	a.dof_blur_near_transition = DOF_RAMP


## The yaw the screen is actually at, lean and all: screen-relative input and
## anything else drawn in screen space must ask for this, not the fixed angle,
## or the keys stop matching the picture while the camera leans.
func yaw_now() -> float:
	return yaw_deg + _yaw


## The camera is leaning (a lock, a sweep) rather than square on.
func leaning() -> bool:
	return absf(_yaw) > LEAN_STILL or absf(_pitch) > LEAN_STILL \
		or absf(_zoom - 1.0) > LEAN_STILL * 0.1 or _bias.length() > LEAN_STILL


## Jump straight to the target (no easing): startup, teleports, screenshots.
func snap_to(p: Vector3) -> void:
	target = p
	_smoothed = p
	_yaw = lean_yaw
	_pitch = lean_pitch
	_zoom = lean_zoom
	_bias = lean_bias
	_apply()


## A short shake of `strength` world units, decaying over `seconds`. Moves only
## h_offset/v_offset, rounded to whole texels so the pixel grid holds.
## `PlayerSettings` may turn this down to nothing: it is the only thing that moves
## the whole picture without the player asking, so it is theirs to refuse.
func shake(strength: float, seconds: float = 0.12) -> void:
	strength *= float(PlayerSettings.value(&"picture.shake"))
	if strength <= 0.001:
		return
	if not is_inside_tree():
		return
	var texel := view_height / float(get_viewport().get_visible_rect().size.y)
	var seed_ms := Time.get_ticks_msec()
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var k := strength * (1.0 - t)
		h_offset = roundf(sin(t * 47.0 + seed_ms) * k / texel) * texel
		v_offset = roundf(cos(t * 61.0 + seed_ms * 0.7) * k / texel) * texel, 0.0, 1.0, seconds)
	tw.tween_callback(func() -> void:
		h_offset = 0.0
		v_offset = 0.0)


func _process(delta: float) -> void:
	_smoothed = _smoothed.lerp(target, 1.0 - exp(-follow_rate * delta))
	_clear_now = lerpf(_clear_now, maxf(DOF_CLEAR_LIFT, clear_lift), 1.0 - exp(-CLEAR_EASE * delta))
	_ease_lean(delta)
	_apply()


## Each part of the lean eased toward what the system asked for: in at LEAN_IN,
## back to square at LEAN_OUT.
func _ease_lean(delta: float) -> void:
	var to_in := 1.0 - exp(-LEAN_IN * delta)
	var to_out := 1.0 - exp(-LEAN_OUT * delta)
	_yaw = lerpf(_yaw, lean_yaw, to_out if is_zero_approx(lean_yaw) else to_in)
	_pitch = lerpf(_pitch, lean_pitch, to_out if is_zero_approx(lean_pitch) else to_in)
	_zoom = lerpf(_zoom, lean_zoom, to_out if is_equal_approx(lean_zoom, 1.0) else to_in)
	_bias = _bias.lerp(lean_bias, to_out if lean_bias.length() < LEAN_STILL else to_in)


func _apply() -> void:
	size = view_height * _zoom
	rotation = Vector3(deg_to_rad(-(pitch_deg + _pitch)), deg_to_rad(yaw_deg + _yaw), 0.0)
	var b := Basis.from_euler(rotation)
	# Express the focus in camera space, snap its screen-plane axes to texels, go back.
	var texel := size / float(get_viewport().get_visible_rect().size.y)
	var local := b.inverse() * (_smoothed + _bias)
	local.x = roundf(local.x / texel) * texel
	local.y = roundf(local.y / texel) * texel
	var focus := b * local
	global_position = focus + b.z * distance
	# The focal plane follows the picture: a lean zooms and tilts, and a plane
	# left where the square-on frame put it would blur the near half of a
	# zoomed-out one. Does nothing until `size` really moves.
	if attributes != null or bool(Quality.current().get("near_focus", false)) \
			or bool(Quality.current().get("near_stand_in", false)):
		_near_focus()
	# Ink patterns are drawn in screen pixels; shifting them by the camera's own
	# texel offset pins every hatch line to the world instead of the glass.
	RenderingServer.global_shader_parameter_set("world_px", Vector2(roundf(local.x / texel), roundf(local.y / texel)))
