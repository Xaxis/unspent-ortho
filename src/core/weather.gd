class_name Weather
## The sky's rules as pure functions of (seed, world minute, landscape): weather
## spells, squalls, dawn mist, wind, lightning, the night, the season and the
## tide. No nodes, no colours; the renderers in src/render/weather/ and 10_sky
## draw what this says.
##
## Contract (CLAUDE.md, Weather):
##   Weather.at(seed, minutes)                -> {kind: StringName, strength: float, wind: float, mist: float}
##   Weather.at_place(seed, minutes, country) -> same, for one country
##   Weather.at_type(seed, minutes, type_id)  -> same, for a landscape type id (BiomeDef.id)
##   Weather.family(kind)                     -> the M1 kind a newer kind behaves like, for
##                                               readers that only know the M1 set
##
## A spell lasts SPELL_MINUTES (17 h, coprime with the day, so a storm visits
## every hour of the clock over the weeks). Its strength is sin^2 over the spell,
## so it is 0 exactly at the joins and the kind only ever changes where nothing
## is falling. Inside a spell some kinds come in squalls: bands that sweep in for
## a quarter of an hour and pass, so rain on the coast is an event and not a
## wash. One roll per spell is shared by every landscape and read through each
## landscape's climate, so a front that squalls on the coast snows on the
## snowfield, throws dry lightning over the bonelands and drops ash on the
## burning at the same moment.

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
## M2.0: the landscapes' own weathers.
const DRIZZLE := &"drizzle"
const WHITEOUT := &"whiteout"
const GLARE := &"glare"
const DRY_STORM := &"dry_storm"
const HAZE := &"haze"

const KINDS: Array[StringName] = [CLEAR, GREY, RAIN, STORM, FOG, HAIL, SNOW, BLIZZARD, ASH, HEAT, DUST, DRIZZLE, WHITEOUT, GLARE, DRY_STORM, HAZE]

## What each newer kind behaves like, for a reader that only knows the M1 kinds
## (a sound bed, whether a body gets wet, how far a machine sees).
const FAMILY := {
	&"drizzle": &"rain", &"whiteout": &"blizzard", &"glare": &"heat", &"dry_storm": &"dust", &"haze": &"fog",
}

## A landscape's weather is its own (`BiomeDef.weather`): rows
## [kind, weight, squall] with weights summing to 100. Squall 0..1 is how much
## of the kind's strength comes and goes in passing bands (0 = steady). Rows run
## in the same order of mood everywhere (fair, bleak, falling, lying, severe)
## because the one shared roll is read through every table: the coast's storm is
## the snowfield's whiteout and the bonelands' dry lightning. Every landscape
## keeps a real share of clear days, so weather is an event.
##
## Dawn mist is `BiomeDef.mist`, 0..1 of fog density at its deepest: the moss
## lies drowned in it most mornings, the pinewood holds some under its crowns,
## the coast gets a thin sea fret. Nothing on dry or burning ground.

## How much a kind pushes the wind at full strength (fog and heat are still air).
const WIND_PUSH := {
	&"clear": 0.0, &"grey": 0.2, &"rain": 0.4, &"storm": 1.3, &"fog": -0.75, &"hail": 0.8,
	&"snow": 0.1, &"blizzard": 1.5, &"ash": -0.3, &"heat": -0.6, &"dust": 1.0,
	&"drizzle": -0.4, &"whiteout": 1.6, &"glare": -0.55, &"dry_storm": 1.1, &"haze": -0.7,
}

## Sight is cut by c * strength. (source; blizzard and ash added, M2.0 kinds)
## Every kind that puts anything in the air has a row: a kind nobody wrote one
## for would leave a machine full sight through a whiteout. Only clear and grey
## hide nothing, and nothing here blinds.
const SIGHT_CUT := {
	&"dust": 0.55, &"fog": 0.45, &"storm": 0.30, &"blizzard": 0.45, &"snow": 0.25,
	&"hail": 0.20, &"ash": 0.25, &"rain": 0.10, &"heat": 0.08,
	&"drizzle": 0.15, &"whiteout": 0.75, &"glare": 0.10, &"dry_storm": 0.35, &"haze": 0.35,
}

## Strikes per world minute at full strength (times strength^2). (source: storm 0.22)
const LIGHTNING := {&"storm": 0.22, &"dry_storm": 0.12}

## Minutes between squall bands, before the seed's own stretch.
const SQUALL_MINUTES := 61.0
## What is left of a squally kind's strength between bands, at squall 1.
const SQUALL_FLOOR := 0.12

## Set only from BootOptions (--weather=kind:strength) or a tour's `weather`
## line, so shots and every system that asks see the same forced sky. Empty =
## the rules decide.
static var forced_kind: StringName = &""
static var forced_strength := 0.0
## A held wind -1..1 (`KIND:S:wind=W`), for a frame about what the wind does to
## the grass; NAN = the kind and the clock decide.
static var forced_wind := NAN


