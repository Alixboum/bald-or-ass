class_name FragmentView
extends Control
## Draws an image with everything hidden except one normalized zone.
## reveal() animates the mask away and frames the image in green or red.

const CORRECT_COLOR := Color("34d27a")
const WRONG_COLOR := Color("ff4b55")
const BORDER_WIDTH := 10.0

enum Result { NONE, CORRECT, WRONG }

var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
var zone := GuessTheme.DEFAULT_ZONE:
	set(value):
		zone = value
		queue_redraw()
## 0 = only the fragment is visible, 1 = full image visible.
var reveal_amount := 0.0:
	set(value):
		reveal_amount = clampf(value, 0.0, 1.0)
		queue_redraw()
var result := Result.NONE:
	set(value):
		result = value
		queue_redraw()
var mask_color := Color("150c11")
var hatch_color := Color(1.0, 0.95, 0.9, 0.035)

var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func show_fragment(new_texture: Texture2D, new_zone: Rect2) -> void:
	if _tween != null:
		_tween.kill()
	texture = new_texture
	zone = new_zone
	result = Result.NONE
	reveal_amount = 0.0


func reveal(correct: bool, duration: float = 0.55) -> void:
	result = Result.CORRECT if correct else Result.WRONG
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "reveal_amount", 1.0, duration)


func is_revealed() -> bool:
	return result != Result.NONE


## Image rectangle fitted inside the control, aspect preserved, room for the border.
func image_rect() -> Rect2:
	if texture == null:
		return Rect2()
	var available := size - Vector2.ONE * (BORDER_WIDTH * 2.0 + 4.0)
	var tex_size := texture.get_size()
	var scale := minf(available.x / tex_size.x, available.y / tex_size.y)
	var draw_size := tex_size * scale
	return Rect2((size - draw_size) * 0.5, draw_size)


func zone_rect() -> Rect2:
	var rect := image_rect()
	return Rect2(rect.position + zone.position * rect.size, zone.size * rect.size)


func _draw() -> void:
	if texture == null:
		return
	var rect := image_rect()
	var window := zone_rect()
	if result != Result.NONE:
		var color := CORRECT_COLOR if result == Result.CORRECT else WRONG_COLOR
		var frame := rect.grow(BORDER_WIDTH * 0.5 + 1.0)
		draw_rect(frame.grow(BORDER_WIDTH * 0.5 + 6.0), Color(color, 0.18 * reveal_amount), true)
		draw_rect(frame, Color(color, minf(1.0, reveal_amount * 2.0)), false, BORDER_WIDTH)
	draw_texture_rect(texture, rect, false)
	var alpha := 1.0 - reveal_amount
	if alpha <= 0.0:
		return
	# Opaque mask around the visible window: top, bottom, left, right.
	var mask := Color(mask_color, alpha)
	var pieces := [
		Rect2(rect.position, Vector2(rect.size.x, window.position.y - rect.position.y)),
		Rect2(Vector2(rect.position.x, window.end.y), Vector2(rect.size.x, rect.end.y - window.end.y)),
		Rect2(Vector2(rect.position.x, window.position.y), Vector2(window.position.x - rect.position.x, window.size.y)),
		Rect2(Vector2(window.end.x, window.position.y), Vector2(rect.end.x - window.end.x, window.size.y)),
	]
	for piece: Rect2 in pieces:
		if piece.size.x > 0.0 and piece.size.y > 0.0:
			draw_rect(piece, mask, true)
	_draw_hatching(rect, window, alpha)
	draw_rect(window.grow(2.0), Color(1.0, 0.94, 0.86, 0.85 * alpha), false, 2.0)


## Subtle diagonal lines on the mask so the hidden area reads as "covered".
func _draw_hatching(rect: Rect2, window: Rect2, alpha: float) -> void:
	var step := 22.0
	var color := Color(hatch_color, hatch_color.a * alpha)
	var x := rect.position.x - rect.size.y
	while x < rect.end.x:
		var from := Vector2(x, rect.end.y)
		var to := Vector2(x + rect.size.y, rect.position.y)
		_draw_clipped_line(from, to, rect, window, color)
		x += step


func _draw_clipped_line(from: Vector2, to: Vector2, rect: Rect2, window: Rect2, color: Color) -> void:
	var samples := 24
	var previous := from
	for i: int in range(1, samples + 1):
		var point := from.lerp(to, float(i) / samples)
		var middle := (previous + point) * 0.5
		if rect.has_point(middle) and not window.grow(4.0).has_point(middle):
			draw_line(previous, point, color, 1.0)
		previous = point
