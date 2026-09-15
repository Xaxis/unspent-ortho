extends TestCase
## Animals of a ruined world: mangy strays in scavenged collars, sheep counted
## with machine tags, gulls off the tip, a kept bull ringed in machine alloy.


func _spawn(kind: StringName, seed_value: int) -> AnimalModel:
	return AnimalModel.spawn(kind, null, seed_value) as AnimalModel


## Triangles on a layer and surface: surface -1 for any.
func _tris(m: AnimalModel, layer: StringName, surface: int = -1) -> int:
	var n := 0
	for b in m.rig._kits.size():
		for entry: Array in m.rig._kits[b]:
			if entry[2] == layer and (surface < 0 or entry[1] == surface):
				n += (entry[0] as MeshKit).verts.size() / 3
	return n


func _has_colour(m: AnimalModel, bone: StringName, col: Color) -> bool:
	for entry: Array in m.rig._kits[m.rig.find(bone)]:
		for c in (entry[0] as MeshKit).colors:
			if c.is_equal_approx(col):
				return true
	return false


func test_every_dog_wears_a_scavenged_collar_with_a_machine_tag() -> void:
	var lit := 0
	var cable := 0
	for s in 16:
		var d := _spawn(&"dog", s * 11 + 3)
		gt(_tris(d, &"collar"), 0, "dog %d has a collar" % s)
		gt(_tris(d, &"tag", SkinRig.FOUND), 0, "dog %d has a plate tag off a machine" % s)
		if _tris(d, &"tag", SkinRig.GLOW) > 0:
			lit += 1
		if _tris(d, &"collar", SkinRig.FOUND) > 0:
			cable += 1
		lt(d.rig.triangle_count(), 801, "dog %d stays in the animal budget" % s)
		d.free()
	check(lit > 0 and lit < 16, "a few tags still show a live pip (%d of 16)" % lit)
	check(cable > 0 and cable < 16, "some collars are machine cable, some cord (%d of 16)" % cable)


func test_strays_are_thin_and_mangy() -> void:
	var ribbed := 0
	for s in 16:
		var d := _spawn(&"dog", s * 7 + 1)
		# The body bone carries the trunk, then the mange: bald patches (up to three
		# cards) and, on the thinnest, three ribs a side.
		var kits: Array = d.rig._kits[d.rig.find(&"body")]
		gt(kits.size(), 1, "dog %d has mange drawn over its coat" % s)
		var marks := (kits[1][0] as MeshKit).verts.size() / 6
		check(marks >= 1, "dog %d: at least one bald patch" % s)
		if marks > 3:
			ribbed += 1
		d.free()
	check(ribbed > 0 and ribbed < 16, "the thinnest show their ribs (%d of 16)" % ribbed)


func test_every_sheep_is_tagged() -> void:
	for s in 12:
		var sh := _spawn(&"sheep", s * 5 + 2)
		gt(_tris(sh, &"tag", SkinRig.FOUND), 0, "sheep %d carries a machine tag" % s)
		lt(sh.rig.triangle_count(), 801, "sheep %d stays in the budget" % s)
		sh.free()


func test_gulls_come_off_the_tip() -> void:
	var oiled := 0
	var ringed := 0
	var trailing := 0
	for s in 24:
		var g := _spawn(&"gull", s * 13 + 5)
		if _has_colour(g, &"body", Palette.ASH[3]):
			oiled += 1
		if _tris(g, &"tag", SkinRig.FOUND) > 0:
			ringed += 1
		if _tris(g, &"refuse") > 0:
			trailing += 1
		g.free()
	check(oiled > 0 and oiled < 24, "some gulls oiled grey (%d of 24)" % oiled)
	check(ringed > 0 and ringed < 24, "a few ringed with a machine band (%d of 24)" % ringed)
	check(trailing > 0 and trailing < 24, "some trail refuse from the bill (%d of 24)" % trailing)


func test_the_bull_is_kept_ringed_and_tagged() -> void:
	for s in 4:
		var b := _spawn(&"bull", s * 3 + 1)
		gt(_tris(b, &"tag", SkinRig.FOUND), 16, "bull %d: a nose ring and an ear tag of machine alloy" % s)
		b.free()


func test_a_village_with_a_tip_near_sends_its_gulls_to_the_refuse() -> void:
	var w := WorldGen.generate(5)
	var g := Game.new()
	g.world = w
	g.query = WorldQuery.new(w)
	g.player = Player.new()
	g.player.world = w
	g.player.query = g.query
	var f: GameSystem = (load("res://src/systems/37_fauna.gd") as GDScript).new()
	f.game = g
	var v: Vector2 = w.villages[0].pos
	# A tip on standing ground a few tiles out from the square.
	var at := v
	for i in 24:
		var p := v + Vector2.from_angle(TAU * i / 24.0) * 6.0
		if g.query.standable(floori(p.x), floori(p.y)):
			at = p
			break
	var tip := WorldProp.new(987654, PropKind.TIP, at, 0.0, 1.0)
	w.props.append(tip)
	g.query.add_prop(tip)
	var spot: Vector2 = f.call("_refuse", v, 18.0)
	check(spot.x >= 0.0, "a spot beside the tip")
	lt(spot.distance_to(at), tip.solid + 1.2, "right beside it")
	g.player.pos = v
	f.call("_populate", 0, v)
	var gulls := (f.get("queue") as Array).filter(func(q: Dictionary) -> bool: return q.kind == &"gull")
	if gulls.is_empty():
		check(false, "gulls came for the refuse")
	for q: Dictionary in gulls:
		lt((q.pos as Vector2).distance_to(at), tip.solid + 3.0, "the flock works the tip, not the tideline")
	w.props.pop_back()
	f.free()
	g.player.free()
	g.free()
