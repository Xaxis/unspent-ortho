class_name DevPageStoryLedger
extends DevPage
## The world writing him down (docs/DESIGN.md, §10): what it has seen him
## do, both records as they read at this minute, and a row per act to note one
## here and now, so a writer can see the notebook and the error log fill without
## breaking a works to do it.


func heading() -> String:
	return "LEDGER"


func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(header("seen"))
	var seen := Story.ledger()
	if seen.is_empty():
		out.append(item(&"none", "nothing yet", "", {"tone": "dim"}))
	for i in seen.size():
		var e: Dictionary = seen[i]
		var ago := Story.now - float(e.at)
		var heard := ago >= StoryLedger.LAG
		out.append(item(StringName("seen_%d" % i), "%s, %s" % [String(e.act), String(e.land)],
			"%dh ago%s" % [floori(ago / 60.0), "" if heard else ", not heard yet"], {"tone": "" if heard else "dim"}))
	out.append(header("note one here"))
	for act: StringName in StoryLedger.ACTS:
		out.append(item(StringName("note_%s" % act), str(StoryLedger.ACTS[act].people), String(act)))
	return out


func confirm(row: Dictionary) -> void:
	var id := String(row.id)
	if not id.begins_with("note_"):
		return
	var act := StringName(id.substr(5))
	var d := BiomeRegistry.at(game.world, game.player.pos)
	# Noted as long enough ago to have been heard: a writer wants to read the
	# notebook now, not half a day from now.
	Story.note(act, d.id if d != null else &"", Story.now - StoryLedger.LAG)
	report("Noted: %s, heard of by now." % StoryLedger.ACTS[act].people)


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var y := panel_heading(ci, r, r.position.y + 16, "the people's notebook")
	for l: String in StoryLedger.lines(&"people"):
		y = panel_line(ci, r, y, l, UiTheme.TEXT_DIM)
	y += 12
	y = panel_heading(ci, r, y, "the machines' log", true)
	for l: String in StoryLedger.lines(&"machines"):
		y = panel_line(ci, r, y, l, UiTheme.TEXT_DIM)
