extends TestCase
## The walking megastructures (src/core/colossus/, src/render/colossus/): the
## gait is a pure function of the world clock, and the space they are drawn in
## keeps every angle and every depth order out past what the far plane holds.

const Def := preload("res://src/core/colossus/colossus_def.gd")
const Route := preload("res://src/core/colossus/colossus_route.gd")
const Walk := preload("res://src/core/colossus/colossus_walk.gd")
const View := preload("res://src/render/colossus/colossus_view.gd")
const Model := preload("res://src/models/colossus_model.gd")

const SIZE := 1300


func _walkers() -> Array:
	return Def.walkers(SIZE)


func _route(d: RefCounted, seed_value := 7) -> RefCounted:
	return Route.make(d, seed_value, SIZE)


func test_the_same_minute_is_the_same_pose() -> void:
	for d: RefCounted in _walkers():
		var a: Dictionary = Walk.pose(d, _route(d), 12345.6)
		var b: Dictionary = Walk.pose(d, _route(d), 12345.6)
		eq(a.hub, b.hub, "%s: one minute, one hub" % d.id)
		for k in 3:
			eq(a.feet[k], b.feet[k], "%s: one minute, one foot %d" % [d.id, k])
			eq(a.knees[k], b.knees[k], "%s: one minute, one knee %d" % [d.id, k])
	var d0: RefCounted = _walkers()[0]
	var other: Dictionary = Walk.pose(d0, _route(d0, 8), 12345.6)
	var here: Dictionary = Walk.pose(d0, _route(d0, 7), 12345.6)
	check(other.hub.origin.distance_to(here.hub.origin) > 1000.0, "another seed walks another route")


## A planted foot does not slide: between two swings it is exactly where it
## landed, to the millimetre, however far the hub has gone meanwhile.
func test_a_planted_foot_stays_where_it_landed() -> void:
	for d: RefCounted in _walkers():
		var r := _route(d)
		var planted_seen := 0
		for k in 3:
			# The middle of leg k's rest in cycle 3.
			var cyc: float = d.cycle_minutes
			var rest_from: float = (3.0 + k / 3.0 + d.swing_share()) * cyc - r.offset
			var rest_to: float = (4.0 + k / 3.0) * cyc - r.offset
			var a: Vector3 = Walk.pose(d, r, rest_from + 1.0).feet[k]
			var b: Vector3 = Walk.pose(d, r, rest_to - 1.0).feet[k]
			near(a.distance_to(b), 0.0, 1e-3, "%s: foot %d still while planted" % [d.id, k])
			check(Walk.pose(d, r, lerpf(rest_from, rest_to, 0.5)).swinging != k, "and it is not the leg in the air")
			planted_seen += 1
		eq(planted_seen, 3, "every leg was asked")


## Never more than one foot off the ground: a tripod on two legs falls over.
func test_one_leg_swings_at_a_time() -> void:
	for d: RefCounted in _walkers():
		var r := _route(d)
		var lap: float = r.lap_minutes()
		var t := 0.0
		while t < lap:
			var p: Dictionary = Walk.pose(d, r, t)
			var up := 0
			for k in 3:
				if p.feet[k].y > 1.0:
					up += 1
			check(up <= 1, "%s: %d feet up at minute %.0f" % [d.id, up, t])
			if up > 1:
				return
			t += 7.0


## The hub never jumps: a world minute moves it by a walk, not a teleport, and
## so do the knees.
func test_the_hub_and_knees_move_continuously() -> void:
	for d: RefCounted in _walkers():
		var r := _route(d)
		var lap: float = r.lap_minutes()
		var prev: Dictionary = Walk.pose(d, r, 0.0)
		var worst := 0.0
		var worst_knee := 0.0
		var t := 0.5
		while t < lap:
			var p: Dictionary = Walk.pose(d, r, t)
			worst = maxf(worst, p.hub.origin.distance_to(prev.hub.origin))
			for k in 3:
				worst_knee = maxf(worst_knee, p.knees[k].distance_to(prev.knees[k]))
			prev = p
			t += 0.5
		# A 40 km stride over a 150-minute swing is ~270 m a minute at the foot;
		# the hub takes a third of it.
		lt(worst, 400.0, "%s: the hub moves under 400 m in half a world minute (worst %.0f)" % [d.id, worst])
		lt(worst_knee, 1500.0, "%s: a knee moves under 1.5 km in half a world minute (worst %.0f)" % [d.id, worst_knee])


