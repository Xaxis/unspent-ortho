class_name DevPageBody
extends DevPage
## The player's body: what is held on (never hungry, unseen, no pressure), how
## much a blow takes (the configuration's `rules.harm`), and what is done at once.


func heading() -> String:
	return "BODY"


func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = [header("held on")]
	out.append(item(&"harm", "harm taken", ConfigChoices.show("rules.harm", GameConfig.value("rules.harm")),
		{"steps": true, "edited": GameConfig.edits.has("rules.harm")}))
	out.append(item(&"fed", "never hungry", "yes" if DevSession.fed else "no", {"steps": true}))
	out.append(item(&"unseen", "machines read me as theirs", "yes" if DevSession.unseen else "no", {"steps": true}))
	out.append(item(&"sheltered", "no pressure from the land", "yes" if DevSession.sheltered else "no", {"steps": true}))
	out.append(header("now"))
	out.append(item(&"mend", "mend", "%d of %d" % [game.body.health, game.body.max_health]))
	out.append(item(&"feed", "feed", _hunger()))
	out.append(item(&"dry", "dry off", "%d%% wet" % roundi(game.body.wet * 100.0)))
	out.append(item(&"lamp", "fill the lamp", "%d min of oil" % roundi(Survival.lamp_oil(game))))
	out.append(item(&"empty", "put everything away", "", {"tone": "warn"}))
	return out


func _hunger() -> String:
	return ["fed", "peckish", "hungry", "starving"][clampi(game.body.hunger_level(game.clock.minutes), 0, 3)]


func confirm(row: Dictionary) -> void:
	match row.id:
		&"mend":
			DevCheats.mend(game)
			report("Mended.")
		&"feed":
			DevCheats.feed(game)
			report("Fed.")
		&"dry":
			DevCheats.dry(game)
			report("Dry.")
		&"lamp":
			DevCheats.fill_lamp(game)
			report("The lamp is full.")
		&"empty":
			if screen.ask("empty", "Again: everything but the knife goes."):
				DevCheats.empty_creel(game)
				report("Carrying the knife.")
		_:
			side(row, 1)


func side(row: Dictionary, dir: int) -> void:
	match row.id:
		&"harm":
			GameConfig.set_value("rules.harm", ConfigChoices.step("rules.harm", GameConfig.value("rules.harm"), dir))
		&"fed":
			DevSession.fed = not DevSession.fed
		&"unseen":
			DevSession.unseen = not DevSession.unseen
		&"sheltered":
			DevSession.sheltered = not DevSession.sheltered
		_:
			return
	DevMode.touched = true
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var b := game.body
	var y := r.position.y + 16
	y = panel_heading(ci, r, y, "the body")
	y = panel_pair(ci, r, y, "health", "%d of %d" % [b.health, b.max_health])
	y = panel_pair(ci, r, y, "wind", "%d%%" % roundi(b.wind / maxf(1.0, b.max_wind) * 100.0))
	y = panel_pair(ci, r, y, "hunger", _hunger())
	y = panel_pair(ci, r, y, "wet", "%d%%" % roundi(b.wet * 100.0))
	y = panel_pair(ci, r, y, "load", "%s of %s" % [UiRules.num(game.inventory.bulk()), UiRules.num(UiLink.creel(game.inventory, b))])
	var felt := PackedStringArray()
	for id: Variant in b.pressure:
		if float(b.pressure[id]) >= Hazards.FELT:
			felt.append("%s %d%%" % [str(id), roundi(float(b.pressure[id]) * 100.0)])
	y = panel_pair(ci, r, y, "pressing", " ".join(felt) if not felt.is_empty() else "nothing")
	y += 16
	match screen.menu.selected().get("id", &""):
		&"harm":
			y = panel_wrapped(ci, r, y, str(ConfigSchema.row("rules.harm").note))
			panel_wrapped(ci, r, y, "An edit of the configuration: kept only if kept on its page.", UiTheme.MACHINE[3])
		&"unseen":
			panel_wrapped(ci, r, y, "Held as a stolen signet holds it: every machine reads the player as one of its own, and the file cools.")
		&"sheltered":
			panel_wrapped(ci, r, y, "Every pressure answered, as if the right gear were worn for all sixteen.")
