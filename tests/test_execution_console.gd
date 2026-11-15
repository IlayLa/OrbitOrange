extends RefCounted
## Checks the execution console (T08): text formatting, every sensor state on
## the panels, the radar detail levels, the alarm lamp and alert, the time
## controls and the harmless self-destruct button. Drives the screen with the
## hand-made frames of ExecutionDemoFrames; no flight is started.

const EXECUTION_CONSOLE_SCENE := preload("res://scenes/ExecutionConsole.tscn")
const DEMO_SCENE := preload("res://scenes/development/T08_demo.tscn")

var _saved_state: Dictionary = {}


func run_tests(report: TestReport) -> void:
	_save_state()
	_check_reading_format(report)
	_check_radar_scope_range(report)
	var console: ExecutionConsole = EXECUTION_CONSOLE_SCENE.instantiate()
	GameState.add_child(console)
	_check_sensor_states(report, console)
	_check_angles_and_acceleration(report, console)
	_check_clock_and_objectives(report, console)
	_check_radar_levels(report, console)
	_check_alarm_and_alert(report, console)
	_check_time_controls(report, console)
	_check_self_destruct(report, console)
	console.free()
	_check_demo_runs(report)
	_restore_state()


func _save_state() -> void:
	_saved_state = {
		"locale": TranslationServer.get_locale(),
		"mission": GameState.mission,
		"science_mission_id": GameState.science_mission_id,
		"side_quest_ids": GameState.side_quest_ids.duplicate(),
		"budget_million_usd": GameState.budget_million_usd,
		"design": GameState.design,
		"plan": GameState.plan,
		# select_mission also recomputes these two.
		"summary": GameState.summary,
		"trajectory": GameState.trajectory,
		"time_scale": FlightSimulation.time_scale,
	}


func _restore_state() -> void:
	TranslationServer.set_locale(_saved_state["locale"])
	GameState.mission = _saved_state["mission"]
	GameState.science_mission_id = _saved_state["science_mission_id"]
	GameState.side_quest_ids = _saved_state["side_quest_ids"]
	GameState.budget_million_usd = _saved_state["budget_million_usd"]
	GameState.design = _saved_state["design"]
	GameState.plan = _saved_state["plan"]
	GameState.summary = _saved_state["summary"]
	GameState.trajectory = _saved_state["trajectory"]
	FlightSimulation.time_scale = _saved_state["time_scale"]


func _check_reading_format(report: TestReport) -> void:
	var as_text := func(value: float) -> String: return "%.0f" % value
	report.check(
			ReadingFormat.reading_text(ExecutionDemoFrames.reading(false, false, 5.0), as_text) == "NO SENSOR",
			"a channel without a sensor reads NO SENSOR")
	report.check(
			ReadingFormat.reading_text(ExecutionDemoFrames.reading(true, false, 5.0), as_text) == "NO SIGNAL",
			"an installed sensor that has failed reads NO SIGNAL")
	report.check(
			ReadingFormat.reading_text(ExecutionDemoFrames.reading(true, true, 5.0), as_text) == "5",
			"a working sensor shows its value")
	report.check_close(ReadingFormat.acceleration_in_g(9.80665), 1.0, 1.0e-12,
			"9.80665 m/s² is exactly 1 g")
	report.check(ReadingFormat.duration_text(INF) == "none", "no pulse left reads \"none\"")
	report.check(ReadingFormat.duration_text(3725.9) == "1:02:05", "3725.9 s reads 1:02:05")
	report.check(ReadingFormat.time_scale_label(0.0) == "II" and ReadingFormat.time_scale_label(100.0) == "100x",
			"time-scale labels are II for pause and 100x for 100")
	report.check(ReadingFormat.alarm_text("LOW_FUEL") == "LOW FUEL"
			and ReadingFormat.alarm_text("THREAT_APPROACH") == "THREAT APPROACHING"
			and ReadingFormat.alarm_text("NEW_CODE") == "NEW_CODE",
			"known alarm codes get readable text; unknown codes are shown as they are")


func _check_radar_scope_range(report: TestReport) -> void:
	report.check_close(ReadingFormat.radar_scope_range_meters(0.0), 10000.0, 0.0,
			"the radar scope is never smaller than 10 km")
	report.check_close(ReadingFormat.radar_scope_range_meters(42000.0), 50000.0, 0.0,
			"a contact at 42 km gives a 50 km scope")
	report.check_close(ReadingFormat.radar_scope_range_meters(1500000.0), 2000000.0, 0.0,
			"a contact at 1500 km gives a 2000 km scope")


