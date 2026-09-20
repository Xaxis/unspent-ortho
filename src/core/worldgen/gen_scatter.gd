class_name GenScatter
## Stages 10 and 12: places worth walking to, then every prop.
##
## Sites (before grounds, since a tip or a fumarole lays its own ground): tips
## of machine leavings, stone circles, ruins, fumaroles, cairns on summits,
## falls where rivers step down, a caldera — each landscape says which of them
## it holds in `BiomeDef.sites`. Wrecks are sited after the grounds, on bay
## sand only.
##
## Props (after grounds): villages first (the fire in the square, the bench
## drawn up to it, the lamp at the square's edge, houses facing in), then
## landmarks, kilns by the villages, then the machines' grid (pylon and pole
## lines striding dead straight across landscapes, spurs to villages), then the
## hashed per-tile scatter. A tile's scatter follows the same recipe its ground
## did (GenContext.recipe), so props lie in the same islands as the ground
## under them, and every prop must be on its landscape's list (`BiomeDef.props`),
## so no reeds grow on the Snowfield and no pines in the Burning. Ore sits in
## rock by landscape, richest in the Bonelands, thickest at cliff feet.


## Prop kinds each landscape's scatter may place, as bit masks by type index.
static func allow(c: GenContext) -> PackedInt64Array:
	var out := PackedInt64Array()
	out.resize(c.types)
	for cc: int in c.land_types:
		for kind: int in c.defs[cc].props:
			out[cc] |= 1 << kind
	return out


## Every kind a landscape declares as ITS OWN, in either list, as bit masks by
## type index.
##
## **A LANDSCAPE DECLARES WHAT IT HOLDS IN TWO PLACES AND THEY MEAN DIFFERENT
## THINGS.** `props` is what the per-tile scatter may DEAL, and `allow` above is
## built from it because that is the question the scatter asks. `ore` is a second
## list with its own rates, laid by its own pass, and its kinds are usually not
## repeated in `props` -- the Ruined Metropolis declares iron, copper and stone
## ore and names none of them twice.
##
## So anything asking "is this thing on theme where it stands" must read BOTH, or
## it calls a landscape's own ore an intruder. That is what it did.
static func declared(c: GenContext) -> PackedInt64Array:
	var out := allow(c)
	for cc: int in c.land_types:
		for row: Array in c.defs[cc].ore:
			out[cc] |= 1 << int(row[0])
	return out


## Kinds placed by design (villages, landmarks, the grid), allowed anywhere.
const PLACED: Array[int] = [PropKind.PYLON, PropKind.POLE, PropKind.RUIN, PropKind.HOUSE, PropKind.LAMP, PropKind.FIRE, PropKind.BENCH, PropKind.KILN, PropKind.TIP, PropKind.WRECK, PropKind.CAIRN, PropKind.STANDING_STONE,
	PropKind.FENCE, PropKind.BARRICADE, PropKind.SIGN, PropKind.GRAVE, PropKind.DEBRIS, PropKind.SHACK, PropKind.VEHICLE, PropKind.HULL,
	PropKind.SEA_WALL, PropKind.TIDE_GAUGE, PropKind.INTAKE, PropKind.PUMP_HOUSE, PropKind.PIPE, PropKind.STUMP, PropKind.FIRE_TOWER,
	PropKind.RELAY, PropKind.CHECKPOINT, PropKind.STACK, PropKind.DRILL_RIG, PropKind.CONVEYOR, PropKind.SURVEY, PropKind.WATER_TANK,
	PropKind.SLAG_HEAP, PropKind.VENT_CAP, PropKind.ARCHIVE, PropKind.WRECKAGE, PropKind.MEMORIAL,
	PropKind.PAN_GATE, PropKind.SALT_HEAP, PropKind.SCRAP_TREE, PropKind.MAGNET_HEAP]


## Sites that shape grounds. Records landmarks.
## How many tiles of a region ONE DECLARED SITE covers. `BiomeDef.sites` counts
## are read against this, so a landscape file still reads as a list of what one of
## its places holds and a region twice the size holds twice as many without
## anybody retuning a landscape.
##
## It is deliberately NOT "a chapter's tiles". Those are two questions — how big a
## place is, and how FULL — and tying the density to the chapter size means a
## bigger chapter is the same emptiness spread further. This is the fullness knob,
## and it is the one to turn when a landscape reads bare.
##
## IT USED TO BE PER TYPE, ACROSS THE WHOLE ISLAND, and that is why a bigger
## landscape was a bigger EMPTY one. The coast is 29.6% of a 512 world — about
## 37,400 tiles — and laid four tips: one place per 9,350 tiles. The loop was
## `for cc in c.land_types`, so growing a region could not add a single thing to
## it. A number that was right when the island was the world.
const TILES_PER_SITE := 14000.0
## How far two places worth walking to stand apart, in tiles.
##
## IT HAS TO FOLLOW THE DENSITY OR IT STARVES WHOEVER IS PLACED LAST. A wreck
## asked for 50 tiles clear of any landmark and a tip for 36, which were roomy
## numbers in a world holding 23 sites. At one site per ~3,300 tiles the mean
## spacing between places is about 57 tiles, so a 50-tile exclusion is nearly the
## whole spacing: the first pass fills the island and the beaches have nowhere
## left. Measured, seed 1 came out with NO wrecks at all, and the failure read as
## "wreck placed expected > 0, got 0" — a kind vanishing, not a spacing being
## tight.
##
## Half the mean spacing is about the most that can be asked. Turning
## `TILES_PER_SITE` moves this with it rather than quietly emptying the coast.
const PLACES_APART := 28.0


## Every region of type `cc`, biggest first, as {id, tiles} — the unit a site
## count is now spent over.
## Write down a place worth walking to. THE REGION GOES ON THE ROW: a reader that
## works out which place a site is in from its position is right until the first
## one that straddles a border, and a sub-arc, a picket and a chapter's demand all
## ask that question (`WorldData.landmarks`). -1 where it stands on land too small
## to be a region at all.
static func _mark(w: WorldData, kind: StringName, at: Vector2, country: int, more: Dictionary = {}) -> void:
	var row := {"kind": kind, "pos": at, "country": country,
		"region": w.region_at(floori(at.x), floori(at.y))}
	for k: Variant in more:
		row[k] = more[k]
	w.landmarks.append(row)


