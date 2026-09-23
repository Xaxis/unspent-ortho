class_name GearTree
## Every implement and module the player can end up holding, and what GRADE it
## is (docs/VISION.md §6.1). One table, because the ladder only means anything
## read all at once.
##
## The pinned promise, and the reason this is a table of grades and FAMILIES
## rather than a table of numbers: **a grade buys modifiers, not damage.** A
## family is one shape of weapon — a knife, a spar, a gaff — and every rung of a
## family does exactly the same damage, reaches exactly as far, swings in exactly
## as many milliseconds and works at exactly the same speed. What a higher rung
## buys is SOCKETS (`Rarity.slots`) and the elite material it is made of. So a
## common knife stays a useful knife for the whole game, and the reason to walk
## into the burning for cinder glass is what you can then bolt onto the thing,
## never a bigger number. `tests/gear_economy/test_grades.gd` holds that.
##
## Rows:
##   grade   common | uncommon | rare | prime | relic (Rarity.NAMES)
##   family  the shape; rungs of one family share every mechanical number.
##           &"" for a one-off that is not part of a ladder.
##   from    the elite material it is made of, &"" for the ordinary rungs
##           (EliteStock declares where each material can be got)
##   unique  a relic only: the one thing no other piece does, said plainly
##
## Adding a rung is a row here, a row in `Items.DEFS`, a recipe in
## `Recipes.LIST`, and nothing else.

