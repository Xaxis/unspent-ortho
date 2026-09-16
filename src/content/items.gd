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
	&"scrap": {"name": "piece of plate", "bulk": 2.0, "group": &"material"},

	# --- Food ---
	&"mussels": {"name": "mussels", "bulk": 0.5, "group": &"food", "feeds": 4.0},
	&"whelks": {"name": "whelks", "bulk": 0.5, "group": &"food", "feeds": 3.0},
	&"samphire": {"name": "samphire", "bulk": 0.5, "group": &"food", "feeds": 2.0},
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

	# --- Salvage kit, worn one at a time (§9.6) ---
	&"kit_plate": {"name": "plate armour", "bulk": 3.0, "group": &"kit", "kit": &"plate", "health": 3},
	&"kit_brace": {"name": "brace", "bulk": 2.0, "group": &"kit", "kit": &"brace", "wind": 700.0},
	&"kit_rig": {"name": "rig", "bulk": 2.0, "group": &"kit", "kit": &"rig", "creel": 20.0},
	&"kit_lens": {"name": "lens", "bulk": 1.0, "group": &"kit", "kit": &"lens", "sight": 3.0},
	&"kit_aerial": {"name": "aerial", "bulk": 1.0, "group": &"kit", "kit": &"aerial", "hearing": 4.0},
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
