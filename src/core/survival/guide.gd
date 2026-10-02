class_name Guide
## The first hour's guide, as pure rules over a running game: the one-line
## goal (what to want next) and the key hints, each with the moment it applies
## and the use that retires it. The guide system (58_guide) says them on the
## teaching channel (`Events.hint`), which is dropped rather than queued: a
## lesson is said in its moment or not at all, so 58_guide says nothing while
## the glass is hushed, and holds a lesson whose moment is "the fight is over"
## until it lifts. The slate shows `goal` standing on the HUD and the hint on
## its key row (90_ui).
##
##   goal(game) -> String                     the want now: food, his things back, light; the
##                                            edge a keeper rang off; the open story lead's
##                                            next step; else "" (see _goal_of)
##   within_reach(game) -> String             the long game's next material or part and where,
##                                            for the making page's "within reach" row; "" for none
##   hint_for(game, retired) -> Dictionary    the first hint that applies and is not retired:
##                                            {id: StringName, line: String, keys: Array} or {}
##   HINTS                                    id -> [line template, action names] for every hint
##
## Hints retire on use (58_guide marks them): walk (moved), take (took), fire
## (a fire made), make (something made at a station), carry (the carrying page
## opened), dodge (a dodge), side (a blow reached a working part), lamp (lit),
## runner/worker (said once when one is first in view).

## The four that are one lesson: shown joined, so they read as "WASD" while they
## are W, A, S and D and as whatever they become if somebody rebinds them.
const MOVE: Array[StringName] = [&"move_up", &"move_left", &"move_down", &"move_right"]

## id -> [line, actions]. The line carries `%s` where a KEY belongs and the
## actions say which, in order; a line with no `%s` still names its action so the
## slate's key row has something to draw.
##
## **THE KEY IS NAMED, NEVER SPELLED.** These lines used to carry the letters:
## "E takes what is in front of you", with "e" beside it for the key row. A
## player may rebind every action on the settings page, and `PlayerSettings` is
## careful that a PAGE can never drift from the live `InputMap` -- and then the
## first thing the game ever teaches them said E while their key was Q, in the
## first hour, to somebody with no way of knowing which to believe. The one place
## a lie like that costs the most is the one place it was.
const HINTS := {
	&"walk": ["%s walks, %s runs.", [MOVE, &"run"]],
	&"take": ["%s takes what is in front of you.", [&"use"]],
	&"fire": ["%s twice on open ground lays a fire.", [&"use"]],
	&"make": ["%s makes things at the fire. Long work cooks while you go.", [&"craft"]],
	&"carry": ["%s shows what you carry. Leave what you do not need.", [&"inventory"]],
	&"lamp": ["Night. %s lights the lamp.", [&"lamp"]],
	# **THE CORE VERB OF AN ACTION GAME, AND IT WAS NEVER NAMED.** `side` is the
	# only lesson that carries `swing`, it is the HELD lesson delivered after
	# plate has already rung, and its words ("strike the side that is lit")
	# assume you have been striking all along. Nothing anywhere told you which
	# key does it. Said as a machine comes on, ahead of the dodge, because a
	# player who cannot strike cannot end the fight they are being taught to
	# survive.
	&"fight": ["%s swings what is in your hands. Wait out its blow, then answer.", [&"swing"]],
	&"dodge": ["It winds up before it strikes: %s gets you out of the way.", [&"dodge"]],
	# **THE VERB THE GAME NEVER TAUGHT.** A player can press 27 things and the
	# guide named 11 of them; targeting was one of the sixteen it did not, which
	# means the whole read -- what a machine is, what it is doing, where its
	# plate is thin, whether it has noticed you -- was reachable only by somebody
	# who pressed an unmentioned key. Taught when the first machine is in view,
	# ahead of the lines that describe a runner and a worker, because it is how
	# you would find those out for yourself.
	&"target": ["%s holds the slate on it: what it is, what it is doing, where its plate is thin.", [&"target"]],
	# The other verb nobody was told about, and this one is INNATE: no gear
	# grants it and nothing takes it away, so a player who never learns it is
	# walking round ledges the game meant them to go over. Said standing at one,
	# because a movement lesson given on flat ground is a sentence about nothing.
	&"jump": ["%s clears it: up two, across two, down three, and no further.", [&"jump"]],
	# CLIMBING (mechanics improvement 5a): the same key, at a rock face too tall
	# to jump, ruled with a route up it. Said standing at one, facing it.
	&"climb": ["%s at a rock face climbs it. Every level costs breath; run out and you come down.", [&"jump"]],
	# The third of the sixteen, and the one the world's own size argues for: a
	# 1300-tile island is not a place you hold in your head. Said once the wake
	# is out of sight behind you, because a survey of ground you can see is a
	# picture of nothing.
	&"map": ["%s opens the survey: where you have walked, and what the machines have been doing to it.", [&"map"]],
	# The fourth, and the pair to `target`: you have learned to look at a machine,
	# now learn not to be looked at. Said with one in view that has NOT noticed
	# you, because that is the only moment crouching is a choice rather than a
	# regret.
	&"crouch": ["%s keeps you low and quiet. It has not seen you yet.", [&"crouch"]],
	# The fifth, and a whole pillar of the game nobody was told about (VISION
	# §9): a player can put a place up, keep it, and have the machines come for
	# it. Said the first time the creel actually holds enough for a piece --
	# before that it is an advertisement, and after the first piece goes up it
	# has taught itself.
	&"holding": ["%s puts a piece up out of the creel. What you build, the plan eventually hears.", [&"holding"]],
	# **THE SIXTH, AND THE WHOLE GEAR PILLAR WAS BEHIND AN UNMENTIONED KEY.**
	# Fitting a wing or a line or a stolen lens grants an ACTION, and nothing in
	# the game ever named it -- the same gap `target` was, and worse, because a
	# player went and found the piece, chose it, put it in a slot, and still had
	# no way to know what to press. One lesson per ability rather than one about
	# abilities: each names its own key and says what that key is FOR, because
	# "you have an ability" teaches nobody anything.
	&"ability_dash": ["%s throws you clear of what is coming. It costs breath.", [&"ability_dash"]],
	&"ability_glide": ["%s opens the wing. Step off something high and ride it down.", [&"ability_glide"]],
	&"ability_scan": ["%s reads every working part near you, and what each machine makes of you.", [&"ability_scan"]],
	&"ability_grapple": ["%s throws a line at what you face and pulls you to it, ledges included.", [&"ability_grapple"]],
	&"ability_spoof": ["%s answers their challenge in their own language. They read you as one of theirs.", [&"ability_spoof"]],
	&"ability_veil": ["%s lets the drip fall ahead of you: a curtain of water their eyes cannot see through.", [&"ability_veil"]],
	# The seventh, and the only app the guide never named. Everything found is
	# already being written down -- pages read, beats landed, answers given -- and
	# a player who is never told carries the whole story in their head or loses
	# it. Offered only once there IS something in it: a lesson that opens an
	# empty book teaches that the book is empty.
	&"journal": ["%s opens what you have found: what you read, what you were told, what you said back.", [&"journal"]],
	# **THE SAFE HAVEN, SAID WHEN YOU ARE STANDING IN ONE** (owner: "the game
	# needs guided narratives to start it, safe havens like towns to
	# systematically teach players the game"). The ground round a village really
	# is the safest in the game -- sixteen of nineteen roster rows keep a
	# `green_min` off it, which `Haven` writes down and a test holds -- and
	# nothing ever told the player so. A safety the player cannot know about
	# buys them nothing.
	&"haven": ["People live here, and nothing of the plan comes this close. Rest, make, and ask them things.", []],
	# **WHAT THE ROAD OUT WILL ASK FOR** (docs/DESIGN.md §Safe havens: "each haven
	# teaches what the road out of it will ask for"). The plan stands on the road
	# out of an unanswered chapter, and VISION §10.3 is emphatic that this is not
	# a lock -- there are three ways past and all three are real. A player who is
	# told none of them meets a barricade and reads it as a wall, which is the
	# message saying no that §10.3 forbids, wearing a model.
	&"road": ["The plan is standing on the road out. Cut it with a steel edge (%s), answer the place, or leave the road.", [&"use"]],
	&"side": ["Plate rings. Strike the side that is lit, while it is spent.", [&"swing"]],
	&"runner": ["A runner. It hunts. Its drive is at its back: let it bite past you, then strike behind.", []],
	&"worker": ["A worker on its round. Keep out of its path and it leaves you be.", []],
}

