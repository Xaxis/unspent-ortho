extends SceneTree

func _initialize() -> void:
	var size := 512
	var runs := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			size = a.trim_prefix("--size=").to_int()
		if a.begins_with("--runs="):
			runs = a.trim_prefix("--runs=").to_int()
	var best := {}
	for r in runs:
		WorldGen.generate(1 + r, size)
		for k: StringName in WorldGen.last_timings:
			best[k] = minf(best.get(k, 1e9), WorldGen.last_timings[k])
		for k: StringName in WorldGen.last_detail:
			best[k] = minf(best.get(k, 1e9), WorldGen.last_detail[k])
	var line := ""
	for k: StringName in best:
		line += "%s %.0f  " % [k, best[k]]
	print("min of %d: %s" % [runs, line])
	quit()
