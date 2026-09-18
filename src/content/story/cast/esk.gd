## Esk sets the bonelands' standing stones back up. A local: colour, never load (docs/STORY.md §8).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"esk", "name": "Esk", "title": "a stone-setter",
		"at": &"local_bonelands", "talk": &"esk", "trade": &"cutter",
		"look": {"build": &"heavy", "hair": &"grey", "hair_style": &"crop", "beard": &"full"},
		"wants": "The stones to stand.",
		"fears": "That the drill grids take the last of them.",
		"hides": "He believes the machines leave graves alone. They do not; they have counted them.",
	})
