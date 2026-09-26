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
## --lens=ortho|persp   which projection the play camera uses; persp is a
##                     third-person perspective lens, off by default
## --view=top|shoulder where the camera opens: looking down (the play camera) or
##                     over the player's shoulder (41_shoulder), beating the
##                     player's `playing.view` for this run; a shot opens there
##                     with no glide
## --eye=H[,P[,F]]     stage a low perspective camera H units over the ground,
##                     a little behind the player and facing --face, pitched P
##                     degrees down (default 10) with a vertical fov of F (default
##                     60): a picture of the world at eye level to the horizon,
##                     for the horizon work before the play camera can stand
##                     there (src/systems/96_eye.gd; render)
## --eye-turn=DEG      turn that eye DEG degrees a second about the player, for
##                     proving a view turning never shows the land late
## --colossi=off      no walking megastructures this run (19_colossi): the only
##                     way to take one moment with and without them and measure
##                     what they cost (render)
## --colossus=W@MINUTE show walker W alone (0 on the skyline, 1 looming, 2 the one
##                     the island passes under), posed MINUTE world minutes into
##                     its walk and walking on from there; `--stats` prints where
##                     each one stands, for --face (render)
## --orbit=off         no ring in the sky this run (19_orbit): the only way to
##                     take one moment with and without it and measure its cost
## --orbit=zenith@H     stage a pass of the ring whose peak stands overhead at hour
##                     H of the first day (H under 24) or at world minute H (24 and
##                     over), alone, crossing on from there; `zenith@H/B` has it
##                     rise at bearing B (degrees, 0 east, 90 south); a trailing
##                     `:ab` measures its cost, layer on and held off (`:ab-layer`,
##                     `:ab-wake` one part alone), and `:bench` takes the cost
##                     apart in back-to-back drawn frames (render)
## --fall=off          no debris falling through the sky this run (21_falls)
## --fall=CLASS@AT[/B]  stage one fall of CLASS (dust, fragment, mass) alone,
##                     lighting at hour AT of the first day (AT under 24) or at
##                     world minute AT, its middle on bearing B (degrees, 0 east,
##                     90 south; with none, the bearing the view faces as it
##                     lights) and crossing the view; several are
##                     joined with commas; one lights again whenever the clock is
##                     put back before it; `:age=S` holds each fall S real
##                     seconds after it lit (one moment, for a frame); a
##                     trailing `:bench` measures what drawing them costs (render)
## --eye-round=DEG     stand that eye DEG degrees round the player from behind:
##                     180 looks the player in the face, 90 at their side
## --walk=DX,DY,SECS   scripted walk in SCREEN directions before the shot
## --run               the scripted walk runs
## --shot=PATH         capture one frame to PATH (png) and quit
## --frames=N          frames to wait after loading before the shot (default 8)
## --scale=N           upscale the shot N times, nearest (default 1)
## --scene=NAME        which scene to boot: game (default) | gallery | title | loading (the loading page, still)
## --place=NAME        start at a named place (GenPlaces): a country ("moss"), an
##                     ecotone ("coast-pinewood"), a landmark ("tip2"), "river", "cliff"
## --stats             print render stats (draw calls, chunk build times) before the shot
## --weather=KIND:S     force the weather (e.g. rain:1, fog:0.6, storm:1:bolt, dry_storm:1:bolt; kinds in Weather.KINDS), sky package;
##                     `:wind=W` also holds the wind at W, -1..1 (clear:0:wind=0.8)
## --lamp              start with the player's lantern lit, sky package
## --silhouette        gallery: machines (and the lineup's people) drawn flat black
## --filter=NAME       gallery: only the items whose name holds NAME
## --bearing=DEG       gallery: turn the camera DEG round the models. 0 is the play
##                     camera's own 45 degrees, 180 the half of a model this one
##                     fixed projection has never shown anybody
## --piece=N|list|all  gallery: one model's FOUND pieces numbered (size, place, the
##                     bearing that shows each, its colour), and N fills the frame
##                     with piece N from that bearing; `all` takes its timber in too.
##                     These three are read by src/gallery.gd itself and not parsed
##                     here: they are the review surface's, not the game's
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
## --fit=ID[,ID...]    wear this gear at start, given if not carried: a piece goes in
##                     its own slot, a module into the first slot it fits (hazards)
## --spawn=K[@DEG][,...] place these roster kinds in front of the player (fight shots/tests).
##                     `@DEG` turns one to a bearing instead of facing the player,
##                     for a frame that is about the MODEL: 0 east, 90 south, as
##                     --face. A yaw out of test_machines_silhouette.gd is `@-yaw`
##                     (Spawner.staged says why).
## --holding=KIND,...  stand a staffed holding in front of the player, free: lean-to,
##                     hearth, hut, store, plot, catchment, palisade, plate wall,
##                     netting, wind spinner, battery stack, radio mast (settlements)
## --attention=F       every holding (stood up at boot or built in play) starts F (0..1)
##                     of the way to a siege: 0.22 surveyed, 0.45 probed, 0.70 raided,
##                     1.0 the region's keeper. Nothing is sent until something reads it (raids)
## --carried=N         N people are already being held at the first depot of the plan,
##                     taken out of a village of that same region, so the region has
##                     somebody to ask him about (taken, story); with --holding, taken
##                     off the staged holding's books instead, to walk home to it
## --craft=KIND        park a craft (raft | hover_sled | walker_rig) in reach of the player (crafts)
## --aboard=KIND      park a craft and stand the player on it, ready to steer (crafts)
## --act=NAME[:MS]     play a fight moment and hold it for the shot: swing | grip | hurt | dodge | alert | windup
##                     (MS = simulation time after the press; each has a default);
##                     fx[:MS] draws every hit mark about the player, MS/1000 through its life
## --screen=NAME       open a slate app once loaded: inventory | crafting | map | pause | controls |
##                     loadout | reads | saves (these three over home) | sheet | journal; NAME:ROW chooses a row,
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
## --target[=sweep]    hold the target key at boot: a shot of a lock, or of the whole
##                     field swept (targeting)
## --read=ID           open a thing's words on the glass once loaded, by fragment id (story:
##                     a writer's view of a page, never a normal start)
## --talk=ID[:NODE]     open a conversation, at its start or at NODE (story, the same)
## --beats=ID,ID       land these story beats at boot, long since settled: a person who waits
##                     on one is there, and a reply that wants one is offered (story, the same)
## --fail-downed       a bad end (downed or carried off) quits the game with exit 1: a tour that
##                     must be survived through real play fails if it is not (fight)
## --rooms=empty      rooms come in without their residents (21_doors): a frame or
##                     a tour about how a room LOOKS, which its warden would
##                     otherwise end by putting the player out of it (interiors)
## --realm=KIND        start in that realm (surface | underground), beside its first
##                     shaft, or at --at read as a tile of THAT realm's world (realms)
## --quality=NAME      the graphics tier this run renders at (src/render/quality.gd):
##                     ultra | high | medium | low | web. Beats the player's own
##                     picture setting and the configuration, for this run only (render)
## --fore=N            how many FOREGROUND pieces may hang over the frame this run
##                     (src/render/depth/), instead of the tier's own `fore` row.
##                     0 turns the layer off, which is the ONLY way to take two
##                     frames of one moment with and without it and measure what
##                     it costs and what it hides (render)
## --config=NAME       the master configuration (configs/NAME.json) this run is made from: the
##                     island, a new game's start, the live rules; named options still win (dev)
## --dev[=PAGE]        dev mode reachable in a tool run; PAGE opens the dev app at a page
##                     (home here go time body give spawn view config builds proofs notes),
##                     PAGE:ROW chooses a row; readout puts the readout on the glass's edge (dev)

