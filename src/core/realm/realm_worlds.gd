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
## key -> WorldData, and key -> GROUP task id while one is in flight.
static var _worlds: Dictionary = {}
static var _tasks: Dictionary = {}
## Raises a game that ended left running. A task cannot be stopped, so `forget`
## lets go of it instead of waiting: it finishes on its one worker and what it
## makes is thrown away (`_gen`). While one is still running no new raise is
## begun, so at most one ever runs -- a game shut down three frames in used to
## wait out a whole single-worker world (34 s here, over 45 min of CI in all).
static var _orphans: Array[int] = []
static var _gen := 0


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
	if _orphan_running():
		# An ended game's raise still holds its worker; `take` will raise this one
		# where it is wanted if nothing else does first.
		return false
	if not BootPage.has_threads():
		# No pool to raise it on (the no-threads web build): it is raised where it
		# is asked for, which is the one frame the shaft costs there.
		return false
	# A GROUP OF ONE, AT LOW PRIORITY, so the raise takes one worker and leaves
	# the rest to the game. As a plain task every stage of it fanned out over
	# every worker at high priority (`GenFields.parallel`), and it runs for
	# twenty seconds of play: a job the renderer waits on inside the draw queued
	# behind it for up to 5.3 s, which on seed 7 was one frame of 4.6-5.2 s the
	# first time the camera came down over the shoulder. Inside a group,
	# `parallel` runs inline -- the path a four-thread machine already takes --
	# so the world is the same world; measured, it takes 33-35 s instead of 21
	# (tests/realm/test_raise_in_background.gd).
	var gen := _gen
	var task := WorkerThreadPool.add_group_task(func(_i: int) -> void: _raise(key, seed_value, size, kind, gen),
		1, 1, false, "realm %s" % kind)
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
		WorkerThreadPool.wait_for_group_task_completion(int(task))
		_mutex.lock()
		w = _worlds.get(key)
		_tasks.erase(key)
		_mutex.unlock()
		if w != null:
			return w
	_raise(key, seed_value, size, kind, _gen)
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
	for t: int in _tasks.values():
		_orphans.append(t)
	_tasks.clear()
	_worlds.clear()
	_gen += 1
	_mutex.unlock()
	Portals.forget()


static func _raise(key: String, seed_value: int, size: int, kind: StringName, gen: int) -> void:
	var w := BootWorld.world(Realm.seed_for(seed_value, kind), size, kind)
	_mutex.lock()
	# A raise begun for a game that has since ended is not this game's world.
	# Whoever got here first wins: `take` may have raised it while a task ran.
	if gen == _gen and not _worlds.has(key):
		_worlds[key] = w
	_mutex.unlock()


## Wait out any raise an ended game left running, for a test that must begin its
## own. A game never calls this: that wait is what `forget` exists to avoid.
static func settle() -> void:
	_mutex.lock()
	var all: Array[int] = _orphans.duplicate()
	_orphans.clear()
	_mutex.unlock()
	for t: int in all:
		WorkerThreadPool.wait_for_group_task_completion(t)


## Whether an ended game's raise is still running. Collects the ones that ended.
static func _orphan_running() -> bool:
	_mutex.lock()
	var left: Array[int] = []
	for t: int in _orphans:
		if WorkerThreadPool.is_group_task_completed(t):
			WorkerThreadPool.wait_for_group_task_completion(t)
		else:
			left.append(t)
	_orphans = left
	var running := not _orphans.is_empty()
	_mutex.unlock()
	return running
