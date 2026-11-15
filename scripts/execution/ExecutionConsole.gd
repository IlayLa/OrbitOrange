class_name ExecutionConsole
extends Control
## The EXECUTION half of the console: the instrument wall, the mission clock
## with the time controls, and the objective list. It displays only what
## arrives in TelemetryFrame objects from FlightSimulation.telemetry_updated.
## Requirements: context/plan_draft.md, sections "EXECUTION half",
## "Execution instruments" and "Time controls". Layout: Amit's mock-up
## res://design/execution_screen.png (see ExecutionLayout).
##
## From FlightSimulation it uses only: the signals telemetry_updated and
## alert_raised, the functions set_time_scale and pause, and the constant
## ALLOWED_TIME_SCALES. It never reads the true craft state, except in the
## debug-build-only DebugTruthPanel (F3), which players never see.
##
## display_frame, show_alert and refresh_objectives are public so that the
## T08 demo and the tests can drive the screen without a flight.

var clock_panel: ClockPanel
var objectives_panel: ObjectivesPanel
var alarm_panel: AlarmPanel
var radar_panel: RadarPanel
var temperature_panel: TemperaturePanel
var angles_panel: AnglesPanel
var altitude_panel: AltitudePanel
var delta_v_panel: DeltaVPanel
var acceleration_panel: AccelerationPanel
var self_destruct_button: SelfDestructButton
## Debug builds only: the true flight state, toggled with F3. See DebugTruthPanel.
var debug_truth_panel: DebugTruthPanel

## Every panel that redraws from a frame, in drawing order.
var _frame_panels: Array[Control] = []


func _ready() -> void:
	size = ScreenLayout.SCREEN_SIZE
	clip_contents = true
	# Right-to-left system languages mirror controls placed by position
	# (tasks/notes/T06.md); this screen is always left to right.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	theme = MissionPresentation.create_theme()
	_create_background()
	_create_panels()

	FlightSimulation.telemetry_updated.connect(display_frame)
	FlightSimulation.alert_raised.connect(show_alert)
	GameState.mission_changed.connect(refresh_objectives)


## Redraws every panel from one telemetry frame.
func display_frame(frame: TelemetryFrame) -> void:
	for panel in _frame_panels:
		panel.call("show_frame", frame)


## Shows an alert message beside the alarm lamp until the player dismisses it.
func show_alert(alarm_code: String, message: String) -> void:
	alarm_panel.show_alert(alarm_code, message)


## Rebuilds the objective list from GameState.
func refresh_objectives() -> void:
	objectives_panel.refresh_objectives()


func _create_background() -> void:
	ScreenLayout.add_mockup_background(self, ExecutionLayout.BACKGROUND_PATH)


func _create_panels() -> void:
	clock_panel = ClockPanel.new()
	clock_panel.time_scales = FlightSimulation.ALLOWED_TIME_SCALES.duplicate()
	clock_panel.time_scale_requested.connect(_on_time_scale_requested)
	clock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clock_panel)

	objectives_panel = ObjectivesPanel.new()
	add_child(objectives_panel)

	temperature_panel = _add_instrument(TemperaturePanel.new(), ExecutionLayout.TEMPERATURE_SCREEN) as TemperaturePanel
	angles_panel = _add_instrument(AnglesPanel.new(), ExecutionLayout.ANGLES_SCREEN) as AnglesPanel
	altitude_panel = _add_instrument(AltitudePanel.new(), ExecutionLayout.ALTITUDE_SCREEN) as AltitudePanel
	delta_v_panel = _add_instrument(DeltaVPanel.new(), ExecutionLayout.DELTA_V_SCREEN) as DeltaVPanel
	acceleration_panel = _add_instrument(
			AccelerationPanel.new(), ExecutionLayout.ACCELERATION_SCREEN) as AccelerationPanel

	radar_panel = RadarPanel.new()
	add_child(radar_panel)

	alarm_panel = AlarmPanel.new()
	add_child(alarm_panel)

	self_destruct_button = SelfDestructButton.new()
	add_child(self_destruct_button)

	debug_truth_panel = DebugTruthPanel.new()
	add_child(debug_truth_panel)

	_frame_panels = [
		clock_panel, objectives_panel, temperature_panel, angles_panel, altitude_panel,
		delta_v_panel, acceleration_panel, radar_panel, alarm_panel,
	]


func _add_instrument(panel: InstrumentPanel, mockup_panel_rect: Rect2) -> InstrumentPanel:
	panel.place_on(mockup_panel_rect)
	add_child(panel)
	return panel


## Shows or hides the debug panel with the true flight state. Only works in
## debug builds; players never see it.
func set_debug_truth_shown(is_shown: bool) -> void:
	debug_truth_panel.set_shown(is_shown)


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F3:
		set_debug_truth_shown(not debug_truth_panel.visible)
		get_viewport().set_input_as_handled()


func _on_time_scale_requested(time_scale: float) -> void:
	if time_scale == 0.0:
		FlightSimulation.pause()
	else:
		FlightSimulation.set_time_scale(time_scale)
