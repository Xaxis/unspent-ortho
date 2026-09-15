class_name PersonBody
## Builds a person's skeleton (proportioned by build) and dresses it (clothes,
## hair, salvage) as parts bound to the bones they move with.
##
## Local frame: the person faces +X, up is +Y, their right hand is +Z.
## A limb hangs along -Y from its joint; +Z rotation swings it forward.
##
## Proportions (art-audio-extract §4): chunky, ~4.6 heads tall, legs carry the
## height, arms hang outside the torso. The base man is 1.34 units tall.
##
## Drawn per docs/ART.md: every part is a lofted solid (Sculpt), 6-8 sided and
## tapered, a little uneven because a hand made it; nothing is a box. Clothing
## replaces the layer under it instead of stacking shells, which is what keeps
## the heaviest look inside 800 triangles. Machine salvage goes on the FOUND
## surface (exact, unhatched) and the straps that tie it on stay MADE.

const BONES: Array[StringName] = [
	&"root", &"hips", &"spine", &"head",
	&"arm_l", &"fore_l", &"hand_l", &"arm_r", &"fore_r", &"hand_r", &"tool", &"food",
	&"thigh_l", &"shin_l", &"foot_l", &"thigh_r", &"shin_r", &"foot_r",
	&"hem", &"aerial", &"aerial_tip", &"tally",
]


## Every size a builder or animator needs, in units, for a build.
static func dims(build: StringName) -> Dictionary:
	var s := PersonLook.shape(build)
	var leg: float = s.leg
	var d := {}
	# Heights run ~8% over the source's 1.35 so the figure survives the camera's
	# vertical foreshortening; heads are taller than they are deep, because the
	# crown is seen nearly as large as the face from this pitch.
	d.boot = 0.12 * lerpf(1.0, leg, 0.4)
	d.thigh = 0.3 * leg
	d.shin = 0.27 * leg
	d.hip_y = d.thigh + d.shin + d.boot
	d.torso = 0.45 * float(s.torso)
	d.chest = 0.38 * float(s.chest)
	d.hip = 0.31 * float(s.hip)
	d.depth = 0.21 * float(s.girth)
	d.belly = float(s.belly)
	d.head = 0.35 * float(s.head)
	d.head_w = 0.3 * float(s.head)
	d.head_d = 0.26 * float(s.head)
	d.upper = 0.27 * float(s.arm)
	d.fore = 0.23 * float(s.arm)
	d.hand = 0.09 * lerpf(1.0, float(s.limb), 0.5)
	d.arm_t = 0.11 * float(s.limb)
	d.thigh_t = 0.15 * lerpf(1.0, float(s.limb), 0.8)
	d.shin_t = 0.13 * lerpf(1.0, float(s.limb), 0.7)
	d.stoop = float(s.stoop)
	d.arms = float(s.arms)
	d.knees = float(s.knees)
	return d


static func make_rig(build: StringName) -> SkinRig:
	var d := dims(build)
	var r := SkinRig.new()
	var root := r.bone(&"root", -1, Vector3.ZERO)
	var hips := r.bone(&"hips", root, Vector3(0, d.hip_y, 0))
	var spine := r.bone(&"spine", hips, Vector3(0, 0.05, 0))
	r.bone(&"head", spine, Vector3(0, d.torso - 0.02, 0))
	var sh_y: float = d.torso - 0.075
	var sh_z: float = d.chest * 0.5 + d.arm_t * 0.3
	for side: int in [-1, 1]:
		var sfx := "_l" if side < 0 else "_r"
		var arm := r.bone(StringName("arm" + sfx), spine, Vector3(0, sh_y, sh_z * side))
		var fore := r.bone(StringName("fore" + sfx), arm, Vector3(0, -d.upper, 0))
		var hand := r.bone(StringName("hand" + sfx), fore, Vector3(0, -d.fore, 0))
		if side > 0:
			r.bone(&"tool", hand, Vector3(0, -d.hand * 0.55, 0))
		else:
			r.bone(&"food", hand, Vector3(0.02, -d.hand * 0.7, 0))
	for side: int in [-1, 1]:
		var sfx := "_l" if side < 0 else "_r"
		var thigh := r.bone(StringName("thigh" + sfx), hips, Vector3(0, -0.03, d.hip * 0.27 * side))
		var shin := r.bone(StringName("shin" + sfx), thigh, Vector3(0, -d.thigh, 0))
		r.bone(StringName("foot" + sfx), shin, Vector3(0, -d.shin, 0))
	r.bone(&"hem", hips, Vector3(0, 0.0, 0))
	var aer := r.bone(&"aerial", spine, Vector3(-d.depth * 0.3, d.torso - 0.04, d.chest * 0.32))
	r.bone(&"aerial_tip", aer, Vector3(0, 0.3, 0))
	r.bone(&"tally", hips, Vector3(0, -0.02, d.hip * 0.5 + 0.02))
	return r


## The resolved colours and switches one dress() works from.
class Wear:
	extends RefCounted
	var d: Dictionary
	var look: Dictionary
	var seed_value := 0
	var skin: Array[Color]
	var hair: Array[Color]
	var shirt: Color
	var shirt_hi: Color
	var shirt_lo: Color
	var coat: Color
	var coat_hi: Color
	var coat_lo: Color
	var trouser: Color
	var trouser_lo: Color
	var boot: Color
	var boot_hi: Color
	var hat: Color
	var hat_hi: Color
	var hat_lo: Color
	## Coat that covers the torso and sleeves (long, oilskin).
	var long_coat := false
	var extras: Array = []
	var salvage: Array = []


