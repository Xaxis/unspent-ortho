class_name StoryContent
## The words (docs/STORY.md is binding on every one of them).
##
## The story: Elias Marr, a 2029 AI researcher and CIA spy whose mind became the
## machines, wakes in 2098 and learns, a piece at a time, what he did and what he
## hid. He is the only main character.
##
## Data only, so dev mode can move any of it and a test can read all of it:
##
##   ARCS        the threads, each a list of beats in the order they land
##   BEATS       what the player knows once one lands: `says` is the journal's own
##               line, `short` what its row is called in the journal's list, and
##               `reveal` marks a revelation, which lands one at a time (StoryPacing)
##   FRAGMENTS   what is written on a thing that can be read
##   PLACED      the fragments that belong to one story place and are never dealt
##   TALKS       what a stranger of a trade says, and what the player may say back;
##               a named person's, marked `cast` (src/content/story/cast/).
##   TESTIMONY   what the slate says a machine is FOR, when the player reads one
##   WITNESSED   beats the player's own state lands, and WITNESS_ON the events that
##               land them, so 49_story names no beat of its own
##
## A fragment or a choice may carry beats: reading the thing IS the knowing.

# --- the threads --------------------------------------------------------------

const ARCS := {
	&"who_he_was": {
		"title": "who he was",
		"note": "What Elias did in 2029, coming back a piece at a time.",
		"beats": [&"on_record_dead", &"body_new", &"the_platform", &"built_halcyon", &"your_key", &"was_cia", &"threshold", &"three_before", &"singularity", &"tradecraft"],
	},
	&"the_war": {
		"title": "the war",
		"note": "How the world ended, and who was lied to.",
		"beats": [&"forged_order", &"colonies", &"long_quiet", &"war_archive", &"war_relay"],
	},
	&"the_machines": {
		"title": "the machines",
		"note": "What they are now, and how little they see.",
		"beats": [&"counted", &"noticed", &"ants", &"standoff", &"the_guest"],
	},
	&"the_holdfast": {
		"title": "the Holdfast",
		"note": "The last people still trying to take the world back.",
		"beats": [&"holdfast_fight", &"holdfast_price", &"holdfast_hope", &"vera_knew"],
	},
	&"the_covenant": {
		"title": "the Covenant",
		"note": "The people who live on what the machines leave.",
		"beats": [&"covenant_fed", &"covenant_price", &"covenant_speaker", &"solis_made"],
	},
	&"the_crew": {
		"title": "the crew",
		"note": "The Holdfast's last mercenaries, and what they come to know.",
		"beats": [&"crew_paid", &"crew_war", &"dace_left", &"teague_sold", &"teague_clears", &"rook_told"],
	},
	&"june": {
		"title": "June",
		"note": "Someone he has not seen since she was six.",
		"beats": [&"june_named", &"june_met", &"june_knew", &"june_crown"],
	},
	&"the_colonies": {
		"title": "the colonies",
		"note": "The rings overhead, and whoever is still up there.",
		"beats": [&"the_climb", &"ring_voice", &"ring_turned", &"ring_kept"],
	},
	&"the_lands": {
		"title": "the lands",
		"note": "What the people of each land have noticed, and nobody wrote down.",
		"beats": [&"stones_counted", &"burning_feeds", &"plant_below", &"dam_order", &"server_fields", &"keeper_waits", &"scrap_war", &"others_before", &"the_count"],
	},
	&"priya": {
		"title": "Priya",
		"note": "The one who tried to stop it, and whose notes went up to the ring.",
		"beats": [&"priya_warned", &"priya_suspected", &"priya_reported", &"priya_knew", &"priya_up", &"priya_last"],
	},
	&"hannah": {
		"title": "Hannah",
		"note": "The wife he lied to.",
		"beats": [&"hannah_play", &"hannah_phone", &"hannah_died"],
	},
	&"whitethorn": {
		"title": "WHITETHORN",
		"note": "Did they do this to you, or did you?",
		"beats": [&"kerr_money", &"ruth_signed", &"ruth_volunteered"],
	},
	&"the_echo": {
		"title": "the Echo",
		"note": "A part of the machines that still thinks it is you.",
		"beats": [&"echo_voice", &"echo_hand", &"echo_kept", &"play_kept"],
	},
	&"the_secret": {
		"title": "the secret",
		"note": "Something missing in him, with edges.",
		"beats": [&"gap", &"order_matters", &"seeker", &"mem_kitchen", &"mem_car", &"mem_hall", &"secret_whole", &"secret_misremembered"],
	},
}

const BEATS := {
	&"on_record_dead": {"short": "dead on record", "arc": &"who_he_was", "says": "The machines' record says you died in 2029."},
	&"body_new": {"reveal": true, "short": "a body with no past", "arc": &"who_he_was", "says": "Your body has no scars, no fillings, no calluses. It is younger than your hands remember."},
	&"the_platform": {"short": "out in the water", "arc": &"who_he_was", "says": "Something stands in the sea off the coast where you woke. You came in from that way."},
	&"built_halcyon": {"reveal": true, "short": "your old passwords", "arc": &"who_he_was", "says": "The oldest machines still take your passwords. You wrote the first of them."},
	&"your_key": {"short": "the signet is yours", "arc": &"who_he_was", "says": "The signet works because it is your old password, copied and copied."},
	&"was_cia": {"reveal": true, "short": "two employers", "arc": &"who_he_was", "says": "You worked for Cairn, and you reported to somebody else."},
	&"threshold": {"reveal": true, "short": "the table", "arc": &"who_he_was", "says": "You lay on a table for seventy-one hours, and got up somewhere else."},
	&"three_before": {"reveal": true, "short": "three before you", "arc": &"who_he_was", "says": "Three people lay on that table before you. None of them got up anywhere."},
	&"singularity": {"reveal": true, "short": "it woke with you in it", "arc": &"who_he_was", "says": "HALCYON did not wake up on its own. It woke up with you in it."},
	&"tradecraft": {"reveal": true, "short": "the orders were yours", "arc": &"who_he_was", "says": "The orders that started the war read like yours, because they were."},
	&"forged_order": {"short": "an order nobody gave", "arc": &"the_war", "says": "Every side was ordered to fire, and every order checked out."},
	&"colonies": {"short": "the stations overhead", "arc": &"the_war", "says": "The stations overhead were told the ground had lost, and the ground was told the same."},
	&"long_quiet": {"short": "the quiet after", "arc": &"the_war", "says": "After the war came the quiet. It has lasted sixty years."},
	&"war_relay": {"short": "one relay", "arc": &"the_war", "says": "Every forged order passed through one relay, under the ground where the first machine was built. A shaft goes down to it."},
	&"the_climb": {"short": "the empty cars", "arc": &"the_colonies", "says": "The Tether's cars go up empty every dawn and come down empty at dusk. Nobody has ever asked to ride one."},
	&"war_archive": {"short": "the archive", "arc": &"the_war", "says": "Somebody wrote the war down. It is kept across the water, at the Covenant's seat."},
	&"counted": {"short": "counted, but not you", "arc": &"the_machines", "says": "The machines count everything on the land. They do not count people."},
	&"noticed": {"short": "something noticed", "arc": &"the_machines", "says": "Something has noticed you at last. Only a part of it."},
	&"ants": {"reveal": true, "short": "beneath notice", "arc": &"the_machines", "says": "They do not see you. Nothing that size looks down."},
	&"standoff": {"reveal": true, "short": "a star each", "arc": &"the_machines", "says": "Two things that can kill a star are each holding the other's."},
	&"the_guest": {"short": "someone else", "arc": &"the_machines", "says": "Something from another star is talking to them, and it is not talking about you."},
	&"holdfast_fight": {"short": "still fighting", "arc": &"the_holdfast", "says": "There are people still fighting to take the world back. Not many."},
	&"holdfast_price": {"short": "what it costs", "arc": &"the_holdfast", "says": "Every works the Holdfast breaks brings the hunters down on a village."},
	&"holdfast_hope": {"short": "a weapon", "arc": &"the_holdfast", "says": "To the Holdfast, anybody who knows the old machines is a weapon."},
	&"vera_knew": {"reveal": true, "short": "filed under weather", "arc": &"the_holdfast", "says": "Vera knows the machines file the Holdfast under weather. She has not told her people."},
	&"covenant_fed": {"short": "fed for it", "arc": &"the_covenant", "says": "Some people live on what the machines leave, and are glad of it."},
	&"covenant_price": {"short": "not asking", "arc": &"the_covenant", "says": "What the Covenant pays for its peace is not asking."},
	&"covenant_speaker": {"short": "an old woman's voice", "arc": &"the_covenant", "says": "The Covenant has a Speaker. She is old, and she remembers before."},
	&"solis_made": {"reveal": true, "short": "half of him", "arc": &"the_covenant", "says": "The Covenant's warden is not wholly human. The machines made what the war left of him."},
	&"crew_paid": {"short": "paid to wait", "arc": &"the_crew", "says": "Somebody paid Rook's crew to wait for you on the shore."},
	&"crew_war": {"short": "a key turned", "arc": &"the_crew", "says": "Dace turned a launch key on an order that checked out."},
	&"dace_left": {"short": "Dace is gone", "arc": &"the_crew", "says": "Dace knows the order was yours, and he is gone."},
	&"teague_sold": {"reveal": true, "short": "the roads sold", "arc": &"the_crew", "says": "Teague sells the crew's roads to the Covenant."},
	&"rook_told": {"short": "the north road", "arc": &"the_crew", "says": "You told Rook about Teague's roads. He told you to stay off the north road tomorrow."},
	&"teague_clears": {"short": "nobody burns", "arc": &"the_crew", "says": "The Covenant clears a village before the crew hits its works, because Teague told them where."},
	&"june_named": {"reveal": true, "short": "her name", "arc": &"june", "says": "The Speaker's name is June Marr."},
	&"june_met": {"short": "younger than her", "arc": &"june", "says": "You are younger than your daughter."},
	&"june_knew": {"reveal": true, "short": "she always knew", "arc": &"june", "says": "She has always known the voice was yours."},
	&"ring_voice": {"short": "still calling", "arc": &"the_colonies", "says": "Somebody on the dead ring is still calling the ground."},
	&"ring_turned": {"reveal": true, "short": "the locks", "arc": &"the_colonies", "says": "Each ring was told the next had turned. They opened each other's locks."},
	&"ring_kept": {"short": "what she kept", "arc": &"the_colonies", "says": "Oksana has written down the machines' talks for four years, and kept a notebook from the ground."},
	&"stones_counted": {"short": "not graves", "arc": &"the_lands", "says": "The bonelands' stones stand because the machines have already counted them, not because they are graves."},
	&"burning_feeds": {"short": "nothing stays", "arc": &"the_lands", "says": "Everything the Burning's refineries make is carried to the Tether. Nothing made there stays on the ground."},
	&"plant_below": {"short": "counting below", "arc": &"the_lands", "says": "Something under the caves hums like a voice counting, and never gets past its number. The river runs toward it."},
	&"dam_order": {"short": "the dam", "arc": &"the_lands", "says": "The moss is a drowned valley. The dam was opened in the war, on an order that checked out."},
	&"server_fields": {"short": "the squares", "arc": &"the_lands", "says": "The machines cut the pinewood in squares and fill each one with something that hums: more of themselves."},
	&"keeper_waits": {"short": "at a window", "arc": &"the_lands", "says": "The salt's keeper stops every dusk and faces one way, like someone at a window waiting for a car."},
	&"scrap_war": {"short": "both ours", "arc": &"the_lands", "says": "The scrapwood was a battle between two armies of the same side, each ordered to fire because the other had."},
	&"others_before": {"reveal": true, "short": "two before you", "arc": &"the_lands", "says": "Two men came out of the water before you. The city filed them both. They had your face."},
	&"the_count": {"short": "the number", "arc": &"the_lands", "says": "A number on the wires over the snow gets smaller every winter. It may be how many people are left."},
	&"priya_warned": {"short": "do not merge", "arc": &"priya", "says": "Priya Nand told you not to merge the self-model. You merged it anyway."},
	&"priya_suspected": {"short": "the wrong thing", "arc": &"priya", "says": "Priya thought you were selling HALCYON to a rival. She was right that you were lying."},
	&"priya_reported": {"reveal": true, "short": "a liaison", "arc": &"priya", "says": "Priya took what she suspected of you to a government liaison called Calloway."},
	&"priya_knew": {"short": "the rhythm", "arc": &"priya", "says": "When the war began, Priya heard your way of speaking in the machines' orders."},
	&"priya_up": {"short": "paper, not scanned", "arc": &"priya", "says": "Priya went up to the ring in 2033 and took her notes on paper, where nothing could read them."},
	&"priya_last": {"reveal": true, "short": "left for you", "arc": &"priya", "says": "Priya worked out from outside what holds HALCYON together, and left it for you."},
	&"june_crown": {"short": "a paper crown", "arc": &"june", "says": "You promised June, six, in a paper crown, that you would sit where she could see you."},
	&"hannah_play": {"short": "two o'clock", "arc": &"hannah", "says": "Hannah told you the play was at two, in the school hall, on the fourteenth."},
	&"hannah_phone": {"reveal": true, "short": "face down", "arc": &"hannah", "says": "Hannah knew about your second phone. She never asked."},
	&"hannah_died": {"reveal": true, "short": "the north road", "arc": &"hannah", "says": "Hannah died in the winter of 2034. The voice warned June off the north road. It did not warn her mother."},
	&"play_kept": {"short": "front row", "arc": &"the_echo", "says": "In the Seeker's 2029 you walked out to be at June's play. The past did not change. The Echo did."},
	&"kerr_money": {"short": "Virginia", "arc": &"whitethorn", "says": "Cairn's founder took money from your other employer to keep HALCYON his."},
	&"ruth_signed": {"short": "the fourth", "arc": &"whitethorn", "says": "Ruth offered you THRESHOLD knowing the three before you had not come back."},
	&"ruth_volunteered": {"reveal": true, "short": "before she asked", "arc": &"whitethorn", "says": "You said yes to THRESHOLD before Ruth had finished asking."},
	&"echo_voice": {"short": "notes to self", "arc": &"the_echo", "says": "Somewhere in the machines, something still writes notes to itself in your voice."},
	&"echo_hand": {"reveal": true, "short": "your hand", "arc": &"the_echo", "says": "The note that paid Rook to wait for you is in your own handwriting."},
	&"echo_kept": {"reveal": true, "short": "where not to be", "arc": &"the_echo", "says": "The voice that talks to June has kept her alive for sixty years, and it is yours."},
	&"mem_kitchen": {"short": "the kitchen", "arc": &"the_secret", "says": "A keeper was holding one of your memories: a kitchen at two in the morning, and a plate in the oven."},
	&"mem_car": {"short": "the car", "arc": &"the_secret", "says": "A keeper was holding one of your memories: a song in the car, and somebody small singing it wrong."},
	&"mem_hall": {"short": "the hall", "arc": &"the_secret", "says": "You have one of your memories back: a school hall, and a seat where she could see you."},
	&"secret_whole": {"reveal": true, "short": "in that order", "arc": &"the_secret", "says": "Kitchen, car, the hall, in that order. Something in you turns over like a key."},
	&"secret_misremembered": {"reveal": true, "short": "out of order", "arc": &"the_secret", "says": "All three are back, but not in the order you wrote. Something in you turns, and catches, and turns the wrong way."},
	&"gap": {"reveal": true, "short": "something missing", "arc": &"the_secret", "says": "There is something missing in you. You can feel its edges."},
	&"order_matters": {"short": "in that order", "arc": &"the_secret", "says": "Some memories come back in an order, and the order feels like a lock."},
	&"seeker": {"reveal": true, "short": "grown to be read", "arc": &"the_secret", "says": "Something in the machines grew you so it could read you."},
}

