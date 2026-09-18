extends TestCase
## A save's picture reads in both formats, because the better picture was bought
## by changing the one the game WRITES and not the ones already on disk.
##
## Saves written before 2026-09-18 carry a 160x90 PNG; ones written since carry
## a 320x180 JPEG (05_save.THUMB has the measurements — four times the pixels at
## 86% of the bytes, so nothing was traded for it). The format was never a
## contract anywhere but `SaveSlots.thumbnail`: `SaveFile` md5s the base64 string
## and never looks inside it. So this is an ADDITIVE reader, not a migration, and
## that claim is what these tests hold.
##
## They also hold the truncation guard on the new format. The PNG test exists
## because handing broken bytes to the decoder fills the log with CRC errors
## rather than returning a clean null; a JPEG decoder does the same, and the
## reason that guard is needed does not change with the format.

## 05_save.gd is a system and has no class_name: it is loaded by file, like the
## runner loads it.
const Save := preload("res://src/systems/05_save.gd")


static func _png(size: Vector2i) -> PackedByteArray:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGB8)
	img.fill(Color(0.3, 0.5, 0.7))
	return img.save_png_to_buffer()


static func _jpg(size: Vector2i) -> PackedByteArray:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGB8)
	img.fill(Color(0.3, 0.5, 0.7))
	return img.save_jpg_to_buffer(0.8)


static func _header(raw: PackedByteArray) -> Dictionary:
	return {"thumb": Marshalls.raw_to_base64(raw)}


func test_a_save_written_before_the_change_still_shows_its_picture() -> void:
	var old := _png(Vector2i(160, 90))
	check(SaveSlots.is_png(old), "the old format is still recognised")
	var tex := SaveSlots.thumbnail(_header(old))
	check(tex != null, "a PNG thumb still decodes — no save on disk lost its picture")
	if tex != null:
		eq(tex.get_size(), Vector2(160, 90), "at the size it was written")


func test_a_save_written_since_shows_its_picture() -> void:
	var now := _jpg(Save.THUMB)
	check(SaveSlots.is_jpg(now), "the new format is recognised")
	check(not SaveSlots.is_png(now), "and is not mistaken for the old one")
	var tex := SaveSlots.thumbnail(_header(now))
	check(tex != null, "a JPEG thumb decodes")
	if tex != null:
		eq(tex.get_size(), Vector2(Save.THUMB), "at the size it is captured AND drawn (no upscale)")


func test_the_new_picture_is_four_times_the_pixels() -> void:
	gt(float(Save.THUMB.x * Save.THUMB.y), float(160 * 90) * 3.9, "four times the pixels")
	# AND THE BYTE CLAIM IS NOT TESTED HERE, deliberately. That it is also SMALLER
	# than the 160x90 PNG it replaced is true of a real frame and false of any
	# picture cheap enough to build in a test: a flat fill is a handful of bytes
	# as PNG and cannot lose to a JPEG of anything. Asserting it on a synthetic
	# image would be measuring a subject chosen to give the answer wanted, which
	# is the whole failure docs/LOOK.md spends a chapter on — this test was
	# written that way first and failed, which is the only reason the note is
	# here. The real numbers are in `05_save.THUMB`, taken off a real frame with
	# `shots/tour/marks/03-*.png`: 39 KB against 34 KB, base64, four times the
	# pixels. Re-measure there, on a frame, if it is ever doubted.


func test_a_half_written_picture_is_refused_before_the_decoder_sees_it() -> void:
	var whole := _jpg(Save.THUMB)
	check(not SaveSlots.is_jpg(whole.slice(0, whole.size() - 1)), "a JPEG cut short")
	check(not SaveSlots.is_jpg(whole.slice(0, 40)), "a JPEG cut to its head")
	eq(SaveSlots.thumbnail(_header(whole.slice(0, whole.size() - 1))), null, "and none is shown")
	check(not SaveSlots.is_jpg("not a jpeg at all, but long enough to be one maybe".to_utf8_buffer()), "text")
	eq(SaveSlots.thumbnail({"thumb": ""}), null, "no picture at all is not an error")


## The one link the headless runner CAN reach of the real capture path, and the
## one that was actually at risk: a viewport hands back RGBA8 and JPEG has no
## alpha, so the encoder sees a format it cannot write unless somebody converts.
## This fails if that conversion is ever dropped.
func test_a_picture_straight_off_a_viewport_encodes() -> void:
	var rgba := Image.create_empty(Save.THUMB.x, Save.THUMB.y, false, Image.FORMAT_RGBA8)
	rgba.fill(Color(0.3, 0.5, 0.7, 1.0))
	var raw := Save.photo(rgba)
	check(not raw.is_empty(), "an RGBA8 frame still encodes to something")
	check(SaveSlots.is_jpg(raw), "and what it encodes to is a whole JPEG")
	check(SaveSlots.thumbnail({"thumb": Marshalls.raw_to_base64(raw)}) != null,
		"that reads back as a picture")
	eq(Save.photo(null), PackedByteArray(), "and no frame at all is not an error (headless)")


func test_the_capture_and_the_drawing_agree() -> void:
	# The upscale is gone, and it stays gone: two constants in two packages that
	# have to name one number, which is exactly the shape that drifts.
	eq(Save.THUMB, UiSavesScreen.THUMB,
		"a save's picture is captured at the size it is drawn, or it is soft again")
