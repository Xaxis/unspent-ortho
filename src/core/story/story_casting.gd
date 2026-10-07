class_name StoryCasting
## Binding a slot to somewhere real (docs/DESIGN.md).
##
##   StoryCasting.cast(world, slots) -> {slot id: {pos, region, land, site, body}}
##
## `body` is the continent the slot was cast on, which is the journey's answer and
## not always the tile's: the black site stands in the sea off the home coast.
##
## Pure and deterministic: the same world casts identically every time it is
## grown, which is what lets casting stay OUT of the save. A save keeps the seed
## and grows the world again, so a saved casting would be a second copy of the
## truth — and this game has opinions about second copies of the truth.
##
## A slot that cannot be filled is simply ABSENT from the answer. Whether that is
## a content error is `StoryPlan`'s question and not this file's: casting reports
## what the world can carry and never decides what the story may ask for.

const Treads := preload("res://src/core/colossus/colossus_treads.gd")

## The surface's own casting, per seed, size and registry, for a slot that
## mirrors one of its places (StorySlot.mirror). Not keyed by seed alone: a test
## that narrows the registry grows a different world under the same seed, and a
## cache keyed on the seed handed one of them the other's places (the black site
## did exactly that). Not keyed by WorldStamp either: it costs a millisecond and
## the gates are cast every frame.
static var _surface: Dictionary = {}
## Casting runs on workers too (GenTreads on the raise, StoryPlan.prepare beside
## it) while the main thread casts a world it enters.
static var _surface_lock := Mutex.new()
const SURFACE_MOST := 16


## How many castings have been worked out, for a test to see where one was.
static var casts := 0


static func cast(world: WorldData, slots: Array[StorySlot]) -> Dictionary:
	if world == null:
		return {}
	return _cast(world, slots, _keeper_grounds(world))


## NO STORY PLACE ON A KEEPER'S GROUND (#72). A place the story deals (a village,
## a works, a landmark, a shaft) keeps off every keeper's ground, its reach of its
## lair (Sentinels.states), so the people who live there and the thing they read
## are not in the fight. At 1840, seed 42's Sefa stood on the pan_rake's den and
## seed 41's whole Covenant seat 17 tiles from the lockkeeper's; at 256, seed 1's
## camp had no tile off the listener's ground for its box.
## Each keeper as (lair x, lair y, reach).
static func _keeper_grounds(world: WorldData) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if world.realm != Realm.SURFACE:
		return out
	for st: SentinelState in Sentinels.states(world):
		var def := Sentinels.by_id(st.design)
		if def != null:
			out.append(Vector3(st.lair.x, st.lair.y, def.reach))
	return out


## How far `p` stands past the nearest keeper's ground, in tiles (negative on
## it); INF where no keeper stands.
static func _keeper_margin(p: Vector2, keepers: Array[Vector3]) -> float:
	var m := INF
	for k: Vector3 in keepers:
		m = minf(m, p.distance_to(Vector2(k.x, k.y)) - k.z)
	return m


## THE LADDER A PLACE IS TAKEN BY, best first, on the slot's own body: a slot never
## leaves its leg for a keeper and is never lost to one. 1: past the ground by
## STOOD_REACH, the farthest anyone or anything cast at a slot stands off it
## (49_cast), so all of them are off it too. 2: off the ground, only nearer. 3:
## where no place on the body is off it (seed 41's leg 1, all the lockkeeper's),
## the one farthest from any keeper's ground.
static func _keeper_step(p: Vector2, keepers: Array[Vector3]) -> int:
	var m := _keeper_margin(p, keepers)
	return 1 if m > StoryWorld.STOOD_REACH else (2 if m > 0.0 else 3)


