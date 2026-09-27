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
	# NOTHING WEATHERS IN THE MACHINE CITY: they keep it. No rust, no bloom, no
	# soot, no frost on anything standing there (the owner's own: clean).
	&"machine_city": Color(0.0, 0.0, 0.0, 0.0),
}


## The wear a landscape type presses with.
static func of(type_id: StringName) -> Color:
	return OF.get(type_id, DEFAULT)


## One texel per tile, blended across ecotones the way SkyGround's is.
##
## THE GROWTH MAP comes out of the SAME pass when `growth` is handed in (one
## Image appended to it): R how far each landscape's growth has taken what was
## built in it (`BiomeDef.overgrowth`, matter_grown), and GBA the light its trees
## are lit by from below after dark (`BiomeDef.underlight`, colour times
## strength, leaf.gdshader). One sweep of the world for both, because a streamed
## world is to have fewer whole-world readers, not more
## (tests/stream/whole_world_readers.txt).
static func image(w: WorldData, growth: Variant = null) -> Image:
	var n := w.size
	# Land ids cover wide regions, so a coarse sweep finds every one of them.
	var rows: Array[Color] = []
	rows.resize(256)
	rows.fill(DEFAULT)
	var grows: Array[Color] = []
	grows.resize(256)
	grows.fill(Color(0, 0, 0, 0))
	var indoors := w.realm == Realm.INTERIOR
	var seen := PackedByteArray()
	seen.resize(256)
	for y in range(0, n, 4):
		for x in range(0, n, 4):
			var c := int(w.country[y * n + x])
			if seen[c] == 0:
				seen[c] = 1
				var d := BiomeRegistry.at(w, Vector2(x, y))
				rows[c] = INDOORS if indoors else of(d.id)
				if not indoors:
					var u := d.underlight
					grows[c] = Color(d.overgrowth, u.r * u.a, u.g * u.a, u.b * u.a)
	var want_growth := growth is Array
	var rgba := PackedByteArray()
	rgba.resize(n * n * 4)
	var gpx := PackedByteArray()
	if want_growth:
		gpx.resize(n * n * 4)
	var has_blend := w.blend.size() == n * n and w.country2.size() == n * n
	for i in n * n:
		var r: Color = rows[int(w.country[i])]
		var g: Color = grows[int(w.country[i])]
		if has_blend and w.blend[i] > 0.0:
			var t := clampf(w.blend[i], 0.0, 1.0)
			r = r.lerp(rows[int(w.country2[i])], t)
			g = g.lerp(grows[int(w.country2[i])], t)
		var o := i * 4
		rgba[o] = int(r.r * 255.0)
		rgba[o + 1] = int(r.g * 255.0)
		rgba[o + 2] = int(r.b * 255.0)
		rgba[o + 3] = int(r.a * 255.0)
		if want_growth:
			gpx[o] = int(clampf(g.r, 0.0, 1.0) * 255.0)
			gpx[o + 1] = int(clampf(g.g, 0.0, 1.0) * 255.0)
			gpx[o + 2] = int(clampf(g.b, 0.0, 1.0) * 255.0)
			gpx[o + 3] = int(clampf(g.a, 0.0, 1.0) * 255.0)
	if want_growth:
		(growth as Array).append(Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, gpx))
	return Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, rgba)


## The growth map's texture, from the same kept pass as `texture` (see `image`).
static func growth_texture(w: WorldData) -> ImageTexture:
	texture(w)
	return _kept[w.get_instance_id()][2]


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
	var growth: Array = []
	var t := ImageTexture.create_from_image(image(w, growth))
	_kept[id] = [weakref(w), t, ImageTexture.create_from_image(growth[0])]
	return t