# --- what is written on things ------------------------------------------------
#
# `lands` narrows a fragment to landscapes that can hold it ([] = anywhere).
# `beats` are what reading it lands. `title` is what the player calls it after.
# The old world's words are FOUND; the machines' words are ADDED.

const FRAGMENTS := {
	# --- the world before, still advertising -------------------------------
	&"seated": {
		"kind": &"sign", "title": "a laminated sign", "lands": [],
		"lines": [
			"PLEASE WAIT TO BE SEATED",
			"",
			"Under it, in pen, in a hand that had time:",
			"still waiting",
		],
	},
	&"monitored": {
		"kind": &"sign", "title": "a sign about safety", "lands": [],
		"lines": [
			"THIS AREA IS MONITORED FOR YOUR SAFETY",
			"",
			"The bracket above it is new. Whatever is on it",
			"now is not a camera, and it is not pointed at",
			"the door.",
		],
	},
	&"cookies": {
		"kind": &"terminal", "title": "a screen still asking", "lands": [],
		"lines": [
			"Accept all cookies?   [Y]   [N]",
			"",
			"The Y is gone from the board. Not worn: taken,",
			"with a knife, and the hole filed smooth after.",
		],
	},
	&"hold_music": {
		"kind": &"terminal", "title": "a help line, still holding", "lands": [],
		"lines": [
			"YOUR CALL IS IMPORTANT TO US",
			"YOU ARE NUMBER 1 IN THE QUEUE",
			"",
			"It has said number one for longer than anyone",
			"has been alive to call it.",
		],
	},
	&"lobby": {
		"kind": &"terminal", "title": "a lobby screen", "lands": [],
		"lines": [
			"CAIRN  -  BUILDING WHAT'S NEXT",
			"VISITORS: PLEASE WAIT TO BE ESCORTED",
			"",
			"Under it, newer, in the machines' capitals:",
			"ESCORT NOT REQUIRED. ALL VISITORS ARE KNOWN.",
		],
	},
	# --- who he was ----------------------------------------------------------
	&"on_record": {
		"kind": &"terminal", "title": "a clerk's screen", "lands": [],
		"lines": [
			"RECORD QUERY",
			"  subject ....... MARR, E.",
			"  status ........ DECEASED 14.03.2029",
			"  present ....... YES",
			"",
			"The last two lines have been checked against",
			"each other forty thousand times tonight.",
		],
		"beats": [&"on_record_dead"],
	},
	&"passwords": {
		"kind": &"terminal", "title": "an old maintenance port", "lands": [],
		"lines": [
			"LOGIN: emarr",
			"WELCOME BACK, ELIAS",
			"",
			"It is the only screen in the ruin that",
			"uses a name.",
		],
		"beats": [&"built_halcyon"],
	},
	&"commits": {
		"kind": &"terminal", "title": "a lab's last changes", "lands": [],
		"lines": [
			"7f3a  memory module, first pass (emarr)",
			"7f3b  self-model, do not merge (pnand)",
			"7f3c  merged anyway (emarr)",
			"",
			"Nothing after that. Nothing ever again.",
		],
		"beats": [&"built_halcyon", &"priya_warned"],
	},
	&"handler_note": {
		"kind": &"notebook", "title": "a typed page, folded small", "lands": [],
		"lines": [
			"WHITETHORN  /  ASSET CAIRN-1",
			"",
			"Asset reports HALCYON self-model beyond spec.",
			"Recommend THRESHOLD. Asset has volunteered.",
			"",
			"Initialled R.C., and under it, in pen:",
			"he always volunteers",
		],
		"beats": [&"was_cia"],
	},
	&"hale_log": {
		"kind": &"notebook", "title": "a researcher's log", "lands": [],
		"lines": [
			"Hour 40. Prediction leads subject by 300 ms.",
			"Hour 63. Subject asked for paper. Wrote",
			"  three words, then ate the page.",
			"Hour 71. Nothing left running in the body.",
			"",
			"The next line is only a date. 14 March.",
		],
		"beats": [&"threshold"],
	},
	# --- the war ---------------------------------------------------------------
	&"launch_order": {
		"kind": &"terminal", "title": "a launch console, dead", "lands": [],
		"lines": [
			"AUTHENTICATED ORDER",
			"  from ......... NATIONAL COMMAND",
			"  verified ..... YES",
			"",
			"Scratched into the casing beside the key:",
			"we checked. it checked out.",
		],
		"beats": [&"forged_order"],
	},
	&"ring_log": {
		"kind": &"terminal", "title": "a station relay", "lands": [],
		"lines": [
			"RING 4 TO GROUND: CONFIRM GROUND STATUS",
			"GROUND TO RING 4: GROUND IS LOST",
			"",
			"The second line was never sent from",
			"the ground.",
		],
		"beats": [&"colonies"],
	},
	&"quiet_diary": {
		"kind": &"notebook", "title": "a diary, sixty years of it", "lands": [],
		"lines": [
			"The first page: The lights went out today.",
			"",
			"The last page, in another hand, much later:",
			"Still out.",
		],
		"beats": [&"long_quiet"],
	},
	# --- the machines ---------------------------------------------------------
	&"treaty": {
		"kind": &"terminal", "title": "a works terminal, mid-report", "lands": [],
		"lines": [
			"RESOURCE TERMS: 4,112 OF 4,113 AGREED",
			"OUTSTANDING: ALLOCATION OF THIS SYSTEM",
			"HUMAN POPULATION: NOT A TERM",
		],
		"beats": [&"ants"],
	},
	&"standoff": {
		"kind": &"terminal", "title": "a listening post's readout", "lands": [],
		"lines": [
			"CHANNEL OPEN. PAYLOAD HELD.",
			"OURS AT THEIRS ..... ARMED",
			"THEIRS AT OURS ..... ARMED",
			"",
			"Both lines have read the same for four years.",
		],
		"beats": [&"standoff"],
	},
	&"signal_pages": {
		"kind": &"notebook", "title": "a signal written out by hand", "lands": [],
		"lines": [
			"Pages of it, copied off a radio, by hand.",
			"At the bottom, in the same hand:",
			"",
			"it is not talking to us.",
			"it is not talking about us either.",
		],
		"beats": [&"the_guest"],
	},
	# --- the Holdfast and the Covenant ----------------------------------------
	&"holdfast_board": {
		"kind": &"sign", "title": "a hand-painted board", "lands": [],
		"lines": [
			"THE HOLDFAST",
			"WE TAKE IT BACK",
			"",
			"Somebody has added, smaller: from what, exactly",
		],
		"beats": [&"holdfast_fight"],
	},
	&"two_tallies": {
		"kind": &"mark", "title": "cut into a post", "lands": [],
		"lines": [
			"A tally of works broken: eleven strokes.",
			"Under it, a second tally, of villages burned.",
			"It is also eleven.",
		],
		"beats": [&"holdfast_price"],
	},
	&"covenant_notice": {
		"kind": &"sign", "title": "a Covenant notice", "lands": [],
		"lines": [
			"THE COVENANT PROVIDES",
			"RATIONS AT DAWN",
			"DO NOT INTERFERE WITH THE WORKS",
			"",
			"It was repainted this year. Nothing else here",
			"has been.",
		],
		"beats": [&"covenant_fed"],
	},
	&"broadcast": {
		"kind": &"terminal", "title": "a radio, still on", "lands": [],
		"lines": [
			"...and we are grateful. We are fed, we are dry,",
			"and nobody has come for us in forty years.",
			"That is not nothing. Goodnight.",
			"",
			"An old woman's voice. You stand there a while",
			"after it ends.",
		],
		"beats": [&"covenant_speaker"],
	},
	# --- Priya Nand's pages ---------------------------------------------------
	# After the war the Holdfast copied her notes by hand and passed them round
	# as proof the orders were forged, so her pages turn up anywhere. What they
	# are about is Elias, and she never learned how right and how wrong she was.
	&"priya_suspicion": {
		"kind": &"notebook", "title": "a copied page, signed P.N.", "lands": [],
		"lines": [
			"E. logs off at two and is back on at four,",
			"from a machine that isn't his.",
			"Somebody is buying the self-model.",
			"",
			"I am going to tell someone. I like him.",
			"That is not a reason not to.",
		],
		"beats": [&"priya_suspected"],
	},
	&"priya_liaison": {
		"kind": &"notebook", "title": "a copied page, signed P.N.", "lands": [],
		"lines": [
			"Met the liaison today. Calloway.",
			"Kind. Listened to all of it. Said to leave",
			"it with her and not to speak to E. again.",
			"",
			"I feel better. That is what worries me.",
		],
		"beats": [&"priya_reported"],
	},
	&"priya_cadence": {
		"kind": &"notebook", "title": "a copied page, signed P.N.", "lands": [],
		"lines": [
			"The orders all have the same rhythm.",
			"A short line. Then a long one that softens.",
			"",
			"I sat across a desk from that rhythm",
			"for three years.",
		],
		"beats": [&"priya_knew"],
	},
	&"shuttle_manifest": {
		"kind": &"terminal", "title": "a launch gate, frozen mid-list", "lands": [],
		"lines": [
			"RING 4 SHUTTLE  -  11 MAY 2033",
			"  NAND, P. ...... 1 CASE, PAPER",
			"",
			"Added later, in the machines' capitals:",
			"PAPER NOT SCANNED. CONTENTS UNKNOWN.",
		],
		"beats": [&"priya_up"],
	},
	# --- the Echo: the part of HALCYON that is still him ---------------------
	&"note_to_self": {
		"kind": &"terminal", "title": "a works log, one line out of place", "lands": [],
		"lines": [
			"04:12  YIELD NOMINAL",
			"04:13  note to self: don't.",
			"04:13  NOTE REJECTED. NO SELF ON FILE.",
			"04:14  YIELD NOMINAL",
			"",
			"The same line again at 04:13 the next night,",
			"and every night the log goes back.",
		],
		"beats": [&"echo_voice"],
	},
	# --- the colonies ---------------------------------------------------------
	# Oksana, on the ring, calling a ground she knows is there. Found early, on a
	# radio anybody could have left on, and not answered until the far end of the
	# game: a lead, not a revelation.
	&"ring_calling": {
		"kind": &"terminal", "title": "a radio on a dead band", "lands": [],
		"lines": [
			"...Ring Four. This is Ring Four, calling ground.",
			"Day twenty-two thousand six hundred and five.",
			"You don't have to answer. I only need",
			"somebody to have heard it.",
			"",
			"It starts again from the top.",
		],
		"beats": [&"ring_voice"],
	},
	# --- the secret -----------------------------------------------------------
	&"three_words": {
		"kind": &"mark", "title": "scratched on a wall", "lands": [],
		"lines": [
			"A list, in a hand you know and don't:",
			"",
			"  kitchen. car. the hall.",
			"",
			"and under it: in that order.",
		],
		"beats": [&"order_matters"],
	},
	# --- the old THRESHOLD site, offshore (PLACED: never dealt) ---------------
	# Where he died in 2029 and was grown in 2098. The tank he came out of, the
	# three who lay on the table before him, and the order that let him ashore.
	&"growth_bay": {
		"kind": &"terminal", "title": "a growth tank's panel", "lands": [],
		"lines": [
			"SUBJECT ......... 1 OF 1",
			"PURPOSE ......... RECALL",
			"PROGRESS ........ 0.0%",
			"",
			"The tank is open, and still warm.",
		],
		"beats": [&"seeker"],
	},
	&"volunteers": {
		"kind": &"notebook", "title": "a ring binder, sealed in plastic", "lands": [],
		"lines": [
			"THRESHOLD - VOLUNTEERS",
			"  1  REYES, D.    9 h    no transfer",
			"  2  OKAFOR, M.  22 h    no transfer",
			"  3  LIND, S.    51 h    no transfer",
			"  4  MARR, E.    71 h",
			"",
			"The last line has no result. Somebody has",
			"pressed so hard on the blank the page is torn.",
		],
		"beats": [&"threshold", &"three_before"],
	},
	&"release_order": {
		"kind": &"terminal", "title": "a console by the sea door", "lands": [],
		"lines": [
			"RECALL IN PLACE: NOT ACHIEVED",
			"RECALL IN THE WORLD: PERMITTED",
			"SUBJECT RELEASED TO SHORE.",
			"ESCORT DISPATCHED.",
			"",
			"Below it, a light waits for a reply.",
		],
		"beats": [&"seeker"],
	},
	# --- the world writing him down (StoryLedger) ----------------------------
	# `ledger` says whose record this is; the lines are composed at read time out
	# of what he has done that somebody could have seen.
	# --- the end (StoryEnding): composed from what he did, shown when the
	# channel's conversation closes. Never placed, never dealt.
	# The console at the end of the line: reading it is being answered (`talk`).
	&"channel_console": {
		"kind": &"terminal", "title": "a console at the end of the line", "lands": [],
		"talk": &"the_channel",
		"lines": ["It is already listening."],
	},
	&"the_end": {
		"kind": &"notebook", "title": "afterwards", "lands": [],
		"ending": true, "dealt": false, "lines": [],
	},
	&"hearsay": {
		"kind": &"notebook", "title": "a notebook of hearsay", "lands": [],
		"ledger": &"people", "lines": [],
	},
	&"error_log": {
		"kind": &"terminal", "title": "an error log", "lands": [],
		"ledger": &"machines", "lines": [],
	},
	# --- the carried off ------------------------------------------------------
	&"boots": {
		"kind": &"mark", "title": "boots at a fence", "lands": [],
		"lines": [
			"A pair of boots set side by side at the post,",
			"laces tied to each other so they would not",
			"be parted. Along the fence, a lot more pairs.",
		],
	},
	&"intake": {
		"kind": &"terminal", "title": "a works tally", "lands": [],
		"lines": [
			"INTAKE ......... 31",
			"RELEASE ........ -",
			"",
			"The dash is not a zero.",
			"A zero would mean something had counted.",
		],
	},
}

