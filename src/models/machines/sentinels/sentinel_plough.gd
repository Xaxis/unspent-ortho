extends MachineModel
## THE PLOUGH: the Snowfield's keeper (src/core/sentinel/designs/plough.gd). The
## plan's power line runs over the snowfield on pylons, and the plough keeps its
## road open: a low, heavy tracked hull under a swept V-share a lane wide, with
## an engine cowl on its back steaming in the cold. Where it has ploughed it
## leaves packed ice; off its furrows it wallows.
##
## Why a WEDGE. Every other keeper is tall. The plough is wide and low and heavy,
## a shape that says it moves snow, not people, and the share's V points where it
## is going: from the front the share IS the machine.
##
## Nothing on it is a box. The hull's armour slopes in to a narrow deck, every
## edge is chamfered, the engine sits in a rounded cowl and the tracks run in
## angled guards: a keeper's body is the warden's near-black indigo, and a stack
## of dark cubes against the snow reads as blocks, which this world never is.
##
## Frost-scarred all over. The share's cutting edge is bright scuffed steel and
## its rime is ice, both on the WORLD's lit material (matter_mesh), so they catch
## the light on the shaded side where the keeper's ramp goes dark: slabs of rime
## along every top edge, long icicles off the hull's lip, frost fans on the flanks,
## ice caked in the angle of the V. The steam off the stack is a white plume.
##
## Poses.
## walk   PLOUGHING: the share down in the snow, the hull rocking on its tracks
## stand  the share lifted clear, idling, the stack breathing slow
## alert  it has you: the share drops and the hull settles onto it
## windup the hull rears back on its rear rollers and the share comes up
## strike the whole mass throws forward, share first, as far as the blow lands
##        (the bite box's front, MachineModel.strike_front): the share is the
##        bite, so its curl stops where the bite does
## hurt   the grille stutters; nothing flinches
## dead   the share digs in and the hull noses down into it, the stack cold

const TRACK_Z := 0.92
const TRACK_TOP := 0.44
const HULL_Y := 0.44
const WHEEL_R := 0.14
## The share: its prow, how far back and out its wings sweep, and how tall.
const PROW_X := 2.05
const WING_X := 0.78
const WING_Z := 1.62
const SHARE_H := 1.02
## The whole body, grown to a keeper's scale: at 1.0 it stood no taller than the
## player at eye level, which is a tractor, not a boss; past 1.2 the hull ran well
## outside the body the fight stands it in (roster radius 1.5), and a player at its
## flank stood inside the drawing.
const SIZE := 1.2
## The strike: the hull's pitch and the share's own shove, and the share's
## front in the hull's frame (the rime along the curl's lip at the prow).
const STRIKE_PITCH := Vector3(0, 0, -0.08)
const STRIKE_SHARE := Vector3(0.1, -0.04, 0)
const SHARE_FRONT := Vector3(PROW_X + 0.42, -HULL_Y + SHARE_H + 0.04, 0)

var _travel := 0.0
var _steam_in := 0.0
var _wheels: Array[Node3D] = []


func build() -> void:
	part_side = &"back"
	height = 2.5
	stride = 2.2
	gallery_turn = 30.0
	emission = 0.26
	begin_rig()
	ramp = Palette.MACHINE["warden"]
	disposition = &"wary"
	var R := ramp
	var D := FoundKit.dirty(R)
	var DD := FoundKit.dirty(R, 2)
	_tracks(D, DD, R)
	var hull := joint(&"hull", self, Vector3(0, HULL_Y, 0))
	_hull(hull, R, D)
	_share(hull, R, D)
	_engine(hull, R, D)
	_head(hull, R)
	finish_rig()
	scale = Vector3.ONE * SIZE


## The ice the world lights: rime and icicles in the world's own material.
static func _ice() -> Array:
	return [Palette.RIME[3], Palette.RIME[4], Palette.RIME[5], Palette.RIME[5], Palette.RIME[5], Palette.RIME[5]]


## Bare steel, scraped bright: the share's cutting edge, lit as the world is.
static func _steel() -> Array:
	return [Palette.SLATE[3], Palette.SLATE[4], Palette.SLATE[5], Palette.SLATE[5], Palette.RIME[5], Palette.RIME[5]]


