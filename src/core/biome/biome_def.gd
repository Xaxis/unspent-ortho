class_name BiomeDef
extends RefCounted
## A landscape TYPE as data (docs/VISION.md, §7.2). Every seed composes its
## world from the registered types: which appear, where, how large, how many
## times and how they meet. Nothing about a landscape may be hard-coded in a
## generator, renderer or system: it is a field here, and adding a landscape is
## adding one file under src/content/biomes/.
##
## A content file declares `static func make() -> BiomeDef` and fills what it
## needs; everything unset is a sane default, so a new type can be four lines
## before it is a hundred. BiomeRegistry discovers the file, gives the type its
## `index` (the byte stored per tile in WorldData.country) and validates it.
##
## What its OBJECTS are made of is `dressing`, a BiomeDressing (which see): the
## stone its boulders are cut from, the timber its fences weather to, what banks
## against a wreck, which patched shelter people put up, what the weather leaves
## on anything left out. A landscape writes down only what it argues with; the
## rest is worked out from what it has already said about itself.
##
## Units: relief is in WorldData levels, distances in tiles, colours are sRGB
## palette values (docs/LOOK.md: straight into ALBEDO, never converted).

## Placement kinds for `anchors`: a site is placed at (u, v) across the island's
## extent, or found by the climate envelope.
const ANCHOR_ALWAYS := 1.0

var id: StringName = &""
var display_name := ""
## Sort key for discovery. The world's byte arrays hand out indices in this
## order, so the M1 six keep 1..6 whatever else is registered. Ties break by id.
var order := 100
## Slot in WorldData.country / country2 / recipe. Set by the registry.
var index := -1
## Realm kinds it can appear in: &"surface", &"underground", &"orbital", &"era".
var realms: Array[StringName] = [&"surface"]
## The water type. Exactly one type is the sea, and it holds index 0.
var sea := false
## A one-line note on what this landscape is for, in the notebook's own words.
var style_note := ""
## How the game says someone is in this landscape: "on the coast", "out on the
## glass", "down in the middens". Flat and present (docs/STORY.md, the voice):
## a place's own preposition, which no rule can guess ("in the coast" is how a
## sentence built off `display_name` said it). Every landscape declares one
## (tests/biome/test_registry.gd).
var spoken_in := ""

# --- placement ------------------------------------------------------------

## Share of the land this type wants, as (min, max). The midpoint is the target
## worldgen balances toward, normalised across every land type registered.
var share := Vector2(0.1, 0.16)
## Journey anchors: [u, v, chance] in the island's extent (u across, v down,
## 0 = north). The first anchor that lands is the type's heart. A type with no
## anchors is placed by its climate envelope instead.
var anchors: Array = []
## Climate envelope for placement: temperature and moisture ranges, 0..1, read
## from the island's own latitude and continentality before relief exists.
## Sites go where the fit is best, and never where the fit is zero.
var temp_range := Vector2(0.0, 1.0)
var moist_range := Vector2(0.0, 1.0)
## Sites wanted when placed by envelope: (min, max), scaled by world size.
var site_count := Vector2i(1, 2)
## How many BODIES of a realm this type must and may lie on, as (least, most)
## (`docs/DESIGN.md` §4). `most` 0 is "as many as the balance wants".
##
##   (0, 0)  the default, and what every type did before continents: anywhere,
##           any number — AND A WORLD MAY NOT HAVE IT AT ALL.
##   (1, 0)  at least one body always carries it. What a story or an economy may
##           build on; ask `BiomeRegistry.guaranteed(id)` rather than reading this.
##   (0, 1)  at most one continent, and a world may not have it. The rare thing
##           you cross an ocean for.
##   (1, 1)  exactly one, guaranteed and exclusive.
##
## KEEP THE GUARANTEED SET SMALL. Every type given `least >= 1` is one that can
## never be made rare, so a long guaranteed list quietly spends the variety
## continents exist to buy. A spine resting on one landscape that always exists is
## more robust than one resting on eight that usually do.
var spread := Vector2i(0, 0)
## Placement bias by neighbour: other type id -> weight (+ likes to lie beside
## it, - keeps away). Read against the sites already placed.
var adjacency: Dictionary = {}
## -1 wants to be inland, +1 wants the shore, 0 does not care.
var coastal := 0.0

