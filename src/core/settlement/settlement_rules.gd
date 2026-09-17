class_name SettlementRules
## What a holding does with its own time (docs/VISION.md §9): power made, stored
## and spent; food grown, stored and eaten; parts worn and mended; people fed or
## going hungry. Pure, deterministic, headless: it takes a Settlement, a world
## minute to settle up to, and the seed and landscape the weather comes from, and
## it moves the holding forward.
##
## **Nothing here ticks.** A holding is settled by CATCHING UP from
## `Settlement.worked_at`, in whole slices of SLICE world minutes, so six hours
## away is twelve steps and not twenty-one thousand frames. Slices are aligned to
## absolute clock boundaries and `worked_at` only ever lands on one, which buys
## the property everything else rests on: settling six hours in one call gives
## exactly the same holding as settling it in twelve, so the answer never depends
## on how often the player looked.
##
## The loop is meant to be felt rather than read: a plot with nobody on it grows
## nothing, a plot nobody waters grows half, a spinner in still air charges
## nothing, a store that is full loses the surplus, and everything standing comes
## apart in the rain a little faster than it does in the sun.

## World minutes settled at a time. Half an hour is fine enough that a squall
## and a dusk are felt, and coarse enough that a week away is a few hundred steps.
const SLICE := 30.0
## The most slices one catch-up will run. Past it the holding is settled forward
## without being simulated: nobody is owed five days of berries they never came
## back for, and the alternative is a load that stalls.
const MAX_SLICES := 336
## Health a person puts back into the worst piece in a world hour, and the health
## one item out of the stores pays for. Mending is materials and hands, so a
## holding that grows nothing cannot keep itself up.
const REPAIR_PER_HOUR := 0.9
const REPAIR_PER_ITEM := 3.0
## Food a resident eats in a world hour, and how fast hunger comes and goes.
const EATS_PER_HOUR := 0.1
const HUNGER_PER_HOUR := 0.22
const FED_PER_HOUR := 0.7
## What a hungry holding gets done, and the hunger at which somebody walks off.
const HUNGRY_WORKS := 0.3
const LEAVES_AT := 1.0
## A plot with no water behind it.
const DRY_CROP := 0.5
## Tiles from the holding's centre a catchment still counts for.
const REACH := 14.0


## What the weather does to the hand's work. Rain and storm are what take a
## thatched roof apart; the machines' plate only rusts, and slower.
static func weather_wear(kind: StringName, strength: float, idiom: StructureKind.Idiom) -> float:
	var bite := 0.0
	match Weather.family(kind):
		&"rain", &"storm":
			bite = 1.2
		&"hail", &"snow", &"blizzard":
			bite = 1.0
		&"dust":
			bite = 0.7
		&"heat":
			bite = 0.4
		&"ash":
			bite = 0.6
	var soft := 1.0 if idiom == StructureKind.Idiom.MADE else 0.45
	return 1.0 + bite * clampf(strength, 0.0, 1.0) * soft


## 0..1 of what a generator makes now: a spinner takes the wind, an array takes
## the daylight. Anything else runs flat out, because pedalling is pedalling.
static func source(kind: int, weather: Dictionary, hour: float) -> float:
	match kind:
		StructureKind.WIND_SPINNER:
			# A still week kills the wind spinners (VISION §9): below a breath
			# the blades do not turn at all.
			return clampf((float(weather.get("wind", 0.0)) - 0.12) / 0.6, 0.0, 1.0)
		StructureKind.SOLAR_ARRAY:
			var light := clampf(sin(PI * clampf((hour - 5.5) / 13.0, 0.0, 1.0)), 0.0, 1.0)
			return light * lerpf(1.0, 0.35, clampf(float(weather.get("strength", 0.0)), 0.0, 1.0))
	return 1.0