## Load over this share of the creel asks for the carrying page.
const CARRY_SHARE := 0.6
## Nightfall past which the lamp is asked for.
const LAMP_NIGHTFALL := 0.4
## Tiles within which a body counts as seen for its hint (the camera shows about 13 across).
const SIGHT := 13.0

## How far from the wake the survey earns itself. The camera shows about 27
## tiles of ground, so this is a little over two screens: far enough that the way
## back is no longer a thing you can see, which is the first moment a map is
## worth opening rather than a picture of what is already in front of you.
const MAP_FAR := 60.0

## How near a held road has to be before it is worth naming. A little over twice
## what the camera shows, so the lesson lands while walking toward the barricade
## rather than when it is already filling the frame and reading as a wall.
const ROAD_NEAR := 60.0


## The want after a bad end, while the bag lies where it was taken
## (Survival.leave_bag): standing on the HUD until it is taken back, so where
## the player's things are is never a line that scrolled past.
const BAG_GOAL := "Your things lie where it took you. The survey marks them."


## WHICH GOAL IT WAS: the key of the line `goal` last returned (StoryContent.LEAD
## or EDGE's, the same with or without the story's words), or &"" for a line
## with none. A tour claims it (`goal:KEY`, 90_ui) rather than matching words
## that change with the story and the fire's name.
static var last_goal_key := &""
static var _key := &""


static func goal(game: Game) -> String:
	_key = &""
	var line := _goal_of(game)
	last_goal_key = _key
	return line


