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
## Weather kind (lowercase: fair grey rain storm fog snow hail sand heat ...), strength 0..1, wind -1..1.
var weather: StringName = &"fair"
var weather_strength := 0.0
var wind := 0.0
## The player is wearing a machine's own signature (Body.spoof_until, written by
## the gear package's spoof ability): the machines read them as one of theirs.
var spoofed := false


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


## Reads the weather: Weather.at(seed, minutes) -> {kind, strength, wind}.
func read_weather() -> void:
	var d := Weather.at(seed_value, minutes)
	weather = StringName(String(d.get("kind", "fair")).to_lower())
	weather_strength = float(d.get("strength", 0.0))
	wind = float(d.get("wind", 0.0))
