## Sorrel counts what goes into the machine city and what comes out. A local: colour, never load (docs/STORY.md §8).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"sorrel", "name": "Sorrel", "title": "a gate-counter",
		"at": &"local_machine_city", "talk": &"sorrel", "trade": &"keeper",
		"look": {"build": &"slight", "hair": &"fair", "hair_style": &"crop", "beard": &"none"},
		"wants": "The two numbers to match, one day, so she can stop.",
		"fears": "Being counted herself.",
		"hides": "She keeps the tally on her arm, because paper can be taken and read.",
	})
