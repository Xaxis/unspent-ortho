class_name Recipes
## Every recipe, as data (docs/research/design-extract.md §9.6, with the trade
## rungs replaced by making, since there is no money). Crafting reads this;
## nothing else should.
##
## A recipe:
##   id: StringName
##   at: StringName        where: hand (anywhere) fire bench kiln wheel loom
##   minutes: float        world minutes charged when made
##   needs: {item: n}      consumed
##   makes: {item: n}      added (empty for builds and actions)
##   tool: StringName      a carried tool with this verb is required (whittling needs a blade)
##   keeps: {item: n}      required, not consumed (a hone)
##   builds: StringName    puts a station in the world in front of you: fire bench kiln
##   action: StringName    works on the held tool instead of making: hone reedge
##
## Design notes where this departs from the source:
## - Tools take a `haft`, whittled from driftwood, dead wood or timber with a
##   blade. The source used timber, which needs an axe, which needs timber;
##   without trade that loop had no way in. Wood picked up is the way in.
## - Plate from a tip makes only the way-in tools: a knife and a pick. Every
##   other edge (axe, mattock, billhook) needs iron, and iron comes only from
##   ore, so the first pick has a job to do. (The source bought these.)
## - Re-edging costs charcoal, not coin.
## - Pacing (M1.5): the source's minutes jumped the clock from a menu, so a first
##   pick landed at night. Station work runs at about a third of them and
##   anything past Survival.MAX_JUMP_MINUTES (30) is set going on the station
##   to finish in world time while the player walks (Crafting.sets_going); hand
##   work and building jump the clock 30 minutes at most.

