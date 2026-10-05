extends TestCase
## THE SWING IS DRAWN WHERE IT HITS (cb's hit audit): a player's blow lands on
## whatever touches its box (FightRules.box_hits from the body, out along the
## facing to its reach, its width across), so the stroke of light is that box
## and nothing else. Drawn as a fan of 108 degrees or more over a straight strip,
## a lance painted 1.8 tiles where nothing landed, and the box struck beside the
## player where nothing was drawn.

const TOO_FAR := 0.001


func test_every_weapon_s_stroke_covers_its_box_and_nothing_more() -> void:
	var ids: Array[StringName] = [&""]
	for id: StringName in Items.DEFS:
		if Items.def(id).has("swing"):
			ids.append(id)
	var wrong: Array[String] = []
	for id: StringName in ids:
		var b := Blow.for_item(id, 5000)
		if b.sweep > 0.0:
			continue
		var mesh := MobFx.swing_mesh(Tuning.PLAYER_RADIUS, Tuning.PLAYER_RADIUS + b.reach, b.width)
		var box := mesh.get_aabb()
		var lo := Vector2(Tuning.PLAYER_RADIUS, -b.width * 0.5)
		var hi := Vector2(Tuning.PLAYER_RADIUS + b.reach, b.width * 0.5)
		if absf(box.position.x - lo.x) > TOO_FAR or absf(box.end.x - hi.x) > TOO_FAR \
				or absf(box.position.z - lo.y) > TOO_FAR or absf(box.end.z - hi.y) > TOO_FAR:
			wrong.append("%s drawn x %.2f..%.2f z %.2f..%.2f, box x %.2f..%.2f z %.2f..%.2f" % [id, box.position.x, box.end.x, box.position.z, box.end.z, lo.x, hi.x, lo.y, hi.y])
	eq(wrong.size(), 0, "every stroke is its box: %s" % str(wrong.slice(0, 3)))


func test_a_swept_tool_s_fan_is_where_its_blow_lands() -> void:
	# A tool swung through an arc (Items.SWEPT) hits a sector, drawn as that fan:
	# every point of the fan between the skin and the tip is struck, and a point
	# just past its edge is not.
	var o := Vector2.ZERO
	var r := Tuning.PLAYER_RADIUS
	var wrong: Array[String] = []
	var swept := 0
	for id: StringName in Items.SWEPT:
		if not Items.DEFS.has(id):
			continue
		var b := Blow.for_item(id, 5000)
		swept += 1
		var half := b.sweep * 0.5
		var mesh := MobFx.swing_mesh(r, r + b.reach, b.width, Callable(), b.sweep)
		var box := mesh.get_aabb()
		if absf(box.end.x - (r + b.reach)) > TOO_FAR or absf(box.end.z - (r + b.reach) * sin(half)) > TOO_FAR:
			wrong.append("%s fan bounds %s" % [id, box])
		for k in 9:
			var a := lerpf(-half, half, k / 8.0)
			for v: float in [0.0, 0.5, 1.0]:
				var on := Vector2.from_angle(a) * lerpf(r, r + b.reach, v)
				if not FightRules.box_hits(o, 0.0, r, b, on, 0.001):
					wrong.append("%s misses its own fan at %s" % [id, on])
			var past := Vector2.from_angle(half + 0.05) * (r + b.reach * 0.5)
			if FightRules.box_hits(o, 0.0, r, b, past, 0.001):
				wrong.append("%s lands past its fan's edge" % id)
	gt(float(swept), 10.0, "every swung tool was asked (%d)" % swept)
	eq(wrong.size(), 0, "each fan is its blow: %s" % str(wrong.slice(0, 3)))


func test_a_stroke_at_a_body_a_ledge_away_shows_it_cannot_land() -> void:
	# A body below a bank two levels down is out of every blow (FightRules.
	# levels_meet), but the stroke was drawn over it all the same (cb's hit
	# audit). The stroke covers only ground a blow from here lands on.
	const F := preload("res://tests/fight/fixture.gd")
	var w := F.flat_world(64, Ground.GRASS, Country.COAST, 4)
	for y in 64:
		for x in range(21, 64):
			w.level[y * 64 + x] = 2
	var sim := F.make_sim(w, Vector2(20.5, 20.5))
	sim.hero.facing = 0.0
	var b := Blow.for_item(&"boathook", 5000)
	var lands := func(local: Vector2) -> bool: return sim.meets_hero(sim.hero.pos + local.rotated(sim.hero.facing))
	var mesh := MobFx.swing_mesh(Tuning.PLAYER_RADIUS, Tuning.PLAYER_RADIUS + b.reach, b.width, lands)
	var over := 0
	var on := 0
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] if mesh.get_surface_count() > 0 else PackedVector3Array()
	for t in range(0, verts.size(), 3):
		var mid := (verts[t] + verts[t + 1] + verts[t + 2]) / 3.0
		if sim.meets_hero(sim.hero.pos + Vector2(mid.x, mid.z)):
			on += 1
		else:
			over += 1
	gt(float(on), 0.0, "the stroke is drawn over the bank it can reach (%d)" % on)
	eq(over, 0, "and over none of the ground below it, a ledge away")
