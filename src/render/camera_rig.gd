class_name CameraRig
extends Camera3D
## The fixed orthographic camera: 45 degrees of yaw, a steep pitch, following a
## target, snapped to whole texels of the low-res viewport so the pixel grid
## never crawls. Also owns the full-screen outline pass.

@export var yaw_deg := 45.0
@export var pitch_deg := 57.0
## Vertical extent of the view in world units.
@export var view_height := 15.0
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
	_outline = MeshInstance3D.new()
	_outline.name = "outline_pass"
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	q.flip_faces = true
	_outline.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/render/outline.gdshader")
	_outline.material_override = mat
	_outline.extra_cull_margin = 16384.0
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_outline)


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
	# Ink patterns are drawn in screen pixels; shifting them by the camera's own
	# texel offset pins every hatch line to the world instead of the glass.
	RenderingServer.global_shader_parameter_set("world_px", Vector2(roundf(local.x / texel), roundf(local.y / texel)))
