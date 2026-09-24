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
## Drawn per docs/LOOK.md: every part is a lofted solid (Sculpt), 6-8 sided and
## tapered, a little uneven because a hand made it; nothing is a box. Clothing
## replaces the layer under it instead of stacking shells, which is what keeps
## the heaviest look inside 800 triangles. Machine salvage goes on the FOUND
## surface (exact, unhatched) and the straps that tie it on stay MADE.

## Length of each of the aerial's two segments.
const AERIAL := 0.4

## Sides round each part. Set for the figure seen over the shoulder at four to
## eight metres, where it is the largest thing in the frame and its silhouette
## is read against the sky: under ten sides a skull or a back reads as a box
## with its corners taken off, which is the voxel look docs/LOOK.md forbids.
## The limbs stay leaner because they are narrower on screen. Every number that
## places something ON a surface (torso_x, face_x) reads these, not a literal.
const SKULL_N := 12
const TORSO_N := 12
const HIPS_N := 10
const ARM_N := 7
const LEG_N := 8
const SHIN_N := 7
const HAT_N := 11

const BONES: Array[StringName] = [
	&"root", &"hips", &"spine", &"head",
	&"arm_l", &"fore_l", &"hand_l", &"arm_r", &"fore_r", &"hand_r", &"tool", &"food",
	&"thigh_l", &"shin_l", &"foot_l", &"thigh_r", &"shin_r", &"foot_r",
	&"hem", &"aerial", &"aerial_tip", &"tally",
]


## How hunger thins a body, per `gaunt` step: [chest, hip, girth, limb, stoop +, cheek].
## Width goes first and the limbs with it; height never changes, so the rig's
## lengths and every pose stay the build's own.
const GAUNT := [
	[1.0, 1.0, 1.0, 1.0, 0.0, 1.0],
	[0.93, 0.94, 0.88, 0.86, 0.03, 0.94],
	[0.86, 0.88, 0.78, 0.74, 0.07, 0.88],
]


## Every size a builder or animator needs, in units, for a build (and how gaunt).
static func dims(build: StringName, gaunt: int = 0) -> Dictionary:
	var s := PersonLook.shape(build)
	var g: Array = GAUNT[clampi(gaunt, 0, 2)]
	if gaunt > 0:
		s = s.duplicate()
		s.chest = float(s.chest) * float(g[0])
		s.hip = float(s.hip) * float(g[1])
		s.girth = float(s.girth) * float(g[2])
		s.limb = float(s.limb) * float(g[3])
		s.stoop = float(s.stoop) + float(g[4])
		s.belly = 0.0
	var leg: float = s.leg
	var d := {}
	d.gaunt = clampi(gaunt, 0, 2)
	d.cheek = float(g[5])
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
	d.waist = lerpf(d.hip, d.chest, 0.5) * float(s.get("waist", 1.0))
	d.seat = float(s.get("seat", 1.0))
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


static func make_rig(build: StringName, gaunt: int = 0) -> SkinRig:
	var d := dims(build, gaunt)
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
	r.bone(&"aerial_tip", aer, Vector3(0, AERIAL, 0))
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
	## Coat that covers the torso and sleeves (long, oilskin, fur).
	var long_coat := false
	## How far the outer layer stands off the body (a fur coat is bulky).
	var pad := 0.0
	var extras: Array = []
	var salvage: Array = []
	var gear: Array = []


## The resolved Wear for a normalized look (PersonGear and tests read it).
static func wear_of(look: Dictionary) -> Wear:
	return _wear(look)


static func _wear(look: Dictionary) -> Wear:
	var w := Wear.new()
	w.look = look
	w.d = dims(look.build, int(look.get("gaunt", 0)))
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
	w.long_coat = look.coat == &"long" or look.coat == &"oilskin" or look.coat == &"fur"
	w.pad = 0.03 if look.coat == &"fur" else (0.012 if w.long_coat else 0.0)
	w.extras = look.extras
	w.salvage = look.salvage
	w.gear = look.get("gear", [])
	return w


## The torso's section at height `y` on the spine bone: Vector3(rx, rz, cx) of
## the outer layer, following the rings _torso() lofts.
static func torso_ring(w: Wear, y: float) -> Vector3:
	var d := w.d
	var top: float = d.torso - 0.04
	var hd: float = d.depth
	var belly: float = d.belly
	var rows: Array = [
		[0.0, hd * 0.5, d.waist * 0.5, 0.0],
		[top * 0.42, hd * 0.52 + belly * 0.6, lerpf(d.waist, d.chest, 0.65) * 0.5, belly * 0.7],
		[top * 0.8, hd * 0.56, d.chest * 0.5, 0.008],
		[top, hd * 0.44, d.chest * 0.45, -0.006],
	]
	var a: Array = rows[0]
	var b: Array = rows[rows.size() - 1]
	var t := 0.0
	if y <= float(a[0]):
		b = a
	elif y >= float(b[0]):
		a = b
	else:
		for i in rows.size() - 1:
			if y >= float(rows[i][0]) and y <= float(rows[i + 1][0]):
				a = rows[i]
				b = rows[i + 1]
				t = (y - float(a[0])) / maxf(1e-5, float(b[0]) - float(a[0]))
	return Vector3(lerpf(a[1], b[1], t) + w.pad, lerpf(a[2], b[2], t) + w.pad, lerpf(a[3], b[3], t))


## How far forward (or back) of the spine the outer layer's flat face is at `y`.
static func torso_x(w: Wear, y: float, back: bool = false) -> float:
	var ring := torso_ring(w, y)
	# A flat face front and back: the face is cos(PI / TORSO_N) of the radius.
	var face := cos(PI / TORSO_N)
	return ring.z - ring.x * face if back else ring.z + ring.x * face


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
	_patches(r, w)
	PersonGear.build(r, w)
	# Food (hidden at rest by bone scale; shown while eating): a heel of bread.
	var food := r.kit(r.find(&"food"), &"food")
	Sculpt.loft(food, [[-0.035, 0.03, 0.03, 0.02, 0.0], [0.0, 0.06, 0.045, 0.02, 0.0], [0.04, 0.035, 0.03, 0.02, 0.0]], 3, [Palette.SAND[3], Palette.SAND[4]], false, true, 0.3, 0.12, 11)


## A triangle seen from both sides: pelt ends, rag strips.
static func flap(k: MeshKit, a: Vector3, b: Vector3, c: Vector3, col: Color, back: Color) -> void:
	k.tri(a, b, c, col)
	k.tri(a, c, b, back)


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
		# Trousers bag over the knee: the lower ring folds, the seat ring does not.
		Sculpt.loft(th, [[0.02, t0 * 0.95, t0, 0.0, 0.0], [-float(d.thigh) * 0.5, t0 * 0.9, t0 * 0.92, 0.006, 0.0, 0.025], [-float(d.thigh), t1 * 1.08, t1 * 1.02, 0.006, 0.0, 0.045]], LEG_N, w.trouser, false, false, PI / LEG_N, 0.04, s)
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
		], SHIN_N, [w.trouser, w.boot], true, false, PI / SHIN_N, 0.04, s + 3)
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
		[0.165, 0.036, bw * 0.84, sole + 0.036, 0.0],
		[0.2, 0.02, bw * 0.56, sole + 0.024, 0.0],
	], 7, [w.boot, w.boot_hi, w.boot_hi], true, true, 0.0, 0.04, seed_value)
	k.pop()


# ---------------------------------------------------------------- hips and torso

