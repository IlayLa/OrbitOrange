class_name ClockPanel
extends Control
## The mission clock (time since launch and time to the next pulse) and the
## time controls: pause, 1x, 10x, 100x, 1000x. The button matching the frame's
## time scale is highlighted. Pressing a button only emits
## time_scale_requested; ExecutionConsole passes it to FlightSimulation.

signal time_scale_requested(time_scale: float)

const MISSION_TIME_FONT_SIZE := 15
const DETAIL_FONT_SIZE := 10
const BUTTON_FONT_SIZE := 10
const BUTTON_GAP_PIXELS := 3.0

## Time scales offered, in button order (FlightSimulation.ALLOWED_TIME_SCALES).
var time_scales: Array[float] = []

var _mission_time_label: Label
var _next_pulse_label: Label
var _time_scale_buttons: Array[Button] = []
var _highlight_style: StyleBoxFlat


func _ready() -> void:
	var inner_rect := ExecutionLayout.inside_frame(ExecutionLayout.CLOCK_SCREEN)
	_mission_time_label = _create_label("T+ " + ReadingFormat.NO_DATA_TEXT, MISSION_TIME_FONT_SIZE,
			inner_rect.position + Vector2(3, -2))
	_next_pulse_label = _create_label("Waiting for launch", DETAIL_FONT_SIZE,
			inner_rect.position + Vector2(3, 19))
	_create_time_scale_buttons()


## Shows the frame's clock values and highlights its time scale.
func show_frame(frame: TelemetryFrame) -> void:
	_mission_time_label.text = "T+ " + ReadingFormat.duration_text(frame.simulation_time_seconds)
	_next_pulse_label.text = "Next pulse in " + ReadingFormat.duration_text(frame.seconds_until_next_pulse)
	highlight_time_scale(frame.time_scale)


## Highlights the button of the given time scale and clears the others.
func highlight_time_scale(time_scale: float) -> void:
	for button_index in _time_scale_buttons.size():
		var button := _time_scale_buttons[button_index]
		if time_scales[button_index] == time_scale:
			button.add_theme_stylebox_override("normal", _highlight_style)
			button.add_theme_stylebox_override("hover", _highlight_style)
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")


## Returns the time scale whose button is highlighted, or -1 when none is.
func highlighted_time_scale() -> float:
	for button_index in _time_scale_buttons.size():
		if _time_scale_buttons[button_index].has_theme_stylebox_override("normal"):
			return time_scales[button_index]
	return -1.0


## Returns the time-control buttons, in the order of time_scales.
func time_scale_buttons() -> Array[Button]:
	return _time_scale_buttons


## Returns the two clock lines as shown.
func clock_text() -> String:
	return _mission_time_label.text + "\n" + _next_pulse_label.text


func _create_time_scale_buttons() -> void:
	_highlight_style = StyleBoxFlat.new()
	_highlight_style.bg_color = ScreenLayout.COLOR_ACCENT_ORANGE
	_highlight_style.border_color = ScreenLayout.COLOR_TEXT_LIGHT
	_highlight_style.set_border_width_all(1)

	var controls_rect := ExecutionLayout.TIME_CONTROLS_RECT
	var button_count := time_scales.size()
	if button_count == 0:
		return
	var button_width_pixels := (controls_rect.size.x - BUTTON_GAP_PIXELS * (button_count - 1)) / button_count
	for scale_index in button_count:
		var time_scale := time_scales[scale_index]
		var button := Button.new()
		button.text = ReadingFormat.time_scale_label(time_scale)
		button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		button.focus_mode = Control.FOCUS_NONE
		button.position = controls_rect.position + Vector2(
				scale_index * (button_width_pixels + BUTTON_GAP_PIXELS), 0)
		button.size = Vector2(button_width_pixels, controls_rect.size.y)
		button.pressed.connect(func() -> void: time_scale_requested.emit(time_scale))
		add_child(button)
		_time_scale_buttons.append(button)


func _create_label(text: String, font_size: int, label_position: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = label_position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ScreenLayout.COLOR_TEXT_LIGHT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
