class_name UiRules
## What the quiet layer shows and when, as pure functions of the game's data,
## so every rule is tested without a window. Nothing here draws.

## A hostile within this many tiles hides every out-of-fight prompt.
const HOSTILE_RADIUS := 8.0
## Health is drawn in cells of three (source: "4 cells of 3").
const PER_CELL := 3
## The creel: load that starts to tell (source: 40; a rig adds 20).
const CREEL := 40.0

## What a person does to a prop, from the taking table (design-extract §9.5).
## Survival owns the real rule; this only names it for the hint.
const PROP_VERBS := {
	PropKind.PINE: "fell", PropKind.SNOW_PINE: "fell", PropKind.BROADLEAF: "fell", PropKind.DEAD_TREE: "fell",
	PropKind.BOULDER: "break", PropKind.STONE_ORE: "break", PropKind.CLINTS: "break", PropKind.WRECK: "break",
	PropKind.IRON_ORE: "dig", PropKind.COPPER_ORE: "dig", PropKind.COAL_ORE: "dig", PropKind.TIN_ORE: "dig",
	PropKind.REEDS: "cut", PropKind.GORSE: "cut", PropKind.PEAT_BANK: "cut",
	PropKind.DRIFTWOOD: "gather", PropKind.WRACK: "gather", PropKind.MUSSEL_ROCK: "gather",
	PropKind.TIP: "turn",
	PropKind.DEBRIS: "turn", PropKind.VEHICLE: "break", PropKind.BARRICADE: "break", PropKind.HULL: "break",
	PropKind.FENCE: "fell", PropKind.STUMP: "fell",
}
const STATIONS := {PropKind.FIRE: &"fire", PropKind.BENCH: &"bench", PropKind.KILN: &"kiln"}

## Inventory groups, in the order the slate lists them.
const GROUPS: Array[StringName] = [&"tools", &"found", &"to wear", &"food", &"goods"]


