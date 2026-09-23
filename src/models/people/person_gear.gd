class_name PersonGear
## Scavenged tech and scavenging kit on a person (PersonLook.GEAR), drawn in the
## MENDED idiom (docs/VISION.md, §8): the part taken off a machine is FOUND
## (exact, unhatched, found.gdshader) and whatever holds it on is MADE (cord,
## tape, straps, in the hand). Both idioms show at once on every piece: that is
## how anyone can tell it was not made here, and that somebody here keeps it going.
##
## Layers: &"gear" for the parts, &"gear_glow" for the faint lights (the slate's
## screen, a charge pip, a radio's lamp). Lights are dim colours on the GLOW
## surface: a smudge by day, a mark in the dark.
##
## Sizes are for the game camera (a person is ~34 px tall): every piece has one FOUND
## mark at least ~0.1 units (2 px) across (the filter block, the lenses, the screen,
## the cell, the aerial), nothing that must read
## is under ~0.05 units across, and every piece changes the outline or sits where
## the camera looks (head, chest, back, the top of the wrist).

const CORD := Color(0.7098, 0.6078, 0.4549)
const TAPE := Color(0.1843, 0.1725, 0.2706)


static func build(r: SkinRig, w: PersonBody.Wear) -> void:
	for g: StringName in w.gear:
		match g:
			&"respirator": _respirator(r, w)
			&"goggles": _goggles(r, w)
			&"slate": _slate(r, w)
			&"battery": _battery(r, w)
			&"radio": _radio(r, w)
			&"pack": _pack(r, w)
			&"coil": _coil(r, w)


## Which forearm wears the slate: the left (the right holds the tool), unless a
## machine gauntlet already sleeves it.
static func slate_side(w: PersonBody.Wear) -> int:
	return 1 if w.salvage.has(&"gauntlet") and int(w.look.side) < 0 else -1


## Whether goggles sit over the eyes (true) or are pushed up on the brow.
static func goggles_down(w: PersonBody.Wear) -> bool:
	var hat: StringName = w.look.hat
	if w.gear.has(&"respirator") or w.look.coat == &"wrap" or hat == &"hood" or hat == &"scarf" or hat == &"furhat":
		return true
	return hat != &"none" or Rng.hash01(w.seed_value, 101) < 0.4


# ---------------------------------------------------------------- pieces

## A filter off a machine's intake, pushed through a rag tied over the mouth, a
## spare canister hung at the jaw on cord.
static func _respirator(r: SkinRig, w: PersonBody.Wear) -> void:
	var d := w.d
	var hh: float = d.head
	var hw: float = d.head_w
	var hd: float = d.head_d
	var side: int = w.look.side
	var head := r.find(&"head")
	var rags: Array[Color] = [Palette.ASH[2], Palette.LINEN[2], Palette.SLATE[2], Palette.SAND[2]]
	var rag := rags[int(Rng.hash01(w.seed_value, 102) * rags.size()) % rags.size()]
	var cloth := r.kit(head, &"gear")
	Sculpt.loft(cloth, [
		[-0.015, hd * 0.38, hw * 0.36, hd * 0.15, 0.0],
		[hh * 0.37, hd * 0.575, hw * 0.54, hd * 0.05, 0.0],
	], 6, rag, false, false, 0.0, 0.07, w.seed_value + 103, 0.62, 0.0)
	# The tie behind the head.
	Sculpt.loft(cloth, [[hh * 0.3, hd * 0.575, hw * 0.545, -0.004, 0.0], [hh * 0.38, hd * 0.575, hw * 0.545, -0.004, 0.0]], 6, TAPE, false, false, 0.0, 0.0, 0, 0.5, PI)
	var f := r.kit(head, &"gear", SkinRig.FOUND)
	var mx := PersonBody.face_x(d, 0.24, 0.0) + 0.012
	var mouth := Vector3(mx, hh * 0.22, 0.0)
	Sculpt.aim(f, mouth, mouth + Vector3(1.0, -0.5, 0.0).normalized())
	# A square filter block, the lightest plate on the face: the mark that reads
	# at the game camera (at least 2 px across), its intake face dark.
	Sculpt.loft(f, [[0.0, 0.066, 0.066, 0.0, 0.0], [0.1, 0.078, 0.078, 0.0, 0.0]], 4, Palette.PLATE[4], false, false, PI / 4)
	Sculpt.loft(f, [[0.1, 0.078, 0.078, 0.0, 0.0], [0.104, 0.05, 0.05, 0.0, 0.0], [0.106, 0.0, 0.0, 0.0, 0.0]], 4, [Palette.PLATE[3], Palette.PLATE[0]], false, false, PI / 4)
	f.pop()
	var can_at := Vector3(hd * 0.2, hh * 0.1, side * (hw * 0.5 + 0.035))
	var can_dir := Vector3(0.45, -1.0, side * 0.3).normalized()
	Sculpt.aim(f, can_at, can_at + can_dir)
	Sculpt.loft(f, [[0.0, 0.04, 0.04, 0.0, 0.0], [0.12, 0.04, 0.04, 0.0, 0.0]], 6, Palette.PLATE[4], true, true, 0.0)
	f.pop()
	var tie := r.kit(head, &"gear")
	Sculpt.aim(tie, can_at, can_at + can_dir)
	for y: float in [0.035, 0.085]:
		Sculpt.loft(tie, [[y - 0.011, 0.046, 0.046, 0.0, 0.0], [y + 0.011, 0.046, 0.046, 0.0, 0.0]], 6, CORD, false, false, 0.0)
	tie.pop()


