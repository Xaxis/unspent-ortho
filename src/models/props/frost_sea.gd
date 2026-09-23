extends RefCounted
## What stands on the Frost Sea (docs/LANDSCAPES.md §2). The sea itself is the
## ground, so everything here is either what the sea did — ice thrown up on end
## where two floes met, a hole a seal keeps open, a trawler it closed round to
## the gunwale — or what the plan stood on it to listen through: a tripod over a
## hole it keeps from freezing.
##
## Two pens. Sea ice is MADE and it is the first thing in the game drawn on the
## GLASS row (`GroundColors.GLASS`, matter.gdshaderinc 86): ice is the one
## natural thing that takes light the way a pane does, hard and half-clear, and
## on a plain that is white to the horizon the block's lit edge is the only
## place a specular lives. The hull's plate and the rig are FOUND, ruled, and
## carry no mark in their alpha because on that pen an alpha is a lamp. What
## banks against them is the landscape's own snow, through its dressing, so the
## same hull frozen into another sea is rimed in that sea's white.
##
## Nothing here is a cube. A block is a leaning slab with a tapered head and a
## second plate fallen against it; a hull is a lofted bulwark; a rig is three
## rods and a drum; a hole is a ring of lumps round a dark disc.
##
## The gallery (`tools/shot.sh shots/x.png --scene=gallery --filter=frost`) shows
## every kind here in the frost sea's own dressing, and beside them the two
## machines the landscape keeps to itself, so one frame answers whether the sea's
## things read as one place.

const Kit := preload("res://src/models/props/kit.gd")
const P := preload("res://src/render/palette.gd")
const Works := preload("res://src/models/props/works.gd")
const Remains := preload("res://src/models/props/remains.gd")
## machine_gallery.gd has no class_name (the gallery lists inherited statics);
## reached by path, as sentinel_gallery.gd reaches it.
const MG := preload("res://src/models/machines/machine_gallery.gd")

## Sea ice as a THING, tagged GLASS. Bluer and harder than the ice it stands on
## (frost_sea.gd says the same of the ground: frozen sea is not fallen snow), the
## edge a step brighter where the light comes through it. `made` is called LAST,
## after the lerp, because a lerp moves alpha and alpha is the whole of the mark.
static var ICE: Color = GroundColors.made(P.RIME[4].lerp(P.SLATE[4], 0.22), GroundColors.GLASS)
static var ICE_EDGE: Color = GroundColors.made(P.RIME[5], GroundColors.GLASS)
static var ICE_DEEP: Color = GroundColors.made(P.RIME[3].lerp(P.SLATE[3], 0.3), GroundColors.GLASS)
## Ice with blood frozen into it, still ice.
static var BLOOD_ICE: Color = GroundColors.made(P.RUST[1].lerp(P.INK[1], 0.3), GroundColors.GLASS)
## What is left of a seal, bleached.
static var BONE: Color = GroundColors.made(P.LINEN[4], GroundColors.BONE_MADE)
## Rope on the hull, and the sheet over its winch.
static var ROPE: Color = GroundColors.made(P.SAND[2], GroundColors.ROPE)
## The dark water in a hole: the frost sea draws its leads in SLATE[1] and a
## hole is a lead the size of a hand, a step darker for being deep.
const WATER := P.SLATE[0]


static func build(k: Kit, kind: int, v: int, c: int) -> void:
	k.hand(Ink.hand_of(c))
	match kind:
		PropKind.PRESSURE_BLOCK: pressure_block(k, v, c)
		PropKind.FROZEN_HULL: frozen_hull(k, v, c)
		PropKind.SOUNDING_RIG: sounding_rig(k, v, c)
		PropKind.SEAL_HOLE: seal_hole(k, v, c)


