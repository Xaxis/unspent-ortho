extends TestCase
## A BODY STANDS ON THE LAND AS IT IS DRAWN. Bodies were drawn on their tile's
## level (WorldData.height_at), and the mesher draws the land with warped
## contours and smoothed levels, so within half a tile of a bank the two are a
## step apart: a body sank to the shins in a lip, or hung over a drop, and the
## stipple that draws a hidden body through the land could not reach legs sunk
## less than its margin. The rules keep the tile's level; the drawing does not.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_a_body_stands_on_the_land_as_it_is_drawn() -> void:
	Sx.use_root("bodies-on-ground")
	var g := Sx.game(tree, ["--seed=1", "--size=256", "--hour=11", "--weather=clear:0"])
	await process_frames(3)
	var home := g.player.pos
	g.view.ensure_near(home)
	await process_frames(2)
	var spots: Array[Vector2] = []
	for dy in range(-30, 31):
		for dx in range(-30, 31):
			var p := home + Vector2(dx, dy) * 0.37
			if g.view.chunk_at(p) == null or Ground.is_water(g.world.ground_at(int(p.x), int(p.y))):
				continue
			if absf(g.view.drawn_height(p) - g.world.height_at(p)) >= 0.25:
				spots.append(p)
	gt(float(spots.size()), 2.0, "near a bank the drawn land and the tile's level part (%d spots)" % spots.size())
	var worst := 0.0
	var tried := 0
	for p in spots:
		var at := g.player.place(p)
		if at.distance_to(p) > 0.05:
			continue
		g.player.sync_view(0.0)
		tried += 1
		worst = maxf(worst, absf(g.player.on_land().y - g.player.lift - g.view.drawn_height(at)))
	gt(float(tried), 1.0, "and he can stand on some of them")
	lt(worst, 0.02, "standing there, he is drawn on the drawn land (worst %.2f off)" % worst)
	Sx.end(g)
