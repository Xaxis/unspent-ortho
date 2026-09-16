extends TestCase
## A landscape may say what its water is (`BiomeDef.water_wash`) — but water is
## still a CHART, and a chart is a drawing.
##
## The scrapwood's pools were the shared chart blue: a pale slate pond measuring
## (111, 141, 175) against the moss's (23, 38, 53), the brightest large object in
## a landscape whose whole mood is green-brown gloom (playtest 6). Taking the
## wash all the way to a dead green-black answered the colour and lost the
## drawing instead: the chart's whole value range collapsed and a river read as a
## black ribbon cut out of the land — Law 2 broken the other way round.
##
## So the rule both sides of that have to meet: whatever a landscape says its
## water is, the soundings, the bank line, the marbling and the broken white of a
## fall must all still draw, in the same order the chart drew them.

## The chart's own steps, from src/render/water.gdshader: the sounding line, the
## two river bands, the swash at the bank, and the white of a fall.
const CHART: Array[Color] = [
	Color(0.0392, 0.0824, 0.1412), Color(0.1059, 0.2471, 0.3765),
	Color(0.1686, 0.3882, 0.5373), Color(0.2627, 0.5725, 0.6902),
	Color(0.8667, 0.9412, 0.9686),
]
## And standing water's, which is drawn dark to begin with: the oily film, the
## deep, the two greens of the edge and the rim line.
const STILL: Array[Color] = [
	Color(0.0706, 0.0667, 0.1137), Color(0.0392, 0.0824, 0.1412),
	Color(0.0824, 0.1451, 0.1882), Color(0.1137, 0.2353, 0.2549),
	Color(0.1647, 0.3529, 0.3255),
]
## How much of the chart's own value range a landscape's water must keep. The
## flat green-black that made a ribbon of the scrapwood's river kept 0.15.
const KEEP := 0.25


static func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


## water.gdshader's fragment step, as GDScript.
static func washed(c: Color, w: Color) -> Color:
	if w.a <= 0.001:
		return c
	var k := 0.30 + 1.55 * _lum(c)
	return c.lerp(Color(w.r * k, w.g * k, w.b * k), w.a)


static func _spread(rows: Array[Color], w: Color) -> float:
	var lo := 9.9
	var hi := -1.0
	for c: Color in rows:
		var l := _lum(washed(c, w))
		lo = minf(lo, l)
		hi = maxf(hi, l)
	return hi - lo


func test_a_landscapes_own_water_still_has_a_drawing_in_it() -> void:
	var said := 0
	for rows: Array[Color] in [CHART, STILL]:
		var raw := _spread(rows, Color(0, 0, 0, 0))
		gt(raw, 0.15, "the chart itself has steps between its darkest and its brightest")
		for d in BiomeRegistry.all():
			if d.water_wash.a <= 0.001:
				continue
			said += 1
			var kept := _spread(rows, d.water_wash) / raw
			gt(kept, KEEP, "the %s's water keeps enough of the chart to still be drawn" % d.id)
	gt(float(said), 0.0, "at least one landscape says what its water is")


func test_the_wash_never_turns_the_chart_upside_down() -> void:
	# Deeper water must still draw darker than the swash, and a fall must still
	# break white over both, or the chart stops meaning anything.
	for d in BiomeRegistry.all():
		if d.water_wash.a <= 0.001:
			continue
		var last := -1.0
		for c: Color in CHART:
			var l := _lum(washed(c, d.water_wash))
			gt(l, last, "the %s's chart still rises step by step" % d.id)
			last = l


func test_the_scrapwoods_water_is_dead_but_is_not_a_hole_in_the_page() -> void:
	# The measured complaint: a pool at (111, 141, 175) against the moss's
	# (23, 38, 53), 3.7x brighter, in a wood of green-brown gloom. The moss says
	# nothing about its water, so what it draws is the shader's own dark still
	# water — that is the value this has to come down to, not past.
	var wood := BiomeRegistry.get_def(&"scrapwood")
	check(wood != null, "the scrapwood is registered")
	var river := _lum(washed(CHART[2], wood.water_wash))
	lt(river, _lum(CHART[2]) * 0.55, "the wood's river has left the chart blue behind")
	gt(river, _lum(CHART[0]), "and is still lighter than the sounding line drawn on it")
	var pool := _lum(washed(STILL[3], wood.water_wash))
	gt(pool, _lum(STILL[0]), "its pools are still lighter than the oil lying on them")
