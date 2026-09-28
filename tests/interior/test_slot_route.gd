extends TestCase
## THE STRING'S ROUTE (SlotRoute.to_ramp): from a face settlement's junction to
## the nearest ramp up out of the slots, along the plan's open ways. Asked of
## every settlement seed 1 grows.


func test_every_settlement_has_a_route_to_a_ramp() -> void:
	var w := BootWorld.world(1, Tuning.WORLD_SIZE)
	var plan := SlotDoors._plan(w)
	var tops := {}
	for k in plan.centre.size():
		if plan.ramp[k] != 0:
			tops[plan.ramp_to[k]] = true
	var n := 0
	var routed := 0
	for t: Threshold in Interiors.thresholds(w):
		if t.kind != &"face_hold":
			continue
		n += 1
		var r := SlotRoute.to_ramp(w, t.door)
		if r.is_empty():
			continue
		routed += 1
		lt(float(r.size()), float(SlotRoute.MOST + 2), "%s: within reach" % t.key)
		lt(r[0].distance_to(t.door), SlotRoute.START_REACH, "%s: from the settlement's own junction" % t.key)
		check(tops.has(r[r.size() - 1]), "%s: to a ramp's top" % t.key)
		# Each step is along an open way: one node to the next, a pitch apart.
		for i in range(1, r.size() - 1):
			near(r[i - 1].distance_to(r[i]), float(GenSlots.PITCH), GenSlots.JITTER * 2.0 + 0.5, "%s: step %d is one node on" % [t.key, i])
	gt(float(n), 0.0, "seed 1 has settlements")
	eq(routed, n, "every settlement has its way out")
