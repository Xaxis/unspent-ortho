class_name PersonBody
## Builds a person's skeleton (proportioned by build) and dresses it (clothes,
## hair, salvage) as parts bound to the bones they move with.
##
## Local frame: the person faces +X, up is +Y, their right hand is +Z.
## A limb hangs along -Y from its joint; +Z rotation swings it forward.
##
## Proportions (art-audio-extract §4): chunky, ~4.6 heads tall, legs carry the
## height, arms hang outside the torso. The base man is 1.34 units tall.

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
	var sh_z: float = d.chest * 0.5 + d.arm_t * 0.5 + 0.005
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


## Dress a fresh rig with a normalized look. Geometry only; call rig.attach/rebuild after.
static func dress(r: SkinRig, look: Dictionary) -> void:
	var d := dims(look.build)
	var seed_value := hash(PersonLook.signature(look) + str(look.get("hair", "")) + str(look.get("shirt", "")))
	var skin := PersonLook.skin_values(look)
	var hair := PersonLook.hair_values(look)
	var shirt := PersonLook.colour(look.shirt)
	var shirt_hi := PersonLook.step(look.shirt, 1)
	var coat_c := PersonLook.colour(look.coat_col)
	var coat_hi := PersonLook.step(look.coat_col, 1)
	var coat_lo := PersonLook.step(look.coat_col, -1)
	var trouser := PersonLook.colour(look.trouser)
	var trouser_hi := PersonLook.step(look.trouser, 1)
	var boot := PersonLook.colour(look.boot)
	var boot_hi := PersonLook.step(look.boot, 1)
	var coat: StringName = look.coat
	var long_coat := coat == &"long" or coat == &"oilskin"
	var extras: Array = look.extras
	var sleeve := coat_c if long_coat else shirt
	var sleeve_hi := coat_hi if long_coat else shirt_hi
	var rolled := extras.has(&"rolled") and not long_coat

	# --- legs and boots ---
	for side: int in [-1, 1]:
		var sfx := "_l" if side < 0 else "_r"
		var th := r.kit(r.find(StringName("thigh" + sfx)))
		th.block(0, -d.thigh - 0.02, 0, d.thigh_t, d.thigh + 0.04, d.thigh_t, trouser, trouser_hi)
		var sh := r.kit(r.find(StringName("shin" + sfx)))
		sh.block(0.005, -d.shin, 0, d.shin_t, d.shin + 0.01, d.shin_t, trouser)
		sh.block(0.005, -d.shin, 0, d.shin_t + 0.02, 0.07, d.shin_t + 0.02, boot, boot_hi)
		var ft := r.kit(r.find(StringName("foot" + sfx)))
		ft.block(0.045, -d.boot, 0, 0.235, d.boot, 0.135, boot, boot_hi)
		ft.block(0.05, -d.boot, 0, 0.245, 0.025, 0.145, Palette.INK[2])

	# --- hips: trousers seat, belt ---
	var hk := r.kit(r.find(&"hips"))
	hk.block(0, -0.12, 0, d.depth * 0.94, 0.26, lerpf(d.hip, d.chest, 0.4), trouser, trouser_hi)
	var cut: StringName = look.shirt_cut
	if cut == &"tucked" and not long_coat:
		hk.block(0, 0.1, 0, d.depth * 0.96 + 0.012, 0.05, lerpf(d.hip, d.chest, 0.5) + 0.012, Palette.EARTH[1])
		if extras.has(&"buckle"):
			hk.block(d.depth * 0.48 + 0.008, 0.1, 0, 0.02, 0.05, 0.05, Palette.COPPER[3])
	elif cut == &"loose" and not long_coat:
		hk.block(0, -0.05, 0, d.depth * 0.98 + 0.02, 0.14, lerpf(d.hip, d.chest, 0.6) + 0.02, shirt)

	# --- torso ---
	var tk := r.kit(r.find(&"spine"))
	var waist_w := lerpf(d.hip, d.chest, 0.55)
	var top_h: float = d.torso - 0.04
	var torso_c := coat_c if long_coat else shirt
	var torso_hi := coat_hi if long_coat else shirt_hi
	var pad := 0.02 if long_coat else 0.0
	tk.block(0, 0.04, 0, d.depth + pad, top_h * 0.5, waist_w + pad, torso_c)
	tk.block(0, top_h * 0.45 - 0.04, 0, d.depth * 1.04 + pad, top_h * 0.55, d.chest + pad, torso_c, torso_hi)
	if d.belly > 0.0:
		tk.block(d.depth * 0.5 + d.belly * 0.4, -0.02, 0, d.belly, top_h * 0.42, waist_w * 0.8, torso_c, torso_hi)
	# The neck, in shade: the head reads as sitting on the shoulders, not floating.
	tk.block(0, top_h - 0.01, 0, 0.1, 0.05, 0.11, skin[0])
	match coat:
		&"jerkin":
			tk.block(-0.01, -0.02, 0, d.depth + 0.035, top_h * 0.96, d.chest + 0.035, coat_c, coat_hi)
			tk.block(d.depth * 0.5 + 0.02, 0.0, 0, 0.012, top_h * 0.8, d.chest * 0.18, shirt)
			hk.block(0, -0.04, 0, d.depth + 0.05, 0.1, d.hip + 0.05, coat_c)
		&"long", &"oilskin":
			var collar := coat_hi if coat == &"oilskin" else coat_lo
			tk.block(-0.02, top_h - 0.06, 0, d.depth * 0.9, 0.09, d.chest * 0.72, collar, coat_hi)
			tk.block(d.depth * 0.5 + 0.012, 0.02, 0.0, 0.012, top_h * 0.72, 0.022, coat_lo)
			if coat == &"oilskin":
				for i in 3:
					tk.block(d.depth * 0.5 + 0.02, 0.06 + i * 0.1, d.chest * 0.12, 0.01, 0.025, 0.025, Palette.COPPER[2])
	if extras.has(&"shawl"):
		var shawl := PersonLook.colour(look.hat_col)
		tk.block(-0.02, top_h - 0.12, 0, d.depth + 0.06, 0.12, d.chest + 0.07, shawl, PersonLook.step(look.hat_col, 1))
		tk.block(-d.depth * 0.5 - 0.02, top_h * 0.35, 0, 0.03, top_h * 0.55, d.chest * 0.5, shawl)
	if extras.has(&"neckerchief"):
		tk.block(d.depth * 0.3, top_h - 0.05, 0, 0.1, 0.07, 0.14, Palette.RUST[3], Palette.RUST[4])
	if extras.has(&"apron"):
		tk.block(d.depth * 0.5 + 0.012, top_h * 0.25, 0, 0.012, top_h * 0.55, d.chest * 0.45, Palette.LINEN[3])
	if extras.has(&"satchel"):
		# A strap from the right shoulder to a bag on the left hip: everyone's kit is on them.
		var run: float = sqrt(pow(top_h * 0.9, 2) + pow(d.chest * 0.75, 2))
		var tilt: float = atan2(d.chest * 0.75, top_h * 0.9)
		for fx: float in [d.depth * 0.52 + 0.008, -d.depth * 0.52 - 0.008]:
			tk.push(Transform3D(Basis(Vector3.RIGHT, tilt), Vector3(fx, top_h * 0.5, 0)))
			tk.block(0, -run * 0.5, 0, 0.016, run, 0.05, Palette.EARTH[1])
			tk.pop()
		hk.block(0.02, -0.16, -(d.hip * 0.5 + 0.05), 0.2, 0.17, 0.08, Palette.EARTH[2], Palette.EARTH[3])
		hk.block(0.02, -0.03, -(d.hip * 0.5 + 0.05), 0.21, 0.04, 0.09, Palette.EARTH[3])

	# --- skirts on the hem bone: coats, smocks, aprons swing on their own ---
	var hem := r.kit(r.find(&"hem"))
	var hem_len := 0.0
	var hem_c := coat_c
	if coat == &"long":
		hem_len = d.thigh + d.shin * 0.35
	elif coat == &"oilskin":
		hem_len = d.thigh + d.shin * 0.6
	elif cut == &"smock":
		hem_len = d.thigh * 0.62
		hem_c = shirt
	if hem_len > 0.0:
		var hw: float = maxf(d.hip, waist_w) + 0.07
		var hd: float = d.depth + 0.1
		var y0 := -hem_len
		var dark := PersonLook.step(look.coat_col if hem_c == coat_c else look.shirt, -1)
		# Back panel, two side panels, two front flaps with a gap: legs swing through the front.
		hem.block(-hd * 0.5 + 0.02, y0, 0, 0.04, hem_len + 0.04, hw, hem_c)
		for side: int in [-1, 1]:
			hem.block(0, y0 + 0.02, side * (hw * 0.5 - 0.02), hd, hem_len + 0.02, 0.04, hem_c)
			hem.block(hd * 0.5 - 0.02, y0 + 0.04, side * hw * 0.3, 0.04, hem_len, hw * 0.36, hem_c)
		hem.block(0, y0, 0, hd + 0.01, 0.03, hw + 0.01, dark)
	if extras.has(&"apron"):
		var ap_len: float = d.thigh * 0.9
		hem.block(d.depth * 0.5 + 0.06, -ap_len, 0, 0.02, ap_len + 0.05, d.hip * 0.8, Palette.LINEN[3], Palette.LINEN[4])

	# --- arms ---
	for side: int in [-1, 1]:
		var sfx := "_l" if side < 0 else "_r"
		var ak := r.kit(r.find(StringName("arm" + sfx)))
		ak.block(0, -d.upper - 0.01, 0, d.arm_t, d.upper + 0.05, d.arm_t, sleeve, sleeve_hi)
		if coat == &"jerkin":
			ak.block(0, -0.06, 0, d.arm_t + 0.02, 0.09, d.arm_t + 0.02, coat_c, coat_hi)
		var fk := r.kit(r.find(StringName("fore" + sfx)))
		if rolled:
			fk.block(0, -d.fore, 0, d.arm_t * 0.86, d.fore, d.arm_t * 0.86, skin[1])
			fk.block(0, -0.05, 0, d.arm_t + 0.012, 0.055, d.arm_t + 0.012, shirt_hi)
		else:
			fk.block(0, -d.fore, 0, d.arm_t * 0.94, d.fore + 0.01, d.arm_t * 0.94, sleeve)
			fk.block(0, -d.fore, 0, d.arm_t + 0.006, 0.035, d.arm_t + 0.006, PersonLook.step(look.coat_col if long_coat else look.shirt, -1))
		var hd_k := r.kit(r.find(StringName("hand" + sfx)))
		hd_k.block(0.005, -d.hand, 0, d.hand * 1.05, d.hand + 0.01, d.arm_t * 0.82, skin[1], skin[2])

	# --- head ---
	_head(r, d, look, skin, hair, seed_value)

	# --- salvage ---
	_salvage(r, d, look)

	# Food (hidden at rest by bone scale; shown while eating).
	var food := r.kit(r.find(&"food"), &"food")
	food.block(0.02, -0.03, 0, 0.09, 0.06, 0.07, Palette.LINEN[4], Palette.EARTH[4])


