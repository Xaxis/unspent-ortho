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
	&"wet", &"dark", &"vacuum", &"pressure", &"em", &"resonance", &"time_shear"]

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
static func _hour_shift(out: Dictionary, place: Place) -> void:
	var night := clampf(FightRules.nightfall(place.hour), 0.0, 1.0)
	if out.has(&"cold"):
		out[&"cold"] = float(out[&"cold"]) * (0.62 + 0.38 * night)
	if out.has(&"dark"):
		out[&"dark"] = float(out[&"dark"]) * (0.45 + 0.55 * night)
	if out.has(&"heat"):
		out[&"heat"] = float(out[&"heat"]) * (0.35 + 0.65 * (1.0 - night))
	# A wet land is damp underfoot; it only soaks a body that is in the water
	# (or, below, out in the rain).
	if out.has(&"wet") and not place.in_water:
		out[&"wet"] = float(out[&"wet"]) * 0.45
	_add(out, &"dark", 0.75 * night)
	_add(out, &"cold", 0.30 * night)


## What is falling out of the sky, read through the families a hazard knows.
static func _weather_shift(out: Dictionary, place: Place) -> void:
	var s := clampf(place.weather_strength, 0.0, 1.0)
	var kind := place.weather
	var family := Weather.family(kind)
	match family:
		&"rain", &"storm", &"sleet", &"hail":
			_add(out, &"wet", 0.40 * s)
			_add(out, &"cold", 0.20 * s)
			if family == &"storm":
				_add(out, &"em", 0.20 * s)
		&"snow", &"blizzard":
			_add(out, &"cold", 0.45 * s)
			_add(out, &"wet", 0.15 * s)
			_add(out, &"dark", 0.25 * s)
		&"fog":
			_add(out, &"dark", 0.20 * s)
			_add(out, &"wet", 0.10 * s)
		&"heat":
			_add(out, &"heat", 0.45 * s)
		&"ash":
			_add(out, &"fumes", 0.35 * s)
			_add(out, &"toxins", 0.10 * s)
			_add(out, &"dark", 0.15 * s)
		&"dust":
			_add(out, &"fumes", 0.25 * s)
			_add(out, &"dark", 0.10 * s)
			if kind == &"dry_storm":
				_add(out, &"em", 0.25 * s)
	# Wind takes the warmth off a body, and takes much more of it off a cold one.
	var gale := clampf(absf(place.wind), 0.0, 1.0)
	if gale > 0.1:
		_add(out, &"cold", 0.25 * gale * (1.0 if out.has(&"cold") else 0.4))


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
	var roof := clampf(place.shelter, 0.0, 1.0)
	if roof > 0.0:
		_take(out, &"wet", 0.80 * roof)
		_take(out, &"cold", 0.35 * roof)
		_take(out, &"heat", 0.45 * roof)
		_take(out, &"radiation", 0.50 * roof)
		_take(out, &"fumes", 0.20 * roof)
	var hearth := clampf(place.fire, 0.0, 1.0)
	if hearth > 0.0:
		_take(out, &"cold", 0.70 * hearth)
		_take(out, &"wet", 0.50 * hearth)
		_take(out, &"dark", 0.60 * hearth)
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