## THE LINE IS HIS PURPOSE, NEVER A RECIPE FROM NOWHERE (owner: "the messages
## under the health bar don't make sense and are completely disconnected from
## the rest of the game"). In order: a real need while it is real (hunger, his
## things lying where he fell, the dark with a lamp unlit); the edge a keeper
## has rung off, since that fight is what he is doing; then the next step of the
## open story lead, keyed on story state and never on what the bag holds;
## otherwise nothing. A pick held only decides where Maren's errand stands, and
## any make of it will do: every better pick consumes the plain one, and the whole
## story used to vanish behind "a fire before dark" once one was made. The long
## game's recipe ladder (next_elite, next_part) is the making page's "within
## reach" row, not a goal.
static func _goal_of(game: Game) -> String:
	var inv := game.inventory
	var now := game.clock.minutes
	if game.body.hunger_level(now) >= 2:
		return "Eat something: mussels off the rocks, or berries."
	if not SurvivalState.of(game).bags.is_empty():
		return BAG_GOAL
	if FightRules.nightfall(game.clock.hour()) >= LAMP_NIGHTFALL and not game.body.lamp_lit and inv.has(&"lamp"):
		return "Light the lamp against the dark."
	# PEOPLE AT RISK BEFORE HIS OWN KIT: a raid warned on his holding
	# (Holding.RAIDED) puts shutters on its beds ahead of the pick, the plate and
	# the crew. Behind them, a player warned early heard only "coming for".
	if Holding.shutters_wanted(game) and StoryContent.LEAD.has(&"shutters"):
		_key = &"shutters"
		return String(StoryContent.LEAD[&"shutters"])
	var edge := edge_goal(game)
	if edge != "":
		return edge
	if not Story.landed(LEAD_BEAT):
		return ""
	if not has_pick(inv):
		return _first_hour(game)
	var reaper := reaper_goal()
	if reaper != "":
		return reaper
	var paid := Story.chose(CAMP_PAID) == StringName(StoryContent.PAID[CAMP_PAID].pick)
	if not paid:
		if Story.landed(REAPER_DOWN) and StoryContent.LEAD.has(&"crew"):
			_key = &"crew"
			return String(StoryContent.LEAD[&"crew"])
		if not inv.has(&"iron_ore") and not inv.has(&"iron"):
			return _led(&"ore", "Take the pick to the ore in the rock.")
		return camp_goal()
	var armour := armour_goal(game)
	if armour != "":
		return armour
	return way_goal(game)


## The picks that answer Maren's errand: the plain one and what it is made into.
const PICKS: Array[StringName] = [&"pick", &"pick_steel", &"pick_spar", &"pick_glass"]


static func has_pick(inv: Inventory) -> bool:
	for id in PICKS:
		if inv.has(id):
			return true
	return false


## Maren's errand, step by step: a fire, charcoal, a haft, plate, the pick.
static func _first_hour(game: Game) -> String:
	var inv := game.inventory
	var fire := _fire(game)
	if fire == null:
		if Survival._makeable_build(game, &"fire").is_empty():
			return _led(&"fire_gather", "A fire before dark: three driftwood and two stones.")
		return _led(&"fire_lay", "A fire before dark: lay it on open ground.")
	var at := fire_name(game, fire)
	if not _cooking_or_has(game, &"charcoal"):
		if inv.count(&"driftwood") < 4 and inv.count(&"deadwood") < 4:
			return _led(&"charcoal_gather", "Charcoal for a pick: four driftwood or dead wood, burnt at {at}.", at)
		# **NO KEY IN A GOAL LINE.** The goal says what to WANT; the `make`
		# lesson says which key, in the player's own keys, at this moment.
		return _led(&"charcoal_set", "Charcoal for a pick: set it going at {at}.", at)
	if not inv.has(&"haft"):
		return _led(&"haft", "A haft, whittled from wood.")
	if inv.count(&"scrap") == 0:
		return _led(&"plate", "Plate for a pick: turn over the tip.")
	return _led(&"pick", "A pick, made at {at}.", at)


## HOB'S ERRAND: once he has named the keeper (`reaper_named`) and until it
## falls, ending it is the want (LEAD `reaper`); once its plating has rung his
## edge off, edge_goal's steps say how.
const REAPER_DOWN := &"reaper_down"


## ROOK'S POINTER: paid and armoured while nobody has named what keeps the yard,
## and the yard's hop waits on its fall, the want is the tide-pickers who know it
## (LEAD `hob`, Rook's talk node `keeper`), until Hob has named it. Asked by
## way_goal after a holding's needs, which are people's and come first.
static func hob_goal() -> String:
	if not Story.landed(NAMED_BEAT) and not Story.landed(REAPER_DOWN) and StoryContent.LEAD.has(&"hob"):
		_key = &"hob"
		return String(StoryContent.LEAD[&"hob"])
	return ""


static func reaper_goal() -> String:
	if Story.landed(NAMED_BEAT) and not Story.landed(REAPER_DOWN) and StoryContent.LEAD.has(&"reaper"):
		_key = &"reaper"
		return String(StoryContent.LEAD[&"reaper"])
	return ""


## MAREN'S LEAD (ROADMAP slice 1, step 2): once she has given it (the beat
## `marens_lead`, her talk), the first hour's goals are said in her words, the
## short form of what she told him and why (StoryContent.LEAD), and the one after
## the pick points at the Holdfast's camp. Before she has, or for a player who
## never asks, the plain line: what to want, not why. `{at}` is the fire's name.
const LEAD_BEAT := &"marens_lead"


static func _led(key: StringName, plain: String, at: String = "") -> String:
	_key = key
	var line := plain
	if Story.landed(LEAD_BEAT) and StoryContent.LEAD.has(key):
		line = String(StoryContent.LEAD[key])
	return line.replace("{at}", at)


## THE ROAD TO THE CAMP (ROADMAP slice 2, step 1): with her lead given and iron
## in the bag, the want is the crew who pay for it (StoryContent.LEAD `camp`),
## until they have paid (CAMP_PAID in StoryContent.PAID): meeting Rook is not the
## promise kept, the pay is. Only once led: a player she never sent has no
## reason to go, and the survey marks the camp from her lead on
## (StoryContent.TOLD).
const CAMP_PAID := &"rook.iron"


static func camp_goal() -> String:
	var paid := Story.chose(CAMP_PAID) == StringName(StoryContent.PAID[CAMP_PAID].pick)
	if Story.landed(LEAD_BEAT) and not paid and StoryContent.LEAD.has(&"camp"):
		_key = &"camp"
		return String(StoryContent.LEAD[&"camp"])
	return ""


