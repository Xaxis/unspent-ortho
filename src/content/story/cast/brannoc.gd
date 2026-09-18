## Brannoc walks the pylons over the snow and listens to the wires. A local: colour, never load (docs/STORY.md §8).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"brannoc", "name": "Brannoc", "title": "a line-walker",
		"at": &"local_snowfield", "talk": &"brannoc", "trade": &"courier",
		"look": {"build": &"tall", "hair": &"grey", "hair_style": &"unkempt", "beard": &"full", "hat": &"furhat"},
		"wants": "Somebody to tell what the wires say.",
		"fears": "Being right about the number.",
		"hides": "One number on the wires gets smaller every winter. He thinks it is the people.",
	})