## Two track units in angled guards: a sloped fender over each, road wheels
## showing under it, frost packed along the run.
func _tracks(D: Array, DD: Array, R: Array) -> void:
	var shape: Array[Vector2] = [Vector2(1.2, 0.26), Vector2(1.0, TRACK_TOP - 0.06), Vector2(-1.08, TRACK_TOP - 0.06),
		Vector2(-1.28, 0.26), Vector2(-1.28, 0.14), Vector2(-1.1, 0.0), Vector2(1.02, 0.0), Vector2(1.2, 0.14)]
	# The guard: sloped down and out over the track, chamfered at both ends.
	var guard: Array[Vector2] = [Vector2(1.3, 0.28), Vector2(1.06, TRACK_TOP + 0.02), Vector2(-1.14, TRACK_TOP + 0.02),
		Vector2(-1.36, 0.28), Vector2(-1.3, 0.24), Vector2(-1.1, TRACK_TOP - 0.04), Vector2(1.02, TRACK_TOP - 0.04), Vector2(1.24, 0.24)]
	for sz: float in [-1.0, 1.0]:
		var tk := FoundKit.kit()
		FoundKit.slab(tk, Vector3(0, 0, sz * TRACK_Z), Vector3.RIGHT, Vector3.UP, shape, 0.4, DD, 0.02)
		FoundKit.slab(tk, Vector3(0, 0.02, sz * (TRACK_Z + 0.05)), Vector3.RIGHT, Vector3(0, 1, sz * 0.45).normalized(), guard, 0.46, D, 0.05)
		FoundKit.rivets(tk, Vector3(-1.0, 0.44, sz * (TRACK_Z + 0.26)), Vector3(1.0, 0.44, sz * (TRACK_Z + 0.26)), Vector3(0, 0.5, sz).normalized(), 8, R[5])
		body_mesh(tk, self)
		var ice := FoundKit.matter_kit(Ink.NONE)
		# Frost packed along the foot of the track and rime along the guard's top.
		for j in 6:
			var x := -1.1 + j * 0.44
			ice.rock(x, 0.07, sz * (TRACK_Z + 0.24), 0.26, 0.09, 500 + j + int(sz) * 10, Palette.RIME[5], 6)
			ice.rock(x + 0.2, TRACK_TOP + 0.06, sz * (TRACK_Z + 0.02), 0.22, 0.06, 520 + j + int(sz) * 10, Palette.RIME[5], 6)
		wear_matter(ice, self)
		for x: float in [-0.8, -0.26, 0.28, 0.82]:
			var w := Node3D.new()
			w.position = Vector3(x, 0.2, sz * (TRACK_Z + 0.21))
			add_child(w)
			var wk := FoundKit.kit()
			FoundKit.disc(wk, Vector3.ZERO, Vector3.BACK, WHEEL_R, 0.05, 8, 0.02, D, D[2], PI / 8.0)
			body_mesh(wk, w)
			_wheels.append(w)


