extends TestCase
## The ring in the sky (src/core/orbit/, src/render/orbit/, 19_orbit): where it
## is is a pure function of the clock that crosses the sky at one steady pace,
## the Earth's shadow falls on it where geometry says, the layer it is drawn in
## lands on the same pixel as the eye's own camera, and the sky lays it in the
## right order.
##
## What only a real frame can answer -- the unlit hull is the sky's own colour
## at noon, the stars go out behind it at night -- is asked of the LIVE frame by
## 19_orbit (`tour_seen` &"ring_ghost", &"ring_hides_stars") in
## tours/orbit_sky.tour and tours/orbit_night.tour, because a headless run
## draws nothing.

const Def := preload("res://src/core/orbit/orbit_def.gd")
const Pass := preload("res://src/core/orbit/orbit_pass.gd")
const Layer := preload("res://src/render/orbit/orbit_layer.gd")
const Model := preload("res://src/models/orbit/ring_model.gd")


func _sun(el: float) -> Vector3:
	return Vector3(cos(deg_to_rad(el)), sin(deg_to_rad(el)), 0.0)


func _def() -> RefCounted:
	return Def.ring()


func test_the_same_minute_is_the_same_pose() -> void:
	var d := _def()
	var p0 := Pass.next_pass(d, 7, 5000.0)
	var m: float = float(p0.rise) + 200.0
	var a := Pass.pose(d, 7, m)
	var b := Pass.pose(d, 7, m)
	eq(a.rel, b.rel, "one minute, one place")
	eq(a.basis, b.basis, "one minute, one frame")
	check(bool(a.up), "the middle of a pass is up")
	var other := Pass.pose(d, 8, m)
	check(not bool(other.up) or (other.rel as Vector3).distance_to(a.rel) > 10.0, "another seed goes over at another time or place")


## Between one world minute and the next the ring moves by the pace and no more,
## the whole way across; and the wheel's own frame turns smoothly too.
func test_a_pass_moves_continuously() -> void:
	var d := _def()
	var p := Pass.pass_of(d, 7, 3)
	var prev := Pass.pose(d, 7, float(p.rise) + 0.5)
	var most := 0.0
	var m: float = float(p.rise) + 1.5
	while m < float(p.set) - 0.5:
		var now := Pass.pose(d, 7, m)
		check(bool(now.up), "up through its window (minute %.0f)" % m)
		most = maxf(most, rad_to_deg((prev.dir as Vector3).angle_to(now.dir)))
		var turn := rad_to_deg(((prev.basis as Basis).get_rotation_quaternion()).angle_to((now.basis as Basis).get_rotation_quaternion()))
		check(turn < 0.5, "the wheel's frame turns %.2f deg in a minute" % turn)
		if turn >= 0.5:
			return
		prev = now
		m += 1.0
	lt(most, 0.5, "no minute jumps across the sky")
	check(not bool(Pass.pose(d, 7, float(p.set) + 5.0).up), "and it has set after its window")


## Passes come round every period to the minute, and next_pass names the one
## in the sky or the next to rise.
func test_passes_come_round_every_period() -> void:
	var d := _def()
	var per: float = float(d.period_h) * 60.0
	for k in range(0, 12):
		var a := Pass.pass_of(d, 7, k)
		var b := Pass.pass_of(d, 7, k + 1)
		near(float(b.rise) - float(a.rise), per, 1e-3, "pass %d to %d" % [k, k + 1])
		check(float(a.peak_el) >= float(d.peak_least) - 1e-3 and float(a.peak_el) <= float(d.peak_most) + 1e-3, "peak %.1f in range" % float(a.peak_el))
	var p := Pass.pass_of(d, 7, 5)
	eq(int(Pass.next_pass(d, 7, float(p.rise) + 30.0).k), 5, "during a pass, that pass")
	eq(int(Pass.next_pass(d, 7, float(p.set) + 30.0).k), 6, "after it, the next")
	# Over a week the passes fall at every part of the day, not one.
	var quarters := {}
	for k in range(0, 8):
		quarters[int(fposmod(float(Pass.pass_of(d, 7, k).rise) / 60.0 + float(d.window_h) * 0.5, 24.0) / 6.0)] = true
	eq(quarters.size(), 4, "a week's passes peak in all four quarters of the day")


