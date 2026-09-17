extends TestCase
## Tracks (TrackGround, TrackPath, TrackMarks): what a ground keeps and for how
## long, where the feet come down, and that every mark is a hollow with a rim.


func _walk(path: TrackPath, from: Vector2, dir: Vector2, tiles: float, s: Dictionary, frame: float = 0.05) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at := from
	var gone := 0.0
	path.feed(at, s)
	while gone < tiles:
		at += dir * frame
		gone += frame
		out.append_array(path.feed(at, s))
	return out


func test_every_ground_is_decided_and_the_hard_ones_keep_nothing() -> void:
	for g in Ground.NAMES.size():
		var row := TrackGround.of(g)
		if row.is_empty():
			continue
		check(row.mark in [TrackGround.PRINT, TrackGround.SCUFF, TrackGround.FLATTEN], "%s keeps a known mark" % Ground.NAMES[g])
		gt(float(row.lasts), 0.0, "%s lasts a while" % Ground.NAMES[g])
		check(float(row.depth) > 0.0 and float(row.depth) <= 1.0, "%s reads" % Ground.NAMES[g])
	for g: int in [Ground.ROCK, Ground.ROAD, Ground.FLOOR, Ground.GRAVEL, Ground.SCREE, Ground.LIMESTONE,
			Ground.CLINKER, Ground.ICE, Ground.WATER, Ground.DEEP_WATER, Ground.RIVER, Ground.BLACKWATER]:
		check(TrackGround.of(g).is_empty(), "%s keeps no mark" % Ground.NAMES[g])
	eq(TrackGround.of(Ground.SNOW).mark, TrackGround.PRINT)
	eq(TrackGround.of(Ground.SHINGLE).mark, TrackGround.SCUFF)
	eq(TrackGround.of(Ground.GRASS).mark, TrackGround.FLATTEN)
	gt(float(TrackGround.of(Ground.MUD).lasts), float(TrackGround.of(Ground.SAND).lasts), "mud holds a print longer than sand")
	gt(float(TrackGround.of(Ground.SAND).lasts), float(TrackGround.of(Ground.GRASS).lasts), "and sand longer than grass springs back")


func test_the_weather_that_fills_a_mark_fills_it_faster() -> void:
	var snow := TrackGround.of(Ground.SNOW)
	var still := TrackGround.wear(snow, 60.0, {"kind": &"clear", "strength": 0.0})
	var falling := TrackGround.wear(snow, 60.0, {"kind": &"snow", "strength": 1.0})
	var whiteout := TrackGround.wear(snow, 60.0, {"kind": &"whiteout", "strength": 1.0})
	gt(falling, still * 4.0, "snowfall fills prints in snow")
	near(whiteout, falling, 1e-6, "a whiteout is a blizzard's family and fills them as fast")
	near(TrackGround.wear(snow, 60.0, {"kind": &"rain", "strength": 1.0}), still, 1e-6, "rain does not fill a print in snow")
	lt(TrackGround.wear(TrackGround.of(Ground.MUD), 60.0, {"kind": &"clear", "strength": 0.0}), 0.2, "an hour on a still day leaves a mud print")


func test_feet_come_down_a_step_apart_left_and_right() -> void:
	var path := TrackPath.new()
	var s := {"kind": TrackPath.SHAPE_FOOT, "step": 0.6, "gauge": 0.2}
	var marks := _walk(path, Vector2(10, 10), Vector2.RIGHT, 6.0, s)
	gt(float(marks.size()), 8.0, "about one a step")
	lt(float(marks.size()), 12.0)
	for i in range(1, marks.size()):
		near(marks[i].at.x - marks[i - 1].at.x, 0.6, 0.06, "a step apart")
		eq(marks[i].side, -int(marks[i - 1].side), "left and right in turn")
		near(absf(marks[i].at.y - 10.0), 0.1, 1e-4, "half the gauge off the line walked")
		near(marks[i].angle, 0.0, 1e-4, "pointing the way walked")
	# Heading east, the left foot is on the north side (tile y smaller).
	for m: Dictionary in marks:
		if m.side == -1:
			lt(m.at.y, 10.0, "the left foot is on the left")