static func force(kind: StringName, strength: float, wind: float = NAN) -> void:
	forced_kind = kind
	forced_strength = clampf(strength, 0.0, 1.0)
	forced_wind = clampf(wind, -1.0, 1.0) if not is_nan(wind) else NAN


static func unforce() -> void:
	forced_kind = &""
	forced_strength = 0.0
	forced_wind = NAN


static func family(kind: StringName) -> StringName:
	return FAMILY.get(kind, kind)


## The landscape type id at a type index.
static func type_of(country: int) -> StringName:
	return BiomeRegistry.by_index(country).id


## A landscape's climate rows; a type that declares none reads the coast's.
static func climate(type_id: StringName) -> Array:
	var d := BiomeRegistry.get_def(type_id)
	if d != null and not d.weather.is_empty():
		return d.weather
	return BiomeRegistry.by_index(Country.COAST).weather


## The weather where no landscape is named: the coast's reading of the front.
static func at(seed_value: int, minutes: float) -> Dictionary:
	return at_place(seed_value, minutes, Country.COAST)


static func at_place(seed_value: int, minutes: float, country: int) -> Dictionary:
	return at_type(seed_value, minutes, type_of(country))


static func at_type(seed_value: int, minutes: float, type_id: StringName) -> Dictionary:
	var kind: StringName
	var strength: float
	if forced_kind != &"":
		kind = forced_kind
		strength = forced_strength
	else:
		var s := spell_index(seed_value, minutes)
		# The season is read where the spell begins, or the Turning would flip a
		# fair spell to grey at midnight with rain half-fallen.
		var row := row_for(seed_value, s, type_id, day_of(spell_start(seed_value, s)))
		kind = row[0]
		if kind == CLEAR:
			strength = 0.0
		else:
			strength = pow(sin(PI * spell_phase(seed_value, minutes)), 2.0)
			strength *= squall_gain(seed_value, minutes, float(row[2]))
	var wind := wind_at(seed_value, minutes, kind, strength) if is_nan(forced_wind) else forced_wind
	return {"kind": kind, "strength": strength, "wind": wind, "mist": mist(seed_value, minutes, type_id, kind, strength, wind)}


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
	return row_for(seed_value, spell, type_of(country), day)[0]


## The climate row [kind, weight, squall] a spell rolls in a landscape.
static func row_for(seed_value: int, spell: int, type_id: StringName, day: int = 0) -> Array:
	var table := climate(type_id)
	var r := Rng.hash_ints(seed_value, spell, 0x3EA7) % 100
	var row: Array = table[0]
	var acc := 0
	for t: Array in table:
		acc += int(t[1])
		if r < acc:
			row = t
			break
	if row[0] == CLEAR and day + 1 > TURNING_DAY:
		return [GREY, row[1], 0.0]
	return row


## 0..1: a squall band passing at this minute. Smooth and seeded: two slow
## waves, the second stretching the first, cut into bands about a third of the
## time.
static func squall_pulse(seed_value: int, minutes: float) -> float:
	var a := Rng.hash01(seed_value, 0x5A11) * TAU
	var b := Rng.hash01(seed_value, 0x5A12) * TAU
	var stretch := lerpf(0.8, 1.25, Rng.hash01(seed_value, 0x5A13))
	var w := 0.7 * (0.5 + 0.5 * sin(TAU * minutes / (SQUALL_MINUTES * stretch) + a)) + 0.3 * (0.5 + 0.5 * sin(TAU * minutes / 23.0 + b))
	return smoothstep(0.42, 0.82, w)


## The share of a kind's strength that shows at this minute: 1 for a steady
## kind; between SQUALL_FLOOR and 1 as squall bands pass for a squally one.
static func squall_gain(seed_value: int, minutes: float, squall: float) -> float:
	if squall <= 0.0:
		return 1.0
	var floor_share := lerpf(1.0, SQUALL_FLOOR, clampf(squall, 0.0, 1.0))
	return lerpf(floor_share, 1.0, squall_pulse(seed_value, minutes))


## Dawn mist 0..1 in a landscape: forms in the small hours, deepest about
## sunrise, burnt off by mid-morning; thicker on some mornings than others,
## blown away by a wind, beaten down by anything falling hard.
static func mist(seed_value: int, minutes: float, type_id: StringName, kind: StringName = CLEAR, strength: float = 0.0, wind: float = 0.0) -> float:
	var d := BiomeRegistry.get_def(type_id)
	var deep := d.mist if d != null else 0.0
	if deep <= 0.0:
		return 0.0
	var h := fposmod(minutes, 1440.0) / 60.0
	var shape := smoothstep(2.5, 5.2, h) * (1.0 - smoothstep(6.8, 9.5, h))
	if shape <= 0.0:
		return 0.0
	var morning := lerpf(0.45, 1.0, Rng.hash01(seed_value, day_of(minutes), 0x3157))
	var still := 1.0 - clampf(absf(wind) * 1.6, 0.0, 1.0)
	var beaten := 1.0 - clampf(float(WIND_PUSH.get(kind, 0.0)), 0.0, 1.0) * strength
	return clampf(deep * shape * morning * still * beaten, 0.0, 1.0)


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


