extends TestCase
## The last people: dressed by their land and their trade, worn, hungry, and
## carrying scavenged tech mended in both idioms (docs/VISION.md §6, §8).


func _hazards(id: StringName) -> Dictionary:
	return BiomeRegistry.get_def(id).hazards


func _share(folk: Array[Dictionary], key: String, value: Variant) -> float:
	var n := 0
	for p in folk:
		var v: Variant = p[key]
		if (v is Array and (v as Array).has(value)) or (not v is Array and v == value):
			n += 1
	return float(n) / folk.size()


func test_weather_gear_follows_the_land() -> void:
	var snow := PersonLook.villagers(3, 40, _hazards(&"snowfield"))
	gt(_share(snow, "coat", &"fur"), 0.4, "furs in the snow")
	gt(_share(snow, "hat", &"furhat") + _share(snow, "hat", &"knit"), 0.5, "warm hats in the snow")
	var burning := PersonLook.villagers(3, 40, _hazards(&"burning"))
	gt(_share(burning, "coat", &"wrap"), 0.4, "wraps in the burning")
	gt(_share(burning, "gear", &"respirator"), 0.3, "respirators where the air is foul")
	gt(_share(burning, "hat", &"hood") + _share(burning, "hat", &"scarf"), 0.5, "heads covered from the ash")
	var moss := PersonLook.villagers(3, 40, _hazards(&"moss"))
	gt(_share(moss, "coat", &"oilskin"), 0.3, "oilskins in the wet")
	var coast := PersonLook.villagers(3, 40, _hazards(&"coast"))
	eq(_share(coast, "coat", &"fur"), 0.0, "no furs on a mild coast")
	eq(_share(coast, "coat", &"wrap"), 0.0, "no ash wraps on a mild coast")
	eq(_share(coast, "hat", &"furhat"), 0.0, "no fur hats on a mild coast")


func test_a_landscape_type_added_later_dresses_its_people_from_its_hazards() -> void:
	# Nothing here names a landscape: a new type with foul, glaring air gets
	# respirators and goggles without a line changed in PersonLook.
	var glass := PersonLook.villagers(8, 40, {&"radiation": 0.8, &"heat": 0.6})
	gt(_share(glass, "gear", &"respirator"), 0.4, "respirators under radiation")
	gt(_share(glass, "gear", &"goggles"), 0.25, "goggles in the glare")
	var cold_string_keys := PersonLook.villagers(8, 40, {"cold": 0.9})
	gt(_share(cold_string_keys, "coat", &"fur"), 0.4, "hazard tables keyed by String work too")


func test_trades_bring_their_kit() -> void:
	var scav: Array[Dictionary] = []
	var dig: Array[Dictionary] = []
	var kids: Array[Dictionary] = []
	for i in 40:
		scav.append(PersonLook.dress(PersonLook.random(21, i), {}, &"scavenger", i))
		dig.append(PersonLook.dress(PersonLook.random(22, i), {}, &"digger", i))
		kids.append(PersonLook.dress(PersonLook.random(23, i), {}, &"child", i))
	gt(_share(scav, "gear", &"pack"), 0.6, "scavengers carry packs of salvage")
	gt(_share(scav, "salvage", &"plate") + _share(scav, "salvage", &"breastplate"), 0.3, "machine plate as armour")
	gt(_share(dig, "gear", &"goggles") + _share(dig, "gear", &"respirator"), 0.45, "diggers guard eyes and lungs")
	for k in kids:
		eq(k.build, &"boy", "a child is a child")
		check(not (k.gear as Array).has(&"pack") and not (k.gear as Array).has(&"battery"), "children carry nothing heavy")
		eq((k.salvage as Array).size(), 0, "no machine plate on a child")
	eq(PersonLook.trade_for(&"work", &"axe_felling"), &"cutter")
	eq(PersonLook.trade_for(&"work", &"pick"), &"digger")
	eq(PersonLook.trade_for(&"work", &"billhook"), &"gatherer")
	eq(PersonLook.trade_for(&"walk", &""), &"scavenger")
	eq(PersonLook.trade_for(&"play", &""), &"child")
	eq(PersonLook.trade_for(&"idle", &""), &"keeper")


