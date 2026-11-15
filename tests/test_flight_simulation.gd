extends RefCounted

const Flight = preload("res://autoload/FlightSimulation.gd")
const TEST_MISSION_ID := "flight_test_mission"
const TEST_ENGINE_ID := "flight_test_engine"
const TEST_LIQUID_ENGINE_ID := "flight_test_liquid_engine"
const TEST_TANK_ID := "flight_test_tank"
const TEST_ALTIMETER_ID := "flight_test_altimeter"
const TEST_RADAR_ID := "flight_test_radar"
const TEST_CAMERA_ID := "flight_test_camera"
const TEST_UNFIT_CAMERA_ID := "flight_test_unfit_camera"
const TEST_SMALL_TANK_ID := "flight_test_small_tank"
const TEST_DROPOUT_ID := "flight_test_dropout"
const FUEL_GAUGE_ID := "telemetry_fuel_gauge"
const ATTITUDE_SENSOR_ID := "telemetry_attitude_star_tracker"


func run_tests(report: TestReport) -> void:
	var selected_mission: Dictionary = GameState.mission
	var selected_science_id: String = GameState.science_mission_id
	_register_parts()
	_check_timing(report)
	_check_telemetry_and_science(report)
	_check_radar(report)
	_check_burns(report)
	_check_terminal_reasons(report)
	_check_terminal_tick_precedence(report)
	_check_low_fuel_alarm(report)
	_check_early_fuel_warning(report)
	_check_sensor_diagnostics(report)
	_check_science_fit(report)
	_check_shared_orbit_radii(report)
	GameState.mission = selected_mission
	GameState.science_mission_id = selected_science_id
	for part_id in [
		TEST_ENGINE_ID, TEST_LIQUID_ENGINE_ID, TEST_TANK_ID, TEST_ALTIMETER_ID,
		TEST_RADAR_ID, TEST_CAMERA_ID, TEST_DROPOUT_ID, TEST_UNFIT_CAMERA_ID, TEST_SMALL_TANK_ID,
	]:
		GameData.parts_by_id.erase(part_id)


func _check_timing(report: TestReport) -> void:
	for scale_factor in [1.0, 1000.0]:
		var flight := _start_flight([], 17.5)
		var steps: Array[float] = []
		var results: Array[FlightResult] = []
		flight.simulation_step.connect(func(seconds: float) -> void: steps.append(seconds))
		flight.flight_ended.connect(func(result: FlightResult) -> void: results.append(result))
		flight.set_time_scale(scale_factor)
		flight._process(20.0 / scale_factor)
		flight.advance_simulation(50.0)
		report.check(steps == [5.0, 5.0, 5.0], "warp preserves the fixed tick cadence")
		report.check(results.size() == 1, "a deadline between ticks ends the flight exactly once")
		if results.size() == 1:
			report.check(results[0].end_reason == FlightResult.EndReason.MISSION_COMPLETED, "deadline completes a stable flight")
			report.check_close(results[0].flight_duration_seconds, 17.5, 0.0001, "flight ends at the exact deadline")
		flight.free()

	var paused_flight := _start_flight()
	var observed_frames: Array[TelemetryFrame] = []
	paused_flight.telemetry_updated.connect(func(frame: TelemetryFrame) -> void: observed_frames.append(frame))
	paused_flight.simulation_step.connect(func(_seconds: float) -> void: paused_flight.raise_alert("TEST", "Pause"))
	paused_flight.set_time_scale(1000.0)
	paused_flight._process(1.0)
	paused_flight._process(1.0)
	report.check_close(paused_flight.simulation_time_seconds, 5.0, 0.0, "a synchronous alert stops catch-up")
	report.check(observed_frames.size() == 2 and observed_frames.back().time_scale == 0.0, "paused frames still publish")
	paused_flight.free()


