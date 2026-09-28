class_name StoryMap
extends RefCounted
## The whole story laid on one world, for the story map (dev mode's STORY tab)
## and the arc view: every beat of every arc, where on THIS world it lands, the
## order it lands in, and the line of source that made it (docs/ROADMAP.md,
## "Tools track").
##
##   StoryMap.project(world)          -> StoryMap   the shape, pure, per world
##   map.state_of(beat)               -> &"landed" | &"withheld" | &"open" | &"later"
##   map.visible(arc, cast, leg)      -> beat ids a filter keeps, in story order
##
## WHERE A BEAT LANDS is where one of its DOORS stands. A door is anything that
## can land it, read off the same tables the game lands it from (tests/story/
## test_arcs.gd holds that every beat has one):
##
##   talk      a node reached or a reply given; a named person's stands at their
##             story slot, a trade's is said by anybody of the trade, anywhere
##   fragment  words read off a thing: a story place's own (PLACED), a kind of
##             room's (ROOMS), or dealt to a readable thing in the lands it names
##   keeper    a landscape's keeper taken gives its memory back (KEEPER_MEMORY),
##             and any keeper's testimony tells him something is missing
##   testimony a machine read on the slate, any of its role, anywhere
##   witness   the player's own state (WITNESS_ON), where the world has a place
##             for it
##   secret    the three memories back: where the last of them came back
##
## A beat takes the place of the first of its doors that has one, in `RANK`
## order. A beat none of whose doors stands anywhere on this world is UNPLACED,
## and says why: the map lists it and never pretends to a place.
##
## Pure and derived: it reads the world and the story's tables, casts nothing
## new, and is never saved. What the player has done (`state_of`) is read live,
## so one projection serves a whole game.

## The legs of the journey (docs/STORY.md, "The journey"), by StorySlot.leg.
const LEGS: Array[String] = ["home coast", "across the water", "below", "far shore", "orbit"]

## Which door gives a beat its place, first first: a person standing somewhere
## is the most particular place a beat has, a thing dealt to a whole land the least.
const RANK: Array[StringName] = [&"talk", &"fragment_placed", &"room", &"keeper", &"witness", &"fragment_land", &"secret", &"testimony"]

## Where a witnessed event happens, when the world has one place for it: a
## story slot. An event with none happens wherever the player is.
const WITNESS_AT := {
	&"works_dark": &"the_yard",
	&"other_realm": &"the_shaft",
	&"ring_held": &"local_the_crags",
}

const CONTENT := "res://src/content/story/story_content.gd"
const CAST_DIR := "res://src/content/story/cast"

var seed_value := 0
## [{leg, name, body, pos}] in journey order; `pos` is the leg's first spine stop.
var legs: Array[Dictionary] = []
## The spine's stops in order: [{id, name, pos, leg}].
var spine: Array[Dictionary] = []
## Place id -> {id, name, pos, leg, kind}.
var places: Dictionary = {}
## Beat id -> {id, arc, index, says, short, reveal, doors, place, leg, order}.
var beats: Dictionary = {}
## Every beat, in story order: by leg, then by how far along its arc it is.
var order: Array[StringName] = []
## Arc ids in ARCS order.
var arcs: Array[StringName] = []
## [{arc, from, to}]: each arc's placed beats, one to the next, in arc order.
var arrows: Array[Dictionary] = []
## Beat ids with no place on this world.
var unplaced: Array[StringName] = []
## StoryGates.all(world), as cast.
var gates: Array[Dictionary] = []
## A region's own asks (StorySubarc): [{region, land, pos (its yard), from (the village nearest it)}].
var subarcs: Array[Dictionary] = []
## "TABLE.id" -> line, read once from the source.
var _lines: Dictionary = {}
## The keeper's lair nearest where he woke: any keeper's testimony lands there first.
var _first_lair: StringName = &""


static var _cached_world: WorldData = null
static var _cached: StoryMap = null


## The map for `world`, projected once per world object (StoryPlan.cast's rule).
static func of(world: WorldData) -> StoryMap:
	if world == null:
		return null
	if world != _cached_world:
		_cached_world = world
		_cached = project(world)
	return _cached


static func forget() -> void:
	_cached_world = null
	_cached = null


static func project(world: WorldData) -> StoryMap:
	var m := StoryMap.new()
	if world == null:
		return m
	m.seed_value = world.seed_value
	m._lines = source_index(_read(CONTENT))
	m._places(world)
	m._beats()
	m._order()
	m._arrows()
	m.gates = StoryGates.all(world)
	m._subarcs(world)
	return m


# --- places ---------------------------------------------------------------------------------

