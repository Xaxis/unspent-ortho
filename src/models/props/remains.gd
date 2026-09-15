extends RefCounted
## What people left, and the patched places where they still live. Everything a
## person built is MADE here, however much steel is in it: the trawler, the car,
## the sea wall, the fire tower are the hand's work gone to rust and ruin, drawn
## uneven and hatched. What came off a machine and was put to use (plate nailed
## over a hole, a light panel wired to a stove-pipe) is FOUND: ruled, clean,
## violet, riveted, and it never quite belongs.
##
## Each model dresses for its landscape: a car drowned at the coast's tide line,
## sunk to its windows in the moss, buried in snow, scoured pale in the
## bonelands, burnt to its shell in the burning. The shape says what it was;
## the dressing says what the land did to it.
##
## Models face +X. Runs (fences, walls, barricades) lie along X, so a line of
## them is placed with rot = the line's bearing.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")

## The stolen light people wire in: the same three tubes the houses use.
const NEON: Array[Color] = [Color(0.3, 0.95, 1.0), Color(1.0, 0.25, 0.8), Color(0.55, 1.0, 0.35)]


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.HAND)
	match kind:
		PropKind.FENCE: fence(k, v, c)
		PropKind.BARRICADE: barricade(k, v, c)
		PropKind.GRAVE: grave(k, v, c)
		PropKind.DEBRIS: debris(k, v, c)
		PropKind.SHACK: shack(k, v, c)
		PropKind.VEHICLE: vehicle(k, v, c)
		PropKind.HULL: hull(k, v, c)
		PropKind.SEA_WALL: sea_wall(k, v, c)
		PropKind.STUMP: stump(k, v, c)
		PropKind.FIRE_TOWER: fire_tower(k, v, c)
		PropKind.WATER_TANK: water_tank(k, v, c)
		PropKind.SLAG_HEAP: slag_heap(k, v, c)


# --- shared pieces -------------------------------------------------------------

## The land's own wash in a country, and a step darker: what drifts and banks
## against a thing (sand, peat, needles, snow, dust, ash).
static func drift_of(c: int) -> Array[Color]:
	match c:
		Country.MOSS: return [P.EARTH[1].lerp(P.MOSS[1], 0.4), P.EARTH[1]]
		Country.PINEWOOD: return [P.EARTH[2].lerp(P.EARTH[3], 0.4), P.EARTH[2]]
		Country.SNOWFIELD: return [P.RIME[5], P.RIME[4]]
		Country.BONELANDS: return [P.LINEN[4].lerp(P.SAND[4], 0.4), P.LINEN[3]]
		Country.BURNING: return [P.ASH[2], P.ASH[1]]
	return [P.SAND[4], P.SAND[3]]


## Timber as each country weathers it: silvered by salt, black with bog, grey
## with needles, bleached, or charred.
static func wood_of(c: int) -> Array[Color]:
	match c:
		Country.MOSS: return [P.EARTH[1], P.INK[3]]
		Country.PINEWOOD: return [P.EARTH[2], P.EARTH[1]]
		Country.SNOWFIELD: return [P.SLATE[2], P.EARTH[1]]
		Country.BONELANDS: return [P.LINEN[3], P.LINEN[2]]
		Country.BURNING: return [P.INK[2], P.STONE[0]]
	return [P.LINEN[3].lerp(P.ASH[3], 0.4), P.LINEN[2]]


## Soft lumps [x, z, r, h] banked against a thing, feet sunk in the ground.
## Drifts lie long and low along their own axis, never piled like stones.
static func banks(k: Kit, lumps: Array, col: Color, seed_value: int) -> void:
	for i in lumps.size():
		var l: Array = lumps[i]
		var r: float = l[2]
		var h := minf(float(l[3]), r * 0.45)
		var ang := Rng.hash01(seed_value, i, 5) * PI
		k.made.push(Transform3D(Basis(Vector3.UP, ang) * Basis.from_scale(Vector3(1.3, 1.0, 0.78)), Vector3(float(l[0]), 0.0, float(l[1]))))
		k.clump(0.0, -0.18, 0.0, r, h + 0.18, seed_value + i, col if i % 2 == 0 else GroundColors.down(col, 0.08), 9)
		k.made.pop()


## A quad seen from both sides.
static func both(pen: MeshKit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	pen.quad(a, b, c, d, col)
	pen.quad(d, c, b, a, GroundColors.down(col, 0.1))


## A corrugated sheet on the plane (o, o + u, o + u + v, o + v): ribs along v,
## light and dark by turns, so it reads as tin at a glance.
static func corrugated(pen: MeshKit, o: Vector3, u: Vector3, v: Vector3, ribs: int, col: Color) -> void:
	var n := u.cross(v).normalized() * 0.006
	for i in ribs:
		var a := o + u * (float(i) / ribs)
		var b := o + u * (float(i + 1) / ribs)
		var cc := col if i % 2 == 0 else GroundColors.down(col, 0.35)
		pen.quad(a + n * float(i % 2), b + n * float(i % 2), b + v + n * float(i % 2), a + v + n * float(i % 2), cc)


## A rust run down a MADE face from `top`: wide at the top, drying to a thread.
static func streak(k: Kit, top: Vector3, width: float, length: float, out: Vector3, col: Color = P.RUST[2]) -> void:
	var along := Vector3(out.z, 0, -out.x).normalized() * width * 0.5
	var lift := out.normalized() * 0.008
	var mid := top + Vector3(0, -length * 0.5, 0)
	var foot := top + Vector3(0, -length, 0)
	k.made.quad(top - along + lift, top + along + lift, mid + along * 0.45 + lift, mid - along * 0.6 + lift, col)
	k.made.quad(mid - along * 0.6 + lift, mid + along * 0.45 + lift, foot + along * 0.1 + lift, foot - along * 0.08 + lift, GroundColors.down(col, 0.3))


## A piece of machine plate put to a person's use: ruled, riveted, on the
## plane of (a, b, c, d), a hair out. FOUND.
static func patch(k: Kit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tone: int = 3) -> void:
	k.plate(a, b, c, d, P.PLATE[tone], P.PLATE[maxi(tone - 2, 0)], P.PLATE[5])


## Machine plate that must read from either side (a roof seen from above and
## below, a panel propped at any angle).
static func plate_both(k: Kit, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tone: int = 3) -> void:
	patch(k, a, b, c, d, tone)
	patch(k, d, c, b, a, tone)


## A tube of stolen neon on a plane: dark mount, then the tube, lit at night.
static func neon_tube(k: Kit, a: Vector3, b: Vector3, out: Vector3, col: Color) -> void:
	var up := Vector3(0, 0.022, 0)
	var o := out.normalized()
	k.made.quad(a - up + o * 0.01, b - up + o * 0.01, b + up + o * 0.01, a + up + o * 0.01, P.INK[1])
	var up2 := Vector3(0, 0.012, 0)
	k.made.quad(a - up2 + o * 0.02, b - up2 + o * 0.02, b + up2 + o * 0.02, a + up2 + o * 0.02, GroundColors.lamp(col, 2.0))


## A wheel on its side axis (z): tyre and hub.
static func wheel(k: Kit, at: Vector3, r: float, width: float, tyre: Color, hub: Color) -> void:
	k.made.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0, -width * 0.5)))
	k.made.prism(0, 0, 0, r, width, r, 9, tyre, hub)
	k.made.prism(0, -0.004, 0, r * 0.45, width + 0.008, r * 0.45, 7, hub, GroundColors.up(hub, 0.3))
	k.made.pop()


# --- fences and barricades -----------------------------------------------------

## A run of fence two tiles along X. 0: posts and barbed wire, 1: a machine's
## mesh panel between hand posts, 2: a section gone over. Snow fences are slats
## in the Snowfield; reeds grow through them in the Moss.
static func fence(k: Kit, v: int, c: int) -> void:
	var s := 20100 + v * 13 + c
	var wood := wood_of(c)
	var posts: Array[float] = [-0.98, 0.02]
	if c == Country.SNOWFIELD and v != 1:
		# A snow fence: split slats wired in a ribbon, a drift built up behind.
		for pi in 2:
			k.limb(Vector3(posts[pi], -0.1, 0.0), Vector3(posts[pi] + Kit.j(s, pi, 0.05), 1.05, Kit.j(s, pi + 3, 0.04)), 0.04, 0.03, 5, wood[1])
		var lean := 0.0 if v == 0 else 0.35
		for i in 13:
			var x := -1.0 + i * 0.155
			var h := 0.85 + Kit.j(s, 10 + i, 0.08) - (absf(x) * 0.3 if v == 2 else 0.0)
			k.made.push(Transform3D(Basis(Vector3.RIGHT, lean + Kit.j(s, 30 + i, 0.05)), Vector3(x, -0.05, 0.0)))
			k.slab(0.0, 0.0, 0.0, 0.07, h, 0.025, s + 40 + i, wood[0] if i % 3 else wood[1], P.RIME[5], 0.008)
			k.made.pop()
		k.sag(Vector3(-1.0, 0.25, 0.02), Vector3(1.0, 0.25, 0.02), 0.03, 4, 0.007, P.INK[2])
		k.sag(Vector3(-1.0, 0.7, 0.02), Vector3(1.0, 0.7, 0.02), 0.03, 4, 0.007, P.INK[2])
		banks(k, [[-0.6, -0.3, 0.45, 0.45], [0.2, -0.35, 0.55, 0.55], [0.8, -0.28, 0.4, 0.4], [-0.1, 0.25, 0.3, 0.14]], P.RIME[5], s + 60)
		return
	match v:
		0:
			for pi in 2:
				var top := Vector3(posts[pi] + Kit.j(s, pi, 0.06), 0.9 + Kit.j(s, pi + 5, 0.08), Kit.j(s, pi + 3, 0.05))
				k.limb(Vector3(posts[pi], -0.1, 0.0), top, 0.045, 0.032, 5, wood[0] if pi == 0 else wood[1])
			# Three strands, the lowest slack; barbs every hand's width.
			for h: float in [0.3, 0.55, 0.8]:
				var dip := 0.04 if h > 0.5 else 0.12
				k.sag(Vector3(-1.0, h, 0.0), Vector3(1.0, h - 0.03, 0.0), dip, 6, 0.006, P.INK[2])
				for b in 7:
					var t := (b + 0.5) / 7.0
					var p := Vector3(-1.0 + t * 2.0, h - 0.015 - dip * 4.0 * t * (1.0 - t), 0.0)
					k.fleck(p + Vector3(-0.02, -0.02, 0.0), p + Vector3(0.02, 0.02, 0.01), p + Vector3(0.0, 0.0, -0.02), P.INK[3])
			# A rag caught on the top strand, long faded.
			k.fleck(Vector3(0.35, 0.78, 0.0), Vector3(0.45, 0.62, 0.02), Vector3(0.31, 0.6, -0.01), P.BLOOM[1] if c != Country.BURNING else P.ASH[1])
		1:
			# A machine's mesh panel, ruled and exact, lashed between hand posts;
			# it sags where one post leans. Razor coil along its top.
			for pi in 2:
				k.limb(Vector3(posts[pi], -0.1, 0.0), Vector3(posts[pi] + (0.08 if pi == 1 else 0.0), 1.25, 0.0), 0.05, 0.04, 5, wood[pi])
			k.found.push(Transform3D(Basis(Vector3.BACK, 0.03) * Basis(Vector3.RIGHT, 0.06), Vector3(-0.48, 0.1, 0.03)))
			var pw := 0.96
			var ph := 1.02
			k.found.quad(Vector3(-pw, 0, 0), Vector3(pw, 0, 0), Vector3(pw, 0.04, 0), Vector3(-pw, 0.04, 0), P.PLATE[2])
			k.found.quad(Vector3(-pw, ph - 0.04, 0), Vector3(pw, ph - 0.04, 0), Vector3(pw, ph, 0), Vector3(-pw, ph, 0), P.PLATE[2])
			for i in 11:
				var x := -pw + i * (pw * 2.0 / 10.0)
				k.found.quad(Vector3(x - 0.008, 0, 0.004), Vector3(x + 0.008, 0, 0.004), Vector3(x + 0.008, ph, 0.004), Vector3(x - 0.008, ph, 0.004), P.PLATE[3])
				k.found.quad(Vector3(x + 0.008, 0, -0.004), Vector3(x - 0.008, 0, -0.004), Vector3(x - 0.008, ph, -0.004), Vector3(x + 0.008, ph, -0.004), P.PLATE[1])
			for j in 5:
				var y := 0.2 + j * 0.17
				k.found.quad(Vector3(-pw, y - 0.007, 0.006), Vector3(pw, y - 0.007, 0.006), Vector3(pw, y + 0.007, 0.006), Vector3(-pw, y + 0.007, 0.006), P.PLATE[3])
				k.found.quad(Vector3(pw, y - 0.007, -0.006), Vector3(-pw, y - 0.007, -0.006), Vector3(-pw, y + 0.007, -0.006), Vector3(pw, y + 0.007, -0.006), P.PLATE[1])
			for i in 5:
				k.hoop(Vector3(-0.8 + i * 0.4, ph + 0.1, 0.0), 0.1, 6, 0.008, P.PLATE[4], Vector3(1, 0, 0))
			k.found.pop()
			# Lashed on with rope where the ruler meets the hand.
			for pi in 2:
				k.made.prism(posts[pi] + (0.03 if pi == 1 else 0.0), 0.5, 0.0, 0.06, 0.58, 0.06, 5, P.LINEN[2])
		_:
			# Gone over: one post snapped, the wire slack on the ground, the
			# other post still standing with a strand wound round it.
			k.limb(Vector3(-0.98, -0.1, 0.0), Vector3(-0.95, 0.85, 0.05), 0.045, 0.034, 5, wood[0])
			k.limb(Vector3(0.02, -0.05, 0.0), Vector3(0.1, 0.3, 0.02), 0.045, 0.04, 5, wood[1])
			k.limb(Vector3(0.12, 0.03, 0.08), Vector3(0.85, 0.04, 0.4), 0.04, 0.03, 5, wood[1])
			k.sag(Vector3(-0.95, 0.75, 0.05), Vector3(0.8, 0.05, 0.35), 0.1, 6, 0.006, P.INK[2])
			k.sag(Vector3(-0.95, 0.5, 0.05), Vector3(1.0, 0.03, -0.2), 0.05, 6, 0.006, P.INK[2])
			k.sag(Vector3(-0.2, 0.03, -0.3), Vector3(0.6, 0.03, 0.1), -0.05, 5, 0.006, P.INK[3])
	if c == Country.MOSS:
		# Reeds through the wire, taller than the posts.
		var rs := k.made.vertex_count()
		for i in 9:
			var x := -0.9 + i * 0.22 + Kit.j(s, 70 + i, 0.06)
			var z := Kit.j(s, 80 + i, 0.18)
			k.blade(Vector3(x, -0.02, z), Vector3(x + 0.05, 0.9 + Kit.j(s, 90 + i, 0.25), z), 0.05, Kit.j(s, 95 + i, 1.5), P.SPRUCE[3] if i % 2 else P.MOSS[3])
		k.sway_by_height(rs, 0.0, 1.0, 0.7)
	elif c == Country.BURNING:
		banks(k, [[-0.6, 0.2, 0.3, 0.12], [0.5, -0.2, 0.35, 0.1]], P.ASH[2], s + 90)


