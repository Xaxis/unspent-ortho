class_name Palette
## Every colour the game draws with. Generated from docs/research/art-audio-extract.md §2
## (the running build of the original game). Index 0 is the darkest step of a ramp.
##
## MADE things (anything a person built) use only the coast ramps. FOUND things
## (machines, their salvage) use FOUND / per-kind machine ramps, LENS for the
## working part ("soft side, hit here") and COLD for a plated visor. Never mix.

const INK: Array[Color] = [Color(0.0314, 0.0275, 0.0588), Color(0.0706, 0.0667, 0.1137), Color(0.1176, 0.1098, 0.1804), Color(0.1843, 0.1725, 0.2706), Color(0.2706, 0.2588, 0.3882)]
const STONE: Array[Color] = [Color(0.1059, 0.1216, 0.1686), Color(0.1843, 0.2118, 0.2745), Color(0.2902, 0.3333, 0.4000), Color(0.4275, 0.4784, 0.5490), Color(0.5922, 0.6353, 0.6902), Color(0.7843, 0.8118, 0.8471)]
const BRINE: Array[Color] = [Color(0.0392, 0.0824, 0.1412), Color(0.0627, 0.1490, 0.2471), Color(0.1059, 0.2471, 0.3765), Color(0.1686, 0.3882, 0.5373), Color(0.2627, 0.5725, 0.6902), Color(0.4980, 0.7961, 0.8471)]
const SLATE: Array[Color] = [Color(0.0745, 0.1020, 0.1412), Color(0.1373, 0.1843, 0.2392), Color(0.2157, 0.2824, 0.3529), Color(0.3216, 0.4000, 0.4784), Color(0.4588, 0.5373, 0.6118), Color(0.6392, 0.7059, 0.7686)]
const EARTH: Array[Color] = [Color(0.1020, 0.0706, 0.1255), Color(0.2000, 0.1373, 0.1216), Color(0.3098, 0.2118, 0.1529), Color(0.4353, 0.3020, 0.1922), Color(0.6000, 0.4392, 0.2667), Color(0.7804, 0.6118, 0.3843)]
const RUST: Array[Color] = [Color(0.1647, 0.0627, 0.0941), Color(0.2902, 0.1137, 0.0941), Color(0.4314, 0.2000, 0.1255), Color(0.6039, 0.3098, 0.1569), Color(0.7686, 0.4549, 0.2196), Color(0.9098, 0.6471, 0.3412)]
const MOSS: Array[Color] = [Color(0.0627, 0.0863, 0.1216), Color(0.1020, 0.1647, 0.1412), Color(0.1725, 0.2667, 0.1882), Color(0.2745, 0.4118, 0.2275), Color(0.4275, 0.5725, 0.2784), Color(0.6392, 0.7608, 0.3686)]
const SPRUCE: Array[Color] = [Color(0.0471, 0.0706, 0.1255), Color(0.0824, 0.1451, 0.1882), Color(0.1137, 0.2353, 0.2549), Color(0.1647, 0.3529, 0.3255), Color(0.2588, 0.5176, 0.4157), Color(0.4784, 0.6980, 0.5686)]
const SAND: Array[Color] = [Color(0.1333, 0.1137, 0.1490), Color(0.2314, 0.1961, 0.2196), Color(0.3608, 0.3020, 0.2706), Color(0.5216, 0.4392, 0.3529), Color(0.6784, 0.5765, 0.4392), Color(0.8471, 0.7569, 0.5765)]
const LINEN: Array[Color] = [Color(0.1843, 0.1647, 0.1686), Color(0.2980, 0.2667, 0.2471), Color(0.4353, 0.3961, 0.3490), Color(0.5882, 0.5412, 0.4627), Color(0.7529, 0.7020, 0.5804), Color(0.9098, 0.8627, 0.7529)]
const FLESH: Array[Color] = [Color(0.2000, 0.0980, 0.1059), Color(0.3569, 0.1843, 0.1569), Color(0.5490, 0.3373, 0.2275), Color(0.7216, 0.4980, 0.3412), Color(0.8784, 0.6667, 0.4941)]
const COPPER: Array[Color] = [Color(0.2000, 0.1255, 0.0392), Color(0.3725, 0.2353, 0.0627), Color(0.5765, 0.3765, 0.1020), Color(0.7804, 0.5529, 0.1725), Color(0.9412, 0.7333, 0.3059)]
const ASH: Array[Color] = [Color(0.1373, 0.1490, 0.1804), Color(0.2314, 0.2510, 0.2902), Color(0.3608, 0.3843, 0.4314), Color(0.5255, 0.5529, 0.6000), Color(0.7216, 0.7490, 0.7882)]
const EMBER: Array[Color] = [Color(0.1647, 0.0510, 0.0235), Color(0.3608, 0.1098, 0.0314), Color(0.5765, 0.2000, 0.0471), Color(0.7843, 0.3529, 0.0824), Color(0.9608, 0.6471, 0.1843), Color(1.0000, 0.9412, 0.7529)]
const RIME: Array[Color] = [Color(0.0745, 0.1216, 0.1804), Color(0.1294, 0.2196, 0.2902), Color(0.2078, 0.3451, 0.4314), Color(0.3647, 0.5451, 0.6275), Color(0.5882, 0.7529, 0.8157), Color(0.8667, 0.9412, 0.9686)]
const BLOOM: Array[Color] = [Color(0.1686, 0.0784, 0.1882), Color(0.3686, 0.1451, 0.2980), Color(0.6275, 0.2392, 0.4235), Color(0.8157, 0.4353, 0.5725), Color(0.9294, 0.6392, 0.7216), Color(0.9843, 0.8235, 0.8706)]
const FOUND: Array[Color] = [Color(0.0784, 0.0392, 0.1412), Color(0.1686, 0.0824, 0.3137), Color(0.2902, 0.1216, 0.5490), Color(0.4549, 0.2000, 0.8784), Color(0.6157, 0.3608, 1.0000), Color(0.8627, 0.7686, 1.0000)]
const LENS: Array[Color] = [Color(0.2275, 0.1647, 0.0314), Color(0.5608, 0.4157, 0.0706), Color(0.9098, 0.7608, 0.2275), Color(1.0000, 0.9529, 0.7529)]
const COLD: Array[Color] = [Color(0.0863, 0.1333, 0.1804), Color(0.1529, 0.2824, 0.3608), Color(0.3098, 0.5490, 0.6510), Color(0.7059, 0.8627, 0.9294)]
const PLATE: Array[Color] = [Color(0.0745, 0.0784, 0.1412), Color(0.1490, 0.1451, 0.2706), Color(0.2471, 0.2196, 0.4314), Color(0.3765, 0.3216, 0.6392), Color(0.5216, 0.4667, 0.7686), Color(0.7294, 0.7294, 0.8627)]

