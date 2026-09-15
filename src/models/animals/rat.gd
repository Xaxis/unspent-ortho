extends AnimalModel
## A rat: small, low, a long bare tail. Earth, ash or slate. Stands up to look.

const FURS := [[Color("4f3627"), Color("6f4d31")], [Color("3b404a"), Color("5c626e")], [Color("37485a"), Color("52667a")], [Color("33231f"), Color("4f3627")]]


func build() -> void:
	height = 0.16
	part_side = &"none"
	super.build()


func _build_rig() -> void:
	var s := size_jitter(0.14)
	var fur: Array = pick(FURS)
	var c0: Color = fur[0]
	var c1: Color = fur[1]
	var pink := Palette.FLESH[3]
	var root := rig.bone(&"root", -1, Vector3.ZERO)
	var body := rig.bone(&"body", root, Vector3(0, 0.075 * s, 0))
	var bk := rig.kit(body)
	bk.block(0.02 * s, -0.045 * s, 0, 0.14 * s, 0.085 * s, 0.09 * s, c0, c1)
	bk.block(-0.08 * s, -0.05 * s, 0, 0.1 * s, 0.1 * s, 0.11 * s, c0, c1)
	var head := rig.bone(&"head", body, Vector3(0.09 * s, 0.0, 0))
	var hk := rig.kit(head)
	hk.block(0.04 * s, -0.035 * s, 0, 0.08 * s, 0.065 * s, 0.07 * s, c0, c1)
	hk.block(0.095 * s, -0.03 * s, 0, 0.04 * s, 0.035 * s, 0.035 * s, c0)
	hk.block(0.118 * s, -0.02 * s, 0, 0.014, 0.014, 0.018, pink)
	for side: int in [-1, 1]:
		hk.block(0.02 * s, 0.02 * s, side * 0.035 * s, 0.03 * s, 0.03 * s, 0.012, pink.darkened(0.2))
		hk.block(0.06 * s, 0.0, side * 0.036 * s, 0.012, 0.012, 0.008, Palette.INK[0])
	var tail := rig.bone(&"tail", body, Vector3(-0.13 * s, -0.01 * s, 0))
	rig.kit(tail).block(-0.07 * s, -0.008, 0, 0.14 * s, 0.016, 0.016, pink.darkened(0.15))
	var tail2 := rig.bone(&"tail2", tail, Vector3(-0.14 * s, 0, 0))
	rig.kit(tail2).block(-0.07 * s, -0.006, 0, 0.14 * s, 0.012, 0.012, pink.darkened(0.25))
	for side: int in [-1, 1]:
		var sfx := "l" if side < 0 else "r"
		leg("f" + sfx, body, Vector3(0.05 * s, -0.03 * s, side * 0.035 * s), 0.025 * s, 0.022 * s, 0.018, c0, pink, 0.02)
		leg("b" + sfx, body, Vector3(-0.08 * s, -0.03 * s, side * 0.04 * s), 0.025 * s, 0.022 * s, 0.022, c0, pink, 0.02)
	height = 0.16 * s


func _stride(speed: float) -> float:
	return 0.12 + speed * 0.05


func _pose(p: StringName, t: float, speed: float) -> Dictionary:
	var d := {}
	var sniff := sin(clock * 22.0) * 0.08
	d[&"head"] = Vector3(0, sin(clock * 1.3) * 0.3, sniff)
	d[&"tail"] = Vector3(0, sin(clock * 1.1) * 0.3, 0.1)
	d[&"tail2"] = Vector3(0, sin(clock * 1.1 - 0.9) * 0.4, -0.1)
	match p:
		&"walk", &"flee":
			var fast := p == &"flee" or speed > 2.0
			quad_gait(d, gait_phase, &"gallop" if fast else &"trot", 0.7, 1.0)
			d[&"body"] = Vector3(0, 0, sin(TAU * gait_phase) * (0.18 if fast else 0.06))
			d[&"tail"] = Vector3(0, sin(TAU * gait_phase) * 0.3, 0.15)
		&"alert":
			# Up on the haunches, forepaws off the ground.
			d[&"body"] = Vector3(0, 0, 1.05)
			d["@body"] = Vector3(-0.03, 0.03, 0)
			d[&"head"] = Vector3(0, sin(t * 2.0) * 0.4, -0.7 + sniff)
			d[&"fl_u"] = Vector3(0, 0, -0.6)
			d[&"fr_u"] = Vector3(0, 0, -0.6)
			d[&"bl_u"] = Vector3(0, 0, -1.0)
			d[&"br_u"] = Vector3(0, 0, -1.0)
			d[&"tail"] = Vector3(0, 0, -1.0)
		&"windup":
			d[&"body"] = Vector3(0, 0, -0.2)
			d["@body"] = Vector3(-0.02, -0.02, 0)
			d[&"head"] = Vector3(0, 0, 0.3)
		&"strike":
			var k := smoothstep(0.0, 0.1, t)
			d["@body"] = Vector3(0.08 * k, 0.03 * k, 0)
			d[&"head"] = Vector3(0, 0, 0.4)
			d[&"fl_u"] = Vector3(0, 0, 1.0 * k)
			d[&"fr_u"] = Vector3(0, 0, 1.0 * k)
		&"hurt":
			d[&"body"] = Vector3(0.4, 0, 0)
		&"dead":
			var fall := smoothstep(0.0, 0.25, t)
			d[&"root"] = Vector3(PI * fall, 0, 0)
			d["@root"] = Vector3(0, 0.1 * fall, 0)
			for k: String in ["fl", "fr", "bl", "br"]:
				d[StringName(k + "_u")] = Vector3(0.3 if k.ends_with("l") else -0.3, 0, 0.2)
	return d


static func gallery() -> Array:
	return AnimalModel.gallery_for(&"rat", [[&"stand", 0.5, 0.0, 0.4], [&"walk", 0.3, 1.5, 0.4], [&"alert", 0.4, 0.0, 0.4], [&"flee", 0.2, 6.0, 0.4], [&"strike", 0.1, 0.0, 0.4], [&"dead", 1.0, 0.0, 0.4]])