## A barricade across a way in: 0 tyres, sandbags and a leaning sheet of plate
## behind crossed stakes; 1 cast blocks with faded chevrons and a machine plate
## bolted on, struck through.
static func barricade(k: Kit, v: int, c: int) -> void:
	var s := 20300 + v * 11 + c
	var wood := wood_of(c)
	var drift := drift_of(c)
	if v % 2 == 0:
		for i in 3:
			var x := -0.9 + i * 0.12
			for t in 3 - i:
				k.made.prism(x + 0.02 * t, t * 0.14 - 0.02, -0.35 + i * 0.25, 0.2, t * 0.14 + 0.12, 0.2, 9, P.INK[2], P.INK[1])
				k.made.prism(x + 0.02 * t, t * 0.14 + 0.121, -0.35 + i * 0.25, 0.09, t * 0.14 + 0.124, 0.09, 9, P.INK[0])
		for i in 7:
			var x := -0.2 + (i % 4) * 0.34 + (0.17 if i >= 4 else 0.0)
			var y := -0.02 + (0.18 if i >= 4 else 0.0)
			k.slab(x, y, -0.1 + Kit.j(s, i, 0.05), 0.34, 0.2, 0.26, s + i, P.LINEN[3] if i % 3 else P.EARTH[3], P.LINEN[4], 0.035, 0.25)
		# The sheet: plate off a machine, propped on a stake.
		k.found.push(Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0.2, 0.0, -0.5)))
		k.plate(Vector3(-0.55, 0, 0), Vector3(0.75, 0, 0), Vector3(0.75, 0.95, 0), Vector3(-0.55, 0.95, 0), P.PLATE[3], P.PLATE[1], P.PLATE[5])
		k.found.pop()
		k.limb(Vector3(0.7, -0.05, -1.0), Vector3(0.62, 0.8, -0.72), 0.03, 0.025, 4, wood[1])
		# Crossed stakes in front, sharpened, wired.
		for i in 3:
			var x := -0.9 + i * 0.85
			k.limb(Vector3(x - 0.35, -0.05, 0.55), Vector3(x + 0.3, 0.75, 0.9), 0.035, 0.012, 4, wood[0])
			k.limb(Vector3(x + 0.35, -0.05, 0.55), Vector3(x - 0.3, 0.75, 0.9), 0.035, 0.012, 4, wood[1])
		k.sag(Vector3(-1.2, 0.35, 0.72), Vector3(1.2, 0.35, 0.72), 0.06, 7, 0.006, P.INK[2])
	else:
		var concrete := P.STONE[3].lerp(P.LINEN[3], 0.35)
		if c == Country.BURNING:
			concrete = P.STONE[1]
		for i in 3:
			var x := -0.85 + i * 0.85
			var rot := Kit.j(s, i, 0.2)
			k.made.push(Transform3D(Basis(Vector3.UP, rot) * Basis(Vector3.BACK, Kit.j(s, i + 4, 0.06)), Vector3(x, -0.04, Kit.j(s, i + 8, 0.12))))
			k.slab(0.0, 0.0, 0.0, 0.84, 0.5, 0.42, s + 20 + i, concrete, GroundColors.up(concrete, 0.2), 0.02, 0.55)
			# Chevrons, faded, painted on by a hand that wanted to be seen.
			for ch in 3:
				var cx := -0.26 + ch * 0.24
				k.made.quad(Vector3(cx, 0.06, 0.216), Vector3(cx + 0.1, 0.06, 0.216), Vector3(cx + 0.16, 0.42, 0.13), Vector3(cx + 0.06, 0.42, 0.13), P.RUST[3] if c != Country.BURNING else P.RUST[1])
			k.made.pop()
		k.limb(Vector3(-0.4, 0.5, 0.1), Vector3(-0.2, 0.95, 0.35), 0.018, 0.014, 4, P.RUST[2])
		k.limb(Vector3(0.45, 0.5, -0.05), Vector3(0.9, 0.82, -0.1), 0.018, 0.014, 4, P.RUST[2])
		# The machines' own plate, bolted on the middle block, and struck.
		k.plate(Vector3(-0.2, 0.12, 0.24), Vector3(0.2, 0.12, 0.24), Vector3(0.2, 0.34, 0.18), Vector3(-0.2, 0.34, 0.18), P.RIME[5].lerp(P.PLATE[4], 0.5), P.PLATE[1], P.PLATE[2])
		k.made.quad(Vector3(-0.26, 0.15, 0.25), Vector3(0.26, 0.28, 0.215), Vector3(0.26, 0.32, 0.205), Vector3(-0.26, 0.19, 0.24), P.INK[0])
	banks(k, [[-0.9, -0.5, 0.35, 0.12], [0.8, -0.45, 0.4, 0.14]], drift[0], s + 50)


# --- the dead ------------------------------------------------------------------

## Graves and memorials. 0: a mound under a lashed cross with a rag on it;
## 1: a marker cut from machine plate with the name scratched by hand and a jar
## lamp that someone still lights; 2: three stakes in a row (in the Moss, the
## bog's grave markers, tall so they can be found again).
static func grave(k: Kit, v: int, c: int) -> void:
	var s := 20500 + v * 7 + c
	var wood := wood_of(c)
	var mound := drift_of(c)
	if c == Country.COAST:
		mound = [P.EARTH[2].lerp(P.MOSS[2], 0.4), P.EARTH[2]]
	match v % 3:
		0:
			_mound(k, Vector3(0.1, 0.0, 0.0), 0.62, 0.26, s, mound)
			k.limb(Vector3(-0.55, -0.05, 0.0), Vector3(-0.53, 0.95, 0.02), 0.035, 0.028, 5, wood[0])
			k.limb(Vector3(-0.54, 0.7, -0.26), Vector3(-0.52, 0.72, 0.28), 0.028, 0.024, 5, wood[0])
			k.made.prism(-0.535, 0.66, 0.0, 0.045, 0.76, 0.045, 5, P.LINEN[2])
			k.fleck(Vector3(-0.52, 0.72, 0.22), Vector3(-0.47, 0.42, 0.26), Vector3(-0.5, 0.45, 0.16), P.BLOOM[1] if c != Country.SNOWFIELD else P.RUST[2])
			for i in 8:
				var a := float(i) / 8.0 * TAU
				k.stone(0.1 + cos(a) * 0.72, -0.04, sin(a) * 0.36, 0.07, 0.08, s + 10 + i, P.STONE[3] if i % 2 else P.LINEN[3], 5)
		1:
			_mound(k, Vector3(0.15, 0.0, 0.0), 0.55, 0.2, s, mound)
			k.found.push(Transform3D(Basis(Vector3.BACK, -0.08), Vector3(-0.5, -0.1, 0.0)))
			k.found.quad(Vector3(0, 0, 0.22), Vector3(0, 0, -0.22), Vector3(0, 0.62, -0.22), Vector3(0, 0.7, 0.22), P.PLATE[3])
			k.found.quad(Vector3(0, 0, -0.22), Vector3(0, 0, 0.22), Vector3(0, 0.7, 0.22), Vector3(0, 0.62, -0.22), P.PLATE[2])
			for r in 4:
				k.found.quad(Vector3(0.004, 0.08 + r * 0.16, 0.17), Vector3(0.004, 0.08 + r * 0.16, 0.15), Vector3(0.004, 0.1 + r * 0.16, 0.15), Vector3(0.004, 0.1 + r * 0.16, 0.17), P.PLATE[5])
			k.found.pop()
			# The name, scratched with a nail: a row of short strokes.
			for i in 5:
				var z := -0.12 + i * 0.05
				k.made.quad(Vector3(-0.47, 0.4, z), Vector3(-0.47, 0.4, z + 0.02), Vector3(-0.465, 0.5 - (i % 2) * 0.03, z + 0.03), Vector3(-0.465, 0.5 - (i % 2) * 0.03, z + 0.01), P.LINEN[5])
			# A jar with a stub of candle: the lamp code lights it after dusk.
			k.made.prism(-0.25, -0.02, 0.28, 0.06, 0.14, 0.055, 7, P.SPRUCE[3], P.SPRUCE[4])
			k.made.prism(-0.25, 0.05, 0.28, 0.022, 0.12, 0.018, 5, GroundColors.lamp(P.EMBER[4], 1.4))
			# Flowers left on it, one fresh.
			k.fleck(Vector3(0.2, 0.12, -0.2), Vector3(0.3, 0.12, -0.12), Vector3(0.24, 0.2, -0.16), P.BLOOM[4])
			k.fleck(Vector3(0.28, 0.1, -0.28), Vector3(0.36, 0.1, -0.2), Vector3(0.3, 0.17, -0.24), P.LINEN[5])
		_:
			var tall := 1.35 if c == Country.MOSS else 0.8
			for i in 3:
				var z := -0.5 + i * 0.5
				_mound(k, Vector3(0.15, 0.0, z), 0.34, 0.14, s + i, mound)
				k.limb(Vector3(-0.2, -0.05, z), Vector3(-0.19 + Kit.j(s, i, 0.05), tall - i * 0.08, z + Kit.j(s, i + 3, 0.04)), 0.03, 0.02, 4, wood[i % 2])
				k.made.prism(-0.19, tall * 0.78 - i * 0.08, z, 0.04, tall * 0.84 - i * 0.08, 0.04, 5, [P.LINEN[4], P.RUST[3], P.BLOOM[2]][i])
			if c == Country.SNOWFIELD:
				k.clump(0.1, 0.02, 0.0, 0.5, 0.18, s + 9, P.RIME[5], 8)


## A grave's mound: long and low along x, the fresh side darker.
static func _mound(k: Kit, at: Vector3, length: float, h: float, s: int, cols: Array[Color]) -> void:
	k.made.push(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.5)), at))
	k.clump(0.0, -0.1, 0.0, length, h + 0.1, s, cols[0], 9)
	k.made.pop()
	k.made.push(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.45)), at + Vector3(0.12, 0.0, 0.03)))
	k.clump(0.0, -0.1, 0.0, length * 0.6, h + 0.08, s + 1, cols[1], 7)
	k.made.pop()


# --- litter of the world before --------------------------------------------------

