class_name DevPageStory
extends DevPage
## The story, from the inside (docs/STORY.md, docs/DEV.md): what this playthrough
## has found, what it has been told, and every beat that exists whether it has
## landed or not.
##
## The owner asked that all of it be editable. What that means here: land a beat,
## forget one, land a whole arc, forget the lot, and read back every choice the
## player has made — so a writer can sit in the middle of act three without
## playing to it, and see what a line will say when they get there.
##
## The words themselves live in `src/content/story/story_content.gd`, which this
## page names so nobody has to go looking.


func heading() -> String:
	return "STORY"


func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for arc: StringName in StoryContent.arcs():
		var def: Dictionary = StoryContent.ARCS[arc]
		var at := Story.at(arc)
		out.append(header("%s — %d%%" % [String(def.get("title", arc)), roundi(at * 100.0)]))
		for beat: StringName in StoryContent.arc_beats(arc):
			var landed := Story.landed(beat)
			out.append(item(beat, StoryContent.beat_says(beat), "known" if landed else "not yet",
				{"steps": true, "tone": "" if landed else "dim"}))
		out.append(item(StringName("arc_%s" % arc), "land the whole arc", "", {"tone": "warn"}))
	out.append(header("found"))
	out.append(item(&"found", "things read", "%d of %d" % [Story.found_count(), StoryFragments.all().size()]))
	for id: StringName in Story.found():
		out.append(item(StringName("frag_%s" % id), StoryFragments.title_of(id), String(id), {"tone": "dim"}))
	out.append(header("said"))
	var choices := Story.choices()
	if choices.is_empty():
		out.append(item(&"none", "nothing yet", "", {"tone": "dim"}))
	for where: StringName in choices:
		out.append(item(StringName("choice_%s" % where), String(where), String(choices[where]), {"tone": "dim"}))
	out.append(header("the whole lot"))
	out.append(item(&"forget", "forget everything the story knows", "", {"tone": "warn"}))
	out.append(item(&"where", "the words are in", "src/content/story/", {"tone": "dim"}))
	return out


## Left and right on a beat land it or take it back: the two directions are the
## same switch, because a beat is either known or it is not.
func side(row: Dictionary, _dir: int) -> void:
	var id: StringName = row.id
	if StoryContent.BEATS.has(id):
		if Story.landed(id):
			Story.forget_beat(id)
			report("Forgotten: %s" % StoryContent.beat_says(id))
		else:
			Story.beat(id)
			report("Landed: %s" % StoryContent.beat_says(id))


func confirm(row: Dictionary) -> void:
	var id: String = String(row.id)
	if StoryContent.BEATS.has(row.id):
		side(row, 1)
		return
	if id.begins_with("arc_"):
		var arc := StringName(id.substr(4))
		for beat: StringName in StoryContent.arc_beats(arc):
			Story.beat(beat)
		report("The whole of %s is known." % arc)
		return
	if id == "forget":
		if not screen.ask(&"story_forget", "Forget every beat, every reading and every answer?"):
			return
		Story.forget()
		report("The story knows nothing again.")
