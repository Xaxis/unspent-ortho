extends TestCase
## THE GROUND presses a body on top of the land it stands on and the things near
## it (docs/LANDSCAPES.md, shared system 3: "within R of ground G adds H"). The
## rows are `GroundHazards.TABLE`; `Hazards.felt` reads them through
## `Place.near_grounds`, which 52_hazards fills off the tiles round the body
## (`GroundHazards.near`). The frost sea's leads thin the ice at their edge.


static func place(ground: int, near_grounds: Dictionary) -> Hazards.Place:
	var p := Hazards.Place.new()
	p.hazards = {&"collapse": 0.4}
	p.ground = ground
	p.near_grounds = near_grounds
	return p


static func collapse(p: Hazards.Place) -> float:
	return float(Hazards.felt(p).get(&"collapse", 0.0))


## On the ice at a lead's edge the sea's 0.4 takes the lead's add; two tiles off
## it is the sea's own; and the add alone stays under FELT (PropHazards' rule 2).
func test_the_ice_at_a_leads_edge_is_thinner_than_the_sheet() -> void:
	var row: Dictionary = GroundHazards.rows(Ground.BLACKWATER)[0]
	eq(row.id, &"collapse", "a lead's row is the ice giving way")
	lt(float(row.add), 0.25, "and on its own it stays under FELT")
	near(collapse(place(Ground.ICE, {Ground.BLACKWATER: 0.0})), 0.4 + float(row.add), 1e-5, "the sea's floor plus the lead's add, at its edge")
	near(collapse(place(Ground.ICE, {Ground.BLACKWATER: float(row.reach)})), 0.4, 1e-5, "and the sea's own at its reach")
	near(collapse(place(Ground.ICE, {})), 0.4, 1e-5, "and the sea's own with no lead near")
	near(collapse(place(Ground.MUD, {Ground.BLACKWATER: 0.0})), 0.4, 1e-5, "a bog's black water thins no ice: the row is on ice only")


## A seal's hole at a lead's edge is thin ice once, not twice: the ground is one
## source with the things near the body (PropHazards' rule 1).
func test_a_seal_hole_at_a_lead_is_one_source() -> void:
	var p := place(Ground.ICE, {Ground.BLACKWATER: 0.0})
	p.near_props = [WorldProp.new(1, PropKind.SEAL_HOLE, Vector2.ZERO, 0.0, 1.0)]
	var most := maxf(float(GroundHazards.rows(Ground.BLACKWATER)[0].add), float(PropHazards.near(PropKind.SEAL_HOLE)[0].add))
	near(collapse(p), 0.4 + most, 1e-5, "the larger add, not the sum")


## What 52_hazards hands `felt`: the nearest tile of each pressing ground round
## the body, measured to that tile's edge, and nothing past the table's reach.
func test_near_reads_the_tiles_round_the_body() -> void:
	var w := WorldData.new(1, 16)
	w.ground.fill(Ground.ICE)
	w.level.fill(1)
	w.ground[8 * 16 + 8] = Ground.BLACKWATER
	var at := GroundHazards.near(w, Vector2(6.5, 8.5))
	near(float(at.get(Ground.BLACKWATER, INF)), 1.5, 1e-5, "a lead two tiles over is a tile and a half from the body's centre to its edge")
	eq(GroundHazards.near(w, Vector2(8.6, 8.4)).get(Ground.BLACKWATER), 0.0, "standing in it is at it")
	check(not GroundHazards.near(w, Vector2(2.5, 2.5)).has(Ground.BLACKWATER), "and six tiles off it is not near")


## THE BODY SAYS SO WHERE THE GROUND SAYS SO. On the frost sea's ice, still and
## clear, the line ("The ground under this is not holding.") is told past BITE:
## on every tile touching a lead, and on none two tiles off it or further, the
## way 52_hazards asks it (a tile's middle). And on ground that is not ice,
## beside the same water, never.
func test_the_line_is_told_at_a_leads_edge_and_nowhere_else() -> void:
	var w := WorldData.new(1, 24)
	w.ground.fill(Ground.ICE)
	w.level.fill(1)
	for y in 24:
		w.ground[y * 24 + 12] = Ground.BLACKWATER
	for x in range(4, 21):
		if x == 12:
			continue
		var at := Vector2(x + 0.5, 12.5)
		var told := collapse(place(Ground.ICE, GroundHazards.near(w, at))) >= Hazards.BITE
		var off := absi(x - 12)
		if off == 1:
			check(told, "the body says so on the tile beside the lead (%d)" % x)
		else:
			check(not told, "and not %d tiles off it (%d)" % [off, x])
	var diagonal := Vector2(11.5, 11.5)
	check(collapse(place(Ground.ICE, GroundHazards.near(w, diagonal))) >= Hazards.BITE, "a tile touching the lead at its corner counts as beside it")
	check(collapse(place(Ground.MUD, GroundHazards.near(w, Vector2(11.5, 12.5)))) < Hazards.BITE, "and on mud beside the same water the ground holds")
