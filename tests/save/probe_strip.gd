extends SceneTree
## Where a save's problem is SAID, and whether it fits there, in pixels.
##
##   godot --headless --path . -s tests/save/probe_strip.gd
##
## Two places say it. The title's key strip has room for one short line, and
## these sentences used to be drawn straight through the key hint beside them;
## the reason page (the faded continue row, or a game handed back to the title)
## has the glass where the list stands, and says the whole of it. Both are
## measured here from the title's own numbers, never a copy of them, and both
## are held to by tests/save/test_problem_fits.gd.


## The title's slate, loaded at run time rather than named here. A script run
## (`-s`) has no autoloads until _initialize returns, and UiTitleMenu extends
## UiScreen, which cannot compile without Events: named in this file it would
## fail to load before a line of it ran.
var menu: GDScript


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	menu = load("res://src/ui/ui_title_menu.gd")
	var g := UiSlate.glass_of(menu.DEVICE)
	var x := g.position.x + UiSlate.MARGIN_L
	for p: Array in menu.KEY_HINTS:
		x += maxi(9, UiFont.width(p[0] as String) + 6) + 4
		x += UiFont.width(p[1] as String) + 12
	var room := (g.end.x - UiSlate.MARGIN_R) - x
	print("== the key strip: one line, %d px of it (glass %s)" % [room, g])
	for code: StringName in [&"missing", &"newer", &"older", &"elsewhere", &"damaged"]:
		for slot: int in [0, 1]:
			_say(SaveSlots.problem(slot, code), room)

	var width := g.size.x - int(menu.REASON_INSET) * 2
	var top := int(menu.list_top())
	var lines := (g.end.y - UiSlate.KEYS_H - 2 - top) / UiTheme.LINE
	print("")
	print("== the reason page: %d px wide, %d lines of room (%d allowed)" % [width, lines, menu.REASON_LINES])
	for why: String in [SaveFile.WHY_ELSEWHERE, SaveFile.WHY_DAMAGED, SaveFile.WHY_NEWER,
			SaveFile.WHY_OLDER, SaveFile.WHY_MISSING, _ground_moved()]:
		var wrapped := UiSlate.wrap_text(width, why)
		var widest := 0
		for l: String in wrapped:
			widest = maxi(widest, UiFont.width(l))
		print("  %d lines, widest %3d px %s: %s" % [wrapped.size(), widest,
			"fits" if wrapped.size() <= int(menu.REASON_LINES) and widest <= width else "OVER", why.left(46) + "..."])
	quit()


## The longest sentence SaveCore.disagrees can make in this registry.
func _ground_moved() -> String:
	var longest := ["", ""]
	for d in BiomeRegistry.land():
		var n := SaveCore.spoken(d.id)
		if n.length() > longest[0].length():
			longest[1] = longest[0]
			longest[0] = n
		elif n.length() > longest[1].length():
			longest[1] = n
	return "That game was saved in the %s. This world has %s there instead, so it is not the same ground." % longest


func _say(s: String, room: int) -> void:
	var w := UiFont.width(s)
	print("  %3d px  %-42s %s" % [w, '"' + s + '"', "OVER by %d" % (w - room) if w > room else "fits"])
