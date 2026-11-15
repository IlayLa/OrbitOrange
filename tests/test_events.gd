extends RefCounted

const Director = preload("res://autoload/EventDirector.gd")
const Flight = preload("res://autoload/FlightSimulation.gd")
const EventRates = preload("res://scripts/events/EventRates.gd")
const ThreatGeometry = preload("res://scripts/events/ThreatModel.gd")
const Maneuver = preload("res://scripts/events/EmergencyManeuver.gd")
const REFERENCE_MISSION_ID := "low_earth_orbit_placeholder"
const RADAR_BASIC := "telemetry_radar_basic"
const RADAR_ADVANCED := "telemetry_radar_advanced"
const ALTIMETER := "telemetry_altimeter_basic"
const CAMERA := "science_camera_basic"
const COMPUTER_BASIC := "telemetry_computer_basic"
const COMPUTER_HARDENED := "telemetry_computer_hardened"
const CONJUNCTION := "satellite_conjunction"
const DEBRIS := "debris_shower"
const ASTEROID := "unknown_asteroid"
const ENGINE_FAULT := "engine_malfunction"
const LEAK := "propellant_leak"
const SENSOR_FAULT := "sensor_failure"
const FLARE := "solar_flare"
const STEP_SECONDS := 5.0


func run_tests(report: TestReport) -> void:
	_check_rate_modifiers(report)
	_check_rate_samples(report)
	_check_geometry(report)
	_check_radar_and_queue(report)
	_check_emergency_burn(report)
	_check_elapsed_collision_and_damage(report)
	_check_collision_before_planned_burn(report)
	_check_terminal_precedence(report)
	_check_real_warp_replay(report)
	_check_faults_and_hooks(report)


func _check_rate_modifiers(report: TestReport) -> void:
	var event_type := {"id": CONJUNCTION, "earliest_time_seconds": 600.0, "inside_zone_multiplier": 3.0}
	var mission := {"hazard_rates": {CONJUNCTION: [_band(0.0, 2000.0, 0.2), _band(2000.0, 100000.0, 0.02)]}}
	var related_quests: Array[Dictionary] = [
		{"related_event_type_ids": [CONJUNCTION], "related_multiplier": 2.0, "unrelated_bonus": 0.05},
		{"related_event_type_ids": [DEBRIS], "related_multiplier": 4.0, "unrelated_bonus": 0.25},
	]
	mission["hazard_zones"] = [
		{"inner_altitude_kilometers": 700.0, "outer_altitude_kilometers": 1000.0, "event_type_ids": [CONJUNCTION]},
		{"inner_altitude_kilometers": 800.0, "outer_altitude_kilometers": 1100.0, "event_type_ids": [CONJUNCTION]},
	]
	report.check_close(EventRates.effective_rate_events_per_hour(event_type, mission, [], 1999.999, 600.0),
			0.2, 1.0e-10, "the lower rate band includes altitudes just below its upper edge")
	report.check_close(EventRates.effective_rate_events_per_hour(event_type, mission, [], 2000.0, 600.0),
			0.02, 1.0e-10, "the upper rate band owns the shared boundary")
	report.check_close(EventRates.effective_rate_events_per_hour(event_type, mission, [], 100000.0, 600.0),
			0.0, 0.0, "above the last band there is no event rate")
	report.check_close(EventRates.effective_rate_events_per_hour(event_type, mission, related_quests, 900.0, 599.999),
			0.0, 0.0, "earliest time gates even a heavily modified event")
	report.check_close(EventRates.effective_rate_events_per_hour(event_type, mission, related_quests, 900.0, 600.0),
			1.5, 1.0e-10, "overlapping zones count once and both quest modifiers multiply")


func _check_rate_samples(report: TestReport) -> void:
	var zero_rows := _run_rate_fixture(0.0, 10000)
	report.check(zero_rows.is_empty(), "zero events are rolled in 10,000 zero-rate ticks")
	var steps_per_thousand_hours := int(1000.0 * 3600.0 / STEP_SECONDS)
	var rows := _run_rate_fixture(0.2, steps_per_thousand_hours)
	report.check(absi(rows.size() - 200) <= 60,
			"a fixed seed rolls %d events at 0.2 per hour over 1,000 hours" % rows.size())


