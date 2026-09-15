extends SceneTree
## Chunk build cost by stage, headless (the CPU work is the same as in game):
##   godot --headless --path . -s tools/gd/bench_chunks.gd -- --seed=1


func _initialize() -> void:
	var o := BootOptions.parse(OS.get_cmdline_user_args())
	var w := WorldGen.generate(o.seed_value, o.size)
	var t0 := Time.get_ticks_usec()
	var m := TerrainMesher.new(w)
	var d := Decor.new(w, m)
	print("bench setup %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var stages := {"fill": 0.0, "shore": 0.0, "mesher": 0.0, "decor": 0.0}
	var n := 0
	var cn := ceili(float(w.size) / TerrainMesher.CHUNK)
	for cy in range(1, cn - 1):
		for cx in range(1, cn - 1):
			var x0 := cx * 32 - 1
			var y0 := cy * 32 - 1
			var a := Time.get_ticks_usec()
			var rc := PackedByteArray()
			var rc2 := PackedByteArray()
			var rb := PackedFloat32Array()
			m.transitions.fill(x0, y0, x0 + 34, y0 + 34, rc, rc2, rb)
			var b := Time.get_ticks_usec()
			m._shore_field(x0, y0, x0 + 34, y0 + 34)
			var c := Time.get_ticks_usec()
			var ch := m.build(cx, cy)
			var e := Time.get_ticks_usec()
			d.build(ch)
			var f := Time.get_ticks_usec()
			stages.fill += (b - a) / 1000.0
			stages.shore += (c - b) / 1000.0
			stages.mesher += (e - c) / 1000.0
			stages.decor += (f - e) / 1000.0
			n += 1
	print("bench %d chunks: transitions %.1f, shore %.1f, mesher total %.1f, decor %.1f ms avg" % [n, stages.fill / n, stages.shore / n, stages.mesher / n, stages.decor / n])
	print("prof texfill %.1f window %.1f tiles %.1f ms, verts %d" % [TerrainMesher.PROF[0] / 1000.0 / n, TerrainMesher.PROF[1] / 1000.0 / n, TerrainMesher.PROF[2] / 1000.0 / n, TerrainMesher.PROF[3] / n])
	quit()
