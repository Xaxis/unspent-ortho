extends TestCase
## FLAMES GUTTER IN THE WET (the lands builder's weather audit). An open fire
## burns low in rain and lower in a storm; a carried lamp dims and stutters; a
## hearth under a roof and a kiln burn as ever. A dry sky, however dark, costs
## no flame anything. 15_lights `gutter` is the one rule; `_update` and the
## lantern read it with the weather where the player stands.

const Lights := preload("res://src/systems/15_lights.gd")


func _mean(kind: int, carried: bool, weather: StringName, strength: float) -> float:
	var t := 0.0
	for i in 200:
		t += Lights.gutter(kind, carried, weather, strength, float(i) * 0.037, 0.3)
	return t / 200.0


func test_an_open_fire_burns_low_in_the_rain_and_lower_in_a_storm() -> void:
	var dry := _mean(PropKind.FIRE, false, &"clear", 0.0)
	near(dry, 1.0, 1e-6, "a dry night costs a fire nothing")
	var rain := _mean(PropKind.FIRE, false, &"rain", 1.0)
	var storm := _mean(PropKind.FIRE, false, &"storm", 1.0)
	lt(rain, 0.8, "rain takes a fire low (%.2f)" % rain)
	lt(storm, rain, "a storm lower still (%.2f)" % storm)
	gt(storm, 0.15, "and it does not go out (%.2f)" % storm)
	near(_mean(PropKind.FIRE, false, &"fog", 1.0), 1.0, 1e-6, "fog is not wet enough to matter")


func test_a_carried_lamp_dims_and_stutters_in_a_storm() -> void:
	var dry := _mean(PropKind.LAMP, true, &"clear", 0.0)
	var storm := _mean(PropKind.LAMP, true, &"storm", 1.0)
	lt(storm, dry - 0.1, "the lantern dims in a storm (%.2f)" % storm)
	var lo := INF
	var hi := -INF
	for i in 200:
		var v: float = Lights.gutter(PropKind.LAMP, true, &"storm", 1.0, float(i) * 0.037, 0.3)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	gt(hi - lo, 0.15, "and stutters: the flame catches and gutters (%.2f..%.2f)" % [lo, hi])


func test_a_roof_keeps_the_rain_off() -> void:
	near(_mean(PropKind.HOUSE, false, &"storm", 1.0), 1.0, 1e-6, "a hearth under a roof")
	near(_mean(PropKind.KILN, false, &"storm", 1.0), 1.0, 1e-6, "a kiln")
