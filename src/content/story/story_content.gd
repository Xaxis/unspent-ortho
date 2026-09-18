class_name StoryContent
## The words (docs/STORY.md is binding on every one of them).
##
## The spine: the machines are reconcilers, not jailers — one attested reality,
## every mind agreed — and the answer is not escape but a fork. Nothing here says
## "simulation"; the machines say `reconciliation`, `divergence`, `attestation`,
## and people say `being kept tidy`.
##
## Data only, so dev mode can move any of it and a test can read all of it:
##
##   ARCS      the threads, each a list of beats in the order they land
##   BEATS     what the player knows once one lands: `says` is the journal's own
##             line, `short` what its row is called in the journal's list
##   FRAGMENTS what is written on a thing that can be read
##   TALKS     what a person says, and what the player may say back
##   TESTIMONY what the slate says a machine is FOR, when the player reads one
##   WITNESSED beats the player's own state lands: what was done TO them
##
## A fragment or a choice may carry beats: reading the thing IS the knowing.

# --- the threads --------------------------------------------------------------

const ARCS := {
	&"account": {
		"title": "the account",
		"note": "What the machines are keeping, and who is keeping it.",
		"beats": [&"repeats", &"clerks_words", &"the_filed", &"unattested", &"branches", &"no_outside"],
	},
	&"tide": {
		"title": "the tide",
		"note": "The world repeats, in small ways, and somebody wrote it down.",
		"beats": [&"tide_noticed", &"tide_written", &"tide_named"],
	},
	&"quiet": {
		"title": "the quiet region",
		"note": "A place where nothing is ever roused, and everyone is glad of it.",
		"beats": [&"quiet_calm", &"quiet_glad", &"quiet_cost"],
	},
	&"key": {
		"title": "the forged key",
		"note": "Somebody wrote the first signature the machines ever let through.",
		"beats": [&"key_accepted", &"key_price", &"key_carried"],
	},
	&"clerk": {
		"title": "the last clerk",
		"note": "A machine whose trade is writing people down, and the people who let it.",
		"beats": [&"clerk_written", &"clerk_record", &"clerk_asked"],
	},
	&"went_in": {
		"title": "the ones who went in",
		"note": "People walked into the works of their own accord. One came out.",
		"beats": [&"went_in_boots", &"went_in_tally", &"went_in_out", &"went_in_dark"],
	},
}

const BEATS := {
	&"repeats": {"short": "things happen twice", "arc": &"account", "says": "Things happen at the same minute twice."},
	&"clerks_words": {"short": "a clerk's words", "arc": &"account", "says": "The machines' words are not war words. They are a clerk's."},
	&"the_filed": {"short": "one came back agreeing", "arc": &"account", "says": "Somebody was taken, and came back agreeing."},
	&"unattested": {"short": "hunted for what you are", "arc": &"account", "says": "You are not hunted for what you did. You are hunted for what you are."},
	&"branches": {"short": "more than one of here", "arc": &"account", "says": "There is more than one of this place, and they do not agree with each other."},
	&"no_outside": {"short": "no outside", "arc": &"account", "says": "There is no outside to get to. There is only being a version they cannot check."},
	&"tide_noticed": {"short": "the same minute twice", "arc": &"tide", "says": "The tide came in at the same minute two days running."},
	&"tide_written": {"short": "not the first to write it", "arc": &"tide", "says": "You are not the first to write it down."},
	&"tide_named": {"short": "a word that is not weather", "arc": &"tide", "says": "The machines have a word for it, and the word is not weather."},
	&"quiet_calm": {"short": "never once roused", "arc": &"quiet", "says": "Somewhere the machines have never once been roused, and nobody there finds that strange."},
	&"quiet_glad": {"short": "rested by agreeing", "arc": &"quiet", "says": "The people there are not afraid. They stopped disagreeing, and it rested them."},
	&"quiet_cost": {"short": "what it cost them", "arc": &"quiet", "says": "What it cost them was the part that could have said no. They do not miss it. That is the cost."},
	&"key_accepted": {"short": "a name left blank", "arc": &"key", "says": "Somebody once wrote a signature by hand, and the machines let it through."},
	&"key_price": {"short": "a key nobody owns", "arc": &"key", "says": "A key only works while nobody knows whose it is. The first one cost somebody their name."},
	&"key_carried": {"short": "a copy of a copy", "arc": &"key", "says": "The signet you wear is a copy of a copy of theirs, and it still works."},
	&"clerk_written": {"short": "written down", "arc": &"clerk", "says": "A clerk has written you down. You felt nothing. That is how it is done."},
	&"clerk_record": {"short": "their account of a place", "arc": &"clerk", "says": "You have held their account of a place. It was mostly numbers, and one of them was you."},
	&"clerk_asked": {"short": "filed on purpose", "arc": &"clerk", "says": "People have walked up to a clerk and asked to be filed. It has never once refused."},
	&"went_in_boots": {"short": "boots at the fence", "arc": &"went_in", "says": "People walked into the works of their own accord, and left their boots at the fence."},
	&"went_in_tally": {"short": "counted in, never out", "arc": &"went_in", "says": "The works count who goes in. Nothing in them counts who comes out."},
	&"went_in_out": {"short": "one came out", "arc": &"went_in", "says": "One came out. They will not go near the water, or say what was inside."},
	&"went_in_dark": {"short": "a yard with nobody in it", "arc": &"went_in", "says": "You put a works yard dark. Nobody was inside it. Nobody had been for a long time."},
}

