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
	if is_found(id):
		_found(r.kit(b, &"tool", SkinRig.FOUND), r.kit(b, &"tool_glow", SkinRig.GLOW), id)
		return true
	var k := r.kit(b, &"tool")
	var seed_value := hash(id)
	var wood := Palette.EARTH[3]
	var iron := Palette.SLATE[3]
	var edge := Palette.STONE[4]
	match id:
		&"knife":
			_grip(k, -0.07, 0.05, 0.022, Palette.EARTH[2], seed_value)
			_band(k, 0.045, 0.03, Palette.COPPER[2])
			_blade(k, 0.06, 0.24, 0.03, 0.018, Palette.STONE[3], edge)
		&"knife_shear":
			_grip(k, -0.075, 0.055, 0.024, Palette.LINEN[2], seed_value)
			_band(k, -0.02, 0.028, Palette.RUST[2])
			_band(k, 0.05, 0.034, Palette.STONE[4])
			_blade(k, 0.064, 0.29, 0.034, 0.02, Palette.STONE[4], Palette.STONE[5])
		&"billhook":
			_grip(k, -0.1, 0.1, 0.026, wood, seed_value)
			_band(k, 0.095, 0.03, iron)
			# A broad blade that runs up and curls forward into the hook.
			Sculpt.slab(k, PackedVector2Array([Vector2(-0.012, 0.1), Vector2(0.05, 0.1), Vector2(0.07, 0.26), Vector2(0.05, 0.33), Vector2(-0.02, 0.3)]), 0.008, Palette.SLATE[3], edge)
			Sculpt.slab(k, PackedVector2Array([Vector2(0.05, 0.33), Vector2(0.07, 0.26), Vector2(0.13, 0.26), Vector2(0.12, 0.3)]), 0.007, Palette.SLATE[3], edge)
		&"axe_hand":
			_haft(k, -0.14, 0.46, 0.024, wood, seed_value, 0.012)
			_axe_head(k, 0.37, 0.11, 0.06, 0.06, Palette.SLATE[3], edge)
		&"axe_felling":
			_haft(k, -0.44, 0.58, 0.026, wood, seed_value, 0.02)
			Sculpt.loft(k, [[-0.46, 0.03, 0.03, 0.0, 0.0], [-0.42, 0.032, 0.032, 0.0, 0.0]], 6, Palette.EARTH[2], true, true, PI / 6, 0.05, seed_value)
			_axe_head(k, 0.48, 0.16, 0.08, 0.07, Palette.STONE[3], Palette.STONE[5])
		&"axe_works":
			# Out of the Works: a crucible head too good for this coast, on a bound haft.
			_haft(k, -0.22, 0.52, 0.026, Palette.EARTH[2], seed_value, 0.0)
			_band(k, 0.0, 0.032, Palette.INK[3])
			_band(k, 0.08, 0.032, Palette.INK[3])
			_axe_head(k, 0.42, 0.16, 0.09, 0.075, Palette.INK[3], Palette.RIME[5])
			_band(k, 0.42, 0.04, Palette.COPPER[3])
		&"pick":
			_haft(k, -0.42, 0.46, 0.026, wood, seed_value, 0.015)
			_pick_head(k, 0.44, Palette.SLATE[3], Palette.STONE[4], true)
		&"mattock", &"mattock_steel":
			var steel := id == &"mattock_steel"
			_haft(k, -0.42, 0.46, 0.026, wood, seed_value, 0.015)
			_pick_head(k, 0.42, Palette.STONE[3] if steel else Palette.SLATE[3], Palette.STONE[5] if steel else Palette.STONE[4], false)
		&"stave":
			_haft(k, -0.64, 0.74, 0.024, wood, seed_value, 0.03, 0.8)
			_band(k, 0.7, 0.028, Palette.EARTH[5])
			_band(k, -0.04, 0.03, Palette.LINEN[2])
		&"boathook":
			_haft(k, -0.6, 0.9, 0.021, Palette.EARTH[2], seed_value, 0.025, 0.85)
			_band(k, 0.86, 0.026, Palette.SLATE[2])
			# A spike straight on, a hook turned back beside it.
			Sculpt.loft(k, [[0.88, 0.016, 0.016, 0.0, 0.0], [1.08, 0.0, 0.0, 0.0, 0.0]], 4, iron, true, false, PI / 4)
			Sculpt.slab(k, PackedVector2Array([Vector2(-0.015, 0.88), Vector2(0.012, 0.88), Vector2(-0.07, 0.99), Vector2(-0.1, 0.99)]), 0.008, iron, edge)
			Sculpt.slab(k, PackedVector2Array([Vector2(-0.1, 0.99), Vector2(-0.07, 0.99), Vector2(-0.075, 0.9), Vector2(-0.095, 0.92)]), 0.008, iron, edge)
		_:
			return false
	return true


