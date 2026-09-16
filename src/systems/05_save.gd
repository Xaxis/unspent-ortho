extends GameSystem
## Saving and loading the running game.
##   - registers the core state (SaveCore) first, so every later system's
##     SaveGame.register lands after it and is applied after it
##   - a game booted with a slot (--load=N, Continue, Load) is applied in started(),
##     after every setup and before the first frame; the world was generated from
##     the save's seed with the first chunks drawn where the save stood, and is
##     held to what the save says stood there (SaveCore.disagrees) before a byte
##     of it is applied — a save is never laid onto ground that has moved
##   - and when it will not open, this game is not played at all: it takes no save
##     of any kind and hands back to the title with the reason (_refuse)
##   - autosaves to slot 0 on sleep, on coming into another landscape and every
##     three world hours, never while a fight is on (AutosaveRules); and on leaving
##     (to the title, quit, the window closed) when calm
##   - an autosave also waits while any page is open (the map, carrying and making
##     do not pause the world), and for a few frames after the last closes, so its
##     picture is the world and never a page
##   - keeps play time, and a thumbnail of the world: taken when the first page
##     opens (the frame before the page is drawn) for saves made from a page, and
##     at the moment of an autosave
## Screens reach it through the game's systems by name (UiSavesScreen):
##   save_to(slot) -> String    "" or why not
##   load_from(slot) -> String  "" (the game is replaced next frame) or why not
##   save_on_leaving() -> String  the autosave, before the game goes ("" or why not)
##   last_saved_at               unix seconds this game was last saved (or loaded), -1 never
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
## Why the save this game was booted with was not opened, or "". Set once, in
## started(); this game then writes nothing and hands back to the title.
var refused := ""
## When this game was last saved, or loaded (it stands as saved), in unix seconds; -1 never.
var last_saved_at := -1.0
## The world with no page over it, read back as the first page opened (small;
## encoded only if a save is made from the page).
var _world_frame: Image
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
		# The world is made before this runs, so it can be held to what the save
		# says stood there. A save that disagrees is not applied at all: nothing
		# is worse than the player laid down on ground that moved without a word.
		var moved := SaveCore.disagrees(game, r.header) if r.ok else ""
		if r.ok and moved == "":
			SaveGame.apply(r.data)
			loaded_from = slot
			last_saved_at = Time.get_unix_time_from_system()
			_forced_weather = Weather.forced_kind != &""
		else:
			# A file this build cannot read says so itself; a file it can read whose
			# ground has moved is an island case the stamp could not see.
			var code: StringName = r.code if not r.ok else &"elsewhere"
			_refuse(slot, code, moved if moved != "" else str(r.why))
	rules = AutosaveRules.new(game.clock.minutes, _land())
	rules.enter_all(_lands)


## A save this build will not open leaves nothing half done. Applying none of it
## would have left the player standing at the saved tile, at the saved hour, with
## an empty pack and no idea it was not their game — and the autosave, due within
## minutes, would then have written over the very slot just refused (the door in
## is Continue on slot 0). So: no save and no load for the rest of this session,
## the slot remembered as turned away so nothing offers it again, and the game
## hands straight back to the title, which says the whole reason on its glass.
func _refuse(slot: int, code: StringName, why: String) -> void:
	refused = why
	_loading = true
	SaveSlots.turn_away(slot, code, why)
	SaveSlots.handed_back = slot
	Events.message.emit(why)
	_hand_back.call_deferred()


## Deferred, never awaited: a game freed before the flush (a test that ends it)
## drops the call with the node, rather than resuming inside a freed object.
func _hand_back() -> void:
	if is_instance_valid(game) and game.is_inside_tree():
		UiTitle.replace_game(game)


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
		_world_frame = frame()


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
	return _clear_frames >= CLEAR_FRAMES and not under_boot_page() and calm()


## The loading page is still drawn over this game. It is a page like any other
## for the purpose above — an autosave taken under it saves a picture of the
## page, not of the world — and the first autosave of a game is due early enough
## to land there on a machine slow to lift it.
func under_boot_page() -> bool:
	return is_inside_tree() and not get_tree().get_nodes_in_group(&"boot_page").is_empty()


const WHY_LOADING := "Another game is on its way."


func save_to(slot: int) -> String:
	if _loading:
		return WHY_LOADING
	if not SaveSlots.MANUAL.has(slot) and slot != SaveSlots.AUTO:
		return "There is no such slot."
	if not calm():
		return "Not with that so close."
	var thumb := png(_world_frame) if not game.open_screens.is_empty() else thumbnail()
	return _write(slot, &"manual", thumb)


## Leaving the game: the autosave takes it as it stands, when calm, so to the
## title or quit never throws play away. Its picture is the world from before
## the pause page. The test runner's own folder takes none (see _process).
func save_on_leaving() -> String:
	if _loading or rules == null:
		return WHY_LOADING if _loading else ""
	if SaveSlots.root == SaveSlots.TEST_ROOT:
		return ""
	if not calm():
		return "Not with that so close."
	var thumb := png(_world_frame) if not game.open_screens.is_empty() else thumbnail()
	return _write(SaveSlots.AUTO, &"quit", thumb)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and game != null and is_inside_tree():
		save_on_leaving()


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
	# Whatever that slot was once turned away for, it now holds a game this build
	# wrote on this island.
	SaveSlots.forget_turned_away(slot)
	rules.saved(game.clock.minutes)
	last_saved_at = Time.get_unix_time_from_system()
	wrote.emit(slot, reason)
	Events.saved.emit(slot, reason)
	return ""


## A game booted from `o` takes this one's place in the tree, after the app has
## drawn a frame saying so; the loading page takes it from there.
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
	# Through the loading page, like every start (BootWorld contract): the window
	# keeps drawing while the saved world is made.
	BootPage.open_game(parent, o)


func _land() -> StringName:
	return BiomeRegistry.at(game.world, game.player.pos).id


## The last drawn frame, small, as PNG bytes; empty where nothing is drawn (headless).
func thumbnail() -> PackedByteArray:
	return png(frame())


## The last drawn frame, THUMB-sized; null where nothing is drawn (headless).
func frame() -> Image:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return null
	var tex := get_viewport().get_texture()
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return null
	img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_LANCZOS)
	return img


static func png(img: Image) -> PackedByteArray:
	return img.save_png_to_buffer() if img != null and not img.is_empty() else PackedByteArray()
