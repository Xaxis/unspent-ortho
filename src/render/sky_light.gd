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
## 20:15 (the sun is low and warm on what it lights, and `day_gone` takes the
## level down under it), and the blue of the sky takes the land over the last
## three quarters of an hour, landing on night where night_fall lands.
## The 21:00 key is short of the night's own blue on purpose: blue is the
## BRIGHTEST channel at night (0.90 against 0.56 red), so a key that went the
## whole way there in the last half hour of the evening measurably LIFTED a
## blue-leaning land like the snowfield just as it should have been settling.
## The last of that blue deepens over 21:00-21:36, under a level that is flat.
## 21:36 (t = 0.90) is where the light stops moving at all, and 16:48 (t = 0.70)
## is where it starts: those two are EVENING_FROM and EVENING_TO, the anchors the
## whole evening is now paced against (`day_gone`).
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
## The sun swings this far either side of the key over the day.
##
## WIDER THAN THE SOURCE'S 70 TOTAL, and on purpose: this camera almost never
## shows sky, so the ONLY way a player senses that a sun is crossing overhead is
## the shadows swinging round under it (owner, 2026-09-18: "we should see or
## sense the orbiting sun ... so we see our night day transitions"). At 35 either
## side the sweep is inside the noise of a shadow's own shape; at 52 a thing you
## walked past in the morning is lit from the other hand by evening.
const SWING := 52.0
const SUNRISE := 4.5
const SUNSET := 21.0
## Shadow length on screen, as a share of the caster's screen height. The ends
## rake much further than the source asked for, for the reason SWING does: a long
## shadow is how a low sun is READ from above, and the difference between noon
## and evening has to be a difference you can see on the ground rather than one
## you can only measure.
const SHADOW_NOON := 0.5
const SHADOW_LOW := 2.10
const MOON_ELEVATION := 58.0
## How solid a moon shadow is. Faint, and softened by SUN_ANGLE_LOW.
const MOON_SHADOW := 0.42
## Display level of the light at the dead of night. The source's rule is 0.58
## (Weather.light_level, which sight still uses), but our terrain albedos are
## darker than its sprites and at 0.58 the land sank to black; 0.70 keeps the
## night blue and the lamps still matter.
const NIGHT_LEVEL := 0.70
## The hour a roofed realm reads as, whatever the clock says (`closed`). It is
## inside the flat stretch past the last tint key (21:36), so the light a cave is
## composed with does not drift with the time of day it cannot see.
const NIGHT_HOUR := 23.0
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
## own in low light (docs/LOOK.md section 5: the player reads at any hour, with
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
## and what the palette is decoded into (matter.gdshaderinc). They are MEASURED
## against the albedo-only frame (the unshaded debug view): sunlit flat ground at
## noon comes back about 1.4x its albedo in linear light, and shade about a fifth
## of that. At 2.10 and 0.55 it came back 2.6x, which put every lit field in the
## filmic shoulder and washed the whole day pale (the shoulder squeezes green
## against red and blue), and a stronger ambient made shade a larger share, not
## a smaller one. Raising one of these without the other undoes one half.

## The sun's energy at noon and the moon's in the dead of night. The gap between
## them and the gap between DAY_AMBIENT and NIGHT_AMBIENT are the whole of why a
## lantern matters.
const SUN_NOON := 1.17
const MOON_NIGHT := 0.115
## How much of the full moon's light a new moon leaves: the sky's own glow and
## the stars. A new-moon night is truly dark where the land has no light of its
## own; the player's fill (FIGURE_FILL) keeps a body readable whatever the moon.
const MOON_NEW := 0.12
## How much of the night's AMBIENT the moon carries: the rest is the sky itself.
const MOON_AMBIENT := 0.4


## How much of the full moon's light there is at phase `p`: 1 full, MOON_NEW new.
static func moon_share(p: float) -> float:
	return lerpf(MOON_NEW, 1.0, 0.5 + 0.5 * cos(TAU * p))
## The sun's angular size, in degrees. Real penumbra: a fence post has a crisp
## shadow at its foot and a soft one four tiles away, which no filter can fake
## and which is most of what says a shadow is cast by something standing up.
## Wider when the light is low, because a low sun is seen through more air.
## Room past the frame's own depth that the sun's one shadow split keeps, so a
## cliff standing behind the player still casts onto the ground in front. Spent
## against the LIVE camera every frame (`_drive_environment`), because the zoom
## moves and a constant range ends the shadows in a line across the picture.
const SHADOW_ROOM := 15.0
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
const DAY_AMBIENT := 0.26
const NIGHT_AMBIENT := 0.21

## And it is the COAST's night. NIGHT_AMBIENT above was measured on the coast's
## mid-value grass, and `lit` said in as many words that one global setting could
## not serve landscapes whose albedos differ by a factor of three. Measured on
## seed 7 at 23:00, bare ground, no village: the coast came back 81.4% under luma
## 24 and the moss bog 95.3%, on one setting. So a landscape says how much of the
## night sky stands over it (`BiomeDef.night_sky`) and the coast stays 1.0.
##
## These two are the floor and the ceiling on what a content file may ask for,
## and they are not negotiable from the content layer: a landscape that could set
## its own night freely could put the ground the player walks on under luma 24,
## which is the `noir` direction that was rejected as unplayable. MOST is the
## other end — a landscape bright enough at midnight to make a lantern pointless
## is not a night either.
const NIGHT_SKY_LEAST := 0.55
const NIGHT_SKY_MOST := 1.80

## --- A LID OVER A LANDSCAPE (`BiomeDef.sky_shut`) ---
##
## What the light is under something that stands between a place and the sun at
## every hour: a smog dome a city still runs its plant for, a gorge, a canopy
## nothing gets through. The HOUR IS UNTOUCHED — the clock, the weather, the
## schedule and the cast shadows all go on running, which is the whole difference
## between this and `closed`, and it is why a landscape may have one and a realm
## still owns the other.
##
## The two numbers below are what a FULL lid leaves, and they are chosen as a
## RATIO to each other rather than for their own sakes, because that ratio is
## what decides whether the hour can still be read off the ground.
##
## Under the open sky the sun is most of the light and the ambient fills the
## shade: SUN_NOON against DAY_AMBIENT, about four to one, so noon and midnight are a
## different world from each other. Under a lid it is the other way round — the
## brightest thing overhead is the lid ITSELF, lit from beneath by whatever the
## place runs at night and from above by a sun it does not let through. So the
## ambient becomes the light and the sun becomes a residue, and the residue is
## what is left of the hour.
##
## LID_SUN is a share of whatever the sun would have been, so it still moves with
## the day and still throws the same shadows in the same direction, only faintly.
## LID_AMBIENT is a LEVEL, not a share, and it does not move with the hour at all
## -- that is the point of it, and it is why a landscape under a full lid measures
## nearly the same at noon and at midnight. The difference that is left is the
## residue: at 0.035 the sun contributes about a fifth of what a lit face takes
## at noon and almost nothing at midnight, so the hour is a thing you can still
## find in the frame and not a thing the frame is about.
##
## A landscape still says its own LEVEL under the lid with `night_sky` (which
## reaches the day as far as the lid is shut) and its own COLOUR with
## `light_tint`. Neither is spelled here, because a lid is not one landscape's.
const LID_AMBIENT := 0.26
const LID_SUN := 0.035
## The underside of the lid: what metal reflects under it, and the hue the shade
## takes. Dirty, warm and dim, because a lid low enough to stop the sun is lit
## from beneath by the place under it. It is multiplied by the landscape's own
## light (`mood`), so a smog dome over sodium lamps and a rock roof over a river
## are the same rule and two different ceilings.
const LID_SKY_TOP := Color(0.115, 0.098, 0.088)
const LID_SKY_HORIZON := Color(0.225, 0.180, 0.142)
const LID_SKY_GROUND := Color(0.070, 0.058, 0.050)

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
const GLOW_INTENSITY := 0.75
const GLOW_BLOOM := 0.15
const GLOW_HDR := 1.05