static func _regions_of(w: WorldData, cc: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in w.regions:
		if int(r.get("index", -1)) == cc:
			out.append(r)
	return out


## How many of a per-chapter count this region earns, never fewer than one where
## the landscape declares any: a place that holds none of what its landscape is
## known for is not that landscape.
static func _want_here(declared: int, region: Dictionary) -> int:
	if declared <= 0:
		return 0
	return maxi(1, roundi(float(declared) * float(region.get("tiles", 0)) / TILES_PER_SITE))


static func sites(c: GenContext) -> void:
	var w := c.w
	var rng := Rng.make(c.s, 81)
	# Tips: scrap heaps where a landscape says the machines dumped them. PER
	# REGION, so a place twice the size holds twice as many (`TILES_PER_SITE`).
	for cc: int in c.land_types:
		for region: Dictionary in _regions_of(w, cc):
			var want := _want_here(int(c.defs[cc].sites.get("tips", 0)), region)
			var here := int(region.get("id", -1))
			var placed := 0
			for attempt in 2500:
				if placed >= want:
					break
				var p := _random_tile_in(c, rng, region.get("bounds", c.land_rect) as Rect2)
				var i := p.y * c.size + p.x
				if w.country[i] != cc or w.blend[i] > 0.42 or w.region_at(p.x, p.y) != here:
					continue
				if not _clear_site(c, p, 6, 2) or _near_landmark(w, Vector2(p), PLACES_APART * maxf(c.body_k, 0.5)) or _near_village(w, Vector2(p), 22.0):
					continue
				_lay_tip(c, p, rng.randf_range(4.0, 7.5))
				_mark(w, &"tip", Vector2(p) + Vector2(0.5, 0.5), cc)
				placed += 1
	# Stone circles on open flat ground where a landscape keeps them, per region
	# for the same reason.
	for cc: int in c.land_types:
		for region: Dictionary in _regions_of(w, cc):
			var circles := _want_here(int(c.defs[cc].sites.get("stone_circles", 0)), region)
			var here := int(region.get("id", -1))
			var placed := 0
			for attempt in 2500:
				if placed >= circles:
					break
				var p := _random_tile_in(c, rng, region.get("bounds", c.land_rect) as Rect2)
				var i := p.y * c.size + p.x
				if w.country[i] != cc or w.blend[i] > 0.3 or w.region_at(p.x, p.y) != here:
					continue
				if not _clear_site(c, p, 5, 1) or _near_landmark(w, Vector2(p), PLACES_APART) or _near_village(w, Vector2(p), 26.0):
					continue
				_mark(w, &"stone_circle", Vector2(p) + Vector2(0.5, 0.5), cc)
				placed += 1
	# Ruins where people had steadings to lose.
	var ruins := 0
	for attempt in 1200:
		if ruins >= maxi(2, roundi(7 * maxf(c.body_k, 0.3))):
			break
		var p := _random_tile(c, rng)
		var i := p.y * c.size + p.x
		var cc := w.country[i]
		if cc == Country.SEA or not bool(c.defs[cc].sites.get("ruins", false)):
			continue
		if not _clear_site(c, p, 3, 1) or _near_landmark(w, Vector2(p), 36.0) or _near_village(w, Vector2(p), 24.0):
			continue
		_mark(w, &"ruin", Vector2(p) + Vector2(0.5, 0.5), cc)
		ruins += 1
	# Fumaroles: fields of vents on their own clinker, out on the slopes of a
	# landscape that breathes, so a walk through the ash has somewhere to go.
	var vented := -1
	var vent_count := 0
	for cc: int in c.land_types:
		if int(c.defs[cc].sites.get("fumaroles", 0)) > 0:
			vented = cc
			vent_count = int(c.defs[cc].sites.get("fumaroles", 0))
			break
	var fumaroles := 0
	var heart := c.hearts[c.caldera_type] if c.caldera_type >= 0 else Vector2(-1, -1)
	for attempt in (6000 if vented >= 0 else 0):
		if fumaroles >= maxi(2, roundi(vent_count * c.body_k)):
			break
		var p := _random_tile(c, rng)
		var i := p.y * c.size + p.x
		if w.country[i] != vented or w.blend[i] > 0.3:
			continue
		if heart.x >= 0.0 and Vector2(p).distance_to(heart) < GenRelief.crater_radius(c) * 1.1:
			continue
		# Later attempts settle for rougher ground and closer company.
		var rough := 1 if attempt < 3000 else 2
		if not _clear_site(c, p, 4, rough) or _near_landmark(w, Vector2(p), (30.0 if attempt < 3000 else 20.0) * maxf(c.body_k, 0.5)) or _near_village(w, Vector2(p), 22.0):
			continue
		_lay_patch(c, p, rng.randf_range(4.0, 6.0), Ground.CLINKER)
		_mark(w, &"fumarole", Vector2(p) + Vector2(0.5, 0.5), vented)
		fumaroles += 1
	# Summits: the highest walkable ground in each upland landscape gets a cairn,
	# raised in the order its type declares (BiomeDef.sites.summit).
	var best_at: Array[Vector2i] = []
	var best_l := PackedInt32Array()
	for cc in c.types:
		best_at.append(Vector2i(-1, -1))
		best_l.append(-1)
	var level := w.level
	for y in range(4, c.size - 4, 2):
		for x in range(4, c.size - 4, 2):
			var i := y * c.size + x
			var cc := w.country[i]
			var l := level[i]
			if l <= best_l[cc] or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0:
				continue
			if level[i + 1] == l and level[i - 1] == l and level[i + c.size] == l and level[i - c.size] == l:
				best_l[cc] = l
				best_at[cc] = Vector2i(x, y)
	var summits: Array[int] = []
	for cc: int in c.land_types:
		if int(c.defs[cc].sites.get("summit", 0)) > 0:
			summits.append(cc)
	summits.sort_custom(func(a: int, b: int) -> bool:
		return int(c.defs[a].sites.summit) < int(c.defs[b].sites.summit))
	for cc: int in summits:
		if best_at[cc].x >= 0:
			_mark(w, &"summit", Vector2(best_at[cc]) + Vector2(0.5, 0.5), cc)
	# Falls: wherever a river's bed steps down a level.
	for r in c.rivers:
		for j in range(1, r.size()):
			var a := r[j - 1]
			var b := r[j]
			if w.level_at(floori(a.x), floori(a.y)) > w.level_at(floori(b.x), floori(b.y)):
				_mark(w, &"falls", a, w.country_at(floori(a.x), floori(a.y)), {"dir": b - a})
	if heart.x >= 0.0:
		_mark(w, &"caldera", heart, w.country_at(int(heart.x), int(heart.y)))


static func _random_tile(c: GenContext, rng: RandomNumberGenerator) -> Vector2i:
	return _random_tile_in(c, rng, c.land_rect)


## **A TILE INSIDE A GIVEN RECT, BECAUSE A PER-REGION SITE HAS TO LOOK WHERE THE
## REGION IS.** The site loops below throw darts and keep the ones that land in
## the region they are filling -- and they were throwing them at `land_rect`, the
## bounding box of ALL the land. On a 1300 world that is about 1.6 million tiles,
## so a 700-tile region was hit about once in 2,500 darts, which is exactly the
## number of darts the loop throws. Then that one hit still had to be clear, off
## a road, away from a village and away from another landmark -- so small regions
## got NOTHING, and a landscape that declared tips in its own file had none
## anywhere on the island.
##
## Aimed at the region's own bounds, a dart lands inside it perhaps half the
## time. Same loop, same rules, same count; it just looks where the thing is.
static func _random_tile_in(c: GenContext, rng: RandomNumberGenerator, r: Rect2) -> Vector2i:
	return Vector2i(
		clampi(rng.randi_range(int(r.position.x), int(r.end.x)), 3, c.size - 4),
		clampi(rng.randi_range(int(r.position.y), int(r.end.y)), 3, c.size - 4))


## Dry, roadless, village-free, nearly flat ground within radius r.
static func _clear_site(c: GenContext, p: Vector2i, r: int, max_rise: int) -> bool:
	var w := c.w
	var i0 := p.y * c.size + p.x
	if c.land[i0] == 0:
		return false
	var l0 := w.level[i0]
	for dy in range(-r, r + 1, 2):
		for dx in range(-r, r + 1, 2):
			var x := p.x + dx
			var y := p.y + dy
			if x < 2 or y < 2 or x >= c.size - 2 or y >= c.size - 2:
				return false
			var i := y * c.size + x
			if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0 or c.ramp[i] != 0:
				return false
			if absi(w.level[i] - l0) > max_rise:
				return false
	return true


static func _near_landmark(w: WorldData, p: Vector2, d: float) -> bool:
	for m in w.landmarks:
		if (m.pos as Vector2).distance_squared_to(p) < d * d:
			return true
	return false


static func _near_village(w: WorldData, p: Vector2, d: float) -> bool:
	for v in w.villages:
		if (v.pos as Vector2).distance_squared_to(p) < d * d:
			return true
	return false


static func _lay_tip(c: GenContext, p: Vector2i, r: float) -> void:
	var cc := c.w.country[p.y * c.size + p.x]
	_lay_patch(c, p, r, c.defs[cc].tip_ground)


## A lobed patch of a site's own ground.
##
## **IT STOPS AT THE BORDER.** The patch is what later decides which props stand
## here, so ground laid across a border puts one landscape's props in another --
## measured, one stone ore in the machine city, from a tip whose centre was a few
## tiles inside its own land. It was invisible while the site loops could barely
## find a small region at all; aiming them at their region's own bounds made them
## land near edges as often as anywhere else, and the bleed showed.
##
## A scrap tip belongs to the landscape that dumped it, and its ground has no
## business in the next one.
static func _lay_patch(c: GenContext, p: Vector2i, r: float, ground: int) -> void:
	var own: int = c.w.country[p.y * c.size + p.x]
	var ri := ceili(r) + 2
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var x := p.x + dx
			var y := p.y + dy
			if x < 1 or y < 1 or x >= c.size - 1 or y >= c.size - 1:
				continue
			var i := y * c.size + x
			if c.w.country[i] != own:
				continue
			if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0:
				continue
			var ang := atan2(dy, dx)
			var edge := r * (0.8 + 0.25 * sin(ang * 3.0 + p.x) + 0.12 * sin(ang * 5.0 + p.y))
			if dx * dx + dy * dy <= edge * edge:
				c.site_ground[i] = ground + 1


static func props(c: GenContext) -> void:
	var occ := PackedByteArray()
	occ.resize(c.n)
	_wrecks(c)
	_villages(c, occ)
	GenSettle.frame_spawn(c)
	_landmarks(c, occ)
	c.mark(&"props.places")
	_lines(c, occ)
	c.mark(&"props.lines")
	# The dystopian evidence of every landscape (GenWorks), before the scatter
	# so a clearcut or a corridor stays clear.
	GenWorks.place(c, occ)
	c.mark(&"props.works")
	_scatter(c, occ)
	c.mark(&"props.scatter")
	_way_in(c)
	_black_site(c)


## THE THRESHOLD SITE, out in the water off the beach he washes up on
## (`BlackSite`, docs/STORY.md). Where Elias died in 2029 and where the Seeker
## grew the body he wakes in, so it stands where the spawn can see it and is
## reached by raft.
##
## Laid LAST, after the scatter, for one reason: it is the only thing in this
## file that stands in deep water, so nothing else has an opinion about the tiles
## it wants and it has no opinion about theirs. It takes no `occ` and asks for no
## `_free` -- there is nothing out there to be free of.
##
## **THE ORDER OF THESE FOUR IS A CONTRACT.** The story hands each readable thing
## its words by counting props of that kind in ID order within
## `StoryWorld.PLACE_REACH` of the site (`StoryFragments.held_by`), so the first
## CONSOLE laid is the tank's own panel and the second is the console by the sea
## door. Insert a third and the two that exist start saying each other's lines.
static func _black_site(c: GenContext) -> void:
	var at := BlackSite.site(c.w)
	if at == Vector2.INF:
		return
	# The deck faces the shore it was reached from, so the ladder and the open
	# side of the handrail are the side a raft comes at.
	var face := (c.w.spawn - at).angle()
	_add(c, PropKind.PLATFORM, at, face)
	# On the deck: the tank off to one side, its panel beside the door, the sea
	# door's console across from it, and the binder left where somebody read it.
	var along := Vector2.from_angle(face)
	var across := Vector2(-along.y, along.x)
	_add(c, PropKind.GROWTH_TANK, at - along * 1.15 + across * 0.5, face)
	_add(c, PropKind.CONSOLE, at - along * 0.15 + across * 1.55, face)
	_add(c, PropKind.CONSOLE, at + along * 1.5 - across * 0.9, face + PI * 0.5)
	_add(c, PropKind.ARCHIVE, at - along * 1.3 - across * 1.5, face - PI * 0.4)


## The first iron within a morning's walk of the spawn. The coast's own rock is
## mostly far up in the hills, and the way in (knife, fire, haft, pick, iron,
## axe) stalls without a vein; so a small scree outcrop with two iron seams and
## a stone seam is set at the foot of a rise inland of the spawn, unless iron
## already shows that close.
const WAY_IN_NEAR := 22.0
const WAY_IN_FAR := 46.0

static func _way_in(c: GenContext) -> void:
	var w := c.w
	var sp := w.spawn
	var taken := {}
	for prop in w.props:
		if prop.pos.distance_squared_to(sp) > (WAY_IN_FAR + 4.0) * (WAY_IN_FAR + 4.0):
			continue
		if prop.kind == PropKind.IRON_ORE and prop.pos.distance_to(sp) < WAY_IN_FAR:
			return
		taken[Vector2i(floori(prop.pos.x), floori(prop.pos.y))] = true
	var best := Vector2i(-1, -1)
	var best_score := -1e9
	var r := int(WAY_IN_FAR)
	for y in range(floori(sp.y) - r, floori(sp.y) + r + 1, 2):
		for x in range(floori(sp.x) - r, floori(sp.x) + r + 1, 2):
			if x < 3 or y < 3 or x >= c.size - 3 or y >= c.size - 3:
				continue
			var d := Vector2(x + 0.5, y + 0.5).distance_to(sp)
			if d < WAY_IN_NEAR or d > WAY_IN_FAR:
				continue
			var i := y * c.size + x
			var l := w.level[i]
			if l <= 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0:
				continue
			var g := w.ground[i]
			if g == Ground.SAND or g == Ground.SHINGLE or g == Ground.MUD or Ground.is_water(g):
				continue
			var ok := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var j := (y + dy) * c.size + x + dx
					if w.level[j] != l or c.water[j] != 0 or c.road[j] != 0 or taken.has(Vector2i(x + dx, y + dy)):
						ok = false
			if not ok:
				continue
			# At the foot of a rise the seams read as the rise's own rock.
			var rise := 0
			for k: Vector2i in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3)]:
				if w.level_at(x + k.x, y + k.y) > l:
					rise = 1
			var sc := float(rise) * 2.0 - absf(d - 30.0) * 0.08 + GenFields.h01(c.s, x, y, 91) * 0.8
			if sc > best_score:
				best_score = sc
				best = Vector2i(x, y)
	if best.x < 0:
		return
	var centre := Vector2(best.x + 0.5, best.y + 0.5)
	# A lobed scree patch under the seams, never a square.
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var j := (best.y + dy) * c.size + best.x + dx
			var ang := atan2(dy, dx)
			var edge := 2.2 + 0.6 * sin(ang * 3.0 + best.x) + 0.3 * sin(ang * 5.0 + best.y)
			if dx * dx + dy * dy <= edge * edge and w.level[j] == w.level[best.y * c.size + best.x] and c.water[j] == 0 and c.road[j] == 0:
				w.ground[j] = Ground.SCREE
	var a := GenFields.h01(c.s, best.x, best.y, 92) * TAU
	# **EACH SEAM ON THE CENTRE'S OWN COUNTRY.** The three stand up to 1.2 tiles
	# out, so a seam sited a stride inside its landscape can put one of them over
	# the border -- measured, exactly one stone ore in the machine city, which
	# declares no stone. The centre passing the test says nothing about where the
	# props land, which is the same mistake as counting placements and calling
	# them drawn.
	var own: int = w.country[best.y * c.size + best.x]
	var any := _declares_ore(c, own, PropKind.IRON_ORE) or _declares_ore(c, own, PropKind.STONE_ORE)
	_seam(c, PropKind.IRON_ORE, centre + Vector2.from_angle(a) * 0.9, not any)
	_seam(c, PropKind.IRON_ORE, centre + Vector2.from_angle(a + 2.3) * 1.1, not any)
	_seam(c, PropKind.STONE_ORE, centre + Vector2.from_angle(a + 4.2) * 1.2)


