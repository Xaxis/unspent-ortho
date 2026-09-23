class_name EliteStock
## The elite materials, and the one place each of them comes from
## (docs/VISION.md §6.1). This is the spine of the long game: the best of a kind
## is behind a LANDSCAPE or behind one kind of machine, so a player who wants it
## has to travel or fight for it.
##
## Two gates, and no third:
##
## **A landscape's own.** The material is refined from a raw that only that
## landscape gives, at a station: brimstone comes out of a vent and vents are
## only in the burning, limestone out of clints and clints are only in the
## bonelands, peat out of a bank and banks are only in the moss, crottle off rock
## that only stands in snow. So the recipe is open to anyone and the INPUT is the
## journey, which is why nothing here needs a special case in worldgen.
##
## **One machine's own.** The material is cut out of one kind of machine and no
## other, and each of those kinds keeps to its own country (`Roster` `where`), so
## a keeper's lens means walking into the pinewood and beating a warden.
##
## Nothing is declared here that cannot be got in the game as it stands today.
## The salt flats and the scrapwood have neither a raw only they give (their props
## yield salt, scrap and iron ore, which other lands give too) nor a machine kind
## of their own, so they hold no elite material yet and none is invented for them.
##
## `GearEconomy.declare()` pours all of this into `Materials` and `Drops`, which
## is where every other package reads it.

## id -> where it comes from and what it is.
##   land, raw, at    a landscape's own: refine `raw` at station `at`
##   kind             one machine's own: the roster id it is cut out of
##   chance           a kill's odds of giving it up
##   what             the line a player is shown (docs/ART.md §11: a material
##                    keeps its landscape's colour and hand)
##   grade            the grade of thing it tends to make
const MATERIALS := {
	# --- a landscape's own ----------------------------------------------------
	&"cinder_glass": {"land": &"burning", "raw": &"brimstone", "at": &"kiln", "grade": &"rare",
		"what": "slag fused black, with a bloom of copper under the skin"},
	&"clint_spar": {"land": &"bonelands", "raw": &"limestone", "at": &"kiln", "grade": &"rare",
		"what": "a blade of spar off the clints, half-clear and cold to hold"},
	&"bog_iron": {"land": &"moss", "raw": &"peat", "at": &"fire", "grade": &"rare",
		"what": "iron the bog grew: soft, stubborn, and it takes a patch"},
	&"frost_varnish": {"land": &"snowfield", "raw": &"crottle", "at": &"fire", "grade": &"rare",
		"what": "lichen boiled hard; it does not craze when the cold comes"},
	# The crags': broken out of a carved face on the crags' own rock (Takes gates
	# it on ROCK), and nothing else in the world gives it.
	&"hush_slate": {"land": &"the_crags", "raw": &"hushstone", "at": &"kiln", "grade": &"rare",
		"what": "stone a scanner reads as nothing at all"},
	# The frost sea's (docs/VISION.md §6.1 names it): lens ice is cut out of a
	# pressure block with a steel edge, and pressure blocks stand nowhere else.
	&"deep_ice_lens": {"land": &"frost_sea", "raw": &"lens_ice", "at": &"bench", "grade": &"rare",
		"what": "the clear heart of a slab of sea ice, ground until the far side comes through it"},
	# The glass desert's (docs/LANDSCAPES.md §3): fulgurite comes off a fulgurite
	# and a fulgurite stands only in the strike fields' sand, on the one
	# landscape that scatters it. Refined at the kiln, it is what the shock
	# lattice is wound round — the prime module that had no `from` — and what
	# a glass lance is bound round.
	&"fulgurite_core": {"land": &"glass_desert", "raw": &"fulgurite", "at": &"kiln", "grade": &"prime",
		"what": "a strike's own cast, fired again: green-black, and it rings when it is struck"},
	# The Ruined Metropolis's own (docs/LANDSCAPES.md §4): steel wire rope cut
	# out of a lift core, which stands only on the city's own floor and grass
	# (Takes gates the cut on the ground), re-laid at the fire. The spec says
	# "the forge"; the fire is the one hot station a person builds and where
	# iron is already made, so it is the forge this game has.
	&"tower_cable": {"land": &"ruined_metropolis", "raw": &"lift_cable", "at": &"fire", "grade": &"rare",
		"what": "lift rope annealed and laid up again: it takes a body's weight and does not stretch"},
	# The Drowned City's own (docs/LANDSCAPES.md §5): copper conductor cut out
	# of a drowned tram's trolley gear, which stands only in the city's own
	# shallows (Takes gates the cut on MUD), poured again at the fire with the
	# salt still in it. Copper is poured at the fire everywhere else, so this is.
	&"brine_copper": {"land": &"drowned_city", "raw": &"sea_copper", "at": &"fire", "grade": &"rare",
		"what": "copper the sea kept for a century, poured again: green at the grain, and water runs off it"},

	# --- one machine's own ----------------------------------------------------
	&"tide_iron": {"kind": &"harvester", "chance": 0.35, "grade": &"prime",
		"what": "pitted and rust-bled: the shore is still in it"},
	&"mono_edge": {"kind": &"cutter", "chance": 0.3, "grade": &"prime",
		"what": "a filament edge, one atom wide and still bright"},
	&"keeper_lens": {"kind": &"warden", "chance": 0.3, "grade": &"prime",
		"what": "the eye a keeper reads its hours by, cracked across once"},
	&"haul_gyro": {"kind": &"hauler", "chance": 0.3, "grade": &"prime",
		"what": "a gyro out of a spine, still holding the way it was set"},
	&"line_coil": {"kind": &"lineman", "chance": 0.35, "grade": &"prime",
		"what": "a mile of hair-fine wire, wound warm"},
	&"clerk_die": {"kind": &"clerk", "chance": 0.25, "grade": &"relic",
		"what": "the die a filer stamps with: exact, older than the rest of it"},
	&"vane_true": {"kind": &"sweeper", "chance": 0.35, "grade": &"prime",
		"what": "a vane off a sweeper, bent back true by hand"},
	&"dredge_screw": {"kind": &"dredger", "chance": 0.3, "grade": &"prime",
		"what": "a screw that bites mud, threaded the wrong way round"},
	# The machines' own shop, carried: what the top rung of every recipe is made
	# AT rather than OF (CraftTiers.JIG). A hunter carries one to mend its legs.
	&"fab_jig": {"kind": &"longlegs", "chance": 0.25, "grade": &"prime",
		"what": "a jig a hunter mends its own legs on: clamps, a rule, a heat gun"},
	# The Ruined Metropolis's own worker (docs/LANDSCAPES.md §4): the hydraulic
	# ram out of its boom, which is what drives a jaw through poured concrete.
	&"boom_ram": {"kind": &"demolisher", "chance": 0.3, "grade": &"prime",
		"what": "the ram out of a demolisher's boom, still weeping oil at the seal"},
}