## Settle `s` forward to the world minute `now`. `ctx` carries what the world
## knows and the rules do not: {seed: int, land: StringName (the landscape type
## the holding stands in; &"" for a calm default)}.
##
## Returns what happened, for whoever wants to say it out loud:
##   {minutes: float settled, made: {item: int}, spoiled: {item: int} (surplus
##    with nowhere to go), ruined: [piece id], mended: [piece id],
##    left: [person id], hungry: bool}
static func catch_up(s: Settlement, now: float, ctx: Dictionary = {}) -> Dictionary:
	var report := {"minutes": 0.0, "made": {}, "spoiled": {}, "ruined": [], "mended": [], "left": [], "hungry": false}
	if not is_finite(s.worked_at):
		# Never run: the holding starts working at the next whole slice, so the
		# minute it was founded on cannot make its first step a short one.
		s.worked_at = floorf(now / SLICE) * SLICE
		return report
	var seed_value := int(ctx.get("seed", 0))
	var land := StringName(ctx.get("land", &""))
	var steps := 0
	while s.worked_at + SLICE <= now and steps < MAX_SLICES:
		_slice(s, s.worked_at, seed_value, land, report)
		s.worked_at += SLICE
		steps += 1
		report["minutes"] = float(report["minutes"]) + SLICE
	if s.worked_at + SLICE <= now:
		# Longer away than anyone is owed: the clock catches up and the holding
		# does not (see MAX_SLICES).
		s.worked_at = floorf(now / SLICE) * SLICE
	s.night = night_at(now)
	return report


## 0 in broad day, 1 in the dark, which is what `Settlement.signature()` weighs a
## window and a column of smoke by. The same shape as the people's own day
## (35_folk DUSK and DAWN), because it is the same day.
static func night_at(minutes: float) -> float:
	var hour := fposmod(minutes, 1440.0) / 60.0
	if hour >= 21.0 or hour < 5.0:
		return 1.0
	if hour < 6.5:
		return clampf((6.5 - hour) / 1.5, 0.0, 1.0)
	if hour > 19.5:
		return clampf((hour - 19.5) / 1.5, 0.0, 1.0)
	return 0.0


static func _slice(s: Settlement, at: float, seed_value: int, land: StringName, report: Dictionary) -> void:
	var hours := SLICE / 60.0
	var weather := _weather(seed_value, at + SLICE * 0.5, land)
	var hour := fposmod(at + SLICE * 0.5, 1440.0) / 60.0
	_forget_the_gone(s)
	_wire(s, weather, hour)
	var works := _works_factor(s)
	_grow(s, hours, works, report)
	_feed(s, hours, report)
	_wear(s, hours, weather, report)
	_mend(s, hours, report)


static func _weather(seed_value: int, at: float, land: StringName) -> Dictionary:
	if land == &"":
		return {"kind": Weather.CLEAR, "strength": 0.0, "wind": 0.35}
	return Weather.at_type(seed_value, at, land)


## A piece staffed by somebody who is no longer here is a piece standing empty.
## Nothing else in the package has to remember to tidy up after a raid.
static func _forget_the_gone(s: Settlement) -> void:
	for p in s.pieces:
		if p.staffed_by >= 0 and not s.people.has(p.staffed_by):
			p.staffed_by = -1
		if p.ruined and p.staffed_by >= 0:
			p.staffed_by = -1


## Power made, spent and banked. Consumers are served in piece order, so which
## mast goes dark when the wind drops is the order they were built in and never
## a coin toss.
static func _wire(s: Settlement, weather: Dictionary, hour: float) -> void:
	var made := 0.0
	for p in s.pieces:
		if not p.standing() or p.condition() < Structure.WORKS_ABOVE:
			continue
		var out := StructureKind.makes_power(p.kind)
		if out > 0.0:
			made += out * p.condition() * source(p.kind, weather, hour)
	var spare := made
	var room := s.charge_room()
	for p in s.pieces:
		var want := StructureKind.draw_power(p.kind)
		if want <= 0.0:
			p.powered = false
			continue
		if not p.standing() or p.condition() < Structure.WORKS_ABOVE:
			p.powered = false
			continue
		if spare >= want:
			spare -= want
			p.powered = true
		elif s.charge >= want:
			# What the batteries are for: the mast stays up through a still night.
			s.charge -= want
			p.powered = true
		else:
			p.powered = false
	s.charge = clampf(s.charge + maxf(0.0, spare) * (SLICE / 60.0), 0.0, room)


