class_name Moment
extends RefCounted
## What the world is like right now, as the senses and the spawner need it.
## Built once per frame by the systems from the clock, the body and the
## weather; built by hand in tests.

var seed_value := 1
## World minutes since day 0, 00:00.
var minutes := 8.0 * 60.0
var lamp_lit := false
var filed := 0
var laden_tier := 0
## --- what the player is doing about being noticed (StealthQuery reads) ---
## Down in the heather: seen and heard less far, and slower.
var crouched := false
## 0..1 where the player stands, from the ground, what grows there and the
## night (Cover.at). A lit lamp is no cover: it is already 0 then.
var cover := 0.0
## The player is wearing a machine's own signature (`Body.spoof_until`, written
## by the gear package's spoof ability): the machines read them as one of their
## own. `StealthQuery` cuts their sight by it and refuses them the notice
## outright; nothing alive is fooled by a stolen signet.
var spoofed := false
## How loud the player is, against a walk on plain ground (StealthNoise.loudness):
## 1 walking, about 0.3 standing still, less crouched or on moss, more running
## on shingle. It is the whole of what shortens hearing.
var loudness := 1.0
## 0..1 in the plan network the player stands in (Interference).
var interference := 0.0
## Weather kind (lowercase: fair grey rain storm fog snow hail sand heat ...), strength 0..1, wind -1..1.
var weather: StringName = &"fair"
var weather_strength := 0.0
var wind := 0.0


func hour() -> float:
	return fposmod(minutes, 1440.0) / 60.0


## Day 1 is the first day.
func day() -> int:
	return floori(minutes / 1440.0) + 1


func nightfall() -> float:
	return FightRules.nightfall(hour())


## Sight x (1 - c x strength) per weather kind (design-extract §5; the sky's
## Weather.SIGHT_CUT, which covers every kind it can send). Hearing never.
func weather_sight() -> float:
	var k := weather
	if k == &"sand" or k == &"sandstorm":
		k = &"dust"
	return Weather.sight_factor(k, clampf(weather_strength, 0.0, 1.0))


## Reads the weather a body is standing in. Every landscape type has its own
## climate, so a machine in a whiteout must have its sight cut by the whiteout
## and not by whatever the coast is doing: pass the type id the bodies are in
## (`BiomeRegistry.at(world, pos).id`). Without one this falls back to the
## world-wide read, which is what a test with no world wants.
func read_weather(type_id: StringName = &"") -> void:
	var d := Weather.at_type(seed_value, minutes, type_id) if type_id != &"" \
		else Weather.at(seed_value, minutes)
	weather = StringName(String(d.get("kind", "fair")).to_lower())
	weather_strength = float(d.get("strength", 0.0))
	wind = float(d.get("wind", 0.0))
