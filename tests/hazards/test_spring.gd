extends TestCase
## Water a body can DRINK is the answer to a dry land and nothing else
## (docs/LANDSCAPES.md: the mesas' cistern is "the land's own spring"). It is
## held apart from standing in water, which soaks you and takes the warmth off.


func _mesa_noon() -> Hazards.Place:
	var p := Hazards.Place.new()
	p.hazards = {&"heat": 0.5, &"thirst": 0.55}
	p.hour = 13.0
	return p


func test_a_spring_answers_thirst_and_only_thirst() -> void:
	var dry := Hazards.felt(_mesa_noon())
	var at := _mesa_noon()
	at.spring = 1.0
	var wet := Hazards.felt(at)
	gt(float(dry.get(&"thirst", 0.0)), Hazards.FELT, "a noon on the mesa presses with thirst (%.2f)" % float(dry.get(&"thirst", 0.0)))
	lt(float(wet.get(&"thirst", 0.0)), Hazards.FELT, "at the cistern it is not even felt (%.2f)" % float(wet.get(&"thirst", 0.0)))
	check(not wet.has(&"wet"), "drinking does not soak you")
	near(float(wet.get(&"heat", 0.0)), float(dry.get(&"heat", 0.0)), 1e-6, "and the sun is as hot as it was")


func test_a_cistern_is_the_mesas_spring() -> void:
	var sys: GDScript = load("res://src/systems/52_hazards.gd")
	var springs: Array = sys.get_script_constant_map()["SPRINGS"]
	check(springs.has(PropKind.CISTERN), "the cistern is a spring")
	check(Takes.GIVES_NOTHING.has(PropKind.CISTERN), "and it says why it hands over no item")
