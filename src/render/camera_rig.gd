class_name CameraRig
extends Camera3D
## The fixed orthographic camera: 45 degrees of yaw, a steep pitch, following a
## target, snapped to whole texels of the low-res viewport so the pixel grid
## never crawls. Also owns the full-screen outline pass.

@export var yaw_deg := 45.0
@export var pitch_deg := 57.0
## Vertical extent of the view in world units.
@export var view_height := 15.0
@export var distance := 80.0
@export var follow_rate := 10.0

var target := Vector3.ZERO
var _smoothed := Vector3.ZERO
var _outline: MeshInstance3D


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


## Jump straight to the target (no easing): startup, teleports, screenshots.
func snap_to(p: Vector3) -> void:
	target = p
	_smoothed = p
	_apply()


## A short shake of `strength` world units, decaying over `seconds`. Moves only
## h_offset/v_offset, rounded to whole texels so the pixel grid holds.
func shake(strength: float, seconds: float = 0.12) -> void:
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
	_apply()


func _apply() -> void:
	size = view_height
	var b := Basis.from_euler(rotation)
	# Express the focus in camera space, snap its screen-plane axes to texels, go back.
	var texel := view_height / float(get_viewport().get_visible_rect().size.y)
	var local := b.inverse() * _smoothed
	local.x = roundf(local.x / texel) * texel
	local.y = roundf(local.y / texel) * texel
	var focus := b * local
	global_position = focus + b.z * distance
	# Ink patterns are drawn in screen pixels; shifting them by the camera's own
	# texel offset pins every hatch line to the world instead of the glass.
	RenderingServer.global_shader_parameter_set("world_px", Vector2(roundf(local.x / texel), roundf(local.y / texel)))