## The MENDED rungs: FOUND parts cut down and bound to a MADE haft (docs/ART.md
## §12), each named for the elite material that is in it, so a player reads the
## landscape in the tool.
const PIECES := {
	# --- made implements, the ladder that is already there (M1) ---------------
	&"knife": {"grade": &"common", "family": &"knife"},
	&"stave": {"grade": &"common", "family": &"stave"},
	&"boathook": {"grade": &"common", "family": &"gaff"},
	&"billhook": {"grade": &"common", "family": &"bill"},
	&"axe_hand": {"grade": &"common", "family": &"axe"},
	&"mattock": {"grade": &"common", "family": &"mattock"},
	&"pick": {"grade": &"common", "family": &"pick"},
	# Cemented steel: the same shapes, harder, and still no sockets. A steel edge
	# is its own family because it holds an edge far longer than the iron rung and
	# so is not a grade of it: it is the same tool, kept.
	&"knife_shear": {"grade": &"uncommon", "family": &"knife_steel"},
	&"axe_felling": {"grade": &"uncommon", "family": &"axe_steel"},
	&"mattock_steel": {"grade": &"uncommon", "family": &"mattock_steel"},
	&"pick_steel": {"grade": &"uncommon", "family": &"pick_steel"},
	# The one implement that is never made and never cut off a machine (items.gd:
	# "Rare; never craftable"). It is FOUND, on the deck of a fire tower whose last
	# tenant left their sacking up — which is what this row promised for a whole
	# wave while nothing in the world held one. `no_source` is gone with it, and
	# `tests/gear_economy/test_obtainable.gd` now allows none at all.
	&"axe_works": {"grade": &"rare", "family": &"axe_works"},

	# --- found implements, taken whole off the works --------------------------
	# Graded by where they are got, never by what they do. Machine tech taken whole
	# is UNCOMMON to a one -- it comes off the plan's works, which are everywhere the
	# plan is -- so the two hardest-hitting things in the game are ordinary, and the
	# only thing any of them carries is the one binding a haft takes. That is the
	# whole of the promise above, stated in the table rather than argued for.
	&"las_hand": {"grade": &"uncommon", "family": &"beam"},
	&"rep_light": {"grade": &"uncommon", "family": &"repeater"},
	&"arc_cut": {"grade": &"uncommon", "family": &"arc"},
	&"mono_blade": {"grade": &"uncommon", "family": &"thin"},
	&"plasma_torch": {"grade": &"uncommon", "family": &"torch"},
	&"stun_hand": {"grade": &"uncommon", "family": &"stunner"},
	&"flash_burst": {"grade": &"uncommon", "family": &"flasher"},
	&"las_long": {"grade": &"uncommon", "family": &"beam_long"},
	&"las_broad": {"grade": &"uncommon", "family": &"beam_broad"},
	&"sonic_wave": {"grade": &"uncommon", "family": &"wave"},
	&"pulse_hammer": {"grade": &"uncommon", "family": &"hammer"},
	&"beam_lance": {"grade": &"uncommon", "family": &"lance"},

	# --- MENDED implements: the tree this package builds ----------------------
	# Two rungs per made family. Every number is the common rung's; what the rung
	# buys is two sockets, then three, and the hand of the land it came out of.
	&"knife_spar": {"grade": &"rare", "family": &"knife", "from": &"clint_spar"},
	&"knife_mono": {"grade": &"prime", "family": &"knife", "from": &"mono_edge"},
	&"axe_bog": {"grade": &"rare", "family": &"axe", "from": &"bog_iron"},
	&"axe_tide": {"grade": &"prime", "family": &"axe", "from": &"tide_iron"},
	&"bill_glass": {"grade": &"rare", "family": &"bill", "from": &"cinder_glass"},
	&"bill_vane": {"grade": &"prime", "family": &"bill", "from": &"vane_true"},
	&"mattock_bog": {"grade": &"rare", "family": &"mattock", "from": &"bog_iron"},
	&"mattock_gyro": {"grade": &"prime", "family": &"mattock", "from": &"haul_gyro"},
	&"pick_spar": {"grade": &"rare", "family": &"pick", "from": &"clint_spar"},
	&"pick_glass": {"grade": &"prime", "family": &"pick", "from": &"cinder_glass"},
	&"stave_varnish": {"grade": &"rare", "family": &"stave", "from": &"frost_varnish"},
	&"stave_coil": {"grade": &"prime", "family": &"stave", "from": &"line_coil"},
	&"hook_varnish": {"grade": &"rare", "family": &"gaff", "from": &"frost_varnish"},
	&"hook_screw": {"grade": &"prime", "family": &"gaff", "from": &"dredge_screw"},
	# Found weapons cut down and rehafted: the same beam, on a stick a person
	# made, with somewhere to bolt a part. Machine tech taken whole cannot be
	# mended; machine tech a person has already opened up can.
	&"beam_hafted": {"grade": &"rare", "family": &"beam", "from": &"tide_iron"},
	&"beam_lens": {"grade": &"prime", "family": &"beam", "from": &"keeper_lens"},
	&"arc_hafted": {"grade": &"rare", "family": &"arc", "from": &"mono_edge"},
	&"hammer_hafted": {"grade": &"rare", "family": &"hammer", "from": &"haul_gyro"},
	&"lance_hafted": {"grade": &"rare", "family": &"lance", "from": &"dredge_screw"},
	# A second rare lance, from the glass desert's own material: two roads to
	# the same rung, one across the moss and one across the glass.
	&"lance_glass": {"grade": &"rare", "family": &"lance", "from": &"fulgurite_core"},
	&"lance_die": {"grade": &"prime", "family": &"lance", "from": &"clerk_die"},
	&"blade_die": {"grade": &"prime", "family": &"thin", "from": &"clerk_die"},
	# The relic. Three sockets like a prime, and one thing nothing else does. A
	# pour of it that goes wrong hands back the blade that went into it: `flawed`
	# is what "flawed but usable" means in data (CraftTiers).
	&"blade_seal": {"grade": &"relic", "family": &"thin", "from": &"clerk_die",
		"flawed": &"blade_die",
		"unique": "the only thing you can hold that wears their name"},

	# --- WORN rungs: a family of gear, graded the same way -----------------
	# The grapple brace (`boots_magnet`, the hands piece that grants `grapple`)
	# is a family like a knife's: every rung grants the same ability and the
	# same resists, and what a rung buys is sockets. The Ruined Metropolis is a
	# vertical city, so it is where the climbing brace is raised: its top rung
	# is made of the ram out of the city's own demolisher (docs/LANDSCAPES.md §4).
	&"boots_magnet": {"grade": &"uncommon", "family": &"brace"},
	&"brace_cable": {"grade": &"rare", "family": &"brace", "from": &"tower_cable"},
	&"brace_ram": {"grade": &"prime", "family": &"brace", "from": &"boom_ram"},
	# The glide wing is a family the same way (docs/LANDSCAPES.md §6): every rung
	# glides and resists alike, and what the mesas' span wire buys is a second
	# socket. A land of drops is where the wing is raised.
	&"glide_wing": {"grade": &"uncommon", "family": &"wing"},
	&"wing_span": {"grade": &"rare", "family": &"wing", "from": &"span_wire"},

	# --- modules: the modifiers themselves (ModifierTable says what each does) --
	&"mod_wadding": {"grade": &"common", "family": &""},
	&"mod_filter": {"grade": &"common", "family": &""},
	&"mod_shade": {"grade": &"common", "family": &""},
	&"mod_grip": {"grade": &"common", "family": &""},
	&"mod_wick": {"grade": &"common", "family": &""},
	&"mod_foil": {"grade": &"uncommon", "family": &""},
	&"mod_spring": {"grade": &"uncommon", "family": &""},
	&"mod_signet": {"grade": &"rare", "family": &""},
	&"mod_gyro": {"grade": &"uncommon", "family": &"", "from": &"haul_gyro"},
	&"mod_clamp": {"grade": &"uncommon", "family": &"", "from": &"tide_iron"},
	&"mod_ablative": {"grade": &"uncommon", "family": &"", "from": &"cinder_glass"},
	&"mod_cooling": {"grade": &"rare", "family": &"", "from": &"bog_iron"},
	&"mod_capacitor": {"grade": &"rare", "family": &"", "from": &"line_coil"},
	&"mod_harmonic": {"grade": &"rare", "family": &"", "from": &"mono_edge"},
	&"mod_damp": {"grade": &"rare", "family": &"", "from": &"frost_varnish"},
	&"mod_hush": {"grade": &"rare", "family": &"", "from": &"hush_slate"},
	&"mod_icelens": {"grade": &"rare", "family": &"", "from": &"deep_ice_lens"},
	&"mod_seal": {"grade": &"rare", "family": &"", "from": &"brine_copper"},
	&"mod_leech": {"grade": &"prime", "family": &"", "from": &"clerk_die"},
	&"mod_phase": {"grade": &"prime", "family": &"", "from": &"keeper_lens"},
	# The shock lattice had no `from` (docs/VISION.md §6.1 names the gap): it is
	# wound round a fulgurite core now, so the glass desert is its gate.
	&"mod_lattice": {"grade": &"prime", "family": &"", "from": &"fulgurite_core"},
}