static func _hips(r: SkinRig, w: Wear) -> void:
	var d := w.d
	var k := r.kit(r.find(&"hips"))
	var hd: float = d.depth
	var hz: float = d.hip
	var cz: float = d.waist
	var seat: float = d.seat
	var cut: StringName = w.look.shirt_cut
	var belt := Palette.EARTH[1]
	var top := w.trouser
	if not w.long_coat and w.look.coat != &"jerkin":
		top = belt if cut == &"tucked" else w.shirt
	# The seat is the widest ring, below the hip joint and over the tops of the
	# thighs; the woman's stands out past them.
	Sculpt.loft(k, [
		[-0.17, hd * 0.36, hz * 0.4, -0.01, 0.0],
		[-0.07, hd * 0.5 * lerpf(1.0, seat, 0.5), hz * 0.52 * seat, -0.014 * seat, 0.0],
		[0.03, hd * 0.5, lerpf(hz * 0.52 * seat, cz * 0.5, 0.7), -0.004, 0.0],
		[0.11, hd * 0.49, cz * 0.49, 0.0, 0.0],
	], HIPS_N, [w.trouser, w.trouser, top], false, false, PI / HIPS_N, 0.03, w.seed_value + 1)
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
		&"fur":
			length = d.thigh + d.shin * 0.3
			flare = 0.13
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
		# The second ring sits just under the seat so a flared seat never shows through.
		var y2 := -minf(maxf(length * 0.45, 0.08), length * 0.8)
		var over := maxf(hz * 0.56, hz * 0.52 * seat + 0.016)
		# A skirt hangs in folds that deepen toward the hem.
		var rings: Array = [
			[0.08, hd * 0.53, cz * 0.53, 0.0, 0.0],
			[y2, hd * 0.55 * lerpf(1.0, seat, 0.5) + flare * 0.5, over + flare * 0.45, -flare * 0.2, 0.0, 0.03],
			[y1, hd * 0.55 * lerpf(1.0, seat, 0.5) + flare * 1.04, over + flare * 1.04, -flare * 0.48, 0.0, 0.07],
		]
		var fur: bool = w.look.coat == &"fur"
		if length > d.thigh * 0.5:
			# Long skirts part at the front so the legs stride through them.
			Sculpt.skirt(hem, rings, 8, col, lo, 0.8, PI, 0.16 if fur else 0.05, w.seed_value + 2)
		else:
			Sculpt.loft(hem, rings, 9, [col, lo], false, false, PI / 9, 0.05, w.seed_value + 2)
		if fur:
			# A ragged hem of pelt ends hanging past the skirt's edge.
			var trim := PersonLook.step(w.look.coat_col, 2)
			var rx: float = rings[2][1]
			var rz: float = rings[2][2]
			var cx: float = rings[2][3]
			for i in 7:
				var a := PI * 0.3 + (i + 0.5) / 7.0 * PI * 1.4
				var da := PI * 1.4 / 7.0 * 0.45
				var drop := 0.05 + Rng.hash01(w.seed_value, i, 85) * 0.05
				var e0 := Vector3(cx + cos(a - da) * rx, y1 + 0.01, sin(a - da) * rz)
				var e1 := Vector3(cx + cos(a + da) * rx, y1 + 0.01, sin(a + da) * rz)
				var tip := Vector3(cx + cos(a) * rx * 1.04, y1 - drop, sin(a) * rz * 1.04)
				flap(hem, e0, tip, e1, trim if i % 2 else w.coat_lo, w.coat_lo)
	if w.look.coat == &"wrap":
		# A rope sash over the wrap's ends, and strips of the same cloth hanging
		# from it: no hem, just what was left of the length.
		Sculpt.loft(k, [[0.06, hd * 0.53, cz * 0.53 + 0.004, 0.0, 0.0], [0.11, hd * 0.52, cz * 0.52 + 0.004, 0.0, 0.0]], 6, Palette.SAND[3], false, false, PI / 6, 0.05, w.seed_value + 3)
		for i in 5:
			var a := PI * 0.55 + i / 4.0 * PI * 0.9 + (Rng.hash01(w.seed_value, i, 86) - 0.5) * 0.3
			var half := 0.035 + Rng.hash01(w.seed_value, i, 87) * 0.02
			var drop: float = d.thigh * (0.38 + Rng.hash01(w.seed_value, i, 88) * 0.3)
			var o := Vector3(cos(a) * (hd * 0.56 + 0.012), 0.08, sin(a) * (cz * 0.56 + 0.012))
			var side := Vector3(-sin(a), 0, cos(a)) * half
			var out := Vector3(cos(a), 0, sin(a))
			var sway := out * (0.02 + drop * 0.12)
			var c := w.coat if i % 2 == 0 else w.coat_lo
			hem.quad(o - side, o + side, o + side + Vector3(0, -drop, 0) + sway, o - side * 0.6 + Vector3(0, -drop * 0.9, 0) + sway, c)
			hem.quad(o - side * 0.6 + Vector3(0, -drop * 0.9, 0) + sway, o + side + Vector3(0, -drop, 0) + sway, o + side, o - side, w.coat_lo)
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
	var waist: float = d.waist
	var belly: float = d.belly
	var coat: StringName = w.look.coat
	var body := w.coat if w.long_coat else w.shirt
	var body_hi := w.coat_hi if w.long_coat else w.shirt_hi
	var pad := w.pad
	# The cloth gathers at the waist and hangs slack over the belly; the chest
	# ring is taut. The shoulder ring between the chest and the neck is what
	# makes a shoulder a slope that rolls into the arm, not a shelf.
	Sculpt.loft(k, [
		[0.0, hd * 0.5 + pad, waist * 0.5 + pad, 0.0, 0.0, 0.03],
		[top * 0.42, hd * 0.52 + belly * 0.6 + pad, lerpf(waist, d.chest, 0.65) * 0.5 + pad, belly * 0.7, 0.0, 0.018],
		[top * 0.8, hd * 0.56 + pad, d.chest * 0.5 + pad, 0.008, 0.0],
		[top, hd * 0.46 + pad, d.chest * 0.46 + pad, -0.008, 0.0],
		[top + 0.026, hd * 0.34 + pad * 0.6, d.chest * 0.33 + pad * 0.6, -0.012, 0.0],
		[top + 0.045, 0.075, 0.085, -0.012, 0.0],
	], TORSO_N, [body, body, body, body_hi, body_hi], false, true, PI / TORSO_N, 0.03, w.seed_value + 4)
	# Neck: in shade, so the head reads as sitting on the shoulders, not floating.
	if coat != &"oilskin" and coat != &"fur" and not w.extras.has(&"neckerchief"):
		_skin(k, true)
		Sculpt.loft(k, [[top + 0.02, 0.05, 0.055, -0.01, 0.0], [top + 0.1, 0.048, 0.052, -0.004, 0.0]], 8, w.skin[0], false, false, PI / 8)
		_skin(k, false)
	var front := hd * 0.56 * 0.924 + pad
	match coat:
		&"jerkin":
			# A sleeveless leather jerkin, open down the front over the shirt.
			Sculpt.loft(k, [
				[-0.05, hd * 0.56, waist * 0.56, 0.0, 0.0],
				[top * 0.8, hd * 0.6, d.chest * 0.54, 0.008, 0.0],
				[top + 0.01, hd * 0.47, d.chest * 0.49, -0.006, 0.0],
			], 6, [w.coat, w.coat_hi], false, false, 0.0, 0.05, w.seed_value + 5, 0.82, PI)
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
		&"fur":
			# A shaggy collar of pelts turned up round the neck: the outline of a
			# person dressed in whatever died.
			var trim := PersonLook.step(w.look.coat_col, 2)
			var ring_x := hd * 0.47 + pad
			var ring_z: float = d.chest * 0.46 + pad
			var n := 9
			for i in n:
				var a := float(i) / n * TAU + Rng.hash01(w.seed_value, i, 81) * 0.3
				var a2 := a + TAU / n * 1.1
				var base_y := top - 0.03
				var p0 := Vector3(cos(a) * ring_x, base_y, sin(a) * ring_z)
				var p1 := Vector3(cos(a2) * ring_x, base_y, sin(a2) * ring_z)
				var am := (a + a2) * 0.5
				var reach := 1.3 + Rng.hash01(w.seed_value, i, 82) * 0.25
				var tip := Vector3(cos(am) * ring_x * reach, top + 0.05 + Rng.hash01(w.seed_value, i, 83) * 0.04, sin(am) * ring_z * reach)
				flap(k, p0, tip, p1, trim if i % 2 == 0 else w.coat_hi, w.coat_lo)
		&"wrap":
			# Cloth bound round and round over the shirt against heat and ash: bands
			# laid on the slant, each crossing the last.
			var tilts: Array[float] = [0.42, -0.36, 0.3]
			var heights: Array[float] = [top * 0.28, top * 0.56, top * 0.82]
			for i in 3:
				var ring := torso_ring(w, heights[i])
				var t := tilts[i] + (Rng.hash01(w.seed_value, i, 84) - 0.5) * 0.12
				var rz := ring.y / cos(t) + 0.014
				k.push(Transform3D(Basis(Vector3(1, 0, 0), t), Vector3(0, heights[i], 0)))
				Sculpt.loft(k, [[-0.036, ring.x + 0.016, rz, ring.z, 0.0], [0.036, ring.x + 0.014, rz - 0.004, ring.z, 0.0]], 7, w.coat if i % 2 == 0 else w.coat_hi, false, false, PI / 7, 0.06, w.seed_value + 90 + i)
				k.pop()


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
		# The shoulder is a dome that rolls into the torso's shoulder ring, not
		# the capped end of a tube standing beside it.
		Sculpt.loft(ak, [
			[t * 0.46, t * 0.14, t * 0.16, -0.004, -side * t * 0.12],
			[t * 0.34, t * 0.4, t * 0.42, 0.0, -side * t * 0.06],
			[0.0, t * 0.56, t * 0.56, 0.0, 0.0],
			[-float(d.upper) - 0.01, t * 0.44, t * 0.46, 0.006, 0.0, 0.04],
		], ARM_N, [shoulder, sleeve], true, false, PI / ARM_N, 0.04, s)
		if coat == &"fur":
			# Pelt sleeves: bulkier, the cuff turned back in the trim.
			Sculpt.loft(ak, [[-float(d.upper) * 0.2, t * 0.62, t * 0.64, 0.0, 0.0], [-float(d.upper) * 0.8, t * 0.56, t * 0.58, 0.004, 0.0]], ARM_N, w.coat_lo, false, false, PI / ARM_N, 0.12, s + 5)
		var fk := r.kit(r.find(StringName("fore" + sfx)))
		var fl: float = d.fore
		if coat == &"wrap":
			for i in 2:
				var by := -fl * (0.25 + i * 0.42)
				Sculpt.loft(fk, [[by - 0.028, t * 0.5, t * 0.52, 0.0, 0.0], [by + 0.028, t * 0.5, t * 0.52, 0.004, 0.0]], ARM_N, w.coat if i == 0 else w.coat_hi, false, false, PI / ARM_N, 0.08, s + 6 + i)
		elif coat == &"fur":
			Sculpt.loft(fk, [[-fl * 0.82, t * 0.52, t * 0.54, 0.008, 0.0], [-fl * 0.66, t * 0.54, t * 0.56, 0.006, 0.0]], ARM_N, PersonLook.step(w.look.coat_col, 2), false, false, PI / ARM_N, 0.14, s + 6)
		if rolled:
			_skin(fk, true)
			Sculpt.loft(fk, [
				[0.01, t * 0.5, t * 0.5, 0.0, 0.0],
				[-0.045, t * 0.5, t * 0.5, 0.0, 0.0],
				[-fl, t * 0.33, t * 0.37, 0.008, 0.0],
			], ARM_N, [w.shirt_hi, w.skin[1]], true, false, PI / ARM_N, 0.04, s + 1)
			_skin(fk, false)
		else:
			Sculpt.loft(fk, [
				[0.01, t * 0.46, t * 0.46, 0.0, 0.0],
				[-fl * 0.85, t * 0.43, t * 0.45, 0.007, 0.0, 0.05],
				[-fl, t * 0.4, t * 0.42, 0.008, 0.0],
			], ARM_N, [sleeve], true, false, PI / ARM_N, 0.04, s + 1)
		_hand(r.kit(r.find(StringName("hand" + sfx))), d, w, side, s + 2)