func test_everyone_is_worn_and_most_are_hungry() -> void:
	var folk := PersonLook.villagers(5, 48, _hazards(&"coast"))
	var thin := 0
	var heavy := 0
	for p in folk:
		gt(int(p.patches), 0, "nobody's clothes are whole")
		check(not (p.gear as Array).has(&"slate"), "the slate is the player's alone")
		check(PersonLook.contrast_ok(p), "a dressed look keeps the contrast bar")
		if int(p.gaunt) > 0:
			thin += 1
		if p.build == &"heavy" or p.build == &"squat":
			heavy += 1
	gt(float(thin) / folk.size(), 0.6, "most are thin")
	lt(float(heavy) / folk.size(), 0.12, "the heavy are rare")
	check((PersonLook.normalize({}).gear as Array).has(&"slate"), "the player wears the slate")
	eq(PersonLook.dress(PersonLook.random(4, 1), _hazards(&"moss"), &"gatherer", 99), PersonLook.dress(PersonLook.random(4, 1), _hazards(&"moss"), &"gatherer", 99), "dressing is deterministic")


func test_hunger_thins_the_body_but_never_its_height() -> void:
	var fed := PersonBody.dims(&"man", 0)
	var starved := PersonBody.dims(&"man", 2)
	lt(float(starved.chest), float(fed.chest) * 0.9, "narrower chest")
	lt(float(starved.arm_t), float(fed.arm_t) * 0.8, "thinner arms")
	gt(float(starved.stoop), float(fed.stoop), "a stoop")
	eq(starved.hip_y, fed.hip_y, "the same legs")
	eq(starved.torso, fed.torso, "the same back")
	var p := PersonModel.make({"gaunt": 0})
	var rig_before := p.rig
	var shoulder: float = p.rig.rest[p.rig.find(&"arm_r")].z
	p.set_look({"gaunt": 2})
	check(p.rig != rig_before, "a new body when hunger changes it")
	lt(p.rig.rest[p.rig.find(&"arm_r")].z, shoulder, "shoulders drawn in")
	p.free()


func test_patches_are_sewn_on_and_skip_what_covers_them() -> void:
	var base := _made_tris({"patches": 0, "gear": []})
	gt(_made_tris({"patches": 3, "gear": []}), base, "patches add cloth")
	# Under plate on the chest and a pack on the back, the torso is never patched:
	# the patches go to knees and elbows instead.
	var covered := {"salvage": [&"breastplate"], "gear": [&"pack"], "coat": &"none"}
	var bare := covered.duplicate()
	bare.patches = 0
	var sewn := covered.duplicate()
	sewn.patches = 3
	eq(_made_tris(sewn, &"spine"), _made_tris(bare, &"spine"), "nothing sewn under plate or pack")
	gt(_made_tris(sewn), _made_tris(bare), "the patches went somewhere else")


func _made_tris(spec: Dictionary, bone: StringName = &"") -> int:
	var look := PersonLook.normalize(spec)
	var r := PersonBody.make_rig(look.build)
	PersonBody.dress(r, look)
	var n := 0
	for b in r._kits.size():
		if bone != &"" and r.names[b] != bone:
			continue
		for entry: Array in r._kits[b]:
			if entry[1] == SkinRig.MADE and entry[2] == &"body":
				n += (entry[0] as MeshKit).verts.size() / 3
	return n


## Surfaces used by the gear layers of a look: {SkinRig surface: true}.
func _gear_surfaces(spec: Dictionary) -> Dictionary:
	var look := PersonLook.normalize(spec)
	var r := PersonBody.make_rig(look.build)
	PersonBody.dress(r, look)
	var out := {}
	for b in r._kits.size():
		for entry: Array in r._kits[b]:
			if (entry[2] == &"gear" or entry[2] == &"gear_glow") and not (entry[0] as MeshKit).verts.is_empty():
				out[entry[1]] = true
	return out