## A field of debris you walk through. 0: a slab of broken concrete with bars
## out of it; 1: a length of pipe, a tyre, cans; 2: a roof sheet blown flat,
## cable in loops and broken glass that catches the light.
static func debris(k: Kit, v: int, c: int) -> void:
	var s := 20700 + v * 5 + c
	var concrete := P.STONE[3].lerp(P.LINEN[3], 0.3) if c != Country.BURNING else P.STONE[1]
	match v % 3:
		0:
			k.made.push(Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, 0.12), Vector3(0.0, -0.05, 0.0)))
			k.slab(0.0, 0.0, 0.0, 1.1, 0.14, 0.8, s, concrete, GroundColors.up(concrete, 0.15), 0.05, 0.05)
			k.made.pop()
			k.slab(0.7, -0.04, -0.4, 0.4, 0.12, 0.3, s + 1, GroundColors.down(concrete, 0.2), concrete, 0.04, 0.1)
			for i in 5:
				var a := Vector3(-0.45 + i * 0.2, 0.1, 0.33 - i * 0.07)
				k.limb(a, a + Vector3(0.1 + Kit.j(s, i, 0.1), 0.3 + Kit.j(s, i + 5, 0.12), 0.15), 0.014, 0.01, 4, P.RUST[2])
			for i in 6:
				k.stone(-0.6 + i * 0.26, -0.03, -0.55 + Kit.j(s, 20 + i, 0.12), 0.06, 0.05, s + 20 + i, concrete, 4)
		1:
			k.limb(Vector3(-0.8, 0.1, -0.2), Vector3(0.6, 0.08, 0.1), 0.1, 0.1, 8, P.RUST[2])
			k.made.prism(-0.8, 0.0, -0.2, 0.12, 0.2, 0.12, 8, P.RUST[1], P.INK[1])
			k.made.push(Transform3D(Basis(Vector3.BACK, 0.22), Vector3(0.45, 0.02, -0.5)))
			k.made.prism(0, 0, 0, 0.26, 0.14, 0.26, 10, P.INK[2], P.INK[1])
			k.made.prism(0, 0.141, 0, 0.12, 0.145, 0.12, 10, P.INK[0])
			k.made.pop()
			for i in 4:
				var p := Vector3(-0.4 + i * 0.22, 0.0, 0.45 + Kit.j(s, i, 0.1))
				k.made.prism(p.x, 0.0, p.z, 0.04, 0.09, 0.04, 6, P.RUST[3] if i % 2 else P.SLATE[3], P.INK[2])
		_:
			corrugated(k.made, Vector3(-0.7, 0.03, -0.45), Vector3(-0.15, 0.02, 0.75), Vector3(1.2, 0.04, 0.2), 9, P.SLATE[3] if c != Country.BURNING else P.RUST[1])
			k.cable(Vector3(0.5, 0.03, 0.3), Vector3(0.85, 0.05, -0.4), -0.05, 5, 0.012, P.INK[2])
			k.hoop(Vector3(0.6, 0.03, -0.1), 0.15, 8, 0.01, P.INK[2])
			for i in 5:
				var p := Vector3(-0.5 + i * 0.18, 0.02, 0.55 + Kit.j(s, i, 0.08))
				k.fleck(p, p + Vector3(0.05, 0.005, 0.03), p + Vector3(0.01, 0.01, -0.04), GroundColors.glint(P.SPRUCE[4] if i % 2 else P.RIME[4]))
	if c == Country.SNOWFIELD:
		k.clump(0.1, -0.1, 0.1, 0.5, 0.18, s + 30, P.RIME[5], 8)
	elif c == Country.MOSS or c == Country.PINEWOOD:
		k.clump(-0.3, -0.06, 0.3, 0.2, 0.1, s + 31, P.MOSS[2], 6)


# --- where people still live ---------------------------------------------------

## A patched shelter, one kind per landscape: the fishing shack on the coast,
## the stilt hut over the moss, the hunting blind in the pines, the emergency
## pod half under the snow, the stone lean-to on the bones, the dugout in the
## ash. Variant 1 has stolen tech in it: a machine's light panel wired to a
## neon tube and an aerial, lit after dusk.
static func shack(k: Kit, v: int, c: int) -> void:
	var s := 21000 + v * 17 + c * 3
	var lit := v % 2 == 1
	match c:
		Country.MOSS: _stilt_hut(k, s, lit)
		Country.PINEWOOD: _blind(k, s, lit)
		Country.SNOWFIELD: _pod(k, s, lit)
		Country.BONELANDS: _lean_to(k, s, lit)
		Country.BURNING: _dugout(k, s, lit)
		_: _fish_shack(k, s, lit)


## Stolen tech on a wall: a FOUND light panel, the neon tube it feeds, a cable
## down to the ground and an aerial on the roof line.
static func _wired(k: Kit, wall_a: Vector3, wall_b: Vector3, out: Vector3, roof: Vector3, col: Color) -> void:
	var mid := wall_a.lerp(wall_b, 0.5)
	var o := out.normalized()
	k.found.quad(mid + o * 0.02 + Vector3(-0.0, 0.0, 0.0) - (wall_b - wall_a).normalized() * 0.12, mid + o * 0.02 + (wall_b - wall_a).normalized() * 0.12, mid + o * 0.02 + (wall_b - wall_a).normalized() * 0.12 + Vector3(0, 0.16, 0), mid + o * 0.02 - (wall_b - wall_a).normalized() * 0.12 + Vector3(0, 0.16, 0), P.PLATE[1])
	k.found.quad(mid + o * 0.03 - (wall_b - wall_a).normalized() * 0.09 + Vector3(0, 0.03, 0), mid + o * 0.03 + (wall_b - wall_a).normalized() * 0.09 + Vector3(0, 0.03, 0), mid + o * 0.03 + (wall_b - wall_a).normalized() * 0.09 + Vector3(0, 0.13, 0), mid + o * 0.03 - (wall_b - wall_a).normalized() * 0.09 + Vector3(0, 0.13, 0), Color(col.r, col.g, col.b, 0.86))
	neon_tube(k, wall_a + Vector3(0, 0.34, 0) + o * 0.01, wall_b + Vector3(0, 0.34, 0) + o * 0.01, o, col)
	k.sag(mid + o * 0.04, mid + o * 0.3 + Vector3(0, -mid.y, 0), 0.02, 3, 0.008, P.INK[1])
	k.rod(roof, roof + Vector3(0.02, 0.75, 0.0), 0.012, 4, P.PLATE[3])
	k.rod(roof + Vector3(0.02, 0.62, -0.18), roof + Vector3(0.02, 0.62, 0.18), 0.008, 4, P.PLATE[3])
	k.rod(roof + Vector3(0.02, 0.5, -0.12), roof + Vector3(0.02, 0.5, 0.12), 0.008, 4, P.PLATE[3])
	k.found.prism(roof.x + 0.02, roof.y + 0.75, roof.z, 0.02, roof.y + 0.8, 0.012, 6, Color(1.0, 0.25, 0.3, 0.3))


static func _fish_shack(k: Kit, s: int, lit: bool) -> void:
	var tar := P.INK[3].lerp(P.EARTH[1], 0.4)
	var t := PropModels.Houses.walls(k, 1.5, 2.1, 1.05, s, tar, GroundColors.down(tar, 0.2), Vector3(0.04, 0.0, -0.02))
	# Weatherboards: dark lines along the walls.
	for side in 2:
		var a: Vector3 = t[2] if side == 0 else t[3]
		var b: Vector3 = t[1] if side == 0 else t[2]
		var out := Vector3(1, 0, 0) if side == 0 else Vector3(0, 0, 1)
		for i in 5:
			var y := 0.16 + i * 0.19
			k.made.quad(a + Vector3(0, y, 0) + out * 0.012, b + Vector3(0, y, 0) + out * 0.012, b + Vector3(0, y + 0.02, 0) + out * 0.012, a + Vector3(0, y + 0.02, 0) + out * 0.012, P.INK[1])
	# Pent roof of tin, rust in bands, a sheet of machine plate over the hole.
	var ry := 1.08
	corrugated(k.made, Vector3(-0.95, ry + 0.3, -1.25), Vector3(0.0, 0.0, 2.5), Vector3(1.95, -0.34, 0.0), 12, P.RUST[2])
	k.made.quad(Vector3(-0.95, ry + 0.3, -1.25), Vector3(1.0, ry - 0.04, -1.25), Vector3(1.0, ry - 0.04, 1.25), Vector3(-0.95, ry + 0.3, 1.25), P.INK[2])
	patch(k, Vector3(-0.3, ry + 0.21, -0.2), Vector3(-0.3, ry + 0.21, 0.6), Vector3(0.5, ry + 0.08, 0.6), Vector3(0.5, ry + 0.08, -0.2), 2)
	# Door on the front, a stovepipe off true.
	k.made.quad(Vector3(0.77, 0.0, 0.25), Vector3(0.77, 0.0, -0.2), Vector3(0.8, 0.82, -0.2), Vector3(0.8, 0.82, 0.25), P.EARTH[1])
	k.limb(Vector3(-0.5, ry + 0.25, 0.7), Vector3(-0.44, ry + 0.95, 0.72), 0.06, 0.055, 6, P.INK[2])
	# Nets hung to dry between two poles, floats on the head-rope; creels stacked.
	k.limb(Vector3(1.4, -0.05, -1.3), Vector3(1.42, 1.3, -1.3), 0.03, 0.025, 4, P.LINEN[2])
	k.limb(Vector3(1.45, -0.05, 0.6), Vector3(1.43, 1.25, 0.6), 0.03, 0.025, 4, P.LINEN[2])
	k.sag(Vector3(1.42, 1.22, -1.3), Vector3(1.43, 1.18, 0.6), 0.12, 6, 0.008, P.LINEN[3])
	for i in 8:
		var z := -1.2 + i * 0.24
		var top := Vector3(1.42, 1.2 - 0.48 * (1.0 - pow((z + 0.35) / 0.95, 2.0)) * 0.25, z)
		k.made.quad(top, top + Vector3(0.005, 0, 0.24), top + Vector3(0.03, -0.9 + Kit.j(s, i, 0.15), 0.24), top + Vector3(0.03, -0.85 + Kit.j(s, i + 9, 0.15), 0.0), P.SLATE[1] if i % 2 else P.INK[3])
		if i % 2 == 0:
			k.fleck(top + Vector3(0.02, 0.0, 0.02), top + Vector3(0.02, -0.05, 0.08), top + Vector3(0.05, -0.02, 0.05), P.RUST[4])
	for i in 3:
		k.made.prism(1.0, i * 0.22, -0.9, 0.2, 0.2 + i * 0.22, 0.17, 6, P.EARTH[2] if i % 2 else P.EARTH[3], P.INK[2])
	if lit:
		_wired(k, Vector3(0.79, 0.45, -0.7), Vector3(0.79, 0.45, -0.3), Vector3(1, 0, 0), Vector3(0.6, ry + 0.02, -1.1), NEON[0])
	banks(k, [[-0.6, 1.05, 0.4, 0.14], [0.7, 1.1, 0.35, 0.12]], P.SAND[4], s + 70)


static func _stilt_hut(k: Kit, s: int, lit: bool) -> void:
	var floor_y := 0.75
	# Stilts sunk in the black water, a ladder, a walkway plank out to firm ground.
	for sx: float in [-0.6, 0.6]:
		for sz: float in [-0.7, 0.7]:
			k.limb(Vector3(sx * 1.05, -0.25, sz * 1.05), Vector3(sx, floor_y, sz), 0.05, 0.04, 5, P.EARTH[1])
	k.slab(0.0, floor_y, 0.0, 1.5, 0.06, 1.7, s, P.EARTH[2], P.EARTH[3], 0.02)
	k.made.push(Transform3D(Basis.IDENTITY, Vector3(0, floor_y + 0.06, 0)))
	PropModels.Houses.walls(k, 1.15, 1.4, 0.8, s + 1, P.EARTH[2].lerp(P.MOSS[1], 0.3), P.EARTH[1], Vector3(-0.03, 0.0, 0.02))
	k.made.pop()
	# Reed thatch, heavy and shaggy, held down with a net of cable.
	var ry := floor_y + 0.86
	k.clump(0.0, ry - 0.12, 0.0, 1.05, 0.75, s + 2, P.EARTH[3].lerp(P.MOSS[2], 0.3), 9)
	var th := k.made.vertex_count()
	for i in 14:
		var a := float(i) / 14.0 * TAU
		var base := Vector3(cos(a) * 0.85, ry - 0.02, sin(a) * 0.95)
		k.blade(base, base * 1.18 + Vector3(0, -0.28, 0), 0.12, a + 1.57, P.EARTH[3] if i % 2 else P.SAND[3])
	k.sway_by_height(th, ry - 0.3, ry, 0.15)
	k.cable(Vector3(-0.7, ry + 0.05, -0.6), Vector3(0.7, ry + 0.1, 0.6), -0.2, 4, 0.01, P.INK[2])
	k.cable(Vector3(0.7, ry + 0.05, -0.6), Vector3(-0.7, ry + 0.1, 0.6), -0.2, 4, 0.01, P.INK[2])
	patch(k, Vector3(0.59, floor_y + 0.2, -0.55), Vector3(0.59, floor_y + 0.2, -0.05), Vector3(0.59, floor_y + 0.65, -0.05), Vector3(0.59, floor_y + 0.65, -0.55), 3)
	k.made.quad(Vector3(0.6, floor_y + 0.07, 0.35), Vector3(0.6, floor_y + 0.07, 0.05), Vector3(0.6, floor_y + 0.7, 0.05), Vector3(0.6, floor_y + 0.7, 0.35), P.INK[2])
	for i in 5:
		var y := i * 0.17
		k.limb(Vector3(0.95 + y * 0.35, y - 0.1, 0.05), Vector3(0.95 + y * 0.35, y - 0.1, 0.35), 0.018, 0.018, 4, P.EARTH[2])
	k.limb(Vector3(0.95, -0.1, 0.03), Vector3(0.62, floor_y, 0.03), 0.02, 0.02, 4, P.EARTH[1])
	k.limb(Vector3(0.95, -0.1, 0.37), Vector3(0.62, floor_y, 0.37), 0.02, 0.02, 4, P.EARTH[1])
	k.slab(1.6, -0.08, -0.5, 1.6, 0.05, 0.28, s + 5, P.EARTH[2], P.EARTH[3], 0.03)
	# Black water under it, a green scum at the rim.
	_pool(k, Vector3(0.0, 0.0, 0.0), 1.2, s + 6)
	if lit:
		_wired(k, Vector3(0.6, floor_y + 0.12, -0.45), Vector3(0.6, floor_y + 0.12, -0.12), Vector3(1, 0, 0), Vector3(-0.2, ry + 0.4, 0.0), NEON[2])


