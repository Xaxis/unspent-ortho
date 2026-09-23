## Hob sorts what the tide brings in, at the coast village along from Maren's. A local: colour, never load (docs/STORY.md §8).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"hob", "name": "Hob", "title": "a wrack-picker",
		"at": &"local_coast", "talk": &"hob", "trade": &"gatherer",
		"look": {"build": &"bent", "hair": &"grey", "hair_style": &"thin", "beard": &"full"},
		"wants": "One tide with nothing on it he has to explain.",
		"fears": "Rowing out to see where it comes from.",
		"hides": "He keeps the new things in a box under his bed, sorted, and has never sold one.",
	})
