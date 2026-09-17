class_name DevTitle
extends Control
## Dev mode on the title (docs/DEV.md): the chord and ` read from the keys, the
## dev app opened as a full page slate over the title's own, a violet "` dev"
## label on the title slate's bezel where dev mode can be reached, and what a
## non-release build is (channel, version, commit) in the corner below it.
##
## UiTitle makes one in its setup (DevTitle.attach) and its menu stops reading
## keys while the app is open (is_open).

const LABEL_AT := Vector2i(10, 10)
## Pixels in from the title slate's left edge: past KEEP DRY, short of the grey casing.
const LABEL_ON_BEZEL := 134
const VIOLET := Color("#b3a8ea")

var title: UiTitle
var screen: UiDevScreen
var _held := false


static func attach(t: UiTitle, layer: CanvasLayer) -> DevTitle:
	var d := DevTitle.new()
	d.name = "dev"
	d.title = t
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(d)
	# Back on the title the saves are the player's again, whatever dev mode started before.
	DevPlay.restore_saves()
	if DevMode.access() != &"off":
		DevMode.ensure_actions()
	return d


func is_open() -> bool:
	return screen != null and screen.is_open


func open(page: StringName = &"") -> void:
	if not DevMode.reachable():
		return
	if screen == null:
		UiSlate.warm()
		screen = UiDevScreen.new()
		screen.title_scene = title
		screen.standalone = true
		get_parent().add_child(screen)
	if not screen.is_open:
		screen.picture = null
		screen.open()
	if page != &"":
		screen.open_at(page)


func _process(_delta: float) -> void:
	queue_redraw()
	if DevMode.access() == &"off" or title.menu == null or title.menu.sleeping:
		return
	if not InputMap.has_action(&"dev_toggle"):
		return
	var now := Input.is_action_pressed(&"dev_toggle")
	# Just pressed too: a key struck and let go inside one frame (a browser delivers
	# a quick tap that way) is never seen held.
	var went_down := (now and not _held) or Input.is_action_just_pressed(&"dev_toggle")
	_held = now
	# The open app reads ` itself and shuts on it.
	if not went_down or is_open():
		return
	if not DevMode.reachable():
		if DevMode.chord(Time.get_ticks_msec()):
			Events.sfx.emit(&"ui_slate_ping", Vector3.ZERO)
			open()
		return
	open()


func _draw() -> void:
	if title == null or title.menu == null or not title.menu.is_lit():
		return
	var stamp := DevStamp.current()
	if not stamp.is_empty() and str(stamp.get("config", "")) != "" and str(stamp.get("channel", "")) != "release":
		# Below the slate, where the dark band lies: what build this is, for anyone
		# who sends word about it.
		var words := DevStamp.label(stamp)
		UiDraw.text_rimmed(self, Vector2i(UiBase.DESIGN.x - LABEL_AT.x - UiFont.width(words), UiBase.DESIGN.y - LABEL_AT.y - 2), words, UiTheme.TEXT, UiTheme.RIM)
	if not DevMode.reachable() or is_open():
		return
	# A label stuck on the slate's lower bezel, clear of what is scratched into it
	# and of the patched casing: the key, and the word.
	var d := UiTitleMenu.DEVICE
	var at := Vector2i(d.position.x + LABEL_ON_BEZEL, d.end.y - 14)
	var w := UiFont.width("dev") + 16
	UiDraw.rect(self, Rect2i(at.x - 2, at.y - 1, w + 4, 11), UiTheme.RIM)
	UiDraw.frame(self, Rect2i(at.x - 2, at.y - 1, w + 4, 11), UiTheme.MACHINE[1])
	UiDraw.text(self, Vector2i(at.x + 1, at.y - 1), "`", VIOLET)
	UiDraw.text(self, Vector2i(at.x + 10, at.y - 1), "dev", VIOLET)
