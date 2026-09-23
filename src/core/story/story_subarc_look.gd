class_name StorySubarcLook
extends RefCounted
## What a region looks like to the story, filled in by 49_story and read by the
## pure rules in `StorySubarc` — the shape `SentinelLook` already set: a system
## gathers, and the rules decide.

var region := -1
var land: StringName = &""
## The plan's depot in this region, or Vector2.INF, and whether it has been put dark.
var works := Vector2.INF
var works_dark := false
## What the people here call the ground the yard works: the machines' own mark on
## it (GenWorks: a cut, a burn, a quarry, a bore field).
var works_name := "the works"
## Who the plan is holding at that yard, and who has walked back out of it, as
## they are spoken of (`Taken.say`: a name when anybody knows one, and "somebody
## out of Oyster Row" when nobody does). The first is why a yard is worth walking
## into; the second is what somebody thanks him for afterwards, and is why the
## record outlives the rescue.
var held: Array[String] = []
var freed: Array[String] = []
## The walk home, which is the first thing in this game that can fail slowly
## (`Escort`, unspent-ortho-cb): who is out of the yard and will not come down
## the road alone, who is on it with him now, who reached a door, and who did
## not — `lost_on_road`, spelled out because `lost()` on this same look already
## means the PLAN has lost this place, and two words that far apart may not share
## a name. `lost_to` is the roster kind that took one back, by the same name, or
## `&""` for the cold and the water and the fall — the two are different things
## for a village to be told, and only one of them is nobody's fault.
var waiting: Array[String] = []
var walking: Array[String] = []
var arrived: Array[String] = []
var lost_on_road: Array[String] = []
var lost_to: Dictionary = {}
## Every landmark of the region: {id: int, kind, name, pos, found, opened}.
var landmarks: Array[Dictionary] = []
## Whether this region's keeper has been taken, and what the plan's network here
## makes of him now (calm / wary / hostile / hunted).
var keeper_down := false
var level: StringName = &"calm"
## Whether the chapter is wholly answered (`Chapters.answered_here`): explored,
## mined and defended. A villager cannot know what he has mined, so what they say
## about it is what they have WATCHED him do, never a count of his creel.
var answered := false


## The plan has lost this place: the only thing that ends the danger that working
## a region raises (docs/VISION.md).
func lost() -> bool:
	return works_dark or keeper_down


## They are looking for him here.
func roused() -> bool:
	return level == &"hostile" or level == &"hunted"


func any(found: bool, opened: bool) -> Dictionary:
	for l: Dictionary in landmarks:
		if bool(l.found) == found and bool(l.opened) == opened:
			return l
	return {}
