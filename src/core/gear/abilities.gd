class_name Abilities
## Every ability the gear can grant, and the one place they are built. A module
## or a piece of kit names one by id (`Items` field `ability`); the book asks
## here for the object.

const IDS: Array[StringName] = [&"dash", &"glide", &"scan", &"grapple", &"spoof"]
## What every body has without wearing anything: always in the book, never on the
## gear page, never granted by an item.
const INNATE: Array[StringName] = [&"jump"]


static func make(id: StringName) -> Ability:
	match id:
		&"dash": return AbilityDash.new()
		&"glide": return AbilityGlide.new()
		&"scan": return AbilityScan.new()
		&"grapple": return AbilityGrapple.new()
		&"spoof": return AbilitySpoof.new()
		&"jump": return AbilityJump.new()
	return null


## The book a body carries: what its gear grants, and what it has anyway.
static func with_innate(granted: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = INNATE.duplicate()
	for id in granted:
		if not out.has(id):
			out.append(id)
	return out


## The input action an ability answers to, for the input map and the tours.
static func action_of(id: StringName) -> StringName:
	var a := make(id)
	return a.action if a != null else &""


## Every input action the abilities need; project.godot must carry each one.
static func actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in IDS + INNATE:
		var a := action_of(id)
		if a != &"":
			out.append(a)
	return out