## ONE STEADY PACE horizon to horizon: the sky angle crossed in each world hour
## is the same all the way over, overhead or low, about sixteen degrees for a
## pass that goes over the top.
func test_a_pass_crosses_the_sky_at_a_steady_pace() -> void:
	var d := _def()
	for peak: float in [25.0, 55.0, 88.0]:
		var p := Pass.make_pass(d, 0, 0.0, peak, 30.0, 1.0)
		var w: float = Pass.window_min(d)
		var want: float = rad_to_deg(float(p.arc)) / (w / 60.0)
		var m := w * 0.05
		while m < w * 0.95 - 60.0:
			var a := Pass.pose(d, 7, m, p)
			var b := Pass.pose(d, 7, m + 60.0, p)
			var rate := rad_to_deg((a.dir as Vector3).angle_to(b.dir))
			near(rate, want, want * 0.06, "peak %.0f: %.1f deg in the hour from minute %.0f, want %.1f" % [peak, rate, m, want])
			m += 60.0
	var over := Pass.make_pass(d, 0, 0.0, 88.0, 30.0, 1.0)
	var pace: float = rad_to_deg(float(over.arc)) / float(d.window_h)
	check(pace > 14.0 and pace < 18.0, "an overhead pass crosses at %.1f deg a world hour" % pace)
	# And its peak is where it was asked for.
	var top := Pass.pose(d, 7, Pass.window_min(d) * 0.5, over)
	near(float(top.elevation), 88.0, 0.6, "the middle of the window is the peak")
	near(float(top.dist), float(d.altitude_km), 3.0, "straight up it is its altitude away")


## THE EARTH'S SHADOW is geometry: a point straight overhead goes dark exactly
## when the sun is acos(R / (R + h)) under the horizon (23.9 degrees here), with
## the half-degree sun's penumbra either side, and not a degree sooner.
func test_the_eclipse_boundary_is_where_geometry_puts_it() -> void:
	var d := _def()
	var edge := Pass.eclipse_depth(d)
	near(edge, -rad_to_deg(acos(4500.0 / 4920.0)), 1e-4, "the boundary is the geometry's")
	near(edge, -23.86, 0.05, "which is about 23.9 degrees down")
	var over := Vector3(0.0, float(d.orbit_km()), 0.0)
	near(Pass.sunlit(d, over, _sun(10.0)), 1.0, 1e-6, "day: lit")
	near(Pass.sunlit(d, over, _sun(-10.0)), 1.0, 1e-6, "an hour after dusk: still lit, over a dark land")
	gt(Pass.sunlit(d, over, _sun(edge + 0.6)), 0.95, "just short of the boundary: lit")
	lt(Pass.sunlit(d, over, _sun(edge - 0.6)), 0.05, "just past it: in the shadow")
	near(Pass.sunlit(d, over, _sun(-28.0)), 0.0, 1e-6, "midnight: eclipsed")
	# The shader asks the same question with the same numbers.
	var src := FileAccess.get_file_as_string("res://src/render/orbit/orbit.gdshader")
	check(src.contains("smoothstep(planet_km - PENUMBRA_KM, planet_km + PENUMBRA_KM, perp)"), "orbit.gdshader's sunlit is OrbitPass.sunlit")
	check(src.contains("const float PENUMBRA_KM = %.1f;" % Pass.PENUMBRA_KM), "with the same penumbra")


## A KNOWN DIRECTION LANDS ON THE SAME PIXEL in the layer and on the screen: the
## sky's `orbit_uv` (mirrored by OrbitLayer.uv_of) against the engine's own
## cameras, asked through `unproject_position` -- the eye's, over the whole
## frame, and the layer's, cut down to the ring's rectangle at one and two layer
## pixels a frame pixel.
func test_a_direction_lands_on_the_same_pixel_in_the_layer_and_the_frame() -> void:
	var basis := Basis.from_euler(Vector3(deg_to_rad(38.0), deg_to_rad(-71.0), 0.0))
	for sz: Vector2i in [Vector2i(1920, 1080), Vector2i(1440, 810)]:
		var eye := _cam(sz, basis, 62.0)
		var centre := (-basis.z * 0.9 + basis.x * 0.2 + basis.y * 0.1).normalized() * 520.0
		var r := Layer.rect_of(basis, 62.0, sz, centre, 80.0)
		gt(float(r.size.x), 50.0, "the ring's rectangle is on the glass")
		lt(float(r.size.x * r.size.y), float(sz.x * sz.y) * 0.5, "and is a small part of it")
		var ndc := Layer.ndc_rect(r, sz)
		for ss: int in [1, 2]:
			var lay := _cam(r.size * ss, basis, 62.0)
			Layer.cut(lay, basis, 62.0, sz, ndc)
			var worst := 0.0
			var asked := 0
			for i in 60:
				var d := (centre.normalized() + basis.x * (Rng.hash01(3, i) - 0.5) * 0.25
					+ basis.y * (Rng.hash01(4, i) - 0.5) * 0.25).normalized()
				var uv := Layer.uv_of(basis, 62.0, float(sz.x) / float(sz.y), d, ndc)
				if uv.x < 0.0:
					continue
				asked += 1
				# The layer's own camera puts it here...
				worst = maxf(worst, (uv * Vector2(r.size * ss)).distance_to(lay.unproject_position(d * 900.0)))
				# ...and the eye puts it on the same frame pixel.
				var frame := Vector2(r.position) + uv * Vector2(r.size)
				worst = maxf(worst, frame.distance_to(eye.unproject_position(d * 900.0)))
			gt(float(asked), 20.0, "enough directions landed inside the rectangle")
			lt(worst, 0.05, "%dx%d, %d layer px a frame px: a direction lands %.3f px apart" % [sz.x, sz.y, ss, worst])
	var src := FileAccess.get_file_as_string("res://src/render/orbit/orbit_sky.gdshaderinc")
	check(src.contains("vec2 ndc = v.xy / (-v.z) / orbit_tan;"), "the sky projects as uv_of does")
	check(src.contains("return vec2((ndc.x - orbit_rect.x) / (orbit_rect.z - orbit_rect.x), (orbit_rect.w - ndc.y) / (orbit_rect.w - orbit_rect.y));"), "into the rectangle, y down, as uv_of does")