func _run_rate_fixture(rate_events_per_hour: float, number_of_steps: int) -> Array[Dictionary]:
	var mission := {
		"body_id": "earth",
		"duration_seconds": STEP_SECONDS * (number_of_steps + 1),
		"hazard_rates": {SENSOR_FAULT: [_band(0.0, 2000.0, rate_events_per_hour)]},
	}
	var flight := HookFlight.new()
	var director := Director.new()
	director.configure(flight, mission, [], 7249, true, false)
	flight.flight_started.emit()
	for step_index in number_of_steps:
		flight.advance_tick()
	var rows: Array[Dictionary] = flight.event_log.duplicate(true)
	director.free()
	flight.free()
	return rows


func _check_geometry(report: TestReport) -> void:
	var body: Dictionary = GameData.body("earth")
	var initial_state := _circular_state(body)
	var coast := OrbitModel.build_trajectory_from_state(body, initial_state, [])
	var threat := _crossing_threat(body, coast, 0.0, 2.5, 0.0, 100.0, CONJUNCTION)
	var crossing := ThreatGeometry.closest_approach(body, coast, threat, 0.0, 5.0)
	report.check_close(crossing.get("time_seconds", INF), 2.5, 1.0e-4,
			"the shared search locates a crossing strictly inside a five-second tick")
	report.check_close(crossing.get("distance_meters", INF), 0.0, 0.01,
			"the exact Kepler position at the refined time is inside the collision radius")

	var near_miss := _crossing_threat(body, coast, 0.0, 2.5, 115.0, 100.0, CONJUNCTION)
	var miss := ThreatGeometry.closest_approach(body, coast, near_miss, 0.0, 5.0)
	report.check_close(miss.get("distance_meters", INF), 115.0, 0.01,
			"the same relative motion can miss by more than the collision radius")

	var scheduled_burn := ResolvedBurn.new()
	var burn_time_seconds := 2.3
	var at_burn := OrbitModel.state_at_time(body, coast, burn_time_seconds)
	scheduled_burn.polar_angle_radians = at_burn.polar_angle_radians()
	scheduled_burn.delta_v_along_velocity_meters_per_second = 500.0
	var burned := OrbitModel.build_trajectory_from_state(body, initial_state, [scheduled_burn])
	var post_burn_crossing := _crossing_threat(body, burned, 0.0, 3.85, 0.0, 100.0, CONJUNCTION)
	var same_object_without_burn := ThreatGeometry.closest_approach(body, coast, post_burn_crossing, 0.0, 5.0)
	var same_object_with_burn := ThreatGeometry.closest_approach(body, burned, post_burn_crossing, 0.0, 5.0)
	report.check_close(burned.segments[0].end_time_seconds, burn_time_seconds, 1.0e-5,
			"the fixture has a scheduled burn between regular samples")
	report.check(same_object_without_burn.get("distance_meters", 0.0) > 100.0,
			"the unmodified orbit safely misses the post-burn crossing")
	report.check_close(same_object_with_burn.get("time_seconds", INF), 3.85, 1.0e-4,
			"the search propagates the post-burn segment within the same tick")

	var random := RandomNumberGenerator.new()
	random.seed = 9283
	var generated := ThreatGeometry.generate_threat(body, coast, random, 0.0, 600.0, 100.0, 13, CONJUNCTION)
	random.seed = 9283
	var repeated := ThreatGeometry.generate_threat(body, coast, random, 0.0, 600.0, 100.0, 13, CONJUNCTION)
	report.check(not generated.is_empty() and not repeated.is_empty(), "generation accepts a verified close orbital pass")
	if not generated.is_empty() and not repeated.is_empty():
		var generated_threat: Threat = generated["threat"]
		var repeated_threat: Threat = repeated["threat"]
		report.check(generated["target_time_seconds"] >= 180.0 and generated["target_time_seconds"] <= 300.0
				and generated_threat.miss_distance_meters <= 300.0,
				"random threats pass within three collision radii after a 180–300 second lead")
		report.check(generated["target_time_seconds"] == repeated["target_time_seconds"]
				and generated_threat.state.velocity_x_meters_per_second == repeated_threat.state.velocity_x_meters_per_second
				and generated_threat.miss_distance_meters == repeated_threat.miss_distance_meters,
				"seeding gives exactly the same target, orbital state and distance")
	report.check(ThreatGeometry.generate_threat(body, coast, random, 0.0, 179.0, 100.0, 14, CONJUNCTION).is_empty(),
			"a mission too near its deadline cannot generate a full-lead encounter")

	var retrograde := ResolvedBurn.new()
	retrograde.fires_immediately = true
	retrograde.delta_v_along_velocity_meters_per_second = -2250.0
	var impact := OrbitModel.build_trajectory_from_state(body, initial_state, [retrograde])
	var terminal_seconds := ThreatGeometry.terminal_time_seconds(impact)
	report.check(is_finite(terminal_seconds) and impact.final_segment().end_reason == TrajectorySegment.EndReason.IMPACT,
			"the candidate fixture impacts the atmosphere")
	report.check(ThreatGeometry.closest_approach(body, impact, threat, terminal_seconds + 1.0, terminal_seconds + 6.0).is_empty(),
			"the search gives no clearance beyond the candidate path's physical end")


