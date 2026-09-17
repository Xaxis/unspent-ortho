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

## Day fraction keys: [t, tint, level]. The source's rows are kept exactly; the
## two between 0.80 and 0.90 are ours. The source ran straight from the dusk key
## (19:12) to full night blue at 21:36, so between 19:12 and 21:00 the level sat
## flat at about 0.81 and only the hue moved: the last two hours of the day were
## as bright as the afternoon and steadily bluer. Now the warmth is HELD to about
## 20:15 (the sun is low and warm on what it lights, and Weather.night_fall takes
## the level down under it), and the blue of the sky takes the land over the last
## three quarters of an hour, landing on night where night_fall lands.
## The 21:00 key is short of the night's own blue on purpose: blue is the
## BRIGHTEST channel at night (0.90 against 0.56 red), so a key that went the
## whole way there in the last half hour of the evening measurably LIFTED a
## blue-leaning land like the snowfield just as it should have been settling.
## The last of that blue deepens over 21:00-21:36, under a level that is flat.
## 21:36 (t = 0.90) is where the light stops moving at all, and it is the anchor
## every other term in the evening is paced against (night_dark).
const KEYS := [
	[0.00, Vector3(0.56, 0.64, 0.90), 0.82],
	[0.22, Vector3(0.56, 0.64, 0.90), 0.82],
	[0.30, Vector3(1.00, 0.84, 0.70), 0.86],
	[0.40, Vector3(1.00, 1.00, 0.99), 1.00],
	[0.70, Vector3(1.00, 1.00, 0.99), 1.00],
	[0.80, Vector3(0.98, 0.74, 0.58), 0.80],
	[0.8438, Vector3(0.95, 0.72, 0.56), 0.80],
	[0.8750, Vector3(0.72, 0.68, 0.78), 0.82],
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
## How solid a moon shadow is. Faint, and softened by SUN_ANGLE_LOW.
const MOON_SHADOW := 0.42
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

## --- LANTERN: the real lights (docs/LOOK.md law 2, "light is the author") ---
##
## The numbers below are LINEAR light, because that is what the renderer wants
## and what the palette is decoded into (matter.gdshaderinc). They are chosen so
## a surface the sun is full on comes back at about the palette value it was
## authored as, and everything else is honestly less than that.

## The sun's energy at noon and the moon's in the dead of night. The gap between
## them and the gap between DAY_AMBIENT and NIGHT_AMBIENT are the whole of why a
## lantern matters.
const SUN_NOON := 2.10
const MOON_NIGHT := 0.55
## The sun's angular size, in degrees. Real penumbra: a fence post has a crisp
## shadow at its foot and a soft one four tiles away, which no filter can fake
## and which is most of what says a shadow is cast by something standing up.
## Wider when the light is low, because a low sun is seen through more air.
const SUN_ANGLE := 0.9
const SUN_ANGLE_LOW := 3.2

## The sky. Four colours drive a ProceduralSkyMaterial: the top and horizon of
## the sky, and the horizon and bottom of the ground under it. It is what metal
## and water REFLECT -- a polished machine carries the horizon along its flank
## and a still pool holds the dusk -- and it is where the ambient takes its HUE,
## so shade is the colour of the sky over it: blue at noon, warm at dusk,
## indigo at night.
const DAY_SKY_TOP := Color(0.29, 0.42, 0.66)
const DAY_SKY_HORIZON := Color(0.62, 0.68, 0.74)
const DUSK_SKY_TOP := Color(0.16, 0.18, 0.38)
const DUSK_SKY_HORIZON := Color(0.72, 0.42, 0.30)
const NIGHT_SKY_TOP := Color(0.105, 0.145, 0.300)
const NIGHT_SKY_HORIZON := Color(0.150, 0.190, 0.340)
## The ground half of the sky dome: bounce off the land, which is what keeps an
## underside from going to nothing.
const SKY_GROUND_DAY := Color(0.20, 0.20, 0.18)
const SKY_GROUND_NIGHT := Color(0.045, 0.052, 0.082)

## How much light comes from the sky rather than from the sun, day and night.
## The sky's colours above give the HUE (normalised to unit level, half way to
## white, so shade is tinted by the sky and not made of it); these two give the
## LEVEL, and they are stated as plain numbers rather than as a multiplier on a
## radiance map, because a number that can be measured off a frame is a number
## that can be argued with. Tripling the night sky's own colours and doubling
## its multiplier once moved a night frame's median luma from 7 to 10, which is
## to say it did nothing anyone could have predicted.
##
## NIGHT_AMBIENT is LANTERN law 3 in one number and it was measured, not chosen.
## A night frame has to stay mostly clear of luma 24 -- under that, a lit room
## shows a black screen with a green dot, which is why `noir` was beautiful and
## unshippable -- while a lamp still has to be worth carrying. Against
## MOON_NIGHT it also decides whether a night has SHAPE in it: a quarter of the
## light at midnight is the moon, so a wall still turns away from something.
const DAY_AMBIENT := 0.55
const NIGHT_AMBIENT := 1.25

## The tonemapper. This is the CEILING that replaced the shader's page shoulder
## (see sky.gdshaderinc): the frame is rendered in HDR and rolled off once, for
## the whole image, so a neon tube four times over white comes back as a bright
## tube instead of a white hole -- and a pale landscape seen from a dark one
## cannot flatten onto anything, because there is no page to flatten onto.
const TONEMAP := Environment.TONE_MAPPER_FILMIC
## A filmic curve costs about a third of a stop in the mids; this buys it back,
## so the palette still lands roughly where it was authored.
const EXPOSURE := 1.10

## Bloom. A light in the dark reads as bright because it BLEEDS, and this is the
## one effect that separates a lit tube from a bright rectangle. The threshold
## is over 1.0 on purpose: only things that are really emitting glow, so a snow
## field at noon does not.
const GLOW_BLOOM := 0.15
const GLOW_HDR := 1.05

## Air. Distance is separated by ATMOSPHERE and not by a haze filter -- the fog
## takes its colour from the sun and the sky, so at dusk the far land goes warm
## on the sun's side and cold away from it for nothing.
##
## It is DEPTH fog with a begin and an end, not exponential, and that is forced
## by the camera. Under an orthographic projection every pixel in the frame is
## between about 26 and 60 units from the eye, so exponential fog puts almost
## exactly the same veil over all of it -- a flat grey wash over the whole
## picture, which is the papery failure again wearing a different coat
## (measured: 18% over the entire first frame). Begun past the near land and
## ended past the far, it does what air does instead.
const FOG_BEGIN := 31.0
const FOG_END := 74.0
const FOG_DENSITY := 0.34
const FOG_SKY := 0.0
const FOG_AERIAL := 0.22
## Volumetric air, where the tier allows it: this is what makes a lamp in rain a
## CONE and a machine's lens a shaft.
const VOLUME_DENSITY := 0.021
const VOLUME_ANISOTROPY := 0.25

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
## How far this place is from the sky: 0 under the open one, 1 with a roof over
## it (src/core/realm — a cave, a buried city, the inside of a works). The realms
## system is its only writer.
##
## A roofed realm's darkness cannot be said by a landscape file, and that is why
## this is here rather than in one. A landscape can dim its own light and its own
## washes, and the caves do both — but what MAKES a dark frame in this game is the
## night: the blue floor under the washes, the hatch laid a line-length at a time,
## the ink turning to night blue, and a lamp's pool being worth carrying. All four
## hang off how far night has fallen, which is read off the HOUR, and the hour is
## exactly what stops mattering when there is rock overhead. Dimmed by a landscape
## alone, a cave at noon came out flat and muddy instead of dark (a measured 0.04
## page value with no floor under it and no hatch on it). So: underground reads as
## night to everything the sky writes, whatever the clock says, and the one thing
## it does NOT get is the skyglow — there is no sky up there to glow.
var closed := 0.0
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
	# The renderer decides what a colour written into ALBEDO means, and the two
	# renderers disagree (measured; matter.gdshaderinc says what and by how
	# much). Every lit shader reads this and converts, so one palette draws the
	# same picture on the desktop and on the web.
	RenderingServer.global_shader_parameter_set("sky_linear", 1.0 if Quality.forward_plus() else 0.0)
	sun = DirectionalLight3D.new()
	sun.name = "sun"
	sun.shadow_enabled = true
	sun.shadow_bias = 0.025
	sun.shadow_normal_bias = 0.9
	# ONE split, not a cascade, and that is deliberate. The camera is
	# orthographic and shows fifteen world units; over the fifty this covers, a
	# 4096 atlas is about eighty texels to the world unit, which is crisper than
	# any cascade would leave the near split. What buys softness here is the
	# sun's angular size (SUN_ANGLE), which is the real thing rather than a
	# filter: a fence post is sharp at its foot and soft four tiles out.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# From the camera (CameraRig.distance 30): the view's depth plus tall land
	# behind it, and no further, so the atlas keeps crisp shadow texels.
	sun.directional_shadow_max_distance = 50.0
	sun.directional_shadow_blend_splits = false
	sun.light_angular_distance = SUN_ANGLE
	sun.light_energy = SUN_NOON
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
	# It lights FIGURES and nothing else -- including nothing in the air. A
	# directional light injects into volumetric fog whatever its cull mask says,
	# so without this the warm fill on people was lighting the whole night's fog
	# and turning a blue moonlit coast brown (measured: mean rgb 54/44/37).
	figure_light.light_volumetric_fog_energy = 0.0
	add_child(figure_light)
	get_tree().node_added.connect(_on_node_added)
	if get_parent() != null:
		_tag_tree(get_parent())
	env = WorldEnvironment.new()
	env.environment = build_environment()
	add_child(env)


## The one Environment. Every expensive thing on it is gated on the tier's own
## row (Quality.ROWS) and NOT re-derived here, so `degrade` can move a tier and
## this file does not argue: `volumetric`, `ssao` and `ssil` are this package's
## to honour and `shadow_lights` is the lights system's.
static func build_environment() -> Environment:
	var q := Quality.current()
	var e := Environment.new()
	# What is DRAWN behind the world stays a flat colour -- the camera looks down
	# at 57 degrees and a horizon in the corner of the frame is a distraction --
	# but the sky is built all the same, because it is the ambient light and it
	# is what polished metal reflects.
	e.background_mode = Environment.BG_COLOR
	e.background_color = Palette.BRINE[0]
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sun_angle_max = 24.0
	sm.sun_curve = 0.18
	sm.ground_curve = 0.06
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	e.sky = sky
	# The ambient LEVEL is stated as a colour and an energy, so it is a number
	# that can be measured off a frame and argued with; the SKY is still what
	# metal and water reflect, and what gives a polished machine its horizon.
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = DAY_SKY_HORIZON
	e.ambient_light_energy = DAY_AMBIENT
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# The ceiling (see sky.gdshaderinc): one curve for the whole frame.
	e.tonemap_mode = TONEMAP
	e.tonemap_exposure = EXPOSURE
	e.tonemap_white = 4.0
	# A light in the dark reads as bright because it bleeds.
	e.glow_enabled = true
	e.glow_intensity = 0.75
	e.glow_bloom = GLOW_BLOOM
	e.glow_hdr_threshold = GLOW_HDR
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Air between the planes of the world, coloured by the sun and the sky.
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_depth_begin = FOG_BEGIN
	e.fog_depth_end = FOG_END
	e.fog_depth_curve = 1.4
	e.fog_density = FOG_DENSITY
	e.fog_sky_affect = FOG_SKY
	e.fog_aerial_perspective = FOG_AERIAL
	e.volumetric_fog_enabled = bool(q.get("volumetric", false))
	e.volumetric_fog_density = VOLUME_DENSITY
	e.volumetric_fog_anisotropy = VOLUME_ANISOTROPY
	e.volumetric_fog_length = 48.0
	e.volumetric_fog_gi_inject = 0.0
	e.ssao_enabled = bool(q.get("ssao", false))
	e.ssao_radius = 0.7
	e.ssao_intensity = 1.9
	e.ssao_power = 1.4
	e.ssao_detail = 0.6
	e.ssil_enabled = bool(q.get("ssil", false))
	e.ssil_radius = 3.0
	e.ssil_intensity = 0.7
	# The grade. It used to be a per-fragment multiply inside the shader, where
	# nothing could know how bright the frame had turned out; here it is one
	# knob on the finished image, set from the same hour and the same landscapes
	# in view (see `compose`).
	e.adjustment_enabled = true
	return e


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
	# How far night has fallen HERE: the hour, or all the way under a roof.
	var night := maxf(Weather.night_fall(hour), closed)
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
	var daylight := 1.0 - night
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
	RenderingServer.global_shader_parameter_set("sky_view", Vector4(texel, night, ground_scale, glow_reach))
	# The blue floor under the washes comes on under a roof; the skyglow does not,
	# because there is no sky up there to be glowing.
	var nt := night_terms(hour, weather_tint)
	RenderingServer.global_shader_parameter_set("sky_night", Vector2(maxf(nt.x, closed), nt.y))
	# The low-sun glow belongs to the SUN, so it is fed the hour's own tint and
	# not the composed one. Fed `total` it read a landscape's MOOD as a low sun:
	# the burning's own warm, low light (LEVEL, MOOD) answered "the sun is on the
	# horizon" at midday, and the burning's noon moved 7% when GLOW was retuned
	# for the evening. A warm land must not be counted as a warm hour.
	var glow := sun_glow(tint_at(hour), s)
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
	RenderingServer.global_shader_parameter_set("water_wash", water_wash_at(neon_shares))
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
	# The hour's colour is now the LIGHT's colour, not a multiply over every
	# surface: `total` is hue times level, so it is split back into the two.
	# That is the single change that lets a face turned to a low sun be warm
	# while the face beside it, turned away, keeps the sky's blue -- which one
	# multiply over the whole fragment could never do, and which is most of what
	# a lit world looks like.
	var level := maxf((total.x + total.y + total.z) / 3.0, 0.02)
	var hue := Color(total.x / level, total.y / level, total.z / level)
	# Godot decodes light_color from sRGB, so encode the ratio we mean.
	sun.light_color = hue.linear_to_srgb()
	var lit := 1.0 - maxf(night, closed)
	sun.light_energy = lerpf(MOON_NIGHT, SUN_NOON * level * glow, lit)
	# A low sun is seen through more air, so its edge is softer. Real penumbra.
	sun.light_angular_distance = lerpf(SUN_ANGLE_LOW, SUN_ANGLE, clampf(el / 55.0, 0.0, 1.0))
	# The moon casts too, softly. The source game's rule was that nothing casts
	# at night, which was right when night was a blue wash over a drawing; under
	# a real sky it is the opposite -- moonlight that casts is most of what makes
	# a night frame have shape in it without being lifted, which is LANTERN law
	# 3. `casts_at` still says whether the SUN casts, and everything that reads
	# it is unchanged.
	sun.shadow_enabled = cast_allowed and closed < 0.5
	sun.shadow_opacity = maxf(shadow_strength(hour), MOON_SHADOW * (1.0 - lit))
	if figure_light != null:
		# A person still takes a fill of their own in low light, because the
		# player has to read at any hour (docs/ART.md section 5). It is much
		# smaller than it was: the sky is doing the work now, and a fill that
		# beat the sky would put the one warm moving thing on screen in a light
		# nothing in the world is casting.
		figure_light.light_energy = FIGURE_FILL * maxf(low_light(hour), closed)
		figure_light.visible = figure_light.light_energy > 0.01
	if env != null:
		_drive_environment(env.environment, hour, night)


## The sky, the air and the grade, for this hour. The sky is the AMBIENT light
## and the reflection: at night it is a deep indigo dome over a near-black
## ground, which is why a night frame still has form in it without being lifted.
func _drive_environment(e: Environment, hour: float, night: float) -> void:
	var nightly := maxf(night, closed)
	var dusky := clampf(low_light(hour), 0.0, 1.0)
	var mood := Color(weather_tint.x * region_tint.x, weather_tint.y * region_tint.y, weather_tint.z * region_tint.z)
	var top := DAY_SKY_TOP.lerp(DUSK_SKY_TOP, dusky).lerp(NIGHT_SKY_TOP, nightly) * mood
	var hor := DAY_SKY_HORIZON.lerp(DUSK_SKY_HORIZON, dusky).lerp(NIGHT_SKY_HORIZON, nightly) * mood
	var gnd := SKY_GROUND_DAY.lerp(SKY_GROUND_NIGHT, nightly) * mood
	var sm := (e.sky.sky_material if e.sky != null else null) as ProceduralSkyMaterial
	if sm != null:
		sm.sky_top_color = top
		sm.sky_horizon_color = hor
		sm.ground_horizon_color = hor.lerp(gnd, 0.6)
		sm.ground_bottom_color = gnd
		sm.sun_angle_max = lerpf(18.0, 40.0, dusky)
	# The ambient takes the sky's own hue at unit level, so shade is the colour
	# of the sky over it -- blue at noon, warm at dusk, indigo at night -- and
	# the LEVEL is the one number law 3 is measured by.
	var hl := maxf((hor.r + hor.g + hor.b) / 3.0, 0.02)
	# Part of the way to white. The sky's own hue at full strength paints every
	# shadow in the frame the same colour, and shade should be TINTED by the sky
	# rather than made of it -- but this is also the door a LANDSCAPE's own light
	# comes through (`mood`, from BiomeDef.light_tint), so taking it far toward
	# white takes each place's own light away from it. At 0.40 the mean pairwise
	# Lab dE across the six heartlands was 19.5; at 0.26 it is 22.9.
	e.ambient_light_color = Color(hor.r / hl, hor.g / hl, hor.b / hl).lerp(Color(1, 1, 1), 0.26)
	# Under a roof there is no sky to be ambient: what light there is comes off
	# the walls, and it is very little. That is what makes a cave a cave.
	e.ambient_light_energy = lerpf(DAY_AMBIENT, NIGHT_AMBIENT, nightly) * lerpf(1.0, 0.45, closed)
	# The air takes its colour from the sky, so distance separates by atmosphere.
	# Its ENERGY has to fall with the light or the fog stops being air and
	# becomes a lamp: at midnight the ground is at about 0.03 and an unscaled fog
	# colour is ten times that, so the far half of every night frame was being
	# lit by its own haze (measured: it put the median back up to 97 after the
	# ambient and the moon had both been cut to a third).
	e.fog_light_color = hor
	e.fog_light_energy = lerpf(1.0, 0.10, nightly)
	e.fog_density = FOG_DENSITY * lerpf(1.0, 2.1, clampf(fog.z, 0.0, 1.0))
	e.volumetric_fog_albedo = hor.lerp(Color(1, 1, 1), 0.35)
	e.volumetric_fog_ambient_inject = lerpf(0.35, 0.10, nightly)
	# Volumetric air thickens in rain, in mist and at night, which is when a
	# lamp is a cone and a machine's lens is a shaft.
	# On a clear noon there is almost nothing in the air, and a volumetric haze
	# that is always there is the papery veil again by another name.
	e.volumetric_fog_density = VOLUME_DENSITY * lerpf(0.12, 2.4,
		clampf(maxf(fog.z, maxf(air.x, nightly * 0.5)), 0.0, 1.0))
	# The grade, on the finished image. Same inputs the shader's own multiply
	# had; one place that can see the whole frame.
	var g: Vector4 = neon_grade_at(hour, neon_shares)[0]
	# It may only ever DARKEN. `neon_grade.x` goes negative for a landscape that
	# wants to lift itself into daylight, and a lift applied AFTER the tonemapper
	# is a lift with no ceiling over it: the snowfield seen from the pinewood
	# came back with 10% of the frame at pure white, which is the exact failure
	# the old page shoulder existed to stop, wearing a new coat. A landscape that
	# wants to be brighter says so in its own LIGHT (BiomeDef.light_tint reaches
	# the sun and the sky through `mood`), where the tonemapper can still hold it.
	e.adjustment_brightness = clampf(1.0 - g.x * 0.35, 0.55, 1.0)
	e.adjustment_saturation = clampf(1.0 - g.y * 0.30, 0.55, 1.3)
	e.adjustment_contrast = clampf(1.0 + g.w * 0.20, 0.8, 1.35)


## What the land can hold (SkyGround), for snow, ash, wet and fog.
func set_ground(tex: Texture2D, world_size: int) -> void:
	RenderingServer.global_shader_parameter_set("sky_ground", tex)
	ground_scale = 1.0 / maxf(1.0, float(world_size))


## What the land DOES to a thing standing in it (SkyWear): rust, salt, soot,
## frost, by world position. Read by matter_worn() in every lit shader, which is
## LANTERN law 1. Kept apart from set_ground because a realm crossing replaces
## the world and 10_sky hands both over again.
func set_wear(tex: Texture2D) -> void:
	RenderingServer.global_shader_parameter_set("sky_wear", tex)


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


## How much of the dark belongs to this land (sky_shade.w): all of low light,
## except in a warm country, whose evening keeps its own dark warmth (the
## burning glows from below; its clinker must not turn violet at dusk).
## It is what sky_gloom() and the wet ground's day sheen read. The blue floor
## under the washes is NOT this any more: it hung off low light and so came up
## with the eased curve of night fall, which is the whole of art review finding
## 2 — it is `sky_night` now, spent against the light the evening loses.
static func dusk_lift(hour: float, region: Vector3) -> float:
	var warm := clampf((region.x - region.z) * 4.0, 0.0, 0.8)
	return low_light(hour) * (1.0 - warm)


## A low sun lays its warmth on what it lights: lit faces take up to GLOW more
## light at a warm tint while the sun still casts (shade_cool divides it back
## out of shade), so dawn and dusk read warm and clear rather than dim. Held well
## under the level the evening keys give up (1.00 -> 0.80 over 16:48-19:12), or
## the glow simply cancels the fall and dusk is as bright as the afternoon.
const GLOW := 0.12


static func sun_glow(tint: Vector3, sun: Dictionary) -> float:
	var cast := float(sun.get("cast", 1.0 if bool(sun.get("casts", true)) else 0.0))
	if cast <= 0.0:
		return 1.0
	var lum := (tint.x + tint.y + tint.z) / 3.0
	return 1.0 + GLOW * cast * clampf((tint.x - tint.z) / maxf(0.05, lum) * 1.8, 0.0, 1.0)


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
	# `cast` is how much of a shadow is left (shadow_strength); `casts` is only
	# whether there is any. The low-sun glow rides the first of those, because a
	# glow keyed to the second stepped 7% of the frame's light off in one frame
	# at half past eight, in the middle of the smoothest part of the fall.
	return {"azimuth": az, "elevation": el, "energy": 1.0 - nf * (1.0 - NIGHT_LEVEL),
		"casts": casts_at(h), "cast": shadow_strength(h)}


## The hours the sun casts a shadow: from properly up in the morning to the last
## of the dusk. It is stated in hours and not in how far night has fallen,
## because the evening's fall is long now (Weather.DUSK_START) and dusk's LONG
## LOW SHADOWS are the whole picture at 19:30. The moon never casts.
const SHADOW_FROM := 5.0
const SHADOW_TO := 20.5
## How long shadow_strength takes to walk from 1 to 0 at either end of the day.
##
## IT IS NOT A FADE, whatever it reads like. All three lit shaders take the cast
## shadow through `step(0.5, ATTENUATION)` (world.gdshader, found.gdshader,
## water.gdshader), so a face is lit or it is shaded and there is nothing in
## between: every cast shadow in the world goes out in one instant, at the hour
## this constant puts shadow_opacity through a half — 20:07 as it stands. Moving
## that instant is worth about TWENTY VALUES of frame on the coast, a third of
## everything the evening has to spend: widening this to two hours (to spread a
## fade that does not exist) moved the switch to 20:00 and turned the coast's
## half past eight back up by sixteen values, measured.
##
## So 0.75 is not a taste. It lands the switch inside 20:00-20:30, the half hour
## where the light's own fall is steepest and can swallow it. A shadow that
## really faded wants `smoothstep` in place of that `step` in the three lit
## shaders, which is the render package's to give, not the sky's.
const SHADOW_FADE := 0.75


static func casts_at(hour: float) -> bool:
	var h := fposmod(hour, 24.0)
	return h >= SHADOW_FROM and h <= SHADOW_TO


## 0..1 how solid the sun's cast shadow is drawn at this hour.
static func shadow_strength(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	return clampf(minf((h - SHADOW_FROM) / SHADOW_FADE, (SHADOW_TO - h) / SHADOW_FADE), 0.0, 1.0)


## 0 in full daylight, 1 in the dead of night: HOW LITTLE LIGHT THERE IS, which
## is the term everything that only belongs to the dark hangs off (the shader's
## sky_gloom(), Lights.gloom, the figure fill, the blue floor under the washes,
## the lift of the darks at sky_shade.w).
##
## It used to read "how far the tint is from noon", counting a WARM tint as a
## dark one: at 19:00 the tint is warm and the level is 0.82, so it answered 0.89
## while the sun was still at full energy and the land was still bright. Every
## night term came on at once in the middle of a bright evening — the skyglow
## added a blue wash to every surface and the darks were lifted onto night blue —
## which is why dusk measured BRIGHTER and steadily BLUER than the afternoon.
## It is the light's own level now: the tint's luminance times the sun's, and
## never less than how far night has fallen.
static func low_light(hour: float) -> float:
	var t := tint_at(hour)
	var lum := (t.x * 0.3 + t.y * 0.59 + t.z * 0.11) * float(sun_at(hour).energy)
	return clampf(maxf(Weather.night_fall(hour), 1.0 - clampf(lum * 1.25, 0.0, 1.0)), 0.0, 1.0)


## The level of light a lit face takes at this hour: the tint's own luminance,
## the sun's energy and the low-sun glow, in one number. It is what a frame's
## mean brightness follows, and what night_dark() below is measured against.
static func light_level(hour: float) -> float:
	var t := tint_at(hour)
	var s := sun_at(hour)
	return (t.x * 0.3 + t.y * 0.59 + t.z * 0.11) * float(s.energy) * sun_glow(t, s)


## How far the night's own dark has come (the `sky_night` global): how much of
## the night's blue floor is under the washes, and how much skyglow is up.
##
## THE DARK FILLS IN EXACTLY AS FAST AS THE LIGHT GOES — literally: it IS the
## share of the evening's light that has gone. Every term that keeps a dark frame
## readable ADDS light to it, and together the floor and the skyglow are worth
## about a third of a night frame. Hung off how far night has fallen, two thirds
## of that lift landed in the forty minutes either side of a quarter to eight,
## where the light's own fall is at its smallest, so the land measured BRIGHTER
## at eight in the evening than at half past seven (art review finding 2).
##
## The anchors are the last of the day and THE HOUR THE LIGHT ACTUALLY SETTLES.
## That is 21:36, where the last tint key lands (light_level: 0.539 at 20:00,
## 0.442 at 20:30, 0.404 at 21:00, 0.370 from 21:36 on) — not 20:30, where the
## shadows go. Anchored at 20:30 the term hit 1.0 by construction while the light
## still had a sixth of its fall left, and the skyglow — cubed, so most of it was
## still to come — went 0.21 to 1.00 in that one half hour: 80% of a full-frame
## emission spent in thirty minutes. Five landscapes of six measurably turned
## back up there (moss +11.9%, pinewood +10.3%, burning +10.3%, snowfield +5.7%).
##
## It also answers the dawn without a second rule: the light comes back, the term
## goes down. A sky darker than its hour is the other half (weather_dark).
##
## There is no second shaping on top. The earlier `gone / max(here, gone)`
## division was argued from a reading of the shader in which the floor is laid
## on AFTER the light; the floor is written into ALBEDO and the sun multiplies it
## like everything else (see frame_level, which composes what the shader
## composes), so the division only back-loaded the term into the hours where the
## light has nothing left to pay for it.
const DARK_FROM := 18.5
const DARK_FULL := 21.2


## And it is spent a WHISKER behind that, not on the same line, because the sky's
## own dark is not the only thing filling a dusk frame in. Two more arrive early
## and neither is the sky's: the village lamps, which `15_lights.compensate` pins
## to a target brightness, so a pool-lit surface stops getting darker at all once
## it is lit (measured: on the coast the lamps alone almost exactly cancel the
## light's fall between 19:30 and 20:00); and the cast shadows, which all switch
## off in one instant around 20:07 (SHADOW_FADE). Spent on the same line as the
## light, the sky's dark left no room for either and the coast turned back up by
## 1.5 values at eight. The ease is small — the term is still inside a fortieth
## of the light's own fall at every hour — and it is measured, not chosen.
const DARK_EASE := 1.25


static func night_dark(hour: float) -> float:
	var day := light_level(DARK_FROM)
	var gone := light_level(DARK_FULL)
	var here := light_level(hour)
	var gone_share := clampf((day - here) / maxf(1e-4, day - gone), 0.0, 1.0)
	return pow(gone_share, DARK_EASE)


## And the other half of what `sky_night` carries: a sky darker than its hour.
## docs/ART.md section 6 asks the skyglow to keep shapes readable "in dusk, storms
## and night", and a storm at ten in the morning is not the night coming, so it
## cannot be read off the hour. It is read off the WEATHER'S OWN multiply, which
## is the only thing that can darken a sky out of its turn — never off how dark
## the composed light has ended up, which counts a setting sun twice and was half
## of why the evening lifted.
static func weather_dark(tint: Vector3) -> float:
	var lum := tint.x * 0.3 + tint.y * 0.59 + tint.z * 0.11
	return clampf(1.0 - lum * 1.25, 0.0, 1.0)


## How far the skyglow lags the floor. The floor is a lift of a wash the sun then
## multiplies, so it costs less the more light is still up; the skyglow is
## emission over the whole frame at the same strength whatever the hour, so it
## tells most at the very end, when there is nothing left in the darks. Up on the
## same line as the floor it put the evening's last half hour back up by eleven
## values on the coast. Cubed against the OLD anchor it was worse the other way:
## 0.21 to 1.00 in the half hour from eight, which is the rise this package was
## sent back to fix. Against the anchor where the light really settles, it is
## measured: at 2.0 the coast turned up three values at eight in the evening, and
## this is the exponent that holds every half hour of every landscape down.
const GLOW_LAG := 2.5


## The `sky_night` global: x how far the dark has come (the blue floor under the
## washes), y how much skyglow is up.
## A sky darker than its hour is in both at full strength: a storm at ten in the
## morning has a floor AND a glow, and the lag must not take the glow off it.
static func night_terms(hour: float, weather: Vector3) -> Vector2:
	var dark := night_dark(hour)
	var storm := weather_dark(weather)
	return Vector2(maxf(dark, storm), maxf(pow(dark, GLOW_LAG), storm))


## The constants sky.gdshaderinc composes a dark frame with, mirrored here so the
## evening can be measured without a frame (frame_level). tests/sky read them
## back out of the shader source: if one moves there and not here, a test fails.
const NIGHT_FLOOR := Vector3(0.08, 0.10, 0.21)
const NIGHT_KNEE := 0.32
const GLOW_LEVEL := 0.24
const GLOW_FLOOR := 0.033

## HOW MUCH OF A PICTURE EACH NIGHT TERM ACTUALLY REACHES. The shader constants
## above say how strong a term is WHERE IT LANDS; a frame is not all of that.
## The skyglow is emission on lit MADE and FOUND geometry: the sea has its own
## shader, the page behind the land takes none of it, and the ink pass draws over
## a good deal of what does. The floor only lifts the part of a wash the outline
## and the hatching have not already taken.
##
## So these two are MEASURED, not derived: least squares against 78 rendered
## frames (six landscapes x thirteen hours, seed 7, clear, native 640x360, the
## world under the slate's bands), which lands the model within 3.3 values on
## 0-255 across the whole set, and reproduces the 20:30 rise this package was
## sent to kill in the four landscapes the frames show it in. Re-fit them if the
## shader's own composition changes; do not guess them.
const GLOW_REACH := 0.25
const FLOOR_REACH := 0.70


## WHAT A FRAME OF THIS LAND READS AT, on the CPU: sky_apply()'s own arithmetic
## over a bank of washes, for one hour and one landscape's light.
##
## This exists because the rule the evening has to keep — the light falls and
## never turns back — is a rule about the COMPOSED picture, and every term that
## keeps a dark frame readable works on a different part of it. The floor lifts a
## wash under the knee and is then multiplied by the sun; the skyglow is emission
## added on top of everything, unmultiplied; the landscape's mood multiplies the
## tint. A test that watches only the light's own level, or only the floor, can
## be green while the frame turns back up — which is exactly what happened
## (tests/sky/test_night_readable modelled the floor as a multiply ON the light
## and could not see an eleven per cent rise the frames showed).
##
## It is a model, not a render: it says nothing about where the land is dark, only
## what the whole page averages. `region` is the landscape's light (type_light).
static func frame_level(hour: float, region: Vector3, weather := Vector3.ONE) -> float:
	var hue_tint := tint_at(hour)
	var total := hue_tint * region * weather
	var s := sun_at(hour)
	var e := float(s.energy) * sun_glow(hue_tint, s)
	var nt := night_terms(hour, weather)
	var tl := maxf(total.x * 0.3 + total.y * 0.59 + total.z * 0.11, 0.001)
	var hue := total / tl
	var sum := 0.0
	var n := 0
	for a: float in [0.10, 0.16, 0.22, 0.30, 0.40, 0.52, 0.66, 0.82]:
		for shade: float in [1.0, 0.8, 0.6]:
			var c := Vector3.ZERO
			for i in 3:
				var v := a * total[i]
				var fl := NIGHT_FLOOR[i] * nt.x * FLOOR_REACH
				if v < NIGHT_KNEE:
					v = fl + (NIGHT_KNEE - fl) * (v / NIGHT_KNEE)
				c[i] = v * e * shade + (a * hue[i] * GLOW_LEVEL + hue[i] * GLOW_FLOOR) * nt.y * GLOW_REACH
			sum += c.x * 0.3 + c.y * 0.59 + c.z * 0.11
			n += 1
	return sum / float(n)


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
##
## The EVENING is where these rows earn their keep, and where docs/ART.md section 3
## makes its promises by name: the pines and the moss go dark early, the snowfield
## holds its light late and turns blue, the bonelands drop hard off the end of the
## day, the burning's dusk is a furnace and keeps its warmth through the night.
##
## TWO RULES HOLD EVERY ROW, and both are measured findings, not taste.
##
## 1. A ROW'S DUSK IS WHEN IT FALLS, NOT HOW FAR BELOW ITS OWN NIGHT IT DIPS.
## Every row used to dip at dusk and then climb back to a bright midnight key —
## by 5% on the coast, 18% in the moss, 21% on the bonelands. From 21:36 the
## light itself is flat (the last tint key has landed), so every bit of that
## climb after it is a land getting BRIGHTER through the small hours, and the
## part just before it is spent against a fall with almost nothing left. So each
## row carries a SETTLE KEY AT 21:00, worth what its midnight key is worth: the
## dip is recovered while the sun is still going, and from nine o'clock a
## landscape's light does not move again until the morning.
##
## 2. THE MIDNIGHT KEY IS THE NIGHT'S ANCHOR AND IS NOT TOUCHED FOR THE EVENING'S
## SAKE. It lerps the whole way to the noon key, so moving it moves the morning
## too: the snowfield's was pulled down for its blue evening and greyed its
## night by 6% and every 08:00 frame with it.
const MOOD := {
	# The coast's evening is the longest and the shallowest, and goes grey-blue.
	&"coast": [[0.0, Vector3(0.98, 0.99, 1.0)], [12.0, Vector3(0.97, 0.98, 1.0)], [17.0, Vector3(0.96, 0.97, 1.0)], [19.9, Vector3(0.92, 0.95, 1.0)], [20.5, Vector3(0.97, 0.99, 1.0)]],
	# The moss lies under the trees and the water: its dusk is among the first.
	&"moss": [[0.0, Vector3(0.93, 0.97, 0.94)], [6.0, Vector3(0.88, 0.95, 0.9)], [12.0, Vector3(0.95, 0.98, 0.94)], [16.5, Vector3(0.88, 0.94, 0.9)], [18.4, Vector3(0.84, 0.91, 0.88)], [19.5, Vector3(0.84, 0.91, 0.88)], [20.2, Vector3(0.93, 0.97, 0.94)]],
	# Under the pines the light starts going at half five and is gone by seven:
	# by seven the pinewood has lost more of its afternoon than any other land.
	&"pinewood": [[0.0, Vector3(0.95, 0.97, 1.0)], [11.0, Vector3(0.97, 0.98, 0.97)], [15.5, Vector3(0.96, 0.96, 0.96)], [17.4, Vector3(0.88, 0.89, 0.94)], [18.9, Vector3(0.84, 0.86, 0.93)], [19.5, Vector3(0.84, 0.86, 0.93)], [20.5, Vector3(0.95, 0.97, 1.0)]],
	# Snow holds the last of the sun and takes its warmth, then turns hard blue.
	&"snowfield": [[0.0, Vector3(0.94, 0.97, 1.0)], [12.5, Vector3(1.0, 1.0, 1.0)], [16.5, Vector3(0.94, 0.97, 1.0)], [19.4, Vector3(0.79, 1.0, 1.0)], [19.9, Vector3(0.79, 1.0, 1.0)], [20.5, Vector3(0.92, 0.98, 1.0)]],
	# Nothing on the bonelands holds any light: the day ends like a switch.
	&"bonelands": [[0.0, Vector3(1.0, 0.98, 0.96)], [9.0, Vector3(1.0, 0.99, 0.97)], [12.5, Vector3(1.0, 1.0, 1.0)], [16.0, Vector3(1.0, 0.98, 0.94)], [19.4, Vector3(0.93, 0.88, 0.84)], [19.9, Vector3(0.93, 0.88, 0.84)], [20.7, Vector3(1.0, 0.98, 0.96)]],
	# The burning glows from below: its dusk is a furnace and its night stays warm.
	&"burning": [[0.0, Vector3(1.0, 0.92, 0.86)], [12.0, Vector3(1.0, 0.97, 0.94)], [17.0, Vector3(1.0, 0.92, 0.84)], [19.6, Vector3(1.0, 0.86, 0.68)], [19.9, Vector3(1.0, 0.86, 0.68)], [20.7, Vector3(1.0, 0.92, 0.86)]],
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
## Each landscape's own grade offset and how wet it lies are its own
## (`BiomeDef.grade`, `BiomeDef.wet`): the land carries its own evidence
## (GenWorks, WorksMap), so the grade leans a landscape only as far as its
## light — a bleak grey coast, the moss's green gloom kept readable enough to
## see the cuts in it, the pines a shade under their canopy, the snow's cold
## glare, the bones' hard white, the burning's warm low furnace.
## The darkness term goes NEGATIVE where a landscape's own washes are dark, so
## every land reads as day at noon in its own way. Measured mean luma of a clear
## noon frame (seed 7, --hour=12 --weather=clear:0), HUD rows excluded, is the
## check: a dark wood is dimmer than a salt pan, but none of them is night.


## The grade row for a share's key: a landscape type id (what the sky samples)
## or a type index. An unknown landscape reads the coast's.
static func neon_row(key: Variant) -> Array:
	var d := BiomeRegistry.get_def(key) if key is StringName else BiomeRegistry.by_index(int(key))
	if d == null:
		d = BiomeRegistry.by_index(Country.COAST)
	return [d.grade, d.wet]


## What the inland water in view is drawn in (`BiomeDef.water_wash`), blended
## over the same shares as the grade, so a river crossing a border changes
## colour the way the light does. The sea never reads this.
static func water_wash_at(shares: Dictionary) -> Vector4:
	var sum := Vector4.ZERO
	var total := 0.0
	for k: Variant in shares:
		var d := BiomeRegistry.get_def(k) if k is StringName else BiomeRegistry.by_index(int(k))
		# Squared, so the land the camera is actually over carries the water and
		# a sliver of a neighbour at the edge of the frame only softens it. The
		# water is under your feet, not in the air: it belongs to the land it
		# lies in far more than the light does.
		var w := float(shares[k])
		w *= w
		total += w
		if d == null:
			continue
		var c := d.water_wash
		sum += Vector4(c.r, c.g, c.b, 1.0) * (w * c.a)
	if total <= 0.0 or sum.w <= 0.0001:
		return Vector4.ZERO
	return Vector4(sum.x / sum.w, sum.y / sum.w, sum.z / sum.w, clampf(sum.w / total, 0.0, 1.0))


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