## The whole walk is a lap: minute t and minute t + lap are one picture.
func test_the_lap_comes_round() -> void:
	for d: RefCounted in _walkers():
		var r := _route(d)
		var lap: float = r.lap_minutes()
		gt(lap, 60.0 * 24.0, "%s: a lap takes more than a day (%.1f days)" % [d.id, lap / 1440.0])
		# The ring really closes: the plants a lap on are the plants it began on,
		# and the last half-minute of a lap walks into the first without a jump.
		for k in 3:
			near(Walk.plant(d, r, k, 2).distance_to(Walk.plant(d, r, k, 2 + r.cycles())), 0.0, 1.0, "%s: plant %d comes round" % [d.id, k])
		lt(Walk.pose(d, r, lap - 0.5).hub.origin.distance_to(Walk.pose(d, r, 0.0).hub.origin), 400.0, "%s: no jump where the lap closes" % d.id)
		for t: float in [0.0, 333.3, 2000.0]:
			var a: Dictionary = Walk.pose(d, r, t)
			var b: Dictionary = Walk.pose(d, r, t + lap)
			near(a.hub.origin.distance_to(b.hub.origin), 0.0, 1.0, "%s: the hub comes round" % d.id)
			for k in 3:
				near(a.feet[k].distance_to(b.feet[k]), 0.0, 1.0, "%s: foot %d comes round" % [d.id, k])


## The legs are rigid: a thigh and a shin are the same length at every minute,
## and the knee is where two rigid bones meet.
func test_the_legs_do_not_stretch() -> void:
	for d: RefCounted in _walkers():
		var r := _route(d)
		for t: float in [0.0, 100.0, 777.0, 5000.0]:
			var p: Dictionary = Walk.pose(d, r, t)
			for k in 3:
				near(p.hips[k].distance_to(p.knees[k]), d.thigh, 1.0, "%s: thigh %d is its own length" % [d.id, k])
				near(p.knees[k].distance_to(p.ankles[k]), d.shin, 1.0, "%s: shin %d is its own length" % [d.id, k])


## Left to its gait, no walk sets a foot on the island: a foot on the land wants
## a tread the land was made with (test_colossus_treads.gd holds those), so a
## route handed none lands every plant in the sea.
func test_no_foot_comes_down_on_the_island() -> void:
	var c := Vector2(SIZE * 0.5, SIZE * 0.5)
	for d: RefCounted in _walkers():
		var r := _route(d)
		var lap: float = r.lap_minutes()
		var nearest := INF
		var t := 0.0
		while t < lap:
			var p: Dictionary = Walk.pose(d, r, t)
			for k in 3:
				var f: Vector3 = p.feet[k]
				nearest = minf(nearest, Vector2(f.x, f.z).distance_to(c))
			t += 11.0
		gt(nearest, SIZE * 2.0, "%s: every foot keeps off the island (nearest %.0f)" % [d.id, nearest])


## The circuits the owner is shown: one on the skyline, one looming, one the
## land passes between the legs of.
func test_the_circuits_hold_their_distances() -> void:
	var c := Vector3(SIZE * 0.5, 0.0, SIZE * 0.5)
	var seen := {}
	for d: RefCounted in _walkers():
		var r := _route(d)
		var lap: float = r.lap_minutes()
		var lo := INF
		var hi := 0.0
		var t := 0.0
		while t < lap:
			var o: Vector3 = Walk.pose(d, r, t).hub.origin
			var flat := Vector2(o.x - c.x, o.z - c.z).length()
			lo = minf(lo, flat)
			hi = maxf(hi, flat)
			t += 30.0
		seen[d.circuit] = true
		match d.circuit:
			&"A":
				gt(lo, 110000.0, "A stays out on the skyline")
				lt(hi, 260000.0, "and not past it")
			&"B":
				gt(lo, 25000.0, "B keeps its distance")
				lt(hi, 90000.0, "and looms")
			&"C":
				lt(lo, 3000.0, "C's hub passes over the island")
	check(seen.has(&"A") and seen.has(&"B") and seen.has(&"C"), "all three circuits are walked")
	eq(Def.walkers(400).size(), 1, "a small world gets one, far out")
	eq((Def.walkers(400)[0] as RefCounted).circuit, &"A", "and it is the far one")


