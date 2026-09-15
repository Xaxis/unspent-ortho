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


func hour() -> float:
	return fposmod(minutes, 1440.0) / 60.0


## Day 1 is the first day.
func day() -> int:
	return floori(minutes / 1440.0) + 1


func nightfall() -> float:
	return FightRules.nightfall(hour())


## Sight x (1 - c x strength) per weather kind (design-extract §5). Hearing never.
func weather_sight() -> float:
	var c := 0.0
	match String(weather):
		"sand", "sandstorm": c = 0.55
		"fog": c = 0.45
		"storm": c = 0.30
		"snow": c = 0.25
		"hail": c = 0.20
	return 1.0 - c * clampf(weather_strength, 0.0, 1.0)


## Reads the weather: Weather.at(seed, minutes) -> {kind, strength, wind}.
func read_weather() -> void:
	var d := Weather.at(seed_value, minutes)
	weather = StringName(String(d.get("kind", "fair")).to_lower())
	weather_strength = float(d.get("strength", 0.0))
	wind = float(d.get("wind", 0.0))
