class_name UiSketch
## Things scanned onto the slate at their real pixel size. Each is first drawn the way the world
## is drawn: a flat palette wash, a hand-inked contour, and shadow put in as
## pixel hatching on the side away from the light (key light upper left).
##
## MADE things are drawn by hand: the pen wanders a little, the wash slips a
## pixel off the line toward the light, the lit edge of the line breaks up,
## and the shadow is hatched. FOUND things (machine plate, found weapons) are
## drawn with a ruler: exact edges, no hatching, a flat darker step for shade,
## and their working part glowing amber.
##
## A sketch is a list of parts on a design grid (default 32x32, y down), in
## draw order; later parts sit over earlier ones and take the line between:
##   ["poly", colour, [x, y, x, y, ...]]
##   ["bar",  colour, x0, y0, x1, y1, width0, width1]   a tapered stroke
##   ["ell",  colour, cx, cy, rx, ry]
##   ["line", x0, y0, x1, y1, ...]                      an ink detail stroke
##   ["dot",  x, y]                                     a rivet, a knot
##   ["glow", cx, cy, r]                                an amber working part
## Colours: "a1".."a6" and "b1".."b6" step the item's two ramps (UiIcons.ITEMS),
## "ramp:N" names a Palette ramp directly, "l" is the amber.
##
## Rasterized once per (sketch, size) into a cached texture and drawn at whole
## pixels, never scaled.
##
## **The raster runs on a WorkerThreadPool worker, and the work is split in two
## so that it can.** `_item_job` / `_station_job` / `_ramps_for` read the content
## classes — UiIcons, Items, Palette, UiTheme — and run on the thread that ASKED
## for the sketch; `_bake` and everything under it read only what they were
## handed, plus Rng, Geometry2D and their own Image. The lookups are pennies
## against the pixels, so nothing is lost by moving them, and what is gained is
## that no worker here is ever the thread that reaches into the rest of the game.
## `tests/ui/test_sketch_threads.gd` reads this file's own source and fails if a
## worker-side function names one of those classes again, because the failure
## this guards against is not a red test: it is the process gone, with no save.

const GRID := 32.0
## The drawing's own inks, before the scanner turns it to tones: the contour, a
## hatched shade cast behind the thing, and the light it is washed toward.
const INK := Color(0.0706, 0.0667, 0.1137)
const CAST := Color(0.0, 0.0, 0.0, 0.55)
const LIGHT := Color(0.93, 0.93, 0.9)