## The hull: armour sloping in from a wide skirt to a narrow deck, every edge
## chamfered; icicles long off its lip and frost fans on its flanks.
func _hull(hull: Node3D, R: Array, D: Array) -> void:
	var k := FoundKit.kit()
	var plan := FoundKit.plan_oct(2.4, 1.9, 0.42)
	# Wide at the skirt, drawn well in at the deck: the slope IS the armour.
	FoundKit.loft(k, [FoundKit.ring(plan, -0.08, 0.1), FoundKit.ring(plan, 0.0, 0.0),
		FoundKit.ring(plan, 0.22, 0.06), FoundKit.ring(plan, 0.5, 0.3), FoundKit.ring(plan, 0.58, 0.42)], R, true)
	FoundKit.seam(k, Vector3(-0.8, 0.581, 0.0), Vector3(0.7, 0.581, 0.0), Vector3.UP, R, 4)
	FoundKit.rivets(k, Vector3(0.9, 0.36, -0.7), Vector3(0.9, 0.36, 0.7), Vector3(1, 0.6, 0).normalized(), 6, R[5])
	body_mesh(k, hull)
	day_wear(hull, Vector3(-0.2, 0.583, -0.2), Vector3.UP, Vector3.RIGHT, 0.5, 0.3, 63, 2)
	var ice := FoundKit.matter_kit(Ink.NONE)
	var cold := _ice()
	for sz: float in [-1.0, 1.0]:
		# Icicles off the skirt's lip, long and uneven: the cold has had it a long time.
		for j in 9:
			var x := -1.0 + j * 0.25
			var len := 0.14 + Rng.hash01(71, j, int(sz)) * 0.32
			FoundKit.lathe(ice, Vector3(x, 0.0, sz * 0.96), Vector3.DOWN, [Vector2(0.045, 0.0), Vector2(0.02, len * 0.6), Vector2(0.0, len)], 5, cold)
		# Rime in slabs along the deck's edge.
		for j in 5:
			ice.rock(-0.9 + j * 0.42, 0.56, sz * 0.62, 0.3, 0.07, 530 + j + int(sz) * 10, Palette.RIME[5], 6)
		# Frost fans on the flank: fern strokes spreading up from the skirt.
		for f in 3:
			var base := Vector3(-0.7 + f * 0.62, 0.08, sz * 0.97)
			var n := Vector3(0, 0.25, sz).normalized()
			for s in 5:
				var a := -0.9 + s * 0.45
				var tip := base + Vector3(sin(a) * 0.22, 0.2 + cos(a) * 0.14, 0)
				# Thin ice bars, not flat marks: a mark is held to a floor in frame
				# pixels and at eye level drew as a fat white rod.
				FoundKit.tbar(ice, base + n * 0.01, tip + n * 0.01, 0.012, 0.006, 3, cold)
	# Snow lying on the deck, where nothing warm reaches it.
	ice.rock(0.55, 0.6, -0.3, 0.4, 0.07, 490, Palette.RIME[5], 6)
	ice.rock(0.62, 0.6, 0.34, 0.34, 0.06, 491, Palette.RIME[5], 6)
	wear_matter(ice, hull)


## The share: two swept plates in a V, prow forward, bigger than the hull is wide,
## curling forward at the top as a mouldboard does. Near-black like the body, with
## a bright scuffed cutting edge and a slab of rime along its top, both lit by the
## world; dents scuffed pale; ice caked in the angle.
func _share(hull: Node3D, R: Array, D: Array) -> void:
	var share := joint(&"share", hull, Vector3(0.0, 0.0, 0.0))
	var k := FoundKit.kit()
	var edge := FoundKit.matter_kit(Ink.NONE)
	var steel := _steel()
	var cold := _ice()
	for sz: float in [-1.0, 1.0]:
		var prow := Vector3(PROW_X, -HULL_Y + 0.02, 0.0)
		var wing := Vector3(WING_X, -HULL_Y + 0.02, sz * WING_Z)
		var along := (wing - prow).normalized()
		var span := prow.distance_to(wing)
		var out := along.cross(Vector3.UP * sz).normalized()
		# Three bands up the face, each leaning further forward: the swept curl.
		var bands := [[0.0, 0.42, 0.18], [0.4, 0.76, 0.34], [0.74, SHARE_H, 0.55]]
		for b: Array in bands:
			var lean: float = b[2]
			var up := Vector3.UP.lerp(-out, lean).normalized()
			var y0: float = b[0]
			var y1: float = b[1]
			var o := prow + Vector3(0, y0, 0) - out * y0 * lean * 0.5
			var poly: Array[Vector2] = [Vector2(0.02, 0.0), Vector2(span - 0.02, 0.0), Vector2(span - 0.1, y1 - y0), Vector2(0.1, y1 - y0)]
			FoundKit.slab(k, o, along, up, poly, 0.07, R, 0.03)
		# Bracing back to the hull, raked.
		FoundKit.tbar(k, prow.lerp(wing, 0.55) + Vector3(-0.15, 0.55, 0), Vector3(0.8, 0.32, sz * 0.55), 0.07, 0.055, 6, D, 0.02)
		# The cutting edge: a strip of bright steel along the foot, proud of the plate.
		var cut: Array[Vector2] = [Vector2(-0.04, -0.02), Vector2(span + 0.04, -0.02), Vector2(span, 0.12), Vector2(0.0, 0.14)]
		FoundKit.slab(edge, prow + out * 0.05, along, Vector3.UP.lerp(-out, 0.18).normalized(), cut, 0.1, steel, 0.02)
		# Rime slabs along the top, heavy, and icicles off the curl.
		var top := prow + Vector3(0, SHARE_H, 0) - out * 0.3
		var top_w := wing + Vector3(0, SHARE_H, 0) - out * 0.3
		for j in 6:
			var at := top.lerp(top_w, (float(j) + 0.5) / 6.0)
			edge.rock(at.x, at.y + 0.04, at.z, 0.26, 0.1, 540 + j + int(sz) * 10, Palette.RIME[5], 6)
		for j in 5:
			var at := top.lerp(top_w, (float(j) + 0.3) / 5.0) - out * 0.06
			var len := 0.12 + Rng.hash01(81, j, int(sz)) * 0.22
			FoundKit.lathe(edge, at, Vector3.DOWN, [Vector2(0.035, 0.0), Vector2(0.015, len * 0.6), Vector2(0.0, len)], 5, cold)
		# Dents, scuffed pale: where it met rock under the drifts.
		for d in 3:
			var at := prow.lerp(wing, 0.25 + d * 0.25) + Vector3(0, 0.3 + d * 0.18, 0) + out * 0.06
			FoundKit.mark(edge, at, out, Vector3.UP, 0.18 - d * 0.03, 0.12, Palette.SLATE[5], 0.004)
	FoundKit.tbar(k, Vector3(PROW_X + 0.04, -HULL_Y + 0.02, 0), Vector3(PROW_X - 0.36, -HULL_Y + SHARE_H + 0.1, 0), 0.08, 0.05, 6, D, 0.02)
	body_mesh(k, share)
	# Ice caked in the angle of the V.
	edge.rock(PROW_X - 0.22, -HULL_Y + 0.16, 0.0, 0.26, 0.18, 480, Palette.RIME[5], 6)
	edge.rock(PROW_X - 0.46, -HULL_Y + 0.1, 0.36, 0.2, 0.14, 481, Palette.RIME[4], 6)
	edge.rock(PROW_X - 0.48, -HULL_Y + 0.1, -0.4, 0.2, 0.14, 482, Palette.RIME[5], 6)
	wear_matter(edge, share)


