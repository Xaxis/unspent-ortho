extends TestCase
## The DEV flag (94_dev) says, in the corner of every frame of play, that dev mode
## can be reached. It has to BE in a corner of the frame the game draws on, and
## big enough to hold its word: placed for a 640x360 base it stood in the middle
## of the 1920x1080 one, next to whatever the world had there, three letters
## clipped to two.

const Dev := preload("res://src/systems/94_dev.gd")


func test_the_flag_stands_in_a_corner_of_the_frame() -> void:
	var r: Rect2i = Dev.flag_rect()
	var frame := Rect2i(Vector2i.ZERO, UiBase.SIZE)
	check(frame.encloses(r), "on the frame: %s in %s" % [r, frame])
	var right := UiBase.SIZE.x - r.end.x
	var bottom := UiBase.SIZE.y - r.end.y
	lt(float(right), 80.0, "at the right edge (%d px off it)" % right)
	lt(float(bottom), 80.0, "at the bottom edge (%d px off it)" % bottom)


func test_the_flag_holds_its_word() -> void:
	var r: Rect2i = Dev.flag_rect()
	gt(float(r.size.x), float(UiFont.width("DEV")), "wide enough for DEV (%d against %d)" % [r.size.x, UiFont.width("DEV")])
	gt(float(r.size.y), float(UiFont.SIZE), "tall enough for a line (%d against %d)" % [r.size.y, UiFont.SIZE])
