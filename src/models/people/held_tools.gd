class_name HeldTools
## Everything a hand can hold: the made ladder, found weapons, and how each one
## is swung. Geometry is in the `tool` bone's frame: the handle runs along +Y
## from the grip at the origin; a blade's edge leads on +X (the side that moves
## first in a forward chop).
##
## MADE tools use the coast ramps, worn and slightly uneven. FOUND weapons are
## exact and symmetric in the violet FOUND ramp with their light on a glow mesh:
## anyone should see at a glance that nobody on this coast made one.

const MADE: Array[StringName] = [&"knife", &"knife_shear", &"billhook", &"axe_hand", &"axe_felling", &"axe_works", &"pick", &"mattock", &"mattock_steel", &"stave", &"boathook"]
const FOUND: Array[StringName] = [&"las_hand", &"las_long", &"las_broad", &"arc_cut", &"mono_blade", &"stun_hand", &"pulse_hammer", &"rep_light", &"beam_lance", &"flash_burst", &"sonic_wave", &"plasma_torch"]

## How a thing is swung. Each class has its own arc in PersonAnim.
##   fist   jab from the guard              blade  quick forehand slash
##   hook   high diagonal cut               axe    one-handed overhead chop
##   heavy  two-handed chop from behind     pick   two-handed overhead strike
##   sweep  two-handed wide flat swing      thrust two-handed lunge along the shaft
##   point  arm out, the device does the work
const CLASS := {
	&"": &"fist",
	&"knife": &"blade", &"knife_shear": &"blade", &"mono_blade": &"blade", &"plasma_torch": &"blade", &"las_hand": &"blade",
	&"billhook": &"hook",
	&"axe_hand": &"axe", &"axe_works": &"axe",
	&"axe_felling": &"heavy",
	&"pick": &"pick", &"mattock": &"pick", &"mattock_steel": &"pick", &"pulse_hammer": &"pick",
	&"stave": &"sweep", &"las_long": &"sweep", &"las_broad": &"sweep", &"sonic_wave": &"sweep",
	&"boathook": &"thrust", &"beam_lance": &"thrust",
	&"arc_cut": &"point", &"stun_hand": &"point", &"rep_light": &"point", &"flash_burst": &"point",
}

## [windup, active, recovery, cooldown] ms (design-extract §6.4, §9.2, §9.3), used
## when Items.DEFS has no `swing` for the id yet.
const SWING_MS := {
	&"": [70, 80, 110, 180],
	&"knife": [60, 100, 120, 140], &"stave": [90, 110, 130, 150], &"boathook": [160, 120, 200, 240],
	&"billhook": [100, 110, 150, 170], &"axe_hand": [130, 120, 170, 200], &"mattock": [180, 130, 220, 260],
	&"pick": [180, 130, 220, 260], &"knife_shear": [55, 95, 105, 125], &"axe_felling": [230, 150, 260, 300],
	&"mattock_steel": [190, 130, 230, 270], &"axe_works": [170, 140, 200, 230],
	&"las_hand": [70, 90, 110, 130], &"las_long": [160, 110, 190, 230], &"las_broad": [140, 120, 170, 210],
	&"arc_cut": [60, 80, 100, 120], &"mono_blade": [45, 80, 90, 110], &"stun_hand": [80, 100, 120, 150],
	&"pulse_hammer": [190, 130, 210, 250], &"rep_light": [40, 70, 70, 90], &"beam_lance": [120, 90, 150, 180],
	&"flash_burst": [50, 90, 100, 130], &"sonic_wave": [110, 120, 140, 170], &"plasma_torch": [150, 110, 180, 220],
}

## Where the off hand holds the handle, in tool units along +Y: [preferred, lowest,
## highest]. A hand slides along a haft, so when the preferred grip is out of
## reach the off hand takes the nearest point of the range. Absent = one hand.
const OFF_GRIP := {
	&"axe_felling": [-0.34, -0.4, 0.2], &"pick": [-0.3, -0.38, 0.3], &"mattock": [-0.3, -0.38, 0.3], &"mattock_steel": [-0.3, -0.38, 0.3],
	&"pulse_hammer": [-0.26, -0.32, 0.28], &"stave": [0.42, -0.6, 0.65], &"las_long": [-0.24, -0.28, 0.1],
	&"las_broad": [-0.2, -0.22, 0.1], &"sonic_wave": [-0.18, -0.2, 0.08], &"boathook": [0.45, -0.55, 0.8], &"beam_lance": [0.4, -0.48, 0.66],
}