func test_scavenged_tech_is_mended_found_bound_with_made() -> void:
	for g: StringName in PersonLook.GEAR:
		if g == &"coil":
			continue
		var s := _gear_surfaces({"gear": [g]})
		check(s.has(SkinRig.FOUND), "%s: the part off a machine is FOUND" % g)
		check(s.has(SkinRig.MADE), "%s: what holds it on is MADE" % g)
	# A coil is rope (all hand) or machine cable (found, tied with cord): both occur.
	var found := false
	var made := false
	for i in 12:
		var s := _gear_surfaces({"gear": [&"coil"], "shirt": "linen:%d" % (i % 5), "hair": PersonLook.HAIR_PRESETS[i % 6]})
		check(s.has(SkinRig.MADE), "a coil is always tied by hand")
		found = found or s.has(SkinRig.FOUND)
		made = made or not s.has(SkinRig.FOUND)
	check(found and made, "rope coils and cable coils both turn up")


func test_the_slate_glows_faintly_on_the_wrist_and_kit_lights_are_dim() -> void:
	var look := PersonLook.normalize({})
	var r := PersonBody.make_rig(look.build)
	PersonBody.dress(r, look)
	var wrist := r.find(&"fore_l")
	var lit := 0
	for entry: Array in r._kits[wrist]:
		if entry[2] == &"gear_glow" and entry[1] == SkinRig.GLOW:
			for c in (entry[0] as MeshKit).colors:
				lit += 1
				lt(PersonLook.luma(c), 110.0, "the screen is faint, never a lamp")
	gt(lit, 0, "the slate's screen is lit on the left wrist")
	var g := PersonModel.make({"salvage": [&"gauntlet"], "side": -1})
	gt(g.rig.triangle_count([&"gear_glow"]), 0, "a gauntlet on the left moves the slate to the right wrist")
	var right := 0
	for entry: Array in g.rig._kits[g.rig.find(&"fore_r")]:
		if entry[2] == &"gear_glow":
			right += (entry[0] as MeshKit).verts.size()
	gt(right, 0, "and it is there")
	g.free()


func test_goggles_come_down_where_the_air_is_bad() -> void:
	var w := PersonBody.wear_of(PersonLook.normalize({"gear": [&"goggles", &"respirator"]}))
	check(PersonGear.goggles_down(w), "with a respirator the goggles are on")
	w = PersonBody.wear_of(PersonLook.normalize({"gear": [&"goggles"], "coat": &"wrap"}))
	check(PersonGear.goggles_down(w), "in wraps the goggles are on")
	var up := 0
	for i in 20:
		w = PersonBody.wear_of(PersonLook.normalize({"gear": [&"goggles"], "hat": &"none", "shirt": "linen:%d" % (i % 5), "hair": PersonLook.HAIR_PRESETS[i % 6], "skin_v": 1 + i % 3}))
		if not PersonGear.goggles_down(w):
			up += 1
	gt(up, 0, "bareheaded in clean air, some push them up")


func test_every_new_coat_and_hat_dresses_every_build() -> void:
	for b: StringName in PersonLook.BUILDS:
		for c: StringName in [&"fur", &"wrap"]:
			for h: StringName in [&"hood", &"furhat"]:
				var look := PersonLook.normalize({"build": b, "coat": c, "hat": h, "gaunt": 2, "patches": 3, "gear": [&"pack", &"respirator", &"goggles"], "salvage": [&"breastplate"]})
				var r := PersonBody.make_rig(b, 2)
				PersonBody.dress(r, look)
				var n := 0
				for bi in r._kits.size():
					for entry: Array in r._kits[bi]:
						n += (entry[0] as MeshKit).verts.size() / 3
				gt(n, 600, "%s in %s and %s is dressed" % [b, c, h])
				lt(n, 1301, "%s in %s and %s fits the budget" % [b, c, h])
