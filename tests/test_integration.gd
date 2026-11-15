extends RefCounted
## Flies real rockets from the pad to a score, through the public functions of
## every module: GameState, PlanResolver, RocketModel, Kepler, OrbitModel,
## FlightSimulation and Scoring. Added by T09.

const Flight = preload("res://autoload/FlightSimulation.gd")
const MISSION_ID := "low_earth_orbit_placeholder"
const SCIENCE_MISSION_ID := "earth_imaging"
const SOLID_ENGINE_PART_ID := "engine_solid_basic"
const CAMERA_PART_ID := "science_camera_basic"
## Simulated seconds handed to advance_simulation per call.
const ADVANCE_CHUNK_SECONDS := 500.0
## A flight that has not ended after this many chunks is a bug, not a slow test.
const MAXIMUM_CHUNK_COUNT := 200
const MINIMUM_SUCCESS_POINTS := 70.0
const SUCCESS_BAND_NAMES: Array[String] = ["Success", "Great Success", "Perfect", "Scientific Breakthrough"]


func run_tests(report: TestReport) -> void:
	var saved_mission: Dictionary = GameState.mission
	var saved_science_mission_id: String = GameState.science_mission_id
	var saved_side_quest_ids: Array[String] = GameState.side_quest_ids
	var saved_budget_million_usd: float = GameState.budget_million_usd
	var saved_design: RocketDesign = GameState.design
	var saved_plan: MissionPlan = GameState.plan
	var saved_summary: PlanSummary = GameState.summary
	var saved_trajectory: Trajectory = GameState.trajectory
	var saved_flight_result: FlightResult = GameState.flight_result
	var saved_score: ScoreReport = GameState.score

	_check_example_flight_setup(report)
	_check_winning_flight(report)
	_check_failing_flight(report)

	GameState.mission = saved_mission
	GameState.science_mission_id = saved_science_mission_id
	GameState.side_quest_ids = saved_side_quest_ids
	GameState.budget_million_usd = saved_budget_million_usd
	GameState.design = saved_design
	GameState.plan = saved_plan
	GameState.summary = saved_summary
	GameState.trajectory = saved_trajectory
	GameState.flight_result = saved_flight_result
	GameState.score = saved_score


## The shared helper builds the reference rocket and a launch angle whose
## apoapsis is at the target altitude.
func _check_example_flight_setup(report: TestReport) -> void:
	var mission: Dictionary = GameData.mission(MISSION_ID)
	var body: Dictionary = GameData.body(mission["body_id"])
	var design := RocketDesign.new()
	var plan := MissionPlan.legacy_plan()
	ExampleFlight.fill_reference_flight(design, plan, mission)
	report.check(design.stages.size() == 2, "the example rocket has two stages")
	report.check(design.payload_part_ids.size() == 2, "the example rocket carries a camera and an altimeter")
	report.check(plan.launch_stage_ids == [design.stages[0].stage_id], "only the first stage fires at launch")
	report.check(plan.pulses.size() == 1, "the example plan has one pulse")
	var summary: PlanSummary = RocketModel.summarize_plan(design, plan, mission["launch_loss_meters_per_second"])
	report.check_close(summary.cost_million_usd, 16.5, 0.0001, "the example rocket costs 16.5 million USD")
	report.check(summary.blocking_problems.is_empty(), "nothing blocks the launch of the example rocket")
	var apoapsis_radius_meters: float = ExampleFlight.launch_apoapsis_radius_meters(
			body, deg_to_rad(mission["launch_site"]["polar_angle_degrees"]),
			summary.burnout_speed_meters_per_second, plan.launch_angle_radians)
	var target_apoapsis_radius_meters: float = (
			float(body["radius_meters"]) + 1000.0 * float(mission["target"]["altitude_kilometers"]))
	report.check_close(apoapsis_radius_meters, target_apoapsis_radius_meters, 1.0,
			"the example launch angle puts the apoapsis at the target altitude")
	var launch_angle_degrees: float = rad_to_deg(plan.launch_angle_radians)
	report.check(launch_angle_degrees > 1.0 and launch_angle_degrees < 89.0,
			"the example launch angle is strictly between 1 and 89 degrees (%.4f)" % launch_angle_degrees)