func _check_telemetry_and_science(report: TestReport) -> void:
	var first := _start_flight([TEST_ALTIMETER_ID, TEST_CAMERA_ID])
	var second := _start_flight([TEST_ALTIMETER_ID, TEST_CAMERA_ID])
	first.advance_simulation(100.0)
	for step_index in 100:
		second.advance_simulation(1.0)
	var channel := TelemetryFrame.CHANNEL_ALTITUDE_METERS
	var first_frame := first._create_telemetry_frame()
	var second_frame := second._create_telemetry_frame()
	report.check(first_frame.reading(channel).value == second_frame.reading(channel).value, "same seed survives different frame grouping")
	report.check_close(first_frame.data_generated_megabits, 200.0, 0.0001, "100 seconds of science at 2 megabits per second")
	report.check_close(first_frame.data_delivered_megabits, 200.0, 0.0001, "instant link delivers all science")
	first.advance_simulation(1.0)
	report.check(first._create_telemetry_frame().reading(channel).value == first_frame.reading(channel).value, "slow sensor holds its sample")
	first.advance_simulation(1.0)
	first.vehicle_state.is_working_by_instrument[TEST_ALTIMETER_ID] = false
	first.vehicle_state.is_working_by_instrument[TEST_CAMERA_ID] = false
	first.advance_simulation(10.0)
	var failed_frame := first._create_telemetry_frame()
	report.check(failed_frame.reading(channel).is_sensor_installed and not failed_frame.reading(channel).is_sensor_working, "failed sensor remains installed")
	report.check_close(failed_frame.data_generated_megabits, 204.0, 0.0001, "failed camera stops generating data")
	first.free()
	second.free()

	var missing := _start_flight()
	report.check(not missing._create_telemetry_frame().reading(channel).is_sensor_installed, "altimeter is optional")
	missing.free()
	var dropout := _start_flight([TEST_DROPOUT_ID])
	dropout.advance_simulation(1.0)
	var reading := dropout._create_telemetry_frame().reading(channel)
	report.check(reading.is_sensor_installed and not reading.is_sensor_working, "dropout hides a working instrument's sample")
	dropout.free()


func _check_radar(report: TestReport) -> void:
	for resolution_level in 3:
		var radar := _part(TEST_RADAR_ID, "telemetry", {
			"channel": "radar", "range_kilometers": 50.0, "resolution_level": resolution_level,
			"updates_per_second": 1.0, "noise_fraction": 0.0, "dropout_probability": 0.0,
		})
		GameData.register_part(radar)
		var flight := _start_flight([TEST_RADAR_ID])
		var near_threat := _threat_at_offset(flight.craft_state, 1, 5000.0)
		var far_threat := _threat_at_offset(flight.craft_state, 2, 100000.0)
		flight.add_threat(near_threat)
		flight.add_threat(far_threat)
		var detections: Array[bool] = []
		flight.simulation_step.connect(func(_seconds: float) -> void: detections.append(near_threat.is_revealed))
		flight.advance_simulation(5.0)
		var frame := flight._create_telemetry_frame()
		report.check(detections == [true] and not far_threat.is_revealed, "radar reveals an in-range threat before the step signal")
		report.check(frame.radar_contacts.size() == 1, "out-of-range contacts are excluded")
		if frame.radar_contacts.size() == 1:
			var contact: Dictionary = frame.radar_contacts[0]
			report.check(contact["resolution_level"] == resolution_level, "radar forwards the installed resolution")
			report.check((contact["event_type_id"] == "test_threat") == (resolution_level == 2), "only tier 2 reveals the contact type")
		report.check(frame.active_alarms.has("HAZARD_NEAR"), "hazard proximity appears in the alarms")
		flight.remove_threat(1)
		report.check(flight._create_telemetry_frame().radar_contacts.is_empty(), "removed threats leave the contact cache")
		flight.free()