## How well the holding works this slice: hungry people do a third of it.
static func _works_factor(s: Settlement) -> float:
	return lerpf(1.0, HUNGRY_WORKS, clampf(s.hunger, 0.0, 1.0))


static func _grow(s: Settlement, hours: float, works: float, report: Dictionary) -> void:
	var watered := _watered(s)
	var room := s.store_room()
	for p in s.pieces:
		if not p.working():
			continue
		var makes := StructureKind.makes(p.kind)
		if makes.is_empty():
			continue
		var rate := p.condition() * works
		if StructureKind.wants_water(p.kind) and not watered:
			rate *= DRY_CROP
		for id: StringName in makes:
			var amount := float(makes[id]) * hours * rate
			_lay_by(s, id, amount, room, report)


## A catchment in reach, in repair: what keeps the plots green.
static func _watered(s: Settlement) -> bool:
	for p in s.pieces:
		if p.standing() and StructureKind.gives_water(p.kind) and p.condition() >= Structure.WORKS_ABOVE:
			if p.pos.distance_to(s.centre) <= REACH:
				return true
	return false


## Put `amount` of `id` by. Produce comes in whole things, so the fraction of a
## basket is carried on the holding's own tally until it is one; what the store
## has no room for is lost, and said so.
static func _lay_by(s: Settlement, id: StringName, amount: float, room: float, report: Dictionary) -> void:
	if amount <= 0.0:
		return
	var key := "grown_%s" % id
	var part := float(s.tally.get(key, 0.0)) + amount
	var whole := floori(part)
	s.tally[key] = part - float(whole)
	if whole <= 0:
		return
	var have := s.stored()
	var fits := maxi(0, mini(whole, floori(room - have)))
	if fits > 0:
		s.stores[id] = int(s.stores.get(id, 0)) + fits
		var made: Dictionary = report["made"]
		made[id] = int(made.get(id, 0)) + fits
	if whole > fits:
		var lost: Dictionary = report["spoiled"]
		lost[id] = int(lost.get(id, 0)) + (whole - fits)


## Residents eat out of the stores. With nothing to eat, hunger rises, the work
## slows, and in the end somebody walks away: people are the one thing a holding
## can lose without a machine coming for it.
static func _feed(s: Settlement, hours: float, report: Dictionary) -> void:
	if s.people.is_empty():
		s.hunger = 0.0
		return
	var want := float(s.people.size()) * EATS_PER_HOUR * hours
	match _eat_from_stores(s, want):
		ATE:
			s.hunger = maxf(0.0, s.hunger - FED_PER_HOUR * hours)
		WENT_WITHOUT:
			s.hunger = minf(1.0, s.hunger + HUNGER_PER_HOUR * hours)
			report["hungry"] = true
		_:
			# Half an hour is not a meal. Nobody is fed and nobody goes hungry:
			# hunger only moves when food was actually eaten or actually missed,
			# or an empty holding would talk itself out of being empty.
			pass
	if s.hunger >= LEAVES_AT and s.people.size() > 0:
		var gone: int = s.people[s.people.size() - 1]
		s.people.remove_at(s.people.size() - 1)
		s.looks.erase(gone)
		for p in s.pieces:
			if p.staffed_by == gone:
				p.staffed_by = -1
		(report["left"] as Array).append(gone)
		s.hunger = 0.65


## What a slice's eating came to.
enum {WENT_WITHOUT = -1, NOT_YET = 0, ATE = 1}


