extends TestCase
## Day two, with a knife and no bench.
##
## The landscapes that press hardest stand 74-100 tiles from a spawn on every
## seed tested, so a player walks into one before they have built a bench. What
## they can wear there is what a pair of hands makes out of rags, wrack, reeds
## and pitch. A2 measured that kit against the hard landscapes and found a wall:
## glare 0.70 and cold 0.68, biting every hour of the day, and heat and thirst at
## 0.85 — over HARM, a drain with nothing to buy an answer with.
##
## Two rules, and they are different rules on purpose:
##
##   HARM   never, in any weather a landscape's own climate rolls, at any hour.
##          A drain a player cannot answer is not difficulty, it is a wall.
##   BITE   never from the LAND ALONE (its settled weather). A storm may slow
##          your legs; that is what shelter and a fire are for. The ground you
##          are standing on may not, until you have chosen to go somewhere hard.
##
## Two pressures are answered by WHERE YOU STAND rather than by what you wear,
## and that is the design, not a hole in it: dark is answered by light, and a
## heap of swarf that will not hold is answered by getting under something or off
## it. `Hazards._answer_shift` already models both, so this file carries a lamp
## and asks the place answers to be real rather than asking for a hat that sees
## in the dark.

## The hours a body might be caught out at.
const HOURS: Array[float] = [3.0, 9.0, 12.0, 15.0, 19.0, 22.0]
## hazard -> what answers it where you stand, and how the Place says so.
const BY_PLACE := {&"dark": "light", &"collapse": "a roof"}


static func hand_makeable() -> Array[StringName]:
	var out: Array[StringName] = []
	for r: Dictionary in Recipes.LIST:
		if r.get("at", &"") != &"hand":
			continue
		for id: Variant in (r.get("makes", {}) as Dictionary):
			var s := StringName(id)
			if not out.has(s) and (Gear.is_wearable(s) or Gear.is_module(s)):
				out.append(s)
	out.sort()
	return out


## The strongest resist a hand-made kit can carry against one hazard: the best
## piece in each slot, and every socket it opens filled with the best DISTINCT
## hand-made module that fits there. One of each module, because a bag of six
## identical rag shades is not a design, it is an exploit.
##
## This is a per-hazard CEILING, not a loadout — the whole-kit question, where
## one slot has to answer two pressures at once, is `test_whole_kit.gd`.
static func day_two_resist(id: StringName) -> float:
	var made := hand_makeable()
	var total := 0.0
	var spent: Array[StringName] = []
	for slot: StringName in Gear.SLOTS:
		var piece: StringName = &""
		var best := -1.0
		for item: StringName in made:
			if Gear.is_module(item) or Gear.slot_of(item) != slot:
				continue
			var r := float(Gear.resist_of(item).get(id, 0.0))
			if r > best:
				best = r
				piece = item
		if piece == &"":
			continue
		total = 1.0 - (1.0 - total) * (1.0 - maxf(0.0, best))
		for _socket: int in Gear.sockets(piece):
			var mod: StringName = &""
			var mbest := 0.0
			for item: StringName in made:
				if not Gear.is_module(item) or spent.has(item) or not Gear.fits(item, slot):
					continue
				var r := float(Gear.resist_of(item).get(id, 0.0))
				if r > mbest:
					mbest = r
					mod = item
			if mod == &"":
				continue
			spent.append(mod)
			total = 1.0 - (1.0 - total) * (1.0 - mbest)
	return total


## What a landscape presses with, worst case over the hours and over `kinds` of
## weather. `lamp` is lit, because dark is answered by light.
static func _worst(def: BiomeDef, kinds: Array[StringName]) -> Dictionary:
	var out: Dictionary = {}
	for hour: float in HOURS:
		for kind: StringName in kinds:
			for strength: float in [0.0, 1.0]:
				var p := Hazards.Place.new()
				p.hazards = def.hazards
				p.hour = hour
				p.weather = kind
				p.weather_strength = strength
				p.lamp = true
				var felt := Hazards.felt(p)
				for k: Variant in felt:
					out[StringName(k)] = maxf(float(out.get(k, 0.0)), float(felt[k]))
	return out


## Everything its own climate can throw, at full strength.
static func worst_raw(def: BiomeDef) -> Dictionary:
	var kinds: Array[StringName] = [&"clear"]
	for row: Variant in Weather.climate(def.id):
		var r: Array = row
		kinds.append(StringName(r[0]))
	return _worst(def, kinds)


## The land on its own, in the weather it settles to.
static func settled_raw(def: BiomeDef) -> Dictionary:
	return _worst(def, [&"clear"] as Array[StringName])


