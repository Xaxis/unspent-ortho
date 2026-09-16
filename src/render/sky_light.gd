class_name SkyLight
extends Node3D
## Sun, moon and every global the sky shader include reads. Numbers are the
## source game's (art-audio-extract §6): night is blue, not black; the key light
## stays upper-left of the screen and swings only 70 degrees; nothing casts at
## night; weather and region are colour multiplies, never a veil.
##
## One writer: only this node sets the sky_*, neon_* and glint globals (and
## wind_strength, which world.gdshader's sway reads). The 10_sky system fills
## `weather_tint`, `region_tint`, `season_turn`, `clouds`, `fog`, `flash`,
## `settle`, `wind`, `sway`, `air`, `bolt`, `focus` and `cast_allowed`; the 15_lights
## system fills `lamps` and `glints`. Anyone may call set_hour().
##
## Once a sky system drives it (`driven`), set_hour() only records the hour and
## the node composes every global ONCE per frame in its own late _process
## (process_priority COMPOSE_LAST), after every system has filled its fields,
## so the order in which game.gd and the systems run never matters and nothing
## is written twice. Undriven (the title, the gallery, a test) set_hour()
## composes at once.

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
## Lights mirrored in wet ground (sky_glints*, glint_rgb*): three mat4 globals
## of four columns. Not OmniLights: a list of points the reflection draws.
const MAX_GLINTS := 12
## After every GameSystem (they run at 0), before nothing that reads the globals.
const COMPOSE_LAST := 1000
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

## Per landscape type id: (warmth, wetness) in -1..1, read by the source's
## light cast. A type not listed casts neutral light (its BiomeDef.light_tint
## still multiplies on top). New types add a row.
const CAST := {
	&"sea": Vector2(0.0, 0.3), &"coast": Vector2(0.0, 0.0), &"moss": Vector2(-0.1, 1.0), &"pinewood": Vector2(-0.6, 0.35),
	&"snowfield": Vector2(-1.0, -0.3), &"bonelands": Vector2(0.35, -1.0), &"burning": Vector2(1.0, -0.6),
}

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
## Share of each landscape type in view (type id -> weight), for the neon grade.
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
## The airs over the focus: x rain falling now (rain and drizzle), y glare,
## z how warm the fog is drawn (furnace haze), w whiteout. (sky_air)
var air := Vector4.ZERO
## Lightning after a strike: xy the strike's world x/z, z the afterglow rolling
## in the clouds 0..1, w the machines' power 0..1 (1 steady; a strike stutters
## it for a beat). (sky_bolt)
var bolt := Vector4(0.0, 0.0, 0.0, 1.0)
## The camera's focus in world space, for weather that closes in on the
## player (sky_focus: a whiteout).
var focus := Vector3.ZERO
## Tiles the afterglow has rolled out from the strike (sky_view.w).
var glow_reach := 0.0
## Lights mirrored in wet ground: Vector4(x, y, z, level) each, at most
## MAX_GLINTS, nearest the camera first; filled by the lights system.
var glints: Array[Vector4] = []
## The colour of each glint (rgb, w spare), parallel to `glints`.
var glint_colors: Array[Vector4] = []
## True once a sky system fills this node every frame (see the header).
var driven := false
## The world clock hour set_hour() last recorded.
var clock_hour := 8.0
## How many times the globals have been composed, and on which process frame
## last: one writer, once a frame (tests/sky/test_one_writer.gd).
var compose_count := 0
var last_compose_frame := -1


func _init() -> void:
	process_priority = COMPOSE_LAST


func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "sun"
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# From the camera (CameraRig.distance 30): the view's depth plus tall land
	# behind it, and no further, so a 2048 atlas keeps crisp shadow texels.
	sun.directional_shadow_max_distance = 50.0
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
func set_hour(h: float) -> void:
	clock_hour = h
	if not (driven and is_inside_tree()):
		compose()


func _process(_delta: float) -> void:
	if driven:
		compose()


