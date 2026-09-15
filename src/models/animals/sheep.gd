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
	var root := rig.bone(&"root", -1, Vector3.ZERO)
	var body := rig.bone(&"body", root, Vector3(0, 0.4 * s, 0))
	var bk := rig.kit(body)
	bk.block(0, -0.18 * s, 0, 0.62 * s, 0.34 * s, 0.4 * s, f0, f1)
	# The lumpy outline: tufts along the back and flanks, never symmetric.
	for i in 7:
		var x := lerpf(-0.26, 0.24, i / 6.0) * s + (rng.randf() - 0.5) * 0.05
		var side := -1.0 if i % 2 else 1.0
		var tuft := 0.1 + rng.randf() * 0.06
		bk.block(x, 0.12 * s, (rng.randf() - 0.5) * 0.18 * s, tuft * s, 0.05 * s, tuft * 1.2 * s, f1)
		bk.block(x, -0.14 * s + rng.randf() * 0.1, side * 0.2 * s, tuft * s, tuft * s, 0.04, f0 if i % 3 else f1)
	bk.block(-0.32 * s, -0.12 * s, 0, 0.06 * s, 0.24 * s, 0.3 * s, f0, f1)
	var head := rig.bone(&"head", body, Vector3(0.3 * s, -0.02 * s, 0))
	var hk := rig.kit(head)
	hk.block(0.08 * s, -0.12 * s, 0, 0.17 * s, 0.15 * s, 0.13 * s, face)
	hk.block(0.0, 0.0, 0, 0.1 * s, 0.05 * s, 0.14 * s, f1)
	for side: int in [-1, 1]:
		hk.block(0.02 * s, -0.06 * s, side * 0.1 * s, 0.05 * s, 0.03 * s, 0.07 * s, face)
		hk.block(0.12 * s, -0.05 * s, side * 0.067 * s, 0.022, 0.022, 0.012, Palette.LINEN[4] if dark_face else Palette.INK[1])
	var leg_c := face if dark_face else Palette.EARTH[1]
	for side: int in [-1, 1]:
		var sfx := "l" if side < 0 else "r"
		leg("f" + sfx, body, Vector3(0.2 * s, -0.16 * s, side * 0.11 * s), 0.12 * s, 0.12 * s, 0.045 * s, leg_c, Palette.INK[2], 0.03)
		leg("b" + sfx, body, Vector3(-0.21 * s, -0.16 * s, side * 0.11 * s), 0.12 * s, 0.12 * s, 0.05 * s, leg_c, Palette.INK[2], 0.03)
	var tail := rig.bone(&"tail", body, Vector3(-0.33 * s, 0.02 * s, 0))
	rig.kit(tail).block(-0.02, -0.1 * s, 0, 0.05 * s, 0.1 * s, 0.08 * s, f0)
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
