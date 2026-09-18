extends RefCounted
## Games and slot folders for the save tests.
##   const Sx := preload("res://tests/save/save_fixture.gd")
##   Sx.use_root("round-trip")          # SaveSlots.root = user://test-saves/round-trip, emptied
##   var g := Sx.game(tree, ["--seed=1", "--size=64"])
##   Sx.system(g, "05_save")
##   Sx.end(g)                          # out of the tree and freed: the registry clears
##   Sx.finish()                        # emptied, and SaveSlots.root back to TEST_ROOT


static func use_root(name: String) -> String:
	# The SHARD's test root, never the literal: this fixture is where most save
	# tests write, so a hard-coded "user://test-saves" here leaves three gate
	# shards sharing one folder even after SaveSlots stopped doing so.
	SaveSlots.root = SaveSlots.test_root.path_join(name)
	forget()
	wipe()
	return SaveSlots.root


## Empty the folder and point SaveSlots back at the runner's own, where tests
## outside tests/save read an empty set of slots.
static func finish() -> void:
	wipe()
	forget()
	SaveSlots.root = SaveSlots.test_root


## What one game's refusal left standing for the next (SaveSlots.turn_away lives
## as long as the process): no test inherits another's.
static func forget() -> void:
	SaveSlots.turned_away.clear()
	SaveSlots.handed_back = -1


static func wipe() -> void:
	var dir := DirAccess.open(SaveSlots.root)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)


static func game(tree: SceneTree, args: Array, o: BootOptions = null) -> Game:
	if o == null:
		o = BootOptions.parse(PackedStringArray(args))
	var g := Game.new()
	g.name = "game"
	tree.root.add_child(g)
	g.setup(o)
	return g


static func system(g: Game, n: String) -> Node:
	for s in g.systems:
		if s.name == n:
			return s
	return null


static func end(g: Game) -> void:
	if not is_instance_valid(g):
		return
	if g.get_parent() != null:
		g.get_parent().remove_child(g)
	g.free()
