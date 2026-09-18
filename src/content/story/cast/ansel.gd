## Ansel watches the moss drain, roof by roof. A local: colour, never load (docs/STORY.md §8).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"ansel", "name": "Ansel", "title": "a pump-watcher",
		"at": &"local_moss", "talk": &"ansel", "trade": &"cutter",
		"look": {"build": &"old", "hair": &"white", "hair_style": &"thin", "beard": &"chin"},
		"wants": "To see his mother's village come up out of the water.",
		"fears": "That they will drain it and never look at the roofs.",
		"hides": "The dam that drowned the valley was opened on an order that checked out.",
	})