func _check_burns(report: TestReport) -> void:
	var flight := _start_flight()
	var pulse := Pulse.new()
	pulse.stage_id = flight.vehicle_state.design.stages[0].stage_id
	pulse.delta_v_along_velocity_meters_per_second = 50.0
	flight._plan.pulses.append(pulse)
	flight._plan.pulses.append(pulse.duplicate_pulse())
	flight._coast_segment.end_reason = TrajectorySegment.EndReason.NEXT_BURN
	flight._coast_segment.end_time_seconds = 22.5
	var indices: Array[int] = []
	var outcomes: Array[BurnOutcome] = []
	flight.pulse_fired.connect(func(pulse_index: int, outcome: BurnOutcome) -> void:
		indices.append(pulse_index)
		outcomes.append(outcome))
	flight.set_time_scale(1000.0)
	flight._process(1.0)
	report.check(flight.time_scale == 1.0, "planned pulse drops warp to normal speed")
	report.check_close(flight.simulation_time_seconds, 12.5, 0.0001, "unused warp is discarded ten seconds before the pulse")
	var speed_before_meters_per_second := flight.craft_state.speed_meters_per_second()
	flight.advance_simulation(10.0)
	report.check(indices == [0] and outcomes[0].did_fire, "planned pulse fires once at its original index")
	report.check(flight.craft_state.speed_meters_per_second() > speed_before_meters_per_second, "delivered prograde burn changes the live speed")
	flight.pause()
	var pending_index: int = flight._next_pulse_index
	var emergency_outcome := flight.apply_emergency_pulse(pulse)
	report.check(emergency_outcome.did_fire and indices == [0, -1], "an emergency pulse fires while paused")
	report.check(flight._next_pulse_index == pending_index, "an emergency pulse preserves remaining planned work")
	flight.vehicle_state.has_failed_by_stage[pulse.stage_id] = true
	var failure := flight.apply_emergency_pulse(pulse)
	report.check(not failure.did_fire and indices == [0, -1], "failed emergency burn leaves the trajectory intact")
	flight.free()

	var design := RocketDesign.new()
	var launch_stage := design.add_stage(TEST_ENGINE_ID)
	var second_stage := design.add_stage(TEST_ENGINE_ID)
	design.add_stage(TEST_ENGINE_ID)
	var plan := MissionPlan.legacy_plan()
	plan.launch_stage_ids.append_array([launch_stage.stage_id, second_stage.stage_id])
	var ascent := Flight.new()
	ascent.start_flight(design, plan, _mission(120.0), 123)
	var channel := TelemetryFrame.CHANNEL_ACCELERATION_METERS_PER_SECOND_SQUARED
	var first_acceleration := ascent._create_telemetry_frame().reading(channel).value
	ascent.advance_simulation(5.0)
	var second_acceleration := ascent._create_telemetry_frame().reading(channel).value
	report.check(first_acceleration > 0.0 and second_acceleration > first_acceleration, "acceleration increases as launch mass falls")
	ascent.advance_simulation(20.0)
	report.check(ascent._launch_stage == null and ascent._create_telemetry_frame().reading(channel).value == 0.0, "staged launch transitions to coast")
	ascent.free()


func _check_terminal_reasons(report: TestReport) -> void:
	for has_reached_orbit in [false, true]:
		var flight := _start_flight()
		flight._has_reached_stable_orbit = has_reached_orbit
		flight._coast_segment.end_reason = TrajectorySegment.EndReason.IMPACT
		flight._coast_segment.end_time_seconds = 7.5
		var results: Array[FlightResult] = []
		flight.flight_ended.connect(func(result: FlightResult) -> void: results.append(result))
		flight.advance_simulation(10.0)
		var reason := FlightResult.EndReason.CRASHED if has_reached_orbit else FlightResult.EndReason.LAUNCH_FAILURE
		report.check(results.size() == 1 and results[0].end_reason == reason, "impact is classified using flight history")
		flight.free()

	var escape := _start_flight()
	var body: Dictionary = GameData.body("earth")
	escape.craft_state.position_x_meters = float(body["radius_meters"]) * 20.0
	escape.craft_state.position_y_meters = 0.0
	escape._coast_segment.start_state = escape.craft_state.duplicate_state()
	escape._coast_segment.elements.is_open = true
	var escape_results: Array[FlightResult] = []
	escape.flight_ended.connect(func(result: FlightResult) -> void: escape_results.append(result))
	escape.advance_simulation(5.0)
	report.check(escape_results.size() == 1 and escape_results[0].end_reason == FlightResult.EndReason.ESCAPED, "open trajectory ends at the escape boundary")
	escape.free()

	for reason in [FlightResult.EndReason.ABORTED, FlightResult.EndReason.COLLISION]:
		var flight := _start_flight()
		var results: Array[FlightResult] = []
		var entry := {"event_type_id": "test", "outcome": "logged"}
		flight.log_event(entry)
		entry["outcome"] = "modified"
		flight.flight_ended.connect(func(result: FlightResult) -> void: results.append(result))
		flight.end_flight(reason)
		flight.end_flight(reason)
		report.check(results.size() == 1 and results[0].end_reason == reason, "external ending is preserved once")
		if results.size() == 1:
			report.check(results[0].event_log[0]["outcome"] == "logged", "result owns a copy of the event record")
		flight.free()


