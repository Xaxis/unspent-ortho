extends AnimalModel
## A gull: a lozenge. White body, slate mantle, a heavy hooked copper bill with a
## red spot, flesh legs, black wingtips crossed over the tail. It lifts when
## approached: &"flee" and &"fly" take it into the air (the root rises; the
## caller moves it across the ground).

const MANTLES := [[Color("52667a"), Color("75899c")], [Color("75899c"), Color("a3b4c4")], [Color("37485a"), Color("52667a")], [Color("868d99"), Color("b8bfc9")]]

## Seconds the land pose takes to come down from flying height.
const LAND_SECONDS := 0.7

var _mantle: Array = []


func build() -> void:
	height = 0.36
	part_side = &"none"
	super.build()


func _build_rig() -> void:
	var s := size_jitter(0.1)
	_mantle = pick(MANTLES)
	var m0: Color = _mantle[0]
	var m1: Color = _mantle[1]
	var white := Palette.LINEN[5]
	var white_lo := Palette.LINEN[4]
	var sd := seed_value * 29 + 13
	var root := rig.bone(&"root", -1, Vector3.ZERO)
	var body := rig.bone(&"body", root, Vector3(0, 0.2 * s, 0))
	var bk := rig.kit(body)
	# The lozenge: full breast, tapering to a tail that points up and back.
	trunk(bk, [
		[-0.22 * s, 0.012 * s, 0.03 * s, 0.03 * s],
		[-0.12 * s, 0.05 * s, 0.06 * s, 0.0],
		[0.03 * s, 0.075 * s, 0.075 * s, -0.01 * s],
		[0.12 * s, 0.05 * s, 0.055 * s, 0.02 * s],
	], 6, [white, white_lo, white], sd, 0.03)
	var head := rig.bone(&"head", body, Vector3(0.13 * s, 0.05 * s, 0))
	var hk := rig.kit(head)
	trunk(hk, [[-0.04 * s, 0.035 * s, 0.035 * s, 0.0], [0.02 * s, 0.05 * s, 0.045 * s, 0.01 * s], [0.07 * s, 0.03 * s, 0.03 * s, 0.0]], 6, white, sd + 1, 0.02)
	# A heavy hooked bill with the red spot near the tip.
	trunk(hk, [[0.06 * s, 0.016 * s, 0.013 * s, -0.004 * s], [0.12 * s, 0.012 * s, 0.009 * s, -0.004 * s], [0.145 * s, 0.006 * s, 0.004 * s, -0.012 * s]], 4, [Palette.COPPER[4], Palette.RUST[3]], sd + 2, 0.0)
	for side: int in [-1, 1]:
		Sculpt.card(hk, Vector3(0.03 * s, 0.022 * s, side * 0.043 * s), Vector3(0.045 * s, 0.022 * s, side * 0.04 * s), Vector3(0.045 * s, 0.034 * s, side * 0.04 * s), Vector3(0.03 * s, 0.034 * s, side * 0.043 * s), Palette.INK[0], Vector3(0.3, 0.2, side).normalized())
	for side: int in [-1, 1]:
		var sfx := "_l" if side < 0 else "_r"
		var w := rig.bone(StringName("wing" + sfx), body, Vector3(0.0, 0.03 * s, side * 0.06 * s))
		# Wings are flat slabs along +Z (their span): mantle grey, black at the tip.
		var wk := rig.kit(w)
		wk.push(Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5 * side), Vector3.ZERO))
		Sculpt.slab(wk, PackedVector2Array([Vector2(-0.1 * s, 0.0), Vector2(0.06 * s, 0.0), Vector2(0.03 * s, 0.17 * s), Vector2(-0.08 * s, 0.17 * s)]), 0.008, m1, m0)
		wk.pop()
		var tip := rig.bone(StringName("tip" + sfx), w, Vector3(-0.02 * s, 0, side * 0.17 * s))
		var tk := rig.kit(tip)
		tk.push(Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5 * side), Vector3.ZERO))
		Sculpt.slab(tk, PackedVector2Array([Vector2(-0.06 * s, 0.0), Vector2(0.05 * s, 0.0), Vector2(0.0, 0.1 * s), Vector2(-0.07 * s, 0.07 * s)]), 0.007, m1, m0)
		Sculpt.slab(tk, PackedVector2Array([Vector2(-0.07 * s, 0.07 * s), Vector2(0.0, 0.1 * s), Vector2(-0.06 * s, 0.17 * s)]), 0.007, Palette.INK[1], Palette.INK[1])
		tk.pop()
	for side: int in [-1, 1]:
		var sfx := "_l" if side < 0 else "_r"
		var lg := rig.bone(StringName("leg" + sfx), body, Vector3(0.0, -0.07 * s, side * 0.03 * s))
		var lk := rig.kit(lg)
		Sculpt.loft(lk, [[-0.13 * s, 0.008, 0.008, 0.0, 0.0], [0.0, 0.01, 0.01, 0.0, 0.0]], 4, Palette.FLESH[3], false, false, PI / 4)
		flap(lk, Vector3(-0.01, -0.13 * s, 0.0), Vector3(0.05, -0.13 * s, -0.025), Vector3(0.05, -0.13 * s, 0.025), Palette.FLESH[2], Palette.FLESH[2])
	height = 0.36 * s


func _stride(speed: float) -> float:
	return 0.12 + speed * 0.04