var seed_value := 1
var size := Tuning.WORLD_SIZE
var at := Vector2(-1, -1)
var village := -1
var hour := Tuning.START_HOUR
var zoom := 0.0
## Which PROJECTION the play camera uses: &"ortho" (the game as it ships) or
## &"persp", a third-person perspective lens. Opt-in and off by default, so
## every frame, tour and canon picture in the repository is unchanged.
var lens: StringName = &"ortho"
## Where the camera opens (41_shoulder), or &"" for the player's own setting.
var view: StringName = &""
## The staged eye (height, pitch down, vertical fov), or zero for none (96_eye).
var eye := Vector3.ZERO
## How fast the staged eye turns, degrees a second (96_eye).
var eye_turn := 0.0
## &"off" takes the colossi away for this run (19_colossi).
var colossi: StringName = &""
## "W@MINUTE": one walker alone at a staged minute of its walk, or "" (19_colossi).
var colossus := ""
## "off", "zenith@H" (19_orbit), or "" for the ring's own schedule.
var orbit := ""
## "off", "CLASS@AT[/B][,...][:bench]" (21_falls), or "" for the falls' own schedule.
var fall := ""
var eye_round := 0.0
var walk := Vector2.ZERO
var walk_seconds := 0.0
var run := false
var shot := ""
var frames := 8
## 1 since the base became 1920x1080: a shot is already the size a player sees,
## and doubling it wrote 3840x2160 frames — 56 MB for one canon run, and slower
## to open than to render. Someone reviewing a frame wants the game's own pixels,
## not more of them. Pass --scale=2 deliberately when a detail needs enlarging.
var scale := 1
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
## The body made on the character page (UiCharacterScreen), a PersonLook spec. Not a
## command-line option: the title fills it in when "begin" is pressed, and 33_avatar
## puts it on. Empty: `--look`, or the base body.
var avatar: Dictionary = {}
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
var fit: PackedStringArray = []
var spawn: PackedStringArray = []
## Pieces of a holding to stand in front of the player at boot (settlements).
var holding: PackedStringArray = []
## How far every holding starts along the plan's escalation, 0..1 (raids).
var attention := 0.0
## How many people the plan is already holding at boot (taken).
var carried := 0
## A craft parked in reach at boot, and one the player starts aboard (crafts).
var craft := ""
var aboard := ""
var act := ""
var screen := ""
var explore := 0
var ui_demo := false
var tour := ""
## Save slot to boot, or -1. SaveSlots.options_for fills seed, size, at and hour from it.
var load_slot := -1
## Arguments that could not be read as ONE option, said in words. Several
## options passed as a single quoted word ("--seed=4 --hour=11 ...") used to be
## read as `seed`, whose value `to_int` turned into 41101 -- every digit in the
## string -- while the hour, the sky and what is in hand fell back to defaults.
## A tour then ran on a different island with a knife in hand in the rain and
## failed at its first swing, and the frame looked like a bug under load
## (integ-cam, 2026-09-24). main.gd refuses to start on any of these.
var problems: PackedStringArray = []
var saves := ""
var progress := 0.4
var probe := false
var fail_downed := false
var rooms_empty := false
var target := false
var target_sweep := false
## A fragment to open on the glass, and a conversation (and the node in it) to open,
## once loaded: staging for a writer looking at the words (49_story).
var read := ""
var talk := ""
## Story beats landed before the first frame, as if long ago (49_story).
var beats := ""
## Which realm to start in (Realm.KINDS). The world a game opens with is always
## the surface's; the realms system crosses before the first frame.
var realm: StringName = &"surface"
## The graphics tier this run renders at (Quality.ROWS), or &"" to take whatever
## the player's picture setting, the configuration, or this machine decides.
var quality: StringName = &""
## How many foreground pieces may hang over the frame, or -1 to take the tier's
## own `fore` row. 0 is the layer off.
var fore := -1
var config := ""
var dev := false
var dev_page := ""