func _check_radar_and_queue(report: TestReport) -> void:
	var fixture := _orbital_flight([RADAR_ADVANCED])
	var flight: Flight = fixture["flight"]
	var director: Director = fixture["director"]
	var body: Dictionary = GameData.body("earth")
	var now_seconds := flight.simulation_time_seconds
	var later := _crossing_threat(body, flight.trajectory, now_seconds, now_seconds + 95.0, 210.0, 100.0, CONJUNCTION)
	var earlier := _crossing_threat(body, flight.trajectory, now_seconds, now_seconds + 80.0, 450.0, 250.0, ASTEROID)
	var alerts: Array[float] = []
	flight.alert_raised.connect(func(_code: String, _message: String) -> void:
		alerts.append(flight.simulation_time_seconds))
	report.check(director.force_encounter(CONJUNCTION, [later], now_seconds + 95.0)
			and director.force_encounter(ASTEROID, [earlier], now_seconds + 80.0), "two fixture encounters register")
	flight.advance_simulation(STEP_SECONDS)
	report.check(later.is_revealed and earlier.is_revealed and alerts == [now_seconds + STEP_SECONDS],
			"T03 radar reveals both contacts and the director raises only the earliest alert")
	report.check(director.active_encounter.get("event_type_id") == ASTEROID and flight.time_scale == 0.0,
			"earliest approach orders contacts and pauses flight")
	director.acknowledge_alert()
	if alerts.size() == 1:
		flight.advance_simulation(STEP_SECONDS)
	report.check(alerts.size() == 2 and director.active_encounter.get("event_type_id") == CONJUNCTION,
			"acknowledging the first alert surfaces the next contact")
	director.acknowledge_alert()
	flight.advance_simulation(160.0)
	report.check(alerts.size() == 2 and later.is_revealed and earlier.is_revealed,
			"persistently revealed contacts never trigger the same alert twice")
	report.check(flight.time_scale == FlightSimulation.NORMAL_TIME_SCALE and flight.threats.is_empty()
			and flight.event_log.size() == 2
			and flight.event_log[0]["outcome"] == "Threat avoided" and flight.event_log[1]["outcome"] == "Threat avoided",
			"Ignoring both near misses resumes at 1× and resolves both event rows")
	report.check(not flight.event_log.is_empty() and flight.event_log[0]["delta_v_spent_meters_per_second"] == 0.0
			and not flight.event_log[0]["did_player_react"], "Ignore leaves the row with zero velocity change")
	_free_fixture(fixture)

	fixture = _orbital_flight([RADAR_BASIC, RADAR_ADVANCED])
	flight = fixture["flight"]
	director = fixture["director"]
	flight.vehicle_state.is_working_by_instrument[RADAR_ADVANCED] = false
	now_seconds = flight.simulation_time_seconds
	var failed_radar_threat := _crossing_threat(body, flight.trajectory, now_seconds, now_seconds + 17.5, 175.0, 100.0, CONJUNCTION)
	director.force_encounter(CONJUNCTION, [failed_radar_threat], now_seconds + 17.5)
	flight.advance_simulation(STEP_SECONDS)
	report.check(director.active_encounter.is_empty(), "outside ten seconds a failed selected radar gives no alert")
	flight.advance_simulation(STEP_SECONDS)
	report.check(not failed_radar_threat.is_revealed and not director.active_encounter.is_empty() and flight.time_scale == 0.0,
			"within ten seconds the late warning still works when the highest-tier radar failed")
	director.acknowledge_alert()
	_free_fixture(fixture)


