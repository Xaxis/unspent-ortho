class_name Items
## Every item, as data. Mechanics numbers are the source's
## (docs/research/design-extract.md §9.2-9.4); display names are plain
## placeholders until the story rewrite renames them. Money is gone: no item
## carries a price.
##
## Schema (all optional except name, bulk):
##   name: String          what the player sees
##   bulk: float           weight toward load (creel 40)
##   group: StringName     tool found material food good kit (how a UI sorts)
##   tool: bool            has an edge; can be held
##   verb: StringName      work verb it enables: break dig fell cut (&"" = a weapon only)
##   stuff: StringName     hardness: wood iron steel crucible found
##   speed: int            work speed, 10000 = bare-hand minutes (lower is faster)
##   bite: int             uses per full edge (0 = never dulls)
##   swing: Array[int]     [windup, active, recovery, cooldown] ms
##   reach: float, width: float, dmg: int, knock: float, knock_ms: int
##   wick: int             found weapons: charges spent per swing (unmendable)
##   feeds: float          hours of food
##   kit: StringName       wearable salvage slot (one worn at a time)
##   creel: float          extra load carried without slowing (worn kit, or carried basket)
##   health: int, wind: float, sight: float, hearing: float   what a worn kit adds
##
## Gear and modules (the hazards package; src/core/gear/gear.gd reads these):
##   slot: StringName      head body hands back tool craft: a piece worn there
##   sockets: int          modules the piece takes
##   module: true          it is a module; `fits` lists the slots it may sit in
##   resist: {hazard: 0..1}  pressures it keeps off (src/core/hazards/hazards.gd)
##   ability: StringName   the ability it grants while fitted (src/core/gear/abilities.gd)
##   tier: StringName      made | mended | found, the three idioms (docs/ART.md §12)
##   wears: Dictionary     what a body is seen wearing while it is fitted, in the people
##                         model's words (PersonLook): `hat`/`coat` name one, `extras`,
##                         `salvage`, `gear` add to those lists, and `wing: true` puts
##                         the glide wing on the back. GearLook.compose reads it for the
##                         gear page and the walking figure alike, so the two agree.
##   icon: Array           [shape, ramp, ramp] the slate draws it as; shape names are
##                         UiIcons.SHAPES. A MENDED row must name a shape with cord in
##                         it, or the icon reads as a machine part with no maker.
##   sockets on a tool     a mended implement says how many modules bind to its haft.

## Hardness ladder: a seam needs a tool of at least its stuff.
const STUFF_RANK := {&"wood": 0, &"iron": 1, &"steel": 2, &"crucible": 3, &"found": 4}

## Bare hands, for the fight package: no item, these numbers. (source)
const FISTS := {"swing": [70, 80, 110, 180], "lockout": 440, "reach": 0.6, "width": 0.8, "dmg": 1,
	"knock": 2.5, "knock_ms": 120, "creep": 0.35}