## A still pool of black water with a green rim, lying flat on the ground.
static func _pool(k: Kit, at: Vector3, r: float, s: int) -> void:
	var ring: Array[Vector3] = []
	var rim: Array[Vector3] = []
	for i in 12:
		var a := float(i) / 12.0 * TAU
		var rr := r * (0.8 + Rng.hash01(s, i) * 0.35)
		ring.append(at + Vector3(cos(a) * rr, 0.012, sin(a) * rr))
		rim.append(at + Vector3(cos(a) * (rr + 0.09), 0.008, sin(a) * (rr + 0.09)))
	for i in 12:
		var n := (i + 1) % 12
		k.made.tri(at + Vector3(0, 0.012, 0), ring[n], ring[i], P.BRINE[0])
		k.made.quad(ring[i], ring[n], rim[n], rim[i], P.SPRUCE[2])


static func _blind(k: Kit, s: int, lit: bool) -> void:
	# A platform up among the trunks on four poles, a screen of cut boughs
	# round it, a ladder, a tarp roof tied down.
	var fy := 1.3
	for sx: float in [-0.45, 0.45]:
		for sz: float in [-0.45, 0.45]:
			k.limb(Vector3(sx * 1.3, -0.05, sz * 1.3), Vector3(sx, fy + 0.8, sz), 0.045, 0.035, 5, P.EARTH[1])
	k.limb(Vector3(-0.58, 0.4, -0.58), Vector3(0.58, 0.9, 0.58), 0.025, 0.025, 4, P.EARTH[2])
	k.limb(Vector3(0.58, 0.4, -0.58), Vector3(-0.58, 0.9, 0.58), 0.025, 0.025, 4, P.EARTH[2])
	k.slab(0.0, fy, 0.0, 1.2, 0.06, 1.2, s, P.EARTH[2], P.EARTH[3], 0.02)
	for side in 4:
		var a := float(side) * PI * 0.5
		var out := Vector3(cos(a), 0, sin(a))
		var along := Vector3(-sin(a), 0, cos(a))
		for i in 5:
			var base := out * 0.6 + along * (-0.48 + i * 0.24) + Vector3(0, fy + 0.04, 0)
			k.blade(base, base + Vector3(0, 0.55 + Kit.j(s, side * 10 + i, 0.1), 0) + out * 0.08, 0.28, a + PI * 0.5, P.SPRUCE[2] if (i + side) % 2 else P.SPRUCE[1])
	# The shooting slot left open on the front.
	k.made.quad(Vector3(0.62, fy + 0.35, -0.2), Vector3(0.62, fy + 0.35, 0.2), Vector3(0.62, fy + 0.45, 0.2), Vector3(0.62, fy + 0.45, -0.2), P.INK[1])
	var ty := fy + 0.85
	both(k.made, Vector3(-0.7, ty, -0.7), Vector3(0.7, ty - 0.12, -0.7), Vector3(0.7, ty - 0.12, 0.7), Vector3(-0.7, ty, 0.7), P.EARTH[3].lerp(P.SPRUCE[3], 0.45))
	for i in 7:
		var y := i * 0.19
		k.limb(Vector3(0.95 - y * 0.2, y, -0.18), Vector3(0.95 - y * 0.2, y, 0.18), 0.016, 0.016, 4, P.EARTH[2])
	k.limb(Vector3(1.0, -0.05, -0.2), Vector3(0.66, fy, -0.2), 0.02, 0.02, 4, P.EARTH[1])
	k.limb(Vector3(1.0, -0.05, 0.2), Vector3(0.66, fy, 0.2), 0.02, 0.02, 4, P.EARTH[1])
	# Skins stretched on a frame by the ladder, and a bucket.
	k.made.quad(Vector3(-0.9, 0.1, 0.9), Vector3(-0.3, 0.1, 1.05), Vector3(-0.28, 0.75, 1.02), Vector3(-0.92, 0.7, 0.88), P.EARTH[3])
	if lit:
		_wired(k, Vector3(0.62, fy + 0.05, 0.25), Vector3(0.62, fy + 0.05, 0.55), Vector3(1, 0, 0), Vector3(0.0, ty, 0.0), NEON[0])


static func _pod(k: Kit, s: int, lit: bool) -> void:
	# An emergency shelter from before: a ribbed shell, once orange, half
	# under the snow, a hatch dug clear, a flue and a flag on a pole.
	var shell := P.RUST[3].lerp(P.LINEN[3], 0.45)
	var ribs := 7
	for i in ribs:
		var x0 := -1.1 + i * (2.2 / ribs)
		var x1 := x0 + 2.2 / ribs
		var col := shell if i % 2 == 0 else GroundColors.down(shell, 0.18)
		for j in 6:
			var a0 := PI * float(j) / 6.0
			var a1 := PI * float(j + 1) / 6.0
			var p0 := Vector3(0, sin(a0) * 0.9 - 0.2, cos(a0) * 0.9)
			var p1 := Vector3(0, sin(a1) * 0.9 - 0.2, cos(a1) * 0.9)
			k.made.quad(Vector3(x0, p0.y, p0.z), Vector3(x1, p0.y, p0.z), Vector3(x1, p1.y, p1.z), Vector3(x0, p1.y, p1.z), col)
	for i in 12:
		var a0 := PI * float(i) / 12.0
		var a1 := PI * float(i + 1) / 12.0
		k.fleck(Vector3(1.1, -0.2, 0), Vector3(1.1, sin(a0) * 0.9 - 0.2, cos(a0) * 0.9), Vector3(1.1, sin(a1) * 0.9 - 0.2, cos(a1) * 0.9), GroundColors.down(shell, 0.1))
	# The hatch on the end, the letters of an old aid mark worn to blocks.
	k.made.quad(Vector3(1.11, -0.1, 0.3), Vector3(1.11, -0.1, -0.3), Vector3(1.11, 0.5, -0.25), Vector3(1.11, 0.5, 0.25), P.INK[2])
	# An aid cross once, worn down to two pale bars on the flank.
	k.made.quad(Vector3(0.1, 0.52, 0.6), Vector3(0.6, 0.52, 0.6), Vector3(0.6, 0.62, 0.53), Vector3(0.1, 0.62, 0.53), P.LINEN[5])
	k.made.quad(Vector3(0.3, 0.38, 0.69), Vector3(0.4, 0.38, 0.69), Vector3(0.4, 0.76, 0.43), Vector3(0.3, 0.76, 0.43), P.LINEN[5])
	k.limb(Vector3(-0.4, 0.55, -0.3), Vector3(-0.38, 1.2, -0.3), 0.05, 0.045, 6, P.INK[2])
	patch(k, Vector3(-0.8, 0.55, -0.52), Vector3(-0.3, 0.65, -0.52), Vector3(-0.3, 0.3, -0.8), Vector3(-0.8, 0.2, -0.8), 3)
	k.limb(Vector3(1.4, -0.1, -0.7), Vector3(1.42, 1.6, -0.7), 0.025, 0.02, 4, P.SLATE[2])
	k.fleck(Vector3(1.42, 1.55, -0.7), Vector3(1.75, 1.45, -0.62), Vector3(1.42, 1.35, -0.7), P.RUST[3])
	banks(k, [[-0.9, 0.6, 0.8, 0.55], [0.0, 0.8, 0.9, 0.5], [-0.9, -0.6, 0.7, 0.45], [0.2, -0.85, 0.8, 0.4], [-1.3, 0.0, 0.6, 0.6], [1.3, 0.75, 0.4, 0.2]], P.RIME[5], s + 40)
	k.clump(-0.3, 0.45, 0.0, 0.7, 0.3, s + 50, P.RIME[5], 8)
	if lit:
		_wired(k, Vector3(1.12, 0.05, 0.42), Vector3(1.12, 0.05, 0.75), Vector3(1, 0, 0), Vector3(0.3, 0.68, 0.0), NEON[1])


static func _lean_to(k: Kit, s: int, lit: bool) -> void:
	# A dry-stone wall against a cast slab, tin laid across weighted with
	# stones, a barrel for water, a goat-hide door.
	var stone: Array[Color] = [P.LINEN[3], P.LINEN[2], P.LINEN[4], P.SAND[3]]
	PropModels.Houses.rubble_wall(k, Vector2(-0.9, -0.8), Vector2(0.9, -0.85), PackedFloat32Array([1.0, 1.05, 1.0, 0.95, 0.9, 0.85, 0.8]), 0.3, s, stone)
	PropModels.Houses.rubble_wall(k, Vector2(-0.95, -0.7), Vector2(-0.9, 0.8), PackedFloat32Array([1.0, 0.95, 0.9, 0.9, 0.85, 0.8, 0.75]), 0.3, s + 1, stone)
	PropModels.Houses.rubble_wall(k, Vector2(-0.8, 0.85), Vector2(0.2, 0.9), PackedFloat32Array([0.75, 0.7, 0.72, 0.6]), 0.28, s + 2, stone)
	corrugated(k.made, Vector3(-1.1, 1.08, -1.0), Vector3(0.0, 0.0, 2.05), Vector3(2.0, -0.35, 0.0), 11, P.RUST[3].lerp(P.LINEN[3], 0.3))
	k.made.quad(Vector3(-1.1, 1.08, -1.0), Vector3(0.9, 0.73, -1.0), Vector3(0.9, 0.73, 1.05), Vector3(-1.1, 1.08, 1.05), P.INK[2])
	for i in 4:
		k.stone(-0.6 + i * 0.4, 1.02 - i * 0.07, -0.4 + (i % 2) * 0.6, 0.12, 0.1, s + 10 + i, P.LINEN[4], 5)
	k.made.quad(Vector3(0.85, 0.0, 0.1), Vector3(0.85, 0.0, -0.55), Vector3(0.88, 0.72, -0.55), Vector3(0.88, 0.72, 0.1), P.EARTH[3])
	k.made.prism(1.25, 0.0, 0.6, 0.24, 0.62, 0.22, 9, P.RUST[2], P.INK[1])
	for i in 2:
		k.made.prism(1.25, 0.15 + i * 0.3, 0.6, 0.245, 0.18 + i * 0.3, 0.245, 9, P.INK[2])
	if lit:
		_wired(k, Vector3(0.9, 0.3, 0.2), Vector3(0.9, 0.3, 0.55), Vector3(1, 0, 0), Vector3(-0.2, 0.95, 0.0), NEON[2])
	banks(k, [[-0.4, -1.1, 0.5, 0.18], [0.8, -1.0, 0.4, 0.14]], P.LINEN[4].lerp(P.SAND[4], 0.4), s + 30)


