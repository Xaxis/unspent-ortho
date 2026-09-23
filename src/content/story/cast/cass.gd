## Cass reads the drowned city's ferry timetable, which nobody set. A local: colour, never load (docs/STORY.md).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"cass", "name": "Cass", "title": "a ferry-reader",
		"at": &"local_drowned_city", "talk": &"cass", "trade": &"courier",
		"look": {"build": &"woman", "hair": &"red", "hair_style": &"bun", "beard": &"none"},
		"wants": "One boat to be late, so she knows somebody is steering.",
		"fears": "Being aboard when the timetable runs out.",
		"hides": "She rode one once, to the end of the line, and will not say what was at the stop.",
	})
