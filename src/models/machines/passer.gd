extends FigureModel
## A MACHINE THAT PASSES. The higher machines of the city: better dressed than
## anyone, unhurried, and the only bodies in the landscape not working.
##
## WHY IT IS DRAWN AS A PERSON AND NOT AS A MACHINE. Everywhere else the game
## draws a machine, `MachineModel` does it, and two contracts make that body
## unmistakable on sight: the violet `Palette.MACHINE` ramp with its one saturated
## amber lens, and status lamps blinking `MachineModel.disposition`. Both are
## load-bearing for every other machine and neither may be weakened. So this one
## does not inherit them: it extends `FigureModel` directly and owns a
## `PersonModel`, which means it has no ramp to soften and no lamp to hide. The
## contracts for ordinary machines are untouched because this body never enters
## them.
##
## AND IT STILL ANSWERS AS A MACHINE. Nothing that reads a body reads its model:
## `TargetRead.of`, `Targeting.threat_of`, `Roles.of_row` and
## `StoryContent.testimony` all key off `MobState` and the roster row, which say
## `machine: true` and `role: watcher`. So the slate's read gives its health, its
## powers, its senses and its testimony exactly as for anything else of the plan,
## the fight treats it as plate and not as flesh, and the one place a player can
## learn what it is, is by putting the slate on it. That progression — pass one
## unknowing, read one, then never be able to unsee them — is the landscape's
## whole mechanic, and it costs nothing because both halves already existed.
##
## The inherited no-ops are deliberate, not unfinished:
##   set_part_lit  there is no working part to light, and no part to aim at
##   flare_part    so a blow, an opening and a flicker of suspicion show nothing
##   set_hunting   it never runs anything down; it has people for that
## `top_toward`, `part_position`, `draw_calls` and `triangle_count` are the base
## class's and walk the person's own meshes, so a tag stands clear of the head
## and the budget is counted honestly.

## It moves exactly as the crowd moves. A body posed on a different clock from
## everyone around it reads as odd before anything else does, and "odd" is the
## one thing this must never be.
const POSE_HZ := 12.0

var _person: PersonModel


func build() -> void:
	# No working part: nothing on this body is a place to aim at.
	part_side = &"none"
	height = 1.7
	_person = PersonModel.make(PersonLook.passing(0))
	_person.pose_hz = POSE_HZ
	add_child(_person)


## Given a seed of its own and the world's sun by whoever put it out (30_mobs).
## Both matter: a street of identical bodies is a tell, and a person casting no
## shadow where everybody else casts one is a louder one.
func pass_as(seed_value: int, sun: DirectionalLight3D) -> void:
	if _person == null:
		return
	_person.set_look(PersonLook.passing(seed_value))
	_person.sun = sun


func set_pose(p: StringName) -> void:
	if p == pose:
		return
	pose = p
	if _person == null:
		return
	match p:
		&"dead":
			_person.play_action(&"downed", 0.0)
		&"hurt":
			_person.play_action(&"hurt", 0.0)
		&"windup", &"strike":
			_person.play_action(&"swing", 0.0)
		_:
			# Stands, walks and waits with nothing in its hands. It is never
			# alert, because it is never surprised.
			if _person.action != &"downed":
				_person.play_action(&"", 0.0)


## FigureModel's argument order is (delta, speed) and PersonModel's is
## (speed, delta). They are swapped here on purpose; passing them straight
## through animates the gait off the frame time and does not raise an error.
func animate(delta: float, speed: float) -> void:
	if _person != null:
		_person.animate(speed, delta)


## Every look this body can wear, so the gallery shows what a street of them
## looks like and the absences can be judged against a villager standing beside
## them. Whoever reviews the gallery is the second reader this has to survive.
static func gallery() -> Array:
	var out: Array = []
	for i in 6:
		var p := PersonModel.make(PersonLook.passing(i * 7717))
		out.append({"name": "passer %d" % i, "node": p})
	return out
