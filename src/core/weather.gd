class_name Weather
## The sky's rules as pure functions of (seed, world minute, country): weather
## spells, wind, lightning, the night, the season and the tide. No nodes, no
## colours; the renderers in src/render/weather/ and 10_sky draw what this says.
##
## Contract (CLAUDE.md, Weather):
##   Weather.at(seed, minutes)                -> {kind: StringName, strength: float, wind: float}
##   Weather.at_place(seed, minutes, country) -> same, for one country
##
## A spell lasts SPELL_MINUTES (17 h, coprime with the day, so a storm visits
## every hour of the clock over the weeks). Its strength is sin^2 over the spell,
## so it is 0 exactly at the joins and the kind only ever changes where nothing
## is falling. One roll per spell is shared by every country and read through
## each country's table, so a front that rains on the coast snows on the
## snowfield and drops ash on the burning at the same moment.

const SPELL_MINUTES := 1020.0
## After this day fair weather hardens to grey. (source: Turning = 22)
const TURNING_DAY := 22
## The one autumn: the light drains over this many days, then stays drained.
const SEASON_DAYS := 34.0
## Night at its deepest removes this share of the light. (source)
const DARKEST := 0.62

const CLEAR := &"clear"
const GREY := &"grey"
const RAIN := &"rain"
const STORM := &"storm"
const FOG := &"fog"
const HAIL := &"hail"
const SNOW := &"snow"
const BLIZZARD := &"blizzard"
const ASH := &"ash"
const HEAT := &"heat"
const DUST := &"dust"

const KINDS: Array[StringName] = [CLEAR, GREY, RAIN, STORM, FOG, HAIL, SNOW, BLIZZARD, ASH, HEAT, DUST]

## Per country id (Country enum order: sea, coast, moss, pinewood, snowfield,
## bonelands, burning): [kind, weight] with weights summing to 100. Numbers are
## the source's rolls, with sand renamed to dust on the bones and to ash-fall in
## the burning, heat haze added to the bones, and more fog in the moss.
const TABLES: Array = [
	[[CLEAR, 22], [GREY, 30], [RAIN, 20], [FOG, 14], [STORM, 14]],
	[[CLEAR, 26], [GREY, 28], [RAIN, 22], [FOG, 8], [HAIL, 6], [STORM, 10]],
	[[CLEAR, 18], [GREY, 28], [RAIN, 26], [FOG, 20], [STORM, 8]],
	[[CLEAR, 22], [GREY, 32], [RAIN, 26], [FOG, 12], [STORM, 8]],
	[[CLEAR, 30], [GREY, 26], [SNOW, 30], [HAIL, 6], [BLIZZARD, 8]],
	[[CLEAR, 26], [GREY, 20], [DUST, 20], [HEAT, 14], [FOG, 10], [STORM, 10]],
	[[CLEAR, 30], [HEAT, 28], [ASH, 28], [GREY, 14]],
]

## How much a kind pushes the wind at full strength (fog and heat are still air).
const WIND_PUSH := {
	&"clear": 0.0, &"grey": 0.2, &"rain": 0.4, &"storm": 1.3, &"fog": -0.75, &"hail": 0.8,
	&"snow": 0.1, &"blizzard": 1.5, &"ash": -0.3, &"heat": -0.6, &"dust": 1.0,
}

## Sight is cut by c * strength. (source; blizzard and ash added)
const SIGHT_CUT := {
	&"dust": 0.55, &"fog": 0.45, &"storm": 0.30, &"blizzard": 0.45, &"snow": 0.25,
	&"hail": 0.20, &"ash": 0.25, &"rain": 0.10,
}

## Set only from BootOptions (--weather=kind:strength) so shots and every system
## that asks see the same forced sky. Empty = the rules decide.
static var forced_kind: StringName = &""
static var forced_strength := 0.0


static func force(kind: StringName, strength: float) -> void:
	forced_kind = kind
	forced_strength = clampf(strength, 0.0, 1.0)


static func unforce() -> void:
	forced_kind = &""
	forced_strength = 0.0


