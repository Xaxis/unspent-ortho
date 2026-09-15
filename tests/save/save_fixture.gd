extends RefCounted
## Games and slot folders for the save tests.
##   const Sx := preload("res://tests/save/save_fixture.gd")
##   Sx.use_root("round-trip")          # SaveSlots.root = user://test-saves/round-trip, emptied
##   var g := Sx.game(tree, ["--seed=1", "--size=64"])
##   Sx.system(g, "05_save")
##   Sx.end(g)                          # out of the tree and freed: the registry clears
##   Sx.finish()                        # emptied, and SaveSlots.root back to TEST_ROOT


static func use_root(name: String) -> String:
	SaveSlots.root = "user://test-saves".path_join(name)
	wipe()
	return SaveSlots.root


## Empty the folder and point SaveSlots back at the runner's own, where tests
## outside tests/save read an empty set of slots.
static func finish() -> void:
	wipe()
	SaveSlots.root = SaveSlots.TEST_ROOT


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
