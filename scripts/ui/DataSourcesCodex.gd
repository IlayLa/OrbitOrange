class_name DataSourcesCodex
extends Control
## The Data Sources codex: every part's full source citation, grouped by
## category, and the sources of the celestial bodies. The part popup shows
## only a one-line tag; the codex keeps the whole citation one click away
## (Option 3, "Data Sources codex"). Opened from the Main Menu and by
## right-clicking a part card. Esc or the close button hides it.

const TITLE_FONT_SIZE_PIXELS := 12
const NAME_FONT_SIZE_PIXELS := 10
const TEXT_FONT_SIZE_PIXELS := 8
const COLOR_DIM_BACKGROUND := Color(0, 0, 0, 0.6)
const COLOR_PANEL := Color("10182b")
const COLOR_BORDER := Color("bed3fa")
const CATEGORY_TITLES := {
	"engine": "ENGINES",
	"tank": "TANKS",
	"telemetry": "TELEMETRY",
	"science": "SCIENCE",
}

## Part id -> the Label holding the part's name, to scroll to it.
var _name_labels_by_part_id: Dictionary = {}
var _scroll: ScrollContainer
var _panel_rect: Rect2


## Builds the codex inside panel_rect (in this control's coordinates). The
## control itself covers the whole screen so that clicks behind it are caught.
func _init(panel_rect: Rect2 = Rect2(40, 20, 560, 360)) -> void:
	_panel_rect = panel_rect
	size = ScreenLayout.SCREEN_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	var dim := ColorRect.new()
	dim.color = COLOR_DIM_BACKGROUND
	dim.size = ScreenLayout.SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := Panel.new()
	panel.position = _panel_rect.position
	panel.size = _panel_rect.size
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL
	panel_style.border_color = COLOR_BORDER
	panel_style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var title := Label.new()
	title.text = "DATA SOURCES"
	title.position = Vector2(8, 4)
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE_PIXELS)
	title.add_theme_color_override("font_color", ScreenLayout.COLOR_ACCENT_ORANGE)
	panel.add_child(title)

	var note := Label.new()
	note.text = "≈ approximate   game values are not real prices"
	note.position = Vector2(130, 7)
	note.add_theme_font_size_override("font_size", TEXT_FONT_SIZE_PIXELS)
	note.add_theme_color_override("font_color", PixelGlyphs.COLOR_MUTED_TEXT)
	panel.add_child(note)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.tooltip_text = "Close (Esc)"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", TEXT_FONT_SIZE_PIXELS)
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = ScreenLayout.COLOR_PANEL_DARK_BLUE
	close_style.border_color = COLOR_BORDER
	close_style.set_border_width_all(1)
	close_style.set_content_margin_all(2)
	for style_name in ["normal", "hover", "pressed", "focus"]:
		close_button.add_theme_stylebox_override(style_name, close_style)
	close_button.position = Vector2(_panel_rect.size.x - 46, 4)
	close_button.size = Vector2(40, 14)
	close_button.pressed.connect(hide)
	panel.add_child(close_button)
	# A Button measures its text with the small font only once the theme is
	# applied, at the end of the frame, so the size is set again then.
	close_button.set_deferred("size", Vector2(40, 14))

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(6, 24)
	_scroll.size = _panel_rect.size - Vector2(12, 30)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)

	var entries := VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 2)
	_scroll.add_child(entries)
	var text_width_pixels: float = _scroll.size.x - 14.0

	for category: String in CATEGORY_TITLES:
		_add_heading(entries, CATEGORY_TITLES[category])
		for part in GameData.parts_in_category(category):
			var is_approximate: bool = part.get("is_approximate", false)
			var name_label := _add_text(entries, "%s%s" % [part.get("name", part.get("id", "")), "  ≈" if is_approximate else ""],
					NAME_FONT_SIZE_PIXELS, ScreenLayout.COLOR_TEXT_LIGHT, text_width_pixels)
			_name_labels_by_part_id[part.get("id", "")] = name_label
			_add_text(entries, part.get("source", "No source recorded."), TEXT_FONT_SIZE_PIXELS,
					PixelGlyphs.COLOR_MUTED_TEXT, text_width_pixels)
	_add_heading(entries, "CELESTIAL BODIES")
	var listed_body_ids: Dictionary = {}
	for mission in GameData.all_missions():
		var body_id: String = mission.get("body_id", "")
		if body_id.is_empty() or listed_body_ids.has(body_id):
			continue
		listed_body_ids[body_id] = true
		var body: Dictionary = GameData.body(body_id)
		_add_text(entries, body.get("name", body_id), NAME_FONT_SIZE_PIXELS, ScreenLayout.COLOR_TEXT_LIGHT, text_width_pixels)
		_add_text(entries, body.get("source", "No source recorded."), TEXT_FONT_SIZE_PIXELS,
				PixelGlyphs.COLOR_MUTED_TEXT, text_width_pixels)


## Shows the codex. With a part id, scrolls so that the part is at the top.
func open_at(part_id: String = "") -> void:
	show()
	if _scroll == null:
		return
	_scroll.scroll_vertical = 0
	if _name_labels_by_part_id.has(part_id):
		var name_label: Label = _name_labels_by_part_id[part_id]
		# Containers sort at the end of the frame; scroll once they have.
		_scroll_to_label.call_deferred(name_label)


## True when this part has an entry.
func has_entry(part_id: String) -> bool:
	return _name_labels_by_part_id.has(part_id)


func _scroll_to_label(name_label: Label) -> void:
	_scroll.scroll_vertical = int(name_label.position.y)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()


func _gui_input(event: InputEvent) -> void:
	# A click on the dimmed screen around the panel closes the codex.
	if event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event
		if button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT and not _panel_rect.has_point(button_event.position):
			accept_event()
			hide()


func _add_heading(parent: Control, heading_text: String) -> void:
	var heading := _add_text(parent, heading_text, NAME_FONT_SIZE_PIXELS, ScreenLayout.COLOR_ACCENT_ORANGE, -1.0)
	heading.custom_minimum_size.y = 16
	heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM


func _add_text(parent: Control, text: String, font_size_pixels: int, text_color: Color, width_pixels: float) -> Label:
	var label := Label.new()
	label.text = text
	if width_pixels > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = width_pixels
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size_pixels)
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_constant_override("line_spacing", -1)
	parent.add_child(label)
	return label
