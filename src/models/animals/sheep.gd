extends AnimalModel
## A sheep: a brick. No waist, no neck, the head carried low, a lumpy fleece
## outline. Fleeces run clean to muddy; faces dark or pale, by seed.

const FLEECE := [[Color("c0b394"), Color("e8dcc0")], [Color("ad9370"), Color("d8c193")], [Color("968a76"), Color("c0b394")], [Color("868d99"), Color("b8bfc9")], [Color("33231f"), Color("4f3627")]]
const FACE := [Color("1e1c2e"), Color("2f2c45"), Color("c0b394"), Color("33231f")]


func build() -> void:
	height = 0.66
	part_side = &"none"
	super.build()


func _build_rig() -> void:
	var s := size_jitter(0.08)
	var fl: Array = FLEECE[0] if rng.randf() < 0.45 else (FLEECE[4] if rng.randf() < 0.08 else pick(FLEECE.slice(1, 4)))
	var f0: Color = fl[0]
	var f1: Color = fl[1]
	var face: Color = pick(FACE)
	var dark_face := face.get_luminance() < 0.3
	var sd := seed_value * 17 + 3
	var root := rig.bone(&"root", -1, Vector3.ZERO)
	var body := rig.bone(&"body", root, Vector3(0, 0.4 * s, 0))
	var bk := rig.kit(body)
	# The brick: no waist, no neck, square in section, then broken up by fleece.
	trunk(bk, [
		[-0.36 * s, 0.1 * s, 0.12 * s, -0.02 * s],
		[-0.27 * s, 0.17 * s, 0.19 * s, -0.01 * s],
		[0.0, 0.18 * s, 0.2 * s, -0.01 * s],
		[0.24 * s, 0.17 * s, 0.19 * s, 0.0],
		[0.33 * s, 0.1 * s, 0.12 * s, 0.0],
	], 7, [f0, f1, f1, f0], sd, 0.12)
	# The lumpy outline: fleece clumps along the back and down the flanks, never symmetric.
	for i in 9:
		var u := i / 8.0
		var x := lerpf(-0.3, 0.26, u) * s + (rng.randf() - 0.5) * 0.05 * s
		var z := (0.13 if i % 2 == 0 else -0.13) * s + (rng.randf() - 0.5) * 0.08 * s
		var r := (0.085 + rng.randf() * 0.045) * s
		var y := (0.12 + rng.randf() * 0.04) * s if i % 3 != 2 else -0.02 * s
		Sculpt.clump(bk, Vector3(x, y, z * (1.25 if i % 3 == 2 else 1.0)), Vector3(r, r * 0.75, r), f1 if i % 3 else f0, sd + 10 + i, 5)
	var head := rig.bone(&"head", body, Vector3(0.3 * s, -0.02 * s, 0))
	var hk := rig.kit(head)
	# Carried low: the face hangs forward and down from a woolly poll.
	hk.push(Transform3D(Basis(Vector3(0, 0, 1), -0.55), Vector3.ZERO))
	trunk(hk, [
		[-0.02 * s, 0.06 * s, 0.06 * s, 0.0],
		[0.08 * s, 0.07 * s, 0.06 * s, -0.01 * s],
		[0.19 * s, 0.045 * s, 0.035 * s, -0.02 * s],
	], 6, [face, face], sd + 2)
	hk.pop()
	Sculpt.clump(hk, Vector3(0.02 * s, 0.06 * s, 0), Vector3(0.07 * s, 0.045 * s, 0.07 * s), f1, sd + 3, 4)
	for side: int in [-1, 1]:
		flap(hk, Vector3(0.02 * s, 0.02 * s, side * 0.05 * s), Vector3(0.05 * s, 0.0, side * 0.06 * s), Vector3(-0.01 * s, -0.03 * s, side * 0.13 * s), face, face.darkened(0.2))
		var ex := 0.09 * s
		Sculpt.card(hk, Vector3(ex, -0.03 * s, side * 0.052 * s), Vector3(ex + 0.02 * s, -0.045 * s, side * 0.05 * s), Vector3(ex + 0.02 * s, -0.03 * s, side * 0.05 * s), Vector3(ex, -0.015 * s, side * 0.052 * s), Palette.LINEN[4] if dark_face else Palette.INK[1], Vector3(0.3, 0.2, side).normalized())
	var leg_c := face if dark_face else Palette.EARTH[1]
	for side: int in [-1, 1]:
		var sfx := "l" if side < 0 else "r"
		leg("f" + sfx, body, Vector3(0.2 * s, -0.16 * s, side * 0.11 * s), 0.12 * s, 0.12 * s, 0.05 * s, leg_c, Palette.INK[2], 0.02)
		leg("b" + sfx, body, Vector3(-0.21 * s, -0.16 * s, side * 0.11 * s), 0.12 * s, 0.12 * s, 0.055 * s, leg_c, Palette.INK[2], 0.02)
	var tail := rig.bone(&"tail", body, Vector3(-0.33 * s, 0.02 * s, 0))
	Sculpt.clump(rig.kit(tail), Vector3(-0.02 * s, -0.06 * s, 0), Vector3(0.035 * s, 0.06 * s, 0.04 * s), f0, sd + 4, 4)
	height = 0.66 * s


