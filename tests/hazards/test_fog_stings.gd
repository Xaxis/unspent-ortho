extends TestCase
## FOG STINGS WHERE THE LAND BREATHES FUMES (the lands builder's weather audit).
## A fog is still, low air: over ground that gives off fumes it holds them down
## round a body, so a fog spell raises fumes wherever the land declares any, and
## over clean ground it is only wet and dark. A haze is the fog of a hot land:
## heat and fumes in the air, not water.


func _place(hazards: Dictionary, kind: StringName) -> Hazards.Place:
	var p := Hazards.Place.new()
	p.hazards = hazards
	p.hour = 12.0
	p.weather = kind
	p.weather_strength = 1.0
	return p


func test_fog_over_fuming_ground_raises_the_fumes() -> void:
	var fuming := {&"heat": 0.5, &"fumes": 0.5, &"wet": 0.45}
	var clear := float(Hazards.felt(_place(fuming, &"clear")).get(&"fumes", 0.0))
	var fog := float(Hazards.felt(_place(fuming, &"fog")).get(&"fumes", 0.0))
	gt(fog, clear + 0.1, "a fog holds the fumes down (%.2f -> %.2f)" % [clear, fog])
	gt(fog, Hazards.BITE, "enough to bite (%.2f)" % fog)
	eq(float(Hazards.felt(_place({&"cold": 0.3}, &"fog")).get(&"fumes", 0.0)), 0.0, "over clean ground a fog brings no fumes")


func test_haze_is_heat_and_fumes_not_water() -> void:
	var burning := {&"heat": 0.7, &"fumes": 0.5}
	var clear := Hazards.felt(_place(burning, &"clear"))
	var haze := Hazards.felt(_place(burning, &"haze"))
	gt(float(haze.get(&"heat", 0.0)), float(clear.get(&"heat", 0.0)), "a haze is hotter than a clear day")
	gt(float(haze.get(&"fumes", 0.0)), float(clear.get(&"fumes", 0.0)), "and thicker with fumes")
	eq(float(haze.get(&"wet", 0.0)), 0.0, "and it wets nobody")
