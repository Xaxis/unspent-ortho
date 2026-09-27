extends TestCase
## ESC LEAVES A CONVERSATION AND NOTHING ELSE. The talk reads its own keys and
## runs before the slate; the frame esc put a talk down, the slate saw esc go
## down with nobody talking and opened the pause menu over the world.

const Sx := preload("res://tests/save/save_fixture.gd")


func test_esc_out_of_a_talk_does_not_open_the_pause_menu() -> void:
	Sx.use_root("talk_esc")
	var g := Sx.game(tree, ["--seed=1", "--size=64", "--hour=11", "--talk=maren"])
	# The slate starts reading keys once the game is up, a few frames in.
	await frames(60)
	check(g.talking, "a conversation is up")
	Input.action_press(&"pause")
	await frames(4)
	Input.action_release(&"pause")
	await frames(4)
	check(not g.talking, "esc put it down")
	var ui := Sx.system(g, "90_ui")
	eq(ui.call("top"), null, "and no page opened over the world")
	check(not tree.paused, "and the world is not paused")
	# A fresh esc is a fresh press: it opens the menu as it always did.
	Input.action_press(&"pause")
	await frames(4)
	Input.action_release(&"pause")
	await frames(2)
	check(ui.call("top") != null, "the next esc opens home")
	tree.paused = false
	Sx.end(g)
	Sx.finish()
