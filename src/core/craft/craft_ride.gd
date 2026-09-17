class_name CraftRide
extends RefCounted
## What a craft under a body changes, and the whole of it: which ground counts as
## standable and how far it may step, read by `WorldQuery.move_body`, and how
## fast it goes, read by `Hero.ground_speed`. Nothing else about movement changes,
## so the fight simulation stays the one thing that moves the player (docs/CLAUDE.md,
## "The player's body").
##
## `Hero.ride` holds one of these while a craft carries the player and null
## otherwise; only the crafts package writes it. Empty `grounds` means "anything a
## body could stand on", so a sled keeps a walker's footing and gains only speed.

var kind: StringName = &""
## Ground ids this may travel over; empty = a walker's rules (anything but deep water).
var grounds: Dictionary = {}
## Levels it may step in one move. A body's own limit is 1; 2 is a cliff.
var levels := 1
var walk := Tuning.WALK_SPEED
var run := Tuning.RUN_SPEED


static func walker() -> CraftRide:
	return CraftRide.new()


func crosses(ground: int) -> bool:
	if grounds.is_empty():
		return ground != Ground.DEEP_WATER
	return grounds.has(ground)


func speed(running: bool) -> float:
	return run if running else walk
