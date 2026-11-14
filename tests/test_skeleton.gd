extends RefCounted
## Checks that the shared skeleton holds together: the data files load, the
## shared types can be created, and a design plus a plan resolves into a
## summary and a trajectory. These checks must keep passing after every task.
## Owned by the integrator.


func run_tests(report: TestReport) -> void:
	_check_data_files(report)
	_check_plan_resolves(report)
	_check_scoring_runs(report)
	_check_flight_runs_from_launch_to_score(report)


## Plays the whole game without any screen: choose a mission, build a rocket,
## fly, end the flight and score it.
func _check_flight_runs_from_launch_to_score(report: TestReport) -> void:
	var mission: Dictionary = GameData.all_missions()[0]
	var no_side_quest_ids: Array[String] = []
	GameState.start_new_game()
	GameState.select_mission(mission["id"], "earth_imaging", no_side_quest_ids)
	var first_stage: Stage = GameState.design.add_stage("engine_liquid_basic", "tank_aluminium_basic")
	GameState.plan.launch_stage_ids.append(first_stage.stage_id)
	GameState.notify_design_changed()
	report.check(GameState.summary != null, "choosing a mission and a rocket fills GameState.summary")

	var received_results: Array[FlightResult] = []
	var remember_result := func(result: FlightResult) -> void: received_results.append(result)
	FlightSimulation.flight_ended.connect(remember_result)
	FlightSimulation.start_flight(GameState.design, GameState.plan, GameState.mission, 1)
	report.check(FlightSimulation.is_flying, "the flight starts")
	FlightSimulation.end_flight(FlightResult.EndReason.MISSION_COMPLETED)
	FlightSimulation.flight_ended.disconnect(remember_result)

	report.check(received_results.size() == 1, "ending the flight reports exactly one result")
	if received_results.size() == 1:
		GameState.finish_flight(received_results[0])
		report.check(GameState.score != null, "finishing the flight produces a score")


func _check_data_files(report: TestReport) -> void:
	report.check(not GameData.parts_by_id.is_empty(), "parts.json has at least one part")
	report.check(not GameData.all_missions().is_empty(), "missions.json has at least one mission")
	report.check(not GameData.all_event_types().is_empty(), "event_types.json has at least one event type")

	var earth: Dictionary = GameData.body("earth")
	report.check(
			earth.has("gravitational_parameter_cubic_meters_per_second_squared"),
			"bodies.json describes Earth with its gravitational parameter")
	report.check(
			not GameData.parts_in_category(GameData.CATEGORY_ENGINE).is_empty(),
			"the catalogue has at least one engine")

	for part_id: String in GameData.parts_by_id:
		var part: Dictionary = GameData.parts_by_id[part_id]
		var has_required_keys: bool = (
				part.has("category") and part.has("name") and part.has("cost_million_usd")
				and part.has("dry_mass_kilograms") and part.has("stats") and part.has("source"))
		report.check(has_required_keys, "part \"%s\" has every required key" % part_id)


func _check_plan_resolves(report: TestReport) -> void:
	var mission: Dictionary = GameData.all_missions()[0]
	var design := RocketDesign.new()
	var first_stage: Stage = design.add_stage("engine_liquid_basic", "tank_aluminium_basic")
	design.payload_part_ids.append("science_camera_basic")

	var plan := MissionPlan.new()
	plan.launch_stage_ids.append(first_stage.stage_id)
	var pulse := Pulse.new()
	pulse.pulse_id = plan.next_free_pulse_id()
	pulse.stage_id = first_stage.stage_id
	pulse.delta_v_along_velocity_meters_per_second = 100.0
	plan.pulses.append(pulse)

	var resolved_plan: ResolvedPlan = PlanResolver.resolve(design, plan, mission)
	report.check(resolved_plan.summary != null, "resolving a plan gives a summary")
	report.check(resolved_plan.trajectory != null, "resolving a plan gives a trajectory")
	report.check(
			resolved_plan.summary.delta_v_delivered_by_pulse.size() == plan.pulses.size(),
			"the summary has one delivered delta-v entry per pulse")
	report.check(
			not resolved_plan.trajectory.segments.is_empty(),
			"the trajectory has at least one segment")
	report.check_close(
			resolved_plan.summary.cost_million_usd, 12.0, 0.001,
			"the cost of engine + tank + camera is the sum of their costs")

	var body: Dictionary = GameData.body(mission.get("body_id", "earth"))
	var state_after_one_minute: OrbitState = OrbitModel.state_at_time(body, resolved_plan.trajectory, 60.0)
	report.check(
			state_after_one_minute.radius_meters() > body["radius_meters"],
			"one minute after launch the craft is above the surface")


func _check_scoring_runs(report: TestReport) -> void:
	var flight_result := FlightResult.new()
	flight_result.did_reach_orbit = true
	var no_side_quests: Array[Dictionary] = []
	var score: ScoreReport = Scoring.compute_score(
			{}, {}, no_side_quests, RocketDesign.new(), 10.0, 30.0, flight_result)
	report.check(score != null and score.band_name != "", "scoring returns a report with a band name")

	flight_result.end_reason = FlightResult.EndReason.LAUNCH_FAILURE
	var failure_score: ScoreReport = Scoring.compute_score(
			{}, {}, no_side_quests, RocketDesign.new(), 10.0, 30.0, flight_result)
	report.check(
			failure_score.is_launch_failure and failure_score.total_points == 0.0,
			"a launch failure scores exactly 0")
