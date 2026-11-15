extends Control
## T08 demo: shows the execution console fed with hand-made telemetry frames
## (ExecutionDemoFrames), so a person can check every panel state without a
## flight. Use the < and > buttons at the top right to step through the
## scenarios; under them each scenario says what to check.
## The clock runs at the frame's time scale, and the time controls work: they
## set FlightSimulation.time_scale, which the demo copies into its frame.
## Scenario 8 moves a radar contact inward and starts over when it arrives.
## Scenario 11 flies T09's reference rocket (ExampleFlight) for real: the
## console then reads live telemetry, and the debug panel (F3, debug builds
## only) shows the true state beside it. Leaving the scenario ends the flight.

const EXECUTION_CONSOLE_SCENE := preload("res://scenes/ExecutionConsole.tscn")
const LEFT_TO_RIGHT_LOCALE := "en"
const DEMO_MISSION_ID := "low_earth_orbit_placeholder"
const DEMO_SCIENCE_MISSION_ID := "earth_imaging"
## How fast the contact of scenario 8 closes, in metres per real second.
const APPROACH_METERS_PER_REAL_SECOND := 20000.0
## Area under the < > buttons for the scenario name and what to check. It ends
## above the angles panel.
const CAPTION_RECT := Rect2(520, 34, 118, 74)
const CAPTION_FONT_SIZE := 8

var _console: ExecutionConsole
var _caption_label: Label
var _state_index: int = 0
## The hand-made frame on screen; null during the live flight.
var _frame: TelemetryFrame
var _has_started_flight: bool = false


func _ready() -> void:
	TranslationServer.set_locale(LEFT_TO_RIGHT_LOCALE)
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	size = ScreenLayout.SCREEN_SIZE
	_select_demo_mission()

	_console = EXECUTION_CONSOLE_SCENE.instantiate()
	add_child(_console)
	_create_state_controls()
	_show_state(0)


func _process(real_seconds_since_last_frame: float) -> void:
	if _frame == null:
		return
	if FlightSimulation.time_scale != _frame.time_scale:
		_frame.time_scale = FlightSimulation.time_scale
	var simulated_seconds := real_seconds_since_last_frame * _frame.time_scale
	_frame.simulation_time_seconds += simulated_seconds
	if is_finite(_frame.seconds_until_next_pulse):
		_frame.seconds_until_next_pulse = maxf(0.0, _frame.seconds_until_next_pulse - simulated_seconds)
	if _state_index == ExecutionDemoFrames.STATE_THREAT_APPROACH:
		_move_approaching_contact(real_seconds_since_last_frame)
	_console.display_frame(_frame)


## Returns the index of the scenario on screen.
func state_index() -> int:
	return _state_index


## Returns the caption on screen: the scenario name and what to check.
func caption_text() -> String:
	return _caption_label.text


## Flies the reference rocket on fresh design and plan objects, so the ones
## GameState held before stay untouched.
func _start_live_flight() -> void:
	_frame = null
	GameState.design = RocketDesign.new()
	GameState.plan = MissionPlan.new()
	ExampleFlight.fill_reference_flight(GameState.design, GameState.plan, GameState.mission)
	GameState.notify_design_changed()
	FlightSimulation.start_flight(GameState.design, GameState.plan, GameState.mission, GameState.random_seed)
	FlightSimulation.set_time_scale(FlightSimulation.NORMAL_TIME_SCALE)
	_has_started_flight = true
	_console.set_debug_truth_shown(true)


func _end_live_flight() -> void:
	if _has_started_flight and FlightSimulation.is_flying:
		FlightSimulation.end_flight(FlightResult.EndReason.ABORTED)
	_has_started_flight = false
	if is_instance_valid(_console):
		_console.set_debug_truth_shown(false)


func _move_approaching_contact(real_seconds: float) -> void:
	var contact: Dictionary = _frame.radar_contacts[0]
	var range_meters: float = contact["range_meters"] - APPROACH_METERS_PER_REAL_SECOND * real_seconds
	if range_meters < ExecutionDemoFrames.APPROACH_END_RANGE_METERS:
		range_meters = ExecutionDemoFrames.APPROACH_START_RANGE_METERS
		_console.radar_panel.reset_scope()
	contact["range_meters"] = range_meters


func _select_demo_mission() -> void:
	var side_quest_ids: Array[String] = []
	for side_quest: Dictionary in GameData.mission(DEMO_MISSION_ID).get("side_quests", []):
		side_quest_ids.append(side_quest.get("id", ""))
	GameState.select_mission(DEMO_MISSION_ID, DEMO_SCIENCE_MISSION_ID, side_quest_ids)


func _create_state_controls() -> void:
	var switch_rect := ScreenLayout.CONSOLE_SWITCH_RECT
	var button_size := Vector2(switch_rect.size.x / 2.0, switch_rect.size.y)
	var previous_button := Button.new()
	previous_button.text = "<"
	previous_button.position = switch_rect.position
	previous_button.size = button_size
	previous_button.pressed.connect(func() -> void: _show_state(_state_index - 1))
	add_child(previous_button)

	var next_button := Button.new()
	next_button.text = ">"
	next_button.position = switch_rect.position + Vector2(button_size.x, 0)
	next_button.size = button_size
	next_button.pressed.connect(func() -> void: _show_state(_state_index + 1))
	add_child(next_button)

	var caption_background := ColorRect.new()
	caption_background.color = ExecutionLayout.COLOR_SCREEN_DARK
	caption_background.position = CAPTION_RECT.position
	caption_background.size = CAPTION_RECT.size
	caption_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption_background)

	_caption_label = Label.new()
	_caption_label.position = CAPTION_RECT.position + Vector2(3, 1)
	_caption_label.size = CAPTION_RECT.size - Vector2(6, 2)
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_label.clip_text = true
	_caption_label.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	_caption_label.add_theme_color_override("font_color", ScreenLayout.COLOR_TEXT_LIGHT)
	_caption_label.add_theme_constant_override("line_spacing", -2)
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption_label)


func _exit_tree() -> void:
	_end_live_flight()


func _show_state(state_index: int) -> void:
	var state_count := ExecutionDemoFrames.STATE_NAMES.size()
	_state_index = posmod(state_index, state_count)
	_end_live_flight()
	_caption_label.text = "DEMO %s\nCheck: %s" % [
			ExecutionDemoFrames.STATE_NAMES[_state_index], ExecutionDemoFrames.CHECK_HINTS[_state_index]]
	_console.alarm_panel.dismiss_alert()
	_console.radar_panel.reset_scope()
	if _state_index == ExecutionDemoFrames.STATE_LIVE_FLIGHT:
		_start_live_flight()
		return
	_frame = ExecutionDemoFrames.frame_for_state(_state_index)
	FlightSimulation.set_time_scale(_frame.time_scale)
	if _state_index == ExecutionDemoFrames.STATE_ALARMS:
		_console.show_alert(ExecutionDemoFrames.DEMO_ALERT_CODE, ExecutionDemoFrames.DEMO_ALERT_MESSAGE)
	elif _state_index == ExecutionDemoFrames.STATE_THREAT_ALERT:
		_console.show_alert(ExecutionDemoFrames.THREAT_ALERT_CODE, ExecutionDemoFrames.THREAT_ALERT_MESSAGE)
	_console.display_frame(_frame)