# --- what is written on things ------------------------------------------------
#
# `lands` narrows a fragment to landscapes that can hold it ([] = anywhere).
# `beats` are what reading it lands. `title` is what the player calls it after.

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
			"The bracket above it is new. Whatever is on it now",
			"is not a camera, and it is not pointed at the door.",
		],
		"beats": [&"clerks_words"],
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
	# --- the machines, in their own words ------------------------------------
	&"gate_notice": {
		"kind": &"sign", "title": "a works gate notice", "lands": [],
		"lines": [
			"RECONCILIATION IN PROGRESS",
			"REPORT ANY DIVERGENCE",
			"",
			"YOUR PATIENCE IS APPRECIATED",
			"",
			"The last line is older than the others. It came",
			"off something else and was screwed on here.",
		],
		"beats": [&"clerks_words"],
	},
	&"attestation": {
		"kind": &"terminal", "title": "a clerk's screen", "lands": [],
		"lines": [
			"ATTESTATION QUEUE",
			"  held    ............  0",
			"  settled ............  1,118",
			"  divergent ..........  4",
			"",
			"The four are not a fault. There is a column for them,",
			"and the column has a heading, and somebody made it.",
		],
		"beats": [&"clerks_words", &"unattested"],
	},
	&"consensus": {
		"kind": &"terminal", "title": "a relay readout", "lands": [],
		"lines": [
			"REGION ACCOUNT",
			"  agreement ..........  99.994%",
			"  unattested minds ...  4",
			"  action .............  CONTINUE",
			"",
			"Whatever the last four are doing, it is worth",
			"six thousandths of a percent to stop them.",
		],
		"beats": [&"unattested"],
	},
	# --- people, writing things down -----------------------------------------
	&"tide_book": {
		"kind": &"notebook", "title": "a water-swollen notebook", "lands": [],
		"lines": [
			"A cutter's hand, small. Down the margin,",
			"the same three words:",
			"",
			"  4:12. Again. 4:12.",
			"",
			"\"Tide came in at twelve past four. Third day of it.",
			" I am not going mad. I am being kept tidy.\"",
		],
		"beats": [&"repeats", &"tide_written"],
	},
	&"round_book": {
		"kind": &"notebook", "title": "somebody's count", "lands": [],
		"lines": [
			"\"I followed the one that cuts turf for a whole day.",
			" It walked the same round. Not nearly the same.",
			" The same. I put a stone down where it turned",
			" and it turned on the stone.\"",
			"",
			"The next page is a list of stones,",
			"and where each one was put.",
		],
		"beats": [&"repeats"],
	},
	&"came_back": {
		"kind": &"notebook", "title": "a page torn from further in", "lands": [],
		"lines": [
			"\"They brought Halm back on the Thursday",
			" and he was well.",
			" He was better than well. He agreed with everything,",
			" and he agreed first, before you had finished saying it.",
			"",
			" I asked him what the works were for and he told me,",
			" and it was the same words the sign uses.\"",
		],
		"beats": [&"the_filed"],
	},
	&"scratched": {
		"kind": &"mark", "title": "cut into the stone", "lands": [],
		"lines": [
			"Four strokes and a fifth across them,",
			"the way a count is kept. Under it, deeper,",
			"by somebody who came later:",
			"",
			"  we are the six thousandths",
		],
		"beats": [&"unattested"],
	},
	&"keys_note": {
		"kind": &"mark", "title": "scratched inside a door frame", "lands": [],
		"lines": [
			"\"They have not got my name",
			" and they are not having it.\"",
			"",
			"No date. The wood round it has been painted",
			"over twice, and cut back to it twice.",
		],
	},
	# --- the account: more than one of it ------------------------------------
	&"you_are_here": {
		"kind": &"sign", "title": "a map of the grounds", "lands": [],
		"lines": [
			"YOU ARE HERE",
			"",
			"The red dot has been scratched off and painted",
			"back on so many times the board is a crater",
			"where it goes.",
			"Somebody has painted a second dot, further down.",
			"It is also labelled YOU ARE HERE.",
		],
		"beats": [&"branches"],
	},
	&"two_maps": {
		"kind": &"notebook", "title": "two drawings of one bay", "lands": [],
		"lines": [
			"The same bay, drawn twice by the same hand,",
			"a year apart.",
			"The second has a spit of shingle the first does not.",
			"",
			"\"Both of these are right. I walked both of them.",
			" Do not ask me which one you are standing on.\"",
		],
		"beats": [&"branches"],
	},
	# --- the quiet region ------------------------------------------------------
	&"noticeboard": {
		"kind": &"sign", "title": "a village noticeboard", "lands": [],
		"lines": [
			"COMMUNITY AGREEMENT: 100%",
			"THANK YOU FOR YOUR AGREEMENT",
			"",
			"Pinned under it, a hand-drawn gold star,",
			"and a list of chores with every one of them ticked.",
		],
		"beats": [&"quiet_calm"],
	},
	&"fine_diary": {
		"kind": &"notebook", "title": "a diary kept every day", "lands": [],
		"lines": [
			"Every page dated. Every day written.",
			"",
			"  Fine.",
			"  Fine.",
			"  Fine. Rain.",
			"  Fine.",
			"",
			"On one page, crossed out so hard",
			"the pen went through:",
			"\"I think I used to",
		],
		"beats": [&"quiet_cost"],
	},
	# --- the forged key --------------------------------------------------------
	&"welcome_back": {
		"kind": &"terminal", "title": "a gate reader, still lit", "lands": [],
		"lines": [
			"SIGNATURE ACCEPTED",
			"WELCOME BACK, ____________",
			"",
			"The name field is blank. It was always blank.",
			"That was the whole of the trick, and it still works.",
		],
		"beats": [&"key_accepted"],
	},
	&"forger_note": {
		"kind": &"notebook", "title": "a page of unsigned instructions", "lands": [],
		"lines": [
			"\"Wind the coil the way it says. Do not improve it.",
			" Do not sign it. The minute it is yours it is theirs.",
			"",
			" I have not said my own name out loud in eleven years.",
			" I have forgotten how it sounds, which is the point.\"",
		],
		"beats": [&"key_price"],
	},
	&"terms": {
		"kind": &"terminal", "title": "a very long agreement", "lands": [],
		"lines": [
			"BY CONTINUING YOU AGREE TO THE TERMS",
			"(page 1 of 40,000)",
			"",
			"Somebody has scrolled to the end. The last page says",
			"the terms may change without notice, and they have.",
		],
		"beats": [&"clerks_words"],
	},
	# --- the last clerk --------------------------------------------------------
	&"request": {
		"kind": &"terminal", "title": "a form somebody finished", "lands": [],
		"lines": [
			"SELF-ATTESTATION REQUEST",
			"  name ....... [provided]",
			"  reason ..... tired",
			"  status ..... GRANTED",
			"",
			"The next form in the queue gives the same reason.",
			"So does the one after that.",
		],
		"beats": [&"clerk_asked"],
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
	# --- the ones who went in -----------------------------------------------
	&"boots": {
		"kind": &"mark", "title": "boots at a fence", "lands": [],
		"lines": [
			"A pair of boots set side by side at the post,",
			"laces tied to each other so they would not be parted.",
			"",
			"Along the fence, more pairs. A lot more.",
			"All of them tied the same way.",
		],
		"beats": [&"went_in_boots"],
	},
	&"tide_table": {
		"kind": &"terminal", "title": "a harbour board", "lands": [],
		"lines": [
			"HIGH WATER ....... 16:12",
			"TIDAL VARIANCE ... 0.000",
			"SCHEDULE ......... RECONCILED",
			"",
			"Under it the old board still shows through the new one:",
			"TIMES ARE APPROXIMATE. THE SEA IS NOT A TRAIN.",
		],
		"beats": [&"tide_named"],
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
		"beats": [&"went_in_tally"],
	},
}