static func _head(r: SkinRig, d: Dictionary, look: Dictionary, skin: Array[Color], hair: Array[Color], seed_value: int) -> void:
	var k := r.kit(r.find(&"head"))
	var hh: float = d.head
	var hw: float = d.head_w
	var hd: float = d.head_d
	var style: StringName = look.hair_style
	var hat: StringName = look.hat
	# Jaw set forward, a full-width face, a crown that steps in: from this pitch
	# the crown is as big on screen as the face, so it must not be a box.
	k.block(0.018, 0.0, 0, hd * 0.86, hh * 0.36, hw * 0.84, skin[1])
	k.block(-0.004, hh * 0.3, 0, hd, hh * 0.5, hw, skin[1], skin[2])
	k.block(-0.012, hh * 0.78, 0, hd * 0.82, hh * 0.2, hw * 0.82, skin[1], skin[2])
	# Eyes, set wide enough to survive as two pixels; a nose one step lighter.
	for side: int in [-1, 1]:
		k.block(hd * 0.5, hh * 0.48, side * hw * 0.22, 0.02, hh * 0.13, hw * 0.13, Palette.INK[1])
		k.block(-hd * 0.08, hh * 0.38, side * (hw * 0.5 + 0.01), 0.06, 0.08, 0.025, skin[0])
	k.block(hd * 0.5 + 0.02, hh * 0.26, 0, 0.05, hh * 0.2, hw * 0.16, skin[2], skin[2])
	# Mouth line in shade, unless a beard or mask covers it.
	if look.beard == &"none" and not (look.salvage as Array).has(&"mask"):
		k.block(hd * 0.43 + 0.012, hh * 0.12, 0, 0.012, 0.022, hw * 0.3, skin[0])

	var h0 := hair[0]
	var h1 := hair[1]
	var covered := hat == &"scarf" or hat == &"knit" or hat == &"souwester"
	# The hair layer: a cap over the stepped crown, a back panel over the face tier.
	var cap_w := hw * 0.86 + 0.03
	var cap_d := hd * 0.86 + 0.03
	var back_d := hd * 0.5
	match style:
		&"crop":
			if not covered:
				k.block(-0.014, hh * 0.76, 0, cap_d, hh * 0.27, cap_w, h0, h1)
				k.block(hd * 0.44, hh * 0.7, 0, 0.05, hh * 0.1, hw * 0.7, h0)
			k.block(-hd * 0.5 + back_d * 0.5 - 0.014, hh * 0.3, 0, back_d, hh * 0.5, hw + 0.028, h0)
		&"long":
			if not covered:
				k.block(-0.014, hh * 0.76, 0, cap_d, hh * 0.28, cap_w + 0.01, h0, h1)
				k.block(hd * 0.43, hh * 0.68, 0, 0.06, hh * 0.13, hw * 0.8, h0)
			k.block(-hd * 0.5 + back_d * 0.5 - 0.016, -hh * 0.5, 0, back_d, hh * 1.3, hw + 0.035, h0)
			for side: int in [-1, 1]:
				k.block(-hd * 0.1, -hh * 0.2, side * (hw * 0.5 + 0.018), hd * 0.55, hh * 1.0, 0.036, h0)
		&"tail":
			if not covered:
				k.block(-0.014, hh * 0.76, 0, cap_d, hh * 0.26, cap_w, h0, h1)
			k.block(-hd * 0.5 + back_d * 0.5 - 0.014, hh * 0.36, 0, back_d, hh * 0.44, hw + 0.028, h0)
			k.block(-hd * 0.5 - 0.035, -hh * 0.55, 0, 0.065, hh * 1.05, 0.075, h0, h1)
			k.block(-hd * 0.5 - 0.03, hh * 0.42, 0, 0.075, 0.045, 0.09, Palette.EARTH[1])
		&"bun":
			if not covered:
				k.block(-0.012, hh * 0.8, 0, cap_d - 0.01, hh * 0.22, cap_w - 0.01, h0, h1)
			k.block(-hd * 0.5 + back_d * 0.5 - 0.012, hh * 0.38, 0, back_d, hh * 0.44, hw + 0.022, h0)
			k.block(-hd * 0.5 - 0.04, hh * 0.62, 0, 0.13, 0.13, 0.15, h0, h1)
		&"thin":
			k.block(-hd * 0.36, hh * 0.3, 0, hd * 0.34, hh * 0.3, hw + 0.025, h0)
			if not covered:
				k.block(0.0, hh * 0.975, -hw * 0.1, hd * 0.44, 0.025, hw * 0.34, h1)
		&"bald":
			k.block(-hd * 0.4, hh * 0.3, 0, hd * 0.24, hh * 0.2, hw + 0.02, h0)
		&"unkempt":
			if not covered:
				k.block(-0.014, hh * 0.76, 0, cap_d + 0.01, hh * 0.3, cap_w + 0.01, h0, h1)
				for i in 4:
					var jx := (Rng.hash01(seed_value, i, 1) - 0.6) * hd * 0.7
					var jz := (Rng.hash01(seed_value, i, 2) - 0.5) * hw * 0.8
					k.block(jx, hh * 1.0, jz, 0.07, 0.04 + Rng.hash01(seed_value, i, 3) * 0.05, 0.07, h1 if i % 2 else h0)
			k.block(-hd * 0.22, hh * 0.05, 0, hd * 0.62, hh * 0.8, hw + 0.05, h0)
			k.block(-hd * 0.5 - 0.02, -hh * 0.22, hw * 0.15, 0.05, hh * 0.42, hw * 0.5, h0)

	match look.beard:
		&"chin":
			k.block(hd * 0.42, -hh * 0.14, 0, 0.09, hh * 0.3, hw * 0.4, h0, h1)
		&"full":
			k.block(hd * 0.1, -hh * 0.16, 0, hd * 0.85, hh * 0.46, hw * 1.04, h0, h1)
			k.block(hd * 0.52, hh * 0.18, 0, 0.03, 0.03, hw * 0.46, h1)
		&"stache":
			k.block(hd * 0.52, hh * 0.15, 0, 0.035, 0.035, hw * 0.52, h0, h1)

	var hc := PersonLook.colour(look.hat_col)
	var hc_hi := PersonLook.step(look.hat_col, 1)
	var hc_lo := PersonLook.step(look.hat_col, -1)
	match hat:
		&"band":
			# A tall felt crown: the silhouette is height.
			k.block(-0.005, hh * 0.76, 0, hd * 1.02, hh * 0.52, hw * 1.02, hc, hc_hi)
			k.block(-0.005, hh * 0.76, 0, hd * 1.06, hh * 0.12, hw * 1.06, hc_lo)
			k.block(-0.005, hh * 0.74, 0, hd * 1.28, 0.025, hw * 1.28, hc_lo)
		&"brim":
			k.prism(-0.01, hh * 0.76, 0, hw * 0.98, hh * 0.76 + 0.03, hw * 0.98, 8, hc_lo, hc, PI / 8.0)
			k.block(-0.01, hh * 0.78, 0, hd * 0.84, hh * 0.36, hw * 0.84, hc, hc_hi)
			k.block(-0.01, hh * 0.79, 0, hd * 0.86, 0.04, hw * 0.86, hc_lo)
		&"cap":
			k.block(-0.005, hh * 0.74, 0, hd * 1.1, hh * 0.28, hw * 1.08, hc, hc_hi)
			k.block(hd * 0.58, hh * 0.74, 0, 0.14, 0.03, hw * 0.8, hc_lo, hc)
		&"knit":
			k.block(-0.01, hh * 0.64, 0, hd * 1.08, hh * 0.14, hw * 1.08, hc_lo, hc)
			k.block(-0.02, hh * 0.76, 0, hd * 1.0, hh * 0.3, hw * 1.0, hc, hc_hi)
			k.prism(-0.04, hh * 1.05, 0, hw * 0.42, hh * 1.26, 0.0, 4, hc, hc_hi, PI / 4.0)
		&"scarf":
			k.block(-0.02, hh * 0.3, 0, hd * 1.02, hh * 0.8, hw * 1.08, hc, hc_hi)
			k.block(-hd * 0.5 - 0.02, -hh * 0.3, 0, 0.05, hh * 0.7, hw * 0.5, hc)
			k.block(-hd * 0.5 - 0.05, -hh * 0.05, 0, 0.07, 0.07, 0.1, hc_lo)
		&"souwester":
			k.block(-0.02, hh * 0.72, 0, hd * 1.02, hh * 0.36, hw * 1.02, hc, hc_hi)
			k.block(-0.06, hh * 0.7, 0, hd * 1.42, 0.03, hw * 1.34, hc_lo, hc)
			k.block(-hd * 0.62, hh * 0.28, 0, 0.04, hh * 0.44, hw * 1.2, hc_lo)


