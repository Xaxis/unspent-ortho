extends TestCase
## Animation rules, sampled from the pure pose functions.

var _rig: SkinRig


func _r() -> SkinRig:
	if _rig == null:
		_rig = PersonBody.make_rig(&"man")
	return _rig


func _at(p: PersonAnim.Pose, bone: StringName, tool_id: StringName = &"") -> Vector3:
	var q := PersonAnim.resolve(_r(), p, tool_id)
	return PersonAnim.fk(_r(), q, _r().find(bone)).origin


func test_walk_legs_alternate_and_arms_counter_swing() -> void:
	var d := PersonBody.dims(&"man")
	var a := PersonAnim.locomotion(0.0, PersonAnim.GAIT_WALK, 0.0, d, &"fist")
	var b := PersonAnim.locomotion(0.5, PersonAnim.GAIT_WALK, 0.0, d, &"fist")
	gt(_at(a, &"foot_l").x, _at(a, &"foot_r").x + 0.2, "left foot leads at contact")
	gt(_at(b, &"foot_r").x, _at(b, &"foot_l").x + 0.2, "right foot leads half a cycle later")
	gt(_at(a, &"hand_r").x, _at(a, &"hand_l").x, "right arm forward with the left leg")


func test_walk_bobs_twice_per_stride_and_the_head_lands_late() -> void:
	var d := PersonBody.dims(&"man")
	var lows: Array[float] = []
	var ys: Array[float] = []
	for i in 40:
		var p := PersonAnim.locomotion(i / 40.0, PersonAnim.GAIT_WALK, 0.0, d, &"fist")
		ys.append(p.o(&"hips").y)
	for i in 40:
		if ys[i] < ys[(i + 39) % 40] and ys[i] <= ys[(i + 1) % 40]:
			lows.append(i / 40.0)
	eq(lows.size(), 2, "two lows per cycle")
	check(lows[0] > 0.0 and lows[0] < 0.2, "down comes just after contact, got %s" % str(lows))
	var head_low := 0.0
	var best := 1.0
	for i in 20:
		var p := PersonAnim.locomotion(i / 40.0, PersonAnim.GAIT_WALK, 0.0, d, &"fist")
		var hy := p.o(&"hips").y + p.o(&"head").y
		if hy < best:
			best = hy
			head_low = i / 40.0
	gt(head_low, lows[0], "the head bottoms out after the hips")


func test_run_leans_further_and_lifts_the_knees_more() -> void:
	var d := PersonBody.dims(&"man")
	var walk := PersonAnim.locomotion(0.75, PersonAnim.GAIT_WALK, 0.0, d, &"fist")
	var run := PersonAnim.locomotion(0.75, PersonAnim.GAIT_RUN, 0.0, d, &"fist")
	lt(run.r(&"spine").z, walk.r(&"spine").z - 0.1, "run leans forward")
	lt(run.r(&"shin_l").z, walk.r(&"shin_l").z - 0.3, "run folds the swing knee")
	gt(run.r(&"fore_r").z, walk.r(&"fore_r").z + 0.5, "run bends the elbows")


func test_idle_breathes_and_stoops_by_build() -> void:
	var man := PersonBody.dims(&"man")
	var a := PersonAnim.locomotion(0.0, 0.0, 0.0, man, &"fist")
	var b := PersonAnim.locomotion(0.0, 0.0, 0.85, man, &"fist")
	check(absf(a.o(&"spine").y - b.o(&"spine").y) > 0.004, "the chest rises and falls")
	var bent := PersonAnim.locomotion(0.0, 0.0, 0.0, PersonBody.dims(&"bent"), &"fist")
	lt(bent.r(&"spine").z, a.r(&"spine").z - 0.5, "a bent person stoops")


