class_name FrontProbe
extends RefCounted
## `perf front SECS`: what a gust front does to the picture, sampled where it
## matters. After `near front` (18_trample) has chosen a bush with a crown
## downwind of it, this reads the rendered frame every frame for SECS at three
## places — the grass upwind of the bush, the bush, and the crown — and prints
## each one's mean brightness over time, one line per sample:
##   tour front t=SECONDS grass=L bush=L crown=L
## A front crossing them shows as a brightness peak in each, in that order,
## lagged by the distance between them over the front's speed. Frames are
## finished before they are read (a readback), so the numbers are the picture.

## World tiles upwind of the bush the grass sample stands.
const UPWIND := 3.0
## Height over the ground each sample looks at: a blade, the bush, the crown.
const HEIGHTS: Array[float] = [0.15, 0.45, 2.6]
## Screen pixels round each sample, square.
const BOX := 18


static func perf(tour: Node, game: Node, parts: PackedStringArray) -> bool:
	var secs := parts[2].to_float() if parts.size() > 2 else 6.0
	var trample: Node = null
	for s: Node in game.get("systems"):
		if s.name == "18_trample":
			trample = s
	if trample == null or not (trample.get("front_bush") as Vector2).is_finite():
		printerr("tour perf front: no `near front` has chosen a bush and a crown")
		return false
	var bush: Vector2 = trample.get("front_bush")
	var crown: Vector2 = trample.get("front_crown")
	var dir := (crown - bush).normalized()
	var at: Array[Vector2] = [bush - dir * UPWIND, bush, crown]
	var view: WorldView = game.get("view")
	var cam := tour.get_viewport().get_camera_3d()
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(secs * 1000.0):
		await RenderingServer.frame_post_draw
		var img := tour.get_viewport().get_texture().get_image()
		var line := "tour front t=%.2f" % ((Time.get_ticks_msec() - start) / 1000.0)
		for i in 3:
			var p := at[i]
			var sp := cam.unproject_position(Vector3(p.x, view.surface_height(p) + HEIGHTS[i], p.y))
			sp *= Vector2(img.get_size()) / tour.get_viewport().get_visible_rect().size
			line += " %s=%.1f" % [["grass", "bush", "crown"][i], _luma(img, Vector2i(sp))]
		print(line)
	return true


static func _luma(img: Image, c: Vector2i) -> float:
	var sum := 0.0
	var n := 0
	for y in range(c.y - BOX, c.y + BOX + 1, 3):
		for x in range(c.x - BOX, c.x + BOX + 1, 3):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var col := img.get_pixel(x, y)
			sum += (0.3 * col.r + 0.59 * col.g + 0.11 * col.b) * 255.0
			n += 1
	return sum / maxf(float(n), 1.0)
