extends TestCase
## The drawn depot, held to the job it exists to do (docs/VISION.md). Four
## hundred lines of geometry went in with nothing under tests/ so much as naming
## the file, under a header that says it is "drawn to be READ FROM FAR OFF AT
## NIGHT" — which is a claim about a number nobody was checking.

## Surfaces a yard may cost: the found mesh, the lamps and what people lashed on.
const YARD_BUDGET := 4
const PART_BUDGET := 5


func test_the_mast_stands_well_over_anything_else_the_plan_builds() -> void:
	var m := WorksDepot.measure(0)
	# A fire tower prop is 4.2 and the tallest landmark short of the stack is 8.6;
	# the mast has to be a silhouette beside those, not among them.
	gt(float(m.high), 8.0, "the mast is not a silhouette over the land")
	print("works yard: %.1f tall, %.1f across, %d draws" % [float(m.high), float(m.wide), int(m.draws)])


func test_the_plan_advancing_shows_as_more_of_the_yard_and_not_a_taller_mast() -> void:
	var first := WorksDepot.measure(0)
	var last := WorksDepot.measure(Works.STAGES - 1)
	near(float(last.high), float(first.high), 0.01, "the mast is the same mast at every stage")
	gt(float(last.wide), float(first.wide) - 0.01, "and the yard has more in it")
	lt(float(last.draws), float(YARD_BUDGET) + 0.5, "a full yard still costs what a yard costs")


func test_a_yard_and_its_parts_cost_what_a_machine_costs() -> void:
	lt(float(WorksDepot.measure(0).draws), float(YARD_BUDGET) + 0.5, "an empty yard")
	for i in Works.PART_NAMES.size():
		var root := WorksDepot.part(i, 5, null)
		var draws := 0
		for c in root.get_children():
			var mesh := c as MeshInstance3D
			if mesh != null and mesh.visible and mesh.mesh != null:
				draws += mesh.mesh.get_surface_count()
		root.free()
		lt(float(draws), float(PART_BUDGET) + 0.5, "%s draws %d times" % [Works.PART_NAMES[i], draws])


## THE CRAGS' WINCH HOUSE (#68): no mast and no light of its own, and a machine's
## cost to draw like any yard. The crags hold no machine light, so the housings'
## own lamps are what say a part is working, open or dark.
func test_the_winch_house_has_no_mast_and_no_light() -> void:
	for stage: int in [0, Works.STAGES - 1]:
		var m := WorksDepot.measure(stage, WorksDepot.WINCH)
		lt(float(m.high), 3.0, "stage %d: no mast stands over it (%.1f tall)" % [stage, float(m.high)])
		lt(float(m.draws), float(YARD_BUDGET) + 0.5, "stage %d: it costs what a yard costs" % stage)
	var root := WorksDepot.yard(WorksSite.new(), 0, null, WorksDepot.WINCH)
	check(root.get_node_or_null(^"lamps") == null, "and nothing of it is lit")
	root.free()
	var m0 := WorksDepot.measure(0, WorksDepot.WINCH)
	print("winch house: %.1f tall, %.1f across, %d draws" % [float(m0.high), float(m0.wide), int(m0.draws)])


# --- the mass of it ---------------------------------------------------------------

## THE DECK IS A WALL. Without it the yard was an open field with decorative
## furniture: nothing to break a line of sight behind, which is most of what the
## "stealth-and-fight set piece" of the brief actually is.
func test_the_deck_stops_a_body_and_the_parts_can_still_be_reached() -> void:
	for form: StringName in WorksDepot.FORMS:
		_blocks_and_reach(form)


## Every form's mass: a wall over the middle of the yard, and every housing still
## stood at. The winch house's drum stands on whichever side its lip is, so it is
## asked at every bearing of the cable.
func _blocks_and_reach(form: StringName) -> void:
	const BODY := 0.34
	var cables: Array[Vector3] = [Vector3.INF]
	if form == WorksDepot.WINCH:
		for k in 8:
			var d := Vector2.from_angle(TAU * k / 8.0) * 5.0
			cables.append(Vector3(d.x, -2.0, d.y))
	for cable in cables:
		_blocks_at(form, cable, BODY)


func _blocks_at(form: StringName, cable: Vector3, body: float) -> void:
	var deck := WorksDepot.yard_blocks(form, cable)
	check(not deck.is_empty(), "%s: the yard is walk-through" % form)
	# It covers the middle of the yard, so a body cannot walk through the depot.
	var covered := false
	for c: Vector3 in deck:
		if Vector2(c.x, c.y).length() < c.z:
			covered = true
	check(covered, "%s: the middle of the yard is open ground" % form)
	# And no part is buried in the deck or in its own housing: a player standing
	# at `PART_REACH` has somewhere to stand.
	var site := WorksSite.new()
	site.pos = Vector2(100, 100)
	site.facing = 0.0
	for i in Works.PART_NAMES.size():
		var at := site.part(i)
		var room := 0
		for j in 32:
			var p := at + Vector2.from_angle(TAU * j / 32.0) * (Works.PART_REACH * 0.7)
			var clear := true
			for c: Vector3 in deck:
				if (site.pos + Vector2(c.x, c.y)).distance_to(p) < c.z + body:
					clear = false
			for c: Vector3 in WorksDepot.part_blocks(i):
				if (at + Vector2(c.x, c.y)).distance_to(p) < c.z + body:
					clear = false
			if clear:
				room += 1
		gt(float(room), 8.0, "%s: %s cannot be stood at (cable %s)" % [form, Works.PART_NAMES[i], cable])


## Every part's own mass stays well inside the reach it is worked from, or a part
## a player can reach is a part they cannot get their hands on.
func test_no_part_is_wider_than_the_reach_it_is_worked_from() -> void:
	for i in Works.PART_NAMES.size():
		for c: Vector3 in WorksDepot.part_blocks(i):
			lt(Vector2(c.x, c.y).length() + c.z, Works.PART_REACH - 0.4,
				"%s's mass reaches past the hands that open it" % Works.PART_NAMES[i])
