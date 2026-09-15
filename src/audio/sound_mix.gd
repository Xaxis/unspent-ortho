class_name SoundMix
## The mix as rules: bus layout and levels, the heard-level measure, how beds
## are weighted by where the player stands and what the weather does, and which
## machine is heard. Pure (no nodes), so the running game, the tests and
## tools/audio.sh all use the same numbers.
##
## Reference: 0 dB heard is the weather bed (rain) at full strength.
##   thunder +6..+10 | world events -4..+5 | interface <= -6
## heard = rms(loudest 0.5 s) x bus x call gain. Nothing carries its weight
## below 120 Hz (judge on a laptop). Hearing takes no penalty from weather or
## dark: you hear a machine before you see it.

const WEATHER_PATH := "res://src/core/weather.gd"

## [name, send, volume dB]. Made in code by AudioSystem; Master gets a limiter.
const BUSES := [
	[&"Music", &"Master", -8.0],
	[&"SFX", &"Master", -2.5],
	[&"SfxFar", &"SFX", -1.0],
	[&"Ambience", &"Master", -11.9],
	[&"Machines", &"Master", -11.9],
	[&"UI", &"Master", -6.0],
]

## Footfalls: tiles travelled per step sound when walking and running, and the
## shortest gap between two (so a stutter at a wall does not machine-gun).
const STRIDE_WALK := 0.95
const STRIDE_RUN := 1.3
const STEP_MIN_GAP := 0.2

## One-shots further than this are not heard; past SFX_FAR they are dull and wet.
const SFX_RANGE := 40.0
const SFX_FAR := 9.0

## Country -> the bed named after what makes its sound.
const COUNTRY_BED := {
	Country.SEA: &"bed_wind",
	Country.COAST: &"bed_wind",
	Country.MOSS: &"bed_moss",
	Country.PINEWOOD: &"bed_pines",
	Country.SNOWFIELD: &"bed_snowfield",
	Country.BONELANDS: &"bed_bones",
	Country.BURNING: &"bed_burning",
}

## Weather kind -> its bed (kinds with no bed only damp or colour the others).
const WEATHER_BED := {
	&"rain": &"weather_rain",
	&"storm": &"weather_storm",
	&"hail": &"weather_hail",
	&"snow": &"weather_snow",
	&"sand": &"weather_sand",
}

## How much a weather kind at full strength softens the country beds.
const WEATHER_DAMP := {
	&"fog": 0.8, &"snow": 0.7, &"storm": 0.5, &"rain": 0.8, &"hail": 0.75, &"sand": 0.6,
}

## Absolute heard level (dBFS, loudest 0.5 s RMS after its bus) of the weather
## bed at full strength: 0 dB of the mix sheet. Game-typical loudness with
## headroom for thunder at +10.
const REF_DBFS := -24.0

static var _weather_script: GDScript
static var _weather_checked := false


static func bus_db(bus: StringName) -> float:
	var total := 0.0
	var at := bus
	for guard in 4:
		var found := false
		for row: Array in BUSES:
			if row[0] == at:
				total += float(row[2])
				at = row[1]
				found = true
				break
		if not found:
			break
	return total


## How loud a baked sound is heard, measured from its samples, its bus and its
## call gain, in dB relative to the weather bed at full strength.
static func heard_db(b: SoundBank.Baked, extra_db: float = 0.0) -> float:
	var r := Synth.loudest_rms(b.samples, b.rate, 0.5)
	return 20.0 * log(maxf(1e-9, r)) / log(10.0) + bus_db(b.bus) + b.gain_db + extra_db - REF_DBFS


# ------------------------------------------------------------------ beds

## Country bed weights at a tile: the tile's country, turning toward its
## neighbour by WorldData.blend (0 pure, 0.5 on the border).
static func country_weights(world: WorldData, p: Vector2) -> Dictionary:
	var out := {}
	var x := clampi(floori(p.x), 0, world.size - 1)
	var y := clampi(floori(p.y), 0, world.size - 1)
	var i := y * world.size + x
	var c: int = world.country[i]
	var c2: int = world.country2[i] if world.country2.size() > i else c
	var bl: float = clampf(world.blend[i], 0.0, 1.0) if world.blend.size() > i else 0.0
	var a: StringName = COUNTRY_BED.get(c, &"bed_wind")
	out[a] = 1.0 - bl
	if bl > 0.0:
		var b: StringName = COUNTRY_BED.get(c2, &"bed_wind")
		out[b] = float(out.get(b, 0.0)) + bl
	return out