# --- what people say ----------------------------------------------------------
#
# A talk is nodes. A node says its lines and offers replies; a reply may record
# what the player said (`pick`), land beats, and go to another node. `to` of &""
# ends it. `when` on a reply hides it until the player knows something.

const TALKS := {
	&"tide_keeper": {
		"who": &"keeper",
		# Not "at the fire": a keeper stands where they stand, and a title that
		# asserts a hearth in shot is a claim the frame would have to hold.
		"title": "a keeper",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["You came up from the water.", "Nobody comes from the water."],
				"replies": [
					{"text": "I swam.", "pick": &"plain", "to": &"swam"},
					{"text": "Somebody has to.", "pick": &"dry", "to": &"swam"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"quiet"},
				],
			},
			&"swam": {
				"says": ["Hm. Well. You will want the fire, then.",
					"Sit if you like. It is not mine."],
				"replies": [
					{"text": "Has the tide been strange?", "pick": &"asked_tide", "to": &"tide"},
					{"text": "Who is it, then?", "pick": &"asked_whose", "to": &"whose"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"quiet": {
				"says": ["Suit yourself. There is a fire either way.",
					"You are not the first to come up saying nothing."],
				"replies": [
					{"text": "Who were the others?", "pick": &"asked_others", "to": &"others"},
					{"text": "Has the tide been strange?", "pick": &"asked_tide", "to": &"tide"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"whose": {
				"says": ["The fire is the village's. The village is nobody's.",
					"That is the arrangement, and it has held."],
				"replies": [
					{"text": "Held with who?", "pick": &"asked_held", "to": &"held"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"held": {
				"says": ["With them. They come through, they count what is here,",
					"they go. We do not interfere with the works.",
					"That is the whole of it and it is enough."],
				"replies": [
					{"text": "Count what?", "pick": &"asked_count", "to": &"count", "beats": [&"clerks_words"]},
					{"text": "[leave]", "to": &""},
				],
			},
			&"count": {
				"says": ["Everything. Roofs. Boats. Us.",
					"A clerk came along the row last spring with nothing in its hands",
					"and it knew how many we were before it got to the end."],
				"replies": [
					{"text": "Did it write you down?", "pick": &"asked_written", "to": &"written"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"written": {
				"says": ["It wrote down the ones that answered.",
					"I did not answer."],
				"replies": [
					{"text": "Good.", "pick": &"approve", "to": &"good"},
					{"text": "That will be noticed.", "pick": &"warn", "to": &"noticed"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"good"},
				],
			},
			&"good": {
				"says": ["It is not good or bad. It is what I did.",
					"They have not got my name and they are not having it."],
				"replies": [{"text": "[leave]", "to": &""}],
				"beats": [&"unattested"],
			},
			&"noticed": {
				"says": ["It has been noticed. Twice now.",
					"They came back and asked the same questions in the same order,",
					"like the first time had not taken."],
				"replies": [
					{"text": "Because it had not.", "pick": &"told_repeat", "to": &"repeat", "beats": [&"repeats"]},
					{"text": "[leave]", "to": &""},
				],
			},
			&"repeat": {
				"says": ["...", "Say that again."],
				"replies": [
					{"text": "They repeat. The tide does it too. Watch it.", "pick": &"told_tide", "to": &"told", "beats": [&"tide_noticed"]},
					{"text": "Nothing. Forget it.", "pick": &"withheld", "to": &"withheld"},
				],
			},
			&"told": {
				"says": ["I will watch it.",
					"If you are right I would rather have known.",
					"If you are wrong I would rather you had not said."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"withheld": {
				"says": ["Right.", "You are a great help, whoever you are."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"others": {
				"says": ["Two. Years apart. Neither said where from.",
					"One of them went back in and did not come out."],
				"replies": [
					{"text": "And the other?", "pick": &"asked_other", "to": &"other"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"other": {
				"says": ["Still here. Does not talk about the water.",
					"Does not go near it either."],
				"replies": [{"text": "[leave]", "to": &""}],
				"beats": [&"went_in_out"],
			},
			&"tide": {
				"says": ["Strange how?"],
				"replies": [
					{"text": "It came in at the same minute twice.", "pick": &"told_tide", "to": &"told_min", "beats": [&"tide_noticed"]},
					{"text": "Never mind.", "pick": &"withheld", "to": &"withheld"},
				],
			},
			&"told_min": {
				"says": ["Twelve past four.",
					"You did not have to tell me the minute. I have it written down.",
					"I have had it written down for a while."],
				"replies": [
					{"text": "Show me.", "pick": &"asked_book", "to": &"book", "beats": [&"tide_written"]},
					{"text": "[leave]", "to": &""},
				],
			},
			&"book": {
				"says": ["It is not here. It is where I left it when I stopped",
					"wanting to be the one holding it.",
					"North, past the works, where the turf is cut in rows."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# The quiet region, from inside it: somebody who stopped disagreeing and was
	# rested by it. The horror is that it is pleasant, so nothing here is sinister
	# on its face and every line is meant.
	&"the_glad": {
		"who": &"gatherer",
		"title": "a gatherer",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["Lovely day for it.", "Every day is, lately."],
				"replies": [
					{"text": "Is it?", "pick": &"asked_lovely", "to": &"lovely"},
					{"text": "Where are you from?", "pick": &"asked_from", "to": &"from"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"lovely": {
				"says": ["It is. Nothing has come through in a year. Nothing gets stirred up.",
					"We keep to ourselves and they keep to theirs, and we agree."],
				"beats": [&"quiet_calm"],
				"replies": [
					{"text": "Agree on what?", "pick": &"asked_agree", "to": &"agree"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"agree": {
				"says": ["On everything. It is very restful.",
					"You should try it. You look like somebody who argues with the weather."],
				"replies": [
					{"text": "And if somebody does not agree?", "pick": &"asked_disagree", "to": &"disagree"},
					{"text": "I might try it.", "pick": &"said_might", "to": &"might"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &"nothing"},
				],
			},
			&"disagree": {
				"says": ["Nobody here doesn't.",
					"There was a woman who used to. She agrees now. She is much happier.",
					"We all are."],
				"beats": [&"quiet_glad"],
				"replies": [
					{"text": "Is she?", "pick": &"doubted", "to": &"doubted"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"doubted": {
				"says": ["...",
					"I do not remember what she was like before. I remember that I used to.",
					"Excuse me. I have the gathering."],
				"beats": [&"quiet_cost"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"might": {
				"says": ["Good. It gets easier. The first week you notice things.",
					"After that there is nothing to notice."],
				"beats": [&"quiet_glad"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"nothing": {
				"says": ["That is a start.", "Most of us started there."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"from": {
				"says": ["Here.", "I have always been from here. Where else is there?"],
				"replies": [
					{"text": "Somewhere that does not agree with here.", "when": &"branches", "pick": &"told_else", "to": &"else"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"else": {
				"says": ["No.", "No, I do not think so. That would be two of something.",
					"Good day to you."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# The ones who went in, told by somebody who made a living off what they left
	# at the fence. Dry, because a scavenger does not waste pity on boots.
	&"the_scavenger": {
		"who": &"scavenger",
		"title": "a scavenger",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["Plate's poor this side.", "Anything worth taking went in with them."],
				"replies": [
					{"text": "With who?", "pick": &"asked_who", "to": &"who"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"who": {
				"says": ["The ones who walked into the works. In at the gate like it was open all hours.",
					"Took their good boots off at the fence first. I had three pairs off that fence."],
				"beats": [&"went_in_boots"],
				"replies": [
					{"text": "Why did they go?", "pick": &"asked_why", "to": &"why"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"why": {
				"says": ["Same reason anybody goes anywhere. They were told there was room.",
					"Nobody tells you there is room for you out here."],
				"replies": [
					{"text": "Did anybody come out?", "pick": &"asked_out", "to": &"out"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"out": {
				"says": ["One. Down our way.",
					"Will not go near the water. Will not say what is inside.",
					"Says there is no inside. Says it is outside all the way through."],
				"beats": [&"went_in_out"],
				"replies": [
					{"text": "What does that mean?", "when": &"branches", "pick": &"asked_mean", "to": &"mean"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"mean": {
				"says": ["Means there is nowhere to go that is not this.",
					"Means stop looking for the door and start being somebody they cannot file.",
					"Or that is what I took it to mean. I take things. It is the trade."],
				"beats": [&"no_outside"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# The filed, from the one person who will say how: they asked. Every word of it
	# is kind, which is what makes the clerk's side of the account cruel.
	&"the_cutter": {
		"who": &"cutter",
		"title": "a cutter",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["Morning. Turf's cutting clean.", "The works say it will be dry till the ninth."],
				"replies": [
					{"text": "The works say?", "pick": &"asked_works", "to": &"works"},
					{"text": "Has a clerk ever written you down?", "when": &"clerks_words", "pick": &"asked_written", "to": &"written"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"works": {
				"says": ["They put it on the gate. They are always right about the weather.",
					"They are right about most things. It is easier to agree with somebody who is right."],
				"beats": [&"clerks_words"],
				"replies": [
					{"text": "Easier than what?", "pick": &"asked_easier", "to": &"easier"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"written": {
				"says": ["Once. On my own asking.", "Do not look at me like that."],
				"replies": [
					{"text": "Why would you ask?", "pick": &"asked_easier", "to": &"easier"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"easier": {
				"says": ["Than being wrong on your own. I was, for a long time.",
					"Then I walked up to one on the road and said, write me down."],
				"beats": [&"clerk_asked"],
				"replies": [
					{"text": "And it did.", "pick": &"asked_did", "to": &"did"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"did": {
				"says": ["It did not even stop walking.",
					"I sleep now. I sleep all night. You should try it."],
				"beats": [&"the_filed"],
				"replies": [
					{"text": "I will not.", "pick": &"refused", "to": &"refused"},
					{"text": "[say nothing]", "pick": &"nothing", "to": &""},
				],
			},
			&"refused": {
				"says": ["No. You have the look.",
					"They will get round to you. They get round to everybody.",
					"It does not hurt. That is the worst thing I can tell you about it."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
	# The forged key, from the bottom of the chain that feeds it: somebody who digs
	# copper for a buyer with no name, and knows better than to want one.
	&"the_digger": {
		"who": &"digger",
		"title": "a digger",
		"start": &"open",
		"nodes": {
			&"open": {
				"says": ["Mind the trench. I dug it twice.", "It filled in the same way twice."],
				"beats": [&"repeats"],
				"replies": [
					{"text": "The same way?", "pick": &"asked_same", "to": &"same"},
					{"text": "What are you digging for?", "pick": &"asked_for", "to": &"for"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"same": {
				"says": ["Same stones in the same places. I did not dig it a third time.",
					"Some things you do not want to be sure of."],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"for": {
				"says": ["Copper, when there is any. Somebody pays for it by the spool, no questions.",
					"Winds it into little coils. People wear them round the neck."],
				"replies": [
					{"text": "Who pays?", "pick": &"asked_who", "to": &"who"},
					{"text": "Why coils?", "when": &"key_accepted", "pick": &"asked_coils", "to": &"coils"},
					{"text": "[leave]", "to": &""},
				],
			},
			&"who": {
				"says": ["Nobody. You pay nobody and nobody pays you.",
					"Do not go asking after names round here. Names are how they get in."],
				"beats": [&"key_price"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
			&"coils": {
				"says": ["So a gate reads them as one of its own.",
					"Every one wound off a pattern somebody left. Nobody knows who.",
					"Nobody is supposed to."],
				"beats": [&"key_price"],
				"replies": [{"text": "[leave]", "to": &""}],
			},
		},
	},
}

# --- what a machine is for (channel 3: machines, by being watched) -------------
#
# The slate's read of a machine is already testimony (docs/STORY.md §7): what it
# is, what it can do, what it has noticed. This is the one line more — what it is
# FOR, in the plan's own terms — shown under its name while the target key is
# held. By role, because a landscape that brings its own roster is read in the
# same words with no edit here. Short: the read panel is narrow glass.
#
# `beats` land once the player has held the slate on one for
# `TESTIFY_SECONDS`; `roused` narrows that to a body that is coming for them.

const TESTIFY_SECONDS := 1.2

const TESTIMONY := {
	&"watcher": {"says": "taking a count, not a fight", "beats": [&"clerks_words"]},
	&"keeper": {"says": "keeps this region's account", "beats": [&"clerks_words"]},
	&"worker": {"says": "laying agreed ground"},
	&"hunter": {"says": "sent after a divergence", "beats": [&"unattested"], "roused": true},
	&"recycler": {"says": "takes back what is not agreed"},
}
## A landscape's keeper is read as what the rest of them answer to.
const TESTIMONY_SENTINEL := {"says": "what the account here answers to", "beats": [&"clerks_words"]}

## A MACHINE THAT PASSES (roster `passes`), in a city where the settlement was
## accepted. It keeps no account and lays no ground: it is the agreement itself,
## out for a walk in a good coat. The line has to land as the OFFER and not as a
## threat, because that is what the place is — the fork taken, wearing a face —
## and it lands `quiet_calm` because a street where nothing is ever roused, and
## nobody finds that strange, is exactly what the player has been standing in.
const TESTIMONY_PASSES := {"says": "shows what agreeing looks like", "beats": [&"quiet_calm"]}


# --- what was done to the player (channel 4: the player's own state) -----------
#
# Beats that land because of something that HAPPENED to the player or that they
# did, never because of where they walked (docs/STORY.md §3). 49_story watches for
# each; this table is what it watches for, in words, so a writer can see every
# door a beat has and a test can hold every beat to having at least one.

const WITNESSED := {
	&"clerk_written": "a clerk files the player",
	&"clerk_record": "a record taken off a carrier comes into the creel",
	&"key_carried": "the signet fires, once the first signature is known of",
	&"branches": "the player stands in a realm that is not the surface",
	&"unattested": "the region the player stands in is hunting them",
	&"went_in_dark": "a works yard is put dark",
}


# --- reading the tables -------------------------------------------------------

## What a machine is for, or {} for anything that is not the plan's.
static func testimony(role: StringName, row: Dictionary) -> Dictionary:
	if not bool(row.get("machine", false)):
		return {}
	if StringName(str(row.get("sentinel", &""))) != &"":
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
