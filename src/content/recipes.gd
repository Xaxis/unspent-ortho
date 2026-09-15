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
## - Tools take a `haft`, whittled from driftwood or timber with a blade. The
##   source used timber, which needs an axe, which needs timber; without trade
##   that loop had no way in. Driftwood is the way in.
## - Every made tool also has an iron rung (iron for plate), so ore matters.
## - Re-edging costs charcoal, not coin.

const LIST: Array[Dictionary] = [
	# --- By hand, anywhere ---
	{"id": &"campfire", "at": &"hand", "minutes": 20.0, "needs": {&"driftwood": 3, &"stone": 2}, "makes": {}, "builds": &"fire"},
	{"id": &"campfire_timber", "at": &"hand", "minutes": 20.0, "needs": {&"timber": 1, &"stone": 2}, "makes": {}, "builds": &"fire"},
	{"id": &"campfire_peat", "at": &"hand", "minutes": 20.0, "needs": {&"peat": 3, &"stone": 2}, "makes": {}, "builds": &"fire"},
	{"id": &"haft", "at": &"hand", "minutes": 30.0, "needs": {&"driftwood": 2}, "makes": {&"haft": 1}, "tool": &"cut"},
	{"id": &"haft_timber", "at": &"hand", "minutes": 30.0, "needs": {&"timber": 1}, "makes": {&"haft": 2}, "tool": &"cut"},
	{"id": &"hone", "at": &"hand", "minutes": 25.0, "needs": {&"stone": 1}, "makes": {&"hone": 1}},
	{"id": &"sharpen", "at": &"hand", "minutes": 20.0, "needs": {}, "makes": {}, "keeps": {&"hone": 1}, "action": &"hone"},
	{"id": &"stave", "at": &"hand", "minutes": 40.0, "needs": {&"timber": 1}, "makes": {&"stave": 1}, "tool": &"cut"},
	{"id": &"bench", "at": &"hand", "minutes": 60.0, "needs": {&"timber": 3, &"scrap": 1}, "makes": {}, "builds": &"bench"},
	{"id": &"kiln", "at": &"hand", "minutes": 120.0, "needs": {&"stone": 8}, "makes": {}, "builds": &"kiln"},

	# --- Fire ---
	{"id": &"reedge", "at": &"fire", "minutes": 45.0, "needs": {&"charcoal": 1}, "makes": {}, "action": &"reedge"},
	{"id": &"charcoal", "at": &"fire", "minutes": 180.0, "needs": {&"driftwood": 4}, "makes": {&"charcoal": 2}},
	{"id": &"charcoal_wood", "at": &"fire", "minutes": 180.0, "needs": {&"timber": 2}, "makes": {&"charcoal": 2}},
	{"id": &"tin", "at": &"fire", "minutes": 240.0, "needs": {&"tin_ore": 3, &"charcoal": 2}, "makes": {&"tin": 1}},
	{"id": &"iron", "at": &"fire", "minutes": 300.0, "needs": {&"iron_ore": 3, &"charcoal": 3}, "makes": {&"iron": 1}},
	{"id": &"iron_coal", "at": &"fire", "minutes": 300.0, "needs": {&"iron_ore": 3, &"coal": 2}, "makes": {&"iron": 1}},
	{"id": &"iron_scrap", "at": &"fire", "minutes": 240.0, "needs": {&"scrap": 3, &"charcoal": 2}, "makes": {&"iron": 1}},
	{"id": &"copper", "at": &"fire", "minutes": 240.0, "needs": {&"copper_ore": 3, &"charcoal": 2}, "makes": {&"copper": 1}},
	{"id": &"pitch", "at": &"fire", "minutes": 200.0, "needs": {&"resin": 4}, "makes": {&"pitch": 1}},
	{"id": &"oil", "at": &"fire", "minutes": 90.0, "needs": {&"resin": 2}, "makes": {&"oil": 1}},
	{"id": &"dye", "at": &"fire", "minutes": 260.0, "needs": {&"crottle": 5}, "makes": {&"dye": 1}},
	{"id": &"soup", "at": &"fire", "minutes": 40.0, "needs": {&"mussels": 3, &"wrack": 1}, "makes": {&"soup": 2}},
	{"id": &"stew", "at": &"fire", "minutes": 60.0, "needs": {&"mussels": 4, &"samphire": 2}, "makes": {&"stew": 2}},
	{"id": &"smoked", "at": &"fire", "minutes": 200.0, "needs": {&"whelks": 5, &"driftwood": 3}, "makes": {&"smoked": 2}},
	{"id": &"knife_made", "at": &"fire", "minutes": 150.0, "needs": {&"scrap": 1, &"charcoal": 1}, "makes": {&"knife": 1}},
	{"id": &"pick_made", "at": &"fire", "minutes": 240.0, "needs": {&"scrap": 1, &"haft": 1, &"charcoal": 1}, "makes": {&"pick": 1}},
	{"id": &"pick_iron", "at": &"fire", "minutes": 240.0, "needs": {&"iron": 1, &"haft": 1, &"charcoal": 1}, "makes": {&"pick": 1}},
	{"id": &"axe_made", "at": &"fire", "minutes": 270.0, "needs": {&"scrap": 1, &"haft": 1, &"charcoal": 2}, "makes": {&"axe_hand": 1}},
	{"id": &"axe_iron", "at": &"fire", "minutes": 270.0, "needs": {&"iron": 1, &"haft": 1, &"charcoal": 2}, "makes": {&"axe_hand": 1}},
	{"id": &"mattock_made", "at": &"fire", "minutes": 300.0, "needs": {&"scrap": 2, &"haft": 1, &"charcoal": 1}, "makes": {&"mattock": 1}},
	{"id": &"mattock_iron", "at": &"fire", "minutes": 300.0, "needs": {&"iron": 2, &"haft": 1, &"charcoal": 1}, "makes": {&"mattock": 1}},
	{"id": &"billhook_made", "at": &"fire", "minutes": 210.0, "needs": {&"scrap": 1, &"haft": 1, &"charcoal": 1}, "makes": {&"billhook": 1}},
	{"id": &"billhook_iron", "at": &"fire", "minutes": 210.0, "needs": {&"iron": 1, &"haft": 1, &"charcoal": 1}, "makes": {&"billhook": 1}},
	{"id": &"boathook_made", "at": &"fire", "minutes": 150.0, "needs": {&"scrap": 1, &"haft": 2, &"charcoal": 1}, "makes": {&"boathook": 1}},

	# --- Bench ---
	{"id": &"pot", "at": &"bench", "minutes": 300.0, "needs": {&"tin": 2}, "makes": {&"pot": 1}},
	{"id": &"basket", "at": &"bench", "minutes": 120.0, "needs": {&"reeds": 6}, "makes": {&"basket": 1}},
	{"id": &"oilcloth", "at": &"bench", "minutes": 120.0, "needs": {&"yarn": 2, &"pitch": 1}, "makes": {&"oilcloth": 1}},
	{"id": &"lamp", "at": &"bench", "minutes": 180.0, "needs": {&"tin": 1, &"copper": 1}, "makes": {&"lamp": 1}},
	{"id": &"kit_plate", "at": &"bench", "minutes": 240.0, "needs": {&"scrap": 3, &"iron": 1}, "makes": {&"kit_plate": 1}},
	{"id": &"kit_brace", "at": &"bench", "minutes": 180.0, "needs": {&"scrap": 2, &"timber": 1, &"iron": 1}, "makes": {&"kit_brace": 1}},
	{"id": &"kit_rig", "at": &"bench", "minutes": 150.0, "needs": {&"scrap": 1, &"yarn": 3, &"oilcloth": 1}, "makes": {&"kit_rig": 1}},
	{"id": &"kit_lens", "at": &"bench", "minutes": 200.0, "needs": {&"scrap": 1, &"tin": 1, &"resin": 1}, "makes": {&"kit_lens": 1}},
	{"id": &"kit_aerial", "at": &"bench", "minutes": 160.0, "needs": {&"scrap": 2, &"tin": 2}, "makes": {&"kit_aerial": 1}},

	# --- Wheel and loom (inside houses, once there are interiors) ---
	{"id": &"yarn", "at": &"wheel", "minutes": 150.0, "needs": {&"wool": 3}, "makes": {&"yarn": 1}},
	{"id": &"blanket", "at": &"loom", "minutes": 420.0, "needs": {&"yarn": 4}, "makes": {&"blanket": 1}},

	# --- Kiln: lime, ash, and steel by cementation (the tool is eaten for a day or more) ---
	{"id": &"lime", "at": &"kiln", "minutes": 240.0, "needs": {&"limestone": 3, &"coal": 2}, "makes": {&"lime": 2}},
	{"id": &"lime_gorse", "at": &"kiln", "minutes": 240.0, "needs": {&"limestone": 3, &"gorse_cut": 5}, "makes": {&"lime": 2}},
	{"id": &"kelp_ash", "at": &"kiln", "minutes": 300.0, "needs": {&"wrack": 8}, "makes": {&"kelp_ash": 1}},
	{"id": &"knife_cemented", "at": &"kiln", "minutes": 900.0, "needs": {&"knife": 1, &"charcoal": 4}, "makes": {&"knife_shear": 1}},
	{"id": &"axe_cemented", "at": &"kiln", "minutes": 1800.0, "needs": {&"axe_hand": 1, &"charcoal": 8}, "makes": {&"axe_felling": 1}},
	{"id": &"mattock_cemented", "at": &"kiln", "minutes": 1800.0, "needs": {&"mattock": 1, &"charcoal": 8}, "makes": {&"mattock_steel": 1}},
	{"id": &"pick_cemented", "at": &"kiln", "minutes": 1800.0, "needs": {&"pick": 1, &"charcoal": 8}, "makes": {&"pick_steel": 1}},
]
