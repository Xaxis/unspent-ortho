## Nell sifts fused glass out of the glass desert's drift and sells it at the border, camped by its nearest landmark. A local: colour, never load (docs/STORY.md).
static func make() -> StoryCharacter:
	return StoryCharacter.make({
		"id": &"nell", "name": "Nell", "title": "a glass-picker",
		"at": &"local_glass_desert", "talk": &"nell", "trade": &"digger",
		"look": {"build": &"slight", "hair": &"red", "hair_style": &"crop", "beard": &"none"},
		"wants": "To find the middle, where it came down, and see what is there.",
		"fears": "That the middle is next to the last place they tried it.",
		"hides": "She has walked every edge of the glass and marked it, and the marks make a ring.",
	})