## The country the player is most in (for music), from the same weights.
static func dominant_country(world: WorldData, p: Vector2) -> Dictionary:
	var x := clampi(floori(p.x), 0, world.size - 1)
	var y := clampi(floori(p.y), 0, world.size - 1)
	var i := y * world.size + x
	var c: int = world.country[i]
	var bl: float = world.blend[i] if world.blend.size() > i else 0.0
	if c == Country.SEA:
		c = Country.COAST
	return {"country": c, "purity": 1.0 - clampf(bl, 0.0, 1.0)}


static func is_sea(world: WorldData, x: int, y: int) -> bool:
	if not world.in_bounds(x, y):
		return true
	var g := world.ground[y * world.size + x]
	return world.level[y * world.size + x] <= 0 and (g == Ground.WATER or g == Ground.DEEP_WATER)


## Nearest tile matching `match_fn(world, x, y)` within radius, coarse then fine,
## and the direction the matches lie in, weighted by closeness.
## Returns {distance: float (INF if none), direction: Vector2}.
static func nearest(world: WorldData, p: Vector2, radius: int, match_fn: Callable) -> Dictionary:
	var px := floori(p.x)
	var py := floori(p.y)
	var best := INF
	var best_at := Vector2i(px, py)
	var dir := Vector2.ZERO
	for dy in range(-radius, radius + 1, 2):
		for dx in range(-radius, radius + 1, 2):
			if match_fn.call(world, px + dx, py + dy):
				var d := Vector2(dx, dy).length()
				if d < best:
					best = d
					best_at = Vector2i(px + dx, py + dy)
				if d > 0.0:
					dir += Vector2(dx, dy) / (d * maxf(1.0, d * d))
	if best < INF:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var tx := best_at.x + dx
				var ty := best_at.y + dy
				if match_fn.call(world, tx, ty):
					best = minf(best, Vector2(tx + 0.5 - p.x, ty + 0.5 - p.y).length())
	return {"distance": best, "direction": dir.normalized() if dir.length() > 1e-6 else Vector2.ZERO}


static func sea_near(world: WorldData, p: Vector2, radius: int = 24) -> Dictionary:
	return nearest(world, p, radius, is_sea)


static func river_near(world: WorldData, p: Vector2, radius: int = 12) -> Dictionary:
	return nearest(world, p, radius, func(w: WorldData, x: int, y: int) -> bool:
		return w.in_bounds(x, y) and w.ground[y * w.size + x] == Ground.RIVER)


static func shore_weight(sea_distance: float) -> float:
	return pow(clampf(1.0 - (sea_distance - 1.5) / 20.0, 0.0, 1.0), 1.6)


static func river_weight(river_distance: float) -> float:
	return pow(clampf(1.0 - (river_distance - 1.0) / 10.0, 0.0, 1.0), 1.5)


## Gusts: two slow sines multiplied (0.041 and 0.017 Hz, from the source), so
## wind never repeats on a period anyone would notice. 0.1..1.
static func gust(seconds: float) -> float:
	return 0.55 + 0.45 * sin(TAU * 0.041 * seconds) * sin(TAU * 0.017 * seconds + 1.1)


## Every bed's target level 0..1 for a listener. `near_sea` and `near_river`
## come from sea_near/river_near (scanned a few times a second, not per frame).
static func bed_levels(world: WorldData, p: Vector2, weather: Dictionary, near_sea: Dictionary, near_river: Dictionary, seconds: float) -> Dictionary:
	var kind: StringName = weather.get("kind", &"fair")
	var s := clampf(float(weather.get("strength", 0.0)), 0.0, 1.0)
	var wind := clampf(absf(float(weather.get("wind", 0.0))), 0.0, 1.0)
	var g := gust(seconds)
	var out := {}
	var shore := shore_weight(float(near_sea.get("distance", INF)))
	var river := river_weight(float(near_river.get("distance", INF)))
	var damp := lerpf(1.0, float(WEATHER_DAMP.get(kind, 1.0)), s)
	var weights := country_weights(world, p)
	for bed: StringName in weights:
		var w: float = weights[bed]
		var lvl := w * damp * (1.0 - 0.35 * shore)
		match bed:
			&"bed_wind":
				lvl *= (0.55 + 0.45 * wind) * lerpf(0.75, 1.1, g)
			&"bed_pines":
				lvl *= (0.6 + 0.4 * wind) * lerpf(0.8, 1.1, g)
			&"bed_bones":
				lvl *= (0.7 + 0.3 * wind) * lerpf(0.85, 1.05, g)
		out[bed] = float(out.get(bed, 0.0)) + lvl
	out[&"bed_shore"] = shore * lerpf(1.0, 0.8, s * float(kind == &"storm"))
	out[&"bed_river"] = river * damp
	for k: StringName in WEATHER_BED:
		out[WEATHER_BED[k]] = s if kind == k else 0.0
	out[&"weather_gust"] = clampf(smoothstep(0.3, 1.0, wind) * g * g + (0.6 * s if kind == &"storm" else 0.0), 0.0, 1.0)
	return out


