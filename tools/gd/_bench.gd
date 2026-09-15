extends SceneTree

func _initialize() -> void:
	var size := 512
	var n := size * size
	var a := PackedFloat32Array(); a.resize(n)
	var b := PackedFloat32Array(); b.resize(n)
	var best := 1e9
	for r in 5:
		var t := Time.get_ticks_usec()
		for y in size:
			for x in size:
				var i := y * size + x
				b[i] = a[i] * 0.5 + a[i] * a[i]
		best = minf(best, (Time.get_ticks_usec() - t) / 1000.0)
	print("calibration 2d loop arith (13 ms unloaded): ", best)
	quit()
