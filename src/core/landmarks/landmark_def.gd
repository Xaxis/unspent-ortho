class_name LandmarkDef
extends RefCounted
## One KIND of place worth the walk (docs/VISION.md, §8). A landmark kind is
## data: a silhouette readable from a long way off, a reason to go to it, a small
## risk, and a table of what it gives — declared once here and claimed by the
## landscapes that hold it (`BiomeDef.landmarks`, or this row's own `lands`).
##
## The bar every one of them is held to, and what the tests check:
##   - it can be SEEN before it can be reached (`sees` tiles, and a model whose
##     top stands above everything around it);
##   - there is a reason to walk to it (`drops` is never empty);
##   - there is a risk in it (`guarded`, or the hazard of the ground it stands on);
##   - it goes on the map the moment it is seen, and stays there;
##   - what it gives is DETERMINISTIC: the same seed and the same site always
##     give the same things, so a cache cannot be rerolled by loading a save.

var id: StringName = &""
var display_name := ""
## The landscape types that hold it, when their own file does not say. A kind
## with no lands is placed nowhere, which is how a kind is retired.
var lands: Array[StringName] = []
## The line said when it is first seen from a distance, and the line said on
## arriving at it. Both are about the PLACE, never about the reward.
var far := ""
var near := ""
## Tiles it can be read from. The model is drawn to hold at this distance and
## `tests/landmarks` measures the height it needs to.
var sees := 22.0
## How the ground under it is chosen: &"shore" (water within a few tiles),
## &"high" (nothing near stands higher), &"open" (clear of props), &"water"
## (beside inland water), &"rough" (broken ground). Everything also wants room.
var wants: StringName = &"open"
## Tiles it keeps from another landmark, from a village and from a works.
var apart := 70.0
## The drop table it is opened for (`src/core/loot`). One economy, not four.
var drops: StringName = &""
## Something of the plan is still here, and opening the cache wakes it.
var guarded := false
## The mark the map draws it with, and what the reads app calls what it left.
var mark: StringName = &""


static func make(id_: StringName, name_: String) -> LandmarkDef:
	var d := LandmarkDef.new()
	d.id = id_
	d.display_name = name_
	d.drops = StringName("landmark_%s" % id_)
	return d
