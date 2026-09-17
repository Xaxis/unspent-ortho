class_name UiScreen
extends Control
## An app on the slate. Apps take abstract actions, never devices, so tests
## drive them directly:
##   up down left right   choose / change a value
##   confirm              do the chosen row (E, Enter, Space)
##   back                 close, one level (Esc)
##   <own_action>         the key that opened the app also closes it
## Opening and closing emit Events.screen_changed(screen_name, open), which is
## what pauses gameplay input, and the slate's sounds.
##
## Every app draws on the same device (UiSlate): draw_frame() first (the veil,
## the bezel and glass, the status bar with this app lit), its own content, then
## draw_keys() (the key strip and the note). Over all of it a child layer draws
## the glass's flaws, the wake scan and the dimming with low power.

signal closed(screen: UiScreen)

## Set by subclasses in _init.
var screen_name: StringName = &"screen"
var own_action: StringName = &""
var menu := UiMenu.new()
## The running game, or null (title, tests without a world).
var game: Game
## A short line in the key strip: what was done, or why not (then in the warning).
var note := ""
var note_age := 0.0
var note_warn := false
var is_open := false
## 0..1: the glass wakes when an app opens, a scan line running down it at whole
## pixels; switching from one app to the next wakes it faster.
var wake := 1.0
var wake_seconds := UiSlate.WAKE_SECONDS
var wakes := true
## The glass's brightness 0..1 (the ui system sets it from the slate's power).
## The dimming is drawn on the glass layer over the app, so that layer redraws.
var brightness := 1.0:
	set(v):
		if not is_equal_approx(v, brightness):
			brightness = v
			if _fx != null:
				_fx.queue_redraw()
## The slate's power 0..1, for the cell in the status bar.
var power := 1.0
## Where this app's device sits (the title's slate is smaller).
var device_rect := UiSlate.DEVICE
## First row drawn of a list longer than its pane.
var scroll := 0

var _fx: Control
## The last frame drew a plain device because its bake was not in yet.
var _plain := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.theme()
	visible = false
	_fx = Control.new()
	_fx.name = "glass"
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_glass)
	add_child(_fx)


## `switched`: the slate was already awake on another app.
func open(switched: bool = false) -> void:
	if is_open:
		return
	is_open = true
	visible = true
	wake = 0.0 if wakes else 1.0
	wake_seconds = UiSlate.SWITCH_SECONDS if switched else UiSlate.WAKE_SECONDS
	move_child(_fx, -1)
	note = ""
	_on_open()
	refresh()
	# The HUD steps aside while an app is open; its messages land in the key strip.
	if not Events.message.is_connected(say):
		Events.message.connect(say)
	Events.screen_changed.emit(screen_name, true)
	Events.sfx.emit(&"ui_slate_switch" if switched else &"ui_slate_wake", Vector3.ZERO)


## `switched`: another app takes the glass at once, so the slate does not sleep.
func close(switched: bool = false) -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if Events.message.is_connected(say):
		Events.message.disconnect(say)
	_on_close()
	Events.screen_changed.emit(screen_name, false)
	if not switched:
		Events.sfx.emit(&"ui_slate_sleep", Vector3.ZERO)
	closed.emit(self)


## Rebuild rows from the game's data and redraw.
func refresh() -> void:
	queue_redraw()


## Returns true if the action was used.
func handle(action: StringName) -> bool:
	if not is_open:
		return false
	match action:
		&"up", &"down":
			if menu.move(-1 if action == &"up" else 1):
				Events.sfx.emit(&"ui_slate_click", Vector3.ZERO)
				_on_choice_changed()
				queue_redraw()
			return true
		&"left", &"right":
			_on_side(-1 if action == &"left" else 1)
			return true
		&"confirm":
			var row := menu.selected()
			if row.is_empty():
				return true
			if not UiMenu.enabled(row):
				refuse(String(row.get("why", "Not now.")))
			else:
				_on_confirm(row)
			return true
		&"back":
			close()
			return true
	if own_action != &"" and action == own_action:
		close()
		return true
	return false


## Move the choice to the row whose id is `id`, if there is one (shots, links).
func select(id: StringName) -> void:
	for i in menu.rows.size():
		if UiMenu.selectable(menu.rows[i]) and menu.rows[i].get("id") == id:
			menu.index = i
			_on_choice_changed()
			queue_redraw()
			return


## Move `scroll` so the chosen row is among the `lines` drawn, keeping a
## group's heading in view with its first row.
func keep_in_view(lines: int) -> void:
	if menu.index < 0:
		scroll = 0
		return
	if menu.index < scroll:
		scroll = menu.index
	elif menu.index >= scroll + lines:
		scroll = menu.index - lines + 1
	if scroll > 0 and menu.index == scroll and menu.rows[scroll - 1].has("header"):
		scroll -= 1
	scroll = clampi(scroll, 0, maxi(0, menu.rows.size() - lines))


func refuse(why: String) -> void:
	Events.sfx.emit(&"ui_slate_deny", Vector3.ZERO)
	say(why)
	note_warn = true


func say(text: String) -> void:
	note = text
	note_age = 0.0
	note_warn = false
	queue_redraw()


func _exit_tree() -> void:
	# Sketches and bezels this app asked for may still be drawing on a worker.
	UiSketch.wait()
	UiSlate.wait()


## Jump the wake to its end, and wait out the sketches this page asked for
## (screenshots: a shot has one frame to be right in, and a scan window is never
## drawn until its raster is in from a worker).
func settle() -> void:
	wake = 1.0
	UiSketch.wait()
	queue_redraw()
	_fx.queue_redraw()


## The world clock as the status bar says it, or "" with no game.
func clock_text() -> String:
	return game.clock.label() if game != null and game.clock != null else ""


func _process(delta: float) -> void:
	if is_open and _plain and UiSlate.ready(device_rect.size):
		_plain = false
		queue_redraw()
		_fx.queue_redraw()
	# A sketch is never drawn on this thread (UiSketch.draw_item says why), so a
	# scan window stands empty until its raster lands. Redraw while any is out and
	# the page fills itself in, the way the bezel does above.
	if is_open and UiSketch.waiting():
		queue_redraw()
	if is_open and wake < 1.0:
		wake = minf(1.0, wake + delta / wake_seconds)
		_fx.queue_redraw()
	if is_open and note != "":
		var was := note_age
		note_age += delta
		if note_age > 3.0 and floori(was * 8.0) != floori(note_age * 8.0):
			queue_redraw()


## The veil, the device, the status bar with this app lit.
func draw_frame(app: StringName = screen_name) -> void:
	UiSlate.veil(self)
	draw_device()
	UiSlate.status(self, app, clock_text(), power, device_rect)


## The bezel and glass, noting whether they were still a plain frame.
func draw_device() -> void:
	_plain = not UiSlate.ready(device_rect.size)
	UiSlate.device(self, device_rect)


## The key strip, with the note on its right.
func draw_keys(pairs: Array) -> void:
	UiSlate.keys(self, pairs, note, note_age, note_warn, device_rect)


func _draw_glass() -> void:
	if not is_open:
		return
	UiSlate.marks(_fx, device_rect)
	UiSlate.wake(_fx, wake, device_rect)
	UiSlate.dim(_fx, brightness, device_rect)


# --- for subclasses ---

func _on_open() -> void:
	pass


func _on_close() -> void:
	pass


func _on_confirm(_row: Dictionary) -> void:
	Events.sfx.emit(&"ui_slate_confirm", Vector3.ZERO)


func _on_side(_dir: int) -> void:
	pass


func _on_choice_changed() -> void:
	pass