## A chunky mitten, big enough to read as a hand at 640x360: palm wider than the
## wrist, blunt fingers, a thumb toward the front.
static func _hand(k: MeshKit, d: Dictionary, w: Wear, side: int, seed_value: int) -> void:
	var h: float = d.hand * 1.2
	if w.extras.has(&"mitts"):
		_mitt(k, h * 1.12, side, seed_value)
		return
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


## Corded mitts: the same blunt hand a size up in dark leather, no skin showing,
## and cord wound at the wrist, which is what says they were made here.
static func _mitt(k: MeshKit, h: float, side: int, seed_value: int) -> void:
	var leather: Array[Color] = [Palette.EARTH[1], Palette.EARTH[2]]
	Sculpt.loft(k, [
		[0.02, 0.034, 0.034, 0.0, 0.0],
		[-h * 0.48, h * 0.42, h * 0.28, 0.01, 0.0],
		[-h * 1.0, h * 0.31, h * 0.21, 0.004, 0.0],
	], 5, leather, false, true, 0.0, 0.05, seed_value)
	var tz := -side * h * 0.12
	k.tri(Vector3(h * 0.3, -h * 0.18, tz), Vector3(h * 0.52, -h * 0.5, tz), Vector3(h * 0.26, -h * 0.5, tz - side * 0.02), leather[1])
	Sculpt.loft(k, [[0.02, 0.037, 0.037, 0.0, 0.0], [-0.012, 0.039, 0.039, 0.0, 0.0]], 4, PersonGear.CORD, false, false, PI / 4, 0.05, seed_value + 3)


# ---------------------------------------------------------------- head

## Eye height as a fraction of the head: set low, so a brim seen from the
## camera's 57 degrees still leaves an eye and the nose showing under it.
const EYE_Y := 0.42


## How far forward the skull's surface is at height fraction `yf` and sideways
## offset `z` (units): the skull has an edge down the nose (phase 0), so the
## face turns away either side of it and is never one flat square.
static func face_x(d: Dictionary, yf: float, z: float) -> float:
	var hd: float = d.head_d
	var hw: float = d.head_w
	var rows: Array = _skull_rows(d, false)
	var rx := 0.0
	var rz := 0.0
	var cx := 0.0
	for i in rows.size() - 1:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		var ya: float = a[0] / float(d.head)
		var yb: float = b[0] / float(d.head)
		if yf >= ya and yf <= yb:
			var t := (yf - ya) / maxf(1e-5, yb - ya)
			rx = lerpf(a[1], b[1], t)
			rz = lerpf(a[2], b[2], t)
			cx = lerpf(a[3], b[3], t)
	# Walk the skull's facets out from the nose edge to the one `z` lies on.
	var az := absf(z)
	var step := TAU / SKULL_N
	for f in SKULL_N / 4:
		var z0 := rz * sin(step * f)
		var z1 := rz * sin(step * (f + 1))
		if az <= z1 or f == SKULL_N / 4 - 1:
			var u := clampf((az - z0) / maxf(1e-5, z1 - z0), 0.0, 1.0)
			return cx + rx * lerpf(cos(step * f), cos(step * (f + 1)), u)
	return cx + rx


## The skull as loft rows [y, rx, rz, cx, cz]: a tapered jaw, full cheeks, and a
## crown that rounds over (only drawn to the hatband when a hat hides it).
static func _skull_rows(d: Dictionary, hatted: bool) -> Array:
	var hh: float = d.head
	var hw: float = d.head_w
	var hd: float = d.head_d
	# Hunger hollows the cheeks first.
	var cheek: float = d.get("cheek", 1.0)
	var rows: Array = [
		[0.0, hd * 0.24, hw * 0.2 * cheek, hd * 0.2, 0.0],
		[hh * 0.2, hd * 0.44, hw * 0.37 * cheek * cheek, hd * 0.12, 0.0],
		[hh * 0.46, hd * 0.54, hw * 0.5 * cheek, hd * 0.03, 0.0],
		[hh * 0.72, hd * 0.53, hw * 0.49, -0.006, 0.0],
	]
	if not hatted:
		rows.append([hh * 0.9, hd * 0.43, hw * 0.41, -0.02, 0.0])
		rows.append([hh * 1.0, hd * 0.2, hw * 0.19, -0.026, 0.0])
	return rows


