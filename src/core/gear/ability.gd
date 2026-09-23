class_name Ability
extends RefCounted
## The one interface every ability is read through (docs/VISION.md), so the
## player controller, the fight and the slate all speak to abilities the same
## way and a new one is a file, never a new branch in a system.
##
##   id        what it is called everywhere (&"dash", &"glide", ...)
##   action    the input action that fires it (project.godot [input])
##   cooldown  real seconds before it may fire again
##   charges   found charges (`wick`) spent per use: FOUND tech is not free
##   wind      fight wind spent per use, in the fight's own units
##   hold      true: driven by on_hold while the key is down, not by a press
##   lasts     world minutes the effect stands after it fires (0 = at once)
##
## Hooks (all optional; the base does nothing):
##   refusal(ctx) -> StringName   &"" to allow it, else why not (a word the
##                                slate turns into a line)
##   on_press(ctx) -> bool        it fired
##   on_hold(ctx, delta)          the key is still down
##   passive(ctx, delta)          every frame while it is fitted, fired or not
##
## Costs and cooldowns are checked by AbilityBook, never in here: an ability
## says what it does, the book says whether it may.

var id: StringName = &""
var name := ""
var action: StringName = &""
var cooldown := 0.0
var charges := 0
var wind := 0.0
var hold := false
var lasts := 0.0
## What the slate writes beside it on the gear page.
var note := ""


## Why this cannot fire right now, beyond cost and cooldown. &"" = it can.
func refusal(_ctx: AbilityCtx) -> StringName:
	return &""


func on_press(_ctx: AbilityCtx) -> bool:
	return false


func on_hold(_ctx: AbilityCtx, _delta: float) -> void:
	pass


func passive(_ctx: AbilityCtx, _delta: float) -> void:
	pass


## The lines the slate and the HUD say for a refusal, so every ability refuses
## in the same voice.
const REFUSALS := {
	&"cooling": "Not yet. It is still warm.",
	&"no_charge": "No charge left in it.",
	&"winded": "You have no breath for it.",
	&"held": "Something has hold of you.",
	&"busy": "Your hands are full.",
	&"no_drop": "There is nothing to step off here.",
	&"no_anchor": "Nothing in range to take hold of.",
	&"nothing": "Nothing answers.",
	&"already": "It is already running.",
	&"swimming": "Nothing under your feet to jump from.",
	&"airborne": "Your feet are already off the ground.",
	&"riding": "Not from a deck. Step off first.",
	&"swinging": "Not in the middle of a blow.",
}


static func refusal_line(why: StringName) -> String:
	return REFUSALS.get(why, "It will not.")
