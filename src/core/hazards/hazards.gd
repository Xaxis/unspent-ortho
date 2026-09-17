class_name Hazards
## One model for every pressure the world puts on a body (docs/VISION.md §6, §7.3).
##
## A landscape type declares its hazards (`BiomeDef.hazards`, the biomes package;
## until it is filled the registry derives them from the six M1 countries). The
## hour, the weather, the height you stand at, a roof and a fire move them. Worn
## gear resists them (`Gear.resist_total` -> `Body.resist`). What is left is what
## the body feels (`Body.pressure`), and it is felt long before it hurts:
##
##   FELT  the gauge lights on the slate, breath shows, the land sounds wrong
##   BITE  walking slows and wind shortens; the gauge turns to the warning colour
##   HARM  a slow drain begins, with hours to answer it, and it never takes the
##         last point of health: weather alone can never kill you outright
##
## Everything here is pure. `felt(place)` is the whole rule; the system
## (src/systems/52_hazards.gd) only builds the Place and applies what comes back.

const IDS: Array[StringName] = [&"cold", &"heat", &"fumes", &"toxins", &"radiation",
	&"wet", &"dark", &"vacuum", &"pressure", &"em", &"resonance", &"time_shear",
	# What the two landscapes added in M2 press with. A landscape declares a
	# hazard and this list is what makes it real, so the two must be added
	# together: `tests/hazards/test_hazards.gd` fails on a landscape that
	# declares a pressure nothing here knows.
	&"glare", &"thirst", &"magnetism", &"collapse"]

## A pressure is seen and heard at FELT, tells on the body at BITE, drains at HARM.
const FELT := 0.25
const BITE := 0.55
const HARM := 0.75
## Gear never takes a pressure away entirely: a trace always shows on the slate.
const RESIST_CAP := 0.9
## Walking is this much slower under one pressure at its worst.
const SLOW := 0.35
## Health lost per world minute at full pressure (about one point every 45 minutes).
const DRAIN_PER_MINUTE := 1.0 / 45.0
## A drain stops here: the weather hollows a body out, it does not kill it.
const HARM_FLOOR := 1
## Levels above this and the air thins and the cold sharpens.
const HIGH_LEVEL := 6
## What the hour alone may add to a dark or a cold place at deepest night, as a
## share of what that landscape declares. A landscape that declares neither gets
## nothing: `BiomeDef.hazards` is the authority on which places are dark and
## which are cold, and the clock never overrules it.
const NIGHT_DARK := 0.6
const NIGHT_COLD := 0.35
## ...and whatever the hour manufactures stays under BITE on its own, so night
## alone never slows a body's legs anywhere.
const NIGHT_MOST := BITE - 0.05

## The first line said when a pressure begins to bite, one per hazard.
const LINES := {
	&"cold": "The cold is getting into you.",
	&"heat": "The heat is standing on you.",
	&"fumes": "The air here is not for breathing.",
	&"toxins": "Whatever is in the air is on your skin now.",
	&"radiation": "Something here is counting against you.",
	&"wet": "You are soaked through.",
	&"dark": "You cannot see what is with you.",
	&"vacuum": "There is not enough air to hold.",
	&"pressure": "The weight of it is on your chest.",
	&"em": "Your teeth are buzzing.",
	&"resonance": "The stone is ringing through you.",
	&"time_shear": "A minute of you is somewhere else.",
	&"glare": "The ground is throwing the sun back at you.",
	&"thirst": "This place is drinking you.",
	&"magnetism": "Everything iron on you is pulling somewhere.",
	&"collapse": "The ground under this is not holding.",
}


## Where a body stands and what the world is doing to it there. Built by
## 52_hazards from the world, or by hand in a test.
class Place:
	extends RefCounted
	## Hazard id -> base strength 0..1, from BiomeDef.hazards.
	var hazards: Dictionary = {}
	var hour := 12.0
	var weather: StringName = &"clear"
	var weather_strength := 0.0
	## -1..1 as Weather gives it; only its size matters to a body.
	var wind := 0.0
	## Terrain level the body stands on (WorldData levels).
	var level := 0
	## 0..1: a roof, a village, a deep canopy, a cave mouth.
	var shelter := 0.0
	## 0..1: how close a lit fire is.
	var fire := 0.0
	var lamp := false
	var in_water := false


## Raw strengths where the body stands, before any gear: hazard id -> 0..1.
## Only hazards that reach anything at all are in the result.
static func felt(place: Place) -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in IDS:
		var v := float(place.hazards.get(id, 0.0))
		if v > 0.0:
			out[id] = v
	_hour_shift(out, place)
	_weather_shift(out, place)
	_height_shift(out, place)
	_answer_shift(out, place)
	for id: StringName in out.keys():
		var v: float = clampf(out[id], 0.0, 1.0)
		if v <= 0.001:
			out.erase(id)
		else:
			out[id] = v
	return out


