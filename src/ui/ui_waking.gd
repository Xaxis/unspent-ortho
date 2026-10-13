class_name UiWaking
extends CanvasLayer
## COMING TO (owner, 2026-10-13: "effects of him slowly coming to
## consciousness"). The world through his eyes as they open on the first
## morning (waking.gdshader): black, a slit that opens and falls shut, the world
## swimming and drained, wider and sharper each time until he is awake.
##
## Over the world and under the slate (Hud is layer 10), so the record's first
## lines are read over the black. 48_wake drives it with `eyes` and frees it once
## they are wide open: awake, it costs nothing.

const LAYER := 8

var _rect: ColorRect
var _mat: ShaderMaterial
var open := 0.0
var focus := 0.0
var light := 0.0


func _init() -> void:
	layer = LAYER
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://src/ui/waking.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)
	eyes(0.0, 0.0, 0.0)


## `o` 0 shut .. 1 wide, `f` 0 swimming .. 1 sharp, `l` 0 drained .. 1 the world's own.
func eyes(o: float, f: float, l: float) -> void:
	open = clampf(o, 0.0, 1.0)
	focus = clampf(f, 0.0, 1.0)
	light = clampf(l, 0.0, 1.0)
	_mat.set_shader_parameter(&"open", open)
	_mat.set_shader_parameter(&"focus", focus)
	_mat.set_shader_parameter(&"light", light)


func awake() -> bool:
	return open >= 1.0 and focus >= 1.0 and light >= 1.0
