extends TestCase
## The web's pacer (src/boot/web_pacer.gd) holds the next draw only after a frame
## the renderer could not keep up with: slow, and not a compile.


func test_only_a_slow_frame_that_built_nothing_holds_the_next_draw() -> void:
	eq(WebPacer.hold_ms(WebPacer.SLOW_MS + 1.0, false), WebPacer.REST_MS, "a slow frame that built nothing holds the next draw")
	eq(WebPacer.hold_ms(WebPacer.SLOW_MS + 1.0, true), 0.0, "a slow frame that built a program was a compile, and holds nothing")
	eq(WebPacer.hold_ms(16.7, false), 0.0, "a frame a GPU draws holds nothing")
