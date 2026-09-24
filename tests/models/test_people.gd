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


## Body triangles for a look, counted on the dressed rig (no mesh built).
func _tris(spec: Dictionary) -> int:
	var look := PersonLook.normalize(spec)
	var r := PersonBody.make_rig(look.build)
	PersonBody.dress(r, look)
	var n := 0
	for b in r._kits.size():
		for entry: Array in r._kits[b]:
			n += (entry[0] as MeshKit).verts.size() / 3
	return n


## A person's triangle ceiling. The M1 figure fit 800; the last people carry
## their whole scavenged kit on top (gear, patches, weather coats), and the worst
## case below adds every axis's heaviest choice at once, which nobody wears.
## Raised from 1300 when the figure was rounded for the view over the shoulder
## (PersonBody's SKULL_N and siblings): measured on forty random villagers, a
## street went from 25,677 triangles to 41,049 (641 to 1,026 each), which is
## nothing to the GPU. What it does cost is the build, on the main thread.
const BUDGET := 1700


func test_no_look_of_any_build_passes_the_triangle_budget() -> void:
	# The worst look is bounded per axis, since parts on different axes add: the
	# worst head (hat x hair x beard), the worst coat and cut, every extra at once,
	# the two heaviest salvage parts (normalize keeps two at most), the three
	# heaviest pieces of gear, and every patch.
	for b: StringName in [&"man", &"woman", &"heavy"]:
		var bare := {"build": b, "extras": [], "gear": [], "patches": 0}
		var base := _tris(bare)
		var head := 0
		for h: StringName in PersonLook.HATS:
			for st: StringName in PersonLook.HAIR_STYLES:
				for bd: StringName in PersonLook.BEARDS:
					head = maxi(head, _tris(_with(bare, {"hat": h, "hair_style": st, "beard": bd})) - base)
		var coat := 0
		for c: StringName in PersonLook.COATS:
			for cut: StringName in PersonLook.SHIRT_CUTS:
				coat = maxi(coat, _tris(_with(bare, {"coat": c, "shirt_cut": cut})) - base)
		var extras := _tris(_with(bare, {"extras": PersonLook.EXTRAS.duplicate()})) - base
		var parts: Array[int] = []
		for sv: StringName in PersonLook.SALVAGE:
			parts.append(_tris(_with(bare, {"salvage": [sv]})) - base)
		parts.sort()
		var kit: Array[int] = []
		for g: StringName in PersonLook.GEAR:
			kit.append(_tris(_with(bare, {"gear": [g]})) - base)
		kit.sort()
		var patches := _tris(_with(bare, {"patches": 3, "coat": &"long"})) - _tris(_with(bare, {"coat": &"long"}))
		var worst := base + head + coat + extras + parts[-1] + parts[-2] + kit[-1] + kit[-2] + kit[-3] + patches
		lt(worst, BUDGET + 1, "%s: worst look %d = base %d + head %d + coat %d + extras %d + salvage %d + %d + gear %d + %d + %d + patches %d" % [b, worst, base, head, coat, extras, parts[-1], parts[-2], kit[-1], kit[-2], kit[-3], patches])
		for g: StringName in PersonLook.GEAR:
			lt(_tris(_with(bare, {"gear": [g]})) - base, 160, "%s: %s is kit, not luggage" % [b, g])
	var p := PersonModel.make({"build": &"squat", "hat": &"band", "coat": &"jerkin", "hair_style": &"bun", "beard": &"full", "extras": PersonLook.EXTRAS.duplicate(), "salvage": [&"brace", &"gauntlet", &"plate"], "gear": [&"pack", &"respirator", &"radio", &"coil"], "patches": 3}, &"axe_felling")
	eq((p.look.salvage as Array).size(), 2, "a third salvage part is dropped")
	eq((p.look.gear as Array).size(), PersonLook.GEAR_MAX, "gear past the most a body carries is dropped")
	lt(p.body_triangles(), BUDGET + 1, "a heavy real look")
	gt(p.tool_triangles(), 0, "holds the axe")
	p.free()
	# What a village actually wears stays well inside it.
	var total := 0
	var folk := PersonLook.villagers(9, 24, {&"wet": 0.3})
	for spec: Dictionary in folk:
		total += _tris(spec)
	lt(total / folk.size(), BUDGET * 3 / 4, "a typical villager")


