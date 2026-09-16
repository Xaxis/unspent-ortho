class_name DevPlay
## Starting a game from dev mode: a configuration played, a note restaged. Like
## every start it goes through the loading page (BootPage.open_game), in place
## of whatever scene is up (a game or the title). A game dev mode starts keeps its
## saves in user://dev-saves/<name>, apart from the player's, so trying something
## never writes over the autosave a player would Continue.

const SAVES := "dev-saves"

## Where saves lived before dev mode started a game ("" while none is dev-started).
static var _root_before := ""


## Saves back where they were: a start that dev mode did not make (the title
## opening, New game, Continue) is the player's again. DevTitle calls it.
static func restore_saves() -> void:
	if _root_before != "":
		SaveSlots.root = _root_before
		_root_before = ""


## A game dev mode started is still the one up (its saves are kept apart).
static func dev_started() -> bool:
	return _root_before != ""


## A new game as the active configuration says, on its island.
static func config(scene: Node) -> void:
	var o := BootOptions.new()
	GameConfig.fill_boot(o)
	GameConfig.fill_new_game(o)
	start(scene, o, GameConfig.active if GameConfig.active != "" else "none")


## A game at a note's moment.
static func note(scene: Node, n: Dictionary) -> void:
	start(scene, DevNotes.restage(n), "notes")


## Replaces `scene` after the frame: the call comes from a page inside it.
static func start(scene: Node, o: BootOptions, saves: String) -> void:
	if scene == null or scene.get_parent() == null:
		return
	if _root_before == "":
		_root_before = SaveSlots.root
	# A tool run's dev games stay among the tools' saves, never the owner's.
	SaveSlots.root = ("user://tool-saves" if DevMode.tool_run else "user://").path_join(SAVES).path_join(saves)
	DevMode.touched = true
	_replace.call_deferred(scene, o)


static func _replace(scene: Node, o: BootOptions) -> void:
	if not is_instance_valid(scene) or scene.get_parent() == null:
		return
	var parent := scene.get_parent()
	scene.get_tree().paused = false
	parent.remove_child(scene)
	scene.queue_free()
	BootPage.open_game(parent, o)
