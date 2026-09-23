## Perrin grafts trees in an orchard the machines still feed. A local: colour, never load (docs/STORY.md).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"perrin", "name": "Perrin", "title": "a grafter",
		"at": &"local_grey_orchards", "talk": &"perrin", "trade": &"gatherer",
		"look": {"build": &"old", "hair": &"white", "hair_style": &"thin", "beard": &"stache"},
		"wants": "To keep one row alive that the sprayers have no schedule for.",
		"fears": "That the schedule is the only thing still holding the place together.",
		"hides": "He eats what the orchard makes, knowing what it is sprayed with.",
	})
