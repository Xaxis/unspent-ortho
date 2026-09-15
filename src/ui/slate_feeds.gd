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
##   default: every living mob within READ_RADIUS tiles, hostile or indifferent
##   by its `hostile` flag; interference unknown.
##
## saves (the saves package):
##   {slots: [{id: StringName, title: String, when: String, place: String,
##             thumb: Image (THUMB size, or null), empty: bool}], can_save: bool}
##   acts: row ids are slot ids; the act decides save or load from the slot.
##   default: three empty slots, refused with the reason.

const APPS: Array[StringName] = [&"loadout", &"reads", &"saves"]
const THUMB := Vector2i(96, 54)
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
		&"saves": return default_saves()
	return {}


## Confirm a row. Returns the line to say ("" for none); "!" first = refused.
static func act(app: StringName, game: Game, row_id: StringName) -> String:
	if _acts.has(app) and (_acts[app] as Callable).is_valid():
		return String((_acts[app] as Callable).call(game, row_id))
	match app:
		&"loadout": return "!Kit is put on from carrying; no module fits here yet."
		&"saves": return "!No save module is wired into the slate yet."
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
			var hostile: Variant = m.get("hostile")
			var k: Variant = m.get("kind")
			var kind := StringName(k) if k != null else &""
			scans.append({"id": StringName("scan_%d" % m.get_instance_id()), "kind": kind, "name": String(kind).get_slice(".", 0).replace("_", " "), "pos": mp,
				"disposition": &"hostile" if hostile == null or bool(hostile) else &"indifferent", "note": ""})
		scans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.pos as Vector2).distance_to(p) < (b.pos as Vector2).distance_to(p))
	return {"interference": -1.0, "network": "", "scans": scans}


static func default_saves() -> Dictionary:
	var slots: Array[Dictionary] = []
	for i in 3:
		slots.append({"id": StringName("slot_%d" % (i + 1)), "title": "", "when": "", "place": "", "thumb": null, "empty": true})
	return {"slots": slots, "can_save": false}