func _check_sensor_states(report: TestReport, console: ExecutionConsole) -> void:
	var instruments: Array[InstrumentPanel] = [
		console.temperature_panel, console.altitude_panel,
		console.angles_panel, console.angles_panel,
	]
	var rows: Array[int] = [0, 0, AnglesPanel.ATTITUDE_ROW, AnglesPanel.FLIGHT_PATH_ANGLE_ROW]

	console.display_frame(ExecutionDemoFrames.frame_for_state(ExecutionDemoFrames.STATE_SENSORS_MISSING))
	var every_missing := true
	for instrument_index in instruments.size():
		every_missing = every_missing and instruments[instrument_index].value_text(rows[instrument_index]).ends_with("NO SENSOR")
	report.check(every_missing, "with no sensors installed every instrument reads NO SENSOR")
	report.check(console.radar_panel.shown_texts() == ["NO SENSOR"], "with no radar the radar reads NO SENSOR")
	report.check(console.delta_v_panel.value_text() == "4440 m/s",
			"the delta-v panel needs no sensor and still reads 4440 m/s (got %s)" % console.delta_v_panel.value_text())
	report.check(console.objectives_panel.shown_text().contains("FUEL NO SENSOR"),
			"without a fuel gauge the left column reads FUEL NO SENSOR")

	console.display_frame(ExecutionDemoFrames.frame_for_state(ExecutionDemoFrames.STATE_SENSORS_FAILED))
	var every_failed := true
	for instrument_index in range(1, instruments.size()):
		every_failed = every_failed and instruments[instrument_index].value_text(rows[instrument_index]).ends_with("NO SIGNAL")
	report.check(every_failed, "with failed sensors every installed instrument reads NO SIGNAL")
	report.check(console.objectives_panel.shown_text().contains("FUEL NO SIGNAL"),
			"with a failed fuel gauge the left column reads FUEL NO SIGNAL")

	console.display_frame(ExecutionDemoFrames.frame_for_state(ExecutionDemoFrames.STATE_NOMINAL))
	report.check(console.altitude_panel.value_text() == "412.3 km", "altitude 412300 m reads 412.3 km (got %s)" % console.altitude_panel.value_text())
	report.check(console.delta_v_panel.value_text() == "4440 m/s",
			"the delta-v panel (in place of fuel) reads 4440 m/s (got %s)" % console.delta_v_panel.value_text())
	report.check(console.temperature_panel.value_text() == "NO SENSOR", "the retired temperature slot shows NO SENSOR")


func _check_angles_and_acceleration(report: TestReport, console: ExecutionConsole) -> void:
	console.display_frame(ExecutionDemoFrames.frame_for_state(ExecutionDemoFrames.STATE_NOMINAL))
	report.check(console.acceleration_panel.value_text(AccelerationPanel.VALUE_ROW) == "0.00 g",
			"acceleration reads 0.00 g in free flight (got %s)" % console.acceleration_panel.value_text())

	console.display_frame(ExecutionDemoFrames.frame_for_state(ExecutionDemoFrames.STATE_LAUNCH_BURN))
	report.check(console.acceleration_panel.value_text(AccelerationPanel.VALUE_ROW) == "2.50 g",
			"2.5 × 9.80665 m/s² reads 2.50 g during the burn (got %s)" % console.acceleration_panel.value_text())
	var attitude_text := console.angles_panel.value_text(AnglesPanel.ATTITUDE_ROW)
	var flight_path_text := console.angles_panel.value_text(AnglesPanel.FLIGHT_PATH_ANGLE_ROW)
	report.check(attitude_text.ends_with("+30.0°") and flight_path_text.ends_with("+25.0°"),
			"attitude and flight-path angle are shown separately in degrees (got %s / %s)" % [attitude_text, flight_path_text])