## The engine cowl on its back: a rounded housing turned about its long axis, not
## a box, with louvres down its flanks and a stack off its crown. The grille
## across its back end is the working part.
func _engine(hull: Node3D, R: Array, D: Array) -> void:
	var house := joint(&"engine", hull, Vector3(-0.62, 0.58, 0.0))
	var k := FoundKit.kit()
	# Turned about x: a barrel of a cowl, round-shouldered.
	FoundKit.lathe(k, Vector3(-0.46, 0.36, 0.0), Vector3.RIGHT, [Vector2(0.4, 0.0), Vector2(0.5, 0.08), Vector2(0.52, 0.72), Vector2(0.44, 0.9), Vector2(0.3, 0.96)], 10, R, PI / 10.0)
	for sz: float in [-1.0, 1.0]:
		FoundKit.ticks(k, Vector3(-0.2, 0.36, sz * 0.52), Vector3(0.3, 0.36, sz * 0.52), Vector3(0, 0, sz), 6, R[1], 0.32)
	FoundKit.lathe(k, Vector3(0.18, 0.84, 0.22), Vector3.UP, [Vector2(0.1, 0.0), Vector2(0.09, 0.66), Vector2(0.13, 0.7), Vector2(0.13, 0.8)], 8, D)
	body_mesh(k, house)
	add_lamp(house, Vector3(0.2, 0.86, -0.24), Vector3.UP, Vector3.RIGHT, 0.085, 0.085, &"status")
	var ice := FoundKit.matter_kit(Ink.NONE)
	ice.rock(0.0, 0.86, -0.1, 0.36, 0.07, 560, Palette.RIME[5], 6)
	ice.rock(0.2, 1.62, 0.22, 0.14, 0.04, 561, Palette.RIME[5], 6)
	wear_matter(ice, house)
	# The grille on the back end: the engine's heat in rings, what a blow has to reach.
	var pk := FoundKit.kit()
	var glow: Array = [Palette.LENS[0], Palette.LENS[1], Palette.LENS[2], Palette.LENS[2], Palette.LENS[3], Palette.LENS[3]]
	for j in 4:
		FoundKit.lathe(pk, Vector3(-0.47, 0.36, 0.0), Vector3.RIGHT, [Vector2(0.14 + j * 0.08, 0.0), Vector2(0.16 + j * 0.08, 0.02)], 10, glow, PI / 10.0)
	part_mesh(pk, house)
	set_part_anchor(house, Vector3(-0.52, 0.36, 0.0), 1.0)


