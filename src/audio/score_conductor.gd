class_name ScoreConductor
extends RefCounted
## The score's form over minutes, as rules: which stems sound and how loud, and
## when a phrase is played. Pure (no nodes, no sound), driven by tick(dt, input)
## with explicit time, so the running game (75_music), the offline render
## (ScoreScene, tools/audio.sh --score) and the tests hear the same score.
##
## Input each tick:
##   weights   {landscape id: 0..1} where the listener stands (sums to 1); an
##             ecotone is two of them at once
##   hour      world hour (night deepens and thins the score)
##   weather   {kind, strength}: rain, fog, snow and ash each colour the texture
##   danger    0..1 raw: hostile machines close (the pulse quickens, dissonance
##             rises, and resolves when it passes)
##   near      0..1 raw: hostile machines within earshot but not yet close (only
##             bakes the tense stems ahead)
##   grid      0..1: a machine installation's proximity (a hum and a pulse)
##   sentinel  {land, strength 0..1}: inside a sentinel's reach (its motif)
##
## Form. Time is cut into sections of 40-85 s, each with a density 0 (drone and
## air), 1 (the pad comes), 2 (the pulse and phrases), 3 (all of it, phrases
## often). The density walks a step at a time, never jumping from rest to all,
## and eases between sections over tens of seconds; every layer then rises and
## falls with its own time constant. A new game walks 0, 1, 2 first.
##
## Ecotones. A landscape's drone, pad and air follow its weight with equal power;
## its pulse and phrases follow the square of it, so halfway across a border two
## harmonies overlap in sustained tones while the rhythms step back: a slow
## modulation from one key into the next rather than two songs at once.

const BAR := ScoreLandscapes.BAR

## Seconds a layer takes to come in, and to go (time constants).
const RISE := {&"drone": 9.0, &"pad": 14.0, &"pulse": 9.0, &"texture": 12.0, &"grid": 5.0, &"dissonance": 3.0, &"tense": 2.0}
const FALL := {&"drone": 16.0, &"pad": 20.0, &"pulse": 14.0, &"texture": 16.0, &"grid": 8.0, &"dissonance": 8.0, &"tense": 6.0}
const SECTION_MIN := 40.0
const SECTION_MAX := 85.0
## How long the density takes to reach a new section's (time constant, s).
const FORM_EASE := 16.0
## At most this many sections in a row at density 2 or more before a rest is due.
const BUSY_RUN := 3
## Danger rises fast (a machine is on you) and falls slowly (it takes a while to believe it).
const DANGER_RISE := 1.0
const DANGER_FALL := 6.0
## Danger must have passed this high before its passing is resolved.
const RESOLVE_FROM := 0.55
const RESOLVE_BELOW := 0.18
const RESOLVE_REST := 25.0
const MOTIF_REST := 150.0
## Arriving: this share of the ear in one landscape for this long, not heard lately.
const ARRIVE_PURITY := 0.75
const ARRIVE_HOLD := 8.0
const ARRIVE_REST := 900.0
## Seconds between phrases: at full density, and where phrases just begin.
const PHRASE_GAP_FULL := 20.0
const PHRASE_GAP_SPARSE := 55.0
## No phrase while danger is at least this.
const PHRASE_DANGER := 0.25
## A level this low is silence, and the stem is let go.
const SILENT := 0.0005

## Weather kind -> texture variant it colours the air with.
const WEATHER_TEXTURE := {
	&"rain": ScoreStems.RAIN, &"storm": ScoreStems.RAIN, &"hail": ScoreStems.RAIN,
	&"fog": ScoreStems.FOG,
	&"snow": ScoreStems.SNOW, &"blizzard": ScoreStems.SNOW,
	&"ash": ScoreStems.ASH, &"dust": ScoreStems.ASH, &"sand": ScoreStems.ASH, &"heat": ScoreStems.ASH,
}

var seed_value := 1
## Music clock (s): bar lines fall on whole multiples of BAR from 0.
var time := 0.0
## Form density 0..3, eased; what it is after night thins it.
var density := 0.0
var effective := 0.0
var danger := 0.0
var night := 0.0
var grid := 0.0
var section := 0
var section_start := 0.0
var section_length := SECTION_MIN
var section_density := 0
## Stem key -> level 0..1 (what the players are set to), and what it is easing toward.
var levels: Dictionary = {}
var targets: Dictionary = {}
## Cues fired by the last tick: [key, gain]. Every cue fired: [time, key, gain].
var cues: Array = []
var played: Array = []