# --- relief and climate ---------------------------------------------------

## Blended by soft membership across the coarse grid (GenCountries.params), so
## the land rises and falls over many tiles rather than at a border.
##   base    mean elevation in levels        hills   hill amplitude
##   ridge   ridge amplitude                 terrace plateau stepping 0..1
##   valley  levels per tile of a river's side (low: a vale, high: a gorge)
##   rain    runoff feeding rivers           temp    0 frozen .. 1 furnace
##   moist   0 desert .. 1 drowned           cliff   headland cliff tendency
##   shelf   levels a terrace step stands above its two: tall cliffs between
##           broad shelves (0: the two-level scarp)
##   shelf_var  0..1, how much the shelf's height wanders across the land
var relief := {
	# `near` is relief AT WALKING SCALE and it is the one a landscape has to ask
	# for by name. `hills` and `ridge` ride noise whose wavelengths are 58 and 92
	# TILES, and the play camera shows 26.7 x 17.9 — so a player always stands
	# inside a third of one undulation and a landform arrives as a gentle ramp.
	# Raising `ridge` makes that ramp steeper over 92 tiles, never narrower:
	# measured, the middens at `ridge` 13.5 (the largest in the registry) render
	# as a flat plain, and so do the crags at `base` 11 and `cliff` 0.85. The
	# landforms were real on the map and absent at eye level, which is exactly
	# what the wavelengths predict. `near` rides the 1/13 field (13 and 6.5 tiles
	# over its two octaves), which is the scale a body walks through.
	&"base": 3.0, &"hills": 2.0, &"ridge": 0.0, &"near": 0.0, &"terrace": 0.0, &"valley": 0.5,
	&"rain": 1.0, &"temp": 0.5, &"moist": 0.5, &"cliff": 0.0,
}
## The region's FORM (`GenForm`): its land at the scale of the region. Empty is
## no form. Keys, all optional:
##   crest   levels the land rises from its shore to its spine (the ground
##           farthest from the sea within this landscape on its body)
##   rise    how the rise is shaped from shore to spine: t^rise, so above 1 the
##           shore stays low and the climb comes late
##   passes  0..1, how deep the saddles along the spine sink, as a share of crest
##   wave    tiles between one top and the next along the spine, times body_k
##   shore   tiles from the sea, times body_k, that stay at the landscape's own
##           height before the rise begins: the lowland where the river mouths
##           make marsh and the bays back onto dune
var form := {}
## > 0: this type's heart is a crater of this radius in tiles (at world size
## 512), with a raised rim and a sunk basin.
var caldera := 0.0
## Dunes ridge up behind this type's sandy bays.
var dunes := false

# --- borders and ecotones -------------------------------------------------

## Levels of elevation that move this type's border (positive: it takes the
## high ground, as the snow does).
var border_elevation := 0.0
## Long tongues into a named neighbour: other id -> Vector2(how far the tongue
## reaches in tiles, how hard the border's fingers bite there). Declared on the
## lower-ordered of the pair; both sides interleave.
var tongues: Dictionary = {}
## How this type's ground reaches OUT past its border into an ecotone.
## 0 = the plain rule (the blend itself). > 0 thins it to blend*near*thin, so
## ash and salt drift out rather than march.
var reach_out_thin := 0.0
## How far a neighbour's ground reaches IN over this type's side. Same shape.
var reach_in_thin := 0.0
## (elevation reference, elevation gain, rise gain, cap): when the cap is > 0
## this type only creeps out onto ground that stands high.
var reach_out_high := Vector4.ZERO
## (elevation reference, gain, cap): when the cap is > 0 a neighbour climbs in
## along this type's LOW ground.
var reach_in_low := Vector3.ZERO

# --- the look (docs/LOOK.md) --------------------------------------------