static func _wear(look: Dictionary) -> Wear:
	var w := Wear.new()
	w.look = look
	w.d = dims(look.build)
	w.seed_value = hash(PersonLook.signature(look) + str(look.get("hair", "")) + str(look.get("shirt", "")))
	w.skin = PersonLook.skin_values(look)
	w.hair = PersonLook.hair_values(look)
	w.shirt = PersonLook.colour(look.shirt)
	w.shirt_hi = PersonLook.step(look.shirt, 1)
	w.shirt_lo = PersonLook.step(look.shirt, -1)
	w.coat = PersonLook.colour(look.coat_col)
	w.coat_hi = PersonLook.step(look.coat_col, 1)
	w.coat_lo = PersonLook.step(look.coat_col, -1)
	w.trouser = PersonLook.colour(look.trouser)
	w.trouser_lo = PersonLook.step(look.trouser, -1)
	w.boot = PersonLook.colour(look.boot)
	w.boot_hi = PersonLook.step(look.boot, 1)
	w.hat = PersonLook.colour(look.hat_col)
	w.hat_hi = PersonLook.step(look.hat_col, 1)
	w.hat_lo = PersonLook.step(look.hat_col, -1)
	w.long_coat = look.coat == &"long" or look.coat == &"oilskin"
	w.extras = look.extras
	w.salvage = look.salvage
	return w


## Dress a fresh rig with a normalized look. Geometry only; call rig.attach/rebuild after.
static func dress(r: SkinRig, look: Dictionary) -> void:
	var w := _wear(look)
	_legs(r, w)
	_hips(r, w)
	_torso(r, w)
	_arms(r, w)
	_head(r, w)
	_extras(r, w)
	_salvage(r, w)
	# Food (hidden at rest by bone scale; shown while eating): a heel of bread.
	var food := r.kit(r.find(&"food"), &"food")
	Sculpt.loft(food, [[-0.035, 0.03, 0.03, 0.02, 0.0], [0.0, 0.06, 0.045, 0.02, 0.0], [0.04, 0.035, 0.03, 0.02, 0.0]], 4, [Palette.SAND[3], Palette.SAND[4]], false, true, 0.3, 0.12, 11)


static func _skin(k: MeshKit, on: bool) -> void:
	# UV2.y marks skin for the person shader: shaded, never hatched (ART.md §5).
	k.sway_phase = 1.0 if on else 0.0


# ---------------------------------------------------------------- legs

static func _legs(r: SkinRig, w: Wear) -> void:
	var d := w.d
	for side: int in [-1, 1]:
		var sfx := "_l" if side < 0 else "_r"
		var s := w.seed_value + side * 17
		var th := r.kit(r.find(StringName("thigh" + sfx)))
		var t0: float = d.thigh_t * 0.56
		var t1: float = d.shin_t * 0.5
		Sculpt.loft(th, [[0.02, t0 * 0.95, t0, 0.0, 0.0], [-float(d.thigh), t1 * 1.05, t1, 0.004, 0.0]], 6, w.trouser, false, false, PI / 6, 0.05, s)
		var sh := r.kit(r.find(StringName("shin" + sfx)))
		var sl: float = d.shin
		var s0: float = d.shin_t * 0.5
		var calf := s0 * 1.08
		var ankle := s0 * 0.78
		var boot_top := -sl * 0.62
		Sculpt.loft(sh, [
			[0.0, s0, s0, 0.0, 0.0],
			[boot_top, calf, calf * 0.96, -0.004, 0.0],
			[-sl, ankle * 1.05, ankle, 0.006, 0.0],
		], 6, [w.trouser, w.boot], true, false, PI / 6, 0.05, s + 3)
		var ft := r.kit(r.find(StringName("foot" + sfx)))
		_boot(ft, d, w, s + 7)


## A boot as a loft along the foot: heel, instep, a blunt toe that sits low.
static func _boot(k: MeshKit, d: Dictionary, w: Wear, seed_value: int) -> void:
	var sole := -float(d.boot) + 0.03
	var bw: float = d.shin_t * 0.52
	# Local +Y runs along the foot (+X), local +X is up.
	k.push(Transform3D(Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)), Vector3.ZERO))
	Sculpt.loft(k, [
		[-0.075, 0.05, bw * 0.8, sole + 0.05, 0.0],
		[0.03, 0.075, bw * 1.02, sole + 0.07, 0.0],
		[0.175, 0.034, bw * 0.84, sole + 0.034, 0.0],
	], 6, [w.boot, w.boot_hi], true, true, PI / 6, 0.04, seed_value)
	k.pop()


# ---------------------------------------------------------------- hips and torso

static func _hips(r: SkinRig, w: Wear) -> void:
	var d := w.d
	var k := r.kit(r.find(&"hips"))
	var hd: float = d.depth
	var hz: float = d.hip
	var cz := lerpf(d.hip, d.chest, 0.45)
	var cut: StringName = w.look.shirt_cut
	var belt := Palette.EARTH[1]
	var top := w.trouser
	if not w.long_coat and w.look.coat != &"jerkin":
		top = belt if cut == &"tucked" else w.shirt
	Sculpt.loft(k, [
		[-0.14, hd * 0.4, hz * 0.44, -0.01, 0.0],
		[0.04, hd * 0.52, lerpf(hz, cz, 0.5) * 0.52, 0.0, 0.0],
		[0.11, hd * 0.49, cz * 0.49, 0.0, 0.0],
	], 8, [w.trouser, top], true, false, PI / 8, 0.03, w.seed_value + 1)
	if cut == &"tucked" and not w.long_coat and w.extras.has(&"buckle"):
		var bx := hd * 0.5 * 0.93 + 0.004
		Sculpt.card(k, Vector3(bx, 0.07, -0.028), Vector3(bx, 0.07, 0.028), Vector3(bx, 0.11, 0.028), Vector3(bx, 0.11, -0.028), Palette.COPPER[3], Vector3.RIGHT)

	# Skirts on the hem bone: coats and smocks swing on their own.
	var hem := r.kit(r.find(&"hem"))
	var length := 0.0
	var flare := 0.0
	var col := w.coat
	var lo := w.coat_lo
	match w.look.coat:
		&"long":
			length = d.thigh + d.shin * 0.42
			flare = 0.09
		&"oilskin":
			length = d.thigh + d.shin * 0.2
			flare = 0.15
		&"jerkin":
			length = d.thigh * 0.28
			flare = 0.03
	if length == 0.0 and cut == &"smock":
		length = d.thigh * 0.6
		flare = 0.06
		col = w.shirt
		lo = w.shirt_lo
	elif length == 0.0 and cut == &"loose":
		length = d.thigh * 0.24
		flare = 0.03
		col = w.shirt
		lo = w.shirt_lo
	if length > 0.0:
		var y1 := -length
		var rings: Array = [
			[0.08, hd * 0.53, cz * 0.53, 0.0, 0.0],
			[-length * 0.45, hd * 0.55 + flare * 0.5, hz * 0.56 + flare * 0.45, -flare * 0.2, 0.0],
			[y1, hd * 0.55 + flare * 1.04, hz * 0.56 + flare * 1.04, -flare * 0.48, 0.0],
		]
		if length > d.thigh * 0.5:
			# Long skirts part at the front so the legs stride through them.
			Sculpt.skirt(hem, rings, 6, col, lo, 0.8, PI, 0.06, w.seed_value + 2)
		else:
			Sculpt.loft(hem, rings, 8, [col, lo], false, false, PI / 8, 0.06, w.seed_value + 2)
	if w.extras.has(&"apron"):
		var ay: float = -d.thigh * 0.8
		var ax: float = hd * 0.55 + flare + 0.018
		hem.push(Transform3D(Basis(Vector3(0, 0, 1), -0.08), Vector3(ax, 0, 0)))
		Sculpt.card(hem, Vector3(0, ay, -hz * 0.36), Vector3(0, ay, hz * 0.36), Vector3(0, 0.1, hz * 0.3), Vector3(0, 0.1, -hz * 0.3), Palette.LINEN[3], Vector3.RIGHT)
		hem.pop()