## Two machine lenses on a strap: over the eyes where the air or the glare is
## bad, pushed up on the brow where it is not.
static func _goggles(r: SkinRig, w: PersonBody.Wear) -> void:
	var d := w.d
	var hh: float = d.head
	var hw: float = d.head_w
	var hd: float = d.head_d
	var head := r.find(&"head")
	var down := goggles_down(w)
	var yf: float = PersonBody.EYE_Y if down else 0.84
	var y := hh * yf
	var lift := 0.0 if down else 0.026
	var aim := Basis(Vector3(0, 0, 1), -PI * 0.5 + (0.5 if down else 1.15))
	var f := r.kit(head, &"gear", SkinRig.FOUND)
	for sd: int in [-1, 1]:
		var z := sd * hw * 0.22
		var at := Vector3(PersonBody.face_x(d, yf, z) - 0.008 + lift, y, z)
		f.push(Transform3D(aim, at))
		Sculpt.loft(f, [[0.0, 0.066, 0.066, 0.0, 0.0], [0.046, 0.06, 0.06, 0.0, 0.0]], 6, Palette.PLATE[1], false, false, 0.0)
		# The glass a step brighter than the rim, so each lens is a light mark.
		Sculpt.loft(f, [[0.04, 0.054, 0.054, 0.0, 0.0], [0.044, 0.0, 0.0, 0.0, 0.0]], 6, Palette.COLD[3], false, false, 0.0)
		f.pop()
	# The bridge between the lenses.
	var bx := PersonBody.face_x(d, yf, 0.0) + lift + 0.02
	Sculpt.card(f, Vector3(bx, y - 0.012, -hw * 0.12), Vector3(bx, y - 0.012, hw * 0.12), Vector3(bx, y + 0.012, hw * 0.12), Vector3(bx, y + 0.012, -hw * 0.12), Palette.PLATE[2], Vector3(1, 0.4, 0))
	var strap := r.kit(head, &"gear")
	var grow := 1.0 if down else 1.08
	Sculpt.loft(strap, [
		[y - 0.03, hd * 0.575 * grow, hw * 0.55 * grow, -0.004, 0.0],
		[y + 0.03, hd * 0.575 * grow, hw * 0.55 * grow, -0.006, 0.0],
	], 7, TAPE, false, false, 0.0, 0.0, 0, 0.7, PI)


