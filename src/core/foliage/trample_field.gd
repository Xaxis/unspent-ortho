class_name TrampleField
extends RefCounted
## Where bodies have pushed through the grass, round the focus: the parting a
## player leaves and the flattened path that lingers after it (grass.gdshader).
##
## A SIZE x SIZE grid of TEXEL tiles, toroidal: world texel (tx, ty) lives at
## (tx mod SIZE, ty mod SIZE), so following the focus moves no data. Only the
## texels that leave the window when the focus moves are cleared. The shader
## samples it with repeat at world xz / SPAN and trusts it only inside the
## window (`window()`), so the wrap never shows.
##
## Per texel: `push`, which way the blades there lean away from what stood on
## them and how far (length 0..1), recovering over about four seconds; and
## `flat`, how far they are pressed down, 0..1, lingering about twenty.
## Deterministic and pure: nothing here reads a clock.

const SIZE := 64
const TEXEL := 0.25
const SPAN := SIZE * TEXEL
## Seconds for the lean to fall to 1/e (gone to the eye in about 3x this).
const RECOVER := 1.3
## Seconds for the flattening to fall to 1/e.
const LINGER := 7.0

var push := PackedVector2Array()
var flat := PackedFloat32Array()
## World texel of the window's low corner.
var origin := Vector2i.ZERO
## Nothing is pressed anywhere: decay and upload have nothing to do.
var quiet := true
## The slots pressed now, each once: decay visits these and nothing else, so a
## body standing in open grass costs a few dozen texels a frame, not 4096.
var _live := PackedInt32Array()
var _is_live := PackedByteArray()
## The upload, kept current texel by texel (`bytes`).
var _bytes := PackedByteArray()


func _init() -> void:
	push.resize(SIZE * SIZE)
	flat.resize(SIZE * SIZE)
	_is_live.resize(SIZE * SIZE)
	_bytes.resize(SIZE * SIZE * 4)
	for i in SIZE * SIZE:
		_encode(i)


static func _slot(tx: int, ty: int) -> int:
	return posmod(tx, SIZE) + posmod(ty, SIZE) * SIZE


func _encode(i: int) -> void:
	var p := push[i]
	_bytes[i * 4] = clampi(128 + roundi(p.x * 127.0), 1, 255)
	_bytes[i * 4 + 1] = clampi(128 + roundi(p.y * 127.0), 1, 255)
	_bytes[i * 4 + 2] = clampi(roundi(flat[i] * 255.0), 0, 255)


func _clear(i: int) -> void:
	push[i] = Vector2.ZERO
	flat[i] = 0.0
	_encode(i)


## Centre the window on `centre` (world xz, tiles). Texels that fall out of it
## are cleared, so what comes back in on the far side starts upright.
func focus(centre: Vector2) -> void:
	var o := Vector2i(floori(centre.x / TEXEL) - SIZE / 2, floori(centre.y / TEXEL) - SIZE / 2)
	if o == origin:
		return
	# Only a live slot can hold anything to clear.
	for i in _live:
		var sx := i % SIZE
		var sy := i / SIZE
		# The world texel this slot stands for in the OLD window.
		var tx := origin.x + posmod(sx - origin.x, SIZE)
		var ty := origin.y + posmod(sy - origin.y, SIZE)
		if tx < o.x or tx >= o.x + SIZE or ty < o.y or ty >= o.y + SIZE:
			_clear(i)
	origin = o


## A body at `pos` pushing the grass within `radius` tiles away from it by
## `amount` 0..1, strongest at its rim, and pressing the middle down by
## `flatten` 0..1. A stamp never weakens what a stronger one left.
func stamp(pos: Vector2, radius: float, amount: float, flatten: float = 0.0) -> void:
	var lo := Vector2i(floori((pos.x - radius) / TEXEL), floori((pos.y - radius) / TEXEL))
	var hi := Vector2i(floori((pos.x + radius) / TEXEL), floori((pos.y + radius) / TEXEL))
	lo = lo.max(origin)
	hi = hi.min(origin + Vector2i(SIZE - 1, SIZE - 1))
	for ty in range(lo.y, hi.y + 1):
		for tx in range(lo.x, hi.x + 1):
			var c := Vector2((float(tx) + 0.5) * TEXEL, (float(ty) + 0.5) * TEXEL)
			var d := c - pos
			var r := d.length()
			if r >= radius:
				continue
			var s := amount * (1.0 - smoothstep(radius * 0.55, radius, r))
			var i := _slot(tx, ty)
			var p := d / maxf(r, 1e-4) * s
			if p.length_squared() > push[i].length_squared():
				push[i] = p
			var f := flatten * (1.0 - smoothstep(radius * 0.25, radius * 0.6, r))
			if f > flat[i]:
				flat[i] = f
			_encode(i)
			if _is_live[i] == 0:
				_is_live[i] = 1
				_live.append(i)
			quiet = false


## Let the grass stand back up over `dt` seconds.
func decay(dt: float) -> void:
	if quiet:
		return
	var kp := exp(-dt / RECOVER)
	var kf := exp(-dt / LINGER)
	# Compacted in place: a slot that stood back up leaves the list.
	var kept := 0
	for k in _live.size():
		var i := _live[k]
		var p := push[i] * kp
		var f := flat[i] * kf
		if p.length_squared() < 1e-5:
			p = Vector2.ZERO
		if f < 3e-3:
			f = 0.0
		push[i] = p
		flat[i] = f
		_bytes[i * 4] = clampi(128 + roundi(p.x * 127.0), 1, 255)
		_bytes[i * 4 + 1] = clampi(128 + roundi(p.y * 127.0), 1, 255)
		_bytes[i * 4 + 2] = roundi(f * 255.0)
		if f > 0.0 or p != Vector2.ZERO:
			_live[kept] = i
			kept += 1
		else:
			_is_live[i] = 0
	_live.resize(kept)
	quiet = kept == 0


## (push x, push y, flat) at world `xz`; zero outside the window.
func at(xz: Vector2) -> Vector3:
	var tx := floori(xz.x / TEXEL)
	var ty := floori(xz.y / TEXEL)
	if tx < origin.x or ty < origin.y or tx >= origin.x + SIZE or ty >= origin.y + SIZE:
		return Vector3.ZERO
	var i := _slot(tx, ty)
	return Vector3(push[i].x, push[i].y, flat[i])


## The window for the shader (foliage_trample_at): its low corner in world xz,
## 1 / SPAN, and SPAN.
func window() -> Vector4:
	return Vector4(origin.x * TEXEL, origin.y * TEXEL, 1.0 / SPAN, SPAN)


## RGBA8 texels in slot order: r, g the lean as 128 + 127 x lean (128 is
## upright), b the flattening. The field's own buffer: do not write to it.
func bytes() -> PackedByteArray:
	return _bytes