static func _torso(r: SkinRig, w: Wear) -> void:
	var d := w.d
	var k := r.kit(r.find(&"spine"))
	var top: float = d.torso - 0.04
	var hd: float = d.depth
	var waist := lerpf(d.hip, d.chest, 0.5)
	var belly: float = d.belly
	var coat: StringName = w.look.coat
	var body := w.coat if w.long_coat else w.shirt
	var body_hi := w.coat_hi if w.long_coat else w.shirt_hi
	var pad := 0.012 if w.long_coat else 0.0
	Sculpt.loft(k, [
		[0.0, hd * 0.5 + pad, waist * 0.5 + pad, 0.0, 0.0],
		[top * 0.42, hd * 0.52 + belly * 0.6 + pad, lerpf(waist, d.chest, 0.65) * 0.5 + pad, belly * 0.7, 0.0],
		[top * 0.8, hd * 0.56 + pad, d.chest * 0.5 + pad, 0.008, 0.0],
		[top, hd * 0.44 + pad, d.chest * 0.45 + pad, -0.006, 0.0],
		[top + 0.045, 0.075, 0.085, -0.012, 0.0],
	], 8, [body, body, body, body_hi], false, true, PI / 8, 0.035, w.seed_value + 4)
	# Neck: in shade, so the head reads as sitting on the shoulders, not floating.
	if coat != &"oilskin" and not w.extras.has(&"neckerchief"):
		_skin(k, true)
		Sculpt.loft(k, [[top + 0.02, 0.05, 0.055, -0.01, 0.0], [top + 0.1, 0.048, 0.052, -0.004, 0.0]], 6, w.skin[0], false, false, PI / 6)
		_skin(k, false)
	var front := hd * 0.56 * 0.924 + pad
	match coat:
		&"jerkin":
			# A sleeveless leather jerkin, open down the front over the shirt.
			Sculpt.loft(k, [
				[-0.05, hd * 0.56, waist * 0.56, 0.0, 0.0],
				[top * 0.8, hd * 0.6, d.chest * 0.54, 0.008, 0.0],
				[top + 0.01, hd * 0.47, d.chest * 0.49, -0.006, 0.0],
			], 7, [w.coat, w.coat_hi], false, false, 0.0, 0.05, w.seed_value + 5, 0.82, PI)
		&"long":
			# The shirt shows in a V between the lapels.
			var vy := top * 0.52
			k.tri(Vector3(front + 0.004, vy, 0), Vector3(front - 0.02, top + 0.02, -0.06), Vector3(front - 0.02, top + 0.02, 0.06), w.shirt)
			Sculpt.card(k, Vector3(front + 0.006, top * 0.1, 0.004), Vector3(front + 0.006, top * 0.1, 0.016), Vector3(front + 0.006, vy, 0.016), Vector3(front + 0.006, vy, 0.004), w.coat_lo, Vector3.RIGHT)
		&"oilskin":
			# A tall collar turned up against the weather.
			Sculpt.loft(k, [[top - 0.01, hd * 0.47, d.chest * 0.43, -0.008, 0.0], [top + 0.1, hd * 0.44, d.chest * 0.36, -0.02, 0.0]], 6, w.coat_hi, false, false, 0.0, 0.03, w.seed_value + 6, 0.78, PI)
			for i in 3:
				var y := top * (0.2 + i * 0.24)
				Sculpt.card(k, Vector3(front + 0.004, y, -0.014), Vector3(front + 0.004, y, 0.014), Vector3(front + 0.004, y + 0.028, 0.014), Vector3(front + 0.004, y + 0.028, -0.014), Palette.COPPER[2], Vector3.RIGHT)


# ---------------------------------------------------------------- arms and hands