## One of the way-in's seams, laid only where the landscape under it says that
## ore is there. The machine city holds copper and iron and NO stone, and the
## way in stood a stone seam in it on seed 42 -- one off-theme prop, of the kind
## that reads as the world having broken rather than as a placer not asking.
##
## `force` is the fallback: the way in is the player's first ore and has to exist
## on every seed, so if a landscape claims none of what this lays, the iron goes
## down anyway rather than leaving a world with no seam near its spawn.
static func _seam(c: GenContext, kind: int, at: Vector2, force := false) -> void:
	var x := floori(at.x)
	var y := floori(at.y)
	if x < 0 or y < 0 or x >= c.size or y >= c.size:
		return
	if not force and not _declares_ore(c, c.w.country[y * c.size + x], kind):
		return
	_add(c, kind, at)


## Whether this landscape says this ore is under it. `BiomeDef.ore` is the
## authority on what a place holds (CLAUDE.md: a landscape's own declaration
## outranks the shared list).
static func _declares_ore(c: GenContext, cc: int, kind: int) -> bool:
	if cc < 0 or cc >= c.defs.size():
		return false
	for row: Variant in c.defs[cc].ore:
		var r: Array = row
		if r.size() > 0 and int(r[0]) == kind:
			return true
	return false


## Wrecks on beaches in bays: sited once the grounds exist, on sand with sand
## round it, never on shingle or turf.
static func _wrecks(c: GenContext) -> void:
	var w := c.w
	var size := c.size
	var rng := Rng.make(c.s, 82)
	var level := w.level
	var convex := c.convex
	var inland := c.inland
	var water := c.water
	var road := c.road
	var ground := w.ground
	var country := w.country
	const SAND := Ground.SAND
	var strands := PackedByteArray()
	strands.resize(c.types)
	for cc: int in c.land_types:
		strands[cc] = 1 if c.defs[cc].beached_wrecks else 0
	# Every bay-beach tile with sand all round, found in one pass.
	var band := 12
	var parts: Array[PackedInt32Array] = []
	parts.resize(ceili(float(size) / band))
	GenFields.rows(size - 3, func(y0: int, y1: int) -> void:
		var found := PackedInt32Array()
		for y in range(maxi(y0, 3), y1):
			for x in range(3, size - 3):
				var i := y * size + x
				if ground[i] != SAND or level[i] != 1 or convex[i] < 0.5 or inland[i] > 3.5 or water[i] != 0 or road[i] != 0:
					continue
				if strands[country[i]] == 0:
					continue
				# Hauled up on the sand, not lying in the wash.
				if ground[i - 1] != SAND or ground[i + 1] != SAND or ground[i - size] != SAND or ground[i + size] != SAND:
					continue
				if ground[i - size - 1] != SAND or ground[i - size + 1] != SAND or ground[i + size - 1] != SAND or ground[i + size + 1] != SAND:
					continue
				found.append(i)
		parts[y0 / band] = found
	, band)
	var cands := PackedInt32Array()
	for part in parts:
		cands.append_array(part)
	var wrecks := 0
	var want := maxi(1, roundi(4 * maxf(c.body_k, 0.3)))
	for attempt in mini(400, cands.size() * 2):
		if wrecks >= want:
			break
		var i := cands[rng.randi_range(0, cands.size() - 1)]
		var p := Vector2i(i % size, i / size)
		if _near_landmark(w, Vector2(p), PLACES_APART * maxf(c.body_k, 0.4)) or _near_village(w, Vector2(p), 16.0):
			continue
		_mark(w, &"wreck", Vector2(p) + Vector2(0.5, 0.5), country[i])
		wrecks += 1


