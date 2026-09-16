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
##   ready     {landscape id: 0..1} how much of that landscape's score can
##             actually sound yet (its core stems baked). Absent means all of
##             it: the offline render and the tests hear the ideal score.
##   soon      {landscape id: 0..1} landscapes the listener is walking toward,
##             for baking only: never heard, never mixed
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
## falls with its own time constant. A new game walks up through OPENING first,
## a step at a time but quickly, so the whole score is heard within half a
## minute of waking and the slow form of sections and rests begins from there.
##
## Ecotones. A landscape's drone, pad and air follow its weight with equal power
## (the gains' squares sum to one, whatever the number of landscapes in the ear,
## so no border dips or swells); its pulse and phrases follow the square of it,
## so halfway across a border two harmonies overlap in sustained tones while the
## rhythms step back: a slow modulation from one key into the next rather than
## two songs at once. How wide that overlap is comes from the two keys'
## ScoreLandscapes.affinity: landscapes that share a tonal centre lean into each
## other for a whole ecotone, ones whose keys stand far apart turn over in a
## short, marked stretch. Nothing is ever cut: every gain moves continuously.
##
## Never collapsing. A landscape is only crossfaded INTO as far as it can
## actually sound: `ready` scales its share, and what is left is given back to
## the landscapes that can. Walk or teleport faster than the bake and the score
## keeps playing what it has and completes the turn when the stems arrive,
## instead of falling silent halfway.

const BAR := ScoreLandscapes.BAR

## Seconds a layer takes to come in, and to go (time constants).
const RISE := {&"drone": 9.0, &"pad": 14.0, &"pulse": 9.0, &"texture": 12.0, &"grid": 5.0, &"dissonance": 3.0, &"tense": 2.0}
const FALL := {&"drone": 16.0, &"pad": 20.0, &"pulse": 14.0, &"texture": 16.0, &"grid": 8.0, &"dissonance": 8.0, &"tense": 6.0}
const SECTION_MIN := 40.0
const SECTION_MAX := 85.0
## How long the density takes to reach a new section's (time constant, s).
const FORM_EASE := 16.0
## The opening: [seconds, density] per section before the form starts walking.
## A player must hear the whole score within half a minute of waking, not after
## a minute and a half, so these are short and eased quickly (OPEN_EASE); what
## follows is the slow form of sections and rests.
const OPENING: Array = [[5.0, 0], [7.0, 1], [10.0, 2], [16.0, 3]]
const OPEN_EASE := 5.0
## How long a landscape's share follows its readiness and the ear (time constant,
## s): slow enough that a stem arriving never steps the mix, quick enough that a
## teleport is a turn and not a wait.
const READY_EASE := 1.5
const BLEND_EASE := 2.5
## The sharpest an ecotone's crossfade gets, for two keys with nothing in common:
## the overlap narrows toward the border but never becomes a cut.
const CROSS_SHARP := 3.0
## A landscape under this share of the ear is not mixed at all.
const BLEND_FLOOR := 0.002
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
## However the form moves, two phrases are never queued nearer than this: the
## arrival phrase and the first of a stretch are both allowed to come early, but
## not on top of what just played. Each waits for its own bar line, so what is
## heard between them is this less at most one bar.
const PHRASE_MIN_GAP := 18.0
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
## Landscape -> share of the ear it is actually mixed at (sums to 1), and the
## equal-power gain that share becomes (the squares sum to 1). What the score
## is blending right now, as against the `weights` it was asked for.
var heard_weights: Dictionary = {}
var blend: Dictionary = {}
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
var _last_phrase := -INF
var _phrase_count := 0
## Landscape -> its last two phrase shapes (never played again straight away),
## and the section the last phrase was played in.
var _recent_phrases: Dictionary = {}
var _phrase_section := 0
var _pending: Array = []
## Landscape -> eased readiness, and the raw shares the blend is easing through.
var _ready: Dictionary = {}
var _raw: Dictionary = {}
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
	var weather: Dictionary = input.get("weather", {})
	var sentinel: Dictionary = input.get("sentinel", {})
	var sentinel_s := clampf(float(sentinel.get("strength", 0.0)), 0.0, 1.0)
	_blend(input.get("weights", {}), input.get("ready", {}), dt)
	targets = {}
	for land: StringName in blend:
		_targets_for(land, float(blend[land]), float(heard_weights[land]), weather, sentinel_s, dt)
	_ease(dt)
	_phrases(heard_weights, dt)
	_resolve(heard_weights)
	_motif(heard_weights, sentinel, sentinel_s)
	_fire()


