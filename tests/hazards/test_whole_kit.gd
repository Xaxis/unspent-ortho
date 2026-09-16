extends TestCase
## What a WHOLE body can wear, not one hazard at a time.
##
## `tests/hazards/test_answers.gd` asks whether each pressure has an answer. That
## is not the question a player asks. A player wears one piece per slot, and a
## landscape that presses three ways with three answers in two slots is a wall
## however good each answer is on its own. The salt flats shipped exactly that:
## the second glare answer was worn on the BACK, which is the only slot that
## answers the same landscape's thirst, so every body that answered the glare
## went thirsty, and the piece added to make the flat survivable made it worse.
##
## So everything here reads the whole kit: one piece per slot, sockets filled,
## and every hazard the landscape declares at once.

const EPS := 1e-6


## Every wearable piece for a slot, plus &"" for wearing nothing there.
static func _choices(slot: StringName) -> Array[StringName]:
	var out: Array[StringName] = [&""]
	out.append_array(Gear.wearables_for(slot))
	return out


static func _modules() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in Items.DEFS:
		if Gear.is_module(id):
			out.append(id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## The two numbers a kit is judged by: the hardest pressure left on the body,
## and the sum, which only breaks ties so the search is deterministic.
static func _score(raw: Dictionary, resist: Dictionary) -> Vector2:
	var kept := Hazards.after_resist(raw, resist)
	var sum := 0.0
	for id: Variant in kept:
		sum += float(kept[id])
	return Vector2(Hazards.worst(kept), sum)


static func _better(a: Vector2, b: Vector2) -> bool:
	if a.x < b.x - EPS:
		return true
	if a.x > b.x + EPS:
		return false
	return a.y < b.y - EPS


## The best whole loadout against `raw`: one piece in each slot (or none), every
## socket filled with whatever module helps most. `force` is a piece that must be
## worn, `ban` one that may not be — the two questions this file asks.
##
## Sockets are filled greedily, one at a time, taking whichever module takes most
## off the hardest pressure. Greedy is exact for a maximum because resistances
## combine independently per hazard and a module can only ever take pressure off.
static func best_kit(raw: Dictionary, force: StringName = &"", ban: StringName = &"") -> Dictionary:
	var slots: Array[StringName] = []
	var options: Array = []
	for slot: StringName in Gear.SLOTS:
		var c := _choices(slot)
		if force != &"" and Gear.slot_of(force) == slot:
			c = [force]
		elif ban != &"":
			c.erase(ban)
		if c.size() > 1 or c[0] != &"":
			slots.append(slot)
			options.append(c)
	var mods := _modules()
	var best_score := Vector2(9.0, 9.0)
	var best: Dictionary = {}
	var counts: Array[int] = []
	for o: Array in options:
		counts.append(o.size())
	var total := 1
	for n: int in counts:
		total *= n
	for pick: int in total:
		var worn: Array[StringName] = []
		var open: Array[StringName] = []  # one entry per free socket, naming its slot
		var n := pick
		for i: int in slots.size():
			var o: Array = options[i]
			var id: StringName = o[n % o.size()]
			n /= o.size()
			if id == &"":
				continue
			worn.append(id)
			for s: int in Gear.sockets(id):
				open.append(slots[i])
		var resist: Dictionary = {}
		for id: StringName in worn:
			Gear.combine(resist, Gear.resist_of(id))
		var fitted: Array[StringName] = []
		for socket: StringName in open:
			var take: StringName = &""
			var take_score := _score(raw, resist)
			var take_resist: Dictionary = {}
			for m: StringName in mods:
				if not Gear.fits(m, socket):
					continue
				var trial := resist.duplicate()
				Gear.combine(trial, Gear.resist_of(m))
				var s := _score(raw, trial)
				if _better(s, take_score):
					take = m
					take_score = s
					take_resist = trial
			if take == &"":
				continue
			fitted.append(take)
			resist = take_resist
		var score := _score(raw, resist)
		if _better(score, best_score):
			best_score = score
			best = {"worn": worn.duplicate(), "modules": fitted.duplicate(),
				"resist": resist, "kept": Hazards.after_resist(raw, resist),
				"worst": score.x}
	return best


## A landscape at the hour and the weather that press it hardest, which is what a
## kit has to survive, not the average day.
static func worst_place(def: BiomeDef) -> Hazards.Place:
	var top := Hazards.Place.new()
	var top_worst := -1.0
	for h: int in 24:
		for row: Array in def.weather:
			var p := Hazards.Place.new()
			p.hazards = def.hazards
			p.hour = float(h)
			p.weather = row[0]
			p.weather_strength = 1.0
			var w := Hazards.worst(Hazards.felt(p))
			if w > top_worst:
				top_worst = w
				top = p
	return top


static func _lands() -> Array[BiomeDef]:
	var out: Array[BiomeDef] = []
	for d: BiomeDef in BiomeRegistry.land():
		if not d.hazards.is_empty():
			out.append(d)
	return out


func test_every_landscape_can_be_worn_through_at_its_worst() -> void:
	for d: BiomeDef in _lands():
		var raw := Hazards.felt(worst_place(d))
		var kit := best_kit(raw)
		lt(float(kit["worst"]), Hazards.BITE,
			"%s at its worst, in the best whole kit: %s + %s leaves %.3f"
			% [d.id, kit["worn"], kit["modules"], kit["worst"]])


## The strongest wearable answer to `id` anywhere in the tables.
static func _strongest(id: StringName) -> StringName:
	var best: StringName = &""
	var top := 0.0
	var ids: Array[StringName] = []
	for item: StringName in Items.DEFS:
		ids.append(item)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for item: StringName in ids:
		if Gear.is_module(item) or not Gear.is_wearable(item):
			continue
		var r := float(Gear.resist_of(item).get(id, 0.0))
		if r > top:
			top = r
			best = item
	return best


## The regression guard the salt flats needed, and the one that is not vacuous.
##
## "Adding a piece never raises the best achievable pressure" is trivially true:
## the best over a larger set of loadouts can only fall. What went wrong is
## narrower and worth a law of its own — the game offers ONE strongest answer to
## each pressure, a player reads the item table and wears it, and on the salt
## flats the strongest glare answer that was not the brim sat on the back, which
## is the only slot that answers the same landscape's thirst. So: wearing the
## strongest answer to any pressure a landscape declares must still leave the
## whole landscape survivable.
##
## Note what this deliberately does NOT assert. Forcing a WEAKER piece of the
## same slot (a scanner lens instead of a brim) is a trade a player makes with
## their eyes open, not a trap, and a rule against it would ban every choice.
func test_wearing_a_pressures_strongest_answer_never_costs_the_landscape() -> void:
	for d: BiomeDef in _lands():
		var raw := Hazards.felt(worst_place(d))
		var seen: Dictionary = {}
		for h: Variant in d.hazards:
			var piece := _strongest(StringName(h))
			if piece == &"" or seen.has(piece):
				continue
			seen[piece] = true
			var kit := best_kit(raw, piece)
			lt(float(kit["worst"]), Hazards.BITE,
				"%s is the strongest answer to %s, which the %s declares, so a body wearing it must still survive there (leaves %.3f with %s + %s)"
				% [piece, h, d.id, kit["worst"], kit["worn"], kit["modules"]])