func _places(world: WorldData) -> void:
	var cast := StoryPlan.cast(world)
	var bodies := StoryJourney.bodies(world)
	var by_id := {}
	for s: StorySlot in StoryPlan.slots():
		by_id[s.id] = s
	for s: StorySlot in StoryPlan.slots():
		# 2029's places stand on their 2098 twins' tiles (Realm.ERA is the same coast).
		var at: StringName = s.mirror if s.mirror != &"" else s.id
		if not cast.has(at):
			continue
		var twin: StorySlot = by_id.get(at, s)
		var p: Vector2 = cast[at].pos
		var leg := twin.leg if twin.ordered else _leg_at(world, bodies, p)
		places[s.id] = {"id": s.id, "name": _slot_name(s), "pos": p, "leg": leg, "kind": &"slot",
			"local": not s.ordered and s.mirror == &"", "twin": s.mirror}
	# A place is named for who stands there, the way a writer knows it.
	var who := {}
	for c: StoryCharacter in StoryCast.all():
		if places.has(c.at):
			var names: PackedStringArray = who.get(c.at, PackedStringArray())
			names.append(c.name)
			who[c.at] = names
	for at: StringName in who:
		var names: PackedStringArray = who[at]
		places[at]["who"] = ", ".join(names.slice(0, 3)) + (" +%d" % (names.size() - 3) if names.size() > 3 else "")
	for s: StorySlot in StoryPlan.slots():
		if s.ordered and places.has(s.id):
			spine.append({"id": s.id, "name": places[s.id].name, "pos": places[s.id].pos, "leg": s.leg})
	for i in LEGS.size():
		var leg := {"leg": i, "name": LEGS[i], "body": StoryJourney.body_for(world, i), "pos": Vector2.INF}
		for stop: Dictionary in spine:
			if int(stop.leg) == i:
				leg.pos = stop.pos
				break
		legs.append(leg)
	# The keepers: each design's lair nearest where he woke.
	for st: SentinelState in Sentinels.states(world):
		var id := StringName("lair:%s" % st.design)
		if places.has(id) and (places[id].pos as Vector2).distance_to(world.spawn) <= st.lair.distance_to(world.spawn):
			continue
		places[id] = {"id": id, "name": "the %s keeper" % String(st.land).replace("_", " "), "pos": st.lair,
			"leg": _leg_at(world, bodies, st.lair), "kind": &"lair"}
		if _first_lair == &"" or st.lair.distance_to(world.spawn) < (places[_first_lair].pos as Vector2).distance_to(world.spawn):
			_first_lair = id
	# Rooms: the bunkers by whose they are, every other kind at its door nearest home.
	var tenants := StoryRooms.tenants(world)
	for t: Threshold in Interiors.thresholds(world):
		var room := StoryRooms.room_of(t.kind, StringName(str(tenants.get(t.key, &""))))
		if not StoryContent.ROOMS.has(room):
			continue
		var id := StringName("room:%s" % room)
		if places.has(id) and (places[id].pos as Vector2).distance_to(world.spawn) <= t.host.distance_to(world.spawn):
			continue
		places[id] = {"id": id, "name": _room_name(room), "pos": t.host, "leg": _leg_at(world, bodies, t.host), "kind": &"room"}


static func _leg_at(world: WorldData, bodies: Array[int], p: Vector2) -> int:
	var at := bodies.find(world.continent_at(floori(p.x), floori(p.y)))
	return clampi(at, 0, LEGS.size() - 1) if at >= 0 else 0


static func _slot_name(s: StorySlot) -> String:
	var n := String(s.id)
	if n.begins_with("local_"):
		var land := BiomeRegistry.get_def(StringName(n.trim_prefix("local_")))
		return (land.display_name.to_lower() if land != null else n.trim_prefix("local_").replace("_", " "))
	if n.begins_with("then_"):
		return "2029: %s" % n.trim_prefix("then_").replace("_", " ")
	return n.replace("_", " ")


static func _room_name(room: StringName) -> String:
	var parts := String(room).split(":")
	if parts.size() > 1:
		return "%s's %s" % [parts[1], parts[0].replace("_", " ")]
	return ("his " if parts[0] == "bunker" else "a ") + parts[0].replace("_", " ")


# --- beats and their doors ------------------------------------------------------------------