## The ground hatch hand (Ink).
var hatch := Ink.WIND
## Ground id -> wash (sRGB). Overrides GroundColors' shared wash for this type.
var grounds: Dictionary = {}
## Ground id -> ink mark code (GroundColors). Overrides the shared mark.
var ground_marks: Dictionary = {}
## The wash of a terrace wall where the ground on top does not decide it.
var cliff_wash := Color(0.5, 0.45, 0.4)
## The wall material: how world.gdshader bands the strata (GroundColors.STRATA_*).
var strata := GroundColors.STRATA_COAST
## The plainest ground of this type: its wash where nothing breaks it, and what
## an ecotone draws where it must pick one ground for this landscape.
var plain_ground := Ground.GRASS
## The bank of inland water drawn on this type's side.
var bank_ground := Ground.SAND
## The shore a still pool lies in here.
var pool_rim_ground := Ground.MUD
## Rivers freeze over on this landscape's high ground.
var rivers_freeze := false
## The stone a rock face turns into when drawn as this type.
var rock_ground := Ground.ROCK
## A village's cleared ground here, and what its square is trodden to.
var village_ground := Ground.GRASS
var village_square_ground := Ground.GRAVEL
## What its people BUILT (`BiomeForms`): which shapes their buildings take, how
## those buildings stand relative to each other and to the square, and how far
## out the nearest one is. Null builds one storey and a hearth, which is what
## every landscape did before a landscape could argue.
##
## It sits here among the worldgen fields and not among the look ones because
## the forms decide the SETTLEMENT and not only its drawing: how many buildings
## there are is the stock's own size, how much ground each stands on is its
## form's, and the plan decides where they go. Move it and every prop after the
## first village takes a different id.
var built: BiomeForms = null
## Ground id -> [density, kind, weight, kind, weight, ...] for the decor layer.
## The density may be Vector2(density, evenness) for a cover that should stand
## evenly rather than in drifts (Decor._table).
## A ground with no row here uses the shared table.
var decor: Dictionary = {}
## [blade, tip] of this type's grass, and the colour of its loose rock.
var grass_colors: Array[Color] = []
## This landscape's own grasses (GrassSpecies), laid by its d.decor as
## Decor.GRASS_A, GRASS_B, GRASS_C. Empty: it grows none of its own.
var grasses: Array[GrassSpecies] = []
var rock_color := Color(0.42, 0.43, 0.47)
## What the small life on this ground is coloured, where it differs from the
## shared hand: &"bloom" (a flower's head, three stages), &"fronds" (bracken,
## three), &"twig" (a fallen stick), &"spoil" (the grit a drill leaves).
var decor_tints: Dictionary = {}
## What grows tall here is coloured the same way: &"leaf" (a broadleaf crown,
## four tones light to dark), &"trunk", &"scrub" (a bush, three tones). Without
## a row, a landscape's trees are drawn in the shared greens.
var tree_tints: Dictionary = {}
## Its rock breaks into rubble that gathers at a cliff foot rather than crumbling.
var hard_rock := false
## What this landscape's BUILT and FOUND things are made of (`BiomeDressing`):
## boulders, bones, timber, drift, sods, walling, cast concrete, signs, the
## shelter people patch together, and what the weather leaves on a thing left
## out. Null takes the whole of it from the fields above.
var dressing: BiomeDressing = null
## Multiplied into this landscape's light.
var light_tint := Color(1, 1, 1)
## How brightly this landscape's DAY is lit against the one daylight (1 = the
## coast's). It is spent along the light's own evening (`SkyLight.day_gone`), so
## it is gone by the time night falls and never reaches a night, which is
## `night_sky`'s. `light_tint` cannot do this: it is multiplied in at every hour,
## and it lifted the moss's drawn night sky by 10 luma when asked to lift its day.
## For a ground dark enough that a noon under the shared sun reads as dusk. A
## roofed realm reads as night at every hour, so it has no day to spend this on.
var day_light := 1.0
## How much of the NIGHT sky's own light reaches the ground here (1 = the
## coast's, which is where the night was calibrated and which does not move).
##
## `lit` named the exposure/ambient/tonemap triple as its least confident call
## precisely because it is ONE global setting serving landscapes whose albedos
## differ by a factor of three: a night level tuned on the coast's mid-value
## grass leaves a bog black and a salt pan glowing. This is that one number made
## the landscape's own.
##
## It scales the night's AMBIENT and its MOON together, and the second half was
## the correction: the first attempt scaled only the ambient, on the argument
## that the moon is the same moon everywhere. It is — but how much of it reaches
## the ground is exactly what a lid over your head changes, and a canopy blocks a
## moon as surely as it blocks the skyglow. Scaling only the ambient also made
## the lever too weak to measure: at 1.45 it moved a midnight bog's ground from
## luma 10.5 to 10.9. Scaling both keeps the RATIO between them, which is what
## decides whether a night has shape in it (see NIGHT_AMBIENT's own note), so a
## dark landscape stays dark rather than going flat.
##
## Above 1 an open place under a wide sky (a fen, a salt pan, snow that throws
## the sky back); below 1 anything with a lid on it (a canopy, a gorge). It is
## spent only as far as night has fallen, so it can never touch a noon frame,
## and it is blended across an ecotone on the same shares as the grade, the air
## and the score (`SkyLight.night_sky_at`) — a night level that snapped at a
## border would draw the border as a line, which is the one thing an ecotone
## exists not to do. `SkyLight.NIGHT_SKY_LEAST/MOST` clamp it: readability at
## night is a floor the content layer may not argue with.
var night_sky := 1.0
## How much contrast THE WEB'S day picture takes here, as a multiplier on its
## count-back (`CompatTrim`): 1 as the row says, under 1 flatter, over 1 firmer.
## Compatibility squeezes a bright landscape's tonal range 10-16% and lifts its
## blacks (the live site's "pale"), and does the opposite to a dark one -- the
## moss comes out MORE contrasty -- so no single contrast serves both (the
## 2026-09-23 tone sweep: every global value made four places worse). Declared,
## never measured live, blended on the grade's squared shares
## (`SkyLight.web_contrast_at`), spent only by day (the night rows are their own
## fit), and it does nothing on Forward+, where the count-back is all ones.
var web_contrast := 1.0
## How far this landscape is SHUT OFF from the sky: 0 under the open one, 1 with
## something between it and the sun at every hour of the day.
##
## It is the DAY's half of `night_sky` above, and the two are deliberately
## separate. `night_sky` says how much of the NIGHT sky reaches the ground and is
## spent only as far as night has fallen, so it can never touch a noon frame.
## This one is spent at EVERY hour, because a lid does not know what time it is.
##
## It is not `SkyLight.closed`, which is the realm's all-or-nothing door: that
## reads a place as night whatever the clock says, takes the cast shadows away
## with it, and no landscape file may set it (a roof belongs to a realm). This is
## a landscape's own, it is partial, and THE HOUR GOES ON RUNNING UNDER IT — the
## clock, the weather, the schedule and the shadows are all untouched. What
## changes is only how much of the sky's own light arrives.
##
## Three things move together, and together is the point (see SkyLight.LID_*):
## the SUN falls away to a residue, so nothing is lit from one hard direction any
## more; the AMBIENT stops walking from day to night and settles on a level that
## does not move with the hour; and the sky dome — what metal reflects and where
## the shade takes its hue — stops being blue and becomes the underside of
## whatever is overhead. A landscape still says its LEVEL with `night_sky`, which
## reaches the day too as far as this is spent, and its COLOUR with `light_tint`.
##
## What it must NOT become is a multiply over every surface. `sky_apply`'s four
## retired no-ops are there because that is what was tried, and a per-fragment
## dim was most of why night was not dark (docs/LOOK.md). This is spent on the
## LIGHT, once, in `SkyLight.compose`, and it is blended across an ecotone on the
## same shares as the grade, the air, the night and the score, so a border
## between an open landscape and a shut one is a walk into shade and not a line
## drawn across the frame.
var sky_shut := 0.0
## How torn a ROOFED landscape's roof is to the day above, 0..1: where it is,
## a column of daylight comes down a sinkhole into the dark (`11_dome`, on the
## same tears and the same sun as a torn lid). It is not `sky_shut`: that is a
## landscape putting a lid over itself and is spent on the whole light; this
## only opens holes in a roof a realm already has, and touches nothing else.
## Runtime only, so a LOOK field: it moves no island.
var sky_holes := 0.0
## How far the growth of this land has taken the things people built in it,
## 0..1: moss on every ledge, ivy hanging from every storey, green streaks where
## run-off feeds it, dense low and thinning upward (`matter_grown`, SkyWear's
## growth map). 1 is a city the forest has; a wet land might take 0.2.
## Runtime only, so a LOOK field: it moves no island.
var overgrowth := 0.0
## What this land's vents breathe (16_vents): the colour of the puff, and in
## ALPHA how big and how often, as a multiple of the Burning's ash (1). 0 alpha
## takes the Burning's. Above 1 the machine caps breathe too, leaking round
## their seals. Runtime only, so a LOOK field.
var vent_breath := Color(0, 0, 0, 0)
## What lights this land's trees from below after dark, if anything: the colour,
## and in ALPHA how strongly (leaf.gdshader, through SkyWear's growth map). The
## grey orchards' is the plan's grow light, still run on schedule for trees
## nobody will pick. Runtime only, so a LOOK field.
var underlight := Color(0, 0, 0, 0)
## How much more rain comes down as drips here, under a canopy (10_sky, Drips):
## 1 is open ground. Runtime only, so a LOOK field.
var canopy_drip := 1.0
## Cold lights drifting low after dark, how many (10_sky wisps): 0 is none.
## Never in rain or a wind. Runtime only, so a LOOK field.
var wisps := 0.0
## HOW THIS LAND'S WEATHER LOOKS, per weather kind (Weather.KINDS), where it is
## not the shared look (src/render/weather). A kind with no row here looks as
## it does everywhere. Rows so far:
##   &"dust": {"air": Color, "thick": float}  the colour a dust storm carries the
##            air to here (red iron in the mesas, salt on the flats) and how much
##            thicker than the shared dust it lies (1 = the shared)
##   &"fog":  {"air": Color, "low": float}  the colour this land's fog is, and how
##            low and heavy it lies in the hollows, 0..1
## Runtime only, so a LOOK field; BiomeRegistry.problems names a bad row.
var weather_style: Dictionary = {}
## Every field a weather_style row may carry, per kind.
const WEATHER_STYLE_FIELDS := {&"dust": ["air", "thick"], &"fog": ["air", "low"]}


