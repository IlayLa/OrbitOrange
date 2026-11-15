class_name PlanningStyle
extends RefCounted
## Shared readable console styling; no gameplay state.


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
static func create_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 11
	for control_type in ["Button", "Label", "LineEdit", "SpinBox"]:
		result.set_font_size("font_size", control_type, 11)
	result.set_color("font_color", "Label", Color("#e0eaf2"))
	result.set_color("font_color", "Button", Color("#e0eaf2"))
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", Color("#61788b"))
	result.set_font_size("font_size", "TooltipLabel", 10)
	result.set_stylebox("normal", "Button", panel_style(Color("#3e5e79"), Color("#83817c")))
	result.set_stylebox("hover", "Button", panel_style(Color("#4171c4"), Color("#bed3fa")))
	result.set_stylebox("pressed", "Button", panel_style(Color("#345e9c"), Color("#bed3fa")))
	result.set_stylebox("disabled", "Button", panel_style(Color("#686c70"), Color("#83817c")))
	result.set_stylebox("normal", "LineEdit", panel_style(Color("#0c1925"), Color("#36536b")))
	result.set_stylebox("focus", "LineEdit", panel_style(Color(0, 0, 0, 0), Color("#83dfed")))
	result.set_stylebox("panel", "PanelContainer", panel_style())
	result.set_stylebox("panel", "TooltipPanel", panel_style())
	return result