func _with(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	out.merge(b, true)
	return out


func test_every_tool_has_a_model_and_found_ones_glow() -> void:
	var p := PersonModel.make({})
	for id: StringName in HeldTools.all_ids():
		p.set_held(id)
		gt(p.tool_triangles(), 0, "%s has geometry" % id)
		lt(p.tool_triangles(), 400, "%s is a tool, not a building" % id)
		var glows := p.rig.triangle_count([&"tool_glow"]) > 0
		eq(glows, HeldTools.is_found(id), "%s glows only if found" % id)
		if HeldTools.is_found(id):
			var g := p.rig.meshes[SkinRig.FOUND]
			check(g != null and g.visible and _lit_vertices(g) > 0, "%s light drawn in the FOUND mesh" % id)
	p.set_held(&"")
	eq(p.tool_triangles(), 0, "bare hands hold nothing")
	eq(p.rig.triangle_count([&"tool_glow"]), 0, "no tool light with bare hands")
	p.set_look({"gear": []})
	var bare := p.rig.meshes[SkinRig.FOUND]
	check(bare == null or not bare.visible or _lit_vertices(bare) == 0, "no light with bare hands and no lit kit")
	check(p.rig.meshes[SkinRig.GLOW] == null, "lights never take a mesh of their own")
	p.free()


func _lit_vertices(mi: MeshInstance3D) -> int:
	var n := 0
	for c: Color in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		if c.a < 0.98 and c.a >= 0.5:
			n += 1
	return n


func test_found_weapons_draw_with_the_ruler_and_made_tools_with_the_hand() -> void:
	# ART.md law 3: FOUND on found.gdshader (clean, lit), MADE on the hand's material.
	for id: StringName in HeldTools.all_ids():
		var r := PersonBody.make_rig(&"man")
		HeldTools.build(r, id)
		var surfaces := {}
		var violet := 0
		for entry: Array in r._kits[r.find(&"tool")]:
			var k: MeshKit = entry[0]
			if k.verts.is_empty():
				continue
			surfaces[entry[1]] = true
			for c in k.colors:
				# FOUND sits at hue ~260 degrees with a cold, held-down chroma; ink shares
				# the hue but has almost none.
				if c.h > 0.66 and c.h < 0.86 and maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) > 0.1:
					violet += 1
		if HeldTools.is_found(id):
			check(not surfaces.has(SkinRig.MADE), "%s has nothing hand-drawn" % id)
			check(surfaces.has(SkinRig.GLOW), "%s is lit" % id)
			gt(violet, 0, "%s carries the FOUND violet" % id)
		else:
			eq(surfaces.keys(), [SkinRig.MADE], "%s is made by hand" % id)
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
	p.play_action(&"eat", 0.0)
	p.play_action(&"juggle", 1.0)
	eq(p.action, &"eat", "an unknown action leaves the current one alone")
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


## Half-widths of the posed, skinned figure seen from the front: [hips, shoulders].
## Hips: every part but the arms, from the crotch to the waist. Shoulders: every
## part, arms included, across the top of the chest.
func _outline(build: StringName) -> Vector2:
	var p := PersonModel.make({"build": build, "extras": []})
	var d := PersonBody.dims(build)
	var hip_y: float = d.hip_y
	var sh_y: float = hip_y + 0.05 + float(d.torso) - 0.075
	var arms: Array[StringName] = [&"arm_l", &"fore_l", &"hand_l", &"arm_r", &"fore_r", &"hand_r", &"tool", &"food"]
	var hips := 0.0
	var shoulders := 0.0
	for b in p.rig.names.size():
		var xf := p.bone_transform(p.rig.names[b])
		for entry: Array in p.rig._kits[b]:
			for v in (entry[0] as MeshKit).verts:
				var m := xf * v
				if m.y > hip_y - 0.16 and m.y < hip_y + 0.08 and not arms.has(p.rig.names[b]):
					hips = maxf(hips, absf(m.z))
				if m.y > sh_y - 0.1 and m.y < sh_y + 0.02:
					shoulders = maxf(shoulders, absf(m.z))
	p.free()
	return Vector2(hips, shoulders)


func test_the_woman_is_the_only_build_whose_hips_outline_her_shoulders() -> void:
	# art-audio-extract §4: the only build with hips wider than shoulders, and every
	# pair apart by 18% in silhouette. Measured on the skinned mesh, not on dims.
	var w := _outline(&"woman")
	var ratio := w.x / w.y
	gt(ratio, 1.0, "woman: hips wider than shoulders, arms and all (%.3f / %.3f)" % [w.x, w.y])
	for b: StringName in PersonLook.BUILDS:
		if b == &"woman":
			continue
		var o := _outline(b)
		lt(o.x / o.y, 1.0, "%s: shoulders wider than hips" % b)
		gt(ratio, o.x / o.y * 1.18, "woman's flare is 18%% past %s's" % b)
