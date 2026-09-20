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
	out.append(["frame", "%s  %d draws" % [frame_line(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]])
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


## The last few seconds of frames, as a DISTRIBUTION and judged against
## docs/PERF.md -- because the row this replaces could not see the thing it was
## being read for.
##
## **IT SHOWED `fps` AND A MEAN, WHICH ARE THE TWO NUMBERS THAT CANNOT SEE A
## HITCH.** The owner booted the game and said "every second of running causes a
## small lurch, nothing is smooth" while the median frame was 8.3 ms; a mean of
## 8.3 with one frame in ninety at 140 ms reads as perfect and plays as broken.
## `Engine.get_frames_per_second()` is worse still — frames in the last SECOND,
## so a single 140 ms stall costs it about eight of sixty and it prints 52.
##
## And the engine's own `TIME_PROCESS` cannot stand in for a frame either: it is
## a sample taken about twice a second, not a per-frame value (12_landscape's
## `_driven_line` has the measurement). So this times the frames itself, the way
## `--stats` does, and reports what a player actually feels: the worst of the
## last few seconds, and how many times its own budget was missed.
##
## WINDOW is a few seconds at 120 Hz. Short enough that walking into a bad place
## shows immediately, long enough that one frame cannot own the number.
const WINDOW := 600
const OVER_MS := 16.7

static var _ms := PackedFloat32Array()
static var _last_usec := 0


## Called once a frame by whoever draws the readout, so the window fills even
## while the panel is shut and the first look is not a blank one.
static func tick() -> void:
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		_ms.append(float(now - _last_usec) / 1000.0)
		if _ms.size() > WINDOW:
			_ms = _ms.slice(_ms.size() - WINDOW)
	_last_usec = now


static func frame_line() -> String:
	if _ms.size() < 8:
		return "measuring"
	var a := Array(_ms)
	a.sort()
	var pick := func(q: float) -> float:
		return float(a[clampi(int(q * (a.size() - 1)), 0, a.size() - 1)])
	var over := 0
	for v: float in a:
		if v > OVER_MS:
			over += 1
	var p50: float = pick.call(0.5)
	var p95: float = pick.call(0.95)
	var worst := float(a[-1])
	return "%.1f p50  %.1f p95  %.1f worst  %d over %.1f" % [p50, p95, worst, over, OVER_MS]
