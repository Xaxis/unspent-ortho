extends AnimalModel
## A dog: a wedge. Deep chest, tucked waist, head carried above the back, tail a
## line. Coats from the source (earth 2, ink 2, ash 1, ink 3, earth 1, ash 2),
## never earth 3, which is the colour of the road it stands on.

const COATS := [[Color("4f3627"), Color("6f4d31")], [Color("1e1c2e"), Color("2f2c45")], [Color("3b404a"), Color("5c626e")], [Color("2f2c45"), Color("454263")], [Color("33231f"), Color("4f3627")], [Color("5c626e"), Color("868d99")]]

var _ears_up := true
var _tail_curl := 0.0


func build() -> void:
	height = 0.62
	part_side = &"none"
	super.build()


func _build_rig() -> void:
	var s := size_jitter(0.09)
	var coat: Array = pick(COATS)
	var c0: Color = coat[0]
	var c1: Color = coat[1]
	var patch: Color = [Palette.LINEN[3], Palette.ASH[3], c1, Palette.SAND[4]][rng.randi_range(0, 3)]
	var has_patch := rng.randf() < 0.55
	_ears_up = rng.randf() < 0.6
	_tail_curl = rng.randf() * 0.6
	var ink := Palette.INK[0]
	var leg_c := c0.lerp(c1, 0.3)

	var root := rig.bone(&"root", -1, Vector3.ZERO)
	var body := rig.bone(&"body", root, Vector3(0, 0.4 * s, 0))
	var bk := rig.kit(body)
	# Deep chest, tucked waist, rump: the wedge.
	bk.block(0.16 * s, -0.19 * s, 0, 0.25 * s, 0.32 * s, 0.2 * s, c0, c1)
	bk.block(-0.07 * s, 0.0, 0, 0.22 * s, 0.12 * s, 0.13 * s, c0, c1)
	bk.block(-0.24 * s, -0.07 * s, 0, 0.16 * s, 0.2 * s, 0.17 * s, c0, c1)
	if has_patch:
		bk.block(0.29 * s, -0.17 * s, 0, 0.012, 0.2 * s, 0.1 * s, patch)
	var neck := rig.bone(&"neck", body, Vector3(0.24 * s, 0.08 * s, 0))
	rig.kit(neck).block(0.0, -0.04, 0, 0.12 * s, 0.24 * s, 0.11 * s, c0, c1)
	var head := rig.bone(&"head", neck, Vector3(0.0, 0.19 * s, 0))
	var hk := rig.kit(head)
	hk.block(0.02 * s, -0.05 * s, 0, 0.15 * s, 0.12 * s, 0.14 * s, c0, c1)
	hk.block(0.13 * s, -0.06 * s, 0, 0.1 * s, 0.07 * s, 0.08 * s, patch if has_patch else c0, c1)
	hk.block(0.185 * s, -0.025 * s, 0, 0.022, 0.03, 0.035, ink)
	for side: int in [-1, 1]:
		hk.block(0.09 * s, 0.01 * s, side * 0.04 * s, 0.012, 0.022, 0.022, ink)
		if _ears_up:
			hk.block(-0.01 * s, 0.06 * s, side * 0.045 * s, 0.035 * s, 0.07 * s, 0.035 * s, c0, c1)
		else:
			hk.block(-0.005 * s, -0.04 * s, side * 0.078 * s, 0.05 * s, 0.1 * s, 0.018, c0.darkened(0.15))
	var jaw := rig.bone(&"jaw", head, Vector3(0.08 * s, -0.06 * s, 0))
	var jk := rig.kit(jaw)
	jk.block(0.06 * s, -0.025 * s, 0, 0.12 * s, 0.025 * s, 0.07 * s, c0)
	jk.block(0.11 * s, 0.0, 0, 0.02, 0.012, 0.06 * s, Palette.LINEN[4])
	var tail := rig.bone(&"tail", body, Vector3(-0.33 * s, 0.08 * s, 0))
	rig.kit(tail).block(0, 0, 0, 0.035 * s, 0.14 * s, 0.035 * s, c0, c1)
	var tip := rig.bone(&"tail2", tail, Vector3(0, 0.14 * s, 0))
	rig.kit(tip).block(0, 0, 0, 0.028 * s, 0.13 * s, 0.028 * s, c1)
	for side: int in [-1, 1]:
		var sfx := "l" if side < 0 else "r"
		leg("f" + sfx, body, Vector3(0.22 * s, -0.1 * s, side * 0.065 * s), 0.15 * s, 0.15 * s, 0.055 * s, leg_c, c0.darkened(0.3), 0.06 * s)
		leg("b" + sfx, body, Vector3(-0.26 * s, -0.04 * s, side * 0.07 * s), 0.17 * s, 0.19 * s, 0.06 * s, leg_c, c0.darkened(0.3), 0.06 * s)
	height = 0.62 * s


func _stride(speed: float) -> float:
	return 0.45 + speed * 0.14