## PAID IN PLATE: once the crew have paid for the iron (StoryContent.PAID, Rook's
## `iron`), the want is the plate armour the pay is for (LEAD `armour`), until
## it is made, or a better piece of that kit is carried: the mended plate is made
## out of the plate it replaces (Recipes `plate_mended`).
static func armour_goal(game: Game) -> String:
	for at: StringName in StoryContent.PAID:
		var row: Dictionary = StoryContent.PAID[at]
		if Story.chose(at) == row.pick and not _carries_kit_of(game.inventory, row.makes) and StoryContent.LEAD.has(&"armour"):
			_key = &"armour"
			return String(StoryContent.LEAD[&"armour"])
	return ""


## Whether `inv` carries `id`, or any piece of the same kit (Items `kit`).
static func _carries_kit_of(inv: Inventory, id: StringName) -> bool:
	if inv.has(id):
		return true
	var kit: StringName = Items.def(id).get("kit", &"")
	if kit == &"":
		return false
	for other: StringName in inv.ids_in(Items.group(id)):
		if Items.def(other).get("kit", &"") == kit:
			return true
	return false


## THE WAY ON (ROADMAP slice 2): once the crew have paid, each hop of the
## Holdfast's chain is the want until the beat that ends it lands, so every beat
## of the slice is reached by the goal line alone. In order: the dark yard's
## screen (built_halcyon), back to Rook (holdfast_hope), Vera (war_archive), and
## the archive across the water until he has met the man there. Each hop's line
## is StoryContent.LEAD[key]. A hop opens on its `after` beat (`_hop_open`), and
## the first open hop not yet behind him is the goal: the order is the priority.
## A hop marked `last` is a leg's standing lead with nothing in this leg to end
## it: it waits behind the next keeper's lead (keeper_goal) as well, or a
## standing keeper named to him would never be said again.
const WAY: Array[Dictionary] = [
	{"key": &"yard", "after": &"reaper_down", "until": &"built_halcyon"},
	{"key": &"rook_again", "after": &"built_halcyon", "until": &"holdfast_hope"},
	{"key": &"vera", "after": &"holdfast_hope", "until": &"war_archive"},
	# Across the water (slice 3): a raft until one is carried or put in, the
	# narrows until he has stood on the far body, then the archive. Having met the
	# archive's man he has crossed, however he did, so that ends both as well.
	{"key": &"raft", "after": &"war_archive", "has": &"raft", "heard": [StoryCrossing.PUT_IN, StoryCrossing.CROSSED], "met": &"otto"},
	{"key": &"crossing", "after": &"war_archive", "heard": [StoryCrossing.CROSSED], "met": &"otto"},
	{"key": &"archive", "after": &"war_archive", "met": &"otto"},
	# THE ARCHIVE (slice 3 step 4). The man there met, one of the war's orders,
	# until he has been shown one (tradecraft), however it came.
	{"key": &"orders", "after": &"war_archive", "until": &"tradecraft"},
	# JUNE (slice 3 step 3). The archive's man met, the Covenant's seat, until the
	# Speaker is heard of (her own set is in the house nearest it); then her name,
	# which only somebody who left the Covenant will say (Imre); then June herself,
	# once her name has been felt and she is home to be found
	# (StoryCharacter.present), until he has met her; then back to her, once what
	# she always knew has been felt, for what the voice says.
	{"key": &"covenant", "after": &"war_archive", "until": &"covenant_speaker"},
	{"key": &"speaker", "after": &"covenant_speaker", "until": &"june_named"},
	{"key": &"june", "after": &"june_named", "felt": true, "met": &"june"},
	{"key": &"june_voice", "after": &"june_knew", "felt": true, "until": &"echo_kept"},
	# THE WARDEN. Once what the voice kept her from has settled (the Covenant's
	# revelations with it, so his reply is never held back), the warden, until he
	# says whose roads he is sold: nothing else leads to him, and Rook waits on it.
	{"key": &"warden", "after": &"echo_kept", "felt": true, "until": &"teague_sold"},
	# THE CLIMB (slice 3 step 7). Once Solis has said the road up (walker_told) and
	# his word on Teague has settled, the half-broken walker, until the enclave in
	# its crown is met: the far shore's last thread. Only where a crater of it lies
	# on the Covenant's body (`where`): the goal never sends him to another leg's.
	{"key": &"walker", "after": &"walker_told", "once": &"teague_sold", "where": &"crater:the_covenant", "until": &"enclave_met"},
	# BACK AT THE CAMP (slice 3 step 8). Once what the archive showed him has been
	# felt, the old soldier, until he has spoken to him since, whatever he said, so
	# the confession is never forced, or Dace is gone; once what the warden said of
	# Teague has been felt, Rook, until he has spoken to him since. Each leads him
	# to the person, never to the line. Neither opens before the warden's word is
	# felt (`once`), nor while the climb, once open, is still before him
	# (`behind`): sent home across the water while the far shore's threads
	# settle, he would only come back. In those hours the mend is the goal, else
	# the relay.
	{"key": &"camp_back", "after": &"tradecraft", "felt": true, "once": &"teague_sold", "behind": &"walker", "spoke": &"dace", "until": &"dace_left"},
	{"key": &"rook_teague", "after": &"teague_sold", "felt": true, "behind": &"walker", "spoke": &"rook", "until": &"rook_told"},
	{"key": &"mend", "after": &"covenant_fed", "has": &"plate_mended"},
	# The relay below, once Otto has said where the orders went (war_relay): slice
	# 4's lead, so nothing in this slice ends it.
	{"key": &"relay", "after": &"war_relay", "last": true},
]


