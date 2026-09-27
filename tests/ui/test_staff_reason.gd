extends TestCase
## A PLAYER ALWAYS SEES WHY NOTHING HAPPENS. A piece that wants hands and cannot
## have them says why on the holding page (46_settlements.why_not_staff), not a
## bare "nobody on it" beside a key that does nothing.


func test_a_piece_nobody_can_staff_says_why() -> void:
	var p := Structure.new(1, StructureKind.PLOT, Vector2.ZERO, 0.0)
	eq(UiSettlementScreen.staff_line(p, ""), "nobody on it", "nobody on it, and somebody could be")
	eq(UiSettlementScreen.staff_line(p, "Nowhere for anybody else to sleep here."),
		"Nowhere for anybody else to sleep here.", "nobody can be: it says why")
	p.staffed_by = 3
	eq(UiSettlementScreen.staff_line(p, "Nowhere for anybody else to sleep here."), "worked", "worked is worked")