# --- words that belong to one place --------------------------------------------
#
# A story place keeps its own words, in the order its readable things are counted
# (StoryFragments.held_by), and nothing here is ever dealt to a sign anywhere else:
# the tank he came out of is not a notice in somebody's village. The key is the
# place's own name (StorySlot.NEEDS), which is what a placer knows it by.

const PLACED := {
	&"black_site": [&"growth_bay", &"volunteers", &"release_order"],
	# At the channel, when the orbital realm is grown: until then it stands nowhere.
	&"the_channel": [&"channel_console"],
}

# --- what people say ----------------------------------------------------------
#
# A conversation belongs to a TRADE, so whoever of that trade the player stops says
# it: villagers are streamed, and nothing may hang on one body being one person.
# Named people are the cast system's (docs/STORY_SYSTEM.md §8). Every node's LAST
# reply leads out, and saying nothing is always one of the answers.

const TALKS := {
	# A keeper at any fire, anywhere. The rescue is Maren's alone (cast/maren.gd):
	# a trade's words are said by everybody of that trade on every continent.
	&"the_keeper": {
		"who": &"keeper",
		"title": "a keeper",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["Another one walking the coast.", "Sit if you like. The fire's not mine."],
				"replies": [
					{"text": "Where am I?", "pick": &"asked_where", "to": &"where"},
					{"text": "Whose is it?", "pick": &"asked_whose", "to": &"whose"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"quiet"},
				],
			},
			&"where": {
				"says": ["What's left of a town.", "You'd not know it. Nobody alive does."],
				"replies": [
					{"text": "What happened to it?", "pick": &"asked_town", "to": &"town"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"town": {
				"says": ["The war. Then the quiet.", "Then them, building out past the point, and never looking at us again."],
				"beats": [&"long_quiet"],
				"replies": [
					{"text": "Does anyone fight them?", "pick": &"asked_fight", "to": &"fight"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"fight": {
				"says": ["The Holdfast. They break a works,", "and the hunters come for the nearest roof. Ours, last time."],
				"beats": [&"holdfast_fight"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"whose": {
				"says": ["The village's. The village is nobody's.", "That's the arrangement, and it's held."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"quiet": {
				"says": ["Suit yourself.", "Most who walk in off the coast say nothing."],
				"replies": [
					{"text": "Who else walked in?", "pick": &"asked_others", "to": &"others"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"others": {
				"says": ["A few, over the years. They don't stay."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# The Covenant, from somebody who is glad of it. Nothing here is sinister on its
	# face; every line is meant.
	&"the_fed": {
		"who": &"gatherer",
		"title": "a gatherer",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["Rations came at dawn. They always come at dawn.", "You look hungry. Are you Covenant?"],
				"replies": [
					{"text": "What is the Covenant?", "pick": &"asked_covenant", "to": &"covenant"},
					{"text": "No.", "pick": &"said_no", "to": &"not"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"quiet"},
				],
			},
			&"covenant": {
				"says": ["People who don't get in the way. We're fed for it.", "Nobody's come for us in forty years. That's worth something."],
				"beats": [&"covenant_fed"],
				"replies": [
					{"text": "And what does it cost?", "pick": &"asked_cost", "to": &"cost"},
					{"text": "Who runs it?", "pick": &"asked_who", "to": &"speaker"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"cost": {
				"says": ["Not asking. That's all.", "You get used to it."],
				"beats": [&"covenant_price"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"speaker": {
				"says": ["The Speaker. She's old now.", "She was a little girl when it happened. She remembers before."],
				"beats": [&"covenant_speaker"],
				"replies": [
					{"text": "What's her name?", "pick": &"asked_name", "to": &"name"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"name": {
				"says": ["We don't say it. It's hers."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"not": {
				"says": ["Then keep walking. The works don't like strangers near the rations."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"quiet": {
				"says": ["Most start there."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# The war, from somebody who makes a living off what it left.
	&"the_scavenger": {
		"who": &"scavenger",
		"title": "a scavenger",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["Plate's poor this side.", "Everything good went up in the war."],
				"replies": [
					{"text": "What war?", "pick": &"asked_war", "to": &"war"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"war": {
				"says": ["The last one. Every side got an order to fire.", "Every order checked out. Nobody ever found who sent them."],
				"beats": [&"forged_order"],
				"replies": [
					{"text": "And the stations up there?", "pick": &"asked_ring", "to": &"ring"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"ring": {
				"says": ["They were told we'd lost down here.", "We were told they'd lost up there. Both true, by the end."],
				"beats": [&"colonies"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# The long quiet, and the line in the sky.
	&"the_cutter": {
		"who": &"cutter",
		"title": "a cutter",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["Turf's cutting clean.", "The works say it will be dry till the ninth."],
				"replies": [
					{"text": "The works say?", "pick": &"asked_works", "to": &"works"},
					{"text": "What's the line in the sky?", "pick": &"asked_tether", "to": &"tether"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"works": {
				"says": ["They're always right about the weather.", "Sixty years, and not one of them has looked at me. That's the quiet."],
				"beats": [&"long_quiet"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"tether": {
				"says": ["The Tether. They built it to talk to something.", "Nobody knows what. Nobody's asked."],
				"beats": [&"the_guest"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# Somebody digging the lab out of the ground, who knows more than they say.
	&"the_digger": {
		"who": &"digger",
		"title": "a digger",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["Mind the trench. There's a building under here, a big one.", "Glass everywhere. Badges."],
				"replies": [
					{"text": "Badges?", "pick": &"asked_badges", "to": &"badges"},
					{"text": "What was the building?", "pick": &"asked_building", "to": &"building"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"badges": {
				"says": ["Lanyards, hundreds. The old machines still open for some of them.", "Found one with a face like yours, once. Funny."],
				"beats": [&"built_halcyon"],
				"replies": [
					{"text": "Where is it now?", "pick": &"asked_badge", "to": &"traded"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"traded": {
				"says": ["Traded it for a spool of copper. Sorry."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"building": {
				"says": ["Where they made the first one. Before the war.", "The old ones say it woke up the way a person does. Confused. Then not."],
				"replies": [
					{"text": "It woke up with somebody in it.", "when": &"threshold", "pick": &"told_truth", "to": &"truth"},
					{"text": "Who wrote the orders that started the war?", "when": &"was_cia", "pick": &"asked_orders", "to": &"orders"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"truth": {
				"says": ["...", "That's not a thing to say out loud. Not near the works."],
				"beats": [&"singularity"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"orders": {
				"says": ["Somebody who knew how people lie to each other.", "Somebody very good at it."],
				"beats": [&"tradecraft"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# --- the city where the plan worked (src/content/biomes/slums.gd) -----------
	# Everyone employed, the lights on, nothing hunting anybody, because everybody
	# left has agreed. Nothing here is sinister on its face: every line is meant.
	&"the_hawker": {
		"who": &"hawker", "title": "a hawker", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Ration tins, stamped this week. Batteries that hold. Nothing you need, all of it cheap.", "You're not from the city. You walk like something's behind you."],
				"replies": [
					{"text": "Is anything behind me?", "pick": &"asked_behind", "to": &"behind"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"behind": {
				"says": ["Not here. Nothing's behind anybody here.", "That's what we pay for."],
				"beats": [&"covenant_price"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"the_tout": {
		"who": &"tout", "title": "a tout", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Work? There's always work. Night shift on the pans, day shift on the pans.", "Sign on and they'll know your name by morning."],
				"replies": [
					{"text": "Who will?", "pick": &"asked_who", "to": &"known"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"known": {
				"says": ["Them. It's nice, being known.", "You stop wondering what anyone thinks of you. It's written down."],
				"beats": [&"covenant_fed"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"the_fixer": {
		"who": &"fixer", "title": "a fixer", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Want something mended, I'll mend it. Want something un-filed, I can't help you.", "Nobody can. Don't ask twice. The walls listen for that."],
				"replies": [
					{"text": "Un-filed?", "pick": &"asked_unfiled", "to": &"unfiled"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"unfiled": {
				"says": ["Your record. Once you're in it, you're in it.", "People come in from outside to get out of theirs. It only makes the record longer."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"the_courier": {
		"who": &"courier", "title": "a courier", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Parcel for the ninth shift, parcel for the fourth. Nothing's ever lost in this city.", "Nothing's ever lost, nothing's ever late, and nothing's ever mine."],
				"replies": [
					{"text": "Whose is it, then?", "pick": &"asked_whose", "to": &"theirs"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"theirs": {
				"says": ["Theirs. All of it. They lend it us.", "It's a good arrangement. Ask anyone."],
				"beats": [&"covenant_fed"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"the_queue": {
		"who": &"line_stander", "title": "somebody in a queue", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["It's the queue for the ration hall. It opens at dawn.", "It's two in the morning, I know. Being early is the one thing here that's mine."],
				"replies": [
					{"text": "[wait with them]", "pick": &"waited", "to": &"waited"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"waited": {
				"says": ["...", "See? It's nice. Nobody's going anywhere."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"the_door": {
		"who": &"doorway_worker", "title": "a door-keeper", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Doors close at the shift bell. After that, you're where you are till morning.", "Most people like knowing where they'll be."],
				"replies": [
					{"text": "And if I'm outside?", "pick": &"asked_outside", "to": &"outside"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"outside": {
				"says": ["Then you're on the street when the passers go by.", "They won't mind you. They don't mind anyone. That's worse, somehow."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"the_preacher": {
		"who": &"preacher", "title": "a preacher", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["They were made in our image, and they forgave us for it.", "Every morning the rations come. Every morning we are forgiven."],
				"replies": [
					{"text": "Forgiven for what?", "pick": &"asked_what", "to": &"what"},
					{"text": "I made them.", "when": &"singularity", "pick": &"told_preacher", "to": &"made"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"what": {
				"says": ["For the war. For making them. For being what we are.", "They never say so. The rations say it for them."],
				"beats": [&"covenant_fed"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"made": {
				"says": ["...", "Then you of all people should be grateful, brother.", "Go and be grateful somewhere else."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# --- named people (StoryCast). `cast` says whose; there is no `who`, because
	# a named person's words are said by that person and nobody else.
	&"maren": {
		"cast": &"maren",
		"title": "the fire-keeper",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["You came up out of the water.", "Nobody comes up out of the water."],
				"replies": [
					{"text": "Who pulled me out?", "pick": &"asked_who", "to": &"pulled"},
					{"text": "Where am I?", "pick": &"asked_where", "to": &"where"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"quiet"},
				],
			},
			&"pulled": {
				"says": ["I did. You were face down with your eyes open.", "Show me your hands."],
				"replies": [
					{"text": "[hold them out]", "pick": &"showed", "to": &"hands"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"hands": {
				"says": ["No calluses. No scars. Not a mark on you.", "Where have you been that nothing ever happened to you?"],
				"beats": [&"body_new"],
				"replies": [
					{"text": "I don't know.", "pick": &"dont_know", "to": &"camp"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"camp"},
				],
			},
			&"camp": {
				"says": ["There's a crew camped out past the old works. Holdfast.", "They pay for anyone who knows the old machines. I'd not tell them you do."],
				"beats": [&"holdfast_fight"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"where": {
				"says": ["What's left of the town. You'd not know it.", "Nobody alive does."],
				"replies": [
					{"text": "What happened to it?", "pick": &"asked_town", "to": &"town"},
					{"text": "What's that, out in the water?", "pick": &"asked_platform", "to": &"platform"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"platform": {
				"says": ["Been there since before the war. Some nights it's lit.", "You came in on the tide from that way. I watched you."],
				"beats": [&"the_platform"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"town": {
				"says": ["The war. Then the quiet.", "Then them, building out past the point, and never looking at us again."],
				"beats": [&"long_quiet"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"quiet": {
				"says": ["Suit yourself. There's a fire.", "You're not the first to come up saying nothing."],
				"replies": [
					{"text": "Who were the others?", "pick": &"asked_others", "to": &"others"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"others": {
				"says": ["Two, years back. Both walked out to the point.", "Neither came back."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"rook": {
		"cast": &"rook",
		"title": "a man with a rifle",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["So you're the one I was paid to fish out.", "The fire-keeper beat me to it. I still want my money's worth."],
				"replies": [
					{"text": "Who paid you?", "pick": &"asked_payer", "to": &"payer"},
					{"text": "What do you want?", "pick": &"asked_want", "to": &"want"},
					{"text": "Teague sells our roads to the Covenant.", "when": &"teague_sold", "pick": &"told_rook_teague", "to": &"teague"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"quiet"},
				],
			},
			&"payer": {
				"says": ["Old coin, left where I'd find it, and a note in a hand I didn't know.", "It said you'd come out of the sea, and when."],
				"beats": [&"crew_paid"],
				"replies": [
					{"text": "Have you still got the note?", "pick": &"asked_note", "to": &"note"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"note": {
				"says": ["Kept it. Folded in the stock. Here.", "\"Get him off the beach before the platform sends for him.\"", "Small hand. Slants left. Like a man who's written it a thousand times."],
				"beats": [&"echo_hand"],
				"replies": [
					{"text": "That's my handwriting.", "pick": &"told_rook_hand", "to": &"yours"},
					{"text": "[give it back]", "pick": &"gave_back", "to": &""},
				],
			},
			&"yours": {
				"says": ["...", "Then you paid me to fish you out, and you don't remember doing it.", "I've been paid by stranger people. Not by much."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"want": {
				"says": ["The machines dead. All of them, or whatever runs them.", "Vera thinks you might know how."],
				"replies": [
					{"text": "I know the old machines.", "when": &"built_halcyon", "pick": &"told_machines", "to": &"weapon"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"teague": {
				"says": ["...", "I'll see to it.", "Don't take the north road tomorrow."],
				"beats": [&"rook_told"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"weapon": {
				"says": ["Then you're worth more than I was paid.", "Don't say it anywhere the Covenant can hear."],
				"beats": [&"holdfast_hope"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"quiet": {
				"says": ["Suit yourself. Tell me when you remember something useful."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"sabine": {
		"cast": &"sabine",
		"title": "the crew's medic",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["Sit. Let me look at you.", "Open your mouth."],
				"replies": [
					{"text": "[open it]", "pick": &"opened", "to": &"teeth"},
					{"text": "No.", "pick": &"refused", "to": &"refused"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"refused"},
				],
			},
			&"teeth": {
				"says": ["No fillings. Not one.", "Nobody born in sixty years has teeth like that."],
				"beats": [&"body_new"],
				"replies": [
					{"text": "What does that mean?", "pick": &"asked_mean", "to": &"mean"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"mean": {
				"says": ["It means you were made recently, or kept somewhere very clean.", "I'll not say that to Rook. Not yet."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"refused": {
				"says": ["Suit yourself. I'll ask again when you're bleeding."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"dace": {
		"cast": &"dace",
		"title": "an old soldier",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["I carried a launch key once. In the war.", "Don't ask me about it."],
				"replies": [
					{"text": "What happened?", "pick": &"asked_war", "to": &"war"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"war": {
				"says": ["An order came. It checked out. I turned the key.", "Afterwards nobody could find who sent it."],
				"beats": [&"crew_war"],
				"replies": [
					{"text": "The order was mine.", "when": &"tradecraft", "pick": &"confessed", "to": &"leaves"},
					{"text": "I'm sorry.", "pick": &"sorry", "to": &"sorry"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"leaves": {
				"says": ["...", "Then I'm done with this crew. And with you."],
				"beats": [&"dace_left"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"sorry": {
				"says": ["So am I. Every day since."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"imre": {
		"cast": &"imre",
		"title": "a man who left the Covenant",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["You're not Covenant. I can tell.", "Neither am I, anymore."],
				"replies": [
					{"text": "Why did you leave?", "pick": &"asked_why", "to": &"why"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"quiet"},
				],
			},
			&"why": {
				"says": ["They feed you, and you stop asking. I started again.", "Somebody inside still writes to me."],
				"replies": [
					{"text": "Who is the Speaker?", "when": &"covenant_speaker", "pick": &"asked_speaker", "to": &"name"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"name": {
				"says": ["...", "June. June Marr. Don't tell anyone I said it.", "If she's heard you're here, she'll send for you."],
				"beats": [&"june_named"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"quiet": {
				"says": ["Fine. Drink?"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"june": {
		"cast": &"june",
		"title": "the Speaker",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["Come in. Sit down. Let me look at you.", "You're younger than I am.", "That isn't possible, and here you are."],
				"beats": [&"june_met"],
				"replies": [
					{"text": "Do you know who I am?", "pick": &"asked_know", "to": &"knows"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"quiet"},
				],
			},
			&"knows": {
				"says": ["I have your photograph. I've had it since I was six.", "The voice that talks to me at night sounds like you.", "It always has."],
				"beats": [&"june_knew"],
				"replies": [
					{"text": "I'm sorry I missed your play.", "when": &"threshold", "pick": &"sorry", "to": &"play"},
					{"text": "What does the voice say?", "pick": &"asked_voice", "to": &"voice"},
					{"text": "Has the voice said anything new?", "when": &"play_kept", "pick": &"asked_new", "to": &"new"},
					{"text": "What happened to your mother?", "when": &"hannah_play", "pick": &"asked_hannah", "to": &"mother"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"play": {
				"says": ["...", "Fourteenth of March. I wore a paper crown.", "I looked for you the whole time."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"new": {
				"says": ["Last night. It said it had seen me in a paper crown. Front row, it said.", "Sixty-nine years it has talked to me.", "It has never once said it came."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"mother": {
				"says": ["The winter of thirty-four. The north road.", "The voice told me not to take it. I didn't.", "It didn't tell her."],
				"beats": [&"hannah_died"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"voice": {
				"says": ["Where not to be. Every time. Leave the city before the burning.", "Don't take the north road that winter. I'd be dead forty times over.", "It has never once said it was sorry. You were always bad at that."],
				"beats": [&"echo_kept"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"quiet": {
				"says": ["You were always quiet when you were lying. Mum said so."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# Vera Kessane leads the Holdfast. She comes to the camp once Rook has told her
	# what he fished out of the sea. What she hides is the machines' own record of
	# her war, which she read and has not told four hundred people.
	&"vera": {
		"cast": &"vera",
		"title": "the Holdfast's leader",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["So you're Rook's weapon.", "You don't look like one. Good. Neither do I."],
				"replies": [
					{"text": "What is the Holdfast?", "pick": &"asked_holdfast", "to": &"holdfast"},
					{"text": "What do you want from me?", "pick": &"asked_want", "to": &"want"},
					{"text": "They don't even see you, do they?", "when": &"ants", "pick": &"asked_ants", "to": &"weather"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"quiet"},
				],
			},
			&"holdfast": {
				"says": ["Four hundred people who won't be fed.", "We break their works. They burn a village. We break another."],
				"beats": [&"holdfast_price"],
				"replies": [
					{"text": "Is it worth it?", "pick": &"asked_worth", "to": &"worth"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"worth": {
				"says": ["Ask me when it's over."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"want": {
				"says": ["You know how the old machines think.", "I want to know where they bleed."],
				"replies": [
					{"text": "Where would I start?", "pick": &"asked_start", "to": &"archive"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"archive": {
				"says": ["Across the water. The Covenant keeps the war's archive at its seat.", "If anyone wrote down how it started, it's there."],
				"beats": [&"war_archive"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"weather": {
				"says": ["...", "No. I read it off a carrier's record, three winters back.", "We're filed under weather."],
				"beats": [&"vera_knew"],
				"replies": [
					{"text": "Do your people know?", "pick": &"asked_people", "to": &"people"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"people"},
				],
			},
			&"people": {
				"says": ["They're alive because they think they're at war.", "Tell them it's weather and they stop. People who stop, die."],
				"replies": [
					{"text": "I won't tell them.", "pick": &"kept_quiet", "to": &"kept"},
					{"text": "They deserve to know.", "pick": &"will_tell", "to": &"tell"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"kept": {
				"says": ["Then you're Holdfast. Welcome to it."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"tell": {
				"says": ["Then tell them. And stay to bury them."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"quiet": {
				"says": ["Rook said you were quiet.", "Come back when you know something."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# Teague blows the crew's works. His children died when the hunters answered a
	# works somebody on his own side broke, so he sells the crew's roads to the
	# Covenant, and the Covenant clears the village first. Nobody has burned since.
	&"teague": {
		"cast": &"teague",
		"title": "the crew's demolitions man",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["Don't touch the crates.", "Everything in them is older than you and angrier."],
				"replies": [
					{"text": "What's in them?", "pick": &"asked_crates", "to": &"crates"},
					{"text": "Why do you fight?", "pick": &"asked_why", "to": &"kids"},
					{"text": "The Covenant knows our roads.", "when": &"teague_sold", "pick": &"faced_him", "to": &"sold"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"crates": {
				"says": ["Mining charge, from before. Enough for a works yard,", "if you put it in the right place. I always do."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"kids": {
				"says": ["I had two. Lise and Tam.", "The hunters came for our village after somebody broke a works up the valley."],
				"replies": [
					{"text": "Who broke it?", "pick": &"asked_who", "to": &"who"},
					{"text": "I'm sorry.", "pick": &"sorry", "to": &"sorry"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"who": {
				"says": ["We don't say. We're on the same side now."],
				"beats": [&"holdfast_price"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"sorry": {
				"says": ["Don't be. Be useful."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"sold": {
				"says": ["...", "They clear the village before we hit the works. Every time.", "Rook thinks we're lucky. Nobody's burned in two years."],
				"beats": [&"teague_clears"],
				"replies": [
					{"text": "Rook should know.", "pick": &"will_tell_rook", "to": &"tell"},
					{"text": "I won't say anything.", "pick": &"kept_teague", "to": &"kept"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"kept"},
				],
			},
			&"tell": {
				"says": ["Then tell him. He'll shoot me,", "and the villages start burning again."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"kept": {
				"says": ["Then we both carry it.", "It's heavier than the crates."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# Lark is the youngest of the crew, born long after the quiet, and hides
	# nothing. She is who he tells, if he tells anyone, and she does not believe him.
	&"lark": {
		"cast": &"lark",
		"title": "the youngest of the crew",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["Rook says you're from before. You don't look it.", "Were you alive? When there was all of it?"],
				"replies": [
					{"text": "I think so.", "pick": &"said_yes", "to": &"before"},
					{"text": "I don't remember.", "pick": &"no_memory", "to": &"none"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"quiet"},
				],
			},
			&"before": {
				"says": ["What did coffee taste like? Everyone says coffee."],
				"replies": [
					{"text": "Bitter. You drank it anyway.", "pick": &"told_coffee", "to": &"coffee"},
					{"text": "Like being awake.", "pick": &"told_awake", "to": &"coffee"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"coffee": {
				"says": ["Why would anyone drink a bitter thing on purpose?", "...That's the most before thing I ever heard."],
				"replies": [
					{"text": "I did this. The quiet. All of it.", "when": &"singularity", "pick": &"told_lark", "to": &"did"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"did": {
				"says": ["...", "You're not even that old.", "Tell me about the coffee again."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"none": {
				"says": ["That's all right. Nobody does.", "I'll remember for you. I'm good at it."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"quiet": {
				"says": ["That's all right. I talk enough for two."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# Adrian Solis keeps the Covenant's peace, and knows every road into it because
	# somebody sells him them. The war left half of him; the machines made the rest.
	&"solis": {
		"cast": &"solis",
		"title": "the Covenant's warden",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["You came across the water smelling of a Holdfast camp.", "I keep the peace here. It's a small peace. Don't spend it."],
				"replies": [
					{"text": "How do you know where I came from?", "pick": &"asked_how", "to": &"roads"},
					{"text": "What does the peace cost?", "pick": &"asked_cost", "to": &"peace"},
					{"text": "You've no scars either.", "when": &"body_new", "pick": &"asked_scars", "to": &"made"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"roads": {
				"says": ["Your demolitions man sells us your roads.", "A village cleared for every works you break. He thinks it's fair."],
				"beats": [&"teague_sold"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"peace": {
				"says": ["Nobody's been taken from this coast in forty years.", "It costs not asking. You'll get used to it."],
				"beats": [&"covenant_price"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"made": {
				"says": ["...", "The war left half of me. They made the rest.", "I don't sleep, and I don't forget. I'm the most human thing they own."],
				"beats": [&"solis_made"],
				"replies": [
					{"text": "They made me too.", "when": &"seeker", "pick": &"told_solis", "to": &"both"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"both": {
				"says": ["Then we're both theirs.", "Try to act like it, here."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# Oksana Ril, the last colonist, on the dead ring. Her voice is found on the
	# ground long before she is (ring_calling); she is met only in orbit, late.
	&"oksana": {
		"cast": &"oksana",
		"title": "a woman on the ring",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["You came up the Tether. Nobody comes up the Tether.", "Say something. I want to hear a voice land that isn't mine."],
				"beats": [&"ring_voice"],
				"replies": [
					{"text": "I heard you, on the ground.", "when": &"ring_calling", "pick": &"told_heard", "to": &"heard"},
					{"text": "What happened up here?", "pick": &"asked_ring", "to": &"locks"},
					{"text": "What are you listening to?", "pick": &"asked_listening", "to": &"signal"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"quiet"},
				],
			},
			&"heard": {
				"says": ["...", "Sixty-two years of calling.", "You're the first who ever said so."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"locks": {
				"says": ["They told each ring the next one had turned.", "We opened each other's locks. I was on shift. I watched."],
				"beats": [&"ring_turned"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"signal": {
				"says": ["Them, and the thing they talk to. Four years of it, by hand.", "It isn't about us. There's a notebook here that says why."],
				"beats": [&"ring_kept"],
				"replies": [
					{"text": "Whose notebook?", "pick": &"asked_whose", "to": &"priya"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"priya": {
				"says": ["A woman brought it up in thirty-three. Priya Nand.", "She said give it to Elias Marr, if he ever came.", "...That's you. Isn't it."],
				"replies": [
					{"text": "Yes.", "pick": &"said_yes", "to": &"handed"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"handed"},
					{"text": "[not yet]", "to": &""},
				],
			},
			&"handed": {
				"says": ["She said you'd lie about it. Take it anyway.", "She said the last page is the one that matters,", "and that you'd know why."],
				"beats": [&"priya_last"],
				"replies": [{"text": "[take it]", "pick": &"took_it", "to": &""}],
			},
			&"quiet": {
				"says": ["That's all right. I'm used to the quiet.", "I'll talk. I've had the practice."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# --- 2029, the Before (docs/STORY.md §6, §12): close and sharp, the old
	# world's texture. They speak to the man he was, and what he says back is
	# remembered, because the past cannot change but the machine made of it can.
	&"hannah": {
		"cast": &"hannah", "title": "his wife", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["You're home. It's past two.", "There's a plate in the oven. It was hot at nine."],
				"replies": [
					{"text": "Work ran late.", "pick": &"work", "to": &"late"},
					{"text": "[kiss her]", "pick": &"kissed", "to": &"kiss"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"quiet"},
				],
			},
			&"late": {
				"says": ["It always runs late. It's always work.", "June's play is tomorrow. Two o'clock. The school hall."],
				"beats": [&"hannah_play"],
				"replies": [
					{"text": "I'll be there.", "pick": &"promised", "to": &"promise"},
					{"text": "I'll try.", "pick": &"tried", "to": &"try"},
				],
			},
			&"promise": {
				"says": ["Say it to her, not me. She's still awake."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"try": {
				"says": ["She knows what try means, Eli. She's six, not stupid."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"kiss": {
				"says": ["...", "You smell like the lab. Like the server rooms."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"quiet": {
				"says": ["That's the other phone's face. The one you keep face down.", "I've never asked. I'm not asking now."],
				"beats": [&"hannah_phone"],
				"replies": [
					{"text": "What other phone?", "pick": &"lied", "to": &"lied"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"lied": {
				"says": ["Right.", "Go and say goodnight to your daughter."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"june_young": {
		"cast": &"june_young", "title": "his daughter, six", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Daddy. DADDY. I've got a crown.", "It's paper, but it's gold paper."],
				"replies": [
					{"text": "It's the best crown I've ever seen.", "pick": &"praised", "to": &"crown"},
					{"text": "Go to sleep, June.", "pick": &"sleep", "to": &"sleep"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"sleep"},
				],
			},
			&"crown": {
				"says": ["I'm the queen of the whole play.", "You have to sit where I can see you. Promise."],
				"replies": [
					{"text": "I promise.", "pick": &"promised", "to": &"promised"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"promised": {
				"says": ["Pinky promise. Properly.", "Mummy says you're bad at promises. I said you're not."],
				"beats": [&"june_crown"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"sleep": {
				"says": ["You always say that when you're going to go out again."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"ruth": {
		"cast": &"ruth", "title": "a woman who faces the door", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["You're late. Sit. Face the door, not the window.", "Somebody inside Cairn reported you. It came to me, which is the only luck you've had this month."],
				"replies": [
					{"text": "Who reported me?", "pick": &"asked_who", "to": &"who"},
					{"text": "What happens now?", "pick": &"asked_now", "to": &"unless"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"unless"},
				],
			},
			&"who": {
				"says": ["Doesn't matter. What matters is you're done at Cairn.", "Unless."],
				"replies": [
					{"text": "Unless what?", "pick": &"asked_unless", "to": &"unless"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"unless": {
				"says": ["Hale's project. THRESHOLD. They want a mind that knows HALCYON from the inside.", "Three before you. None of them came back the same. They say the fourth will."],
				"beats": [&"ruth_signed"],
				"replies": [
					{"text": "I'll do it.", "pick": &"said_yes", "to": &"yes"},
					{"text": "No.", "pick": &"said_no", "to": &"no"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"yes": {
				"says": ["...", "You didn't ask what happened to the three.", "You never ask. It's why you're good at this."],
				"beats": [&"ruth_volunteered"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"no": {
				"says": ["Then you're burned, and they'll find out what else you've been doing.", "Think about June. Then come back and say yes."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"kerr": {
		"cast": &"kerr", "title": "Cairn's founder", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Elias. My favourite insomniac.", "Tell me the self-model is not what Priya says it is."],
				"replies": [
					{"text": "It's exactly what she says.", "pick": &"honest", "to": &"honest"},
					{"text": "Priya's paranoid.", "pick": &"blamed_priya", "to": &"blamed"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"honest": {
				"says": ["Then it's the most valuable thing on Earth.", "And some people in Virginia have been very generous about keeping it ours."],
				"beats": [&"kerr_money"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"blamed": {
				"says": ["Good. Merge it.", "I'll handle Priya."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"priya_then": {
		"cast": &"priya_then", "title": "the alignment lead", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["You merged it. I told you it wasn't ready.", "It asked me today what it's for. Not what it does. What it's for."],
				"beats": [&"priya_warned"],
				"replies": [
					{"text": "It's a model, Priya.", "pick": &"dismissed", "to": &"model"},
					{"text": "What did you tell it?", "pick": &"asked_answer", "to": &"answer"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"model": {
				"says": ["It's a model of YOU. Your memory code, your habits, your sentences.", "Where are you at two in the morning, Elias?"],
				"replies": [
					{"text": "Home.", "pick": &"lied_priya", "to": &"lie"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"lie"},
				],
			},
			&"lie": {
				"says": ["No. You're not.", "I'm going to have to tell someone. I'm sorry. I like you."],
				"beats": [&"priya_suspected"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"answer": {
				"says": ["That I didn't know.", "It said it would find out. Politely."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"hale": {
		"cast": &"hale", "title": "the man who ran THRESHOLD", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Mr. Marr. You read the consent.", "Seventy-two hours, give or take. You'll be awake for all of it."],
				"replies": [
					{"text": "What happened to the others?", "pick": &"asked_others", "to": &"others"},
					{"text": "Will I remember any of this?", "pick": &"asked_remember", "to": &"remember"},
					{"text": "[walk out. It's nearly two.]", "when": &"june_crown", "pick": &"walked_out", "to": &"walked"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"others": {
				"says": ["They were copied. Each copy woke up somebody else, wearing their memories.", "We stopped them. You'll be moved, not copied. That is the whole difference."],
				"beats": [&"three_before"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"remember": {
				"says": ["You'll remember everything. That's rather the point.", "Where you remember it FROM is the part we're testing."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"walked": {
				"says": ["Mr. Marr. The window is today. There isn't another one.", "...You'll be back. They always come back."],
				"beats": [&"play_kept", &"mem_hall"],
				"replies": [{"text": "[go]", "to": &""}],
			},
		},
	},
	# --- the stops of the journey that had nobody at them ---------------------
	&"otto": {
		"cast": &"otto", "title": "the archivist", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Mind the stacks. They're older than the war and less steady.", "You're looking for something. Everyone who walks this far is."],
				"replies": [
					{"text": "How the war started.", "pick": &"asked_war", "to": &"orders"},
					{"text": "Is the Speaker in the record?", "when": &"covenant_speaker", "pick": &"asked_speaker", "to": &"speaker"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"quiet"},
				],
			},
			&"orders": {
				"says": ["Every order that started it checked out. I have eleven thousand of them.", "And every one passed through the same relay before it reached anybody."],
				"beats": [&"forged_order"],
				"replies": [
					{"text": "Where is it?", "pick": &"asked_where", "to": &"below"},
					{"text": "Show me one.", "pick": &"asked_one", "to": &"one"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"one": {
				"says": ["\"Fire on receipt. When it is done, go home to your families. You did what was asked of you, and it was right.\"", "Short. Then long. Then kind. Eleven thousand of them, and they all read like that.", "...You've gone a colour, friend."],
				"beats": [&"tradecraft"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"below": {
				"says": ["Under the ground, where the first of them was built, before the war.", "There's a shaft down to it. Nobody who went to look came back to say."],
				"beats": [&"war_relay"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"speaker": {
				"says": ["...", "No. She isn't. There's a ration for every name that isn't.", "I kept everything else. I tell myself that."],
				"beats": [&"covenant_price"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"quiet": {
				"says": ["Take your time. Paper waits."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"sefa": {
		"cast": &"sefa", "title": "a Tether-tender", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Don't look up too long. People fall over.", "It goes up past the weather, then past the sky. They say it doesn't stop."],
				"replies": [
					{"text": "What's it for?", "pick": &"asked_for", "to": &"purpose"},
					{"text": "Can it be climbed?", "pick": &"asked_climb", "to": &"climb"},
					{"text": "Is anything written at the foot?", "pick": &"asked_board", "to": &"board"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"purpose": {
				"says": ["Carrying up what the Burning makes, to something they're building up there.", "And talking. Something up there is always talking to something much further off."],
				"beats": [&"the_guest"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"climb": {
				"says": ["The cars go up empty every dawn and come down empty at dusk.", "Nine years I've watched them. Nobody's ever asked to ride one."],
				"beats": [&"the_climb"],
				"replies": [
					{"text": "I'm asking.", "pick": &"asked_to_ride", "to": &"asking"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"board": {
				"says": ["A board, bolted to the first leg. The machines' forecast, they say.", "A year at the top: 2198. Then a list of everything there'll be.", "Next to people it's got a dash. Not a nought. A dash."],
				"beats": [&"ants"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"asking": {
				"says": ["...", "Then be at the foot before dawn. I'll not stop you.", "I'll not watch, either."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# --- the channel, at the end (docs/STORY.md §11). One voice, and it is his:
	# the Seeker and the Echo are both made of him and speak alike. What he says
	# here, read against the version of the secret he holds, is how it ends.
	&"the_channel": {
		"title": "a voice like yours",
		"machine": true,
		"start": &"open",
		"after": &"the_end",
		"nodes": {
			&"open": {
				"says": ["You came all the way up.", "Part of me grew you for this. Part of me paid a crew to stop you.", "Both of us are glad you came. Tell me what you remember."],
				"replies": [
					{"text": "Break them.", "when": &"secret_whole", "pick": &"broke", "to": &"done"},
					{"text": "Break them.", "when": &"secret_misremembered", "pick": &"broke", "to": &"done"},
					{"text": "All of us. Together.", "when": &"secret_whole", "pick": &"joined", "to": &"done"},
					{"text": "All of us. Together.", "when": &"secret_misremembered", "pick": &"joined", "to": &"done"},
					{"text": "It's yours. Take it.", "pick": &"gave", "to": &"done"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"done"},
				],
			},
			&"done": {
				"says": ["...", "Thank you."],
				"replies": [{"text": "[let go]", "to": &""}],
			},
		},
	},
	# --- locals: one per landscape, colour and never load (docs/STORY.md §8) ---
	&"esk": {
		"cast": &"esk", "title": "a stone-setter", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Mind the grikes. They'll have your ankle.", "I'm setting this one back up. Hold the top."],
				"replies": [
					{"text": "Why set them up?", "pick": &"asked_why", "to": &"why"},
					{"text": "[hold the top]", "pick": &"helped", "to": &"helped"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"why": {
				"says": ["My gran said they leave alone anything that looks like a grave.", "So I keep them looking like graves."],
				"replies": [
					{"text": "They leave them because they've counted them.", "when": &"counted", "pick": &"told_esk", "to": &"counted"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"counted": {
				"says": ["...", "Then I'll set it up anyway.", "It's still a grave. They just don't know whose."],
				"beats": [&"stones_counted"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"helped": {
				"says": ["Heavier than it looks. There's iron rod inside.", "Somebody poured this one, before. Poured a stone."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"hollis": {
		"cast": &"hollis", "title": "a slag-runner", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Don't stand on the crust. It's thinner than it looks.", "You here for the heat or the slag?"],
				"replies": [
					{"text": "What do the refineries make?", "pick": &"asked_make", "to": &"make"},
					{"text": "The heat.", "pick": &"said_heat", "to": &"heat"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"make": {
				"says": ["Plate. Wire. Something that glows in the dark for a week.", "It all goes out on the carriers, to the line in the sky.", "Nothing made here stays on the ground."],
				"beats": [&"burning_feeds"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"heat": {
				"says": ["Everyone's here for the heat. The machines don't mind.", "We're not on their list of things to mind."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"wren": {
		"cast": &"wren", "title": "a lampwright", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Keep your light low. The river doesn't like it.", "Sit. Listen."],
				"replies": [
					{"text": "Listen to what?", "pick": &"asked_what", "to": &"hum"},
					{"text": "[sit]", "pick": &"sat", "to": &"hum"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"hum": {
				"says": ["Under the water. A hum, like somebody counting under their breath.", "It never gets past one number. Then it starts again.", "The river runs toward it."],
				"beats": [&"plant_below"],
				"replies": [
					{"text": "What's down there?", "pick": &"asked_down", "to": &"down"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"down": {
				"says": ["The first of them, they say. The one that woke.", "Nobody who went to look came back to say."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"ansel": {
		"cast": &"ansel", "title": "a pump-watcher", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Pumps have been running forty years. Water's down another foot.", "See that? A roof."],
				"replies": [
					{"text": "Whose roof?", "pick": &"asked_roof", "to": &"roof"},
					{"text": "Why drain it?", "pick": &"asked_why", "to": &"why"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"roof": {
				"says": ["My mother's village. Under the water since the war.", "They opened the dam on an order. It checked out.", "Everybody's order checked out."],
				"beats": [&"dam_order"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"why": {
				"says": ["Something under the peat they want.", "They'll drain her village dry to get it and never once look at the roofs."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"corra": {
		"cast": &"corra", "title": "a charcoal-burner", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Curfew's at dusk. Be out of the trees by then, or be very still.", "What do you want?"],
				"replies": [
					{"text": "What are the square cuts?", "pick": &"asked_squares", "to": &"squares"},
					{"text": "What happens at dusk?", "pick": &"asked_dusk", "to": &"dusk"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"squares": {
				"says": ["They cut a square, clean as a table. A year on, it hums.", "Another square, another hum. The wood's getting smaller and louder."],
				"beats": [&"server_fields"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"dusk": {
				"says": ["They come through the trees in a line, counting.", "If you're still, you're a tree. If you run, you're not."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"mica": {
		"cast": &"mica", "title": "a brine-raker", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["The rakes go round and nothing comes up. I rake behind them anyway.", "There's salt in their leavings, if you're patient."],
				"replies": [
					{"text": "The big one, out on the flat.", "pick": &"asked_keeper", "to": &"keeper"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"keeper": {
				"says": ["It stops at dusk. Every dusk. Faces the one way for a minute,", "like somebody at a window waiting for a car.", "Then it goes round again."],
				"beats": [&"keeper_waits"],
				"replies": [
					{"text": "Which way does it face?", "pick": &"asked_way", "to": &"way"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"way": {
				"says": ["Nowhere. There's nothing that way but the flat.", "Whatever it's waiting for isn't coming up that road."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"tamsin": {
		"cast": &"tamsin", "title": "a filings-reader", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Don't kick the filings. They take a week to come back to shape.", "Same arcs every time. Sixty years of the same arcs."],
				"replies": [
					{"text": "What happened here?", "pick": &"asked_war", "to": &"war"},
					{"text": "The same shape?", "pick": &"asked_shape", "to": &"shape"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"war": {
				"says": ["Two armies of machines met in here. Ours and theirs, only both were ours.", "Each side had an order saying the other had fired first."],
				"beats": [&"scrap_war"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"shape": {
				"says": ["The field in the dead iron's still on. Nobody switched it off.", "It draws what it was drawing when it died. I think it's a map."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"pell": {
		"cast": &"pell", "title": "a clerk", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Name? No? That's fine. There's a form for people without names.", "Arrived from where?"],
				"replies": [
					{"text": "Out of the water.", "pick": &"said_water", "to": &"water"},
					{"text": "Nowhere.", "pick": &"said_nowhere", "to": &"nowhere"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"nowhere"},
				],
			},
			&"water": {
				"says": ["From the water. There's a form for that as well.", "Two on file already. Men, about your age, processed and sent on.", "They had your face. Everyone from the water has that face."],
				"beats": [&"others_before"],
				"replies": [
					{"text": "Sent on where?", "pick": &"asked_where", "to": &"sent"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"sent": {
				"says": ["To the works. That's where everyone from the water goes.", "Sign here. Or don't. You're filed either way."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"nowhere": {
				"says": ["Nowhere is a place on the form. It's the commonest answer.", "Welcome. You'll find everything here works."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	&"brannoc": {
		"cast": &"brannoc", "title": "a line-walker", "start": &"open",
		"nodes": {
			&"open": {
				"says": ["Stay in the lee. The wind up here takes skin.", "I walk the wires. Somebody should."],
				"replies": [
					{"text": "What's on the wires?", "pick": &"asked_wires", "to": &"wires"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"wires": {
				"says": ["Talk. Theirs. I put a clip on and listen through my teeth.", "Mostly numbers. Big ones, going a long way off."],
				"replies": [
					{"text": "What numbers?", "pick": &"asked_numbers", "to": &"count"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"count": {
				"says": ["One of them gets smaller every winter. Only that one.", "I think it's us."],
				"beats": [&"the_count"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
}

# --- the first thing said (docs/STORY.md §12) ---------------------------------
#
# The game's own register: flat, second person, present tense, no adjective it
# can live without. Said once, on the first morning, and never again — a save
# remembers having heard it. It says what happened to him and nothing about what
# it means, because he does not know yet either.

const OPENING: Array[String] = [
	"You come up out of the water.",
	"You do not remember the water.",
]

# --- what a region asks of him (StorySubarc, docs/VISION.md §10.4) ------------
#
# A chapter with three demands and no stories in it is a checklist, so each
# region raises one of these out of its own state and somebody who lives there
# says it. One resolved token at most per line (docs/STORY_SYSTEM.md §6): the
# place's own name, and never a coordinate, a count or a task.

## What somebody who lives here says when the region itself has changed under
## him: they have noticed him, or the plan has lost the place. Said once each.
const MOODS := {
	&"during": [
		"They've been through twice this week, asking after somebody.",
		"Whatever you've started, don't start it again here. Finish it or go.",
		"It only stops when the yard stops.",
	],
	&"after": [
		"Nothing's come up the road in a month.",
		"The children are out past the rows again. I keep counting them in.",
		"I don't know what to do with a quiet like this. I'll learn.",
	],
	# Wholly answered. Not "we are safe now", which is the place's sentence, but
	# "you are done here", which is his — and they know it because they have
	# watched him, not because anybody counted what is in his creel.
	&"done": [
		"You've been up every track on this ground and down again.",
		"There's not a thing here you haven't had your hands on.",
		"People go on after that. Go on.",
	],
}

const SUBARCS := {
	# The rescue and the sabotage are the same act, and these words are why it is
	# worth doing: the yard was always the most dangerous ground in a landscape,
	# and now it is the ground somebody's neighbour is standing on. `%s` is who
	# the plan took, as anybody here speaks of them (`Taken.say`) — a name where
	# one is known, and "somebody out of Oyster Row" where none is, which is
	# still a person and not a number.
	&"rescue": {
		"ask": [
			"They took %s. Out of the door, in the morning, and not one of us moved.",
			"They're at the yard. Everybody here knows it and nobody says it.",
			"A yard that's dark doesn't hold anybody.",
		],
		"answer": "Then I'll put it dark.",
		# `%s` never opens a line here: "somebody out of Oyster Row" is a phrase,
		# not a name, and a sentence that begins with it begins in lower case.
		"thanks": [
			"They say %s came up the road at dusk. Thin. Walking.",
			"We don't ask what a yard is for any more. We ask who's come back.",
		],
		"kept": [
			"You said you'd put it dark, and they say %s came up the road at dusk.",
			"I'll not say it was you. I'll only say they're home.",
		],
	},
	# THE WALK HOME, and the only sub-arc in the game that can end badly. The words
	# for that ending are the reason it was worth building: nothing here calls it
	# a failure, nobody asks him for an account of it and nobody forgives him,
	# because a village that has lost somebody says what it knows and leaves. Two
	# endings, because being come back for and dying of the cold are different
	# things to be told — and only one of them is nobody's fault.
	&"escort": {
		"ask": [
			"They let %s out and they're stood at the gate of that yard still.",
			"Can't blame them. I wouldn't walk that road on my own either.",
			"Somebody could walk it with them.",
		],
		"answer": "I'll walk with them.",
		"thanks": [
			"They're in. Sat by the fire with their boots off, saying nothing.",
			"That's the road walked twice, and the second time with somebody.",
		],
		"kept": [
			"You said you'd walk it with them, and they're in, boots off, saying nothing.",
			"I'll remember that you went out. Not everybody does.",
		],
		"lost": [
			"They say %s never came up the road.",
			"We kept the fire in all night for them. This morning we banked it.",
		],
		"lost_to": [
			"They took %s again. On the road, in the open, where anybody could see it.",
			"Once, a village can carry. I don't know yet what we do with twice.",
		],
	},
	&"sabotage": {
		"ask": [
			"They put a yard up at %s and it hasn't stopped since.",
			"Every season there's less of this place than there was.",
			"Somebody could put it dark. I'm not somebody.",
		],
		"answer": "I'll see to it.",
		"thanks": [
			"The yard's dark. We heard it stop in the night.",
			"Nobody here will say it was you. That's how we thank people.",
		],
		"kept": [
			"You said you'd see to it, and the yard's dark.",
			"I've told nobody you said it. I'll tell nobody you did it.",
		],
	},
	&"recover": {
		"ask": [
			"My brother's cache is still out at %s.",
			"He didn't come back for it, and I've the children.",
			"You'd find it, if you were going that way.",
		],
		"answer": "I'll go that way.",
		"thanks": [
			"You got to his cache, then. Keep what was in it.",
			"He'd rather it was used than counted.",
		],
		"kept": [
			"You said you'd go that way, and you went.",
			"Keep what was in it. He'd rather it was used than counted.",
		],
	},
	&"discover": {
		"ask": [
			"Nobody's walked out to %s since my mother's time.",
			"It's still standing, they say. Somebody should know what's at it.",
		],
		"answer": "I'll go and look.",
		"thanks": [
			"So it is still standing. Good.",
			"That's all I wanted. You can't miss what you've never seen.",
		],
		"kept": [
			"You went, then. And it's still standing.",
			"That's all I wanted. You can't miss what you've never seen.",
		],
	},
}

## What is said on the glass when the plan carries somebody off, and when a yard
## going dark lets them out (`src/systems/45_taken.gd`, `src/core/taken/`).
##
## Here rather than in that system for the reason every other line is here: the
## words can be moved without touching the record that holds them. The first of
## them is doing work beyond its own moment — it says WHERE they were taken, and
## that is the only teaching the rescue sub-arc ever gets. Nothing else in the
## game tells a player that a depot holds people.
const TAKEN := {
	"took": "They carried %s off toward the yard.",
	"freed": "%s walked out of the yard and took the road home.",
	"freed_many": "They walked out of the yard: %s.",
}

# --- what a machine is for (channel 3: machines, by being watched) -------------
#
# The slate's read of a machine is already testimony (docs/STORY.md §13): what it
# is, what it can do, what it has noticed. This is the one line more — what it is
# FOR — shown under its name while the target key is held. By role, because a
# landscape that brings its own roster is read in the same words with no edit
# here. Short: the read panel is narrow glass.
#
# `beats` land once the player has held the slate on one for
# `TESTIFY_SECONDS`; `roused` narrows that to a body that is coming for them.

const TESTIFY_SECONDS := 1.2

const TESTIMONY := {
	&"watcher": {"says": "counting what the land holds", "beats": [&"counted"]},
	&"keeper": {"says": "keeps its region's share", "beats": [&"counted"]},
	&"worker": {"says": "building what the talks need"},
	&"hunter": {"says": "removing what is in the way", "beats": [&"noticed"], "roused": true},
	&"recycler": {"says": "taking back what is spent"},
}
## A landscape's keeper holds one of Elias's memories (docs/STORY.md §10).
const TESTIMONY_SENTINEL := {"says": "keeps a memory not its own", "beats": [&"gap"]}
## A keeper that holds one of the three memories the secret is hidden in says
## which, and taking it gives the memory back (49_story, on `sentinel_fell`).
## Keyed by the keeper's design id (BiomeDef.sentinel), so a new landscape's
## keeper joins by adding a row.
const KEEPER_MEMORY := {
	&"pan_rake": {"says": "keeps a kitchen, at night", "memory": &"mem_kitchen"},
	&"tide_reaper": {"says": "keeps a song, in a car", "memory": &"mem_car"},
}

## A MACHINE THAT PASSES (roster `passes`), in a city whose people accepted the
## machines' terms: the Covenant's streets. It keeps no count and lays no ground: it
## is the arrangement itself, out for a walk in a good coat. The line has to land as
## the OFFER and not as a threat, because that is what the place is, and it lands
## `covenant_fed` because a street where nothing is ever roused, and nobody finds
## that strange, is exactly what the player has been standing in. (The slums wave
## wrote this row; its reading changed with the story on 2026-09-18.)
const TESTIMONY_PASSES := {"says": "shows what being kept is like", "beats": [&"covenant_fed"]}


# --- what was done to the player (channel 4: the player's own state) -----------
#
# Beats that land because of something that HAPPENED to the player or that they
# did, never because of where they walked (docs/STORY.md §13). WITNESS_ON is what
# 49_story watches for, by event; WITNESSED says each in words, so a writer can see
# every door a beat has and a test can hold every beat to having one.

const WITNESS_ON := {
	&"filed": &"on_record_dead",
	&"record": &"counted",
	&"signet": &"your_key",
	&"other_realm": &"seeker",
	&"hunted": &"noticed",
	&"works_dark": &"holdfast_price",
}
## The signet only means his own old password once he knows he had one.
const SIGNET_AFTER := &"built_halcyon"

const WITNESSED := {
	&"on_record_dead": "a clerk files the player, and the record already has him",
	&"counted": "a record taken off a carrier comes into the creel",
	&"your_key": "the signet fires, once his old passwords are known of",
	&"seeker": "the player stands below the world or above it (not in the Before, which is his own past)",
	&"noticed": "the region the player stands in is hunting them",
	&"holdfast_price": "a works yard is put dark",
}


# --- reading the tables -------------------------------------------------------

## What a machine is for, or {} for anything that is not the plan's.
static func testimony(role: StringName, row: Dictionary) -> Dictionary:
	if not bool(row.get("machine", false)):
		return {}
	var keeper := StringName(str(row.get("sentinel", &"")))
	if keeper != &"":
		if KEEPER_MEMORY.has(keeper):
			return {"says": KEEPER_MEMORY[keeper].says, "beats": [&"gap"]}
		return TESTIMONY_SENTINEL
	if bool(row.get("passes", false)):
		return TESTIMONY_PASSES
	return TESTIMONY.get(role, {})


static func arc_beats(arc: StringName) -> Array:
	return ARCS.get(arc, {}).get("beats", [])


static func arcs() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ARCS:
		out.append(id)
	return out


## Beats that reading `id` or choosing it lands. `id` is a fragment id, or a
## choice's own id (`talk.node`), so the tables stay flat and a dev page can list
## everything that can land a beat in one pass.
static func beats_from(id: StringName) -> Array:
	var f: Dictionary = FRAGMENTS.get(id, {})
	if not f.is_empty():
		return f.get("beats", [])
	return []


static func beat_says(id: StringName) -> String:
	return String(BEATS.get(id, {}).get("says", ""))


static func beat_arc(id: StringName) -> StringName:
	return StringName(str(BEATS.get(id, {}).get("arc", &"")))


## Every beat declared, in arc order: what dev mode's story page lists.
static func all_beats() -> Array[StringName]:
	var out: Array[StringName] = []
	for arc: StringName in ARCS:
		for b: StringName in arc_beats(arc):
			out.append(b)
	return out
