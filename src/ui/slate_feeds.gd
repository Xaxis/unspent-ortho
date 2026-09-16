class_name SlateFeeds
## Contract: other packages fill the slate's apps without touching src/ui.
## A package registers a feed (what the app shows) and, if its rows do
## something, an act (what confirming a row does), in its GameSystem's setup:
##
##   SlateFeeds.provide(&"loadout", func(game: Game) -> Dictionary: return {...})
##   SlateFeeds.on_act(&"loadout", func(game: Game, row_id: StringName) -> String: return "")
##
## An act returns one plain line to show (a refusal starts with "!"), or "".
## Without a feed each app shows what the game already knows, honestly.
##
## loadout (hazards, gear, abilities):
##   {slots: [{id: StringName, label: String, item: StringName (&"" empty),
##             modules: [{id: StringName, name: String, grants: String}]}],
##    resist: {hazard id: 0..1}, abilities: [{id, name: String, ready: bool, note: String}]}
##   default: head body hands back tool craft, from the worn kit and the thing in
##   hand; resistances from Body.resist; no abilities.
##
## reads (disposition, interference):
##   {interference: float 0..1 (or -1 unknown), network: String,
##    scans: [{id: StringName, kind: StringName, name: String, pos: Vector2,
##             disposition: StringName (hostile wary observant indifferent), note: String}]}
##   default: every living machine (roster `machine: true`) within READ_RADIUS
##   tiles, hostile or indifferent by its `hostile` flag; animals give no
##   signature; interference unknown.
##
## saves: not a feed. The saves app (UiSavesScreen) talks to the save system
##   (05_save: save_to, load_from) itself; it lives under home like the others.

## The apps that live under home (and read, so they open beside a hostile once
## home is up); loadout and reads are filled through feeds.
const APPS: Array[StringName] = [&"loadout", &"reads", &"saves"]
const READ_RADIUS := 24.0
const SLOTS: Array[StringName] = [&"head", &"body", &"hands", &"back", &"tool", &"craft"]
## Worn kit, by the slot it sits in.
const KIT_SLOT := {&"plate": &"body", &"brace": &"hands", &"rig": &"back", &"lens": &"head", &"aerial": &"head"}

static var _feeds: Dictionary = {}
static var _acts: Dictionary = {}


static func provide(app: StringName, feed: Callable) -> void:
	_feeds[app] = feed


static func on_act(app: StringName, act: Callable) -> void:
	_acts[app] = act


static func has_feed(app: StringName) -> bool:
	return _feeds.has(app) and (_feeds[app] as Callable).is_valid()


static func clear() -> void:
	_feeds.clear()
	_acts.clear()


## What an app shows now.
static func feed(app: StringName, game: Game) -> Dictionary:
	if has_feed(app):
		var v: Variant = (_feeds[app] as Callable).call(game)
		if v is Dictionary:
			return v
	match app:
		&"loadout": return default_loadout(game)
		&"reads": return default_reads(game)
	return {}


## Confirm a row. Returns the line to say ("" for none); "!" first = refused.
static func act(app: StringName, game: Game, row_id: StringName) -> String:
	if _acts.has(app) and (_acts[app] as Callable).is_valid():
		return String((_acts[app] as Callable).call(game, row_id))
	match app:
		&"loadout": return "!Kit is put on from carrying; no module fits here yet."
	return ""


## What can go in a slot, said plainly, for a slot standing empty: a player who
## has found nothing yet still learns what to look for.
static func fits(slot: StringName) -> String:
	var kinds := PackedStringArray()
	for kit: StringName in KIT_SLOT:
		if KIT_SLOT[kit] == slot:
			kinds.append(String(kit))
	if not kinds.is_empty():
		return "takes %s" % " or ".join(kinds)
	match slot:
		&"tool": return "takes what is in hand"
		&"craft": return "takes a mended machine module"
	return ""


static func default_loadout(game: Game) -> Dictionary:
	var slots: Array[Dictionary] = []
	var worn := &""
	var held := &""
	var resist := {}
	if game != null:
		worn = game.inventory.worn
		held = game.inventory.held
		resist = game.body.resist
	for s in SLOTS:
		var item := &""
		if s == &"tool":
			item = held
		elif worn != &"" and KIT_SLOT.get(Items.def(worn).get("kit", &""), &"") == s:
			item = worn
		slots.append({"id": s, "label": String(s), "item": item, "modules": []})
	return {"slots": slots, "resist": resist, "abilities": []}


static func default_reads(game: Game) -> Dictionary:
	var scans: Array[Dictionary] = []
	if game != null and game.is_inside_tree():
		var p := game.player.pos
		for m: Node in game.get_tree().get_nodes_in_group(&"mobs"):
			var alive: Variant = m.get("alive")
			var mp: Variant = m.get("pos")
			if (alive != null and not bool(alive)) or not (mp is Vector2):
				continue
			if (mp as Vector2).distance_to(p) > READ_RADIUS:
				continue
			var k: Variant = m.get("kind")
			var kind := StringName(k) if k != null else &""
			# The stolen module reads machine signatures: a dog or a gull gives none.
			if not bool(Roster.row(kind).get("machine", false)):
				continue
			var hostile: Variant = m.get("hostile")
			scans.append({"id": StringName("scan_%d" % m.get_instance_id()), "kind": kind, "name": String(kind).get_slice(".", 0).replace("_", " "), "pos": mp,
				"disposition": &"hostile" if hostile == null or bool(hostile) else &"indifferent", "note": ""})
		scans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.pos as Vector2).distance_to(p) < (b.pos as Vector2).distance_to(p))
	return {"interference": -1.0, "network": "", "scans": scans}