func _check_emergency_burn(report: TestReport) -> void:
	var fixture := _orbital_flight([RADAR_ADVANCED], true)
	var flight: Flight = fixture["flight"]
	var director: Director = fixture["director"]
	var body: Dictionary = GameData.body("earth")
	var now_seconds := flight.simulation_time_seconds
	var target_seconds := now_seconds + 85.0
	var threat := _crossing_threat(body, flight.trajectory, now_seconds, target_seconds, 0.0, 100.0, CONJUNCTION)
	director.force_encounter(CONJUNCTION, [threat], target_seconds)
	flight.advance_simulation(STEP_SECONDS)
	report.check(not director.active_encounter.is_empty() and flight.time_scale == 0.0,
			"radar pauses before a collision-course conjunction")
	var stage_id: int = flight.vehicle_state.design.stages.back().stage_id
	var pulse := Pulse.new()
	pulse.stage_id = stage_id
	pulse.fires_immediately = true
	pulse.delta_v_along_velocity_meters_per_second = 15.0

	var propellant_before := flight.vehicle_state.propellant_kilograms_by_stage.duplicate()
	var jettison_before := flight.vehicle_state.is_jettisoned_by_stage.duplicate()
	var path_before := flight.trajectory
	var velocity_before := flight.craft_state.velocity_y_meters_per_second
	var planned_time_seconds := flight.trajectory.segments[0].end_time_seconds
	var preview: Trajectory = Maneuver.preview_trajectory(body, flight.craft_state, flight.vehicle_state, pulse)
	var clearance := ThreatGeometry.closest_approach(body, preview, threat, flight.simulation_time_seconds, target_seconds + 60.0)
	report.check(clearance.get("distance_meters", 0.0) > 100.0 and threat.miss_distance_meters < 0.01,
			"the maneuver preview turns an actual crossing into a clear pass")
	report.check(flight.vehicle_state.propellant_kilograms_by_stage == propellant_before
			and flight.vehicle_state.is_jettisoned_by_stage == jettison_before
			and flight.trajectory == path_before and flight.craft_state.velocity_y_meters_per_second == velocity_before,
			"preview leaves live propellant, stage flags, velocity and trajectory untouched")

	flight.vehicle_state.has_failed_by_stage[stage_id] = true
	var failed: BurnOutcome = director.acknowledge_alert(pulse)
	report.check((failed == null or not failed.did_fire) and flight.time_scale == 0.0
			and not director.active_encounter.is_empty() and flight.trajectory == path_before,
			"a stage that fails between preview and execution leaves flight paused with its alert")
	flight.vehicle_state.has_failed_by_stage[stage_id] = false
	var fired: BurnOutcome = director.acknowledge_alert(pulse)
	report.check(fired != null and fired.did_fire and flight.time_scale == FlightSimulation.NORMAL_TIME_SCALE,
			"a successful Execute fires and resumes flight at 1×")
	if fired != null and fired.did_fire:
		var candidate_state := OrbitModel.state_at_time(body, preview, flight.simulation_time_seconds)
		report.check_close(flight.craft_state.velocity_y_meters_per_second,
				candidate_state.velocity_y_meters_per_second, 1.0e-8, "the actual maneuver matches the previewed velocity")
		report.check_close(flight.event_log[0]["delta_v_spent_meters_per_second"],
				fired.delta_v_delivered_meters_per_second, 1.0e-8, "the event logs exactly the actual delivered velocity change")
		report.check(flight.vehicle_state.propellant_kilograms_by_stage[stage_id] < propellant_before[stage_id]
				and flight.event_log[0]["did_player_react"] and flight.trajectory != path_before,
				"Execute spends reserve, records reaction, and rebuilds the trajectory")
		var next_planned_time_seconds: float = flight.trajectory.segments[0].end_time_seconds
		var pending_pulse: Pulse = fixture["pending_pulse"]
		var restarted_seconds := Kepler.seconds_until_polar_angle(body[OrbitModel.GRAVITATIONAL_PARAMETER_KEY],
				flight.craft_state, pending_pulse.polar_angle_radians, pending_pulse.extra_revolutions)
		report.check_close(next_planned_time_seconds - flight.simulation_time_seconds, restarted_seconds, 1.0e-6,
				"the later planned burn restarts its revolution count from the executed maneuver")
		report.check(next_planned_time_seconds > planned_time_seconds, "restarting the revolution count postpones the planned firing")

	flight.advance_simulation(160.0)
	report.check(flight.is_flying and flight.event_log[0]["outcome"] == "Threat avoided",
			"the patched orbit actually clears the conjunction")
	_free_fixture(fixture)