## Every shape an item can take. Tools lie on the diagonal, head up and right.
const SHAPES := {
	&"knife": [
		["bar", "b3", 4.5, 28.0, 12.5, 20.0, 4.2, 3.6],
		["dot", 7.0, 25.5], ["dot", 9.5, 23.0],
		["poly", "a2", [10.5, 20.5, 13.0, 18.0, 15.0, 20.0, 12.5, 22.5]],
		["poly", "a5", [12.5, 18.5, 28.0, 3.5, 25.0, 11.0, 15.0, 21.0]],
		["line", 14.5, 18.0, 25.5, 7.0],
	],
	&"axe": [
		["bar", "b3", 20.5, 8.0, 15.0, 30.5, 3.4, 3.8],
		["poly", "a4", [9.0, 3.0, 23.5, 4.5, 24.0, 11.5, 15.0, 12.0, 9.5, 17.5, 4.5, 11.0]],
		["line", 7.0, 6.5, 6.0, 13.0],
		["poly", "a2", [18.0, 3.5, 24.0, 4.5, 24.5, 12.0, 18.5, 12.0]],
	],
	&"pick": [
		["bar", "b3", 16.5, 9.0, 15.0, 30.5, 3.2, 3.6],
		["poly", "a4", [1.5, 11.0, 7.0, 6.0, 16.0, 4.0, 25.0, 6.0, 30.5, 11.0, 24.0, 9.0, 16.0, 8.5, 8.0, 9.0]],
		["poly", "a2", [13.0, 3.0, 20.0, 3.0, 20.0, 10.5, 13.0, 10.5]],
	],
	&"mattock": [
		["bar", "b3", 17.0, 9.0, 14.5, 30.5, 3.2, 3.6],
		["poly", "a4", [2.0, 5.0, 14.0, 5.0, 14.0, 10.5, 6.0, 11.0, 2.5, 14.0]],
		["poly", "a4", [20.0, 5.0, 30.5, 8.0, 20.0, 10.5]],
		["poly", "a2", [13.5, 3.5, 20.5, 3.5, 20.5, 11.5, 13.5, 11.5]],
	],
	&"billhook": [
		["bar", "b3", 20.0, 17.0, 23.0, 30.5, 3.6, 4.0],
		["poly", "a2", [17.0, 15.0, 22.5, 15.0, 22.5, 19.5, 17.5, 19.5]],
		["poly", "a4", [17.5, 16.0, 17.5, 7.0, 14.5, 3.0, 8.0, 2.5, 4.5, 7.5, 5.5, 10.5, 9.0, 7.0, 12.5, 7.5, 13.5, 11.0, 13.5, 16.0]],
		["line", 16.0, 8.0, 12.5, 4.5],
	],
	&"stave": [
		["bar", "b4", 3.5, 29.0, 28.5, 3.5, 3.0, 2.4],
		["line", 9.0, 21.5, 11.0, 23.5], ["line", 10.5, 20.0, 12.5, 22.0],
		["line", 22.0, 8.5, 23.5, 10.0],
	],
	&"boathook": [
		["bar", "b3", 3.5, 29.5, 21.0, 12.0, 2.8, 2.6],
		["poly", "a4", [19.0, 12.5, 24.5, 6.0, 25.0, 1.5, 28.5, 1.5, 29.5, 6.5, 25.0, 12.0, 22.0, 15.0]],
		["poly", "a3", [25.0, 9.0, 31.0, 11.0, 26.5, 12.5]],
	],
	&"glim": [
		["poly", "a2", [12.5, 25.0, 19.5, 25.0, 19.5, 31.0, 12.5, 31.0]],
		["poly", "a3", [10.0, 5.0, 22.0, 5.0, 22.0, 25.0, 10.0, 25.0]],
		["poly", "a4", [12.0, 2.0, 20.0, 2.0, 22.0, 5.0, 10.0, 5.0]],
		["line", 10.0, 19.0, 22.0, 19.0], ["line", 10.0, 21.0, 22.0, 21.0],
		["glow", 16.0, 12.0, 3.2],
	],
	&"stone": [
		["poly", "a3", [4.0, 21.0, 7.0, 13.0, 14.0, 9.0, 22.0, 10.0, 28.0, 15.0, 28.5, 23.0, 22.0, 27.5, 10.0, 27.5]],
		["poly", "a4", [7.0, 13.0, 14.0, 9.0, 22.0, 10.0, 18.0, 15.0, 10.0, 17.0]],
		["line", 18.0, 15.0, 21.0, 21.0],
	],
	&"timber": [
		["bar", "b3", 4.0, 23.0, 24.0, 12.0, 11.0, 11.0],
		["line", 7.0, 20.0, 19.0, 13.5], ["line", 9.0, 25.0, 16.0, 21.0],
		["ell", "a5", 24.5, 12.5, 5.0, 6.0],
		["ell", "a4", 24.5, 12.5, 2.6, 3.2],
		["dot", 24.5, 12.5],
	],
	&"driftwood": [
		["bar", "a4", 3.0, 23.0, 29.0, 14.0, 6.0, 3.0],
		["bar", "a4", 14.0, 19.0, 20.0, 6.0, 3.2, 1.4],
		["dot", 9.0, 20.5], ["dot", 22.5, 16.5],
		["line", 6.0, 22.5, 12.0, 20.0],
	],
	# Dead wood: a few dry sticks thrown down across each other, one with a twig
	# still on it, so it never reads as driftwood's one sea-worn log or timber's cut ends.
	&"sticks": [
		["bar", "a3", 4.0, 26.0, 27.0, 7.0, 3.4, 2.0],
		["bar", "a4", 5.0, 8.0, 26.0, 25.0, 3.0, 1.8],
		["bar", "a4", 16.0, 16.5, 22.0, 3.5, 1.8, 1.0],
		["bar", "a2", 3.0, 18.0, 28.0, 20.0, 2.4, 1.6],
		["dot", 11.0, 20.5], ["dot", 20.5, 12.0],
		["line", 7.0, 23.0, 12.0, 19.0],
	],
	&"scrap": [
		["poly", "a3", [5.0, 9.0, 25.0, 5.0, 28.0, 23.0, 21.0, 24.0, 19.0, 27.5, 7.0, 27.0]],
		["poly", "a4", [5.0, 9.0, 25.0, 5.0, 25.5, 8.0, 5.5, 12.0]],
		["dot", 9.0, 15.0], ["dot", 23.0, 12.0], ["dot", 10.0, 23.5], ["dot", 24.5, 20.0],
	],
	&"shell": [
		# Mussels: a pair of long dark shells, pointed at the hinge, each with its
		# pale lip, so at the feed's size they are still shells and not a stone.
		["poly", "a2", [3.0, 27.0, 5.0, 21.0, 14.0, 12.0, 24.0, 5.0, 28.0, 5.0, 27.0, 9.0, 19.0, 19.0, 9.0, 27.0]],
		["bar", "b5", 6.5, 23.5, 25.0, 7.0, 1.4, 0.8],
		["poly", "a3", [7.0, 30.5, 10.0, 25.0, 19.0, 19.0, 28.0, 15.0, 31.0, 16.0, 29.0, 20.0, 20.0, 26.0, 11.0, 30.5]],
		["bar", "b5", 10.5, 28.0, 28.5, 16.5, 1.4, 0.8],
	],
	&"greens": [
		["bar", "a4", 16.0, 30.0, 8.0, 6.0, 2.2, 1.6],
		["bar", "a3", 16.0, 30.0, 17.0, 3.0, 2.4, 1.6],
		["bar", "a4", 16.0, 30.0, 26.0, 8.0, 2.2, 1.4],
		["ell", "a5", 10.0, 12.0, 3.0, 1.6], ["ell", "a4", 22.5, 15.0, 3.2, 1.6],
		["line", 12.0, 25.5, 20.0, 24.5], ["line", 12.0, 27.0, 20.0, 26.0],
	],
	&"bread": [
		["ell", "a3", 16.0, 19.5, 13.5, 8.5],
		["ell", "a5", 15.0, 16.5, 10.5, 5.5],
		["line", 9.0, 17.0, 12.0, 14.0], ["line", 14.0, 17.5, 17.0, 14.0], ["line", 19.0, 18.0, 22.0, 15.0],
	],
	&"bowl": [
		["poly", "b3", [3.0, 15.0, 29.0, 15.0, 26.5, 23.0, 21.0, 28.0, 11.0, 28.0, 5.5, 23.0]],
		["ell", "a4", 16.0, 15.0, 13.0, 3.2],
		["line", 12.0, 9.0, 11.0, 6.0, 12.5, 3.0], ["line", 18.0, 9.5, 17.0, 6.5, 18.5, 3.5],
	],
	&"ore": [
		["poly", "a3", [4.0, 20.0, 8.0, 10.0, 17.0, 6.0, 26.0, 9.5, 29.0, 19.0, 24.0, 27.0, 11.0, 28.0]],
		["poly", "a4", [8.0, 10.0, 17.0, 6.0, 26.0, 9.5, 17.0, 13.0]],
		["ell", "b4", 12.0, 18.0, 2.4, 1.8], ["ell", "b4", 21.0, 15.0, 2.0, 1.6], ["ell", "b3", 18.0, 23.0, 1.8, 1.4],
	],
	&"ingot": [
		# A cast bar: the sides slope in to a narrow top, so it reads as poured
		# metal, not a block.
		["poly", "a3", [2.0, 27.5, 27.5, 22.5, 23.5, 14.5, 7.5, 18.0]],
		["poly", "a2", [27.5, 22.5, 30.5, 18.0, 26.0, 10.5, 23.5, 14.5]],
		["poly", "a5", [7.5, 18.0, 23.5, 14.5, 26.0, 10.5, 11.0, 13.5]],
		["poly", "a4", [2.0, 27.5, 7.5, 18.0, 11.0, 13.5, 4.0, 21.0]],
		["line", 13.5, 15.5, 20.0, 14.0],
	],
	&"lump": [
		["poly", "a3", [4.0, 25.0, 6.5, 15.0, 13.0, 9.5, 22.0, 10.5, 28.0, 17.0, 26.5, 26.0, 15.0, 28.5]],
		["poly", "a4", [6.5, 15.0, 13.0, 9.5, 22.0, 10.5, 16.0, 16.0]],
		["line", 16.0, 16.0, 18.0, 24.0],
	],
	# Copper: the seam's rock with the metal running through it in a branching vein.
	&"ore_vein": [
		["poly", "a3", [3.0, 21.0, 7.0, 11.0, 15.0, 6.0, 25.0, 8.0, 29.0, 17.0, 25.0, 27.0, 12.0, 28.0]],
		["poly", "a4", [7.0, 11.0, 15.0, 6.0, 25.0, 8.0, 16.0, 12.0]],
		["bar", "b4", 5.0, 24.0, 16.0, 16.0, 3.0, 2.2],
		["bar", "b4", 16.0, 16.0, 27.0, 12.0, 2.2, 1.4],
		["bar", "b3", 16.0, 16.0, 19.0, 26.0, 2.0, 1.2],
		["ell", "b5", 16.0, 16.0, 2.6, 2.2],
	],
	# Tin: dark heavy crystals standing up out of their rock.
	&"ore_crystal": [
		["poly", "a3", [3.0, 27.0, 5.0, 20.0, 12.0, 18.0, 22.0, 19.0, 29.0, 24.0, 27.0, 29.5, 6.0, 29.5]],
		["poly", "b2", [7.0, 21.0, 7.5, 10.0, 11.5, 6.5, 16.0, 9.5, 15.5, 21.0]],
		["poly", "b4", [7.5, 10.0, 11.5, 6.5, 16.0, 9.5, 12.0, 12.5]],
		["poly", "b2", [16.5, 22.0, 17.5, 14.0, 21.5, 11.5, 26.0, 14.0, 25.0, 23.0]],
		["poly", "b4", [17.5, 14.0, 21.5, 11.5, 26.0, 14.0, 22.0, 16.5]],
		["line", 12.0, 12.5, 11.5, 20.5], ["line", 22.0, 16.5, 21.5, 22.5],
	],
	# A whelk: one spiral shell, its whorls stepping down to a point, the mouth
	# dark at the wide end.
	&"fish": [
		["ell", "a3", 13.0, 16.0, 10.0, 5.6],
		["ell", "a4", 12.5, 18.2, 7.4, 2.6],
		["poly", "a2", [22.0, 16.0, 29.5, 10.0, 27.5, 16.0, 29.5, 22.0]],
		["poly", "a4", [9.5, 11.0, 14.5, 7.5, 17.5, 11.2]],
		["line", 8.5, 12.0, 8.0, 19.5],
		["dot", 6.5, 15.0],
	],
	&"lens_ice": [
		["poly", "a4", [10.0, 6.0, 22.0, 6.0, 28.0, 16.0, 22.0, 26.0, 10.0, 26.0, 4.0, 16.0]],
		["poly", "a5", [12.0, 9.0, 20.0, 9.0, 24.0, 16.0, 20.0, 23.0, 12.0, 23.0, 8.0, 16.0]],
		["poly", "a6", [12.0, 10.0, 16.5, 9.2, 13.0, 14.5]],
		["line", 12.0, 9.0, 20.0, 23.0], ["line", 4.0, 16.0, 8.0, 16.0],
	],
	&"whelk": [
		["ell", "a3", 11.5, 22.0, 8.0, 6.8],
		["ell", "a4", 17.0, 15.5, 5.6, 4.8],
		["ell", "a4", 21.5, 10.0, 3.8, 3.4],
		["ell", "a5", 25.0, 6.0, 2.4, 2.2],
		["poly", "a5", [25.0, 4.0, 29.5, 1.5, 27.0, 6.5]],
		["ell", "a1", 8.5, 25.0, 3.8, 2.8],
		["bar", "a3", 5.5, 27.5, 2.0, 30.5, 2.4, 1.4],
	],
	# Bladder wrack: a flat forked frond with its floats in pairs along the midrib.
	&"wrack": [
		["bar", "a3", 15.5, 30.0, 16.0, 18.0, 2.6, 2.2],
		["bar", "a3", 16.0, 18.0, 8.0, 5.0, 4.4, 2.6],
		["bar", "a3", 16.0, 18.0, 25.5, 4.5, 4.4, 2.6],
		["ell", "a5", 10.5, 10.5, 2.4, 2.4], ["ell", "a5", 13.5, 15.0, 2.2, 2.2],
		["ell", "a5", 22.5, 9.5, 2.4, 2.4], ["ell", "a5", 19.5, 14.5, 2.2, 2.2],
		["line", 16.0, 18.0, 8.5, 5.5], ["line", 16.0, 18.0, 25.0, 5.0],
	],
	# Reeds: a few straight stalks cut together and tied, heads still on. Kept
	# upright and apart, since splayed they are the greens' fan.
	&"reeds": [
		["bar", "a3", 9.0, 30.0, 12.0, 7.0, 2.6, 1.8],
		["bar", "a4", 15.0, 30.0, 17.0, 5.0, 2.6, 1.8],
		["bar", "a3", 21.0, 30.0, 22.5, 7.5, 2.6, 1.8],
		["bar", "a5", 12.2, 9.5, 12.9, 1.0, 3.6, 0.8],
		["bar", "a5", 17.2, 7.5, 17.7, 0.0, 3.6, 0.8],
		["bar", "a5", 22.6, 10.0, 23.2, 2.0, 3.6, 0.8],
		["bar", "b1", 6.5, 21.0, 24.5, 20.0, 3.4, 3.4],
	],
	# Gorse cut: a spined branch with its flowers on it.
	&"gorse": [
		["bar", "a3", 4.0, 29.0, 27.0, 5.0, 2.6, 1.4],
		["bar", "a3", 13.0, 19.5, 6.0, 12.0, 1.8, 1.0],
		["bar", "a3", 19.0, 13.0, 27.0, 17.0, 1.8, 1.0],
		["line", 8.0, 25.0, 5.0, 22.0], ["line", 10.5, 22.5, 13.5, 25.5], ["line", 15.5, 17.0, 18.0, 20.0],
		["line", 17.5, 14.5, 14.5, 11.5], ["line", 22.5, 9.5, 25.5, 12.0], ["line", 23.5, 8.5, 21.0, 5.5],
		["ell", "b4", 6.5, 11.5, 2.4, 2.2], ["ell", "b4", 27.0, 17.0, 2.4, 2.2],
		["ell", "b5", 27.0, 5.0, 2.6, 2.4], ["ell", "b4", 12.0, 15.5, 2.0, 1.8],
	],
	# Crottle: the lichen scraped off with its chip of rock, a tuft forking like
	# antler standing up off it. Drawn as a crust on the stone it read as
	# the stone, since the scan keeps value and not hue.
	&"crottle": [
		["poly", "a2", [4.0, 26.0, 7.0, 21.0, 25.0, 20.0, 29.0, 25.0, 25.0, 29.5, 8.0, 29.5]],
		["bar", "a4", 16.0, 24.0, 16.0, 14.5, 3.6, 2.8],
		["bar", "a4", 16.0, 15.0, 9.0, 8.5, 2.8, 2.0],
		["bar", "a4", 16.0, 15.0, 23.0, 8.5, 2.8, 2.0],
		["bar", "a5", 16.0, 15.0, 16.0, 5.0, 2.6, 1.8],
		["bar", "a5", 9.5, 9.0, 5.5, 3.5, 2.0, 1.4], ["bar", "a5", 9.5, 9.0, 12.0, 3.0, 2.0, 1.4],
		["bar", "a5", 22.5, 9.0, 20.0, 3.0, 2.0, 1.4], ["bar", "a5", 22.5, 9.0, 26.5, 3.5, 2.0, 1.4],
	],
	# Peat: a cut turf, square-edged from the spade, roots standing out of its top.
	&"peat": [
		["poly", "a3", [4.0, 14.0, 21.0, 10.0, 28.5, 14.0, 28.5, 24.0, 11.0, 29.0, 4.0, 24.5]],
		["poly", "a4", [4.0, 14.0, 21.0, 10.0, 28.5, 14.0, 11.0, 18.5]],
		["line", 11.0, 18.5, 11.0, 29.0],
		["line", 8.0, 14.5, 7.0, 10.0], ["line", 14.0, 13.5, 14.5, 8.5], ["line", 20.0, 13.0, 21.5, 7.5],
		["line", 15.0, 22.0, 26.0, 19.0], ["line", 15.0, 25.5, 24.0, 23.0],
		["dot", 6.5, 20.0], ["dot", 19.0, 21.0],
	],
	# Limestone: broken off in its beds, the layers stepped where they parted.
	&"limestone": [
		["poly", "a3", [3.0, 27.5, 3.5, 21.0, 25.0, 19.5, 26.0, 26.5]],
		["poly", "a4", [6.0, 21.0, 7.0, 14.5, 27.0, 13.0, 28.5, 19.5]],
		["poly", "a5", [10.0, 14.5, 11.0, 8.0, 26.0, 7.0, 27.0, 13.0]],
		["line", 5.0, 24.5, 24.5, 23.0], ["line", 12.5, 11.0, 17.0, 10.5],
	],
	# Hushstone: a dark close-grained stone, flat-faced where it was broken off a
	# carved face, one pale seam of the second ramp running through it.
	&"hushstone": [
		["poly", "a2", [4.0, 22.0, 6.0, 13.0, 14.0, 8.0, 24.0, 9.5, 29.0, 17.0, 27.0, 25.0, 15.0, 28.5, 6.0, 27.0]],
		["poly", "a3", [6.0, 13.0, 14.0, 8.0, 24.0, 9.5, 27.0, 15.0, 17.0, 16.5, 8.0, 17.0]],
		["bar", "b4", 8.0, 19.5, 26.5, 18.0, 1.6, 1.0],
		["line", 9.0, 22.0, 20.0, 23.5], ["line", 17.0, 16.5, 21.0, 20.0],
	],
	# Brimstone: the crust off a vent, pitted where the gas came through, crystals
	# grown up out of it.
	&"brimstone": [
		["poly", "a4", [3.0, 26.0, 5.0, 17.0, 11.0, 12.0, 17.0, 14.0, 22.0, 9.0, 28.5, 15.0, 29.0, 26.0, 16.0, 29.0]],
		["poly", "a5", [10.0, 13.0, 12.5, 3.5, 15.0, 13.0]],
		["poly", "a5", [20.0, 10.5, 23.0, 1.5, 25.5, 11.5]],
		["poly", "a5", [26.0, 13.5, 29.5, 7.5, 29.0, 16.0]],
		["ell", "a2", 10.0, 20.5, 2.2, 1.7], ["ell", "a2", 19.5, 19.0, 2.0, 1.6],
		["ell", "a2", 24.0, 23.5, 1.7, 1.4], ["ell", "a2", 14.0, 25.0, 1.5, 1.2],
	],
	&"sack": [
		["poly", "a4", [8.0, 29.0, 4.5, 21.0, 8.0, 13.0, 12.5, 10.0, 19.5, 10.0, 24.0, 13.0, 27.5, 21.0, 24.0, 29.0]],
		["poly", "a3", [12.5, 10.0, 10.0, 4.0, 16.0, 7.5, 22.0, 4.0, 19.5, 10.0]],
		["line", 12.0, 10.5, 20.0, 10.5],
		["line", 11.0, 17.0, 13.0, 24.0],
	],
	&"cloth": [
		# Folded twice and set down: soft corners, a woven stripe, loose ends.
		["poly", "a3", [3.0, 23.0, 6.5, 18.5, 26.0, 16.0, 30.0, 20.5, 28.0, 27.0, 17.0, 29.0, 4.5, 28.5]],
		["poly", "a4", [5.0, 18.5, 7.5, 11.5, 16.0, 9.0, 25.0, 8.5, 28.5, 13.0, 27.0, 18.5, 17.0, 20.5, 6.5, 20.5]],
		["line", 5.0, 25.0, 17.0, 24.5, 29.0, 23.0],
		["line", 8.0, 15.5, 17.0, 13.5, 27.5, 13.5],
		["line", 3.5, 26.5, 1.5, 28.5], ["line", 5.5, 28.5, 4.0, 31.0], ["line", 28.5, 26.0, 30.5, 28.5],
	],
	&"basket": [
		["line", 7.0, 14.0, 9.0, 6.0, 16.0, 3.5, 23.0, 6.0, 25.0, 14.0],
		["poly", "a4", [4.0, 14.0, 28.0, 14.0, 25.0, 28.5, 7.0, 28.5]],
		["line", 5.0, 19.0, 27.0, 19.0], ["line", 6.0, 24.0, 26.0, 24.0],
		["line", 12.0, 14.0, 12.5, 28.5], ["line", 20.0, 14.0, 19.5, 28.5],
	],
	&"pot": [
		["ell", "a3", 16.0, 20.0, 12.0, 9.5],
		["poly", "a2", [6.0, 11.0, 26.0, 11.0, 24.5, 15.0, 7.5, 15.0]],
		["ell", "a4", 16.0, 10.5, 10.0, 3.0],
		["line", 3.0, 14.0, 5.0, 17.0], ["line", 29.0, 14.0, 27.0, 17.0],
	],
	&"lamp": [
		["poly", "a3", [9.0, 26.0, 23.0, 26.0, 26.0, 30.0, 6.0, 30.0]],
		["poly", "a2", [10.0, 8.0, 22.0, 8.0, 23.0, 26.0, 9.0, 26.0]],
		["poly", "linen:5", [12.0, 10.0, 20.0, 10.0, 21.0, 24.0, 11.0, 24.0]],
		["poly", "ember:4", [16.0, 12.0, 18.5, 18.0, 16.0, 21.0, 13.5, 18.0]],
		["poly", "a4", [11.0, 3.0, 21.0, 3.0, 22.0, 8.0, 10.0, 8.0]],
		["line", 16.0, 3.0, 16.0, 0.5],
	],
	&"flask": [
		["ell", "b3", 16.0, 21.5, 10.0, 8.5],
		["bar", "a3", 16.0, 14.0, 16.0, 6.0, 5.0, 4.0],
		["poly", "b2", [13.5, 2.0, 18.5, 2.0, 18.5, 6.0, 13.5, 6.0]],
		["line", 9.0, 19.0, 11.0, 16.5],
	],
	&"hone": [
		["poly", "a2", [4.0, 21.0, 25.0, 12.0, 28.5, 16.0, 7.5, 25.5]],
		["poly", "a4", [4.0, 21.0, 22.0, 13.0, 25.0, 12.0, 26.0, 13.5, 6.0, 22.5]],
		["poly", "a3", [4.0, 17.0, 23.0, 8.5, 25.0, 12.0, 4.0, 21.0]],
	],
	&"kit": [
		["poly", "a3", [4.0, 12.0, 12.0, 5.0, 20.0, 5.0, 28.0, 12.0, 26.0, 24.0, 16.0, 29.0, 6.0, 24.0]],
		["poly", "a4", [8.0, 11.0, 12.0, 8.0, 20.0, 8.0, 24.0, 11.0, 23.0, 15.0, 9.0, 15.0]],
		["dot", 9.0, 19.0], ["dot", 23.0, 19.0],
		["glow", 16.0, 21.0, 2.0],
	],
	&"dram": [
		# A found cell, ruled: a squat case on the diagonal, a terminal at the
		# foot, a stepped shoulder, and the charge showing through a slot.
		["bar", "a2", 4.0, 28.0, 8.5, 23.5, 6.5, 6.5],
		["bar", "a3", 7.5, 24.5, 19.5, 12.5, 14.5, 12.0],
		["bar", "a4", 18.5, 13.5, 23.0, 9.0, 12.0, 7.5],
		["bar", "a2", 22.5, 9.5, 27.0, 5.0, 4.5, 3.5],
		["bar", "l", 10.5, 21.5, 17.0, 15.0, 5.2, 4.4],
		["line", 9.9, 18.6, 13.4, 22.1], ["line", 14.1, 14.4, 17.6, 17.9],
		["dot", 7.0, 18.5], ["dot", 17.5, 23.5],
		["glow", 13.75, 18.25, 1.3],
	],
	&"paper": [
		["poly", "linen:5", [7.0, 4.0, 24.0, 3.0, 26.5, 28.5, 7.5, 29.0]],
		["line", 10.0, 9.0, 21.0, 8.5], ["line", 10.0, 13.0, 22.0, 12.5], ["line", 10.0, 17.0, 18.0, 16.5],
		["line", 10.0, 23.0, 16.0, 26.0, 22.0, 21.0],
	],
	&"berries": [
		["line", 12.0, 14.0, 16.0, 6.0, 21.0, 13.0], ["line", 16.0, 6.0, 17.0, 21.0],
		["ell", "b4", 10.0, 8.0, 5.5, 2.6], ["ell", "b3", 22.0, 7.0, 5.0, 2.4],
		["ell", "a3", 11.5, 19.0, 5.0, 5.0], ["ell", "a4", 21.5, 18.0, 5.0, 5.0], ["ell", "a3", 16.5, 26.0, 5.0, 4.6],
	],
	&"beam": [
		["bar", "a2", 3.0, 29.0, 9.0, 23.0, 4.5, 4.5],
		["bar", "a3", 8.0, 24.0, 23.0, 9.0, 6.0, 6.0],
		["line", 11.0, 17.0, 15.0, 21.0], ["line", 14.0, 14.0, 18.0, 18.0],
		["poly", "a4", [20.0, 8.0, 24.0, 4.0, 28.0, 8.0, 24.0, 12.0]],
		["glow", 25.5, 6.5, 2.6],
	],
	&"broad": [
		["poly", "a2", [12.0, 18.0, 20.0, 18.0, 20.0, 30.0, 12.0, 30.0]],
		["line", 12.0, 22.0, 20.0, 22.0], ["line", 12.0, 26.0, 20.0, 26.0],
		["poly", "a2", [13.5, 11.0, 18.5, 11.0, 18.5, 18.0, 13.5, 18.0]],
		["poly", "a3", [3.0, 4.0, 29.0, 4.0, 29.0, 11.0, 3.0, 11.0]],
		["glow", 8.0, 7.5, 2.0], ["glow", 16.0, 7.5, 2.0], ["glow", 24.0, 7.5, 2.0],
	],
	&"blade": [
		["bar", "a2", 4.0, 29.0, 11.0, 22.0, 4.5, 4.5],
		["poly", "a3", [8.0, 18.0, 17.0, 27.0, 15.0, 29.0, 6.0, 20.0]],
		["poly", "a4", [13.0, 19.0, 27.0, 3.0, 29.5, 5.0, 16.0, 22.0]],
		["glow", 21.5, 11.5, 1.8],
	],
	&"hammer": [
		["bar", "a2", 16.0, 13.0, 16.0, 30.5, 4.5, 4.5],
		["line", 14.0, 22.0, 18.0, 22.0], ["line", 14.0, 26.0, 18.0, 26.0],
		["poly", "a3", [3.0, 3.0, 29.0, 3.0, 29.0, 13.0, 3.0, 13.0]],
		["poly", "a4", [3.0, 3.0, 7.0, 3.0, 7.0, 13.0, 3.0, 13.0]], ["poly", "a4", [25.0, 3.0, 29.0, 3.0, 29.0, 13.0, 25.0, 13.0]],
		["glow", 16.0, 8.0, 2.8],
	],
	&"torch": [
		["ell", "a2", 9.0, 23.0, 6.0, 6.0],
		["bar", "a3", 11.0, 21.0, 21.0, 11.0, 6.0, 5.0],
		["poly", "a4", [19.0, 9.0, 25.0, 3.0, 29.0, 7.0, 23.0, 13.0]],
		["glow", 27.0, 5.0, 2.6],
	],
	&"brace": [
		["poly", "a2", [8.0, 13.0, 24.0, 13.0, 24.0, 19.0, 8.0, 19.0]],
		["poly", "a3", [5.0, 6.0, 27.0, 6.0, 27.0, 13.0, 5.0, 13.0]],
		["poly", "a3", [5.0, 19.0, 27.0, 19.0, 27.0, 26.0, 5.0, 26.0]],
		["dot", 9.0, 9.5], ["dot", 23.0, 9.5], ["dot", 9.0, 22.5], ["dot", 23.0, 22.5],
	],
	&"rig": [
		["bar", "a3", 9.0, 3.0, 9.0, 30.0, 3.5, 3.5],
		["bar", "a3", 23.0, 3.0, 23.0, 30.0, 3.5, 3.5],
		["bar", "a2", 9.0, 10.0, 23.0, 10.0, 3.0, 3.0],
		["bar", "a2", 9.0, 21.0, 23.0, 21.0, 3.0, 3.0],
		["line", 9.0, 3.0, 4.0, 1.0], ["line", 23.0, 3.0, 28.0, 1.0],
	],
	&"lens": [
		["ell", "a3", 16.0, 16.0, 13.0, 13.0],
		["ell", "a2", 16.0, 16.0, 8.0, 8.0],
		["dot", 16.0, 5.0], ["dot", 16.0, 27.0], ["dot", 5.0, 16.0], ["dot", 27.0, 16.0],
		["glow", 16.0, 16.0, 4.5],
	],
	&"aerial": [
		["bar", "a2", 16.0, 21.0, 16.0, 5.0, 2.4, 2.4],
		["line", 11.0, 10.0, 21.0, 10.0], ["line", 12.5, 15.0, 19.5, 15.0],
		["poly", "a3", [5.0, 29.0, 27.0, 29.0, 22.0, 20.0, 10.0, 20.0]],
		["glow", 16.0, 4.0, 2.2],
	],
	&"bundle": [
		["poly", "a4", [5.0, 16.0, 11.0, 8.0, 21.0, 8.0, 27.0, 16.0, 25.0, 27.0, 7.0, 27.0]],
		["line", 5.5, 17.0, 26.5, 17.0], ["line", 16.0, 8.0, 16.0, 27.0],
	],
	# Gear against a place's pressures (the hazards package). The mended ones show
	# their join: a plate panel and the cord that binds it (docs/ART.md §12).
	&"mask": [
		["poly", "a3", [5.0, 9.0, 27.0, 9.0, 28.0, 17.0, 22.0, 25.0, 10.0, 25.0, 4.0, 17.0]],
		["poly", "a4", [7.0, 10.5, 25.0, 10.5, 25.5, 15.0, 6.5, 15.0]],
		["ell", "b3", 16.0, 19.0, 6.0, 6.0],
		["ell", "b5", 16.0, 19.0, 3.0, 3.0],
		["line", 5.0, 10.0, 1.5, 6.0], ["line", 27.0, 10.0, 30.5, 6.0],
		["dot", 10.0, 19.0], ["dot", 22.0, 19.0],
	],
	&"hat": [
		["poly", "a4", [10.0, 20.0, 11.0, 9.0, 14.0, 6.5, 19.0, 6.5, 22.0, 9.0, 23.0, 20.0]],
		["poly", "a3", [2.0, 20.0, 30.0, 20.0, 28.0, 25.0, 4.0, 25.0]],
		["poly", "b3", [10.5, 15.0, 22.5, 15.0, 22.5, 19.0, 10.5, 19.0]],
		["line", 3.5, 22.5, 28.5, 22.5],
	],
	&"vest": [
		["poly", "a3", [7.0, 5.0, 13.0, 7.0, 19.0, 7.0, 25.0, 5.0, 27.0, 26.0, 5.0, 26.0]],
		["poly", "a2", [13.0, 7.0, 19.0, 7.0, 18.0, 13.0, 14.0, 13.0]],
		["poly", "b4", [9.0, 14.0, 23.0, 14.0, 23.0, 23.0, 9.0, 23.0]],
		["line", 11.0, 15.0, 11.0, 22.0], ["line", 14.0, 15.0, 14.0, 22.0],
		["line", 18.0, 15.0, 18.0, 22.0], ["line", 21.0, 15.0, 21.0, 22.0],
		["dot", 8.0, 8.0], ["dot", 24.0, 8.0],
	],
	&"boot": [
		["poly", "a3", [9.0, 4.0, 17.0, 4.0, 18.0, 18.0, 27.0, 20.0, 28.0, 25.0, 7.0, 25.0, 8.0, 12.0]],
		["poly", "b3", [6.0, 25.0, 29.0, 25.0, 29.0, 29.0, 6.0, 29.0]],
		["line", 9.5, 8.0, 16.5, 8.0], ["line", 9.5, 12.0, 17.0, 12.0],
		["dot", 10.0, 27.0], ["dot", 17.0, 27.0],
		["glow", 24.0, 27.0, 2.4],
	],
	&"wing": [
		["poly", "a3", [3.0, 8.0, 12.0, 10.0, 11.0, 17.0, 3.5, 15.0]],
		["poly", "a4", [12.0, 10.0, 21.0, 13.0, 19.5, 19.0, 11.0, 17.0]],
		["poly", "a5", [21.0, 13.0, 30.0, 17.0, 27.5, 22.0, 19.5, 19.0]],
		["bar", "b3", 2.5, 7.0, 30.5, 16.5, 2.6, 2.0],
		["line", 8.0, 9.5, 7.0, 16.0], ["line", 16.0, 11.5, 15.0, 18.0], ["line", 25.0, 15.0, 23.5, 21.0],
		["dot", 6.0, 12.0], ["dot", 15.0, 15.0], ["dot", 24.0, 18.5],
	],
	&"coil": [
		["poly", "a2", [9.0, 4.0, 23.0, 4.0, 23.0, 7.0, 9.0, 7.0]],
		["poly", "a2", [9.0, 25.0, 23.0, 25.0, 23.0, 28.0, 9.0, 28.0]],
		["bar", "a4", 10.0, 8.0, 22.0, 11.0, 2.4, 2.4],
		["bar", "a4", 22.0, 11.0, 10.0, 14.0, 2.4, 2.4],
		["bar", "a4", 10.0, 14.0, 22.0, 17.0, 2.4, 2.4],
		["bar", "a4", 22.0, 17.0, 10.0, 20.0, 2.4, 2.4],
		["bar", "a4", 10.0, 20.0, 22.0, 24.0, 2.4, 2.4],
	],
	&"scan_lens": [
		["poly", "a3", [8.0, 8.0, 24.0, 8.0, 24.0, 24.0, 8.0, 24.0]],
		["ell", "a4", 16.0, 16.0, 6.5, 6.5],
		["ell", "b5", 16.0, 16.0, 3.0, 3.0],
		["bar", "b3", 4.0, 12.0, 28.0, 12.0, 2.2, 2.2],
		["bar", "b3", 4.0, 20.0, 28.0, 20.0, 2.2, 2.2],
		["dot", 8.0, 8.0], ["dot", 24.0, 8.0], ["dot", 8.0, 24.0], ["dot", 24.0, 24.0],
		["glow", 16.0, 16.0, 3.4],
	],
	&"foil": [
		["poly", "a4", [4.0, 7.0, 28.0, 5.0, 29.0, 22.0, 5.0, 24.0]],
		["line", 4.5, 12.0, 28.5, 10.0],
		["line", 4.5, 17.0, 28.5, 15.0],
		["bar", "b3", 5.0, 24.0, 29.0, 22.0, 2.2, 2.2],
		["dot", 8.0, 23.5], ["dot", 16.0, 23.0], ["dot", 24.0, 22.4],
	],
	&"signet": [
		["poly", "a3", [7.0, 4.0, 25.0, 4.0, 25.0, 20.0, 7.0, 20.0]],
		["poly", "a5", [9.5, 7.0, 22.5, 7.0, 22.5, 11.0, 9.5, 11.0]],
		["poly", "a2", [10.0, 20.0, 13.5, 20.0, 13.5, 28.0, 10.0, 28.0]],
		["poly", "a2", [18.5, 20.0, 22.0, 20.0, 22.0, 28.0, 18.5, 28.0]],
		["dot", 9.0, 17.5], ["dot", 23.0, 17.5],
		["glow", 16.0, 9.0, 3.6],
	],
	&"shield": [
		["poly", "a3", [5.0, 4.0, 27.0, 4.0, 27.0, 17.0, 16.0, 29.0, 5.0, 17.0]],
		["poly", "a4", [8.0, 7.0, 24.0, 7.0, 24.0, 16.0, 16.0, 24.5, 8.0, 16.0]],
		["line", 8.0, 11.5, 24.0, 11.5],
		["dot", 7.0, 6.0], ["dot", 25.0, 6.0], ["dot", 7.0, 15.0], ["dot", 25.0, 15.0],
		["glow", 16.0, 11.5, 3.2],
	],
}

