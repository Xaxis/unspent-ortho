extends RefCounted
## The one script that names the scenes a start makes (Game, UiTitle). BootPage
## loads it by path, so the game's scripts compile when it loads (on a loader
## thread behind the loading page), not before main.gd can draw a first frame.
##
##   BootPage.make_game(parent, o) / make_title(parent, o)   (never Game.new() in boot code)
##
## Why a script that names them, and not load("res://src/game.gd"): on Godot 4.7.2
## the game's scripts compiled with game.gd itself as the first one loaded were
## never released at exit. Every run (a shot, a tour, the Mac app) ended with
## ~110 scripts, their static materials and meshes, and GL RIDs reported as leaks,
## burying real ones. Compiled from a script that names Game, as main.gd did
## before the loading page, they go cleanly. tests/export/test_exit.gd runs a game
## and a title in a child process and fails if that comes back.


static func make_game(parent: Node, o: BootOptions) -> Game:
	var game := Game.new()
	game.name = "game"
	parent.add_child(game)
	game.setup(o)
	return game


static func make_title(parent: Node, o: BootOptions) -> UiTitle:
	var title := UiTitle.new()
	title.name = "title"
	parent.add_child(title)
	title.setup(o)
	return title


## Where the title's first view is (its drift's start) for `w`. Pure (a worker calls it).
static func opening(w: WorldData) -> Vector2:
	return UiTitle.opening(w)[0]
