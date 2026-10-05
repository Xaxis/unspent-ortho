class_name GroundHazards
## What the GROUND round a body presses it with, as against the land it stands
## on and the things standing near it (docs/LANDSCAPES.md, shared system 3:
## "within R of ground G adds H"). `BiomeDef.hazards` stays the authority for
## what the land does and `PropHazards` for what a thing adds; a ground declares
## here what standing near a tile of it adds, so the ice at a lead's edge is thin
## wherever a lead opens, and a landscape that lays the ground has said all it
## needs to by laying it.
##
## A row is `{id, reach, add, on}`: the hazard (one of `Hazards.IDS`), how many
## tiles from the nearest tile of the ground it is felt, what it adds there
## falling straight to 0 at `reach`, and the ground the body must stand ON for
## it (-1 for any). It is one source with the things near the body
## (`Hazards._near_shift`, PropHazards' rule 1), and it keeps PropHazards' rule 2:
## an add on its own stays under FELT.
##
## Pure data and one read. `Hazards.felt` reads it through `Place.near_grounds`,
## which 52_hazards fills from the tiles round the body (`near`) every sweep.

const TABLE := {
	# THE LEADS (the frost sea's `_surface`): the sheet at a lead's edge is the
	# sheet the sea is opening. 0.24 on the frost sea's own 0.4 takes every tile
	# touching a lead past BITE, where the body says so, and none two tiles off
	# (tests/hazards/test_ground_hazards.gd); on its own it stays under FELT.
	# On ICE only: a bog's black water in the moss is a wet edge, not a floor
	# giving way.
	Ground.BLACKWATER: [
		{"id": &"collapse", "reach": 2.0, "add": 0.24, "on": Ground.ICE},
	],
}


## The rows a ground declares; empty for a ground that presses nothing.
static func rows(ground: int) -> Array:
	return TABLE.get(ground, [])


## The furthest any row reaches: how far round the body `near` has to look.
static func reach_most() -> float:
	var most := 0.0
	for list: Array in TABLE.values():
		for row: Dictionary in list:
			most = maxf(most, float(row.reach))
	return most


## Each ground with a row that lies within `reach_most` of `pos` in `world`, and
## how far the nearest tile of it is from the body (to the tile's edge, so a
## body standing beside a lead is at 0): ground -> tiles. A square of
## (2 * reach_most + 1)^2 tiles round the body, read once a sweep.
static func near(world: WorldData, pos: Vector2) -> Dictionary:
	var out := {}
	var r := ceili(reach_most())
	var cx := floori(pos.x)
	var cy := floori(pos.y)
	for ty in range(cy - r, cy + r + 1):
		for tx in range(cx - r, cx + r + 1):
			if not world.in_bounds(tx, ty):
				continue
			var g := world.ground_at(tx, ty)
			if not TABLE.has(g):
				continue
			var dx := maxf(0.0, absf(pos.x - (tx + 0.5)) - 0.5)
			var dy := maxf(0.0, absf(pos.y - (ty + 0.5)) - 0.5)
			var d := sqrt(dx * dx + dy * dy)
			if d < float(out.get(g, INF)):
				out[g] = d
	return out