## Shapes drawn with a ruler.
const FOUND_SHAPES: Array[StringName] = [&"glim", &"scrap", &"kit", &"dram", &"beam", &"broad", &"blade", &"hammer", &"torch", &"brace", &"rig", &"lens", &"aerial", &"signet", &"shield"]

## Stations, on a 48x32 grid: [parts, ramp a, ramp b, found].
const STATIONS := {
	&"fire": [[
		["poly", "ember:3", [16.0, 22.0, 18.0, 12.0, 22.0, 15.0, 24.0, 3.0, 28.0, 13.0, 31.0, 9.0, 33.0, 22.0]],
		["poly", "ember:4", [20.0, 22.0, 22.0, 17.0, 24.5, 10.0, 27.0, 18.0, 29.0, 22.0]],
		["bar", "b3", 9.0, 27.5, 34.0, 20.0, 4.0, 3.2],
		["bar", "b4", 14.0, 20.0, 39.0, 27.5, 3.6, 4.0],
		["ell", "a3", 8.0, 27.0, 5.0, 3.5], ["ell", "a4", 17.5, 29.0, 5.0, 3.0],
		["ell", "a3", 28.0, 29.0, 5.0, 3.0], ["ell", "a4", 38.5, 27.0, 5.0, 3.5],
	], &"stone", &"earth", false],
	&"bench": [[
		["bar", "b3", 8.0, 16.0, 6.0, 31.0, 3.2, 3.2],
		["bar", "b3", 40.0, 16.0, 42.0, 31.0, 3.2, 3.2],
		["bar", "b2", 7.0, 25.0, 41.0, 25.0, 2.0, 2.0],
		["poly", "b4", [2.0, 11.0, 46.0, 11.0, 46.0, 16.0, 2.0, 16.0]],
		["line", 4.0, 13.5, 20.0, 13.5],
		["poly", "a4", [30.0, 4.0, 38.0, 4.0, 38.0, 8.0, 30.0, 8.0]],
		["bar", "b3", 34.0, 8.0, 34.0, 11.0, 2.0, 2.0],
		["bar", "a3", 12.0, 9.5, 24.0, 7.5, 1.6, 1.2],
	], &"stone", &"earth", false],
	&"kiln": [[
		["poly", "b3", [8.0, 31.0, 8.0, 17.0, 13.0, 8.0, 24.0, 4.0, 35.0, 8.0, 40.0, 17.0, 40.0, 31.0]],
		["line", 9.0, 22.0, 39.0, 22.0], ["line", 12.0, 14.0, 36.0, 14.0],
		["line", 16.0, 14.0, 15.0, 22.0], ["line", 30.0, 14.0, 31.0, 22.0], ["line", 23.0, 22.0, 23.0, 31.0],
		["poly", "ink:2", [18.0, 31.0, 18.0, 25.0, 24.0, 21.0, 30.0, 25.0, 30.0, 31.0]],
		["poly", "ember:4", [21.0, 31.0, 24.0, 25.0, 27.0, 31.0]],
		["bar", "b2", 24.0, 4.5, 24.0, 0.5, 4.0, 3.0],
	], &"rust", &"stone", false],
	&"wheel": [[
		["ell", "a3", 20.0, 14.0, 11.0, 11.0],
		["ell", "a4", 20.0, 14.0, 3.0, 3.0],
		["line", 20.0, 3.0, 20.0, 25.0], ["line", 9.0, 14.0, 31.0, 14.0],
		["bar", "a2", 20.0, 16.0, 30.0, 31.0, 2.4, 2.4],
		["bar", "a2", 20.0, 16.0, 10.0, 31.0, 2.4, 2.4],
		["poly", "b4", [34.0, 20.0, 44.0, 20.0, 42.0, 31.0, 36.0, 31.0]],
	], &"earth", &"linen", false],
	&"loom": [[
		["bar", "a3", 8.0, 2.0, 8.0, 31.0, 3.0, 3.0],
		["bar", "a3", 40.0, 2.0, 40.0, 31.0, 3.0, 3.0],
		["poly", "b4", [10.0, 8.0, 38.0, 8.0, 38.0, 24.0, 10.0, 24.0]],
		["line", 14.0, 8.0, 14.0, 24.0], ["line", 19.0, 8.0, 19.0, 24.0], ["line", 24.0, 8.0, 24.0, 24.0],
		["line", 29.0, 8.0, 29.0, 24.0], ["line", 34.0, 8.0, 34.0, 24.0],
		["bar", "a4", 5.0, 5.0, 43.0, 5.0, 3.0, 3.0],
	], &"earth", &"rust", false],
	&"hand": [[
		["bar", "b3", 6.0, 27.0, 40.0, 18.0, 5.0, 3.0],
		["dot", 14.0, 24.5],
		["bar", "b3", 16.0, 12.0, 23.0, 5.0, 3.4, 3.0],
		["poly", "a5", [21.5, 7.0, 42.0, 22.0, 34.0, 20.0, 19.0, 9.5]],
	], &"stone", &"earth", false],
}