static func _dugout(k: Kit, s: int, lit: bool) -> void:
	# Dug into the ash for the heat: a roof of machine plate on ribs, banked
	# over with ash, a heat shield of plate at the door, a pipe breathing.
	banks(k, [[-0.7, -0.7, 0.8, 0.5], [0.3, -0.8, 0.8, 0.45], [-0.8, 0.6, 0.8, 0.5], [0.4, 0.75, 0.7, 0.42], [-1.1, 0.0, 0.7, 0.6]], P.ASH[2], s + 1)
	for i in 4:
		var x := -0.8 + i * 0.5
		k.limb(Vector3(x, 0.1, -0.75), Vector3(x, 0.85, 0.0), 0.04, 0.035, 4, P.INK[2])
		k.limb(Vector3(x, 0.85, 0.0), Vector3(x, 0.1, 0.75), 0.035, 0.03, 4, P.INK[2])
	k.found.push(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)))
	plate_both(k, Vector3(-0.95, 0.35, -0.55), Vector3(0.75, 0.35, -0.55), Vector3(0.75, 0.9, 0.05), Vector3(-0.95, 0.9, 0.05), 2)
	plate_both(k, Vector3(0.75, 0.35, 0.55), Vector3(-0.95, 0.35, 0.55), Vector3(-0.95, 0.9, -0.03), Vector3(0.75, 0.9, -0.03), 3)
	k.found.pop()
	k.clump(-0.4, 0.6, 0.0, 0.6, 0.35, s + 5, P.ASH[2], 8)
	k.made.quad(Vector3(0.78, 0.0, 0.3), Vector3(0.78, 0.0, -0.3), Vector3(0.78, 0.6, -0.2), Vector3(0.78, 0.6, 0.2), P.INK[1])
	k.plate(Vector3(1.05, 0.0, -0.55), Vector3(1.05, 0.0, -0.2), Vector3(1.0, 0.75, -0.2), Vector3(1.0, 0.75, -0.55), P.PLATE[3], P.PLATE[1], P.PLATE[5])
	k.limb(Vector3(0.1, 0.8, 0.3), Vector3(0.15, 1.4, 0.32), 0.05, 0.05, 6, P.RUST[1])
	k.made.prism(0.15, 1.4, 0.32, 0.055, 1.42, 0.055, 6, P.INK[0], GroundColors.glow(P.EMBER[3], 0.8))
	if lit:
		_wired(k, Vector3(0.8, 0.1, 0.35), Vector3(0.8, 0.1, 0.6), Vector3(1, 0, 0), Vector3(-0.3, 0.9, 0.0), NEON[1])


# --- vehicles ------------------------------------------------------------------

## A car (0) or a van (1) from before, and what each landscape did to it:
## drowned at the tide line, sunk in the bog, grown over in the pines, buried
## in snow, scoured to primer in the bonelands, burnt out in the burning.
static func vehicle(k: Kit, v: int, c: int) -> void:
	var s := 21500 + v * 19 + c * 5
	# Body paint as it was, and how it lies now.
	var paint: Color = [P.SPRUCE[2].lerp(P.SLATE[3], 0.5), P.RUST[3].lerp(P.LINEN[3], 0.4), P.LINEN[3], P.SLATE[3]][(v + c) % 4]
	var sink := 0.0
	var tilt := Basis.IDENTITY
	var wheels := true
	var glass := P.SLATE[1].lerp(P.INK[2], 0.4)
	match c:
		Country.COAST:
			paint = paint.lerp(P.RUST[2], 0.45)
			sink = 0.14
			tilt = Basis(Vector3.BACK, -0.07) * Basis(Vector3.RIGHT, 0.06)
		Country.MOSS:
			paint = paint.lerp(P.EARTH[1], 0.55)
			sink = 0.38
			tilt = Basis(Vector3.BACK, 0.12) * Basis(Vector3.RIGHT, -0.1)
		Country.PINEWOOD:
			paint = paint.lerp(P.MOSS[1], 0.3)
			sink = 0.08
			tilt = Basis(Vector3.RIGHT, 0.05)
		Country.SNOWFIELD:
			sink = 0.1
		Country.BONELANDS:
			paint = P.LINEN[3].lerp(paint, 0.25)
			sink = 0.12
			wheels = false
			tilt = Basis(Vector3.RIGHT, -0.04)
		Country.BURNING:
			paint = P.STONE[1].lerp(P.RUST[1], 0.3)
			sink = 0.1
			wheels = false
			glass = P.INK[0]
	var van := v % 2 == 1
	var hw := 0.58 if van else 0.52
	# The lower body in side view (x along, y up), extruded straight: bumpers,
	# bonnet and boot are its top faces.
	var lower: Array[Vector2] = [Vector2(-1.25, 0.2), Vector2(-1.27, 0.55), Vector2(-1.12, 0.64), Vector2(0.62, 0.64), Vector2(1.18, 0.57), Vector2(1.28, 0.44), Vector2(1.26, 0.2)]
	if van:
		lower = [Vector2(-1.35, 0.22), Vector2(-1.36, 0.72), Vector2(-1.3, 0.76), Vector2(0.95, 0.76), Vector2(1.34, 0.66), Vector2(1.38, 0.28)]
	var belt := lower[2].y
	k.made.push(Transform3D(tilt, Vector3(0, -sink, 0)))
	var n := lower.size()
	for i in n:
		var j := (i + 1) % n
		var a := lower[i]
		var b := lower[j]
		var col := paint if i != n - 1 else P.INK[2]
		if i == 0 or i == n - 2:
			col = GroundColors.down(paint, 0.25)
		k.made.quad(Vector3(a.x, a.y, hw), Vector3(b.x, b.y, hw), Vector3(b.x, b.y, -hw), Vector3(a.x, a.y, -hw), col)
	var cen := Vector3(0.0, 0.42, 0.0)
	for i in n:
		var j := (i + 1) % n
		k.made.tri(Vector3(cen.x, cen.y, hw), Vector3(lower[j].x, lower[j].y, hw), Vector3(lower[i].x, lower[i].y, hw), paint)
		k.made.tri(Vector3(cen.x, cen.y, -hw), Vector3(lower[i].x, lower[i].y, -hw), Vector3(lower[j].x, lower[j].y, -hw), GroundColors.down(paint, 0.2))
	# The cabin: a tapered box on the belt, glass all round in a car, a panelled
	# load box with glass only at the front in a van.
	var cin := 0.08 if van else 0.15
	var base0 := lower[2].x + 0.04
	var base1 := 0.9 if van else 0.58
	var top0 := -1.3 if van else -0.74
	var top1 := 0.62 if van else 0.06
	var roof_y := 1.26 if van else 1.0
	var bz := hw - 0.03
	var tz := hw - cin
	var c0 := Vector3(base0, belt, bz)
	var c1 := Vector3(base1, belt, bz)
	var c2 := Vector3(top1, roof_y, tz)
	var c3 := Vector3(top0, roof_y, tz)
	var m := Vector3(1, 1, -1)
	var roof := GroundColors.up(paint, 0.22)
	k.made.quad(c3, c2, c2 * m, c3 * m, roof)
	# Screen and back glass.
	k.made.quad(c2, c1, c1 * m, c2 * m, glass)
	k.made.quad(c0, c3, c3 * m, c0 * m, glass if not van else GroundColors.down(paint, 0.2))
	k.made.quad(c0, c1, c2, c3, paint)
	k.made.quad(c1 * m, c0 * m, c3 * m, c2 * m, GroundColors.down(paint, 0.2))
	# A crack of pale light across the screen, and the roof's gutter line.
	k.made.quad(c1.lerp(c2, 0.3) + Vector3(0.012, 0.01, -0.3), c1.lerp(c2, 0.36) + Vector3(0.012, 0.01, -0.28), c1.lerp(c2, 0.72) + Vector3(0.012, 0.01, 0.1), c1.lerp(c2, 0.7) + Vector3(0.012, 0.01, 0.07), P.LINEN[2] if c != Country.BURNING else P.INK[2])
	for sz: float in [1.0, -1.0]:
		var q0 := c0 * Vector3(1, 1, sz)
		var q1 := c1 * Vector3(1, 1, sz)
		var q2 := c2 * Vector3(1, 1, sz)
		var q3 := c3 * Vector3(1, 1, sz)
		var nrm := (q1 - q0).cross(q3 - q0).normalized() * (0.012 * sz)
		var u0 := 0.62 if van else 0.08
		var u1 := 0.94 if van else 0.92
		var lo := 0.14
		var hi := 0.86
		var wa := q0.lerp(q1, u0).lerp(q3.lerp(q2, u0), lo) + nrm
		var wb := q0.lerp(q1, u1).lerp(q3.lerp(q2, u1), lo) + nrm
		var wc := q0.lerp(q1, u1).lerp(q3.lerp(q2, u1), hi) + nrm
		var wd := q0.lerp(q1, u0).lerp(q3.lerp(q2, u0), hi) + nrm
		if sz > 0.0:
			k.made.quad(wa, wb, wc, wd, glass)
		else:
			k.made.quad(wb, wa, wd, wc, glass)
		if not van:
			# The door pillar between the two lights.
			var pa := q0.lerp(q1, 0.5).lerp(q3.lerp(q2, 0.5), lo) + nrm * 1.6
			var pb := q0.lerp(q1, 0.56).lerp(q3.lerp(q2, 0.56), lo) + nrm * 1.6
			var pc := q0.lerp(q1, 0.56).lerp(q3.lerp(q2, 0.56), hi) + nrm * 1.6
			var pd := q0.lerp(q1, 0.5).lerp(q3.lerp(q2, 0.5), hi) + nrm * 1.6
			if sz > 0.0:
				k.made.quad(pa, pb, pc, pd, paint)
			else:
				k.made.quad(pb, pa, pd, pc, paint)
		var fz := (hw + 0.012) * sz
		# Wheel arches, a door seam, rust blooming along the sill.
		for wx: float in [-0.8, 0.8]:
			for e in 5:
				var a0 := PI * float(e) / 5.0
				var a1 := PI * float(e + 1) / 5.0
				var p0 := Vector3(wx + cos(a0) * 0.27, 0.2 + sin(a0) * 0.25, fz)
				var p1 := Vector3(wx + cos(a1) * 0.27, 0.2 + sin(a1) * 0.25, fz)
				if sz > 0.0:
					k.made.tri(Vector3(wx, 0.2, fz), p0, p1, P.INK[1])
				else:
					k.made.tri(Vector3(wx, 0.2, fz), p1, p0, P.INK[1])
		var sa := Vector3(-0.5, 0.21, fz * 1.01)
		var sb := Vector3(0.45, 0.21, fz * 1.01)
		if sz > 0.0:
			k.made.quad(sa, sb, sb + Vector3(-0.1, 0.12, 0), sa + Vector3(0.12, 0.1, 0), P.RUST[2])
			k.made.quad(Vector3(0.2, 0.26, fz * 1.02), Vector3(0.225, 0.26, fz * 1.02), Vector3(0.225, belt - 0.02, fz * 1.02), Vector3(0.2, belt - 0.02, fz * 1.02), P.INK[2])
		else:
			k.made.quad(sb, sa, sa + Vector3(0.12, 0.1, 0), sb + Vector3(-0.1, 0.12, 0), P.RUST[2])
	# Lamps: dead headlights, the red of a tail light.
	var nose := lower[n - 2].x + 0.012
	var tail := lower[1].x - 0.012
	for sz: float in [0.32, -0.32]:
		k.made.quad(Vector3(nose, 0.4, sz - 0.1), Vector3(nose, 0.4, sz + 0.1), Vector3(nose, 0.5, sz + 0.1), Vector3(nose, 0.5, sz - 0.1), P.LINEN[2])
		k.made.quad(Vector3(tail, 0.46, sz + 0.1), Vector3(tail, 0.46, sz - 0.1), Vector3(tail, 0.54, sz - 0.1), Vector3(tail, 0.54, sz + 0.1), P.RUST[1])
	if wheels:
		for wx: float in [-0.8, 0.8]:
			for wz: float in [hw - 0.04, -hw + 0.04]:
				wheel(k, Vector3(wx, 0.21, wz), 0.21, 0.15, P.INK[2], P.STONE[2])
	else:
		for wx: float in [-0.8, 0.8]:
			for wz: float in [hw - 0.06, -hw + 0.06]:
				k.made.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(wx, 0.15, wz - 0.04)))
				k.made.prism(0, 0, 0, 0.13, 0.08, 0.13, 7, P.RUST[1], P.STONE[1])
				k.made.pop()
	if c == Country.BURNING:
		# Burnt through: the roof buckled, the paint blistered to rust.
		for i in 3:
			var x := top0 + 0.1 + i * (top1 - top0 - 0.2) / 3.0
			k.made.quad(Vector3(x, roof_y + 0.012, -0.2), Vector3(x + 0.2, roof_y + 0.012, -0.22), Vector3(x + 0.18, roof_y + 0.012, 0.18), Vector3(x - 0.04, roof_y + 0.012, 0.24), P.RUST[1] if i % 2 else P.INK[1])
	k.made.pop()
	# What the land did.
	var d := drift_of(c)
	match c:
		Country.COAST:
			banks(k, [[-1.2, 0.5, 0.5, 0.3], [0.9, 0.55, 0.45, 0.26], [-0.2, -0.65, 0.6, 0.22], [1.3, -0.3, 0.35, 0.2]], d[0], s + 60)
			for i in 6:
				var x := -0.9 + i * 0.35
				var y := roof_y - sink + 0.02 if absf(x) < 0.4 else 0.6 - sink
				k.made.quad(Vector3(x, y, -0.4), Vector3(x + 0.08, y, -0.4), Vector3(x + 0.14, y - 0.35, -0.62), Vector3(x + 0.02, y - 0.3, -0.62), P.EARTH[1] if i % 2 else P.SPRUCE[1])
			streak(k, Vector3(0.6, 0.5 - sink, hw + 0.02), 0.2, 0.3, Vector3(0, 0, 1))
		Country.MOSS:
			_pool(k, Vector3(0.0, 0.0, 0.0), 1.55, s + 70)
			var rs := k.made.vertex_count()
			for i in 10:
				var a := float(i) * 0.9
				var base := Vector3(cos(a) * (1.3 + Kit.j(s, i, 0.2)), 0.0, sin(a) * 0.95)
				k.blade(base, base + Vector3(0.05, 0.75 + Kit.j(s, i + 20, 0.2), 0.0), 0.06, a, P.SPRUCE[3] if i % 2 else P.MOSS[3])
			k.sway_by_height(rs, 0.0, 0.8, 0.6)
			k.made.quad(Vector3(-1.2, 0.2, hw + 0.03), Vector3(1.2, 0.08, hw + 0.03), Vector3(1.2, 0.14, hw + 0.03), Vector3(-1.2, 0.26, hw + 0.03), P.MOSS[3])
		Country.PINEWOOD:
			k.clump(-0.3, roof_y - sink - 0.1, 0.0, 0.45, 0.2, s + 80, P.MOSS[2], 7)
			k.clump(0.9, 0.5 - sink, 0.1, 0.25, 0.12, s + 81, P.MOSS[3], 6)
			k.limb(Vector3(-1.6, 0.05, 0.9), Vector3(0.6, roof_y + 0.1, -0.2), 0.05, 0.02, 5, P.EARTH[1])
			banks(k, [[1.2, 0.5, 0.35, 0.15], [-1.1, -0.6, 0.4, 0.14]], d[0], s + 82)
		Country.SNOWFIELD:
			banks(k, [[-0.7, 0.75, 0.8, 0.75], [0.4, 0.8, 0.8, 0.7], [1.3, 0.4, 0.6, 0.55], [-1.4, 0.2, 0.6, 0.6], [0.1, -0.7, 0.6, 0.35], [1.0, -0.5, 0.45, 0.3]], P.RIME[5], s + 90)
			k.clump(-0.3, roof_y - sink - 0.08, 0.0, 0.6, 0.22, s + 95, P.RIME[5], 8)
			k.clump(0.9, 0.52 - sink, 0.0, 0.35, 0.12, s + 96, P.RIME[5], 7)
		Country.BONELANDS:
			banks(k, [[-0.6, 0.75, 0.7, 0.35], [0.6, 0.7, 0.6, 0.3], [1.4, 0.2, 0.4, 0.2]], d[0], s + 100)
			for i in 9:
				var p := Vector3(-1.0 + i * 0.25, 0.35 + Kit.j(s, i, 0.15), hw + 0.014)
				k.made.quad(p, p + Vector3(0.04, 0, 0), p + Vector3(0.04, 0.03, 0), p + Vector3(0, 0.03, 0), P.RUST[2])
		Country.BURNING:
			banks(k, [[-0.9, 0.65, 0.55, 0.26], [0.7, -0.7, 0.6, 0.24], [1.4, 0.3, 0.35, 0.16]], P.ASH[2], s + 110)


