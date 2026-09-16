class_name DevPageTime
extends DevPage
## The clock and the sky: the hour, a day on, how fast the clock runs (the
## configuration's `rules.clock`, as an edit), and weather held over the land.

const MOMENTS := [[&"dawn", "dawn", 6.0], [&"noon", "noon", 12.0], [&"dusk", "dusk", 19.5], [&"night", "midnight", 0.0]]
const STRENGTHS: Array[float] = [0.25, 0.5, 0.75, 1.0]

## The weather this page holds, as it steps: "rules" or a kind.
var _kind := "rules"
var _strength := 1.0


func heading() -> String:
	return "TIME AND SKY"


func rows() -> Array[Dictionary]:
	if Weather.forced_kind != &"":
		_kind = String(Weather.forced_kind)
	var out: Array[Dictionary] = [header("the clock")]
	out.append(item(&"hour", "hour", "%02d:%02d" % [floori(game.clock.hour()), floori(fmod(game.clock.minutes, 60.0))], {"steps": true}))
	out.append(item(&"minutes", "ten minutes", "", {"steps": true}))
	for m: Array in MOMENTS:
		out.append(item(m[0], m[1], "%02d:%02d" % [floori(m[2]), roundi(fmod(m[2], 1.0) * 60.0)]))
	out.append(item(&"day", "a day on", "day %d" % (game.clock.day() + 2)))
	out.append(item(&"rate", "clock runs", ConfigChoices.show("rules.clock", GameConfig.value("rules.clock")),
		{"steps": true, "edited": GameConfig.edits.has("rules.clock")}))
	out.append(header("the sky"))
	out.append(item(&"weather", "weather", ConfigChoices.show("world.weather", _kind), {"steps": true}))
	out.append(item(&"strength", "how hard", "%d%%" % roundi(_strength * 100.0), {"steps": true, "enabled": _kind != "rules", "why": "The land's own weather comes as hard as it comes."}))
	var bolts := Weather.LIGHTNING.has(StringName(_kind))
	out.append(item(&"bolt", "lightning", "", {"enabled": bolts, "why": "Only a storm throws lightning (storm, dry storm)."}))
	return out


func confirm(row: Dictionary) -> void:
	match row.id:
		&"dawn", &"noon", &"dusk", &"night":
			for m: Array in MOMENTS:
				if m[0] == row.id:
					DevCheats.set_hour(game, m[2])
			say(game.clock.label())
		&"day":
			DevCheats.add_minutes(game, 1440.0)
			say(game.clock.label())
		&"bolt":
			DevCheats.set_weather(game, "%s:%s:bolt" % [_kind, str(_strength)])
			say("Struck.")
		&"hour", &"rate", &"weather", &"strength", &"minutes":
			side(row, 1)


func side(row: Dictionary, dir: int) -> void:
	match row.id:
		&"hour":
			DevCheats.add_minutes(game, 60.0 * dir)
		&"minutes":
			DevCheats.add_minutes(game, 10.0 * dir)
		&"rate":
			GameConfig.set_value("rules.clock", ConfigChoices.step("rules.clock", GameConfig.value("rules.clock"), dir))
		&"weather":
			_kind = str(ConfigChoices.step("world.weather", _kind, dir))
			_apply()
		&"strength":
			if _kind == "rules":
				return
			var i := STRENGTHS.find(_strength)
			_strength = STRENGTHS[posmod(i + dir, STRENGTHS.size())]
			_apply()
		_:
			return
	Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)


func _apply() -> void:
	if _kind == "rules":
		DevCheats.set_weather(game, "rules")
	else:
		DevCheats.set_weather(game, "%s:%s" % [_kind, str(_strength)])


func detail(ci: CanvasItem, r: Rect2i) -> void:
	var y := r.position.y + 8
	y = panel_heading(ci, r, y, "now")
	y = panel_pair(ci, r, y, "clock", game.clock.label())
	var w := DevCheats.weather_here(game)
	y = panel_pair(ci, r, y, "sky", "%s %d%%" % [String(w.kind).replace("_", " "), roundi(float(w.strength) * 100.0)])
	y = panel_pair(ci, r, y, "held", "yes, until given back" if bool(w.forced) else "no, the land's own")
	y = panel_pair(ci, r, y, "clock runs", ConfigChoices.show("rules.clock", GameConfig.value("rules.clock")))
	y += 8
	var row := screen.menu.selected()
	match row.get("id", &""):
		&"rate":
			y = panel_wrapped(ci, r, y, str(ConfigSchema.row("rules.clock").note))
			y = panel_wrapped(ci, r, y, "An edit of the configuration: kept only if kept on its page.", UiTheme.MACHINE[3])
		&"weather", &"strength":
			y = panel_wrapped(ci, r, y, "Held weather stays over every landscape until it is set back to each land's own.")
		&"hour", &"minutes":
			y = panel_wrapped(ci, r, y, "Moving the clock is not sleeping: nothing on the land is cleared and nobody gets hungrier.")