static var _cache := {}
## Images drawn ahead on a worker (a sketch takes tens of milliseconds), waiting
## to become textures on the main thread.
static var _ready := {}
## Keys whose raster is out on a worker right now, so a page redrawing every
## frame asks for one only once.
static var _out := {}
static var _lock := Mutex.new()
static var _tasks: Array[int] = []


## Draw item `id` sketched `size` pixels square with its top-left at `at`, if it
## is drawn yet. Nothing is drawn while its raster is still out on a worker, and
## `UiScreen` redraws the page when it lands — the same way the slate's own bezel
## is a plain frame until its bake is in.
##
## **Never block for one.** A sketch is rastered a pixel at a time in GDScript, so
## it costs the square of its size: measured, one item at 78 pixels is 57 ms and
## the same item at the base's 234 is 586 ms. Drawn on demand that is a half
## second of frozen main thread every time the carrying page opens, on the one
## interaction a player makes most.
static func draw_item(ci: CanvasItem, id: StringName, at: Vector2i, size: int) -> void:
	var tex := item_texture(id, size)
	if tex != null:
		ci.draw_texture(tex, Vector2(at))


## The item's texture, or null while its raster is still out (one is started).
static func item_texture(id: StringName, size: int) -> ImageTexture:
	return _texture("i|%s|%d" % [id, size], func() -> Dictionary: return _item_job(id, size))


