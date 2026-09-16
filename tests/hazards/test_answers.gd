extends TestCase
## Two pressures a body could not answer.
##
## GLARE was the only one in the game the best legal loadout could not bring
## below a bite, because both answers to it — the brimmed hat and the scanner
## lens — are worn on the HEAD, and the salt flats is one of the two landscapes
## nearest a spawn (74-100 tiles on every seed tested). A place that hurts with
## nothing to do about it is not a difficulty, it is a wall.
##
## MAGNETISM sat at one number at every hour in every weather its climate rolls,
## alone among the landscapes' signature pressures, and was the only hazard in
## the game with nothing WEARABLE against it at all — only two modules, so it
## could only be answered through sockets on pieces worn for something else.


static func place(hazards: Dictionary, hour: float = 12.0) -> Hazards.Place:
	var p := Hazards.Place.new()
	p.hazards = hazards
	p.hour = hour
	return p


## The best a body can wear against `id`: the strongest PIECE in each slot (one
## per slot), plus one of each distinct module. This is the reviewer's own model
## and it reproduces their numbers — glare 0.45 before this branch, magnetism
## 0.48 from two modules and nothing else.
static func best_resist(id: StringName) -> float:
	var total := 0.0
	for slot: StringName in Gear.SLOTS:
		var best := 0.0
		for item: Variant in Items.DEFS:
			var d: Dictionary = Items.DEFS[item]
			if d.get("module", false) or d.get("slot", &"") != slot:
				continue
			best = maxf(best, float((d.get("resist", {}) as Dictionary).get(id, 0.0)))
		total = 1.0 - (1.0 - total) * (1.0 - best)
	for item: Variant in Items.DEFS:
		var d: Dictionary = Items.DEFS[item]
		if not d.get("module", false):
			continue
		var r := float((d.get("resist", {}) as Dictionary).get(id, 0.0))
		total = 1.0 - (1.0 - total) * (1.0 - r)
	return total


func test_glare_has_an_answer_that_is_not_worn_on_the_head() -> void:
	var heads := 0
	var elsewhere := 0
	for item: Variant in Items.DEFS:
		var d: Dictionary = Items.DEFS[item]
		if d.get("module", false):
			continue
		if float((d.get("resist", {}) as Dictionary).get(&"glare", 0.0)) <= 0.0:
			continue
		if d.get("slot", &"") == &"head":
			heads += 1
		else:
			elsewhere += 1
	gt(float(heads), 0.0, "the brim still answers glare")
	gt(float(elsewhere), 0.0, "and something that is not worn on the head does too")


func test_the_salt_flats_at_its_worst_comes_below_a_bite_with_the_best_kit() -> void:
	# The flat at noon under its own glare, which is when it is hardest.
	var salt := BiomeRegistry.get_def(&"salt_flats")
	var p := place(salt.hazards, 12.0)
	p.weather = &"glare"
	p.weather_strength = 1.0
	var raw := Hazards.felt(p)
	gt(float(raw.get(&"glare", 0.0)), Hazards.BITE, "bare on the flat at noon, glare bites")
	var kept := Hazards.after_resist(raw, {&"glare": best_resist(&"glare")})
	lt(float(kept.get(&"glare", 0.0)), Hazards.BITE, "and the best kit brings it under the bite")
	# Not free: the back is the only other slot that answers it, and the back is
	# also where the one answer to this landscape's thirst is worn.
	var back_glare := false
	var back_thirst := false
	for item: Variant in Items.DEFS:
		var d: Dictionary = Items.DEFS[item]
		if d.get("module", false) or d.get("slot", &"") != &"back":
			continue
		var r: Dictionary = d.get("resist", {})
		back_glare = back_glare or float(r.get(&"glare", 0.0)) > 0.0
		back_thirst = back_thirst or float(r.get(&"thirst", 0.0)) > 0.0
	check(back_glare and back_thirst, "answering glare off the head costs the back slot, and the flat's thirst wants it")


func test_magnetism_has_a_quiet_half_of_the_day() -> void:
	var wood := BiomeRegistry.get_def(&"scrapwood")
	var noon := float(Hazards.felt(place(wood.hazards, 12.0)).get(&"magnetism", 0.0))
	var small_hours := float(Hazards.felt(place(wood.hazards, 3.0)).get(&"magnetism", 0.0))
	gt(noon, small_hours * 1.4, "the field is hardest while the grid is working")
	lt(small_hours, Hazards.BITE, "and in the small hours it no longer bites")
	gt(noon, Hazards.FELT, "but the wood never stops being a wood full of live iron")


func test_something_wearable_answers_magnetism() -> void:
	var worn := 0
	for item: Variant in Items.DEFS:
		var d: Dictionary = Items.DEFS[item]
		if d.get("module", false) or d.get("slot", &"") == &"":
			continue
		if float((d.get("resist", {}) as Dictionary).get(&"magnetism", 0.0)) > 0.0:
			worn += 1
	gt(float(worn), 0.0, "a piece, not only a module, keeps the field off a body")
	# And it is worth wearing: the modules alone left 0.39 at the wood's worst
	# hour, which is still a bite you carry all day.
	var wood := BiomeRegistry.get_def(&"scrapwood")
	var raw := Hazards.felt(place(wood.hazards, 12.0))
	var mods_only := 1.0 - (1.0 - 0.20) * (1.0 - 0.35)
	var with_piece := best_resist(&"magnetism")
	gt(with_piece, mods_only + 1e-6, "the piece takes more off than the two modules could alone")
	lt(float(Hazards.after_resist(raw, {&"magnetism": with_piece}).get(&"magnetism", 0.0)),
		float(Hazards.after_resist(raw, {&"magnetism": mods_only}).get(&"magnetism", 0.0)),
		"a wearable answer is worth wearing")
	lt(float(Hazards.after_resist(raw, {&"magnetism": with_piece}).get(&"magnetism", 0.0)),
		Hazards.FELT, "and the whole kit puts the wood's worst hour out of mind")


func test_both_new_answers_are_reachable_with_a_knife_and_no_bench() -> void:
	# The landscapes that press hardest are 74-100 tiles from a spawn: a player
	# meets them on day two. A bench answer is no answer there.
	var found := {}
	for r: Dictionary in Recipes.LIST:
		var makes: Dictionary = r.get("makes", {})
		for id: Variant in makes:
			if id == &"back_awning" or id == &"mitts_corded":
				found[id] = r
	eq(found.size(), 2, "both new pieces have a recipe")
	for id: Variant in found:
		var r: Dictionary = found[id]
		eq(r.get("at", &""), &"hand", "%s is made in the hand, not at a bench" % id)