static func _cast(world: WorldData, slots: Array[StorySlot], keepers: Array[Vector3]) -> Dictionary:
	var out := {}
	casts += 1
	# Cast in declaration order, because `apart` measures against what is already
	# placed: the spine's own sequence decides who gets the good ground.
	var taken: Array[Vector2] = []
	var order := StoryJourney.bodies(world)
	# The ORDER is the guarantee (owner, 2026-09-18: "there is an order of operation
	# to the ultimate destinations"). A slot is cast on its leg's body, or on the
	# first body farther out that can hold it, and never nearer home than the slot
	# before it. So the journey only ever moves outward, whatever this world dealt
	# where, and a leg whose own continent lacks the place moves on rather than back.
	var floor_rank := 0
	var twin := {}
	for s: StorySlot in slots:
		# A slot that mirrors a place of the surface stands on that place's tile and
		# never asks this world for its own kind of ground: 2029 has no works yard,
		# and the lab stands where the yard WILL rise (unspent-ortho-df).
		if s.mirror != &"":
			if s.realm != world.realm:
				continue
			if twin.is_empty():
				twin = _twin(world, slots)
			if twin.has(s.mirror):
				out[s.id] = (twin[s.mirror] as Dictionary).duplicate()
			continue
		# The landfall is not dealt: the world says where the water from home
		# comes ashore, or there is none.
		if s.needs == StorySlot.LANDFALL:
			if s.realm == world.realm:
				var rows := _candidates(world, s)
				if not rows.is_empty():
					out[s.id] = (rows[0] as Dictionary).duplicate()
			continue
		# A crater is not dealt: it is the one the world marks as its people's
		# (GenTreads `folk`: the lame leg's, wherever its foot came down), its
		# middle toe's (Treads.MIDDLE_TOE), on whatever body; or none. The walker
		# lead pins it (`crater:the_tread`), across another water where it lies
		# there (StoryCrossing.to_walker). Its row keeps the tread's ankle, pads
		# and yaw, so whoever stands there is stood by it without walking the
		# world's landmarks again (49_cast).
		if s.needs == StorySlot.TREAD:
			if s.realm == world.realm:
				var treads := _candidates(world, s)
				if not treads.is_empty():
					var row: Dictionary = (treads[0] as Dictionary).duplicate()
					var at: Vector2 = row.pos
					row["land"] = _land_at(world, at)
					row["body"] = world.continent_at(floori(at.x), floori(at.y))
					out[s.id] = row
					taken.append(at)
			continue
		var place := {}
		var start := clampi(maxi(s.leg, floor_rank), 0, maxi(order.size() - 1, 0))
		if not s.ordered:
			start = 0
		for rank in range(start, order.size()):
			place = _fill(world, s, taken, order[rank], keepers)
			if not place.is_empty():
				place["body"] = order[rank]
				if s.realm == world.realm and s.ordered:
					floor_rank = rank
				break
		if place.is_empty():
			continue
		out[s.id] = place
		taken.append(place.get("pos", Vector2.ZERO) as Vector2)
	if world.realm == Realm.SURFACE:
		# A place of 2098 that a place of 2029 mirrors is where a gate into the
		# Before stands (StoryGates). Where, off it, is worked out here once and kept
		# in its row, and the Before's twin rows are copies of these (`_twin`), so a
		# gate is one spot in both years (GateStand).
		for s: StorySlot in slots:
			if s.mirror != &"" and out.has(s.mirror):
				var row: Dictionary = out[s.mirror]
				if not row.has("gate"):
					row["gate"] = GateStand.of(world, row)
		var key := _key(world)
		_surface_lock.lock()
		if _surface.size() >= SURFACE_MOST:
			_surface.clear()
		_surface[key] = out
		_surface_lock.unlock()
	return out


## The surface's casting for the world `world` mirrors: the one already cast in
## this game if there is one (the game starts on the surface, so crossing into
## 2029 costs nothing), and otherwise the surface grown from the same seed.
static func _twin(world: WorldData, slots: Array[StorySlot]) -> Dictionary:
	var key := _key(world)
	_surface_lock.lock()
	var had := _surface.has(key)
	_surface_lock.unlock()
	if not had:
		@warning_ignore("return_value_discarded")
		cast(WorldGen.generate(world.seed_value, world.size), slots)
	_surface_lock.lock()
	var got: Dictionary = _surface.get(key, {})
	_surface_lock.unlock()
	return got


