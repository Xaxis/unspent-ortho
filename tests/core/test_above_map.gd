extends TestCase
## WHAT HANGS OVER THE GROUND, AS THE SHADER READS IT (AboveMap; docs/ABOVE.md
## S2): each connected mass is one id, two masses apart are two, the id reaches
## a tile past its mass (so a rim drawn past its tiles is cut with it), and a
## world with nothing overhead carries nothing.

const F := preload("res://tests/fight/fixture.gd")


func _world() -> WorldData:
	var w := F.flat_world(64, Ground.GRASS, Country.COAST, 2)
	for y in range(10, 14):
		for x in range(10, 16):
			w.set_overhead(x, y, 8, 11)
	for y in range(30, 33):
		for x in range(40, 44):
			w.set_overhead(x, y, 9, 12)
	return w


func test_nothing_overhead_carries_nothing() -> void:
	var m := AboveMap.of(F.flat_world(64, Ground.GRASS, Country.COAST, 2))
	check(m.ids.is_empty() and m.image == null, "no map")
	eq(m.id_at(10, 10), 0, "and no mass anywhere")


func test_each_connected_mass_is_one_id_and_two_apart_are_two() -> void:
	var m := AboveMap.of(_world())
	var a := m.id_at(12, 11)
	var b := m.id_at(41, 31)
	check(a != 0 and b != 0, "both masses have ids (%d, %d)" % [a, b])
	check(a != b, "and not the same one")
	eq(m.id_at(15, 13), a, "a slab is one mass corner to corner")
	eq(m.id_at(25, 20), 0, "open ground between them is none")


func test_an_id_reaches_one_tile_past_its_mass_in_the_picture() -> void:
	var w := _world()
	var m := AboveMap.of(w)
	var a := m.id_at(12, 11)
	var px := m.image.get_pixel(16 - m.x0, 11 - m.y0)
	eq(int(round(px.g * 255.0)) + int(round(px.b * 255.0)) * 256, a, "the tile past its east edge carries its id")
	check(px.r < 0.5, "but nothing hangs over it")
	var inside := m.image.get_pixel(12 - m.x0, 11 - m.y0)
	check(inside.r > 0.5, "over the mass, the picture says so")
	eq(int(round(inside.a * 255.0)), 8, "with its underside's level")
	var two_past := m.image.get_pixel(17 - m.x0, 11 - m.y0)
	eq(int(round(two_past.g * 255.0)), 0, "two tiles past, nothing")


## THE DAY REACHES IN UNDER THE LID A LITTLE WAY (AboveMap.bounce): full at an
## open tile, falling off with the way in, gone by BOUNCE_REACH; and the box's
## own edge is no sky, so a window cut from a roofed world is dark at its rim.
func test_the_day_reaches_in_under_the_lid_and_is_gone_deep_in() -> void:
	var w := 40
	var h := 5
	var mask := PackedByteArray()
	mask.resize(w * h)
	for i in w * h:
		mask[i] = 1
	# One open column at x = 0, like a tear's edge.
	for y in h:
		mask[y * w] = 0
	var g := AboveMap.bounce(mask, w, h)
	eq(g[2 * w], 255, "open sky is full")
	gt(float(g[2 * w + 1]), 200.0, "the first tile in is nearly so")
	var last := 256
	for x in range(1, 16):
		check(g[2 * w + x] <= last, "it only falls with the way in (x %d)" % x)
		last = g[2 * w + x]
	eq(g[2 * w + int(AboveMap.BOUNCE_REACH) + 1], 0, "gone past the reach")
	# All covered, no sky in the box at all: dark everywhere, edges included.
	var shut := PackedByteArray()
	shut.resize(9 * 9)
	shut.fill(1)
	var gs := AboveMap.bounce(shut, 9, 9)
	eq(gs.count(0), 81, "a box with no open tile has no day in it, rim or middle")