## THE SPACE THEY ARE DRAWN IN. A vertex further than the far plane holds is
## moved along its own ray, so its angle (where it is on the glass) is exact,
## depth order is kept, and nothing reaches the far plane out to 400 km.
func test_compressed_space_keeps_angles_and_order_inside_the_far_plane() -> void:
	var near_p := 0.12
	for far_p: float in [1035.0, 1400.0]:
		var prev := -INF
		var dir := Vector3(0.3, 0.2, -1.0).normalized()
		for dist: float in [10.0, 500.0, 0.8 * far_p, 0.83 * far_p, 2000.0, 5000.0, 30000.0, 150000.0, 250000.0, 400000.0]:
			var v := dir * dist
			var c: Vector3 = View.compress(v, near_p, far_p, false)
			near(c.normalized().angle_to(dir), 0.0, 1e-5, "the ray is kept at %.0f" % dist)
			gt(c.length(), prev, "order is kept at %.0f" % dist)
			lt(c.length(), far_p * 0.996, "inside the far plane at %.0f (far %.0f)" % [dist, far_p])
			if dist < 0.8 * far_p:
				near(c.length(), dist, 1e-3, "nearer than the knee nothing moves")
			prev = c.length()
		# Resolvable where it matters: a kilometre apart at 150 km stays apart.
		var a: Vector3 = View.compress(dir * 150000.0, near_p, far_p, false)
		var b: Vector3 = View.compress(dir * 151000.0, near_p, far_p, false)
		gt(b.length() - a.length(), 1e-3, "1 km at 150 km is still a depth step")


func test_compressed_space_under_an_orthographic_camera_keeps_the_glass() -> void:
	var prev := -INF
	for dist: float in [10.0, 300.0, 900.0, 5000.0, 400000.0]:
		var v := Vector3(12.0, -3.0, -dist)
		var c: Vector3 = View.compress(v, 1.0, 500.0, true)
		near(c.x, v.x, 1e-4, "the glass x is kept")
		near(c.y, v.y, 1e-4, "the glass y is kept")
		gt(-c.z, prev, "depth order is kept")
		lt(-c.z, 500.0 - 1.0, "and it stays in front of the far plane")
		prev = -c.z


## The shader and the mirror above are one rule, so the shader carries the same
## knee and ceiling the mirror is tested with.
func test_the_shader_spends_the_same_rule() -> void:
	var src := FileAccess.get_file_as_string("res://src/render/colossus/colossus.gdshader")
	check(src.contains("skip_vertex_transform"), "the shader places its own vertices")
	var mode := src.substr(src.find("render_mode"), 120)
	mode = mode.substr(0, mode.find(";"))
	check(not mode.contains("fog_disabled"), "fog_disabled compiles FOG out: the air would never be laid on")
	check(mode.contains("shadows_disabled"), "a compressed vertex cannot read the shadow map")
	check(src.contains("shadows_disabled"), "a compressed vertex cannot read the shadow map")
	check(src.contains("comp_l"), "the log's scale comes from the view, not a second constant")
	check(src.contains("FOG ="), "the air is laid on after the light, as the land's is")
	check(src.contains("matter_albedo("), "and the colour goes through the one door")
	check(not src.contains("void light()"), "no light()")