static func _add(c: GenContext, kind: int, p: Vector2, rot: float = -1.0) -> WorldProp:
	var w := c.w
	var id := w.props.size()
	var r := rot if rot >= 0.0 else GenFields.h01(c.s, id, kind, 77) * TAU
	var prop := WorldProp.new(id, kind, p, r, 0.8 + GenFields.h01(c.s, id, kind, 78) * 0.4)
	w.props.append(prop)
	return prop


## Mark the tiles a big solid covers so nothing else grows through it.
static func _occupy(c: GenContext, occ: PackedByteArray, p: Vector2, r: float) -> void:
	var ri := ceili(r)
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var x := floori(p.x) + dx
			var y := floori(p.y) + dy
			if x >= 0 and y >= 0 and x < c.size and y < c.size:
				occ[y * c.size + x] = 1


## No river and no still water within `r` of `p`. Kept apart from `_free` because
## it asks a different question over a different radius: what a building STANDS
## on rather than what it is crowded by.
static func _dry_around(c: GenContext, p: Vector2, r: float) -> bool:
	var ri := ceili(r)
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			if Vector2(dx, dy).length() > r:
				continue
			var x := floori(p.x) + dx
			var y := floori(p.y) + dy
			if x < 0 or y < 0 or x >= c.size or y >= c.size:
				continue
			if c.water[y * c.size + x] != 0:
				return false
	return true


static func _free(c: GenContext, occ: PackedByteArray, p: Vector2, r: float) -> bool:
	var ri := ceili(r)
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var x := floori(p.x) + dx
			var y := floori(p.y) + dy
			if x < 1 or y < 1 or x >= c.size - 1 or y >= c.size - 1:
				return false
			var i := y * c.size + x
			if occ[i] != 0 or c.road[i] != 0 or c.land[i] == 0 or c.water[i] != 0:
				return false
	return true