## What is wrong with `weather_style`, one line each (BiomeRegistry.problems).
func style_problems() -> Array[String]:
	var out: Array[String] = []
	for kind: StringName in weather_style:
		if not WEATHER_STYLE_FIELDS.has(kind):
			out.append("weather_style has no row for %s" % kind)
			continue
		for field: String in (weather_style[kind] as Dictionary):
			if not (WEATHER_STYLE_FIELDS[kind] as Array).has(field):
				out.append("weather_style %s has no field %s" % [kind, field])
	return out
## The dystopian grade offset added to SkyLight's own (`SkyLight.neon_row`):
## (dark, desat, cool, contrast). `sky.gdshaderinc` scales the graded colour by
## (1 - dark), so POSITIVE dark dims and NEGATIVE lifts: every landscape's dark
## term goes negative, far enough that its own washes still read as day at noon.
var grade := Vector4(-0.4, 0.15, 0.04, 0.05)
## How wet this land lies with no rain on it: 0 dry, 1 drowned.
var wet := 0.0
## What this landscape's INLAND water is drawn in (rivers, pools, falls; never
## the sea). rgb is the colour a middling depth takes, and ALPHA is how far the
## chart is pulled to it — 0, the default, is the shared chart blues. The
## drawing is kept whatever this is: the soundings, the dashes carried
## downstream, the marbling and the foam all stay and only their colour moves,
## so a pool gone black still has its edge and a brine pan still has its swash.
## Without it a landscape could not say what its water looks like, and the
## scrapwood — a wood of green-brown gloom — had a pale slate-blue pond as the
## brightest object in its frame (playtest 6).
var water_wash := Color(0, 0, 0, 0)
## A ragged overhang of snow hangs on this landscape's terrace lips, whatever
## the ground on top (docs/LOOK.md).
var lip_snow := false