static func all_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(MADE)
	out.append_array(FOUND)
	return out


static func klass(id: StringName) -> StringName:
	return CLASS.get(id, &"blade" if id != &"" else &"fist")


static func is_found(id: StringName) -> bool:
	return FOUND.has(id)


static func two_handed(id: StringName) -> bool:
	return OFF_GRIP.has(id)


static func off_grip(id: StringName) -> float:
	return float(OFF_GRIP[id][0]) if OFF_GRIP.has(id) else 0.0


## [lowest, highest] the off hand may slide to along the handle.
static func off_range(id: StringName) -> Vector2:
	return Vector2(float(OFF_GRIP[id][1]), float(OFF_GRIP[id][2])) if OFF_GRIP.has(id) else Vector2.ZERO


## [windup, active, recovery, cooldown] in ms: the item table wins when it has one.
static func swing_ms(id: StringName) -> Array[int]:
	var out: Array[int] = []
	var def := Items.def(id)
	var src: Array = def.get("swing", SWING_MS.get(id, SWING_MS[&""]))
	for v: Variant in src:
		out.append(int(v))
	while out.size() < 4:
		out.append(100)
	return out


## Add the tool's geometry to the rig's tool bone. Returns false for bare hands
## or an id with no model (the hand stays empty rather than showing a wrong thing).
static func build(r: SkinRig, id: StringName) -> bool:
	var b := r.find(&"tool")
	if b < 0 or id == &"":
		return false
	var k := r.kit(b, &"tool")
	var g := r.kit(b, &"tool_glow", true)
	match id:
		&"knife":
			k.block(0, -0.07, 0, 0.04, 0.12, 0.035, Palette.EARTH[2], Palette.EARTH[3])
			k.block(0.004, 0.05, 0, 0.05, 0.012, 0.045, Palette.COPPER[2])
			k.block(0.008, 0.06, 0, 0.045, 0.16, 0.012, Palette.STONE[3], Palette.STONE[4])
			k.block(0.018, 0.22, 0, 0.025, 0.04, 0.012, Palette.STONE[4])
		&"knife_shear":
			k.block(0, -0.07, 0, 0.042, 0.12, 0.036, Palette.LINEN[2], Palette.RUST[2])
			k.block(0, -0.02, 0, 0.046, 0.015, 0.04, Palette.RUST[2])
			k.block(0.004, 0.05, 0, 0.06, 0.014, 0.05, Palette.STONE[4])
			k.block(0.01, 0.064, 0, 0.055, 0.2, 0.012, Palette.STONE[4], Palette.STONE[5])
			k.block(0.036, 0.064, 0, 0.008, 0.2, 0.014, Palette.STONE[5])
			k.block(0.022, 0.26, 0, 0.03, 0.04, 0.012, Palette.STONE[5])
		&"billhook":
			k.block(0, -0.1, 0, 0.045, 0.2, 0.04, Palette.EARTH[3], Palette.EARTH[4])
			k.block(0.005, 0.1, 0, 0.065, 0.24, 0.014, Palette.SLATE[3], Palette.SLATE[4])
			k.block(0.05, 0.3, 0, 0.1, 0.06, 0.014, Palette.SLATE[3], Palette.SLATE[4])
			k.block(0.1, 0.24, 0, 0.035, 0.08, 0.014, Palette.STONE[4])
		&"axe_hand":
			_haft(k, -0.14, 0.46, 0.045, Palette.EARTH[3], Palette.EARTH[4])
			k.block(0.07, 0.33, 0, 0.14, 0.1, 0.05, Palette.SLATE[3], Palette.SLATE[4])
			k.block(0.155, 0.3, 0, 0.04, 0.16, 0.045, Palette.STONE[4], Palette.STONE[5])
			k.block(-0.045, 0.35, 0, 0.05, 0.07, 0.055, Palette.SLATE[2])
		&"axe_felling":
			_haft(k, -0.42, 0.56, 0.05, Palette.EARTH[3], Palette.EARTH[4])
			k.block(-0.405, -0.44, 0, 0.065, 0.05, 0.065, Palette.EARTH[2])
			k.block(0.08, 0.42, 0, 0.17, 0.12, 0.06, Palette.STONE[3], Palette.STONE[4])
			k.block(0.18, 0.37, 0, 0.05, 0.22, 0.055, Palette.STONE[4], Palette.STONE[5])
			k.block(-0.055, 0.44, 0, 0.07, 0.09, 0.065, Palette.STONE[2])
		&"axe_works":
			# Out of the Works: a crucible head too good for this coast, on a bound haft.
			_haft(k, -0.2, 0.5, 0.05, Palette.EARTH[2], Palette.EARTH[3])
			k.block(0.0, 0.0, 0, 0.056, 0.14, 0.056, Palette.INK[3])
			k.block(0.08, 0.36, 0, 0.16, 0.13, 0.06, Palette.INK[3], Palette.STONE[3])
			k.block(0.18, 0.31, 0, 0.05, 0.22, 0.05, Palette.STONE[5], Palette.RIME[5])
			k.block(0.08, 0.41, 0, 0.1, 0.02, 0.065, Palette.COPPER[3])
		&"pick":
			_haft(k, -0.4, 0.5, 0.05, Palette.EARTH[3], Palette.EARTH[4])
			k.block(0.0, 0.44, 0, 0.44, 0.07, 0.06, Palette.SLATE[3], Palette.SLATE[4])
			k.block(0.25, 0.43, 0, 0.08, 0.05, 0.04, Palette.STONE[4])
			k.block(-0.25, 0.43, 0, 0.08, 0.05, 0.04, Palette.STONE[4])
			k.block(0.0, 0.42, 0, 0.08, 0.11, 0.08, Palette.SLATE[2])
		&"mattock", &"mattock_steel":
			var steel := id == &"mattock_steel"
			var m0: Color = Palette.STONE[3] if steel else Palette.SLATE[3]
			var m1: Color = Palette.STONE[5] if steel else Palette.STONE[4]
			_haft(k, -0.4, 0.5, 0.05, Palette.EARTH[3], Palette.EARTH[4])
			k.block(0.14, 0.4, 0, 0.26, 0.07, 0.07, m0, m1)
			k.block(0.28, 0.36, 0, 0.05, 0.11, 0.13, m1)
			k.block(-0.16, 0.43, 0, 0.22, 0.05, 0.05, m0)
			k.block(0.0, 0.4, 0, 0.08, 0.12, 0.08, Palette.SLATE[2])
		&"stave":
			_haft(k, -0.62, 0.72, 0.045, Palette.EARTH[3], Palette.EARTH[4])
			k.block(0, 0.62, 0, 0.05, 0.1, 0.05, Palette.EARTH[4], Palette.EARTH[5])
			k.block(0, -0.06, 0, 0.052, 0.14, 0.052, Palette.LINEN[2])
		&"boathook":
			_haft(k, -0.58, 0.88, 0.042, Palette.EARTH[2], Palette.EARTH[3])
			k.block(0, 0.84, 0, 0.06, 0.08, 0.06, Palette.SLATE[2])
			k.block(0, 0.92, 0, 0.022, 0.18, 0.022, Palette.SLATE[3], Palette.STONE[4])
			k.block(-0.06, 0.9, 0, 0.1, 0.022, 0.022, Palette.SLATE[3])
			k.block(-0.1, 0.82, 0, 0.022, 0.1, 0.022, Palette.SLATE[3], Palette.STONE[4])
		_:
			if not is_found(id):
				return false
			_found(k, g, id)
	return true


