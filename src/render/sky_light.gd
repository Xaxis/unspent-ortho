class_name SkyLight
extends Node3D
## Sun, moon and every global the sky shader include reads. Numbers are the
## source game's (art-audio-extract §6): night is blue, not black; the key light
## stays upper-left of the screen and swings only 70 degrees; nothing casts at
## night; weather and region are colour multiplies, never a veil.
##
## One writer: only this node sets the sky_* shader globals (and wind_strength,
## which world.gdshader's sway reads). The 10_sky system fills `weather_tint`,
## `region_tint`, `season_turn`, `clouds`, `fog`, `flash`, `settle`, `wind`,
## `sway` and `cast_allowed`; the 15_lights system fills `lamps`. Both then
## rely on set_hour(), which composes everything, so the order in which game.gd
## and the systems run never matters.

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
## Render layers the sky's lights sort by (bit masks, set on nodes as they enter
## the tree, so no model or view has to know). People take a fill light of their
## own in low light (docs/ART.md section 5: the player reads at any hour, with
## or without a lantern; the source's player light floor is 0.45). Water takes
## no lamplight, so a lamp by the sea never lays a glow disc on it (section 6).
const LAYER_FIGURES := 1 << 17
const LAYER_WATER := 1 << 18
const WATER_SHADER := "res://src/render/water.gdshader"
## Linear energy of the figure fill at the dead of night: with the moon it lifts
## a person to about 0.45 of their daylight value. Warm, because people are the
## only warm moving thing on screen.
const FIGURE_FILL := 1.9
const FIGURE_FILL_COLOR := Color(1.0, 0.8, 0.6)

## Per country id: (warmth, wetness) in -1..1, read by the source's light cast.
## Sea, coast, moss, pinewood, snowfield, bonelands, burning.
const CLIMATE: Array[Vector2] = [
	Vector2(0.0, 0.3), Vector2(0.0, 0.0), Vector2(-0.1, 1.0), Vector2(-0.6, 0.35),
	Vector2(-1.0, -0.3), Vector2(0.35, -1.0), Vector2(1.0, -0.6),
]

var sun: DirectionalLight3D
var figure_light: DirectionalLight3D
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
## The colour of each lamp pool (rgb, w spare), parallel to `lamps`.
var lamp_colors: Array[Vector4] = []
## Share of each country in view (Country id -> weight), for the neon grade.
var neon_shares: Dictionary = {}
## 1 / world size, for the sky_ground texture (set_ground); 0 = none.
var ground_scale := 0.0
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
	figure_light = DirectionalLight3D.new()
	figure_light.name = "figure_light"
	figure_light.shadow_enabled = false
	figure_light.light_specular = 0.0
	figure_light.light_cull_mask = LAYER_FIGURES
	figure_light.light_color = FIGURE_FILL_COLOR
	# From over the camera's shoulder and a little from the key's side, so every
	# face the camera sees takes it and the figure still shows two values.
	figure_light.rotation_degrees = Vector3(-42.0, 20.0, 0.0)
	figure_light.light_energy = 0.0
	add_child(figure_light)
	get_tree().node_added.connect(_on_node_added)
	if get_parent() != null:
		_tag_tree(get_parent())
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
	RenderingServer.global_shader_parameter_set("sky_view", Vector4(texel, Weather.night_fall(hour), ground_scale, 0.0))
	var glow := sun_glow(total, s)
	var cool := shade_cool(total) / glow
	RenderingServer.global_shader_parameter_set("sky_shade", Vector4(cool.x, cool.y, cool.z, dusk_lift(hour, region_tint)))
	var packed := lamp_columns(lamps)
	RenderingServer.global_shader_parameter_set("sky_lamps", packed[0])
	RenderingServer.global_shader_parameter_set("sky_lamps2", packed[1])
	var packed_rgb := lamp_columns(lamp_colors)
	RenderingServer.global_shader_parameter_set("neon_lamp_rgb", packed_rgb[0])
	RenderingServer.global_shader_parameter_set("neon_lamp_rgb2", packed_rgb[1])
	var ng := neon_grade_at(hour, neon_shares)
	RenderingServer.global_shader_parameter_set("neon_grade", ng[0])
	RenderingServer.global_shader_parameter_set("neon_wet", ng[1])
	if sun == null:
		return
	sun.rotation_degrees = Vector3(-el, az, 0.0)
	# The renderer lights in linear space and encodes the result for display
	# (measured: out = srgb(lin(albedo) * lin(colour) * energy)), while the
	# source's levels are display multiplies. Energy is linear, so decode.
	sun.light_energy = pow(float(s.energy) * glow, 2.2)
	sun.shadow_enabled = bool(s.casts) and cast_allowed
	if figure_light != null:
		figure_light.light_energy = FIGURE_FILL * low_light(hour)
		figure_light.visible = figure_light.light_energy > 0.01
	if env != null:
		env.environment.ambient_light_color = SKY_AMBIENT
		env.environment.ambient_light_energy = SKY_AMBIENT_ENERGY * low_light(hour)


## What the land can hold (SkyGround), for snow, ash, wet and fog.
func set_ground(tex: Texture2D, world_size: int) -> void:
	RenderingServer.global_shader_parameter_set("sky_ground", tex)
	ground_scale = 1.0 / maxf(1.0, float(world_size))


