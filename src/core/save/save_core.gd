class_name SaveCore
## The state every running game has, registered with SaveGame by 05_save before
## any other system registers its own. Everything a world does not regenerate
## from its seed:
##
##   world      seed and size (a save only loads onto its own world), props put in
##              the world at runtime (built stations), what was taken (depleted,
##              and survival's taken/spent per option), the stations built
##   clock      world minutes
##   player     place and facing (the fight body is moved with it)
##   body       condition: health, wind, hunger, wet, wounds, lamp lit, arrests...
##   inventory  items, edges, held, worn kit, dull notices given
##   survival   when the body woke, wet until, lamp oil and when it was settled
##   weather    a forced sky (--weather), if any
##
## Props: the world holds its generated props, then whatever the systems' setup
## laid deterministically (the strand), then props added in play. `props_base` is
## how many there were when every system was set up (05_save marks it before a
## load is applied); only props past it are saved, and ids past it are remapped
## on load if a newer build lays a different number, so taken/depleted marks
## still land on the right prop.
##
## Transient state is not saved: the work in hand (a save drops it, as a blow
## would), real-time timers (busy, stun, invulnerable, grip), mobs on the coast.
## The map's memory is the slate's own key (90_ui registers &"ui").

const META_BASE := &"save_props_base"
## THE WORLD A SAVE KEEPS, while the player is in a room (docs/interiors): a
## pocket is grown again from its door's key and holds nothing of its own worth
## keeping here, so the core world state -- what was built and taken, the size
## the slot boots at -- is the coast outside, which 21_doors sets here on the way
## in and clears on the way out. Saved as the pocket instead, a save made indoors
## booted a world the size of a cottage and lost everything built outside.
const META_OUTSIDE := &"save_outside_world"
const BODY_FLOATS: Array[String] = ["max_wind", "wind", "hurt_until", "fed_until", "wet", "load", "tired",
	"spoof_until", "move_factor"]
const BODY_INTS: Array[String] = ["max_health", "health", "arrests", "filed"]
const BODY_BOOLS: Array[String] = ["lamp_lit", "crouched"]


static func register(game: Game) -> void:
	SaveGame.register(&"world", func() -> Variant: return save_world(game), func(v: Variant) -> void: load_world(game, v))
	SaveGame.register(&"clock", func() -> Variant: return {"minutes": game.clock.minutes},
		func(v: Variant) -> void: game.clock.minutes = SaveCodec.to_num(_d(v).get("minutes"), game.clock.minutes))
	SaveGame.register(&"player", func() -> Variant: return save_player(game), func(v: Variant) -> void: load_player(game, v))
	SaveGame.register(&"body", func() -> Variant: return save_body(game.body), func(v: Variant) -> void: load_body(game.body, v))
	SaveGame.register(&"inventory", func() -> Variant: return save_inventory(game.inventory),
		func(v: Variant) -> void: load_inventory(game, v))
	SaveGame.register(&"survival", func() -> Variant: return save_survival(game), func(v: Variant) -> void: load_survival(game, v))
	SaveGame.register(&"weather", func() -> Variant: return {"kind": String(Weather.forced_kind), "strength": Weather.forced_strength},
		func(v: Variant) -> void: load_weather(v))


## The cheap second line, run once the world exists and before anything of the
## save is applied: the header says which landscape the player stood in, and the
## world just grown from the save's seed must put that same landscape under that
## same tile. The stamp catches a registry that moved; this catches a WORLDGEN
## STAGE that moved, which no stamp can see into. Returns "" or the sentence to
## say. A header with no landscape (or a tile off the world) is not held to it.
static func disagrees(game: Game, header: Dictionary) -> String:
	var want := StringName(str(header.get("landscape", "")))
	if want == &"" or game == null or game.world == null:
		return ""
	# A save made in another REALM stood on another world, and the world a game
	# opens with is always the surface's: the realms system crosses to the saved
	# one in started(). Holding a cave save to the ground of the coast above it
	# would refuse every save ever made under the world.
	if StringName(str(header.get("realm", "surface"))) != game.world.realm:
		return ""
	var p := SaveCodec.to_vec2(header.get("pos"), Vector2(-1, -1))
	if p.x < 0.0 or p.y < 0.0 or p.x >= float(game.world.size) or p.y >= float(game.world.size):
		return ""
	var here := BiomeRegistry.at(game.world, p)
	if here.id == want:
		return ""
	return "That game was saved in the %s. This world has %s there instead, so it is not the same ground." % [
		spoken(want), spoken(here.id)]