# --- the coast's dead fleet and its wall ---------------------------------------

## A trawler beached years ago. 0: heeled over on the sand, nets still on her
## gantry; 1: broken in two, the stern swung away, ribs showing in the gap.
static func hull(k: Kit, v: int, c: int) -> void:
	var s := 22000 + v * 23 + c
	var drift := drift_of(c)
	if v % 2 == 0:
		k.made.push(Transform3D(Basis(Vector3.RIGHT, 0.42) * Basis(Vector3.BACK, 0.06), Vector3(0.0, -0.3, 0.0)))
		_hull_part(k, 0, 8, s, true)
		k.made.pop()
		banks(k, [[-1.5, -0.95, 0.55, 0.32], [0.1, -1.1, 0.6, 0.34], [1.5, -0.8, 0.5, 0.26], [-2.3, 0.3, 0.4, 0.2], [0.6, 1.0, 0.45, 0.16]], drift[0], s + 50)
	else:
		k.made.push(Transform3D(Basis(Vector3.RIGHT, 0.18) * Basis(Vector3.BACK, 0.1), Vector3(0.55, -0.3, 0.0)))
		_hull_part(k, 3, 8, s, false)
		k.made.pop()
		k.made.push(Transform3D(Basis(Vector3.UP, 0.55) * Basis(Vector3.RIGHT, -0.34), Vector3(-0.9, -0.3, 0.55)))
		_hull_part(k, 0, 4, s + 1, true)
		k.made.pop()
		banks(k, [[-1.8, 1.3, 0.5, 0.3], [0.5, -1.0, 0.55, 0.3], [1.9, -0.7, 0.45, 0.24], [-0.3, 0.25, 0.4, 0.2], [2.5, 0.4, 0.35, 0.18]], drift[0], s + 60)
		# Plates and a winch drum spilled from the break.
		k.slab(-0.2, -0.05, -0.9, 0.5, 0.05, 0.3, s + 70, P.RUST[2], P.RUST[3], 0.02)
		k.made.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.2, 0.18, 1.2)))
		k.made.prism(0, 0, 0, 0.2, 0.35, 0.2, 8, P.RUST[1], P.INK[2])
		k.made.pop()


## Hull stations: x, half beam, keel y, sheer y.
const _STATIONS: Array[Vector4] = [
	Vector4(-2.1, 0.62, 0.05, 1.12), Vector4(-1.6, 0.74, -0.14, 1.06), Vector4(-0.8, 0.8, -0.3, 1.02),
	Vector4(0.0, 0.8, -0.33, 1.02), Vector4(0.8, 0.74, -0.3, 1.08), Vector4(1.5, 0.56, -0.2, 1.2),
	Vector4(2.0, 0.3, -0.04, 1.34), Vector4(2.35, 0.02, 0.2, 1.48),
]


## Stations [from, to) of the hull, plated, with a wheelhouse, gantry and nets
## if `stern` and the stern is in range; an open torn end gets ribs.
static func _hull_part(k: Kit, from: int, to: int, s: int, stern: bool) -> void:
	var hullc := P.INK[3].lerp(P.BRINE[1], 0.35)
	var bottom := P.RUST[1]
	var band := P.LINEN[3]
	var rings: Array = []
	for si in range(from, to):
		var st := _STATIONS[si]
		var b := st.y
		var kl := st.z
		var sh := st.w
		var pts: Array[Vector3] = []
		# One side keel to sheer, then the other sheer to keel.
		for q: Vector2 in [Vector2(0.0, 0.0), Vector2(0.55, 0.12), Vector2(0.95, 0.5), Vector2(1.0, 0.86), Vector2(0.97, 1.0)]:
			pts.append(Vector3(st.x, lerpf(kl, sh, q.y), b * q.x))
		rings.append(pts)
	for r in rings.size() - 1:
		var a: Array[Vector3] = rings[r]
		var bb: Array[Vector3] = rings[r + 1]
		for e in a.size() - 1:
			for sgn: float in [1.0, -1.0]:
				var p0 := a[e] * Vector3(1, 1, sgn)
				var p1 := a[e + 1] * Vector3(1, 1, sgn)
				var q0 := bb[e] * Vector3(1, 1, sgn)
				var q1 := bb[e + 1] * Vector3(1, 1, sgn)
				# Strakes of rust and bare plate by turns below the waterline.
				var col := (bottom if (r + from) % 2 == 0 else P.RUST[2]) if e <= 1 else (band if e == 3 else hullc)
				if e == 2 and (r + from) % 3 == 1:
					col = hullc.lerp(P.RUST[2], 0.5)
				if sgn > 0.0:
					k.made.quad(p0, q0, q1, p1, col)
				else:
					k.made.quad(p1, q1, q0, p0, GroundColors.down(col, 0.15))
		# The deck between the sheers.
		var ds := a[4] + Vector3(0, -0.04, 0)
		var dq := bb[4] + Vector3(0, -0.04, 0)
		k.made.quad(ds, dq, dq * Vector3(1, 1, -1), ds * Vector3(1, 1, -1), P.EARTH[2])
		# Planks gone grey in lines along the deck, a hatch left open on it.
		for pz: float in [-0.3, 0.0, 0.3]:
			var a0 := Vector3(ds.x, ds.y + 0.012, ds.z * pz)
			var a1 := Vector3(dq.x, dq.y + 0.012, dq.z * pz)
			k.made.quad(a0 + Vector3(0, 0, 0.02), a1 + Vector3(0, 0, 0.02), a1 - Vector3(0, 0, 0.02), a0 - Vector3(0, 0, 0.02), P.EARTH[1])
		if (r + from) % 3 == 2:
			var hc := ds.lerp(dq, 0.5) + Vector3(0, 0.02, 0)
			k.made.quad(hc + Vector3(-0.18, 0, 0.2), hc + Vector3(0.18, 0, 0.2), hc + Vector3(0.18, 0, -0.2), hc + Vector3(-0.18, 0, -0.2), P.INK[1])
		# Rust weeping from the scuppers down the topsides.
		if r % 2 == 0:
			var mid := a[4].lerp(bb[4], 0.5)
			streak(k, mid + Vector3(0, -0.05, 0.02), 0.12, 0.55, Vector3(0, 0, 1))
	# Ends: the stern transom, the stem, or a torn edge with ribs.
	var first: Array[Vector3] = rings[0]
	var last: Array[Vector3] = rings[rings.size() - 1]
	if from == 0:
		for e in first.size() - 1:
			k.made.quad(first[e + 1] * Vector3(1, 1, -1), first[e] * Vector3(1, 1, -1), first[e], first[e + 1], GroundColors.down(hullc, 0.3))
	else:
		_torn(k, first, s)
	if to < _STATIONS.size():
		_torn(k, last, s + 3)
	if stern and from == 0:
		# The wheelhouse, its windows out, a gantry over the stern with the
		# net still hanging from it.
		k.slab(-0.9, 1.0, 0.0, 0.9, 0.72, 0.9, s + 10, P.LINEN[3], P.LINEN[4], 0.02, 0.06)
		k.slab(-0.9, 1.72, 0.0, 1.05, 0.08, 1.02, s + 11, P.INK[2], P.RUST[2], 0.02)
		for i in 3:
			var z := -0.3 + i * 0.3
			k.made.quad(Vector3(-0.44, 1.35, z - 0.1), Vector3(-0.44, 1.35, z + 0.1), Vector3(-0.45, 1.6, z + 0.1), Vector3(-0.45, 1.6, z - 0.1), P.INK[1])
		k.made.quad(Vector3(-1.2, 1.35, 0.465), Vector3(-0.6, 1.35, 0.465), Vector3(-0.6, 1.58, 0.465), Vector3(-1.2, 1.58, 0.465), P.INK[1])
		streak(k, Vector3(-0.7, 1.3, 0.47), 0.1, 0.3, Vector3(0, 0, 1))
		k.limb(Vector3(-1.95, 1.05, 0.55), Vector3(-2.2, 2.3, 0.1), 0.04, 0.035, 5, P.RUST[3])
		k.limb(Vector3(-1.95, 1.05, -0.55), Vector3(-2.2, 2.3, -0.1), 0.04, 0.035, 5, P.RUST[3])
		k.limb(Vector3(-2.2, 2.3, -0.12), Vector3(-2.2, 2.3, 0.12), 0.035, 0.035, 4, P.RUST[2])
		for i in 6:
			var z := -0.3 + i * 0.12
			k.made.quad(Vector3(-2.2, 2.28, z), Vector3(-2.2, 2.28, z + 0.12), Vector3(-2.45 + Kit.j(s, i, 0.05), 0.9, z + 0.14), Vector3(-2.4, 0.95, z), P.SLATE[1] if i % 2 else P.INK[3])
		for i in 4:
			k.fleck(Vector3(-2.3, 1.7 - i * 0.2, -0.3 + i * 0.2), Vector3(-2.33, 1.62 - i * 0.2, -0.24 + i * 0.2), Vector3(-2.28, 1.66 - i * 0.2, -0.2 + i * 0.2), P.RUST[4])
		k.limb(Vector3(-0.2, 1.0, 0.0), Vector3(0.1, 2.6, 0.0), 0.04, 0.03, 5, P.RUST[2])
		k.limb(Vector3(0.05, 2.2, 0.0), Vector3(1.3, 1.1, 0.0), 0.02, 0.02, 4, P.RUST[2])
	# A hull number in white, three blocks weathered down to marks.
	if to >= 7:
		for i in 3:
			var x := 1.35 + i * 0.16
			k.made.quad(Vector3(x, 0.72, 0.62 - i * 0.07), Vector3(x + 0.1, 0.72, 0.6 - i * 0.07), Vector3(x + 0.1, 0.92, 0.6 - i * 0.07), Vector3(x, 0.92, 0.62 - i * 0.07), P.LINEN[4])


