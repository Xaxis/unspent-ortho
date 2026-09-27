extends TestCase
## A fight is never hidden by a tree: the player and the bodies about them keep
## a clearing in the crowns (18_crowns + world.gdshader `crown_clear`).

const Crowns := preload("res://src/systems/18_crowns.gd")


func _slots() -> PackedVector4Array:
	var s := PackedVector4Array()
	s.resize(Crowns.SLOTS)
	return s


func test_the_player_always_keeps_their_own_clearing() -> void:
	var s := _slots()
	var mobs: Array[Vector2] = []
	for i in 20:
		mobs.append(Vector2(i, i))
	Crowns.fill(s, Vector2(10, 4), mobs, func(_p: Vector2) -> float: return 1.5)
	near(s[0].x, 10.0, 0.001, "slot 0 x")
	near(s[0].z, 4.0, 0.001, "slot 0 z")
	near(s[0].y, 1.5, 0.001, "slot 0 takes the ground under it")
	gt(s[0].w, 1.0, "slot 0 has a reach")
	for i in range(1, Crowns.SLOTS):
		gt(s[i].w, 0.0, "a crowd fills every other slot")


func test_unused_slots_are_blanked_so_an_old_clearing_never_sticks() -> void:
	var s := _slots()
	var many: Array[Vector2] = [Vector2(1, 1), Vector2(2, 2), Vector2(3, 3), Vector2(4, 4), Vector2(5, 5)]
	Crowns.fill(s, Vector2.ZERO, many, func(_p: Vector2) -> float: return 0.0)
	var none: Array[Vector2] = []
	Crowns.fill(s, Vector2.ZERO, none, func(_p: Vector2) -> float: return 0.0)
	for i in range(1, Crowns.SLOTS):
		near(s[i].w, 0.0, 0.001, "slot %d is free again" % i)


func test_the_clearing_reaches_about_a_tile_and_a_half() -> void:
	# Small enough that a wood still reads as a wood a step away; big enough to
	# clear a crown standing over the player.
	gt(Crowns.REACH, 1.2, "reach")
	lt(Crowns.REACH, 2.2, "reach")


func test_the_shader_only_opens_what_sways_and_stands_clear() -> void:
	# The numbers, not the lines that use them: the shader declares each as a
	# const so reformatting or renaming a local cannot quietly drop the rule.
	var src := FileAccess.get_file_as_string("res://src/render/world.gdshader")
	check(src.contains("uniform vec4 crown_clear[CROWN_CLEAR];"), "the shader takes the clearings")
	check(src.contains("const float CROWN_SWAY = %.2f;" % Crowns.SWAY_MIN), "only what sways can go: a trunk or a wall never opens")
	check(src.contains("const float CROWN_LIFT = %.2f;" % Crowns.LIFT), "only what stands clear of the point's own ground")
	check(src.contains("sway < CROWN_SWAY"), "the sway gate reads the const")
	check(src.contains("wp.y < p.y + CROWN_LIFT"), "the lift gate reads the const")
	check(src.contains("ink_hash(px + vec2(53.0, 11.0)) < cut"), "cut as world-pinned stipple, never a fade")
	check(src.contains("const int CROWN_CLEAR = %d;" % Crowns.SLOTS), "the shader and the system agree on the slots")


func _flock(n: int, at: Vector2) -> Array:
	# A flock of gulls: alive, near, not hostile, not aware of anyone.
	var pos: Array[Vector2] = []
	var hostile := PackedByteArray()
	var aware := PackedByteArray()
	for i in n:
		pos.append(at + Vector2(i * 0.3, 0.0))
		hostile.append(0)
		aware.append(0)
	return [pos, hostile, aware]


func test_a_flock_of_gulls_never_crowds_out_the_machine_swinging_at_you() -> void:
	# The bug this feature was built to prevent: pests further off filling every
	# slot while the thing actually attacking stays hidden.
	var f := _flock(12, Vector2(12, 0))
	var pos: Array[Vector2] = f[0]
	var hostile: PackedByteArray = f[1]
	var aware: PackedByteArray = f[2]
	# The machine is added LAST, as a mob that spawned later would be.
	pos.append(Vector2(2, 0))
	hostile.append(1)
	aware.append(1)
	var got := Crowns.choose(pos, hostile, aware, Vector2.ZERO, Crowns.SLOTS - 1)
	eq(got.size(), Crowns.SLOTS - 1, "every slot is filled")
	near(got[0].distance_to(Vector2(2, 0)), 0.0, 0.001, "the hostile that has noticed you comes first")


func test_a_body_that_has_noticed_you_outranks_a_nearer_one_that_has_not() -> void:
	var pos: Array[Vector2] = [Vector2(1, 0), Vector2(9, 0)]
	var hostile := PackedByteArray([1, 1])
	var aware := PackedByteArray([0, 1])
	var got := Crowns.choose(pos, hostile, aware, Vector2.ZERO, 1)
	near(got[0].x, 9.0, 0.001, "the one hunting you, not the one standing about")


