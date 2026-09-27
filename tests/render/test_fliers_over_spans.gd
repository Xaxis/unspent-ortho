extends TestCase
## The plan's traffic (FlierView) over mass hanging above the land (docs/ABOVE.md
## §2): the light a flier drops lands on the first thing under it, which over a
## span is the span's top, not the street beneath the rock; and its hull keeps
## its lane's height over that top rather than flying through the mass.

const FlierViewScript := preload("res://src/render/depth/flier_view.gd")


func test_a_flier_over_a_span_lights_its_top_and_clears_it() -> void:
	var w := WorldData.new(3, 64)
	for i in w.level.size():
		w.level[i] = 2
		w.ground[i] = Ground.GRASS
		w.country[i] = Country.COAST
	# A span from level 6 up to level 60 (30 units): taller than a lane is high.
	for y in range(20, 40):
		for x in range(20, 40):
			w.set_overhead(x, y, 6, 60)
	var v: FlierView = FlierViewScript.new()
	tree.root.add_child(v)
	v.setup(w, null, ShaderMaterial.new())
	var high := FlierView.HIGH
	var top := 60 * WorldData.STEP
	v._place(0, Vector2(30.5, 30.5), high, 0.0)
	var shade_y := v._shades[0].global_position.y
	var hull_y := v._pool[0].global_position.y
	gt(shade_y, top - 0.01, "the dropped light lies on the span's top (%.2f), not the street under it" % top)
	gt(hull_y, top + high - 0.01, "and the hull keeps its lane's height over that top")
	# Off the span, nothing moves.
	v._place(1, Vector2(5.5, 5.5), high, 0.0)
	near(v._shades[1].global_position.y, w.height_at(Vector2(5.5, 5.5)) + 0.06, 1e-4, "over open ground it lies on the ground as before")
	v.queue_free()