func test_swing_phases_follow_windup_active_recovery() -> void:
	var d := PersonBody.dims(&"man")
	for id: StringName in [&"", &"knife", &"billhook", &"axe_hand", &"axe_felling", &"pick", &"stave", &"boathook", &"stun_hand"]:
		var ms := HeldTools.swing_ms(id)
		var total := float(ms[0] + ms[1] + ms[2])
		var klass := HeldTools.klass(id)
		var g := PersonAnim.swing(klass, 0.0, ms, d)
		var wind := PersonAnim.swing(klass, ms[0] / total, ms, d)
		var strike := PersonAnim.swing(klass, (ms[0] + ms[1] * 0.45) / total, ms, d)
		var end := PersonAnim.swing(klass, 1.0, ms, d)
		# Anticipation turns the right shoulder back; the blow brings it through.
		lt(wind.r(&"spine").y, g.r(&"spine").y + 0.01, "%s winds the shoulders back" % klass)
		gt(strike.r(&"spine").y, wind.r(&"spine").y + 0.3, "%s drives the shoulder through" % klass)
		near(end.r(&"arm_r").z, g.r(&"arm_r").z, 1e-4, "%s recovers to guard" % klass)
		var tip := &"tool" if id != &"" else &"hand_r"
		gt(_at(strike, tip, id).x, _at(wind, tip, id).x + 0.15, "%s: the business end comes forward" % klass)


