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
## --scene=NAME        which scene to boot: game (default) | gallery | title | loading (the loading page, still)
## --place=NAME        start at a named place (GenPlaces): a country ("moss"), an
##                     ecotone ("coast-pinewood"), a landmark ("tip2"), "river", "cliff"
## --stats             print render stats (draw calls, chunk build times) before the shot
## --weather=KIND:S     force the weather (e.g. rain:1, fog:0.6, storm:1:bolt, dry_storm:1:bolt; kinds in Weather.KINDS), sky package
## --lamp              start with the player's lantern lit, sky package
## --silhouette        gallery: machines (and the lineup's people) drawn flat black
## --parade=K,K[:POSE] stand machines round the player (K a kind or `all`; POSE a
##                     FigureModel pose or `walk`): review only, never mobs
## --hand=ID           the player holds ID (given if not carried), characters
## --look=TOKENS       the player's look: build,hat,coat,hair,beard,salvage names, or seed:N (characters)
## --pose=NAME[:T]     the player plays a PersonModel action on a loop, or frozen T s in (characters)
## --face=DEG          the player's facing in degrees, 0 east, 90 south (characters)
## --folk=N            N villagers in a ring round the player, for crowd shots (characters)
## --fauna=KIND:N,...  N animals of KIND in a ring round the player, e.g. gull:3 (characters)
## --give=ID:N,ID:N    put items in the creel at start (survival)
## --held=ID           hold this item at start, given if not carried (survival)
## --use[=KIND]        at start, face the nearest workable prop (of KIND, e.g. iron_ore) and use (survival)
## --build=STATION     at start, put a fire/bench/kiln in front of the player, free (survival)
## --put=KIND[,KIND]   at start, place these props (e.g. tip,driftwood) in an arc in front of the player (survival)
## --taken             the --put props start already taken, laid in a row across the screen (their leavings show)
## --hold=SECONDS      survival and its drawing run on fixed 1/60 s frames and stop SECONDS
##                     after start: a take or a fire caught at an exact moment (--frames > SECONDS*60)
## --spawn=K[,K...]    place these roster kinds in front of the player (fight shots/tests)
## --act=NAME[:MS]     play a fight moment and hold it for the shot: swing | grip | hurt | dodge | alert | windup
##                     (MS = simulation time after the press; each has a default);
##                     fx[:MS] draws every hit mark about the player, MS/1000 through its life
## --screen=NAME       open a slate app once loaded: inventory | crafting | map | pause | controls |
##                     loadout | reads | saves (these three over home) | sheet; NAME:ROW chooses a row,
##                     map:N opens at scale N; lowpower[:NAME] drains the slate's power first;
##                     on --scene=title: keys, or wake:SECS to hold the wake (slate)
## --explore=N         the map remembers N tiles of wandering from the start (ui)
## --ui-demo           ui shots: sample recipes, a message, a spent body (ui)
## --tour=PATH         play a tour (src/systems/98_tour.gd) and quit
## --load=N            boot the save in slot N (0 autosave, 1-3 the player's): its seed,
##                     size, clock and place, then everything it holds (saves)
## --saves=DIR         keep saves in user://DIR (default user://saves; shots use
##                     user://tool-saves and each tour user://tool-saves/<tour name>, so
##                     they never touch the player's nor each other's) (saves)
## --progress=F        --scene=loading: hold the loading page's line at F (0..1) (export)
## --probe             after the first frame, check audio, focus and saves and print `web ...` lines (export, tools/web.sh)
## --fail-downed       a bad end (downed or carried off) quits the game with exit 1: a tour that
##                     must be survived through real play fails if it is not (fight)

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
var place := ""
var stats := false
## "kind:strength[:bolt]" or "" (the weather rules decide). Read by 10_sky.
var weather := ""
var lamp := false
var silhouette := false
var parade := ""
var hand := ""
var look := ""
var pose := ""
var face := ""
var folk := 0
var fauna := ""
var give: Dictionary = {} # StringName -> int
var held := ""
var use := false
var use_kind := ""
var build := ""
var hold := -1.0
var put: PackedStringArray = []
var taken := false
var spawn: PackedStringArray = []
var act := ""
var screen := ""
var explore := 0
var ui_demo := false
var tour := ""
## Save slot to boot, or -1. SaveSlots.options_for fills seed, size, at and hour from it.
var load_slot := -1
var saves := ""
var progress := 0.4
var probe := false
var fail_downed := false


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
			"place": o.place = v
			"stats": o.stats = true
			"weather": o.weather = v
			"lamp": o.lamp = true
			"silhouette": o.silhouette = true
			"parade": o.parade = v
			"hand": o.hand = v
			"look": o.look = v
			"pose": o.pose = v
			"face": o.face = v
			"folk": o.folk = v.to_int()
			"fauna": o.fauna = v
			"screen": o.screen = v
			"give":
				for part in v.split(",", false):
					var iv := part.split(":")
					o.give[StringName(iv[0])] = iv[1].to_int() if iv.size() > 1 else 1
			"held": o.held = v
			"use":
				o.use = true
				o.use_kind = v.replace("_", " ")
			"build": o.build = v
			"hold": o.hold = v.to_float()
			"put": o.put = v.split(",", false)
			"taken": o.taken = true
			"spawn": o.spawn = v.split(",", false)
			"act": o.act = v
			"explore": o.explore = v.to_int()
			"ui-demo": o.ui_demo = true
			"tour": o.tour = v
			"load": o.load_slot = v.to_int()
			"saves": o.saves = v
			"progress": o.progress = v.to_float()
			"probe": o.probe = true
			"fail-downed": o.fail_downed = true
			_: push_warning("unknown option --%s" % k)
	return o