## Draw a station sketched `w` pixels wide (height follows the 48x32 grid).
static func draw_station(ci: CanvasItem, station: StringName, at: Vector2i, w: int) -> void:
	var tex := _texture("s|%s|%d" % [station, w], func() -> Dictionary: return _station_job(station, w))
	if tex != null:
		ci.draw_texture(tex, Vector2(at))


## True once every sketch this page asked to be drawn ahead can be drawn.
static func drawn(ids: Array[StringName], size: int) -> bool:
	for id in ids:
		if item_texture(id, size) == null:
			return false
	return true


static func station_size(w: int) -> Vector2i:
	return Vector2i(w, roundi(w * 32.0 / 48.0))


## Draw these sketches ahead, off the main thread, so a page that shows them
## next does not stall. Items at `size`, stations at `station_w`.
static func warm(ids: Array[StringName], size: int, stations: Array[StringName] = [], station_w: int = 96) -> void:
	_reap()
	# Claim the keys first, THEN resolve them. `_out` is checked here as well as
	# `_cache` and `_ready` because it was not before: a key already out on a
	# worker from `_texture` was warmed a second time, so the same sketch was
	# rasterised twice — doubling the bake in exactly the busy moment warming
	# exists to smooth out.
	var jobs: Array[Array] = []
	_lock.lock()
	for id in ids:
		var key := "i|%s|%d" % [id, size]
		if not _cache.has(key) and not _ready.has(key) and not _out.has(key):
			_out[key] = true
			jobs.append([key, id, size, true])
	for st in stations:
		var key := "s|%s|%d" % [st, station_w]
		if not _cache.has(key) and not _ready.has(key) and not _out.has(key):
			_out[key] = true
			jobs.append([key, st, station_w, false])
	_lock.unlock()
	if jobs.is_empty():
		return
	# Everything a raster needs out of a content class is read HERE, on the main
	# thread (UiSketch.render says why). What goes to the worker is numbers.
	for j: Array in jobs:
		j.append(_item_job(j[1], j[2]) if j[3] else _station_job(j[1], j[2]))
	# One task EACH, not one task for the lot. They used to be drawn in a row on a
	# single worker, which was fine when a sketch was tens of milliseconds; at the
	# base's resolution a full creel of ten is over five seconds of that worker,
	# and the page shows a row with nothing in its scan window until its turn
	# comes. Given one task apiece the pool spreads them and the whole creel lands
	# in about the time the slowest one takes.
	for j: Array in jobs:
		var job := j
		_tasks.append(WorkerThreadPool.add_task(func() -> void:
			var img := _bake(job[4])
			_lock.lock()
			_ready[job[0]] = img
			_out.erase(job[0])
			_lock.unlock()))