## Whether the surface `world` mirrors has been cast in this process already, so
## casting `world` copies its rows and grows no surface (`_twin`).
static func has_twin(world: WorldData) -> bool:
	var key := _key(world)
	_surface_lock.lock()
	var had := _surface.has(key)
	_surface_lock.unlock()
	return had


static func _key(world: WorldData) -> String:
	var ids := PackedStringArray()
	for d: BiomeDef in BiomeRegistry.all():
		ids.append(String(d.id))
	return "%d:%d:%s" % [world.seed_value, world.size, ",".join(ids)]


static func _fill(world: WorldData, s: StorySlot, taken: Array[Vector2], body: int, keepers: Array[Vector3]) -> Dictionary:
	if s.realm != &"" and world.realm != s.realm:
		return {}
	var fits: Array[Dictionary] = []
	for c: Dictionary in _candidates(world, s):
		var p: Vector2 = c.get("pos", Vector2.ZERO)
		# A place in the sea stands on no body, so it says which coast it belongs to.
		var on := int(c.get("body", world.continent_at(floori(p.x), floori(p.y))))
		if on != body:
			continue
		if s.land != &"" and StringName(str(c.get("land", &""))) != s.land:
			continue
		if s.apart > 0.0:
			# Distances only mean something on one body: across water a slot forty
			# tiles off is not forty tiles away.
			if world.same_body(p, world.spawn) and p.distance_to(world.spawn) < s.apart:
				continue
			var clear := true
			for t: Vector2 in taken:
				if world.same_body(p, t) and p.distance_to(t) < s.apart:
					clear = false
					break
			if not clear:
				continue
		fits.append(c)
	if fits.is_empty():
		return {}
	# Of those, where the story may stand: not under a walker's foot, and on the
	# best step of the keeper ladder any of them reaches (`_keeper_step`). The pick
	# below is still made over every fit, so a place refused moves only its own
	# slot, to the nearest place allowed, and never reshuffles another slot's pick.
	var standing: Array[Dictionary] = []
	for f: Dictionary in fits:
		if not bool(f.get("trodden", false)):
			standing.append(f)
	if standing.is_empty():
		return {}
	var step := 3
	for f: Dictionary in standing:
		step = mini(step, _keeper_step(f.pos, keepers))
	var allowed: Array[Dictionary] = []
	if step < 3:
		for f: Dictionary in standing:
			if _keeper_step(f.pos, keepers) == step:
				allowed.append(f)
	else:
		var far: Dictionary = standing[0]
		for f: Dictionary in standing:
			if _keeper_margin(f.pos, keepers) > _keeper_margin(far.pos, keepers):
				far = f
		allowed.append(far)
	var chosen := _choose(world, s, fits, allowed)
	chosen["keeper_step"] = step
	return chosen


## Of `allowed`, the one slot `s` takes: nearest home where it asks for that, else
## its own pick of `fits` where that is allowed, else the allowed place nearest it.
static func _choose(world: WorldData, s: StorySlot, fits: Array[Dictionary], allowed: Array[Dictionary]) -> Dictionary:
	if s.nearest:
		var best: Dictionary = allowed[0]
		for f: Dictionary in allowed:
			if (f.pos as Vector2).distance_to(world.spawn) < (best.pos as Vector2).distance_to(world.spawn):
				best = f
		return best
	# Deterministic: the same slot in the same world always takes the same place,
	# or a save would open onto a thread that had moved.
	var key := s.mirror if s.mirror != &"" else s.id
	var at := int(Rng.hash01(world.seed_value, absi(int(key.hash())), 0, 0x5717) * float(fits.size()))
	var pick: Dictionary = fits[clampi(at, 0, fits.size() - 1)]
	if allowed.has(pick):
		return pick
	var near: Dictionary = allowed[0]
	for f: Dictionary in allowed:
		if (f.pos as Vector2).distance_to(pick.pos) < (near.pos as Vector2).distance_to(pick.pos):
			near = f
	return near