const LIST: Array[Dictionary] = [
	# --- By hand, anywhere ---
	{"id": &"campfire", "at": &"hand", "minutes": 10.0, "needs": {&"driftwood": 3, &"stone": 2}, "makes": {}, "builds": &"fire"},
	{"id": &"campfire_timber", "at": &"hand", "minutes": 10.0, "needs": {&"timber": 1, &"stone": 2}, "makes": {}, "builds": &"fire"},
	{"id": &"campfire_deadwood", "at": &"hand", "minutes": 10.0, "needs": {&"deadwood": 3, &"stone": 2}, "makes": {}, "builds": &"fire"},
	{"id": &"campfire_peat", "at": &"hand", "minutes": 10.0, "needs": {&"peat": 3, &"stone": 2}, "makes": {}, "builds": &"fire"},
	{"id": &"haft", "at": &"hand", "minutes": 15.0, "needs": {&"driftwood": 2}, "makes": {&"haft": 1}, "tool": &"cut"},
	{"id": &"haft_deadwood", "at": &"hand", "minutes": 15.0, "needs": {&"deadwood": 2}, "makes": {&"haft": 1}, "tool": &"cut"},
	{"id": &"haft_timber", "at": &"hand", "minutes": 15.0, "needs": {&"timber": 1}, "makes": {&"haft": 2}, "tool": &"cut"},
	{"id": &"hone", "at": &"hand", "minutes": 25.0, "needs": {&"stone": 1}, "makes": {&"hone": 1}},
	{"id": &"sharpen", "at": &"hand", "minutes": 20.0, "needs": {}, "makes": {}, "keeps": {&"hone": 1}, "action": &"hone"},
	{"id": &"stave", "at": &"hand", "minutes": 30.0, "needs": {&"timber": 1}, "makes": {&"stave": 1}, "tool": &"cut"},
	{"id": &"bench", "at": &"hand", "minutes": 30.0, "needs": {&"timber": 3, &"scrap": 1}, "makes": {}, "builds": &"bench"},
	{"id": &"kiln", "at": &"hand", "minutes": 30.0, "needs": {&"stone": 8}, "makes": {}, "builds": &"kiln"},

	# --- Fire ---
	{"id": &"reedge", "at": &"fire", "minutes": 30.0, "needs": {&"charcoal": 1}, "makes": {}, "action": &"reedge"},
	# A hearthstone does what a hone does, a little slower, for anyone who sits at a fire.
	{"id": &"sharpen_fire", "at": &"fire", "minutes": 30.0, "needs": {}, "makes": {}, "action": &"hone"},
	{"id": &"charcoal", "at": &"fire", "minutes": 40.0, "needs": {&"driftwood": 4}, "makes": {&"charcoal": 2}},
	{"id": &"charcoal_deadwood", "at": &"fire", "minutes": 40.0, "needs": {&"deadwood": 4}, "makes": {&"charcoal": 2}},
	{"id": &"charcoal_wood", "at": &"fire", "minutes": 40.0, "needs": {&"timber": 2}, "makes": {&"charcoal": 2}},
	{"id": &"tin", "at": &"fire", "minutes": 80.0, "needs": {&"tin_ore": 3, &"charcoal": 2}, "makes": {&"tin": 1}},
	{"id": &"iron", "at": &"fire", "minutes": 100.0, "needs": {&"iron_ore": 3, &"charcoal": 2}, "makes": {&"iron": 1}},
	{"id": &"iron_coal", "at": &"fire", "minutes": 100.0, "needs": {&"iron_ore": 3, &"coal": 2}, "makes": {&"iron": 1}},
	{"id": &"copper", "at": &"fire", "minutes": 80.0, "needs": {&"copper_ore": 3, &"charcoal": 2}, "makes": {&"copper": 1}},
	{"id": &"pitch", "at": &"fire", "minutes": 70.0, "needs": {&"resin": 4}, "makes": {&"pitch": 1}},
	{"id": &"oil", "at": &"fire", "minutes": 90.0, "needs": {&"resin": 2}, "makes": {&"oil": 1}},
	# The shore's lamp oil: whelks rendered down. Slower and dearer than pine resin.
	{"id": &"oil_whelks", "at": &"fire", "minutes": 40.0, "needs": {&"whelks": 3}, "makes": {&"oil": 1}},
	{"id": &"dye", "at": &"fire", "minutes": 90.0, "needs": {&"crottle": 5}, "makes": {&"dye": 1}},
	{"id": &"soup", "at": &"fire", "minutes": 40.0, "needs": {&"mussels": 3, &"wrack": 1}, "makes": {&"soup": 2}},
	{"id": &"stew", "at": &"fire", "minutes": 60.0, "needs": {&"mussels": 4, &"samphire": 2}, "makes": {&"stew": 2}},
	{"id": &"smoked", "at": &"fire", "minutes": 70.0, "needs": {&"whelks": 5, &"driftwood": 3}, "makes": {&"smoked": 2}},
	# The way in: plate beaten to an edge. Nothing else is made from plate alone.
	{"id": &"knife_made", "at": &"fire", "minutes": 40.0, "needs": {&"scrap": 1, &"charcoal": 1}, "makes": {&"knife": 1}},
	{"id": &"pick_made", "at": &"fire", "minutes": 45.0, "needs": {&"scrap": 1, &"haft": 1, &"charcoal": 1}, "makes": {&"pick": 1}},
	{"id": &"pick_iron", "at": &"fire", "minutes": 80.0, "needs": {&"iron": 1, &"haft": 1, &"charcoal": 1}, "makes": {&"pick": 1}},
	{"id": &"axe_iron", "at": &"fire", "minutes": 90.0, "needs": {&"iron": 1, &"haft": 1, &"charcoal": 1}, "makes": {&"axe_hand": 1}},
	{"id": &"mattock_iron", "at": &"fire", "minutes": 100.0, "needs": {&"iron": 2, &"haft": 1, &"charcoal": 1}, "makes": {&"mattock": 1}},
	{"id": &"billhook_iron", "at": &"fire", "minutes": 70.0, "needs": {&"iron": 1, &"haft": 1, &"charcoal": 1}, "makes": {&"billhook": 1}},
	{"id": &"boathook_made", "at": &"fire", "minutes": 50.0, "needs": {&"scrap": 1, &"haft": 2, &"charcoal": 1}, "makes": {&"boathook": 1}},

	# --- Bench ---
	{"id": &"pot", "at": &"bench", "minutes": 100.0, "needs": {&"tin": 2}, "makes": {&"pot": 1}},
	{"id": &"basket", "at": &"bench", "minutes": 40.0, "needs": {&"reeds": 6}, "makes": {&"basket": 1}},
	{"id": &"oilcloth", "at": &"bench", "minutes": 40.0, "needs": {&"yarn": 2, &"pitch": 1}, "makes": {&"oilcloth": 1}},
	{"id": &"lamp", "at": &"bench", "minutes": 60.0, "needs": {&"tin": 1, &"copper": 1}, "makes": {&"lamp": 1}},
	{"id": &"kit_plate", "at": &"bench", "minutes": 80.0, "needs": {&"scrap": 3, &"iron": 1}, "makes": {&"kit_plate": 1}},
	{"id": &"kit_brace", "at": &"bench", "minutes": 60.0, "needs": {&"scrap": 2, &"timber": 1, &"iron": 1}, "makes": {&"kit_brace": 1}},
	{"id": &"kit_rig", "at": &"bench", "minutes": 50.0, "needs": {&"scrap": 1, &"yarn": 3, &"oilcloth": 1}, "makes": {&"kit_rig": 1}},
	{"id": &"kit_lens", "at": &"bench", "minutes": 70.0, "needs": {&"scrap": 1, &"tin": 1, &"resin": 1}, "makes": {&"kit_lens": 1}},
	{"id": &"kit_aerial", "at": &"bench", "minutes": 55.0, "needs": {&"scrap": 2, &"tin": 2}, "makes": {&"kit_aerial": 1}},

	# --- Gear against a place's pressures (docs/VISION.md §6) ---
	# Made: rags off what people left, packed with dried wrack and sealed with pitch.
	{"id": &"scarf_mask", "at": &"hand", "minutes": 20.0, "needs": {&"rag": 2, &"charcoal": 1}, "makes": {&"scarf_mask": 1}, "tool": &"cut"},
	{"id": &"mod_wadding", "at": &"hand", "minutes": 20.0, "needs": {&"rag": 2, &"wrack": 2}, "makes": {&"mod_wadding": 1}, "tool": &"cut"},
	{"id": &"mod_filter", "at": &"hand", "minutes": 25.0, "needs": {&"rag": 1, &"charcoal": 2}, "makes": {&"mod_filter": 1}, "tool": &"cut"},
	{"id": &"mod_grip", "at": &"hand", "minutes": 15.0, "needs": {&"rag": 1, &"pitch": 1}, "makes": {&"mod_grip": 1}, "tool": &"cut"},
	# Both by hand, from what a dry flat and a dead wood actually give you: the
	# landscapes that press hardest are reached on day two, with a knife and no
	# bench (playtest 3 and 7).
	{"id": &"mod_shade", "at": &"hand", "minutes": 25.0, "needs": {&"rag": 2, &"driftwood": 2}, "makes": {&"mod_shade": 1}, "tool": &"cut"},
	{"id": &"mitts_corded", "at": &"hand", "minutes": 20.0, "needs": {&"rag": 2, &"pitch": 1}, "makes": {&"mitts_corded": 1}, "tool": &"cut"},
	# A wick lamp is a cup, a rag and the oil the lamp already burns: by hand,
	# so the dark of a city can be answered from a belt on the day it is reached.
	{"id": &"mod_wick", "at": &"hand", "minutes": 20.0, "needs": {&"tin": 1, &"rag": 1, &"oil": 1}, "makes": {&"mod_wick": 1}, "tool": &"cut"},
	# The whole MADE tier is hand work, and these three were the exception for no
	# reason but the order they were written in. A made piece is cloth, reed and
	# pitch, cut and bound: a bench is for MENDED work, where machine parts are
	# fitted to a frame. Leaving them at a bench put the answer to cold, wet and
	# glare a day's walk and a day's building behind the landscapes that press
	# with them, which are the ones a player reaches first (tests/hazards/test_day_two).
	# Each under Survival.MAX_JUMP_MINUTES, because a hand recipe cannot be set
	# going at a station and jumps the clock whole.
	{"id": &"wrap_warm", "at": &"hand", "minutes": 30.0, "needs": {&"rag": 3, &"wrack": 2, &"pitch": 1}, "makes": {&"wrap_warm": 1}, "tool": &"cut"},
	{"id": &"oilskin", "at": &"hand", "minutes": 28.0, "needs": {&"rag": 3, &"pitch": 2}, "makes": {&"oilskin": 1}, "tool": &"cut"},
	{"id": &"hat_brim", "at": &"hand", "minutes": 26.0, "needs": {&"rag": 2, &"reeds": 3, &"pitch": 1}, "makes": {&"hat_brim": 1}, "tool": &"cut"},
	# Mended: plate and wire off the machines, bound to a made frame. Both idioms show.
	{"id": &"mod_foil", "at": &"bench", "minutes": 50.0, "needs": {&"scrap": 2, &"tin": 2}, "makes": {&"mod_foil": 1}},
	{"id": &"mod_spring", "at": &"bench", "minutes": 60.0, "needs": {&"scrap": 2, &"iron": 1}, "makes": {&"mod_spring": 1}},
	{"id": &"rebreather", "at": &"bench", "minutes": 80.0, "needs": {&"scrap": 2, &"tin": 1, &"charcoal": 2, &"rag": 2}, "makes": {&"rebreather": 1}},
	{"id": &"boots_magnet", "at": &"bench", "minutes": 85.0, "needs": {&"scrap": 2, &"iron": 2, &"copper": 1}, "makes": {&"boots_magnet": 1}},
	{"id": &"vest_heatsink", "at": &"bench", "minutes": 90.0, "needs": {&"scrap": 3, &"copper": 2, &"rag": 2}, "makes": {&"vest_heatsink": 1}},
	{"id": &"scanner_lens", "at": &"bench", "minutes": 95.0, "needs": {&"scrap": 1, &"tin": 1, &"copper": 1, &"resin": 2}, "makes": {&"scanner_lens": 1}},
	{"id": &"condenser", "at": &"bench", "minutes": 75.0, "needs": {&"scrap": 2, &"copper": 2, &"rag": 1}, "makes": {&"condenser": 1}},
	{"id": &"glide_wing", "at": &"bench", "minutes": 110.0, "needs": {&"scrap": 4, &"timber": 2, &"rag": 3, &"pitch": 1}, "makes": {&"glide_wing": 1}},

	# --- The elite materials (EliteStock: each from one landscape or one machine) -
	# The journey is the gate, not the clock: the recipe is open to anyone and the
	# INPUT is what has to be walked to. A kiln pour can go wrong (CraftTiers).
	{"id": &"cinder_glass", "at": &"kiln", "minutes": 160.0, "needs": {&"brimstone": 2, &"coal": 2}, "makes": {&"cinder_glass": 1}},
	{"id": &"clint_spar", "at": &"kiln", "minutes": 150.0, "needs": {&"limestone": 3, &"charcoal": 2}, "makes": {&"clint_spar": 1}},
	# The crags' own: two hushstone is one carved face broken up entirely
	# (Takes: uses 2), so a slate costs a face, and the kiln is where it is fired
	# to the stone a scanner reads as nothing.
	{"id": &"hush_slate", "at": &"kiln", "minutes": 150.0, "needs": {&"hushstone": 2, &"charcoal": 2}, "makes": {&"hush_slate": 1}},
	{"id": &"bog_iron", "at": &"fire", "minutes": 120.0, "needs": {&"peat": 4, &"charcoal": 2}, "makes": {&"bog_iron": 1}},
	{"id": &"frost_varnish", "at": &"fire", "minutes": 100.0, "needs": {&"crottle": 3, &"oil": 1}, "makes": {&"frost_varnish": 1}},
	# Ground at the bench with oil for the polish: two cuts of lens ice for one
	# lens, because the first is always cloudy.
	{"id": &"deep_ice_lens", "at": &"bench", "minutes": 90.0, "needs": {&"lens_ice": 2, &"oil": 1}, "makes": {&"deep_ice_lens": 1}},
	{"id": &"fulgurite_core", "at": &"kiln", "minutes": 150.0, "needs": {&"fulgurite": 3, &"charcoal": 2}, "makes": {&"fulgurite_core": 1}},
	# Lift rope annealed in the fire and laid up again: the city's own.
	{"id": &"tower_cable", "at": &"fire", "minutes": 110.0, "needs": {&"lift_cable": 2, &"charcoal": 1}, "makes": {&"tower_cable": 1}},
	# The mesas' span wire: the ropeway's rope annealed at the fire, the one hot
	# station a person builds (the spec's "forge", as the city's cable reads it).
	{"id": &"span_wire", "at": &"fire", "minutes": 110.0, "needs": {&"rope_steel": 2, &"charcoal": 1}, "makes": {&"span_wire": 1}},
	# Nothing is dead loot: what a ruined pour leaves is still plate.
	{"id": &"spoil_scrap", "at": &"fire", "minutes": 30.0, "needs": {&"spoil": 2, &"charcoal": 1}, "makes": {&"scrap": 1}},

	# --- MENDED implements, rare: the common tool with a mount bound to it --------
	# Same edge, same swing, two sockets. What it cost was the journey.
	{"id": &"knife_spar", "at": &"bench", "minutes": 95.0, "needs": {&"knife": 1, &"clint_spar": 1, &"rag": 1}, "makes": {&"knife_spar": 1}},
	{"id": &"axe_bog", "at": &"bench", "minutes": 105.0, "needs": {&"axe_hand": 1, &"bog_iron": 1, &"pitch": 1}, "makes": {&"axe_bog": 1}},
	{"id": &"bill_glass", "at": &"bench", "minutes": 100.0, "needs": {&"billhook": 1, &"cinder_glass": 1, &"rag": 1}, "makes": {&"bill_glass": 1}},
	{"id": &"mattock_bog", "at": &"bench", "minutes": 110.0, "needs": {&"mattock": 1, &"bog_iron": 1, &"pitch": 1}, "makes": {&"mattock_bog": 1}},
	{"id": &"pick_spar", "at": &"bench", "minutes": 110.0, "needs": {&"pick": 1, &"clint_spar": 1, &"rag": 1}, "makes": {&"pick_spar": 1}},
	{"id": &"stave_varnish", "at": &"bench", "minutes": 80.0, "needs": {&"stave": 1, &"frost_varnish": 1, &"rag": 1}, "makes": {&"stave_varnish": 1}},
	{"id": &"hook_varnish", "at": &"bench", "minutes": 90.0, "needs": {&"boathook": 1, &"frost_varnish": 1, &"pitch": 1}, "makes": {&"hook_varnish": 1}},
	# The grapple brace re-cabled with the city's own rope: a vertical city is
	# where you climb (GearTree family `brace`).
	{"id": &"brace_cable", "at": &"bench", "minutes": 100.0, "needs": {&"boots_magnet": 1, &"tower_cable": 1, &"rag": 1}, "makes": {&"brace_cable": 1}},
	# The glide wing re-strung with the mesas' span wire (GearTree family
	# `wing`): the wing that goes into it is the wing that comes out, stiffer.
	{"id": &"wing_span", "at": &"bench", "minutes": 100.0, "needs": {&"glide_wing": 1, &"span_wire": 1, &"rag": 2}, "makes": {&"wing_span": 1}},
	# A beam or a lance a person BUILT, out of plate, a charge and one machine part:
	# found tech taken whole can never be mended, so the mended rung is not a
	# stolen weapon rehafted — it is one made from the same refuse.
	{"id": &"beam_hafted", "at": &"bench", "minutes": 120.0, "needs": {&"scrap": 2, &"tide_iron": 1, &"wick": 2, &"haft": 1}, "makes": {&"beam_hafted": 1}},
	{"id": &"arc_hafted", "at": &"bench", "minutes": 115.0, "needs": {&"scrap": 2, &"mono_edge": 1, &"wick": 2, &"haft": 1}, "makes": {&"arc_hafted": 1}},
	{"id": &"hammer_hafted", "at": &"bench", "minutes": 130.0, "needs": {&"scrap": 3, &"haul_gyro": 1, &"wick": 2, &"haft": 1}, "makes": {&"hammer_hafted": 1}},
	{"id": &"lance_hafted", "at": &"bench", "minutes": 125.0, "needs": {&"scrap": 2, &"dredge_screw": 1, &"wick": 2, &"haft": 2}, "makes": {&"lance_hafted": 1}},
	# The glass desert's road to the same rung: a skater's blade bound round a
	# fulgurite core, both got on the glass.
	{"id": &"lance_glass", "at": &"bench", "minutes": 125.0, "needs": {&"scrap": 2, &"fulgurite_core": 1, &"skate_blade": 1, &"wick": 2, &"haft": 2}, "makes": {&"lance_glass": 1}},

	# --- MENDED implements, prime: the rare rung again, on their own jig ---------
	# The top rung is a bench with a FOUND jig kept in hand (CraftTiers.JIG), cut
	# off a hunter. Nothing a person built reaches it, and a pour can go wrong.
	{"id": &"knife_mono", "at": &"bench", "minutes": 150.0, "needs": {&"knife_spar": 1, &"mono_edge": 1, &"copper": 1}, "keeps": {&"fab_jig": 1}, "makes": {&"knife_mono": 1}},
	{"id": &"axe_tide", "at": &"bench", "minutes": 160.0, "needs": {&"axe_bog": 1, &"tide_iron": 1, &"copper": 1}, "keeps": {&"fab_jig": 1}, "makes": {&"axe_tide": 1}},
	{"id": &"bill_vane", "at": &"bench", "minutes": 155.0, "needs": {&"bill_glass": 1, &"vane_true": 1, &"copper": 1}, "keeps": {&"fab_jig": 1}, "makes": {&"bill_vane": 1}},
	{"id": &"mattock_gyro", "at": &"bench", "minutes": 165.0, "needs": {&"mattock_bog": 1, &"haul_gyro": 1, &"copper": 1}, "keeps": {&"fab_jig": 1}, "makes": {&"mattock_gyro": 1}},
	{"id": &"pick_glass", "at": &"bench", "minutes": 165.0, "needs": {&"pick_spar": 1, &"cinder_glass": 2, &"copper": 1}, "keeps": {&"fab_jig": 1}, "makes": {&"pick_glass": 1}},
	{"id": &"stave_coil", "at": &"bench", "minutes": 140.0, "needs": {&"stave_varnish": 1, &"line_coil": 1, &"copper": 1}, "keeps": {&"fab_jig": 1}, "makes": {&"stave_coil": 1}},
	{"id": &"hook_screw", "at": &"bench", "minutes": 150.0, "needs": {&"hook_varnish": 1, &"dredge_screw": 1, &"copper": 1}, "keeps": {&"fab_jig": 1}, "makes": {&"hook_screw": 1}},
	{"id": &"beam_lens", "at": &"bench", "minutes": 170.0, "needs": {&"beam_hafted": 1, &"keeper_lens": 1, &"copper": 1}, "keeps": {&"fab_jig": 1}, "makes": {&"beam_lens": 1}},
	{"id": &"lance_die", "at": &"bench", "minutes": 170.0, "needs": {&"lance_hafted": 1, &"clerk_die": 1, &"copper": 1}, "keeps": {&"fab_jig": 1}, "makes": {&"lance_die": 1}},
	{"id": &"blade_die", "at": &"bench", "minutes": 180.0, "needs": {&"scrap": 3, &"clerk_die": 1, &"wick": 2, &"copper": 2}, "keeps": {&"fab_jig": 1}, "makes": {&"blade_die": 1}},
	# The relic: a filer's die set into a blade, so the thing in your hand wears
	# their name. A pour that fails leaves the flawed twin, which still works.
	{"id": &"blade_seal", "at": &"bench", "minutes": 240.0, "needs": {&"blade_die": 1, &"clerk_die": 1, &"keeper_lens": 1, &"copper": 2}, "keeps": {&"fab_jig": 1}, "makes": {&"blade_seal": 1}},
	# The grapple brace's top rung, on the jig like every prime: the cabled
	# brace with a demolisher's ram bolted to it (GearTree family `brace`).
	{"id": &"brace_ram", "at": &"bench", "minutes": 160.0, "needs": {&"brace_cable": 1, &"boom_ram": 1, &"copper": 1}, "keeps": {&"fab_jig": 1}, "makes": {&"brace_ram": 1}},

	# --- the modifiers (ModifierTable says what each one decides) ----------------
	# Half an hour at a bench for everything below the jig, because the work is
	# lashing one part to another; the months are in the MATERIAL, which is a
	# landscape away or inside a machine. Half an hour is also under
	# Survival.MAX_JUMP_MINUTES, so a modifier is finished in the hand rather than
	# left cooking on the bench -- which is what makes it something a player can
	# decide to make when they see what the next landscape does to them.
	{"id": &"mod_gyro", "at": &"bench", "minutes": 30.0, "needs": {&"scrap": 2, &"haul_gyro": 1, &"rag": 1}, "makes": {&"mod_gyro": 1}},
	{"id": &"mod_clamp", "at": &"bench", "minutes": 30.0, "needs": {&"scrap": 2, &"tide_iron": 1, &"iron": 1}, "makes": {&"mod_clamp": 1}},
	{"id": &"mod_ablative", "at": &"bench", "minutes": 30.0, "needs": {&"scrap": 2, &"cinder_glass": 1, &"pitch": 1}, "makes": {&"mod_ablative": 1}},
	{"id": &"mod_cooling", "at": &"bench", "minutes": 30.0, "needs": {&"scrap": 1, &"bog_iron": 1, &"copper": 2}, "makes": {&"mod_cooling": 1}},
	{"id": &"mod_capacitor", "at": &"bench", "minutes": 30.0, "needs": {&"scrap": 1, &"line_coil": 1, &"copper": 1, &"wick": 2}, "makes": {&"mod_capacitor": 1}},
	{"id": &"mod_harmonic", "at": &"bench", "minutes": 30.0, "needs": {&"mono_edge": 1, &"haft": 1, &"pitch": 1}, "makes": {&"mod_harmonic": 1}},
	{"id": &"mod_damp", "at": &"bench", "minutes": 30.0, "needs": {&"frost_varnish": 1, &"rag": 2, &"pitch": 1}, "makes": {&"mod_damp": 1}},
	{"id": &"mod_hush", "at": &"bench", "minutes": 40.0, "needs": {&"hush_slate": 1, &"rag": 2, &"scrap": 1}, "makes": {&"mod_hush": 1}},
	{"id": &"mod_icelens", "at": &"bench", "minutes": 40.0, "needs": {&"deep_ice_lens": 1, &"scrap": 1, &"rag": 1}, "makes": {&"mod_icelens": 1}},
	{"id": &"mod_leech", "at": &"bench", "minutes": 140.0, "needs": {&"clerk_die": 1, &"copper": 2, &"wick": 2}, "keeps": {&"fab_jig": 1}, "makes": {&"mod_leech": 1}},
	{"id": &"mod_phase", "at": &"bench", "minutes": 145.0, "needs": {&"keeper_lens": 1, &"copper": 2, &"resin": 2}, "keeps": {&"fab_jig": 1}, "makes": {&"mod_phase": 1}},
	{"id": &"mod_lattice", "at": &"bench", "minutes": 150.0, "needs": {&"scrap": 3, &"copper": 2, &"wick": 2, &"fulgurite_core": 1}, "keeps": {&"fab_jig": 1}, "makes": {&"mod_lattice": 1}},
	# --- Crafts (docs/VISION.md §5) ---
	# A raft is lashed at the shore out of what the tide brings and one drum off a
	# wreck: the first craft, reachable on day one. The mended two need a bench,
	# iron and a machine's own ducts and legs.
	{"id": &"raft", "at": &"hand", "minutes": 30.0, "needs": {&"driftwood": 6, &"scrap": 1, &"rag": 2}, "makes": {&"raft": 1}, "tool": &"cut"},
	{"id": &"hover_sled", "at": &"bench", "minutes": 120.0, "needs": {&"scrap": 4, &"iron": 2, &"timber": 2, &"copper": 1, &"rag": 2}, "makes": {&"hover_sled": 1}},
	{"id": &"walker_rig", "at": &"bench", "minutes": 140.0, "needs": {&"scrap": 5, &"iron": 3, &"timber": 3, &"rag": 2}, "makes": {&"walker_rig": 1}},

	# --- Wheel and loom (inside houses, once there are interiors) ---
	{"id": &"yarn", "at": &"wheel", "minutes": 50.0, "needs": {&"wool": 3}, "makes": {&"yarn": 1}},
	{"id": &"blanket", "at": &"loom", "minutes": 140.0, "needs": {&"yarn": 4}, "makes": {&"blanket": 1}},

	# --- Kiln: lime, ash, and steel by cementation (the tool is eaten for a day or more) ---
	{"id": &"lime", "at": &"kiln", "minutes": 80.0, "needs": {&"limestone": 3, &"coal": 2}, "makes": {&"lime": 2}},
	{"id": &"lime_gorse", "at": &"kiln", "minutes": 80.0, "needs": {&"limestone": 3, &"gorse_cut": 5}, "makes": {&"lime": 2}},
	{"id": &"kelp_ash", "at": &"kiln", "minutes": 100.0, "needs": {&"wrack": 8}, "makes": {&"kelp_ash": 1}},
	{"id": &"knife_cemented", "at": &"kiln", "minutes": 300.0, "needs": {&"knife": 1, &"charcoal": 4}, "makes": {&"knife_shear": 1}},
	{"id": &"axe_cemented", "at": &"kiln", "minutes": 600.0, "needs": {&"axe_hand": 1, &"charcoal": 8}, "makes": {&"axe_felling": 1}},
	{"id": &"mattock_cemented", "at": &"kiln", "minutes": 600.0, "needs": {&"mattock": 1, &"charcoal": 8}, "makes": {&"mattock_steel": 1}},
	{"id": &"pick_cemented", "at": &"kiln", "minutes": 600.0, "needs": {&"pick": 1, &"charcoal": 8}, "makes": {&"pick_steel": 1}},

	# --- Raids: what a machine was carrying about you (docs/VISION.md §9.2) ---
	# A filed record is their own account of a place, taken off the body that was
	# walking home with it. Stripped with a blade it is what it is made of: a spool
	# of copper and a foil card, which is the stuff a signet is wound from. Nobody
	# out here is sentimental about proof. It is a found thing, so it can never be
	# MADE (tests/survival/test_crafting.gd: the top rung stays found). Its deeper
	# use is as the gate to the spoofer a player can BUILD (StructureKind.SPOOFER
	# costs one), so stripping it for copper is a choice with a price.
	{"id": &"record_stripped", "at": &"hand", "minutes": 10.0, "needs": {&"record": 1}, "makes": {&"copper": 1}, "tool": &"cut"},
]
