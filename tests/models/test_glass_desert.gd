extends TestCase
## The Glass Desert's models (docs/LANDSCAPES.md §3), held to the contracts the
## other model tests cannot see: the machine tests walk twelve named kinds and
## the sentinel tests build a keeper only for its ramp, so a fault in the
## skater's or the anvil's `build()` would surface in a gallery frame and
## nowhere else. And the four props carry claims of their own — the glass is
## GLASS, the rod's tip is the machines' cold on the beacon's beat, and each
## does what the landscape's file says it does to a body.

const Glass := preload("res://src/models/props/glass_desert.gd")
const Works := preload("res://src/models/props/works.gd")
const Hazards52 := preload("res://src/systems/52_hazards.gd")

const PROPS: Array[int] = [PropKind.FULGURITE, PropKind.GLASS_BLISTER, PropKind.FUSED_CAR, PropKind.STRIKE_ROD]


static func _land() -> int:
	return BiomeRegistry.index_of(&"glass_desert")


static func _marked(cols: PackedColorArray, code: int) -> int:
	var n := 0
	for col in cols:
		if roundi(col.a * 255.0) == code:
			n += 1
	return n


func test_its_two_machines_build_within_the_budget_and_on_their_ramps() -> void:
	# The skater borrows the longlegs' ramp (Palette.MACHINE is a solved packing
	# of twelve) and the anvil wears the keeper's, like every keeper.
	for spec: Array in [[&"skater", Palette.MACHINE["longlegs"], 0.72], [&"sentinel_anvil", Palette.MACHINE["warden"], 8.2]]:
		var kid: StringName = spec[0]
		var m := FigureModel.create(kid)
		check(m is MachineModel, "%s draws with a machine's body" % kid)
		var mm := m as MachineModel
		eq(mm.ramp, spec[1], "%s is on its ramp" % kid)
		near(mm.height, float(spec[2]), 1e-6, "%s's height is what a tell has to clear" % kid)
		lt(float(m.draw_calls()), 7.0, "%s draw calls (budget 6)" % kid)
		for p: StringName in MachineModel.POSES:
			mm.set_pose(p)
			mm.settle()
		mm.animate(0.1, 1.0)
		check(mm.part_anchor != null, "%s has a working part to hit" % kid)
		m.free()


func test_the_glass_is_glass_and_the_one_lamp_is_the_rods() -> void:
	var land := _land()
	for kind: int in [PropKind.FULGURITE, PropKind.GLASS_BLISTER, PropKind.FUSED_CAR]:
		for v in PropModels.variants(kind, land):
			var t := PropModels.template(kind, v, land)
			gt(float(_marked(t.made_c, GroundColors.GLASS)), 0.0, "%s %d carries the GLASS row on its made faces" % [PropKind.NAMES[kind], v])
			# No made mark may reach the FOUND pen: there it is a lamp, and only
			# the rod has one.
			for col in t.found_c:
				check(col.a >= 0.98, "%s %d has a FOUND face at alpha %.3f: a made mark on the wrong pen is a blinking lamp" % [PropKind.NAMES[kind], v, col.a])
	var rod := PropModels.template(PropKind.STRIKE_ROD, 0, land)
	var blinking := 0
	for col in rod.found_c:
		if col.a < 0.5:
			blinking += 1
	gt(float(blinking), 0.0, "the rod's tip blinks (a FOUND alpha under 0.5)")
	# And it blinks the machines' own cold: STRIP's colour at BEACON's alpha,
	# so the one lamp on the landscape is on the machines' arc.
	near(Glass.TIP.r, Works.STRIP.r, 1e-4, "the tip is the strip's red")
	near(Glass.TIP.g, Works.STRIP.g, 1e-4, "the tip is the strip's green")
	near(Glass.TIP.b, Works.STRIP.b, 1e-4, "the tip is the strip's blue")
	near(Glass.TIP.a, Works.BEACON.a, 1e-4, "on the beacon's alpha, so it blinks")
	var glow := PropModels.glow_points(PropKind.STRIKE_ROD, 0, land)
	eq(glow.size(), 1, "the rod declares its one light")
	check(bool(glow[0].get("blink", false)), "and it is on the machines' beat")
	near((glow[0].color as Color).r, Glass.TIP.r, 1e-4, "the light is the colour the geometry is drawn in")
	for kind: int in PROPS:
		for v in PropModels.variants(kind, land):
			gt(float(PropModels.template(kind, v, land).made_v.size() + PropModels.template(kind, v, land).found_v.size()), 11.0,
				"%s %d is modelled" % [PropKind.NAMES[kind], v])


func test_each_is_drawn_in_the_pen_it_is_made_of() -> void:
	var land := _land()
	for v in 3:
		var f := PropModels.template(PropKind.FULGURITE, v, land)
		eq(f.found_v.size(), 0, "a fulgurite %d is sand, fused: nothing ruled on it" % v)
	for v in 2:
		var b := PropModels.template(PropKind.GLASS_BLISTER, v, land)
		eq(b.found_v.size(), 0, "a blister %d is the sheet, burst: nothing ruled on it" % v)
		var car := PropModels.template(PropKind.FUSED_CAR, v, land)
		gt(float(car.found_v.size()), 0.0, "a fused car %d is a FOUND body" % v)
		gt(float(car.made_v.size()), 0.0, "in a MADE pool, with a melted flank drawn by the hand")
	var rod := PropModels.template(PropKind.STRIKE_ROD, 0, land)
	gt(float(rod.found_v.size()), float(rod.made_v.size()), "a strike rod is mostly ruled: it is the plan's")


func test_each_does_to_a_body_what_the_landscape_says() -> void:
	# A fulgurite is broken for its tubes on the sand, consumed, and leaves rubble.
	var fulg: Array = Takes.options(PropKind.FULGURITE)
	eq(fulg.size(), 1, "one way to take a fulgurite")
	eq(fulg[0].item, &"fulgurite", "and it gives the raw of the landscape's own material")
	eq(int(fulg[0].uses), 2, "twice")
	check(not bool(fulg[0].keep), "then it is gone")
	check((fulg[0].ground as Array).has(Ground.SAND), "held to the sand it stands in")
	eq(RemnantModels.for_kind(PropKind.FULGURITE), &"rubble", "what is left is rubble")
	# A blister gives nothing, shelters, and a body steps into it.
	check(Takes.GIVES_NOTHING.has(PropKind.GLASS_BLISTER), "a blister gives nothing, and says why")
	check(Hazards52.ROOFS.has(PropKind.GLASS_BLISTER), "it is shade")
	near(PropKind.SOLID[PropKind.GLASS_BLISTER], 0.0, 1e-6, "and a body walks into it")
	# A fused car is stripped and pried, stands, and is cover.
	var car: Array = Takes.options(PropKind.FUSED_CAR)
	eq(car.size(), 2, "strip, then pry")
	eq(car[0].item, &"scrap")
	eq(car[1].item, &"copper_ore")
	eq(car[1].stuff, &"steel", "the copper wants a steel edge")
	for o: Dictionary in car:
		check(bool(o.keep), "the car stands (%s)" % o.verb)
	check(Cover.PROPS.has(PropKind.FUSED_CAR), "and it is cover")
	# A strike rod is robbed of its copper by hand and it is theft.
	var rod: Array = Takes.options(PropKind.STRIKE_ROD)
	eq(rod.size(), 1)
	eq(rod[0].item, &"copper")
	eq(rod[0].verb, &"turn", "by hand")
	check(Takes.is_plan_work(PropKind.STRIKE_ROD), "and it is the plan's, so robbing it is filed")
