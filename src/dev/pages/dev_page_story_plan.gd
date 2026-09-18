class_name DevPageStoryPlan
extends DevPage
## The guided path (docs/STORY_SYSTEM.md §6, §10): every stop of the spine, which
## leg of the journey it belongs to, and where it was cast in THIS world, with the
## revelation still settling, if any, above it. E goes there, so a writer can
## stand at any stop without walking the legs before it.

var _placed := {}
var _order: Array[int] = []


func heading() -> String:
	return "THE PATH"


func rows() -> Array[Dictionary]:
	if _placed.is_empty():
		_placed = StoryPlan.cast(game.world)
		_order = StoryJourney.bodies(game.world)
	var out: Array[Dictionary] = []
	out.append(header("pacing"))
	var last := StoryPacing.last_reveal()
	if StoryPacing.settling():
		out.append(item(&"settling", "being felt: %s" % StoryContent.BEATS[last].short,
			"%d min" % ceili(StoryPacing.settles_in()), {"tone": "warn"}))
	else:
		out.append(item(&"settled", "nothing settling", String(last) if last != &"" else "", {"tone": "dim"}))
	var group := ""
	for s: StorySlot in StoryPlan.slots():
		var g := "leg %d" % (s.leg + 1) if s.ordered else "locals"
		if g != group:
			group = g
			out.append(header(g))
		var value := "colour"
		if s.realm != game.world.realm:
			value = "in the %s" % s.realm
		elif _placed.has(s.id):
			value = "body %d" % (_order.find(int(_placed[s.id].body)) + 1)
		elif s.require:
			value = "NOT CAST"
		out.append(item(StringName("slot_%s" % s.id), String(s.id).trim_prefix("the_").replace("_", " "), value,
			{"tone": "warn" if value == "NOT CAST" else ("" if _placed.has(s.id) else "dim")}))
	out.append(header("the secret"))
	var got := StorySecret.order()
	var names := PackedStringArray()
	for m: StringName in got:
		names.append(String(m).trim_prefix("mem_"))
	var state := "whole" if StorySecret.whole() else ("out of order" if StorySecret.complete() else "%d of 3" % got.size())
	out.append(item(&"secret", ", ".join(names) if not names.is_empty() else "no memories back", state,
		{"tone": "warn" if state == "out of order" else ""}))
	out.append(header("gates into 2029"))
	for g: Dictionary in StoryGates.all(game.world):
		out.append(item(StringName("gate_%s" % g.id), String(g.id).trim_prefix("gate_"),
			"open" if bool(g.open) else "on %s" % String(StoryContent.BEATS[g.opens].short),
			{"tone": "" if bool(g.open) else "dim"}))
	var bad := StoryPlan.problems(game.world)
	out.append(header("problems"))
	if bad.is_empty():
		out.append(item(&"fine", "every required stop is cast", "", {"tone": "dim"}))
	for i in bad.size():
		out.append(item(StringName("problem_%d" % i), bad[i], "", {"tone": "warn"}))
	return out


func confirm(row: Dictionary) -> void:
	var id := String(row.id)
	if not id.begins_with("slot_"):
		return
	var s := StringName(id.substr(5))
	if not _placed.has(s):
		refuse("%s is not cast in this world." % s)
		return
	DevSession.came_from = game.player.pos
	# A stop in the sea (the black site) puts him on the nearest ground to it.
	DevCheats.teleport(game, _placed[s].pos)
	Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
	screen.close()


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var id := String(screen.menu.selected().get("id", ""))
	var y := r.position.y + 16
	if id == "settling" or id == "settled":
		y = panel_heading(ci, r, y, "one at a time")
		panel_wrapped(ci, r, y, "After a revelation lands, nothing else that reveals is offered, and nobody who waits on one comes, for %d world minutes (StoryPacing)." % int(StoryPacing.SETTLE))
		return
	if not id.begins_with("slot_"):
		return
	var s: StorySlot = null
	for sl: StorySlot in StoryPlan.slots():
		if String(sl.id) == id.substr(5):
			s = sl
	if s == null:
		return
	y = panel_heading(ci, r, y, String(s.id))
	y = panel_pair(ci, r, y, "needs", String(s.needs) + ((" " + String(s.kind)) if s.kind != &"" else ""))
	y = panel_pair(ci, r, y, "leg", str(s.leg + 1))
	y = panel_pair(ci, r, y, "load", "required" if s.require else "colour")
	if s.land != &"":
		y = panel_pair(ci, r, y, "landscape", String(s.land))
	if _placed.has(s.id):
		var p: Vector2 = _placed[s.id].pos
		y = panel_pair(ci, r, y, "cast at", "%d, %d" % [floori(p.x), floori(p.y)])
		y = panel_pair(ci, r, y, "from here", "%d tiles" % roundi(p.distance_to(game.player.pos)))
	var who := PackedStringArray()
	for c: StoryCharacter in StoryCast.all():
		if c.at == s.id:
			who.append(c.name)
	if not who.is_empty():
		y = panel_pair(ci, r, y, "people", ", ".join(who))
	var words: Array = StoryContent.PLACED.get(s.needs, [])
	if not words.is_empty():
		panel_pair(ci, r, y, "its own words", "%d" % words.size())