## What a landscape declares is what it presses at its hardest. The sun decides
## how much of that is on a body now: it takes some of the cold and most of the
## gloom off at midday and gives them back after dark, and the heat is its own,
## so it goes when the sun does. A snowfield at noon is felt; the same snowfield
## at dusk bites; at three in the morning it is dangerous.
##
## The sun here is `FightRules.nightfall`, which is `Weather.night_fall`: the one
## curve the sky is drawn on. Dusk therefore means the dusk the player can SEE
## (18:30-21:00) and not an hour of its own, which is what made that promise
## false for a year (tests/hazards/test_hazards.gd).
static func _hour_shift(out: Dictionary, place: Place) -> void:
	var night := clampf(FightRules.nightfall(place.hour), 0.0, 1.0)
	if out.has(&"cold"):
		out[&"cold"] = float(out[&"cold"]) * (0.62 + 0.38 * night)
	if out.has(&"dark"):
		out[&"dark"] = float(out[&"dark"]) * (0.45 + 0.55 * night)
	if out.has(&"heat"):
		out[&"heat"] = float(out[&"heat"]) * (0.35 + 0.65 * (1.0 - night))
	# Glare is the sun itself coming back off the ground: it is gone the moment
	# the sun is, more completely than heat, which the ground holds on to.
	if out.has(&"glare"):
		out[&"glare"] = float(out[&"glare"]) * (0.05 + 0.95 * (1.0 - night))
	# The field in the dead iron runs off the grid the wood is still wired into,
	# and the grid works the machines' day: it hums up through the morning and
	# sags in the small hours. Without this term it sat at one number at every
	# hour in every weather, alone among the signature pressures (playtest 7).
	if out.has(&"magnetism"):
		out[&"magnetism"] = float(out[&"magnetism"]) * (0.45 + 0.55 * (1.0 - night))
	# A dry land takes water out of a body all day and eases off at night.
	if out.has(&"thirst"):
		out[&"thirst"] = float(out[&"thirst"]) * (0.55 + 0.45 * (1.0 - night))
	# A wet land is damp underfoot; it only soaks a body that is in the water
	# (or, below, out in the rain).
	if out.has(&"wet") and not place.in_water:
		out[&"wet"] = float(out[&"wet"]) * 0.45
	# Night deepens a place's own dark and cold; it does not manufacture either.
	# A coast that declares no dark shows no gauge at midnight, exactly as it did
	# before there were gauges, and a pinewood that declares 0.4 is a place you
	# want a lamp for. The clock is a multiplier on the landscape, never a term
	# of its own (see NIGHT_MOST).
	_add(out, &"dark", minf(NIGHT_DARK * float(place.hazards.get(&"dark", 0.0)), NIGHT_MOST) * night)
	_add(out, &"cold", minf(NIGHT_COLD * float(place.hazards.get(&"cold", 0.0)), NIGHT_MOST) * night)


## What is falling out of the sky, read through the families a hazard knows.
static func _weather_shift(out: Dictionary, place: Place) -> void:
	var s := clampf(place.weather_strength, 0.0, 1.0)
	var kind := place.weather
	var family := Weather.family(kind)
	match family:
		&"rain", &"storm", &"sleet", &"hail":
			_add(out, &"wet", 0.40 * s)
			_add(out, &"cold", 0.20 * s)
			# Rain is the one thing a dry land gives back, and the one thing a
			# heap of swarf cannot stand: it slumps what it soaks.
			_take(out, &"thirst", 0.45 * s)
			_take(out, &"glare", 0.60 * s)
			_add(out, &"collapse", 0.20 * s)
			if family == &"storm":
				_add(out, &"em", 0.20 * s)
				_add(out, &"magnetism", 0.15 * s)
		&"snow", &"blizzard":
			_add(out, &"cold", 0.45 * s)
			_add(out, &"wet", 0.15 * s)
			_add(out, &"dark", 0.25 * s)
			# Sun on fresh snow is the worst glare there is — but only while the
			# air is clear enough to see through it.
			if family == &"snow":
				_add(out, &"glare", 0.25 * s)
		&"fog":
			_add(out, &"dark", 0.20 * s)
			_add(out, &"wet", 0.10 * s)
			_take(out, &"glare", 0.55 * s)
		&"heat":
			_add(out, &"heat", 0.45 * s)
			_add(out, &"thirst", 0.30 * s)
			_add(out, &"glare", 0.35 * s)
		&"ash":
			_add(out, &"fumes", 0.35 * s)
			_add(out, &"toxins", 0.10 * s)
			_add(out, &"dark", 0.15 * s)
		&"dust":
			_add(out, &"fumes", 0.25 * s)
			_add(out, &"dark", 0.10 * s)
			_add(out, &"thirst", 0.20 * s)
			_take(out, &"glare", 0.30 * s)
			if kind == &"dry_storm":
				_add(out, &"em", 0.25 * s)
				_add(out, &"magnetism", 0.20 * s)
	# Wind takes the warmth off a body, and takes much more of it off a cold one.
	var gale := clampf(absf(place.wind), 0.0, 1.0)
	if gale > 0.1:
		_add(out, &"cold", 0.25 * gale * (1.0 if out.has(&"cold") else 0.4))
		# A stack of plate goes over in a gale; nothing else in the list cares.
		if out.has(&"collapse"):
			_add(out, &"collapse", 0.20 * gale)