static func way_goal(game: Game) -> String:
	if Story.chose(CAMP_PAID) != StringName(StoryContent.PAID[CAMP_PAID].pick):
		return ""
	# THE HOLDING (Holding): once the plan has taken somebody out of a village
	# that saw him, or he has seen the price, and until a holding of his stands,
	# that comes first. Nothing may explain the taking before it has happened, so
	# where only the price has landed it is said for a burned village instead.
	if Holding.wanted(game) and not Holding.stands(game) and StoryContent.LEAD.has(&"holding"):
		_key = &"holding"
		if not Holding.taken_from_seen(game):
			return String(StoryContent.HOLDING_MOVE["lead_burned"])
		return String(StoryContent.LEAD[&"holding"])
	# Then Rook's pointer, while the chain waits on a keeper nobody has named.
	var hob := hob_goal()
	if hob != "":
		return hob
	var last := &""
	for hop: Dictionary in WAY:
		if not _hop_open(game, hop) or _hop_done(game, hop) or not StoryContent.LEAD.has(hop.key):
			continue
		if bool(hop.get("last", false)):
			if last == &"":
				last = hop.key
			continue
		_key = hop.key
		return String(StoryContent.LEAD[hop.key])
	var keeper := keeper_goal(game)
	if keeper != "" or last == &"":
		return keeper
	_key = last
	return String(StoryContent.LEAD[last])


## THE LEGS HE CAN REACH (StoryJourney): the body ids of the journey's legs he
## can get to, so a lead never points where he cannot go. Home's before the raft;
## the far shore's (leg 1) from the crossing on: put in at the narrows, landed, or
## having met the archive's man there. A later leg joins when the journey reaches
## it. An islet off the journey (no village, no stop) is never one.
static func bodies_reached(game: Game) -> Array[int]:
	var legs := 1
	if Story.heard(StoryCrossing.PUT_IN) or Story.heard(StoryCrossing.CROSSED) or Story.met(&"otto"):
		legs = 2
	var out: Array[int] = []
	for leg in legs:
		var body := StoryJourney.body_for(game.world, leg)
		if body != 0 and not out.has(body):
			out.append(body)
	return out


## THE NEXT KEEPER (ROADMAP slice 2, step 6): once the Reaper is down and the way
## has nothing to ask, the nearest keeper of a design not yet taken
## (Sentinels.next_keeper), in the words of whoever named it (StoryContent.LEAD,
## keyed by its design), from the naming (KEEPER_NAMED_BY) until it falls. The
## words are the namer's reasons, so nothing says them before he has. It holds no
## key memory, so it never stands in the way's path, only after it.
static func keeper_goal(game: Game) -> String:
	if not Story.landed(REAPER_DOWN):
		return ""
	var next := Sentinels.next_keeper(Sentinels.live(game), game.world.spawn, game.world, bodies_reached(game))
	if next == null or not StoryContent.LEAD.has(next.design) \
			or not Story.landed(StringName(str(StoryContent.KEEPER_NAMED_BY.get(next.land, &"")))):
		return ""
	_key = next.design
	return String(StoryContent.LEAD[next.design])


## Whether a WAY hop has opened: its `after` beat has landed, and been felt where
## the hop says `felt` (a person who waits on a revelation is not there to be sent
## to until it has settled); its `once` beat, where it names one, has landed and
## been felt as well; the hop it is `behind`, where it names one, has not opened
## or is done; and its `where`, a place on this world (StoryMap.crater_pos), is.
static func _hop_open(game: Game, hop: Dictionary) -> bool:
	if not Story.landed(hop.after):
		return false
	if hop.has("once") and not StoryPacing.felt(hop.once):
		return false
	if bool(hop.get("felt", false)) and not StoryPacing.felt(hop.after):
		return false
	if hop.has("behind"):
		for other: Dictionary in WAY:
			if other.key == hop.behind and _hop_open(game, other) and not _hop_done(game, other):
				return false
	return not hop.has("where") or StoryMap.crater_pos(game, hop.where).is_finite()


## Whether a WAY hop is behind him: a beat landed (`until`), a person met (`met`),
## a person spoken to since its `after` beat landed (`spoke`), or, for the
## crossing, a thing carried (`has`) or something he did heard (`heard`).
static func _hop_done(game: Game, hop: Dictionary) -> bool:
	if hop.has("until") and Story.landed(hop.until):
		return true
	if hop.has("met") and Story.met(hop.met):
		return true
	if hop.has("spoke") and Story.spoke_since(hop.spoke, Story.landed_at(hop.after)):
		return true
	if hop.has("has") and game.inventory.has(hop.has):
		return true
	for key: StringName in hop.get("heard", []):
		if Story.heard(key):
			return true
	return false


## WHAT THE PINNED GOAL IS SHORT OF: the items the thing it asks him to make still
## wants, beyond what he carries, keyed by the goal (last_goal_key). The action
## prompt reads it to say what to hold for them (Survival.describe_target). A
## goal that makes nothing wants nothing here.
const GOAL_MAKES := {
	&"holding": {"piece": StructureKind.LEAN_TO},
	&"armour": {"recipe": &"kit_plate"},
	&"mend": {"recipe": &"plate_mended"},
}


## Reads the goal last pinned (last_goal_key, which 90_ui refreshes a few times a
## second), never the goal afresh: the action prompt asks every frame.
static func goal_wants(game: Game) -> Array[StringName]:
	var out: Array[StringName] = []
	if not GOAL_MAKES.has(last_goal_key):
		return out
	var makes: Dictionary = GOAL_MAKES[last_goal_key]
	var needs: Dictionary = {}
	if makes.has("piece"):
		needs = StructureKind.ROWS[int(makes.piece)].get("cost", {})
	elif makes.has("recipe"):
		needs = Crafting.recipe(StringName(makes.recipe)).get("needs", {})
	for item: StringName in needs:
		if game.inventory.count(item) < int(needs[item]):
			out.append(item)
	return out


