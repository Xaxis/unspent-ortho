extends AnimalModel
## A bull: a barrel. Rust-brown, a pale face, horns, dewlap, hump, a tufted tail,
## and no daylight under the belly. When it lowers its head, get off the field.

const HIDES := [[Color("6e3320"), Color("9a4f28")], [Color("4f3627"), Color("6f4d31")], [Color("4a1d18"), Color("6e3320")], [Color("33231f"), Color("4f3627")], [Color("6f4d31"), Color("997044")]]


func build() -> void:
	height = 1.15
	part_side = &"none"
	super.build()


func _build_rig() -> void:
	var s := size_jitter(0.07)
	var hide: Array = pick(HIDES)
	var h0: Color = hide[0]
	var h1: Color = hide[1]
	var pale: Color = [Palette.LINEN[3], Palette.SAND[4], Palette.LINEN[4]][rng.randi_range(0, 2)]
	var horn := Palette.LINEN[4]
	var horn_len := 0.2 + rng.randf() * 0.1
	var sd := seed_value * 23 + 11
	var root := rig.bone(&"root", -1, Vector3.ZERO)
	var body := rig.bone(&"body", root, Vector3(0, 0.66 * s, 0))
	var bk := rig.kit(body)
	# The barrel: deep and round all along, the belly low between short legs so
	# no daylight shows under it, a hump rising over the shoulders.
	trunk(bk, [
		[-0.5 * s, 0.14 * s, 0.14 * s, 0.04 * s],
		[-0.42 * s, 0.28 * s, 0.26 * s, 0.0],
		[-0.18 * s, 0.35 * s, 0.32 * s, -0.05 * s],
		[0.14 * s, 0.37 * s, 0.33 * s, -0.05 * s],
		[0.38 * s, 0.3 * s, 0.27 * s, 0.0],
		[0.48 * s, 0.18 * s, 0.18 * s, 0.03 * s],
	], 7, [h0, h1, h1, h1, h0], sd, 0.06)
	# The hump over the shoulders.
	Sculpt.clump(bk, Vector3(0.22 * s, 0.3 * s, 0), Vector3(0.24 * s, 0.16 * s, 0.2 * s), h1, sd + 1, 6)
	if rng.randf() < 0.35:
		Sculpt.clump(bk, Vector3(-0.1 * s, -0.05 * s, 0.25 * s), Vector3(0.15 * s, 0.12 * s, 0.07 * s), pale, sd + 2, 4)
	var neck := rig.bone(&"neck", body, Vector3(0.44 * s, 0.02 * s, 0))
	var nk := rig.kit(neck)
	trunk(nk, [[-0.1 * s, 0.28 * s, 0.24 * s, -0.04 * s], [0.22 * s, 0.2 * s, 0.18 * s, -0.14 * s]], 6, h0, sd + 3, 0.05, false)
	# Dewlap: a fold of hide hanging under the throat.
	flap(nk, Vector3(-0.05 * s, -0.3 * s, 0), Vector3(0.18 * s, -0.28 * s, 0), Vector3(0.08 * s, -0.46 * s, 0), h0, h0)
	var head := rig.bone(&"head", neck, Vector3(0.2 * s, -0.08 * s, 0))
	var hk := rig.kit(head)
	# Carried low and square, the pale face a broad plate in front.
	hk.push(Transform3D(Basis(Vector3(0, 0, 1), -0.9), Vector3(0.02 * s, -0.04 * s, 0)))
	trunk(hk, [
		[-0.06 * s, 0.14 * s, 0.16 * s, 0.0],
		[0.12 * s, 0.15 * s, 0.16 * s, 0.0],
		[0.28 * s, 0.1 * s, 0.11 * s, -0.02 * s],
		[0.34 * s, 0.07 * s, 0.09 * s, -0.02 * s],
	], 6, [h1, pale, pale], sd + 4, 0.04)
	hk.pop()
	var nose := Vector3(0.22 * s, -0.33 * s, 0)
	Sculpt.loft(hk, [[nose.y - 0.03 * s, 0.05 * s, 0.08 * s, nose.x, 0.0], [nose.y + 0.04 * s, 0.05 * s, 0.085 * s, nose.x, 0.0]], 6, Palette.INK[2], false, true, PI / 6)
	for side: int in [-1, 1]:
		# Horns: out to the side, then up and forward.
		hk.push(Transform3D(Basis(Vector3(1, 0, 0), side * 1.3), Vector3(0.08 * s, 0.06 * s, side * 0.13 * s)))
		Sculpt.loft(hk, [[0.0, 0.055 * s, 0.055 * s, 0.0, 0.0], [horn_len * 0.7 * s, 0.04 * s, 0.04 * s, 0.03 * s, 0.0], [horn_len * s, 0.03 * s, 0.03 * s, 0.07 * s, 0.0]], 5, horn, false, false, 0.0, 0.04, sd + 5)
		hk.pop()
		var tipb := Vector3(0.06 * s, 0.1 * s + horn_len * 0.2 * s, side * (0.14 + horn_len * 0.95) * s)
		Sculpt.loft(hk, [[tipb.y, 0.03 * s, 0.03 * s, tipb.x, tipb.z], [tipb.y + 0.12 * s, 0.0, 0.0, tipb.x + 0.05 * s, tipb.z - side * 0.03 * s]], 5, [Palette.LINEN[5]], false, false, 0.0)
		flap(hk, Vector3(-0.04 * s, 0.02 * s, side * 0.15 * s), Vector3(0.02 * s, 0.0, side * 0.16 * s), Vector3(-0.04 * s, -0.05 * s, side * 0.25 * s), h0, h1)
		Sculpt.card(hk, Vector3(0.1 * s, -0.04 * s, side * 0.155 * s), Vector3(0.14 * s, -0.06 * s, side * 0.15 * s), Vector3(0.14 * s, -0.035 * s, side * 0.15 * s), Vector3(0.1 * s, -0.015 * s, side * 0.155 * s), Palette.INK[0], Vector3(0.2, 0.1, side).normalized())
	var tail := rig.bone(&"tail", body, Vector3(-0.48 * s, 0.2 * s, 0))
	Sculpt.loft(rig.kit(tail), [[-0.5 * s, 0.02 * s, 0.02 * s, 0.0, 0.0], [0.0, 0.03 * s, 0.03 * s, 0.0, 0.0]], 4, h0, false, false, PI / 4, 0.05, sd + 6)
	var tuft := rig.bone(&"tail2", tail, Vector3(0, -0.5 * s, 0))
	Sculpt.clump(rig.kit(tuft), Vector3(0, -0.07 * s, 0), Vector3(0.04 * s, 0.08 * s, 0.04 * s), Palette.INK[2], sd + 7, 4)
	for side: int in [-1, 1]:
		var sfx := "l" if side < 0 else "r"
		leg("f" + sfx, body, Vector3(0.28 * s, -0.36 * s, side * 0.18 * s), 0.16 * s, 0.15 * s, 0.15 * s, h0, Palette.INK[1], 0.03)
		leg("b" + sfx, body, Vector3(-0.32 * s, -0.36 * s, side * 0.18 * s), 0.16 * s, 0.15 * s, 0.16 * s, h0, Palette.INK[1], 0.03)
	height = 1.15 * s