static func _arms(r: SkinRig, w: Wear) -> void:
	var d := w.d
	var coat: StringName = w.look.coat
	var sleeve := w.coat if w.long_coat else w.shirt
	var rolled: bool = w.extras.has(&"rolled") and not w.long_coat
	var t: float = d.arm_t
	for side: int in [-1, 1]:
		var sfx := "_l" if side < 0 else "_r"
		var s := w.seed_value + side * 31
		var ak := r.kit(r.find(StringName("arm" + sfx)))
		var shoulder := sleeve
		if coat == &"jerkin":
			shoulder = w.coat
		Sculpt.loft(ak, [
			[t * 0.3, t * 0.36, t * 0.36, 0.0, 0.0],
			[0.0, t * 0.56, t * 0.56, 0.0, 0.0],
			[-float(d.upper) - 0.01, t * 0.44, t * 0.46, 0.006, 0.0],
		], 6, [shoulder, sleeve], false, false, PI / 6, 0.05, s)
		var fk := r.kit(r.find(StringName("fore" + sfx)))
		var fl: float = d.fore
		if rolled:
			_skin(fk, true)
			Sculpt.loft(fk, [
				[0.01, t * 0.5, t * 0.5, 0.0, 0.0],
				[-0.045, t * 0.5, t * 0.5, 0.0, 0.0],
				[-fl, t * 0.33, t * 0.37, 0.008, 0.0],
			], 6, [w.shirt_hi, w.skin[1]], true, false, PI / 6, 0.05, s + 1)
			_skin(fk, false)
		else:
			Sculpt.loft(fk, [
				[0.01, t * 0.46, t * 0.46, 0.0, 0.0],
				[-fl, t * 0.4, t * 0.42, 0.008, 0.0],
			], 6, [sleeve], true, false, PI / 6, 0.05, s + 1)
		_hand(r.kit(r.find(StringName("hand" + sfx))), d, w, side, s + 2)


## A chunky mitten, big enough to read as a hand at 640x360: palm wider than the
## wrist, blunt fingers, a thumb toward the front.
static func _hand(k: MeshKit, d: Dictionary, w: Wear, side: int, seed_value: int) -> void:
	var h: float = d.hand * 1.2
	_skin(k, true)
	Sculpt.loft(k, [
		[0.012, 0.03, 0.03, 0.0, 0.0],
		[-h * 0.48, h * 0.42, h * 0.27, 0.01, 0.0],
		[-h * 1.0, h * 0.3, h * 0.2, 0.004, 0.0],
	], 6, [w.skin[1], w.skin[2]], false, true, 0.0, 0.05, seed_value)
	var tz := -side * h * 0.12
	k.tri(Vector3(h * 0.3, -h * 0.18, tz), Vector3(h * 0.52, -h * 0.5, tz), Vector3(h * 0.26, -h * 0.5, tz - side * 0.02), w.skin[2])
	k.tri(Vector3(h * 0.3, -h * 0.18, tz), Vector3(h * 0.26, -h * 0.5, tz + side * 0.02), Vector3(h * 0.52, -h * 0.5, tz), w.skin[1])
	_skin(k, false)


# ---------------------------------------------------------------- head

static func _head(r: SkinRig, w: Wear) -> void:
	var d := w.d
	var k := r.kit(r.find(&"head"))
	var hh: float = d.head
	var hw: float = d.head_w
	var hd: float = d.head_d
	var hat: StringName = w.look.hat
	_skin(k, true)
	# Chin set forward, full cheeks, a crown that narrows: from this pitch the
	# crown is as big on screen as the face, so its outline matters as much.
	var rings: Array = [
		[0.0, hd * 0.3, hw * 0.3, hd * 0.12, 0.0],
		[hh * 0.26, hd * 0.47, hw * 0.44, hd * 0.06, 0.0],
		[hh * 0.58, hd * 0.52, hw * 0.5, 0.0, 0.0],
		[hh * 0.86, hd * 0.47, hw * 0.45, -0.012, 0.0],
	]
	# The crown only when no hat hides it; the chin is never seen from above.
	if hat == &"none":
		rings.append([hh * 1.0, hd * 0.3, hw * 0.28, -0.02, 0.0])
	Sculpt.loft(k, rings, 8, [w.skin[1], w.skin[1], w.skin[1], w.skin[2]], false, true, PI / 8, 0.025, w.seed_value + 9)
	var face := hd * 0.52 * 0.924
	# Eyes: two dark marks, tall enough to survive the camera's foreshortening.
	var ey := hh * 0.5
	for side: int in [-1, 1]:
		var z := side * hw * 0.2
		Sculpt.card(k, Vector3(face + 0.003, ey - 0.03, z - 0.02), Vector3(face + 0.003, ey - 0.03, z + 0.02), Vector3(face + 0.003, ey + 0.045, z + 0.02), Vector3(face + 0.003, ey + 0.045, z - 0.02), Palette.INK[1], Vector3.RIGHT)
	# Nose: a small wedge one step lighter, so a profile has a point.
	var nb := Vector3(face - 0.004, hh * 0.52, 0)
	var nt := Vector3(face + 0.05, hh * 0.34, 0)
	k.tri(nb, Vector3(face, hh * 0.3, 0.03), nt, w.skin[2])
	k.tri(nb, nt, Vector3(face, hh * 0.3, -0.03), w.skin[2])
	k.tri(Vector3(face, hh * 0.3, 0.03), Vector3(face, hh * 0.3, -0.03), nt, w.skin[0])
	# Ears.
	for side: int in [-1, 1]:
		var ez := side * (hw * 0.5 + 0.012)
		var e := [Vector3(-0.01, hh * 0.36, ez), Vector3(-0.045, hh * 0.62, ez), Vector3(0.02, hh * 0.6, ez)]
		if side > 0:
			k.tri(e[0], e[2], e[1], w.skin[0])
		else:
			k.tri(e[0], e[1], e[2], w.skin[0])
	_skin(k, false)
	_hair(k, w, hat)
	_beard(k, w)
	_hat(k, w, hat)


