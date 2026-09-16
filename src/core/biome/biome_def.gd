class_name BiomeDef
extends RefCounted
## A landscape TYPE as data (docs/VISION.md §3, §7.2). Every seed composes its
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
## Units: relief is in WorldData levels, distances in tiles, colours are sRGB
## palette values (docs/ART.md: straight into ALBEDO, never converted).

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
var relief := {
	&"base": 3.0, &"hills": 2.0, &"ridge": 0.0, &"terrace": 0.0, &"valley": 0.5,
	&"rain": 1.0, &"temp": 0.5, &"moist": 0.5, &"cliff": 0.0,
}
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

# --- the look (docs/ART.md §3) --------------------------------------------

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
## Ground id -> [density, kind, weight, kind, weight, ...] for the decor layer.
## A ground with no row here uses the shared table.
var decor: Dictionary = {}
## [blade, tip] of this type's grass, and the colour of its loose rock.
var grass_colors: Array[Color] = []
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
## Multiplied into this landscape's light.
var light_tint := Color(1, 1, 1)
## The dystopian grade offset (SkyLight.NEON_COUNTRY): (dark, desat, cool,
## contrast). Dark goes NEGATIVE where the washes are dark, so every landscape
## reads as day at noon.
var grade := Vector4(-0.4, 0.15, 0.04, 0.05)
## How wet this land lies with no rain on it: 0 dry, 1 drowned.
var wet := 0.0
## A ragged overhang of snow hangs on this landscape's terrace lips, whatever
## the ground on top (docs/ART.md §4).
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
var village_names: Array = []
var village_order := 50
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
## with no hours is awake all day.
var roster: Dictionary = {}
## Sentinel design id for this type (empty until designed).
var sentinel: StringName = &""
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