var _busy_run := 0
var _pad_b: Dictionary = {}
var _danger_peak := 0.0
var _last_resolve := -INF
var _last_motif := -INF
var _sentinel_was := 0.0
var _next_phrase := INF
var _phrase_count := 0
## Landscape -> its last two phrase shapes (never played again straight away),
## and the section the last phrase was played in.
var _recent_phrases: Dictionary = {}
var _phrase_section := 0
var _pending: Array = []
var _dominant: StringName = &""
var _dominant_since := 0.0
var _announced: Dictionary = {}
var _input: Dictionary = {}


func _init(p_seed: int = 1) -> void:
	seed_value = p_seed
	section_length = _section_length(0)


# ------------------------------------------------------------------ the tick

func tick(dt: float, input: Dictionary) -> void:
	_input = input
	time += dt
	cues.clear()
	_form(dt)
	night = SoundMix.night(float(input.get("hour", 12.0)))
	var raw_danger := clampf(float(input.get("danger", 0.0)), 0.0, 1.0)
	danger += (raw_danger - danger) * (1.0 - exp(-dt / (DANGER_RISE if raw_danger > danger else DANGER_FALL)))
	var raw_grid := clampf(float(input.get("grid", 0.0)), 0.0, 1.0)
	grid += (raw_grid - grid) * (1.0 - exp(-dt / 4.0))
	effective = clampf(density - 1.2 * night, 0.0, 3.0)
	var weights: Dictionary = input.get("weights", {})
	var weather: Dictionary = input.get("weather", {})
	var sentinel: Dictionary = input.get("sentinel", {})
	var sentinel_s := clampf(float(sentinel.get("strength", 0.0)), 0.0, 1.0)
	targets = {}
	for land: StringName in weights:
		var w := clampf(float(weights[land]), 0.0, 1.0)
		if w > 0.001:
			_targets_for(land, w, weather, sentinel_s, dt)
	_ease(dt)
	_phrases(weights, dt)
	_resolve(weights)
	_motif(weights, sentinel, sentinel_s)
	_fire()


## A stem's share of the mix for one landscape at weight w.
func _targets_for(land: StringName, w: float, weather: Dictionary, sentinel_s: float, dt: float) -> void:
	var bed := sin(w * PI * 0.5)
	var mel := w * w
	var n := night * PI * 0.5
	var eff := effective
	_add(ScoreStems.key_for(land, &"drone", 0), bed * cos(n) * lerpf(0.8, 1.0, smoothstep(0.0, 1.5, eff)))
	_add(ScoreStems.key_for(land, &"drone", 1), bed * sin(n))
	var kind: StringName = StringName(weather.get("kind", &"clear"))
	var colour := int(WEATHER_TEXTURE.get(kind, -1))
	var c := smoothstep(0.12, 0.6, float(weather.get("strength", 0.0))) if colour >= 0 else 0.0
	_add(ScoreStems.key_for(land, &"texture", ScoreStems.AIR), bed * smoothstep(-0.3, 0.7, eff) * (1.0 - 0.7 * c))
	if colour >= 0:
		_add(ScoreStems.key_for(land, &"texture", colour), bed * c)
	# Which progression: each section picks, per landscape, and the pad turns
	# from one to the other over its own easing.
	var want_b := 1.0 if Rng.hash01(seed_value, section, String(land).hash(), 0x7b) >= 0.5 else 0.0
	var b := float(_pad_b.get(land, want_b))
	b += (want_b - b) * (1.0 - exp(-dt / 12.0))
	_pad_b[land] = b
	var pad := bed * smoothstep(0.5, 1.4, eff) * (1.0 - 0.45 * danger)
	_add(ScoreStems.key_for(land, &"pad", 0), pad * cos(b * PI * 0.5))
	_add(ScoreStems.key_for(land, &"pad", 1), pad * sin(b * PI * 0.5))
	var quick := smoothstep(0.15, 0.55, danger)
	_add(ScoreStems.key_for(land, &"pulse", 0), mel * smoothstep(1.5, 2.3, eff) * (1.0 - quick))
	_add(ScoreStems.key_for(land, &"pulse", 1), mel * quick)
	_add(ScoreStems.key_for(land, &"dissonance", 0), bed * maxf(smoothstep(0.35, 0.85, danger), 0.4 * sentinel_s))
	_add(ScoreStems.key_for(land, &"grid", 0), w * grid)


func _add(key: StringName, v: float) -> void:
	targets[key] = float(targets.get(key, 0.0)) + v