## Air. Distance is separated by ATMOSPHERE and not by a haze filter -- the fog
## takes its colour from the sun and the sky, so at dusk the far land goes warm
## on the sun's side and cold away from it for nothing.
##
## It is DEPTH fog with a begin and an end, not exponential, and that is forced
## by the camera. Under an orthographic projection exponential fog puts almost
## exactly the same veil over every pixel -- a flat grey wash over the whole
## picture, which is the papery failure again wearing a different coat
## (measured: 18% over the entire first frame).
##
## WHERE it begins and ends is no longer written here. It was (31 and 74), and
## those numbers were chosen against the depth range of the loaded CHUNKS rather
## than of the FRAME: the ground a player can actually see lies between depth
## 25.1 and 34.9, so the air reached about one per cent at the top of the picture
## and distance did nothing at all. `Air.reach()` derives it from the camera that
## is really drawing, so a zoom or a lean cannot put it outside the frame again,
## and `Air.ROWS` says what distance DOES in each landscape -- dark in the bog,
## pale on the snow. See src/render/depth/air.gd; this file only spends it.
## HOW FAR THE EYE SEES, in world units, when the camera looks out to the
## horizon (`sees_horizon`). The one number the eye-level picture is built on:
## the air closes to nothing by here, the camera's far plane is a little past it,
## and the far world and the open sea are drawn at least this far out.
const SEE := 900.0
const FOG_SKY := 0.0
## How much of the depth fog a CLEAR DAY keeps in the top-down frame (see
## `_drive_environment`). Night and fog weather are unaffected.
const DAY_AIR := 0.0
const FOG_AERIAL := 0.22
## Volumetric air, where the tier allows it: this is what makes a lamp in rain a
## CONE and a machine's lens a shaft.
const VOLUME_DENSITY := 0.021
const VOLUME_ANISOTROPY := 0.25
## THE AIR IS A LAYER ON THE GROUND, NOT A COLUMN FROM THE EYE (owner's fc,
## 2026-09-22, on frames of six places under both cameras). Godot integrates an Environment's volumetric density
## along the whole ray from the camera, so the light a lamp sends up crossed
## `CameraRig.distance` of air -- 30 units above the world under ortho, 14.4 under
## the lens -- and a number that changes nothing in the orthographic projection
## decided how much light the air took: the moss at night took 30% off a lit tube
## at arm's length, and pressing Z thinned every fog. A FogVolume standing on the
## ground round the focus makes the path the air a thing actually stands in.
## The gain keeps the ground's optical depth where the column put it under the
## play camera (distance / (AIR_HIGH / sin(pitch))), so a day frame should
## not move; what changes is that a light standing IN the layer crosses only the
## air above it.
## Two units: a lamp or a tube on a post stands at the top of it or above, so
## its CORE reaches the eye at its own colour with the haze round it; at four,
## a stolen tube in the moss arrived at 0.77 of itself (sweep, 2026-09-22).
const AIR_HIGH := 2.0
## At night the layer keeps half the column's thickness, and takes in NO
## ambient light: the column's darkness between lamps was partly the air eating
## them, and a night air lit by the sky is a milky one.
const AIR_NIGHT := 0.5
const AIR_INJECT := 0.0
const AIR_BELOW := 3.0
const AIR_WIDE := 120.0
var _layer: FogVolume

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
## Where the moon is in its month (Weather.moon_phase): 0 full, 0.5 new. Set by
## 10_sky; the moon's light and its disc follow it (`moon_share`).
var moon_phase := 0.0
## Cloud shadows: xy drift offset in tiles, z coverage 0..1, w strength 0..1.
var clouds := Vector4.ZERO
## Fog banks: xy drift offset, z density 0..1, w dust in the air 0..1.
var fog := Vector4.ZERO
## Lightning: 0..1, decays in a few frames.
var flash := 0.0
## Lying snow, ash and wet (Weather.settled), 0..1 each; w spare.
var settle := Vector4.ZERO
## Wind for anything that sways: xy along world x/z, z gust, w phase (see sky.gdshaderinc).
var wind := Vector4.ZERO
## The travelling gust field (WindField): xy its offset in cells, zw its bearing.
var gust := Vector4(0.0, 0.0, 1.0, 0.0)
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
## How much LID is over this place, composed from the landscapes in view
## (`BiomeDef.sky_shut`, blended by `sky_shut_at`). Written here once a frame,
## read by anyone who has to know how dark a place is rather than what o'clock
## it is.
##
## It is the partial, per-landscape companion to `closed` above, and the pair
## divide the work: `closed` says the HOUR HAS STOPPED MATTERING (a realm with a
## roof, all or nothing, 20_realms' to write, and it takes the cast shadows with
## it); this says THE SKY DOES NOT REACH HERE (a landscape's own, partial, and
## the hour goes on running underneath it).
##
## WHY IT IS A FIELD AND NOT A STATIC FUNCTION OF THE HOUR. Everything in this
## game that asks "how dark is it" has asked the clock — `low_light(hour)`,
## `Lights.lamps_wanted(hour)`, `Weather.night_fall(hour)` — and that was exactly
## true while every landscape stood under the same sky. It stops being true the
## moment one of them has a lid on it: a city under a smog dome keeps its street
## lamps burning at noon, because it is dark at noon, and a lamp rule that reads
## the clock turns them all off at half past six in the morning and leaves the
## street a flat murk until seven at night. That was measured, not guessed — it
## is the difference between the slums at 00:00 and at 12:00 on seed 7, and the
## midnight frame is the better picture by a long way.
##
## So this is the seam. A reader that already spends `closed` spends this beside
## it; a reader that spends neither is saying its answer belongs to the clock
## alone, which is still right for a schedule and wrong for a light.
var lid := 0.0
## What set_hour last composed, for systems that tint unlit things (particles,
## lamps) to match the lit world.
var last_tint := Vector3.ONE
var last_energy := 1.0
## The air last composed over the landscapes in view (`Air.at`). Read-only to
## everyone else: the fore layer asks it how thick the air is so an occluder
## sits in the same weather the land behind it does, and a test measures it.
var last_air: Dictionary = Air.DEFAULT.duplicate()
## How far a full dust storm carries the air to the land's dust colour.
const DUST_TAKE := 0.85
## How far a machine typically sees in clear air, in tiles: the middle of the
## roster's `sees` (8..18, most 11..15). A dust storm's air is laid so that
## what it cuts from THIS is what it cuts from the eye (see `_dust_air`).
const SIGHT_TYPICAL := 12.0
## The dust strength past which the air is wholly the storm's: under it the
## storm's reach blends in from the hour's own, so a storm rising is seen coming.
const DUST_FULL := 0.3
## And how far it takes the sky's horizon to that colour (the top a little less).
const DUST_SKY := 0.8
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
## The CompatTrim row this frame was composed with (all ones on Forward+).
var trim: Dictionary = CompatTrim.IDENTITY
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
	RenderingServer.global_shader_parameter_set("sky_linear", 1.0 if decodes() else 0.0)
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
	# The view's depth plus tall land behind it, and no further, so the atlas
	# keeps crisp shadow texels. Re-derived from the LIVE camera every frame in
	# `_drive_environment` — this is only what it opens at.
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


## Whether the palette must be decoded before it is written into ALBEDO on the
## renderer this run is on (matter.gdshaderinc, `sky_linear`).
static func decodes() -> bool:
	return Quality.forward_plus()



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
	e.glow_intensity = GLOW_INTENSITY
	e.glow_bloom = GLOW_BLOOM
	e.glow_hdr_threshold = GLOW_HDR
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Air between the planes of the world, coloured by the sun and the sky. The
	# reach is the play camera's until a real one drives it (`_drive_environment`
	# asks the camera that is drawing), so a headless build_environment() is
	# already truthful about the frame rather than about the loaded chunks.
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	var reach := Air.reach(30.0, 15.0, 57.0)
	e.fog_depth_begin = reach.x
	e.fog_depth_end = reach.y
	e.fog_depth_curve = Air.CURVE
	e.fog_density = Air.DEPTH
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
	var night := maxf(day_gone(hour), closed)
	# And how much LID the landscapes in view have over them, which is the same
	# question asked of a landscape rather than of a realm. Composed here, before
	# anything spends it, because `last_energy` below is one of the things that
	# has to know (see the note under it).
	var shut := sky_shut_at(neon_shares)
	lid = shut
	remember_lid(shut)
	# `closed` says this place reads as NIGHT whatever the clock says (see the
	# field's own header). These two were the last things that did not keep that
	# rule: the hour's tint and the sun's energy were still read straight off the
	# clock, so under a roof every other term in this file had gone to night while
	# these two still said noon.
	#
	# It showed up as a RED LANTERN. 15_lights.compensate divides its warm lamp
	# (0.96, 0.74, 0.53) by `last_tint` per channel and subtracts `last_energy`
	# as a black point. In the caves at noon it was handed a daylight-level tint
	# times the realm's cold blue -- (0.620, 0.680, 0.832) -- and a sun energy of
	# 1.0, so it answered (2.617, 1.204, 0.371) - 1.0, the blue clamped to zero by
	# its own maxf, and the pool came out sRGB (1.00, 0.39, 0.00): a deep red,
	# against the coast's ochre from the same lamp. It was ochre underground at
	# MIDNIGHT and red at noon, which is the tell -- the lamp was fighting a sun
	# that is not there. That breaks LOOK law 2's one thematic rule, a person's
	# light is WARM, and it is the drift a global night setting produces whenever
	# one realm is darker than the coast it was tuned on.
	#
	# So the hour eases to the night key under a roof and the energy to
	# NIGHT_LEVEL, which is exactly what they already read at midnight and why the
	# cave lamp was already correct there. No clamp is added to the lamp: the lamp
	# was never wrong.
	var total := tint_at(hour).lerp(tint_at(NIGHT_HOUR), closed) \
		* season_drain(season_turn) * region_tint * weather_tint
	last_tint = total
	# THE LID IS IN HERE AND THE TINT ABOVE IS DELIBERATELY NOT, and that split is
	# the whole of what makes a smog dome different from a rock roof.
	#
	# `last_energy` is the black point `15_lights.compensate` subtracts, so it has
	# to mean HOW MUCH LIGHT IS ON THIS PLACE. Left on the clock it says the sun is
	# fully up at noon under a dome that stops the sun, and the street lamps then
	# fight a sun that is not there — which is the RED LANTERN above, in a new
	# coat: measured on the slums at seed 7, the pools at noon came out a fraction
	# of the same lamps at midnight, in the same street, under the same lid.
	#
	# The TINT does not take it, because `closed` eases the tint to the NIGHT KEY
	# and the night key is BLUE. That is right for a cave and exactly wrong here:
	# it would take the sodium out of the one landscape in the game whose whole
	# argument is that it is orange. A lid says how MUCH light arrives, not what
	# colour it is; the colour is the landscape's own (`BiomeDef.light_tint`).
	last_energy = 1.0 - maxf(night, shut) * (1.0 - NIGHT_LEVEL)
	RenderingServer.global_shader_parameter_set("sky_tint", total)
	var az: float = s.azimuth
	var el: float = s.elevation
	# At eye level the light stands where the sky draws the sun (`eye_light`).
	var eye := horizon_share(_cam())
	if eye > 0.0:
		el = lerpf(el, eye_light(hour).y, eye)
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
	RenderingServer.global_shader_parameter_set("sky_gust", gust)
	RenderingServer.global_shader_parameter_set("wind_strength", sway)
	# What a lamp, a window and a stolen tube burn by when the SKY is not what
	# made the street dark (`neon_burn`, sky.gdshaderinc). 0 for every landscape
	# under an open sky, so this reaches only the one that asked for a lid.
	RenderingServer.global_shader_parameter_set("sky_lid", shut)
	var texel := 14.0 / 360.0
	if is_inside_tree():
		var cam := get_viewport().get_camera_3d()
		var rows := get_viewport().get_visible_rect().size.y
		if cam != null and rows > 0.0:
			texel = CameraRig.units_per_pixel_of(cam, rows)
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
	# The lid, as a fact the shaders can read (`neon_burn` in sky.gdshaderinc).
	# A NEON face decided whether it was burning off the mean of `sky_tint` alone,
	# which is right under an open sky and wrong under one that is shut: measured
	# on the slums at noon, `sky_tint` means 0.86 and the gate answered 0.24, so
	# every sign in a street drawn dark at noon was burning at a QUARTER — which
	# reads as a city guttering out, and this is the one landscape whose whole
	# argument is that it works.
	RenderingServer.global_shader_parameter_set("sky_lid", shut)
	RenderingServer.global_shader_parameter_set("sky_air", air)
	RenderingServer.global_shader_parameter_set("sky_bolt", bolt)
	RenderingServer.global_shader_parameter_set("sky_focus", Vector4(focus.x, focus.y, focus.z, eye))
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
	var sh := sun_hue_at(hour, total).lerp(total / level, closed)
	var hue := Color(sh.x, sh.y, sh.z)
	# Godot decodes light_color from sRGB, so encode the ratio we mean.
	sun.light_color = hue.linear_to_srgb()
	# What water divides out of its body (water.gdshader): the SUN's hue, as far
	# as the sun is up (`sun_share`). White at noon, so no day frame moves, and
	# white all night, where the light is the moon's and water keeps the night
	# blue it has always had.
	var sun_up := minf(sun_share(hour), 1.0 - closed)
	var own := Vector3.ONE.lerp(sh, sun_up)
	RenderingServer.global_shader_parameter_set("sun_hue", Vector4(own.x, own.y, own.z, 0.0))
	# How much of the night sky stands over the landscapes in view. It scales the
	# moon here and the ambient in _drive_environment, TOGETHER, so the ratio
	# between them — which is what puts shape in a night — is the same in every
	# landscape and only the amount of light differs.
	var ns := night_sky_at(neon_shares)
	# How far the landscapes in view are shut off from the sky
	# (`BiomeDef.sky_shut`). Unlike `ns` it is spent at EVERY hour, because a lid
	# does not know what time it is.
	var lit := 1.0 - maxf(night, closed)
	# What Compatibility's light is counted back by (CompatTrim; all ones on
	# Forward+). Chosen before the sun is lit, because whether the sun casts is
	# what decides which row: a casting sun is a second pass there.
	var casts := cast_allowed and closed < 0.5
	trim = CompatTrim.row(casts and lerpf(MOON_NIGHT, SUN_NOON * level * glow, lit) > 0.0, maxf(night, closed), web_contrast_at(neon_shares))
	CompatTrim.remember(trim)
	# A lid takes the SUN down to a residue and leaves everything else about it
	# alone: the same bearing, the same penumbra, the same shadows, faintly. It is
	# a SHARE and not a level, so what little is left still rises and sets, and
	# that residue is the hour a player can still find in a shut street.
	#
	# AND IT IS THE SUN'S SHARE, NOT THE MOON'S. It used to multiply the whole
	# term, so a lid dimmed the moon as hard as it dimmed the noon sky -- which
	# is backwards twice over. A dome of smog stops the sun; the moon's light is
	# already what NIGHT means, and a lidded landscape's whole argument is that
	# it looks like night. Measured on the city, seed 1, village 1, `--frames=8`:
	# noon 43.9 mean luma against midnight's 34.3, and the noon frame is flat
	# brown murk while the midnight one has lamp pools, cast shadows and depth.
	# Brighter and much worse. `sky_light.gd` already promised the opposite --
	# "a landscape under a full lid measures nearly the same at noon and at
	# midnight" -- and it was not true because the hour still swung the one term
	# that is directional. Taking LID_SUN off the moon is what lets that residue
	# be cut from the noon side without touching the midnight frame at all.
	# The sun on its own evening (`sun_share`, `sun_energy_at`): what is left of
	# it, not what is left of the day. A roof still takes it all.
	var sun_lit := minf(sun_share(hour), 1.0 - closed)
	var keep := lerpf(1.0, _warm_keep(tint_at(hour)), sun_lit if fposmod(hour, 24.0) > EVENING_FROM else 0.0)
	var moon := MOON_NIGHT * ns * moon_share(moon_phase)
	sun.light_energy = lerpf(moon, SUN_NOON * level * keep * glow * lerpf(1.0, LID_SUN, shut) * (1.0 - orbit_shade), sun_lit) \
		* float(trim.sun)
	# THE AIR IS LIT ON THE DAY'S CURVE, NOT THE SUN'S. Looking down, the volumetric
	# bank over the land scatters the sun back into every pixel, and a low amber
	# sun at full strength came out as a brown veil over the whole frame, deepest
	# over the dark sea (canon 12). So the air takes only what the day's curve
	# would have given it; where the horizon is seen the air IS the golden hour,
	# and takes it all.
	var day_energy := lerpf(moon, SUN_NOON * level * glow * lerpf(1.0, LID_SUN, shut) * (1.0 - orbit_shade), lit) * float(trim.sun)
	var air_share := clampf(day_energy / maxf(sun.light_energy, 0.001), 0.0, 1.0)
	sun.light_volumetric_fog_energy = lerpf(air_share, 1.0, horizon_share(_cam()))
	# A low sun is seen through more air, so its edge is softer. Real penumbra,
	# and it is spent against the evening rather than against `el`: the elevation
	# this file computes is chosen to give a SCREEN-SPACE shadow length, not to say
	# how high the sun really is, and it never drops below about 60 degrees in the
	# evening at all — so the widening this constant exists for had never once
	# happened at dusk. On the one curve the shadows soften as they lengthen and
	# fade, which is the whole of what a low sun looks like.
	sun.light_angular_distance = lerpf(SUN_ANGLE, SUN_ANGLE_LOW, clampf(night, 0.0, 1.0))
	# The moon casts too, softly. The source game's rule was that nothing casts
	# at night, which was right when night was a blue wash over a drawing; under
	# a real sky it is the opposite -- moonlight that casts is most of what makes
	# a night frame have shape in it without being lifted, which is LANTERN law
	# 3. `casts_at` still says whether the SUN casts, and everything that reads
	# it is unchanged.
	sun.shadow_enabled = casts
	sun.shadow_opacity = maxf(shadow_strength(hour), MOON_SHADOW * (1.0 - lit))
	RenderingServer.global_shader_parameter_set("sky_emission", float(trim.emission))
	if figure_light != null:
		# A person still takes a fill of their own in low light, because the
		# player has to read at any hour (docs/LOOK.md section 5). It is much
		# smaller than it was: the sky is doing the work now, and a fill that
		# beat the sky would put the one warm moving thing on screen in a light
		# nothing in the world is casting.
		# A lid counts as low light for this, whatever the clock says: under one
		# the street IS as dark as a night, and the player has to read at any hour.
		figure_light.light_energy = FIGURE_FILL * maxf(low_light(hour), maxf(closed, shut))
		figure_light.visible = figure_light.light_energy > 0.01
	if env != null:
		_drive_environment(env.environment, hour, night, ns, shut)


