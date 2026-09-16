extends SceneTree
## Every sentence SaveSlots.problem() can put on the title's key strip, against
## the room the title's slate actually has, plus the candidates for a rewrite.

const ROOM := 200


func _initialize() -> void:
	var d := Rect2i(166, 158, 308, 188)  # UiTitleMenu.DEVICE
	var g := UiSlate.glass_of(d)
	var x := g.position.x + UiSlate.MARGIN_L
	x += maxi(9, UiFont.width("e") + 6) + 4
	var keys_end := x + UiFont.width("choose")
	var room := (g.end.x - UiSlate.MARGIN_R) - (keys_end + 4)
	print("title slate: room for a note = %d px" % room)
	print("-- now --")
	for code: StringName in [&"missing", &"newer", &"older", &"elsewhere", &"damaged"]:
		for slot: int in [0, 1]:
			_say(SaveSlots.problem(slot, code), room)
	print("-- candidates --")
	for tail: String in [
			"is empty.",
			"is from a newer game.",
			"is too old for this game.",
			"was made on another island.",
			"is from another island.",
			"is damaged.",
			"cannot be read.",
		]:
		for who: String in ["The autosave", "Slot 3"]:
			_say("%s %s" % [who, tail], room)
	quit()


func _say(s: String, room: int) -> void:
	var w := UiFont.width(s)
	print("  %3d px  %-48s %s" % [w, '"' + s + '"', "OVER by %d" % (w - room) if w > room else "fits"])