## The player's slate strapped to the wrist: a stolen display in a bezel, taped
## on, its screen a faint cold light, one corner cracked.
static func _slate(r: SkinRig, w: PersonBody.Wear) -> void:
	var d := w.d
	var sd := slate_side(w)
	var sfx := "_r" if sd > 0 else "_l"
	var fore := r.find(StringName("fore" + sfx))
	var t: float = d.arm_t
	var fl: float = d.fore
	var y := -fl * 0.6
	var n := Vector3(0.55, 0.0, sd * 0.84).normalized()
	var u := Vector3.UP
	var v := u.cross(n)
	var xf := Transform3D(Basis(v, u, n), Vector3(0, y, 0) + n * (t * 0.46 + 0.016))
	var f := r.kit(fore, &"gear", SkinRig.FOUND)
	f.push(xf)
	# Wider than the forearm it is strapped to: the screen must be a mark at the
	# game camera, not a pixel.
	Sculpt.slab(f, _rect(0.13, 0.18, 0.02), 0.012, Palette.PLATE[2], Palette.PLATE[1])
	# The crack across one corner of the glass.
	Sculpt.card(f, Vector3(0.018, 0.066, 0.0136), Vector3(0.023, 0.071, 0.0136), Vector3(0.046, 0.04, 0.0136), Vector3(0.041, 0.035, 0.0136), Palette.PLATE[0], Vector3.BACK)
	f.pop()
	var glow := r.kit(fore, &"gear_glow", SkinRig.GLOW)
	glow.push(xf)
	Sculpt.card(glow, Vector3(-0.05, -0.066, 0.013), Vector3(0.05, -0.066, 0.013), Vector3(0.05, 0.066, 0.013), Vector3(-0.05, 0.066, 0.013), Palette.RIME[2], Vector3.BACK)
	glow.pop()
	var tape := r.kit(fore, &"gear")
	tape.push(xf)
	for ty: float in [-0.078, 0.08]:
		Sculpt.card(tape, Vector3(-0.07, ty - 0.012, 0.0138), Vector3(0.07, ty - 0.012, 0.0138), Vector3(0.07, ty + 0.012, 0.0138), Vector3(-0.07, ty + 0.012, 0.0138), TAPE, Vector3.BACK)
	tape.pop()
	for ty: float in [-0.078, 0.08]:
		Sculpt.loft(tape, [[y + ty - 0.012, t * 0.5, t * 0.52, 0.0, 0.0], [y + ty + 0.012, t * 0.5, t * 0.52, 0.004, 0.0]], 5, TAPE, false, false, PI / 5)


## A machine's cell carried at the small of the back, strapped to the belt, a
## charge pip on top and a cable run up to the shoulder.
static func _battery(r: SkinRig, w: PersonBody.Wear) -> void:
	var d := w.d
	var side: int = w.look.side
	var hips := r.find(&"hips")
	var bx: float = -(float(d.depth) * 0.5 * 0.93 + w.pad) - 0.036
	var at := Vector3(bx, 0.12, side * float(d.hip) * 0.2)
	var back := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	var f := r.kit(hips, &"gear", SkinRig.FOUND)
	f.push(Transform3D(back, at))
	Sculpt.slab(f, _rect(0.13, 0.11, 0.018), 0.026, Palette.PLATE[3], Palette.PLATE[1])
	Sculpt.card(f, Vector3(-0.05, 0.03, 0.027), Vector3(0.05, 0.03, 0.027), Vector3(0.05, 0.042, 0.027), Vector3(-0.05, 0.042, 0.027), Palette.FOUND[1], Vector3.BACK)
	f.pop()
	var pip := r.kit(hips, &"gear_glow", SkinRig.GLOW)
	var top := at + Vector3(0, 0.056, 0)
	Sculpt.card(pip, top + Vector3(-0.024, 0.001, side * 0.004), top + Vector3(0.024, 0.001, side * 0.004), top + Vector3(0.024, 0.001, side * 0.05), top + Vector3(-0.024, 0.001, side * 0.05), Palette.EMBER[4], Vector3.UP)
	var strap := r.kit(hips, &"gear")
	strap.push(Transform3D(back, at))
	Sculpt.card(strap, Vector3(-0.014, -0.068, 0.028), Vector3(0.014, -0.068, 0.028), Vector3(0.014, 0.068, 0.028), Vector3(-0.014, 0.068, 0.028), Palette.EARTH[1], Vector3.BACK)
	Sculpt.card(strap, Vector3(-0.022, -0.012, 0.029), Vector3(0.022, -0.012, 0.029), Vector3(0.022, 0.012, 0.029), Vector3(-0.022, 0.012, 0.029), CORD, Vector3.BACK)
	strap.pop()
	# The cable, up the back to the shoulder on the slate's side.
	var spine := r.kit(r.find(&"spine"), &"gear")
	var top_y: float = d.torso - 0.04
	var cz := at.z
	var sz: float = slate_side(w) * float(d.chest) * 0.36
	var pts: Array[Vector3] = [
		Vector3(PersonBody.torso_x(w, 0.08, true) - 0.01, 0.08, cz),
		Vector3(PersonBody.torso_x(w, top_y * 0.6, true) - 0.01, top_y * 0.6, lerpf(cz, sz, 0.5)),
		Vector3(PersonBody.torso_x(w, top_y, true) - 0.004, top_y + 0.02, sz),
	]
	for i in 2:
		var a := pts[i]
		var b := pts[i + 1]
		Sculpt.card(spine, a + Vector3(0, 0, -0.008), a + Vector3(0, 0, 0.008), b + Vector3(0, 0, 0.008), b + Vector3(0, 0, -0.008), TAPE, Vector3(-1, 0.3, 0))


