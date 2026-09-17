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
##   BEATS     what the player knows once one lands (the journal's own line)
##   FRAGMENTS what is written on a thing that can be read
##   TALKS     what a person says, and what the player may say back
##
## A fragment or a choice may carry beats: reading the thing IS the knowing.

# --- the threads --------------------------------------------------------------

const ARCS := {
	&"account": {
		"title": "the account",
		"note": "What the machines are keeping, and who is keeping it.",
		"beats": [&"repeats", &"clerks_words", &"the_filed", &"unattested", &"no_outside"],
	},
	&"tide": {
		"title": "the tide",
		"note": "The world repeats, in small ways, and somebody wrote it down.",
		"beats": [&"tide_noticed", &"tide_written", &"tide_named"],
	},
}

const BEATS := {
	&"repeats": {"arc": &"account", "says": "Things happen at the same minute twice."},
	&"clerks_words": {"arc": &"account", "says": "The machines' words are not war words. They are a clerk's."},
	&"the_filed": {"arc": &"account", "says": "Somebody was taken, and came back agreeing."},
	&"unattested": {"arc": &"account", "says": "You are not hunted for what you did. You are hunted for what you are."},
	&"no_outside": {"arc": &"account", "says": "There is no outside to get to. There is only being a version they cannot check."},
	&"tide_noticed": {"arc": &"tide", "says": "The tide came in at the same minute two days running."},
	&"tide_written": {"arc": &"tide", "says": "You are not the first to write it down."},
	&"tide_named": {"arc": &"tide", "says": "The machines have a word for it, and the word is not weather."},
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
			"A cutter's hand, small, and the same three words down the margin:",
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
			"The next page is a list of stones, and where they were put.",
		],
		"beats": [&"repeats"],
	},
	&"came_back": {
		"kind": &"notebook", "title": "a page torn from further in", "lands": [],
		"lines": [
			"\"They brought Halm back on the Thursday and he was well.",
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
			"Four strokes, and a fifth across them, the way a count is kept.",
			"Under it, scratched deeper, by somebody who came later:",
			"",
			"  we are the six thousandths",
		],
		"beats": [&"unattested"],
	},
	&"keys_note": {
		"kind": &"mark", "title": "scratched inside a door frame", "lands": [],
		"lines": [
			"\"They have not got my name and they are not having it.\"",
			"",
			"No date. The wood around it has been painted over twice",
			"and cut back to it twice.",
		],
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
}

# --- reading the tables -------------------------------------------------------

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