## The camera that is really drawing, or null (headless, or before the rig is in
## the tree). The air is stated in multiples of the frame's own depth, so these
## three are what it is spent on; asked of the live camera rather than of the
## CameraRig's exported defaults, because a target lean and a `--zoom` both move
## the picture and neither of them touches the export.
func _cam() -> Camera3D:
	if not is_inside_tree():
		return null
	return get_viewport().get_camera_3d()


func _cam_size() -> float:
	var c := _cam()
	return c.size if c != null else 15.0


## The fov when a LENS is drawing, and 0 when it is not -- which is how `Air`
## tells the two apart without knowing what a CameraRig is. `_cam_size()` still
## answers for an orthographic camera and is meaningless under a perspective one,
## so nothing may read it without asking this first.
func _cam_fov() -> float:
	var c := _cam()
	return c.fov if c != null and c.projection == Camera3D.PROJECTION_PERSPECTIVE else 0.0


func _cam_pitch() -> float:
	var c := _cam()
	return absf(rad_to_deg(c.rotation.x)) if c != null else 57.0


## How far back the camera stands from what it is looking at. The rig puts it at
## `focus + basis.z * distance` (basis.z points back out of the screen), so the
## depth of the focus is what is left of that along the same axis. Measured off
## the live camera and the live focus rather than off CameraRig.distance, so a
## rig that is moved, or a scene with a camera of its own, still gets air that
## lands inside its own picture.
func _cam_distance() -> float:
	var c := _cam()
	if c == null:
		return 30.0
	return maxf(1.0, (c.global_position - focus).dot(c.global_transform.basis.z))