# --- what grows, what is buried -------------------------------------------

## PropKind ids the per-tile scatter may place here. Nothing else grows.
var props: Array[int] = []
## Ore in this type's rock as [[PropKind, cumulative chance], ...], in order.
var ore: Array = []
## Ore also shows in this type's loose gravel (the Bonelands' seams do).
var gravel_ore := false
## Chance reeds stand at water's edge here (0: nothing grows in this water).
var reed_chance := 0.0
## Nothing green survives here, and the green things thin as they near it.
var scorched := false
## What grows on the dune sand behind this type's beaches.
var shore_bush := PropKind.BUSH
## static func(t: BiomeSample) -> int: the ground of one tile. -1 keeps the
## shared answer. Set from the content file; the six M1 recipes live in theirs.
var surface := Callable()
## static func(t: BiomeSample) -> int: the prop on one tile, or -1 for none.
var scatter := Callable()
## Landmark sites this type carries:
##   tips int           scrap heaps the machines dumped here
##   stone_circles int  what stood here before, some of it cast in concrete
##   ruins bool         steadings people lost
##   fumaroles int      fields of vents out on the slopes
##   summit int         the order this landscape's cairn is raised in (0: none)
##   kiln_ground int    the Ground a village's kiln stands on (absent: no kiln)
var sites: Dictionary = {}
## The ground a scrap tip lies on here.
var tip_ground := Ground.GRAVEL
## Hulls are hauled up on this landscape's beaches.
var beached_wrecks := true
## Still water: {order, cell, chance, r_min, r_max, ground}, `order` deciding
## which landscape's pools are laid first. Empty: no tarns or pools.
var pools: Dictionary = {}
## Villages wanted in this type, their placeholder names, and the order this
## landscape is settled in when a world is shared out (the land that fills up
## what is left goes last).
var villages := 0
## Whether `villages` is counted PER REGION rather than per landscape.
##
## **A CITY THAT LAYS ONE VILLAGE HOWEVER MANY BOROUGHS IT HAS IS NOT A CITY.**
## The count has always been per landscape, which is right for a coast whose
## fishing villages are scattered over one shore and wrong for anything urban:
## measured on the Slums, seed 1 laid three regions of 11,796, 2,222 and 1,994
## tiles and built in exactly ONE of them, leaving two boroughs of city ground
## with nothing standing on them at all. Seed 42 was three regions and two empty.
## Every connected run of a landscape is a PLACE (`WorldData.regions`), and a
## place a player can walk the length of without meeting a building is not a
## place, it is a texture.
##
## Off by default, so no landscape that was right before moves.
var villages_each_region := false
## How far the village's own levelled platform reaches, in tiles. 0 takes
## `GenSettle.FLAT` (6.5), which is what every landscape had.
##
## **THE PLATFORM WAS SMALLER THAN THE PLOT, AND THAT IS THE WHOLE SHORTFALL.**
## Buildings are laid out to `GenSettle.HOUSE_REACH` — 14.5 tiles from the
## square — while only 6.5 tiles of ground were ever levelled, and a building is
## refused unless its own nine tiles share one level. So on terraced ground
## everything past the platform's edge was struck out before it could be built,
## and nothing reported the shortfall: the landscape asked for 22-34 buildings
## and stood 3, 6 and 9.
##
## Measured on the Slums, which declares stepped relief precisely BECAUSE a city
## stands on platforms — so its own fiction was refusing its own buildings. A
## landscape that cuts a bigger platform is saying its people levelled the ground
## before they built, which is what a city is.
var village_platform := 0.0
## How far the village's own levelled platform reaches, in tiles. 0 takes
## `GenSettle.FLAT` (6.5), which is what every landscape had.
##
## **THE PLATFORM WAS SMALLER THAN THE PLOT, AND THAT IS THE WHOLE SHORTFALL.**
## Buildings are laid out to `GenSettle.HOUSE_REACH` (14.5 tiles from the
## square) while only 6.5 tiles of ground were levelled, and a building is
## refused unless its own nine tiles share one level -- so on terraced ground
## everything past the platform's edge was struck out before it was ever built.
## Measured on the Slums, which declares stepped relief BECAUSE a city stands on
## platforms: villages asking for 22-34 buildings stood 3, 6 and 9.
##
## A landscape that cuts a bigger platform is saying its people levelled the
## ground before they built, which is what a city is.
var village_names: Array = []
var village_order := 50
## How many people this landscape puts on the street round each of its villages,
## when that is more than the six a village gets (`35_folk.PER_VILLAGE`). A city
## is not a village with the same handful of people in it, and the count is what
## its crowd is made of: past `35_folk.CROWD_BLIND` standing together nobody
## looks up at a stranger any more, so this one number is also what decides
## whether the player is an event here or traffic.
##
## Runtime only — worldgen lays the village, not the people in it — so it is a
## LOOK field in `WorldStamp` and adding it refuses nobody's save.
var street_folk := 0
## How many of the machines' flying craft stand over this landscape at once,
## within reach of the player (`src/render/depth/flier_view.gd`, `14_fliers`).
## 0 is every landscape that has not asked, and the layer builds nothing there.
##
## They are not bodies: nothing fights them, nothing spawns them and no roster
## row is read. They are the plan's traffic, on the plan's own survey bearing,
## and what they do for the picture is cross between the camera and the place
## and lay a bar of shade along a lit street.
##
## Runtime only, so a LOOK field in `WorldStamp`: it moves no island and refuses
## no save.
var fliers := 0
## The share of this landscape's BUILDINGS that project a hologram over their own
## roof, 0..1 (`src/render/depth/holo_view.gd`, `17_holo`). 0 is every landscape
## that has not asked, and the layer builds nothing there.
##
## Only what a landscape built UPWARD can carry one — a column of light over a
## cottage is a joke — so this does nothing at all without a `built` whose forms
## stand over four units. It is the other half of "advertising": a sign arm hangs
## a lit BOARD over a lane, and this is light standing in the air with nothing
## holding it up.
##
## Runtime only, so a LOOK field in `WorldStamp`: it moves no island and refuses
## no save.
var holograms := 0.0
## The player wakes in this landscape.
var spawn_home := false