## True while any sketch is still being drawn on a worker. A page redraws itself
## while this holds, so a scan window that was empty fills in as its raster lands.
static func waiting() -> bool:
	_reap()
	return not _tasks.is_empty()


## Wait out every sketch still being drawn ahead (before the game goes away, and
## for a shot, which has one frame to be right in).
static func wait() -> void:
	for t in _tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	_tasks.clear()


static func _reap() -> void:
	for t: int in _tasks.duplicate():
		if WorkerThreadPool.is_task_completed(t):
			WorkerThreadPool.wait_for_task_completion(t)
			_tasks.erase(t)


static func _has_ready(key: String) -> bool:
	_lock.lock()
	var has := _ready.has(key)
	_lock.unlock()
	return has


## The texture for `key`, or null while its raster is out on a worker — in which
## case one is started. NEVER rasters on the calling thread: see `draw_item`.
static func _texture(key: String, job_of: Callable) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	_reap()
	_lock.lock()
	var img: Image = _ready.get(key)
	_ready.erase(key)
	var out := _out.has(key)
	if img == null and not out:
		_out[key] = true
	_lock.unlock()
	if img == null:
		if not out:
			# Resolved HERE, on the caller's thread, and never inside the task:
			# `job_of` reads content classes, `_bake` reads only numbers.
			var job: Dictionary = job_of.call()
			_tasks.append(WorkerThreadPool.add_task(func() -> void:
				var made := _bake(job)
				_lock.lock()
				_ready[key] = made
				_out.erase(key)
				_lock.unlock()))
		return null
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## What an item's sketch is made of, read off the content classes. MAIN THREAD
## ONLY (UiSketch.render says why); `_bake` is what the worker runs on it.
static func _item_job(id: StringName, size: int) -> Dictionary:
	var st := UiIcons.style_of(id)
	var shape: StringName = st[0]
	var parts: Array = SHAPES.get(shape, SHAPES[&"bundle"])
	return {
		"parts": parts,
		"grid": Vector2(GRID, GRID),
		"px": Vector2i(size, size),
		"ramps": _ramps_for(parts, st[1], st[2]),
		"found": FOUND_SHAPES.has(shape),
		"seed": hash(id),
		"tones": UiIcons.tones_for(id),
	}


