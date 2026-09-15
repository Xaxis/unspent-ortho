extends TestCase
## People: looks, crowds, budgets, held tools, the PersonModel contract.


func _heaviest(build: StringName) -> Dictionary:
	return {
		"build": build, "hat": &"souwester", "coat": &"oilskin", "shirt_cut": &"smock", "beard": &"full",
		"hair_style": &"unkempt", "extras": PersonLook.EXTRAS.duplicate(), "salvage": [&"plate", &"aerial"],
	}


func test_every_look_axis_applies() -> void:
	var p := PersonModel.make({})
	for b: StringName in PersonLook.BUILDS:
		p.set_look({"build": b})
		eq(p.look.build, b, "build")
	for h: StringName in PersonLook.HATS:
		p.set_look({"hat": h})
	for c: StringName in PersonLook.COATS:
		p.set_look({"coat": c})
	for s: StringName in PersonLook.SHIRT_CUTS:
		p.set_look({"shirt_cut": s})
	for b: StringName in PersonLook.BEARDS:
		p.set_look({"beard": b})
	for h: StringName in PersonLook.HAIR_STYLES:
		p.set_look({"hair_style": h})
	for h: StringName in PersonLook.HAIR_PRESETS:
		p.set_look({"hair": h})
	for e: StringName in PersonLook.EXTRAS:
		p.set_look({"extras": [e]})
	for s: StringName in PersonLook.SALVAGE:
		p.set_look({"salvage": [s], "side": -1})
		gt(p.rig.triangle_count([&"salvage", &"salvage_glow"]), 0, "salvage %s has geometry" % s)
	for w: StringName in PersonLook.SKIN_WINDOWS:
		p.set_look({"skin": w, "skin_v": 2})
	p.set_look({"shirt": Color(0.5, 0.4, 0.3), "trouser": ["earth", 1], "boot": "stone:0"})
	check(p.rig.body.mesh.get_surface_count() == 1, "one lit surface")
	p.free()


func test_unknown_names_fall_back_instead_of_breaking() -> void:
	var s := PersonLook.normalize({"build": &"giant", "hat": "crown", "salvage": [&"jetpack", &"lens", &"lens"]})
	eq(s.build, &"man")
	eq(s.hat, &"none")
	eq(s.salvage, [&"lens"], "unknown and repeated salvage dropped")


func test_triangle_budget_for_the_heaviest_look_of_every_build() -> void:
	for b: StringName in PersonLook.BUILDS:
		var p := PersonModel.make(_heaviest(b), &"axe_felling")
		lt(p.body_triangles(), 801, "%s body" % b)
		gt(p.tool_triangles(), 0, "%s holds the axe" % b)
		p.free()


func test_every_tool_has_a_model_and_found_ones_glow() -> void:
	var p := PersonModel.make({})
	for id: StringName in HeldTools.all_ids():
		p.set_held(id)
		gt(p.tool_triangles(), 0, "%s has geometry" % id)
		lt(p.tool_triangles(), 400, "%s is a tool, not a building" % id)
		var glows := p.rig.triangle_count([&"tool_glow"]) > 0
		eq(glows, HeldTools.is_found(id), "%s glows only if found" % id)
		if HeldTools.is_found(id):
			check(p.rig.glow != null and p.rig.glow.visible, "%s glow mesh shown" % id)
	p.set_held(&"")
	eq(p.tool_triangles(), 0, "bare hands hold nothing")
	check(p.rig.glow == null or not p.rig.glow.visible, "glow hidden with bare hands")
	p.free()


func test_found_weapons_are_found_colours_and_made_tools_are_not() -> void:
	for id: StringName in HeldTools.all_ids():
		var r := PersonBody.make_rig(&"man")
		HeldTools.build(r, id)
		var violet := 0
		var n := 0
		for entry: Array in r._kits[r.find(&"tool")]:
			var k: MeshKit = entry[0]
			for c in k.colors:
				n += 1
				# FOUND sits at hue ~262 degrees and is saturated; ink shares the hue but not the chroma.
				if c.h > 0.66 and c.h < 0.86 and c.s > 0.45:
					violet += 1
		if HeldTools.is_found(id):
			gt(float(violet) / n, 0.5, "%s is mostly FOUND violet" % id)
		else:
			eq(violet, 0, "%s has no machine colour in it" % id)


func test_swing_timings_come_from_the_item_table_when_it_has_them() -> void:
	eq(HeldTools.swing_ms(&"knife"), [60, 100, 120, 140] as Array[int], "knife from Items")
	eq(HeldTools.swing_ms(&"axe_felling"), [230, 150, 260, 300] as Array[int], "felling axe fallback")
	eq(HeldTools.swing_ms(&""), [70, 80, 110, 180] as Array[int], "fists")
	near(PersonAnim.default_seconds(&"swing", &"pick"), 0.53, 1e-6, "pick swing seconds")


func test_crowd_rule_nobody_shares_build_hat_and_coat() -> void:
	var crowd := PersonLook.crowd(42, 40)
	eq(crowd.size(), 40, "a crowd of 40 fits")
	var seen := {}
	for p in crowd:
		var sig := PersonLook.signature(p)
		check(not seen.has(sig), "repeated silhouette %s" % sig)
		seen[sig] = true
		check(PersonLook.distinct_axes(p) >= 2, "%s has fewer than two of build/hat/coat" % sig)
		check(PersonLook.contrast_ok(p), "%s fails the contrast bar" % sig)
		check((p.salvage as Array).size() <= 2, "never the full salvage set")


