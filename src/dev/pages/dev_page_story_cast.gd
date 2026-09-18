class_name DevPageStoryCast
extends DevPage
## The named people (docs/STORY_SYSTEM.md §8, §10), by the place each stands at:
## where the story cast them in THIS world, whether they are there now and, if not,
## what they wait on, and whether he has spoken to them. E stands beside one, as a
## tour's `at cast:ID` does, so a writer can walk up and hear them.

## Casting sweeps the world's villages, works, landmarks and portals, so it is done
## once per page and not per keypress.
var _placed := {}


func heading() -> String:
	return "PEOPLE"


func rows() -> Array[Dictionary]:
	if _placed.is_empty():
		_placed = StoryPlan.cast(game.world)
	var out: Array[Dictionary] = []
	for s: StorySlot in StoryPlan.slots():
		var here: Array[StoryCharacter] = []
		for c: StoryCharacter in StoryCast.all():
			if c.at == s.id:
				here.append(c)
		if here.is_empty():
			continue
		out.append(header("%s — %s" % [String(s.id).trim_prefix("the_").replace("_", " "), _where(s)]))
		for c: StoryCharacter in here:
			var state := _state(c)
			out.append(item(StringName("cast_%s" % c.id), "%s, %s" % [c.name, c.title], state,
				{"tone": "" if state == "there" or state == "met" else "dim"}))
	return out


## Where a slot was cast in this world, or why it was not.
func _where(s: StorySlot) -> String:
	if s.realm != game.world.realm:
		return "in the %s" % s.realm
	if not _placed.has(s.id):
		return "not in this world"
	var p: Vector2 = _placed[s.id].pos
	return "%d, %d" % [floori(p.x), floori(p.y)]


## What stands between the player and this person now, in one word or two.
func _state(c: StoryCharacter) -> String:
	if not _placed.has(c.at):
		return "not cast"
	if c.gone_when != &"" and Story.landed(c.gone_when):
		return "gone"
	if c.appears_when != &"" and not StoryPacing.felt(c.appears_when):
		return "settling" if Story.landed(c.appears_when) else "waits"
	return "met" if Story.met(c.id) else "there"


func confirm(row: Dictionary) -> void:
	var id := String(row.id)
	if not id.begins_with("cast_"):
		return
	var c := StoryCast.get_def(StringName(id.substr(5)))
	var to := _cast_place(c.id)
	if not to.is_finite():
		refuse("%s is not stood in this world: %s." % [c.name, _state(c)])
		return
	DevSession.came_from = game.player.pos
	DevCheats.teleport(game, to)
	Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)
	screen.close()


## Beside the person, as 49_cast answers a tour.
func _cast_place(id: StringName) -> Vector2:
	var cast := DevCheats.system(game, "49_cast")
	if cast == null:
		return Vector2.INF
	return cast.call("tour_place", "cast:%s" % id)


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var id := String(screen.menu.selected().get("id", ""))
	if not id.begins_with("cast_"):
		return
	var c := StoryCast.get_def(StringName(id.substr(5)))
	if c == null:
		return
	var y := panel_heading(ci, r, r.position.y + 16, c.name)
	y = panel_pair(ci, r, y, "now", _state(c))
	if c.appears_when != &"":
		y = panel_pair(ci, r, y, "comes once", String(StoryContent.BEATS.get(c.appears_when, {}).get("short", c.appears_when)))
	if c.gone_when != &"":
		y = panel_pair(ci, r, y, "goes once", String(StoryContent.BEATS.get(c.gone_when, {}).get("short", c.gone_when)))
	y = panel_pair(ci, r, y, "walks with him", "can" if c.may_join else "no")
	y = panel_pair(ci, r, y, "their words", String(c.talk))
	y += 8
	for pair: Array in [["wants", c.wants], ["fears", c.fears], ["hides", c.hides]]:
		y = panel_heading(ci, r, y, str(pair[0]))
		y = panel_wrapped(ci, r, y, str(pair[1]))
