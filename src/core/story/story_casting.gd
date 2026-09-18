class_name StoryCasting
## Binding a slot to somewhere real (docs/STORY_SYSTEM.md §5).
##
##   StoryCasting.cast(world, slots) -> {slot id: {pos, region, land, site}}
##
## Pure and deterministic: the same world casts identically every time it is
## grown, which is what lets casting stay OUT of the save. A save keeps the seed
## and grows the world again, so a saved casting would be a second copy of the
## truth — and this game has opinions about second copies of the truth.
##
## A slot that cannot be filled is simply ABSENT from the answer. Whether that is
## a content error is `StoryPlan`'s question and not this file's: casting reports
## what the world can carry and never decides what the story may ask for.

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
	for s: StorySlot in slots:
		var place := {}
		var start := clampi(maxi(s.leg, floor_rank), 0, maxi(order.size() - 1, 0))
		for rank in range(start, order.size()):
			place = _fill(world, s, taken, order[rank])
			if not place.is_empty():
				if s.realm == world.realm:
					floor_rank = rank
				break
		if place.is_empty():
			continue
		out[s.id] = place
		taken.append(place.get("pos", Vector2.ZERO) as Vector2)
	return out


static func _fill(world: WorldData, s: StorySlot, taken: Array[Vector2], body: int) -> Dictionary:
	if s.realm != &"" and world.realm != s.realm:
		return {}
	var fits: Array[Dictionary] = []
	for c: Dictionary in _candidates(world, s):
		var p: Vector2 = c.get("pos", Vector2.ZERO)
		if world.continent_at(floori(p.x), floori(p.y)) != body:
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
	var at := int(Rng.hash01(world.seed_value, absi(int(s.id.hash())), 0, 0x5717) * float(fits.size()))
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
	return out


## A landscape's id at a point, through the registry's own door. Never the INDEX:
## `BiomeDef.order` decides indices and adding a landscape reorders them, so a
## stored index means a different place after the next content change — and there
## are eleven landscapes now against VISION's 20+.
static func _land_at(world: WorldData, p: Vector2) -> StringName:
	var def := BiomeRegistry.at(world, p)
	return def.id if def != null else &""
