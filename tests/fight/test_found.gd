extends TestCase
## Tools in a fight: a found weapon spends its charges and does its full damage;
## with too few it still swings but does what a fist does. Made tools wear by a
## swing. Kit worn counts; kit merely carried counts only for a bag with no
## `worn` slot of its own.

const F := preload("res://tests/fight/fixture.gd")


func _found_def() -> Dictionary:
	return {"name": "test beam", "bulk": 1.0, "tool": true, "stuff": &"found", "wick": 2, "dmg": 7,
		"swing": [70, 90, 110, 130], "reach": 1.3, "width": 1.1, "knock": 5.0, "knock_ms": 180}


func test_a_found_blow_is_full_damage_whatever_its_edge() -> void:
	var b := Blow.from_dict(_found_def())
	b.wick = 2
	b.dmg = 7
	b.dry()
	eq(b.dmg, 1, "dry, it does what a fist does")
	eq(b.cuts, false)
	var made := Blow.for_item(&"knife", 5000)
	eq(made.wick, 0, "a made tool spends nothing")
	eq(made.dmg, 1, "half an edge on a knife is a fist")


func test_charges_are_spent_and_run_out() -> void:
	var inv := Inventory.new()
	inv.add(FightRules.CHARGE, 3)
	check(FightRules.spend_charges(inv, 2), "two of three")
	eq(inv.count(FightRules.CHARGE), 1)
	check(not FightRules.spend_charges(inv, 2), "one is too few")
	eq(inv.count(FightRules.CHARGE), 1, "and nothing is spent trying")
	check(FightRules.spend_charges(inv, 0), "a made tool needs none")


func test_a_swing_wears_the_knife() -> void:
	var sim := F.make_sim()
	var inv := sim.hero.inventory
	inv.add(&"knife")
	inv.set_held(&"knife")
	var before := inv.edge(&"knife")
	sim.press_swing()
	F.ms(sim, 16)
	lt(inv.edge(&"knife"), before, "one use of its edge")
	var e := F.first(sim.drain(), &"swing")
	eq(e.get("dry", true), false)


func test_a_dull_edge_is_noticed_once() -> void:
	var inv := Inventory.new()
	inv.add(&"knife")
	var noticed := 0
	for i in 90:
		if FightRules.wear(inv, &"knife", 1):
			noticed += 1
	eq(noticed, 1, "said once as it passes the line")
	lt(inv.edge(&"knife"), 120.0, "worn to nothing, never broken")
	check(inv.has(&"knife"))


func test_kit_counts() -> void:
	var inv := Inventory.new()
	check(not FightRules.wears(inv, &"plate"))
	check(not FightRules.wears(null, &"plate"))
	if &"worn" in inv:
		inv.set(&"worn", &"")
	check(not FightRules.wears(inv, &"brace"))


func test_a_flash_puts_the_body_back_as_it_was() -> void:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var k := MeshKit.new()
	k.box(Vector3(-0.5, 0, -0.5), Vector3(0.5, 1, 0.5), Palette.FOUND[3], Palette.FOUND[4], true)
	body.mesh = k.build()
	var own := ShaderMaterial.new()
	body.material_override = own
	root.add_child(body)
	var card := MeshInstance3D.new()
	card.mesh = QuadMesh.new()
	var glow := ShaderMaterial.new()
	card.material_override = glow
	root.add_child(card)
	MobFx.set_flash(root, true)
	check(body.material_override != own, "the body flashes")
	eq(card.material_override, glow, "a glow card never does")
	MobFx.set_flash(root, true)
	MobFx.set_flash(root, false)
	eq(body.material_override, own, "and is itself again, even flashed twice")
	root.free()


func test_a_material_changed_during_a_flash_is_kept() -> void:
	var root := Node3D.new()
	var part := MeshInstance3D.new()
	var k := MeshKit.new()
	k.box(Vector3(-0.5, 0, -0.5), Vector3(0.5, 1, 0.5), Palette.FOUND[3], Palette.FOUND[4], true)
	part.mesh = k.build()
	var lit := ShaderMaterial.new()
	part.material_override = lit
	root.add_child(part)
	var shadow := MeshInstance3D.new()
	shadow.mesh = part.mesh
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var shadow_mat := ShaderMaterial.new()
	shadow.material_override = shadow_mat
	root.add_child(shadow)
	MobFx.set_flash(root, true)
	eq(shadow.material_override, shadow_mat, "a shadow-only twin never flashes")
	# The figure relights its part mid-flash, as a machine does.
	var dark := ShaderMaterial.new()
	part.material_override = dark
	MobFx.set_flash(root, false)
	eq(part.material_override, dark, "the figure's own choice stands")
	check(not part.has_meta(&"unflashed"), "and nothing is left set aside")
	MobFx.set_flash(root, true)
	MobFx.set_flash(root, false)
	eq(part.material_override, dark, "a later flash puts back the new one")
	root.free()


## A figure with its own flash is asked, and nothing of it is swapped.
class SelfFlashing:
	extends Node3D
	var flashes: Array[bool] = []

	func set_flash(on: bool) -> void:
		flashes.append(on)


func test_a_figure_that_flashes_itself_is_asked_to() -> void:
	var fig := SelfFlashing.new()
	var body := MeshInstance3D.new()
	var k := MeshKit.new()
	k.box(Vector3(-0.5, 0, -0.5), Vector3(0.5, 1, 0.5), Palette.FOUND[3], Palette.FOUND[4], true)
	body.mesh = k.build()
	var own := ShaderMaterial.new()
	body.material_override = own
	fig.add_child(body)
	MobFx.set_flash(fig, true)
	eq(body.material_override, own, "no swap")
	MobFx.set_flash(fig, false)
	eq(fig.flashes, [true, false] as Array[bool])
	fig.free()