## What else a kill gives up, beyond the plate the roster already counts
## (`Roster` `drops`, spent by the fight package). Two things:
##
## **Charges.** The found ladder's ammunition, and the only reason a beam is worth
## carrying. They come off the bodies that spend them.
##
## **The machines' own tools.** Every found weapon in `Items.DEFS` is machine tech
## taken whole, and before this table there was NO way to hold one: they are not
## made, not on a take, not on a drop. So each is carried by the one kind of
## machine whose work it is — a cutter carries a torch, a hunter carries a beam —
## and taking it off that body is the whole of how the found ladder is entered.
## One kind each, so a player learns which body to look for.
const SPOILS := {
	# Hunters: what is carried to run a person down.
	&"longlegs": [{"item": &"wick", "chance": 0.45, "count": Vector2i(1, 2)},
		{"item": &"mono_blade", "chance": 0.1, "rarity": Rarity.UNCOMMON}],
	&"runner": [{"item": &"wick", "chance": 0.5, "count": Vector2i(1, 2)},
		{"item": &"las_hand", "chance": 0.12, "rarity": Rarity.UNCOMMON}],
	&"flock": [{"item": &"wick", "chance": 0.3},
		{"item": &"flash_burst", "chance": 0.12, "rarity": Rarity.UNCOMMON}],
	&"dredger": [{"item": &"sonic_wave", "chance": 0.1, "rarity": Rarity.UNCOMMON}],
	# The glass desert's skater: the blade it runs the plates on, which is what
	# a glass lance is ground from (Recipes: lance_glass). A spoil and not an
	# elite material on purpose: the landscape's one-gate material is the
	# fulgurite core, and a second gate on the same land would be two.
	&"skater": [{"item": &"wick", "chance": 0.4, "count": Vector2i(1, 2)},
		{"item": &"skate_blade", "chance": 0.35, "rarity": Rarity.UNCOMMON}],
	# Watchers and keepers: what is carried to stop somebody.
	&"watcher": [{"item": &"wick", "chance": 0.4},
		{"item": &"stun_hand", "chance": 0.12, "rarity": Rarity.UNCOMMON}],
	&"clerk": [{"item": &"rep_light", "chance": 0.12, "rarity": Rarity.UNCOMMON}],
	&"warden": [{"item": &"las_long", "chance": 0.1, "rarity": Rarity.UNCOMMON}],
	# Workers: what is carried to cut, lift and burn through things all day.
	&"cutter": [{"item": &"plasma_torch", "chance": 0.1, "rarity": Rarity.UNCOMMON}],
	&"harvester": [{"item": &"las_broad", "chance": 0.1, "rarity": Rarity.UNCOMMON}],
	&"hauler": [{"item": &"pulse_hammer", "chance": 0.1, "rarity": Rarity.UNCOMMON}],
	&"sweeper": [{"item": &"arc_cut", "chance": 0.12, "rarity": Rarity.UNCOMMON}],
	&"lineman": [{"item": &"beam_lance", "chance": 0.1, "rarity": Rarity.UNCOMMON}],
	# The crags' chainman: links off the chain it drags (docs/LANDSCAPES.md §1).
	# No weapon, because it carries none -- it measures.
	&"chainman": [{"item": &"chain_link", "chance": 0.6, "count": Vector2i(1, 3)}],
	# The frost sea's saw sled: what comes off the blade that cuts the ice. A
	# tooth and not a material, because docs/LANDSCAPES.md §2 gives the frost sea
	# its elite through a PROP (lens ice off a pressure block) and a landscape
	# holds one gate, not two.
	&"icesaw": [{"item": &"saw_tooth", "chance": 0.45, "count": Vector2i(1, 2)}],
	# The drowned city's ferry: the bilge pump out of its hull
	# (docs/LANDSCAPES.md §5). A spoil and not a material, for the frost sea's
	# reason: the drowned city's one gate is brine copper, stripped off a
	# drowned tram, and a landscape holds one gate, not two.
	&"ferry": [{"item": &"bilge_pump", "chance": 0.35}],
}