## A cold slit on the cowl's front, looking over the share.
func _head(hull: Node3D, R: Array) -> void:
	var head := joint(&"head", hull, Vector3(0.1, 1.0, 0.0))
	var k := FoundKit.kit()
	FoundKit.lathe(k, Vector3(-0.08, 0.0, 0.0), Vector3.RIGHT, [Vector2(0.14, 0.0), Vector2(0.16, 0.06), Vector2(0.14, 0.16)], 8, R, PI / 8.0)
	FoundKit.visor(k, Vector3(0.081, 0.0, 0.0), Vector3.RIGHT, Vector3.UP, 0.22, 0.05)
	body_mesh(k, head)
	add_scan(head, Vector3(0.083, 0.0, 0.0), Vector3.RIGHT, Vector3.BACK, 0.2, 0.04, 3.0)
	# No work beam: its dithered cone reads as dark speckle over the snow at eye
	# level, dirt across the share, which is the one shape that must read.


func _pose_deltas(p: StringName) -> Dictionary:
	var d := {}
	match p:
		&"stand":
			d[&"share"] = pr(Vector3(0, 0.1, 0), Vector3(0, 0, 0.06))
			d[&"head"] = r(Vector3(0, 0, 0.08))
		&"alert":
			d[&"hull"] = pr(Vector3(0.02, -0.05, 0), Vector3(0, 0, -0.04))
			d[&"share"] = pr(Vector3(0, -0.02, 0))
			d[&"head"] = r(Vector3(0, 0, -0.12))
		&"windup":
			d[&"hull"] = pr(Vector3(-0.14, 0.1, 0), Vector3(0, 0, 0.14))
			d[&"share"] = pr(Vector3(0.02, 0.16, 0), Vector3(0, 0, 0.12))
			d[&"head"] = r(Vector3(0, 0, -0.16))
		&"strike":
			var throw := 0.36
			if strike_front > 0.0:
				throw = maxf(0.0, strike_reach() - (Basis.from_euler(STRIKE_PITCH) * (SHARE_FRONT + STRIKE_SHARE)).x)
			d[&"hull"] = pr(Vector3(throw, -0.04, 0), STRIKE_PITCH)
			d[&"share"] = pr(STRIKE_SHARE)
		&"hurt":
			d[&"head"] = r(Vector3(0, 0, 0.1))
		&"dead":
			d[&"hull"] = pr(Vector3(0.1, -0.16, 0.06), Vector3(0.12, 0.1, -0.2))
			d[&"share"] = pr(Vector3(0, -0.08, 0), Vector3(0, 0, -0.1))
			d[&"engine"] = pr(Vector3(0, -0.04, 0), Vector3(0.18, 0, 0.06))
			d[&"head"] = r(Vector3(0, 0, 0.4))
	return d


func _gait_deltas(phase: float) -> Dictionary:
	return {
		&"hull": pr(Vector3(0, absf(sin(phase * TAU)) * 0.016, 0), Vector3(sin(phase * TAU) * 0.012, 0, cos(phase * TAU) * 0.016)),
		&"share": r(Vector3(0, 0, sin(phase * TAU + 0.8) * 0.02)),
	}


func _routine(delta: float, on: bool) -> void:
	var v := maxf(speed_now, nominal_speed if pose == &"walk" else 0.0)
	_travel += delta * v
	for w in _wheels:
		w.rotation.z = -_travel / WHEEL_R
	if not on or pose == &"dead":
		return
	# Steam off the stack, a white plume: slow at idle, fast when it works. The one
	# warm thing on the snowfield, and the first thing a player sees of it.
	_steam_in -= delta
	if _steam_in > 0.0 or not is_inside_tree():
		return
	_steam_in = 0.18 if v > 0.5 or pose == &"windup" else 0.4
	var stack := (joints[&"engine"] as Node3D).global_transform * Vector3(0.18, 1.66, 0.22)
	var drift := Vector2(-0.6, 0.2).rotated(-global_rotation.y)
	# Two puffs a beat, one riding on the other: one alone is a wisp against the sky.
	var seed_value := int(_travel * 100.0) + get_instance_id()
	MobFx.plume(get_parent(), stack, Palette.RIME[5], 1.3, 2.8, drift, seed_value)
	MobFx.plume(get_parent(), stack + Vector3(0, 0.35, 0), Palette.RIME[5], 1.0, 2.2, drift * 1.3, seed_value + 7)