## A handset off a relay, hung high on the chest on cord: a stub aerial past the
## shoulder, a speaker grille, a lamp that says it still listens.
static func _radio(r: SkinRig, w: PersonBody.Wear) -> void:
	var d := w.d
	var side: int = w.look.side
	var spine := r.find(&"spine")
	var top: float = d.torso - 0.04
	var y := top * 0.66
	var z := -side * float(d.chest) * 0.26
	var x := PersonBody.torso_x(w, y) + 0.04
	var f := r.kit(spine, &"gear", SkinRig.FOUND)
	# Four sides at a quarter turn: flat faces front and back, 0.07 deep, 0.11 wide.
	Sculpt.loft(f, [[y - 0.09, 0.05, 0.078, x, z], [y + 0.07, 0.05, 0.078, x, z]], 4, Palette.PLATE[3], true, true, PI / 4)
	var fx := x + 0.05 * 0.707 + 0.002
	for gy: float in [-0.06, -0.038, -0.016]:
		Sculpt.card(f, Vector3(fx, y + gy - 0.006, z - 0.03), Vector3(fx, y + gy - 0.006, z + 0.03), Vector3(fx, y + gy + 0.006, z + 0.03), Vector3(fx, y + gy + 0.006, z - 0.03), Palette.PLATE[0], Vector3.RIGHT)
	var foot := Vector3(x - 0.012, y + 0.07, z + side * 0.03)
	# Up and out past the shoulder, where the outline shows it.
	Sculpt.aim(f, foot, foot + Vector3(-0.2, 1.0, -side * 0.5).normalized())
	# Tall and thick enough to stand a line of pixels past the shoulder, a knob on its end.
	Sculpt.loft(f, [[0.0, 0.022, 0.022, 0.0, 0.0], [0.44, 0.014, 0.014, 0.0, 0.0]], 4, Palette.PLATE[3], false, false, PI / 4)
	Sculpt.loft(f, [[0.43, 0.034, 0.034, 0.0, 0.0], [0.48, 0.0, 0.0, 0.0, 0.0]], 4, Palette.PLATE[4], true, false, PI / 4)
	f.pop()
	var lamp := r.kit(spine, &"gear_glow", SkinRig.GLOW)
	Sculpt.card(lamp, Vector3(fx + 0.001, y + 0.018, z - 0.046), Vector3(fx + 0.001, y + 0.018, z - 0.006), Vector3(fx + 0.001, y + 0.056, z - 0.006), Vector3(fx + 0.001, y + 0.056, z - 0.046), Palette.EMBER[4], Vector3.RIGHT)
	var cord := r.kit(spine, &"gear")
	# Tape round its middle where the case split.
	Sculpt.loft(cord, [[y - 0.004, 0.056, 0.084, x, z], [y + 0.018, 0.056, 0.084, x, z]], 4, TAPE, false, false, PI / 4)
	var sx := PersonBody.torso_x(w, top) + 0.006
	var bk := PersonBody.torso_x(w, top * 0.35, true) - 0.006
	var sh := Vector3(sx, top + 0.015, z * 1.1)
	Sculpt.card(cord, Vector3(x, y + 0.07, z - 0.012), Vector3(x, y + 0.07, z + 0.012), sh + Vector3(0, 0, 0.012), sh + Vector3(0, 0, -0.012), CORD, Vector3(1, 0.5, 0))
	var bb := Vector3(bk, top * 0.35, -z * 0.5)
	Sculpt.card(cord, sh + Vector3(-0.02, 0, -0.012), sh + Vector3(-0.02, 0, 0.012), bb + Vector3(0, 0, 0.012), bb + Vector3(0, 0, -0.012), CORD, Vector3(-1, 0.5, 0))