func _cam(sz: Vector2i, basis: Basis, fov: float) -> Camera3D:
	var vp := SubViewport.new()
	vp.size = sz
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(vp)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = fov
	cam.near = 50.0
	cam.far = 6000.0
	vp.add_child(cam)
	cam.global_transform = Transform3D(basis, Vector3.ZERO)
	return cam


## THE ORDER in the dome: the ring over the air and the sun's glow, the clouds
## over the ring, and the sun, the moon and the stars taken away behind it.
func test_the_dome_lays_the_ring_in_the_right_order() -> void:
	var src := FileAccess.get_file_as_string("res://src/render/sky_dome.gdshaderinc")
	var clouds := src.find("col = mix(col, cloud, amount);")
	var hook := src.find("vec4 orbit_seen = cubemap ? vec4(0.0) : orbit_at(d);")
	var sun := src.find("col += disc_col")
	gt(float(clouds), 0.0, "the clouds are laid")
	gt(float(hook), float(clouds), "the ring comes after them in the code...")
	lt(float(hook), float(sun), "...and before the sun's disc")
	check(src.contains("up * mix(1.0, 0.2, 1.0 - clear) * (1.0 - orbit_hide);"), "the hull eclipses the sun")
	check(src.contains("smoothstep(-0.02, -0.18, dome_sun_dir.y) * (1.0 - orbit_hide);"), "and the moon and stars (both ride on `dark`)")
	var inc := FileAccess.get_file_as_string("res://src/render/orbit/orbit_sky.gdshaderinc")
	check(src.contains("col = col * (1.0 - orbit_seen.a * orbit_mass) + orbit_seen.rgb;"), "its light is ADDED over the air, which by day it does not dim")
	check(inc.contains("* open * orbit_on"), "the clouds, which the dome laid first, are laid back over the ring's light")
	check(FileAccess.get_file_as_string("res://src/render/sky_eye.gdshader").contains("#define DOME_ORBIT"), "the seen sky asks for it")
	check(not FileAccess.get_file_as_string("res://src/render/colossus/colossus.gdshader").contains("DOME_ORBIT"), "and the colossi do not")


## Inside its budget: the near body under 25k triangles, the far one a fraction
## of that, one surface each (one draw), and every bone a real transform.
func test_the_ring_is_one_draw_inside_its_budget() -> void:
	var d := _def()
	for detail: bool in [true, false]:
		var m := Model.build(d, detail, 7)
		eq(m.get_surface_count(), 1, "one surface, one draw")
		var tris := (m.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		lt(float(tris), 25000.0 if detail else 8000.0, "%s body: %d triangles" % ["near" if detail else "far", tris])
		gt(float(tris), 2000.0 if detail else 600.0, "and it is a body, not a stub")
	var rows := Model.bone_rows(d, 7, 1234.0)
	eq(rows.size(), Model.BONES * 3, "every bone has its rows")
	eq(Model.chunk_list(d, 7).size(), int(d.chunks) + 1, "the loose pieces and the snapped spoke")
	# The chunks move with the clock, and the wheel does not.
	var later := Model.bone_rows(d, 7, 1334.0)
	eq(rows[0], later[0], "bone 0 is the wheel itself")
	check(rows[3] != later[3], "a loose piece turns")


## The layer only renders what the sky can show: a pass that is down, or a view
## turned away from it, costs nothing.
func test_the_layer_stands_down_when_nothing_can_be_seen() -> void:
	var src := FileAccess.get_file_as_string("res://src/render/orbit/orbit_layer.gd")
	check(src.contains("SubViewport.UPDATE_DISABLED"), "the layer can stand down")
	var sys := FileAccess.get_file_as_string("res://src/systems/19_orbit.gd")
	check(sys.contains("open and float(air.share) > 0.0"), "only while the horizon is in frame and the sky is open")
	check(sys.contains("m.set_shader_parameter(&\"orbit_on\", 1.0 if on else 0.0)"), "and the sky is told not to read a stale frame")