## The low-fuel alarm compares the propellant on board with the full capacity
## of the stages still attached, so a small upper stage is not "low" after the
## big lower stage has been dropped.
func _check_low_fuel_alarm(report: TestReport) -> void:
	var design := RocketDesign.new()
	var lower_stage: Stage = design.add_stage(TEST_LIQUID_ENGINE_ID, TEST_TANK_ID)
	var upper_stage: Stage = design.add_stage(TEST_LIQUID_ENGINE_ID, TEST_SMALL_TANK_ID)
	var flight := _start_flight_with_design(design, 200.0)
	report.check(not _has_low_fuel_alarm(flight), "no low-fuel alarm with every tank full")
	flight.vehicle_state.is_jettisoned_by_stage[lower_stage.stage_id] = true
	report.check(not _has_low_fuel_alarm(flight), "no low-fuel alarm after the big lower stage is dropped")
	flight.vehicle_state.propellant_kilograms_by_stage[upper_stage.stage_id] = 11.0
	report.check(not _has_low_fuel_alarm(flight), "no low-fuel alarm above 10 percent of the attached capacity")
	flight.vehicle_state.propellant_kilograms_by_stage[upper_stage.stage_id] = 10.0
	report.check(_has_low_fuel_alarm(flight), "low-fuel alarm at 10 percent of the attached capacity")
	flight.vehicle_state.is_jettisoned_by_stage[upper_stage.stage_id] = true
	report.check(not _has_low_fuel_alarm(flight), "no low-fuel alarm when no stage is attached")
	flight.free()


func _check_early_fuel_warning(report: TestReport) -> void:
	var reserves: Array[float] = []
	for gauge_state in ["working", "failed", "missing"]:
		var design := RocketDesign.new()
		var stage := design.add_stage(TEST_LIQUID_ENGINE_ID, TEST_SMALL_TANK_ID)
		if gauge_state != "missing":
			design.payload_part_ids.append(FUEL_GAUGE_ID)
		var flight := _start_flight_with_design(design, 200.0)
		if gauge_state == "failed":
			flight.vehicle_state.is_working_by_instrument[FUEL_GAUGE_ID] = false
		flight.vehicle_state.propellant_kilograms_by_stage[stage.stage_id] = 20.0
		flight.set_time_scale(1000.0)
		flight.advance_simulation(5.0)
		report.check(_has_low_fuel_alarm(flight) == (gauge_state == "working") and flight.time_scale == 1000.0,
				"the %s gauge produces the expected passive warning at 20 percent fuel" % gauge_state)
		flight.advance_simulation(5.0)
		var expected_rows := 1 if gauge_state == "working" else 0
		report.check(flight.event_log.size() == expected_rows, "the %s gauge records at most one early warning" % gauge_state)
		if expected_rows == 1 and not flight.event_log.is_empty():
			report.check(flight.event_log[0]["event_type_id"] == "fuel_warning", "the report explains the early fuel warning")
		reserves.append(flight._create_telemetry_frame().delta_v_remaining_meters_per_second)
		var pulse := Pulse.new()
		pulse.stage_id = stage.stage_id
		pulse.delta_v_along_velocity_meters_per_second = 20.0
		var outcome := flight.apply_emergency_pulse(pulse)
		report.check_close(outcome.delta_v_delivered_meters_per_second, 20.0, 1.0e-6,
				"the %s gauge has no effect on the burn delivery" % gauge_state)
		flight.free()
	report.check_close(reserves[0], reserves[1], 0.0, "a working or failed gauge on the same rocket reports the same reserve")


