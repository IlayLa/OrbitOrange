class_name PlanningStyle
extends RefCounted
## Shared readable console styling; no gameplay state.

## Number fields: box, outline, and the outline while typing.
const COLOR_FIELD_FILL := Color("#0c1925")
const COLOR_FIELD_BORDER := Color("#36536b")
const COLOR_FIELD_FOCUS := Color("#83dfed")
const GRABBER_SIZE_PIXELS := Vector2i(6, 12)


## A flat panel with pixel padding and a restrained outline.
static func panel_style(fill: Color = Color("#3e5e79"), border: Color = Color("#83817c")) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(0)
	box.content_margin_left = 3.0
	box.content_margin_right = 3.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	return box


## A compact theme suitable for the 640 by 400 planning console.
## Buttons take their skin from the project theme (assets/ui/ui_theme.tres).
static func create_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 11
	for control_type in ["Button", "Label", "LineEdit", "SpinBox"]:
		result.set_font_size("font_size", control_type, 11)
	result.set_color("font_color", "Label", Color("#e0eaf2"))
	result.set_font_size("font_size", "TooltipLabel", 10)
	result.set_stylebox("normal", "LineEdit", panel_style(COLOR_FIELD_FILL, COLOR_FIELD_BORDER))
	result.set_stylebox("focus", "LineEdit", panel_style(Color(0, 0, 0, 0), COLOR_FIELD_FOCUS))
	result.set_stylebox("panel", "PanelContainer", panel_style())
	result.set_stylebox("panel", "TooltipPanel", panel_style())
	_add_slider_style(result)
	return result


## Gives a SpinBox the shared number-field look and behaviour: dark box, cyan
## outline while typing, typed text replacing the old value, and whole-unit
## arrow steps over a finer typed step. Works inside any theme.
static func style_number_field(field: SpinBox, font_size_pixels: int, arrow_step: float = 1.0) -> void:
	field.select_all_on_focus = true
	field.custom_arrow_step = arrow_step
	field.add_theme_font_size_override("font_size", font_size_pixels)
	var line_edit: LineEdit = field.get_line_edit()
	line_edit.add_theme_font_size_override("font_size", font_size_pixels)
	line_edit.add_theme_stylebox_override("normal", panel_style(COLOR_FIELD_FILL, COLOR_FIELD_BORDER))
	line_edit.add_theme_stylebox_override("focus", panel_style(Color(0, 0, 0, 0), COLOR_FIELD_FOCUS))
	line_edit.add_theme_stylebox_override("read_only", panel_style(COLOR_FIELD_FILL, COLOR_FIELD_BORDER.darkened(0.4)))


## A slider in the number fields' colours: the dark field box as the track,
## the focus cyan for the filled part, and a square pixel grabber.
static func _add_slider_style(theme: Theme) -> void:
	var track := panel_style(COLOR_FIELD_FILL, COLOR_FIELD_BORDER)
	track.content_margin_top = 2.0
	track.content_margin_bottom = 2.0
	theme.set_stylebox("slider", "HSlider", track)
	var filled := panel_style(COLOR_FIELD_BORDER, COLOR_FIELD_BORDER)
	filled.content_margin_top = 2.0
	filled.content_margin_bottom = 2.0
	theme.set_stylebox("grabber_area", "HSlider", filled)
	var filled_highlight := panel_style(COLOR_FIELD_FOCUS.darkened(0.35), COLOR_FIELD_FOCUS.darkened(0.35))
	filled_highlight.content_margin_top = 2.0
	filled_highlight.content_margin_bottom = 2.0
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled_highlight)
	theme.set_icon("grabber", "HSlider", _grabber_texture(Color("#e0eaf2")))
	theme.set_icon("grabber_highlight", "HSlider", _grabber_texture(COLOR_FIELD_FOCUS))
	theme.set_icon("grabber_disabled", "HSlider", _grabber_texture(Color("#61788b")))


## A 6 by 12 pixel block with a dark outline.
static func _grabber_texture(fill: Color) -> ImageTexture:
	var image := Image.create(GRABBER_SIZE_PIXELS.x, GRABBER_SIZE_PIXELS.y, false, Image.FORMAT_RGBA8)
	image.fill(COLOR_FIELD_FILL)
	image.fill_rect(Rect2i(Vector2i.ONE, GRABBER_SIZE_PIXELS - Vector2i(2, 2)), fill)
	return ImageTexture.create_from_image(image)