## The hair layer. A cap tilted back so the hairline is high at the brow and low
## at the nape; styles add to it. Under a hat only what shows below the brim is drawn.
static func _hair(k: MeshKit, w: Wear, hat: StringName) -> void:
	var d := w.d
	var hh: float = d.head
	var hw: float = d.head_w
	var hd: float = d.head_d
	var h0 := w.hair[0]
	var h1 := w.hair[1]
	var style: StringName = w.look.hair_style
	var covered := hat != &"none"
	var s := w.seed_value + 21
	var pivot := Vector3(0, hh * 0.62, 0)
	if not covered and style != &"bald" and style != &"thin":
		var wob := 0.16 if style == &"unkempt" else 0.05
		var lift := 0.03 if style == &"unkempt" else 0.012
		k.push(Transform3D(Basis(Vector3(0, 0, 1), 0.42), pivot))
		Sculpt.loft(k, [
			[hh * -0.08, hd * 0.55, hw * 0.53, -0.018, 0.0],
			[hh * 0.24, hd * 0.53 + lift, hw * 0.51 + lift, -0.02, 0.0],
			[hh * 0.44 + lift, hd * 0.3, hw * 0.3, -0.03, 0.0],
		], 8, [h0, h1], false, true, PI / 8, wob, s)
		k.pop()
	# The nape and the back of the head: shows under any hat.
	var back_lo := hh * 0.3
	if style == &"bald" or style == &"thin":
		back_lo = hh * 0.34
	if style != &"bald" or not covered:
		Sculpt.loft(k, [
			[back_lo, hd * 0.53, hw * 0.52, -0.012, 0.0],
			[hh * (0.6 if style == &"bald" else 0.74), hd * 0.54, hw * 0.52, -0.014, 0.0],
		], 6, h0, false, false, 0.0, 0.05, s + 1, 0.55, PI)
	match style:
		&"long":
			Sculpt.loft(k, [
				[-hh * 0.55, hd * 0.44, hw * 0.52, -0.05, 0.0],
				[hh * 0.62, hd * 0.56, hw * 0.55, -0.02, 0.0],
			], 6, h0, false, false, 0.0, 0.08, s + 2, 0.6, PI)
		&"tail":
			k.push(Transform3D(Basis(Vector3(0, 0, 1), -0.35), Vector3(-hd * 0.52, hh * 0.46, 0)))
			Sculpt.loft(k, [[0.02, 0.035, 0.04, 0.0, 0.0], [-hh * 0.95, 0.018, 0.02, 0.0, 0.0]], 4, [h0], true, false, 0.0, 0.1, s + 3)
			k.pop()
		&"bun":
			Sculpt.loft(k, [
				[hh * 0.62, 0.035, 0.04, -hd * 0.58, 0.0],
				[hh * 0.74, 0.07, 0.075, -hd * 0.66, 0.0],
				[hh * 0.88, 0.035, 0.04, -hd * 0.64, 0.0],
			], 5, [h0, h1], true, true, 0.0, 0.1, s + 4)
		&"unkempt":
			if not covered:
				for i in 3:
					var a := Rng.hash01(s, i) * TAU
					var base := Vector3(cos(a) * hd * 0.2 - 0.03, hh * 1.02, sin(a) * hw * 0.2)
					var tip := base + Vector3(cos(a) * 0.06, 0.06 + Rng.hash01(s, i, 2) * 0.05, sin(a) * 0.06)
					k.tri(base + Vector3(0, 0, -0.03), tip, base + Vector3(0, 0, 0.03), h1)
					k.tri(base + Vector3(0, 0, 0.03), tip, base + Vector3(0, 0, -0.03), h0)
		&"thin":
			if not covered:
				k.quad(Vector3(-hd * 0.2, hh * 1.005, -hw * 0.12), Vector3(-hd * 0.2, hh * 1.005, hw * 0.1), Vector3(hd * 0.08, hh * 1.005, hw * 0.08), Vector3(hd * 0.08, hh * 1.005, -hw * 0.1), h1)


static func _beard(k: MeshKit, w: Wear) -> void:
	var d := w.d
	var hh: float = d.head
	var hw: float = d.head_w
	var hd: float = d.head_d
	var h0 := w.hair[0]
	var h1 := w.hair[1]
	match w.look.beard:
		&"chin":
			Sculpt.loft(k, [[hh * 0.22, 0.03, hw * 0.16, hd * 0.42, 0.0], [-hh * 0.12, 0.01, 0.02, hd * 0.44, 0.0]], 4, h0, false, true, PI / 4)
		&"full":
			Sculpt.loft(k, [
				[-hh * 0.14, hd * 0.24, hw * 0.24, hd * 0.2, 0.0],
				[hh * 0.14, hd * 0.52, hw * 0.5, hd * 0.06, 0.0],
				[hh * 0.46, hd * 0.55, hw * 0.52, 0.0, 0.0],
			], 6, [h0, h1], false, false, 0.0, 0.08, w.seed_value + 23, 0.62, 0.0)
		&"stache":
			var x := hd * 0.47 + 0.012
			Sculpt.card(k, Vector3(x, hh * 0.2, -hw * 0.22), Vector3(x, hh * 0.2, hw * 0.22), Vector3(x + 0.004, hh * 0.3, hw * 0.16), Vector3(x + 0.004, hh * 0.3, -hw * 0.16), h1, Vector3.RIGHT)
			k.quad(Vector3(x - 0.02, hh * 0.3, -hw * 0.16), Vector3(x - 0.02, hh * 0.3, hw * 0.16), Vector3(x + 0.004, hh * 0.3, hw * 0.16), Vector3(x + 0.004, hh * 0.3, -hw * 0.16), h0)