## A carrying frame lashed from sticks, loaded with plate cut off machines and a
## coil of their cable: what a scavenger brings home. It stands past the
## shoulders, so it changes the outline from every side.
static func _pack(r: SkinRig, w: PersonBody.Wear) -> void:
	var d := w.d
	var spine := r.find(&"spine")
	var top: float = d.torso - 0.04
	var chest: float = d.chest
	var x := PersonBody.torso_x(w, top * 0.55, true) - 0.05
	var frame := r.kit(spine, &"gear")
	var zs := chest * 0.3
	var high := top + 0.26
	for sd: int in [-1, 1]:
		Sculpt.loft(frame, [[-0.08, 0.016, 0.016, x, sd * zs], [high, 0.013, 0.013, x - 0.02, sd * zs * 1.08]], 4, Palette.EARTH[2], false, true, 0.0, 0.1, w.seed_value + 120 + sd)
	for yb: float in [top * 0.08, high - 0.04]:
		var a := Vector3(x - 0.006, yb, -zs * 1.1 - 0.035)
		Sculpt.aim(frame, a, Vector3(x - 0.006, yb, zs * 1.1 + 0.035))
		Sculpt.loft(frame, [[0.0, 0.013, 0.013, 0.0, 0.0], [zs * 2.2 + 0.07, 0.013, 0.013, 0.0, 0.0]], 4, Palette.EARTH[1], false, false, 0.0)
		frame.pop()
	var back := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	var scrap := r.kit(spine, &"gear", SkinRig.FOUND)
	var tilt := (Rng.hash01(w.seed_value, 121) - 0.5) * 0.4
	# A sheet of plate the height of the back, and a violet panel off a machine's flank.
	scrap.push(Transform3D(back.rotated(Vector3(1, 0, 0), tilt), Vector3(x - 0.036, top * 0.58, 0.0)))
	Sculpt.slab(scrap, _rect(chest * 0.9, top * 0.95, 0.045), 0.014, Palette.PLATE[3], Palette.PLATE[1])
	Sculpt.card(scrap, Vector3(-chest * 0.38, top * 0.3, 0.015), Vector3(-chest * 0.06, top * 0.3, 0.015), Vector3(-chest * 0.06, top * 0.35, 0.015), Vector3(-chest * 0.38, top * 0.35, 0.015), Palette.FOUND[1], Vector3.BACK)
	scrap.pop()
	scrap.push(Transform3D(back.rotated(Vector3(1, 0, 0), -tilt - 0.3), Vector3(x - 0.068, top * 0.72, chest * 0.08)))
	Sculpt.slab(scrap, _rect(chest * 0.58, top * 0.5, 0.0), 0.012, Palette.FOUND[2], Palette.FOUND[1])
	scrap.pop()
	# A coil of cable on top of the load, above the shoulders.
	var cy := high - 0.02
	var cx := x - 0.06
	Sculpt.loft(scrap, [[cy, 0.08, 0.1, cx, 0.0], [cy + 0.05, 0.08, 0.1, cx, 0.0]], 6, Palette.INK[3], false, true, 0.0)
	Sculpt.loft(scrap, [[cy + 0.051, 0.042, 0.052, cx, 0.0], [cy + 0.052, 0.0, 0.0, cx, 0.0]], 6, Palette.INK[1], false, false, 0.0)
	var lash := r.kit(spine, &"gear")
	var lx := x - 0.086
	var ly0 := top * 0.2
	var ly1 := top * 0.95
	for sd: int in [-1, 1]:
		Sculpt.card(lash, Vector3(lx, ly0, -sd * zs - 0.014), Vector3(lx, ly0, -sd * zs + 0.014), Vector3(lx, ly1, sd * zs + 0.014), Vector3(lx, ly1, sd * zs - 0.014), CORD, Vector3.LEFT)
	# A cord over the coil, down to the frame.
	Sculpt.card(lash, Vector3(cx - 0.1 * 0.707 - 0.004, cy - 0.04, -0.016), Vector3(cx - 0.1 * 0.707 - 0.004, cy - 0.04, 0.016), Vector3(cx, cy + 0.056, 0.016), Vector3(cx, cy + 0.056, -0.016), CORD, Vector3(-1, 1, 0))
	# Shoulder straps over the front.
	var sx := PersonBody.torso_x(w, top) + 0.006
	for sd: int in [-1, 1]:
		var z := sd * chest * 0.3
		var lo := PersonBody.torso_x(w, top * 0.45) + 0.006
		Sculpt.card(lash, Vector3(sx, top + 0.02, z - 0.018), Vector3(sx, top + 0.02, z + 0.018), Vector3(lo, top * 0.45, z * 1.25 + 0.018), Vector3(lo, top * 0.45, z * 1.25 - 0.018), Palette.EARTH[1], Vector3.RIGHT)