# --------------------------------------------------------------- weather

## Weather.at(seed, minutes) when the sky package's core exists, else a fair
## day with a gentle wind that still breathes.
static func weather_at(seed_value: int, minutes: float) -> Dictionary:
	if not _weather_checked:
		_weather_checked = true
		if ResourceLoader.exists(WEATHER_PATH):
			_weather_script = load(WEATHER_PATH)
	if _weather_script == null:
		return {"kind": &"fair", "strength": 0.0, "wind": 0.35 + 0.2 * sin(minutes / 97.0)}
	var raw: Variant = _weather_script.call("at", seed_value, minutes)
	return normalize_weather(raw, _weather_script)


## Whatever shape Weather.at returns (kind as String, StringName or enum int),
## a {kind: StringName lower-case, strength: 0..1, wind: -1..1}.
static func normalize_weather(raw: Variant, script: GDScript = null) -> Dictionary:
	var out := {"kind": &"fair", "strength": 0.0, "wind": 0.0}
	if not raw is Dictionary:
		return out
	var d: Dictionary = raw
	var k: Variant = d.get("kind", &"fair")
	var name := ""
	if k is int and script != null:
		var consts := script.get_script_constant_map()
		for key: String in ["NAMES", "KINDS", "KIND_NAMES"]:
			if consts.has(key) and int(k) >= 0 and int(k) < consts[key].size():
				name = String(consts[key][int(k)])
				break
	elif k is String or k is StringName:
		name = String(k)
	out["kind"] = StringName(name.to_lower()) if name != "" else &"fair"
	out["strength"] = clampf(float(d.get("strength", 0.0)), 0.0, 1.0)
	out["wind"] = clampf(float(d.get("wind", 0.0)), -1.0, 1.0)
	return out


# -------------------------------------------------------------- machines

## Level of a machine bed at distance d: 0.45 at the edge of its racket, 1 on top.
static func machine_level(d: float, racket: float) -> float:
	if racket <= 0.0 or d >= racket:
		return 0.0
	return 0.45 + 0.55 * (1.0 - maxf(0.0, d) / racket)


## Distance is a timbre change before it is a level change: the low-pass
## corner falls from 16 kHz on top of it to 1.4 kHz at the edge.
static func machine_cutoff(d: float, racket: float) -> float:
	var t := clampf(d / maxf(0.001, racket), 0.0, 1.0)
	return 16000.0 * pow(1400.0 / 16000.0, pow(t, 0.8))


static func machine_wet(d: float, racket: float) -> float:
	return 0.03 + 0.22 * clampf(d / maxf(0.001, racket), 0.0, 1.0)


## The one machine that plays: the loudest living mob within its racket.
## mobs: nodes exposing kind, pos (tile space) and alive. Returns
## {kind, level, distance, node} or an empty Dictionary.
static func loudest_machine(mobs: Array, listener: Vector2) -> Dictionary:
	var best := {}
	var best_level := 0.0
	for m: Object in mobs:
		if m == null or not is_instance_valid(m):
			continue
		var alive: Variant = m.get("alive")
		if alive is bool and not alive:
			continue
		var raw_kind: Variant = m.get("kind")
		if raw_kind == null:
			continue
		var kind := SoundMachines.kind_of(StringName(str(raw_kind)))
		if kind == &"":
			continue
		var pos: Variant = m.get("pos")
		if not pos is Vector2:
			continue
		var d := (pos as Vector2).distance_to(listener)
		var lvl := machine_level(d, SoundMachines.RACKET[kind])
		if lvl > best_level:
			best_level = lvl
			best = {"kind": kind, "level": lvl, "distance": d, "node": m}
	return best


# ----------------------------------------------------------- one-shots

## Level of a one-shot at distance d tiles (1 within 3 tiles).
static func sfx_gain(d: float) -> float:
	if d >= SFX_RANGE:
		return 0.0
	return 1.0 / (1.0 + maxf(0.0, d - 3.0) / 7.0)