## A wooden haft: six-sided, a hair thicker at the grip, with a little bend in it.
static func _haft(k: MeshKit, y0: float, y1: float, r: float, col: Color, seed_value: int, bend: float, taper: float = 0.9) -> void:
	var mid := lerpf(y0, y1, 0.5)
	Sculpt.loft(k, [[y0, r, r, 0.0, 0.0], [mid, r * lerpf(1.0, taper, 0.5), r * lerpf(1.0, taper, 0.5), bend, 0.0], [y1, r * taper, r * taper, 0.0, 0.0]], 6, col, true, true, PI / 6, 0.06, seed_value)


## A short handle for a knife or a hook.
static func _grip(k: MeshKit, y0: float, y1: float, r: float, col: Color, seed_value: int) -> void:
	Sculpt.loft(k, [[y0, r * 0.9, r * 0.8, 0.0, 0.0], [lerpf(y0, y1, 0.4), r * 1.08, r, 0.0, 0.0], [y1, r, r * 0.9, 0.0, 0.0]], 6, col, true, true, PI / 6, 0.05, seed_value)


## A collar round the handle: ferrule, bolster, binding.
static func _band(k: MeshKit, y: float, r: float, col: Color) -> void:
	Sculpt.loft(k, [[y - 0.012, r, r, 0.0, 0.0], [y + 0.012, r, r, 0.0, 0.0]], 6, col, true, true, PI / 6)


## A blade: back straight, edge swept up to the point, a bright line of edge.
static func _blade(k: MeshKit, y0: float, y1: float, w: float, t: float, col: Color, edge: Color) -> void:
	Sculpt.slab(k, PackedVector2Array([Vector2(-0.006, y0), Vector2(w, y0), Vector2(w * 0.9, lerpf(y0, y1, 0.7)), Vector2(0.004, y1), Vector2(-0.008, lerpf(y0, y1, 0.8))]), t * 0.3, col, edge)


## An axe head: a wedge that flares toward the bit (+X), a poll behind the eye.
static func _axe_head(k: MeshKit, y: float, reach: float, h: float, t: float, col: Color, edge: Color) -> void:
	Sculpt.slab(k, PackedVector2Array([Vector2(-0.035, y - h * 0.35), Vector2(reach * 0.55, y - h * 0.3), Vector2(reach, y - h * 0.7), Vector2(reach + 0.012, y + h * 0.45), Vector2(reach * 0.55, y + h * 0.28), Vector2(-0.035, y + h * 0.35)]), t * 0.28, col, edge)
	Sculpt.loft(k, [[y - h * 0.36, t * 0.5, t * 0.45, -0.01, 0.0], [y + h * 0.36, t * 0.5, t * 0.45, -0.01, 0.0]], 6, col, true, true, PI / 6)


## A pick (two points) or a mattock (a point behind, a broad adze ahead).
static func _pick_head(k: MeshKit, y: float, col: Color, edge: Color, pick: bool) -> void:
	Sculpt.loft(k, [[y - 0.045, 0.035, 0.034, 0.0, 0.0], [y + 0.045, 0.035, 0.034, 0.0, 0.0]], 6, col, true, true, PI / 6)
	for dir: float in [1.0, -1.0]:
		var reach := 0.24 if pick or dir < 0.0 else 0.2
		k.push(Transform3D(Basis(Vector3(0, 0, 1), -dir * (PI * 0.5 + 0.18)), Vector3(0, y, 0)))
		if pick or dir < 0.0:
			Sculpt.loft(k, [[0.02, 0.024, 0.022, 0.0, 0.0], [reach * 0.6, 0.016, 0.015, 0.0, 0.0], [reach, 0.0, 0.0, 0.0, 0.0]], 5, [col, edge], false, false, 0.0)
		else:
			k.pop()
			k.push(Transform3D(Basis(Vector3(0, 1, 0), PI * 0.5), Vector3(0, y, 0)))
			Sculpt.slab(k, PackedVector2Array([Vector2(-0.03, 0.02), Vector2(0.03, 0.02), Vector2(0.055, -0.2), Vector2(-0.055, -0.2)]), 0.0, col, edge)
			k.pop()
			k.push(Transform3D(Basis(Vector3(0, 0, 1), -(PI * 0.5 + 0.25)), Vector3(0, y, 0)))
			Sculpt.slab(k, PackedVector2Array([Vector2(-0.028, 0.02), Vector2(0.028, 0.02), Vector2(0.052, reach), Vector2(-0.052, reach)]), 0.007, col, edge)
		k.pop()