## The same for a station. MAIN THREAD ONLY.
static func _station_job(station: StringName, w: int) -> Dictionary:
	var st: Array = STATIONS.get(station, STATIONS[&"hand"])
	return {
		"parts": st[0],
		"grid": Vector2(48, 32),
		"px": station_size(w),
		"ramps": _ramps_for(st[0], st[1], st[2]),
		"found": st[3],
		"seed": hash(station),
		"tones": UiTheme.PHOSPHOR,
	}


## The worker's whole job: arithmetic on what it was handed, into an Image of its
## own. It asks no content class anything, so nothing it does can reach a Node.
static func _bake(job: Dictionary) -> Image:
	var img := _raster(job["parts"], job["grid"], job["px"], job["ramps"], job["found"], job["seed"])
	return to_phosphor(img, job["tones"])


## Every ramp this part list can name, resolved to colours. A part may name a
## ramp of its own ("ramp:N"), so the list is read for those as well as the two
## the item declares; `lens` and `plate` are always in, because the amber working
## part and a rivet's glint are drawn from them whatever the item is.
static func _ramps_for(parts: Array, ramp_a: StringName, ramp_b: StringName) -> Dictionary:
	var out := {
		&"a": UiIcons.ramp(ramp_a),
		&"b": UiIcons.ramp(ramp_b),
		&"lens": UiIcons.ramp(&"lens"),
		&"plate": UiIcons.ramp(&"plate"),
	}
	for part: Array in parts:
		if part.size() < 2 or not (part[0] == "poly" or part[0] == "bar" or part[0] == "ell"):
			continue
		var token: String = part[1]
		if not token.contains(":"):
			continue
		var name := StringName(token.split(":")[0])
		if not out.has(name):
			out[name] = UiIcons.ramp(name)
	return out


## The drawing as the slate's scanner shows it: the inked contour bright, the
## washes stepped down to the glass by their value through an ordered dither,
## the hatched shade and bled wash as the faintest tone, and a working part as
## the hottest pixel. `tones` is a five-step ramp (phosphor, or the violet).
static func to_phosphor(src: Image, tones: Array[Color]) -> Image:
	const BAYER := [0.0, 0.5, 0.75, 0.25]
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a <= 0.01:
				continue
			var col: Color
			if c.a < 0.7 and c.r + c.g + c.b < 0.05:
				# Hatched shade cast on the glass behind the thing.
				col = tones[1]
			elif c.a > 0.75 and c.r < 0.12 and c.g < 0.12 and c.b < 0.16:
				col = tones[3]
			elif c.r > 0.85 and c.g > 0.6 and c.b < 0.8 and c.r > c.b + 0.2:
				col = tones[4]
			elif c.a < 0.7:
				col = tones[1]
			else:
				var lum := c.r * 0.3 + c.g * 0.55 + c.b * 0.15
				var level := clampf(lum * 3.4, 0.0, 2.99)
				var idx := floori(level)
				if level - idx > BAYER[(y % 2) * 2 + x % 2]:
					idx += 1
				col = tones[clampi(idx, 0, 3)]
			out.set_pixel(x, y, col)
	return out


## The sketch as a colour drawing with a clear ground round it (the scanner
## takes it from here: to_phosphor).
static func render(parts: Array, grid: Vector2, px: Vector2i, ramp_a: StringName, ramp_b: StringName, found: bool, seed: int) -> Image:
	return _raster(parts, grid, px, _ramps_for(parts, ramp_a, ramp_b), found, seed)


