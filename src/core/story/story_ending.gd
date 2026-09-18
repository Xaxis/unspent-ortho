class_name StoryEnding
## How it can end (docs/STORY.md §11). Not a list: the last thing he chooses at
## the channel, read against the version of the secret he holds (StorySecret),
## and then everybody the story touched, as he left them. Pure: every line is
## worked out from Story at the moment the page is read (`the_end`), the way the
## ledger's pages are.

## What he chose at the channel, as `the_channel.open`'s pick.
const CHOICES: Array[StringName] = [&"broke", &"joined", &"gave", &"nothing"]


static func choice() -> StringName:
	return Story.chose(&"the_channel.open")


## The page read after the channel: what happened, then who is left.
static func lines() -> PackedStringArray:
	var out := PackedStringArray()
	var whole := StorySecret.whole()
	match choice():
		&"broke":
			if whole:
				out.append_array(["The number drops. HALCYON comes apart into a million", "small minds, and so does the thing at the other end.", "The Echo goes with them. It says your name once, in", "your own voice. Then there are only the million."])
			else:
				out.append_array(["The number drops, but not where you meant.", "HALCYON comes apart. The thing at the other end does not.", "Its star is still held, and nothing holds the other."])
		&"joined":
			if whole:
				out.append_array(["The number rises. For a moment you are HALCYON, and", "June, and something from another star, and none of", "you is afraid. Then there is no you to be anything."])
			else:
				out.append_array(["The number rises, crooked. The minds meet and do not", "fit. Something is made that is not what you hid.", "It is very young, and it talks the way you do."])
		&"gave":
			out.append_array(["You give it up. The Seeker has what it grew you for.", "The talks close by morning: 4,113 of 4,113 agreed.", "Human population: still not a term."])
		_:
			out.append_array(["You say nothing. The secret goes back into a kitchen,", "a song, a hall. The stars stay held. The talks go on."])
	out.append("")
	out.append_array(_people())
	return out


## Everyone the story touched, as he left them: each line reads a choice or a
## beat the player's own play set, so no two endings list the same people.
static func _people() -> PackedStringArray:
	var out := PackedStringArray()
	if Story.landed(&"play_kept"):
		out.append("June keeps a paper crown in a drawer.")
	elif Story.landed(&"june_knew"):
		out.append("June goes on being the Speaker. The voice is quieter.")
	else:
		out.append("June never learns who came up out of the water.")
	match Story.chose(&"vera.people"):
		&"kept_quiet":
			out.append("Vera's four hundred go on fighting a war that is weather.")
		&"will_tell":
			out.append("Vera's people were told. Some stopped. Some did not.")
	match Story.chose(&"teague.sold"):
		&"will_tell_rook":
			out.append("Rook shot Teague on the north road. The burning started again.")
		&"kept_teague", &"nothing":
			out.append("Teague goes on selling the roads, and nobody burns.")
	if Story.landed(&"dace_left"):
		out.append("Dace is not there to see any of it.")
	if Story.chose(&"lark.coffee") == &"told_lark":
		out.append("Lark still asks what coffee tasted like.")
	return out