func _beats() -> void:
	for arc: StringName in StoryContent.ARCS:
		arcs.append(arc)
		var list: Array = StoryContent.arc_beats(arc)
		for i in list.size():
			var b: StringName = list[i]
			var def: Dictionary = StoryContent.BEATS.get(b, {})
			beats[b] = {"id": b, "arc": arc, "index": i, "of": list.size(), "says": str(def.get("says", "")),
				"short": str(def.get("short", b)), "reveal": bool(def.get("reveal", false)), "doors": [],
				"place": &"", "pos": Vector2.INF, "leg": -1, "why": "", "source": _source("BEATS", b)}
	for door: Dictionary in _all_doors():
		for b: StringName in door.beats:
			if beats.has(b):
				(beats[b].doors as Array).append(door)
	# The secret lands where the last of its memories came back.
	for b: StringName in [&"secret_whole", &"secret_misremembered"]:
		if beats.has(b):
			(beats[b].doors as Array).append({"kind": &"secret", "id": &"StorySecret", "place": &"", "speaker": "",
				"cast": &"", "why": "the three memories back", "source": "src/core/story/story_secret.gd:1", "beats": [b]})
	for b: StringName in beats:
		var d: Dictionary = beats[b]
		(d.doors as Array).sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return RANK.find(x.kind) < RANK.find(y.kind))
		for door: Dictionary in d.doors:
			if door.place != &"" and places.has(door.place):
				d.place = door.place
				d.pos = places[door.place].pos
				d.leg = int(places[door.place].leg)
				break
	for b: StringName in [&"secret_whole", &"secret_misremembered"]:
		if beats.has(b) and beats[b].place == &"":
			for m: StringName in StorySecret.KEY:
				if beats.has(m) and beats[m].place != &"":
					beats[b].place = beats[m].place
					beats[b].pos = beats[m].pos
					beats[b].leg = beats[m].leg
	for b: StringName in beats:
		var d: Dictionary = beats[b]
		if d.place == &"":
			var whys := PackedStringArray()
			for door: Dictionary in d.doors:
				var w := str(door.why)
				if w != "" and not whys.has(w):
					whys.append(w)
			d.why = "; ".join(whys) if not whys.is_empty() else "no door"
			unplaced.append(b)


## Every door the story's tables declare: {kind, id, node, speaker, cast, place, why, source, beats}.
func _all_doors() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var who := {}
	for c: StoryCharacter in StoryCast.all():
		who[c.talk] = c
	for talk: StringName in StoryContent.TALKS:
		var t: Dictionary = StoryContent.TALKS[talk]
		var c: StoryCharacter = who.get(talk, null)
		var speaker := c.name if c != null else str(t.get("title", t.get("who", talk)))
		var place := &""
		var why := ""
		if c != null:
			place = c.at
			why = "%s stands at %s, not cast on this world" % [c.name, c.at]
		elif bool(t.get("machine", false)):
			why = "a machine that answers, at a place not yet grown"
		else:
			why = "said by any %s, anywhere" % str(t.get("who", "stranger"))
		var nodes: Dictionary = t.get("nodes", {})
		for node: StringName in nodes:
			var n: Dictionary = nodes[node]
			var got: Array = n.get("beats", []).duplicate()
			for r: Dictionary in n.get("replies", []):
				got.append_array(r.get("beats", []))
			if got.is_empty():
				continue
			out.append({"kind": &"talk", "id": talk, "node": node, "speaker": speaker, "cast": c.id if c != null else &"",
				"place": place, "why": why, "source": _source("TALKS", talk), "beats": got})
	for id: StringName in StoryContent.FRAGMENTS:
		var f: Dictionary = StoryContent.FRAGMENTS[id]
		var got: Array = f.get("beats", [])
		if got.is_empty():
			continue
		var door := {"kind": &"fragment_land", "id": id, "node": &"", "speaker": str(f.get("title", id)), "cast": &"",
			"place": &"", "why": "", "source": _source("FRAGMENTS", id), "beats": got}
		var own := _placed_at(id)
		var room := _room_of(id)
		if own != &"":
			door.kind = &"fragment_placed"
			door.place = own
			door.why = "the %s's own words, at a place not yet grown" % String(own).replace("_", " ")
		elif room != &"":
			door.kind = &"room"
			door.place = StringName("room:%s" % room)
			door.why = "in %s, and this world has none" % _room_name(room)
		elif not bool(f.get("dealt", true)):
			door.why = "opened by something else, never dealt"
		else:
			var lands: Array = f.get("lands", [])
			var kind := String(f.get("kind", "thing"))
			if lands.is_empty():
				door.why = "dealt to any %s, anywhere" % kind
			else:
				# The nearest land of those it names that this world has a local for.
				for l: Variant in lands:
					door.place = StringName("local_%s" % l)
					if places.has(door.place):
						break
				door.why = "dealt to a %s in %s" % [kind, ", ".join(PackedStringArray(lands)).replace("_", " ")]
		out.append(door)
	for keeper: StringName in StoryContent.KEEPER_MEMORY:
		out.append({"kind": &"keeper", "id": keeper, "node": &"", "speaker": "the %s" % String(keeper).replace("_", " "), "cast": &"",
			"place": StringName("lair:%s" % keeper), "why": "its keeper stands nowhere on this world",
			"source": _source("KEEPER_MEMORY", keeper), "beats": [StoryContent.KEEPER_MEMORY[keeper].memory]})
	# Any keeper's testimony: the one nearest where he woke is the first he can read.
	out.append({"kind": &"keeper", "id": &"TESTIMONY_SENTINEL", "node": &"", "speaker": "any keeper", "cast": &"",
		"place": _first_lair, "why": "no keeper on this world", "source": _source("TESTIMONY_SENTINEL", &""),
		"beats": StoryContent.TESTIMONY_SENTINEL.get("beats", [])})
	for role: StringName in StoryContent.TESTIMONY:
		out.append({"kind": &"testimony", "id": role, "node": &"", "speaker": "any %s" % role, "cast": &"", "place": &"",
			"why": "read off any %s machine" % role, "source": _source("TESTIMONY", role),
			"beats": StoryContent.TESTIMONY[role].get("beats", [])})
	out.append({"kind": &"testimony", "id": &"passes", "node": &"", "speaker": "a machine that passes", "cast": &"", "place": &"",
		"why": "read off a machine that passes, in the Covenant's streets", "source": _source("TESTIMONY_PASSES", &""),
		"beats": StoryContent.TESTIMONY_PASSES.get("beats", [])})
	for event: StringName in StoryContent.WITNESS_ON:
		var b: StringName = StoryContent.WITNESS_ON[event]
		out.append({"kind": &"witness", "id": event, "node": &"", "speaker": "", "cast": &"",
			"place": WITNESS_AT.get(event, &""), "why": str(StoryContent.WITNESSED.get(b, event)),
			"source": _source("WITNESS_ON", event), "beats": [b]})
	return out


