class_name SkyLight
extends Node3D
## Sun, moon and the per-channel sky tint, driven by the world clock. Numbers
## are the source game's (art-audio-extract §6): night is blue, not black; the
## key light stays upper-left of the screen and swings only 70 degrees.

## Day fraction keys: [t, tint, level].
const KEYS := [
	[0.00, Vector3(0.56, 0.64, 0.90), 0.82],
	[0.22, Vector3(0.56, 0.64, 0.90), 0.82],
	[0.30, Vector3(1.00, 0.84, 0.70), 0.86],
	[0.40, Vector3(1.00, 1.00, 0.99), 1.00],
	[0.70, Vector3(1.00, 1.00, 0.99), 1.00],
	[0.80, Vector3(0.98, 0.74, 0.58), 0.80],
	[0.90, Vector3(0.56, 0.64, 0.90), 0.82],
	[1.00, Vector3(0.56, 0.64, 0.90), 0.82],
]

var sun: DirectionalLight3D
var env: WorldEnvironment
## Extra multiply from weather or region; 1 = none.
var weather_tint := Vector3.ONE


func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "sun"
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 120.0
	sun.light_energy = 1.0
	add_child(sun)
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Palette.BRINE[0]
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.BLACK
	e.ambient_light_energy = 0.0
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)


## hour: 0..24 of the world clock.
func set_hour(hour: float) -> void:
	var t := fposmod(hour, 24.0) / 24.0
	var tint := Vector3.ONE
	var level := 1.0
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if t >= a[0] and t <= b[0]:
			var f: float = (t - float(a[0])) / maxf(1e-5, float(b[0]) - float(a[0]))
			tint = (a[1] as Vector3).lerp(b[1], f)
			level = lerpf(a[2], b[2], f)
			break
	var total := tint * level * weather_tint
	RenderingServer.global_shader_parameter_set("sky_tint", total)
	# Sun from the upper left of the screen. Camera yaw is 45 (looking north-west),
	# so screen upper-left is world west; the light travels east and a little
	# north, which lights south faces and shades east faces: two readable sides.
	# Swing 70 degrees across the day; low at the ends.
	var day := clampf((hour - 6.0) / 14.0, 0.0, 1.0)
	var swing := lerpf(-35.0, 35.0, day)
	var elevation := lerpf(28.0, 62.0, sin(day * PI))
	var night := hour < 5.5 or hour > 20.5
	if night:
		elevation = 50.0
		swing = 10.0
	sun.rotation_degrees = Vector3(-elevation, -72.0 + swing, 0.0)
	sun.light_energy = 0.55 if night else 1.0
	sun.shadow_enabled = not night