static func _candidates(world: WorldData, s: StorySlot) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match s.needs:
		StorySlot.VILLAGE:
			for v: Dictionary in world.villages:
				var p: Vector2 = v.get("pos", Vector2.ZERO)
				out.append({"pos": p, "region": -1, "land": _land_at(world, p), "site": StorySlot.VILLAGE})
		StorySlot.WORKS:
			for w: WorksSite in Works.sites(world):
				out.append({"pos": w.pos, "region": w.region, "land": w.land, "site": StorySlot.WORKS, "facing": w.facing})
		StorySlot.LANDMARK:
			# Every landmark SITED, each saying whether a walker's foot came down on
			# it (`trodden`): what lies under a crater is no place to stand, and the
			# story reads the world as the feet left it. GenTreads never asks the
			# story where it stands. Sited, not only standing, so a trodden one
			# moves its own slot and leaves every other pick where it was (`_fill`).
			for l: LandmarkSite in Landmarks.sited(world):
				if s.kind != &"" and l.kind != s.kind:
					continue
				out.append({"pos": l.pos, "region": l.region, "land": l.land, "site": StorySlot.LANDMARK, "kind": l.kind,
					"facing": l.facing, "trodden": Landmarks.trodden(world, l.id)})
		StorySlot.PORTAL:
			for pt: Portal in Portals.in_world(world):
				out.append({"pos": pt.pos, "region": pt.region, "land": _land_at(world, pt.pos), "site": StorySlot.PORTAL})
		StorySlot.TREAD:
			# Read off the world, never chosen here: worldgen laid the people's
			# holding at that tread before any story was cast.
			for m: Dictionary in world.landmarks:
				if StringName(m.get("kind", &"")) == &"tread" and bool(m.get("folk", false)):
					var pad: Vector3 = (m.pads as Array)[Treads.MIDDLE_TOE]
					out.append({"pos": Vector2(pad.x, pad.y), "region": -1, "land": &"", "site": StorySlot.TREAD,
						"ankle": m.pos, "pads": m.pads, "yaw": m.yaw})
		StorySlot.LANDFALL:
			# The landfall body's row says where the shortest water from home comes
			# ashore (GenBodies `from`), a tile of that body.
			for row: Dictionary in world.continents:
				if bool(row.get("landfall", false)) and row.has("from"):
					var at: Vector2 = row["from"]
					out.append({"pos": at, "region": -1, "land": _land_at(world, at), "site": StorySlot.LANDFALL, "body": int(row.get("id", -1))})
		StorySlot.BLACK_SITE:
			var at := StoryWorld.black_site(world)
			if at != Vector2.INF:
				var home := world.continent_at(floori(world.spawn.x), floori(world.spawn.y))
				out.append({"pos": at, "region": -1, "land": &"", "site": StorySlot.BLACK_SITE, "body": home})
	return out


## Of `craters`, the one on `at`'s body nearest it; INF where that body has none.
## The one rule for where the walker lead pins its crater (StoryMap.crater_pos)
## and where the crater's people stand (the slot `the_tread`), so the survey never
## sends him to a crater Tull is not at. World-only, so world generation's casting
## can ask it without loading the game.
static func crater_near(world: WorldData, craters: Array[Vector2], at: Vector2) -> Vector2:
	var best := Vector2.INF
	for c: Vector2 in craters:
		if world.same_body(c, at) and (not best.is_finite() or c.distance_to(at) < best.distance_to(at)):
			best = c
	return best


## A landscape's id at a point, through the registry's own door. Never the INDEX:
## `BiomeDef.order` decides indices and adding a landscape reorders them, so a
## stored index means a different place after the next content change — and there
## are eleven landscapes now against VISION's 20+.
static func _land_at(world: WorldData, p: Vector2) -> StringName:
	var def := BiomeRegistry.at(world, p)
	return def.id if def != null else &""
