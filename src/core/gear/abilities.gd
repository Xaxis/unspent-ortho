class_name Abilities
## Every ability the gear can grant, and the one place they are built. A module
## or a piece of kit names one by id (`Items` field `ability`); the book asks
## here for the object.

const IDS: Array[StringName] = [&"dash", &"glide", &"scan", &"grapple", &"spoof"]


static func make(id: StringName) -> Ability:
	match id:
		&"dash": return AbilityDash.new()
		&"glide": return AbilityGlide.new()
		&"scan": return AbilityScan.new()
		&"grapple": return AbilityGrapple.new()
		&"spoof": return AbilitySpoof.new()
	return null


## The input action an ability answers to, for the input map and the tours.
static func action_of(id: StringName) -> StringName:
	var a := make(id)
	return a.action if a != null else &""


## Every input action the abilities need; project.godot must carry each one.
static func actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in IDS:
		var a := action_of(id)
		if a != &"":
			out.append(a)
	return out
