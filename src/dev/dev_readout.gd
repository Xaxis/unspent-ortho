class_name DevReadout
## What dev mode reads off a running game, as pairs of words, for the home page's
## panel and the readout on the glass's edge (F3). Nothing here changes the game.


## [[name, value], ...] for where the player is and what the frame costs.
static func pairs(game: Game) -> Array:
	var out: Array = []
	if game == null or game.world == null or game.player == null:
		return out
	var w := game.world
	var p := game.player.pos
	var x := floori(p.x)
	var y := floori(p.y)
	var b := BiomeRegistry.at(w, p)
	var ground := w.ground_at(x, y)
	out.append(["at", "%.1f, %.1f  level %d" % [p.x, p.y, w.level_at(x, y)]])
	var land := b.display_name.to_lower()
	var region := w.region_at(x, y)
	if region >= 0:
		land += "  region %d" % region
	out.append(["land", land])
	out.append(["ground", Ground.NAMES[ground].replace("_", " ") if ground < Ground.NAMES.size() else str(ground)])
	var weather := DevCheats.weather_here(game)
	out.append(["sky", "%s %d%%%s" % [String(weather.kind).replace("_", " "), roundi(float(weather.strength) * 100.0), "  held" if bool(weather.forced) else ""]])
	out.append(["clock", "%s  x%s" % [game.clock.label(), str(snappedf(game.clock.rate, 0.1))]])
	var bodies := 0
	var aware := 0
	if game.is_inside_tree():
		for m: Node in game.get_tree().get_nodes_in_group(&"mobs"):
			if m.get("alive") == null or bool(m.get("alive")):
				bodies += 1
				if bool(m.get("aware")):
					aware += 1
	var file := DevCheats.file_here(game)
	out.append(["bodies", "%d about, %d aware  file %s" % [bodies, aware, String(file.level)]])
	out.append(["frame", "%d fps  %.1f ms  %d draws" % [Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]])
	out.append(["world", "seed %d  size %d  %d chunks due" % [w.seed_value, w.size, game.view.pending()]])
	return out


## The build this is, in a line: its stamp, or where it runs from.
static func build_line() -> String:
	var stamp := DevStamp.current()
	if not stamp.is_empty():
		return DevStamp.label(stamp)
	var commit := DevStamp.source_commit()
	return "source" + (" " + commit if commit != "" else "")


static func config_line() -> String:
	if GameConfig.active == "":
		return "none: every default"
	var line := GameConfig.active
	if GameConfig.source == &"stamp":
		line += ", this build's own"
	elif GameConfig.chain.size() > 1:
		line += " on " + " on ".join(GameConfig.chain.slice(1))
	if not GameConfig.edits.is_empty():
		line += "  %d edit%s" % [GameConfig.edits.size(), "" if GameConfig.edits.size() == 1 else "s"]
	return line
