class_name LandmarkSite
extends RefCounted
## One landmark in one world: which kind it is, where it stands and which of its
## kind it is. Derived from the island every time (`Landmarks.sites`), so it is
## never saved — only what a player has DONE about it is (`LandmarkState`).

## &"kind#n", the name the map, a tour (`place lighthouse2`) and a save all use.
var id: StringName = &""
var kind: StringName = &""
var land: StringName = &""
var region := -1
var pos := Vector2.ZERO
## Which way its front is turned, in world radians.
var facing := 0.0
## 1-based: the second lighthouse in a world is `lighthouse#2`.
var nth := 1


func def() -> LandmarkDef:
	return Landmarks.by_id(kind)


## The name a tour and dev mode reach it by, which is how `GenPlaces` numbers
## every other landmark kind: the first is the bare kind, the rest are numbered.
func place_name() -> StringName:
	return kind if nth <= 1 else StringName("%s%d" % [kind, nth])