static func _head(r: SkinRig, w: Wear) -> void:
	var d := w.d
	var k := r.kit(r.find(&"head"))
	var hh: float = d.head
	var hw: float = d.head_w
	var hd: float = d.head_d
	var hat: StringName = w.look.hat
	_skin(k, true)
	# Under a hat or a full head of hair the crown is never seen: stop at the hatband.
	var style: StringName = w.look.hair_style
	var rows := _skull_rows(d, hat != &"none" or (style != &"bald" and style != &"thin"))
	var cols: Array = [w.skin[1], w.skin[1], w.skin[1], w.skin[2], w.skin[2]]
	Sculpt.loft(k, rows, SKULL_N, cols, false, true, 0.0, 0.025, w.seed_value + 9)
	# Eyes: two dark marks either side of the nose edge, low and forward.
	var ey := hh * EYE_Y
	for side: int in [-1, 1]:
		var z0 := side * hw * 0.13
		var z1 := side * hw * 0.25
		var x0 := face_x(d, EYE_Y, z0) + 0.004
		var x1 := face_x(d, EYE_Y, z1) + 0.004
		Sculpt.card(k, Vector3(x0, ey - 0.024, z0), Vector3(x1, ey - 0.024, z1), Vector3(x1, ey + 0.032, z1), Vector3(x0, ey + 0.032, z0), Palette.INK[2], Vector3(1, 0, side * 0.4))
	# Nose: a wedge off the face edge, pointing forward and down.
	var nx := face_x(d, 0.5, 0.0)
	var nb := Vector3(nx - 0.006, hh * 0.54, 0)
	var nt := Vector3(nx + 0.052, hh * 0.31, 0)
	var nl := Vector3(nx - 0.004, hh * 0.28, 0.034)
	var nr := Vector3(nx - 0.004, hh * 0.28, -0.034)
	k.tri(nb, nl, nt, w.skin[2])
	k.tri(nb, nt, nr, w.skin[2])
	k.tri(nl, nr, nt, w.skin[0])
	# Ears.
	for side: int in [-1, 1]:
		var ez := side * (hw * 0.5 + 0.012)
		var e := [Vector3(-0.01, hh * 0.3, ez), Vector3(-0.05, hh * 0.58, ez), Vector3(0.025, hh * 0.56, ez)]
		if side > 0:
			k.tri(e[0], e[2], e[1], w.skin[0])
		else:
			k.tri(e[0], e[1], e[2], w.skin[0])
	_skin(k, false)
	_hair(k, w, hat)
	_beard(k, w)
	_hat(k, w, hat)


## The hair layer: a domed, uneven cap tilted back so the hairline is high at the
## brow and low at the nape, with a ragged fringe; styles add to it. Under a hat
## only what shows below the brim is drawn.
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
	var pivot := Vector3(0, hh * 0.64, 0)
	if not covered and style != &"bald" and style != &"thin":
		var wob := 0.16 if style == &"unkempt" else 0.08
		var lift := 0.03 if style == &"unkempt" else 0.014
		var tilt := Basis(Vector3(0, 0, 1), 0.4)
		k.push(Transform3D(tilt, pivot))
		# The top sits off-centre by the seed, so no two crowns dome alike.
		var tx := (Rng.hash01(s, 1) - 0.5) * 0.03
		var tz := (Rng.hash01(s, 2) - 0.5) * 0.03
		Sculpt.loft(k, [
			[0.0, hd * 0.56, hw * 0.54, -0.02, 0.0],
			[hh * 0.2, hd * 0.55 + lift, hw * 0.53 + lift, -0.022, 0.0],
			[hh * 0.36 + lift, hd * 0.42 + lift, hw * 0.43 + lift, -0.03 + tx * 0.5, tz * 0.5],
			[hh * 0.46 + lift * 1.5, hd * 0.16, hw * 0.16, -0.04 + tx, tz],
		], SKULL_N, [h0, h1, h1], false, true, 0.0, wob, s)
		k.pop()
		# A ragged fringe flush with the forehead: locks of uneven width and length
		# hanging from the hairline, so the brow edge is never one straight cut.
		var edge := 0.8
		var zs: Array[float] = [-0.4, -0.12, 0.1, 0.4]
		for i in 3:
			var za := zs[i] * hw + (Rng.hash01(s, i, 5) - 0.5) * hw * 0.06
			var zb := zs[i + 1] * hw
			var zm := lerpf(za, zb, 0.35 + Rng.hash01(s, i, 4) * 0.3)
			var drop := 0.04 + Rng.hash01(s, i, 3) * (0.12 if style == &"unkempt" else 0.06)
			var ya := edge - absf(za) / hw * 0.22
			var yb := edge - absf(zb) / hw * 0.22
			var ym := minf(ya, yb) - drop
			var a := Vector3(face_x(d, ya, za) + 0.012, hh * ya + 0.012, za)
			var b := Vector3(face_x(d, yb, zb) + 0.012, hh * yb + 0.012, zb)
			var m := Vector3(face_x(d, ym, zm) + 0.01, hh * ym, zm)
			if (m - a).cross(b - a).dot(Vector3(1, 0.3, 0)) > 0.0:
				k.tri(a, m, b, h1)
			else:
				k.tri(a, b, m, h1)
	# The nape and the back of the head: shows under any hat.
	var back_lo := hh * 0.3
	if style == &"bald" or style == &"thin":
		back_lo = hh * 0.36
	if style != &"bald" or not covered:
		# Seen from behind this is the whole head, so it rounds under the skull
		# into the neck and wraps to behind the ears instead of ending in one
		# straight cut across the nape.
		var nape_top := hh * (0.62 if style == &"bald" else 0.76)
		Sculpt.loft(k, [
			[back_lo - hh * 0.06, hd * 0.44, hw * 0.4, -0.006, 0.0],
			[back_lo + hh * 0.08, hd * 0.535, hw * 0.5, -0.012, 0.0],
			[nape_top, hd * 0.555, hw * 0.515, -0.014, 0.0],
		], 8, h0, false, false, 0.0, 0.06, s + 1, 0.52, PI)
	match style:
		&"long":
			Sculpt.loft(k, [
				[-hh * 0.55, hd * 0.44, hw * 0.52, -0.05, 0.0],
				[hh * 0.62, hd * 0.57, hw * 0.55, -0.02, 0.0],
			], 9, h0, false, false, 0.0, 0.1, s + 2, 0.6, PI)
		&"tail":
			k.push(Transform3D(Basis(Vector3(0, 0, 1), -0.12), Vector3(-hd * 0.5, hh * 0.5, 0)))
			Sculpt.loft(k, [[0.02, 0.035, 0.04, 0.0, 0.0], [-hh * 0.95, 0.018, 0.02, 0.0, 0.0]], 4, [h0], true, false, 0.0, 0.1, s + 3)
			k.pop()
		&"bun":
			Sculpt.loft(k, [
				[hh * 0.62, 0.035, 0.04, -hd * 0.58, 0.0],
				[hh * 0.76, 0.07, 0.075, -hd * 0.66, 0.0],
				[hh * 0.9, 0.035, 0.04, -hd * 0.64, 0.0],
			], 4, [h0, h1], true, true, PI / 4, 0.1, s + 4)
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
				k.quad(Vector3(-hd * 0.2, hh * 1.0, -hw * 0.12), Vector3(-hd * 0.2, hh * 1.0, hw * 0.1), Vector3(hd * 0.06, hh * 1.0, hw * 0.08), Vector3(hd * 0.06, hh * 1.0, -hw * 0.1), h1)


static func _beard(k: MeshKit, w: Wear) -> void:
	var d := w.d
	var hh: float = d.head
	var hw: float = d.head_w
	var hd: float = d.head_d
	var h0 := w.hair[0]
	var h1 := w.hair[1]
	match w.look.beard:
		&"chin":
			Sculpt.loft(k, [[hh * 0.2, 0.03, hw * 0.16, hd * 0.44, 0.0], [-hh * 0.14, 0.01, 0.02, hd * 0.46, 0.0]], 4, h0, false, true, PI / 4)
		&"full":
			Sculpt.loft(k, [
				[-hh * 0.14, hd * 0.24, hw * 0.22, hd * 0.24, 0.0],
				[hh * 0.14, hd * 0.5, hw * 0.44, hd * 0.12, 0.0],
				[hh * 0.4, hd * 0.57, hw * 0.52, hd * 0.03, 0.0],
			], 5, [h0, h1], false, false, 0.0, 0.1, w.seed_value + 23, 0.62, 0.0)
		&"stache":
			var x := face_x(d, 0.26, 0.0) + 0.02
			Sculpt.card(k, Vector3(x, hh * 0.2, -hw * 0.22), Vector3(x, hh * 0.2, hw * 0.22), Vector3(x + 0.004, hh * 0.28, hw * 0.14), Vector3(x + 0.004, hh * 0.28, -hw * 0.14), h1, Vector3.RIGHT)
			k.quad(Vector3(x - 0.03, hh * 0.28, -hw * 0.14), Vector3(x - 0.03, hh * 0.28, hw * 0.14), Vector3(x + 0.004, hh * 0.28, hw * 0.14), Vector3(x + 0.004, hh * 0.28, -hw * 0.14), h0)