## Fill of each health cell, 0..3, left to right. Cells = max / 3 rounded up.
static func health_cells(health: int, max_health: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var cells := maxi(1, ceili(max_health / float(PER_CELL)))
	for i in cells:
		out.append(clampi(health - i * PER_CELL, 0, PER_CELL))
	return out


## Wind is only worth a line on screen once some of it is spent.
static func wind_shown(wind: float, max_wind: float) -> bool:
	return wind < max_wind - 0.5


# --- the slate's power and the felt pressures --------------------------------------

## A felt pressure (a hazard the body is under) is only a gauge once it is this
## strong, and it is the warning once it is costing the body something. Both are
## the hazard model's own steps, so the glass and the rules never disagree about
## when a place has become a problem (src/core/hazards/hazards.gd).
const PRESSURE_SHOWN := Hazards.FELT
const PRESSURE_WARN := Hazards.BITE
## The slate runs off the lamp's reserve (a flask lights it this long) or the
## found charges carried, whichever holds more (docs/ART.md §9: brightness dips
## when the lamp oil or charge is low).
const POWER_LAMP_MINUTES := 360.0
const POWER_CHARGES := 3


## Power 0..1 from the lamp's minutes of light and the charges carried.
static func slate_power(lamp_minutes: float, charges: int) -> float:
	return clampf(maxf(lamp_minutes / POWER_LAMP_MINUTES, charges / float(POWER_CHARGES)), 0.0, 1.0)


## How bright the glass is at a power: full down to UiSlate.LOW_POWER, then
## dipping toward UiSlate.DIM_FLOOR, never so far that it cannot be read.
static func brightness(power: float) -> float:
	if power >= UiSlate.LOW_POWER:
		return 1.0
	return lerpf(UiSlate.DIM_FLOOR, 1.0, clampf(power / UiSlate.LOW_POWER, 0.0, 1.0))


## Segments lit in the four-segment cell glyph.
static func cell_segments(power: float) -> int:
	return clampi(ceili(power * 4.0 - 0.001), 0, 4)


## The charge readout is only on the wrist while the thing in hand spends charges.
static func charge_shown(held: StringName) -> bool:
	return held != &"" and int(Items.def(held).get("wick", 0)) > 0


## Felt pressures, the HUD's gauges, in a fixed order so they never swap places:
## the body's needs that matter now, then every hazard pressure (Body.pressure,
## written by the hazards package) strong enough to be felt.
## [{id: StringName, level: 1 quiet | 2 warning, value: 0..1}]
static func pressures(body: Body, minutes: float, load: float, cap: float = CREEL) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n in needs(body, minutes, load, cap):
		out.append({"id": n.need, "level": n.level, "value": 0.5 if n.level == 1 else 1.0})
	var shown := {}
	for row: Dictionary in out:
		shown[row.id] = true
	var ids: Array = body.pressure.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id: Variant in ids:
		# A need and a hazard can share a name (wet is both): the body's own need
		# is the one that is shown, never two gauges with one glyph.
		if shown.has(StringName(id)):
			continue
		var v := float(body.pressure[id])
		if v >= PRESSURE_SHOWN:
			out.append({"id": StringName(id), "level": 2 if v >= PRESSURE_WARN else 1, "value": clampf(v, 0.0, 1.0)})
	return out


## The creel a body carries before load tells, when nothing better says (UiLink.creel).
static func creel(body: Body) -> float:
	var v: Variant = body.get("max_load")
	return float(v) if v != null and float(v) > 0.0 else CREEL


## Needs that matter now, most pressing first: [{need, level}] where level 1 is
## a quiet mark and 2 is the accent (act on it).
## `cap` is the load carried before it tells.
static func needs(body: Body, minutes: float, load: float, cap: float = CREEL) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hunger := body.hunger_level(minutes)
	if hunger >= 1:
		out.append({"need": &"hunger", "level": 2 if hunger >= 2 else 1})
	if body.wet > 0.3:
		out.append({"need": &"wet", "level": 2 if body.wet > 0.75 else 1})
	if load > cap:
		out.append({"need": &"load", "level": 2 if load >= cap * 2.0 else 1})
	if body.tired > 0.6:
		out.append({"need": &"tired", "level": 2 if body.tired > 0.9 else 1})
	return out


## Distance in tiles to the nearest living hostile among `mobs` (group &"mobs"
## members: `pos: Vector2`, `alive: bool`, optional `hostile: bool`). INF if none.
static func nearest_hostile(mobs: Array, p: Vector2) -> float:
	var best := INF
	for m: Object in mobs:
		if m == null:
			continue
		var alive: Variant = m.get("alive")
		if alive != null and not bool(alive):
			continue
		var hostile: Variant = m.get("hostile")
		if hostile != null and not bool(hostile):
			continue
		var mp: Variant = m.get("pos")
		if mp is Vector2:
			best = minf(best, (mp as Vector2).distance_to(p))
	return best


static func hostile_near(mobs: Array, p: Vector2) -> bool:
	return nearest_hostile(mobs, p) <= HOSTILE_RADIUS


## The use hint is an out-of-fight prompt: never while busy, while a page is
## open, or with a hostile close (no text in a fight).
static func hint_allowed(busy: bool, screen_open: bool, mobs: Array, p: Vector2) -> bool:
	return not busy and not screen_open and not hostile_near(mobs, p)


## The hint line for a prop: "pine - fell", or "" when nothing is to be done to it.
static func prop_hint(kind: int) -> String:
	if STATIONS.has(kind):
		return "%s - make" % PropKind.NAMES[kind]
	if PROP_VERBS.has(kind):
		return "%s - %s" % [PropKind.NAMES[kind], PROP_VERBS[kind]]
	return ""


## The key that does a hint's verb: stations open the making page.
static func hint_key(kind: int) -> String:
	return "c" if STATIONS.has(kind) else "e"


## What the slate calls a thing: its Items name, or its id made readable.
static func item_name(id: StringName) -> String:
	return Items.display_name(id).replace("_", " ")


const ARTICLES: PackedStringArray = ["a ", "an ", "some "]


## True if a name counts itself ("a piece of plate"), so a number must
## replace the article rather than stand before it.
static func has_article(name: String) -> bool:
	for a in ARTICLES:
		if name.begins_with(a):
			return true
	return false


## A name with no article, for "the ..." and for a slip's item column.
static func bare(name: String) -> String:
	for a in ARTICLES:
		if name.begins_with(a):
			return name.substr(a.length())
	return name


## More than one of a thing that counts itself: "a piece of plate" -> "pieces
## of plate". A name without an article is left as it is ("driftwood", "mussels").
static func plural(name: String) -> String:
	if not name.begins_with("a ") and not name.begins_with("an "):
		return bare(name)
	var n := bare(name)
	var cut := n.find(" of ")
	var head := n if cut < 0 else n.substr(0, cut)
	var tail := "" if cut < 0 else n.substr(cut)
	for end: String in ["s", "x", "ch", "sh"]:
		if head.ends_with(end):
			return head + "es" + tail
	if head.length() > 1 and head.ends_with("y") and not "aeiou".contains(head[head.length() - 2]):
		return head.substr(0, head.length() - 1) + "ies" + tail
	return head + "s" + tail


## A number of a thing in words: "a piece of plate", "two pieces of plate",
## "one driftwood", "three driftwood".
static func counted(name: String, n: int) -> String:
	if has_article(name):
		return name if n == 1 else "%s %s" % [UiLink.count_word(n), plural(name)]
	return "%s %s" % [UiLink.count_word(n), name]


static func bare_name(id: StringName) -> String:
	return bare(item_name(id))


## A list row's name before its "×n": "wick", "pieces of plate".
static func list_name(id: StringName, n: int) -> String:
	var name := item_name(id)
	return plural(name) if n > 1 and has_article(name) else name


## Every recipe, at every station, that wants `id`. [{recipe, station}]
static func recipes_using(id: StringName, recipes: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in recipes:
		if (r.get("needs", {}) as Dictionary).has(id):
			out.append(r)
	return out


## Recipes at every station kind, from Crafting (or a stand-in list).
static func all_recipes(extra: Array[Dictionary] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for st: StringName in [&"hand", &"fire", &"bench", &"kiln", &"wheel", &"loom"]:
		out.append_array(Crafting.recipes_at(st))
	if out.is_empty():
		out.append_array(extra)
	return out


static func item_group(id: StringName) -> StringName:
	return UiLink.group_of(id)


## The carrying app's rows: group headers followed by that group's items, by name.
## [{header: StringName}] or [{id: StringName, count: int}].
static func inventory_rows(inv: Inventory) -> Array[Dictionary]:
	var by_group := {}
	for id: StringName in inv.items:
		var g := item_group(id)
		if not by_group.has(g):
			by_group[g] = []
		by_group[g].append(id)
	var out: Array[Dictionary] = []
	for g in GROUPS:
		if not by_group.has(g):
			continue
		var ids: Array = by_group[g]
		ids.sort_custom(func(a: StringName, b: StringName) -> bool: return Items.display_name(a) < Items.display_name(b))
		out.append({"header": g})
		for id: StringName in ids:
			out.append({"id": id, "count": inv.count(id)})
	return out


## Whole hours and minutes, said plainly: "4 h", "1 h 30", "45 min".
static func duration(minutes: float) -> String:
	var m := roundi(minutes)
	if m < 60:
		return "%d min" % m
	if m % 60 == 0:
		return "%d h" % (m / 60)
	return "%d h %02d" % [m / 60, m % 60]


## The clock face at a world minute: "12:30", or "day 3 04:00" once it passes midnight
## of the day `now_minutes` is in.
static func clock_at(minutes: float, now_minutes: float = -1.0) -> String:
	var h := floori(fposmod(minutes, 1440.0) / 60.0)
	var m := floori(fposmod(minutes, 60.0))
	var day := floori(minutes / 1440.0)
	if now_minutes >= 0.0 and day != floori(now_minutes / 1440.0):
		return "day %d %02d:%02d" % [day + 1, h, m]
	return "%02d:%02d" % [h, m]


## Make sure the inventory holds at least n of each; never adds twice, so it
## is safe if another system applies the same --give.
static func apply_give(inv: Inventory, give: Dictionary) -> void:
	for id: StringName in give:
		var want: int = give[id]
		if inv.count(id) < want:
			inv.add(id, want - inv.count(id))


## A share as a percentage that never reads 0 once anything is there: "12%", "0.4%".
static func share(f: float) -> String:
	var p := f * 100.0
	if p > 0.0 and p < 9.95:
		return "%.1f%%" % maxf(0.1, p)
	return "%d%%" % roundi(p)


## 3 -> "3", 2.5 -> "2.5".
static func num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## Where a recipe is made, in words: "by hand", "at the fire".
static func station_words(at: StringName) -> String:
	return "by hand" if at == &"hand" or at == &"" else "at the %s" % at


## The thing a recipe is drawn by: its first output, or the station it builds,
## or the held tool it mends.
static func recipe_output(r: Dictionary) -> StringName:
	for id: StringName in r.get("makes", {}):
		return id
	return &""


## A recipe's line in a list: what it makes ("charcoal ×2"), what it builds
## ("build a fire") or what it does ("sharpen what is in hand"). When another
## recipe in `among` makes the same, the first input that tells them apart is
## added: "pick, of iron".
static func recipe_title(r: Dictionary, among: Array[Dictionary] = []) -> String:
	var title := ""
	var builds := StringName(r.get("builds", &""))
	match StringName(r.get("action", &"")):
		&"hone": title = "sharpen what is in hand"
		&"reedge": title = "re-edge what is in hand"
	if builds != &"":
		title = "build a %s" % builds
	if title == "":
		var parts := PackedStringArray()
		var makes: Dictionary = r.get("makes", {})
		for id: StringName in makes:
			var n := int(makes[id])
			parts.append(list_name(id, n) + (" ×%d" % n if n > 1 else ""))
		title = ", ".join(parts)
	var twins: Array[Dictionary] = []
	for o in among:
		if o != r and _same_result(o, r):
			twins.append(o)
	if twins.is_empty():
		return title
	for id: StringName in r.get("needs", {}):
		if twins.all(func(o: Dictionary) -> bool: return not (o.get("needs", {}) as Dictionary).has(id)):
			return "%s, of %s" % [title, item_name(id)]
	return title


## Two recipes that end in the same thing: the same outputs (in any number), the
## same station built, or the same mend.
static func _same_result(a: Dictionary, b: Dictionary) -> bool:
	if a.get("builds", &"") != b.get("builds", &"") or a.get("action", &"") != b.get("action", &""):
		return false
	var ka: Array = (a.get("makes", {}) as Dictionary).keys()
	var kb: Array = (b.get("makes", {}) as Dictionary).keys()
	ka.sort()
	kb.sort()
	return ka == kb