static func _villages(c: GenContext, occ: PackedByteArray) -> void:
	var w := c.w
	var rng := Rng.make(c.s, 29)
	for v in w.villages:
		var vp: Vector2 = v.pos
		# The square: the fire in the middle, the bench drawn up to it, the lamp
		# on the square's edge where the light reaches both. (3, 3) from the
		# centre stays clear: --village=N starts there.
		var fire := _add(c, PropKind.FIRE, vp + Vector2(-0.3, -0.5))
		var bench := _add(c, PropKind.BENCH, fire.pos + Vector2(-1.7, -0.9))
		bench.rot = (fire.pos - bench.pos).angle()
		var lamp_at := vp + Vector2.from_angle(-PI * 0.3) * clampf(GenSettle.square_radius(c, v, -PI * 0.3) - 0.6, 2.4, 3.4)
		_add(c, PropKind.LAMP, lamp_at)
		# What this landscape's people build, and how they stand (`BiomeForms`).
		# The village record already carries its country, so this costs no lookup
		# and no renderer: the form table is core, which is why world gen may read
		# it at all.
		var forms := BiomeForms.of(int(v.get("country", Country.COAST)))
		var streets := forms.plan == &"row" or forms.plan == &"block"
		_occupy(c, occ, vp, STREET_CLEAR if streets else SQUARE_CLEAR)
		_occupy(c, occ, lamp_at, 0.5)
		# How many buildings go up is the LANDSCAPE's to say (`BiomeForms.how_many`).
		# It used to be the stock's own size, one form to each so no two shared a
		# silhouette, which is right for a village and is what a village still gets
		# when it declares nothing.
		var want := forms.how_many()
		var count := rng.randi_range(want.x, want.y)
		var placed := 0
		var start := rng.randf() * TAU
		# A frontage runs on a bearing this village keeps: half a turn, because a
		# street is a line and not a direction.
		var street := Rng.hash01(c.s, floori(vp.x), floori(vp.y), 4203) * PI
		var stride := forms.widest() * 2.0 + 0.4
		# A village deals its houses one model each, so no two silhouettes in it
		# repeat: on seed 7 the hash alone gave the spawn village three of one
		# house and two of another out of seven (art review 5). Dealt AFTER
		# placing, nearest the square first — the ring is filled in a spiral, not
		# in order of distance — so in a village that wired a machine's light in,
		# the lit house is the one a player standing on the square is looking at
		# (art review 11). Only a share of villages did (LIT_SHARE).
		# Its own stream, not the village rng: drawing from that one would shift
		# every house position after it, and `tests/render/test_parity.gd` pins
		# those to the world M1 made. Dealing a model must not move a house.
		var pack := _house_pack(Rng.make(c.s, 4200 + floori(vp.x) * 131 + floori(vp.y)),
			Rng.hash01(c.s, floori(vp.x), floori(vp.y), 4202) < LIT_SHARE, forms)
		var houses: Array[WorldProp] = []
		var row := streets
		# A BLOCK IS A ROW WITH LANES. One street through the square is a village
		# with a street; a city is several of them side by side with frontage on
		# both sides of each, which is the same rule run per lane. `row` is the
		# one-lane case and lays every building exactly where it did, so no world
		# that has a street today moves.
		var lanes := forms.lanes()
		for h in 480:
			if placed >= count:
				break
			var lane := 0
			var hh := h
			if lanes > 1:
				# Lanes are filled in step rather than one after another, so a city
				# that runs out of ground is short on every street instead of
				# having two full ones and a field.
				lane = (h % lanes) - (lanes >> 1)
				hh = h / lanes
			if row and (hh >> 2) > ROW_RANKS:
				# A STREET, not ribbon development. The ring spirals outward until it
				# finds room, which is right for scattered buildings; a frontage that
				# did the same walked off across the island one refused spot at a
				# time — measured, a settlement whose far end stood 150 tiles from
				# its square on ground the level check kept refusing. Past the last
				# rank the settlement is simply smaller, which is what a street on
				# bad ground is.
				break
			var hp := Vector2.ZERO
			# Where this building FACES before the hand that set it down is added.
			# The jitter itself is still drawn after every check below, because the
			# ring's stream is what every seed's village was laid from and a draw
			# made for a candidate that is then refused moves all of them.
			var bearing := 0.0
			if row:
				# A FRONTAGE: two lines either side of a street, filled outward from
				# the square both ways, each building square to the line and hard up
				# against its neighbour. What a player does here is walk THROUGH it,
				# and what stands between them and the camera is the far side of the
				# street — which is the whole reason a landscape gets to say this.
				var along := Vector2.from_angle(street)
				var across := Vector2(-along.y, along.x)
				var side := 1.0 if (hh & 1) == 0 else -1.0
				var way := 1.0 if (hh & 2) == 0 else -1.0
				# The street's own width wanders a little rank by rank, so a frontage
				# whose exact band of ground is broken has somewhere else to stand:
				# every spot in a row is at one fixed offset, and on rough ground
				# that put three buildings on a street with room for six.
				var rank := hh >> 2
				var wobble := 1.0 + (Rng.hash01(c.s, floori(vp.x) + rank, floori(vp.y), 4204) - 0.5) * 0.5
				hp = vp + along * (forms.apart + float(rank) * stride) * way \
					+ across * (float(lane) * forms.block_deep() + side * ROW_STREET * wobble)
				bearing = (across * -side).angle()
			else:
				var a := start + h * 2.39996
				if absf(wrapf(a - PI * 0.25, -PI, PI)) < 0.4:
					continue
				# Inner ring first, spreading out as the good spots are taken.
				var rad := forms.apart + fmod(h * 0.618, 1.0) * 2.8 + h * 0.035
				hp = vp + Vector2.from_angle(a) * rad
				bearing = (vp - hp).angle()
			hp = hp.floor() + Vector2(0.5, 0.5)
			# The player wakes with room around them and the view ahead open.
			var to_spawn := hp - w.spawn
			# Clear of the box a query round the spawn looks in, too.
			if maxf(absf(to_spawn.x), absf(to_spawn.y)) < 5.5 or (to_spawn.length() < 9.0 and to_spawn.normalized().dot(Vector2.from_angle(w.spawn_facing)) > 0.5):
				continue
			if not _free(c, occ, hp, 1.0):
				continue
			var l := w.level_at(floori(hp.x), floori(hp.y))
			var level_ok := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if w.level_at(floori(hp.x) + dx, floori(hp.y) + dy) != l:
						level_ok = false
			if not level_ok:
				continue
			# NO STILL WATER UNDER A BUILDING'S OWN FOOTPRINT. `_free` clears a
			# radius of one, which was the whole of a coastal cottage; a city form
			# stands on 2.4 and `tests/core/test_world_gen_surface.gd` asks for
			# three tiles of dry ground past its `solid`, so a tower could be set
			# down with a bog pool at its door and nothing refused it. It showed as
			# one blackwater beside one house on one seed, which is what a rule
			# that was true for small buildings looks like when buildings grow.
			if not _dry_around(c, hp, forms.widest() + 3.0):
				continue
			var house := _add(c, PropKind.HOUSE, hp)
			houses.append(house)
			# Facing the square, never quite square to it — and on a frontage barely
			# off it at all, because a line of doors pointing every which way is a
			# ring with extra steps. ONE draw either way, so the ring's stream is
			# the stream every seed's village was laid from.
			house.rot = wrapf(bearing + rng.randf_range(-0.2, 0.2) * (0.25 if row else 1.0), 0.0, TAU)
			_occupy(c, occ, hp, forms.room())
			placed += 1
		# HOW FAR THIS SETTLEMENT REACHES IS RECORDED HERE, BECAUSE THIS IS WHAT
		# KNOWS. A ring's furthest house and a street's furthest tower are nine
		# tiles apart and nothing downstream can tell which it is looking at
		# (`WorldData.village_reach` says what that cost).
		var reach := 0.0
		for h2: WorldProp in houses:
			reach = maxf(reach, h2.pos.distance_to(vp) + forms.widest())
		v["reach"] = reach
		houses.sort_custom(func(a: WorldProp, b: WorldProp) -> bool:
			return a.pos.distance_squared_to(vp) < b.pos.distance_squared_to(vp))
		# A village that outgrew the pack would repeat a silhouette, which is the
		# whole thing this deal exists to stop. The modulo keeps it deterministic
		# if it ever happens; the assert is so nobody finds out from a screenshot.
		#
		# A CITY REPEATS ITSELF AND IS NOT WRONG TO. What the rule protects against
		# is two of one silhouette standing next to each other, which reads as a
		# stamp -- not the second one existing at all. A landscape that says how far
		# apart two of a kind must stand (`BiomeForms.repeat_apart`) keeps the
		# protection and gets to be bigger than its own stock.
		if forms.repeats():
			for i in houses.size():
				var pick := -1
				# **AND WHEN NOTHING CLEARS THE BAR, TAKE THE FURTHEST, NOT THE NEXT
				# IN THE CYCLE.** This used to fall back on `pack[i % pack.size()]`,
				# which is the one answer that ignores where the building stands --
				# so a landscape whose bar the deal could not meet got no protection
				# at all rather than the best available. Measured over five seeds:
				# the green towers asked for 20 tiles and the cycle gave it 5.1,
				# which is nearer than its own `apart` and is exactly the two-of-one-
				# silhouette-side-by-side this whole deal exists to stop. The other
				# three cities never noticed because their bars are met outright
				# (the slums 15.0 of 15.0, the machine city 6.0 of 6.0, the drowned
				# city 11.2 of 11.0), so the fallback almost never fired and was
				# wrong in the dark for as long as it existed.
				var best_gap := -1.0
				for t in pack.size():
					var cand: int = pack[(i + t) % pack.size()]
					var nearest := INF
					for j in i:
						if houses[j].variant != cand:
							continue
						nearest = minf(nearest, houses[j].pos.distance_to(houses[i].pos))
					if nearest >= forms.repeat_apart:
						pick = cand
						break
					if nearest > best_gap:
						best_gap = nearest
						pick = cand
				houses[i].variant = pick if pick >= 0 else pack[i % pack.size()]
				# AND THE SECOND OF A KIND IS NOT THE SAME SIZE AS THE FIRST. The
				# distance rule keeps two identical silhouettes from standing
				# together; this is what keeps them from reading as one silhouette
				# twice when both are in the same frame at different depths, which
				# is most of what makes a real skyline out of six shapes.
				var nth := 0
				for j in i:
					if houses[j].variant == houses[i].variant:
						nth += 1
				houses[i].scale = REPEAT_BANDS[nth % REPEAT_BANDS.size()]
		else:
			assert(houses.size() <= pack.size(), "a village placed more houses than there are models")
			for i in houses.size():
				houses[i].variant = pack[i % pack.size()]
		# How much ground a building stands on is its FORM's, not its kind's:
		# a tower is not a croft with more storeys, and a body walking a street
		# has to be stopped by the frontage rather than by a coastal radius.
		# Set only now, because world gen places first and deals afterwards so
		# that the lit one comes out nearest the square; `forms.room()` above
		# already kept the widest of them clear at placing time. Its own pass,
		# because there are two ways to deal a form now and only one answer to
		# what a dealt form stands on.
		for i in houses.size():
			houses[i].solid = forms.reach(houses[i].variant) * houses[i].scale
		# A STREET LIGHTS ITSELF. A square gets one lamp, which is a village's whole
		# public light and is nothing down a frontage that runs nineteen tiles out
		# either way. `PropKind.LAMP` is the strongest source 15_lights has (reach
		# 3.8 at full energy) and a `row` settlement was getting the same ONE, so
		# the city measured 4.9x darker than the coast at noon and its own towers
		# five tiles off did not read. The sky cannot answer that — a lidded
		# landscape takes LID_SUN (0.035) of a sun whatever the hour, so what is
		# left has to come off the ground.
		#
		# They stand at the kerb BETWEEN ranks and change sides as they go, so the
		# light crosses the street rather than running down one gutter, and no
		# stretch of the frontage is left dark between two pools.
		if row:
			var along2 := Vector2.from_angle(street)
			var across2 := Vector2(-along2.y, along2.x)
			for rank2 in ROW_RANKS:
				for way_i in 2:
					var way2 := 1.0 if way_i == 0 else -1.0
					var side2 := 1.0 if ((rank2 + way_i) & 1) == 0 else -1.0
					var lp := vp + along2 * (forms.apart + (float(rank2) + 0.5) * stride) * way2 						+ across2 * (side2 * ROW_STREET * ROW_KERB)
					lp = lp.floor() + Vector2(0.5, 0.5)
					if not _free(c, occ, lp, 0.6):
						continue
					_add(c, PropKind.LAMP, lp)
					_occupy(c, occ, lp, 0.5)
		# AND WHERE YOU STAND IN IT, for the same reason as `reach` above: four
		# callers and two tests each carried their own `vp + Vector2(3, 3)`, which
		# was a clear spot on a village green and is a doorway on a street. The
		# historical offset is tried FIRST and kept whenever it is clear, so every
		# ring village stands exactly where it always did.
		v["stand"] = _standing_spot(c, vp, houses)