## A slab of sea ice thrown up on end at a ridge and left leaning, a second
## plate fallen against its foot, chips of both round them and snow banked on
## the lee. Three variants lean, turn and size differently, because a ridge is
## a clump of these and two shapes in a clump is a stamp.
static func pressure_block(k: Kit, v: int, c: int) -> void:
	var s := 41000 + v * 19 + c
	var tilt := 0.55 + v * 0.16
	var yaw := Kit.j(s, 1, 0.5)
	var w := 1.5 - v * 0.14
	var h := 1.2 + v * 0.08
	var d := 0.34 - v * 0.04
	# Leaning toward +x, its foot sunk in the ridge. The slab keeps hard faces on
	# purpose: it is a plate, and a plate's facets are what say it broke off.
	k.made.push(Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, -tilt), Vector3(0.0, -0.08, 0.0)))
	k.slab(0.0, 0.0, 0.0, w, h, d, s, ICE, ICE_EDGE, 0.05, 0.24, 0.0)
	k.made.pop()
	# The plate that met it, fallen the other way and lower.
	k.made.push(Transform3D(Basis(Vector3.UP, yaw + 0.45) * Basis(Vector3.BACK, 0.85 + v * 0.1), Vector3(-0.45 + v * 0.08, -0.06, 0.28)))
	k.slab(0.0, 0.0, 0.0, 0.9, 0.72, 0.22, s + 3, ICE_DEEP, ICE_EDGE, 0.05, 0.18, 0.0)
	k.made.pop()
	# Chips off both at the foot, welded into lumps by `stone`.
	for i in 4:
		var a := Kit.j(s, 10 + i, PI) + i * 1.5
		var r := 0.1 + Rng.hash01(s, i, 3) * 0.1
		k.stone(cos(a) * (0.5 + r), -0.05, sin(a) * (0.42 + r), r, r * 1.1, s + 20 + i, ICE if i % 2 == 0 else ICE_DEEP, 6)
	var dress := BiomeDressing.of(c)
	if dress.cold():
		Remains.banks(k, [[0.5, -0.4, 0.4, 0.14], [-0.7, 0.4, 0.3, 0.1]], dress.snow[0], s + 30)


## Stations along a trawler's length, x and half beam at the gunwale. Only what
## stands above the ice is drawn: the sea has the rest, to the gunwale.
const _STATIONS: Array[Vector2] = [Vector2(-2.9, 0.3), Vector2(-2.3, 0.72), Vector2(-1.2, 0.95),
	Vector2(0.0, 1.0), Vector2(1.2, 0.92), Vector2(2.2, 0.62), Vector2(2.9, 0.08)]
## The bulwark's top and the deck below it, over the ice.
const _GUN := 0.42
const _DECK := 0.2


