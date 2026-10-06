class_name WebPacer
extends Node
## A SLOW RENDERER MUST NOT HOLD THE PAGE. Web only: main.gd adds it at boot.
##
## The page's main thread waits on the GPU inside a frame (WebGL calls that must
## answer), and on the web it is also the thread every other thread's file reads
## and prints are handed to (Emscripten proxies the file system there). Where a
## frame takes seconds to draw (SwiftShader on the Linux box, 10-06: 15-60 s at
## load 80-170) the main thread spent nearly all of its time inside frames, and
## everything waiting on it waited with it: the island's raise loading one script
## sat 880 s, the title's 256-tile coast took 66-1007 s to grow (0.7 s on a GPU),
## and a key was answered a frame late.
##
## So after a frame that took longer than SLOW_MS to draw and built no GL program
## (a build is a compile, and a compile passes; a renderer that cannot keep up
## does not), the next draw waits REST_MS: the page runs its frames' logic, its
## input and its threads' reads in between, then draws again. On a GPU no frame
## is that slow and nothing is held. A held frame is not a drawn one, so whatever
## counts frames it means to have drawn reads `RenderingServer.render_loop_enabled`
## (01_warm_lights): this runs first in every frame and sets it.

const SLOW_MS := 2000.0
const REST_MS := 1000.0

var _pre := 0
var _hold_until := 0
var _links := 0


## How long the next draw waits after one that took `drew_ms`.
static func hold_ms(drew_ms: float, built_a_program: bool) -> float:
	return REST_MS if drew_ms > SLOW_MS and not built_a_program else 0.0


func _ready() -> void:
	name = "web_pacer"
	process_mode = Node.PROCESS_MODE_ALWAYS
	# First in every frame, so the frame's other nodes read this frame's answer.
	process_priority = -1000000
	RenderingServer.frame_pre_draw.connect(_drawing)
	RenderingServer.frame_post_draw.connect(_drawn)


func _process(_delta: float) -> void:
	RenderingServer.render_loop_enabled = Time.get_ticks_usec() >= _hold_until


func _drawing() -> void:
	_pre = Time.get_ticks_usec()


func _drawn() -> void:
	var now := Time.get_ticks_usec()
	# The page counts every program it links (src/boot/shell.html).
	var links := int(JavaScriptBridge.eval("window.unspentLinks || 0", true))
	var built := links != _links
	_links = links
	_hold_until = now + int(WebPacer.hold_ms((now - _pre) / 1000.0, built) * 1000.0)


func _exit_tree() -> void:
	RenderingServer.render_loop_enabled = true
