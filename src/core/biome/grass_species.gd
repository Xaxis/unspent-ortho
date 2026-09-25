class_name GrassSpecies
extends RefCounted
## One grass a landscape grows, as data: its shape and how it moves. A landscape
## lists its own in `BiomeDef.grasses`, and its decor tables lay them as
## `Decor.GRASS_A`, `GRASS_B`, `GRASS_C` (its first, second and third). Decor
## builds the patch (`Decor.kit`); grass.gdshader moves it by the stiffness and
## flutter packed into each vertex (`motion_code`). Nothing outside a landscape
## file names a species, so no two landscapes' grass is the same grass.
##
## A patch is `blades` blades rooted over a disc `spread` across. Each blade
## rises `height` and its tip reaches out `reach` of its height, bowed by `curl`,
## laid toward one bearing by `lay` (0 radiates from the middle like a tussock,
## 1 is a sward combed one way). `leaflets` > 0 hangs that many leaflets down
## each side of a blade (a frond). `heads` of the blades carry a seed head.

var id: StringName = &""
var blades := 24
var height := Vector2(0.22, 0.5)
var width := 0.026
var spread := 0.38
var reach := Vector2(0.2, 0.5)
var curl := 0.15
var lay := 0.8
var root := Color(0.3, 0.45, 0.3)
var tip := Color(0.55, 0.6, 0.4)
var leaflets := 0
## A leaflet's length as a share of the frond's height, at the frond's base.
var leaflet := 0.26
## What a leaflet's tip pales toward.
var tip_pale := Color(0.75, 0.78, 0.55)
## A second colour and the share of blades that take it: bracken turning, some
## fronds still green among the russet.
var other := Color(0, 0, 0, 0)
var other_share := 0.0
## Casts a real shadow. Costs a shadow pass, so only for sparse grass on pale
## open ground, where a tuft with no shadow floats.
var casts := false
var heads := 0
var head_color := Color(0.9, 0.88, 0.8)
var head_size := 0.03
## 0.1 bends like a hair, 0.9 like a reed; a crown is 1.
var stiff := 0.55
## 0..9: how fast a blade shivers on its own over the sway.
var flutter := 2


## A species named `id` with the properties in `set_to` (property name -> value):
## how a landscape file declares its grass in one readable block.
static func make(grass_id: StringName, set_to: Dictionary) -> GrassSpecies:
	var g := GrassSpecies.new()
	g.id = grass_id
	for key: String in set_to:
		assert(key in g, "GrassSpecies has no %s" % key)
		g.set(key, set_to[key])
	return g


## What grass.gdshader reads out of the whole part of UV2.y: tens the stiffness
## in tenths (1..9), units the flutter. 0 is "no species": the shader's defaults.
func motion_code() -> int:
	return clampi(roundi(stiff * 10.0), 1, 9) * 10 + clampi(flutter, 0, 9)


## Every property that makes the grass look or move as it does, for comparing
## two landscapes' grass (tests/render/test_species.gd).
func signature() -> Array:
	return [blades, height, width, spread, reach, curl, lay, root, tip, leaflets, leaflet, tip_pale, other, other_share,
		heads, head_color, head_size, stiff, flutter, casts]


## The grass a landscape that declares none grows, from its grass colours. Only
## ever laid through a table that names GRASS_A and has no species behind it.
static func fallback(colors: Array[Color]) -> GrassSpecies:
	var g := GrassSpecies.new()
	g.id = &"turf"
	if colors.size() >= 2:
		g.root = colors[0]
		g.tip = colors[1]
	return g