func _stride(speed: float) -> float:
	return 0.7 + speed * 0.16


func _pose(p: StringName, t: float, speed: float) -> Dictionary:
	var d := {}
	var breath := sin(clock * 2.2)
	d["@body"] = Vector3(0, breath * 0.006, 0)
	d[&"tail"] = Vector3(sin(clock * 1.7) * 0.25, 0, -0.1)
	d[&"tail2"] = Vector3(sin(clock * 1.7 - 0.8) * 0.3, 0, 0)
	d[&"neck"] = Vector3(0, 0, -0.1)
	d[&"head"] = Vector3(0, sin(clock * 0.4) * 0.15, -0.15)
	match p:
		&"walk":
			var bob := quad_gait(d, gait_phase, &"walk", 0.3, 0.6)
			d["@body"] = Vector3(0, (bob - 0.5) * 0.03, 0)
			d[&"body"] = Vector3(sin(TAU * gait_phase) * 0.03, 0, 0)
			d[&"head"] = Vector3(0, 0, -0.25 + cos(2.0 * TAU * gait_phase) * 0.05)
		&"alert":
			d[&"neck"] = Vector3(0, 0, 0.15)
			d[&"head"] = Vector3(0, 0, 0.05)
			d[&"tail"] = Vector3(0, 0, -0.35)
		&"windup":
			# Head down, horns levelled, a forefoot tearing at the ground.
			var paw := fposmod(t, 0.7) / 0.7
			d[&"neck"] = Vector3(0, 0, -0.45)
			d[&"head"] = Vector3(0, 0, -0.55)
			d[&"body"] = Vector3(0, 0, -0.05)
			d["@body"] = Vector3(-0.05, -0.03, 0)
			d[&"fr_u"] = Vector3(0, 0, 0.45 - 0.9 * smoothstep(0.2, 0.7, paw))
			d[&"fr_l"] = Vector3(0, 0, -0.9 * sin(paw * PI))
			d[&"tail"] = Vector3(sin(clock * 6.0) * 0.4, 0, -0.9)
		&"strike", &"flee":
			var run := speed > 1.0 or p == &"flee"
			if run:
				var bob := quad_gait(d, gait_phase, &"gallop", 0.6, 1.0)
				d["@body"] = Vector3(0, bob * 0.08, 0)
				d[&"body"] = Vector3(0, 0, sin(TAU * gait_phase) * 0.08)
			if p == &"strike":
				# The toss: horns low, then hooking up through whatever is there.
				var toss := smoothstep(0.08, 0.28, t) * (1.0 - smoothstep(0.5, 0.8, t))
				d[&"neck"] = Vector3(0, 0, lerpf(-0.5, 0.35, toss))
				d[&"head"] = Vector3(0, 0.15 * toss, lerpf(-0.6, 0.2, toss))
				d["@body"] = (d["@body"] as Vector3) + Vector3(0.12 * smoothstep(0.0, 0.15, t), 0.03 * toss, 0)
				d[&"tail"] = Vector3(0, 0, -1.1)
			else:
				d[&"neck"] = Vector3(0, 0, 0.0)
				d[&"head"] = Vector3(0, 0, -0.1)
		&"hurt":
			var k := 1.0 - smoothstep(0.1, 0.5, t)
			d[&"body"] = Vector3(0.12 * k, 0, 0.05 * k)
			d["@body"] = Vector3(-0.05 * k, 0, 0)
			d[&"neck"] = Vector3(0, 0.3 * k, 0.2 * k)
		&"dead":
			var fall := smoothstep(0.0, 0.5, t)
			d[&"root"] = Vector3(-PI * 0.5 * fall, 0, 0)
			d["@root"] = Vector3(0, 0.3 * fall, 0.62 * fall)
			d[&"neck"] = Vector3(0, 0, -0.3)
			d[&"head"] = Vector3(0, 0, -0.2)
			for k: String in ["fl", "fr", "bl", "br"]:
				d[StringName(k + "_u")] = Vector3(0, 0, 0.3 if k.begins_with("f") else -0.3)
	return d


static func gallery() -> Array:
	return AnimalModel.gallery_for(&"bull", [[&"stand", 1.0, 0.0, 1.7], [&"walk", 0.4, 2.0, 1.7], [&"windup", 0.3, 0.0, 1.7], [&"strike", 0.2, 6.0, 1.7], [&"alert", 0.4, 0.0, 1.7], [&"hurt", 0.1, 0.0, 1.7], [&"dead", 1.0, 0.0, 1.7]])