const DEFS := {
	# --- Made ladder (§9.2) ---
	&"knife": {"name": "knife", "bulk": 1.0, "group": &"tool", "tool": true, "verb": &"cut", "stuff": &"iron",
		"speed": 8200, "bite": 90, "swing": [60, 100, 120, 140], "reach": 0.9, "width": 1.0, "dmg": 2, "knock": 4.0, "knock_ms": 150},
	&"stave": {"name": "stave", "bulk": 2.0, "group": &"tool", "tool": true, "verb": &"", "stuff": &"wood",
		"speed": 10000, "bite": 0, "swing": [90, 110, 130, 150], "reach": 1.6, "width": 1.3, "dmg": 2, "knock": 8.0, "knock_ms": 240},
	&"boathook": {"name": "boathook", "bulk": 3.0, "group": &"tool", "tool": true, "verb": &"", "stuff": &"iron",
		"speed": 10000, "bite": 0, "swing": [160, 120, 200, 240], "reach": 2.1, "width": 0.8, "dmg": 2, "knock": 9.5, "knock_ms": 260},
	&"billhook": {"name": "billhook", "bulk": 2.0, "group": &"tool", "tool": true, "verb": &"cut", "stuff": &"iron",
		"speed": 6200, "bite": 120, "swing": [100, 110, 150, 170], "reach": 1.05, "width": 1.5, "dmg": 3, "knock": 5.0, "knock_ms": 170},
	&"axe_hand": {"name": "hand axe", "bulk": 2.0, "group": &"tool", "tool": true, "verb": &"fell", "stuff": &"iron",
		"speed": 6500, "bite": 120, "swing": [130, 120, 170, 200], "reach": 1.15, "width": 1.6, "dmg": 4, "knock": 6.5, "knock_ms": 200},
	&"mattock": {"name": "mattock", "bulk": 4.0, "group": &"tool", "tool": true, "verb": &"dig", "stuff": &"iron",
		"speed": 6500, "bite": 140, "swing": [180, 130, 220, 260], "reach": 1.25, "width": 1.3, "dmg": 3, "knock": 7.5, "knock_ms": 230},
	&"pick": {"name": "pick", "bulk": 4.0, "group": &"tool", "tool": true, "verb": &"break", "stuff": &"iron",
		"speed": 6000, "bite": 140, "swing": [180, 130, 220, 260], "reach": 1.25, "width": 1.2, "dmg": 4, "knock": 7.0, "knock_ms": 220},
	&"knife_shear": {"name": "steel knife", "bulk": 1.0, "group": &"tool", "tool": true, "verb": &"cut", "stuff": &"steel",
		"speed": 7000, "bite": 260, "swing": [55, 95, 105, 125], "reach": 0.95, "width": 1.0, "dmg": 3, "knock": 4.0, "knock_ms": 150},
	&"axe_felling": {"name": "felling axe", "bulk": 4.0, "group": &"tool", "tool": true, "verb": &"fell", "stuff": &"steel",
		"speed": 5200, "bite": 260, "swing": [230, 150, 260, 300], "reach": 1.5, "width": 1.9, "dmg": 5, "knock": 8.5, "knock_ms": 250},
	&"mattock_steel": {"name": "steel mattock", "bulk": 4.0, "group": &"tool", "tool": true, "verb": &"dig", "stuff": &"steel",
		"speed": 5200, "bite": 260, "swing": [190, 130, 230, 270], "reach": 1.25, "width": 1.3, "dmg": 4, "knock": 8.0, "knock_ms": 240},
	# Not in the source: without trade a steel rung for breaking rock is the only way to the hardest seams.
	&"pick_steel": {"name": "steel pick", "bulk": 4.0, "group": &"tool", "tool": true, "verb": &"break", "stuff": &"steel",
		"speed": 5000, "bite": 260, "swing": [190, 130, 230, 270], "reach": 1.25, "width": 1.2, "dmg": 5, "knock": 7.5, "knock_ms": 230},
	# Rare; never craftable.
	&"axe_works": {"name": "fine axe", "bulk": 3.0, "group": &"tool", "tool": true, "verb": &"fell", "stuff": &"crucible",
		"speed": 4200, "bite": 520, "swing": [170, 140, 200, 230], "reach": 1.4, "width": 1.8, "dmg": 6, "knock": 8.0, "knock_ms": 240},

	# --- Found ladder (§9.3): no verb, never mended, spend charges ---
	&"las_hand": {"name": "short beam", "bulk": 1.0, "group": &"found", "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0,
		"wick": 1, "dmg": 7, "swing": [70, 90, 110, 130], "reach": 1.3, "width": 1.1, "knock": 5.0, "knock_ms": 180},
	&"las_long": {"name": "long beam", "bulk": 2.0, "group": &"found", "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0,
		"wick": 2, "dmg": 9, "swing": [160, 110, 190, 230], "reach": 2.0, "width": 1.2, "knock": 6.5, "knock_ms": 220},
	&"las_broad": {"name": "broad beam", "bulk": 2.0, "group": &"found", "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0,
		"wick": 2, "dmg": 7, "swing": [140, 120, 170, 210], "reach": 1.2, "width": 2.6, "knock": 6.0, "knock_ms": 200},
	&"arc_cut": {"name": "arc cutter", "bulk": 1.0, "group": &"found", "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0,
		"wick": 1, "dmg": 10, "swing": [60, 80, 100, 120], "reach": 0.7, "width": 0.8, "knock": 3.0, "knock_ms": 140},
	&"mono_blade": {"name": "thin blade", "bulk": 1.0, "group": &"found", "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0,
		"wick": 1, "dmg": 11, "swing": [45, 80, 90, 110], "reach": 0.9, "width": 0.9, "knock": 2.0, "knock_ms": 120},
	&"stun_hand": {"name": "stunner", "bulk": 1.0, "group": &"found", "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0,
		"wick": 1, "dmg": 2, "swing": [80, 100, 120, 150], "reach": 1.1, "width": 1.0, "knock": 16.0, "knock_ms": 300},
	&"pulse_hammer": {"name": "pulse hammer", "bulk": 3.0, "group": &"found", "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0,
		"wick": 2, "dmg": 5, "swing": [190, 130, 210, 250], "reach": 1.15, "width": 1.6, "knock": 20.0, "knock_ms": 340},
	&"rep_light": {"name": "repeater", "bulk": 1.0, "group": &"found", "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0,
		"wick": 1, "dmg": 3, "swing": [40, 70, 70, 90], "reach": 1.05, "width": 0.9, "knock": 2.5, "knock_ms": 120},
	&"beam_lance": {"name": "lance", "bulk": 2.0, "group": &"found", "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0,
		"wick": 1, "dmg": 8, "swing": [120, 90, 150, 180], "reach": 2.4, "width": 0.7, "knock": 3.5, "knock_ms": 160},
	&"flash_burst": {"name": "flasher", "bulk": 1.0, "group": &"found", "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0,
		"wick": 1, "dmg": 1, "swing": [50, 90, 100, 130], "reach": 1.4, "width": 2.2, "knock": 8.0, "knock_ms": 240},
	&"sonic_wave": {"name": "wave", "bulk": 2.0, "group": &"found", "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0,
		"wick": 2, "dmg": 6, "swing": [110, 120, 140, 170], "reach": 1.3, "width": 2.2, "knock": 9.0, "knock_ms": 260},
	&"plasma_torch": {"name": "torch", "bulk": 2.0, "group": &"found", "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0,
		"wick": 3, "dmg": 12, "swing": [150, 110, 180, 220], "reach": 1.1, "width": 1.3, "knock": 7.0, "knock_ms": 220},
	&"wick": {"name": "charge", "bulk": 0.5, "group": &"found"},
	# A tooth off the frost sea's saw sled (EliteStock.SPOILS icesaw): machine
	# steel, still bright where the ice ran over it.
	&"saw_tooth": {"name": "saw tooth", "bulk": 0.5, "group": &"found", "stuff": &"found", "icon": [&"blade", &"plate", &"lens"]},

	# --- Materials (§9.4) ---
	# Shore goods are lighter than the source's (3, 2, 2, 5; food 1): the creel
	# was full inside the first hour, before one fire, charcoal and a haft.
	&"driftwood": {"name": "driftwood", "bulk": 1.5, "group": &"material"},
	# Not in the source: fallen wood picked up under any tree, so a fire needs no shore.
	&"deadwood": {"name": "dead wood", "bulk": 1.5, "group": &"material"},
	&"wrack": {"name": "wrack", "bulk": 1.0, "group": &"material"},
	&"wool": {"name": "raw wool", "bulk": 1.0, "group": &"material"},
	&"reeds": {"name": "reeds", "bulk": 2.0, "group": &"material"},
	&"gorse_cut": {"name": "cut gorse", "bulk": 2.0, "group": &"material"},
	&"timber": {"name": "timber", "bulk": 6.0, "group": &"material"},
	&"haft": {"name": "haft", "bulk": 1.0, "group": &"material"},
	&"resin": {"name": "resin", "bulk": 1.0, "group": &"material"},
	&"pitch": {"name": "pitch", "bulk": 2.0, "group": &"material"},
	&"peat": {"name": "peat", "bulk": 3.0, "group": &"material"},
	&"crottle": {"name": "crottle", "bulk": 1.0, "group": &"material"},
	&"dye": {"name": "dye", "bulk": 1.0, "group": &"material"},
	&"brimstone": {"name": "brimstone", "bulk": 4.0, "group": &"material"},
	&"limestone": {"name": "limestone", "bulk": 5.0, "group": &"material"},
	# The crags' own raw: broken out of a carved face with a steel edge, refined
	# at the kiln into hush slate (docs/LANDSCAPES.md §1 PLAYER).
	&"hushstone": {"name": "hushstone", "bulk": 4.0, "group": &"material", "icon": [&"hushstone", &"ink", &"slate"]},
	# The lens unscrewed off a survey mast: machine glass, read in the module's
	# violet like everything else taken whole off the plan.
	&"lens_glass": {"name": "lens glass", "bulk": 0.5, "group": &"found", "icon": [&"lens", &"rime", &"lens"]},
	# Links off a chainman's measuring chain (EliteStock.SPOILS): machine chain,
	# read in the module's violet like everything else off a body.
	&"chain_link": {"name": "chain link", "bulk": 0.5, "group": &"found", "icon": [&"coil", &"plate", &"plate"]},
	# Fused-sand tubes broken off a fulgurite on the glass desert: the raw of
	# its own elite material (EliteStock: fulgurite_core), refined at the kiln.
	&"fulgurite": {"name": "fulgurite", "bulk": 2.0, "group": &"material", "icon": [&"fulgurite", &"sand", &"linen"]},
	# Cut out of a keeper, and out of nothing else in the world (src/core/sentinel).
	&"reaper_core": {"name": "reaper core", "bulk": 3.0, "group": &"material"},
	&"rake_core": {"name": "rake core", "bulk": 3.0, "group": &"material"},
	&"plumb_core": {"name": "plumb core", "bulk": 3.0, "group": &"material"},
	&"anvil_core": {"name": "anvil core", "bulk": 3.0, "group": &"material"},
	&"unbuilder_core": {"name": "unbuilder core", "bulk": 3.0, "group": &"material"},
	&"lockkeeper_core": {"name": "lockkeeper core", "bulk": 3.0, "group": &"material"},
	&"lime": {"name": "lime", "bulk": 1.0, "group": &"material"},
	&"salt": {"name": "salt", "bulk": 1.0, "group": &"material"},
	&"kelp_ash": {"name": "kelp ash", "bulk": 1.0, "group": &"material"},
	&"stone": {"name": "stone", "bulk": 3.0, "group": &"material"},
	&"coal": {"name": "coal", "bulk": 3.0, "group": &"material"},
	&"charcoal": {"name": "charcoal", "bulk": 2.0, "group": &"material"},
	&"tin_ore": {"name": "tin ore", "bulk": 4.0, "group": &"material"},
	&"tin": {"name": "tin", "bulk": 1.0, "group": &"material"},
	&"iron_ore": {"name": "iron ore", "bulk": 4.0, "group": &"material"},
	&"iron": {"name": "iron", "bulk": 1.0, "group": &"material"},
	&"copper_ore": {"name": "copper ore", "bulk": 4.0, "group": &"material"},
	&"copper": {"name": "copper", "bulk": 1.0, "group": &"material"},
	# Cut out of a pressure block on the frost sea with a steel edge (Takes): the
	# clear heart of a slab of sea ice, the raw the deep ice lens is ground from.
	&"lens_ice": {"name": "lens ice", "bulk": 1.0, "group": &"material", "icon": [&"lens_ice", &"rime", &"slate"]},
	&"scrap": {"name": "piece of plate", "bulk": 2.0, "group": &"material"},
	# Steel wire rope cut out of a lift core in the Ruined Metropolis: the raw
	# its elite material is drawn from (EliteStock: tower_cable). Machine-made,
	# so it is drawn in the module's violet like plate is.
	&"lift_cable": {"name": "lift cable", "bulk": 2.0, "group": &"material", "icon": [&"cable", &"plate", &"ink"]},
	# Cloth out of what people left: the one soft material a made garment needs.
	&"rag": {"name": "rags", "bulk": 1.0, "group": &"material"},

	# --- Food ---
	&"mussels": {"name": "mussels", "bulk": 0.5, "group": &"food", "feeds": 4.0},
	&"whelks": {"name": "whelks", "bulk": 0.5, "group": &"food", "feeds": 3.0},
	&"samphire": {"name": "samphire", "bulk": 0.5, "group": &"food", "feeds": 2.0},
	# Out of a seal's hole on the frost sea (Takes SEAL_HOLE): the one food the
	# ice gives, and a whole meal.
	&"fish": {"name": "fish", "bulk": 0.5, "group": &"food", "feeds": 5.0, "icon": [&"fish", &"slate", &"rime"]},
	&"berries": {"name": "berries", "bulk": 1.0, "group": &"food", "feeds": 1.5},
	&"bread": {"name": "bread", "bulk": 1.0, "group": &"food", "feeds": 10.0},
	&"soup": {"name": "soup", "bulk": 1.0, "group": &"food", "feeds": 8.0},
	&"stew": {"name": "stew", "bulk": 1.0, "group": &"food", "feeds": 14.0},
	&"smoked": {"name": "smoked fish", "bulk": 1.0, "group": &"food", "feeds": 12.0},

	# --- Goods ---
	&"pot": {"name": "pot", "bulk": 3.0, "group": &"good"},
	&"yarn": {"name": "yarn", "bulk": 1.0, "group": &"good"},
	&"blanket": {"name": "blanket", "bulk": 3.0, "group": &"good"},
	&"basket": {"name": "basket", "bulk": 2.0, "group": &"good", "creel": 8.0},
	&"lamp": {"name": "lamp", "bulk": 2.0, "group": &"good"},
	&"oil": {"name": "oil", "bulk": 1.0, "group": &"good"},
	&"oilcloth": {"name": "oilcloth", "bulk": 2.0, "group": &"good"},
	&"hone": {"name": "hone", "bulk": 1.0, "group": &"good"},

	# --- Crafts, carried as a bundle until they are set down (docs/VISION.md §5) ---
	# What goes in the creel is the bundle: spars, cord, and the drums, ducts and legs
	# cut off the machines. What comes out of it is a craft standing in the world
	# (src/core/craft/, src/systems/44_crafts.gd). Heavy on purpose — a person carries
	# one craft and little else, so where you leave it matters.
	&"raft": {"name": "raft", "bulk": 10.0, "group": &"good"},
	&"hover_sled": {"name": "hover sled", "bulk": 14.0, "group": &"good"},
	&"walker_rig": {"name": "walker rig", "bulk": 16.0, "group": &"good"},

	# --- Salvage kit, worn one at a time (§9.6) ---
	&"kit_plate": {"name": "plate armour", "bulk": 3.0, "group": &"kit", "kit": &"plate", "health": 3},
	&"kit_brace": {"name": "brace", "bulk": 2.0, "group": &"kit", "kit": &"brace", "wind": 700.0},
	&"kit_rig": {"name": "rig", "bulk": 2.0, "group": &"kit", "kit": &"rig", "creel": 20.0},
	&"kit_lens": {"name": "lens", "bulk": 1.0, "group": &"kit", "kit": &"lens", "sight": 3.0},
	&"kit_aerial": {"name": "aerial", "bulk": 1.0, "group": &"kit", "kit": &"aerial", "hearing": 4.0},

	# --- Gear against the pressures of a place (docs/VISION.md §6) -----------------
	# MADE: cloth, reed and pitch, mended by the hand that made it. Cheap, and it
	# takes the edge off one thing each.
	&"wrap_warm": {"name": "warm wrap", "bulk": 2.0, "group": &"kit", "tier": &"made",
		"slot": &"body", "sockets": 1, "resist": {&"cold": 0.35}, "wears": {"coat": &"wrap", "extras": [&"shawl"]}},
	&"oilskin": {"name": "oilskin", "bulk": 2.0, "group": &"kit", "tier": &"made",
		"slot": &"body", "sockets": 1, "resist": {&"wet": 0.55, &"cold": 0.1}, "wears": {"coat": &"oilskin"}},
	&"scarf_mask": {"name": "scarf-mask", "bulk": 1.0, "group": &"kit", "tier": &"made",
		"slot": &"head", "sockets": 1, "resist": {&"fumes": 0.35, &"toxins": 0.2, &"thirst": 0.15}, "wears": {"hat": &"scarf"}},
	&"hat_brim": {"name": "brimmed hat", "bulk": 1.0, "group": &"kit", "tier": &"made",
		"slot": &"head", "sockets": 1, "resist": {&"heat": 0.3, &"wet": 0.15, &"glare": 0.45}, "wears": {"hat": &"brim"}},
	# Leather and cord with no iron anywhere in them, so nothing on your hands is
	# being pulled. Magnetism was the only pressure with nothing wearable against
	# it at all, and the scrapwood declares it at every hour (playtest 7).
	&"mitts_corded": {"name": "corded mitts", "bulk": 1.0, "group": &"kit", "tier": &"made",
		"slot": &"hands", "sockets": 1, "resist": {&"magnetism": 0.35, &"cold": 0.15}, "wears": {"extras": [&"mitts"]}},
	# MENDED: machine parts bound to a made frame with cord. Most of the high tech
	# a person uses, and where the abilities come from.
	&"vest_heatsink": {"name": "heat-sink vest", "bulk": 3.0, "group": &"kit", "tier": &"mended",
		"slot": &"body", "sockets": 2, "resist": {&"heat": 0.6, &"fumes": 0.2}, "wears": {"salvage": [&"breastplate"], "gear": [&"battery"]}},
	&"rebreather": {"name": "rebreather", "bulk": 2.0, "group": &"kit", "tier": &"mended",
		"slot": &"head", "sockets": 1, "resist": {&"fumes": 0.7, &"toxins": 0.55}, "wears": {"gear": [&"respirator"]}},
	&"boots_magnet": {"name": "magnet boots", "bulk": 3.0, "group": &"kit", "tier": &"mended",
		"slot": &"hands", "sockets": 1,
		"resist": {&"em": 0.4, &"resonance": 0.25, &"collapse": 0.3}, "ability": &"grapple", "wears": {"salvage": [&"brace"]}},
	# The grapple brace's two upper rungs (GearTree family `brace`): the same
	# brace, the same grapple and the same resists, first re-cabled with the
	# city's tower cable, then with a demolisher's ram bolted to it. What a rung
	# buys is SOCKETS, as every rung does, and each is heavier than the last.
	&"brace_cable": {"name": "cable brace", "bulk": 3.5, "group": &"kit", "tier": &"mended",
		"slot": &"hands", "sockets": 2, "icon": [&"boot", &"slate", &"copper"],
		"resist": {&"em": 0.4, &"resonance": 0.25, &"collapse": 0.3}, "ability": &"grapple", "wears": {"salvage": [&"brace"]}},
	&"brace_ram": {"name": "ram brace", "bulk": 4.0, "group": &"kit", "tier": &"mended",
		"slot": &"hands", "sockets": 3, "icon": [&"boot", &"plate", &"lens"],
		"resist": {&"em": 0.4, &"resonance": 0.25, &"collapse": 0.3}, "ability": &"grapple", "wears": {"salvage": [&"brace"]}},
	&"glide_wing": {"name": "glide wing", "bulk": 4.0, "group": &"kit", "tier": &"mended",
		"slot": &"back", "sockets": 2, "resist": {}, "ability": &"glide", "wears": {"wing": true}},
	&"scanner_lens": {"name": "scanner lens", "bulk": 1.0, "group": &"kit", "tier": &"mended",
		"slot": &"head", "sockets": 2, "resist": {&"dark": 0.5, &"glare": 0.35}, "ability": &"scan", "wears": {"salvage": [&"lens"]}},
	# A machine's own coolant loop, cut short and wound: it gives back what a
	# body breathes out. The one answer to a land that drinks you.
	&"condenser": {"name": "drip coil", "bulk": 2.0, "group": &"kit", "tier": &"mended",
		"slot": &"back", "sockets": 1, "resist": {&"thirst": 0.55, &"heat": 0.15}, "wears": {"gear": [&"coil"]}},
	# FOUND: taken whole off the machines' works, never mended.
	&"shield_plate": {"name": "shield plate", "bulk": 3.0, "group": &"found", "tier": &"found", "stuff": &"found",
		"slot": &"back", "sockets": 0,
		"resist": {&"radiation": 0.6, &"heat": 0.35, &"em": 0.3, &"collapse": 0.4}, "wears": {"salvage": [&"plate"]}},

	# --- Modules, which socket into gear -------------------------------------------
	&"mod_wadding": {"name": "wadding", "bulk": 1.0, "group": &"kit", "tier": &"made", "module": true,
		"fits": [&"head", &"body", &"hands"], "resist": {&"cold": 0.2}},
	&"mod_filter": {"name": "char filter", "bulk": 0.5, "group": &"kit", "tier": &"made", "module": true,
		"fits": [&"head"], "resist": {&"fumes": 0.3, &"toxins": 0.2}},
	# A rag stretched on a bent driftwood rib and lashed over a brim, a vest or a
	# pack frame: the second half of the answer to glare, and it is a MODULE for a
	# structural reason rather than a taste one.
	#
	# Glare was the one pressure the best legal loadout could not bring below a
	# bite, because both answers to it — the brim and the scanner lens — are worn
	# on the HEAD (playtest 3). The first fix put the second answer on the back,
	# and that was worse: the back is the only slot that answers the same
	# landscape's thirst, so the flat's best whole kit did not move (0.550, still
	# exactly a bite) and any body that actually wore the new piece went from no
	# harm at all to thirst harming it a third of the time.
	#
	# The salt flats declares three pressures and there are only three slots with
	# answers in them, so the capacity has to come from SOCKETS, which is what
	# they are for. One of these under a brim takes glare from 0.550 to 0.385;
	# one on its own leaves 0.70, still biting, so a rag is not a hat.
	#
	# It answers THIRST as well, because shade is what actually stops a flat
	# drinking a body: out of the sun you sweat a fraction of what you do in it.
	# Without that, thirst was the one pressure with no made answer at all — the
	# drip coil is a machine's coolant loop and wants a bench — so the flat
	# harmed a day-two body a third of the time with nothing to put on.
	&"mod_shade": {"name": "rag shade", "bulk": 1.0, "group": &"kit", "tier": &"made", "module": true,
		"fits": [&"head", &"body", &"back"], "resist": {&"glare": 0.3, &"heat": 0.15, &"thirst": 0.2}},
	# Cord and pitch wound round a haft: it damps the ring that comes back up a
	# tool struck against machine plate, and it is what the hand's slot is for.
	&"mod_grip": {"name": "bound grip", "bulk": 0.5, "group": &"kit", "tier": &"made", "module": true,
		"fits": [&"tool", &"hands"],
		"resist": {&"resonance": 0.35, &"em": 0.1, &"magnetism": 0.2}},
	# A tin cup of oil with a rag wick, hung off the pack frame or the belt: it
	# lights the ground in front of your feet and nothing further. A MODULE for
	# the same structural reason the rag shade is. The dark was answered from the
	# HEAD alone (the scanner lens), and the Ruined Metropolis is the first
	# landscape to declare both dark and toxins, whose strongest answer, the
	# rebreather, is worn on the head too — so the best kit for a city at night
	# in fog left dark at 0.76 on a body that had done everything right
	# (tests/hazards/test_whole_kit.gd). The capacity comes from sockets on the
	# body and the back, which is what they are for.
	&"mod_wick": {"name": "wick lamp", "bulk": 1.0, "group": &"kit", "tier": &"made", "module": true,
		"fits": [&"body", &"back"], "resist": {&"dark": 0.3}},
	&"mod_foil": {"name": "foil lining", "bulk": 1.0, "group": &"kit", "tier": &"mended", "module": true,
		"fits": [&"body", &"back"],
		"resist": {&"radiation": 0.3, &"em": 0.2, &"magnetism": 0.35}},
	&"mod_spring": {"name": "spring coil", "bulk": 1.0, "group": &"kit", "tier": &"mended", "module": true,
		"fits": [&"body", &"hands", &"back"], "resist": {}, "ability": &"dash"},
	&"mod_signet": {"name": "signet", "bulk": 0.5, "group": &"found", "tier": &"found", "stuff": &"found", "module": true,
		"fits": [&"head", &"body", &"back"], "resist": {&"em": 0.15}, "ability": &"spoof"},

	# --- MENDED implements (docs/ART.md 12, docs/VISION.md 6.1) -----------------
	# Every rung of a family does exactly what the common rung does: the same
	# damage, reach, timing and work rate, copied verbatim. What the elite
	# material buys is a MOUNT -- a spar bound along a back, a collar, a lacquered
	# ferrule -- and what the mount buys is SOCKETS. That is the whole ladder, and
	# `GearTree.SAME_ACROSS_A_FAMILY` is what holds it (tests/gear_economy).
	# A mended rung is heavier than the tool it was: machine parts weigh.
	&"knife_spar": {"name": "spar knife", "bulk": 1.5, "group": &"tool", "tier": &"mended", "sockets": 2,
		"icon": [&"knife", &"rime", &"earth"], "tool": true, "verb": &"cut", "stuff": &"iron", "speed": 8200, "bite": 90, "swing": [60, 100, 120, 140], "reach": 0.9, "width": 1.0, "dmg": 2, "knock": 4.0, "knock_ms": 150},
	&"knife_mono": {"name": "filament knife", "bulk": 2.0, "group": &"tool", "tier": &"mended", "sockets": 3,
		"icon": [&"knife", &"slate", &"earth"], "tool": true, "verb": &"cut", "stuff": &"iron", "speed": 8200, "bite": 90, "swing": [60, 100, 120, 140], "reach": 0.9, "width": 1.0, "dmg": 2, "knock": 4.0, "knock_ms": 150},
	&"axe_bog": {"name": "bog-iron axe", "bulk": 2.5, "group": &"tool", "tier": &"mended", "sockets": 2,
		"icon": [&"axe", &"rust", &"earth"], "tool": true, "verb": &"fell", "stuff": &"iron", "speed": 6500, "bite": 120, "swing": [130, 120, 170, 200], "reach": 1.15, "width": 1.6, "dmg": 4, "knock": 6.5, "knock_ms": 200},
	&"axe_tide": {"name": "tide-iron axe", "bulk": 3.0, "group": &"tool", "tier": &"mended", "sockets": 3,
		"icon": [&"axe", &"rust", &"earth"], "tool": true, "verb": &"fell", "stuff": &"iron", "speed": 6500, "bite": 120, "swing": [130, 120, 170, 200], "reach": 1.15, "width": 1.6, "dmg": 4, "knock": 6.5, "knock_ms": 200},
	&"bill_glass": {"name": "glass bill", "bulk": 2.5, "group": &"tool", "tier": &"mended", "sockets": 2,
		"icon": [&"billhook", &"ink", &"earth"], "tool": true, "verb": &"cut", "stuff": &"iron", "speed": 6200, "bite": 120, "swing": [100, 110, 150, 170], "reach": 1.05, "width": 1.5, "dmg": 3, "knock": 5.0, "knock_ms": 170},
	&"bill_vane": {"name": "vane bill", "bulk": 3.0, "group": &"tool", "tier": &"mended", "sockets": 3,
		"icon": [&"billhook", &"stone", &"earth"], "tool": true, "verb": &"cut", "stuff": &"iron", "speed": 6200, "bite": 120, "swing": [100, 110, 150, 170], "reach": 1.05, "width": 1.5, "dmg": 3, "knock": 5.0, "knock_ms": 170},
	&"mattock_bog": {"name": "bog-iron mattock", "bulk": 4.5, "group": &"tool", "tier": &"mended", "sockets": 2,
		"icon": [&"mattock", &"rust", &"earth"], "tool": true, "verb": &"dig", "stuff": &"iron", "speed": 6500, "bite": 140, "swing": [180, 130, 220, 260], "reach": 1.25, "width": 1.3, "dmg": 3, "knock": 7.5, "knock_ms": 230},
	&"mattock_gyro": {"name": "gyro mattock", "bulk": 5.0, "group": &"tool", "tier": &"mended", "sockets": 3,
		"icon": [&"mattock", &"slate", &"earth"], "tool": true, "verb": &"dig", "stuff": &"iron", "speed": 6500, "bite": 140, "swing": [180, 130, 220, 260], "reach": 1.25, "width": 1.3, "dmg": 3, "knock": 7.5, "knock_ms": 230},
	&"pick_spar": {"name": "spar pick", "bulk": 4.5, "group": &"tool", "tier": &"mended", "sockets": 2,
		"icon": [&"pick", &"rime", &"earth"], "tool": true, "verb": &"break", "stuff": &"iron", "speed": 6000, "bite": 140, "swing": [180, 130, 220, 260], "reach": 1.25, "width": 1.2, "dmg": 4, "knock": 7.0, "knock_ms": 220},
	&"pick_glass": {"name": "glass pick", "bulk": 5.0, "group": &"tool", "tier": &"mended", "sockets": 3,
		"icon": [&"pick", &"ink", &"earth"], "tool": true, "verb": &"break", "stuff": &"iron", "speed": 6000, "bite": 140, "swing": [180, 130, 220, 260], "reach": 1.25, "width": 1.2, "dmg": 4, "knock": 7.0, "knock_ms": 220},
	&"stave_varnish": {"name": "lacquered stave", "bulk": 2.5, "group": &"tool", "tier": &"mended", "sockets": 2,
		"icon": [&"stave", &"linen", &"earth"], "tool": true, "verb": &"", "stuff": &"wood", "speed": 10000, "bite": 0, "swing": [90, 110, 130, 150], "reach": 1.6, "width": 1.3, "dmg": 2, "knock": 8.0, "knock_ms": 240},
	&"stave_coil": {"name": "coil stave", "bulk": 3.0, "group": &"tool", "tier": &"mended", "sockets": 3,
		"icon": [&"stave", &"copper", &"earth"], "tool": true, "verb": &"", "stuff": &"wood", "speed": 10000, "bite": 0, "swing": [90, 110, 130, 150], "reach": 1.6, "width": 1.3, "dmg": 2, "knock": 8.0, "knock_ms": 240},
	&"hook_varnish": {"name": "lacquered gaff", "bulk": 3.5, "group": &"tool", "tier": &"mended", "sockets": 2,
		"icon": [&"boathook", &"linen", &"earth"], "tool": true, "verb": &"", "stuff": &"iron", "speed": 10000, "bite": 0, "swing": [160, 120, 200, 240], "reach": 2.1, "width": 0.8, "dmg": 2, "knock": 9.5, "knock_ms": 260},
	&"hook_screw": {"name": "screw gaff", "bulk": 4.0, "group": &"tool", "tier": &"mended", "sockets": 3,
		"icon": [&"boathook", &"slate", &"earth"], "tool": true, "verb": &"", "stuff": &"iron", "speed": 10000, "bite": 0, "swing": [160, 120, 200, 240], "reach": 2.1, "width": 0.8, "dmg": 2, "knock": 9.5, "knock_ms": 260},
	&"beam_hafted": {"name": "hafted beam", "bulk": 1.5, "group": &"tool", "tier": &"mended", "sockets": 2,
		"icon": [&"stave", &"rust", &"earth"], "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0, "wick": 1, "swing": [70, 90, 110, 130], "reach": 1.3, "width": 1.1, "dmg": 7, "knock": 5.0, "knock_ms": 180},
	&"beam_lens": {"name": "sighted beam", "bulk": 2.0, "group": &"tool", "tier": &"mended", "sockets": 3,
		"icon": [&"stave", &"lens", &"earth"], "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0, "wick": 1, "swing": [70, 90, 110, 130], "reach": 1.3, "width": 1.1, "dmg": 7, "knock": 5.0, "knock_ms": 180},
	&"arc_hafted": {"name": "hafted cutter", "bulk": 1.5, "group": &"tool", "tier": &"mended", "sockets": 2,
		"icon": [&"knife", &"slate", &"earth"], "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0, "wick": 1, "swing": [60, 80, 100, 120], "reach": 0.7, "width": 0.8, "dmg": 10, "knock": 3.0, "knock_ms": 140},
	&"hammer_hafted": {"name": "hafted hammer", "bulk": 3.5, "group": &"tool", "tier": &"mended", "sockets": 2,
		"icon": [&"mattock", &"slate", &"earth"], "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0, "wick": 2, "swing": [190, 130, 210, 250], "reach": 1.15, "width": 1.6, "dmg": 5, "knock": 20.0, "knock_ms": 340},
	&"lance_hafted": {"name": "hafted lance", "bulk": 2.5, "group": &"tool", "tier": &"mended", "sockets": 2,
		"icon": [&"boathook", &"slate", &"earth"], "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0, "wick": 1, "swing": [120, 90, 150, 180], "reach": 2.4, "width": 0.7, "dmg": 8, "knock": 3.5, "knock_ms": 160},
	&"lance_die": {"name": "stamped lance", "bulk": 3.0, "group": &"tool", "tier": &"mended", "sockets": 3,
		"icon": [&"boathook", &"ink", &"earth"], "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0, "wick": 1, "swing": [120, 90, 150, 180], "reach": 2.4, "width": 0.7, "dmg": 8, "knock": 3.5, "knock_ms": 160},
	# The glass desert's lance: a skater's blade bound to a lance round a
	# fulgurite core (docs/LANDSCAPES.md §3). Every number is the lance's.
	&"lance_glass": {"name": "glass lance", "bulk": 2.5, "group": &"tool", "tier": &"mended", "sockets": 2,
		"icon": [&"boathook", &"spruce", &"earth"], "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0, "wick": 1, "swing": [120, 90, 150, 180], "reach": 2.4, "width": 0.7, "dmg": 8, "knock": 3.5, "knock_ms": 160},
	# The flawed twin of the relic below: the same blade with no name set into it.
	# A relic pour that goes wrong comes out as this, and it is also worth making
	# on purpose (CraftTiers: "flawed but usable" is a real rung, not a punishment).
	&"blade_die": {"name": "die blade", "bulk": 2.0, "group": &"tool", "tier": &"mended", "sockets": 3,
		"icon": [&"knife", &"slate", &"earth"], "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0, "wick": 1, "swing": [45, 80, 90, 110], "reach": 0.9, "width": 0.9, "dmg": 11, "knock": 2.0, "knock_ms": 120},
	&"blade_seal": {"name": "filer's blade", "bulk": 2.0, "group": &"tool", "tier": &"mended", "sockets": 3,
		"icon": [&"knife", &"ink", &"earth"], "tool": true, "verb": &"", "stuff": &"found", "speed": 10000, "bite": 0, "wick": 1, "swing": [45, 80, 90, 110], "reach": 0.9, "width": 0.9, "dmg": 11, "knock": 2.0, "knock_ms": 120, "ability": &"spoof", "resist": {&"em": 0.5}},

	# --- MENDED modules: the modifiers (ModifierTable says what each decides) ---
	# A part that COSTS the kit something (`loud`, `hot`) never answers a pressure
	# a landscape actually declares, so the best kit for a place is never one that
	# is quietly paying a price (tests/gear_economy/test_modifiers.gd).
	&"mod_gyro": {"name": "gyro brace", "bulk": 1.0, "group": &"kit", "tier": &"mended", "module": true,
		"icon": [&"coil", &"slate", &"earth"], "fits": [&"hands", &"back"], "resist": {&"resonance": 0.3, &"collapse": 0.2}},
	&"mod_clamp": {"name": "magnet clamp", "bulk": 1.5, "group": &"kit", "tier": &"mended", "module": true,
		"icon": [&"boot", &"rust", &"earth"], "fits": [&"hands"], "resist": {&"magnetism": 0.5, &"collapse": 0.3}},
	&"mod_ablative": {"name": "ablative plate", "bulk": 1.5, "group": &"kit", "tier": &"mended", "module": true,
		"icon": [&"foil", &"ink", &"earth"], "fits": [&"body", &"back"], "resist": {&"radiation": 0.3, &"heat": 0.2}},
	&"mod_cooling": {"name": "cooling loop", "bulk": 1.5, "group": &"kit", "tier": &"mended", "module": true,
		"icon": [&"coil", &"rust", &"earth"], "fits": [&"body", &"back", &"tool"], "resist": {&"heat": 0.35}},
	&"mod_capacitor": {"name": "capacitor bank", "bulk": 1.5, "group": &"kit", "tier": &"mended", "module": true,
		"icon": [&"flask", &"copper", &"earth"], "fits": [&"back", &"tool"], "resist": {&"em": 0.2}},
	&"mod_harmonic": {"name": "harmonic edge", "bulk": 0.5, "group": &"kit", "tier": &"mended", "module": true,
		"icon": [&"knife", &"slate", &"earth"], "fits": [&"tool"], "resist": {&"resonance": 0.2}},
	&"mod_damp": {"name": "hush damper", "bulk": 1.0, "group": &"kit", "tier": &"mended", "module": true,
		"icon": [&"timber", &"linen", &"earth"], "fits": [&"tool", &"hands", &"body"], "resist": {&"resonance": 0.45}},
	# A deep ice lens bound over one eye (docs/LANDSCAPES.md §2): it takes the
	# glare off a white plain and lets a little of the dark through, and it is
	# the frost sea's answer to the sea's own light. Head only: it is worn where
	# the eye is. `sight` is its tag (ModifierTable).
	&"mod_icelens": {"name": "ice lens", "bulk": 0.5, "group": &"kit", "tier": &"mended", "module": true,
		"icon": [&"scan_lens", &"rime", &"earth"], "fits": [&"head"], "resist": {&"glare": 0.3, &"dark": 0.2}},
	&"mod_leech": {"name": "leech coil", "bulk": 1.0, "group": &"kit", "tier": &"mended", "module": true,
		"icon": [&"coil", &"ink", &"earth"], "fits": [&"tool", &"back"], "resist": {&"em": 0.15}},
	&"mod_phase": {"name": "phase coil", "bulk": 1.0, "group": &"kit", "tier": &"mended", "module": true,
		"icon": [&"scan_lens", &"lens", &"earth"], "fits": [&"head", &"body"], "resist": {&"em": 0.3, &"time_shear": 0.2}, "ability": &"scan"},
	&"mod_lattice": {"name": "shock lattice", "bulk": 1.5, "group": &"kit", "tier": &"mended", "module": true,
		"icon": [&"vest", &"plate", &"earth"], "fits": [&"tool"], "resist": {&"em": 0.25}},
	# The crags' hush slate, lined into a hat, a coat or a pack: what it decides
	# is the `quiet` tag (ModifierTable); the numbers are what stone that reads
	# as nothing keeps off a body, and they are small on purpose.
	&"mod_hush": {"name": "hush lining", "bulk": 1.0, "group": &"kit", "tier": &"mended", "module": true,
		"icon": [&"foil", &"slate", &"earth"], "fits": [&"head", &"body", &"back"], "resist": {&"em": 0.2, &"resonance": 0.25}},

	# --- elite materials (EliteStock says where each one, and only one, is got) -
	# Each keeps its landscape's or its machine's own colour and hand, so a
	# player reads where a tool came from off the tool (docs/ART.md 11).
	&"cinder_glass": {"name": "cinder glass", "bulk": 2.0, "group": &"material", "icon": [&"lump", &"ink", &"ink"]},
	&"clint_spar": {"name": "clint spar", "bulk": 2.0, "group": &"material", "icon": [&"stone", &"rime", &"rime"]},
	&"hush_slate": {"name": "hush slate", "bulk": 2.0, "group": &"material", "icon": [&"hushstone", &"slate", &"ink"]},
	&"bog_iron": {"name": "bog iron", "bulk": 1.5, "group": &"material", "icon": [&"ingot", &"rust", &"rust"]},
	&"frost_varnish": {"name": "frost varnish", "bulk": 1.0, "group": &"material", "icon": [&"flask", &"linen", &"rime"]},
	# Its raw's own mark a step brighter: the same ice, ground clear.
	&"deep_ice_lens": {"name": "deep ice lens", "bulk": 1.0, "group": &"material", "icon": [&"lens_ice", &"rime", &"lens"]},
	# The glass desert's: a strike's own cast, fired again until it rings.
	&"fulgurite_core": {"name": "fulgurite core", "bulk": 1.5, "group": &"material", "icon": [&"lump", &"spruce", &"rime"]},
	&"tower_cable": {"name": "tower cable", "bulk": 2.0, "group": &"material", "icon": [&"coil", &"slate", &"copper"]},
	&"tide_iron": {"name": "tide iron", "bulk": 1.5, "group": &"material", "icon": [&"ingot", &"rust", &"ash"]},
	&"mono_edge": {"name": "filament edge", "bulk": 0.5, "group": &"found", "stuff": &"found", "icon": [&"blade", &"found", &"lens"]},
	&"keeper_lens": {"name": "keeper lens", "bulk": 1.0, "group": &"found", "stuff": &"found", "icon": [&"lens", &"plate", &"lens"]},
	&"haul_gyro": {"name": "haul gyro", "bulk": 2.0, "group": &"found", "stuff": &"found", "icon": [&"rig", &"plate", &"lens"]},
	&"line_coil": {"name": "line coil", "bulk": 1.0, "group": &"found", "stuff": &"found", "icon": [&"aerial", &"plate", &"lens"]},
	&"clerk_die": {"name": "filer die", "bulk": 1.0, "group": &"found", "stuff": &"found", "icon": [&"signet", &"found", &"lens"]},
	&"vane_true": {"name": "trued vane", "bulk": 1.5, "group": &"found", "stuff": &"found", "icon": [&"broad", &"plate", &"lens"]},
	&"dredge_screw": {"name": "dredge screw", "bulk": 2.5, "group": &"found", "stuff": &"found", "icon": [&"hammer", &"plate", &"lens"]},
	&"fab_jig": {"name": "fabricator jig", "bulk": 3.0, "group": &"found", "stuff": &"found", "icon": [&"brace", &"plate", &"lens"]},
	# Off the glass desert's skater (EliteStock.SPOILS): a runner blade ground
	# to ride glass, and the edge a glass lance is bound round.
	&"skate_blade": {"name": "skate blade", "bulk": 1.5, "group": &"found", "stuff": &"found", "icon": [&"blade", &"plate", &"lens"]},
	&"boom_ram": {"name": "boom ram", "bulk": 3.0, "group": &"found", "stuff": &"found", "icon": [&"hammer", &"plate", &"lens"]},
	# The bilge pump out of a ferry (EliteStock.SPOILS): what keeps a barge that
	# size afloat. Carried for the submersible's hull that is to come
	# (docs/LANDSCAPES.md §5); FOUND tech taken whole.
	&"bilge_pump": {"name": "bilge pump", "bulk": 2.0, "group": &"found", "stuff": &"found", "icon": [&"coil", &"plate", &"lens"]},
	&"spoil": {"name": "ruined stock", "bulk": 1.5, "group": &"material", "icon": [&"lump", &"ash", &"ash"]},
	# raids: a machine's own account of a place, taken off the body that was
	# carrying it home. It is proof, and it is the only thing in the game worth
	# more in a person's hands than where it was (docs/VISION.md §9.2).
	&"record": {"name": "filed record", "bulk": 0.5, "group": &"found", "icon": [&"paper", &"slate", &"lens"]},
}


static func def(id: StringName) -> Dictionary:
	return DEFS.get(id, {})


static func display_name(id: StringName) -> String:
	return def(id).get("name", String(id))


static func has_edge(id: StringName) -> bool:
	return def(id).get("tool", false)


static func bulk(id: StringName) -> float:
	return def(id).get("bulk", 1.0)


static func verb(id: StringName) -> StringName:
	return def(id).get("verb", &"")


static func stuff(id: StringName) -> StringName:
	return def(id).get("stuff", &"")


static func feeds(id: StringName) -> float:
	return def(id).get("feeds", 0.0)


static func group(id: StringName) -> StringName:
	return def(id).get("group", &"material")


## True if `id` is at least as hard as `needed` (wood < iron < steel < crucible).
static func hard_enough(id: StringName, needed: StringName) -> bool:
	return STUFF_RANK.get(stuff(id), -1) >= STUFF_RANK.get(needed, 0)


## A found tool is never mended or honed and has no work verb.
static func is_found(id: StringName) -> bool:
	return stuff(id) == &"found"


## World minutes a work of `bare` minutes takes with tool `id` at `edge` (0..10000).
## Edge blends the tool's speed toward bare hands: a blunt tool still works, slowly. (source §9.1)
static func work_minutes(bare: float, id: StringName, edge: int) -> float:
	var speed: float = def(id).get("speed", 10000)
	var e := clampf(edge / 10000.0, 0.0, 1.0)
	return bare * lerpf(10000.0, speed, e) / 10000.0
