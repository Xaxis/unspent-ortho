extends GameSystem
## THE HUSH (docs/HUSH.md): what haunts a landscape that declares
## `BiomeDef.hush` (the crags), on its own stone circles (HushSites). Nothing
## here is explained, gates anything, or is read by the story: colour, never
## load. This system grows by slices; the machines' part is the fight's.

## How far a tour looks for a ring to stand at.
const TOUR_REACH := 160.0


## `near hush_ring`: the centre of the nearest ring, so a tour stands in it by
## name and never at a coordinate.
func tour_place(what: String) -> Vector2:
	if what != "hush_ring" or game == null or game.world == null or game.player == null:
		return Vector2.INF
	var r := HushSites.nearest(game.world, game.query, game.player.pos, TOUR_REACH)
	return r.centre if r != null else Vector2.INF