## A torn end: ragged plate edges and ribs standing out of it.
static func _torn(k: Kit, ring: Array[Vector3], s: int) -> void:
	for e in ring.size() - 1:
		for sgn: float in [1.0, -1.0]:
			var a := ring[e] * Vector3(1, 1, sgn)
			var b := ring[e + 1] * Vector3(1, 1, sgn)
			k.limb(a, b, 0.035, 0.035, 4, P.RUST[1])
			var tip := a.lerp(b, 0.5) + Vector3(0.18 + Kit.j(s, e, 0.1), Kit.j(s, e + 10, 0.1), 0.0)
			k.fleck(a, b, tip, P.RUST[2])


## A sea wall. 0: a standing length of cast wall with its wave-return lip, a
## bent rail, chevrons nobody reads, bars out of both broken ends; 1: the wall
## gone, blocks tumbled and the breakwater's cast tetrapods thrown up the beach.
static func sea_wall(k: Kit, v: int, c: int) -> void:
	var s := 22500 + v * 29 + c
	var concrete := P.STONE[3].lerp(P.LINEN[3], 0.4)
	if c == Country.SNOWFIELD:
		concrete = P.SLATE[3]
	if v % 2 == 0:
		# Profile across the wall (z seaward +), extruded along x in lengths
		# whose tops break down at both ends.
		var prof: Array[Vector2] = [Vector2(-0.4, -0.1), Vector2(-0.34, 1.12), Vector2(0.18, 1.12), Vector2(0.42, 1.04), Vector2(0.32, 0.92), Vector2(0.26, 0.62), Vector2(0.36, 0.3), Vector2(0.46, -0.1)]
		var xs: Array[float] = [-1.35, -0.9, -0.45, 0.0, 0.45, 0.9, 1.35]
		var drop: Array[float] = [0.55, 0.12, 0.0, 0.0, 0.05, 0.3, 0.7]
		for i in xs.size() - 1:
			for e in prof.size() - 1:
				var a := prof[e]
				var b := prof[e + 1]
				var ay := minf(a.y, 1.12 - drop[i]) if a.y > 0.0 else a.y
				var by := minf(b.y, 1.12 - drop[i]) if b.y > 0.0 else b.y
				var ay2 := minf(a.y, 1.12 - drop[i + 1]) if a.y > 0.0 else a.y
				var by2 := minf(b.y, 1.12 - drop[i + 1]) if b.y > 0.0 else b.y
				var col := concrete if e != 1 else GroundColors.up(concrete, 0.2)
				if e >= 4 and e <= 6:
					col = GroundColors.down(concrete, 0.25)
				k.made.quad(Vector3(xs[i], by, b.x), Vector3(xs[i + 1], by2, b.x), Vector3(xs[i + 1], ay2, a.x), Vector3(xs[i], ay, a.x), col)
			# A dark weed line along the foot of the sea face.
			k.made.quad(Vector3(xs[i], -0.05, 0.475), Vector3(xs[i + 1], -0.05, 0.475), Vector3(xs[i + 1], 0.3, 0.375), Vector3(xs[i], 0.3, 0.375), P.SPRUCE[1])
		for endi: int in [0, xs.size() - 1]:
			var x := xs[endi]
			var top := 1.12 - drop[endi]
			var sgn := -1.0 if endi == 0 else 1.0
			both(k.made, Vector3(x, -0.1, -0.4), Vector3(x, -0.1, 0.46), Vector3(x, minf(top, 0.62), 0.26), Vector3(x, top, -0.34), GroundColors.down(concrete, 0.4) if sgn > 0.0 else GroundColors.down(concrete, 0.1))
			for b in 3:
				var root := Vector3(x, top * (0.35 + b * 0.2), -0.25 + b * 0.22)
				k.limb(root, root + Vector3(sgn * (0.25 + Kit.j(s, b + endi, 0.1)), 0.18 + Kit.j(s, b + endi + 5, 0.1), 0.06), 0.014, 0.01, 4, P.RUST[2])
		# Chevrons on the landward face, faded to a rumour.
		for i in 5:
			var x := -0.7 + i * 0.32
			k.made.quad(Vector3(x + 0.1, 0.75, -0.372), Vector3(x + 0.22, 0.75, -0.372), Vector3(x + 0.12, 0.3, -0.397), Vector3(x, 0.3, -0.397), P.RUST[3].lerp(concrete, 0.4) if i % 2 == 0 else P.LINEN[4].lerp(concrete, 0.3))
		# The rail: posts and a top bar, bent down where something hit it.
		var rail := P.RUST[2]
		for i in 5:
			var x := -0.7 + i * 0.35
			k.limb(Vector3(x, 1.1, -0.15), Vector3(x + (0.15 if i == 3 else 0.0), 1.55 - (0.2 if i == 3 else 0.0), -0.15 + (0.2 if i == 3 else 0.0)), 0.018, 0.016, 4, rail)
		k.sag(Vector3(-0.7, 1.55, -0.15), Vector3(0.35, 1.55, -0.15), 0.0, 3, 0.014, rail)
		k.sag(Vector3(0.35, 1.55, -0.15), Vector3(0.7, 1.35, 0.05), 0.02, 2, 0.014, rail)
		k.sag(Vector3(0.7, 1.35, 0.05), Vector3(0.7, 1.55, -0.15), 0.0, 1, 0.014, rail)
		for i in 7:
			k.fleck(Vector3(-1.0 + i * 0.3, 0.15 + (i % 3) * 0.06, 0.44), Vector3(-0.97 + i * 0.3, 0.19 + (i % 3) * 0.06, 0.45), Vector3(-1.02 + i * 0.3, 0.2 + (i % 3) * 0.06, 0.44), P.LINEN[5])
	else:
		k.made.push(Transform3D(Basis(Vector3.UP, 0.3) * Basis(Vector3.BACK, 0.5), Vector3(-0.7, 0.1, -0.2)))
		k.slab(0.0, 0.0, 0.0, 1.1, 0.8, 0.7, s, concrete, GroundColors.up(concrete, 0.2), 0.04, 0.05)
		k.made.pop()
		k.made.push(Transform3D(Basis(Vector3.UP, -0.5) * Basis(Vector3.RIGHT, 0.35), Vector3(0.6, -0.05, 0.35)))
		k.slab(0.0, 0.0, 0.0, 0.9, 0.55, 0.6, s + 1, GroundColors.down(concrete, 0.1), concrete, 0.04, 0.08)
		k.made.pop()
		for i in 3:
			_tetrapod(k, Vector3(-0.9 + i * 0.95, 0.25, 0.9 - (i % 2) * 0.45), 0.42, s + 10 + i, concrete)
		k.limb(Vector3(0.3, 0.4, 0.3), Vector3(0.8, 1.0, 0.1), 0.016, 0.012, 4, P.RUST[2])
	banks(k, [[-1.2, 0.6, 0.45, 0.2], [0.5, 0.7, 0.55, 0.18], [1.3, -0.5, 0.4, 0.14]], drift_of(c)[0], s + 40)


## A cast breakwater tetrapod: four tapered legs from a knot.
static func _tetrapod(k: Kit, at: Vector3, size: float, s: int, col: Color) -> void:
	var dirs: Array[Vector3] = [Vector3(0, 1, 0), Vector3(0.94, -0.33, 0), Vector3(-0.47, -0.33, 0.82), Vector3(-0.47, -0.33, -0.82)]
	var rot := Basis(Vector3.UP, Rng.hash01(s, 1) * TAU) * Basis(Vector3.RIGHT, Rng.hash01(s, 2) * 0.8)
	for i in 4:
		var d := rot * dirs[i]
		k.limb(at, at + d * size, size * 0.3, size * 0.16, 6, col if i % 2 == 0 else GroundColors.down(col, 0.15))


# --- the pinewood's order and its watch ----------------------------------------

## A stump sawn flat by a harvester's head, standing in its exact row. 0: bare,
## 1: with its log bucked and left, 2: with brash thrown over it.
static func stump(k: Kit, v: int, c: int) -> void:
	var s := 23000 + v * 7 + c
	var bark := P.EARTH[1] if c != Country.BURNING else P.INK[2]
	var face := P.LINEN[4].lerp(P.SAND[4], 0.3) if c != Country.BURNING else P.STONE[1]
	var r := 0.2 + v * 0.02
	k.made.prism(0, -0.05, 0, r * 1.2, 0.08, r, 8, bark)
	k.made.prism(0, 0.08, 0, r, 0.26, r * 0.95, 8, bark, face)
	# The saw's face: rings, and the dark heart.
	k.made.prism(0.0, 0.261, 0.0, r * 0.62, 0.263, r * 0.62, 8, face, GroundColors.down(face, 0.15))
	k.made.prism(0.0, 0.264, 0.0, r * 0.25, 0.266, r * 0.25, 6, face, P.EARTH[3])
	for i in 4:
		var a := float(i) / 4.0 * TAU + 0.4
		k.limb(Vector3(cos(a) * r * 0.8, 0.06, sin(a) * r * 0.8), Vector3(cos(a) * r * 1.55, -0.03, sin(a) * r * 1.55), 0.07, 0.04, 4, bark)
	match v % 3:
		1:
			k.made.push(Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.2, 0.0, 0.55)))
			k.limb(Vector3(-0.55, 0.13, 0), Vector3(0.55, 0.12, 0), 0.14, 0.12, 7, P.EARTH[2] if c != Country.BURNING else P.INK[2])
			k.made.push(Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.71, 0.135, 0.0)))
			k.made.prism(0, 0, 0, 0.13, 0.01, 0.13, 7, face, face)
			k.made.pop()
			k.made.pop()
		2:
			var bs := k.made.vertex_count()
			for i in 7:
				var a := Kit.j(s, i, 1.8) + i * 0.9
				var from := Vector3(cos(a) * 0.3, 0.05 + i * 0.02, sin(a) * 0.3)
				k.limb(from, from + Vector3(cos(a + 0.4) * 0.42, 0.04, sin(a + 0.4) * 0.42), 0.03, 0.014, 3, P.EARTH[2])
				if c != Country.BURNING:
					k.clump(from.x + cos(a + 0.4) * 0.36, 0.0, from.z + sin(a + 0.4) * 0.36, 0.13, 0.08, s + 40 + i, P.EARTH[3] if i % 2 else P.RUST[2], 5)
			k.sway_by_height(bs, 0.0, 0.3, 0.05)
	if c == Country.SNOWFIELD:
		k.clump(0.0, 0.2, 0.0, r * 0.9, 0.1, s + 5, P.RIME[5], 6)