## THE EDGE A KEEPER TAKES (SurvivalState.plates, FightRules.bites). Once a
## keeper's plating has rung the edge in hand off, the goal is the edge that bites
## it, in the order it is made on the home coast -- a kiln, charcoal, the knife
## tempered in it -- and then the keeper, until it falls. Said as the reason, not
## the recipe: the words are the short form of what the one who named the keeper
## told the player (docs/STORY.md; lines for story-wright).
const EDGE_KEEPER := {&"coast": "the reaper"}
const KILN_STONES := 8
const TEMPER_CHARCOAL := 4
## THE ONE WHO NAMED IT (ROADMAP slice 1, step 3): once Hob has told him what
## stands in the yard (the beat `reaper_named`), the lines are the short form of
## what he said (StoryContent.EDGE) and the keeper has the name he gave it
## (StoryContent.KEEPER_NAMED). A player who meets it before anyone has told him
## hears these, plain. `{who}` is the keeper's name, `{at}` the fire's.
const NAMED_BEAT := &"reaper_named"
const EDGE_PLAIN := {
	&"steel_in_hand": "Steel in hand now. Take it to {who}.",
	&"tempering": "The knife is taking its temper in the kiln. Let it.",
	&"kiln_stones": "Iron rings off {who}; steel bites. A kiln to temper the knife: eight stones.",
	&"kiln_lay": "Iron rings off {who}; steel bites. Lay the kiln to temper the knife.",
	&"fire_for_charcoal": "A fire to burn charcoal: the knife's temper wants four.",
	&"charcoal_at": "Four charcoal to temper the knife, burnt at {at}.",
	&"temper": "Temper the knife in the kiln: four charcoal, and the night.",
	&"rings": "It rings. Iron does not bite that plate.",
}


## The keeper of `land` by the name the player has for it.
static func keeper_name(land: StringName) -> String:
	if Story.landed(StringName(str(StoryContent.KEEPER_NAMED_BY.get(land, &"")))) and StoryContent.KEEPER_NAMED.has(land):
		return String(StoryContent.KEEPER_NAMED[land])
	return String(EDGE_KEEPER.get(land, "the keeper"))


## One of the edge's lines: Hob's once he has named the keeper, else plain.
static func edge_line(key: StringName, who: String = "", at: String = "") -> String:
	_key = key
	var line := String(EDGE_PLAIN.get(key, ""))
	if Story.landed(NAMED_BEAT) and StoryContent.EDGE.has(key):
		line = String(StoryContent.EDGE[key])
	return line.replace("{who}", who).replace("{at}", at)


static func edge_goal(game: Game) -> String:
	var st := SurvivalState.of(game)
	for plate: Variant in st.plates:
		var who := keeper_name(StringName(st.plates[plate]))
		if _carries_edge(game, StringName(plate)):
			return edge_line(&"steel_in_hand", who)
		var inv := game.inventory
		if _cooking_or_has(game, &"knife_shear"):
			return edge_line(&"tempering", who)
		if _kiln(game) == null:
			if inv.count(&"stone") < KILN_STONES:
				return edge_line(&"kiln_stones", who)
			return edge_line(&"kiln_lay", who)
		if not _cooking_or_has(game, &"charcoal") or inv.count(&"charcoal") < TEMPER_CHARCOAL:
			var fire := _fire(game)
			if fire == null:
				return edge_line(&"fire_for_charcoal", who)
			return edge_line(&"charcoal_at", who, fire_name(game, fire))
		return edge_line(&"temper", who)
	return ""


## Whether the bag holds an edge that bites plating of `plate`.
static func _carries_edge(game: Game, plate: StringName) -> bool:
	var row := {"plating": plate}
	for id: StringName in game.inventory.items:
		if Items.def(id).has("swing") and FightRules.bites(row, id):
			return true
	return false


## A kiln near: one laid by the player, or one standing in the world.
static func _kiln(game: Game) -> WorldProp:
	var kinds: Array[int] = [PropKind.KILN]
	var best := game.query.nearest_prop(game.player.pos, FIRE_NEAR + 1.0, kinds)
	for q in SurvivalState.of(game).built:
		if q.kind == PropKind.KILN and not game.world.depleted.has(q.id):
			if best == null or q.pos.distance_to(game.player.pos) < best.pos.distance_to(game.player.pos):
				best = q
	return best


## THE LONG GAME, ON THE MAKING PAGE: the next part a room keeps once its
## material is held, else the next elite material and where it is. Never the goal
## line: nobody pointed him at these, so pinned there they read as a recipe out
## of nowhere.
static func within_reach(game: Game) -> String:
	var part := next_part(game)
	if part != &"":
		return part_goal(part)
	var want := next_elite(game)
	return elite_goal(game, want) if want != &"" else ""


## The elite material wanted next (EliteStock): the first the bag holds none of
## that the world has a way to (Sources.reachable), and of those, one the land
## underfoot gives before any other, so the long game starts where the player
## stands. &"" once every one has been held.
static func next_elite(game: Game) -> StringName:
	var here := _land_here(game)
	var first := &""
	for id: Variant in EliteStock.ids():
		var sid := StringName(id)
		if game.inventory.has(sid) or not Sources.reachable(sid):
			continue
		if _elite_lands(sid).has(here):
			return sid
		if first == &"":
			first = sid
	return first