func test_generation_is_deterministic() -> void:
	eq(PersonLook.crowd(7, 12), PersonLook.crowd(7, 12), "same seed, same people")
	check(PersonLook.crowd(7, 12) != PersonLook.crowd(8, 12), "different seed, different people")


func test_skin_is_from_the_windows_and_independent_of_costume() -> void:
	var by_window := {}
	var coat_by_window := {}
	for i in 400:
		var p := PersonLook.random(3, i)
		var sk := PersonLook.skin_values(p)
		var window: Array = PersonLook.SKIN[p.skin]
		check(window.has(sk[0]) and window.has(sk[1]) and window.has(sk[2]), "skin inside its window")
		check(window.find(sk[2]) - window.find(sk[0]) == 2, "three adjacent values")
		by_window[p.skin] = int(by_window.get(p.skin, 0)) + 1
		if p.coat != &"none":
			coat_by_window[p.skin] = int(coat_by_window.get(p.skin, 0)) + 1
	for w: StringName in PersonLook.SKIN_WINDOWS:
		gt(by_window.get(w, 0), 60, "window %s is common" % w)
		# Coats (costume) turn up in every window at about the same rate.
		var rate: float = float(coat_by_window.get(w, 0)) / float(by_window.get(w, 1))
		check(rate > 0.35 and rate < 0.85, "coat rate %.2f in %s" % [rate, w])


func test_builds_differ_in_silhouette() -> void:
	var sizes := {}
	for b: StringName in PersonLook.BUILDS:
		var d := PersonBody.dims(b)
		sizes[b] = Vector3(d.chest, d.hip_y + d.torso + d.head, d.depth)
	for a: StringName in PersonLook.BUILDS:
		for b: StringName in PersonLook.BUILDS:
			if a >= b:
				continue
			var da: Vector3 = sizes[a]
			var db: Vector3 = sizes[b]
			var diff := maxf(absf(da.x - db.x) / maxf(da.x, db.x), maxf(absf(da.y - db.y) / maxf(da.y, db.y), absf(da.z - db.z) / maxf(da.z, db.z)))
			var stoop := absf(float(PersonBody.dims(a).stoop) - float(PersonBody.dims(b).stoop))
			check(diff > 0.06 or stoop > 0.15, "%s and %s read alike (%.3f)" % [a, b, diff])
	var woman := PersonBody.dims(&"woman")
	check(woman.hip > woman.chest * 0.9 and woman.hip > PersonBody.dims(&"man").hip, "woman: hips wider")
	lt(PersonBody.dims(&"boy").hip_y, PersonBody.dims(&"man").hip_y * 0.75, "boy is short")


func test_play_action_contract() -> void:
	var p := PersonModel.make({}, &"knife")
	for a: StringName in PersonAnim.ACTIONS:
		p.play_action(a, 0.3)
		check(p.busy(), "%s makes the body busy" % a)
		for i in 30:
			p.animate(0.0, 1.0 / 60.0)
		check(not p.busy(), "%s given 0.3 s is over after 0.5 s" % a)
	p.play_action(&"downed", 0.0)
	for i in 240:
		p.animate(0.0, 1.0 / 60.0)
	check(p.busy(), "downed holds until replaced")
	eq(p.action_progress(), 1.0, "a held action reports settled")
	p.play_action(&"", 0.0)
	check(not p.busy(), "empty action clears")
	p.play_action(&"swing", 0.0)
	near(p.action_left, 0.28, 1e-6, "swing defaults to the knife's windup+active+recovery")
	for i in 20:
		p.animate(0.0, 1.0 / 60.0)
	check(not p.busy(), "the swing ended on time")
	p.play_action(&"juggle", 1.0)
	check(not p.busy(), "unknown action ignored")
	p.free()


func test_hand_and_tool_tip_follow_the_swing() -> void:
	var p := PersonModel.make({}, &"axe_hand")
	var ms := HeldTools.swing_ms(&"axe_hand")
	var len := (ms[0] + ms[1] + ms[2]) / 1000.0
	p.pose_at(&"swing", ms[0] / 1000.0, len)
	var wind := p.tool_tip()
	p.pose_at(&"swing", (ms[0] + ms[1] * 0.45) / 1000.0, len)
	var strike := p.tool_tip()
	gt(wind.y, strike.y, "the axe is raised in the windup")
	gt(strike.x, wind.x + 0.3, "and comes forward through the strike")
	gt(strike.x, 0.4, "the strike lands in front")
	p.free()


func test_folk_look_parser() -> void:
	var s: Dictionary = load("res://src/systems/35_folk.gd").parse_look("heavy,cap,long,plate,lens,full,satchel", 1)
	eq(s.build, &"heavy")
	eq(s.hat, &"cap")
	eq(s.coat, &"long")
	eq(s.beard, &"full")
	eq(s.salvage, [&"plate", &"lens"])
	eq(s.extras, [&"satchel"])
