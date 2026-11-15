class_name AlarmPanel
extends Control
## ALARM: the lamp flashes while the frame has active alarms, and the alarm
## texts are listed beside it. An alert from FlightSimulation.alert_raised is
## shown until the player dismisses it: with OK, or by resuming the flight.
## raise_alert always pauses the flight, so a frame that runs again means the
## alert was handled, for example in T07's emergency overlay, which resumes
## at 1x. Pressing OK does not resume the flight.
##
## The lit lamp is cut out of the existing mock-up execution_screen_alarm.png;
## the unlit lamp is part of the background picture.

const FLASH_HALF_PERIOD_SECONDS := 0.5
const ALARM_FONT_SIZE := 10
const ALERT_FONT_SIZE := 9

var _lit_lamp: TextureRect
var _alarm_label: Label
var _alert_box: PanelContainer
var _alert_label: Label
var _active_alarm_codes: Array[String] = []
var _flash_elapsed_seconds: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_lamp()
	_create_alarm_label()
	_create_alert_box()


func _process(real_seconds_since_last_frame: float) -> void:
	if _active_alarm_codes.is_empty():
		return
	_flash_elapsed_seconds += real_seconds_since_last_frame
	_lit_lamp.visible = fmod(_flash_elapsed_seconds, 2.0 * FLASH_HALF_PERIOD_SECONDS) < FLASH_HALF_PERIOD_SECONDS


## Starts or stops the flashing and lists the frame's active alarms. Hides the
## alert once the frame shows the flight running again.
func show_frame(frame: TelemetryFrame) -> void:
	if _alert_box.visible and frame.time_scale > 0.0:
		dismiss_alert()
	if frame.active_alarms == _active_alarm_codes:
		return
	var was_quiet := _active_alarm_codes.is_empty()
	_active_alarm_codes = frame.active_alarms.duplicate()
	if _active_alarm_codes.is_empty():
		_lit_lamp.visible = false
		_alarm_label.text = ""
		return
	if was_quiet:
		_flash_elapsed_seconds = 0.0
		_lit_lamp.visible = true
	var alarm_lines: Array[String] = []
	for alarm_code in _active_alarm_codes:
		alarm_lines.append(ReadingFormat.alarm_text(alarm_code))
	_alarm_label.text = "  ".join(alarm_lines)


## Shows an alert message until the player dismisses it. A newer alert
## replaces the one on screen.
func show_alert(alarm_code: String, message: String) -> void:
	_alert_label.text = "%s\n%s" % [ReadingFormat.alarm_text(alarm_code), message]
	_alert_box.visible = true


## Hides the alert message.
func dismiss_alert() -> void:
	_alert_box.visible = false


## True while the lamp is flashing.
func is_flashing() -> bool:
	return not _active_alarm_codes.is_empty()


## True while an alert message is on screen.
func is_alert_shown() -> bool:
	return _alert_box.visible


## Returns the alarm texts and the alert message as shown.
func shown_text() -> String:
	var alert_text := _alert_label.text if _alert_box.visible else ""
	return (_alarm_label.text + "\n" + alert_text).strip_edges()


func _create_lamp() -> void:
	var lamp_texture := AtlasTexture.new()
	lamp_texture.atlas = load(ExecutionLayout.ALARM_BACKGROUND_PATH)
	lamp_texture.region = ExecutionLayout.LAMP_REGION_IN_MOCKUP
	_lit_lamp = TextureRect.new()
	_lit_lamp.texture = lamp_texture
	_lit_lamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lit_lamp.stretch_mode = TextureRect.STRETCH_SCALE
	_lit_lamp.position = ExecutionLayout.ALARM_LAMP_RECT.position
	_lit_lamp.size = ExecutionLayout.ALARM_LAMP_RECT.size
	_lit_lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lit_lamp.visible = false
	add_child(_lit_lamp)


func _create_alarm_label() -> void:
	_alarm_label = Label.new()
	_alarm_label.position = ExecutionLayout.ALARM_TEXT_RECT.position
	_alarm_label.size = Vector2(ExecutionLayout.ALARM_TEXT_RECT.size.x, 16)
	_alarm_label.clip_text = true
	_alarm_label.add_theme_font_size_override("font_size", ALARM_FONT_SIZE)
	_alarm_label.add_theme_color_override("font_color", ExecutionLayout.COLOR_LAMP_RED)
	_alarm_label.add_theme_color_override("font_outline_color", ExecutionLayout.COLOR_SCREEN_DARK)
	_alarm_label.add_theme_constant_override("outline_size", 3)
	_alarm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_alarm_label)


func _create_alert_box() -> void:
	var text_rect := ExecutionLayout.ALARM_TEXT_RECT
	_alert_box = PanelContainer.new()
	_alert_box.position = text_rect.position + Vector2(0, 18)
	_alert_box.size = Vector2(text_rect.size.x, text_rect.size.y - 18)
	var style := StyleBoxFlat.new()
	style.bg_color = ExecutionLayout.COLOR_SCREEN_DARK
	style.border_color = ExecutionLayout.COLOR_LAMP_RED
	style.set_border_width_all(1)
	style.set_content_margin_all(3)
	_alert_box.add_theme_stylebox_override("panel", style)
	_alert_box.visible = false
	add_child(_alert_box)

	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 1)
	_alert_box.add_child(contents)
	_alert_label = Label.new()
	_alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alert_label.custom_minimum_size.x = _alert_box.size.x - 8
	_alert_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_alert_label.add_theme_font_size_override("font_size", ALERT_FONT_SIZE)
	_alert_label.add_theme_color_override("font_color", ScreenLayout.COLOR_TEXT_LIGHT)
	contents.add_child(_alert_label)

	var dismiss_button := Button.new()
	dismiss_button.text = "OK"
	dismiss_button.focus_mode = Control.FOCUS_NONE
	dismiss_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	dismiss_button.add_theme_font_size_override("font_size", ALERT_FONT_SIZE)
	_set_tight_margins(dismiss_button)
	dismiss_button.pressed.connect(dismiss_alert)
	contents.add_child(dismiss_button)


## Copies the project theme's button skin with small margins so the button fits.
static func _set_tight_margins(button: Button) -> void:
	for style_name in ["normal", "hover", "pressed"]:
		var theme_style: StyleBox = button.get_theme_stylebox(style_name, "Button")
		var tight_style: StyleBox = theme_style.duplicate()
		tight_style.content_margin_left = 6
		tight_style.content_margin_right = 6
		tight_style.content_margin_top = 1
		tight_style.content_margin_bottom = 1
		button.add_theme_stylebox_override(style_name, tight_style)