## FOUND weapons: exact, symmetric, chamfered, on the found surface; their light
## on the glow surface. Anyone should see at a glance that nobody here made one.
static func _found(k: MeshKit, g: MeshKit, id: StringName) -> void:
	var v0 := Palette.FOUND[1]
	var v1 := Palette.FOUND[2]
	var v2 := Palette.FOUND[3]
	var light := Palette.FOUND[4]
	var core := Palette.FOUND[5]
	match id:
		&"las_hand":
			_hilt(k, -0.08, 0.1, 0.024, v1, v2)
			_guard(k, 0.1, 0.05, 0.035, v0, v2)
			_light_blade(g, 0.135, 0.44, 0.02, light, core)
		&"las_long":
			_hilt(k, -0.32, 0.12, 0.026, v1, v2)
			_guard(k, 0.12, 0.06, 0.04, v0, v2)
			_cap(k, -0.33, 0.034, v2)
			_light_blade(g, 0.155, 0.9, 0.022, light, core)
		&"las_broad":
			_hilt(k, -0.24, 0.12, 0.026, v1, v2)
			_guard(k, 0.12, 0.1, 0.035, v0, v2)
			g.push(Transform3D(Basis.IDENTITY, Vector3(0.05, 0, 0)))
			Sculpt.slab(g, PackedVector2Array([Vector2(-0.07, 0.15), Vector2(0.07, 0.15), Vector2(0.09, 0.2), Vector2(0.09, 0.46), Vector2(0.0, 0.54), Vector2(-0.09, 0.46), Vector2(-0.09, 0.2)]), 0.01, light, core)
			g.pop()
		&"mono_blade":
			_hilt(k, -0.08, 0.1, 0.02, v1, v2)
			_guard(k, 0.1, 0.03, 0.03, v2, core)
			Sculpt.loft(g, [[0.12, 0.006, 0.006, 0.0, 0.0], [0.56, 0.0, 0.0, 0.0, 0.0]], 4, core, true, false, PI / 4)
		&"plasma_torch":
			_hilt(k, -0.08, 0.12, 0.024, v1, v2)
			Sculpt.loft(k, [[0.12, 0.03, 0.03, 0.0, 0.0], [0.2, 0.045, 0.045, 0.0, 0.0], [0.22, 0.04, 0.04, 0.0, 0.0]], 8, [v0, v2], true, true, PI / 8)
			Sculpt.loft(g, [[0.22, 0.034, 0.034, 0.0, 0.0], [0.36, 0.022, 0.022, 0.0, 0.0], [0.5, 0.0, 0.0, 0.0, 0.0]], 6, [Palette.RIME[4], Palette.RIME[5]], true, false, PI / 6)
		&"arc_cut":
			_hilt(k, -0.08, 0.06, 0.024, v1, v2)
			_guard(k, 0.06, 0.045, 0.045, v0, v2)
			for z: float in [-0.028, 0.028]:
				Sculpt.loft(k, [[0.08, 0.01, 0.01, 0.0, z], [0.22, 0.008, 0.008, 0.0, z]], 4, v2, false, true, PI / 4)
			Sculpt.loft(g, [[0.19, 0.0, 0.0, 0.0, 0.0], [0.215, 0.018, 0.03, 0.0, 0.0], [0.24, 0.0, 0.0, 0.0, 0.0]], 4, core, false, false, PI / 4)
		&"stun_hand":
			_hilt(k, -0.08, 0.06, 0.024, v1, v2)
			Sculpt.loft(k, [[0.06, 0.03, 0.03, 0.0, 0.0], [0.2, 0.07, 0.07, 0.0, 0.0]], 8, [v1], true, false, PI / 8)
			Sculpt.loft(g, [[0.2, 0.064, 0.064, 0.0, 0.0], [0.24, 0.0, 0.0, 0.0, 0.0]], 8, light, false, false, PI / 8)
		&"rep_light":
			_hilt(k, -0.08, 0.06, 0.024, v1, v2)
			Sculpt.slab(k, _chamfer(0.1, 0.16, 0.02, 0.14), 0.035, v0, v2)
			for i in 3:
				Sculpt.loft(g, [[0.22, 0.012, 0.012, 0.0, -0.028 + i * 0.028], [0.24, 0.012, 0.012, 0.0, -0.028 + i * 0.028]], 4, core, false, true, PI / 4)
		&"flash_burst":
			_hilt(k, -0.08, 0.06, 0.024, v1, v2)
			Sculpt.loft(k, [[0.06, 0.025, 0.025, 0.0, 0.0], [0.18, 0.11, 0.11, 0.0, 0.0], [0.2, 0.11, 0.11, 0.0, 0.0]], 8, [v1, v2], true, false, PI / 8)
			Sculpt.loft(g, [[0.19, 0.095, 0.095, 0.0, 0.0], [0.2, 0.0, 0.0, 0.0, 0.0]], 8, light, false, false, PI / 8)
		&"pulse_hammer":
			_hilt(k, -0.34, 0.34, 0.024, v1, v2)
			k.push(Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), Vector3(0, 0.41, 0)))
			Sculpt.loft(k, [[-0.14, 0.06, 0.06, 0.0, 0.0], [-0.12, 0.075, 0.075, 0.0, 0.0], [0.12, 0.075, 0.075, 0.0, 0.0], [0.14, 0.06, 0.06, 0.0, 0.0]], 8, [v2, v1, v2], true, true, PI / 8)
			Sculpt.loft(g, [[0.14, 0.045, 0.045, 0.0, 0.0], [0.15, 0.045, 0.045, 0.0, 0.0]], 8, light, false, true, PI / 8)
			Sculpt.loft(g, [[-0.15, 0.045, 0.045, 0.0, 0.0], [-0.14, 0.045, 0.045, 0.0, 0.0]], 8, light, true, false, PI / 8)
			k.pop()
		&"beam_lance":
			_hilt(k, -0.52, 0.7, 0.02, v1, v2)
			_guard(k, 0.7, 0.04, 0.04, v0, v2)
			_cap(k, -0.53, 0.03, v2)
			Sculpt.loft(g, [[0.73, 0.012, 0.012, 0.0, 0.0], [1.05, 0.004, 0.004, 0.0, 0.0]], 4, core, true, true, PI / 4)
		&"sonic_wave":
			_hilt(k, -0.22, 0.1, 0.024, v1, v2)
			Sculpt.slab(k, _chamfer(0.18, 0.04, 0.012, 0.12), 0.03, v0, v2)
			for x: float in [-0.075, 0.075]:
				k.push(Transform3D(Basis.IDENTITY, Vector3(x, 0, 0)))
				Sculpt.slab(k, _chamfer(0.028, 0.26, 0.008, 0.27), 0.018, v2, v1)
				k.pop()
			for i in 3:
				Sculpt.slab(g, _chamfer(0.11, 0.012, 0.0, 0.2 + i * 0.08), 0.006, light, core)