## Hats change the silhouette first; colour is second. Every brim is cut short
## and turned up at the front and every crown leans back, so from the camera's
## pitch a hat still says which way the face under it points.
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
			# A tall felt crown, pinched at the front, with a dark band: height is the silhouette.
			Sculpt.loft(k, [
				[hh * 0.64, rx * 1.02, rz * 1.02, -0.014, 0.0],
				[hh * 0.8, rx * 0.98, rz * 0.98, -0.02, 0.0],
				[hh * 1.3, rx * 0.8, rz * 0.62, -0.05, 0.0],
			], HAT_N, [lo, c], false, true, 0.0, 0.04, s)
			_brim(k, hh * 0.64, rx * 1.02, rz * 1.02, rx * 1.5, rz * 1.42, -0.012, lo, c, s + 1, 0.0, 0.07, 0.72)
		&"brim":
			# A wide felt brim pinned up at the front, drooping behind.
			Sculpt.loft(k, [[hh * 0.7, rx * 0.98, rz * 0.98, -0.014, 0.0], [hh * 1.12, rx * 0.78, rz * 0.7, -0.04, 0.0]], HAT_N, c, false, true, 0.0, 0.05, s)
			_brim(k, hh * 0.72, rx * 0.98, rz * 0.98, rx * 1.9, rz * 1.8, -0.05, lo, c, s + 1, -0.03, 0.14, 0.7)
		&"cap":
			# Pushed back on the head, the peak short and cocked up.
			Sculpt.loft(k, [[hh * 0.68, rx * 1.02, rz * 1.02, -0.02, 0.0], [hh * 0.98, rx * 0.92, rz * 0.9, -0.03, 0.0], [hh * 1.08, rx * 0.5, rz * 0.5, -0.045, 0.0]], HAT_N, [c, hi], false, true, 0.0, 0.04, s)
			var vy := hh * 0.74
			var vx := rx * 0.98 - 0.02
			var tip := Vector3(vx + 0.075, vy + 0.045, 0)
			k.quad(Vector3(vx, vy, -hw * 0.36), Vector3(vx, vy, hw * 0.36), tip + Vector3(0, 0, hw * 0.24), tip + Vector3(0, 0, -hw * 0.24), c)
			k.quad(tip + Vector3(0, -0.006, -hw * 0.24), tip + Vector3(0, -0.006, hw * 0.24), Vector3(vx, vy - 0.006, hw * 0.36), Vector3(vx, vy - 0.006, -hw * 0.36), lo)
		&"knit":
			Sculpt.loft(k, [
				[hh * 0.6, rx * 1.05, rz * 1.05, -0.014, 0.0],
				[hh * 0.76, rx * 1.05, rz * 1.05, -0.018, 0.0],
				[hh * 1.02, rx * 0.8, rz * 0.8, -0.04, 0.0],
				[hh * 1.2, rx * 0.12, rz * 0.12, -0.08, 0.0],
			], HAT_N, [lo, c, hi], false, true, 0.0, 0.06, s)
		&"scarf":
			# Wrapped over the head and knotted at the nape, tails hanging.
			Sculpt.loft(k, [
				[hh * 0.22, rx * 1.04, rz * 1.04, -0.01, 0.0],
				[hh * 0.74, rx * 1.03, rz * 1.03, -0.015, 0.0],
			], 8, c, false, false, 0.0, 0.05, s, 0.7, PI)
			Sculpt.loft(k, [
				[hh * 0.7, rx * 1.03, rz * 1.03, -0.015, 0.0],
				[hh * 0.94, rx * 0.86, rz * 0.9, -0.025, 0.0],
				[hh * 1.08, rx * 0.4, rz * 0.44, -0.04, 0.0],
			], HAT_N, [c, hi], false, true, 0.0, 0.05, s + 3)
			Sculpt.loft(k, [[hh * 0.3, 0.045, 0.06, -hd * 0.58, 0.0], [-hh * 0.4, 0.02, 0.07, -hd * 0.66, 0.03]], 4, lo, true, true, PI / 4, 0.12, s + 2)
		&"hood":
			# A cloth hood pulled up: open round the face, a slack peak falling back.
			# The lower part is open at the front; the crown is closed, so the
			# camera's pitch never looks into it.
			Sculpt.skirt(k, [
				[hh * 0.08, rx * 1.16, rz * 1.14, -0.02, 0.0],
				[hh * 0.74, rx * 1.1, rz * 1.1, -0.02, 0.0],
			], 9, c, lo, 0.74, PI, 0.06, s)
			Sculpt.loft(k, [
				[hh * 0.72, rx * 1.1, rz * 1.1, -0.02, 0.0],
				[hh * 1.02, rx * 0.98, rz * 0.98, -0.04, 0.0],
				[hh * 1.18, rx * 0.5, rz * 0.52, -0.1, 0.0],
			], HAT_N, [c, hi], false, false, 0.0, 0.07, s + 3)
			# The slack point sags down the back of the head.
			var ring: Array[Vector3] = []
			for i in HAT_N:
				var a := float(i) / HAT_N * TAU
				ring.append(Vector3(-0.1 + cos(a) * rx * 0.5, hh * 1.18, sin(a) * rz * 0.52))
			var point := Vector3(-hd * 0.95, hh * 0.9, 0.0)
			for i in HAT_N:
				k.tri(ring[(i + 1) % HAT_N], ring[i], point, lo if i % 2 else c)
		&"furhat":
			# A pelt crown with a rolled brim and flaps down over the ears.
			Sculpt.loft(k, [
				[hh * 0.6, rx * 1.14, rz * 1.14, -0.015, 0.0],
				[hh * 0.76, rx * 1.22, rz * 1.22, -0.02, 0.0],
				[hh * 0.86, rx * 1.04, rz * 1.04, -0.022, 0.0],
				[hh * 1.16, rx * 0.9, rz * 0.88, -0.04, 0.0],
			], HAT_N, [PersonLook.step(w.look.hat_col, 2), c, c], false, true, 0.0, 0.12, s)
			# Shag, so it never reads as a helmet: many short tufts lying flat off the
			# crown's edge and hanging off the rolled brim. Short and flat, the
			# outline goes ragged all round instead of rising into two points.
			var trim := PersonLook.step(w.look.hat_col, 1)
			for i in 9:
				var a := float(i) / 9.0 * TAU + Rng.hash01(s, i, 7) * 0.4
				var out := Vector3(cos(a), 0, sin(a))
				var base := Vector3(-0.04 + cos(a) * rx * 0.78, hh * 1.15, sin(a) * rz * 0.76)
				var side_v := Vector3(-sin(a), 0, cos(a)) * 0.022
				var tip := Vector3(-0.04 + cos(a) * rx * (0.98 + Rng.hash01(s, i, 8) * 0.1), hh * (1.16 + Rng.hash01(s, i, 9) * 0.04), sin(a) * rz * (0.98 + Rng.hash01(s, i, 8) * 0.1))
				flap(k, base - side_v, tip, base + side_v, trim if i % 2 else hi, lo)
				var b2 := Vector3(-0.02 + cos(a) * rx * 1.18, hh * 0.8, sin(a) * rz * 1.18) + out * 0.004
				var t2 := Vector3(-0.02 + cos(a) * rx * 1.3, hh * (0.68 - Rng.hash01(s, i, 10) * 0.05), sin(a) * rz * 1.3)
				flap(k, b2 - side_v, t2, b2 + side_v, trim if i % 2 == 0 else c, lo)
			for side: int in [-1, 1]:
				var ez := side * (rz * 1.12)
				var a := Vector3(-0.05, hh * 0.64, ez)
				var b := Vector3(0.06, hh * 0.64, ez)
				var cc := Vector3(0.045, hh * 0.22, ez + side * 0.012)
				var dd := Vector3(-0.035, hh * 0.18, ez + side * 0.012)
				Sculpt.card(k, a, b, cc, dd, c, Vector3(0, 0, side))
				Sculpt.card(k, a, b, cc, dd, lo, Vector3(0, 0, -side))
		&"souwester":
			# Brim turned up in front and long and low behind, to shed rain off the collar.
			Sculpt.loft(k, [[hh * 0.64, rx * 1.03, rz * 1.03, -0.014, 0.0], [hh * 1.12, rx * 0.72, rz * 0.72, -0.035, 0.0]], HAT_N, c, false, true, 0.0, 0.04, s)
			_brim(k, hh * 0.66, rx * 1.03, rz * 1.03, rx * 1.6, rz * 1.5, -0.08, lo, c, s + 1, -0.09, 0.13, 0.62)


