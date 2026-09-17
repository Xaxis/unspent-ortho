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
		["poly", "a2", [3.0, 22.0, 6.0, 15.0, 13.0, 10.0, 22.0, 9.0, 25.0, 12.0, 21.0, 19.0, 12.0, 24.0, 5.0, 25.0]],
		["line", 6.0, 21.0, 12.0, 16.0, 20.0, 13.0],
		["poly", "a3", [9.0, 28.0, 12.0, 21.0, 19.0, 15.5, 27.0, 14.5, 30.0, 17.5, 26.0, 24.5, 17.0, 29.0, 10.5, 30.0]],
		["line", 12.0, 27.0, 18.0, 22.0, 26.0, 18.5],
		["poly", "a5", [26.0, 15.0, 30.0, 17.5, 28.5, 20.0, 25.5, 17.5]],
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
static var _lock := Mutex.new()
static var _tasks: Array[int] = []


## Draw item `id` sketched `size` pixels square with its top-left at `at`.
static func draw_item(ci: CanvasItem, id: StringName, at: Vector2i, size: int) -> void:
	ci.draw_texture(item_texture(id, size), Vector2(at))


static func item_texture(id: StringName, size: int) -> ImageTexture:
	return _texture("i|%s|%d" % [id, size], func() -> Image: return _item_image(id, size))


## Draw a station sketched `w` pixels wide (height follows the 48x32 grid).
static func draw_station(ci: CanvasItem, station: StringName, at: Vector2i, w: int) -> void:
	ci.draw_texture(_texture("s|%s|%d" % [station, w], func() -> Image: return _station_image(station, w)), Vector2(at))


static func station_size(w: int) -> Vector2i:
	return Vector2i(w, roundi(w * 32.0 / 48.0))


## Draw these sketches ahead, off the main thread, so a page that shows them
## next does not stall. Items at `size`, stations at `station_w`.
static func warm(ids: Array[StringName], size: int, stations: Array[StringName] = [], station_w: int = 96) -> void:
	var jobs: Array[Array] = []
	for id in ids:
		jobs.append(["i|%s|%d" % [id, size], func() -> Image: return _item_image(id, size)])
	for st in stations:
		jobs.append(["s|%s|%d" % [st, station_w], func() -> Image: return _station_image(st, station_w)])
	jobs = jobs.filter(func(j: Array) -> bool: return not _cache.has(j[0]) and not _has_ready(j[0]))
	_reap()
	if jobs.is_empty():
		return
	_tasks.append(WorkerThreadPool.add_task(func() -> void:
		for j: Array in jobs:
			var img: Image = (j[1] as Callable).call()
			_lock.lock()
			_ready[j[0]] = img
			_lock.unlock()))


## Wait out every sketch still being drawn ahead (before the game goes away).
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


static func _texture(key: String, make: Callable) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	_reap()
	_lock.lock()
	var img: Image = _ready.get(key)
	_ready.erase(key)
	_lock.unlock()
	if img == null:
		img = make.call()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _item_image(id: StringName, size: int) -> Image:
	var st := UiIcons.style_of(id)
	var shape: StringName = st[0]
	var parts: Array = SHAPES.get(shape, SHAPES[&"bundle"])
	var img := render(parts, Vector2(GRID, GRID), Vector2i(size, size), st[1], st[2], FOUND_SHAPES.has(shape), hash(id))
	return to_phosphor(img, UiIcons.tones_for(id))


static func _station_image(station: StringName, w: int) -> Image:
	var st: Array = STATIONS.get(station, STATIONS[&"hand"])
	var img := render(st[0], Vector2(48, 32), station_size(w), st[1], st[2], st[3], hash(station))
	return to_phosphor(img, UiTheme.PHOSPHOR)


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
	var w := px.x
	var h := px.y
	var s := float(w) / grid.x
	# 1. Which part covers each pixel (-1 none). The pen wanders on made things.
	var polys: Array = []
	for part: Array in parts:
		polys.append(_poly_of(part))
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
				if poly.size() >= 3 and Geometry2D.is_point_in_polygon(p, poly):
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
			var base := _colour(parts[wi][1], ramp_a, ramp_b)
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
	for part: Array in parts:
		match part[0]:
			"line":
				var pts: Array = part.slice(1)
				for j in range(0, pts.size() - 2, 2):
					_stroke(img, Vector2(pts[j], pts[j + 1]) * s, Vector2(pts[j + 2], pts[j + 3]) * s, Color(ink, 0.8), found, seed + j)
			"dot":
				# A rivet on found plate catches the light; a knot in wood is ink.
				var c := Vector2i(roundi(float(part[1]) * s - 0.5), roundi(float(part[2]) * s - 0.5))
				_plot(img, c.x, c.y, Palette.PLATE[5] if found else ink)
				if found:
					_plot(img, c.x + 1, c.y + 1, INK)
				elif w >= 64:
					_plot(img, c.x + 1, c.y, ink)
	for g in glows:
		_glow(img, Vector2(g.x, g.y) * s, g.z * s)
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


static func _colour(token: String, ramp_a: StringName, ramp_b: StringName) -> Color:
	if token == "l":
		return Palette.LENS[2]
	var ramp: Array[Color]
	var step := 0
	if token.contains(":"):
		var kv := token.split(":")
		ramp = UiIcons.ramp(StringName(kv[0]))
		step = kv[1].to_int()
	else:
		ramp = UiIcons.ramp(ramp_a if token[0] == "a" else ramp_b)
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
static func _glow(img: Image, c: Vector2, r: float) -> void:
	var lo := Vector2i(floori(c.x - r - 2.0), floori(c.y - r - 2.0))
	var hi := Vector2i(ceili(c.x + r + 2.0), ceili(c.y + r + 2.0))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if dist <= r * 0.45:
				_plot(img, x, y, Palette.LENS[3])
			elif dist <= r:
				_plot(img, x, y, Palette.LENS[2])
			elif dist <= r + 1.0:
				_plot(img, x, y, Color(Palette.LENS[1], 1.0))
			elif dist <= r + 2.2:
				_plot(img, x, y, Color(Palette.LENS[2], 0.3))
