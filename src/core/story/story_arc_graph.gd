class_name StoryArcGraph
extends RefCounted
## One arc as a graph, for dev mode's arc view (docs/ROADMAP.md, "Tools track"):
## its beats in order, what can land each one (the doors StoryMap reads) with
## every line said and who says it where, what must be known before a door
## opens, the gates a beat opens into 2029, and where the arc touches a region's
## own asks. Every node carries the line of source that made it.
##
##   StoryArcGraph.build(map, arc) -> StoryArcGraph   pure; reads StoryMap and the tables
##
## A node: {id, kind: beat | door | gate | subarc, title, lines: [[who, text]],
## place, source, col, row, beat (the beat it serves), arc}. An edge: {from, to,
## kind: next (beat to beat, the arc's own order) | lands (door to its beat) |
## needs (a beat that must be known first, to the door it opens) | opens (a beat
## to the gate it opens) | asks (a sub-arc to the beat it lands)}.

## Lines of a conversation's node shown on its door, at most.
const MOST_LINES := 4

var arc: StringName = &""
var nodes: Array[Dictionary] = []
var edges: Array[Dictionary] = []
var _by_id := {}


static func build(map: StoryMap, arc_id: StringName) -> StoryArcGraph:
	var g := StoryArcGraph.new()
	g.arc = arc_id
	if map == null or not StoryContent.ARCS.has(arc_id):
		return g
	var list: Array = StoryContent.arc_beats(arc_id)
	for i in list.size():
		var b: StringName = list[i]
		var d: Dictionary = map.beats.get(b, {})
		if d.is_empty():
			continue
		var lines: Array = [["", "\"%s\"" % str(d.says)]]
		lines.append(["where", str(map.places[d.place].name) if d.place != &"" else "no place here: %s" % str(d.why)])
		lines.append(["leg", "%d  %s" % [int(d.at_leg) + 1, StoryMap.LEGS[int(d.at_leg)]]])
		if bool(d.reveal):
			lines.append(["", "a revelation: nothing else reveals until it is felt"])
		g._add({"id": StringName("beat:%s" % b), "kind": &"beat", "title": "%d  %s" % [i + 1, str(d.short)], "lines": lines,
			"place": d.place, "source": str(d.source), "col": i, "row": 0, "beat": b, "arc": arc_id})
		if i > 0 and map.beats.has(list[i - 1]):
			g.edges.append({"from": StringName("beat:%s" % list[i - 1]), "to": StringName("beat:%s" % b), "kind": &"next"})
		var row := 1
		for door: Dictionary in d.doors:
			var id := StringName("door:%s:%s:%s" % [b, door.id, door.get("node", &"")])
			if g._by_id.has(id):
				continue
			g._add(g._door_node(map, door, id, b, i, row))
			g.edges.append({"from": id, "to": StringName("beat:%s" % b), "kind": &"lands"})
			for need: StringName in _needs(door):
				g.edges.append({"from": StringName("beat:%s" % need), "to": id, "kind": &"needs", "known": need})
			row += 1
		for gate: Dictionary in StoryGates.GATES:
			if gate.opens == b:
				var gid := StringName("gate:%s" % gate.id)
				g._add({"id": gid, "kind": &"gate", "title": "a gate into 2029", "lines": [
					["at", String(gate.at).replace("_", " ")], ["onto", String(gate.then).replace("_", " ")],
					["", "open once this is felt"]], "place": gate.at, "source": "src/core/story/story_gates.gd:1",
					"col": i, "row": -1, "beat": b, "arc": arc_id})
				g.edges.append({"from": StringName("beat:%s" % b), "to": gid, "kind": &"opens"})
		for door: Dictionary in d.doors:
			if door.kind == &"witness" and door.id == &"burned_seen":
				var sid := StringName("subarc:%s" % b)
				g._add({"id": sid, "kind": &"subarc", "title": "a region asks", "lines": [
					["", "rescue, the walk home, sabotage: a yard broken and not put dark burns the nearest roof on its body, else his own fire, else none"],
					["", "(StorySubarc, one per region)"]], "place": &"", "source": "src/core/story/story_subarc.gd:1",
					"col": i, "row": -1, "beat": b, "arc": arc_id})
				g.edges.append({"from": sid, "to": StringName("beat:%s" % b), "kind": &"asks"})
	# A need on a beat of another arc has no node of its own here: it is said on the door.
	var kept: Array[Dictionary] = []
	for e: Dictionary in g.edges:
		if g._by_id.has(e.from) and g._by_id.has(e.to):
			kept.append(e)
	g.edges = kept
	return g


