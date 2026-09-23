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

## The surface's own casting, per seed, size and registry, for a slot that
## mirrors one of its places (StorySlot.mirror). Not keyed by seed alone: a test
## that narrows the registry grows a different world under the same seed, and a
## cache keyed on the seed handed one of them the other's places (the black site
## did exactly that). Not keyed by WorldStamp either: it costs a millisecond and
## the gates are cast every frame.
static var _surface: Dictionary = {}
const SURFACE_MOST := 16


static func cast(world: WorldData, slots: Array[StorySlot]) -> Dictionary:
	var out := {}
	if world == null:
		return out
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
		var place := {}
		var start := clampi(maxi(s.leg, floor_rank), 0, maxi(order.size() - 1, 0))
		if not s.ordered:
			start = 0
		for rank in range(start, order.size()):
			place = _fill(world, s, taken, order[rank])
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
		if _surface.size() >= SURFACE_MOST:
			_surface.clear()
		_surface[_key(world)] = out
	return out


## The surface's casting for the world `world` mirrors: the one already cast in
## this game if there is one (the game starts on the surface, so crossing into
## 2029 costs nothing), and otherwise the surface grown from the same seed.
static func _twin(world: WorldData, slots: Array[StorySlot]) -> Dictionary:
	var key := _key(world)
	if not _surface.has(key):
		@warning_ignore("return_value_discarded")
		cast(WorldGen.generate(world.seed_value, world.size), slots)
	return _surface.get(key, {})


static func _key(world: WorldData) -> String:
	var ids := PackedStringArray()
	for d: BiomeDef in BiomeRegistry.all():
		ids.append(String(d.id))
	return "%d:%d:%s" % [world.seed_value, world.size, ",".join(ids)]


static func _fill(world: WorldData, s: StorySlot, taken: Array[Vector2], body: int) -> Dictionary:
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
	if s.nearest:
		var best: Dictionary = fits[0]
		for f: Dictionary in fits:
			if (f.pos as Vector2).distance_to(world.spawn) < (best.pos as Vector2).distance_to(world.spawn):
				best = f
		return best
	# Deterministic: the same slot in the same world always takes the same place,
	# or a save would open onto a thread that had moved.
	var key := s.mirror if s.mirror != &"" else s.id
	var at := int(Rng.hash01(world.seed_value, absi(int(key.hash())), 0, 0x5717) * float(fits.size()))
	return fits[clampi(at, 0, fits.size() - 1)]


static func _candidates(world: WorldData, s: StorySlot) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match s.needs:
		StorySlot.VILLAGE:
			for v: Dictionary in world.villages:
				var p: Vector2 = v.get("pos", Vector2.ZERO)
				out.append({"pos": p, "region": -1, "land": _land_at(world, p), "site": StorySlot.VILLAGE})
		StorySlot.WORKS:
			for w: WorksSite in Works.sites(world):
				out.append({"pos": w.pos, "region": w.region, "land": w.land, "site": StorySlot.WORKS})
		StorySlot.LANDMARK:
			for l: LandmarkSite in Landmarks.sites(world):
				if s.kind != &"" and l.kind != s.kind:
					continue
				out.append({"pos": l.pos, "region": l.region, "land": l.land, "site": StorySlot.LANDMARK, "kind": l.kind})
		StorySlot.PORTAL:
			for pt: Portal in Portals.in_world(world):
				out.append({"pos": pt.pos, "region": pt.region, "land": _land_at(world, pt.pos), "site": StorySlot.PORTAL})
		StorySlot.BLACK_SITE:
			var at := StoryWorld.black_site(world)
			if at != Vector2.INF:
				var home := world.continent_at(floori(world.spawn.x), floori(world.spawn.y))
				out.append({"pos": at, "region": -1, "land": &"", "site": StorySlot.BLACK_SITE, "body": home})
	return out


## A landscape's id at a point, through the registry's own door. Never the INDEX:
## `BiomeDef.order` decides indices and adding a landscape reorders them, so a
## stored index means a different place after the next content change — and there
## are eleven landscapes now against VISION's 20+.
static func _land_at(world: WorldData, p: Vector2) -> StringName:
	var def := BiomeRegistry.at(world, p)
	return def.id if def != null else &""
