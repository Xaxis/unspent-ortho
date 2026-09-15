class_name SkyLight
extends Node3D
## Sun, moon and every global the sky shader include reads. Numbers are the
## source game's (art-audio-extract §6): night is blue, not black; the key light
## stays upper-left of the screen and swings only 70 degrees; nothing casts at
## night; weather and region are colour multiplies, never a veil.
##
## One writer: only this node sets the sky_* shader globals. The 10_sky system
## fills `weather_tint`, `region_tint`, `season_turn`, `clouds`, `fog`, `flash`,
## `settle`, `wind` and `cast_allowed`, then calls set_hour(); everything is composed there, so
## the order in which game.gd and the systems run never matters.

## Day fraction keys: [t, tint, level]. (source, exact)
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

## The key light's bearing (degrees about +Y). Camera yaw 45 puts screen
## upper-left in the world's west; this bearing lights the south faces the
## camera sees and shades its east faces, so every solid shows two values.
const KEY_AZIMUTH := -72.0
## The sun swings this far either side of the key over the day. (source: 70 total)
const SWING := 35.0
const SUNRISE := 4.5
const SUNSET := 21.0
## Shadow length on screen, as a share of the caster's screen height. (source)
const SHADOW_NOON := 0.5
const SHADOW_LOW := 1.35
const MOON_ELEVATION := 58.0
## Display level of the light at the dead of night. The source's rule is 0.58
## (Weather.light_level, which sight still uses), but our terrain albedos are
## darker than its sprites and at 0.58 the land sank to black; 0.70 keeps the
## night blue and the lamps still matter.
const NIGHT_LEVEL := 0.70
const REGION_GAIN := 1.3
## Pools of lamplight the ink knows about (two mat4 globals of four columns).
const MAX_LAMPS := 8
## Cool light from the open sky, added under the sun when it is low and all
## night: shadows keep their blue while lit faces warm at dawn and dusk.
## Linear colour, scaled by how low the light is.
const SKY_AMBIENT := Color(0.18, 0.26, 0.52)
const SKY_AMBIENT_ENERGY := 0.16

## Per country id: (warmth, wetness) in -1..1, read by the source's light cast.
## Sea, coast, moss, pinewood, snowfield, bonelands, burning.
const CLIMATE: Array[Vector2] = [
	Vector2(0.0, 0.3), Vector2(0.0, 0.0), Vector2(-0.1, 1.0), Vector2(-0.6, 0.35),
	Vector2(-1.0, -0.3), Vector2(0.35, -1.0), Vector2(1.0, -0.6),
]

var sun: DirectionalLight3D
var env: WorldEnvironment
## Multiplies composed onto the time-of-day tint. 1 = none.
var weather_tint := Vector3.ONE
var region_tint := Vector3.ONE
## 0..1 through the autumn (Weather.season_turn).
var season_turn := 0.0
## Cloud shadows: xy drift offset in tiles, z coverage 0..1, w strength 0..1.
var clouds := Vector4.ZERO
## Fog banks: xy drift offset, z density 0..1, w spare.
var fog := Vector4.ZERO
## Lightning: 0..1, decays in a few frames.
var flash := 0.0
## Lying snow, ash and wet (Weather.settled), 0..1 each; w spare.
var settle := Vector4.ZERO
## Wind for anything that sways: xy along world x/z, z gust, w phase (see sky.gdshaderinc).
var wind := Vector4.ZERO
## Lamp and fire pools for the ink (sky_lamps): Vector4(x, y, z, range) each,
## at most MAX_LAMPS, filled by the lights system.
var lamps: Array[Vector4] = []
## 0..1 how hard the wind blows, for anything that sways (wind_strength).
var sway := 0.4
## Heavy overcast takes the cast shadows away even by day.
var cast_allowed := true
## What set_hour last composed, for systems that tint unlit things (particles,
## lamps) to match the lit world.
var last_tint := Vector3.ONE
var last_energy := 1.0


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
	var s := sun_at(hour)
	var total := tint_at(hour) * season_drain(season_turn) * region_tint * weather_tint
	last_tint = total
	last_energy = s.energy
	RenderingServer.global_shader_parameter_set("sky_tint", total)
	var az: float = s.azimuth
	var el: float = s.elevation
	# Offset per unit of height toward the light, so a cloud's shadow on a wall
	# lines up with its shadow on the ground.
	var tan_el := tan(deg_to_rad(el))
	var proj := Vector2(sin(deg_to_rad(az)), cos(deg_to_rad(az))) / maxf(0.2, tan_el)
	var daylight := 1.0 - Weather.night_fall(hour)
	RenderingServer.global_shader_parameter_set("sky_sun", Vector4(proj.x, proj.y, s.energy, flash))
	RenderingServer.global_shader_parameter_set("sky_clouds", Vector4(clouds.x, clouds.y, clouds.z, clouds.w * daylight))
	RenderingServer.global_shader_parameter_set("sky_fog", fog)
	RenderingServer.global_shader_parameter_set("sky_settle", settle)
	RenderingServer.global_shader_parameter_set("sky_wind", wind)
	RenderingServer.global_shader_parameter_set("wind_strength", sway)
	var texel := 14.0 / 360.0
	if is_inside_tree():
		var cam := get_viewport().get_camera_3d()
		var rows := get_viewport().get_visible_rect().size.y
		if cam != null and rows > 0.0:
			texel = cam.size / rows
	RenderingServer.global_shader_parameter_set("sky_view", Vector4(texel, Weather.night_fall(hour), 0.0, 0.0))
	var packed := lamp_columns(lamps)
	RenderingServer.global_shader_parameter_set("sky_lamps", packed[0])
	RenderingServer.global_shader_parameter_set("sky_lamps2", packed[1])
	if sun == null:
		return
	sun.rotation_degrees = Vector3(-el, az, 0.0)
	# The renderer lights in linear space and encodes the result for display
	# (measured: out = srgb(lin(albedo) * lin(colour) * energy)), while the
	# source's levels are display multiplies. Energy is linear, so decode.
	sun.light_energy = pow(float(s.energy), 2.2)
	sun.shadow_enabled = bool(s.casts) and cast_allowed
	if env != null:
		env.environment.ambient_light_color = SKY_AMBIENT
		env.environment.ambient_light_energy = SKY_AMBIENT_ENERGY * low_light(hour)


