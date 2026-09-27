extends TestCase
## THE CELLAR (SETTLE.md S4): stores a raid cannot loot, the answer to the
## harvester that tribute alone answered. What lies within a standing cellar's
## room is not taken, on paper or by the harvester in the yard (both go through
## RaidResolve.take_stores); a wrecked cellar keeps nothing. It is built with
## `seasoned_timber`, the pinewood saw hall's reward.


func _holding(cellar: bool) -> Settlement:
	var s := Settlement.new(1, Realm.SURFACE, Vector2(20, 20))
	s.add(StructureKind.STORE, Vector2(21, 20))
	if cellar:
		s.add(StructureKind.CELLAR, Vector2(19, 20))
	s.stores = {&"berries": 12, &"timber": 8}
	return s


func test_a_cellar_keeps_the_stores_from_the_harvester() -> void:
	check(StructureKind.buildable(StructureKind.CELLAR), "a cellar can be put up")
	eq(int(StructureKind.cost(StructureKind.CELLAR).get(&"seasoned_timber", 0)), 1, "with seasoned timber in it")
	var d := Items.def(&"seasoned_timber")
	eq(d.get("group", &""), &"material", "seasoned timber is a material")
	near(float(d.get("bulk", 0.0)), 1.5, 1e-6, "of bulk 1.5")
	var open := _holding(false)
	var took_open := RaidResolve.take_stores(open, 20.0)
	var kept := _holding(true)
	var took_kept := RaidResolve.take_stores(kept, 20.0)
	gt(_sum(took_open), 0.0, "without a cellar the harvester takes (%d)" % int(_sum(took_open)))
	eq(_sum(took_kept), 0.0, "with one it takes nothing of what the cellar holds")
	near(kept.stored(), 20.0, 1e-6, "and all 20 are still there")
	# Wrecked, it keeps nothing.
	for p in kept.structures_of(StructureKind.CELLAR):
		kept.destroy_structure(p.id)
	gt(_sum(RaidResolve.take_stores(kept, 20.0)), 0.0, "a wrecked cellar keeps nothing")


func _sum(d: Dictionary) -> float:
	var t := 0.0
	for k: Variant in d:
		t += float(d[k])
	return t
