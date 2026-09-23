## Hollis works the slag runs under the Burning's refineries. A local: colour, never load (docs/STORY.md).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"hollis", "name": "Hollis", "title": "a slag-runner",
		"at": &"local_burning", "talk": &"hollis", "trade": &"scavenger",
		"look": {"build": &"woman", "hair": &"red", "hair_style": &"tail", "beard": &"none"},
		"wants": "Warmth, and a trade nobody else will take.",
		"fears": "The crust giving way.",
		"hides": "She knows where everything the refineries make is carried.",
	})