## The sky, the air and the grade, for this hour. The sky is the AMBIENT light
## and the reflection: at night it is a deep indigo dome over a near-black
## ground, which is why a night frame still has form in it without being lifted.
func _drive_environment(e: Environment, hour: float, night: float, ns: float, shut := 0.0) -> void:
	var nightly := maxf(night, closed)
	var dusky := clampf(low_light(hour), 0.0, 1.0)
	var mood := Color(weather_tint.x * region_tint.x, weather_tint.y * region_tint.y, weather_tint.z * region_tint.z)
	# THE SKY FOLLOWS THE SUN. On the day's curve it went to night while the sun
	# was still up (`sun_share`), and its dusk and its night mixed into one flat
	# lavender-grey at seven. So the SKY's dusk and night are the sun's: warm at
	# the horizon and deep blue overhead while it sets (`sky_dusk`), night only
	# once it has gone. The AMBIENT keeps the day's curve (`hor_amb`), so shade
	# stays the cool it was and the warmth lands where the sun does.
	var sky_night := maxf(closed, minf(nightly, 1.0 - sun_share(hour)))
	var sky_dusky := maxf(dusky, sky_dusk(hour))
	var top := DAY_SKY_TOP.lerp(DUSK_SKY_TOP, sky_dusky).lerp(NIGHT_SKY_TOP, sky_night) * mood
	var hor := DAY_SKY_HORIZON.lerp(DUSK_SKY_HORIZON, sky_dusky).lerp(NIGHT_SKY_HORIZON, sky_night) * mood
	var hor_amb := DAY_SKY_HORIZON.lerp(DUSK_SKY_HORIZON, dusky).lerp(NIGHT_SKY_HORIZON, nightly) * mood
	var top_amb := DAY_SKY_TOP.lerp(DUSK_SKY_TOP, dusky).lerp(NIGHT_SKY_TOP, nightly) * mood
	# And the sun's sky is the SEEN sky's: looking down there is no sky in the
	# frame, only its reflection in every wet thing and the air over the land,
	# and a warm horizon there is a brown veil over the whole picture, sea and
	# all (canon 12). So the sky's own colours are spent as far as the horizon is
	# in frame (`horizon_share`), and from above everything keeps the day's curve.
	var seen := horizon_share(_cam())
	top = top_amb.lerp(top, seen)
	hor = hor_amb.lerp(hor, seen)
	var gnd := SKY_GROUND_DAY.lerp(SKY_GROUND_NIGHT, nightly) * mood
	# In a dust storm the sky is the dust: the horizon goes to the land's own
	# dust at the hour's own level, and the top most of the way after it.
	var sky_dust := clampf(fog.w, 0.0, 1.0)
	if sky_dust > 0.0:
		var dc: Color = Air.at(neon_shares).dust
		var dl := maxf(0.05, dc.get_luminance())
		hor = hor.lerp(dc * (hor.get_luminance() / dl), sky_dust * DUST_SKY)
		top = top.lerp(dc * (top.get_luminance() / dl), sky_dust * DUST_SKY * 0.7)
	# A lid REPLACES the sky rather than dimming it. What is overhead is no longer
	# blue at noon and indigo at midnight: it is the underside of the thing in the
	# way, the same colour at every hour, and it is what metal reflects and where
	# the shade takes its hue. The landscape's own light still multiplies through
	# `mood`, so the lid is that landscape's ceiling and not one grey lid for all.
	if shut > 0.0:
		top = top.lerp(LID_SKY_TOP * mood, shut)
		hor = hor.lerp(LID_SKY_HORIZON * mood, shut)
		gnd = gnd.lerp(LID_SKY_GROUND * mood, shut)
	# The reflected sky is the procedural one even while the seen one is drawn
	# (`_see_sky`): its colours are still worked out here, and handed on.
	var sm := (_plain_sky if _plain_sky != null else (e.sky.sky_material if e.sky != null else null)) as ProceduralSkyMaterial
	if sm != null:
		sm.sky_top_color = top
		sm.sky_horizon_color = hor
		sm.ground_horizon_color = hor.lerp(gnd, 0.6)
		sm.ground_bottom_color = gnd
		sm.sun_angle_max = lerpf(18.0, 40.0, dusky)
	# The ambient takes the sky's own hue at unit level, so shade is the colour
	# of the sky over it -- blue at noon, warm at dusk, indigo at night -- and
	# the LEVEL is the one number law 3 is measured by.
	var hl := maxf((hor_amb.r + hor_amb.g + hor_amb.b) / 3.0, 0.02)
	# Part of the way to white. The sky's own hue at full strength paints every
	# shadow in the frame the same colour, and shade should be TINTED by the sky
	# rather than made of it -- but this is also the door a LANDSCAPE's own light
	# comes through (`mood`, from BiomeDef.light_tint), so taking it far toward
	# white takes each place's own light away from it. At 0.40 the mean pairwise
	# Lab dE across the six heartlands was 19.5; at 0.26 it is 22.9.
	e.ambient_light_color = Color(hor_amb.r / hl, hor_amb.g / hl, hor_amb.b / hl).lerp(Color(1, 1, 1), 0.26)
	# Under a roof there is no sky to be ambient: what light there is comes off
	# the walls, and it is very little. That is what makes a cave a cave.
	#
	# And the NIGHT end of that lerp is the landscape's own now (BiomeDef.night_sky,
	# blended over the shares in view). Only the night end: at noon `nightly` is 0
	# and this term cannot reach the frame at all, which is the property that lets
	# a bog ask for a brighter midnight without touching a single day picture.
	# And under a lid the ambient STOPS WALKING FROM DAY TO NIGHT. It settles on
	# LID_AMBIENT, which does not read the hour at all, and that one substitution
	# is the whole of why a shut landscape measures nearly the same at noon and at
	# midnight: what is left of the difference is the sun's residue (LID_SUN), and
	# where the lid is torn. A landscape still says its own level here — `ns` is
	# on both ends now, so `night_sky` reaches the day as far as the lid is shut,
	# and a landscape that wanted a brighter night gets a brighter street with it.
	var open_sky := lerpf(DAY_AMBIENT, NIGHT_AMBIENT * ns * lerpf(1.0 - MOON_AMBIENT, 1.0, moon_share(moon_phase)), nightly)
	e.ambient_light_energy = lerpf(open_sky, LID_AMBIENT * ns, shut) \
		* lerpf(1.0, 0.45, closed) * float(trim.ambient)
	# The air takes its colour from the sky, so distance separates by atmosphere.
	# Its ENERGY has to fall with the light or the fog stops being air and
	# becomes a lamp: at midnight the ground is at about 0.03 and an unscaled fog
	# colour is ten times that, so the far half of every night frame was being
	# lit by its own haze (measured: it put the median back up to 97 after the
	# ambient and the moon had both been cut to a third).
	# WHICH WAY distance goes is the landscape's (Air.ROWS, docs/LOOK.md law 3):
	# the hour still gives the colour and the air only BENDS it, so dusk is still
	# dusk in the bog -- but the bog bends it down into peat and the snowfield
	# bends it up into glare, and a frame that holds both crossfades between them
	# on the same shares the light and the grade are composed from.
	var a := Air.at(neon_shares)
	last_air = a
	# DUST IS AIR. A dust storm cuts sight by more than half (Weather.SIGHT_CUT)
	# and was drawn as a few streaks over clear air, so a player was unseen in a
	# frame that looked clear. The air takes the land's own dust (Air.dust_of:
	# red iron in the mesas, salt on the flats) and thickens with it.
	var dust := clampf(fog.w, 0.0, 1.0)
	e.fog_light_color = Air.colour(hor, a).lerp(a.dust, dust * DUST_TAKE)
	e.fog_light_energy = lerpf(1.0, 0.10, nightly)
	# Where the tier has no volumetric air, the depth fog stands in for its bank
	# (Quality.ROWS.air_stand_in), so the bog is still thicker than the salt.
	var stand_in := 1.0 + float(Quality.current().get("air_stand_in", 0.0)) * (float(a.bank) - 1.0)
	# Clear daylight takes the depth fog out of the top-down frame. Seen from
	# above, the whole frame lies near one depth, so this fog has no distance
	# to separate: it is one veil over everything, and it was the largest single
	# term in the daytime wash (land p5 +12, saturation -0.03). Night, fog and
	# haze weather keep it. `_look_out` then carries the density to the eye
	# level's own as the shoulder share rises, so the horizon keeps its air. A
	# tier whose depth fog stands in for the volumetric bank keeps it too,
	# because that fog is the only air the tier has.
	var clear_day := 1.0 - maxf(clampf(nightly, 0.0, 1.0), maxf(clampf(fog.z, 0.0, 1.0), dust))
	var day_air := lerpf(1.0, DAY_AIR, clear_day) if float(Quality.current().get("air_stand_in", 0.0)) <= 0.0 else 1.0
	e.fog_density = Air.density(a, lerpf(1.0, 2.1, clampf(fog.z, 0.0, 1.0))) * float(trim.fog) * maxf(stand_in, 0.2) * day_air
	e.glow_intensity = GLOW_INTENSITY * float(trim.glow)
	e.tonemap_exposure = EXPOSURE * float(trim.exposure)
	# And WHERE it lies is the camera's, not a constant: the frame is only about
	# ten units deep, so two numbers written for the loaded chunks left the air
	# entirely outside the picture (Air's header has the measurement).
	var reach := Air.reach(_cam_distance(), _cam_size(), _cam_pitch(), float(a.near), _cam_fov())
	e.fog_depth_begin = reach.x
	e.fog_depth_end = reach.y
	var horizon := horizon_share(_cam())
	# AND SO IS THE SHADOW RANGE, for exactly the same reason. It was 50.0, set
	# once at `_ready` and never asked again, while `--zoom` and now the player's
	# own `+`/`-` write `view_height` directly — so past about 62 the far edge of
	# the frame simply stopped casting, which reads as the shadows ending in a
	# line across the picture. Every other number in this file asks the live
	# camera; this one did not. At the play camera it comes out 49.9 where the
	# constant said 50, which is a quarter of one per cent of the texel density.
	if sun != null:
		sun.directional_shadow_max_distance = _cam_distance() \
			+ Air.frame_depth(_cam_size(), _cam_pitch()) + SHADOW_ROOM
	_look_out(e, sm, a, horizon, nightly)
	_dust_air(e, dust)
	e.volumetric_fog_albedo = Air.colour(hor, a).lerp(a.dust, dust * DUST_TAKE).lerp(Color(1, 1, 1), 0.35 * (1.0 - dust))
	e.volumetric_fog_ambient_inject = lerpf(0.35, 0.10, nightly)
	# Volumetric air thickens in rain, in mist and at night, which is when a
	# lamp is a cone and a machine's lens is a shaft.
	# On a clear noon there is almost nothing in the air, and a volumetric haze
	# that is always there is the papery veil again by another name.
	# A LID IS AIR, and this term did not know it. The thickness was keyed to the
	# hour (`nightly`), so a smog dome at noon — which is the thickest air in the
	# game, being nothing but what is suspended in it — was drawn at the clear-noon
	# floor of 0.12, and a shaft of daylight through a tear in it had no medium to
	# be a shaft IN. It came back as a flat pale decal on the street.
	#
	# It is weighted above night on purpose: a night is dark air and a lid is FULL
	# air, and the one thing the player is meant to walk into here is a column you
	# can see the edges of.
	e.volumetric_fog_density = VOLUME_DENSITY * float(a.bank) * lerpf(0.12, 2.4,
		clampf(maxf(maxf(fog.z, dust * float(a.dust_thick)), maxf(air.x, maxf(nightly * 0.5, shut * 0.35))), 0.0, 1.0))
	_lay_air(e, nightly, horizon)
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
	e.adjustment_saturation = clampf(1.0 - g.y * 0.30, 0.55, 1.3) * float(trim.saturation)
	e.adjustment_contrast = clampf(1.0 + g.w * 0.20, 0.8, 1.35) * float(trim.contrast)


## WHETHER THE CAMERA DRAWING THIS FRAME CAN SEE THE HORIZON: a lens whose top
## edge is level with it or above. That is the eye-level picture (the owner's
## over-the-shoulder view, `96_eye`), and everything about the air and the sky
## changes with it: the land runs out to `SEE`, the sky is DRAWN rather than only
## reflected, and the far edge of the world has to be closed by the air, because
## there is no longer a bottom of the frame to stop at. The shipped orthographic
## camera and the pitched lens (`CameraRig.LENS_PITCH` 40 against half of a 55
## fov) both answer false, so neither changes by a pixel.
static func sees_horizon(cam: Camera3D) -> bool:
	return horizon_share(cam) > 0.0


## HOW MUCH OF THE EYE-LEVEL RULES ARE IN FORCE, 0 (the play camera's) to 1 (the
## horizon's), off how far the top edge of the frame stands below the horizon.
## It is a SHARE and not a switch because a player tips the view with the mouse:
## a boolean put the air, the sky, the shadow and the light over in one frame at
## about 33 degrees down, and every one of them visibly snapped. Every rule that
## differs between the two is spent against this, so no frame of a tilt or of
## the glide down to the shoulder can jump.
##
## The band ends short of the pitched lens and of a lock's lean on it (12.5 and 8
## degrees of margin), so neither ever takes any of it.
static func horizon_share(cam: Camera3D) -> float:
	if cam == null or cam.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return 0.0
	# `basis.z` points back out of the lens, so its `y` is the sine of the pitch
	# DOWN; the top edge stands `fov/2` above the view axis (KEEP_HEIGHT).
	var down := rad_to_deg(asin(clampf(cam.global_transform.basis.z.y, -1.0, 1.0)))
	return smoothstep(HORIZON_FADE_FROM, HORIZON_FADE_TO, down - cam.fov * 0.5)