## Hats change the silhouette first; colour is second.
static func _hat(k: MeshKit, w: Wear, hat: StringName) -> void:
	var d := w.d
	var hh: float = d.head
	var hw: float = d.head_w
	var hd: float = d.head_d
	var c := w.hat
	var hi := w.hat_hi
	var lo := w.hat_lo
	var s := w.seed_value + 41
	var rx := hd * 0.55
	var rz := hw * 0.54
	match hat:
		&"band":
			# A tall felt crown with a dark band: height is the silhouette.
			Sculpt.loft(k, [
				[hh * 0.64, rx * 1.02, rz * 1.02, -0.012, 0.0],
				[hh * 1.34, rx * 0.84, rz * 0.84, -0.03, 0.0],
			], 8, c, false, true, PI / 8, 0.04, s)
			_brim(k, hh * 0.64, rx * 1.02, rz * 1.02, rx * 1.4, rz * 1.4, -0.01, lo, c, s + 1)
		&"brim":
			Sculpt.loft(k, [[hh * 0.7, rx * 0.98, rz * 0.98, -0.012, 0.0], [hh * 1.1, rx * 0.8, rz * 0.8, -0.02, 0.0]], 8, c, false, true, PI / 8, 0.05, s)
			_brim(k, hh * 0.72, rx * 0.98, rz * 0.98, rx * 1.85, rz * 1.8, -0.05, lo, c, s + 1)
		&"cap":
			Sculpt.loft(k, [[hh * 0.66, rx * 1.02, rz * 1.02, -0.012, 0.0], [hh * 0.98, rx * 0.9, rz * 0.9, -0.02, 0.0], [hh * 1.07, rx * 0.5, rz * 0.5, -0.03, 0.0]], 8, [c, hi], false, false, PI / 8, 0.04, s)
			var vy := hh * 0.7
			var vx := hd * 0.5
			k.quad(Vector3(vx, vy, -hw * 0.34), Vector3(vx, vy, hw * 0.34), Vector3(vx + 0.13, vy - 0.03, hw * 0.26), Vector3(vx + 0.13, vy - 0.03, -hw * 0.26), lo)
			k.quad(Vector3(vx + 0.13, vy - 0.035, -hw * 0.26), Vector3(vx + 0.13, vy - 0.035, hw * 0.26), Vector3(vx, vy - 0.005, hw * 0.34), Vector3(vx, vy - 0.005, -hw * 0.34), Palette.INK[2])
		&"knit":
			Sculpt.loft(k, [
				[hh * 0.58, rx * 1.05, rz * 1.05, -0.012, 0.0],
				[hh * 0.74, rx * 1.05, rz * 1.05, -0.014, 0.0],
				[hh * 1.02, rx * 0.8, rz * 0.8, -0.03, 0.0],
				[hh * 1.22, rx * 0.12, rz * 0.12, -0.06, 0.0],
			], 8, [lo, c, hi], false, false, PI / 8, 0.05, s)
		&"scarf":
			# Wrapped over the head and knotted at the nape, tails hanging.
			Sculpt.loft(k, [
				[hh * 0.22, rx * 1.04, rz * 1.04, -0.01, 0.0],
				[hh * 0.78, rx * 1.02, rz * 1.02, -0.015, 0.0],
				[hh * 1.08, rx * 0.5, rz * 0.5, -0.03, 0.0],
			], 8, [c, hi], false, true, 0.0, 0.05, s, 0.74, PI)
			Sculpt.loft(k, [[hh * 0.3, 0.045, 0.06, -hd * 0.58, 0.0], [-hh * 0.4, 0.02, 0.07, -hd * 0.66, 0.03]], 4, lo, true, true, PI / 4, 0.12, s + 2)
		&"souwester":
			# Brim low all round and longest at the back, to shed rain off the collar.
			Sculpt.loft(k, [[hh * 0.64, rx * 1.03, rz * 1.03, -0.012, 0.0], [hh * 1.12, rx * 0.72, rz * 0.72, -0.03, 0.0]], 8, c, false, true, PI / 8, 0.04, s)
			_brim(k, hh * 0.66, rx * 1.03, rz * 1.03, rx * 1.55, rz * 1.5, -0.08, lo, c, s + 1, -0.07)


## A brim: an annulus from the crown ring out to (ox, oz), its edge dropped by
## `droop`, pushed back by `back` so a sou'wester is longer behind.
static func _brim(k: MeshKit, y: float, ix: float, iz: float, ox: float, oz: float, droop: float, under: Color, top: Color, seed_value: int, back: float = 0.0) -> void:
	var n := 8
	var inner: Array[Vector3] = []
	var outer: Array[Vector3] = []
	for i in n:
		var a := PI / n + float(i) / n * TAU
		var j := 1.0 + (Rng.hash01(seed_value, i) - 0.5) * 0.1
		inner.append(Vector3(cos(a) * ix - 0.012, y, sin(a) * iz))
		var behind := maxf(0.0, -cos(a))
		outer.append(Vector3(cos(a) * ox * j - 0.012 + back * behind, y + droop * j - absf(back) * behind * 0.6, sin(a) * oz * j))
	for i in n:
		var i2 := (i + 1) % n
		k.quad(inner[i2], inner[i], outer[i], outer[i2], under)
		k.quad(inner[i], inner[i2], outer[i2], outer[i], top)


# ---------------------------------------------------------------- extras

static func _extras(r: SkinRig, w: Wear) -> void:
	var d := w.d
	var top: float = d.torso - 0.04
	var hd: float = d.depth
	var tk := r.kit(r.find(&"spine"))
	if w.extras.has(&"shawl"):
		Sculpt.loft(tk, [
			[top * 0.5, hd * 0.66, d.chest * 0.6, -0.03, 0.0],
			[top + 0.06, hd * 0.4, d.chest * 0.34, -0.012, 0.0],
		], 8, w.hat, false, false, PI / 8, 0.08, w.seed_value + 51, 0.8, PI)
	if w.extras.has(&"neckerchief"):
		var nx := hd * 0.44
		tk.tri(Vector3(nx, top + 0.03, -0.07), Vector3(nx + 0.04, top - 0.07, 0.0), Vector3(nx, top + 0.03, 0.07), Palette.RUST[3])
		Sculpt.loft(tk, [[top + 0.005, 0.085, 0.09, -0.004, 0.0], [top + 0.05, 0.07, 0.075, -0.01, 0.0]], 6, Palette.RUST[3], false, false, PI / 6, 0.05, w.seed_value + 52)
	if w.extras.has(&"satchel"):
		# A strap from the right shoulder across to a bag on the left hip.
		var f := hd * 0.56 + (0.012 if w.long_coat else 0.0) + 0.006
		for x: float in [f, -f]:
			Sculpt.card(tk, Vector3(x, top + 0.01, d.chest * 0.34), Vector3(x, top - 0.035, d.chest * 0.42), Vector3(x, -0.06, -d.chest * 0.34), Vector3(x, -0.02, -d.chest * 0.42), Palette.EARTH[1], Vector3(signf(x), 0, 0))
		var hk := r.kit(r.find(&"hips"))
		var bz: float = -(d.hip * 0.5 + 0.05)
		Sculpt.loft(hk, [[-0.18, 0.1, 0.035, 0.03, bz], [-0.02, 0.11, 0.04, 0.03, bz]], 5, [Palette.EARTH[2]], false, true, 0.0, 0.06, w.seed_value + 53)