func _check_clock_and_objectives(report: TestReport, console: ExecutionConsole) -> void:
	console.display_frame(ExecutionDemoFrames.frame_for_state(ExecutionDemoFrames.STATE_PAUSED_NO_PULSE))
	var clock_text := console.clock_panel.clock_text()
	report.check(clock_text.contains("T+ 1:30:00") and clock_text.contains("none"),
			"the clock shows mission time and \"none\" when no pulse is left (got %s)" % clock_text.replace("\n", " | "))
	var objectives_text := console.objectives_panel.shown_text()
	report.check(objectives_text.contains("FUEL 1830 kg") and objectives_text.contains("14.5 Mb generated")
			and objectives_text.contains("12.0 Mb delivered"),
			"the left column shows fuel left and science data generated and delivered")

	var mission: Dictionary = GameData.mission("low_earth_orbit_placeholder")
	var side_quest_ids: Array[String] = []
	for side_quest: Dictionary in mission.get("side_quests", []):
		side_quest_ids.append(side_quest.get("id", ""))
	GameState.select_mission("low_earth_orbit_placeholder", "earth_imaging", side_quest_ids)
	var objective_lines := ObjectivesPanel.objective_texts()
	report.check(objective_lines.size() == 2 + side_quest_ids.size(),
			"the objective list has the target orbit, the science mission and one line per side quest (got %d lines)" % objective_lines.size())
	report.check(objective_lines[0].contains("Orbit"), "the first objective is the target orbit")
	report.check(console.objectives_panel.shown_text().contains("Science:"),
			"the panel refreshes its objectives when the mission changes")


func _check_radar_levels(report: TestReport, console: ExecutionConsole) -> void:
	console.display_frame(ExecutionDemoFrames.frame_for_state(ExecutionDemoFrames.STATE_RADAR_CONTACTS))
	var radar := console.radar_panel
	var texts := radar.shown_texts()
	report.check_close(radar.scope_range_meters(), 50000.0, 0.0, "three contacts out to 42 km give a 50 km scope")
	report.check(texts.size() == 3, "level 0 adds no text; levels 1 and 2 add one each (got %s)" % [texts])
	report.check(texts.has("31.0 km"), "the level 1 contact shows its distance")
	var level_two_text := ""
	for text in texts:
		if text.contains("satellite_conjunction"):
			level_two_text = text
	report.check(level_two_text.contains("42.0 km") and level_two_text.contains("+7400 m/s"),
			"the level 2 contact shows type, distance and closing speed (got %s)" % level_two_text.replace("\n", " | "))

	var contact: Dictionary = {"bearing_radians": PI / 2.0, "range_meters": 25000.0}
	var drawn_position := radar.contact_position_pixels(contact)
	var expected_position := ExecutionLayout.RADAR_CENTER_IN_SCREEN + Vector2(
			0.0, -0.5 * ExecutionLayout.RADAR_OUTER_RING_RADIUS_PIXELS)
	report.check(drawn_position.distance_to(expected_position) < 0.01,
			"a contact at bearing 90° and half the scope range is drawn straight up, halfway to the outer ring")

	# An approaching contact must move inward, also across a scope step.
	radar.reset_scope()
	var approach_frame := ExecutionDemoFrames.frame_for_state(ExecutionDemoFrames.STATE_NOMINAL)
	var approaching_contact: Dictionary = {
		"bearing_radians": 0.0, "range_meters": 26000.0,
		"closing_speed_meters_per_second": 0.0, "resolution_level": 0, "event_type_id": "",
	}
	approach_frame.radar_contacts.append(approaching_contact)
	console.display_frame(approach_frame)
	var far_distance_pixels := radar.contact_position_pixels(approaching_contact).distance_to(
			ExecutionLayout.RADAR_CENTER_IN_SCREEN)
	approaching_contact["range_meters"] = 24000.0
	console.display_frame(approach_frame)
	var near_distance_pixels := radar.contact_position_pixels(approaching_contact).distance_to(
			ExecutionLayout.RADAR_CENTER_IN_SCREEN)
	report.check_close(radar.scope_range_meters(), 50000.0, 0.0,
			"the scope does not shrink from 50 km to 25 km as the contact closes from 26 to 24 km")
	report.check(near_distance_pixels < far_distance_pixels,
			"a contact closing from 26 km to 24 km moves inward (%.1f px -> %.1f px)" % [far_distance_pixels, near_distance_pixels])
	radar.reset_scope()
	console.display_frame(ExecutionDemoFrames.frame_for_state(ExecutionDemoFrames.STATE_NOMINAL))
	report.check_close(radar.scope_range_meters(), 10000.0, 0.0, "reset_scope returns the scope to 10 km")


