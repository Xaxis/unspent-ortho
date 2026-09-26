extends TestCase
## The ring in the sky (src/core/orbit/, src/render/orbit/, 19_orbit): where it
## is is a pure function of the clock that crosses the sky at one steady pace,
## the Earth's shadow falls on it where geometry says, the layer it is drawn in
## lands on the same pixel as the eye's own camera, and the sky lays it in the
## right order.
##
## What only a real frame can answer -- the hull is a pale mass at noon, the
## stars go out behind it at night -- is asked of the LIVE frame by
## 19_orbit (`tour_seen` &"ring_pale", &"ring_hides_stars") in
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
## when the sun is acos(R / (R + h)) under the horizon (20.4 degrees here), with
## the half-degree sun's penumbra either side, and not a degree sooner.
func test_the_eclipse_boundary_is_where_geometry_puts_it() -> void:
	var d := _def()
	var edge := Pass.eclipse_depth(d)
	near(edge, -rad_to_deg(acos(4500.0 / 4800.0)), 1e-4, "the boundary is the geometry's")
	near(edge, -20.36, 0.05, "which is about 20.4 degrees down, 300 km up")
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


## A KNOWN DIRECTION LANDS WHERE THE LAYER DREW IT: the layer is aimed at the
## ring with a square lens (OrbitLayer.aim_of / aim), and the sky finds a
## direction on it by that basis and that lens (orbit_sky's `orbit_uv`, the
## mirror of OrbitLayer.uv_of). Asked of the engine's own camera, aimed the
## same way, through `unproject_position`: the ring's centre is the middle of
## the layer, every direction the wheel can cover is on it, and each lands on
## the texel the engine drew it on.
func test_a_direction_lands_where_the_layer_drew_it() -> void:
	for centre: Vector3 in [Vector3(0.0, 300.0, 5.0), Vector3(1200.0, 260.0, -400.0), Vector3(-500.0, 900.0, 300.0)]:
		var bound := 120.0
		var a := Layer.aim_of(centre, bound)
		var b: Basis = a[0]
		var th: float = a[1]
		var fov := rad_to_deg(2.0 * atan(th))
		for n: int in [288, 768]:
			var cam := _cam(Vector2i(n, n), b, fov)
			Layer.aim(cam, b, th)
			var mid := Layer.uv_of(b, fov, 1.0, centre.normalized())
			lt(mid.distance_to(Vector2(0.5, 0.5)), 1e-4, "the ring's centre is the middle of the layer")
			var worst := 0.0
			var asked := 0
			for i in 60:
				# Directions over the whole bounding sphere, out to its edge.
				var u := centre.normalized().cross(Vector3.UP).normalized()
				var w := centre.normalized().cross(u)
				var r := sqrt(Rng.hash01(3, i)) * asin(bound / centre.length())
				var t := Rng.hash01(4, i) * TAU
				var d := (centre.normalized() * cos(r) + (u * cos(t) + w * sin(t)) * sin(r)).normalized()
				var uv := Layer.uv_of(b, fov, 1.0, d)
				check(uv.x >= 0.0, "every direction the wheel can cover is on the layer")
				if uv.x < 0.0:
					return
				asked += 1
				worst = maxf(worst, (uv * float(n)).distance_to(cam.unproject_position(d * 900.0)))
			lt(worst, 0.05, "%d texels: a direction lands %.3f texels from where the engine drew it" % [n, worst])
	var src := FileAccess.get_file_as_string("res://src/render/orbit/orbit_sky.gdshaderinc")
	check(src.contains("vec2 ndc = v.xy / (-v.z) / orbit_tan;"), "the sky projects as uv_of does")
	check(src.contains("return vec2((ndc.x - orbit_rect.x) / (orbit_rect.z - orbit_rect.x), (orbit_rect.w - ndc.y) / (orbit_rect.w - orbit_rect.y));"), "y down, as uv_of does")
	var sys := FileAccess.get_file_as_string("res://src/systems/19_orbit.gd")
	check(sys.contains("m.set_shader_parameter(&\"orbit_view\", layer.aim_basis.transposed())"), "and it is handed the layer's own aim, not the eye's")


## THE LAYER IS DRAWN ONE FRAME IN RENDER_EVERY, and read in between: aimed at
## the ring, what it holds does not change as the eye turns.
func test_the_layer_is_redrawn_only_now_and_then() -> void:
	var src := FileAccess.get_file_as_string("res://src/render/orbit/orbit_layer.gd")
	gt(float(Layer.RENDER_EVERY), 1.0, "not every frame")
	check(src.contains("viewport.render_target_update_mode = SubViewport.UPDATE_ONCE"), "drawn once when it is due")
	check(src.contains("if px_across < SINGLE_PX:\n\t\tss = 1"), "and one sample a pixel for a small ring")


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
	check(inc.contains("return vec4((ring.rgb + wake) * far_through(d, orbit_thick) * open, ring.a * open);"), "the clouds, which the dome laid first, are laid back over the ring's light and the wake's")
	check(inc.contains("wake *= 1.0 - ring.a;"), "and a shard behind the hull is hidden by it")
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