## A trawler frozen in to its gunwale: the bulwark and deck in ruled plate, a
## wheelhouse, a winch, one mast, and the rigging somebody left up, drawn by
## the hand. 0 stands upright; 1 heeled over with the mast broken, the way the
## ice took it.
static func frozen_hull(k: Kit, v: int, c: int) -> void:
	var s := 41200 + v * 23 + c
	var plate := P.PLATE[3]
	var dark := P.PLATE[1]
	var heel := 0.0 if v == 0 else 0.22
	var xf := Transform3D(Basis(Vector3.RIGHT, heel), Vector3.ZERO)
	k.found.push(xf)
	k.made.push(xf)
	var st := _STATIONS
	for i in st.size() - 1:
		var a := st[i]
		var b := st[i + 1]
		# Strakes by turns: bare plate and one rust-run one, the way a working
		# boat's topsides go.
		var col := plate if i % 2 == 0 else P.PLATE[2].lerp(P.RUST[2], 0.4)
		for sgn: float in [1.0, -1.0]:
			var p0 := Vector3(a.x, -0.05, sgn * a.y)
			var p1 := Vector3(b.x, -0.05, sgn * b.y)
			var q0 := Vector3(a.x, _GUN, sgn * (a.y + 0.06))
			var q1 := Vector3(b.x, _GUN, sgn * (b.y + 0.06))
			# Wound as `Kit.slab` winds its +z and -z faces, so both sides face out.
			if sgn > 0.0:
				k.found.quad(p0, p1, q1, q0, col)
			else:
				k.found.quad(p1, p0, q0, q1, col)
			# The cap rail along the gunwale.
			k.rod(q0 + Vector3(0, 0.01, 0), q1 + Vector3(0, 0.01, 0), 0.03, 4, P.PLATE[4])
		# Deck plating between the bulwarks, a step down from the rail.
		k.found.quad(Vector3(a.x, _DECK, -a.y), Vector3(a.x, _DECK, a.y), Vector3(b.x, _DECK, b.y), Vector3(b.x, _DECK, -b.y), dark)
	# Stern and bow closed off.
	var sa := st[0]
	var sb := st[st.size() - 1]
	k.found.quad(Vector3(sa.x, -0.05, -sa.y), Vector3(sa.x, -0.05, sa.y), Vector3(sa.x, _GUN, sa.y + 0.06), Vector3(sa.x, _GUN, -sa.y - 0.06), plate)
	k.found.quad(Vector3(sb.x, -0.05, sb.y), Vector3(sb.x, -0.05, -sb.y), Vector3(sb.x, _GUN, -sb.y - 0.06), Vector3(sb.x, _GUN, sb.y + 0.06), plate)
	# The wheelhouse aft of the middle, its windows dark, and the winch drum
	# forward of it where the net came in.
	k.chamfer(-1.3, _DECK, 0.0, 1.0, 1.0, 1.1, 0.07, plate, P.PLATE[4])
	for z: float in [-0.3, 0.0, 0.3]:
		k.found.quad(Vector3(-0.796, 0.7, z + 0.1), Vector3(-0.796, 0.7, z - 0.1), Vector3(-0.796, 0.95, z - 0.1), Vector3(-0.796, 0.95, z + 0.1), P.COLD[1])
	k.found.prism(0.2, _DECK, 0.0, 0.17, _DECK + 0.32, 0.17, 8, P.PLATE[2], P.PLATE[3])
	k.hoop(Vector3(0.2, _DECK + 0.16, 0.0), 0.18, 8, 0.012, P.PLATE[5])
	# One mast, its foot at the winch: standing, or snapped and hanging.
	var foot := Vector3(0.6, _DECK, 0.0)
	if v == 0:
		var top := Vector3(0.66, 3.5, 0.0)
		k.rod(foot, top, 0.05, 6, P.PLATE[2])
		k.rod(Vector3(0.64, 2.6, -0.5), Vector3(0.64, 2.6, 0.5), 0.025, 4, P.PLATE[3])
		k.found.prism(0.66, 3.5, 0.0, 0.06, 3.58, 0.05, 6, P.PLATE[4], P.PLATE[5])
		# Stays to bow and stern, and halyards off the crosstree, slack.
		k.sag(top, Vector3(2.7, _GUN, 0.0), 0.12, 6, 0.012, ROPE)
		k.sag(top, Vector3(-2.6, _GUN, 0.0), 0.12, 6, 0.012, ROPE)
		for sgn: float in [-1.0, 1.0]:
			k.sag(Vector3(0.64, 2.6, sgn * 0.5), Vector3(-0.2, _GUN + 0.02, sgn * 0.9), 0.1, 5, 0.01, ROPE)
	else:
		var snap := Vector3(0.62, 1.7, 0.0)
		k.rod(foot, snap, 0.05, 6, P.PLATE[2])
		k.rod(snap, Vector3(1.4, 0.5, 0.7), 0.045, 6, P.PLATE[2])
		k.sag(snap, Vector3(2.6, _GUN, 0.1), 0.1, 6, 0.012, ROPE)
		k.sag(Vector3(1.4, 0.5, 0.7), Vector3(-0.4, _GUN, 0.95), 0.06, 5, 0.01, ROPE)
	# A net still hung over the rail to dry, frozen in its folds: sags of cord
	# between the rail and the ice, close enough to read as mesh.
	for i in 6:
		var x := -0.1 + i * 0.28
		k.sag(Vector3(x, _GUN, -0.98 - x * 0.02), Vector3(x + 0.1, 0.0, -1.35), 0.05, 4, 0.008, ROPE)
	k.sag(Vector3(-0.1, 0.0, -1.35), Vector3(1.5, 0.0, -1.35), 0.02, 6, 0.008, ROPE)
	k.made.pop()
	k.found.pop()
	# Rime banked against the bulwark on the ice, the sea's own white.
	var dress := BiomeDressing.of(c)
	var white: Color = dress.snow[0] if dress.cold() else Remains.drift_of(c)[0]
	Remains.banks(k, [[-2.0, 0.95, 0.5, 0.2], [0.4, 1.15, 0.55, 0.22], [2.3, 0.7, 0.4, 0.16], [-1.0, -1.2, 0.45, 0.18], [1.6, -1.1, 0.4, 0.16]], white, s + 40)