## The weather where no country is named: the coast's reading of the front.
static func at(seed_value: int, minutes: float) -> Dictionary:
	return at_place(seed_value, minutes, Country.COAST)


static func at_place(seed_value: int, minutes: float, country: int) -> Dictionary:
	var kind: StringName
	var strength: float
	if forced_kind != &"":
		kind = forced_kind
		strength = forced_strength
	else:
		var s := spell_index(seed_value, minutes)
		# The season is read where the spell begins, or the Turning would flip a
		# fair spell to grey at midnight with rain half-fallen.
		kind = kind_for(seed_value, s, country, day_of(spell_start(seed_value, s)))
		strength = 0.0 if kind == CLEAR else pow(sin(PI * spell_phase(seed_value, minutes)), 2.0)
	return {"kind": kind, "strength": strength, "wind": wind_at(seed_value, minutes, kind, strength)}


## Spells are offset per seed so every world does not start on the same beat.
static func _offset(seed_value: int) -> float:
	return Rng.hash01(seed_value, 0x5E11) * SPELL_MINUTES


static func spell_index(seed_value: int, minutes: float) -> int:
	return floori((minutes + _offset(seed_value)) / SPELL_MINUTES)


## World minute at which spell `spell` begins.
static func spell_start(seed_value: int, spell: int) -> float:
	return spell * SPELL_MINUTES - _offset(seed_value)


## 0 at the start of a spell, 1 at its end.
static func spell_phase(seed_value: int, minutes: float) -> float:
	var t := (minutes + _offset(seed_value)) / SPELL_MINUTES
	return t - floorf(t)


## World day, 0-based (day 0 is "day 1" on the clock).
static func day_of(minutes: float) -> int:
	return floori(minutes / 1440.0)


static func kind_for(seed_value: int, spell: int, country: int, day: int = 0) -> StringName:
	var table: Array = TABLES[clampi(country, 0, TABLES.size() - 1)]
	var r := Rng.hash_ints(seed_value, spell, 0x3EA7) % 100
	var kind: StringName = CLEAR
	var acc := 0
	for row: Array in table:
		acc += int(row[1])
		if r < acc:
			kind = row[0]
			break
	if kind == CLEAR and day + 1 > TURNING_DAY:
		kind = GREY
	return kind


## Scalar wind -1..1 (no bearing yet). Continuous in time: the base is a sum of
## slow seeded waves and the kind's push is scaled by strength, which is 0
## wherever the kind can change.
static func wind_at(seed_value: int, minutes: float, kind: StringName, strength: float) -> float:
	var a := Rng.hash01(seed_value, 0x817D) * TAU
	var b := Rng.hash01(seed_value, 0x817E) * TAU
	var c := Rng.hash01(seed_value, 0x817F) * TAU
	var base := 0.5 * sin(TAU * minutes / 397.0 + a) + 0.3 * sin(TAU * minutes / 151.0 + b) + 0.12 * sin(TAU * minutes / 37.0 + c)
	var push: float = WIND_PUSH.get(kind, 0.0)
	var w := base * (1.0 + push * strength)
	# Strong kinds never fall calm: lift the magnitude, keep the sign. A soft sign,
	# so the wind does not jump when the base crosses zero mid-storm.
	if push > 0.5:
		w += clampf(base * 4.0, -1.0, 1.0) * 0.35 * push * strength
	return clampf(w, -1.0, 1.0)


static func sight_factor(kind: StringName, strength: float) -> float:
	return 1.0 - float(SIGHT_CUT.get(kind, 0.0)) * strength


## Lightning in a storm: chance 0.22 * S^2 per world minute (source). Returns the
## fraction of that minute at which the strike lands, or -1 for none.
static func lightning(seed_value: int, minute: int, kind: StringName, strength: float) -> float:
	if kind != STORM:
		return -1.0
	if Rng.hash01(seed_value, minute, 0x7B01) >= 0.22 * strength * strength:
		return -1.0
	return Rng.hash01(seed_value, minute, 0x7B02)


