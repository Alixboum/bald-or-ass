class_name ZoneCanvas
extends Control
## Editor canvas: shows the full image and lets the user click-drag a
## rectangle that becomes the visible fragment. Emits normalized zones.

signal zone_drawn(zone: Rect2)

const OUTLINE := Color("ff8a5c")
const HANDLE := Color("fff1e0")

var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
var zone := GuessTheme.DEFAULT_ZONE:
	set(value):
		zone = value
		queue_redraw()
## Preview the mask exactly as the player will see it.
var preview_mask := false:
	set(value):
		preview_mask = value
		queue_redraw()

var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_current := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	resized.connect(queue_redraw)


func image_rect() -> Rect2:
	if texture == null:
		return Rect2()
	var available := size - Vector2(8.0, 8.0)
	var tex_size := texture.get_size()
	var scale := minf(available.x / tex_size.x, available.y / tex_size.y)
	var draw_size := tex_size * scale
	return Rect2((size - draw_size) * 0.5, draw_size)


func to_normalized(point: Vector2) -> Vector2:
	var rect := image_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Vector2.ZERO
	return ((point - rect.position) / rect.size).clamp(Vector2.ZERO, Vector2.ONE)


func _gui_input(event: InputEvent) -> void:
	if texture == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start = to_normalized(event.position)
			_drag_current = _drag_start
		elif _dragging:
			_dragging = false
			_drag_current = to_normalized(event.position)
			var drawn := Rect2(_drag_start, _drag_current - _drag_start).abs()
			if drawn.size.x >= GuessTheme.MIN_ZONE_SIZE and drawn.size.y >= GuessTheme.MIN_ZONE_SIZE:
				zone = GuessTheme.normalize_zone(drawn)
				zone_drawn.emit(zone)
		accept_event()
		queue_redraw()
	elif event is InputEventMouseMotion and _dragging:
		_drag_current = to_normalized(event.position)
		accept_event()
		queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	var rect := image_rect()
	draw_texture_rect(texture, rect, false)
	var shown := zone
	if _dragging:
		shown = Rect2(_drag_start, _drag_current - _drag_start).abs()
	var window := Rect2(rect.position + shown.position * rect.size, shown.size * rect.size)
	var dim := Color(0.08, 0.05, 0.07, 0.97 if preview_mask else 0.62)
	for piece: Rect2 in [
		Rect2(rect.position, Vector2(rect.size.x, window.position.y - rect.position.y)),
		Rect2(Vector2(rect.position.x, window.end.y), Vector2(rect.size.x, rect.end.y - window.end.y)),
		Rect2(Vector2(rect.position.x, window.position.y), Vector2(window.position.x - rect.position.x, window.size.y)),
		Rect2(Vector2(window.end.x, window.position.y), Vector2(rect.end.x - window.end.x, window.size.y)),
	]:
		if piece.size.x > 0.0 and piece.size.y > 0.0:
			draw_rect(piece, dim, true)
	draw_rect(window, OUTLINE, false, 3.0)
	for corner: Vector2 in [window.position, Vector2(window.end.x, window.position.y), window.end, Vector2(window.position.x, window.end.y)]:
		draw_rect(Rect2(corner - Vector2(5, 5), Vector2(10, 10)), HANDLE, true)
	var label := "%d × %d %%" % [roundi(shown.size.x * 100.0), roundi(shown.size.y * 100.0)]
	var font := get_theme_default_font()
	draw_string(font, window.position + Vector2(0.0, -8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, HANDLE)