## Does this kind throw lightning at all?
static func strikes(kind: StringName) -> bool:
	return LIGHTNING.has(kind)


## Lightning: chance rate * S^2 per world minute (source: storms 0.22; dry
## lightning over the bonelands is sparser). Returns the fraction of that minute
## at which the strike lands, or -1 for none.
static func lightning(seed_value: int, minute: int, kind: StringName, strength: float) -> float:
	if not LIGHTNING.has(kind):
		return -1.0
	if Rng.hash01(seed_value, minute, 0x7B01) >= float(LIGHTNING[kind]) * strength * strength:
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
	"snow": {"feed": {&"snow": 1.0, &"blizzard": 1.0, &"whiteout": 1.0, &"hail": 0.35}, "build": 150.0, "fade": 540.0},
	"ash": {"feed": {&"ash": 1.0, &"haze": 0.2}, "build": 200.0, "fade": 600.0},
	"wet": {"feed": {&"rain": 1.0, &"storm": 1.0, &"drizzle": 0.75, &"hail": 0.6, &"fog": 0.12, &"blizzard": 0.2}, "build": 45.0, "fade": 110.0},
}


static func settled(seed_value: int, minutes: float, country: int) -> Dictionary:
	return settled_type(seed_value, minutes, type_of(country))


static func settled_type(seed_value: int, minutes: float, type_id: StringName) -> Dictionary:
	var out := {"snow": 0.0, "ash": 0.0, "wet": 0.0}
	# Whole steps on a fixed grid, so the answer changes smoothly with time.
	var end := floorf(minutes / SETTLE_STEP) * SETTLE_STEP
	var steps := int(SETTLE_HOURS * 60.0 / SETTLE_STEP)
	var t0 := end - steps * SETTLE_STEP
	var frac := (minutes - end) / SETTLE_STEP
	# The window slides: its oldest step shrinks as the newest part grows, and
	# every step reads the sky at its own middle, so crossing a step's end
	# changes nothing and a squall builds cover smoothly.
	for i in steps:
		var w := at_type(seed_value, t0 + (i + 0.5) * SETTLE_STEP, type_id)
		_settle_step(out, w.kind, float(w.strength), SETTLE_STEP * (1.0 - frac) if i == 0 else SETTLE_STEP)
	var w := at_type(seed_value, (end + minutes) * 0.5, type_id)
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


## Where the evening turn begins and where it lands. The source crushed the whole
## of it into 20:00-21:00, which gave the game a switch and no dusk: every hour
## before 20:00 was full day and the half hour after it dropped a third of the
## frame's light at once. Dusk is two and a half hours of falling light instead,
## so the hatching, the ink's blue, the lamps and the gloom all walk down one
## slow curve and no half hour of it is a step.
const DUSK_START := 18.5
const DUSK_END := 21.0
## The morning's own shoulder, kept where the source put it.
const DAWN_START := 4.5
const DAWN_END := 6.0


## Night fall 0..1: up over DUSK_START-DUSK_END, down over 04:30-06:00. Eased at
## both ends (smoothstep), so the turn begins and lands without a corner.
static func night_fall(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h >= DUSK_END or h < DAWN_START:
		return 1.0
	if h >= DUSK_START:
		return smoothstep(DUSK_START, DUSK_END, h)
	if h < DAWN_END:
		return 1.0 - smoothstep(DAWN_START, DAWN_END, h)
	return 0.0


## The share of daylight left: 1 by day, 1 - DARKEST * 0.68 (about 0.58) in the
## dead of night. A lamp undoes the difference. (source: lit = 1 - gloom*deep)
static func light_level(hour: float) -> float:
	return 1.0 - night_fall(hour) * DARKEST * 0.68


## 0 at the start of the autumn, 1 once the light has fully drained.
## THE MOON'S MONTH, in game days, and the world minute it is full at: 23:00
## on the first day, so the first night of every game (and every frame shot on
## day 1) is the full moon it always was.
const LUNAR_DAYS := 12.0
const MOON_FULL_AT := 23.0 * 60.0


## Where the moon is in its month at world minute `minutes`: 0 full, 0.5 new,
## back to full at 1. Time, not worldgen: nothing a seed makes reads it.
static func moon_phase(minutes: float) -> float:
	return fposmod((minutes - MOON_FULL_AT) / (LUNAR_DAYS * 1440.0), 1.0)


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
