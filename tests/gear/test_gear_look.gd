extends TestCase
## What a body is seen wearing (GearLook): every wearable says it in the people
## model's own words, and no kit a player can put together ever loses a piece on
## the way to the model. The loss would be silent — a cap in PersonLook.normalize
## quietly dropping the fourth part — so this is where it is made loud.

const SLOTS: Array[StringName] = [&"head", &"body", &"hands", &"back"]


func test_every_wearable_says_what_the_body_is_seen_wearing() -> void:
	var seen := 0
	for slot in SLOTS:
		for id: StringName in Gear.wearables_for(slot):
			seen += 1
			var wears: Dictionary = Items.def(id).get("wears", {})
			check(not wears.is_empty(), "%s is worn on the %s and shows nothing" % [id, slot])
			if wears.has("hat"):
				check(PersonLook.HATS.has(StringName(str(wears.hat))), "%s: no hat %s" % [id, wears.hat])
			if wears.has("coat"):
				check(PersonLook.COATS.has(StringName(str(wears.coat))), "%s: no coat %s" % [id, wears.coat])
			for e: Variant in wears.get("extras", []):
				var n := StringName(str(e))
				check(PersonLook.EXTRAS.has(n) or PersonLook.KIT_EXTRAS.has(n), "%s: no extra %s" % [id, n])
			for v: Variant in wears.get("salvage", []):
				check(PersonLook.SALVAGE.has(StringName(str(v))), "%s: no salvage %s" % [id, v])
			for v: Variant in wears.get("gear", []):
				check(PersonLook.GEAR.has(StringName(str(v))), "%s: no gear %s" % [id, v])
			for k: String in wears:
				check(k in GearLook.NAMED or k in GearLook.LISTED or k == "wing", "%s: '%s' is not a thing a body wears" % [id, k])
	gt(float(seen), 10.0, "every wearable looked at (%d)" % seen)


func test_no_kit_a_player_can_wear_loses_a_piece() -> void:
	var options: Array = []
	for slot in SLOTS:
		var ids: Array = [&""]
		ids.append_array(Gear.wearables_for(slot))
		options.append(ids)
	var kits := 0
	var counters: Array[int] = [0, 0, 0, 0]
	while true:
		var l := Loadout.new()
		var named := PackedStringArray()
		for i in SLOTS.size():
			var id: StringName = options[i][counters[i]]
			if id != &"":
				check(l.fit(SLOTS[i], id), "%s fits the %s" % [id, SLOTS[i]])
				named.append(String(id))
		var look := PersonLook.normalize(GearLook.compose(PersonLook.BASE, l))
		for i in SLOTS.size():
			var id: StringName = options[i][counters[i]]
			if id == &"":
				continue
			for piece: String in GearLook.pieces(id):
				var kv := piece.split(":")
				var lost := false
				match kv[0]:
					"hat", "coat":
						lost = String(look[kv[0]]) != kv[1]
					"extras", "salvage", "gear":
						lost = not (look[kv[0]] as Array).has(StringName(kv[1]))
					"wing":
						lost = not GearLook.wing(l)
				check(not lost, "wearing %s, the model lost %s from %s" % [", ".join(named), piece, id])
		# The body keeps its own things under the gear: the slate on the wrist above all.
		check((look.gear as Array).has(&"slate"), "the slate stays on the wrist under %s" % ", ".join(named))
		kits += 1
		var k := 0
		while k < SLOTS.size():
			counters[k] += 1
			if counters[k] < (options[k] as Array).size():
				break
			counters[k] = 0
			k += 1
		if k == SLOTS.size():
			break
	gt(float(kits), 100.0, "every kit tried (%d)" % kits)


func test_a_crowd_keeps_its_caps() -> void:
	var dealt := PersonLook.normalize({"salvage": PersonLook.SALVAGE.duplicate(), "gear": PersonLook.GEAR.duplicate(), "extras": [&"mitts", &"satchel"]})
	eq((dealt.salvage as Array).size(), 2, "a stranger never wears the full set of salvage")
	eq((dealt.gear as Array).size(), PersonLook.GEAR_MAX, "nor more than a body carries")
	check(not (dealt.extras as Array).has(&"mitts"), "and a kit's own extras are never dealt")
	var kit := PersonLook.normalize({"kit": true, "salvage": PersonLook.SALVAGE.duplicate(), "gear": PersonLook.GEAR.duplicate(), "extras": [&"mitts"]})
	eq((kit.salvage as Array).size(), PersonLook.SALVAGE_KIT, "a chosen kit wears one piece a slot")
	eq((kit.gear as Array).size(), PersonLook.GEAR_KIT)
	check((kit.extras as Array).has(&"mitts"), "and its mitts")


func test_gear_goes_over_the_body_it_is_put_on() -> void:
	var bare := PersonLook.normalize({"build": &"heavy", "hat": &"cap", "hair_style": &"long"})
	var l := Loadout.new()
	var plain := PersonLook.normalize(GearLook.compose(bare, l))
	eq(plain.build, &"heavy", "no gear, the same body")
	eq(plain.hat, &"cap", "in its own hat")
	check(l.fit(&"head", &"hat_brim"), "a hat on")
	var hatted := PersonLook.normalize(GearLook.compose(bare, l))
	eq(hatted.hat, &"brim", "the brimmed hat replaces the cap")
	eq(hatted.build, &"heavy", "and the body under it is the same body")
	eq(hatted.hair_style, &"long")
	check(not GearLook.wing(l), "no wing")
	check(l.fit(&"back", &"glide_wing"), "the wing on")
	check(GearLook.wing(l), "the wing is worn")
