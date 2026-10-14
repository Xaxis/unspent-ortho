class_name StartArea
extends RefCounted
## THE START IS CALM (owner, 2026-10-13: "at the home coast or the initial area
## you start there just shouldn't be any enemies at the start of the game").
## While the first steps are under way (FirstSteps, kept by 58_guide) in a game
## that opened washed up (Story.washed_up, a player's new game), nothing comes
## out within REACH of the spawn: no machine put out on a roll or a round, no
## first meeting, no beast, no hauler sent from a yard (Coast `calm`, 34_works).
## Out past it, or once the steps are done, the world is as it always is.
##
## Measured round the errand's spots on seed 1 before this (four minutes): eleven
## harvesters and haulers on their rounds, three yard dogs and a field bull, all
## 25 to 60 tiles from the spawn. The errand's places lie within 60 of it.

const REACH := 80.0


## Calm at `p` now.
static func calm(game: Node, p: Vector2) -> bool:
	if not Story.washed_up or game == null:
		return false
	var w: WorldData = game.get(&"world")
	if w == null or p.distance_to(w.spawn) > REACH:
		return false
	var guide := game.get_node_or_null(^"58_guide")
	return guide != null and bool(guide.call(&"steps_on"))