func _check_alarm_and_alert(report: TestReport, console: ExecutionConsole) -> void:
	var alarm := console.alarm_panel
	console.display_frame(ExecutionDemoFrames.frame_for_state(ExecutionDemoFrames.STATE_NOMINAL))
	report.check(not alarm.is_flashing(), "the lamp is dark without active alarms")
	console.display_frame(ExecutionDemoFrames.frame_for_state(ExecutionDemoFrames.STATE_ALARMS))
	report.check(alarm.is_flashing(), "the lamp flashes while alarms are active")
	report.check(alarm.shown_text().contains("LOW FUEL") and alarm.shown_text().contains("HAZARD NEAR"),
			"the alarm texts are listed beside the lamp")

	FlightSimulation.alert_raised.emit("HAZARD_NEAR", "Test alert message")
	report.check(alarm.is_alert_shown() and alarm.shown_text().contains("Test alert message"),
			"an alert_raised message appears on screen")
	var paused_without_alarms := ExecutionDemoFrames.frame_for_state(ExecutionDemoFrames.STATE_NOMINAL)
	paused_without_alarms.time_scale = 0.0
	console.display_frame(paused_without_alarms)
	report.check(alarm.is_alert_shown() and not alarm.is_flashing(),
			"while the flight stays paused the alert stays up after the alarms clear")
	alarm.dismiss_alert()
	report.check(not alarm.is_alert_shown(), "OK hides the alert")

	# T07's overlay resumes the flight at 1x when the player answers it.
	FlightSimulation.alert_raised.emit("THREAT_APPROACH", "Satellite conjunction")
	console.display_frame(paused_without_alarms)
	report.check(alarm.is_alert_shown(), "a threat alert stays up while the flight is paused")
	console.display_frame(ExecutionDemoFrames.frame_for_state(ExecutionDemoFrames.STATE_NOMINAL))
	report.check(not alarm.is_alert_shown(), "the alert clears once a frame shows the flight running again")


func _check_time_controls(report: TestReport, console: ExecutionConsole) -> void:
	var clock := console.clock_panel
	var buttons := clock.time_scale_buttons()
	report.check(buttons.size() == FlightSimulation.ALLOWED_TIME_SCALES.size(),
			"there is one time-control button per allowed time scale")
	console.display_frame(ExecutionDemoFrames.frame_for_state(ExecutionDemoFrames.STATE_LAUNCH_BURN))
	report.check_close(clock.highlighted_time_scale(), 1000.0, 0.0, "the 1000x button is highlighted for a 1000x frame")
	console.display_frame(ExecutionDemoFrames.frame_for_state(ExecutionDemoFrames.STATE_PAUSED_NO_PULSE))
	report.check_close(clock.highlighted_time_scale(), 0.0, 0.0, "the pause button is highlighted for a paused frame")

	var ten_times_index := FlightSimulation.ALLOWED_TIME_SCALES.find(10.0)
	buttons[ten_times_index].pressed.emit()
	report.check_close(FlightSimulation.time_scale, 10.0, 0.0, "pressing 10x sets the flight time scale to 10")
	buttons[FlightSimulation.ALLOWED_TIME_SCALES.find(0.0)].pressed.emit()
	report.check_close(FlightSimulation.time_scale, 0.0, 0.0, "pressing pause pauses the flight")


func _check_self_destruct(report: TestReport, console: ExecutionConsole) -> void:
	var ended_flight_count: Array[int] = [0]
	var count_end := func(_result: FlightResult) -> void: ended_flight_count[0] += 1
	FlightSimulation.flight_ended.connect(count_end)
	var was_flying := FlightSimulation.is_flying
	var button := console.self_destruct_button
	button.press()
	report.check(button.is_armed() and button.shown_message() == "", "the first press only arms the self-destruct button")
	button.press()
	report.check(not button.is_armed() and button.shown_message() != "", "the second press shows a joke")
	FlightSimulation.flight_ended.disconnect(count_end)
	report.check(ended_flight_count[0] == 0 and FlightSimulation.is_flying == was_flying,
			"the self-destruct button does not end or change the flight")