# ---------------------------------------------------------------- salvage

## Parts off the machines, tied on. The part is FOUND (exact, unhatched, on the
## found surface); whatever ties it on is MADE. One or two per person.
static func _salvage(r: SkinRig, w: Wear) -> void:
	var d := w.d
	var side: int = w.look.side
	var sfx := "_r" if side > 0 else "_l"
	for part: StringName in w.salvage:
		match part:
			&"plate":
				# A slab of machine plate over one shoulder, off the same line as the roofs.
				var k := r.kit(r.find(StringName("arm" + sfx)), &"salvage", SkinRig.FOUND)
				var t: float = d.arm_t
				k.push(Transform3D(Basis(Vector3(1, 0, 0), side * 0.25), Vector3(0, 0.02, side * (t * 0.5 + 0.03))))
				Sculpt.slab(k, _hexplate(t * 1.9, 0.24, 0.05, 0.07), 0.016, Palette.PLATE[3], Palette.PLATE[2])
				for x: float in [-t * 0.62, t * 0.62]:
					Sculpt.card(k, Vector3(x - 0.012, 0.02, side * 0.0175), Vector3(x + 0.012, 0.02, side * 0.0175), Vector3(x + 0.012, 0.044, side * 0.0175), Vector3(x - 0.012, 0.044, side * 0.0175), Palette.PLATE[5], Vector3(0, 0, side))
				k.pop()
				var tie := r.kit(r.find(StringName("arm" + sfx)), &"salvage")
				Sculpt.loft(tie, [[-0.09, t * 0.5, t * 0.5, 0.0, 0.0], [-0.06, t * 0.5, t * 0.5, 0.0, 0.0]], 5, Palette.EARTH[1], false, false, 0.0)
			&"brace":
				var sh := r.kit(r.find(StringName("shin" + sfx)), &"salvage", SkinRig.FOUND)
				var z: float = side * (d.shin_t * 0.52 + 0.02)
				sh.push(Transform3D(Basis(Vector3(0, 1, 0), PI * 0.5), Vector3(0, 0, z)))
				Sculpt.slab(sh, _chamfered(0.045, d.shin * 0.9, 0.012, -d.shin * 0.45), 0.01, Palette.FOUND[2], Palette.FOUND[1])
				sh.pop()
				sh.push(Transform3D(Basis(Vector3(0, 1, 0), PI * 0.5), Vector3(0, 0, z + side * 0.012)))
				Sculpt.slab(sh, _octagon(0.035), 0.012, Palette.FOUND[3], Palette.FOUND[1])
				sh.pop()
				var th := r.kit(r.find(StringName("thigh" + sfx)), &"salvage", SkinRig.FOUND)
				var tz: float = side * (d.thigh_t * 0.56 + 0.02)
				th.push(Transform3D(Basis(Vector3(0, 1, 0), PI * 0.5), Vector3(0, 0, tz)))
				Sculpt.slab(th, _chamfered(0.045, d.thigh * 0.62, 0.012, -d.thigh * 0.62), 0.01, Palette.FOUND[2], Palette.FOUND[1])
				th.pop()
				var strap := r.kit(r.find(StringName("shin" + sfx)), &"salvage")
				Sculpt.loft(strap, [[-d.shin * 0.5, d.shin_t * 0.56, d.shin_t * 0.56, 0.0, 0.0], [-d.shin * 0.42, d.shin_t * 0.56, d.shin_t * 0.56, 0.0, 0.0]], 6, Palette.EARTH[1], false, false, PI / 6)
			&"rig":
				# Canvas webbing across the chest (MADE) held by a machine clasp (FOUND).
				var k := r.kit(r.find(&"spine"), &"salvage")
				var top: float = d.torso - 0.04
				var fx: float = d.depth * 0.56 + d.belly * 0.7 + 0.008
				for zz: float in [-0.26, 0.26]:
					Sculpt.card(k, Vector3(fx, 0.0, zz * d.chest - 0.018), Vector3(fx, 0.0, zz * d.chest + 0.018), Vector3(fx - 0.03, top + 0.02, zz * d.chest + 0.018), Vector3(fx - 0.03, top + 0.02, zz * d.chest - 0.018), Palette.INK[3], Vector3.RIGHT)
				Sculpt.card(k, Vector3(fx + 0.002, top * 0.36, -d.chest * 0.44), Vector3(fx + 0.002, top * 0.36, d.chest * 0.44), Vector3(fx + 0.002, top * 0.44, d.chest * 0.44), Vector3(fx + 0.002, top * 0.44, -d.chest * 0.44), Palette.INK[3], Vector3.RIGHT)
				var clasp := r.kit(r.find(&"spine"), &"salvage", SkinRig.FOUND)
				clasp.push(Transform3D(Basis(Vector3(0, 1, 0), -PI * 0.5), Vector3(fx + 0.012, top * 0.4, 0)))
				Sculpt.slab(clasp, _octagon(0.042), 0.01, Palette.FOUND[3], Palette.FOUND[2])
				clasp.pop()
			&"gauntlet":
				var k := r.kit(r.find(StringName("fore" + sfx)), &"salvage", SkinRig.FOUND)
				var t: float = d.arm_t
				var rings: Array = []
				for i in 4:
					var y: float = -d.fore * (0.2 + i * 0.24)
					var rr := t * (0.54 if i % 2 == 0 else 0.48)
					rings.append([y, rr, rr, 0.0, 0.0])
				Sculpt.loft(k, rings, 6, [Palette.FOUND[1], Palette.FOUND[2], Palette.FOUND[1]], true, true, PI / 6)
			&"tally":
				var k := r.kit(r.find(&"tally"), &"salvage", SkinRig.FOUND)
				for i in 3:
					var x := -0.075 + i * 0.075
					k.push(Transform3D(Basis(Vector3(0, 1, 0), PI * 0.5), Vector3(x, -0.12 - (i % 2) * 0.03, side * 0.01)))
					Sculpt.slab(k, _chamfered(0.05, 0.08, 0.012, 0.0), 0.008, Palette.PLATE[3], Palette.PLATE[2])
					k.pop()
				var cord := r.kit(r.find(&"tally"), &"salvage")
				Sculpt.card(cord, Vector3(-0.11, -0.02, 0.012), Vector3(0.11, -0.02, 0.012), Vector3(0.11, -0.005, 0.012), Vector3(-0.11, -0.005, 0.012), Palette.EARTH[1], Vector3(0, 0, 1))
			&"aerial":
				var base := r.kit(r.find(&"aerial"), &"salvage", SkinRig.FOUND)
				Sculpt.loft(base, [[-0.04, 0.035, 0.035, 0.0, 0.0], [0.02, 0.035, 0.035, 0.0, 0.0]], 4, Palette.FOUND[2], true, true, PI / 4)
				Sculpt.loft(base, [[0.02, 0.012, 0.012, 0.0, 0.0], [0.31, 0.009, 0.009, 0.0, 0.0]], 4, Palette.FOUND[3], false, true, PI / 4)
				var tip := r.kit(r.find(&"aerial_tip"), &"salvage", SkinRig.FOUND)
				Sculpt.loft(tip, [[0.0, 0.008, 0.008, 0.0, 0.0], [0.26, 0.005, 0.005, 0.0, 0.0]], 4, Palette.FOUND[4], false, false, PI / 4)
				var live := r.kit(r.find(&"aerial_tip"), &"salvage_glow", SkinRig.GLOW)
				Sculpt.loft(live, [[0.23, 0.0, 0.0, 0.0, 0.0], [0.27, 0.03, 0.03, 0.0, 0.0], [0.31, 0.0, 0.0, 0.0, 0.0]], 4, Palette.EMBER[4], false, false, PI / 4)
			&"lens":
				var k := r.kit(r.find(&"head"), &"salvage", SkinRig.FOUND)
				var ez: float = side * d.head_w * 0.2
				var fx: float = d.head_d * 0.48
				k.push(Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), Vector3(fx, d.head * 0.52, ez)))
				Sculpt.loft(k, [[0.0, 0.045, 0.045, 0.0, 0.0], [0.06, 0.04, 0.04, 0.0, 0.0]], 6, Palette.FOUND[1], false, false, 0.0)
				k.pop()
				var glass := r.kit(r.find(&"head"), &"salvage_glow", SkinRig.GLOW)
				glass.push(Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), Vector3(fx + 0.058, d.head * 0.52, ez)))
				Sculpt.loft(glass, [[0.0, 0.034, 0.034, 0.0, 0.0], [0.004, 0.034, 0.034, 0.0, 0.0]], 6, Palette.COLD[2], false, true, 0.0)
				glass.pop()
				var band := r.kit(r.find(&"head"), &"salvage")
				Sculpt.loft(band, [[d.head * 0.5, d.head_d * 0.53, d.head_w * 0.52, -0.01, 0.0], [d.head * 0.56, d.head_d * 0.53, d.head_w * 0.52, -0.01, 0.0]], 8, Palette.INK[2], false, false, PI / 8)
			&"mask":
				var k := r.kit(r.find(&"head"), &"salvage")
				Sculpt.loft(k, [
					[-0.01, d.head_d * 0.36, d.head_w * 0.36, d.head_d * 0.1, 0.0],
					[d.head * 0.34, d.head_d * 0.54, d.head_w * 0.52, d.head_d * 0.02, 0.0],
				], 6, Palette.SLATE[2], false, false, 0.0, 0.05, w.seed_value + 61, 0.6, 0.0)
				var can := r.kit(r.find(&"head"), &"salvage", SkinRig.FOUND)
				var cz: float = side * (d.head_w * 0.5 + 0.03)
				Sculpt.loft(can, [[d.head * 0.02, 0.035, 0.035, d.head_d * 0.2, cz], [d.head * 0.3, 0.035, 0.035, d.head_d * 0.2, cz]], 6, Palette.FOUND[2], true, true, 0.0)