## THE PARTS A ROOM KEEPS, in the long game: a thing kept in one kind of room
## (Interiors.LOOT), wanted once the elite material it `follows` is held -- the
## burning's glass first, then what the burning's foundry casts, which is what a
## cast lance is built on (recipes `lance_cast`).
const PARTS := {
	&"lance_casting": {"room": &"foundry", "follows": &"cinder_glass"},
}


## The part wanted next: one the bag lacks whose material it holds. &"" for none.
static func next_part(game: Game) -> StringName:
	for id: Variant in PARTS:
		var row: Dictionary = PARTS[id]
		if not game.inventory.has(StringName(id)) and game.inventory.has(StringName(row.follows)):
			return StringName(id)
	return &""


## Where a part is kept, said as the long game's goals say it: "Lance casting:
## kept in the foundry, in the burning."
static func part_goal(id: StringName) -> String:
	var row: Dictionary = PARTS[id]
	var name := String(Items.def(id).get("name", String(id).replace("_", " ")))
	var lands := Interiors.lands_of(StringName(row.room))
	var where := ", %s" % _land_said(lands[0]) if not lands.is_empty() else ""
	return "%s: kept in the %s%s." % [name.left(1).to_upper() + name.substr(1), String(row.room).replace("_", " "), where]


## The landscapes an elite material comes from: its own, or the lands its one
## machine keeps to.
static func _elite_lands(id: StringName) -> Array[StringName]:
	var land := EliteStock.land_of(id)
	if land != &"":
		return [land] as Array[StringName]
	var kind := EliteStock.kind_of(id)
	return Sources.lands_of_kind(kind) if kind != &"" else [] as Array[StringName]


static func _land_here(game: Game) -> StringName:
	var p: Vector2 = game.player.pos if game.player != null else game.world.spawn
	return BiomeRegistry.by_index(game.world.country_at(floori(p.x), floori(p.y))).id


## The late goal's words: what it is, how it is had, and where. One line on
## the glass's goal window, which stands left of the place name at the top, so
## it is kept to the length of the first hour's goals and says no more.
static func elite_goal(game: Game, id: StringName) -> String:
	var def := EliteStock.material(id)
	var name := String(Items.def(id).get("name", String(id).replace("_", " ")))
	# Where: here, if the land underfoot gives it; else the first land that does.
	var all := _elite_lands(id)
	var here := _land_here(game)
	var where := ""
	if all.has(here):
		where = "here %s" % _land_said(here)
	elif not all.is_empty():
		where = _land_said(all[0])
	var kind := EliteStock.kind_of(id)
	var how := ""
	if kind != &"":
		how = "cut out of a %s, %s" % [String(kind).replace(".", " "), where]
	else:
		how = "%s at a %s, %s" % [String(def.get("raw", "")).replace("_", " "), String(def.get("at", "fire")), where]
	return "%s: %s." % [name.left(1).to_upper() + name.substr(1), how.strip_edges()]


## A landscape as the goal says someone is in it: its own words (BiomeDef.spoken_in).
static func _land_said(id: StringName) -> String:
	var b := BiomeRegistry.get_def(id)
	return b.spoken_in if b != null and b.spoken_in != "" else "in the %s" % String(id).replace("_", " ")


## The first lesson that fits and has not been spent. `keyed_only` asks for the
## first that NAMES A KEY, which is what the slate's key row wants: several
## lessons carry no key of their own (`runner`, `worker`, `haven` -- they are
## things to know, not things to press), and the row is drawn from whatever this
## answers, so a keyless lesson standing at the front of the list blanked the row
## until the guide got round to saying it. Two different questions, one door.
static func hint_for(game: Game, retired: Dictionary, keyed_only := false) -> Dictionary:
	for id: StringName in _applicable(game):
		if keyed_only and (HINTS[id][1] as Array).is_empty():
			continue
		if not retired.has(id):
			# The line is a TEMPLATE and the actions are names: whoever says it
			# resolves them against the live keys (58_guide), because a key label
			# is the settings package's to answer and core does not read it.
			return {"id": id, "line": HINTS[id][0], "keys": HINTS[id][1]}
	return {}


## The hints that fit the moment, most pressing first.
## Whether the plan is standing on a road the player could walk to from here.
## Asked of whoever KEEPS the holds rather than derived again: `RoadHold.sites`
## walks every road in the world, and a lesson is not worth that on any frame.
static func _road_is_held(game: Game) -> bool:
	if game == null or game.player == null:
		return false
	for sys in game.systems:
		if sys.has_method(&"held_road_near"):
			return bool(sys.call(&"held_road_near", game.player.pos, ROAD_NEAR))
	return false


## The gear system's ability book, found BY WHAT IT KEEPS and never by its name
## -- the idiom `Chapters` uses, and the reason renumbering a system file has
## never broken anything. Null in a fixture with no systems, which is correct:
## nothing has been fitted there.
static func ability_book(game: Game) -> AbilityBook:
	if game == null:
		return null
	for sys: GameSystem in game.systems:
		var book: Variant = sys.get(&"book")
		if book is AbilityBook:
			return book
	return null


## Every ability the GEAR has granted -- innate ones left out, because the jump
## has its own lesson and is not a thing the player chose.
static func granted(game: Game) -> Array[StringName]:
	var out: Array[StringName] = []
	var book := ability_book(game)
	if book == null:
		return out
	for id: StringName in book.fitted:
		if not Abilities.INNATE.has(id):
			out.append(id)
	return out