func node(id: StringName) -> Dictionary:
	return _by_id.get(id, {})


func _add(n: Dictionary) -> void:
	nodes.append(n)
	_by_id[n.id] = n


func _door_node(map: StoryMap, door: Dictionary, id: StringName, b: StringName, col: int, row: int) -> Dictionary:
	var lines: Array = []
	var title := ""
	var place: StringName = door.get("place", &"")
	match door.kind:
		&"talk":
			var who := str(door.speaker)
			title = "%s  (talk)" % who
			var t: Dictionary = StoryContent.TALKS.get(door.id, {})
			var n: Dictionary = t.get("nodes", {}).get(door.node, {})
			var said: Array = n.get("says", [])
			for k in mini(said.size(), MOST_LINES):
				lines.append([who, str(said[k])])
			for r: Dictionary in n.get("replies", []):
				if (r.get("beats", []) as Array).has(b):
					lines.append(["he says", str(r.text)])
		&"fragment_placed", &"fragment_land", &"room":
			var f: Dictionary = StoryContent.FRAGMENTS.get(door.id, {})
			title = "%s  (%s)" % [str(f.get("title", door.id)), str(f.get("kind", "words"))]
			var said: Array = f.get("lines", [])
			for k in mini(said.size(), MOST_LINES):
				lines.append(["", str(said[k])])
		&"keeper":
			title = str(door.speaker)
			lines.append(["", "taken, it gives back what it held" if door.id != &"TESTIMONY_SENTINEL" else "its testimony, read on the slate"])
		&"testimony":
			title = str(door.speaker)
			lines.append(["", "read off it on the slate"])
		&"witness":
			title = "seen: %s" % String(door.id).replace("_", " ")
		&"secret":
			title = "the three memories back"
	lines.append(["where", str(map.places[place].name) if place != &"" and map.places.has(place) else str(door.why)])
	for need: StringName in _needs(door):
		lines.append(["once known", str(StoryContent.BEATS.get(need, {}).get("short", need))])
	return {"id": id, "kind": &"door", "title": title, "lines": lines, "place": place, "source": str(door.source),
		"col": col, "row": row, "beat": b, "arc": arc, "door": door.kind}


## The beats that must be known before a door can land its beat: a reply's
## `when`, a person who is not there until one (`appears_when`), a page shut
## until one is felt (`until`).
static func _needs(door: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	match door.kind:
		&"talk":
			var t: Dictionary = StoryContent.TALKS.get(door.id, {})
			var nodes: Dictionary = t.get("nodes", {})
			for n: StringName in nodes:
				for r: Dictionary in nodes[n].get("replies", []):
					var w := StringName(str(r.get("when", &"")))
					if w == &"" or not StoryContent.BEATS.has(w):
						continue
					# A reply that leads to the door's node, or one in it that lands the beat.
					var lands_it := false
					for rb: StringName in r.get("beats", []):
						lands_it = lands_it or (door.beats as Array).has(rb)
					if (n == door.node and lands_it) or StringName(str(r.get("to", &""))) == door.node:
						if not out.has(w):
							out.append(w)
			if door.cast != &"":
				var c := StoryCast.get_def(door.cast)
				if c != null and c.appears_when != &"" and not out.has(c.appears_when):
					out.append(c.appears_when)
		&"fragment_placed", &"fragment_land", &"room":
			var until := StringName(str(StoryContent.FRAGMENTS.get(door.id, {}).get("until", &"")))
			if StoryContent.BEATS.has(until):
				out.append(until)
	return out
