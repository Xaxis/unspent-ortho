## Maren, the fire-keeper who pulls him out of the surf (docs/STORY.md).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"maren", "name": "Maren", "title": "the fire-keeper",
		"at": &"home", "talk": &"maren", "trade": &"keeper",
		"look": {"build": &"woman", "hair": &"grey", "hair_style": &"bun", "beard": &"none"},
		"wants": "Her village left alone.",
		"fears": "That the crew bring the hunters.",
		"hides": "Nothing yet.",
	})
