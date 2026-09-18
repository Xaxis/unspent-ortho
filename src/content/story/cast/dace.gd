## Old Dace, who fought in the war. He leaves the crew once he knows who Elias is.
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"dace", "name": "Dace", "title": "an old soldier",
		"at": &"the_camp", "talk": &"dace", "trade": &"cutter",
		"look": {"build": &"old", "hair": &"white", "hair_style": &"thin", "beard": &"stache"},
		"gone_when": &"dace_left",
		"may_join": true,
		"wants": "To know why it happened.",
		"fears": "The answer.",
		"hides": "He launched a missile on an order that was forged.",
	})