func _check_elapsed_collision_and_damage(report: TestReport) -> void:
	var fixture := _orbital_flight([])
	var body: Dictionary = GameData.body("earth")
	var flight: Flight = fixture["flight"]
	var director: Director = fixture["director"]
	var now_seconds := flight.simulation_time_seconds
	var target_seconds := now_seconds + 17.5
	var threat := _crossing_threat(body, flight.trajectory, now_seconds, target_seconds, 0.0, 100.0, CONJUNCTION)
	director.force_encounter(CONJUNCTION, [threat], target_seconds)
	var results: Array[FlightResult] = []
	flight.flight_ended.connect(func(result: FlightResult) -> void: results.append(result))
	flight.advance_simulation(10.0)
	report.check(not director.active_encounter.is_empty(), "no installed radar still gives a last-moment collision warning")
	director.acknowledge_alert()
	flight.advance_simulation(100.0)
	flight.advance_simulation(100.0)
	report.check(results.size() == 1 and results[0].end_reason == FlightResult.EndReason.COLLISION
			and results[0].event_log.size() == 1 and results[0].event_log[0]["outcome"] == "Collision"
			and results[0].event_log[0]["delta_v_spent_meters_per_second"] == 0.0,
			"an ignored between-tick crossing ends flight exactly once with the collision already logged")
	_free_fixture(fixture)

	fixture = _orbital_flight([])
	flight = fixture["flight"]
	director = fixture["director"]
	now_seconds = flight.simulation_time_seconds
	target_seconds = now_seconds + 17.5
	var fragments: Array[Threat] = [
		_crossing_threat(body, flight.trajectory, now_seconds, target_seconds, 0.0, 25.0, DEBRIS),
		_crossing_threat(body, flight.trajectory, now_seconds, target_seconds, 110.0, 25.0, DEBRIS),
		_crossing_threat(body, flight.trajectory, now_seconds, target_seconds, 130.0, 25.0, DEBRIS),
	]
	director.force_encounter(DEBRIS, fragments, target_seconds)
	flight.advance_simulation(10.0)
	director.acknowledge_alert()
	flight.advance_simulation(100.0)
	report.check(flight.is_flying and flight.vehicle_state.working_instrument_count() == 1
			and flight.event_log.size() == 1 and flight.event_log[0]["outcome"] == "Damage"
			and flight.threats.is_empty(), "one colliding debris fragment removes exactly one instrument and aggregates the row")
	_free_fixture(fixture)


func _check_collision_before_planned_burn(report: TestReport) -> void:
	var fixture := _orbital_flight([RADAR_ADVANCED], false, false, true)
	var flight: Flight = fixture["flight"]
	var director: Director = fixture["director"]
	var body: Dictionary = GameData.body("earth")
	var planned_burn_seconds := flight.trajectory.segments[0].end_time_seconds
	var tick_start_seconds := floorf(planned_burn_seconds / STEP_SECONDS) * STEP_SECONDS
	var target_seconds := 0.5 * (tick_start_seconds + planned_burn_seconds)
	var now_seconds := flight.simulation_time_seconds
	var threat := _crossing_threat(body, flight.trajectory, now_seconds, target_seconds, 0.0, 100.0, CONJUNCTION)
	report.check(planned_burn_seconds > tick_start_seconds and target_seconds > now_seconds + STEP_SECONDS
			and director.force_encounter(CONJUNCTION, [threat], target_seconds),
			"the fixture crosses the flown path just before a burn in the same tick")
	var planned_pulses: Array[int] = []
	var results: Array[FlightResult] = []
	flight.pulse_fired.connect(func(pulse_index: int, _outcome: BurnOutcome) -> void: planned_pulses.append(pulse_index))
	flight.flight_ended.connect(func(result: FlightResult) -> void: results.append(result))
	flight.advance_simulation(STEP_SECONDS)
	director.acknowledge_alert()
	flight.advance_simulation(45.0)
	report.check(planned_pulses == [1] and results.size() == 1
			and results[0].end_reason == FlightResult.EndReason.COLLISION,
			"after the real burn the director checks collision against the retained pre-burn path")
	_free_fixture(fixture)