func _stride(speed: float) -> float:
	return 0.35 + speed * 0.12


func _pose(p: StringName, t: float, speed: float) -> Dictionary:
	var d := {}
	d["@body"] = Vector3(0, sin(clock * 4.0) * 0.004, 0)
	d[&"tail"] = Vector3(sin(clock * 3.0) * 0.1, 0, 0)
	match p:
		&"stand":
			# Graze: head down for a while, up to chew and look.
			var cycle := fposmod(clock, 7.0)
			var down := smoothstep(0.0, 0.6, cycle) * (1.0 - smoothstep(4.2, 4.9, cycle))
			d[&"head"] = Vector3(0, sin(clock * 0.5) * 0.2 * (1.0 - down), lerpf(0.1, -0.9, down) + sin(clock * 9.0) * 0.03 * (1.0 - down))
		&"walk":
			var bob := quad_gait(d, gait_phase, &"walk", 0.35, 0.7)
			d["@body"] = Vector3(0, (bob - 0.5) * 0.02, 0)
			d[&"head"] = Vector3(0, 0, -0.25 + cos(2.0 * TAU * gait_phase) * 0.06)
		&"flee":
			# Bounding: all four feet leave the ground together.
			var hop := absf(sin(TAU * gait_phase))
			quad_gait(d, gait_phase, &"gallop", 0.5, 0.9)
			d["@body"] = Vector3(0, hop * 0.14, 0)
			d[&"body"] = Vector3(0, 0, cos(TAU * gait_phase) * 0.12)
			d[&"head"] = Vector3(0, 0, 0.35)
			d[&"tail"] = Vector3(0, 0, -0.6)
		&"alert":
			d[&"head"] = Vector3(0, 0, 0.55)
			d["@head"] = Vector3(0, 0.07, 0)
			var stamp := maxf(0.0, sin(t * 7.0)) if fposmod(t, 2.0) < 0.6 else 0.0
			d[&"fl_u"] = Vector3(0, 0, stamp * 0.4)
			d[&"fl_l"] = Vector3(0, 0, -stamp * 0.8)
		&"windup":
			d[&"body"] = Vector3(0, 0, -0.1)
			d["@body"] = Vector3(-0.05, -0.02, 0)
			d[&"head"] = Vector3(0, 0, -0.55)
			d[&"bl_u"] = Vector3(0, 0, 0.3)
			d[&"br_u"] = Vector3(0, 0, 0.3)
		&"strike":
			var k := smoothstep(0.0, 0.12, t)
			d["@body"] = Vector3(0.14 * k, 0.02, 0)
			d[&"head"] = Vector3(0, 0, -0.35 + 0.3 * k)
			d[&"fl_u"] = Vector3(0, 0, 0.6 * k)
			d[&"fr_u"] = Vector3(0, 0, 0.5 * k)
			d[&"bl_u"] = Vector3(0, 0, -0.5 * k)
			d[&"br_u"] = Vector3(0, 0, -0.55 * k)
		&"hurt":
			var k := 1.0 - smoothstep(0.1, 0.5, t)
			d[&"body"] = Vector3(0.25 * k, 0, 0)
			d["@body"] = Vector3(-0.06 * k, 0, 0)
			d[&"head"] = Vector3(0, 0.4 * k, 0.4 * k)
		&"dead":
			var fall := smoothstep(0.0, 0.4, t)
			d[&"root"] = Vector3(-PI * 0.5 * fall, 0, 0)
			d["@root"] = Vector3(0, 0.18 * fall, 0.38 * fall)
			d[&"head"] = Vector3(0, 0, -0.3)
			for k: String in ["fl", "fr", "bl", "br"]:
				d[StringName(k + "_u")] = Vector3(0, 0, 0.25 if k.begins_with("f") else -0.25)
	return d


static func gallery() -> Array:
	return AnimalModel.gallery_for(&"sheep", [[&"stand", 1.5, 0.0, 0.95], [&"walk", 0.4, 1.5, 0.95], [&"alert", 0.2, 0.0, 0.95], [&"flee", 0.2, 5.0, 0.95], [&"stand", 3.0, 0.0, 0.95], [&"strike", 0.1, 0.0, 0.95], [&"hurt", 0.1, 0.0, 0.95], [&"dead", 1.0, 0.0, 0.95]])