static func _salvage(r: SkinRig, d: Dictionary, look: Dictionary) -> void:
	var side: int = look.side
	var sfx := "_r" if side > 0 else "_l"
	for part: StringName in look.salvage:
		match part:
			&"plate":
				# A slab of machine plate tied over one shoulder, off the same line as the roofs.
				var k := r.kit(r.find(StringName("arm" + sfx)), &"salvage")
				k.block(0, -0.14, side * 0.015, d.arm_t + 0.07, 0.2, d.arm_t + 0.05, Palette.PLATE[2], Palette.PLATE[3])
				k.block(d.arm_t * 0.5 + 0.035, -0.07, side * 0.015, 0.012, 0.025, 0.025, Palette.PLATE[4])
				k.block(d.arm_t * 0.5 + 0.035, -0.12, side * 0.015, 0.012, 0.025, 0.025, Palette.PLATE[4])
				var s := r.kit(r.find(&"spine"), &"salvage")
				s.block(0, d.torso * 0.62, 0, d.depth + 0.02, 0.03, d.chest * 0.9, Palette.EARTH[1])
			&"brace":
				var sh := r.kit(r.find(StringName("shin" + sfx)), &"salvage")
				var z: float = side * (d.shin_t * 0.5 + 0.018)
				sh.block(0, -d.shin * 0.9, z, 0.04, d.shin * 0.92, 0.03, Palette.STONE[3], Palette.STONE[4])
				sh.block(0, -0.03, z + side * 0.01, 0.06, 0.05, 0.04, Palette.COPPER[2], Palette.COPPER[3])
				sh.block(0, -d.shin * 0.55, 0, d.shin_t + 0.035, 0.03, d.shin_t + 0.035, Palette.INK[2])
				var th := r.kit(r.find(StringName("thigh" + sfx)), &"salvage")
				th.block(0, -d.thigh, side * (d.thigh_t * 0.5 + 0.018), 0.04, d.thigh * 0.7, 0.03, Palette.STONE[3], Palette.STONE[4])
			&"rig":
				var k := r.kit(r.find(&"spine"), &"salvage")
				var fx: float = d.depth * 0.5 + 0.015 + d.belly
				for zz: float in [-0.25, 0.25]:
					k.block(fx - d.belly, 0.0, zz * d.chest, 0.02, d.torso * 0.9, 0.035, Palette.INK[3])
				k.block(fx - d.belly * 0.5, d.torso * 0.36, 0, 0.02, 0.035, d.chest * 0.95, Palette.INK[3])
				k.block(fx - d.belly * 0.5 + 0.01, d.torso * 0.34, 0, 0.02, 0.06, 0.06, Palette.COPPER[3])
				k.block(-d.depth * 0.5 - 0.03, d.torso * 0.2, 0, 0.06, d.torso * 0.45, d.chest * 0.55, Palette.SLATE[2], Palette.SLATE[3])
			&"gauntlet":
				var k := r.kit(r.find(StringName("fore" + sfx)), &"salvage")
				for i in 3:
					k.block(0, -d.fore * (0.3 + i * 0.27), 0, d.arm_t + 0.04, 0.045, d.arm_t + 0.04, Palette.SLATE[2] if i % 2 else Palette.STONE[3], Palette.STONE[4])
				k.block(-d.arm_t * 0.5 - 0.025, -d.fore * 0.95, 0, 0.02, d.fore * 0.8, 0.02, Palette.COPPER[2])
			&"tally":
				var k := r.kit(r.find(&"tally"), &"salvage")
				for i in 3:
					var x := -0.08 + i * 0.08
					k.block(x, -0.14 - (i % 2) * 0.03, side * 0.01, 0.06, 0.1, 0.018, Palette.PLATE[2], Palette.PLATE[3])
				k.block(0, -0.03, 0, 0.22, 0.02, 0.02, Palette.INK[3])
			&"aerial":
				var base := r.kit(r.find(&"aerial"), &"salvage")
				base.block(0, -0.03, 0, 0.07, 0.06, 0.07, Palette.COPPER[2], Palette.COPPER[3])
				base.block(0, 0.0, 0, 0.022, 0.31, 0.022, Palette.STONE[3])
				var tip := r.kit(r.find(&"aerial_tip"), &"salvage")
				tip.block(0, 0.0, 0, 0.016, 0.26, 0.016, Palette.STONE[4])
				var live := r.kit(r.find(&"aerial_tip"), &"salvage_glow", true)
				live.block(0, 0.25, 0, 0.04, 0.04, 0.04, Palette.EMBER[4], Palette.EMBER[5])
			&"lens":
				var k := r.kit(r.find(&"head"), &"salvage")
				var ez: float = side * d.head_w * 0.22
				k.block(d.head_d * 0.5 + 0.02, d.head * 0.4, ez, 0.05, d.head * 0.3, d.head_w * 0.3, Palette.INK[1])
				k.block(d.head_d * 0.5 + 0.045, d.head * 0.47, ez, 0.01, d.head * 0.14, d.head_w * 0.14, Palette.BRINE[4])
				k.block(-0.005, d.head * 0.52, 0, d.head_d + 0.03, 0.025, d.head_w + 0.03, Palette.INK[2])
			&"mask":
				var k := r.kit(r.find(&"head"), &"salvage")
				k.block(d.head_d * 0.36, -0.01, 0, d.head_d * 0.34, d.head * 0.34, d.head_w * 0.92, Palette.SLATE[2], Palette.SLATE[3])
				k.prism(d.head_d * 0.25, d.head * 0.02, side * (d.head_w * 0.5 + 0.035), 0.04, d.head * 0.3, 0.04, 6, Palette.STONE[3], Palette.COPPER[3])