## The raster itself, and the reason the ramps arrive already resolved: this runs
## on a WorkerThreadPool worker, and a worker must not be the thread that asks a
## content class (UiIcons, Items, Palette, UiTheme) for anything. Those lookups
## are pennies next to the raster — the whole of a creel is microseconds of
## dictionary reads against 1390 ms of pixels — so they are done by whoever asked
## for the sketch, on its own thread, and the worker is handed numbers.
static func _raster(parts: Array, grid: Vector2, px: Vector2i, ramps: Dictionary, found: bool, seed: int) -> Image:
	var w := px.x
	var h := px.y
	var s := float(w) / grid.x
	# 1. Which part covers each pixel (-1 none). The pen wanders on made things.
	#
	# Each part's box is taken first and the point tested against THAT before the
	# polygon. A sketch is a handful of small parts on a 32 grid, so most pixels
	# miss most parts, and the box turns those from a full edge crossing test into
	# four comparisons. It matters now that a sketch is rasterised at the base's
	# resolution: at 234 pixels square this loop is nine times the pixels it was
	# and the carrying page warms one of these per thing carried.
	var polys: Array = []
	var boxes: Array[Rect2] = []
	for part: Array in parts:
		var poly := _poly_of(part)
		polys.append(poly)
		boxes.append(_box_of(poly))
	var ids := PackedInt32Array()
	ids.resize(w * h)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			if not found:
				p += _wobble(seed, x, y) * 0.55
			p /= s
			var got := -1
			for i in polys.size():
				var poly: PackedVector2Array = polys[i]
				if poly.size() < 3 or not boxes[i].has_point(p):
					continue
				if Geometry2D.is_point_in_polygon(p, poly):
					got = i
			ids[y * w + x] = got
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := INK
	var shade_k := maxi(2, roundi(w * 0.09))
	var glows: Array[Vector3] = []
	for part: Array in parts:
		if part[0] == "glow":
			glows.append(Vector3(part[1], part[2], part[3]))
	# 2. Cast shadow behind the thing, hatched, down and right of it.
	if not found:
		for y in h:
			for x in w:
				if ids[y * w + x] >= 0 or posmod(x - y, 3) != 0:
					continue
				for c in range(2, shade_k + 2):
					if _id(ids, w, h, x - c, y - c) >= 0 and _id(ids, w, h, x - c + 1, y - c + 1) >= 0:
						img.set_pixel(x, y, CAST)
						break
	# 3. Wash, light and hatching.
	for y in h:
		for x in w:
			var i := ids[y * w + x]
			# The wash slips a pixel toward the light on a hand-drawn thing.
			var wi := i if found else _id(ids, w, h, x + 1, y + 1)
			if wi < 0 and i < 0:
				continue
			if wi < 0:
				wi = i
			var base := _colour(parts[wi][1], ramps)
			var col := base
			var lit := _id(ids, w, h, x - 2, y - 2) != wi
			var shaded := false
			for k in range(1, shade_k + 1):
				if _id(ids, w, h, x + k, y + k) != wi:
					shaded = true
					break
			if parts[wi][1] == "l":
				# An amber working part is lit from inside: it takes no shade.
				pass
			elif found:
				if shaded:
					col = base.darkened(0.28)
				elif lit:
					col = base.lerp(Color.WHITE, 0.18)
			else:
				col = base.lerp(LIGHT, 0.12)
				if lit:
					col = base.lerp(LIGHT, 0.38)
				elif shaded and posmod(x - y, 3) == 0:
					col = base.lerp(ink, 0.55)
			if i < 0:
				# Wash that slipped past the line: thin, like it bled.
				col = Color(col, 0.55)
			img.set_pixel(x, y, col)
	# 4. The contour: where a part meets the clear ground or a part under it.
	for y in h:
		for x in w:
			var i := ids[y * w + x]
			if i < 0:
				continue
			var edge := false
			var lit_side := true
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var n := _id(ids, w, h, x + d.x, y + d.y)
				if n < i:
					edge = true
					if d.x > 0 or d.y > 0:
						lit_side = false
			if not edge:
				continue
			# A hand-drawn line breaks up where the light falls on it.
			if not found and lit_side and Rng.hash01(seed, x / 2, y / 2, 0x1ce) < 0.16:
				continue
			img.set_pixel(x, y, ink)
	# The shadow side of a made thing's outline is drawn twice.
	if not found:
		for y in h:
			for x in w:
				if ids[y * w + x] < 0 and _id(ids, w, h, x - 1, y - 1) >= 0 and (_id(ids, w, h, x - 1, y) >= 0 or _id(ids, w, h, x, y - 1) >= 0):
					img.set_pixel(x, y, Color(ink, 0.85))
	# 5. Details, rivets and the working part.
	var plate: Array[Color] = ramps[&"plate"]
	var lens: Array[Color] = ramps[&"lens"]
	for part: Array in parts:
		match part[0]:
			"line":
				var pts: Array = part.slice(1)
				for j in range(0, pts.size() - 2, 2):
					_stroke(img, Vector2(pts[j], pts[j + 1]) * s, Vector2(pts[j + 2], pts[j + 3]) * s, Color(ink, 0.8), found, seed + j)
			"dot":
				# A rivet on found plate catches the light; a knot in wood is ink.
				var c := Vector2i(roundi(float(part[1]) * s - 0.5), roundi(float(part[2]) * s - 0.5))
				_plot(img, c.x, c.y, plate[5] if found else ink)
				if found:
					_plot(img, c.x + 1, c.y + 1, INK)
				elif w >= 64:
					_plot(img, c.x + 1, c.y, ink)
	for g in glows:
		_glow(img, Vector2(g.x, g.y) * s, g.z * s, lens)
	return img


static func _poly_of(part: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	match part[0]:
		"poly":
			var pts: Array = part[2]
			for j in range(0, pts.size() - 1, 2):
				out.append(Vector2(pts[j], pts[j + 1]))
		"bar":
			var a := Vector2(part[2], part[3])
			var b := Vector2(part[4], part[5])
			var n := (b - a).orthogonal().normalized()
			var w0: float = part[6] * 0.5
			var w1: float = part[7] * 0.5
			out.append_array([a + n * w0, b + n * w1, b - n * w1, a - n * w0])
		"ell":
			for k in 24:
				var t := k * TAU / 24.0
				out.append(Vector2(part[2] + cos(t) * part[4], part[3] + sin(t) * part[5]))
	return out


## A polygon's bounding box, grown half a grid unit so a point on its own edge is
## never rejected before the polygon itself has been asked.
static func _box_of(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var lo := poly[0]
	var hi := poly[0]
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo).grow(0.5)


## `ramps` is `_ramps_for`'s table: the item's two under &"a" and &"b", every ramp
## a part named under its own name, and always &"lens" and &"plate".
static func _colour(token: String, ramps: Dictionary) -> Color:
	var ramp: Array[Color]
	var step := 0
	if token == "l":
		ramp = ramps[&"lens"]
		step = 2
	elif token.contains(":"):
		var kv := token.split(":")
		ramp = ramps[StringName(kv[0])]
		step = kv[1].to_int()
	else:
		ramp = ramps[&"a" if token[0] == "a" else &"b"]
		step = token.substr(1).to_int()
	return ramp[clampi(step, 0, ramp.size() - 1)]


static func _id(ids: PackedInt32Array, w: int, h: int, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return -1
	return ids[y * w + x]


## A slow wander of the pen, in pixels: value noise on a 5 px lattice.
static func _wobble(seed: int, x: int, y: int) -> Vector2:
	var fx := x / 5.0
	var fy := y / 5.0
	var ix := floori(fx)
	var iy := floori(fy)
	var tx := fx - ix
	var ty := fy - iy
	var out := Vector2.ZERO
	for axis in 2:
		var a := Rng.hash01(seed + axis, ix, iy, 0x70b)
		var b := Rng.hash01(seed + axis, ix + 1, iy, 0x70b)
		var c := Rng.hash01(seed + axis, ix, iy + 1, 0x70b)
		var d := Rng.hash01(seed + axis, ix + 1, iy + 1, 0x70b)
		var v := lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty) * 2.0 - 1.0
		if axis == 0:
			out.x = v
		else:
			out.y = v
	return out


static func _plot(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	if col.a >= 1.0:
		img.set_pixel(x, y, col)
	else:
		img.set_pixel(x, y, img.get_pixel(x, y).blend(col))


static func _stroke(img: Image, a: Vector2, b: Vector2, col: Color, ruled: bool, seed: int) -> void:
	var d := b - a
	var n := maxi(1, ceili(maxf(absf(d.x), absf(d.y))))
	var last := Vector2i(-99, -99)
	for k in n + 1:
		var p := a + d * (k / float(n))
		if not ruled:
			p += Vector2(0.0, (Rng.hash01(seed, k / 4, 0, 0x5e) - 0.5) * 0.9)
		var q := Vector2i(floori(p.x), floori(p.y))
		if q != last:
			_plot(img, q.x, q.y, col)
			last = q


## A found machine's working part: an amber core that lights the plate round it.
static func _glow(img: Image, c: Vector2, r: float, lens: Array[Color]) -> void:
	var lo := Vector2i(floori(c.x - r - 2.0), floori(c.y - r - 2.0))
	var hi := Vector2i(ceili(c.x + r + 2.0), ceili(c.y + r + 2.0))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if dist <= r * 0.45:
				_plot(img, x, y, lens[3])
			elif dist <= r:
				_plot(img, x, y, lens[2])
			elif dist <= r + 1.0:
				_plot(img, x, y, Color(lens[1], 1.0))
			elif dist <= r + 2.2:
				_plot(img, x, y, Color(lens[2], 0.3))