static func layer_of(key: StringName) -> StringName:
	var k := ScoreStems.parse(key)
	if k.is_empty():
		return &""
	if k["layer"] == &"pulse" and int(k["variant"]) == 1:
		return &"tense"
	return k["layer"]


func _ease(dt: float) -> void:
	for key: StringName in targets:
		if not levels.has(key):
			levels[key] = 0.0
	for key: StringName in levels.keys():
		var target := float(targets.get(key, 0.0))
		var lvl: float = levels[key]
		var layer := layer_of(key)
		var tau := float(RISE.get(layer, 10.0)) if target > lvl else float(FALL.get(layer, 15.0))
		lvl += (target - lvl) * (1.0 - exp(-dt / tau))
		if lvl < SILENT and target <= 0.0:
			levels.erase(key)
		else:
			levels[key] = lvl


# ------------------------------------------------------------------ form

func _form(dt: float) -> void:
	while time - section_start >= section_length:
		section_start += section_length
		section += 1
		section_length = _section_length(section)
		section_density = _next_density(section)
	density += (float(section_density) - density) * (1.0 - exp(-dt / FORM_EASE))


func _section_length(k: int) -> float:
	# The opening is walked up quickly: air, then the pad, then everything.
	if k == 0:
		return 20.0
	if k == 1:
		return 30.0
	return lerpf(SECTION_MIN, SECTION_MAX, Rng.hash01(seed_value, k, 0x5ec))


## The next section's density from the current one: a step at a time, a rest
## after a busy run, and the opening walked up 0, 1, 2.
func _next_density(k: int) -> int:
	if k <= 2:
		_busy_run = 1 if k == 2 else 0
		return k
	var cur := section_density
	var h := Rng.hash01(seed_value, k, 0xde)
	var step := 0
	if cur >= 3:
		step = -1 if h < 0.6 else 0
	elif cur <= 0:
		step = 1
	else:
		step = -1 if h < 0.35 else (0 if h < 0.55 else 1)
	if _busy_run >= BUSY_RUN and step >= 0:
		step = -1
	var d := clampi(cur + step, 0, 3)
	_busy_run = _busy_run + 1 if d >= 2 else 0
	return d


# ------------------------------------------------------------------ cues

func _dominant_land(weights: Dictionary) -> StringName:
	var best: StringName = &""
	var best_w := 0.0
	for land: StringName in weights:
		if float(weights[land]) > best_w:
			best_w = float(weights[land])
			best = land
	return best


func _phrases(weights: Dictionary, _dt: float) -> void:
	var land := _dominant_land(weights)
	if land == &"":
		return
	var w := float(weights[land])
	# Arriving somewhere is a moment of its own, whatever the density.
	if land != _dominant:
		_dominant = land
		_dominant_since = time
	if w >= ARRIVE_PURITY and time - _dominant_since >= ARRIVE_HOLD and time - float(_announced.get(land, -INF)) >= ARRIVE_REST and danger < PHRASE_DANGER:
		_announced[land] = time
		_queue_phrase(land, 0.9)
		_next_phrase = time + _phrase_gap()
		return
	if effective < 1.6 or danger >= PHRASE_DANGER or w * w < 0.3:
		_next_phrase = INF
		return
	if _next_phrase == INF:
		# The first phrase of a stretch comes sooner than the ones after it.
		_next_phrase = time + _phrase_gap() * lerpf(0.25, 0.8, Rng.hash01(seed_value, _phrase_count, 0x9f))
	elif time >= _next_phrase:
		_queue_phrase(land, w * w)
		_next_phrase = time + _phrase_gap()


func _phrase_gap() -> float:
	var u := clampf((effective - 1.6) / 1.4, 0.0, 1.0)
	return lerpf(PHRASE_GAP_SPARSE, PHRASE_GAP_FULL, u) * lerpf(1.0, 2.0, night) * lerpf(0.85, 1.15, Rng.hash01(seed_value, _phrase_count, 0x9e))


## The shape the next phrase in `land` will be: chosen by the world, the
## landscape, how many phrases have played and the section the last one played
## in, never one of that landscape's last two. It holds until that phrase is
## played, so what wanted() bakes ahead is what is heard.
func next_phrase_variant(land: StringName) -> int:
	var count := int(ScoreStems.LAYERS[&"melody"]["variants"])
	var recent: Array = _recent_phrases.get(land, [])
	var choices: Array[int] = []
	for v in count:
		if not recent.has(v):
			choices.append(v)
	var h := Rng.hash_ints(seed_value, String(land).hash(), _phrase_count, _phrase_section, 0x9d)
	return choices[h % choices.size()]