func _check_terminal_precedence(report: TestReport) -> void:
	var fixture := _orbital_flight([])
	var flight: Flight = fixture["flight"]
	var director: Director = fixture["director"]
	var body: Dictionary = GameData.body("earth")
	var now_seconds := flight.simulation_time_seconds
	var target_seconds := now_seconds + 2.5
	var threat := _crossing_threat(body, flight.trajectory, now_seconds, target_seconds, 0.0, 100.0, CONJUNCTION)
	director.force_encounter(CONJUNCTION, [threat], target_seconds)

	# Align the impact with a completed tick so T03 emits simulation_step
	# while finalizing a physical flight end.
	var final_segment := flight.trajectory.final_segment()
	final_segment.end_reason = TrajectorySegment.EndReason.IMPACT
	final_segment.end_time_seconds = now_seconds + STEP_SECONDS
	var results: Array[FlightResult] = []
	var alerts: Array[String] = []
	flight.flight_ended.connect(func(result: FlightResult) -> void: results.append(result))
	flight.alert_raised.connect(func(code: String, _message: String) -> void: alerts.append(code))
	flight.advance_simulation(2.0 * STEP_SECONDS)
	report.check(results.size() == 1 and results[0].end_reason == FlightResult.EndReason.CRASHED,
			"an impact on the terminal tick outranks the conjunction on that tick")
	report.check(alerts.is_empty() and director.active_encounter.is_empty(),
			"the terminal tick clears encounters without opening an alert")
	_free_fixture(fixture)


func _check_real_warp_replay(report: TestReport) -> void:
	# One fixed tick per frame at 0.5x against the whole replay in one 8x frame.
	var earlier := _warp_fixture_events(FlightSimulation.ALLOWED_TIME_SCALES[1], STEP_SECONDS)
	var warped := _warp_fixture_events(FlightSimulation.ALLOWED_TIME_SCALES.back(), INF)
	report.check(earlier.size() >= 2, "the seed and rate chosen for the warp fixture roll multiple events")
	report.check(earlier == warped, "0.5x tick by tick and 8x in one frame reproduce exact event ids, times, targets and outcomes")


func _warp_fixture_events(scale_factor: float, simulated_seconds_per_frame: float) -> Array[Dictionary]:
	var fixture := _orbital_flight([RADAR_ADVANCED], false, true)
	var flight: Flight = fixture["flight"]
	var director: Director = fixture["director"]
	const REPLAY_SECONDS := 1000.0
	var start_seconds := flight.simulation_time_seconds
	var body: Dictionary = GameData.body("earth")
	var target_seconds := start_seconds + 95.0
	var near_miss := _crossing_threat(body, flight.trajectory, start_seconds, target_seconds, 250.0, 100.0, CONJUNCTION)
	director.force_encounter(CONJUNCTION, [near_miss], target_seconds)
	for frame_index in 205:
		if not flight.is_flying or flight.simulation_time_seconds >= start_seconds + REPLAY_SECONDS:
			break
		if flight.time_scale == 0.0:
			director.acknowledge_alert()
		flight.set_time_scale(scale_factor)
		var elapsed_seconds := flight.simulation_time_seconds - start_seconds
		var simulated_seconds := minf(simulated_seconds_per_frame, REPLAY_SECONDS - elapsed_seconds)
		flight._process(simulated_seconds / scale_factor)
	var rows: Array[Dictionary] = flight.event_log.duplicate(true)
	_free_fixture(fixture)
	return rows


