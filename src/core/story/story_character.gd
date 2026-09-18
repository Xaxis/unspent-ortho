class_name StoryCharacter
extends RefCounted
## One named person (docs/STORY_SYSTEM.md §8): who they are, where they stand, and
## when they are there. A file under src/content/story/cast/ makes one; StoryCast
## finds them all.
##
## A character is anchored to a PLACE, never to a body: villagers are streamed and
## nothing may hang on one body being one person, so a named person's persistence
## comes from the story slot they stand at, the way a works depot's does. Their
## development is BEATS: `appears_when` brings them in, `gone_when` takes them away,
## and both are story state that is already saved.

var id: StringName = &""
## What he calls them once he knows it.
var name: String = ""
## What the talk panel says before he does ("the fire-keeper").
var title: String = ""
## The spine slot they stand at (StoryPlan.SPINE).
var at: StringName = &""
## Their conversation in StoryContent.TALKS, marked there with `cast` = this id.
var talk: StringName = &""
## How they are dressed: a trade in PersonLook.TRADES.
var trade: StringName = &"keeper"
## Fields laid over a look dealt from their id (build, hair, beard, ...), so a
## writer says only what matters about how they look.
var look: Dictionary = {}
## A beat that must have landed before they are there, or &"" for always. A
## revelation must also have been felt (StoryPacing.felt): nobody walks in on the
## minute their name is said.
var appears_when: StringName = &""
## A beat after which they are gone, or &"" for never.
var gone_when: StringName = &""
## Whether they can walk with him (docs/STORY.md §8). Following and control are
## the actors' business; the story says only who may.
var may_join := false
## For the writer and dev mode: what the story is built on.
var wants := ""
var fears := ""
var hides := ""


static func make(d: Dictionary) -> StoryCharacter:
	var c := StoryCharacter.new()
	c.id = StringName(str(d.get("id", &"")))
	c.name = str(d.get("name", ""))
	c.title = str(d.get("title", ""))
	c.at = StringName(str(d.get("at", &"")))
	c.talk = StringName(str(d.get("talk", &"")))
	c.trade = StringName(str(d.get("trade", &"keeper")))
	c.look = d.get("look", {})
	c.appears_when = StringName(str(d.get("appears_when", &"")))
	c.gone_when = StringName(str(d.get("gone_when", &"")))
	c.may_join = bool(d.get("may_join", false))
	c.wants = str(d.get("wants", ""))
	c.fears = str(d.get("fears", ""))
	c.hides = str(d.get("hides", ""))
	return c


## Whether they are there now, by the story so far.
func present() -> bool:
	if appears_when != &"" and not StoryPacing.felt(appears_when):
		return false
	return gone_when == &"" or not Story.landed(gone_when)