func _wings_folded(d: Dictionary) -> void:
	# Folded along the flanks, tips swept back over the tail.
	# Span swung back (Y), chord hung down on edge (Z): the wing drapes the flank.
	d[&"wing_l"] = Vector3(0, 1.52, -0.45)
	d[&"wing_r"] = Vector3(0, -1.52, -0.45)
	d[&"tip_l"] = Vector3(0, -0.3, 0.1)
	d[&"tip_r"] = Vector3(0, 0.3, 0.1)


func _pose(p: StringName, t: float, speed: float) -> Dictionary:
	var d := {}
	_wings_folded(d)
	d[&"head"] = Vector3(0, sin(clock * 0.9) * 0.6, 0)
	match p:
		&"stand":
			var peck := fposmod(clock, 4.3)
			var dip := smoothstep(3.4, 3.6, peck) * (1.0 - smoothstep(3.8, 4.1, peck))
			d[&"head"] = Vector3(0, sin(clock * 0.9) * 0.6 * (1.0 - dip), -1.1 * dip)
			d["@head"] = Vector3(0.03 * dip, -0.06 * dip, 0)
		&"walk":
			var w := sin(TAU * gait_phase)
			d[&"body"] = Vector3(w * 0.12, 0, 0)
			d[&"leg_l"] = Vector3(0, 0, 0.5 * w)
			d[&"leg_r"] = Vector3(0, 0, -0.5 * w)
			d[&"head"] = Vector3(0, 0, 0.1 * cos(2.0 * TAU * gait_phase))
		&"alert":
			d["@head"] = Vector3(0.0, 0.05, 0)
			d[&"head"] = Vector3(0, sin(t * 4.0) * 0.4, 0.2)
			d[&"wing_l"] = Vector3(0.15, 1.35, -1.0)
			d[&"wing_r"] = Vector3(-0.15, -1.35, -1.0)
		&"flee", &"fly":
			# Up and away: strong downbeats, legs trailing, body climbing.
			var lift := smoothstep(0.0, 0.5, t) if p == &"flee" else 1.0
			var beat := sin(clock * TAU * 3.2)
			var glide := 0.5 + 0.5 * sin(clock * 0.8)
			var flap := lerpf(beat, 0.15, glide * 0.5 * lift) if p == &"fly" else beat
			d[&"wing_l"] = Vector3(flap * 0.75, -0.15, 0)
			d[&"wing_r"] = Vector3(-flap * 0.75, 0.15, 0)
			d[&"tip_l"] = Vector3(flap * 0.45, 0, 0)
			d[&"tip_r"] = Vector3(-flap * 0.45, 0, 0)
			d[&"leg_l"] = Vector3(0, 0, -1.3)
			d[&"leg_r"] = Vector3(0, 0, -1.3)
			d[&"body"] = Vector3(0, 0, 0.15 * lift)
			d[&"head"] = Vector3(0, 0, -0.1)
			d["@root"] = Vector3(0, lift * (1.4 + beat * 0.03), 0)
		&"land":
			# Down out of the air: wings held up and back to brake, feet reaching.
			var down := smoothstep(0.0, LAND_SECONDS, t)
			var beat := sin(clock * TAU * 2.4) * (1.0 - down)
			d[&"wing_l"] = Vector3(0.6 + beat * 0.5, 0.35 * down, -0.2 * down)
			d[&"wing_r"] = Vector3(-0.6 - beat * 0.5, -0.35 * down, -0.2 * down)
			d[&"tip_l"] = Vector3(0.3, 0, 0)
			d[&"tip_r"] = Vector3(-0.3, 0, 0)
			d[&"leg_l"] = Vector3(0, 0, 0.5 * (1.0 - down))
			d[&"leg_r"] = Vector3(0, 0, 0.5 * (1.0 - down))
			d[&"body"] = Vector3(0, 0, -0.25 * (1.0 - down))
			d["@root"] = Vector3(0, 1.4 * (1.0 - down), 0)
		&"windup":
			d[&"head"] = Vector3(0, 0, 0.5)
			d["@head"] = Vector3(-0.03, 0.04, 0)
			d[&"wing_l"] = Vector3(0.55, 0.5, -0.3)
			d[&"wing_r"] = Vector3(-0.55, -0.5, -0.3)
		&"strike":
			var k := smoothstep(0.0, 0.1, t)
			d[&"body"] = Vector3(0, 0, -0.5 * k)
			d[&"head"] = Vector3(0, 0, -0.6 * k)
			d["@head"] = Vector3(0.06 * k, -0.03 * k, 0)
		&"hurt":
			var f := sin(clock * 30.0)
			d[&"wing_l"] = Vector3(0.3 + f * 0.6, 0.4, -0.2)
			d[&"wing_r"] = Vector3(-0.3 - f * 0.6, -0.4, -0.2)
		&"dead":
			var fall := smoothstep(0.0, 0.3, t)
			d[&"root"] = Vector3(PI * 0.9 * fall, 0, 0)
			d["@root"] = Vector3(0, 0.34 * fall, 0)
			d[&"wing_l"] = Vector3(0.2, 0.3, 0)
			d[&"wing_r"] = Vector3(-0.2, -0.3, 0)
			d[&"head"] = Vector3(0.8, 0, -0.4)
	return d


static func gallery() -> Array:
	return AnimalModel.gallery_for(&"gull", [[&"stand", 0.5, 0.0, 0.55], [&"walk", 0.3, 1.0, 0.55], [&"alert", 0.4, 0.0, 0.55], [&"fly", 0.37, 0.0, 0.55], [&"flee", 0.2, 0.0, 0.55], [&"windup", 0.2, 0.0, 0.55], [&"dead", 1.0, 0.0, 0.55]])