## What is actually blended this tick, from what the ear is in and what can
## sound. Three steps, each of which keeps the mix whole:
##   1. a landscape's share is its weight times its readiness; if nothing is
##      ready the last blend is held, so the score never falls silent waiting;
##   2. the shares ease (BLEND_EASE) and are renormalised to sum to 1, so a
##      stem arriving or a teleport is a turn, never a step;
##   3. near the border the shares are sharpened by how far apart the two keys
##      stand, then mapped equal-power: the gains' squares sum to 1 exactly.
func _blend(weights: Dictionary, ready: Dictionary, dt: float) -> void:
	var want := {}
	var total := 0.0
	for land: StringName in weights:
		var w := clampf(float(weights[land]), 0.0, 1.0)
		if w <= 0.0005:
			continue
		var r := clampf(float(ready.get(land, 1.0)), 0.0, 1.0)
		if not _ready.has(land):
			_ready[land] = r
		else:
			_ready[land] = lerpf(float(_ready[land]), r, 1.0 - exp(-dt / READY_EASE))
		var v := w * float(_ready[land])
		if v > 0.0:
			want[land] = v
			total += v
	if total <= 1e-4:
		# Nothing the ear is in can sound yet: hold what is sounding, or, with
		# nothing sounding at all (a game waking up), aim at the ideal.
		want = _raw.duplicate() if not _raw.is_empty() else weights.duplicate()
	for land: StringName in _raw:
		if not want.has(land):
			want[land] = 0.0
	var eased := 1.0 - exp(-dt / BLEND_EASE)
	var sum := 0.0
	for land: StringName in want:
		var v := lerpf(float(_raw.get(land, 0.0)), float(want[land]), eased)
		if v <= BLEND_FLOOR * 0.25:
			_raw.erase(land)
			continue
		_raw[land] = v
		sum += v
	heard_weights = {}
	var kept := 0.0
	for land: StringName in _raw:
		if float(_raw[land]) / maxf(1e-6, sum) > BLEND_FLOOR:
			heard_weights[land] = float(_raw[land])
			kept += float(_raw[land])
	for land: StringName in heard_weights:
		heard_weights[land] = float(heard_weights[land]) / maxf(1e-9, kept)
	_sharpen()
	var power := 0.0
	var gains := {}
	for land: StringName in heard_weights:
		var g := sin(float(heard_weights[land]) * PI * 0.5)
		gains[land] = g
		power += g * g
	blend = {}
	for land: StringName in gains:
		blend[land] = float(gains[land]) / sqrt(maxf(1e-9, power))


## Narrows the ecotone when the keys in it stand far apart: shares are raised to
## a power set by the least affinity among them, then renormalised. Monotone and
## continuous, so no gain ever jumps; at full affinity it changes nothing.
func _sharpen() -> void:
	if heard_weights.size() < 2:
		return
	var lands: Array = heard_weights.keys()
	var least := 1.0
	for i in lands.size():
		for j in range(i + 1, lands.size()):
			least = minf(least, ScoreLandscapes.affinity(lands[i], lands[j]))
	var k := lerpf(1.0, CROSS_SHARP, 1.0 - least)
	if k <= 1.001:
		return
	var sum := 0.0
	for land: StringName in lands:
		var v := pow(float(heard_weights[land]), k)
		heard_weights[land] = v
		sum += v
	for land: StringName in lands:
		heard_weights[land] = float(heard_weights[land]) / maxf(1e-9, sum)