## A type id as it is said out loud, the display name where there is one.
static func spoken(id: StringName) -> String:
	var d := BiomeRegistry.get_def(id)
	return d.display_name if d != null and d.display_name != "" else String(id).replace("_", " ")


## Note how many props the world holds once every system is set up.
static func mark_base(game: Game) -> void:
	game.set_meta(META_BASE, game.world.prop_count())


static func props_base(game: Game) -> int:
	return int(game.get_meta(META_BASE, ground(game).prop_count()))


## The world whose state a save carries: the one stood in, or the one outside
## the room being stood in (META_OUTSIDE).
static func ground(game: Game) -> WorldData:
	if game.has_meta(META_OUTSIDE):
		var o: Variant = game.get_meta(META_OUTSIDE)
		if o is WorldData:
			return o as WorldData
	return game.world


## The header a slot list shows without reading the data. `landscape` is the type
## the player stood in, kept so a loaded world can be held to it (disagrees()).
static func header(game: Game, play_seconds: float, thumb_png: PackedByteArray) -> Dictionary:
	var p := game.player.pos
	var land := BiomeRegistry.at(game.world, p)
	return {
		"saved_at": Time.get_unix_time_from_system(),
		"day": game.clock.day() + 1,
		"hour": game.clock.hour(),
		"clock": game.clock.label(),
		"minutes": game.clock.minutes,
		"landscape": String(land.id),
		"place": land.display_name,
		# Which realm it stood in, so a save made under the world is not held to
		# the ground of the surface it opens on (disagrees, above).
		"realm": String(game.world.realm),
		"play_seconds": play_seconds,
		# The GAME's seed, not the world it happens to be standing in: a realm's
		# world is grown from that seed with the realm's own salt (Realm.seed_for),
		# and a slot boots the seed the player was given.
		"seed": game.options.seed_value,
		"size": ground(game).size,
		"pos": SaveCodec.vec2(p),
		"thumb": Marshalls.raw_to_base64(thumb_png) if not thumb_png.is_empty() else "",
	}


# --- world ------------------------------------------------------------------

static func save_world(game: Game) -> Dictionary:
	var w := ground(game)
	var base := props_base(game)
	var added: Array = []
	for i in range(base, w.prop_count()):
		var q := w.prop_at(i)
		added.append([q.kind, q.pos.x, q.pos.y, q.rot, q.scale, q.variant])
	var depleted := {}
	for id: int in w.depleted:
		depleted[str(id)] = SaveCodec.num(float(w.depleted[id]))
	var state := SurvivalState.of(game)
	var spent := {}
	for k: String in state.spent:
		spent[k] = SaveCodec.num(float(state.spent[k]))
	var built: Array = []
	for q: WorldProp in state.built:
		built.append(q.id)
	# What lies on the heaps the player left, and which of them a bad end left:
	# a heap without its goods is a cairn with nothing under it.
	var left := {}
	for id: int in state.left:
		left[str(id)] = (state.left[id] as Dictionary).duplicate()
	var bags := {}
	for id: int in state.bags:
		bags[str(id)] = SaveCodec.num(float(state.bags[id]))
	return {"seed": game.options.seed_value, "size": w.size, "realm": String(w.realm),
		"stamp": WorldStamp.current(), "props_base": base,
		"props": added, "depleted": depleted, "taken": state.taken.duplicate(), "spent": spent, "built": built,
		"left": left, "bags": bags}