func _check_winning_flight(report: TestReport) -> void:
	var no_side_quest_ids: Array[String] = []
	GameState.select_mission(MISSION_ID, SCIENCE_MISSION_ID, no_side_quest_ids)
	var mission: Dictionary = GameState.mission
	var body: Dictionary = GameData.body(mission["body_id"])
	var gravitational_parameter: float = body[OrbitModel.GRAVITATIONAL_PARAMETER_KEY]
	var design := RocketDesign.new()
	var plan := MissionPlan.legacy_plan()
	ExampleFlight.fill_reference_flight(design, plan, mission)
	GameState.design = design
	GameState.plan = plan
	GameState.notify_design_changed()

	var summary: PlanSummary = GameState.summary
	var launch_state: OrbitState = Kepler.launch_state(
			body, deg_to_rad(mission["launch_site"]["polar_angle_degrees"]),
			summary.burnout_speed_meters_per_second, plan.launch_angle_radians)
	var launch_elements: OrbitElements = Kepler.elements_from_state(gravitational_parameter, launch_state)
	var apoapsis_altitude_kilometers: float = (launch_elements.apoapsis_radius_meters - float(body["radius_meters"])) / 1000.0
	var pulse: Pulse = plan.pulses[0]
	report.check(summary.is_pulse_affordable.size() == 1 and summary.is_pulse_affordable[0],
			"the second stage can deliver the circularising pulse of %.1f m/s" % pulse.delta_v_along_velocity_meters_per_second)
	report.check(GameState.trajectory.status == Trajectory.Status.REACHES_ORBIT,
			"the planned trajectory reaches orbit")

	var pulse_outcomes: Array[BurnOutcome] = []
	var result: FlightResult = _fly(design, plan, mission, pulse_outcomes)
	report.check(result != null, "the winning flight ends within %d simulated seconds" % int(ADVANCE_CHUNK_SECONDS * MAXIMUM_CHUNK_COUNT))
	if result == null:
		return
	report.check(pulse_outcomes.size() == 1 and pulse_outcomes[0].did_fire, "the pulse fires once during the flight")
	GameState.finish_flight(result)
	var score: ScoreReport = GameState.score
	var target: Dictionary = mission["target"]
	var end_reason_name: String = FlightResult.EndReason.keys()[result.end_reason]
	report.check(result.end_reason == FlightResult.EndReason.MISSION_COMPLETED,
			"the winning flight ends as MISSION_COMPLETED (got %s)" % end_reason_name)
	report.check(result.did_reach_orbit, "the winning flight reaches orbit")
	if result.final_elements == null:
		report.check(false, "the winning flight reports its final orbit")
		return
	var final_altitude_kilometers: float = (result.final_elements.semi_major_axis_meters - float(body["radius_meters"])) / 1000.0
	report.check_close(final_altitude_kilometers, float(target["altitude_kilometers"]),
			float(target["altitude_tolerance_kilometers"]),
			"final semi-major-axis altitude in kilometers (burnout %.1f m/s, launch angle %.4f degrees, apoapsis before the pulse %.2f km, pulse %.1f m/s)" % [
				summary.burnout_speed_meters_per_second, rad_to_deg(plan.launch_angle_radians),
				apoapsis_altitude_kilometers, pulse.delta_v_along_velocity_meters_per_second])
	report.check_close(result.final_elements.eccentricity, float(target["eccentricity"]),
			float(target["eccentricity_tolerance"]), "final eccentricity")
	var required_data_megabits: float = GameState.science_mission()["required_data_megabits"]
	report.check(result.data_delivered_megabits >= required_data_megabits,
			"data delivered %.1f megabits, required %.1f (reserve delta-v %.1f m/s)" % [
				result.data_delivered_megabits, required_data_megabits, result.reserve_delta_v_meters_per_second])
	var line_texts: Array[String] = []
	for line in score.lines:
		line_texts.append("%s / %s %.2f of %.2f" % [line.part_name, line.line_name, line.points, line.maximum_points])
	report.check(score.total_points >= MINIMUM_SUCCESS_POINTS and SUCCESS_BAND_NAMES.has(score.band_name),
			"total score %.2f, band %s; lines: %s" % [score.total_points, score.band_name, "; ".join(PackedStringArray(line_texts))])
	report.check(not score.is_launch_failure, "the winning flight is not scored as a launch failure")
	print("  INFO  final eccentricity %s, final semi-major axis altitude %s km, flight duration %s s" % [
		String.num_scientific(result.final_elements.eccentricity), final_altitude_kilometers,
		result.flight_duration_seconds])


## A solid motor that burns out far below orbital speed falls back to the ground.
func _check_failing_flight(report: TestReport) -> void:
	var no_side_quest_ids: Array[String] = []
	GameState.select_mission(MISSION_ID, SCIENCE_MISSION_ID, no_side_quest_ids)
	var mission: Dictionary = GameState.mission
	var design := RocketDesign.new()
	var solid_stage: Stage = design.add_stage(SOLID_ENGINE_PART_ID)
	design.payload_part_ids.append(CAMERA_PART_ID)
	var plan := MissionPlan.legacy_plan()
	plan.launch_stage_ids.append(solid_stage.stage_id)
	plan.launch_angle_radians = deg_to_rad(30.0)
	GameState.design = design
	GameState.plan = plan
	GameState.notify_design_changed()

	var pulse_outcomes: Array[BurnOutcome] = []
	var result: FlightResult = _fly(design, plan, mission, pulse_outcomes)
	report.check(result != null, "the failing flight ends within %d simulated seconds" % int(ADVANCE_CHUNK_SECONDS * MAXIMUM_CHUNK_COUNT))
	if result == null:
		return
	GameState.finish_flight(result)
	var end_reason_name: String = FlightResult.EndReason.keys()[result.end_reason]
	report.check(result.end_reason == FlightResult.EndReason.LAUNCH_FAILURE,
			"the solid-motor flight ends as LAUNCH_FAILURE (got %s)" % end_reason_name)
	report.check(GameState.score.is_launch_failure, "the launch failure is scored as one")
	report.check_close(GameState.score.total_points, 0.0, 0.0, "a launch failure scores exactly 0")


## Flies the plan at time scale 1 until flight_ended fires, in chunks, and
## returns the result, or null when the flight has not ended after
## MAXIMUM_CHUNK_COUNT chunks. Every pulse outcome is appended to pulse_outcomes.
func _fly(design: RocketDesign, plan: MissionPlan, mission: Dictionary, pulse_outcomes: Array[BurnOutcome]) -> FlightResult:
	var flight := Flight.new()
	var results: Array[FlightResult] = []
	flight.flight_ended.connect(func(result: FlightResult) -> void: results.append(result))
	flight.pulse_fired.connect(func(_pulse_index: int, outcome: BurnOutcome) -> void: pulse_outcomes.append(outcome))
	flight.start_flight(design, plan, mission, 1)
	for chunk_index in MAXIMUM_CHUNK_COUNT:
		if not results.is_empty():
			break
		flight.advance_simulation(ADVANCE_CHUNK_SECONDS)
	flight.free()
	return null if results.is_empty() else results[0]