## Where a player staged into this settlement stands: clear of every building it
## put up, on ground they could be put down on. `WorldData.STAND_OFFSET` first,
## because that is where every village in this game has started since M1.
static func _standing_spot(c: GenContext, vp: Vector2, houses: Array[WorldProp]) -> Vector2:
	var tries: Array[Vector2] = [WorldData.STAND_OFFSET]
	for ring: float in [4.3, 5.6, 7.0]:
		for i in 12:
			tries.append(Vector2.from_angle(TAU * float(i) / 12.0) * ring)
	for off: Vector2 in tries:
		var p := vp + off
		var x := floori(p.x)
		var y := floori(p.y)
		if x < 1 or y < 1 or x >= c.size - 1 or y >= c.size - 1:
			continue
		var i2 := y * c.size + x
		if c.land[i2] == 0 or c.water[i2] != 0:
			continue
		var clear := true
		for h: WorldProp in houses:
			if h.pos.distance_to(p) <= h.solid + 0.6:
				clear = false
				break
		if clear:
			return p
	return vp + WorldData.STAND_OFFSET


## Half the width of a street, in tiles: how far a frontage stands off the line
## through the square. Five tiles across is wide enough for two bodies to pass
## and narrow enough that the far side is in frame with the near one.
const ROW_STREET := 2.6
## How many buildings deep a frontage runs from the square, each way and each
## side. Four spots to a rank, so three ranks offer twelve — twice the largest
## stock — and the far end still stands inside one frame of the square.
const ROW_RANKS := 3
## How far out from the street's middle a lamp post stands, as a share of the
## street's half width: at the kerb, just inside the frontage it lights.
const ROW_KERB := 0.82
## How much ground the square itself keeps clear of buildings, in tiles. A green
## keeps its whole circle; a street junction keeps only its own furniture, or the
## first rank of the frontage falls inside it and a city has a hole in the middle.
const SQUARE_CLEAR := 2.5
const STREET_CLEAR := 1.1


## How many villages have somebody's stolen light on the square. NOT all of them:
## dealing a lit house to the front of every pack put a neon tube on the nearest
## house of every village on every seed, which is the neon filter this game is
## not (the owner's own correction: neon is a situational accent). A share of
## villages wired one in; the rest are hearths and a lamp post.
## The sizes a repeated form is dealt, in the order it is dealt them. A building
## is `scale`d whole, so a band changes its height, its width and the ground it
## stands on together (`solid` is `reach * scale`) -- which is the point: a second
## stack of another size is another building, not the same one moved.
const REPEAT_BANDS: Array[float] = [1.0, 1.26, 0.84, 1.12, 0.92, 1.34]


const LIT_SHARE := 0.4


