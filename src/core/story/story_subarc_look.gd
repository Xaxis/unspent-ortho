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
## a region raises (docs/VISION.md §10).
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