func _check_faults_and_hooks(report: TestReport) -> void:
	var mission := {"body_id": "earth", "duration_seconds": 600.0}
	var flight := HookFlight.new()
	var director := Director.new()
	director.configure(flight, mission, [], 972, false, false)
	flight.flight_started.emit()
	var stage_id: int = flight.vehicle_state.design.stages[0].stage_id
	var capacity_kilograms := RocketModel.full_propellant_kilograms(flight.vehicle_state.design.stages[0])
	director.force_event(LEAK)
	report.check_close(flight.vehicle_state.propellant_kilograms_by_stage[stage_id], capacity_kilograms, 0.0,
			"a leak begins without charging for the preceding interval")
	for step_index in 12:
		flight.advance_tick()
	report.check_close(flight.vehicle_state.propellant_kilograms_by_stage[stage_id], capacity_kilograms * 0.99, 1.0e-6,
			"leak drains one percent of full capacity per simulated minute")
	report.check(flight.forecast_refresh_count == 12, "each leak tick requests a single forecast refresh")
	flight.vehicle_state.is_jettisoned_by_stage[stage_id] = true
	flight.advance_tick()
	report.check_close(flight.vehicle_state.propellant_kilograms_by_stage[stage_id], capacity_kilograms * 0.99, 1.0e-6,
			"jettisoned stages stop leaking")
	flight.vehicle_state.is_jettisoned_by_stage[stage_id] = false
	director.force_event(ENGINE_FAULT)
	report.check_close(flight.vehicle_state.specific_impulse_factor_by_stage[stage_id], 0.75, 0.0,
			"the first liquid engine fault weakens specific impulse")
	director.force_event(ENGINE_FAULT)
	report.check(flight.vehicle_state.has_failed_by_stage[stage_id], "a second fault disables the weakened engine")
	director.force_event(SENSOR_FAULT)
	report.check(not flight.vehicle_state.is_working_by_instrument[ALTIMETER]
			and flight.event_log.back()["outcome"] == "Sensor failed", "a sensor fault disables the working telemetry part")
	director.free()
	flight.free()

	for level in [0, 1, 2]:
		flight = HookFlight.new()
		var payload_part_ids: Array[String] = []
		if level >= 1:
			payload_part_ids.append(COMPUTER_BASIC)
		if level >= 2:
			payload_part_ids.append(COMPUTER_HARDENED)
		flight.set_payload(payload_part_ids)
		director = Director.new()
		director.configure(flight, mission, [], 972, false, false)
		flight.flight_started.emit()
		director.force_event(FLARE)
		var expected_scale := pow(0.5, level)
		report.check_close(flight.noise_fraction_addition, 0.2 * expected_scale, 1.0e-10,
				"flare noise addition reflects computer protection level %d" % level)
		report.check_close(flight.dropout_probability_addition, 0.15 * expected_scale, 1.0e-10,
				"flare dropout addition reflects computer protection level %d" % level)
		for step_index in 12:
			flight.advance_tick()
		director.force_event(FLARE)
		for step_index in 12:
			flight.advance_tick()
		report.check_close(flight.noise_fraction_addition, 0.2 * expected_scale, 1.0e-10,
				"an overlapping flare extends the timer without stacking")
		for step_index in 12:
			flight.advance_tick()
		report.check(flight.noise_fraction_addition == 0.0 and flight.dropout_probability_addition == 0.0,
				"both telemetry additions clear at the extended expiry")
		director.force_event(FLARE)
		flight.flight_started.emit()
		report.check(flight.noise_fraction_addition == 0.0 and flight.dropout_probability_addition == 0.0,
				"restarting clears an active flare")
		director.free()
		flight.free()


func _band(inner_kilometers: float, outer_kilometers: float, events_per_hour: float) -> Dictionary:
	return {"inner_altitude_kilometers": inner_kilometers, "outer_altitude_kilometers": outer_kilometers,
		"events_per_hour": events_per_hour}


func _orbital_flight(
		extra_payload: Array[String], add_later_pulse := false,
		roll_faults := false, add_nearby_pulse := false) -> Dictionary:
	var mission: Dictionary = GameData.mission(REFERENCE_MISSION_ID).duplicate(true)
	mission["duration_seconds"] = 20000.0
	if roll_faults:
		mission["hazard_rates"] = {
			SENSOR_FAULT: [_band(0.0, 2000.0, 28.0)],
			FLARE: [_band(0.0, 2000.0, 16.0)],
		}
	var design := RocketDesign.new()
	var plan := MissionPlan.new()
	ExampleFlight.fill_reference_rocket(design, plan)
	design.payload_part_ids.append_array(extra_payload)
	plan.launch_angle_radians = ExampleFlight.find_launch_angle_radians(design, plan, mission)
	plan.pulses.append(ExampleFlight.create_circularizing_pulse(design, plan, mission))
	var pending_pulse: Pulse
	if add_later_pulse:
		pending_pulse = plan.pulses[0].duplicate_pulse()
		pending_pulse.pulse_id = plan.next_free_pulse_id()
		pending_pulse.extra_revolutions = 1
		pending_pulse.delta_v_along_velocity_meters_per_second = 1.0
		plan.pulses.append(pending_pulse)
	if add_nearby_pulse:
		var body: Dictionary = GameData.body(mission["body_id"])
		var resolved := PlanResolver.resolve(design, plan, mission)
		var coast_state: OrbitState = resolved.trajectory.segments[1].start_state
		var nearby_state := Kepler.propagate(body[OrbitModel.GRAVITATIONAL_PARAMETER_KEY], coast_state, 23.0)
		pending_pulse = plan.pulses[0].duplicate_pulse()
		pending_pulse.pulse_id = plan.next_free_pulse_id()
		pending_pulse.polar_angle_radians = nearby_state.polar_angle_radians()
		pending_pulse.delta_v_along_velocity_meters_per_second = 5.0
		plan.pulses.append(pending_pulse)
	var flight := Flight.new()
	var director := Director.new()
	director.configure(flight, mission, [], 10015, roll_faults, false)
	var pulses: Array[int] = []
	flight.pulse_fired.connect(func(pulse_index: int, _outcome: BurnOutcome) -> void: pulses.append(pulse_index))
	flight.start_flight(design, plan, mission, 32855)
	for tick in 400:
		if not flight.is_flying or not pulses.is_empty():
			break
		flight.advance_simulation(STEP_SECONDS)
	return {"flight": flight, "director": director, "pending_pulse": pending_pulse}