func _on_node_added(n: Node) -> void:
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		g.layers = layers_for(g, g.layers)


func _tag_tree(n: Node) -> void:
	_on_node_added(n)
	for c in n.get_children():
		_tag_tree(c)


## The render layers a piece of geometry should have: water is on LAYER_WATER
## alone (lamps cull it); anything inside a PersonModel adds LAYER_FIGURES.
static func layers_for(g: GeometryInstance3D, current: int) -> int:
	var m := g.material_override
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.resource_path == WATER_SHADER:
		return LAYER_WATER
	var p := g.get_parent()
	for i in 8:
		if p == null:
			break
		if p is PersonModel:
			return current | LAYER_FIGURES
		p = p.get_parent()
	return current


## How far a low sun lifts the darks onto blue (sky_shade.w): all of low light,
## except in a warm country, whose evening keeps its own dark warmth (the
## burning glows from below; its clinker must not turn violet at dusk).
static func dusk_lift(hour: float, region: Vector3) -> float:
	var warm := clampf((region.x - region.z) * 4.0, 0.0, 0.8)
	return low_light(hour) * (1.0 - warm)


## A low sun lays its warmth on what it lights: lit faces take up to GLOW more
## light at a warm tint while the sun still casts (shade_cool divides it back
## out of shade), so dawn and dusk read warm and clear rather than dim.
const GLOW := 0.2


static func sun_glow(tint: Vector3, sun: Dictionary) -> float:
	if not bool(sun.casts):
		return 1.0
	var lum := (tint.x + tint.y + tint.z) / 3.0
	return 1.0 + GLOW * clampf((tint.x - tint.z) / maxf(0.05, lum) * 1.8, 0.0, 1.0)


## The multiply for faces in shade under a tint: the tint's warmth taken back
## out (its hue divided away, its level kept) and a little blue added, so at
## dawn and dusk the sun is warm on what it lights and shade stays cool. At a
## neutral tint it is white.
static func shade_cool(tint: Vector3) -> Vector3:
	var lum := (tint.x + tint.y + tint.z) / 3.0
	var out := Vector3.ZERO
	for i in 3:
		out[i] = lum / maxf(0.05, tint[i])
	var warm := clampf((tint.x - tint.z) / maxf(0.05, lum) * 1.5, 0.0, 1.0)
	out = Vector3.ONE.lerp(out, 0.85 * warm) * Vector3(1.0 - 0.04 * warm, 1.0, 1.0 + 0.08 * warm)
	return out


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


## What a country does to the light's level, on top of its cast: the Burning
## lies under warm, low light even at noon (docs/ART.md section 3).
static func country_light(country: int) -> Vector3:
	if country == Country.BURNING:
		return Vector3(0.94, 0.8, 0.68)
	return Vector3.ONE


## A country's cast, pushed REGION_GAIN times further from white than the
## source's formula so that crossing a border is felt in the light itself.
static func country_tint(country: int) -> Vector3:
	var cl := CLIMATE[clampi(country, 0, CLIMATE.size() - 1)]
	var c := Vector3.ONE + (cast_tint(cl.x, cl.y) - Vector3.ONE) * REGION_GAIN
	return c / maxf(c.x, maxf(c.y, c.z))


## Ink & Neon (docs/VISION.md section 8): the grade and the wet for an hour and
## the landscapes in view. Returns [grade Vector4(dark, desat, cool, contrast),
## wet Vector4(base wet, sheen, reflection, 0)]. Day is overcast gloom, dusk is
## long, night is the stage; each landscape leans its own way.
const NEON_DAY := Vector4(0.16, 0.34, 0.28, 0.45)
const NEON_NIGHT := Vector4(0.0, 0.3, 0.2, 0.2)
## Per country: [grade offset Vector4, base wet].
const NEON_COUNTRY := {
	Country.SEA: [Vector4(0.0, 0.0, 0.1, 0.0), 0.0],
	Country.COAST: [Vector4(0.0, 0.0, 0.05, 0.0), 0.65],
	Country.MOSS: [Vector4(0.04, 0.08, 0.05, 0.05), 0.9],
	Country.PINEWOOD: [Vector4(0.06, 0.05, 0.08, 0.05), 0.7],
	Country.SNOWFIELD: [Vector4(-0.08, 0.1, 0.2, -0.1), 0.25],
	Country.BONELANDS: [Vector4(-0.04, 0.12, 0.0, 0.1), 0.3],
	Country.BURNING: [Vector4(0.02, -0.2, -0.3, 0.05), 0.2],
}


static func neon_grade_at(hour: float, shares: Dictionary) -> Array:
	var night := Weather.night_fall(hour)
	var g := NEON_DAY.lerp(NEON_NIGHT, night)
	var wet := 0.55
	if not shares.is_empty():
		var off := Vector4.ZERO
		var w := 0.0
		var total := 0.0
		for c: int in shares:
			var e: Array = NEON_COUNTRY.get(c, NEON_COUNTRY[Country.COAST])
			off += (e[0] as Vector4) * float(shares[c])
			w += float(e[1]) * float(shares[c])
			total += float(shares[c])
		if total > 0.0:
			g += off / total
			wet = w / total
	g = g.clamp(Vector4.ZERO, Vector4.ONE)
	return [g, Vector4(wet, 1.0, 1.0, 0.0)]
