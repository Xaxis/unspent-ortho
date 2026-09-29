extends RefCounted
## A reader (tests/fight/reader.gd and its kin) playing a RUNNING game: each
## physics frame it decides as it does in a bare simulation, and its walk goes
## in through the game's own input path (Game.scripted_move, as keys on the
## screen: LockOn.keys_for), so the ground, the camera and 40_fight's copy of the
## intent all stand between its hands and the body, as they do for a player. Its
## swing and dodge are the presses 40_fight makes from the keys (FightSim.press_*).
##
##   var d := GameDriver.new(game, PlateReader.new(game.player.sim))
##   while ...: d.step(); await tree.physics_frame

var game: Game
var reader: Variant


func _init(g: Game, r: Variant) -> void:
	game = g
	reader = r


func step() -> void:
	var hero := game.player.sim.hero
	reader.act()
	var dir := hero.move
	game.scripted_move = LockOn.keys_for(dir.normalized() if dir.length() > 0.01 else Vector2.ZERO,
		game.camera.yaw_now(), game.player.pos, hero.lock, game.camera.shoulder) * minf(1.0, dir.length())
	game.scripted_run = hero.run
	game.scripted_seconds = 0.05
