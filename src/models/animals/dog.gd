extends AnimalModel
## A dog: a wedge. Deep chest, tucked waist, head carried above the back, tail a
## line. Coats from the source (earth 2, ink 2, ash 1, ink 3, earth 1, ash 2),
## never earth 3, which is the colour of the road it stands on.
##
## A dog of the ruin: thin enough to count its ribs, its coat come away in mangy
## patches, an ear torn, and a collar somebody made it from cord or machine cable
## with a plate tag off a machine (a few still show a live pip).

const COATS := [[Color("4f3627"), Color("6f4d31")], [Color("1e1c2e"), Color("2f2c45")], [Color("3b404a"), Color("5c626e")], [Color("2f2c45"), Color("454263")], [Color("33231f"), Color("4f3627")], [Color("5c626e"), Color("868d99")]]

var _ears_up := true
var _tail_curl := 0.0
## Which ear is torn short: -1, +1, or 0 for neither.
var _torn := 0


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
	var lean := 0.76 + rng.randf() * 0.22
	var ink := Palette.INK[0]
	var leg_c := c0.lerp(c1, 0.3)
	var sd := seed_value * 13 + 5

	var root := rig.bone(&"root", -1, Vector3.ZERO)
	var body := rig.bone(&"body", root, Vector3(0, 0.4 * s, 0))
	# The wedge: a deep chest, the waist tucked up under the loin, a small rump.
	trunk(rig.kit(body), [
		[-0.25 * s, 0.05 * s, 0.045 * s, 0.03 * s],
		[-0.19 * s, 0.1 * s, 0.08 * s * lean, 0.01 * s],
		[-0.04 * s, 0.08 * s, 0.066 * s * lean, 0.035 * s],
		[0.1 * s, 0.16 * s, 0.095 * s * lean, -0.03 * s],
		[0.22 * s, 0.11 * s, 0.075 * s * lean, 0.04 * s],
	], 6, [c0, c0, c1, c1], sd)
	_torn = [0, 0, -1, 1][rng.randi_range(0, 3)]
	# Mange: bald patches where the coat has come away, and the ribs showing.
	var mk := rig.kit(body)
	var bare: Color = [Palette.FLESH[2].lerp(c0, 0.35), Palette.ASH[3].lerp(c0, 0.3)][rng.randi_range(0, 1)]
	for i in rng.randi_range(1, 3):
		var px := lerpf(-0.2, 0.14, rng.randf()) * s
		var sz := (0.025 + rng.randf() * 0.025) * s
		if rng.randf() < 0.4:
			var py := 0.095 * s
			Sculpt.card(mk, Vector3(px - sz, py, -sz * 0.8), Vector3(px + sz, py, -sz), Vector3(px + sz * 0.8, py, sz), Vector3(px - sz, py, sz * 0.7), bare, Vector3.UP)
		else:
			var pz := (1 if rng.randf() < 0.5 else -1) * (0.072 * s * lean + 0.008)
			var py := (rng.randf() - 0.6) * 0.07 * s
			Sculpt.card(mk, Vector3(px - sz, py - sz * 0.7, pz), Vector3(px + sz, py - sz, pz), Vector3(px + sz * 0.7, py + sz, pz), Vector3(px - sz, py + sz * 0.8, pz), bare, Vector3(0, 0, signf(pz)))
	if lean < 0.9:
		var rib := c0.darkened(0.4)
		for side: int in [-1, 1]:
			var rz := side * (0.085 * s * lean + 0.006)
			for i in 3:
				var rx := (0.02 + i * 0.045) * s
				Sculpt.card(mk, Vector3(rx - 0.006 * s, -0.1 * s, rz), Vector3(rx + 0.006 * s, -0.1 * s, rz), Vector3(rx + 0.014 * s, 0.01 * s, rz), Vector3(rx + 0.002 * s, 0.01 * s, rz), rib, Vector3(0, 0, side))
	var neck := rig.bone(&"neck", body, Vector3(0.19 * s, 0.08 * s, 0))
	Sculpt.loft(rig.kit(neck), [[-0.08 * s, 0.085 * s, 0.07 * s, -0.01 * s, 0.0], [0.2 * s, 0.06 * s, 0.055 * s, 0.01 * s, 0.0]], 5, [c1], false, false, 0.0, 0.06, sd + 1)
	# The collar: cord, or cable pulled off a machine, with a machine's plate for a tag.
	var cable := rng.randf() < 0.45
	var ck := rig.kit(neck, &"collar", SkinRig.FOUND if cable else SkinRig.MADE)
	Sculpt.loft(ck, [[0.03 * s, 0.092 * s, 0.08 * s, -0.005 * s, 0.0], [0.065 * s, 0.09 * s, 0.078 * s, -0.004 * s, 0.0]], 6, Palette.INK[3] if cable else [Palette.SAND[3], Palette.EARTH[2]][rng.randi_range(0, 1)], false, false, PI / 6)
	machine_tag(neck, Vector3(0.09 * s, 0.035 * s, 0.0), Vector3(-0.3, -1.0, 0.0), Vector3(1, 0, 0), 0.07 * s, rng.randf() < 0.3)
	var head := rig.bone(&"head", neck, Vector3(0.0, 0.17 * s, 0))
	var hk := rig.kit(head)
	hk.push(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.3), Vector3.ZERO))
	# Skull, stop, muzzle, nose: a wedge again, pointing where it is going.
	trunk(hk, [
		[-0.07 * s, 0.055 * s, 0.055 * s, -0.005 * s],
		[0.03 * s, 0.07 * s, 0.068 * s, -0.005 * s],
		[0.09 * s, 0.045 * s, 0.042 * s, -0.03 * s],
		[0.16 * s, 0.032 * s, 0.03 * s, -0.04 * s],
	], 6, [c0, c1, patch if has_patch else c1], sd + 2)
	k_nose(hk, Vector3(0.165 * s, -0.035 * s, 0), 0.02 * s, ink)
	for side: int in [-1, 1]:
		var z := side * 0.04 * s
		Sculpt.card(hk, Vector3(0.07 * s, 0.0, z - 0.012 * s), Vector3(0.07 * s, 0.0, z + 0.012 * s), Vector3(0.07 * s, 0.018 * s, z + 0.012 * s), Vector3(0.07 * s, 0.018 * s, z - 0.012 * s), ink, Vector3(1, 0.4, side * 0.6).normalized())
		if _ears_up:
			# One ear torn short in a fight, on some.
			var tip := 0.065 if side == _torn else 0.11
			flap(hk, Vector3(-0.02 * s, 0.03 * s, side * 0.025 * s), Vector3(0.03 * s, 0.035 * s, side * 0.045 * s), Vector3(-0.01 * s, tip * s, side * 0.05 * s), c1, c0)
		else:
			flap(hk, Vector3(-0.03 * s, 0.04 * s, side * 0.05 * s), Vector3(0.03 * s, 0.04 * s, side * 0.055 * s), Vector3(-0.005 * s, -0.06 * s, side * 0.07 * s), c0.darkened(0.15), c0)
	hk.pop()
	var jaw := rig.bone(&"jaw", head, Vector3(0.1 * s, -0.075 * s, 0))
	var jk := rig.kit(jaw)
	jk.push(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.3), Vector3.ZERO))
	trunk(jk, [[-0.02 * s, 0.014 * s, 0.03 * s, 0.0], [0.08 * s, 0.01 * s, 0.02 * s, 0.004 * s]], 4, c0, sd + 3, 0.0)
	flap(jk, Vector3(0.07 * s, 0.012 * s, -0.012 * s), Vector3(0.07 * s, 0.012 * s, 0.012 * s), Vector3(0.09 * s, 0.03 * s, 0.0), Palette.LINEN[4], Palette.LINEN[4])
	jk.pop()
	var tail := rig.bone(&"tail", body, Vector3(-0.26 * s, 0.08 * s, 0))
	Sculpt.loft(rig.kit(tail), [[0.0, 0.022 * s, 0.022 * s, 0.0, 0.0], [0.15 * s, 0.017 * s, 0.017 * s, 0.0, 0.0]], 4, c0, true, false, PI / 4, 0.05, sd + 4)
	var tip := rig.bone(&"tail2", tail, Vector3(0, 0.14 * s, 0))
	Sculpt.loft(rig.kit(tip), [[0.0, 0.017 * s, 0.017 * s, 0.0, 0.0], [0.13 * s, 0.0, 0.0, 0.0, 0.0]], 4, c1, false, false, PI / 4, 0.05, sd + 5)
	for side: int in [-1, 1]:
		var sfx := "l" if side < 0 else "r"
		leg("f" + sfx, body, Vector3(0.14 * s, -0.1 * s, side * 0.055 * s), 0.15 * s, 0.15 * s, 0.075 * s, leg_c, c0.darkened(0.3), 0.05 * s)
		leg("b" + sfx, body, Vector3(-0.19 * s, -0.04 * s, side * 0.06 * s), 0.17 * s, 0.19 * s, 0.08 * s, leg_c, c0.darkened(0.3), 0.05 * s)
	height = 0.62 * s


## A blunt nose: a little dark pyramid on the end of the muzzle.
static func k_nose(k: MeshKit, at: Vector3, r: float, col: Color) -> void:
	Sculpt.loft(k, [[at.y - r, r, r, at.x, at.z], [at.y + r * 0.6, r * 0.7, r * 0.8, at.x + r * 0.3, at.z]], 4, col, false, true, PI / 4)


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