func test_two_handed_tools_keep_both_hands_on_the_haft() -> void:
	var d := PersonBody.dims(&"man")
	for id: StringName in [&"axe_felling", &"pick", &"mattock", &"stave", &"boathook", &"las_long", &"beam_lance"]:
		var ms := HeldTools.swing_ms(id)
		for u: float in [0.0, 0.3, 0.55, 0.8]:
			var q := PersonAnim.resolve(_r(), PersonAnim.swing(HeldTools.klass(id), u, ms, d), id)
			var tool := PersonAnim.fk(_r(), q, _r().find(&"tool"))
			var span := HeldTools.off_range(id)
			var a := tool * Vector3(0, span.x, 0)
			var ab := tool * Vector3(0, span.y, 0) - a
			var hand := PersonAnim.fk(_r(), q, _r().find(&"hand_l")) * Vector3(0, -0.045, 0)
			var on := a + ab * clampf((hand - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			lt(hand.distance_to(on), 0.08, "%s at %.2f: left hand on the haft" % [id, u])


func test_dodge_turns_once_and_lands_upright() -> void:
	var d := PersonBody.dims(&"man")
	var mid := PersonAnim.dodge(0.17, 0.42, d)
	check(absf(mid.r(&"root").z) > 1.5, "mid-roll is upside down-ish")
	var landed := PersonAnim.dodge(0.3, 0.42, d)
	near(wrapf(landed.r(&"root").z, -PI, PI), 0.0, 0.05, "a whole turn")
	near(absf(landed.r(&"root").z), TAU, 0.05, "and only one")
	var done := PersonAnim.dodge(0.42, 0.42, d)
	near(done.r(&"root").z, 0.0, 1e-3, "upright at the end")
	near(done.o(&"hips").y, 0.0, 0.01, "standing at the end")


func test_the_roll_stays_a_ball_while_it_turns() -> void:
	# No knot of limbs mid-roll: the body closes into a ball before it starts to
	# turn and opens only once it is upright again. While turned at all, the feet
	# are in at the seat, the head is down at the knees and the hands hold the shins.
	var d := PersonBody.dims(&"man")
	var turned := 0
	for i in 43:
		var t := 0.42 * i / 42.0
		var p := PersonAnim.dodge(t, 0.42, d)
		if absf(wrapf(p.r(&"root").z, -PI, PI)) < 0.05:
			continue
		turned += 1
		var hips := _at(p, &"hips")
		lt(_at(p, &"head").distance_to(_at(p, &"foot_l")), 0.5, "t=%.2f: head down at the feet" % t)
		lt(_at(p, &"foot_l").distance_to(hips), 0.24, "t=%.2f: feet in at the seat" % t)
		lt(_at(p, &"hand_l").distance_to(hips), 0.56, "t=%.2f: hands in round the shins" % t)
	gt(turned, 12, "the roll turns for a good part of the lock")


func test_downed_lies_flat_and_carried_hangs_limp() -> void:
	var d := PersonBody.dims(&"man")
	var down := PersonAnim.downed(3.0, d)
	near(down.r(&"root").z, -PI * 0.5, 1e-3, "face down")
	var head := _at(down, &"head")
	lt(head.y, 0.35, "the head is on the ground")
	var c1 := PersonAnim.carried(0.0, d)
	var c2 := PersonAnim.carried(1.0, d)
	check(c1.r(&"arm_l") != c2.r(&"arm_l"), "limp arms sway")
	lt(c1.r(&"root").z, -1.0, "slung over, not standing")


func test_work_verbs_follow_the_tool() -> void:
	eq(PersonAnim.work_for(&"pick"), &"work_break")
	eq(PersonAnim.work_for(&"mattock"), &"work_dig")
	eq(PersonAnim.work_for(&"axe_hand"), &"work_fell")
	eq(PersonAnim.work_for(&"knife"), &"work_cut", "knife verb from Items")
	eq(PersonAnim.work_for(&""), &"gather")
	var d := PersonBody.dims(&"man")
	for verb: StringName in [&"work_break", &"work_dig", &"work_fell", &"work_cut", &"gather"]:
		var a := PersonAnim.work(verb, 0.1, d, &"pick")
		var b := PersonAnim.work(verb, 0.6, d, &"pick")
		check(a.r(&"spine") != b.r(&"spine") or a.r(&"arm_r") != b.r(&"arm_r") or a.ik_l != b.ik_l, "%s moves" % verb)


func test_eat_brings_food_to_the_mouth() -> void:
	var d := PersonBody.dims(&"man")
	var p := PersonAnim.eat(0.4, d)
	eq(p.food, 1.0, "food shown")
	var hand := _at(p, &"hand_l")
	var head := _at(p, &"head")
	lt(hand.distance_to(head + Vector3(0.1, 0.05, 0)), 0.2, "at the mouth mid-bite")


func test_looping_actions_repeat_exactly_so_their_poses_can_be_shared() -> void:
	var d := PersonBody.dims(&"man")
	for pair: Array in [[&"work_break", &"pick"], [&"work_dig", &"mattock"], [&"work_fell", &"axe_felling"], [&"work_cut", &"knife"], [&"gather", &""], [&"eat", &""], [&"carried", &""]]:
		var period := PersonAnim.loop_period(pair[0], pair[1])
		gt(period, 0.0, "%s loops" % pair[0])
		for t: float in [0.13, 0.41]:
			var a := PersonAnim.action(pair[0], t, 0.0, d, pair[1])
			var b := PersonAnim.action(pair[0], t + period * 3.0, 0.0, d, pair[1])
			for bone: StringName in [&"spine", &"arm_r", &"thigh_l", &"head"]:
				check(a.r(bone).is_equal_approx(b.r(bone)), "%s %s repeats after %.2f s" % [pair[0], bone, period])


func test_a_crowd_of_workers_shares_poses_without_sharing_mistakes() -> void:
	var a := PersonModel.make({}, &"pick")
	var b := PersonModel.make({"hat": &"cap"}, &"pick")
	a.play_action(&"work_break", 0.0)
	b.play_action(&"work_break", 0.0)
	for i in 30:
		a.animate(0.0, 1.0 / 60.0)
		b.animate(0.0, 1.0 / 60.0)
	b.gaze = 1.0
	for i in 5:
		b.animate(2.0, 1.0 / 60.0)
	var sa := a.bone_transform(&"tool")
	a.animate(0.0, 0.0)
	check(sa.is_equal_approx(a.bone_transform(&"tool")), "another worker's glance and stride do not bend this one")
	a.free()
	b.free()
