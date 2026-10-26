class_name GuessUi
extends RefCounted
## Visual language: plum night background, cream type, coral signature colour.

const BG := Color("1f1219")
const PANEL := Color("2b1a23")
const PANEL_EDGE := Color("4a2f3b")
const CREAM := Color("fff1e0")
const MUTED := Color("c9b3ad")
const CORAL := Color("ff7a4d")
const CORRECT := Color("34d27a")
const WRONG := Color("ff4b55")

const FONT_TITLE := "res://assets/template/fonts/display/generic_title.tres"
const FONT_HEADING := "res://assets/template/fonts/display/generic_heading.tres"
const FONT_MEDIUM := "res://assets/template/fonts/ui_medium.tres"
const FONT_BOLD := "res://assets/template/fonts/ui_bold.tres"


static func box(color: Color, edge: Color = Color.TRANSPARENT, radius: int = 18, border: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	style.anti_aliasing = true
	return style


static func label(text: String, size: int = 18, color: Color = CREAM, font_path: String = "") -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	if not font_path.is_empty():
		result.add_theme_font_override("font", load(font_path))
	return result


static func paragraph(text: String, size: int = 17, color: Color = MUTED) -> Label:
	var result := label(text, size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.x = 120.0
	return result


## Large coloured answer / primary button.
static func big_button(text: String, fill: Color, text_color: Color = BG, minimum: Vector2 = Vector2(260, 72)) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = minimum
	result.focus_mode = Control.FOCUS_ALL
	result.add_theme_font_override("font", load(FONT_TITLE))
	result.add_theme_font_size_override("font_size", 30)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.add_theme_color_override(state, text_color)
	result.add_theme_color_override("font_disabled_color", Color(text_color, 0.55))
	result.add_theme_stylebox_override("normal", box(fill, fill.darkened(0.25), 20, 0))
	var hover := box(fill.lightened(0.12), CREAM, 20, 3)
	result.add_theme_stylebox_override("hover", hover)
	result.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, CREAM, 22, 3))
	result.add_theme_stylebox_override("pressed", box(fill.darkened(0.15), CREAM, 20, 3))
	result.add_theme_stylebox_override("disabled", box(Color(fill, 0.35), Color.TRANSPARENT, 20, 0))
	result.pivot_offset = minimum * 0.5
	result.mouse_entered.connect(func() -> void:
		if not result.disabled:
			result.create_tween().tween_property(result, "scale", Vector2(1.03, 1.03), 0.08)
	)
	result.mouse_exited.connect(func() -> void:
		result.create_tween().tween_property(result, "scale", Vector2.ONE, 0.08)
	)
	result.resized.connect(func() -> void: result.pivot_offset = result.size * 0.5)
	return result


## Quiet secondary button.
static func ghost_button(text: String, minimum_width: float = 0.0) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(minimum_width, 46)
	result.focus_mode = Control.FOCUS_ALL
	result.add_theme_font_override("font", load(FONT_MEDIUM))
	result.add_theme_font_size_override("font_size", 16)
	for state: String in ["font_color", "font_focus_color"]:
		result.add_theme_color_override(state, CREAM)
	result.add_theme_color_override("font_hover_color", Color.WHITE)
	result.add_theme_color_override("font_pressed_color", CORAL)
	result.add_theme_color_override("font_disabled_color", Color(MUTED, 0.45))
	var normal := box(Color(PANEL, 0.9), PANEL_EDGE, 14, 1)
	normal.content_margin_top = 10.0
	normal.content_margin_bottom = 10.0
	result.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = CORAL
	result.add_theme_stylebox_override("hover", hover)
	result.add_theme_stylebox_override("pressed", hover)
	var focus := box(Color.TRANSPARENT, CREAM, 16, 2)
	result.add_theme_stylebox_override("focus", focus)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(PANEL, 0.4)
	result.add_theme_stylebox_override("disabled", disabled)
	return result


static func panel(padding: float = 28.0) -> PanelContainer:
	var result := PanelContainer.new()
	var style := box(PANEL, PANEL_EDGE, 26, 1)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 24
	style.shadow_offset = Vector2(0, 10)
	result.add_theme_stylebox_override("panel", style)
	return result


static func vbox(separation: int = 14) -> VBoxContainer:
	var result := VBoxContainer.new()
	result.add_theme_constant_override("separation", separation)
	return result


static func hbox(separation: int = 14) -> HBoxContainer:
	var result := HBoxContainer.new()
	result.add_theme_constant_override("separation", separation)
	return result


static func margin(node: Control, amount: int) -> MarginContainer:
	var result := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		result.add_theme_constant_override(side, amount)
	result.add_child(node)
	return result
