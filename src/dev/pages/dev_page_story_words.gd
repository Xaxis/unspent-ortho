class_name DevPageStoryWords
extends DevPage
## What is written, and on what (docs/STORY_SYSTEM.md §10): every readable thing
## within reach of where he stands and which words it holds in THIS world
## (`StoryFragments.held_by`), then every fragment the story has, read or not. E
## puts a page on the glass without marking it found, so a writer can look at
## words without changing what the playthrough knows.

## How far round the player a readable thing is listed.
const NEAR := 14.0

var _near: Array[Dictionary] = []


func heading() -> String:
	return "WORDS"


func rows() -> Array[Dictionary]:
	if _near.is_empty():
		_near = _readables_near()
	var out: Array[Dictionary] = []
	out.append(header("near you"))
	if _near.is_empty():
		out.append(item(&"none_near", "nothing readable within %d tiles" % int(NEAR), "", {"tone": "dim"}))
	for r: Dictionary in _near:
		var id: StringName = r.holds
		out.append(item(StringName("near_%d" % r.prop), "%s, %d tiles" % [String(r.kind), roundi(float(r.d))],
			String(id) if id != &"" else "nothing written", {"tone": "" if id != &"" else "dim"}))
	for place: StringName in StoryContent.PLACED:
		out.append(header("placed: %s" % String(place).replace("_", " ")))
		for id: StringName in StoryContent.PLACED[place]:
			out.append(_row(id))
	out.append(header("dealt by kind"))
	for id: StringName in StoryFragments.all():
		if not StoryFragments.placed(id):
			out.append(_row(id))
	return out


func _row(id: StringName) -> Dictionary:
	return item(StringName("frag_%s" % id), StoryFragments.title_of(id), "read" if Story.knows(id) else String(StoryFragments.kind_of(id)),
		{"tone": "" if Story.knows(id) else "dim"})


func _readables_near() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for q: WorldProp in game.query.props_near(game.player.pos, NEAR):
		var kind := StoryProps.kind_of(q.kind)
		if kind == &"":
			continue
		out.append({"prop": q.id, "kind": kind, "holds": StoryFragments.held_by(game.world, q),
			"d": q.pos.distance_to(game.player.pos)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.d) < float(b.d))
	return out


func confirm(row: Dictionary) -> void:
	var id := String(row.id)
	var words := &""
	if id.begins_with("frag_"):
		words = StringName(id.substr(5))
	elif id.begins_with("near_"):
		for r: Dictionary in _near:
			if "near_%d" % r.prop == id:
				words = r.holds
	if words == &"":
		refuse("Nothing is written on it.")
		return
	var story := DevCheats.system(game, "49_story")
	if story == null:
		return
	screen.close()
	story.call("open_reading", words, false)


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var id := String(screen.menu.selected().get("id", ""))
	var words := &""
	if id.begins_with("frag_"):
		words = StringName(id.substr(5))
	elif id.begins_with("near_"):
		for n: Dictionary in _near:
			if "near_%d" % n.prop == id:
				words = n.holds
	if words == &"":
		return
	var y := panel_heading(ci, r, r.position.y + 16, StoryFragments.title_of(words))
	for l: String in StoryFragments.lines(words):
		y = panel_line(ci, r, y, l, UiTheme.TEXT_DIM)
	y += 8
	var lands: Array = StoryContent.FRAGMENTS[words].get("beats", [])
	if not lands.is_empty():
		var said := PackedStringArray()
		for b: StringName in lands:
			said.append(String(StoryContent.BEATS.get(b, {}).get("short", b)))
		panel_pair(ci, r, y, "lands", ", ".join(said))