func _pose(p: StringName, t: float, speed: float) -> Dictionary:
	var d := {}
	var breath := sin(clock * 5.0) * 0.006
	var wag := sin(clock * 9.0)
	d[&"neck"] = Vector3(0, 0, -0.42)
	d[&"head"] = Vector3(0, sin(clock * 0.7) * 0.35, 0.42)
	d[&"tail"] = Vector3(wag * 0.25, 0, 0.9 - _tail_curl)
	d[&"tail2"] = Vector3(0, 0, 0.3 + _tail_curl)
	d["@body"] = Vector3(0, breath, 0)
	match p:
		&"stand":
			d[&"head"] = Vector3(0, sin(clock * 0.6) * 0.5, 0.4 + sin(clock * 0.33) * 0.12)
			d[&"jaw"] = Vector3(0, 0, -0.15 - absf(sin(clock * 4.0)) * 0.1)
		&"walk", &"flee":
			var run := p == &"flee" or speed > 4.0
			var kind := &"gallop" if run else (&"trot" if speed > 2.4 else &"walk")
			var bob := quad_gait(d, gait_phase, kind, 0.75 if run else 0.45, 1.3 if run else 0.8)
			d["@body"] = Vector3(0, (bob - 0.5) * (0.06 if run else 0.025), 0)
			d[&"body"] = Vector3(0, 0, sin(TAU * gait_phase) * (0.12 if run else 0.0))
			d[&"neck"] = Vector3(0, 0, -1.05 if run else -0.6)
			d[&"head"] = Vector3(0, 0, 0.85 if run else 0.5 + cos(2.0 * TAU * gait_phase) * 0.06)
			if run:
				d[&"tail"] = Vector3(0, 0, 1.9 if p == &"flee" else 1.3)
				d[&"tail2"] = Vector3(0, 0, 0.4)
		&"alert":
			d[&"neck"] = Vector3(0, 0, -0.08)
			d[&"head"] = Vector3(0, 0, 0.12 + sin(t * 3.0) * 0.03)
			d[&"tail"] = Vector3(0, 0, 0.35)
			d[&"tail2"] = Vector3(0, 0, -0.1)
			d[&"fl_u"] = Vector3(0, 0, 0.55)
			d[&"fl_l"] = Vector3(0, 0, -1.2)
			d["@body"] = Vector3(0, 0.015, 0)
		&"windup":
			var snarl := sin(clock * 40.0) * 0.012
			d[&"body"] = Vector3(0, 0, -0.18)
			d["@body"] = Vector3(-0.04, -0.07 + snarl, 0)
			d[&"neck"] = Vector3(0, 0, -1.25)
			d[&"head"] = Vector3(0, 0, 0.95)
			d[&"jaw"] = Vector3(0, 0, -0.35)
			d[&"tail"] = Vector3(0, 0, 1.35)
			d[&"tail2"] = Vector3(0, 0, 0.0)
			d[&"fl_u"] = Vector3(0, 0, 0.45)
			d[&"fl_l"] = Vector3(0, 0, -0.5)
			d[&"fr_u"] = Vector3(0, 0, 0.3)
			d[&"fr_l"] = Vector3(0, 0, -0.35)
			d[&"bl_u"] = Vector3(0, 0, 0.55)
			d[&"bl_l"] = Vector3(0, 0, -0.9)
			d[&"br_u"] = Vector3(0, 0, 0.6)
			d[&"br_l"] = Vector3(0, 0, -0.95)
		&"strike":
			var lunge := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.35, 0.6, t) * 0.4)
			d[&"body"] = Vector3(0, 0, 0.22 * lunge)
			d["@body"] = Vector3(0.18 * lunge, 0.07 * lunge, 0)
			d[&"neck"] = Vector3(0, 0, -1.35)
			d[&"head"] = Vector3(0, 0, 1.05)
			d[&"jaw"] = Vector3(0, 0, -0.75 * lunge)
			d[&"tail"] = Vector3(0, 0, 1.5)
			d[&"fl_u"] = Vector3(0, 0, 1.1 * lunge)
			d[&"fr_u"] = Vector3(0, 0, 0.9 * lunge)
			d[&"fl_l"] = Vector3(0, 0, -0.3)
			d[&"bl_u"] = Vector3(0, 0, -0.8 * lunge)
			d[&"br_u"] = Vector3(0, 0, -0.65 * lunge)
		&"hurt":
			var k := 1.0 - smoothstep(0.1, 0.5, t)
			d[&"body"] = Vector3(0.3 * k, 0, 0.1 * k)
			d["@body"] = Vector3(-0.08 * k, -0.02, 0)
			d[&"neck"] = Vector3(0, 0.5 * k, -0.5)
			d[&"head"] = Vector3(0, 0, 0.2)
			d[&"jaw"] = Vector3(0, 0, -0.5 * k)
			d[&"tail"] = Vector3(0, 0, 2.3)
		&"dead":
			var fall := smoothstep(0.0, 0.35, t)
			d[&"root"] = Vector3(-PI * 0.5 * fall, 0, 0)
			d["@root"] = Vector3(0, 0.1 * fall, 0.36 * fall)
			d[&"neck"] = Vector3(0, 0, -1.5)
			d[&"head"] = Vector3(0, 0, 0.6)
			d[&"jaw"] = Vector3(0, 0, -0.2)
			d[&"tail"] = Vector3(0, 0, 1.6)
			for k: String in ["fl", "fr", "bl", "br"]:
				d[StringName(k + "_u")] = Vector3(0, 0, 0.35 if k.begins_with("f") else -0.35)
				d[StringName(k + "_l")] = Vector3(0, 0, 0.1)
	return d


static func gallery() -> Array:
	return AnimalModel.gallery_for(&"dog", [[&"stand", 0.5, 0.0, 0.9], [&"walk", 0.4, 2.0, 0.9], [&"alert", 0.5, 0.0, 0.9], [&"flee", 0.23, 7.0, 0.9], [&"windup", 0.4, 0.0, 0.9], [&"strike", 0.1, 0.0, 0.9], [&"hurt", 0.1, 0.0, 0.9], [&"dead", 1.0, 0.0, 0.9]])