## Eat `want` out of whatever food is stored, the least filling first, so the
## smoked fish is still there when the player comes back for it. What a slice
## wants is a fraction of a basket, so the holding carries the fraction until it
## is a whole thing: NOT_YET until it is, then ATE or WENT_WITHOUT.
static func _eat_from_stores(s: Settlement, want: float) -> int:
	# Capped, so a holding that goes a week without food does not eat a week's
	# worth the hour somebody brings a basket.
	var owed := minf(float(s.tally.get("eaten", 0.0)) + want, HUNGRY_BACKLOG)
	var ate := false
	while owed >= 1.0:
		var pick := _least_filling(s)
		if pick == &"":
			break
		s.stores[pick] = int(s.stores[pick]) - 1
		if int(s.stores[pick]) <= 0:
			s.stores.erase(pick)
		owed -= 1.0
		ate = true
	s.tally["eaten"] = owed
	if ate:
		return ATE
	return NOT_YET if owed < 1.0 else WENT_WITHOUT


## Meals a holding can be behind on.
const HUNGRY_BACKLOG := 2.0


## The least filling thing in the stores, or &"" when there is nothing to eat.
static func _least_filling(s: Settlement) -> StringName:
	var pick := &""
	var least := INF
	for id: Variant in s.stores:
		var name := StringName(id)
		if int(s.stores[id]) <= 0:
			continue
		var feeds := float(Items.def(name).get("feeds", 0.0))
		if feeds <= 0.0 or feeds >= least:
			continue
		least = feeds
		pick = name
	return pick


static func _wear(s: Settlement, hours: float, weather: Dictionary, report: Dictionary) -> void:
	var kind := StringName(weather.get("kind", Weather.CLEAR))
	var strength := float(weather.get("strength", 0.0))
	for p in s.pieces:
		if not p.standing():
			continue
		var idiom := StructureKind.idiom(p.kind)
		var loss := StructureKind.wear(p.kind) * hours * weather_wear(kind, strength, idiom)
		if p.damage(loss):
			(report["ruined"] as Array).append(p.id)


## Hands not on a plot or a mast keep the place standing. One person mends one
## piece: the worst one first, and only while the stores hold what it is made of.
static func _mend(s: Settlement, hours: float, report: Dictionary) -> void:
	var free := s.people.size()
	for p in s.pieces:
		if p.staffed_by >= 0:
			free -= 1
	if free <= 0:
		return
	for _hand in free:
		var worst := worst_piece(s)
		if worst == null:
			return
		var put_back := REPAIR_PER_HOUR * hours * lerpf(1.0, HUNGRY_WORKS, clampf(s.hunger, 0.0, 1.0))
		var paid := _pay_for_repair(s, worst, put_back)
		if paid <= 0.0:
			return
		worst.repair(paid)
		if not (report["mended"] as Array).has(worst.id):
			(report["mended"] as Array).append(worst.id)


## The standing piece furthest from whole, or null when everything is in repair.
## Ties go to the piece built first, so the order is never a coin toss.
static func worst_piece(s: Settlement) -> Structure:
	var worst: Structure = null
	for p in s.pieces:
		if not p.standing() or p.condition() >= 0.999:
			continue
		if worst == null or p.condition() < worst.condition():
			worst = p
	return worst


## Take what a mend costs out of the stores. Returns the health it paid for,
## which is zero when the holding has nothing to mend with.
static func _pay_for_repair(s: Settlement, p: Structure, want: float) -> float:
	var need := StructureKind.cost(p.kind)
	if need.is_empty():
		return want
	var stuff := &""
	for id: StringName in need:
		if int(s.stores.get(id, 0)) > 0:
			stuff = id
			break
	if stuff == &"":
		return 0.0
	var owed := float(s.tally.get("mend", 0.0)) + want / REPAIR_PER_ITEM
	var spent := 0
	while owed >= 1.0 and int(s.stores.get(stuff, 0)) > 0:
		s.stores[stuff] = int(s.stores[stuff]) - 1
		if int(s.stores[stuff]) <= 0:
			s.stores.erase(stuff)
		owed -= 1.0
		spent += 1
	s.tally["mend"] = owed
	return float(spent) * REPAIR_PER_ITEM