## A shuffled pack of one of each house model, so a village deals every house a
## different silhouette. In a village that wired a machine's light in, the lit
## house is on TOP of the pack — dealt nearest the square, where a player
## standing in it is looking. Whichever lit models the village does not want go
## to the BACK, so a village of five or six has no stolen light at all and only
## one big enough to need every model there is shows a second tube, out on its rim.
static func _house_pack(rng: RandomNumberGenerator, lit_village: bool, forms: BiomeForms) -> Array[int]:
	# Which of a landscape's forms wired a machine's light in is its own to say
	# (`BiomeForms.lit`), which is the one place it is written down now: the
	# [1, 4] that stood here and in 15_lights was the coastal village's answer
	# given to every landscape that would ever exist.
	var neon := forms.lit()
	var rest: Array[int] = []
	for v: int in range(forms.stock.size()):
		rest.append(v)
	for i in range(rest.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = rest[i]
		rest[i] = rest[j]
		rest[j] = t
	if neon.is_empty():
		return rest
	var lit: int = neon[rng.randi_range(0, neon.size() - 1)]
	var tail: Array[int] = []
	for v: int in rest:
		if neon.has(v) and (v != lit or not lit_village):
			tail.append(v)
	for v: int in tail:
		rest.erase(v)
		rest.push_back(v)
	if lit_village:
		rest.erase(lit)
		rest.push_front(lit)
	return rest


static func _landmarks(c: GenContext, occ: PackedByteArray) -> void:
	var w := c.w
	var rng := Rng.make(c.s, 83)
	for m in w.landmarks:
		var p: Vector2 = m.pos
		match m.kind:
			&"tip":
				var heaps := rng.randi_range(3, 6)
				for h in heaps:
					var q := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 4.0)
					q = q.floor() + Vector2(0.5, 0.5)
					if _free(c, occ, q, 1.0):
						_add(c, PropKind.TIP, q + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)))
						_occupy(c, occ, q, 1.0)
				var wq := p + Vector2(3, -2)
				var wg := c.w.ground_at(floori(wq.x), floori(wq.y))
				if rng.randf() < 0.5 and (wg == Ground.GRAVEL or wg == Ground.CLINKER) and _free(c, occ, wq, 1.3):
					_add(c, PropKind.WRECK, wq)
					_occupy(c, occ, wq, 1.5)
			&"stone_circle":
				var stones := rng.randi_range(7, 9)
				var radius := rng.randf_range(3.2, 4.2)
				# A STONE STANDS IN ITS OWN CIRCLE'S LANDSCAPE. The centre is held
				# to its region and to `blend`, but a stone is laid three or four
				# tiles out from it, which is far enough to be over a border — and
				# once there are several circles in a region instead of one or two
				# for the whole island, one of them lands near an edge. The failure
				# reads "standing stone on the Coast", which is a landscape holding
				# somebody else's monument.
				var mine: int = int(m.get("country", -1))
				for k in stones:
					var q := p + Vector2.from_angle(float(k) / stones * TAU + rng.randf_range(-0.12, 0.12)) * radius
					if mine >= 0 and c.w.country_at(floori(q.x), floori(q.y)) != mine:
						continue
					if _free(c, occ, q, 0.0):
						var st := _add(c, PropKind.STANDING_STONE, q)
						st.rot = (p - q).angle()
						_occupy(c, occ, q, 0.6)
				if rng.randf() < 0.6:
					_add(c, PropKind.CAIRN, p)
				_occupy(c, occ, p, 1.0)
			&"wreck":
				if _free(c, occ, p, 1.0):
					var wr := _add(c, PropKind.WRECK, p)
					wr.rot = rng.randf() * TAU
					_occupy(c, occ, p, 1.6)
				for k in 4:
					var q := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 4.5)
					if _free(c, occ, q, 0.0):
						_add(c, PropKind.DRIFTWOOD, q)
			&"ruin":
				var walls := rng.randi_range(2, 4)
				for k in walls:
					var q := p + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
					if _free(c, occ, q, 0.6):
						_add(c, PropKind.RUIN, q.floor() + Vector2(0.5, 0.5), roundf(rng.randf() * 4.0) * PI * 0.5)
						_occupy(c, occ, q, 0.8)
				if c.defs[int(m.country)].scorched:
					# The steading's orchard stands burnt round it.
					for k in rng.randi_range(4, 7):
						var q := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(3.5, 6.5)
						if _free(c, occ, q, 0.3):
							_add(c, PropKind.DEAD_TREE, q)
							_occupy(c, occ, q, 0.4)
			&"fumarole":
				# Vents breathe in a loose ring, boulders thrown out round them.
				var vents := rng.randi_range(5, 8)
				for k in vents:
					var q := p + Vector2.from_angle(float(k) / vents * TAU + rng.randf_range(-0.3, 0.3)) * rng.randf_range(1.2, 3.6)
					if _free(c, occ, q, 0.4):
						_add(c, PropKind.VENT, q)
						_occupy(c, occ, q, 0.6)
				for k in rng.randi_range(3, 6):
					var q := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.5, 7.0)
					if _free(c, occ, q, 0.4):
						_add(c, PropKind.BOULDER, q)
						_occupy(c, occ, q, 0.6)
			&"summit":
				if _free(c, occ, p, 0.0):
					_add(c, PropKind.CAIRN, p)
					_occupy(c, occ, p, 1.0)
	# Kilns, only by villages, on the ground the landscape names for them (dune
	# sand behind the coast's bays, pavement on the Bonelands). Never on a beach.
	for v in w.villages:
		var cc: int = v.country
		var want := int(c.defs[cc].sites.get("kiln_ground", -1))
		if want < 0:
			continue
		var vp: Vector2 = v.pos
		var done := false
		for rad in range(11, 36, 2):
			if done:
				break
			for a in 16:
				var q := (vp + Vector2.from_angle(a / 16.0 * TAU + rad) * rad).floor() + Vector2(0.5, 0.5)
				if q.x < 1.0 or q.y < 1.0 or q.x >= c.size - 1 or q.y >= c.size - 1:
					continue
				var qi := floori(q.y) * c.size + floori(q.x)
				if want == Ground.SAND and (c.sea_steps[qi] < 3 or w.ground[qi - 1] != want or w.ground[qi + 1] != want):
					continue
				if (q - w.spawn).length() < 7.0:
					continue
				if w.ground_at(floori(q.x), floori(q.y)) == want and _free(c, occ, q, 1.0):
					_add(c, PropKind.KILN, q)
					_occupy(c, occ, q, 1.2)
					done = true
					break


static func _lines(c: GenContext, occ: PackedByteArray) -> void:
	var w := c.w
	var rng := Rng.make(c.s, 91)
	var size := float(c.size)
	var centre := c.land_rect.get_center()
	# Two pylon lines crossing the island, two pole lines, then spurs.
	# Offsets (fractions of the island's half-diagonal) sit in separate bands so
	# the lines stride across different country rather than meeting in a star.
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var specs: Array[Vector3] = [
		Vector3(PropKind.PYLON, PI * 0.5 + rng.randf_range(-0.35, 0.35), side * rng.randf_range(0.12, 0.3)),
		Vector3(PropKind.PYLON, rng.randf_range(-0.4, 0.4), rng.randf_range(-0.28, -0.08)),
		Vector3(PropKind.POLE, PI * 0.5 + rng.randf_range(-0.3, 0.3), -side * rng.randf_range(0.2, 0.4)),
		Vector3(PropKind.POLE, rng.randf_range(-0.3, 0.3), rng.randf_range(0.15, 0.32)),
	]
	for spec in specs:
		var kind := int(spec.x)
		var dir := Vector2.from_angle(spec.y)
		var nrm := Vector2(-dir.y, dir.x)
		var through := centre + nrm * spec.z * c.land_rect.size.length() * 0.5
		var a := through - dir * size * 1.5
		var b := through + dir * size * 1.5
		_string_line(c, occ, kind, a, b, 13.0 if kind == PropKind.PYLON else 7.0)
	# Every village with a line within reach gets a pole spur to its square.
	for v in w.villages:
		var vp: Vector2 = v.pos + Vector2(-3.5, 3.5)
		var best := Vector2.ZERO
		var best_d := 90.0 * maxf(c.body_k, 0.4)
		for line in w.lines:
			for id: int in line.props:
				var d := w.props[id].pos.distance_to(vp)
				if d < best_d and d > 8.0:
					best_d = d
					best = w.props[id].pos
		if best != Vector2.ZERO:
			_string_line(c, occ, PropKind.POLE, vp, best, 6.0)


