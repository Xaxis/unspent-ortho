class_name RealmWorlds
## The worlds a game is made of, one per realm, grown from the one seed
## (docs/VISION.md). A realm's world is raised ONCE per game and kept, so
## walking back up a shaft is instant and the land is the land you left.
##
##   RealmWorlds.begin(seed, size, kind)   start raising it, on a worker
##   RealmWorlds.ready(seed, size, kind)   is it up yet
##   RealmWorlds.take(seed, size, kind)    the world, raised now if it is not
##   RealmWorlds.keep(world)               hand it the world a game already has
##
## A shaft is visible from a long way off, so the realm behind it is begun while
## the player is still walking toward it (20_realms.WARM) and is almost always
## standing by the time they press `use`. `take` is the honest fallback: it raises
## the world on the calling thread, which costs a player one held frame instead of
## a shaft that will not open.
##
## Not pure — it starts tasks — but it holds no nodes and nothing about a running
## game, so a test can raise a realm and read it.

static var _mutex := Mutex.new()
## key -> WorldData, and key -> task id while one is in flight.
static var _worlds: Dictionary = {}
static var _tasks: Dictionary = {}


static func key_of(seed_value: int, size: int, kind: StringName) -> String:
	return "%d:%d:%s" % [seed_value, size, kind]


## Hand it a world a game already has (the one it started in), so that realm is
## never raised twice.
static func keep(w: WorldData) -> void:
	if w == null:
		return
	_mutex.lock()
	_worlds[key_of(w.seed_value, w.size, w.realm)] = w
	_mutex.unlock()


## Start raising the world of `kind` if nothing is holding or raising it. True
## when it is already up.
static func begin(seed_value: int, size: int, kind: StringName) -> bool:
	var key := key_of(seed_value, size, kind)
	_mutex.lock()
	var have: bool = _worlds.has(key)
	var going: bool = _tasks.has(key)
	_mutex.unlock()
	if have:
		return true
	if going:
		return false
	if not BootPage.has_threads():
		# No pool to raise it on (the no-threads web build): it is raised where it
		# is asked for, which is the one frame the shaft costs there.
		return false
	var task := WorkerThreadPool.add_task(func() -> void: _raise(key, seed_value, size, kind),
		true, "realm %s" % kind)
	_mutex.lock()
	_tasks[key] = task
	_mutex.unlock()
	return false


static func ready(seed_value: int, size: int, kind: StringName) -> bool:
	var key := key_of(seed_value, size, kind)
	_mutex.lock()
	var have: bool = _worlds.has(key)
	_mutex.unlock()
	return have


## The world of `kind`, waiting for a task that is raising it, or raising it here
## and now. Never null.
static func take(seed_value: int, size: int, kind: StringName) -> WorldData:
	var key := key_of(seed_value, size, kind)
	_mutex.lock()
	var w: WorldData = _worlds.get(key)
	var task: Variant = _tasks.get(key)
	_mutex.unlock()
	if w != null:
		return w
	if task != null:
		WorkerThreadPool.wait_for_task_completion(int(task))
		_mutex.lock()
		w = _worlds.get(key)
		_tasks.erase(key)
		_mutex.unlock()
		if w != null:
			return w
	_raise(key, seed_value, size, kind)
	_mutex.lock()
	w = _worlds.get(key)
	_mutex.unlock()
	return w


## Every realm this game has raised, by kind.
static func raised() -> Array[StringName]:
	var out: Array[StringName] = []
	_mutex.lock()
	var keys: Array = _worlds.keys()
	_mutex.unlock()
	for k: String in keys:
		var kind := StringName(k.get_slice(":", 2))
		if not out.has(kind):
			out.append(kind)
	return out


## Let go of every world. A game that ends calls this: two 512-tile worlds are
## a dozen megabytes, and the next game's realms are not these ones.
static func forget() -> void:
	_mutex.lock()
	var tasks: Array = _tasks.values()
	_tasks.clear()
	_mutex.unlock()
	for t: int in tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	_mutex.lock()
	_worlds.clear()
	_mutex.unlock()
	Portals.forget()


static func _raise(key: String, seed_value: int, size: int, kind: StringName) -> void:
	var w := BootWorld.world(Realm.seed_for(seed_value, kind), size, kind)
	_mutex.lock()
	# Whoever got here first wins: `take` may have raised it while a task ran.
	if not _worlds.has(key):
		_worlds[key] = w
	_mutex.unlock()