static func parse(args: PackedStringArray) -> BootOptions:
	var o := BootOptions.new()
	for a in args:
		if a.strip_edges().contains(" --"):
			o.problems.append("'%s' holds several options in one argument: pass each as its own word" % a)
			continue
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
			"lens": o.lens = StringName(v)
			"view": o.view = StringName(v)
			"eye":
				var p := v.split(",")
				o.eye = Vector3(p[0].to_float() if p[0] != "" else 1.7,
					p[1].to_float() if p.size() > 1 else 10.0,
					p[2].to_float() if p.size() > 2 else 60.0)
			"eye-turn": o.eye_turn = v.to_float()
			"colossi": o.colossi = StringName(v)
			"colossus": o.colossus = v
			"orbit": o.orbit = v
			"fall": o.fall = v
			"eye-round": o.eye_round = v.to_float()
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
			"realm": o.realm = StringName(v)
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
			"fit": o.fit = v.split(",", false)
			"spawn": o.spawn = v.split(",", false)
			"holding": o.holding = v.split(",", false)
			"attention": o.attention = clampf(v.to_float(), 0.0, 1.0)
			"carried": o.carried = maxi(0, v.to_int())
			"craft": o.craft = v
			"aboard": o.aboard = v
			"act": o.act = v
			"explore": o.explore = v.to_int()
			"ui-demo": o.ui_demo = true
			"tour": o.tour = v
			"load": o.load_slot = v.to_int()
			"saves": o.saves = v
			"progress": o.progress = v.to_float()
			"probe": o.probe = true
			"fail-downed": o.fail_downed = true
			"rooms": o.rooms_empty = v == "empty"
			"read": o.read = v
			"talk": o.talk = v
			"beats": o.beats = v
			"target":
				o.target = true
				o.target_sweep = v == "sweep"
			"quality": o.quality = StringName(v)
			"fore": o.fore = maxi(0, int(v.to_int()))
			"config": o.config = v
			"dev":
				o.dev = true
				o.dev_page = v
			_: push_warning("unknown option --%s" % k)
	return o
