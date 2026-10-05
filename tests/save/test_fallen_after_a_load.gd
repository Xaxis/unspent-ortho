extends TestCase
## WHAT A SAVE SAYS HAS FALLEN STAYS DOWN. A ruin's walls (23_ruins) and a house's
## door (21_doors) are worked out from what stands when the game is set up, and
## again when props fall (Events.fell). A load hands the world back its taken
## props after every system is set up (05_save.started), so a ruin a save holds
## as fallen kept its walls, and a fallen house its way in, until something
## else fell.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_a_loaded_game_has_no_walls_or_door_where_the_save_says_they_fell() -> void:
	Sx.use_root("fallen-after-load")
	var a := Sx.game(tree, ["--seed=7", "--size=512", "--hour=12", "--weather=clear:0"])
	var w := a.world
	var doors: Node = Sx.system(a, "21_doors")
	var ruin: WorldProp = null
	var house: WorldProp = null
	w.sync_table()
	for i in w.table.size():
		var k := int(w.table.kind[i])
		if w.depleted.has(w.table.id[i]) or w.table.id[i] >= SaveCore.props_base(a):
			continue
		if ruin == null and k == PropKind.RUIN:
			ruin = w.prop_at(i)
		if house == null and k == PropKind.HOUSE:
			for t: Threshold in (doors.get(&"doors") as Array):
				if t.host_code == PropKind.HOUSE and t.host == w.table.pos[i]:
					house = w.prop_at(i)
		if ruin != null and house != null:
			break
	check(ruin != null and house != null, "seed 7 at 512 holds a standing ruin and a house with a door")
	if ruin == null or house == null:
		Sx.end(a)
		Sx.finish()
		return
	var at := ruin.pos
	var home := house.pos
	var standing := _walls_near(a, at)
	w.depleted[ruin.id] = INF
	w.depleted[house.id] = INF
	Events.fell.emit()
	# What is left round it when it falls in play: a neighbour's walls may reach.
	var fallen := _walls_near(a, at)
	lt(float(fallen), float(standing), "fallen in play, its walls go (%d of %d circles left)" % [fallen, standing])
	eq(Sx.system(a, "05_save").call("save_to", 2), "", "saved to slot 2 with both fallen")
	Sx.end(a)
	var o := BootOptions.new()
	eq(SaveSlots.options_for(2, o), "", "slot 2 boots")
	var b := Sx.game(tree, [], o)
	eq(_walls_near(b, at), fallen, "loaded, the fallen ruin's walls are gone as they went in play")
	var door := false
	for t: Threshold in (Sx.system(b, "21_doors").get(&"doors") as Array):
		if t.host == home:
			door = true
	check(not door, "and the fallen house has no way in")
	Sx.end(b)
	Sx.finish()


## How many wall circles stand on the tiles within two of `p`.
func _walls_near(g: Game, p: Vector2) -> int:
	var n := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			n += g.query.blocks_at(p + Vector2(dx, dy)).size()
	return n