static func load_world(game: Game, v: Variant) -> void:
	var d := _d(v)
	var w := game.world
	# A save's edits only mean anything on the world they were made on. (A slot
	# always boots its own seed and size; this guards a hand-built BootOptions.)
	if SaveCodec.to_int(d.get("seed"), -1) != game.options.seed_value or SaveCodec.to_int(d.get("size"), -1) != w.size:
		return
	# Nor on another REALM's world. A loaded game always opens on the surface and
	# crosses afterwards, so a save made under the world would otherwise lay a
	# cave's prop ids over the coast's. What each realm had TAKEN out of it comes
	# back through the realms system's own key; what was BUILT in another realm
	# does not yet, because the core world state here is one realm's.
	if StringName(str(d.get("realm", "surface"))) != w.realm:
		return
	# Nor on another island grown from the same seed: prop ids and depleted marks
	# only mean anything against the props this build's registry laid.
	if str(d.get("stamp", WorldStamp.UNKNOWN)) != WorldStamp.current():
		push_warning("save: the world's edits were made on another island; none applied")
		return
	var saved_base := SaveCodec.to_int(d.get("props_base"), props_base(game))
	var base := props_base(game)
	# Props set down since the save's base shift with the base, by position: the
	# stamp says generation laid the same props, so a position is the same prop.
	var remap := func(id: int) -> int:
		var at := w.position_of(id)
		return w.id_at(at - saved_base + base) if at >= saved_base else id
	var touched: Array[WorldProp] = []
	for e: Variant in d.get("props", []):
		if not (e is Array) or (e as Array).size() < 5:
			continue
		var kind := SaveCodec.to_int(e[0], -1)
		if kind < 0 or kind >= PropKind.NAMES.size():
			continue
		# Straight into data and collision: the chunks it lands in are rebuilt once, below.
		var q := WorldProp.new(w.next_id(), kind, Vector2(SaveCodec.to_num(e[1]), SaveCodec.to_num(e[2])),
			SaveCodec.to_num(e[3]), SaveCodec.to_num(e[4], 1.0))
		if (e as Array).size() > 5:
			q.variant = SaveCodec.to_int(e[5], -1)
		w.add_prop(q)
		game.query.add_prop(q)
		touched.append(q)
	for id: int in w.depleted:
		var was := w.prop(id)
		if was != null:
			touched.append(was)
	w.depleted.clear()
	var depleted := _d(d.get("depleted"))
	for k: String in depleted:
		var id: int = remap.call(k.to_int())
		var q := w.prop(id)
		if q != null:
			w.depleted[id] = SaveCodec.to_num(depleted[k])
			touched.append(q)
	var state := SurvivalState.of(game)
	state.taken.clear()
	var taken := _d(d.get("taken"))
	for k: String in taken:
		state.taken[_rekey(k, remap)] = SaveCodec.to_int(taken[k])
	# A thing half taken comes back half taken: the world grows it whole, the takes
	# that were saved work it down again (Harvest.apply_shown).
	state.base_size.clear()
	for k: String in state.taken:
		var q := w.prop(k.get_slice(":", 0).to_int())
		if q != null and Harvest.apply_shown(game, q):
			touched.append(q)
	state.spent.clear()
	var spent := _d(d.get("spent"))
	for k: String in spent:
		state.spent[_rekey(k, remap)] = SaveCodec.to_num(spent[k])
	state.built.clear()
	for e: Variant in d.get("built", []):
		var q := w.prop(remap.call(SaveCodec.to_int(e, -1)))
		if q != null:
			state.built.append(q)
	state.left.clear()
	var left := _d(d.get("left"))
	for k: String in left:
		var id: int = remap.call(k.to_int())
		if w.prop(id) == null:
			continue
		var goods := {}
		var saved := _d(left[k])
		for g: String in saved:
			goods[g if g.begins_with("edge:") else StringName(g)] = SaveCodec.to_int(saved[g])
		state.left[id] = goods
	state.bags.clear()
	var bags := _d(d.get("bags"))
	for k: String in bags:
		var id: int = remap.call(k.to_int())
		if state.left.has(id):
			state.bags[id] = SaveCodec.to_num(bags[k])
	_refresh(game, touched)


## "prop:option" keys follow their prop's id.
static func _rekey(k: String, remap: Callable) -> String:
	var parts := k.split(":")
	if parts.size() != 2:
		return k
	return "%d:%s" % [int(remap.call(parts[0].to_int())), parts[1]]


## Rebuild each drawn chunk that holds a touched prop, once.
static func _refresh(game: Game, props: Array[WorldProp]) -> void:
	if game.view == null:
		return
	var done := {}
	for q in props:
		var key := WorldView._key_of(q.pos)
		if done.has(key) and done[key] != q.id:
			# Already rebuilt for another prop in the chunk; a new prop still needs listing.
			if ground(game).position_of(q.id) >= props_base(game):
				game.view.refresh_props(q)
			continue
		done[key] = q.id
		game.view.refresh_props(q)


# --- player, body, inventory ------------------------------------------------

static func save_player(game: Game) -> Dictionary:
	return {"pos": SaveCodec.vec2(game.player.pos), "facing": game.player.facing}