## A machined grip: exact octagon, banded, a rivet ring at each end.
static func _hilt(k: MeshKit, y0: float, y1: float, r: float, c: Color, band: Color) -> void:
	var rings: Array = []
	var n := maxi(2, int((y1 - y0) / 0.07))
	for i in n + 1:
		var y := lerpf(y0, y1, float(i) / n)
		rings.append([y, r, r, 0.0, 0.0])
	var cols: Array = []
	for i in n:
		cols.append(band if i % 2 == 0 else c)
	Sculpt.loft(k, rings, 8, cols, true, true, PI / 8)


static func _guard(k: MeshKit, y: float, w: float, d: float, c: Color, rim: Color) -> void:
	Sculpt.slab(k, _chamfer(w * 2.0, 0.03, 0.01, y + 0.015), d, c, rim)


static func _cap(k: MeshKit, y: float, r: float, c: Color) -> void:
	Sculpt.loft(k, [[y - 0.015, r, r, 0.0, 0.0], [y + 0.015, r, r, 0.0, 0.0]], 8, c, true, true, PI / 8)


## A blade of light: a flat, pointed, perfectly symmetric bar.
static func _light_blade(g: MeshKit, y0: float, y1: float, w: float, light: Color, core: Color) -> void:
	# Violet through: a paler core only down the middle of the flat, never on the edges.
	Sculpt.slab(g, PackedVector2Array([Vector2(-w, y0), Vector2(w, y0), Vector2(w, y1 - w * 2.0), Vector2(0.0, y1), Vector2(-w, y1 - w * 2.0)]), w * 0.6, light, light)
	Sculpt.slab(g, PackedVector2Array([Vector2(-w * 0.35, y0 + 0.02), Vector2(w * 0.35, y0 + 0.02), Vector2(w * 0.35, y1 - w * 2.5), Vector2(0.0, y1 - w), Vector2(-w * 0.35, y1 - w * 2.5)]), w * 0.62, core, core)


## A chamfered rectangle, w by h, centred at (0, y): exact.
static func _chamfer(w: float, h: float, c: float, y: float) -> PackedVector2Array:
	var x := w * 0.5
	var y0 := y - h * 0.5
	var y1 := y + h * 0.5
	if c <= 0.0:
		return PackedVector2Array([Vector2(-x, y0), Vector2(x, y0), Vector2(x, y1), Vector2(-x, y1)])
	return PackedVector2Array([
		Vector2(-x + c, y0), Vector2(x - c, y0), Vector2(x, y0 + c), Vector2(x, y1 - c),
		Vector2(x - c, y1), Vector2(-x + c, y1), Vector2(-x, y1 - c), Vector2(-x, y0 + c),
	])
