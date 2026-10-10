extends TestCase
## FLAMES GUTTER IN THE WET (the lands builder's weather audit). An open fire
## burns low in rain and lower in a storm; a hearth under a roof and a kiln burn
## as ever. A dry sky, however dark, costs no flame anything. 15_lights `gutter`
## is the one rule; `_update` reads it with the weather where the player stands.
## The headlamp is an LED and never reads it.

const Lights := preload("res://src/systems/15_lights.gd")


func _mean(kind: int, weather: StringName, strength: float) -> float:
	var t := 0.0
	for i in 200:
		t += Lights.gutter(kind, weather, strength, float(i) * 0.037, 0.3)
	return t / 200.0


func test_an_open_fire_burns_low_in_the_rain_and_lower_in_a_storm() -> void:
	var dry := _mean(PropKind.FIRE, &"clear", 0.0)
	near(dry, 1.0, 1e-6, "a dry night costs a fire nothing")
	var rain := _mean(PropKind.FIRE, &"rain", 1.0)
	var storm := _mean(PropKind.FIRE, &"storm", 1.0)
	lt(rain, 0.8, "rain takes a fire low (%.2f)" % rain)
	lt(storm, rain, "a storm lower still (%.2f)" % storm)
	gt(storm, 0.15, "and it does not go out (%.2f)" % storm)
	near(_mean(PropKind.FIRE, &"fog", 1.0), 1.0, 1e-6, "fog is not wet enough to matter")


func test_a_roof_keeps_the_rain_off() -> void:
	near(_mean(PropKind.HOUSE, &"storm", 1.0), 1.0, 1e-6, "a hearth under a roof")
	near(_mean(PropKind.KILN, &"storm", 1.0), 1.0, 1e-6, "a kiln")