func _check_sensor_diagnostics(report: TestReport) -> void:
	var flight := _start_flight([TEST_ALTIMETER_ID, ATTITUDE_SENSOR_ID])
	flight._automatic_mission["target"] = {
		"altitude_kilometers": 250.0, "altitude_tolerance_kilometers": 25.0,
		"eccentricity": 0.0, "eccentricity_tolerance": 0.02,
	}
	flight.advance_simulation(1.0)
	var initial_attitude := flight._create_telemetry_frame().reading(TelemetryFrame.CHANNEL_ATTITUDE_RADIANS)
	report.check(initial_attitude.is_sensor_working and absf(initial_attitude.value) > 1.0e-8
			and absf(initial_attitude.value) <= PI / 2.0 * 0.001 + 1.0e-8,
			"a near-horizontal attitude sample has nonzero bounded angular noise")
	var pulse := Pulse.new()
	pulse.stage_id = flight.vehicle_state.design.stages[0].stage_id
	pulse.delta_v_along_velocity_meters_per_second = 500.0
	flight.apply_emergency_pulse(pulse)
	flight.advance_simulation(5.0)
	var frame := flight._create_telemetry_frame()
	report.check(not frame.reading(TelemetryFrame.CHANNEL_TEMPERATURE_KELVIN).is_sensor_installed
			and not frame.active_alarms.has("OVER_TEMPERATURE")
			and GameData.part("telemetry_temperature_sensor").is_empty(),
			"the temperature part, its live samples and the thermal alarm are gone")
	var results: Array[FlightResult] = []
	flight.flight_ended.connect(func(result: FlightResult) -> void: results.append(result))
	flight.advance_simulation(200.0)
	report.check(results.size() == 1 and results[0].end_reason == FlightResult.EndReason.MISSION_COMPLETED,
			"the usual mission timer still concludes a flight with diagnostics")
	if results.size() == 1:
		var rows := results[0].event_log
		report.check(rows.size() == 2 and rows[0]["event_type_id"] == "burn_diagnostic"
				and rows[0]["explanation"].contains("attitude sensor measured")
				and rows[1]["event_type_id"] == "altitude_diagnostic",
				"the report connects a burn to the eccentricity change and includes the final altimeter evidence")
	flight.free()


## Only science instruments rated above 0 for the chosen science mission
## collect data.
func _check_science_fit(report: TestReport) -> void:
	var flight := _start_flight([TEST_CAMERA_ID, TEST_UNFIT_CAMERA_ID])
	flight.advance_simulation(100.0)
	report.check_close(flight._create_telemetry_frame().data_generated_megabits, 200.0, 0.0001,
			"an instrument with rating 0 for the chosen science mission generates no data")
	flight.free()


## Escape and impact distances come from OrbitModel, so a change there reaches
## the flight.
func _check_shared_orbit_radii(report: TestReport) -> void:
	var flight := _start_flight()
	var body: Dictionary = GameData.body("earth")
	flight._coast_segment.elements.is_open = true
	var escape_radius_meters := OrbitModel.escape_radius_meters(body)
	var at_escape_radius := OrbitState.create(escape_radius_meters, 0.0, 0.0, 1.0)
	var inside_escape_radius := OrbitState.create(0.99 * escape_radius_meters, 0.0, 0.0, 1.0)
	report.check(flight._has_escaped(at_escape_radius), "escape begins at OrbitModel.escape_radius_meters")
	report.check(not flight._has_escaped(inside_escape_radius), "no escape inside OrbitModel.escape_radius_meters")

	var circular_elements := Kepler.elements_from_state(
			body["gravitational_parameter_cubic_meters_per_second_squared"], flight.craft_state)
	report.check(flight._is_stable_orbit(circular_elements), "a 400 km circular orbit is stable")
	flight._body["atmosphere_height_meters"] = 500000.0
	report.check(not flight._is_stable_orbit(circular_elements),
			"stability follows OrbitModel.impact_radius_meters (atmosphere above the orbit)")
	flight.free()


func _has_low_fuel_alarm(flight: Flight) -> bool:
	return flight._create_telemetry_frame().active_alarms.has("LOW_FUEL")


func _check_terminal_tick_precedence(report: TestReport) -> void:
	for has_impact in [true, false]:
		var flight := _start_flight([], 5.0 if has_impact else 200.0)
		if has_impact:
			flight._coast_segment.end_reason = TrajectorySegment.EndReason.IMPACT
			flight._coast_segment.end_time_seconds = 5.0
		var signal_order: Array[String] = []
		var results: Array[FlightResult] = []
		flight.simulation_step.connect(func(_seconds: float) -> void:
			signal_order.append("step")
			flight.end_flight(FlightResult.EndReason.COLLISION))
		flight.flight_ended.connect(func(result: FlightResult) -> void:
			signal_order.append("ended")
			results.append(result))
		flight.advance_simulation(10.0)
		var expected_reason := FlightResult.EndReason.CRASHED if has_impact else FlightResult.EndReason.COLLISION
		report.check(signal_order == ["step", "ended"], "the terminal tick and its result are emitted once")
		report.check(results.size() == 1 and results[0].end_reason == expected_reason,
				"impact outranks a same-tick collision and deadline" if has_impact
				else "a collision on a non-impact tick still ends the flight")
		flight.free()