func _queue_phrase(land: StringName, gain: float) -> void:
	var v := next_phrase_variant(land)
	var recent: Array = _recent_phrases.get(land, [])
	recent.append(v)
	_recent_phrases[land] = recent.slice(-2)
	_phrase_count += 1
	_phrase_section = section
	_queue(ScoreStems.key_for(land, &"melody", v), gain)


func _resolve(weights: Dictionary) -> void:
	_danger_peak = maxf(_danger_peak, danger)
	if danger < RESOLVE_BELOW and _danger_peak >= RESOLVE_FROM:
		_danger_peak = 0.0
		var land := _dominant_land(weights)
		if land != &"" and time - _last_resolve >= RESOLVE_REST:
			_last_resolve = time
			_queue(ScoreStems.key_for(land, &"resolve", 0), float(weights[land]))


func _motif(weights: Dictionary, sentinel: Dictionary, s: float) -> void:
	if s >= 0.5 and _sentinel_was < 0.5 and time - _last_motif >= MOTIF_REST:
		var land: StringName = StringName(sentinel.get("land", &""))
		if land == &"":
			land = _dominant_land(weights)
		if land != &"":
			_last_motif = time
			_queue(ScoreStems.key_for(land, &"motif", 0), 1.0)
	_sentinel_was = s


## Cues wait for the next bar line, so phrases fall in time with the loops.
func _queue(key: StringName, gain: float) -> void:
	var at := ceilf(time / BAR - 0.02) * BAR
	_pending.append([at, key, gain])


func _fire() -> void:
	var i := 0
	while i < _pending.size():
		var p: Array = _pending[i]
		if time >= float(p[0]):
			cues.append([p[1], p[2]])
			played.append([time, p[1], p[2]])
			_pending.remove_at(i)
		else:
			i += 1


# ------------------------------------------------------------------ baking

## Stems that are sounding or may be wanted soon, loudest first: what to bake.
func wanted() -> Array[StringName]:
	var out: Array[StringName] = []
	var keys := levels.keys()
	for key: StringName in targets:
		if not keys.has(key):
			keys.append(key)
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return maxf(float(levels.get(a, 0.0)), float(targets.get(a, 0.0))) > maxf(float(levels.get(b, 0.0)), float(targets.get(b, 0.0))))
	for key: StringName in keys:
		if maxf(float(levels.get(key, 0.0)), float(targets.get(key, 0.0))) > 0.002:
			out.append(key)
	var weights: Dictionary = _input.get("weights", {})
	var land := _dominant_land(weights)
	if land == &"":
		return out
	var ahead: Array[StringName] = []
	for p: Array in _pending:
		ahead.append(p[1])
	ahead.append(ScoreStems.key_for(land, &"melody", next_phrase_variant(land)))
	ahead.append(ScoreStems.key_for(land, &"pad", 0))
	ahead.append(ScoreStems.key_for(land, &"pad", 1))
	ahead.append(ScoreStems.key_for(land, &"pulse", 0))
	var hour := float(_input.get("hour", 12.0))
	if night > 0.0 or SoundMix.night(hour + 1.0) > 0.0:
		ahead.append(ScoreStems.key_for(land, &"drone", 1))
	if night < 1.0 or SoundMix.night(hour + 1.0) < 1.0:
		ahead.append(ScoreStems.key_for(land, &"drone", 0))
	if float(_input.get("near", 0.0)) > 0.0 or danger > 0.01:
		ahead.append(ScoreStems.key_for(land, &"pulse", 1))
		ahead.append(ScoreStems.key_for(land, &"dissonance", 0))
		ahead.append(ScoreStems.key_for(land, &"resolve", 0))
	if float((_input.get("sentinel", {}) as Dictionary).get("strength", 0.0)) > 0.0:
		ahead.append(ScoreStems.key_for(land, &"motif", 0))
	for key in ahead:
		if not out.has(key):
			out.append(key)
	return out


## Where the score bus's low-pass sits: open by day, closed down at night (the
## score goes deeper), and muffled further in fog and falling snow.
static func bus_cutoff(night_share: float, weather: Dictionary) -> float:
	var s := clampf(float(weather.get("strength", 0.0)), 0.0, 1.0)
	var hz := lerpf(14000.0, 3200.0, clampf(night_share, 0.0, 1.0))
	match StringName(weather.get("kind", &"clear")):
		&"fog": hz *= lerpf(1.0, 0.45, s)
		&"snow", &"blizzard": hz *= lerpf(1.0, 0.7, s)
	return hz