## Degrees the top edge stands below the horizon where the eye-level rules begin,
## and where they are wholly in force (a little past level, so a top edge a
## degree under the horizon, which already shows the air thinning into nothing,
## is drawn by the same rules as one above it).
const HORIZON_FADE_FROM := 6.0
const HORIZON_FADE_TO := -2.0
## Where the air begins in front of an eye-level camera, in world units, before a
## landscape's own `near`. Past the player and the ground they are working, so a
## fight is never in it; short enough that the middle distance is already air.
const HORIZON_BEGIN := 18.0
## The shape of the air out to `SEE`: linear, so the middle distance is already
## air -- at 1.35 a city a hundred and fifty tiles off stood as sharp and as
## saturated as the street -- and the edge of the world is never seen. A
## landscape's `depth` bends it, so the bog's air comes in sooner than the salt's.
const HORIZON_CURVE := 1.0
## How much of the far land takes the SKY's own colour in the direction it is
## seen, rather than the fog's flat one: all of it, at eye level, so the land at
## the end of the air and the sky above it are the same colour and the join
## between them is never a line.
const HORIZON_AERIAL := 1.0
## THE AIR LAYER, SEEN ALONG ITS LENGTH. From above, a ray crosses the two-unit
## layer in about 2.4 units; from 1.7 units up it runs INSIDE it to the edge of
## the volumetric range, twenty times as much air, and the layer came out as a
## brown wall at dusk and a black band under the night sky. This keeps the air a
## thing a lamp's cone stands in without making it the whole middle distance,
## which is the depth fog's job at eye level.
const HORIZON_LAYER := 0.14
## The sky as it is seen at eye level (sky_eye.gdshader), swapped in for the
## ProceduralSkyMaterial only while the horizon is in frame.
var _seen_sky: ShaderMaterial
var _plain_sky: Material
## Every `dome_*` uniform the seen sky was last given, by name
## (sky_dome.gdshaderinc). Kept so anything standing IN that sky can be given the
## same numbers (`seen_air`) instead of working its own out and drifting.
var _dome: Dictionary = {}
## How high the real sun stands at noon, for the sky's disc and its glow only:
## the LIGHT's own elevation is chosen for a shadow's length on screen.
const SKY_SUN_NOON := 62.0
## How far below the horizon the sun sinks at midnight, for the same.
const SKY_SUN_DEEP := 28.0
## The warm band a low sun lays along the horizon on its own side, in the
## hour's colours: gold as it touches, ember once it has gone.
const SKY_GLOW := Color(1.00, 0.56, 0.30)
const SKY_GLOW_LATE := Color(0.62, 0.26, 0.24)


## Where the sun really is at `hour`, for the SKY: the light's own azimuth, so
## the warm side of the sky is the side the light comes from, and an elevation
## off the clock that rises from SUNRISE, peaks at noon's SKY_SUN_NOON and is
## under the horizon from SUNSET until it rises again.
static func sky_sun(hour: float, azimuth: float) -> Vector3:
	var h := fposmod(hour, 24.0)
	var el: float
	if h >= SUNRISE and h <= SUNSET:
		el = SKY_SUN_NOON * sin(PI * (h - SUNRISE) / (SUNSET - SUNRISE))
	else:
		var night_len := 24.0 - (SUNSET - SUNRISE)
		el = -SKY_SUN_DEEP * sin(PI * fposmod(h - SUNSET, 24.0) / night_len)
	return Basis.from_euler(Vector3(deg_to_rad(-el), deg_to_rad(azimuth), 0.0)).z


## WHERE THE LIGHT COMES FROM AT EYE LEVEL: (azimuth, elevation) in degrees.
##
## The play camera's light is placed for the length of a shadow ON SCREEN
## (`_elevation_for_shadow`) and never drops much below sixty degrees, which is
## right looking down and wrong looking out: at dusk the sun is drawn low on the
## horizon while every shadow says it is overhead. So at eye level the light
## stands where the drawn body is -- the sun by day (`sky_sun`), the moon by
## night -- on the same azimuth the play camera's light has, and is blended to it
## by `horizon_share`, so the orthographic game is untouched.
##
## Never lower than `EYE_LIGHT_LEAST`: a light at the horizon lights nothing and
## throws a shadow the length of the world. The night is the moon rising from
## where the sun set to `MOON_EYE` and down again to where it will rise, so the
## handover at SUNSET and SUNRISE is at one bearing and one height.
static func eye_light(hour: float) -> Vector2:
	var h := fposmod(hour, 24.0)
	return Vector2(float(sun_at(h).azimuth), _eye_elevation(h))


## The eye's elevation alone (see eye_light), which sun_at reads for the evening
## and so cannot ask eye_light for, since that asks sun_at.
static func _eye_elevation(h: float) -> float:
	var el: float
	if h >= SUNRISE and h <= SUNSET:
		el = SKY_SUN_NOON * sin(PI * (h - SUNRISE) / (SUNSET - SUNRISE))
	else:
		var night_len := 24.0 - (SUNSET - SUNRISE)
		el = MOON_EYE * sin(PI * fposmod(h - SUNSET, 24.0) / night_len)
	return maxf(el, EYE_LIGHT_LEAST)


const EYE_LIGHT_LEAST := 7.0
const MOON_EYE := 46.0


func _dome_set(k: StringName, v: Variant) -> void:
	_dome[k] = v
	_seen_sky.set_shader_parameter(k, v)


## THE AIR AND THE SKY AS THE EYE-LEVEL CAMERA SEES THEM THIS FRAME, for a thing
## that stands in both and has to close into them on no line (the colossi,
## src/render/colossus/). `dome` is every uniform the seen sky was handed, by
## name, so a shader that includes sky_dome.gdshaderinc gets the sky's own
## colours; `fog` is the depth fog as `_look_out` left it (begin, end, curve,
## density), which is what the land at the end of the air is drawn through;
## `thick` is the weather's fog; `share` is `horizon_share`. `dome` is empty
## until the horizon has been in frame once.
func seen_air() -> Dictionary:
	var e: Environment = env.environment if env != null else null
	var f := Vector4.ZERO
	if e != null:
		f = Vector4(e.fog_depth_begin, e.fog_depth_end, e.fog_depth_curve, e.fog_density)
	var out := {"dome": _dome, "fog": f, "thick": clampf(fog.z, 0.0, 1.0), "share": horizon_share(_cam())}
	# The sun's own disc as the procedural sky draws it (its LIGHT0), which the
	# seen sky blends in across the band where the horizon comes into frame.
	if sun != null and sun.visible:
		out["l0_dir"] = sun.global_transform.basis.z
		out["l0_size"] = deg_to_rad(sun.light_angular_distance)
		out["l0_color"] = sun.light_color
		out["l0_energy"] = sun.light_energy
	return out


## The sky that is seen, filled from the same colours the reflected one was.
func _see_sky(e: Environment, sm: ProceduralSkyMaterial, hour: float, nightly: float, seen := 1.0) -> void:
	if e.sky == null:
		return
	if _seen_sky == null:
		_seen_sky = ShaderMaterial.new()
		_seen_sky.shader = preload("res://src/render/sky_eye.gdshader")
		_plain_sky = e.sky.sky_material
	if e.sky.sky_material != _seen_sky:
		e.sky.sky_material = _seen_sky
	var s := sun_at(hour)
	var dir := sky_sun(hour, float(s.azimuth))
	_dome_set(&"dome_seen", clampf(seen, 0.0, 1.0))
	# The procedural sky's own numbers, so at `seen` 0 this IS that sky.
	_dome_set(&"dome_p_top", sm.sky_top_color)
	_dome_set(&"dome_p_horizon", sm.sky_horizon_color)
	_dome_set(&"dome_p_ground_horizon", sm.ground_horizon_color)
	_dome_set(&"dome_p_ground_bottom", sm.ground_bottom_color)
	_dome_set(&"dome_p_sky_curve", sm.sky_curve)
	_dome_set(&"dome_p_ground_curve", sm.ground_curve)
	_dome_set(&"dome_p_sun_angle_max", deg_to_rad(sm.sun_angle_max))
	_dome_set(&"dome_p_sun_curve", sm.sun_curve)
	_dome_set(&"dome_p_sky_energy", sm.sky_energy_multiplier)
	_dome_set(&"dome_p_ground_energy", sm.ground_energy_multiplier)
	_dome_set(&"dome_top_color", sm.sky_top_color)
	_dome_set(&"dome_horizon_color", sm.sky_horizon_color)
	_dome_set(&"dome_ground_color", sm.ground_bottom_color)
	_dome_set(&"dome_sun_dir", dir)
	# The moon stands where the night's light comes from (`eye_light`), so a
	# shadow at eye level falls away from the moon that is drawn.
	var ml := eye_light(hour)
	var moon := Basis.from_euler(Vector3(deg_to_rad(-ml.y), deg_to_rad(ml.x), 0.0)).z
	_dome_set(&"dome_moon_dir", moon)
	# Its phase, for the disc's terminator: 0 full, 0.5 new.
	_dome_set(&"dome_moon_phase", moon_phase)
	# The glow belongs to a sun near the horizon: from a little above it until
	# well after it has gone, and not at all in the dead of night.
	# From the golden hour (the drawn sun under about 38 degrees), not only once
	# it is touching the horizon: at seven it stood at 23 and had no glow at all.
	var low := 1.0 - smoothstep(0.02, 0.62, dir.y)
	var gone := smoothstep(-0.02, -0.34, dir.y)
	_dome_set(&"dome_glow", low * (1.0 - gone) * (1.0 - clampf(clouds.z, 0.0, 1.0) * 0.6))
	_dome_set(&"dome_glow_color", SKY_GLOW.lerp(SKY_GLOW_LATE, smoothstep(0.05, -0.12, dir.y)) * Color(weather_tint.x, weather_tint.y, weather_tint.z))
	_dome_set(&"dome_sun_color", sun.light_color if sun != null else Color(1, 1, 1))
	_dome_set(&"dome_night", clampf(nightly, 0.0, 1.0))
	# The weather's own cover: cloud shadows' coverage, and rain or snow under it.
	var wet := clampf(1.0 - (weather_tint.x + weather_tint.y + weather_tint.z) / 3.0, 0.0, 1.0)
	_dome_set(&"dome_cover", clampf(maxf(clouds.z, wet * 2.2), 0.0, 1.0))
	_dome_set(&"dome_cloud_dark", clampf(clouds.w * 0.6 + wet * 1.5, 0.0, 1.0))
	_dome_set(&"dome_drift", Vector2(clouds.x, clouds.y))


## The sun's shadow at eye level: four splits out to this far, fading at the end.
## One orthogonal split fitted to the frame's depth (the play camera's rule) is a
## band sixty units deep, and from 1.7 units up its far edge is a line drawn
## across the middle of the land.
const HORIZON_SHADOW := 140.0