## The plan's tripod over a sounding hole: three rods to a collar, a ruled drum
## hung under it, the cable paying out of the drum down into the water, and a
## beacon on top on the machines' beat. 1 has the cable paid out across the ice
## to a weight, the hole refreezing.
static func sounding_rig(k: Kit, v: int, c: int) -> void:
	var s := 41400 + v * 11 + c
	var apex := Vector3(0.0, 2.12, 0.0)
	for i in 3:
		var a := float(i) / 3.0 * TAU + 0.5
		var foot := Vector3(cos(a) * 0.72, -0.04, sin(a) * 0.72)
		k.rod(foot, apex, 0.03, 6, P.PLATE[3])
		k.found.prism(foot.x, -0.02, foot.z, 0.1, 0.03, 0.08, 6, P.PLATE[2], P.PLATE[3])
	# The collar the legs meet in, and the beacon standing off it.
	k.found.prism(0.0, 2.02, 0.0, 0.13, 2.26, 0.1, 8, P.PLATE[2], P.PLATE[3])
	k.rod(Vector3(0.0, 2.26, 0.0), Vector3(0.0, 2.4, 0.0), 0.02, 4, P.PLATE[4])
	k.found.prism(0.0, 2.4, 0.0, 0.05, 2.5, 0.045, 6, Works.BEACON, Works.BEACON)
	# The drum: turned, ruled with three bands, hung on a bracket under the collar.
	k.rod(Vector3(0.0, 2.02, 0.0), Vector3(0.0, 1.6, 0.0), 0.025, 4, P.PLATE[3])
	k.found.prism(0.0, 1.22, 0.0, 0.2, 1.6, 0.2, 10, P.PLATE[3], P.PLATE[4], PI / 10.0, true)
	for y: float in [1.3, 1.41, 1.52]:
		k.hoop(Vector3(0.0, y, 0.0), 0.205, 10, 0.008, P.PLATE[5])
	# The hole it keeps open: dark water in a pale refrozen rim, the rim ice.
	k.made.prism(0.0, -0.03, 0.0, 0.44, 0.03, 0.38, 12, ICE_EDGE, ICE_EDGE)
	k.found.prism(0.0, -0.02, 0.0, 0.28, 0.038, 0.28, 12, WATER, WATER)
	if v == 0:
		k.rod(Vector3(0.0, 1.22, 0.0), Vector3(0.02, -0.3, 0.0), 0.012, 4, P.INK[2])
	else:
		# Paid out: down off the drum, over the rim and away to a weight.
		k.rod(Vector3(0.18, 1.3, 0.0), Vector3(0.5, 0.05, 0.2), 0.012, 4, P.INK[2])
		k.rod(Vector3(0.5, 0.05, 0.2), Vector3(1.3, 0.03, 0.6), 0.012, 4, P.INK[2])
		k.found.prism(1.3, -0.02, 0.6, 0.08, 0.14, 0.06, 6, P.PLATE[2], P.PLATE[4])
	var dress := BiomeDressing.of(c)
	if dress.cold():
		Remains.banks(k, [[-0.6, 0.5, 0.3, 0.1]], dress.snow[0], s + 5)


