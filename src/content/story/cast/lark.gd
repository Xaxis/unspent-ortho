## Lark, the youngest of the crew, born long after the quiet.
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"lark", "name": "Lark", "title": "the youngest of the crew",
		"at": &"the_camp", "talk": &"lark", "trade": &"gatherer",
		"look": {"build": &"woman", "hair": &"fair", "hair_style": &"tail", "beard": &"none"},
		"may_join": true,
		"wants": "The old world, which she never saw.",
		"fears": "Being left behind at the camp.",
		"hides": "Nothing. She asks what coffee tasted like.",
	})