## Write every sky global from the fields, for the recorded hour.
func compose() -> void:
	compose_count += 1
	last_compose_frame = Engine.get_process_frames()
	var hour := clock_hour
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
	RenderingServer.global_shader_parameter_set("sky_view", Vector4(texel, Weather.night_fall(hour), ground_scale, glow_reach))
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
	RenderingServer.global_shader_parameter_set("sky_air", air)
	RenderingServer.global_shader_parameter_set("sky_bolt", bolt)
	RenderingServer.global_shader_parameter_set("sky_focus", Vector4(focus.x, focus.y, focus.z, 0.0))
	var gp := glint_columns(glints)
	var gc := glint_columns(glint_colors)
	RenderingServer.global_shader_parameter_set("sky_glints", gp[0])
	RenderingServer.global_shader_parameter_set("sky_glints2", gp[1])
	RenderingServer.global_shader_parameter_set("sky_glints3", gp[2])
	RenderingServer.global_shader_parameter_set("glint_rgb", gc[0])
	RenderingServer.global_shader_parameter_set("glint_rgb2", gc[1])
	RenderingServer.global_shader_parameter_set("glint_rgb3", gc[2])
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


## Glints packed for the three mat4 globals, one per column, unused columns
## zero (level 0 = no glint). Glints past MAX_GLINTS are dropped.
static func glint_columns(points: Array[Vector4]) -> Array[Projection]:
	var cols: Array[Vector4] = []
	for i in MAX_GLINTS:
		cols.append(points[i] if i < points.size() else Vector4.ZERO)
	var out: Array[Projection] = []
	for m in MAX_GLINTS / 4:
		out.append(Projection(cols[m * 4], cols[m * 4 + 1], cols[m * 4 + 2], cols[m * 4 + 3]))
	return out


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


## What a landscape type does to the light's level, on top of its cast: the
## Burning lies under warm, low light even at noon (docs/ART.md section 3).
const LEVEL := {&"burning": Vector3(0.94, 0.8, 0.68)}


## The light a landscape type lays over the hour: its cast, its level, its mood
## at this hour and its own BiomeDef.light_tint, one multiply. null reads as a
## type with nothing of its own.
static func type_light(def: BiomeDef, hour: float) -> Vector3:
	var id: StringName = def.id if def != null else &""
	var own := Vector3.ONE
	if def != null:
		own = Vector3(def.light_tint.r, def.light_tint.g, def.light_tint.b)
	return type_tint(id) * (LEVEL.get(id, Vector3.ONE) as Vector3) * mood_light(id, hour) * own


## Each landscape's light through the day (docs/VISION.md section 8): a multiply
## on the hour's tint, keyed [hour, Vector3] and read round the clock. Never a
## filter: noon keeps nearly all its light, and the mood leans in at the ends of
## the day, where each place is most itself. Bleak grey on the coast, drowned
## green gloom in the moss, an early dusk under the pines, the snowfield's long
## blue evening, hard white noon on the bonelands, furnace dusk in the burning.
## A landscape type not listed keeps the plain hour. New types add a row.
const MOOD := {
	&"coast": [[0.0, Vector3(0.98, 0.99, 1.0)], [12.0, Vector3(0.97, 0.98, 1.0)], [18.5, Vector3(0.95, 0.96, 1.0)]],
	&"moss": [[0.0, Vector3(0.93, 0.97, 0.94)], [6.0, Vector3(0.88, 0.95, 0.9)], [12.0, Vector3(0.95, 0.98, 0.94)], [18.0, Vector3(0.9, 0.96, 0.91)]],
	&"pinewood": [[0.0, Vector3(0.95, 0.97, 1.0)], [11.0, Vector3(0.97, 0.98, 0.97)], [15.5, Vector3(0.96, 0.96, 0.96)], [18.0, Vector3(0.8, 0.82, 0.88)], [20.5, Vector3(0.88, 0.9, 0.98)]],
	&"snowfield": [[0.0, Vector3(0.94, 0.97, 1.0)], [12.5, Vector3(1.0, 1.0, 1.0)], [16.5, Vector3(0.94, 0.97, 1.0)], [19.5, Vector3(0.8, 0.9, 1.0)], [21.5, Vector3(0.88, 0.94, 1.0)]],
	&"bonelands": [[0.0, Vector3(1.0, 0.98, 0.96)], [9.0, Vector3(1.0, 0.99, 0.97)], [12.5, Vector3(1.0, 1.0, 1.0)], [16.0, Vector3(1.0, 0.98, 0.94)], [19.5, Vector3(0.98, 0.9, 0.82)]],
	&"burning": [[0.0, Vector3(1.0, 0.94, 0.9)], [12.0, Vector3(1.0, 0.97, 0.94)], [17.0, Vector3(1.0, 0.92, 0.84)], [19.8, Vector3(1.0, 0.8, 0.66)], [22.0, Vector3(1.0, 0.9, 0.84)]],
}


