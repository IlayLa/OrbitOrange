class_name SelfDestructButton
extends Control
## The tempting self-destruct button from the team notes. The first press arms
## it, the second shows a joke. It never ends or changes the flight.

const ARM_TIMEOUT_SECONDS := 3.0
const MESSAGE_DURATION_SECONDS := 5.0
const BUTTON_FONT_SIZE := 9
const MESSAGE_FONT_SIZE := 10
const IDLE_TEXT := "SELF\nDESTRUCT"
const ARMED_TEXT := "SURE?"
const JOKES: Array[String] = [
	"Self-destruct cancelled: Finance listed the explosives as non-essential payload and sold them.",
	"Countdown 3... 2... 1... The button is decorative. Legal insisted.",
	"Request filed with Range Safety. Expected reply: after the mission.",
	"Self-destruct needs two keys. Amit has the other one and is on lunch break.",
]

var _button: Button
var _message_box: PanelContainer
var _message_label: Label
var _is_armed: bool = false
var _armed_elapsed_seconds: float = 0.0
var _message_elapsed_seconds: float = 0.0
var _next_joke_index: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button = Button.new()
	_button.text = IDLE_TEXT
	_button.focus_mode = Control.FOCUS_NONE
	_button.position = ExecutionLayout.SELF_DESTRUCT_BUTTON_RECT.position
	_button.size = ExecutionLayout.SELF_DESTRUCT_BUTTON_RECT.size
	_button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	var red_style := StyleBoxFlat.new()
	red_style.bg_color = ScreenLayout.COLOR_WARNING_RED
	red_style.border_color = ExecutionLayout.COLOR_SCREEN_DARK
	red_style.set_border_width_all(2)
	red_style.set_content_margin_all(2)
	for style_name in ["normal", "hover", "pressed"]:
		_button.add_theme_stylebox_override(style_name, red_style)
	# Deliberately not the project button skin: keep light text on the red button.
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		_button.add_theme_color_override(color_name, ScreenLayout.COLOR_TEXT_LIGHT)
	_button.pressed.connect(press)
	add_child(_button)
	# Keep the whole button on screen even when its text needs more room.
	var button_size := _button.get_combined_minimum_size().max(ExecutionLayout.SELF_DESTRUCT_BUTTON_RECT.size)
	var bottom_right := ExecutionLayout.SELF_DESTRUCT_BUTTON_RECT.end
	_button.size = button_size
	_button.position = bottom_right - button_size
	_create_message_box()


func _process(real_seconds_since_last_frame: float) -> void:
	if _is_armed:
		_armed_elapsed_seconds += real_seconds_since_last_frame
		if _armed_elapsed_seconds >= ARM_TIMEOUT_SECONDS:
			_disarm()
	if _message_box.visible:
		_message_elapsed_seconds += real_seconds_since_last_frame
		if _message_elapsed_seconds >= MESSAGE_DURATION_SECONDS:
			_message_box.visible = false


## Arms the button on the first press and shows the next joke on the second.
func press() -> void:
	if not _is_armed:
		_is_armed = true
		_armed_elapsed_seconds = 0.0
		_button.text = ARMED_TEXT
		return
	_disarm()
	_message_label.text = JOKES[_next_joke_index]
	_next_joke_index = (_next_joke_index + 1) % JOKES.size()
	_message_elapsed_seconds = 0.0
	_message_box.visible = true


## True after the first press until the second press or the timeout.
func is_armed() -> bool:
	return _is_armed


## Returns the joke on screen, or "" when none is shown.
func shown_message() -> String:
	return _message_label.text if _message_box.visible else ""


func _disarm() -> void:
	_is_armed = false
	_button.text = IDLE_TEXT


func _create_message_box() -> void:
	_message_box = PanelContainer.new()
	_message_box.position = ExecutionLayout.SELF_DESTRUCT_MESSAGE_RECT.position
	_message_box.size = ExecutionLayout.SELF_DESTRUCT_MESSAGE_RECT.size
	var style := StyleBoxFlat.new()
	style.bg_color = ExecutionLayout.COLOR_SCREEN_DARK
	style.border_color = ScreenLayout.COLOR_WARNING_RED
	style.set_border_width_all(1)
	style.set_content_margin_all(4)
	_message_box.add_theme_stylebox_override("panel", style)
	_message_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_box.visible = false
	add_child(_message_box)
	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", MESSAGE_FONT_SIZE)
	_message_label.add_theme_color_override("font_color", ScreenLayout.COLOR_TEXT_LIGHT)
	_message_box.add_child(_message_label)