## The far model: one draw, tapered and jointed, inside its triangle budget, and
## every vertex carries the bone it rides on.
func test_the_far_model_is_one_draw_inside_its_budget() -> void:
	var d: RefCounted = _walkers()[0]
	var m: ArrayMesh = Model.build(d)
	eq(m.get_surface_count(), 1, "one surface, one draw")
	var arrays := m.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_INDEX] == null, "flat faces, unindexed")
	var tris := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	lt(float(tris), 6000.0, "L2 stays under 6k triangles (%d)" % tris)
	gt(float(tris), 800.0, "and is more than a few boxes (%d)" % tris)
	var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var bones := {}
	for i in range(0, custom.size(), 4):
		bones[int(custom[i])] = true
	eq(bones.size(), Model.BONES, "every bone carries geometry")
	# L1, the near body, carries the machinery and stays well inside its budget.
	var near_body: ArrayMesh = Model.build(d, true)
	eq(near_body.get_surface_count(), 1, "L1 is one draw too")
	var near_tris := (near_body.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	gt(float(near_tris), float(tris) * 1.3, "L1 carries more than L2 (%d over %d)" % [near_tris, tris])
	lt(float(near_tris), 20000.0, "and stays under 20k triangles (%d)" % near_tris)
	var lens := 0
	for c: Color in arrays[Mesh.ARRAY_COLOR] as PackedColorArray:
		if c.a < 0.98:
			lens += 1
	gt(float(lens), 0.0, "the amber lens is marked for light")


## THE CULLING IS ON ANGLES, because the engine cannot see where a compressed
## vertex is, and it must never cut a walker that is on the glass: every part
## of the body that projects into the frame, at every yaw and every pitch the
## shoulder can take, belongs to a walker the view says to draw.
func test_nothing_on_the_glass_is_ever_culled() -> void:
	var eye := Vector3(SIZE * 0.5, 2.0, SIZE * 0.5)
	var fov := 60.0
	var aspect := 16.0 / 9.0
	var tan_v := tan(deg_to_rad(fov) * 0.5)
	var tan_h := tan_v * aspect
	var in_frame := 0
	var culled := 0
	for d: RefCounted in _walkers():
		var r := _route(d)
		for t: float in [700.0, 1300.0, 4000.0]:
			var p: Dictionary = Walk.pose(d, r, t)
			var pts: Array[Vector3] = [p.hub.origin, p.hub.origin + Vector3(0.0, d.spire_top - d.hip_height, 0.0)]
			for k in 3:
				for s: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
					pts.append(p.hips[k].lerp(p.knees[k], s))
					pts.append(p.knees[k].lerp(p.ankles[k], s))
			for yaw_i in 72:
				for pitch: float in [-14.0, 0.0, 10.0, 25.0, 42.0]:
					var b := Basis.from_euler(Vector3(deg_to_rad(-pitch), deg_to_rad(yaw_i * 5.0), 0.0))
					var fwd := -b.z
					var seen := false
					for q: Vector3 in pts:
						var v := b.inverse() * (q - eye)
						if -v.z > 1.0 and absf(v.x / -v.z) < tan_h and absf(v.y / -v.z) < tan_v:
							seen = true
							break
					if not seen:
						continue
					in_frame += 1
					if not View.in_view(eye, fwd, fov, aspect, p.hub.origin):
						culled += 1
	gt(float(in_frame), 100.0, "the sweep saw walkers on the glass (%d views)" % in_frame)
	eq(culled, 0, "and never culled one that was on it")


## THE STEPS A PLAYER FEELS are found by asking two minutes the same question:
## every landing between them, once, at the minute and place the pose puts it,
## and nothing at all across a skip (a night slept is not forty footfalls).
func test_every_landing_is_one_step_event() -> void:
	for d: RefCounted in _walkers():
		var r := _route(d)
		var events: Array = []
		var t := 0.0
		while t < 3.0 * float(d.cycle_minutes):
			events.append_array(Walk.steps_between(d, r, t, t + 0.25))
			t += 0.25
		eq(events.size(), 9, "%s: three cycles, three legs, nine landings" % d.id)
		for e: Dictionary in events:
			var m: float = e.minute
			var before: Dictionary = Walk.pose(d, r, m - 0.5)
			var after: Dictionary = Walk.pose(d, r, m + 0.5)
			var k: int = e.leg
			gt(before.feet[k].y, 0.0, "%s: leg %d was still in the air just before" % [d.id, k])
			near(after.feet[k].y, 0.0, 1e-3, "and is down just after")
			near(after.feet[k].distance_to(e.at), 0.0, 1.0, "where the event says it landed")
		eq(Walk.steps_between(d, r, 0.0, 600.0).size(), 0, "a skip of ten world hours fires nothing")
		eq(Walk.steps_between(d, r, 5.0, 5.0).size(), 0, "no time, no step")


## What a footfall does to the person hearing it, by how far off it came down:
## the ground carries it first and the air much later, and it fades to nothing
## a long way out rather than at the edge of the frame.
func test_a_step_is_felt_before_it_is_heard_and_fades_with_distance() -> void:
	near(Walk.felt(1000.0).x, 0.35, 0.02, "a foot at a kilometre shakes the picture a third of a unit")
	eq(Walk.felt(160000.0).x, 0.0, "past 150 km nothing shakes")
	var last := INF
	for d: float in [1000.0, 5000.0, 30000.0, 60000.0, 120000.0]:
		var f: Vector2 = Walk.felt(d)
		lt(f.x, last + 1e-6, "weaker further off (%.0f)" % d)
		gt(f.y, 1.5, "and still a long slow roll (%.0f)" % d)
		last = f.x
	near(Walk.ground_delay(30000.0), 10.0, 1e-3, "the ground carries it at 3 km/s")
	near(Walk.air_delay(34300.0), 100.0, 1e-3, "the air at 343 m/s")
	gt(Walk.felt(60000.0).x, 0.05, "the looming one is felt")


## A landing is heard, and the walkers are always heard: every name the system
## emits is a sound on the sheet, the landing carries past the edge of the world
## and fades with it, and the drone follows what the system says its hum is.
func test_what_a_colossus_sounds_like_is_on_the_sheet() -> void:
	for n: StringName in [&"colossus_step", &"colossus_boom", &"bed_colossus"]:
		check(SoundBank.has_sound(SoundNames.resolve(n)), "%s is a sound" % n)
	gt(SoundMix.colossus_gain(2000.0), SoundMix.colossus_gain(60000.0), "a near landing is louder")
	gt(SoundMix.colossus_gain(250000.0), 0.0, "and one on the skyline is still heard")
	var w := WorldData.new(3, 64)
	var calm := {"kind": &"fair", "strength": 0.0}
	var quiet: Dictionary = SoundMix.bed_levels(w, Vector2(32, 32), calm, {}, {}, 0.0, {"colossi": 0.0})
	var loud: Dictionary = SoundMix.bed_levels(w, Vector2(32, 32), calm, {}, {}, 0.0, {"colossi": 0.9})
	near(float(quiet.get(&"bed_colossus", 0.0)), 0.0, 1e-6, "no walkers, no drone")
	gt(float(loud.get(&"bed_colossus", 0.0)), 0.8, "a walker overhead fills the air")


## THE GAZE: while a colossus is in front of the view it may tip up far enough to
## take the machine in, and when it is not the view comes home without a jump.
func test_the_gaze_lets_the_view_tip_up_and_eases_it_home() -> void:
	const Shoulder := preload("res://src/core/view/shoulder.gd")
	near(Shoulder.least_for(0.0), Shoulder.PITCH_LEAST, 1e-4, "no walker, the usual limit")
	near(Shoulder.least_for(1.0), Shoulder.GAZE_LEAST, 1e-4, "a walker ahead, the gaze's")
	lt(Shoulder.GAZE_LEAST, -40.0, "far enough to see a hub 45 degrees up")
	var up := Shoulder.look(0.0, Shoulder.PITCH, Vector2(0.0, -5000.0), Shoulder.least_for(1.0))
	near(up.y, Shoulder.GAZE_LEAST, 1e-4, "the mouse takes it all the way up")
	var held := Shoulder.look(0.0, -40.0, Vector2(0.0, -100.0), Shoulder.PITCH_LEAST)
	near(held.y, -40.0, 1e-4, "once the gaze lets go the mouse cannot take it further")
	var p := -45.0
	var worst := 0.0
	var frames := 0
	while p < Shoulder.PITCH_LEAST - 1e-4 and frames < 2000:
		var q := Shoulder.settle(p, Shoulder.PITCH_LEAST, 1.0 / 60.0)
		worst = maxf(worst, q - p)
		p = q
		frames += 1
	near(p, Shoulder.PITCH_LEAST, 1e-3, "it comes home")
	lt(worst, 0.5, "never more than half a degree a frame (%.2f)" % worst)
	gt(float(frames) / 60.0, 1.0, "over more than a second (%.1f s)" % (float(frames) / 60.0))


## A LEG'S SHADOW ON THE LAND: the capsules handed to the shaders are the ones
## whose shadow really crosses the ground round the player, and none else --
## the common frame hands over nothing and the land pays nothing for it.
func test_only_a_leg_between_the_player_and_the_sun_is_handed_over() -> void:
	var d: RefCounted = _walkers()[1]
	var p: Dictionary = Walk.pose(d, _route(d), 900.0)
	var sun := Vector3(0.3, 0.35, -0.5).normalized()
	# The ground under the middle of leg 0's shin, looking back up the sun.
	var mid: Vector3 = (p.knees[0] + p.ankles[0]) * 0.5
	var under := mid - sun * (mid.y / sun.y)
	under.y = 0.0
	var kept: Array = Walk.shadow_capsules(d, p, sun, under, 1500.0)
	gt(float(kept.size()), 0.0, "the shin's shadow falls where the player stands")
	lt(float(kept.size()), 9.0, "and never more than eight capsules")
	var far_off := under + Vector3(-sun.z, 0.0, sun.x).normalized() * 60000.0
	eq(Walk.shadow_capsules(d, p, sun, far_off, 1500.0).size(), 0, "sixty kilometres to the side, nothing")
	eq(Walk.shadow_capsules(d, p, Vector3(0.3, -0.2, 0.9).normalized(), under, 1500.0).size(), 0, "a sun under the horizon casts nothing")
	# And the capsule really stands on the line from there to the sun.
	var c: Array = kept[0]
	var a: Vector3 = c[0]
	var b: Vector3 = c[1]
	var ab := b - a
	var best := INF
	for i in 201:
		var q := a + ab * (float(i) / 200.0)
		var t := maxf(0.0, (q - under).dot(sun))
		best = minf(best, (under + sun * t).distance_to(q))
	lt(best, float(c[2]) + 1500.0, "the ray to the sun passes through it (%.0f m off, radius %.0f)" % [best, c[2]])


## A LEG'S SHADOW TAPERS AS THE LEG DOES: a shin is eight hundred metres at the
## knee and a hundred and ten at the ankle, and its shadow near the foot is a
## narrow hard band only if the capsule carries both radii.
func test_a_shadow_capsule_tapers_like_its_leg() -> void:
	var d: RefCounted = _walkers()[1]
	var p: Dictionary = Walk.pose(d, _route(d), 900.0)
	var sun := Vector3(0.3, 0.35, -0.5).normalized()
	var ankle: Vector3 = p.ankles[0]
	var under := ankle - sun * (ankle.y / sun.y)
	under.y = 0.0
	var shin: Array = []
	for c: Array in Walk.shadow_capsules(d, p, sun, under, 1500.0):
		if (c[1] as Vector3).is_equal_approx(ankle):
			shin = c
	eq(shin.size(), 4, "the shin is handed over with a radius at each end")
	if shin.size() == 4:
		near(float(shin[2]), float((d.shin_r as Vector2).x), 1e-3, "the knee end is the shin's own root")
		near(float(shin[3]), float((d.shin_r as Vector2).y), 1e-3, "and the ankle end its tip")


## THE NEAR BODY COMES IN ON A STIPPLE, NEVER A POP: across the band round
## NEAR_LOD both bodies are drawn, each told its share of the pixels, and the
## share runs continuously from all-far to all-near.
func test_the_near_body_is_handed_over_on_a_stipple() -> void:
	near(View.near_share(View.NEAR_LOD + View.LOD_BAND + 1.0), 0.0, 1e-6, "past the band, the far body only")
	near(View.near_share(View.NEAR_LOD - View.LOD_BAND - 1.0), 1.0, 1e-6, "inside it, the near body only")
	var worst := 0.0
	var last := View.near_share(View.NEAR_LOD + View.LOD_BAND * 1.2)
	var d := View.NEAR_LOD + View.LOD_BAND * 1.2
	while d > View.NEAR_LOD - View.LOD_BAND * 1.2:
		d -= 100.0
		var s := View.near_share(d)
		worst = maxf(worst, absf(s - last))
		last = s
	lt(worst, 0.02, "no hundred metres of approach moves it more than 2%% (%.3f)" % worst)
	var view: Node3D = View.new()
	tree.root.add_child(view)
	var d0: RefCounted = _walkers()[0]
	view.setup([d0], 7, SIZE)
	eq(view.get_child_count(), 2, "one instance for each body")
	var hub: Vector3 = (Walk.pose(d0, view.routes[0], 0.0).hub as Transform3D).origin
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.far = 1400.0
	# The switch is on the straight-line distance to the hub, fifty-five km up.
	cam.position = Vector3(hub.x - sqrt(View.NEAR_LOD * View.NEAR_LOD - hub.y * hub.y), 2.0, hub.z)
	cam.look_at(Vector3(hub.x, 40000.0, hub.z))
	view.update(cam, 0.0, {}, true)
	var shown := 0
	for c: Node in view.get_children():
		if (c as MeshInstance3D).visible:
			shown += 1
		var mat := (c as MeshInstance3D).material_override as ShaderMaterial
		var cut: float = mat.get_shader_parameter("lod_cut") if mat.get_shader_parameter("lod_cut") != null else -1.0
		gt(cut, 0.3, "%s is told its share (%.2f)" % [c.name, cut])
		lt(cut, 0.7, "%s: the middle of the band is half and half" % c.name)
	eq(shown, 2, "in the middle of the band both bodies are drawn")
	cam.position = Vector3(hub.x - View.NEAR_LOD * 1.5, 2.0, hub.z)
	view.update(cam, 0.0, {}, true)
	shown = 0
	for c: Node in view.get_children():
		shown += 1 if (c as MeshInstance3D).visible else 0
	eq(shown, 1, "far off, one")
	cam.free()
	view.free()