## Rope, or cable pulled off a machine, coiled and worn across the body from the
## left shoulder to the right hip, so it reads from the front and from behind.
static func _coil(r: SkinRig, w: PersonBody.Wear) -> void:
	var d := w.d
	var spine := r.find(&"spine")
	var top: float = d.torso - 0.04
	var rope := Rng.hash01(w.seed_value, 111) < 0.5
	var k := r.kit(spine, &"gear", SkinRig.MADE if rope else SkinRig.FOUND)
	var cols: Array = [Palette.SAND[3], Palette.SAND[4], Palette.SAND[2]] if rope else [Palette.INK[3], Palette.PLATE[2], Palette.INK[2]]
	var mid_y := top * 0.5
	var ring := PersonBody.torso_ring(w, mid_y)
	# The loop's long axis runs from over the left shoulder to past the right hip.
	var along := Vector3(0, 1.0, -0.62).normalized()
	var c := Vector3(ring.z, mid_y + 0.02, 0.0)
	var half := top * 0.72
	var depth := ring.x + 0.034
	var segs := 7
	var pts: Array[Vector3] = []
	for i in segs:
		var a := float(i) / segs * TAU
		pts.append(c + along * cos(a) * half + Vector3(1, 0, 0) * sin(a) * depth)
	# Three turns side by side, each its own shade, so it reads as a coil and not
	# a strap.
	var tube := 0.017
	var n0 := Vector3.RIGHT.cross(along).normalized()
	for turn in 3:
		var shift := n0 * (turn - 1.0) * 0.034 + Vector3.RIGHT * (0.006 if turn == 1 else 0.0)
		for i in segs:
			var p0 := pts[i] + shift
			var p1 := pts[(i + 1) % segs] + shift
			var t := (p1 - p0).normalized()
			var b0 := t.cross(n0).normalized()
			var col: Color = cols[turn % cols.size()] if i % 3 else cols[(turn + 1) % cols.size()]
			for j in 3:
				var q0 := (n0 * cos(j / 3.0 * TAU) + b0 * sin(j / 3.0 * TAU)) * tube
				var q1 := (n0 * cos((j + 1) / 3.0 * TAU) + b0 * sin((j + 1) / 3.0 * TAU)) * tube
				Sculpt.card(k, p0 + q0, p1 + q0, p1 + q1, p0 + q1, col, (q0 + q1).normalized())
	var tie := r.kit(spine, &"gear")
	var knot := pts[segs / 2 + 1]
	Sculpt.loft(tie, [[knot.y - 0.03, 0.036, 0.036, knot.x, knot.z], [knot.y + 0.03, 0.036, 0.036, knot.x, knot.z]], 4, Palette.EARTH[1] if rope else CORD, false, false, PI / 4)
	if not rope:
		# The cut end hanging from the knot, copper showing.
		var e := knot + Vector3(0.02, -0.03, 0.0)
		Sculpt.card(k, e + Vector3(0, 0, -0.01), e + Vector3(0, 0, 0.01), e + Vector3(0.01, -0.09, 0.012), e + Vector3(0.01, -0.09, -0.008), Palette.COPPER[3], Vector3.RIGHT)


# ---------------------------------------------------------------- shapes

## A rectangle with its corners cut (none when `cut` is 0), centred, counter-clockwise.
static func _rect(wd: float, ht: float, cut: float) -> PackedVector2Array:
	var x := wd * 0.5
	var y := ht * 0.5
	if cut <= 0.0:
		return PackedVector2Array([Vector2(-x, -y), Vector2(x, -y), Vector2(x, y), Vector2(-x, y)])
	return PackedVector2Array([
		Vector2(-x + cut, -y), Vector2(x - cut, -y), Vector2(x, -y + cut), Vector2(x, y - cut),
		Vector2(x - cut, y), Vector2(-x + cut, y), Vector2(-x, y - cut), Vector2(-x, -y + cut),
	])