static func _placed_at(id: StringName) -> StringName:
	for place: StringName in StoryContent.PLACED:
		if (StoryContent.PLACED[place] as Array).has(id):
			return &"the_black_site" if place == StorySlot.BLACK_SITE else place
	return &""


static func _room_of(id: StringName) -> StringName:
	for room: StringName in StoryContent.ROOMS:
		for key: StringName in StoryContent.ROOMS[room]:
			if (StoryContent.ROOMS[room][key] as Array).has(id):
				return room
	return &""


# --- order ------------------------------------------------------------------------------------

## Story order: the leg a beat lands on, then how far along its own arc it is, then
## the arcs' own order. A beat with no place goes by its arc alone, after the legs
## its arc has already reached.
func _order() -> void:
	var reach := {}
	for arc: StringName in arcs:
		var leg := 0
		for b: StringName in StoryContent.arc_beats(arc):
			var d: Dictionary = beats.get(b, {})
			if d.is_empty():
				continue
			if int(d.leg) >= 0:
				leg = int(d.leg)
			d["at_leg"] = int(d.leg) if int(d.leg) >= 0 else leg
	var all: Array[StringName] = []
	for arc: StringName in arcs:
		for b: StringName in StoryContent.arc_beats(arc):
			if beats.has(b) and not all.has(b):
				all.append(b)
	all.sort_custom(func(a: StringName, b: StringName) -> bool:
		var x: Dictionary = beats[a]
		var y: Dictionary = beats[b]
		if int(x.at_leg) != int(y.at_leg):
			return int(x.at_leg) < int(y.at_leg)
		var fx := float(x.index) / float(maxi(1, int(x.of)))
		var fy := float(y.index) / float(maxi(1, int(y.of)))
		if not is_equal_approx(fx, fy):
			return fx < fy
		return arcs.find(x.arc) < arcs.find(y.arc))
	order = all
	for i in order.size():
		beats[order[i]]["order"] = i


## One arrow from each placed beat of an arc to its next placed one, except
## between two landscapes' locals: what the people of one land noticed and what
## another's did are gathered by the arc, not walked from one to the other (the
## locals are colour, sought from home outward and never a stop, StoryPlan.LOCALS),
## and an arrow there would draw a journey nobody makes.
func _arrows() -> void:
	for arc: StringName in arcs:
		var last := &""
		for b: StringName in StoryContent.arc_beats(arc):
			if not beats.has(b) or beats[b].place == &"":
				continue
			if last != &"" and not (local(beats[last].place) and local(beats[b].place)):
				arrows.append({"arc": arc, "from": last, "to": b})
			last = b