## A seal's breathing hole: a ring of ice lumps round dark water, the ice round
## it dark with blood, and what is left of what came up through it. Life going
## on, and the one thing on the sea that was not put there by the plan.
static func seal_hole(k: Kit, v: int, c: int) -> void:
	var s := 41600 + v * 7 + c
	# The stain first, flat on the ice, then the water, then the rim over both.
	k.made.prism(0.0, -0.03, 0.0, 0.56, 0.012, 0.5, 10, BLOOD_ICE, BLOOD_ICE, 0.3)
	k.made.prism(0.0, -0.02, 0.0, 0.24, 0.02, 0.24, 10, WATER, WATER)
	for i in 7:
		var a := float(i) / 7.0 * TAU + Kit.j(s, i, 0.3)
		var r := 0.09 + Rng.hash01(s, i, 2) * 0.07
		k.stone(cos(a) * 0.36, -0.04, sin(a) * 0.36, r, r * 0.9, s + 10 + i, ICE_EDGE if i % 3 else ICE, 6)
	# Bones: a rib or two and a long one, thrown clear.
	k.limb(Vector3(0.45, 0.02, -0.3), Vector3(0.78, 0.04, -0.46), 0.022, 0.014, 4, BONE, Vector3(0.0, 0.05, 0.0))
	k.limb(Vector3(-0.4, 0.02, 0.36), Vector3(-0.62, 0.03, 0.52), 0.018, 0.012, 4, BONE, Vector3(0.0, 0.04, 0.0))
	if v == 1:
		k.limb(Vector3(0.3, 0.02, 0.5), Vector3(0.7, 0.05, 0.62), 0.02, 0.012, 4, BONE, Vector3(0.0, 0.06, 0.0))
		# The slide where it hauled out, a smear of darker ice.
		k.made.prism(0.62, -0.03, 0.2, 0.16, 0.014, 0.12, 8, ICE_DEEP, ICE_DEEP)


## Where a rig's beacon is, for PropModels.glow_points: the middle of the lamp
## the geometry above draws, so the light and the thing casting it agree.
static func beacon_at() -> Vector3:
	return Vector3(0.0, 2.45, 0.0)


## Every kind here in the frost sea's own dressing, and beside them the sea's
## keeper and its saw sled, so one frame holds the whole landscape's things.
static func gallery() -> Array:
	var out: Array = []
	var d := BiomeRegistry.get_def(&"frost_sea")
	var c: int = d.index if d != null else 0
	var pm: GDScript = load("res://src/models/prop_models.gd")
	for kind: int in [PropKind.PRESSURE_BLOCK, PropKind.FROZEN_HULL, PropKind.SOUNDING_RIG, PropKind.SEAL_HOLE]:
		var n: int = pm.call(&"variants", kind, c)
		for v in n:
			out.append({"name": "frost sea %s %d" % [PropKind.NAMES[kind], v], "node": pm.call(&"node", kind, v, c)})
	for spec: Array in [[&"sentinel_listener", &"stand"], [&"sentinel_listener", &"alert"], [&"icesaw", &"stand"], [&"icesaw", &"walk"]]:
		var item: FigureModel = MG.make(spec[0], spec[1], 0.3)
		var holder := Node3D.new()
		holder.add_child(item)
		out.append({"name": "frost sea %s %s" % [String(spec[0]).trim_prefix("sentinel_"), spec[1]], "node": holder})
	return out
