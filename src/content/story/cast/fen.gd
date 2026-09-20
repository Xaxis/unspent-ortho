## Fen walks the crags, where the machines' survey does not go. A local: colour, never load (docs/STORY.md §8).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"fen", "name": "Fen", "title": "a wayfinder",
		"at": &"local_the_crags", "talk": &"fen", "trade": &"gatherer",
		"look": {"build": &"woman", "hair": &"dark", "hair_style": &"unkempt", "beard": &"none"},
		"wants": "To know what the machines know, which she suspects is nothing.",
		"fears": "That they left it out because it is worse than they are.",
		"hides": "She has been further in than she tells people, and came back by a way she cannot find again.",
	})
