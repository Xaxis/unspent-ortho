class_name Chapters
extends RefCounted
## THE ONE DOOR: is this place answered, and what is it still asking?
##
## `Chapter` is the rules and knows nothing about a running game. This gathers
## the three states a live world keeps — what has been found, what the keeper is
## doing, what the yard is doing — and hands the answer to whoever asks: the
## story (what a person says about the place), the way on, the slate, dev mode, a
## test. One door, so no two of them can disagree about whether a chapter is done.
##
## Every system is found BY WHAT IT KEEPS and never by its name, which is
## `SaveCore.explored_of`'s idiom and the reason renumbering a system file has
## never broken anything.
##
## Nothing here writes. A chapter is derived, every frame, from state that other
## packages own — so there is no chapter bookkeeping to save, to migrate, or to
## fall out of step with the world it describes.


## The landmark package's memory of what has been found.
static func found_of(game: Game) -> Dictionary:
	for sys in game.systems:
		var s: Variant = sys.get("state")
		if s is LandmarkState:
			return (s as LandmarkState).found
	return {}


## Whether the region's keeper is down. A keeper that has fallen stays fallen, so
## this is the same answer after a save and a load.
static func keeper_down(game: Game, region_id: int) -> bool:
	for sys in game.systems:
		var v: Variant = sys.get("_states")
		if v is Array:
			var found_one := false
			for st: Variant in v:
				if st is SentinelState:
					found_one = true
					if (st as SentinelState).region == region_id:
						return (st as SentinelState).fallen
			# A region the keeper package knows nothing about has no keeper, which
			# is not the same as having one that still stands: DEFENDED then rests
			# entirely on the yard.
			if found_one:
				return false
	return false


## Whether the region's depot has been put dark.
static func yard_broken(game: Game, region_id: int) -> bool:
	for sys in game.systems:
		var v: Variant = sys.get("_states")
		if v is Dictionary:
			for st: Variant in (v as Dictionary).values():
				if st is WorksState and (st as WorksState).region == region_id:
					return (st as WorksState).broken()
	return false


## One chapter, whole. `Chapter.read`'s dictionary, with the live game's answers
## filled in — `answered` is the only field anything should gate on.
static func of(game: Game, region_id: int) -> Dictionary:
	if game == null or game.world == null or region_id < 0:
		return Chapter.read(null, region_id, {}, false, false)
	return Chapter.read(game.world, region_id, found_of(game),
		keeper_down(game, region_id), yard_broken(game, region_id))


## The chapter the player is standing in, or an empty one out on the sea and in
## the gaps between regions (a run too small to be a place belongs to none).
static func here(game: Game) -> Dictionary:
	if game == null or game.world == null or game.player == null:
		return {}
	var p: Vector2 = game.player.pos
	var id := game.world.region_at(floori(p.x), floori(p.y))
	return {} if id < 0 else of(game, id)


## Whether the place the player is standing in is answered. The short question,
## because it is the one most callers actually have.
static func answered_here(game: Game) -> bool:
	var d := here(game)
	return bool(d.get("answered", false))