## High ground is colder, and past the tree line the air thins.
static func _height_shift(out: Dictionary, place: Place) -> void:
	var high := maxi(0, place.level - HIGH_LEVEL)
	if high <= 0:
		return
	_add(out, &"cold", 0.04 * high)
	if out.has(&"vacuum") or out.has(&"pressure"):
		_add(out, &"vacuum", 0.03 * high)


## What the body can do about it where it stands: get under something, stand by
## a fire, light a lamp. Standing in water soaks you whatever the sky is doing.
static func _answer_shift(out: Dictionary, place: Place) -> void:
	if place.in_water:
		out[&"wet"] = 1.0
		_add(out, &"cold", 0.30)
		# Water is water, even a brine pool: standing in it is the answer to a
		# dry land, and nothing throws the sun at you from under your feet.
		_take(out, &"thirst", 0.70)
		_take(out, &"glare", 0.50)
	var roof := clampf(place.shelter, 0.0, 1.0)
	if roof > 0.0:
		_take(out, &"wet", 0.80 * roof)
		_take(out, &"cold", 0.35 * roof)
		_take(out, &"heat", 0.45 * roof)
		_take(out, &"radiation", 0.50 * roof)
		_take(out, &"fumes", 0.20 * roof)
		# Shade is the whole answer to glare, and a roof is somewhere the swarf
		# is not stacked over your head.
		_take(out, &"glare", 0.85 * roof)
		_take(out, &"thirst", 0.25 * roof)
		_take(out, &"collapse", 0.40 * roof)
	var hearth := clampf(place.fire, 0.0, 1.0)
	if hearth > 0.0:
		_take(out, &"cold", 0.70 * hearth)
		_take(out, &"wet", 0.50 * hearth)
		_take(out, &"dark", 0.60 * hearth)
		# The one place a fire is not the answer: it takes the water out of you
		# faster than the flat does, so a camp on the pan is a decision.
		_add(out, &"thirst", 0.15 * hearth * (1.0 if out.has(&"thirst") else 0.0))
	if place.lamp:
		_take(out, &"dark", 0.85)


static func _add(out: Dictionary, id: StringName, v: float) -> void:
	if v <= 0.0:
		return
	out[id] = float(out.get(id, 0.0)) + v


static func _take(out: Dictionary, id: StringName, v: float) -> void:
	if not out.has(id):
		return
	out[id] = maxf(0.0, float(out[id]) - v)


## What the body is left carrying once the gear has taken its share.
## `resist` is hazard id -> 0..1 (Body.resist, written by the gear package).
static func after_resist(raw: Dictionary, resist: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id: Variant in raw:
		var r := clampf(float(resist.get(id, 0.0)), 0.0, RESIST_CAP)
		var v := clampf(float(raw[id]) * (1.0 - r), 0.0, 1.0)
		if v > 0.001:
			out[StringName(id)] = v
	return out


## 0 nothing, 1 felt, 2 biting, 3 harming.
static func level_of(v: float) -> int:
	if v >= HARM:
		return 3
	if v >= BITE:
		return 2
	if v >= FELT:
		return 1
	return 0


## The hardest pressure on the body now, 0 if none.
static func worst(pressure: Dictionary) -> float:
	var top := 0.0
	for id: Variant in pressure:
		top = maxf(top, float(pressure[id]))
	return top


## The id of the hardest pressure (&"" if none), for a cue and a line.
static func worst_id(pressure: Dictionary) -> StringName:
	var top := 0.0
	var which: StringName = &""
	var ids: Array = pressure.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id: Variant in ids:
		if float(pressure[id]) > top:
			top = float(pressure[id])
			which = StringName(id)
	return which


## Multiplier on walking speed: nothing until a pressure bites, then down to
## 1 - SLOW at its worst. Survival multiplies its own move_factor by this.
static func move_factor(pressure: Dictionary) -> float:
	var top := worst(pressure)
	if top < BITE:
		return 1.0
	return 1.0 - SLOW * clampf((top - BITE) / (1.0 - BITE), 0.0, 1.0)


## Health drained over `minutes` of world time. Only the hardest pressure
## drains: two pressures at once are heavy on the legs, not twice as deadly.
static func drain(pressure: Dictionary, minutes: float) -> float:
	var top := worst(pressure)
	if top < HARM:
		return 0.0
	return DRAIN_PER_MINUTE * minutes * clampf((top - HARM) / (1.0 - HARM), 0.0, 1.0)


## Health after a drain: it stops at HARM_FLOOR, so the weather never kills.
static func drained_health(health: int, carried: float) -> int:
	return maxi(HARM_FLOOR, health - floori(carried))


static func line_for(id: StringName) -> String:
	return LINES.get(id, "Something here is working on you.")