## A chamfered rectangle outline, w by h, centred at (0, y_mid): exact, symmetric.
static func _chamfered(w: float, h: float, c: float, y_mid: float) -> PackedVector2Array:
	var x := w * 0.5
	var y0 := y_mid - h * 0.5
	var y1 := y_mid + h * 0.5
	return PackedVector2Array([
		Vector2(-x + c, y0), Vector2(x - c, y0), Vector2(x, y0 + c), Vector2(x, y1 - c),
		Vector2(x - c, y1), Vector2(-x + c, y1), Vector2(-x, y1 - c), Vector2(-x, y0 + c),
	])


## A long hexagon: a plate with its corners cut at top and bottom.
static func _hexplate(w: float, h: float, c: float, y_mid: float) -> PackedVector2Array:
	var x := w * 0.5
	return PackedVector2Array([
		Vector2(0, y_mid - h * 0.5), Vector2(x, y_mid - h * 0.5 + c), Vector2(x, y_mid + h * 0.5 - c),
		Vector2(0, y_mid + h * 0.5), Vector2(-x, y_mid + h * 0.5 - c), Vector2(-x, y_mid - h * 0.5 + c),
	])


static func _octagon(r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 8:
		var a := PI / 8 + i * TAU / 8
		out.append(Vector2(cos(a), sin(a)) * r)
	return out