## A brim: an annulus from the crown ring out to (ox, oz), its edge dropped by
## `droop`, pushed back by `back` so a sou'wester is longer behind. The front is
## turned up by `up` and cut to `front` of its length, falling off round the sides.
static func _brim(k: MeshKit, y: float, ix: float, iz: float, ox: float, oz: float, droop: float, under: Color, top: Color, seed_value: int, back: float = 0.0, up: float = 0.0, front: float = 1.0) -> void:
	var n := HAT_N + 1
	var inner: Array[Vector3] = []
	var outer: Array[Vector3] = []
	for i in n:
		var a := float(i) / n * TAU
		var j := 1.0 + (Rng.hash01(seed_value, i) - 0.5) * 0.1
		inner.append(Vector3(cos(a) * ix - 0.012, y, sin(a) * iz))
		var behind := maxf(0.0, -cos(a))
		var ahead := maxf(0.0, cos(a))
		var reach := lerpf(1.0, front, ahead * ahead)
		var ex := cos(a) * lerpf(ix, ox, reach) * j - 0.012 + back * behind
		var ez := sin(a) * lerpf(iz, oz, lerpf(1.0, front, ahead * ahead * 0.5)) * j
		var ey := y + droop * j * (1.0 - ahead) - absf(back) * behind * 0.6 + up * ahead
		outer.append(Vector3(ex, ey, ez))
	var from := k.vertex_count()
	for i in n:
		var i2 := (i + 1) % n
		k.quad(inner[i2], inner[i], outer[i], outer[i2], under)
		k.quad(inner[i], inner[i2], outer[i2], outer[i], top)
	# Felt bends: welded, a brim is a curve round the head. Its top and its
	# underside face opposite ways, so the crease keeps them apart.
	k.smooth_range(from, k.vertex_count(), 60.0)


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
		], 6, w.hat, false, false, PI / 6, 0.08, w.seed_value + 51, 0.8, PI)
	if w.look.hat == &"hood":
		# The hood's cape, over the shoulders: it stays with the body when the head turns.
		var pad := w.pad
		Sculpt.skirt(tk, [
			[top - 0.13, hd * 0.64 + pad, d.chest * 0.6 + pad, -0.012, 0.0],
			[top + 0.07, hd * 0.44 + pad, d.chest * 0.34 + pad, -0.02, 0.0],
		], 7, w.hat, w.hat_lo, 0.8, PI, 0.08, w.seed_value + 50)
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
		Sculpt.loft(hk, [[-0.18, 0.1, 0.035, 0.03, bz], [-0.02, 0.11, 0.04, 0.03, bz]], 4, [Palette.EARTH[2]], false, true, PI / 4, 0.06, w.seed_value + 53)


# ---------------------------------------------------------------- salvage