## The air, the sky and the shadow, carried from the play camera's rules to the
## eye-level ones by `share` (`horizon_share`). The play camera's values are
## already written when this is called, so each field is a blend from them; at 0
## every field is exactly what the play camera has, so nothing a horizon frame
## changes is left behind for the next top-down one.
##
## Two things cannot be blended, and each changes where it cannot be seen: the
## background (no sky pixel is in frame until the top edge reaches the horizon,
## deep inside the band) and the seen sky, which at `seen` 0 draws exactly the
## procedural sky it replaces (sky_eye.gdshader), so what metal reflects does not
## jump either. The shadow's split mode is the third, and changes at the band's
## top edge, where its range is still the play camera's.
func _look_out(e: Environment, sm: ProceduralSkyMaterial, a: Dictionary, share: float, nightly: float) -> void:
	var w := clampf(share, 0.0, 1.0)
	if w <= 0.0:
		e.background_mode = Environment.BG_COLOR
		if _plain_sky != null and e.sky != null and e.sky.sky_material != _plain_sky:
			e.sky.sky_material = _plain_sky
		e.fog_depth_curve = Air.CURVE
		e.fog_aerial_perspective = FOG_AERIAL
		if sun != null:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_blend_splits = false
			sun.directional_shadow_fade_start = 0.8
		return
	var thick := clampf(fog.z, 0.0, 1.0)
	var see := SEE / lerpf(1.0, 3.5, thick)
	e.background_mode = Environment.BG_SKY
	e.fog_depth_begin = lerpf(e.fog_depth_begin, HORIZON_BEGIN * float(a.near) / lerpf(1.0, 2.0, thick), w)
	e.fog_depth_end = lerpf(e.fog_depth_end, see, w)
	e.fog_depth_curve = lerpf(Air.CURVE, HORIZON_CURVE / clampf(float(a.depth), 0.4, 2.5), w)
	e.fog_density = lerpf(e.fog_density, 1.0, w)
	e.fog_aerial_perspective = lerpf(FOG_AERIAL, HORIZON_AERIAL, w)
	if sm != null:
		# The distance is the sky's colour, and the sky's horizon is the
		# landscape's air: the same `Air.colour` the depth fog was drawn in,
		# so a bog still closes into peat and the snow into glare. The ground
		# half of the dome is the same colour at the horizon, so the far edge
		# of the land and the sky meet on no line at all.
		var bent := Air.colour(sm.sky_horizon_color, a)
		sm.ground_horizon_color = sm.ground_horizon_color.lerp(bent, w)
		sm.sky_horizon_color = sm.sky_horizon_color.lerp(bent, w)
		# Under a lid (`BiomeDef.sky_shut`) there are no stars and no moon to
		# see: the slums at midnight showed a starfield through their smog.
		_see_sky(e, sm, clock_hour, nightly * (1.0 - last_lid()), w)
	if sun != null:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_max_distance = lerpf(sun.directional_shadow_max_distance, HORIZON_SHADOW, w)
		sun.directional_shadow_blend_splits = true
		sun.directional_shadow_fade_start = lerpf(0.8, 0.75, w)


## WHERE A MACHINE CANNOT SEE YOU, YOU CANNOT SEE FAR EITHER. A dust storm cuts
## sight by Weather.SIGHT_CUT; the air it draws is laid from the same number, so
## the picture and the rules agree: clear from the eye to the player, then
## closing to the air's cap at the distance a typical machine still sees at this
## strength. Air.MOST's cap stands (a threat close in is never lost in it), and
## the eye level's own denser horizon is never thinned. The land's `thick` is
## character only (the volumetric bank), never the reach.
## Where a dust storm's air begins and closes, in depth from the eye, for a
## focus `at` deep: clear to the player, closed at what a machine still sees.
static func dust_reach(at: float, dust: float) -> Vector2:
	return Vector2(at * 0.96, at + SIGHT_TYPICAL * Weather.sight_factor(&"dust", clampf(dust, 0.0, 1.0)))


func _dust_air(e: Environment, dust: float) -> void:
	if dust <= 0.0:
		return
	var k := smoothstep(0.0, DUST_FULL, dust)
	var r := dust_reach(_cam_distance(), dust)
	e.fog_depth_begin = lerpf(e.fog_depth_begin, r.x, k)
	e.fog_depth_end = lerpf(e.fog_depth_end, r.y, k)
	e.fog_depth_curve = lerpf(e.fog_depth_curve, 1.0, k)
	e.fog_density = lerpf(e.fog_density, maxf(e.fog_density, Air.MOST), k)


## The column's density moved into the layer (see AIR_HIGH).
func _lay_air(e: Environment, nightly: float, horizon := 0.0) -> void:
	# ONLY WHERE THE TIER HAS VOLUMETRIC AIR (its own `volumetric` column, which
	# built `e`). Compatibility cannot compile a fog shader at all: a FogVolume
	# built on the web tier logged "shader type fog not supported in OpenGL
	# renderer" on every boot and failed the browser proof. There the depth fog
	# stands in (`air_stand_in`), and no layer may exist.
	if not e.volumetric_fog_enabled:
		if _layer != null:
			_layer.free()
			_layer = null
		return
	if _layer == null:
		_layer = FogVolume.new()
		_layer.name = "air_layer"
		_layer.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		var fm := FogMaterial.new()
		fm.edge_fade = 0.35
		_layer.material = fm
		add_child(_layer)
	var fm := _layer.material as FogMaterial
	var gain := 30.0 / (AIR_HIGH / 0.8387)
	fm.density = e.volumetric_fog_density * gain * lerpf(1.0, AIR_NIGHT, clampf(nightly, 0.0, 1.0)) \
		* lerpf(1.0, HORIZON_LAYER, clampf(horizon, 0.0, 1.0))
	e.volumetric_fog_ambient_inject = lerpf(e.volumetric_fog_ambient_inject, AIR_INJECT, clampf(nightly, 0.0, 1.0))
	fm.albedo = e.volumetric_fog_albedo
	e.volumetric_fog_density = 0.0
	_layer.size = Vector3(AIR_WIDE, AIR_HIGH + AIR_BELOW, AIR_WIDE)
	_layer.global_position = Vector3(focus.x, focus.y + (AIR_HIGH - AIR_BELOW) * 0.5, focus.z)


## What the land can hold (SkyGround), for snow, ash, wet and fog.
func set_ground(tex: Texture2D, world_size: int) -> void:
	RenderingServer.global_shader_parameter_set("sky_ground", tex)
	ground_scale = 1.0 / maxf(1.0, float(world_size))


## What the land DOES to a thing standing in it (SkyWear): rust, salt, soot,
## frost, by world position. Read by matter_worn() in every lit shader, which is
## LANTERN law 1. Kept apart from set_ground because a realm crossing replaces
## the world and 10_sky hands both over again.
func set_wear(tex: Texture2D, growth: Texture2D = null) -> void:
	RenderingServer.global_shader_parameter_set("sky_wear", tex)
	# And how far each land's growth has taken what was built in it
	# (SkyWear.growth_texture). None, and nothing grows on anything.
	RenderingServer.global_shader_parameter_set("sky_growth", growth)


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
		# THE EVENING SUN GOES DOWN. The play light above is placed for a
		# shadow's length on screen and never dropped under about 46 degrees, so
		# the golden hour had a sun standing overhead in it. From LOWER_FROM it
		# comes down onto the eye's own arc (`_eye_elevation`, never under
		# SUN_LEAST), so the play camera and the eye see one low sun; and over
		# the last of the day it hands over to where the moon rises, while its
		# own light is going (`sun_share`), so the light never jumps at SUNSET.
		if h > LOWER_FROM:
			var low := minf(el, maxf(_eye_elevation(h), SUN_LEAST))
			el = lerpf(el, low, smoothstep(LOWER_FROM, LOWER_TO, h))
			el = lerpf(el, _elevation_for_shadow(az, SHADOW_LOW), smoothstep(HANDOVER, SUNSET, h))
	else:
		# The moon walks the bearing back overnight, from where the sun set to
		# where it will rise, riding higher at midnight.
		var night_len := 24.0 - (SUNSET - SUNRISE)
		var n := fposmod(h - SUNSET, 24.0) / night_len
		az = KEY_AZIMUTH + lerpf(SWING, -SWING, n)
		var edge := _elevation_for_shadow(az, SHADOW_LOW)
		el = lerpf(edge, MOON_ELEVATION, sin(n * PI))
	var nf := day_gone(h)
	# `cast` is how much of a shadow is left (shadow_strength); `casts` is only
	# whether there is any. The low-sun glow rides the first of those, because a
	# glow keyed to the second stepped 7% of the frame's light off in one frame
	# at the hour the sun stopped casting, in the middle of the smoothest part of
	# the fall.
	return {"azimuth": az, "elevation": el, "energy": 1.0 - nf * (1.0 - NIGHT_LEVEL),
		"casts": casts_at(h), "cast": shadow_strength(h)}


## THE EVENING, AS ONE CURVE: how much of the day's light has gone, 0 in full
## daylight and 1 once the light has settled for the night.
##
## It replaced two schedules that only ever overlapped for forty minutes, which
## is the whole of the defect. The SKY's evening was the tint keys, whose level
## falls from t=0.70 (16:48) and is flat again by t=0.80 (19:12); the BODY's
## night was `Weather.night_fall`, a smoothstep still at zero at 18:30 that does
## all of its work by 21:00. So from five to half past six nothing moved but the
## tint, and from seven to half past eight the smoothstep moved alone, at its
## steepest. Measured on the coast at seed 7, half hour by half hour, the frame
## fell 3.4, 2.6, 5.5, 9.8 values and then 22.3, 23.3, 22.8 — three half hours
## carrying four times what the first three did. That is the cliff, and no
## reshaping of either schedule ON ITS OWN could have taken it out, because each
## of them is flat exactly where the other is steep.
##
## The anchors are the tint keys' OWN shoulders, which is what makes this one
## curve rather than a third: 16:48 is where KEYS begins giving up level and
## 21:36 is where it lands and stops moving at all. The sun's handover to the
## moon, the ambient's fall, the sky's colours, the cast shadow, the sun's
## penumbra, the blue floor, the skyglow and the grade are all spent against this
## now, so there is no hour at which one of them has finished and another has not
## started.
##
## `Weather.night_fall` is untouched and still means what it always did — it is
## the rest of the game's word for "it is night" (the lamps, the mobs, the score,
## the hazards) — and this curve only says how the LIGHT is spent. Outside the
## evening the two agree by construction: night_fall is 0 at EVENING_FROM and 1
## at EVENING_TO, and it still owns the dawn, unchanged.
const EVENING_FROM := 16.8
const EVENING_TO := 21.6
## The evening lingers and then goes, rather than walking down a straight line.
## It is MEASURED, not chosen: what a half hour of it buys was modelled against
## ten rendered coast frames (mean luma of the world band the tour crops to; the
## fit lands within 1.1 values on 0-255), and the model was then swept over
## EVENING_FROM, EVENING_TO and this exponent for the flattest evening. At 1.35
## the coast's nine half hours fall 8.9, 10.2, 10.8, 11.0, 10.3, 10.4, 10.7, 10.9
## and 11.2 values, against a spread of 3.1 to 25.4 before. Lower flattens it a
## little further and costs the afternoon its light; higher buys a brighter seven
## o'clock and steepens the last hour, which is where the budget is tightest
## because the sky dome is going to night there as well (1.5 was tried: 19:00 kept
## three more values and the last half hour cost one more than it gained).
const EVENING_EASE := 1.35