## A stem's share of the mix for one landscape: `bed` is its equal-power gain,
## `share` its plain share of the ear (the rhythms follow its square).
func _targets_for(land: StringName, bed: float, share: float, weather: Dictionary, sentinel_s: float, dt: float) -> void:
	var w := share
	var mel := share * share
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
	var tau := OPEN_EASE if section < OPENING.size() else FORM_EASE
	density += (float(section_density) - density) * (1.0 - exp(-dt / tau))


func _section_length(k: int) -> float:
	# The opening is walked up quickly: air, then the pad, then all of it, so a
	# player hears the whole score inside the first half minute.
	if k < OPENING.size():
		return float(OPENING[k][0])
	return lerpf(SECTION_MIN, SECTION_MAX, Rng.hash01(seed_value, k, 0x5ec))


## The next section's density from the current one: a step at a time, a rest
## after a busy run, and the opening walked up through OPENING.
func _next_density(k: int) -> int:
	if k < OPENING.size():
		var d := int(OPENING[k][1])
		_busy_run = maxi(0, d - 1) if d >= 2 else 0
		return d
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
	if w >= ARRIVE_PURITY and time - _dominant_since >= ARRIVE_HOLD and time - float(_announced.get(land, -INF)) >= ARRIVE_REST and danger < PHRASE_DANGER and time - _last_phrase >= PHRASE_MIN_GAP:
		_announced[land] = time
		_queue_phrase(land, 0.9)
		_next_phrase = time + _phrase_gap()
		return
	if effective < 1.6 or danger >= PHRASE_DANGER or w * w < 0.3:
		_next_phrase = INF
		return
	if _next_phrase == INF:
		# The first phrase of a stretch comes sooner than the ones after it.
		_next_phrase = maxf(time + _phrase_gap() * lerpf(0.25, 0.8, Rng.hash01(seed_value, _phrase_count, 0x9f)), _last_phrase + PHRASE_MIN_GAP)
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
	_last_phrase = time
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

## The core of a landscape's score: the one drone the hour asks for and its own
## air. Small on purpose, so the core of every landscape around the player can
## be held ready and no border is ever met with nothing to play.
static func core_keys(land: StringName, hour: float) -> Array[StringName]:
	return [
		ScoreStems.key_for(land, &"drone", 1 if SoundMix.night(hour) >= 0.5 else 0),
		ScoreStems.key_for(land, &"texture", ScoreStems.AIR),
	] as Array[StringName]


static func _by_weight(weights: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for land: StringName in weights:
		if float(weights[land]) > 0.001:
			out.append(land)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return float(weights[a]) > float(weights[b]))
	return out


## Stems to bake, in the order they are needed. The cores of the landscapes in
## the ear come first, then the cores of the ones being walked toward (so the
## border is met with a score already in hand), and only then the layers that
## fill the landscape out.
func wanted() -> Array[StringName]:
	var out: Array[StringName] = []
	var hour := float(_input.get("hour", 12.0))
	var weights: Dictionary = _input.get("weights", {})
	for land in _by_weight(weights):
		for key in core_keys(land, hour):
			if not out.has(key):
				out.append(key)
	for land in _by_weight(_input.get("soon", {})):
		if weights.has(land):
			continue
		for key in core_keys(land, hour):
			if not out.has(key):
				out.append(key)
	var keys := levels.keys()
	for key: StringName in targets:
		if not keys.has(key):
			keys.append(key)
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return maxf(float(levels.get(a, 0.0)), float(targets.get(a, 0.0))) > maxf(float(levels.get(b, 0.0)), float(targets.get(b, 0.0))))
	for key: StringName in keys:
		if maxf(float(levels.get(key, 0.0)), float(targets.get(key, 0.0))) > 0.002 and not out.has(key):
			out.append(key)
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