## A LAMP IS NOT A WHITE DOT AT NOON: every lamp on the ring is multiplied by how
## dark the sky it stands on is, off the seen sky's own zenith colour.
func test_the_lamps_go_out_against_a_daylit_sky() -> void:
	var noon := Color(0.29, 0.42, 0.66)
	var dusk := Color(0.16, 0.18, 0.32)
	var night := Color(0.03, 0.04, 0.09)
	near(Layer.lamp_seen(noon), 0.0, 1e-6, "noon: no lamp shows (zenith luminance %.2f)" % noon.get_luminance())
	near(Layer.lamp_seen(night), 1.0, 1e-6, "night: every lamp")
	var d := Layer.lamp_seen(dusk)
	check(d > 0.0 and d < 1.0, "dusk: some (%.2f)" % d)
	var src := FileAccess.get_file_as_string("res://src/render/orbit/orbit.gdshader")
	check(src.contains("glow *= lamp_seen;"), "and the shader spends it on every lamp")


## RINGSHINE IS CAPPED at three quarters of the moon, is nothing by day or in the
## Earth's shadow, and falls away as the wheel goes down the sky.
func test_ringshine_is_capped_and_goes_out_at_eclipse() -> void:
	var Sys: GDScript = load("res://src/systems/19_orbit.gd")
	var most: float = Sys.call(&"ringshine_energy", 1.0)
	near(most, SkyLight.MOON_NIGHT * 0.75, 1e-6, "the cap is three quarters of the moon (owner, 2026-09-24: nights stay dark)")
	near(Sys.call(&"ringshine_energy", 7.0), most, 1e-6, "and nothing can ask for more")
	var over: float = Sys.call(&"shine_of", 1.0, 1.0, 1.0, 1.0, 0.0)
	near(over, 1.0, 1e-6, "sunlit overhead at night: the whole cap")
	near(Sys.call(&"shine_of", 0.0, 1.0, 1.0, 1.0, 0.0), 0.0, 1e-6, "eclipsed: none")
	near(Sys.call(&"shine_of", 1.0, 0.0, 1.0, 1.0, 0.0), 0.0, 1e-6, "by day: none")
	lt(Sys.call(&"shine_of", 1.0, 1.0, 0.3, 0.2, 0.0), 0.15, "low and far: a little")
	lt(Sys.call(&"shine_of", 1.0, 1.0, 1.0, 1.0, 1.0), 0.25, "under a covered sky: most of it gone")


## THE TRANSIT: the wheel crossing the sun takes the sun off the land, the hole
## in its middle and the wound do not.
func test_the_wheel_shades_the_land_only_where_it_crosses_the_sun() -> void:
	var d := _def()
	var p := Pass.make_pass(d, 0, 0.0, 88.0, 30.0, 1.0)
	var pose := Pass.pose(d, 7, Pass.window_min(d) * 0.5, p)
	var b: Basis = pose.basis
	var rel: Vector3 = pose.rel
	var rim: float = d.rim_km
	var at_rim := rel + b * Vector3(cos(deg_to_rad(250.0)) * rim, 0.0, sin(deg_to_rad(250.0)) * rim)
	var at_hole := rel + b * Vector3(cos(deg_to_rad(250.0)) * 20.0, 0.0, sin(deg_to_rad(250.0)) * 20.0)
	var at_wound := rel + b * Vector3(cos(deg_to_rad(float(d.gap_at))) * rim, 0.0, sin(deg_to_rad(float(d.gap_at))) * rim)
	for pair: Array in [[at_rim, true], [at_hole, false], [at_wound, false]]:
		var sun: Vector3 = (pair[0] as Vector3).normalized()
		if sun.y <= 0.0:
			continue
		var c := Pass.sun_cover(d, pose, sun)
		if bool(pair[1]):
			gt(c, 0.9, "the sun behind the rim is covered (%.2f)" % c)
		else:
			lt(c, 0.05, "the sun seen through the wheel's middle or its wound is not (%.2f)" % c)
	check(FileAccess.get_file_as_string("res://src/render/sky_light.gd").contains("* (1.0 - orbit_shade), sun_lit)"), "and SkyLight takes it off the sun's term alone")