static func load_player(game: Game, v: Variant) -> void:
	var d := _d(v)
	var p := game.player
	p.pos = SaveCodec.to_vec2(d.get("pos"), p.pos)
	p.facing = SaveCodec.to_num(d.get("facing"), p.facing)
	if p.hero != null:
		p.hero.pos = p.pos
		p.hero.facing = p.facing
		p.hero.move = Vector2.ZERO
	p.drive(Vector2.ZERO, false, 0.0)
	if p.world != null:
		p.position = p.world.to_3d(p.pos)
	if game.camera != null:
		game.camera.snap_to(p.position)
	if game.view != null:
		game.view.focus = p.pos
		game.view.ensure_near(p.pos)


static func save_body(b: Body) -> Dictionary:
	var out := {}
	for f in BODY_FLOATS:
		out[f] = SaveCodec.num(float(b.get(f)))
	for f in BODY_INTS:
		out[f] = int(b.get(f))
	for f in BODY_BOOLS:
		out[f] = bool(b.get(f))
	out["resist"] = b.resist.duplicate()
	out["pressure"] = b.pressure.duplicate()
	return out


static func load_body(b: Body, v: Variant) -> void:
	var d := _d(v)
	for f in BODY_FLOATS:
		if d.has(f):
			b.set(f, SaveCodec.to_num(d[f]))
	for f in BODY_INTS:
		if d.has(f):
			b.set(f, SaveCodec.to_int(d[f]))
	for f in BODY_BOOLS:
		if d.has(f):
			b.set(f, bool(d[f]))
	b.resist = _floats_by_name(d.get("resist"))
	b.pressure = _floats_by_name(d.get("pressure"))
	# A body loaded is not mid-blow, mid-dodge or held.
	b.grip = 0
	b.dodging = false
	b.busy_until = 0.0


static func save_inventory(inv: Inventory) -> Dictionary:
	var dull: Array = []
	for id: StringName in (inv.get("_dull_noticed") as Dictionary):
		dull.append(String(id))
	dull.sort()
	return {"items": SaveCodec.counts(inv.items), "edges": SaveCodec.counts(inv.edges), "held": String(inv.held),
		"worn": String(inv.worn), "dull": dull}


static func load_inventory(game: Game, v: Variant) -> void:
	var d := _d(v)
	var inv := game.inventory
	inv.items = {}
	var items := SaveCodec.to_counts(d.get("items"))
	for id: StringName in items:
		if int(items[id]) > 0:
			inv.items[id] = int(items[id])
	inv.edges = SaveCodec.to_counts(d.get("edges"))
	var dull := {}
	for id: Variant in d.get("dull", []):
		dull[StringName(str(id))] = true
	inv.set("_dull_noticed", dull)
	var worn := StringName(str(d.get("worn", "")))
	inv.worn = worn if worn == &"" or inv.has(worn) else &""
	var held := StringName(str(d.get("held", "")))
	inv.set_held(held)
	if game.player != null and game.player.model != null:
		game.player.model.set_held(inv.held)


static func save_survival(game: Game) -> Dictionary:
	var s := SurvivalState.of(game)
	return {"woke_at": SaveCodec.num(s.woke_at), "wet_until": SaveCodec.num(s.wet_until),
		"lamp_oil": s.lamp_oil, "lamp_at": SaveCodec.num(s.lamp_at)}


static func load_survival(game: Game, v: Variant) -> void:
	var d := _d(v)
	var s := SurvivalState.of(game)
	s.woke_at = SaveCodec.to_num(d.get("woke_at"), s.woke_at)
	s.wet_until = SaveCodec.to_num(d.get("wet_until"), s.wet_until)
	s.lamp_oil = SaveCodec.to_num(d.get("lamp_oil"), s.lamp_oil)
	s.lamp_at = SaveCodec.to_num(d.get("lamp_at"), s.lamp_at)
	s.job = {}
	s.build_ask = {}


# --- the map and the sky ------------------------------------------------------

## The map's memory: the public `explored` of whichever system keeps it (90_ui
## today), found by the field rather than the name; null without one.
static func explored_of(game: Game) -> UiExplored:
	for sys in game.systems:
		var e: Variant = sys.get("explored")
		if e is UiExplored:
			return e
	return null


static func load_weather(v: Variant) -> void:
	var d := _d(v)
	var kind := StringName(str(d.get("kind", "")))
	if kind == &"" or not Weather.KINDS.has(kind):
		Weather.unforce()
	else:
		Weather.force(kind, SaveCodec.to_num(d.get("strength"), 1.0))


static func _d(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _floats_by_name(v: Variant) -> Dictionary:
	var out := {}
	for k: Variant in _d(v):
		out[StringName(str(k))] = SaveCodec.to_num(v[k])
	return out
