## `perf stats begin` / `perf stats end LABEL [raw]`: the `--stats` block over a
## window of a tour instead of over the first frames of a shot, so a measurement
## can walk, turn and change the view on the real keys and be judged on exactly
## those frames. 12_landscape keeps the numbers; this only opens and closes the
## window. `raw` prints every frame's milliseconds, which is what "did the first
## press stall" is answered by. Needs `--stats` on the command line.

static func perf(_tour: Node, game: Node, parts: PackedStringArray) -> bool:
	var land: Node = null
	for s: Node in game.get("systems"):
		if s.has_method(&"stats_begin"):
			land = s
	if land == null or not bool(game.get("options").get("stats")):
		printerr("tour perf stats: run with --stats")
		return false
	match parts[2] if parts.size() > 2 else "":
		"begin":
			land.call(&"stats_begin")
		"end":
			land.call(&"stats_end", parts[3] if parts.size() > 3 else "window",
				parts.size() > 4 and parts[4] == "raw")
		_:
			printerr("tour perf stats: begin or end")
			return false
	return true