func _start_flight(part_ids: Array[String] = [], duration_seconds: float = 200.0) -> Flight:
	var design := RocketDesign.new()
	design.add_stage(TEST_LIQUID_ENGINE_ID, TEST_TANK_ID)
	design.payload_part_ids.assign(part_ids)
	return _start_flight_with_design(design, duration_seconds)


## Starts a flight of the given design on a circular 400 km orbit.
func _start_flight_with_design(design: RocketDesign, duration_seconds: float) -> Flight:
	var mission := _mission(duration_seconds)
	GameState.mission = mission
	GameState.science_mission_id = "flight_test_science"
	var flight := Flight.new()
	flight.start_flight(design, MissionPlan.legacy_plan(), mission, 123)

	# A circular fixture works with the skeleton and the integrated orbit model.
	var body: Dictionary = GameData.body("earth")
	var radius_meters: float = float(body["radius_meters"]) + 400000.0
	var speed_meters_per_second := Kepler.circular_speed_meters_per_second(
			body["gravitational_parameter_cubic_meters_per_second_squared"], radius_meters)
	flight.craft_state = OrbitState.create(radius_meters, 0.0, 0.0, speed_meters_per_second)
	flight._rebuild_trajectory()
	return flight


func _mission(duration_seconds: float) -> Dictionary:
	return {"id": TEST_MISSION_ID, "body_id": "earth", "duration_seconds": duration_seconds,
		"science_missions": [{"id": "flight_test_science", "zone": {
			"type": "altitude_band", "inner_altitude_kilometers": 300.0, "outer_altitude_kilometers": 500.0,
		}}]}


func _threat_at_offset(craft: OrbitState, threat_id: int, offset_meters: float) -> Threat:
	var threat := Threat.new()
	threat.threat_id = threat_id
	threat.event_type_id = "test_threat"
	threat.state = craft.duplicate_state()
	threat.state.position_x_meters += offset_meters
	return threat


func _register_parts() -> void:
	GameData.register_part(_part(TEST_ENGINE_ID, "engine", {
		"engine_type": "solid", "thrust_kilonewtons": 98.0665,
		"specific_impulse_seconds": 100.0, "propellant_kilograms": 1000.0,
	}))
	GameData.register_part(_part(TEST_LIQUID_ENGINE_ID, "engine", {
		"engine_type": "liquid", "thrust_kilonewtons": 98.0665, "specific_impulse_seconds": 100.0,
	}))
	GameData.register_part(_part(TEST_TANK_ID, "tank", {
		"propellant_capacity_kilograms": 1000.0, "pressurization": "regulated",
	}))
	GameData.register_part(_part(TEST_ALTIMETER_ID, "telemetry", {
		"channel": TelemetryFrame.CHANNEL_ALTITUDE_METERS, "updates_per_second": 0.5,
		"noise_fraction": 0.1, "dropout_probability": 0.0,
	}))
	GameData.register_part(_part(TEST_DROPOUT_ID, "telemetry", {
		"channel": TelemetryFrame.CHANNEL_ALTITUDE_METERS, "updates_per_second": 1.0,
		"noise_fraction": 0.0, "dropout_probability": 1.0,
	}))
	GameData.register_part(_part(TEST_SMALL_TANK_ID, "tank", {
		"propellant_capacity_kilograms": 100.0, "pressurization": "regulated",
	}))
	var camera_part := _part(TEST_CAMERA_ID, "science", {"data_rate_megabits_per_second": 2.0})
	camera_part["mission_fit"] = {"flight_test_science": 2}
	GameData.register_part(camera_part)
	var unfit_camera_part := _part(TEST_UNFIT_CAMERA_ID, "science", {"data_rate_megabits_per_second": 5.0})
	unfit_camera_part["mission_fit"] = {"flight_test_science": 0, "other_science": 3}
	GameData.register_part(unfit_camera_part)


func _part(part_id: String, category: String, stats: Dictionary) -> Dictionary:
	return {"id": part_id, "name": part_id, "category": category, "tier": 1,
		"dry_mass_kilograms": 100.0, "cost_million_usd": 1.0, "source": "Synthetic test fixture", "stats": stats}
