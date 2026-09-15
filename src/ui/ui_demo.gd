class_name UiDemo
## Sample data for --ui-demo shots only, so the making page can be judged
## before the survival package fills Crafting. Never used in a normal game.
## Numbers are the source's recipes (design-extract §9.6).

const RECIPES := [
	{"id": &"axe_made", "at": &"fire", "minutes": 270.0, "needs": {&"scrap": 1, &"timber": 1, &"charcoal": 2}, "makes": {&"axe_hand": 1}},
	{"id": &"pick_made", "at": &"fire", "minutes": 240.0, "needs": {&"scrap": 1, &"timber": 1, &"charcoal": 1}, "makes": {&"pick": 1}},
	{"id": &"billhook_made", "at": &"fire", "minutes": 210.0, "needs": {&"scrap": 1, &"timber": 1, &"charcoal": 1}, "makes": {&"billhook": 1}},
	{"id": &"charcoal", "at": &"fire", "minutes": 180.0, "needs": {&"driftwood": 4}, "makes": {&"charcoal": 2}},
	{"id": &"iron_scrap", "at": &"fire", "minutes": 240.0, "needs": {&"scrap": 3, &"charcoal": 2}, "makes": {&"iron": 1}},
	{"id": &"stew", "at": &"fire", "minutes": 60.0, "needs": {&"mussels": 4, &"samphire": 2}, "makes": {&"stew": 2}},
	{"id": &"pot", "at": &"bench", "minutes": 300.0, "needs": {&"tin": 2}, "makes": {&"pot": 1}},
	{"id": &"basket", "at": &"bench", "minutes": 120.0, "needs": {&"reeds": 6}, "makes": {&"basket": 1}},
	{"id": &"lime", "at": &"kiln", "minutes": 240.0, "needs": {&"limestone": 3, &"coal": 2}, "makes": {&"lime": 2}},
]


static func recipes_at(station: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in RECIPES:
		if r.at == station:
			out.append(r)
	return out