## The mood multiply for a landscape type at an hour (MOOD), continuous round
## the clock: the last key eases back into the first across midnight.
static func mood_light(type_id: StringName, hour: float) -> Vector3:
	var keys: Array = MOOD.get(type_id, [])
	if keys.is_empty():
		return Vector3.ONE
	var h := fposmod(hour, 24.0)
	var n := keys.size()
	for i in n:
		var a: Array = keys[i]
		var b: Array = keys[(i + 1) % n]
		var ha := float(a[0])
		var hb := float(b[0]) if i + 1 < n else float(b[0]) + 24.0
		var hh := h if h >= ha else h + 24.0
		if hh >= ha and hh <= hb:
			var t := (hh - ha) / maxf(0.001, hb - ha)
			return (a[1] as Vector3).lerp(b[1], smoothstep(0.0, 1.0, t))
	return keys[0][1]


## A landscape type's cast, pushed REGION_GAIN times further from white than
## the source's formula so that crossing a border is felt in the light itself.
static func type_tint(type_id: StringName) -> Vector3:
	var cl: Vector2 = CAST.get(type_id, Vector2.ZERO)
	var c := Vector3.ONE + (cast_tint(cl.x, cl.y) - Vector3.ONE) * REGION_GAIN
	return c / maxf(c.x, maxf(c.y, c.z))


## The dystopian grade (docs/ART.md section 6): a light, bleak desaturation that
## sets the mood without hiding the land, and how wet each landscape lies without
## rain. Returns [grade Vector4(dark, desat, cool, contrast), wet Vector4(base
## wet, sheen, reflection, 0)]. Day stays day; each landscape leans its own way.
const NEON_DAY := Vector4(0.0, 0.22, 0.10, 0.18)
const NEON_NIGHT := Vector4(0.0, 0.25, 0.12, 0.10)
## Per country: [grade offset Vector4, base wet].
## The land now carries its own evidence (GenWorks, WorksMap), so the grade
## leans each landscape only as far as its light: a bleak grey coast, the moss's
## green gloom kept readable enough to see the cuts in it, the pines a shade
## under their canopy, the snow's cold glare, the bones' hard white, the
## burning's warm low furnace.
## The darkness term goes NEGATIVE where a landscape's own washes are dark, so
## every land reads as day at noon in its own way. Measured mean luma of a clear
## noon frame (seed 7, --hour=12 --weather=clear:0), HUD rows excluded, is the
## check: a dark wood is dimmer than a salt pan, but none of them is night.
const NEON_COUNTRY := {
	Country.SEA: [Vector4(-0.1, 0.0, 0.04, 0.0), 0.0],
	Country.COAST: [Vector4(-0.55, 0.16, 0.05, 0.02), 0.15],
	Country.MOSS: [Vector4(-0.5, 0.16, 0.02, 0.06), 0.35],
	Country.PINEWOOD: [Vector4(-0.45, 0.15, 0.05, 0.06), 0.2],
	Country.SNOWFIELD: [Vector4(-0.04, 0.08, 0.08, -0.03), 0.0],
	Country.BONELANDS: [Vector4(-0.03, 0.14, -0.02, 0.12), 0.0],
	Country.BURNING: [Vector4(-0.42, -0.04, -0.15, 0.1), 0.0],
}


## The NEON_COUNTRY row for a share's key: a landscape type id (what the sky
## samples), or a Country id (how the table is keyed until it moves to type
## ids). An unknown landscape reads the coast's.
static func neon_row(key: Variant) -> Array:
	var c := Weather.COUNTRY_TYPES.find(key) if key is StringName else int(key)
	return NEON_COUNTRY.get(c, NEON_COUNTRY[Country.COAST])


## shares: landscape type id (or Country id) -> weight.
static func neon_grade_at(hour: float, shares: Dictionary) -> Array:
	var night := Weather.night_fall(hour)
	var g := NEON_DAY.lerp(NEON_NIGHT, night)
	var wet := 0.1
	if not shares.is_empty():
		var off := Vector4.ZERO
		var w := 0.0
		var total := 0.0
		for k: Variant in shares:
			var e: Array = neon_row(k)
			off += (e[0] as Vector4) * float(shares[k])
			w += float(e[1]) * float(shares[k])
			total += float(shares[k])
		if total > 0.0:
			g += off / total
			wet = w / total
	# Darkness may go negative: that is a landscape lifting itself into daylight.
	g = g.clamp(Vector4(-0.6, 0.0, 0.0, 0.0), Vector4.ONE)
	return [g, Vector4(wet, 1.0, 1.0, 0.0)]