## Walk a straight line, standing a mast every `spacing` tiles on dry land.
## A gap over water or through a village starts a new line record.
static func _string_line(c: GenContext, occ: PackedByteArray, kind: int, a: Vector2, b: Vector2, spacing: float) -> void:
	var w := c.w
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var ids := PackedInt32Array()
	var missed := 0
	var t := 0.0
	while t <= length:
		var p := a + dir * t
		t += spacing
		var tx := floori(p.x)
		var ty := floori(p.y)
		if tx < 2 or ty < 2 or tx >= c.size - 2 or ty >= c.size - 2:
			continue
		var placed := false
		# Nudge along the line up to a couple of tiles to find footing.
		for nudge: float in [0.0, 1.5, -1.5, 3.0]:
			var q := (p + dir * nudge).floor() + Vector2(0.5, 0.5)
			if q.x < 2.0 or q.y < 2.0 or q.x >= c.size - 2 or q.y >= c.size - 2:
				continue
			var i := floori(q.y) * c.size + floori(q.x)
			if c.land[i] == 0 or c.water[i] != 0 or c.road[i] != 0 or c.village[i] != 0 or occ[i] != 0:
				continue
			var to_spawn := q - w.spawn
			if to_spawn.length_squared() < 16.0 or (to_spawn.length_squared() < 81.0 and to_spawn.normalized().dot(Vector2.from_angle(w.spawn_facing)) > 0.5):
				continue
			var prop := _add(c, kind, q)
			prop.rot = dir.angle()
			_occupy(c, occ, q, 0.0)
			ids.append(prop.id)
			placed = true
			break
		if placed:
			missed = 0
		else:
			missed += 1
			if missed >= 2 and ids.size() >= 2:
				w.lines.append({"kind": kind, "props": ids})
				ids = PackedInt32Array()
			elif missed >= 2:
				ids.clear()
	if ids.size() >= 2:
		w.lines.append({"kind": kind, "props": ids})


static func _scatter(c: GenContext, occ: PackedByteArray) -> void:
	var w := c.w
	var size := c.size
	var s := c.s & 0xFFFFFFFF
	var forest := c.forest
	var rise := c.rise
	var recipe := c.recipe
	var fl := GenFields.batch(size, [
		[GenFields.FIELD, GenFields.noise(c.s, 611, 1.0 / 11.0, 2), 2],
		[GenFields.NOISE, GenFields.noise(c.s, 612, 1.0 / 26.0, 2), size, 1],
	])
	var clump := fl[0]
	var fissure := fl[1]
	var sp := w.spawn
	var face := Vector2.from_angle(w.spawn_facing)
	var land := c.land
	var water := c.water
	var road := c.road
	var village := c.village
	var ground := w.ground
	var level := w.level
	var country := w.country
	var country2 := w.country2
	var blend := w.blend
	var sea_steps := c.sea_steps
	var allow_mask := allow(c)
	var defs := c.defs
	var recipes: Array[Callable] = []
	for d: BiomeDef in defs:
		recipes.append(d.scatter)
	# The highest roll any branch below can use on each ground: most rolls
	# are thrown away before any other work.
	var reach := PackedFloat32Array()
	reach.resize(Ground.COUNT)
	reach.fill(0.3)
	for g: int in [Ground.NEEDLES, Ground.LIMESTONE, Ground.MUD, Ground.ASH, Ground.CLINKER, Ground.SWARF]:
		reach[g] = 0.5
	for g: int in [Ground.SNOW, Ground.GRASS, Ground.HEATH]:
		reach[g] = 0.4
	for g: int in [Ground.BONE, Ground.GRAVEL, Ground.SAND, Ground.SHINGLE, Ground.SALT, Ground.PAN]:
		reach[g] = 0.25
	var solid := PropKind.SOLID
	var band := 12
	var parts: Array[PackedFloat32Array] = []
	parts.resize(ceili(float(size) / band))
	# Candidates are found in parallel, one list per band, and added in row
	# order: prop ids come out the same however the bands were scheduled.
	GenFields.rows(size - 2, func(y0: int, y1: int) -> void:
		var found := PackedFloat32Array()
		var t := BiomeScatter.new()
		# The types in play and the recipe change only where the land does:
		# hand them over when they change, not once a tile.
		var last_recipe := -1
		var last_own := -1
		var last_other := -1
		var recipe_fn := recipes[0]
		t.size = size
		t.clump = clump
		t.fissure = fissure
		t.forest = forest
		t.rise = rise
		t.grounds = ground
		t.sea_steps = sea_steps
		t.levels = level
		t.blends = blend
		for y in range(maxi(y0, 2), y1):
			var row := y * size
			for x in range(2, size - 2):
				var h := (x * 0x27d4eb2d + y * 0x165667b1 + s * 0x9e3779b1) & 0xFFFFFFFF
				h = ((h ^ (h >> 15)) * 0x2c1b3c6d) & 0xFFFFFFFF
				h = ((h ^ (h >> 12)) * 0x297a2d39) & 0xFFFFFFFF
				h ^= h >> 15
				var r := (h & 0xFFFF) / 65536.0
				var i := row + x
				var g := ground[i]
				if r > reach[g] or land[i] == 0 or water[i] != 0 or road[i] != 0 or village[i] != 0 or occ[i] != 0:
					continue
				var own := country[i]
				# The same island its ground came from.
				var cc := recipe[i]
				var l := level[i]
				# Nothing per-tile is written to the sample: see its header.
				var up := maxi(maxi(level[i - 1], level[i + 1]), maxi(level[i - size], level[i + size])) - l
				var wet := water[i - 1] != 0 or water[i + 1] != 0 or water[i - size] != 0 or water[i + size] != 0
				if cc != last_recipe:
					last_recipe = cc
					t.def = defs[cc]
					recipe_fn = recipes[cc]
				if own != last_own:
					last_own = own
					t.own_def = defs[own]
				var c2 := country2[i]
				if c2 != last_other:
					last_other = c2
					t.other_def = defs[c2]
				# What the land decides, then the landscape's own recipe, then
				# the grounds every landscape reads the same way.
				var kind := BiomeScatter.PASS
				if up >= 2 or wet:
					kind = BiomeScatter.first(t, g, r, up, wet)
				if kind == BiomeScatter.PASS and recipe_fn.is_valid():
					# A TYPE MAY DECLARE NO RECIPE, and one of the shipped types does
					# not: the SEA, which holds index 0 and is not a landscape you
					# walk. `recipe[i]` is the island a tile's ground came from, and
					# a worldgen change that leaves one land tile's at 0 calls an
					# invalid Callable and takes the whole scatter stage down —
					# reported as a bare "script error" with no tile, no seed and no
					# landscape named. Adding a landscape moves every island, so this
					# is a trap laid for exactly the wave that adds them; it was hit
					# on the first try. A type with no recipe falls through to the
					# shared table, which is what having no recipe means.
					kind = recipe_fn.call(t, i, g, r)
				if kind == BiomeScatter.PASS:
					kind = BiomeScatter.shared(t, i, g, r)
				if kind < 0 or (allow_mask[own] >> kind) & 1 == 0:
					continue
				if (road[i - 1] != 0 or road[i + 1] != 0 or road[i - size] != 0 or road[i + size] != 0) and solid[kind] > 0.0:
					continue
				var p := Vector2(x + 0.2 + ((h >> 24) & 0xFF) / 425.0, y + 0.2 + ((h >> 8) & 0xFF) / 425.0)
				if solid[kind] > 0.0:
					var to := p - sp
					if to.length_squared() < 9.0 or (to.length_squared() < 64.0 and to.normalized().dot(face) > 0.6):
						continue
				found.append(kind)
				found.append(p.x)
				found.append(p.y)
		parts[y0 / band] = found
	, band)
	for part in parts:
		for j in range(0, part.size(), 3):
			_add(c, int(part[j]), Vector2(part[j + 1], part[j + 2]))
