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
const FOUND: Array[Color] = [Color(0.1042, 0.0902, 0.1412), Color(0.2290, 0.1981, 0.3137), Color(0.3176, 0.2695, 0.4413), Color(0.4654, 0.4154, 0.6010), Color(0.5389, 0.4913, 0.6600), Color(0.6164, 0.5989, 0.6600)]
const LENS: Array[Color] = [Color(0.2275, 0.1647, 0.0314), Color(0.5608, 0.4157, 0.0706), Color(0.9098, 0.7608, 0.2275), Color(1.0000, 0.9529, 0.7529)]
const COLD: Array[Color] = [Color(0.1145, 0.1474, 0.1804), Color(0.2126, 0.3022, 0.3564), Color(0.4133, 0.5337, 0.5850), Color(0.6961, 0.7720, 0.8044)]
const PLATE: Array[Color] = [Color(0.0892, 0.1064, 0.1412), Color(0.1687, 0.1962, 0.2518), Color(0.2536, 0.2892, 0.3655), Color(0.3511, 0.3906, 0.4811), Color(0.4691, 0.5105, 0.5862), Color(0.6077, 0.6477, 0.6985)]

## Per-machine body ramps, along a violet arc from wet (indigo) to burnt (magenta),
## held to a cold, dirty chroma with the top value compressed: machines look
## routine and precise, never cute, and their amber LENS is the only saturated
## thing on them.
const MACHINE := {
	"dredger": [Color(0.1058, 0.0980, 0.1529), Color(0.2311, 0.2134, 0.3406), Color(0.3107, 0.2833, 0.4661), Color(0.4692, 0.4411, 0.6410), Color(0.5191, 0.4902, 0.6600), Color(0.6085, 0.5989, 0.6600)],
	"hauler": [Color(0.1027, 0.0941, 0.1451), Color(0.2233, 0.2020, 0.3176), Color(0.3075, 0.2743, 0.4452), Color(0.4558, 0.4218, 0.6068), Color(0.5298, 0.4943, 0.6600), Color(0.6117, 0.5999, 0.6600)],
	"cutter": [Color(0.1086, 0.0941, 0.1529), Color(0.2377, 0.2055, 0.3406), Color(0.3194, 0.2711, 0.4661), Color(0.4788, 0.4285, 0.6410), Color(0.5276, 0.4798, 0.6600), Color(0.6114, 0.5948, 0.6600)],
	"lineman": [Color(0.1031, 0.0902, 0.1412), Color(0.2277, 0.2000, 0.3137), Color(0.3154, 0.2727, 0.4413), Color(0.4626, 0.4186, 0.6010), Color(0.5395, 0.4943, 0.6600), Color(0.6157, 0.5999, 0.6600)],
	"watcher": [Color(0.1100, 0.0922, 0.1529), Color(0.2407, 0.2020, 0.3373), Color(0.3233, 0.2655, 0.4603), Color(0.4803, 0.4189, 0.6315), Color(0.5350, 0.4768, 0.6600), Color(0.6139, 0.5937, 0.6600)],
	"longlegs": [Color(0.1092, 0.0941, 0.1451), Color(0.2383, 0.2040, 0.3216), Color(0.3272, 0.2751, 0.4471), Color(0.4806, 0.4261, 0.6125), Color(0.5481, 0.4943, 0.6600), Color(0.6185, 0.5999, 0.6600)],
	"runner": [Color(0.1113, 0.0941, 0.1451), Color(0.2426, 0.2020, 0.3176), Color(0.3351, 0.2743, 0.4452), Color(0.4864, 0.4218, 0.6068), Color(0.5572, 0.4943, 0.6600), Color(0.6219, 0.5999, 0.6600)],
	"warden": [Color(0.1104, 0.0883, 0.1490), Color(0.2438, 0.1941, 0.3333), Color(0.3297, 0.2560, 0.4566), Color(0.4858, 0.4082, 0.6258), Color(0.5436, 0.4695, 0.6600), Color(0.6170, 0.5917, 0.6600)],
	"clerk": [Color(0.0997, 0.0804, 0.1294), Color(0.2211, 0.1784, 0.2902), Color(0.3166, 0.2493, 0.4204), Color(0.4550, 0.3841, 0.5688), Color(0.5246, 0.4547, 0.6220), Color(0.5858, 0.5616, 0.6220)],
	"sweeper": [Color(0.1147, 0.0883, 0.1490), Color(0.2504, 0.1921, 0.3294), Color(0.3417, 0.2552, 0.4547), Color(0.4972, 0.4049, 0.6220), Color(0.5567, 0.4695, 0.6600), Color(0.6216, 0.5917, 0.6600)],
	"harvester": [Color(0.1167, 0.0941, 0.1451), Color(0.2584, 0.2079, 0.3255), Color(0.3541, 0.2783, 0.4508), Color(0.5094, 0.4293, 0.6163), Color(0.5708, 0.4943, 0.6600), Color(0.6271, 0.5999, 0.6600)],
	"flock": [Color(0.1191, 0.0844, 0.1569), Color(0.2593, 0.1829, 0.3425), Color(0.3509, 0.2379, 0.4698), Color(0.5137, 0.3921, 0.6448), Color(0.5554, 0.4457, 0.6600), Color(0.6208, 0.5824, 0.6600)],
}


## A colour a fraction of the way from a to b.
static func mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)


## Deterministic small value wobble: the hand-made in hand-made.
static func wobble(col: Color, h: float, amount: float = 0.05) -> Color:
	var k := 1.0 + (h - 0.5) * 2.0 * amount
	return Color(col.r * k, col.g * k, col.b * k, col.a)