func _check_demo_runs(report: TestReport) -> void:
	var state_count := ExecutionDemoFrames.STATE_NAMES.size()
	report.check(ExecutionDemoFrames.CHECK_HINTS.size() == state_count,
			"every demo scenario has a line saying what to check")
	var demo: Control = DEMO_SCENE.instantiate()
	GameState.add_child(demo)
	var console: ExecutionConsole = demo.get("_console")
	var every_state_shows := true
	for state_index in state_count:
		demo.call("_show_state", state_index)
		every_state_shows = (every_state_shows and demo.call("state_index") == state_index
				and String(demo.call("caption_text")).contains("Check: "))
	report.check(every_state_shows, "the T08 demo steps through all %d scenarios, each with its check line" % state_count)

	# Scenario 8: the contact closes in and is drawn closer to the centre.
	demo.call("_show_state", ExecutionDemoFrames.STATE_THREAT_APPROACH)
	var demo_frame: TelemetryFrame = demo.get("_frame")
	var center := ExecutionLayout.RADAR_CENTER_IN_SCREEN
	var drawn_distances_pixels: Array[float] = []
	var scope_ranges_meters: Array[float] = []
	for step_index in 6:
		# 1.5 s steps: six of them close 180 km, short of the restart at 3 km.
		demo.call("_process", 1.5)
		drawn_distances_pixels.append(
				console.radar_panel.contact_position_pixels(demo_frame.radar_contacts[0]).distance_to(center))
		scope_ranges_meters.append(console.radar_panel.scope_range_meters())
	var is_moving_inward := true
	var is_scope_steady := true
	for step_index in range(1, drawn_distances_pixels.size()):
		is_moving_inward = is_moving_inward and drawn_distances_pixels[step_index] < drawn_distances_pixels[step_index - 1]
		is_scope_steady = is_scope_steady and scope_ranges_meters[step_index] >= scope_ranges_meters[step_index - 1]
	report.check(is_moving_inward and is_scope_steady,
			"demo scenario 8: the approaching contact moves inward at every step and the scope never shrinks (%s px)" % [drawn_distances_pixels])

	# Scenario 9: pressing 1x resumes the flight and clears the threat alert.
	demo.call("_show_state", ExecutionDemoFrames.STATE_THREAT_ALERT)
	var alert_was_shown := console.alarm_panel.is_alert_shown() and console.alarm_panel.shown_text().contains("THREAT APPROACHING")
	var one_times_index := FlightSimulation.ALLOWED_TIME_SCALES.find(1.0)
	console.clock_panel.time_scale_buttons()[one_times_index].pressed.emit()
	demo.call("_process", 0.016)
	report.check(alert_was_shown and not console.alarm_panel.is_alert_shown(),
			"demo scenario 9: the threat alert shows while paused and clears after pressing 1x")

	# Scenario 11: a real flight; the instruments read live telemetry.
	report.check(DebugTruthPanel.truth_text().contains("No flight running."),
			"without a flight the debug panel says no flight is running")
	demo.call("_show_state", ExecutionDemoFrames.STATE_LIVE_FLIGHT)
	report.check(FlightSimulation.is_flying, "demo scenario 11 starts a real flight")
	# FlightSimulation holds the craft on the pad until the launch stage burns
	# out, so advance well past the burn before reading the altimeter.
	FlightSimulation.advance_simulation(300.0)
	FlightSimulation.call("_process", 0.0)
	var altitude_text := console.altitude_panel.value_text()
	report.check(altitude_text.ends_with(" km") and altitude_text != "0.0 km",
			"in the live flight the altimeter shows a live altitude (got %s at T+%.0f s)" % [
					altitude_text, FlightSimulation.simulation_time_seconds])
	report.check(console.debug_truth_panel.visible == DebugTruthPanel.is_available(),
			"the live flight shows the debug panel in debug builds only")
	var truth := DebugTruthPanel.truth_text()
	report.check(truth.contains("altitude") and truth.contains("eccentric.") and truth.contains("propellant"),
			"the debug panel lists true altitude, orbit and propellant")
	demo.call("_show_state", ExecutionDemoFrames.STATE_NOMINAL)
	report.check(not FlightSimulation.is_flying and not console.debug_truth_panel.visible,
			"leaving scenario 11 ends the flight and hides the debug panel")
	demo.free()
	report.check(not FlightSimulation.is_flying, "closing the demo leaves no flight running")