static func material(id: StringName) -> Dictionary:
	return MATERIALS.get(id, {})


static func ids() -> Array:
	return MATERIALS.keys()


static func is_elite(id: StringName) -> bool:
	return MATERIALS.has(id)


## The landscape this material belongs to, &"" if it is a machine's.
static func land_of(id: StringName) -> StringName:
	return material(id).get("land", &"")


## The roster kind this material is cut out of, &"" if it is a landscape's.
static func kind_of(id: StringName) -> StringName:
	return material(id).get("kind", &"")


## The one kind of machine that carries `item` as spoils (a charge, a found
## weapon), &"" if none does. Elite materials answer through `kind_of`; this is
## how everything else the economy drops is walked back to a body.
static func carried_by(item: StringName) -> StringName:
	for kind: StringName in SPOILS:
		for row: Dictionary in SPOILS[kind]:
			if StringName(row.get("item", &"")) == item:
				return kind
	return &""


## Either gate, for a walker that only wants to know which body to look for.
static func dropped_by(item: StringName) -> StringName:
	var kind := kind_of(item)
	return kind if kind != &"" else carried_by(item)


## Every elite material one kind of machine gives up.
static func from_kind(kind: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in MATERIALS:
		if kind_of(id) == kind:
			out.append(id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## The whole drop table for one roster kind, in the shape `Drops.declare` takes:
## its elite part, then whatever else it carries.
static func table_for(kind: StringName) -> Array:
	var rows: Array = []
	for id: StringName in from_kind(kind):
		var m := material(id)
		rows.append({"item": id, "chance": float(m.get("chance", 0.3)),
			"rarity": Rarity.of_name(m.get("grade", &"prime"))})
	for row: Dictionary in SPOILS.get(kind, []):
		rows.append(row.duplicate())
	return rows


## Every roster kind that gives up anything through this economy.
static func kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in MATERIALS:
		var k := kind_of(id)
		if k != &"" and not out.has(k):
			out.append(k)
	for k: StringName in SPOILS:
		if not out.has(k):
			out.append(k)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out