## Parts off the machines, tied on. The part is FOUND (exact, unhatched, on the
## found surface); whatever ties it on is MADE. One or two per person.
## Sized for the game camera, not for a close-up: every part is at least 0.08
## units across its narrow side (2 px at the default view height of 14), stands
## clear of the limb it rides on, and is edged one ramp step dark so it reads as a
## plate and not a speck of colour.
static func _salvage(r: SkinRig, w: Wear) -> void:
	var d := w.d
	var side: int = w.look.side
	var sfx := "_r" if side > 0 else "_l"
	var face := Palette.PLATE[4]
	var dim := Palette.PLATE[3]
	var edge := Palette.PLATE[1]
	for part: StringName in w.salvage:
		match part:
			&"plate":
				# A bent pauldron of machine plate over one shoulder, riding up past
				# the shoulder line so the outline itself changes.
				var k := r.kit(r.find(StringName("arm" + sfx)), &"salvage", SkinRig.FOUND)
				var t: float = d.arm_t
				# The top plate rides above the collar line; the side plate hangs just off the sleeve.
				k.push(Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, side), Vector3(0, -side, 0)).rotated(Vector3(1, 0, 0), side * 0.75), Vector3(0, 0.1, side * 0.0)))
				Sculpt.slab(k, PackedVector2Array([Vector2(-0.12, 0.13), Vector2(-0.12, 0.0), Vector2(-0.08, -0.07), Vector2(0.08, -0.07), Vector2(0.12, 0.0), Vector2(0.12, 0.13)]), 0.014, face, edge)
				k.pop()
				k.push(Transform3D(Basis(Vector3(1, 0, 0), side * 0.1), Vector3(0, 0, side * (t * 0.56 + 0.028))))
				Sculpt.slab(k, PackedVector2Array([Vector2(-0.11, 0.07), Vector2(-0.11, -0.07), Vector2(-0.06, -0.14), Vector2(0.06, -0.14), Vector2(0.11, -0.07), Vector2(0.11, 0.07)]), 0.013, dim, edge)
				k.pop()
				var strap := r.kit(r.find(&"spine"), &"salvage")
				var fx: float = d.depth * 0.56 + 0.006
				var sz: float = side * d.chest * 0.44
				Sculpt.card(strap, Vector3(fx, d.torso - 0.05, sz), Vector3(fx, d.torso - 0.1, sz - side * 0.04), Vector3(fx, d.torso * 0.3, -sz * 0.4), Vector3(fx, d.torso * 0.36, -sz * 0.3), Palette.EARTH[1], Vector3.RIGHT)
			&"brace":
				# A machine strut down the outside of one leg, hinged at the knee,
				# standing off the leg so the leg's outline thickens.
				var sz: float = side * (d.shin_t * 0.52 + 0.042)
				var sh := r.kit(r.find(StringName("shin" + sfx)), &"salvage", SkinRig.FOUND)
				sh.push(Transform3D(Basis.IDENTITY, Vector3(0, 0, sz)))
				Sculpt.slab(sh, _hexplate(0.085, d.shin * 0.82, 0.03, -d.shin * 0.46), 0.026, face, Palette.PLATE[2])
				sh.pop()
				sh.push(Transform3D(Basis.IDENTITY, Vector3(0, 0, sz + side * 0.03)))
				Sculpt.slab(sh, _ngon(0.058, 5), 0.012, Palette.FOUND[4], Palette.FOUND[1])
				sh.pop()
				var th := r.kit(r.find(StringName("thigh" + sfx)), &"salvage", SkinRig.FOUND)
				th.push(Transform3D(Basis.IDENTITY, Vector3(0, 0, side * (d.thigh_t * 0.56 + 0.038))))
				var ty: float = -d.thigh * 0.64
				var th_h: float = d.thigh * 0.31
				Sculpt.slab(th, PackedVector2Array([Vector2(-0.04, ty - th_h), Vector2(0.04, ty - th_h), Vector2(0.04, ty + th_h), Vector2(-0.04, ty + th_h)]), 0.024, dim, Palette.PLATE[2])
				th.pop()
				var band := r.kit(r.find(StringName("shin" + sfx)), &"salvage")
				var br: float = d.shin_t * 0.52 + 0.05
				Sculpt.loft(band, [[-d.shin * 0.56, d.shin_t * 0.58, br, 0.0, side * 0.02], [-d.shin * 0.44, d.shin_t * 0.58, br, 0.0, side * 0.02]], 4, Palette.EARTH[1], false, false, PI / 4)
			&"rig":
				# Canvas webbing across the chest (MADE) held by a machine clasp (FOUND).
				var k := r.kit(r.find(&"spine"), &"salvage")
				var top: float = d.torso - 0.04
				var fx: float = d.depth * 0.56 + d.belly * 0.7 + 0.01
				for zz: float in [-0.26, 0.26]:
					Sculpt.card(k, Vector3(fx, 0.0, zz * d.chest - 0.032), Vector3(fx, 0.0, zz * d.chest + 0.032), Vector3(fx - 0.03, top + 0.02, zz * d.chest + 0.032), Vector3(fx - 0.03, top + 0.02, zz * d.chest - 0.032), Palette.INK[3], Vector3.RIGHT)
				Sculpt.card(k, Vector3(fx + 0.002, top * 0.32, -d.chest * 0.46), Vector3(fx + 0.002, top * 0.32, d.chest * 0.46), Vector3(fx + 0.002, top * 0.46, d.chest * 0.46), Vector3(fx + 0.002, top * 0.46, -d.chest * 0.46), Palette.INK[3], Vector3.RIGHT)
				var clasp := r.kit(r.find(&"spine"), &"salvage", SkinRig.FOUND)
				clasp.push(Transform3D(Basis(Vector3(0, 1, 0), -PI * 0.5), Vector3(fx + 0.014, top * 0.39, 0)))
				Sculpt.slab(clasp, _ngon(0.07, 6), 0.012, face, edge)
				clasp.pop()
				var eye := r.kit(r.find(&"spine"), &"salvage_glow", SkinRig.GLOW)
				var ex := fx + 0.028
				Sculpt.card(eye, Vector3(ex, top * 0.39 - 0.024, -0.024), Vector3(ex, top * 0.39 - 0.024, 0.024), Vector3(ex, top * 0.39 + 0.024, 0.024), Vector3(ex, top * 0.39 + 0.024, -0.024), Palette.EMBER[4], Vector3.RIGHT)
			&"gauntlet":
				# A forearm sleeved in ribbed machine conduit, thick as a fist, one live stud still warm.
				var k := r.kit(r.find(StringName("fore" + sfx)), &"salvage", SkinRig.FOUND)
				var t: float = d.arm_t
				Sculpt.loft(k, [
					[-d.fore * 0.06, t * 0.66, t * 0.66, 0.0, 0.0],
					[-d.fore * 0.34, t * 0.8, t * 0.8, 0.0, 0.0],
					[-d.fore * 0.6, t * 0.7, t * 0.7, 0.0, 0.0],
					[-d.fore * 0.9, t * 0.78, t * 0.78, 0.0, 0.0],
				], 5, [face, dim, face], false, false, PI / 5)
				var stud := r.kit(r.find(StringName("fore" + sfx)), &"salvage_glow", SkinRig.GLOW)
				Sculpt.loft(stud, [[-d.fore * 0.56, 0.0, 0.0, 0.0, side * t * 0.8], [-d.fore * 0.46, 0.04, 0.04, 0.0, side * t * 0.88], [-d.fore * 0.36, 0.0, 0.0, 0.0, side * t * 0.8]], 3, Palette.EMBER[4], false, false, 0.0)
			&"tally":
				# Machine tags on a cord at the hip, swinging as the body moves.
				var k := r.kit(r.find(&"tally"), &"salvage", SkinRig.FOUND)
				# Tall tags: the camera's pitch squashes anything hanging to half its height.
				var tag := PackedVector2Array([Vector2(-0.04, -0.21), Vector2(0.04, -0.21), Vector2(0.04, 0.0), Vector2(-0.04, 0.0)])
				for i in 3:
					var x := -0.085 + i * 0.085
					k.push(Transform3D(Basis(Vector3(0, 0, 1), (i - 1) * 0.16), Vector3(x, -0.03 - (i % 2) * 0.05, 0.03)))
					Sculpt.slab(k, tag, 0.01, face if i == 1 else dim, edge)
					k.pop()
				var cord := r.kit(r.find(&"tally"), &"salvage")
				Sculpt.card(cord, Vector3(-0.13, -0.035, 0.03), Vector3(0.13, -0.035, 0.03), Vector3(0.13, -0.01, 0.03), Vector3(-0.13, -0.01, 0.03), Palette.EARTH[1], Vector3(0, 0, 1))
			&"aerial":
				# A long whip off one shoulder with a live tip: breaks the outline.
				var base := r.kit(r.find(&"aerial"), &"salvage", SkinRig.FOUND)
				Sculpt.loft(base, [[-0.05, 0.045, 0.045, 0.0, 0.0], [0.03, 0.04, 0.04, 0.0, 0.0]], 4, dim, false, true, PI / 4)
				Sculpt.loft(base, [[0.03, 0.02, 0.02, 0.0, 0.0], [AERIAL + 0.01, 0.015, 0.015, 0.0, 0.0]], 3, edge, false, false, 0.0)
				var tip := r.kit(r.find(&"aerial_tip"), &"salvage", SkinRig.FOUND)
				Sculpt.loft(tip, [[0.0, 0.015, 0.015, 0.0, 0.0], [AERIAL * 0.9, 0.01, 0.01, 0.0, 0.0]], 3, edge, false, false, 0.0)
				var live := r.kit(r.find(&"aerial_tip"), &"salvage_glow", SkinRig.GLOW)
				Sculpt.loft(live, [[AERIAL * 0.9 - 0.04, 0.0, 0.0, 0.0, 0.0], [AERIAL * 0.9, 0.045, 0.045, 0.0, 0.0], [AERIAL * 0.9 + 0.05, 0.0, 0.0, 0.0, 0.0]], 4, Palette.EMBER[5], false, false, PI / 4)
			&"lens":
				# A dark-rimmed optic over one eye, standing well off the face.
				var k := r.kit(r.find(&"head"), &"salvage", SkinRig.FOUND)
				var ez: float = side * d.head_w * 0.22
				var fx: float = face_x(d, EYE_Y, ez) - 0.01
				var ey: float = d.head * EYE_Y
				# Aimed forward and a little up, so from the camera the lit glass shows in its rim.
				var aim := Basis(Vector3(0, 0, 1), -PI * 0.5 + 0.55)
				k.push(Transform3D(aim, Vector3(fx, ey, ez)))
				Sculpt.loft(k, [[0.0, 0.08, 0.08, 0.0, 0.0], [0.07, 0.074, 0.074, 0.0, 0.0]], 6, Palette.PLATE[2], false, false, 0.0)
				k.pop()
				var glass := r.kit(r.find(&"head"), &"salvage_glow", SkinRig.GLOW)
				glass.push(Transform3D(aim, Vector3(fx, ey, ez) + aim * Vector3(0, 0.072, 0)))
				Sculpt.loft(glass, [[0.0, 0.0, 0.0, 0.0, 0.0], [0.004, 0.064, 0.064, 0.0, 0.0]], 6, Palette.COLD[3], false, false, 0.0)
				glass.pop()
				var band := r.kit(r.find(&"head"), &"salvage")
				Sculpt.loft(band, [[d.head * (EYE_Y - 0.04), d.head_d * 0.56, d.head_w * 0.53, 0.0, 0.0], [d.head * (EYE_Y + 0.08), d.head_d * 0.56, d.head_w * 0.53, -0.004, 0.0]], 7, Palette.INK[2], false, false, 0.0)
			&"breastplate":
				# A machine's panel worn over the chest, laced on with cord over both
				# shoulders; its ruled stencil still says what it was cut from.
				var top: float = d.torso - 0.04
				var y: float = top * 0.56
				var px: float = torso_x(w, y) + 0.016
				var k := r.kit(r.find(&"spine"), &"salvage", SkinRig.FOUND)
				k.push(Transform3D(Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)).rotated(Vector3(0, 0, 1), 0.12), Vector3(px, y, 0.0)))
				var pw: float = d.chest * 0.62
				Sculpt.slab(k, _hexplate(pw, top * 0.62, 0.05, 0.0), 0.012, face, edge)
				Sculpt.slab(k, PackedVector2Array([Vector2(-0.012, -top * 0.26), Vector2(0.012, -top * 0.26), Vector2(0.012, top * 0.26), Vector2(-0.012, top * 0.26)]), 0.018, dim, edge)
				var mark := Palette.FOUND[1]
				Sculpt.card(k, Vector3(-pw * 0.38, top * 0.19, 0.0125), Vector3(-pw * 0.08, top * 0.19, 0.0125), Vector3(-pw * 0.08, top * 0.23, 0.0125), Vector3(-pw * 0.38, top * 0.23, 0.0125), mark, Vector3.BACK)
				k.pop()
				var lace := r.kit(r.find(&"spine"), &"salvage")
				var sx: float = torso_x(w, top) + 0.008
				var bx: float = torso_x(w, top, true) - 0.008
				for sd: int in [-1, 1]:
					var pz: float = sd * pw * 0.42
					Sculpt.card(lace, Vector3(px + 0.004, y + top * 0.28, pz - 0.014), Vector3(px + 0.004, y + top * 0.28, pz + 0.014), Vector3(sx, top + 0.02, sd * d.chest * 0.3 + 0.014), Vector3(sx, top + 0.02, sd * d.chest * 0.3 - 0.014), Palette.SAND[4], Vector3(1, 0.4, 0))
					Sculpt.card(lace, Vector3(sx, top + 0.02, sd * d.chest * 0.3 - 0.014), Vector3(sx, top + 0.02, sd * d.chest * 0.3 + 0.014), Vector3(bx, top * 0.4, sd * d.chest * 0.2 + 0.014), Vector3(bx, top * 0.4, sd * d.chest * 0.2 - 0.014), Palette.SAND[3], Vector3(-1, 0.4, 0))
					# A binding round the plate's edge where the cord knots on.
					Sculpt.card(lace, Vector3(px + 0.02, y - top * 0.05, pz - 0.018), Vector3(px + 0.02, y - top * 0.05, pz + 0.018), Vector3(px + 0.02, y + top * 0.02, pz + 0.018), Vector3(px + 0.02, y + top * 0.02, pz - 0.018), Palette.SAND[4], Vector3.RIGHT)
			&"mask":
				var k := r.kit(r.find(&"head"), &"salvage")
				Sculpt.loft(k, [
					[-0.01, d.head_d * 0.36, d.head_w * 0.34, d.head_d * 0.16, 0.0],
					[d.head * 0.34, d.head_d * 0.56, d.head_w * 0.52, d.head_d * 0.05, 0.0],
				], 6, Palette.SLATE[3], false, false, 0.0, 0.05, w.seed_value + 61, 0.6, 0.0)
				var can := r.kit(r.find(&"head"), &"salvage", SkinRig.FOUND)
				var cz: float = side * (d.head_w * 0.5 + 0.045)
				Sculpt.loft(can, [[-d.head * 0.06, 0.05, 0.05, d.head_d * 0.2, cz], [d.head * 0.34, 0.05, 0.05, d.head_d * 0.2, cz]], 5, face, false, true, 0.0)
				Sculpt.loft(can, [[-d.head * 0.16, 0.0, 0.0, d.head_d * 0.2, cz], [-d.head * 0.06, 0.035, 0.035, d.head_d * 0.2, cz]], 4, edge, false, false, 0.0)


