class_name SettingsApply
## Where a player's settings meet the engine: the buses and the window. Kept
## apart from `PlayerSettings` so the rules can be read in a headless test with
## no display and no sound, and so there is exactly one place that touches either.

## Quietest a level may be before it is silence, in decibels.
const SILENT_DB := -60.0
## Which buses "the world" means. Music has its own level, UI rides the overall
## one on Master: a player who turns the world down still wants to hear the slate
## answer them.
const WORLD_BUSES: Array[StringName] = [&"World", &"Machines"]


## True only in a session a person means to play. A tool run opens its window off
## the screen on purpose and must never be dragged back by a setting: a shot whose
## window moved to the middle of the display captures nothing, which is how this
## was found.
static var for_a_person := false

## A tier named on the command line (`--quality=`), or &"" for none. It beats both
## settings doors, for this run only, and is never written to anyone's file.
static var quality_asked: StringName = &""


static func install(playing: bool) -> void:
	for_a_person = playing
	PlayerSettings.on_sound = Callable(SettingsApply, "sound")
	PlayerSettings.on_window = Callable(SettingsApply, "window")
	PlayerSettings.on_quality = Callable(SettingsApply, "quality")
	PlayerSettings.apply_all()


## The graphics tier this run renders at (docs/LOOK.md, src/render/quality.gd).
##
## THE SEAM. The tier ROWS live in `Quality` and are copied into neither settings
## table; both doors only ever name one, and this is where the two meet, because
## by design neither of them reads the other:
##
##   1. `--quality=NAME`          one run, for a shot or a tour. Beats everything.
##   2. `picture.quality`         the player's, kept on their own device.
##   3. `build.quality`           the owner's, pinned into a stamped build.
##   4. `Quality.detect()`        what this machine can actually do.
##
## `auto` at any rung means "fall through to the next one", so a player who has
## not chosen gets the build's tier, and a build that has not pinned one gets the
## machine's. Unlike `window()` this is NOT guarded by `for_a_person`: a shot and a
## tour must render at the same tier a player would see, or every picture in the
## repository is evidence about a build nobody runs.
static func quality() -> void:
	var want := quality_asked
	if want == &"" or want == &"auto":
		want = StringName(str(PlayerSettings.value(&"picture.quality")))
	if want == &"" or want == &"auto":
		want = StringName(str(GameConfig.value("build.quality")))
	if want == &"" or want == &"auto" or not Quality.has(want):
		want = Quality.detect()
	Quality.apply(want, Engine.get_main_loop() as SceneTree)


## Levels onto the bus layout SoundMix already declares, as an offset from what
## the mix was tuned to — never an absolute, or every bus would come out at the
## same loudness and the mix would be gone.
##
## It never unmutes: `main.gd` mutes the master bus for a run nobody is listening
## to (a shot, a tour, one of six builders), and a player's level has no business
## overruling that.
static func sound() -> void:
	_set_bus(&"Master", _base_db(&"Master"), float(PlayerSettings.value(&"sound.overall")))
	_set_bus(&"Music", _base_db(&"Music"), float(PlayerSettings.value(&"sound.score")))
	var world := float(PlayerSettings.value(&"sound.world"))
	for bus: StringName in WORLD_BUSES:
		_set_bus(bus, _base_db(bus), world)


static func _base_db(bus: StringName) -> float:
	for row: Array in SoundMix.BUSES:
		if row[0] == bus:
			return float(row[2])
	return 0.0


static func _set_bus(bus: StringName, base_db: float, level: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, base_db + level_db(level))


## A level as decibels: 1 is the mix as tuned, 0 is silence.
static func level_db(level: float) -> float:
	var l := clampf(level, 0.0, 1.0)
	if l <= 0.001:
		return SILENT_DB
	return maxf(SILENT_DB, linear_to_db(l))


## The window a person plays in. Never touched on the web (the canvas is the
## page's business) and never in a tool run, which opens its window off the
## screen on purpose and must not be dragged back (`tools/_focus.sh`).
static func window() -> void:
	# Shown on any device that has a window, but only MOVED for a person: a tool
	# run's window is off the screen on purpose and a shot of the page should
	# still show the rows a player would see.
	if not for_a_person or not can_set_window():
		return
	var w := Engine.get_main_loop().root as Window if Engine.get_main_loop() != null else null
	if w == null:
		return
	var full := bool(PlayerSettings.value(&"picture.fullscreen"))
	var mode := DisplayServer.window_get_mode()
	if full and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if not full and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if full:
		return
	var want := window_size(int(PlayerSettings.value(&"picture.scale")))
	if w.size == want:
		return
	w.size = want
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.SCREEN_PRIMARY)
	w.position = screen.position + (screen.size - w.size) / 2


## The window `picture.scale` asks for, never bigger than the screen it opens on.
##
## The scale counts the SLATE's pixels, not the base's (`UiBase.DESIGN`, not
## `UiBase.SIZE`), which is what keeps the row's own words true — "whole pixels of
## yours to one of the game's" is about the glass a player reads, and the glass is
## still drawn in 640x360 units. It also keeps every scale the same window it was
## before LANTERN raised the base: 2 is 1280x720 here as it was at the old floor.
## Reading it off the base instead would make the default window 3840x2160.
##
## The world inside that window is rendered at the full 1920x1080 base (times the
## quality tier's render scale) and fitted into it, so a bigger window buys a
## bigger picture and never a coarser one.
static func window_size(scale: int) -> Vector2i:
	var want := UiBase.DESIGN * maxi(1, scale)
	if not can_set_window():
		return want
	var room := DisplayServer.screen_get_usable_rect(DisplayServer.SCREEN_PRIMARY).size
	if room.x <= 0 or room.y <= 0 or (want.x <= room.x and want.y <= room.y):
		return want
	# Too big for this display: step down whole slate-scales until it fits, so the
	# window stays a whole multiple and never opens half off the screen.
	for s in range(maxi(1, scale) - 1, 0, -1):
		var smaller := UiBase.DESIGN * s
		if smaller.x <= room.x and smaller.y <= room.y:
			return smaller
	return UiBase.DESIGN


## Whether the window rows mean anything on this device: a browser canvas and a
## headless run have no window a player can size, and the page says so rather
## than showing a row that does nothing.
static func can_set_window() -> bool:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return false
	return Engine.get_main_loop() != null
