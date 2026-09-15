class_name Hud
extends CanvasLayer
## The quiet layer. For now: the clock, top right. Everything on it is drawn at
## the 640x360 base resolution, so text is pixel-crisp.

var _clock: Label


func _ready() -> void:
	_clock = Label.new()
	_clock.name = "clock"
	_clock.anchor_left = 1.0
	_clock.anchor_right = 1.0
	_clock.offset_left = -120
	_clock.offset_right = -8
	_clock.offset_top = 4
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.add_theme_font_size_override("font_size", 10)
	_clock.add_theme_color_override("font_color", Palette.LINEN[5])
	_clock.add_theme_color_override("font_shadow_color", Palette.INK[0])
	_clock.add_theme_constant_override("shadow_offset_x", 1)
	_clock.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_clock)


func set_clock(text: String) -> void:
	_clock.text = text
