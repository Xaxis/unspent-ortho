## Orin walks the mesas' trestles and knows the haulers by their note. A local: colour, never load (docs/STORY.md).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"orin", "name": "Orin", "title": "a trestle-walker",
		"at": &"local_mesas", "talk": &"orin", "trade": &"fixer",
		"look": {"build": &"tall", "hair": &"black", "hair_style": &"tail", "beard": &"chin"},
		"wants": "To hear the note change, once, before he is too deaf for it.",
		"fears": "The day they stop crossing, because then they have enough.",
		"hides": "He has counted the crossings for nine years and never told anyone the total.",
	})
