class_name SkyWear
## What the land does to a thing that STANDS in it, as one small texture the lit
## shaders read by world position (global `sky_wear`, `matter.gdshaderinc`):
##   R  rust      G  salt bloom      B  soot      A  frost
##
## LANTERN law 1 (docs/LOOK.md): "Wear accumulates by world position: a machine
## standing in a bog rusts along its underside, the same machine on a salt flat
## blooms white in its seams, the same machine in the Burning carries soot in its
## lee." That is this file and `matter_worn()`, and nothing else.
##
## It is a RENDERING table and it lives here rather than in `BiomeDef` on
## purpose: what a place is made of is the landscape file's business, but what a
## surface standing in it LOOKS like after a few years is the look's, and the
## look is being rebuilt. A landscape that wants to argue gets a row here.
##
## Landscapes meet on their ecotone blend exactly as SkyGround's do, so a
## machine walked from the bog to the salt flat loses its rust and gains its
## bloom over the twelve to twenty-four tiles of the border, and never on a line.

## A landscape with no row wears like the coast: damp, a little salt, no soot.
const DEFAULT := Color(0.45, 0.22, 0.05, 0.05)
## UNDER A ROOF NOTHING SETTLES but the hearth's own smoke. A pocket's tiles
## carry the land they stand in (docs/interiors), and without this the coast's
## salt bloomed white across a cottage's floorboards, measured in a frame.
const INDOORS := Color(0.06, 0.0, 0.14, 0.0)

## rust, salt, soot, frost — each 0..1, how hard this land presses that way.
## The three the brief names are the three that carry: the bog rusts, the flat
## blooms, the Burning blacks. The rest are placed relative to those.
const OF := {
	# Salt spray and a wind off the sea: everything here is damp and a bit crusted.
	&"coast": Color(0.55, 0.30, 0.05, 0.05),
	&"sea": Color(0.65, 0.55, 0.00, 0.00),
	# A bog. Standing water, acid peat, nothing ever dries: the worst rust there is.
	&"moss": Color(0.92, 0.00, 0.05, 0.10),
	# Resin, needle litter and hard frost; wet enough under the canopy to rust.
	&"pinewood": Color(0.42, 0.00, 0.10, 0.35),
	# Dry cold. Nothing rusts fast at this temperature; everything ices.
	&"snowfield": Color(0.14, 0.00, 0.00, 1.00),
	# Dry, alkaline, mineral: a pale bloom out of every seam, little rust.
	&"bonelands": Color(0.18, 0.50, 0.05, 0.15),
	# The Burning. Soot in the lee of everything, and the heat keeps it dry.
	&"burning": Color(0.28, 0.00, 1.00, 0.00),
	# Evaporite. The flat's own crust climbs anything left standing on it.
	&"salt_flats": Color(0.22, 1.00, 0.00, 0.00),
	# A wood floored in rust grit and metal filings, under acid rain off the works.
	&"scrapwood": Color(0.95, 0.10, 0.32, 0.10),
	# Cold wet limestone: carbonate bloom and a slow damp rust, never any sun.
	&"limestone_caves": Color(0.50, 0.38, 0.08, 0.02),
}


## The wear a landscape type presses with.
static func of(type_id: StringName) -> Color:
	return OF.get(type_id, DEFAULT)


## One texel per tile, blended across ecotones the way SkyGround's is.
static func image(w: WorldData) -> Image:
	var n := w.size
	# Land ids cover wide regions, so a coarse sweep finds every one of them.
	var rows: Array[Color] = []
	rows.resize(256)
	rows.fill(DEFAULT)
	var indoors := w.realm == Realm.INTERIOR
	var seen := PackedByteArray()
	seen.resize(256)
	for y in range(0, n, 4):
		for x in range(0, n, 4):
			var c := int(w.country[y * n + x])
			if seen[c] == 0:
				seen[c] = 1
				rows[c] = INDOORS if indoors else of(BiomeRegistry.at(w, Vector2(x, y)).id)
	var rgba := PackedByteArray()
	rgba.resize(n * n * 4)
	var has_blend := w.blend.size() == n * n and w.country2.size() == n * n
	for i in n * n:
		var r: Color = rows[int(w.country[i])]
		if has_blend and w.blend[i] > 0.0:
			r = r.lerp(rows[int(w.country2[i])], clampf(w.blend[i], 0.0, 1.0))
		var o := i * 4
		rgba[o] = int(r.r * 255.0)
		rgba[o + 1] = int(r.g * 255.0)
		rgba[o + 2] = int(r.b * 255.0)
		rgba[o + 3] = int(r.a * 255.0)
	return Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, rgba)


## PURE AND DERIVED, SO KEPT: one texture per world OBJECT (never per seed: a
## test grows one seed twice), so walking back out of a house onto the coast
## hands the coast's own back instead of sweeping the island again (4.6 s for
## the ground measured on seed 4, docs/interiors). Held by a weak reference to
## the world, so a world nobody holds any more takes its texture with it.
static var _kept: Dictionary = {}


static func texture(w: WorldData) -> ImageTexture:
	var id := w.get_instance_id()
	var got: Array = _kept.get(id, [])
	if not got.is_empty() and (got[0] as WeakRef).get_ref() == w:
		return got[1]
	for k: int in _kept.keys():
		if (_kept[k][0] as WeakRef).get_ref() == null:
			_kept.erase(k)
	var t := ImageTexture.create_from_image(image(w))
	_kept[id] = [weakref(w), t]
	return t