static func _haft(k: MeshKit, y0: float, y1: float, t: float, c: Color, top: Color) -> void:
	# Two segments at a hair's difference in thickness: a hand-cut haft, not a dowel.
	var mid := lerpf(y0, y1, 0.55)
	k.block(0, y0, 0, t, mid - y0, t, c)
	k.block(0.002, mid, 0, t * 0.92, y1 - mid, t * 0.96, c, top)


static func _found(k: MeshKit, g: MeshKit, id: StringName) -> void:
	var v0 := Palette.FOUND[1]
	var v1 := Palette.FOUND[2]
	var v2 := Palette.FOUND[3]
	var rivet := Palette.FOUND[5]
	var light := Palette.FOUND[4]
	var core := Palette.FOUND[5]
	match id:
		&"las_hand":
			_grip(k, -0.08, 0.1, 0.05, v1, v2)
			k.block(0, 0.1, 0, 0.08, 0.04, 0.08, v0, v2)
			g.block(0, 0.14, 0, 0.045, 0.3, 0.045, light, core)
			g.block(0, 0.44, 0, 0.03, 0.03, 0.03, core)
		&"las_long":
			_grip(k, -0.3, 0.12, 0.055, v1, v2)
			k.block(0, 0.12, 0, 0.1, 0.05, 0.1, v0, v2)
			k.block(0, -0.32, 0, 0.07, 0.04, 0.07, v2, rivet)
			g.block(0, 0.17, 0, 0.05, 0.7, 0.05, light, core)
		&"las_broad":
			_grip(k, -0.24, 0.12, 0.055, v1, v2)
			k.block(0.06, 0.12, 0, 0.22, 0.05, 0.08, v0, v2)
			g.block(0.07, 0.17, 0, 0.2, 0.34, 0.03, light, core)
			g.block(0.07, 0.51, 0, 0.12, 0.03, 0.025, core)
		&"mono_blade":
			_grip(k, -0.08, 0.1, 0.04, v1, v2)
			k.block(0, 0.1, 0, 0.06, 0.02, 0.06, v2, rivet)
			g.block(0.0, 0.12, 0, 0.012, 0.42, 0.012, core)
		&"plasma_torch":
			_grip(k, -0.08, 0.12, 0.05, v1, v2)
			k.prism(0, 0.12, 0, 0.05, 0.2, 0.035, 6, v0, v2)
			g.prism(0, 0.2, 0, 0.035, 0.46, 0.0, 6, Palette.RIME[4], Palette.RIME[5])
		&"arc_cut":
			k.block(0, -0.08, 0, 0.05, 0.14, 0.05, v1)
			k.block(0, 0.06, 0, 0.1, 0.08, 0.08, v0, v2)
			for z: float in [-0.028, 0.028]:
				k.block(0, 0.14, z, 0.02, 0.12, 0.02, v2, rivet)
			g.block(0, 0.2, 0, 0.012, 0.06, 0.036, core)
		&"stun_hand":
			k.block(0, -0.08, 0, 0.05, 0.14, 0.05, v1)
			k.prism(0, 0.06, 0, 0.06, 0.2, 0.06, 8, v1, v2)
			g.prism(0, 0.2, 0, 0.06, 0.26, 0.0, 8, light, core)
		&"rep_light":
			k.block(0, -0.08, 0, 0.05, 0.14, 0.05, v1)
			k.block(0, 0.06, 0, 0.09, 0.16, 0.07, v0, v2)
			for i in 3:
				g.block(0, 0.22, -0.024 + i * 0.024, 0.018, 0.022, 0.016, light, core)
		&"flash_burst":
			k.block(0, -0.08, 0, 0.05, 0.14, 0.05, v1)
			k.prism(0, 0.06, 0, 0.03, 0.2, 0.11, 8, v1, v0)
			g.prism(0, 0.19, 0, 0.09, 0.2, 0.09, 8, light, core)
		&"pulse_hammer":
			_grip(k, -0.34, 0.36, 0.05, v1, v2)
			k.block(0, 0.34, 0, 0.26, 0.14, 0.14, v1, v2)
			for x: float in [-0.135, 0.135]:
				g.block(x, 0.37, 0, 0.012, 0.08, 0.08, light, core)
			k.block(0, 0.48, 0, 0.1, 0.02, 0.1, rivet)
		&"beam_lance":
			_grip(k, -0.5, 0.7, 0.04, v1, v2)
			k.block(0, 0.7, 0, 0.08, 0.06, 0.08, v0, v2)
			k.block(0, -0.52, 0, 0.06, 0.04, 0.06, v2, rivet)
			g.block(0, 0.76, 0, 0.02, 0.3, 0.02, light, core)
		&"sonic_wave":
			_grip(k, -0.22, 0.1, 0.05, v1, v2)
			k.block(0, 0.1, 0, 0.18, 0.05, 0.06, v0, v2)
			for x: float in [-0.07, 0.07]:
				k.block(x, 0.15, 0, 0.03, 0.26, 0.04, v2, rivet)
			for i in 3:
				g.block(0, 0.2 + i * 0.08, 0, 0.1, 0.012, 0.012, light)


## An exact machined grip: banded, symmetric, rivets at both ends.
static func _grip(k: MeshKit, y0: float, y1: float, t: float, c: Color, band: Color) -> void:
	k.block(0, y0, 0, t, y1 - y0, t, c)
	var n := maxi(2, int((y1 - y0) / 0.09))
	for i in n:
		var y := lerpf(y0, y1, (i + 0.5) / n)
		k.block(0, y, 0, t + 0.012, 0.018, t + 0.012, band)
