extends GameSystem
## Saving and loading the running game.
##   - registers the core state (SaveCore) first, so every later system's
##     SaveGame.register lands after it and is applied after it
##   - a game booted with a slot (--load=N, Continue, Load) is applied in started(),
##     after every setup and before the first frame; the world was generated from
##     the save's seed with the first chunks drawn where the save stood
##   - autosaves to slot 0 on sleep, on coming into another landscape and every
##     three world hours, never while a fight is on (AutosaveRules)
##   - an autosave also waits while any page is open (the map, carrying and making
##     do not pause the world), and for a few frames after the last closes, so its
##     picture is the world and never a page
##   - keeps play time, and a thumbnail of the world: taken when the first page
##     opens (the frame before the page is drawn) for saves made from a page, and
##     at the moment of an autosave
## Screens reach it through the game's systems by name (UiSavesScreen):
##   save_to(slot) -> String    "" or why not
##   load_from(slot) -> String  "" (the game is replaced next frame) or why not
## Once a load is on its way this game takes no more saves or loads.

signal wrote(slot: int, reason: StringName)

const THUMB := Vector2i(160, 90)
## Frames drawn with no page open before an autosave takes its picture: the
## frame a page closes on still shows the page.
const CLEAR_FRAMES := 3

var rules: AutosaveRules
var play_seconds := 0.0
## The slot this game was loaded from, or -1.
var loaded_from := -1
## The world with no page over it, taken as the first page opened.
var _world_thumb := PackedByteArray()
## Frames in a row with no page open.
var _clear_frames := 0
var _forced_weather := false
## A load is on its way: this game is about to give way.
var _loading := false
## The landscapes a loaded game had entered, until the rules exist to hold them.
var _lands: Array = []


func setup(g: Game) -> void:
	super.setup(g)
	# A game that ended without clearing (a test that freed it) leaves dead entries.
	SaveGame.forget_invalid()
	SaveCore.register(g)
	SaveGame.register(&"play", _save_play, _load_play)
	Events.time_skipped.connect(_on_time_skipped)
	Events.screen_changed.connect(_on_screen_changed)


func started() -> void:
	SaveCore.mark_base(game)
	var slot := game.options.load_slot
	if slot >= 0:
		var r := SaveFile.read(SaveSlots.path(slot))
		if r.ok:
			SaveGame.apply(r.data)
			loaded_from = slot
			_forced_weather = Weather.forced_kind != &""
		else:
			push_warning("save: slot %d: %s" % [slot, r.why])
			Events.message.emit(r.why)
	rules = AutosaveRules.new(game.clock.minutes, _land())
	rules.enter_all(_lands)


## Play time, and the landscapes come into (each asks for an autosave once a
## game), the one underfoot among them: the loaded game starts in it.
func _save_play() -> Variant:
	var lands: Array = rules.entered_list() if rules != null else _lands.duplicate()
	var here := String(_land())
	if here != "" and here != "sea" and not lands.has(here):
		lands.append(here)
		lands.sort()
	return {"seconds": play_seconds, "lands": lands}


func _load_play(v: Variant) -> void:
	var d: Dictionary = v if v is Dictionary else {}
	play_seconds = SaveCodec.to_num(d.get("seconds"), 0.0)
	_lands = d.get("lands", []) if d.get("lands") is Array else []


func _exit_tree() -> void:
	if Events.time_skipped.is_connected(_on_time_skipped):
		Events.time_skipped.disconnect(_on_time_skipped)
	if Events.screen_changed.is_connected(_on_screen_changed):
		Events.screen_changed.disconnect(_on_screen_changed)
	if _forced_weather and game != null and game.options.weather == "":
		Weather.unforce()
	SaveGame.clear()


func _on_time_skipped(_minutes: float, reason: StringName) -> void:
	if reason == &"sleep" and rules != null:
		rules.slept()


func _on_screen_changed(_screen: StringName, open: bool) -> void:
	# The game notes open pages before this runs (it connects first).
	if open and game != null and game.open_screens.size() == 1:
		_world_thumb = thumbnail()


func _process(delta: float) -> void:
	if game == null or rules == null or _loading:
		return
	play_seconds += delta
	_clear_frames = 0 if not game.open_screens.is_empty() else _clear_frames + 1
	rules.step_land(_land(), delta)
	if not rules.waiting(game.clock.minutes):
		return
	var why := rules.due(game.clock.minutes, quiet())
	# The test runner's own folder takes no autosaves: every game a test starts
	# would otherwise leave a Continue behind for the next test's title. A test
	# that wants them points SaveSlots.root at a folder of its own.
	if why != &"" and SaveSlots.root != SaveSlots.TEST_ROOT:
		_write(SaveSlots.AUTO, why, thumbnail())


## Nothing is happening that a save would cut through: no fight, nothing
## hostile close, nothing holding the player, no work in hand.
func calm() -> bool:
	var p := game.player
	if p.sim != null and p.sim.fight_on:
		return false
	if game.body.grip > 0 or Survival.busy(game):
		return false
	return not UiRules.hostile_near(get_tree().get_nodes_in_group(&"mobs"), p.pos)


## Calm, and no page open or only just closed: when an autosave may be taken.
## (A save made from the pause page needs only calm.)
func quiet() -> bool:
	return _clear_frames >= CLEAR_FRAMES and calm()


const WHY_LOADING := "Another game is on its way."


func save_to(slot: int) -> String:
	if _loading:
		return WHY_LOADING
	if not SaveSlots.MANUAL.has(slot) and slot != SaveSlots.AUTO:
		return "There is no such slot."
	if not calm():
		return "Not with that so close."
	var thumb := _world_thumb if not game.open_screens.is_empty() else thumbnail()
	return _write(slot, &"manual", thumb)


func load_from(slot: int) -> String:
	if _loading:
		return WHY_LOADING
	var o := BootOptions.new()
	var why := SaveSlots.options_for(slot, o)
	if why != "":
		return why
	_loading = true
	_replace_soon(o)
	return ""


func _write(slot: int, reason: StringName, thumb: PackedByteArray) -> String:
	var err := SaveFile.write(SaveSlots.path(slot), SaveCore.header(game, play_seconds, thumb), SaveGame.collect())
	if err != OK:
		push_warning("save: slot %d not written (%s)" % [slot, error_string(err)])
		return "It would not save."
	rules.saved(game.clock.minutes)
	wrote.emit(slot, reason)
	Events.saved.emit(slot, reason)
	return ""


## A game booted from `o` takes this one's place in the tree, after the page has
## drawn a frame saying so (generating the world holds the screen still).
func _replace_soon(o: BootOptions) -> void:
	for i in 2:
		await get_tree().process_frame
	_replace(o)


func _replace(o: BootOptions) -> void:
	var g := game
	if not is_instance_valid(g) or g.get_parent() == null:
		return
	var parent := g.get_parent()
	get_tree().paused = false
	parent.remove_child(g)
	g.queue_free()
	var next := Game.new()
	next.name = "game"
	parent.add_child(next)
	next.setup(o)


func _land() -> StringName:
	return BiomeRegistry.at(game.world, game.player.pos).id


## The last drawn frame, small, as PNG bytes; empty where nothing is drawn (headless).
func thumbnail() -> PackedByteArray:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return PackedByteArray()
	var tex := get_viewport().get_texture()
	if tex == null:
		return PackedByteArray()
	var img := tex.get_image()
	if img == null or img.is_empty():
		return PackedByteArray()
	img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_LANCZOS)
	return img.save_png_to_buffer()