## A fire tower of timber: four legs raking in, braces, a cabin at the top
## with its windows on every side. 1: the cabin burnt out and a leg gone, the
## whole thing leaning.
static func fire_tower(k: Kit, v: int, c: int) -> void:
	var s := 23500 + v * 13 + c
	var wood := wood_of(c)
	var top := 4.2
	var lean := Basis.IDENTITY if v % 2 == 0 else Basis(Vector3.BACK, -0.12) * Basis(Vector3.RIGHT, 0.06)
	k.made.push(Transform3D(lean, Vector3.ZERO))
	var feet: Array[Vector2] = [Vector2(-0.75, -0.75), Vector2(0.75, -0.75), Vector2(0.75, 0.75), Vector2(-0.75, 0.75)]
	var levels: Array[float] = [0.0, 1.1, 2.2, 3.2, top]
	for i in 4:
		var f := feet[i]
		var g := feet[(i + 1) % 4]
		if v % 2 == 1 and i == 2:
			k.limb(Vector3(f.x, -0.05, f.y), Vector3(f.x * 0.8, 1.6, f.y * 0.8), 0.06, 0.05, 5, P.INK[2])
		else:
			k.limb(Vector3(f.x, -0.05, f.y), Vector3(f.x * 0.45, top, f.y * 0.45), 0.065, 0.05, 5, wood[i % 2])
		for li in levels.size() - 1:
			var y0 := levels[li]
			var y1 := levels[li + 1]
			var k0 := 1.0 - y0 / top * 0.55
			var k1 := 1.0 - y1 / top * 0.55
			if v % 2 == 1 and i == 2 and li > 0:
				continue
			k.limb(Vector3(f.x * k0, y0 + 0.1, f.y * k0), Vector3(g.x * k1, y1, g.y * k1), 0.025, 0.025, 4, wood[1])
			k.limb(Vector3(f.x * k1, y1, f.y * k1), Vector3(g.x * k1, y1, g.y * k1), 0.025, 0.025, 4, wood[0])
	# Stairs as a zigzag of flights inside.
	for i in 6:
		var y := 0.3 + i * 0.62
		var sgn := 1.0 if i % 2 == 0 else -1.0
		k.limb(Vector3(-0.35 * sgn, y, 0.1), Vector3(0.35 * sgn, y + 0.6, 0.1), 0.03, 0.03, 4, wood[0])
	# The cabin.
	var cy := top
	k.slab(0.0, cy, 0.0, 1.0, 0.06, 1.0, s, wood[0], wood[1], 0.02)
	if v % 2 == 0:
		for side in 4:
			var a := float(side) * PI * 0.5
			var out := Vector3(cos(a), 0, sin(a)) * 0.48
			var along := Vector3(-sin(a), 0, cos(a)) * 0.48
			k.made.quad(out - along + Vector3(0, cy + 0.06, 0), out + along + Vector3(0, cy + 0.06, 0), out + along + Vector3(0, cy + 0.42, 0), out - along + Vector3(0, cy + 0.42, 0), wood[1] if side % 2 else wood[0])
			k.made.quad(out * 1.01 - along * 0.85 + Vector3(0, cy + 0.44, 0), out * 1.01 + along * 0.85 + Vector3(0, cy + 0.44, 0), out * 1.01 + along * 0.85 + Vector3(0, cy + 0.8, 0), out * 1.01 - along * 0.85 + Vector3(0, cy + 0.8, 0), P.INK[1])
			k.limb(out - along + Vector3(0, cy + 0.42, 0), out - along + Vector3(0, cy + 0.86, 0), 0.02, 0.02, 4, wood[1])
		k.made.push(Transform3D(Basis.IDENTITY, Vector3(0, cy + 0.86, 0)))
		k.made.prism(0, 0, 0, 0.8, 0.45, 0.0, 4, P.SLATE[1], Color(0, 0, 0, 0), PI * 0.25)
		k.made.pop()
		# A lookout's lamp left on the sill: one of the few that still burn.
		k.made.prism(0.35, cy + 0.44, 0.2, 0.04, cy + 0.54, 0.035, 6, GroundColors.lamp(P.COPPER[4], 1.3))
		if c == Country.SNOWFIELD:
			k.clump(0.0, cy + 1.05, 0.0, 0.55, 0.18, s + 3, P.RIME[5], 7)
	else:
		for side in 3:
			var a := float(side) * PI * 0.5
			var out := Vector3(cos(a), 0, sin(a)) * 0.48
			var along := Vector3(-sin(a), 0, cos(a)) * 0.48
			k.made.quad(out - along + Vector3(0, cy + 0.06, 0), out + along * 0.4 + Vector3(0, cy + 0.06, 0), out + along * 0.2 + Vector3(0, cy + 0.3 + side * 0.08, 0), out - along + Vector3(0, cy + 0.5, 0), P.INK[2])
		k.limb(Vector3(0.45, cy + 0.06, 0.45), Vector3(0.3, cy + 0.9, 0.2), 0.03, 0.02, 4, P.INK[2])
	k.made.pop()
	if v % 2 == 1:
		k.slab(1.2, -0.05, 0.8, 0.8, 0.1, 0.7, s + 20, P.INK[2], P.STONE[1], 0.08, 0.1)
		k.limb(Vector3(0.9, 0.0, 1.3), Vector3(1.9, 0.08, 0.5), 0.05, 0.04, 5, P.INK[2])


# --- water and slag ------------------------------------------------------------

## Water kept where there is none. 0: a riveted tank on a timber stand with a
## ladder and a pipe down to a trough; 1: a cast cistern capped with machine
## plate, a tap, and the buckets waiting their turn.
static func water_tank(k: Kit, v: int, c: int) -> void:
	var s := 24000 + v * 11 + c
	var wood := wood_of(c)
	if v % 2 == 0:
		for sx: float in [-0.45, 0.45]:
			for sz: float in [-0.45, 0.45]:
				k.limb(Vector3(sx * 1.15, -0.05, sz * 1.15), Vector3(sx, 1.2, sz), 0.05, 0.045, 5, wood[0])
		k.limb(Vector3(-0.52, 0.5, -0.52), Vector3(0.52, 1.0, 0.52), 0.025, 0.025, 4, wood[1])
		k.limb(Vector3(0.52, 0.5, -0.52), Vector3(-0.52, 1.0, 0.52), 0.025, 0.025, 4, wood[1])
		k.slab(0.0, 1.2, 0.0, 1.15, 0.06, 1.15, s, wood[1], wood[0], 0.02)
		var tank := P.RUST[2].lerp(P.SLATE[2], 0.3)
		k.made.prism(0, 1.26, 0, 0.62, 2.1, 0.62, 12, tank, GroundColors.up(tank, 0.1))
		k.made.prism(0, 2.1, 0, 0.64, 2.25, 0.0, 12, GroundColors.down(tank, 0.2))
		for i in 3:
			k.made.prism(0, 1.45 + i * 0.25, 0, 0.625, 1.47 + i * 0.25, 0.625, 12, P.INK[2])
		streak(k, Vector3(0.62, 2.05, 0.05), 0.2, 0.7, Vector3(1, 0, 0))
		streak(k, Vector3(0.1, 2.0, 0.63), 0.14, 0.6, Vector3(0, 0, 1))
		for i in 9:
			var y := 0.1 + i * 0.22
			k.limb(Vector3(0.78, y, -0.15), Vector3(0.7, y, 0.15), 0.014, 0.014, 4, wood[1])
		k.limb(Vector3(0.8, -0.05, -0.16), Vector3(0.66, 2.05, -0.16), 0.02, 0.02, 4, wood[0])
		k.limb(Vector3(0.8, -0.05, 0.16), Vector3(0.66, 2.05, 0.16), 0.02, 0.02, 4, wood[0])
		k.limb(Vector3(-0.3, 1.3, 0.5), Vector3(-0.45, 0.35, 1.0), 0.03, 0.03, 5, P.RUST[1])
		k.slab(-0.45, 0.0, 1.15, 0.9, 0.3, 0.35, s + 1, P.STONE[3], P.BRINE[2], 0.02)
	else:
		var cast := P.STONE[3].lerp(P.LINEN[3], 0.4)
		k.made.prism(0, -0.05, 0, 0.8, 0.8, 0.76, 10, cast, GroundColors.up(cast, 0.15))
		k.made.prism(0, 0.2, 0, 0.805, 0.24, 0.805, 10, GroundColors.down(cast, 0.3))
		k.found.prism(0, 0.8, 0, 0.7, 0.86, 0.66, 8, P.PLATE[3], P.PLATE[4], PI / 8.0)
		for i in 8:
			var a := float(i) / 8.0 * TAU
			k.found.prism(cos(a) * 0.6, 0.86, sin(a) * 0.6, 0.025, 0.89, 0.025, 6, P.PLATE[5])
		k.limb(Vector3(0.78, 0.3, 0.0), Vector3(1.0, 0.3, 0.0), 0.03, 0.025, 5, P.COPPER[1])
		for i in 4:
			var z := -0.6 + i * 0.4
			k.made.prism(1.35 + (i % 2) * 0.2, -0.02, z, 0.13, 0.22, 0.15, 7, [P.RUST[3], P.SLATE[3], P.LINEN[3], P.BRINE[2]][i], P.BRINE[1])
		k.limb(Vector3(-0.9, -0.05, 0.7), Vector3(-0.85, 1.4, 0.72), 0.03, 0.025, 4, wood[0])
		k.fleck(Vector3(-0.85, 1.35, 0.72), Vector3(-0.5, 1.2, 0.72), Vector3(-0.85, 1.1, 0.72), P.BRINE[3])
	if c == Country.SNOWFIELD:
		k.clump(0.0, 2.2 if v % 2 == 0 else 0.86, 0.0, 0.55, 0.14, s + 9, P.RIME[5], 8)
	elif c == Country.BONELANDS or c == Country.BURNING:
		banks(k, [[-0.8, -0.8, 0.5, 0.16], [0.8, -0.7, 0.4, 0.12]], drift_of(c)[0], s + 10)


## A heap of slag where a works tipped it: a dark cone run with glassy pours,
## seams that still glow, and (0) the tipping rail and its ladle car still up
## on top, or (1) twin heaps with a crust broken open.
static func slag_heap(k: Kit, v: int, c: int) -> void:
	var s := 24500 + v * 3 + c
	var slag := P.STONE[1].lerp(P.RUST[1], 0.35)
	var cone := func(cx: float, cz: float, r: float, h: float, seed_value: int) -> void:
		var ring0: Array[Vector3] = []
		var ring1: Array[Vector3] = []
		for i in 11:
			var a := float(i) / 11.0 * TAU
			var rr := r * (0.85 + Rng.hash01(seed_value, i) * 0.3)
			ring0.append(Vector3(cx + cos(a) * rr, -0.1, cz + sin(a) * rr))
			ring1.append(Vector3(cx + cos(a) * rr * 0.45, h * (0.62 + Kit.j(seed_value, i, 0.06)), cz + sin(a) * rr * 0.45))
		var apex := Vector3(cx + r * 0.08, h, cz)
		for i in 11:
			var n := (i + 1) % 11
			var col := slag if i % 3 else GroundColors.down(slag, 0.3)
			k.made.quad(ring0[n], ring0[i], ring1[i], ring1[n], col)
			k.made.tri(apex, ring1[n], ring1[i], GroundColors.up(slag, 0.1) if i % 2 else slag)
			# A pour run down the flank: glass, dark green over black.
			if i % 4 == 1:
				var mid := ring0[i].lerp(ring1[i], 0.5)
				var o := (ring0[i] - Vector3(cx, 0, cz)).normalized() * 0.03
				k.made.quad(ring1[i] + o, ring1[n] + o, ring0[n].lerp(ring0[i], 0.6) + o, ring0[i] + o * 1.5, P.SPRUCE[1].lerp(P.INK[2], 0.4))
				k.fleck(mid + o * 2.0, mid + o * 2.0 + Vector3(0.06, 0.04, 0.0), mid + o * 2.0 + Vector3(0.0, 0.06, 0.05), GroundColors.glint(P.SPRUCE[4]))
			if i % 5 == 2:
				var p := ring0[i].lerp(ring1[i], 0.3) + (ring0[i] - Vector3(cx, 0, cz)).normalized() * 0.04
				k.made.quad(p, p + Vector3(0.1, 0.02, 0.0), p + Vector3(0.1, 0.2, 0.0) - (ring0[i] - Vector3(cx, 0, cz)).normalized() * 0.08, p + Vector3(0.0, 0.18, 0.0) - (ring0[i] - Vector3(cx, 0, cz)).normalized() * 0.08, GroundColors.glow(P.EMBER[3], 0.9))
	if v % 2 == 0:
		cone.call(0.0, 0.0, 1.35, 1.35, s)
		# The tipping rail on its trestle, running off the top, the ladle car
		# tipped at its end, a lip of fresh slag frozen coming out of it.
		for i in 3:
			var x := -1.8 + i * 0.7
			var y := 0.4 + i * 0.35
			k.rod(Vector3(x, -0.1, -0.3), Vector3(x, y, -0.2), 0.03, 4, P.PLATE[2])
			k.rod(Vector3(x, -0.1, 0.3), Vector3(x, y, 0.2), 0.03, 4, P.PLATE[2])
		k.rod(Vector3(-1.9, 0.38, -0.2), Vector3(0.0, 1.45, -0.2), 0.022, 4, P.PLATE[3])
		k.rod(Vector3(-1.9, 0.38, 0.2), Vector3(0.0, 1.45, 0.2), 0.022, 4, P.PLATE[3])
		k.found.push(Transform3D(Basis(Vector3.BACK, -0.7), Vector3(0.1, 1.55, 0.0)))
		k.found.prism(0, 0, 0, 0.26, 0.45, 0.36, 10, P.PLATE[2], P.INK[1])
		k.found.prism(0, -0.05, 0, 0.3, 0.02, 0.3, 10, P.PLATE[1])
		k.found.pop()
		k.made.quad(Vector3(0.45, 1.62, -0.12), Vector3(0.45, 1.62, 0.12), Vector3(0.9, 1.0, 0.16), Vector3(0.85, 0.98, -0.14), GroundColors.glow(P.EMBER[2], 0.6))
	else:
		cone.call(-0.5, -0.2, 1.1, 1.05, s)
		cone.call(0.75, 0.45, 0.85, 0.8, s + 7)
		k.made.prism(-0.45, 1.0, -0.2, 0.2, 1.04, 0.14, 7, P.INK[1], GroundColors.glow(P.EMBER[3], 1.0))
	banks(k, [[-1.5, 1.0, 0.5, 0.12], [1.5, -0.9, 0.45, 0.1]], P.ASH[1] if c == Country.BURNING else drift_of(c)[1], s + 20)
