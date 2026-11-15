class_name InstrumentPanel
extends Control
## Base of the small instrument panels: a title and one or more value lines,
## placed inside the grey frame of a mock-up panel. A subclass sets the title
## and rows in _init and fills the values in show_frame.

const TITLE_FONT_SIZE := 9
const VALUE_FONT_SIZE := 13

var title_text: String = ""
## Caption shown in front of each value line; one entry per line.
var row_captions: Array[String] = [""]
var text_color: Color = ScreenLayout.COLOR_TEXT_LIGHT

var _title_label: Label
var _value_labels: Array[Label] = []


## Places the panel inside the frame of the mock-up rectangle.
func place_on(mockup_panel_rect: Rect2) -> void:
	var inner_rect := ExecutionLayout.inside_frame(mockup_panel_rect)
	position = inner_rect.position
	size = inner_rect.size


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := VBoxContainer.new()
	lines.size = size
	lines.add_theme_constant_override("separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lines)

	_title_label = _create_label(title_text, TITLE_FONT_SIZE)
	_title_label.modulate.a = 0.75
	lines.add_child(_title_label)
	for caption in row_captions:
		var value_label := _create_label(_compose(caption, ReadingFormat.NO_DATA_TEXT), VALUE_FONT_SIZE)
		lines.add_child(value_label)
		_value_labels.append(value_label)


## Redraws the panel from a telemetry frame. Subclasses override it.
func show_frame(_frame: TelemetryFrame) -> void:
	pass


## Returns the text currently shown on the value line with the given index.
func value_text(row_index: int = 0) -> String:
	return _value_labels[row_index].text


## Sets the value shown on one line, keeping its caption in front.
func set_value_text(row_index: int, text: String) -> void:
	_value_labels[row_index].text = _compose(row_captions[row_index], text)


func _compose(caption: String, text: String) -> String:
	return text if caption == "" else "%s %s" % [caption, text]


func _create_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", text_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	return label
