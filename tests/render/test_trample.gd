extends TestCase
## Grass parts round whatever walks through it (TrampleField, 18_trample,
## grass.gdshader): leaning away from the body at its rim, pressed down under
## it, standing back up in seconds while the flattened path lingers.


func test_a_stamp_leans_the_grass_away_from_the_body() -> void:
	var f := TrampleField.new()
	var at := Vector2(100.3, 40.7)
	f.focus(at)
	f.stamp(at, 1.0, 1.0, 0.6)
	var east := f.at(at + Vector2(0.6, 0.0))
	var north := f.at(at + Vector2(0.0, -0.6))
	gt(east.x, 0.3, "east of the body the blades lean east (%s)" % east)
	lt(absf(east.y), 0.2, "and not sideways")
	lt(north.y, -0.3, "north of it they lean north (%s)" % north)
	gt(f.at(at).z, 0.5, "under the body they are pressed down")
	eq(f.at(at + Vector2(1.5, 0.0)), Vector3.ZERO, "past its reach nothing moved")
	check(not f.quiet, "the field knows something is pressed")


func test_the_lean_recovers_in_seconds_and_the_path_lingers() -> void:
	var f := TrampleField.new()
	var at := Vector2(10.0, 10.0)
	f.focus(at)
	f.stamp(at, 1.0, 1.0, 0.8)
	var p := at + Vector2(0.6, 0.0)
	var lean0 := f.at(p).x
	for i in 40:
		f.decay(0.1)
	var lean4 := f.at(p).x
	lt(lean4, lean0 * 0.1, "after 4 s the lean is nearly gone (%.3f of %.3f)" % [lean4, lean0])
	gt(f.at(at).z, 0.4, "but the path it pressed is still there (%.3f)" % f.at(at).z)
	for i in 360:
		f.decay(0.1)
	eq(f.at(at), Vector3.ZERO, "after 40 s the grass stands again")
	check(f.quiet, "and the field is quiet, so nothing is uploaded")


func test_a_stronger_stamp_is_never_weakened() -> void:
	var f := TrampleField.new()
	var at := Vector2(5.0, 5.0)
	f.focus(at)
	f.stamp(at, 1.0, 1.0)
	var strong := f.at(at + Vector2(0.6, 0.0)).x
	f.stamp(at, 1.0, 0.2)
	eq(f.at(at + Vector2(0.6, 0.0)).x, strong, "a light step after a heavy one leaves the heavy one's lean")


func test_following_the_focus_clears_what_leaves_and_keeps_what_stays() -> void:
	var f := TrampleField.new()
	var at := Vector2(50.0, 50.0)
	f.focus(at)
	f.stamp(at, 1.0, 1.0, 1.0)
	f.focus(at + Vector2(3.0, 0.0))
	gt(f.at(at).z, 0.9, "three tiles on, the path is still in the window")
	f.focus(at + Vector2(TrampleField.SPAN * 0.5 + 4.0, 0.0))
	eq(f.at(at), Vector3.ZERO, "past the window it is gone")
	# The slot it lived in now holds another place, and must start upright.
	var reused := at + Vector2(TrampleField.SPAN, 0.0)
	eq(f.at(reused), Vector3.ZERO, "the reused slot starts upright")


func test_the_upload_encodes_upright_as_the_shader_decodes_it() -> void:
	var f := TrampleField.new()
	var b := f.bytes()
	eq(b.size(), TrampleField.SIZE * TrampleField.SIZE * 4, "one RGBA8 texel a slot")
	eq(b[0], 128, "upright is 128")
	var src := FileAccess.get_file_as_string("res://src/render/wind.gdshaderinc")
	check(src.contains("* 255.0 - 128.0) / 127.0"), "wind.gdshaderinc decodes 128 as upright")
	var w := f.window()
	eq(w.w, TrampleField.SPAN, "the window says its span")


## The system, end to end on a real headless game: the player's own texel is
## pressed after a frame. Without 18_trample the field does not exist at all.
func test_a_running_game_presses_the_grass_under_the_player() -> void:
	var o := BootOptions.new()
	o.size = 64
	o.hour = 12.0
	var g := Game.new()
	tree.root.add_child(g)
	g.setup(o)
	await process_frames(3)
	var sys: GameSystem = null
	for s: GameSystem in g.systems:
		if s.name == "18_trample":
			sys = s
	check(sys != null, "the trample system runs")
	if sys != null:
		var field: TrampleField = sys.get("field")
		var here: Vector2 = g.player.pos
		gt(field.at(here).z, 0.1, "the grass under the player is pressed (%s)" % field.at(here))
		gt(field.at(here + Vector2(0.6, 0.0)).x, 0.1, "and leans away beside them")
	g.queue_free()
	await frames(1)


## What a frame of it costs the CPU with the whole window pressed, the worst
## case: a long walk leaves the path lying across all of it.
func test_a_frame_of_the_field_is_cheap() -> void:
	var f := TrampleField.new()
	f.focus(Vector2(8.0, 8.0))
	for y in 16:
		for x in 16:
			f.stamp(Vector2(float(x), float(y)), 0.75, 1.0, 1.0)
	var t0 := Time.get_ticks_usec()
	for i in 30:
		f.decay(0.016)
		f.stamp(Vector2(8.0, 8.0), 0.75, 1.0, 0.8)
		f.bytes()
	var ms := (Time.get_ticks_usec() - t0) / 30000.0
	print("trample field frame: %.3f ms" % ms)
	lt(ms, 4.0, "a frame of the field (%.3f ms)" % ms)