## Patches sewn over the worn places, each a scrap of some other cloth with a
## dark seam round it, set a little crooked. Spots are taken in a seeded order;
## a spot under plate, webbing or wraps is skipped.
static func _patches(r: SkinRig, w: Wear) -> void:
	var n: int = w.look.get("patches", 0)
	if n <= 0:
		return
	var d := w.d
	var top: float = d.torso - 0.04
	var side: int = w.look.side
	var spots: Array = []
	var chest_y := top * 0.58
	var chest_free: bool = w.look.coat != &"wrap" and not w.salvage.has(&"breastplate") and not w.salvage.has(&"rig") and not w.gear.has(&"radio")
	if chest_free:
		spots.append([&"spine", Vector3(torso_x(w, chest_y) + 0.006, chest_y, -side * d.chest * 0.18), Vector3.RIGHT, Vector2(0.055, 0.05)])
	var back_y := top * 0.45
	if not w.gear.has(&"pack") and w.look.coat != &"wrap":
		spots.append([&"spine", Vector3(torso_x(w, back_y, true) - 0.006, back_y, side * d.chest * 0.12), Vector3.LEFT, Vector2(0.06, 0.05)])
	for sd: int in [-side, side]:
		var sfx := "_r" if sd > 0 else "_l"
		# The knee: the front of the thigh just above the joint.
		var ky: float = -d.thigh * 0.8
		var kx: float = lerpf(d.thigh_t * 0.56, d.shin_t * 0.5 * 1.05, 0.8) * 0.97 + 0.008
		if not (w.salvage.has(&"brace") and sd == side):
			spots.append([StringName("thigh" + sfx), Vector3(kx, ky, 0.0), Vector3.RIGHT, Vector2(0.045, 0.05)])
		# The elbow: the outside of the upper sleeve.
		var t: float = d.arm_t
		if not (w.salvage.has(&"plate") and sd == side):
			spots.append([StringName("arm" + sfx), Vector3(0.0, -float(d.upper) * 0.72, sd * (t * 0.48 + 0.01)), Vector3(0, 0, sd), Vector2(0.04, 0.045)])
	if w.long_coat:
		var hy: float = -d.thigh * 0.5
		spots.append([&"hem", Vector3(-(d.depth * 0.55 + 0.05), hy, -side * 0.05), Vector3.LEFT, Vector2(0.06, 0.06)])
	# A seeded order, so two people with the same count wear them in different places.
	var order: Array = []
	for i in spots.size():
		order.append([Rng.hash01(w.seed_value, i, 91), i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for j in mini(n, spots.size()):
		var spot: Array = spots[int(order[j][1])]
		var k := r.kit(r.find(spot[0]))
		var at: Vector3 = spot[1]
		var out: Vector3 = spot[2]
		var half: Vector2 = spot[3]
		var up := Vector3.UP
		var across := up.cross(out).normalized()
		var tilt := (Rng.hash01(w.seed_value, j, 92) - 0.5) * 0.5
		across = across.rotated(out, tilt)
		up = up.rotated(out, tilt)
		var e: Array = PATCH_WEAR[int(Rng.hash01(w.seed_value, j, 93) * PATCH_WEAR.size()) % PATCH_WEAR.size()]
		var col := PersonLook.colour(e)
		var seam := PersonLook.step(e, -1)
		var h0 := half + Vector2(0.01, 0.01)
		Sculpt.card(k, at - across * h0.x - up * h0.y, at + across * h0.x - up * h0.y, at + across * h0.x + up * h0.y, at - across * h0.x + up * h0.y, seam, out)
		var a2 := at + out * 0.003
		Sculpt.card(k, a2 - across * half.x - up * half.y, a2 + across * half.x - up * half.y, a2 + across * half.x + up * half.y * 0.9, a2 - across * half.x * 0.85 + up * half.y, col, out)


## Patch cloth: scraps off other clothes, on the muted middle of the ramps.
const PATCH_WEAR := [["earth", 2], ["rust", 2], ["moss", 2], ["slate", 2], ["sand", 3], ["linen", 2], ["brine", 2], ["stone", 2], ["ash", 2]]


## A long hexagon: a plate with its corners cut at top and bottom.
static func _hexplate(w: float, h: float, c: float, y_mid: float) -> PackedVector2Array:
	var x := w * 0.5
	return PackedVector2Array([
		Vector2(0, y_mid - h * 0.5), Vector2(x, y_mid - h * 0.5 + c), Vector2(x, y_mid + h * 0.5 - c),
		Vector2(0, y_mid + h * 0.5), Vector2(-x, y_mid + h * 0.5 - c), Vector2(-x, y_mid - h * 0.5 + c),
	])


static func _ngon(r: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := PI / n + i * TAU / n
		out.append(Vector2(cos(a), sin(a)) * r)
	return out