# --- sky, sound, danger ---------------------------------------------------

## Weather table rows [kind, weight, squall], weights summing to 100
## (the rows Weather reads). Empty reads the coast's.
var weather: Array = []
## Dawn mist at its deepest, 0..1 of fog density.
var mist := 0.0
## Hazard id -> base strength 0..1 (cold, heat, fumes, toxins, radiation, wet,
## dark, glare, thirst, magnetism, collapse, vacuum, pressure, em, resonance,
## time_shear). The hazards package reads this.
var hazards: Dictionary = {}
## Roster id -> {weight: float, hours: Vector2} for the mob spawner. An entry
## with no hours is awake all day. `over` (a Dictionary of roster keys) makes the
## kind this landscape's own: every body of it put down here wears those keys
## over the roster's (a whole `bite` included), and fights, senses and reads on
## the slate by them. Numbers only: a model builds its working part where the
## roster's `part` says, so a part moved here would be drawn on the wrong side.
var roster: Dictionary = {}
## Sentinel design id for this type (empty until designed).
var sentinel: StringName = &""
## Landmark kinds this type holds (`Landmarks`), three or more: the places worth
## the walk in it. Empty takes every kind that names this landscape itself, so a
## landscape only writes this line when it wants something other than that.
## Placed after generation, like a shaft, so the island does not move (LOOK).
var landmarks: Array[StringName] = []
## What of this landscape can be WALKED INTO, and what it is inside (docs/
## interiors): a host to an interior kind (one of Interiors.RECIPES). Hosts:
## `&"house"` every house, `&"form:ID"` a house of that building form (before
## `house`), `&"works:depot"`, `&"landmark:KIND"`. Empty, nothing here has a
## door. Doors are derived after
## generation, like a shaft, so the island does not move (LOOK).
var interiors: Dictionary = {}
var sound_bed: StringName = &"bed_wind"
## Another type's id whose music motif this one borrows; empty composes its own.
var music_motif: StringName = &""


## The target share of the land, before normalising across the registry.
func share_target() -> float:
	return (share.x + share.y) * 0.5


## The relief parameter `name`, 0 when this type does not set it.
func param(name: StringName) -> float:
	return float(relief.get(name, 0.0))


## Roster ids that may spawn here at hour `h`, with their weights.
func roster_at(h: float) -> Dictionary:
	var out := {}
	for k: StringName in roster:
		var row: Dictionary = roster[k]
		var hours: Variant = row.get("hours")
		if hours is Vector2:
			var from: float = (hours as Vector2).x
			var to: float = (hours as Vector2).y
			var hh := fposmod(h, 24.0)
			var inside := (hh >= from and hh < to) if from <= to else (hh >= from or hh < to)
			if not inside:
				continue
		out[k] = float(row.get("weight", 1.0))
	return out
