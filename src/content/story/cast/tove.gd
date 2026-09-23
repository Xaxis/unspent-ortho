## Tove fishes a seal hole on the frost sea, where nobody lives, from a camp by its nearest landmark. A local: colour, never load (docs/STORY.md §8).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"tove", "name": "Tove", "title": "an ice-fisher",
		"at": &"local_frost_sea", "talk": &"tove", "trade": &"gatherer",
		"look": {"build": &"squat", "hair": &"fair", "hair_style": &"long", "beard": &"none"},
		"wants": "A thaw, once, so she can say she saw the water her gran fished.",
		"fears": "Whatever they are listening to hearing her back.",
		"hides": "She has put her own ear to the ice, and heard it, and gone back every still night since.",
	})
