class_name AvatarState
extends RefCounted
## The player's own body, as they made it on the character page at the start of a
## game (owner, 2026-09-17: "an initial character builder where a fully
## configurable character is created ... and selected at game start"). It is the
## body before any gear: GearLook.compose dresses THIS, for the figure walking the
## coast and the figure on the gear page alike.
##
## A look spec in the people model's own words (PersonLook), JSON-safe (names as
## strings, colours as "ramp:step"). Saved under its own key by 33_avatar and kept
## OUT of WorldStamp on purpose, as the story is: a face is appearance, not terrain,
## and a changed face must never be the reason a save is refused.
##
##   AvatarState.of(game).look      the chosen body ({} until 33_avatar sets it)
##   AvatarState.bare(spec)          what of a spec is the BODY: everything gear puts
##                                   on (salvage, the kit's own extras, the kit flag)
##                                   taken off, and the wrist slate always kept

const META := &"avatar_state"
## What only gear puts on a body: never part of the body a player makes.
const GEAR_KEYS: Array[String] = ["salvage", "kit", "trade", "gaunt"]

var look: Dictionary = {}


static func of(game: Node) -> AvatarState:
	if not game.has_meta(META):
		game.set_meta(META, AvatarState.new())
	return game.get_meta(META)


static func bare(spec: Dictionary) -> Dictionary:
	var out := spec.duplicate(true)
	for k: String in GEAR_KEYS:
		out.erase(k)
	# The slate on the wrist is the player's own, whatever the page chose, and the
	# rest of the kit is gear's to put on.
	out["gear"] = [&"slate"]
	return out