## How far away a strike is, in tiles: storms at their height strike close. (source)
static func strike_distance(seed_value: int, minute: int, strength: float) -> float:
	return maxf(40.0, (7000.0 - 6700.0 * strength) * lerpf(0.6, 1.4, Rng.hash01(seed_value, minute, 0x7B03)))


## What the weather has left on the ground at a place: {snow, ash, wet}, each
## 0..1. A leaky integral of the last SETTLE_HOURS: snow and ash build while
## they fall and melt or blow off slowly after; rain wets fast and dries in a
## couple of hours. Pure, so a shot at 15:00 after a snowy morning shows the
## morning's snow.
const SETTLE_HOURS := 12
const SETTLE_STEP := 30.0
## Per settled thing: what feeds it (kind -> share of strength), minutes to
## build at full strength, minutes to fade once it stops.
const SETTLE := {
	"snow": {"feed": {&"snow": 1.0, &"blizzard": 1.0, &"hail": 0.35}, "build": 150.0, "fade": 540.0},
	"ash": {"feed": {&"ash": 1.0}, "build": 200.0, "fade": 600.0},
	"wet": {"feed": {&"rain": 1.0, &"storm": 1.0, &"hail": 0.6, &"fog": 0.12, &"blizzard": 0.2}, "build": 45.0, "fade": 110.0},
}


static func settled(seed_value: int, minutes: float, country: int) -> Dictionary:
	var out := {"snow": 0.0, "ash": 0.0, "wet": 0.0}
	# Whole steps on a fixed grid, so the answer changes smoothly with time.
	var end := floorf(minutes / SETTLE_STEP) * SETTLE_STEP
	var steps := int(SETTLE_HOURS * 60.0 / SETTLE_STEP)
	var t := end - steps * SETTLE_STEP
	for i in steps + 1:
		var w := at_place(seed_value, t, country)
		_settle_step(out, w.kind, float(w.strength), SETTLE_STEP)
		t += SETTLE_STEP
	# The part of the current step already walked.
	var w := at_place(seed_value, minutes, country)
	_settle_step(out, w.kind, float(w.strength), minutes - end)
	return out


static func _settle_step(out: Dictionary, kind: StringName, strength: float, dt: float) -> void:
	for key: String in SETTLE:
		var spec: Dictionary = SETTLE[key]
		var feed := float((spec.feed as Dictionary).get(kind, 0.0)) * strength
		var c := float(out[key])
		c += feed * (1.0 - c) * dt / float(spec.build)
		c -= (1.0 - feed) * c * dt / float(spec.fade)
		out[key] = clampf(c, 0.0, 1.0)


## Night fall 0..1: up over 20:00-21:00, down over 04:30-06:00. (source)
static func night_fall(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h >= 21.0 or h < 4.5:
		return 1.0
	if h >= 20.0:
		return h - 20.0
	if h < 6.0:
		return 1.0 - (h - 4.5) / 1.5
	return 0.0


## The share of daylight left: 1 by day, 1 - DARKEST * 0.68 (about 0.58) in the
## dead of night. A lamp undoes the difference. (source: lit = 1 - gloom*deep)
static func light_level(hour: float) -> float:
	return 1.0 - night_fall(hour) * DARKEST * 0.68


## 0 at the start of the autumn, 1 once the light has fully drained.
static func season_turn(minutes: float) -> float:
	return clampf(minutes / 1440.0 / SEASON_DAYS, 0.0, 1.0)


## Tide height 0..1: two tides per 24 h 50 min, t = 0 is low water. (source)
static func tide(minutes: float) -> float:
	return 0.5 - 0.5 * cos(TAU * fposmod(minutes, 1490.0) / 745.0)


static func tide_rising(minutes: float) -> bool:
	return fposmod(minutes, 745.0) < 372.5


static func is_low_tide(minutes: float) -> bool:
	return tide(minutes) < 0.34


static func is_high_tide(minutes: float) -> bool:
	return tide(minutes) > 0.72