## Per-machine body ramps, along a violet arc from wet (indigo) to burnt (magenta).
const MACHINE := {
	"dredger": [Color(0.0588, 0.0431, 0.1529), Color(0.1216, 0.0863, 0.3412), Color(0.2039, 0.1294, 0.6000), Color(0.3176, 0.2118, 0.9608), Color(0.4824, 0.3569, 1.0000), Color(0.8078, 0.7686, 1.0000)],
	"hauler": [Color(0.0627, 0.0431, 0.1451), Color(0.1373, 0.0863, 0.3176), Color(0.2314, 0.1294, 0.5569), Color(0.3608, 0.2118, 0.8902), Color(0.5451, 0.3725, 1.0000), Color(0.8275, 0.7725, 1.0000)],
	"cutter": [Color(0.0745, 0.0353, 0.1529), Color(0.1569, 0.0706, 0.3412), Color(0.2667, 0.0980, 0.6000), Color(0.4157, 0.1647, 0.9608), Color(0.5686, 0.3176, 1.0000), Color(0.8392, 0.7529, 1.0000)],
	"lineman": [Color(0.0745, 0.0392, 0.1412), Color(0.1608, 0.0863, 0.3137), Color(0.2745, 0.1294, 0.5490), Color(0.4275, 0.2118, 0.8784), Color(0.6118, 0.3725, 1.0000), Color(0.8549, 0.7725, 1.0000)],
	"watcher": [Color(0.0824, 0.0314, 0.1529), Color(0.1765, 0.0667, 0.3373), Color(0.3020, 0.0902, 0.5882), Color(0.4745, 0.1490, 0.9412), Color(0.6275, 0.3059, 1.0000), Color(0.8588, 0.7490, 1.0000)],
	"longlegs": [Color(0.0863, 0.0431, 0.1451), Color(0.1843, 0.0863, 0.3216), Color(0.3176, 0.1294, 0.5608), Color(0.5020, 0.2157, 0.9020), Color(0.6706, 0.3725, 1.0000), Color(0.8745, 0.7725, 1.0000)],
	"runner": [Color(0.0941, 0.0431, 0.1451), Color(0.2078, 0.0863, 0.3176), Color(0.3569, 0.1294, 0.5569), Color(0.5647, 0.2118, 0.8902), Color(0.7333, 0.3725, 1.0000), Color(0.8980, 0.7725, 1.0000)],
	"warden": [Color(0.0941, 0.0275, 0.1490), Color(0.2039, 0.0549, 0.3333), Color(0.3529, 0.0706, 0.5804), Color(0.5529, 0.1216, 0.9294), Color(0.7059, 0.2784, 1.0000), Color(0.8863, 0.7412, 1.0000)],
	"clerk": [Color(0.0902, 0.0314, 0.1294), Color(0.1961, 0.0667, 0.2902), Color(0.3412, 0.0941, 0.5059), Color(0.5373, 0.1529, 0.8118), Color(0.7020, 0.3020, 0.9216), Color(0.8353, 0.6980, 0.9216)],
	"sweeper": [Color(0.1098, 0.0275, 0.1490), Color(0.2353, 0.0549, 0.3294), Color(0.4118, 0.0706, 0.5765), Color(0.6471, 0.1176, 0.9216), Color(0.7961, 0.2784, 1.0000), Color(0.9176, 0.7412, 1.0000)],
	"harvester": [Color(0.1137, 0.0431, 0.1451), Color(0.2471, 0.0902, 0.3255), Color(0.4314, 0.1333, 0.5686), Color(0.6784, 0.2196, 0.9098), Color(0.8275, 0.3725, 1.0000), Color(0.9333, 0.7725, 1.0000)],
	"flock": [Color(0.1216, 0.0118, 0.1569), Color(0.2667, 0.0235, 0.3451), Color(0.4706, 0.0078, 0.6078), Color(0.7412, 0.0196, 0.9686), Color(0.8510, 0.1882, 1.0000), Color(0.9373, 0.7059, 1.0000)],
}


## A colour a fraction of the way from a to b.
static func mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)


## Deterministic small value wobble: the hand-made in hand-made.
static func wobble(col: Color, h: float, amount: float = 0.05) -> Color:
	var k := 1.0 + (h - 0.5) * 2.0 * amount
	return Color(col.r * k, col.g * k, col.b * k, col.a)