func test_among_equals_the_nearest_wins() -> void:
	var pos: Array[Vector2] = [Vector2(6, 0), Vector2(2, 0), Vector2(11, 0)]
	var hostile := PackedByteArray([1, 1, 1])
	var aware := PackedByteArray([1, 1, 1])
	var got := Crowns.choose(pos, hostile, aware, Vector2.ZERO, 2)
	near(got[0].x, 2.0, 0.001, "nearest first")
	near(got[1].x, 6.0, 0.001, "then the next")


## THE FOUND CUT IS OFF IN THE SHIPPED ORTHOGRAPHIC GAME. FOUND geometry has
## never cut and closing that gap changes frames the owner has decided, so the
## capability lands inert and he rules on a picture.
##
## ASKED BOTH WAYS ON PURPOSE. The first version of this test ran a real game and
## asserted the global was zero -- and PASSED with the bug deliberately put back,
## because headless there is no world material, `_process` returns early, the
## writer never runs, and the global sits at its project.godot default of zero.
## An assertion of absence is satisfied by nothing having happened. The filled
## case is what gives the test the ability to fail.
##
## The bug it guards is a DEFAULT: Godot's `Projection()` is the IDENTITY, so a
## zeroing that forgets to spell its four Vector4.ZERO columns puts 1.0 into
## three slots' `w`, which found.gdshader reads as a one-tile reach and switches
## the cut on in the very projection it must be absent from.
func test_found_geometry_does_not_cut_under_the_orthographic_camera() -> void:
	var s := _slots()
	Crowns.fill(s, Vector2(10, 4), [Vector2(12, 4)] as Array[Vector2],
		func(_p: Vector2) -> float: return 1.5)
	var off := Crowns.found_matrix(s, false)
	for i in 4:
		eq(off[i], Vector4.ZERO, "ortho slot %d is zero, so found.gdshader skips it" % i)
	var on := Crowns.found_matrix(s, true)
	near(on[0].x, 10.0, 0.001, "under the lens slot 0 carries the player")
	gt(on[0].w, 0.0, "and a reach the shader will act on")
	gt(on[1].w, 0.0, "and the body beside them")


## sight.gdshaderinc's `sight_cone`, as GDScript: 0 keep, 1 take, for a point
## `wp` and an eye `eye` against the body in slot `p`. Held to the shader's text
## below, so the two cannot drift.
static func _cone(wp: Vector3, eye: Vector3, p: Vector4) -> float:
	if p.w <= 0.0:
		return 0.0
	var own := maxf(0.0, p.w - Crowns.REACH)
	var s := Vector3(p.x, p.y + 0.95, p.z)
	var v := s - eye
	var ln := v.length()
	var a := v / ln
	var r := wp - eye
	var t := r.dot(a)
	if t <= 0.0 or t > ln - (0.7 + own):
		return 0.0
	var d := (r - a * t).length()
	var rim := (1.15 + own) * t / ln
	return 1.0 - smoothstep(rim * 0.72, rim * 1.2, d)


## A BODY'S OWN SHAPE IS NEVER IN ITS OWN WAY. Over the shoulder the cut opens
## whatever stands between the eye and a body, keeping only SIGHT_KEEP in front
## of the body's middle -- a person's depth. A keeper is a machine a gantry
## across (radius 1.35), so its own front plates lay in the cone toward its own
## middle and stippled away: the dark curl across the coast reaper's and the
## plough's flanks at eye level, and gone with no keeper there.
func test_a_big_body_does_not_cut_its_own_front() -> void:
	var s := _slots()
	var keeper := Vector2(0.0, 0.0)
	var mobs: Array[Vector2] = [keeper]
	Crowns.fill(s, Vector2(-3.0, 0.0), mobs, func(_p: Vector2) -> float: return 0.0, PackedFloat32Array([1.35]))
	var eye := Vector3(-6.0, 2.0, 0.6)
	var mid := Vector3(0.0, 0.95, 0.0)
	# A plate on the keeper's near side, a little inside its own radius toward the eye.
	var plate := mid + (eye - mid).normalized() * 1.2
	eq(_cone(plate, eye, s[1]), 0.0, "the keeper's own near plate is kept (w %.2f)" % s[1].w)
	# Something truly between the eye and the keeper still goes.
	var between := mid + (eye - mid).normalized() * 3.0
	gt(_cone(between, eye, s[1]), 0.5, "a thing between the eye and the keeper is still cut")
	# A person-sized body is exactly what it was.
	var small := _slots()
	Crowns.fill(small, Vector2(-3.0, 0.0), mobs, func(_p: Vector2) -> float: return 0.0, PackedFloat32Array([0.35]))
	near(small[1].w, Crowns.REACH, 1e-5, "a body no bigger than a person keeps the reach it had")
	near(s[0].w, Crowns.REACH, 1e-5, "and the player keeps theirs")
	# The shader says the same as the mirror.
	var src := FileAccess.get_file_as_string("res://src/render/sight.gdshaderinc")
	check(src.contains("const float SIGHT_REACH = %.1f;" % Crowns.REACH), "the shader knows the reach a person-sized body is written with")
	check(src.contains("float own = max(0.0, p.w - SIGHT_REACH);"), "its own size is what the slot carries past that")
	check(src.contains("t > len - (SIGHT_KEEP + own)"), "the keep grows by it")
	check(src.contains("(SIGHT_RADIUS + own) * t / len"), "and so does the rim")