func _free_fixture(fixture: Dictionary) -> void:
	fixture["director"].free()
	fixture["flight"].free()


func _circular_state(body: Dictionary) -> OrbitState:
	var radius_meters: float = float(body["radius_meters"]) + 400000.0
	var speed_meters_per_second := Kepler.circular_speed_meters_per_second(
			body[OrbitModel.GRAVITATIONAL_PARAMETER_KEY], radius_meters)
	return OrbitState.create(radius_meters, 0.0, 0.0, speed_meters_per_second)


func _crossing_threat(
		body: Dictionary, trajectory: Trajectory, spawn_time_seconds: float, target_seconds: float,
		offset_meters: float, radius_meters: float, event_type_id: String) -> Threat:
	var craft := OrbitModel.state_at_time(body, trajectory, target_seconds)
	var outward_x := craft.position_x_meters / craft.radius_meters()
	var outward_y := craft.position_y_meters / craft.radius_meters()
	const RELATIVE_SPEED_METERS_PER_SECOND := 1000.0
	var crossing := OrbitState.create(
			craft.position_x_meters - offset_meters * outward_y,
			craft.position_y_meters + offset_meters * outward_x,
			craft.velocity_x_meters_per_second + RELATIVE_SPEED_METERS_PER_SECOND * outward_x,
			craft.velocity_y_meters_per_second + RELATIVE_SPEED_METERS_PER_SECOND * outward_y,
			target_seconds)
	var threat := Threat.new()
	threat.event_type_id = event_type_id
	threat.collision_radius_meters = radius_meters
	threat.state = Kepler.propagate(body[OrbitModel.GRAVITATIONAL_PARAMETER_KEY], crossing, spawn_time_seconds - target_seconds)
	return threat


## A detached fixed-tick fixture keeps rate sampling cheap and exposes the
## two requested FlightSimulation hooks to verify the director's calls.
class HookFlight extends Node:
	signal flight_started
	signal simulation_step(step_seconds: float)
	signal pulse_fired(pulse_index: int, outcome: BurnOutcome)
	signal flight_ended(result: FlightResult)

	var is_flying := true
	var time_scale := 1.0
	var simulation_time_seconds := 0.0
	var craft_state: OrbitState
	var trajectory: Trajectory
	var vehicle_state: VehicleState
	var threats: Array[Threat] = []
	var event_log: Array[Dictionary] = []
	var noise_fraction_addition := 0.0
	var dropout_probability_addition := 0.0
	var forecast_refresh_count := 0

	func _init() -> void:
		var body: Dictionary = GameData.body("earth")
		var radius_meters: float = float(body["radius_meters"]) + 400000.0
		var speed_meters_per_second := Kepler.circular_speed_meters_per_second(
				body[OrbitModel.GRAVITATIONAL_PARAMETER_KEY], radius_meters)
		craft_state = OrbitState.create(radius_meters, 0.0, 0.0, speed_meters_per_second)
		trajectory = OrbitModel.build_trajectory_from_state(body, craft_state, [])
		set_payload([ALTIMETER])

	func set_payload(part_ids: Array[String]) -> void:
		var design := RocketDesign.new()
		design.add_stage(ExampleFlight.SECOND_STAGE_ENGINE_PART_ID, ExampleFlight.SECOND_STAGE_TANK_PART_ID)
		design.payload_part_ids.assign(part_ids)
		vehicle_state = RocketModel.create_vehicle_state(design)

	func advance_tick() -> void:
		simulation_time_seconds += STEP_SECONDS
		craft_state.time_seconds = simulation_time_seconds
		simulation_step.emit(STEP_SECONDS)

	func log_event(record: Dictionary) -> void:
		event_log.append(record.duplicate(true))

	func refresh_flight_forecast() -> void:
		forecast_refresh_count += 1

	func set_telemetry_interference(noise: float, dropout: float) -> void:
		noise_fraction_addition = noise
		dropout_probability_addition = dropout
