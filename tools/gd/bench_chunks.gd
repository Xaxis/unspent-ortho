extends SceneTree
## Chunk build cost, headless (the CPU work is the same as in game):
##   godot --headless --path . -s tools/gd/bench_chunks.gd -- --seed=1


func _initialize() -> void:
	var o := BootOptions.parse(OS.get_cmdline_user_args())
	var w := WorldGen.generate(o.seed_value, o.size)
	var t0 := Time.get_ticks_usec()
	var m := TerrainMesher.new(w)
	print("bench setup %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	# A fixed workload, so a run on a busy machine can be read against it.
	var c0 := Time.get_ticks_usec()
	var acc := 0.0
	for i in 1000000:
		acc += sqrt(float(i & 255))
	print("bench calibration %.1f ms (about 30 when the machine is idle)" % ((Time.get_ticks_usec() - c0) / 1000.0))
	var n := 0
	var total := 0.0
	var cn := ceili(float(w.size) / TerrainMesher.CHUNK)
	for cy in range(1, cn - 1):
		for cx in range(1, cn - 1):
			var a := Time.get_ticks_usec()
			m.build_chunk(cx, cy)
			total += (Time.get_ticks_usec() - a) / 1000.0
			n += 1
	print("bench %d chunks: %.1f ms avg" % [n, total / n])
	var pr := TerrainMesher.PROF
	print("bench mesher: fill %.1f shore %.1f tiles %.1f lattice %.1f cells %.1f water %.1f commit %.1f ms, %d verts" % [pr[0] / 1000.0 / n, pr[1] / 1000.0 / n, pr[2] / 1000.0 / n, pr[7] / 1000.0 / n, pr[3] / 1000.0 / n, pr[4] / 1000.0 / n, pr[5] / 1000.0 / n, pr[6] / n])
	quit()