## Mechanical numbers a family holds equal across its rungs: the fight, the
## reach, the timing and the work rate. Everything a grade is NOT allowed to buy.
const SAME_ACROSS_A_FAMILY: Array[StringName] = [&"dmg", &"reach", &"width", &"swing",
	&"knock", &"knock_ms", &"speed", &"bite", &"wick", &"verb", &"stuff"]


static func row(id: StringName) -> Dictionary:
	return PIECES.get(id, {})


static func has(id: StringName) -> bool:
	return PIECES.has(id)


static func ids() -> Array:
	return PIECES.keys()


## The grade as `Rarity` counts them; anything not in the tree is COMMON, so a
## reader never has to ask whether a thing was declared.
static func grade(id: StringName) -> int:
	return Rarity.of_name(row(id).get("grade", &"common"))


static func family(id: StringName) -> StringName:
	return row(id).get("family", &"")


## The elite material this rung is made of, &"" for the ordinary rungs.
static func made_of(id: StringName) -> StringName:
	return row(id).get("from", &"")


static func unique(id: StringName) -> String:
	return row(id).get("unique", "")


## Every rung of a family, weakest grade first, then by id so the order is fixed.
static func rungs(f: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if f == &"":
		return out
	for id: StringName in PIECES:
		if family(id) == f:
			out.append(id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		if grade(a) != grade(b):
			return grade(a) < grade(b)
		return String(a) < String(b))
	return out


## Every family with more than one rung: the ladders the promise is tested on.
static func ladders() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in PIECES:
		var f := family(id)
		if f != &"" and not out.has(f) and rungs(f).size() > 1:
			out.append(f)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## Everything at one grade, for a slate that says what a grade is worth.
static func at_grade(g: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in PIECES:
		if grade(id) == g:
			out.append(id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out