static func _kept(bare: float, id: StringName) -> float:
	return bare * (1.0 - clampf(day_two_resist(id), 0.0, Hazards.RESIST_CAP))


static func _sorted(d: Dictionary) -> Array:
	var ids: Array = d.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	return ids


## The table this file exists to keep honest, printed so a report can quote it.
func test_a_hand_made_kit_keeps_every_landscape_out_of_harm() -> void:
	var lines: PackedStringArray = []
	for def: BiomeDef in BiomeRegistry.land():
		if def.hazards.is_empty():
			continue
		var raw := worst_raw(def)
		for k: Variant in _sorted(raw):
			var id := StringName(k)
			var bare := float(raw[id])
			var kept := _kept(bare, id)
			lines.append("  %-16s %-11s bare %.2f  day two %.2f %s%s" % [
				def.id, id, bare, kept,
				["", "felt", "BITE", "HARM"][Hazards.level_of(kept)],
				"  (answered by %s)" % BY_PLACE[id] if BY_PLACE.has(id) else ""])
			if BY_PLACE.has(id):
				continue
			lt(kept, Hazards.HARM, "%s presses %s to %.2f on day two, which drains a body with no answer to buy"
				% [def.id, id, kept])
	print("day two, hand-made kit, worst weather:\n", "\n".join(lines))


func test_the_land_alone_never_bites_a_hand_made_kit() -> void:
	var lines: PackedStringArray = []
	for def: BiomeDef in BiomeRegistry.land():
		if def.hazards.is_empty():
			continue
		var raw := settled_raw(def)
		for k: Variant in _sorted(raw):
			var id := StringName(k)
			if BY_PLACE.has(id):
				continue
			var kept := _kept(float(raw[id]), id)
			if kept >= Hazards.FELT:
				lines.append("  %-16s %-11s settled %.2f  day two %.2f" % [def.id, id, float(raw[id]), kept])
			lt(kept, Hazards.BITE, "%s's own %s slows a day-two body's legs at %.2f, in no weather at all"
				% [def.id, id, kept])
	print("day two, hand-made kit, settled weather (only what is still felt):\n", "\n".join(lines))


func test_every_pressure_a_landscape_declares_has_an_answer_by_hand() -> void:
	# Not "every hazard in IDS" — a pressure no landscape in this build declares
	# is answered when the landscape that declares it is written.
	var declared: Array[StringName] = []
	for def: BiomeDef in BiomeRegistry.land():
		for k: Variant in def.hazards:
			var id := StringName(k)
			if float(def.hazards[k]) > 0.0 and not declared.has(id):
				declared.append(id)
	declared.sort()
	for id: StringName in declared:
		if BY_PLACE.has(id):
			continue
		gt(day_two_resist(id), 0.0,
			"nothing a pair of hands makes answers %s, and a landscape declares it" % id)


## ...and the two that are answered by where you stand really are. A place answer
## that does not work is worse than no answer, because nothing on the slate says
## the gear was never the point.
##
## Out of HARM, not out of BITE: a cave at three in the morning with a lamp lit
## is still slow going, and should be. What it may not be is a drain.
func test_the_place_answers_are_real() -> void:
	for def: BiomeDef in BiomeRegistry.land():
		for k: Variant in BY_PLACE:
			var id := StringName(k)
			if float(def.hazards.get(id, 0.0)) <= 0.0:
				continue
			for hour: float in HOURS:
				var p := Hazards.Place.new()
				p.hazards = def.hazards
				p.hour = hour
				p.lamp = true
				p.shelter = 1.0
				lt(float(Hazards.felt(p).get(id, 0.0)), Hazards.HARM,
					"%s: %s is answered by %s, and %s does not answer it at %02d:00"
						% [def.id, id, BY_PLACE[k], BY_PLACE[k], int(hour)])


func test_the_two_hard_landscapes_no_longer_bite_all_day() -> void:
	# The named numbers from the A2 review: glare 0.70 and cold 0.68, carried
	# every hour of day two, in the landscapes' own settled weather. A land may
	# bite in a storm; it may not bite standing still with nothing on the whole of
	# a makeable kit pointed at it.
	for pair: Array in [[&"salt_flats", &"glare"], [&"snowfield", &"cold"], [&"salt_flats", &"thirst"]]:
		var def := BiomeRegistry.get_def(pair[0])
		var id: StringName = pair[1]
		var kept := _kept(float(settled_raw(def).get(id, 0.0)), id)
		lt(kept, Hazards.BITE, "%s still bites on a settled day two (%.2f)" % [id, kept])
