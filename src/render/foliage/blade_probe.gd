class_name BladeProbe
extends RefCounted
## `perf blades`: what colour the grass blades in the frame are, and only the
## blades. The frame is read with every chunk's swaying grass shown, hidden,
## shown and hidden again; a blade is a pixel that changes each time the grass
## goes and is steady across both frames of each kind, so what falls, a body's
## ## breathing, a flier and a blade's own sway are left out. The line gives those
## pixels' mean brightness and saturation, the same for what stands behind them
## in the frame without them (the ground), and what has settled round the
## focus (10_sky `settled`):
##   tour blades n=PIXELS luma=L sat=S rgb=R,G,B behind luma=L sat=S settled={..}
## Snow lying on the blades reads as luma up, ash as saturation down. The
## weather's own light tints blades and ground alike, so a blade's change is
## read against the change behind it.

## A channel step, of 255, that counts as the pixel having changed.
const CHANGED := 10.0
## Frames let pass after a toggle before the frame is read.
const SETTLE_FRAMES := 3


static func perf(tour: Node, game: Node) -> bool:
	var blades := FoliagePerf.nodes(game, "sward")
	if blades.is_empty():
		printerr("tour perf blades: no grass is loaded")
		return false
	var shown := await _frame(tour)
	_show(blades, false)
	var hidden := await _frame(tour)
	_show(blades, true)
	var shown2 := await _frame(tour)
	_show(blades, false)
	var hidden2 := await _frame(tour)
	_show(blades, true)
	var n := 0
	var sum := Vector3.ZERO
	var sat := 0.0
	var back := Vector3.ZERO
	var back_sat := 0.0
	for y in range(0, shown.get_height(), 2):
		for x in range(0, shown.get_width(), 2):
			var a := shown.get_pixel(x, y)
			var b := hidden.get_pixel(x, y)
			var a2 := shown2.get_pixel(x, y)
			var b2 := hidden2.get_pixel(x, y)
			if _step(a, b) < CHANGED or _step(a2, b2) < CHANGED or _step(a, a2) >= CHANGED or _step(b, b2) >= CHANGED:
				continue
			n += 1
			sum += Vector3(a.r, a.g, a.b)
			sat += _sat(a)
			back += Vector3(b.r, b.g, b.b)
			back_sat += _sat(b)
	if n == 0:
		printerr("tour perf blades: no pixel of the frame is a blade")
		return false
	var mean := sum / float(n) * 255.0
	var settled: Variant = {}
	for s: Node in game.get("systems"):
		if s.name == "10_sky":
			settled = s.get("settled")
	var bm := back / float(n) * 255.0
	print("tour blades n=%d luma=%.1f sat=%.3f rgb=%.0f,%.0f,%.0f behind luma=%.1f sat=%.3f settled=%s"
		% [n, _luma(mean), sat / float(n), mean.x, mean.y, mean.z, _luma(bm), back_sat / float(n), settled])
	return true


static func _frame(tour: Node) -> Image:
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	return tour.get_viewport().get_texture().get_image()


## The largest channel step between two pixels, of 255.
static func _step(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) * 255.0


static func _show(nodes: Array[Node3D], on: bool) -> void:
	for m in nodes:
		m.visible = on


static func _sat(c: Color) -> float:
	var hi := maxf(c.r, maxf(c.g, c.b))
	return (hi - minf(c.r, minf(c.g, c.b))) / maxf(hi, 0.001)


static func _luma(c: Vector3) -> float:
	return 0.3 * c.x + 0.59 * c.y + 0.11 * c.z