## 0 in full daylight, 1 once the light has settled: THE curve (see above).
static func day_gone(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h <= EVENING_FROM or h >= EVENING_TO:
		return Weather.night_fall(h)
	return pow((h - EVENING_FROM) / (EVENING_TO - EVENING_FROM), EVENING_EASE)


## THE GOLDEN HOUR. `day_gone` is how much of the DAY's light has gone, and the
## sun used to be spent against it with everything else, so by seven it was at
## half its energy while it was still up and only then turning low and warm:
## measured, 0.58 of noon's 1.17 at 19:00 and 0.39 at 20:00, at the hour the
## evening is meant to be most itself (docs/LOOK.md, dusk). The sky, the
## ambient and the night keep the one curve; the SUN keeps its own: it stays up
## at nearly full strength, low and amber, raking, until it is on the horizon,
## and goes out between SUN_DOWN_FROM and SUNSET. The half hour after that is
## the blue hour -- no sun, the ambient still falling on the one curve -- into a
## night nothing here touches.
##
## The sun starts coming down at LOWER_FROM, is on the eye's arc by LOWER_TO,
## and from HANDOVER walks to where the moon rises.
const LOWER_FROM := 16.0
const LOWER_TO := 17.5
const HANDOVER := 20.4
const SUN_DOWN_FROM := 19.7
## The lowest the evening sun stands before the handover: a player's shadow is
## about seven of their own heights long on the play camera's screen at this.
const SUN_LEAST := 20.0
## The evening sun's own colour, hour -> hue (mean 1), from white through gold to
## deep amber on the horizon. A hue and not a level: `sun_energy_at` says how much.
const SUN_KEYS := [
	[16.0, Vector3(1.00, 1.00, 0.99)],
	[17.5, Vector3(1.10, 0.99, 0.91)],
	[18.5, Vector3(1.28, 0.97, 0.75)],
	[19.5, Vector3(1.50, 0.92, 0.58)],
	[20.3, Vector3(1.62, 0.86, 0.52)],
	[21.0, Vector3(1.62, 0.84, 0.54)],
]


## How much of the SUN is still in the sky, 0..1: the day's own curve outside
## the evening (so the morning and the night are what they were), and in the
## evening full until SUN_DOWN_FROM and gone at SUNSET.
static func sun_share(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h <= EVENING_FROM or h >= EVENING_TO:
		return 1.0 - day_gone(h)
	return 1.0 - smoothstep(SUN_DOWN_FROM, SUNSET, h)


## How far the SKY has gone to its dusk colours, 0..1, by the sun: from the
## start of its lowering to the moment it sets. 0 outside the evening, where the
## sky's dusk is the day's low light as it always was.
static func sky_dusk(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h <= EVENING_FROM or h >= EVENING_TO:
		return 0.0
	return smoothstep(LOWER_TO, SUNSET - 0.4, h)


## The hour's tint's brightest channel over its mean: how much a warm tint's
## MEAN undersells the sun in it. The keys' level falls as the tint warms, and a
## sun whose energy follows the mean of an amber tint goes dim for being amber.
## 1.0 at a white tint, so noon does not move.
static func _warm_keep(t: Vector3) -> float:
	var lum := maxf((t.x + t.y + t.z) / 3.0, 0.001)
	return maxf(t.x, maxf(t.y, t.z)) / lum


## The evening sun's hue at `hour` (SUN_KEYS), or white outside it.
static func sun_key(hour: float) -> Vector3:
	var h := fposmod(hour, 24.0)
	if h <= float(SUN_KEYS[0][0]) or h > EVENING_TO:
		return Vector3(1, 1, 1) if h <= float(SUN_KEYS[0][0]) else SUN_KEYS[SUN_KEYS.size() - 1][1]
	for i in SUN_KEYS.size() - 1:
		var a: Array = SUN_KEYS[i]
		var b: Array = SUN_KEYS[i + 1]
		if h <= float(b[0]):
			return (a[1] as Vector3).lerp(b[1], (h - float(a[0])) / (float(b[0]) - float(a[0])))
	return SUN_KEYS[SUN_KEYS.size() - 1][1]


## The sun's energy at `hour` under a composed light `total` (tint x region x
## weather): what compose() gives the DirectionalLight before the lid, the
## orbit's shade and the web's count-back. `moon` is the night's share of it.
static func sun_energy_at(hour: float, total: Vector3, moon: float = MOON_NIGHT) -> float:
	var level := maxf((total.x + total.y + total.z) / 3.0, 0.02)
	var t := tint_at(hour)
	var keep := lerpf(1.0, _warm_keep(t), sun_share(hour) if fposmod(hour, 24.0) > EVENING_FROM else 0.0)
	return lerpf(moon, SUN_NOON * level * keep * sun_glow(t, sun_at(hour)), sun_share(hour))


## The sun's hue (mean 1) under a composed light: the composed light's own hue
## with the evening sun's colour laid over the hour's, so a landscape's cast
## survives and the evening sun is amber on every land. Handed back to the
## composed hue as the sun goes, so the moon takes the night's own colour.
static func sun_hue_at(hour: float, total: Vector3) -> Vector3:
	var level := maxf((total.x + total.y + total.z) / 3.0, 0.02)
	var hue := total / level
	var h := fposmod(hour, 24.0)
	if h <= float(SUN_KEYS[0][0]) or h >= EVENING_TO:
		return hue
	var t := tint_at(h)
	var th := t / maxf((t.x + t.y + t.z) / 3.0, 0.001)
	var amber := sun_key(h) / Vector3(maxf(th.x, 0.05), maxf(th.y, 0.05), maxf(th.z, 0.05))
	var warm := hue * amber
	warm /= maxf((warm.x + warm.y + warm.z) / 3.0, 0.001)
	return hue.lerp(warm, sun_share(h))


## The hours the sun casts a shadow: from properly up in the morning until it
## SETS. It used to stop at 20:30, half an hour before `SUNSET`, which is a third
## schedule disagreeing with the other two — at half past eight the sun was still
## the brightest thing in the frame and had stopped throwing anything. The moon
## never casts; it takes the shadow over through MOON_SHADOW.
const SHADOW_FROM := 5.0
const SHADOW_TO := SUNSET
## How long shadow_strength takes to walk from 1 to 0 at either end of the day.
##
## The comment that stood here said this was NOT a fade, because all three lit
## shaders took the cast shadow through `step(0.5, ATTENUATION)` and every shadow
## in the world therefore went out in one instant. That was true of the
## wash-and-ink pipeline and it is not true now: `lit` deleted every `light()`
## function in the game, there is no ATTENUATION left anywhere in src/, and
## `shadow_opacity` is a real continuous fade that this constant is the length
## of. The old 0.75 was chosen to land an instant inside the steepest half hour
## it could find, which stopped being a reason when the instant did.
##
## 1.2 runs the fade from 19:48 to sunset, so half past seven still throws the
## long hard warm shadows that are the best thing in the evening, and they
## lengthen, soften (SUN_ANGLE_LOW, spent against `day_gone` now) and fade out
## onto the moon's own instead of stopping.
const SHADOW_FADE := 1.2


## Whether there is any sun shadow left at all. Strict at SHADOW_TO, so the sun
## has stopped casting BY sunset rather than at it.
static func casts_at(hour: float) -> bool:
	var h := fposmod(hour, 24.0)
	return h >= SHADOW_FROM and h < SHADOW_TO


## 0..1 how solid the sun's cast shadow is drawn at this hour.
static func shadow_strength(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	# The evening's shadow goes out WITH the sun (`sun_share`), so the long warm
	# shadows last as long as the light that throws them.
	var evening := sun_share(h) if h > EVENING_FROM and h < SHADOW_TO else (0.0 if h >= SHADOW_TO else 1.0)
	return clampf(minf((h - SHADOW_FROM) / SHADOW_FADE, evening), 0.0, 1.0)


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
	return clampf(maxf(day_gone(hour), 1.0 - clampf(lum * 1.25, 0.0, 1.0)), 0.0, 1.0)


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
## It IS `day_gone` now, which is what the sentence above claims and what the
## term could not do while the light was spent on a different schedule from it.
## The anchors used to be two hours (18:30 and 21:12) read off `light_level`, a
## DISPLAY model that falls by a factor of 1.7 across the evening while the light
## the renderer is actually driven by falls by a factor of thirteen. Hung on the
## one curve the term cannot outrun the light: it lands at 21:36 because that is
## where the light lands.
##
## AND NEITHER THIS NOR THE SKYGLOW REACHES A FRAME UNDER LANTERN. `sky_night` is
## declared in sky.gdshaderinc and sampled by nothing; `neon_skyglow` returns
## vec3(0.0). The blue floor under the washes and the emission over every surface
## are gone, and NIGHT_AMBIENT and MOON_NIGHT are what make a night dark now. So
## this is kept coherent for whoever draws it again, and no number in it is
## evidence about a picture — which is also the reason the last half hour of the
## evening turned back UP on main and nothing here could have been blamed for it.
##
## What that rise really was, measured on seed 7 at 21:00 against 21:30, clear:
## on bare coast the frame moved -0.29 values, and at the village it moved +2.10.
## The light was identical at both hours (night_fall is 1 from 21:00, so the sun
## sat at MOON_NIGHT and the ambient at NIGHT_AMBIENT), but the TINT was still
## falling, and `15_lights.compensate` divides its warm lamp by `last_tint` and
## subtracts `last_energy` as a black point — so the village lamps went on getting
## brighter after the light had nothing left to pay for them. The one curve fixes
## it by giving those thirty-six minutes a real twilight to spend: the same pair
## now falls 12.35 values at the village and 13.29 on bare coast.
##
## It still answers the dawn without a second rule — `day_gone` is night_fall
## there — and a sky darker than its hour is still the other half (weather_dark).


## And it is spent a WHISKER behind the light, not on the same line, because the
## sky's own dark is not the only thing filling a dusk frame in. Two more arrive
## early and neither is the sky's: the village lamps, which `15_lights.compensate`
## pins to a target brightness, so a pool-lit surface stops getting darker at all
## once it is lit (measured: on the coast the lamps alone almost exactly cancel
## the light's fall between 19:30 and 20:00); and the cast shadows, which give up
## most of their strength over SHADOW_FADE. Spent on the same line as the light,
## the sky's dark left no room for either and the coast turned back up by 1.5
## values at eight. The ease is small — the term is still inside a fortieth of
## the light's own fall at every hour. It WAS measured, on frames the shaders no
## longer draw (see night_dark above): it is kept because the shape is right, not
## because anything today moves with it.
const DARK_EASE := 1.25


static func night_dark(hour: float) -> float:
	return pow(day_gone(hour), DARK_EASE)


## And the other half of what `sky_night` carries: a sky darker than its hour.
## docs/LOOK.md section 6 asks the skyglow to keep shapes readable "in dusk, storms
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


## WHAT A FRAME OF THIS LAND READS AT, on the CPU: the two numbers the renderer
## is actually driven by, over a bank of albedos and faces.
##
## IT USED TO COMPOSE sky_apply(): a blue floor lifted under every wash below a
## knee, and a skyglow emitted over everything, with two MEASURED reach constants
## fitted against 78 rendered frames. Every one of those was true of the
## wash-and-ink pipeline and none of it is drawn any more — `sky_night` is
## declared in sky.gdshaderinc and sampled by nothing, and `neon_skyglow` returns
## vec3(0.0). What makes a night dark now is NIGHT_AMBIENT and MOON_NIGHT on real
## lights.
##
## That mattered, because this function is what a tour's `await darker` reads,
## and `darker` is the ONE thing in a tour that can fail on the DIRECTION of the
## light (`same` is an absolute difference and passes a rise exactly as a fall).
## Modelling two terms that are still climbing when the light has landed put the
## guard on a knife edge at the end of every evening: measured over the last half
## hour, the old model turned back UP on all six landscapes and on a land with no
## mood of its own — moss +0.0004, coast +0.0002, pinewood +0.0005, snowfield
## +0.0015 from 21:00, bonelands +0.0003, burning +0.0010 from 21:00. Which side
## of the line a landscape fell on depended on the blend of shares in view, so
## the same tour passed and failed at one commit. The guard added to catch an
## evening that brightens had become an evening that brightens.
##
## So it composes what compose() composes: the sun's energy and the ambient's,
## against the one curve, times the hue's own luminance. It is a DIRECTION model
## and is not a brightness prediction — it has no emission in it (a village's
## lamps and fires are a real part of a dusk frame and belong to 15_lights) and
## no tonemapper, so its numbers fall further than a frame's do. What it is held
## to is that it moves the way the picture moves.
##
## `region` is the landscape's light (type_light); Vector3.ONE is a land with
## none of its own.
const FRAME_ALBEDOS := [0.10, 0.16, 0.22, 0.30, 0.40, 0.52, 0.66, 0.82]
## A face full into the sun, one grazing it, and one in shade.
const FRAME_FACES := [1.0, 0.55, 0.0]


static func frame_level(hour: float, region: Vector3, weather := Vector3.ONE, shut := 0.0) -> float:
	var tint := tint_at(hour)
	var total := tint * region * weather
	var level := maxf((total.x + total.y + total.z) / 3.0, 0.001)
	var hue := total / level
	var lit := 1.0 - day_gone(hour)
	# The lid is spent here exactly as compose() spends it, or this model would go
	# on predicting a sunlit noon for a landscape the renderer draws as a shut one
	# — and this is what `await darker` reads.
	# The lid is spent on the SUN and not on the moon, exactly as compose() spends
	# it now; these two must stay in step or `await darker` grades a composition
	# the renderer is not drawing.
	var keep := lerpf(1.0, _warm_keep(tint), sun_share(hour) if fposmod(hour, 24.0) > EVENING_FROM else 0.0)
	var sun := lerpf(MOON_NIGHT, SUN_NOON * level * keep * sun_glow(tint, sun_at(hour)) * lerpf(1.0, LID_SUN, shut), sun_share(hour))
	var amb := lerpf(lerpf(NIGHT_AMBIENT, DAY_AMBIENT, lit), LID_AMBIENT, shut)
	var hue_lum := maxf(hue.x * 0.3 + hue.y * 0.59 + hue.z * 0.11, 0.01)
	var sum := 0.0
	var n := 0
	for a: float in FRAME_ALBEDOS:
		for face: float in FRAME_FACES:
			sum += a * (sun * face + amb) * hue_lum
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
## Burning lies under warm, low light even at noon (docs/LOOK.md section 3).
const LEVEL := {&"burning": Vector3(0.94, 0.8, 0.68)}


## The light a landscape type lays over the hour: its cast, its level, its mood
## at this hour and its own BiomeDef.light_tint and day_light, one multiply. null reads as a
## type with nothing of its own.
static func type_light(def: BiomeDef, hour: float) -> Vector3:
	var id: StringName = def.id if def != null else &""
	var own := Vector3.ONE
	if def != null:
		own = Vector3(def.light_tint.r, def.light_tint.g, def.light_tint.b) * lerpf(def.day_light, 1.0, day_gone(hour))
	return type_tint(id) * (LEVEL.get(id, Vector3.ONE) as Vector3) * mood_light(id, hour) * own


## Each landscape's light through the day (docs/VISION.md section 8): a multiply
## on the hour's tint, keyed [hour, Vector3] and read round the clock. Never a
## filter: noon keeps nearly all its light, and the mood leans in at the ends of
## the day, where each place is most itself. Bleak grey on the coast, drowned
## green gloom in the moss, an early dusk under the pines, the snowfield's long
## blue evening, hard white noon on the bonelands, furnace dusk in the burning.
## A landscape type not listed keeps the plain hour. New types add a row.
##
## The EVENING is where these rows earn their keep, and where docs/LOOK.md section 3
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


## The dystopian grade (docs/LOOK.md section 6): a light, bleak desaturation that
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


## How much of the night sky's light stands over the landscapes in view
## (`BiomeDef.night_sky`), blended on the SAME shares as the grade, the air, the
## water and the score. That is the whole of what stops a border showing: a night
## level that snapped from one landscape's to another's would draw the ecotone as
## a line across the frame, and an ecotone exists to be the one place the eye
## cannot find the join.
##
## Squared weights, like the water and for the same reason: the night you are
## standing IN belongs to the land under your feet far more than to a sliver of a
## neighbour at the edge of the picture. Unsquared, walking to within a frame's
## width of the coast lifted a midnight bog by a third of the way to the coast's
## while the player was still in the bog.
static func night_sky_at(shares: Dictionary) -> float:
	var sum := 0.0
	var total := 0.0
	for k: Variant in shares:
		var w := float(shares[k])
		if w <= 0.0:
			continue
		w *= w
		var d := BiomeRegistry.get_def(k) if k is StringName else BiomeRegistry.by_index(int(k))
		sum += (d.night_sky if d != null else 1.0) * w
		total += w
	if total <= 0.0:
		return 1.0
	return clampf(sum / total, NIGHT_SKY_LEAST, NIGHT_SKY_MOST)


## The web's day contrast for the landscapes in view (`BiomeDef.web_contrast`),
## blended on the SAME squared shares as the night, the grade and the air, so a
## border never steps.
static func web_contrast_at(shares: Dictionary) -> float:
	var sum := 0.0
	var total := 0.0
	for k: Variant in shares:
		var w := float(shares[k])
		if w <= 0.0:
			continue
		w *= w
		var d := BiomeRegistry.get_def(k) if k is StringName else BiomeRegistry.by_index(int(k))
		sum += (d.web_contrast if d != null else 1.0) * w
		total += w
	if total <= 0.0:
		return 1.0
	return sum / total


## How far the landscapes in view are shut off from the sky (`BiomeDef.sky_shut`),
## blended on the SAME shares as the night, the grade, the air, the water and the
## score, and squared for the same reason: the lid you are standing under belongs
## to the land at your feet far more than to a sliver of a neighbour at the edge
## of the picture.
##
## Unsquared, a shut landscape would start dimming the open one a whole frame
## before its border — and this is the one of the five that is spent at every
## hour, so that error would show at noon, which is where it would be worst.
static func sky_holes_at(shares: Dictionary) -> float:
	var sum := 0.0
	var total := 0.0
	for k: Variant in shares:
		var w := float(shares[k])
		if w <= 0.0:
			continue
		w *= w
		var d := BiomeRegistry.get_def(k) if k is StringName else BiomeRegistry.by_index(int(k))
		sum += (d.sky_holes if d != null else 0.0) * w
		total += w
	if total <= 0.0:
		return 0.0
	return clampf(sum / total, 0.0, 1.0)


## How far the landscapes in view are shut (`BiomeDef.sky_shut`), on squared
## shares like everything else a place says about its sky.
static func sky_shut_at(shares: Dictionary) -> float:
	var sum := 0.0
	var total := 0.0
	for k: Variant in shares:
		var w := float(shares[k])
		if w <= 0.0:
			continue
		w *= w
		var d := BiomeRegistry.get_def(k) if k is StringName else BiomeRegistry.by_index(int(k))
		sum += (d.sky_shut if d != null else 0.0) * w
		total += w
	if total <= 0.0:
		return 0.0
	return clampf(sum / total, 0.0, 1.0)


## The last lid this node composed, for the STATIC rules that were written when
## the clock was the whole story (`Lights.lamps_wanted`). Same shape as
## `CompatTrim.remember`, and for the same reason: those rules are pure
## functions of the hour, they are called from places that hold no reference to
## the sky, and the alternative is threading a number through eight call sites in
## another package's file.
##
## It is deliberately NOT read by `low_light`, `day_gone`, `tint_at` or anything
## else in this file. Those are pure functions of the hour and every test in the
## repository is entitled to keep treating them that way; a remembered global
## quietly changing what a pure function answers is exactly the instrument that
## fails toward green (docs/LOOK.md). This is a door for one kind of caller, it
## says so, and the live value is `SkyLight.lid` on the node.
static var _last_lid := 0.0
## HOW MUCH OF THE SUN'S DISC THE RING IN ORBIT COVERS, seen from here, 0..1
## (19_orbit, OrbitPass.sun_cover): a transit takes the sun's light off the land
## by that share for the minute it lasts. Its one writer is 19_orbit; spent on
## the SUN'S term only, never the moon's.
static var orbit_shade := 0.0


static func remember_lid(v: float) -> void:
	_last_lid = clampf(v, 0.0, 1.0)


## How much lid the sky last composed with. 0 anywhere no landscape declares one.
static func last_lid() -> float:
	return _last_lid


## shares: landscape type id (or Country id) -> weight.
static func neon_grade_at(hour: float, shares: Dictionary) -> Array:
	var night := day_gone(hour)
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
