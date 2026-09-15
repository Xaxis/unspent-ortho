class_name BootOptions
extends RefCounted
## Command-line options, so any state of the game can be reached from a shell.
##   godot --path . -- --seed=3 --at=120,88 --hour=21 --shot=shots/a.png
##
## --seed=N            world seed (default 1)
## --size=N            world size in tiles (default Tuning.WORLD_SIZE)
## --at=X,Y            start tile position (default: the world's spawn)
## --village=N         start beside village N (overrides --at)
## --hour=H            world clock hour at start (default Tuning.START_HOUR)
## --zoom=F            camera view height in world units
## --walk=DX,DY,SECS   scripted walk in SCREEN directions before the shot
## --run               the scripted walk runs
## --shot=PATH         capture one frame to PATH (png) and quit
## --frames=N          frames to wait after loading before the shot (default 8)
## --scale=N           upscale the shot N times, nearest (default 2)
## --scene=NAME        which scene to boot: game (default) | gallery
## --spawn=K[,K...]    place these roster kinds in front of the player (fight shots/tests)
## --act=NAME[:MS]     play a fight moment and hold it for the shot: swing | grip | hurt | dodge | alert
##                     (MS = simulation time after the press; each has a default);
##                     fx[:MS] draws every hit mark about the player, MS/1000 through its life

var seed_value := 1
var size := Tuning.WORLD_SIZE
var at := Vector2(-1, -1)
var village := -1
var hour := Tuning.START_HOUR
var zoom := 0.0
var walk := Vector2.ZERO
var walk_seconds := 0.0
var run := false
var shot := ""
var frames := 8
var scale := 2
var scene := "game"
var spawn: PackedStringArray = []
var act := ""


static func parse(args: PackedStringArray) -> BootOptions:
	var o := BootOptions.new()
	for a in args:
		var kv := a.trim_prefix("--").split("=", true, 1)
		var k := kv[0]
		var v := kv[1] if kv.size() > 1 else ""
		match k:
			"seed": o.seed_value = v.to_int()
			"size": o.size = v.to_int()
			"at":
				var p := v.split(",")
				o.at = Vector2(p[0].to_float(), p[1].to_float())
			"village": o.village = v.to_int()
			"hour": o.hour = v.to_float()
			"zoom": o.zoom = v.to_float()
			"walk":
				var p := v.split(",")
				o.walk = Vector2(p[0].to_float(), p[1].to_float())
				o.walk_seconds = p[2].to_float() if p.size() > 2 else 1.0
			"run": o.run = true
			"shot": o.shot = v
			"frames": o.frames = v.to_int()
			"scale": o.scale = v.to_int()
			"scene": o.scene = v
			"spawn": o.spawn = v.split(",", false)
			"act": o.act = v
			_: push_warning("unknown option --%s" % k)
	return o
