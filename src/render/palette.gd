class_name Palette
## Every colour the game draws with. Generated from the old Unity game (../unspent) §2
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

## Per-machine body ramps. Five things at once (docs/LOOK.md, the Palette
## contract):
##
## 1. The arc runs by ROLE, cold to warm, so what a machine WANTS reads before
##    which kind it is: the filers and the observers at cold indigo (clerk 240,
##    watcher 247), the keepers next (warden 258), the workers through violet
##    (lineman, hauler, sweeper, harvester, cutter, 266-301) and the hunters at
##    the burnt end (flock, dredger, longlegs, runner, 305-336). Nothing on a
##    body leaves that window: a ramp that drifted past it would be a warm
##    machine, and ART §4 gives them exactly one warm read.
## 2. Each kind sits at its own value and chroma inside its family, far enough
##    from the other eleven to be told apart in a lineup at 640x360.
## 3. And far enough from PLATE, which is the same cold slate family: a patched
##    roof must never read as a live machine. The clerk used to sit at hue 220
##    one value off PLATE[2] — a filing machine the colour of a village roof.
## 4. The chroma stays low and dirty, leaving the amber LENS the only saturated
##    thing on a machine.
## 5. The body fill (step 3, every up face) is DARKER than the turf it stands on,
##    so a machine is a cold heavy mass ruled with bright chamfer lines by day
##    and not a pale plastic slab.
##
## Steps: 0/1 undersides and down bevels, 2 walls, 3 the body fill, 4 the lit rim
## on shoulders and chamfers, 5 rivets and the one rubbed edge. The top is
## compressed and desaturated: 3 -> 5 is a third of the climb 0 -> 3.
##
## Every one of these is measured in tests/models/test_machines_ramps.gd. Retune
## by moving a kind's hue, chroma and fill value together and re-running it; the
## table is a solved packing, not twelve independent choices.
const MACHINE := {
	"dredger": [Color(0.1331, 0.0857, 0.1129), Color(0.2310, 0.1518, 0.1972), Color(0.2972, 0.2023, 0.2567), Color(0.3754, 0.2607, 0.3264), Color(0.4216, 0.3150, 0.3761), Color(0.4547, 0.3958, 0.4296)],
	"hauler": [Color(0.0840, 0.0739, 0.0933), Color(0.1482, 0.1320, 0.1631), Color(0.1928, 0.1746, 0.2095), Color(0.2452, 0.2210, 0.2676), Color(0.2858, 0.2636, 0.3062), Color(0.3299, 0.3157, 0.3431)],
	"cutter": [Color(0.1195, 0.0702, 0.1186), Color(0.2094, 0.1294, 0.2079), Color(0.2665, 0.1678, 0.2647), Color(0.3393, 0.2181, 0.3371), Color(0.3803, 0.2698, 0.3783), Color(0.4059, 0.3446, 0.4048)],
	"lineman": [Color(0.1082, 0.1019, 0.1167), Color(0.1877, 0.1765, 0.2026), Color(0.2440, 0.2312, 0.2610), Color(0.3132, 0.2973, 0.3346), Color(0.3656, 0.3496, 0.3871), Color(0.4269, 0.4173, 0.4398)],
	"watcher": [Color(0.0838, 0.0781, 0.1264), Color(0.1499, 0.1408, 0.2186), Color(0.1951, 0.1842, 0.2763), Color(0.2501, 0.2370, 0.3481), Color(0.2941, 0.2823, 0.3826), Color(0.3489, 0.3427, 0.3949)],
	"longlegs": [Color(0.1135, 0.0667, 0.0904), Color(0.1958, 0.1177, 0.1572), Color(0.2470, 0.1572, 0.2027), Color(0.3141, 0.2007, 0.2581), Color(0.3492, 0.2476, 0.2990), Color(0.3689, 0.3142, 0.3419)],
	"runner": [Color(0.1549, 0.0911, 0.1166), Color(0.2689, 0.1636, 0.2057), Color(0.3410, 0.2131, 0.2643), Color(0.4321, 0.2778, 0.3395), Color(0.4784, 0.3389, 0.3947), Color(0.5065, 0.4308, 0.4611)],
	"warden": [Color(0.1056, 0.0888, 0.1467), Color(0.1853, 0.1574, 0.2533), Color(0.2414, 0.2079, 0.3233), Color(0.3082, 0.2666, 0.4096), Color(0.3576, 0.3205, 0.4479), Color(0.4140, 0.3935, 0.4637)],
	"clerk": [Color(0.1083, 0.1083, 0.1496), Color(0.1910, 0.1910, 0.2641), Color(0.2481, 0.2481, 0.3344), Color(0.3191, 0.3191, 0.4283), Color(0.3783, 0.3783, 0.4772), Color(0.4523, 0.4523, 0.5044)],
	"sweeper": [Color(0.0974, 0.0849, 0.1004), Color(0.1709, 0.1520, 0.1754), Color(0.2214, 0.1993, 0.2267), Color(0.2858, 0.2574, 0.2925), Color(0.3295, 0.3042, 0.3355), Color(0.3793, 0.3635, 0.3831)],
	"harvester": [Color(0.1282, 0.1018, 0.1317), Color(0.2239, 0.1777, 0.2301), Color(0.2902, 0.2342, 0.2977), Color(0.3693, 0.3031, 0.3781), Color(0.4229, 0.3600, 0.4313), Color(0.4763, 0.4399, 0.4812)],
	"flock": [Color(0.1506, 0.0886, 0.1454), Color(0.2627, 0.1579, 0.2538), Color(0.3353, 0.2076, 0.3245), Color(0.4246, 0.2694, 0.4114), Color(0.4736, 0.3343, 0.4617), Color(0.5037, 0.4265, 0.4971)],
}


## A colour a fraction of the way from a to b.
static func mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)


## Deterministic small value wobble: the hand-made in hand-made.
static func wobble(col: Color, h: float, amount: float = 0.05) -> Color:
	var k := 1.0 + (h - 0.5) * 2.0 * amount
	return Color(col.r * k, col.g * k, col.b * k, col.a)