## Lamp pools packed for the two mat4 globals, one pool per column, unused
## columns zero (range 0 = no pool). Pools past MAX_LAMPS are dropped.
static func lamp_columns(pools: Array[Vector4]) -> Array[Projection]:
	var cols: Array[Vector4] = []
	for i in MAX_LAMPS:
		cols.append(pools[i] if i < pools.size() else Vector4.ZERO)
	return [Projection(cols[0], cols[1], cols[2], cols[3]), Projection(cols[4], cols[5], cols[6], cols[7])]


## The time-of-day multiply, colour times level, continuous over midnight.
static func tint_at(hour: float) -> Vector3:
	var t := fposmod(hour, 24.0) / 24.0
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if t >= a[0] and t <= b[0]:
			var f: float = (t - float(a[0])) / maxf(1e-5, float(b[0]) - float(a[0]))
			var col := (a[1] as Vector3).lerp(b[1], f)
			return col * lerpf(a[2], b[2], f)
	var last: Array = KEYS[KEYS.size() - 1]
	return (last[1] as Vector3) * float(last[2])


## The autumn's drain: warmer, less green, much less blue as the days go. (source)
static func season_drain(turn: float) -> Vector3:
	var t := clampf(turn, 0.0, 1.0)
	return Vector3(1.0 + 0.06 * t, 1.0 - 0.04 * t, 1.0 - 0.13 * t)


## Sun by day, moon by night, one continuous bearing so faces never flip:
## {azimuth, elevation (degrees), energy: display level 0..1, casts: bool}.
static func sun_at(hour: float) -> Dictionary:
	var h := fposmod(hour, 24.0)
	var az: float
	var el: float
	if h >= SUNRISE and h <= SUNSET:
		var day := (h - SUNRISE) / (SUNSET - SUNRISE)
		az = KEY_AZIMUTH + lerpf(-SWING, SWING, day)
		var ends := pow(absf(day * 2.0 - 1.0), 2.0)
		el = _elevation_for_shadow(az, lerpf(SHADOW_NOON, SHADOW_LOW, ends))
	else:
		# The moon walks the bearing back overnight, from where the sun set to
		# where it will rise, riding higher at midnight.
		var night_len := 24.0 - (SUNSET - SUNRISE)
		var n := fposmod(h - SUNSET, 24.0) / night_len
		az = KEY_AZIMUTH + lerpf(SWING, -SWING, n)
		var edge := _elevation_for_shadow(az, SHADOW_LOW)
		el = lerpf(edge, MOON_ELEVATION, sin(n * PI))
	var nf := Weather.night_fall(h)
	return {"azimuth": az, "elevation": el, "energy": 1.0 - nf * (1.0 - NIGHT_LEVEL), "casts": nf < 0.5}


## 0 at midday, 1 from dusk to dawn: how much of the light is the cool sky
## rather than the sun.
static func low_light(hour: float) -> float:
	var t := tint_at(hour)
	var noon := tint_at(12.0)
	var warm_or_dim := clampf((noon.x + noon.y + noon.z - (t.x + t.y + t.z)) / 1.2, 0.0, 1.0)
	return maxf(warm_or_dim, Weather.night_fall(hour))


## Elevation at which a caster's shadow is `ratio` times its own height ON
## SCREEN, for this camera (yaw 45, pitch 57) and a light from `azimuth`.
static func _elevation_for_shadow(azimuth: float, ratio: float) -> float:
	var a := deg_to_rad(azimuth)
	# Horizontal travel of the light, then its length on screen per tile.
	var gx := -sin(a)
	var gz := -cos(a)
	var sx := 0.7071 * (gx - gz)
	var sy := 0.7071 * sin(deg_to_rad(57.0)) * (gx + gz)
	var k := sqrt(sx * sx + sy * sy)
	var height_on_screen := cos(deg_to_rad(57.0))
	return rad_to_deg(atan(k / (height_on_screen * ratio)))


## The source's light cast for a place (Surface.Cast): warm tilts to fire, cold
## to ice, wet to green, dry to bone; normalised so the brightest channel is 1.
static func cast_tint(warmth: float, wetness: float) -> Vector3:
	var w := clampf(warmth, -1.0, 1.0)
	var d := clampf(wetness, -1.0, 1.0)
	var c := Vector3(1.0 + 0.075 * w - 0.03 * d, 1.0 - 0.02 * absf(w) + 0.015 * d, 1.0 - 0.085 * w - 0.045 * d)
	return c / maxf(c.x, maxf(c.y, c.z))


## A country's cast, pushed REGION_GAIN times further from white than the
## source's formula so that crossing a border is felt in the light itself.
static func country_tint(country: int) -> Vector3:
	var cl := CLIMATE[clampi(country, 0, CLIMATE.size() - 1)]
	var c := Vector3.ONE + (cast_tint(cl.x, cl.y) - Vector3.ONE) * REGION_GAIN
	return c / maxf(c.x, maxf(c.y, c.z))
