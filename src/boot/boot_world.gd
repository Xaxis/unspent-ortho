class_name BootWorld
## Hand-over of the slow parts of a world from the loading page to the scene
## that shows it. The page makes a world and its view ahead (on a worker, or in
## steps without threads) and offers them; the scene asks for its world here
## instead of generating one, and gets the offered one when it matches, or a
## fresh one made now. Thread-safe: the title asks from a worker.
##
## Contract for anything that starts a world (Game, the title):
##   world = BootWorld.world(seed, size)     # never WorldGen.generate directly
##   view = BootWorld.view(world)            # set up; add it to the tree yourself

static var _mutex := Mutex.new()
static var _world: WorldData
static var _view: WorldView


## The offered world for (seed, size), taken, or a new one generated now.
static func world(seed_value: int, size: int) -> WorldData:
	_mutex.lock()
	var w := _world
	if w != null and w.seed_value == seed_value and w.size == size:
		_world = null
	else:
		w = null
	_mutex.unlock()
	if w == null:
		w = WorldGen.generate(seed_value, size)
	return w


## The offered view of `w`, taken, or a new view of it set up now.
static func view(w: WorldData) -> WorldView:
	_mutex.lock()
	var v := _view
	if v != null and v.world == w:
		_view = null
	else:
		v = null
	_mutex.unlock()
	if v == null:
		v = WorldView.new()
		v.setup(w)
	return v


## Offer a world and (optionally) its set-up view to the next scene that asks.
## Anything offered before and never taken is dropped.
static func offer(w: WorldData, v: WorldView = null) -> void:
	_mutex.lock()
	var old := _view
	_world = w
	_view = v
	_mutex.unlock()
	if old != null and old != v and not old.is_inside_tree():
		old.free()


## True while a world is on offer (tests, the page).
static func offered() -> bool:
	_mutex.lock()
	var yes := _world != null
	_mutex.unlock()
	return yes


static func clear() -> void:
	offer(null, null)


## Where a game started with `o` puts the player (the same rule as Game.setup),
## so the page can draw the first view round it before the game exists.
static func start_of(w: WorldData, o: BootOptions) -> Vector2:
	if o.village >= 0 and o.village < w.villages.size():
		return (w.villages[o.village].pos as Vector2) + Vector2(3, 3)
	if o.at.x >= 0:
		return o.at
	if o.place != "" and GenPlaces.find(w, o.place).x >= 0:
		return GenPlaces.find(w, o.place)
	return w.spawn


## A field sketch of `w` for the loading page, `px` pixels square, north up: the
## coast in pale ink, every fourth terrace as a fainter contour, rivers as dots,
## the machines' grid ruled straight across it all, villages as warm specks.
## `inks` holds coast, contour, river, grid, village. Transparent elsewhere. Pure
## (runs on a worker).
static func sketch(w: WorldData, px: int, inks: Dictionary) -> Image:
	var coast: Color = inks.coast
	var contour: Color = inks.contour
	var river: Color = inks.river
	var img := Image.create_empty(px, px, false, Image.FORMAT_RGBA8)
	var n := w.size
	var band := PackedInt32Array()
	band.resize(px * px)
	for y in px:
		for x in px:
			var l := w.level_at(mini(n - 1, int((x + 0.5) * n / px)), mini(n - 1, int((y + 0.5) * n / px)))
			band[y * px + x] = -1 if l <= 0 else l / 4
	for y in range(1, px - 1):
		for x in range(1, px - 1):
			var b := band[y * px + x]
			if b < 0:
				continue
			var lowest := mini(mini(band[y * px + x - 1], band[y * px + x + 1]), mini(band[(y - 1) * px + x], band[(y + 1) * px + x]))
			if lowest < 0:
				img.set_pixel(x, y, coast)
			elif lowest < b:
				img.set_pixel(x, y, contour)
	for r: PackedVector2Array in w.rivers:
		for i in range(0, r.size(), 3):
			var q := Vector2i((r[i] * px / float(n)).floor())
			if q.x > 0 and q.y > 0 and q.x < px - 1 and q.y < px - 1 and img.get_pixelv(q).a == 0.0:
				img.set_pixelv(q, river)
	var scale := px / float(n)
	for line: Dictionary in w.lines:
		var ids: PackedInt32Array = PackedInt32Array(line.get("props", []))
		for j in ids.size() - 1:
			if ids[j] < 0 or ids[j + 1] < 0 or ids[j] >= w.props.size() or ids[j + 1] >= w.props.size():
				continue
			var a := w.props[ids[j]].pos * scale
			var b := w.props[ids[j + 1]].pos * scale
			var steps := maxi(1, ceili(a.distance_to(b)))
			for k in steps + 1:
				var q := Vector2i(a.lerp(b, k / float(steps)).floor())
				if q.x >= 0 and q.y >= 0 and q.x < px and q.y < px:
					img.set_pixelv(q, inks.grid)
	for v: Dictionary in w.villages:
		var q := Vector2i(((v.pos as Vector2) * scale).floor())
		for d: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT]:
			if q.x + d.x < px and q.y < px:
				img.set_pixelv(q + d, inks.village)
	return img


## Build one chunk of the first view round `p` that is not built yet, on this
## thread (it adds nodes to `v`, which need not be in the tree). Returns how many
## are still missing, so a page can build one per frame and draw between them.
static func build_near(v: WorldView, p: Vector2) -> int:
	v.focus = p
	var missing := v.pending()
	if missing == 0:
		return 0
	for key: Vector2i in v._wanted(0.0):
		if v.chunk_at(Vector2(key * WorldView.CHUNK) + Vector2.ONE) == null:
			v._build(key)
			return missing - 1
	return 0