## Whether anything has been written down yet: a page read, a beat landed, or an
## answer given. The journal only ever READS what already happened, so this asks
## `Story` -- who WROTE IT DOWN -- rather than looking for evidence in the live
## world, which is the rule this file's own lessons are built on.
static func _journal_holds_something() -> bool:
	return Story.found_count() > 0 or not Story.landed_beats().is_empty() or not Story.choices().is_empty()


## Whether the creel holds enough for any piece somebody has learnt to build.
## Asked of `SettlementBuild.can_make`, which is the same question the holding
## page answers, so the lesson cannot offer a key that would refuse.
static func _can_build(game: Game) -> bool:
	if game.inventory == null:
		return false
	for kind: int in StructureKind.BUILDABLE:
		if SettlementBuild.can_make(game.inventory, kind):
			return true
	return false


## Whether a jump from where the player stands, the way they face, would CLEAR
## something -- a ledge up or a gap across. Asked of `Jump.plan`, which works the
## whole arc out, so the lesson cannot promise a jump the body could not make:
## the same answer the key itself will give when it is pressed.
static func _at_a_ledge(game: Game) -> bool:
	var sim := game.player.sim if game.player != null else null
	if sim == null or game.query == null or sim.hero.airborne:
		return false
	# `Jump.CARRY`, which is the speed `Jump.find` plans at -- the game's own
	# idea of a jump taken at a walk. Planning at a STANDING speed instead was
	# the first version and it answered "hop" at ledges the finder calls a
	# climb, so the lesson was never said anywhere: the moment and the thing
	# that defines a ledge have to ask the same question.
	var p := Jump.plan(game.world, game.query, sim.hero.pos,
		Vector2.from_angle(sim.hero.facing), Jump.CARRY)
	return p != null and (p.kind == Jump.UP or p.kind == Jump.ACROSS)


## Facing a rock face too tall to jump, near enough to see the route up it.
static func _at_a_face(game: Game) -> bool:
	var sim := game.player.sim if game.player != null else null
	if sim == null or game.query == null or sim.hero.airborne:
		return false
	var f := Climb.face(game.world, game.query, sim.hero.pos, Vector2.from_angle(sim.hero.facing), 2.2)
	return not f.is_empty() and int(f.to_level) - int(f.from_level) > Jump.UP_LEVELS


static func _applicable(game: Game) -> Array[StringName]:
	var out: Array[StringName] = []
	var sim := game.player.sim if game.player != null else null
	if sim != null:
		for m in sim.mobs:
			if not m.alive or m.removed:
				continue
			# Said as a hunter first comes on, before it is close enough to hush the page
			# (a line said in a fight waits until it is over, out of its moment).
			if m.machine and not m.indifferent() and m.roused() and Senses.chebyshev(m.pos, sim.hero.pos) > Survival.THREAT_RADIUS:
				out.append(&"fight")
				out.append(&"dodge")
			var seen := m.pos.distance_to(sim.hero.pos) <= SIGHT
			if seen and m.machine:
				out.append(&"target")
			if seen and m.machine and not m.roused() and not game.body.crouched:
				out.append(&"crouch")
			if seen and m.first_meeting and not m.roused():
				out.append(&"runner")
			if seen and m.patrol and m.indifferent():
				out.append(&"worker")
	if FightRules.nightfall(game.clock.hour()) >= LAMP_NIGHTFALL and not game.body.lamp_lit and game.inventory.has(&"lamp"):
		out.append(&"lamp")
	if game.inventory.bulk() > game.inventory.creel() * CARRY_SHARE:
		out.append(&"carry")
	for id: StringName in granted(game):
		out.append(StringName("ability_%s" % id))
	if _can_build(game):
		out.append(&"holding")
	if game.world != null and game.player != null and Haven.holds(game.world, game.player.pos):
		out.append(&"haven")
	if _road_is_held(game):
		out.append(&"road")
	if _journal_holds_something():
		out.append(&"journal")
	if game.world != null and game.player != null \
			and game.player.pos.distance_to(game.world.spawn) > MAP_FAR:
		out.append(&"map")
	if _at_a_face(game):
		out.append(&"climb")
	if _at_a_ledge(game):
		out.append(&"jump")
	if Survival.use_target(game) != null:
		out.append(&"take")
	if _fire(game) == null and not Survival._makeable_build(game, &"fire").is_empty():
		out.append(&"fire")
	if Survival.station_near(game) != &"":
		out.append(&"make")
	out.append(&"walk")
	return out


## The fire the goal means: the nearest of the fires the player built and any
## fire within FIRE_NEAR tiles (a village's), or null.
const FIRE_NEAR := 12.0


static func _fire(game: Game) -> WorldProp:
	var best := Survival.fire_near(game, FIRE_NEAR)
	var p := game.player.pos
	for q in SurvivalState.of(game).built:
		if q.kind != PropKind.FIRE or game.world.depleted.has(q.id):
			continue
		if best == null or q.pos.distance_to(p) < best.pos.distance_to(p):
			best = q
	return best


## Where the goal sends the player, by name: "the village fire" (a fire in a
## village), "your fire" (one the player laid), else "the fire".
static func fire_name(game: Game, fire: WorldProp) -> String:
	if fire == null:
		return "a fire"
	if Haven.holds(game.world, fire.pos):
		return "the village fire"
	if SurvivalState.of(game).built.any(func(q: WorldProp) -> bool: return WorldProp.same(q, fire)):
		return "your fire"
	return "the fire"


static func _cooking_or_has(game: Game, id: StringName) -> bool:
	if game.inventory.has(id):
		return true
	for job in Survival.cooking(game):
		if (job.makes as Dictionary).has(id):
			return true
	return false
