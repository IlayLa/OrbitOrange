class_name MissionPresentation
extends RefCounted
## Shared presentation helpers used only by mission screens and their demo.

## Returns a theme with pixel-sized controls and the shared screen colours.
static func create_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	result.set_color("font_color", "Label", ScreenLayout.COLOR_TEXT_LIGHT)
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = ScreenLayout.COLOR_PANEL_DARK_BLUE if style_name != "pressed" else ScreenLayout.COLOR_MONITOR_BLUE
		style.border_color = ScreenLayout.COLOR_ACCENT_ORANGE if style_name == "focus" else ScreenLayout.COLOR_MONITOR_FRAME
		style.set_border_width_all(2 if style_name == "focus" else 1)
		style.content_margin_left = 7
		style.content_margin_right = 7
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		if style_name == "disabled":
			style.bg_color = ScreenLayout.COLOR_SPACE_BLACK
		result.set_stylebox(style_name, "Button", style)
	result.set_color("font_disabled_color", "Button", ScreenLayout.COLOR_LIST_GREY)
	return result

## Creates a non-interactive background filling the 640 by 400 pixel canvas.
static func add_background(parent: Control) -> void:
	var background := ColorRect.new()
	background.color = ScreenLayout.COLOR_BEZEL_DARK
	background.size = ScreenLayout.SCREEN_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(background)

## Returns a wrapping label and adds it to the supplied container.
static func add_label(parent: Node, text: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

## Returns the vertical contents of a scrollable monitor at the pixel rectangle.
static func add_monitor(parent: Control, rectangle: Rect2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = rectangle.position
	panel.size = rectangle.size
	var style := StyleBoxFlat.new()
	style.bg_color = ScreenLayout.COLOR_SPACE_BLACK
	style.border_color = ScreenLayout.COLOR_MONITOR_FRAME
	style.set_border_width_all(3)
	style.set_content_margin_all(9)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 9)
	scroll.add_child(contents)
	return contents

## Removes a container's children immediately from layout, freeing them later.
static func clear_contents(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

## Returns an altitude-band description in kilometres.
static func zone_text(zone: Dictionary) -> String:
	return "%.0f-%.0f km altitude" % [float(zone.get("inner_altitude_kilometers", 0.0)), float(zone.get("outer_altitude_kilometers", 0.0))]