## Whether a place is a landscape's local: colour, not a stop.
func local(place: StringName) -> bool:
	return bool(places.get(place, {}).get("local", false))


func _subarcs(world: WorldData) -> void:
	for w: WorksSite in Works.sites(world):
		var from := Vector2.INF
		for v: Dictionary in world.villages:
			var p: Vector2 = v.get("pos", Vector2.ZERO)
			if world.same_body(p, w.pos) and (not from.is_finite() or p.distance_to(w.pos) < from.distance_to(w.pos)):
				from = p
		subarcs.append({"region": w.region, "land": w.land, "pos": w.pos, "from": from})


# --- reading it -------------------------------------------------------------------------------

## What the live game has made of a beat: landed; withheld (a revelation that
## cannot be offered while another settles, StoryPacing); open (the next of its
## arc); or later.
func state_of(beat: StringName) -> StringName:
	if Story.landed(beat):
		return &"landed"
	var d: Dictionary = beats.get(beat, {})
	if d.is_empty():
		return &"later"
	if bool(d.reveal) and StoryPacing.settling():
		return &"withheld"
	if Story.next_of(d.arc) == beat:
		return &"open"
	return &"later"


## Whether a sub-arc of region `r` has been asked, and answered and thanked, by
## what the player has heard (StorySubarc's own marks): &"asked", &"thanked" or &"".
static func subarc_state(r: int) -> StringName:
	var asked := false
	for goal: StringName in StorySubarc.GOALS:
		var id := StringName("%d:%s" % [r, goal])
		if Story.heard(StringName("%s:said" % id)):
			return &"thanked"
		if Story.heard(id):
			asked = true
	return &"asked" if asked else &""


## The beats a filter keeps, in story order. `arc` an arc id, `cast` a character
## id (the beats a named person can land), `leg` 0..4; &"" or -1 keeps all.
func visible(arc: StringName = &"", cast: StringName = &"", leg: int = -1) -> Array[StringName]:
	var out: Array[StringName] = []
	for b: StringName in order:
		var d: Dictionary = beats[b]
		if arc != &"" and d.arc != arc:
			continue
		if leg >= 0 and int(d.leg) != leg:
			continue
		if cast != &"":
			var by := false
			for door: Dictionary in d.doors:
				if door.cast == cast:
					by = true
					break
			if not by:
				continue
		out.append(b)
	return out


## Every named person who can land a beat, in story order of their first.
func speakers() -> Array[StringName]:
	var out: Array[StringName] = []
	for b: StringName in order:
		for door: Dictionary in beats[b].doors:
			if door.cast != &"" and not out.has(door.cast):
				out.append(door.cast)
	return out


## Beats landing at each place, in story order: place id -> [beat ids]. A place
## of 2029 is its 2098 twin's tile (Realm.ERA), so its beats stand with the twin's.
func at_places() -> Dictionary:
	var out := {}
	for b: StringName in order:
		var p: StringName = beats[b].place
		if p == &"":
			continue
		var twin: StringName = places[p].get("twin", &"")
		if twin != &"" and places.has(twin):
			p = twin
		if not out.has(p):
			out[p] = []
		(out[p] as Array).append(b)
	return out


# --- where each line is written -----------------------------------------------------------

## "path:line" of an entry in the story's tables (`TABLE`, `id`), or the table's
## own line for id &"".
func _source(table: String, id: StringName) -> String:
	var key := table if id == &"" else "%s.%s" % [table, id]
	var line := int(_lines.get(key, 0))
	return "%s:%d" % [CONTENT.trim_prefix("res://"), line] if line > 0 else CONTENT.trim_prefix("res://")


## "path:line" of a named person's file.
static func cast_source(id: StringName) -> String:
	return "%s/%s.gd:1" % [CAST_DIR.trim_prefix("res://"), id]


## Where each entry of each table is written: "TABLE.id" -> line (1-based), and
## "TABLE" -> the line the table opens on. An entry is a key one tab in under a
## `const TABLE := {` line; anything deeper belongs to that entry.
static func source_index(text: String) -> Dictionary:
	var out := {}
	var table := ""
	var lines := text.split("\n")
	for i in lines.size():
		var l := lines[i]
		if l.begins_with("const "):
			table = l.trim_prefix("const ").get_slice(" ", 0).get_slice(":", 0)
			out[table] = i + 1
			continue
		if table == "" or not l.begins_with("\t&\""):
			continue
		var id := l.substr(3).get_slice("\"", 0)
		if not out.has("%s.%s" % [table, id]):
			out["%s.%s" % [table, id]] = i + 1
	return out


static func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)
