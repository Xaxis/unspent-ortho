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


## SEVERAL REGIONS AT ONCE, WITH THE LIVE-STATE LOOKUPS DONE ONCE.
##
## `of()` walks `game.systems` three times — `found_of`, `keeper_down` and
## `yard_broken` each sweep every system asking for a property BY NAME — so
## asking it per region paid three sweeps per region for collections that are the
## same every time. `24_holds` asks for every region that keeps a hold, once per
## chapter change, and that refresh is the largest `_process` cost in the game.
##
## This is the same move `Chapter._standing_counts` already makes one file over:
## what cannot change between regions is found once, for every region at once.
##
## `of()` is left exactly as it was and remains the one door for a single region.
## `tests/chapter/test_chapter.gd` holds the two to giving identical answers, so
## the door cannot drift from the bulk path — which is the whole risk of having
## both.
static func for_regions(game: Game, region_ids: Array) -> Dictionary:
	var out := {}
	if game == null or game.world == null:
		for rid: int in region_ids:
			out[rid] = Chapter.read(null, rid, {}, false, false)
		return out
	var found := found_of(game)
	var keepers := _sentinel_states(game)
	var yards := _works_states(game)
	for rid: int in region_ids:
		out[rid] = Chapter.read(game.world, rid, found,
			_keeper_down_in(keepers, rid), _yard_broken_in(yards, rid))
	return out


## The keeper package's states, or an empty array if it keeps none. Finding the
## ARRAY is what costs; asking it about a region is a walk over a handful.
static func _sentinel_states(game: Game) -> Array:
	for sys in game.systems:
		var v: Variant = sys.get("_states")
		if v is Array:
			for st: Variant in (v as Array):
				if st is SentinelState:
					return v as Array
	return []


static func _works_states(game: Game) -> Array:
	for sys in game.systems:
		var v: Variant = sys.get("_states")
		if v is Dictionary:
			for st: Variant in (v as Dictionary).values():
				if st is WorksState:
					return (v as Dictionary).values()
	return []


## Read exactly as `keeper_down` reads it: a region the package knows nothing
## about has no keeper, which is not the same as one that still stands.
static func _keeper_down_in(states: Array, region_id: int) -> bool:
	for st: Variant in states:
		if st is SentinelState and (st as SentinelState).region == region_id:
			return (st as SentinelState).fallen
	return false


static func _yard_broken_in(states: Array, region_id: int) -> bool:
	for st: Variant in states:
		if st is WorksState and (st as WorksState).region == region_id:
			return (st as WorksState).broken()
	return false


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
