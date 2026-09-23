## Gil ties rags to the Middens' walls so people can find their way out, camped by its nearest landmark. A local: colour, never load (docs/STORY.md).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"gil", "name": "Gil", "title": "a rag-marker",
		"at": &"local_the_middens", "talk": &"gil", "trade": &"courier",
		"look": {"build": &"stark", "hair": &"black", "hair_style": &"tail", "beard": &"chin"},
		"wants": "To reach the bottom of one tip before they cover it.",
		"fears": "Reading something down there with his own name in it.",
		"hides": "He keeps every piece of paper he finds, dry, in a hulk only he can find his way back to.",
	})