func test_a_longer_step_leaves_fewer_prints() -> void:
	var walk := _walk(TrackPath.new(), Vector2.ZERO, Vector2.RIGHT, 12.0, {"kind": TrackPath.SHAPE_FOOT, "step": 0.6}).size()
	var run := _walk(TrackPath.new(), Vector2.ZERO, Vector2.RIGHT, 12.0, {"kind": TrackPath.SHAPE_FOOT, "step": 0.9}).size()
	lt(float(run), float(walk), "a run leaves fewer, further apart")


func test_nothing_in_the_water_or_the_air_and_both_feet_on_landing() -> void:
	var path := TrackPath.new()
	var swim := _walk(path, Vector2.ZERO, Vector2.RIGHT, 5.0, {"kind": TrackPath.SHAPE_FOOT, "step": 0.6, "swimming": true})
	eq(swim.size(), 0, "a swimmer leaves no prints")
	var air := {"kind": TrackPath.SHAPE_FOOT, "step": 0.6, "airborne": true}
	eq(_walk(path, Vector2(5, 0), Vector2.RIGHT, 2.0, air).size(), 0, "nothing while in the air")
	var landed := path.feed(Vector2(7.05, 0), {"kind": TrackPath.SHAPE_FOOT, "step": 0.6})
	eq(landed.size(), 2, "both feet come down together")
	eq(landed[0].side + landed[1].side, 0, "one of each")


func test_a_dodge_scuffs_and_a_teleport_is_not_a_walk() -> void:
	var path := TrackPath.new()
	var s := {"kind": TrackPath.SHAPE_FOOT, "step": 5.0}
	path.feed(Vector2.ZERO, s)
	path.feed(Vector2(0.1, 0), s)
	var dodge := path.feed(Vector2(0.2, 0), {"kind": TrackPath.SHAPE_FOOT, "step": 5.0, "dodging": true, "dodge_dir": Vector2.DOWN})
	eq(dodge.size(), 1, "a dodge drags one scuff")
	eq(dodge[0].shape, TrackPath.SHAPE_SCUFF)
	near(dodge[0].angle, Vector2.DOWN.angle(), 1e-4, "along the dodge")
	eq(path.feed(Vector2(40, 40), s).size(), 0, "a crossing is no trail")


func test_a_rig_strides_wide_and_a_sled_sweeps_and_a_raft_leaves_nothing() -> void:
	var rig := _walk(TrackPath.new(), Vector2.ZERO, Vector2.RIGHT, 8.0, {"kind": TrackPath.SHAPE_RIG, "step": 1.35, "gauge": 0.6})
	check(rig.size() >= 5 and rig.size() <= 6, "a rig foot every long stride: %d" % rig.size())
	eq(rig[0].shape, TrackPath.SHAPE_RIG)
	near(absf(rig[0].at.y), 0.3, 1e-4, "set wide")
	var sled := _walk(TrackPath.new(), Vector2.ZERO, Vector2.RIGHT, 4.0, {"kind": TrackPath.SHAPE_SWEEP, "step": 0.4})
	gt(float(sled.size()), 8.0, "a sled brushes a band as it goes")
	eq(sled[0].side, 0, "down its middle")
	eq(_walk(TrackPath.new(), Vector2.ZERO, Vector2.RIGHT, 6.0, {"kind": &"", "step": 0.4}).size(), 0, "a raft leaves nothing")


func test_every_mark_is_a_hollow_with_a_rim_and_nothing_at_its_edges() -> void:
	for shape: StringName in TrackMarks.PIXELS:
		var px: Vector2i = TrackMarks.PIXELS[shape]
		var h := TrackMarks.height_field(shape, px)
		var lo := 0.0
		var hi := 0.0
		for v in h:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		lt(lo, -0.3, "%s is pressed in" % shape)
		check(hi <= 1.0 and lo >= -1.0, "%s stays in range" % shape)
		var edge := 0.0
		for x in px.x:
			edge = maxf(edge, absf(h[x]))
			edge = maxf(edge, absf(h[(px.y - 1) * px.x + x]))
		for y in px.y:
			edge = maxf(edge, absf(h[y * px.x]))
			edge = maxf(edge, absf(h[y * px.x + px.x - 1]))
		lt(edge, 0.12, "%s fades out before its edges (no square shows)" % shape)
		var tex: Array = TrackMarks.textures(shape)
		check(tex[0] is ImageTexture and tex[1] is ImageTexture, "%s has a mask and a normal map" % shape)
	gt(float(TrackMarks.SIZE[&"rig"].x), float(TrackMarks.SIZE[&"foot"].x) * 3.0, "a machine foot is far bigger than a boot")
