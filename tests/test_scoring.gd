extends RefCounted
## Numerical scoring and scene-behaviour regression checks using isolated fixtures.
var _mission: Dictionary
var _science: Dictionary
var _design: RocketDesign
const FINAL_SCREEN_SCENE := preload("res://scenes/FinalScreen.tscn")
const FINAL_SCREEN_SCRIPT := preload("res://scripts/mission/FinalScreen.gd")

func run_tests(report: TestReport) -> void:
	_mission = GameData.all_missions()[0].duplicate(true)
	_science = _mission["science_missions"][0].duplicate(true)
	_design = RocketDesign.new()
	var fixture_id := "t04_test_three_star_instrument"
	var previous_part := GameData.part(fixture_id)
	GameData.register_part({"id": fixture_id, "category": "science", "mission_fit": {_science["id"]: 3}})
	_design.payload_part_ids.append(fixture_id)
	_check_required_examples(report)
	_check_quests(report)
	_check_science_and_health(report)
	_check_mixed_and_extreme_results(report)
	_check_missing_and_open_orbits(report)
	_check_bands(report)
	_check_final_screen_portraits(report)
	_check_data_and_screens(report)
	if previous_part.is_empty():
		GameData.parts_by_id.erase(fixture_id)
	else:
		GameData.register_part(previous_part)

func _flight() -> FlightResult:
	var result := FlightResult.new()
	result.did_reach_orbit = true
	result.final_elements = OrbitElements.new()
	result.final_elements.semi_major_axis_meters = float(GameData.body(_mission["body_id"])["radius_meters"]) + float(_mission["target"]["altitude_kilometers"]) * 1000.0
	result.final_elements.eccentricity = float(_mission["target"]["eccentricity"])
	result.science_coverage_fraction = 1.0
	result.data_delivered_megabits = float(_science["required_data_megabits"])
	result.data_generated_megabits = result.data_delivered_megabits
	result.installed_instrument_count = 2
	result.working_instrument_count = 2
	return result

func _score(result: FlightResult, cost_million_usd: float = 27.0, budget_million_usd: float = 30.0, quests: Array[Dictionary] = []) -> ScoreReport:
	return Scoring.compute_score(_mission, _science, quests, _design, cost_million_usd, budget_million_usd, result)

func _points(score: ScoreReport, line_name: String) -> float:
	for line in score.lines:
		if line.line_name == line_name:
			return line.points
	return NAN

func _check_sum(report: TestReport, score: ScoreReport) -> void:
	var total := 0.0
	for line in score.lines:
		total += line.points
		report.check(not line.explanation.is_empty(), line.line_name + " explains the result")
	report.check_close(total, score.total_points, 0.000001, "score rows sum to the unrounded total")

func _check_required_examples(report: TestReport) -> void:
	var result := _flight()
	var score := _score(result)
	report.check_close(score.total_points, 100.0, 0.000001, "perfect flight ten percent under budget earns 100")
	report.check(score.band_name == "Perfect", "perfect flight has Perfect band")
	report.check_close(_score(result, 30.0).total_points, 95.0, 0.000001, "exactly on budget earns 95")
	for example in [[27.0, 30.0], [30.0, 25.0], [33.0, 15.0], [45.0, -25.0], [48.0, -25.0]]:
		report.check_close(Scoring.budget_points(example[0], 30.0), example[1], 0.000001, "budget cost %.0f gives %.0f points" % [example[0], example[1]])
		var budget_report := _score(result, example[0])
		report.check_close(_points(budget_report, "Within budget") + _points(budget_report, "Margin"), Scoring.budget_points(example[0], 30.0), 0.000001, "budget preview equals report rows")
	result.final_elements.semi_major_axis_meters += 50000.0
	report.check_close(_points(_score(result), "Altitude accuracy"), 7.5, 0.000001, "half altitude tolerance earns 7.5")
	_check_sum(report, _score(result))
	result.end_reason = FlightResult.EndReason.LAUNCH_FAILURE
	score = _score(result)
	report.check(score.is_launch_failure and score.total_points == 0.0, "launch failure overrides otherwise perfect input")
	_check_sum(report, score)
	report.check_close(Scoring.budget_points(0.0, 0.0), 25.0, 0.000001, "zero budget and cost have no saving margin")
	report.check_close(Scoring.budget_points(1.0, 0.0), -25.0, 0.000001, "spending with zero budget receives minimum budget score")

func _quest(condition_type: String, threshold_meters_per_second: float, grant_million_usd: float = 5.0) -> Dictionary:
	return {"name": "Test reserve", "grant_million_usd": grant_million_usd, "condition": {"type": condition_type, "delta_v_meters_per_second": threshold_meters_per_second}}

func _check_quests(report: TestReport) -> void:
	var result := _flight()
	result.reserve_delta_v_meters_per_second = 100.0
	var quests: Array[Dictionary] = [_quest("reserve_delta_v_at_least", 100.0)]
	var score := _score(result, 27.0, 35.0, quests)
	report.check_close(score.total_points, 120.0, 0.000001, "one successful quest adds 20 with its grant retained")
	quests = [_quest("reserve_delta_v_at_most", 100.0)]
	report.check_close(_points(_score(result, 27.0, 35.0, quests), "Test reserve"), 20.0, 0.000001, "at-most threshold is inclusive")
	result.reserve_delta_v_meters_per_second = 0.0
	quests = []
	for failed_count in range(1, 4):
		quests.append(_quest("reserve_delta_v_at_least", 100.0))
		score = _score(result, 30.0, 30.0 + 5.0 * failed_count, quests)
		var expected_penalties := [5.0, 15.0, 30.0]
		report.check_close(_points(score, "Failure penalty"), -expected_penalties[failed_count - 1], 0.000001, "failure penalty for %d quests" % failed_count)
		report.check_close(_points(score, "Within budget"), 25.0, 0.000001, "all failed grants are reclaimed exactly once")
	_check_sum(report, score)
	quests = [_quest("reserve_delta_v_at_least", 100.0)]
	score = _score(result, 35.0, 35.0, quests)
	report.check_close(_points(score, "Within budget"), 25.0 - 100.0 / 6.0, 0.000001, "failed grant can turn an on-budget design into an over-budget flight")

func _check_science_and_health(report: TestReport) -> void:
	var result := _flight()
	result.working_instrument_count = 1
	report.check_close(_points(_score(result), "Vehicle health"), 2.5, 0.000001, "one of two instruments earns half health")
	result.installed_instrument_count = 0
	result.working_instrument_count = 0
	report.check_close(_points(_score(result), "Vehicle health"), 5.0, 0.000001, "empty payload earns full health by user decision")
	result.science_coverage_fraction = 0.4
	result.data_delivered_megabits = 2500.0
	result.data_generated_megabits = 50000.0
	var score := _score(result)
	report.check_close(_points(score, "Coverage"), 4.0, 0.000001, "half required coverage earns 4")
	report.check_close(_points(score, "Data returned"), 2.0, 0.000001, "score uses delivered rather than generated data")
	_design.payload_part_ids.append("science_camera_basic")
	report.check_close(_points(_score(result), "Instrument fit"), 8.0, 0.000001, "fit uses best instrument rather than adding ratings")
	_design.payload_part_ids.erase("science_camera_basic")
	var empty_design := RocketDesign.new()
	score = Scoring.compute_score(_mission, {}, [], empty_design, 27.0, 30.0, result)
	report.check_close(_points(score, "Instrument fit") + _points(score, "Coverage") + _points(score, "Data returned"), 0.0, 0.000001, "missing science selection earns zero science")
	var zero_tolerance: Dictionary = _mission.duplicate(true)
	zero_tolerance["target"]["altitude_tolerance_kilometers"] = 0.0
	score = Scoring.compute_score(zero_tolerance, _science, [], _design, 27.0, 30.0, result)
	report.check_close(_points(score, "Altitude accuracy"), 15.0, 0.000001, "exact zero-tolerance match earns full accuracy")
	result.final_elements.semi_major_axis_meters += 1.0
	score = Scoring.compute_score(zero_tolerance, _science, [], _design, 27.0, 30.0, result)
	report.check_close(_points(score, "Altitude accuracy"), 0.0, 0.000001, "zero-tolerance mismatch earns zero")
	var zero_requirements: Dictionary = _science.duplicate(true)
	zero_requirements["required_coverage_fraction"] = 0.0
	zero_requirements["required_data_megabits"] = 0.0
	score = Scoring.compute_score(_mission, zero_requirements, [], _design, 27.0, 30.0, result)
	report.check_close(_points(score, "Coverage") + _points(score, "Data returned"), 12.0, 0.000001, "zero requirements are satisfied on a closed orbit")
	result.final_elements = null
	score = Scoring.compute_score(_mission, zero_requirements, [], _design, 27.0, 30.0, result)
	report.check_close(_points(score, "Coverage"), 0.0, 0.000001, "zero requirement still needs final closed elements for coverage")

func _check_missing_and_open_orbits(report: TestReport) -> void:
	var result := _flight()
	result.did_reach_orbit = false
	result.end_reason = FlightResult.EndReason.COLLISION
	var score := _score(result)
	report.check(not score.is_launch_failure, "loss of final safe orbit is distinct from launch failure")
	report.check_close(_points(score, "Orbit achieved"), 0.0, 0.000001, "orbit points use final safe-orbit flag")
	report.check_close(_points(score, "Altitude accuracy"), 15.0, 0.000001, "collision still grades valid closed final elements independently")
	result.final_elements.is_open = true
	score = _score(result)
	report.check_close(_points(score, "Altitude accuracy") + _points(score, "Orbit shape") + _points(score, "Coverage"), 0.0, 0.000001, "open orbit earns zero orbital accuracy and coverage")
	result.final_elements = null
	score = _score(result)
	_check_sum(report, score)
	report.check_close(_points(score, "Coverage"), 0.0, 0.000001, "missing elements earn zero coverage")
	report.check(Scoring.compute_score({}, {}, [], RocketDesign.new(), 10.0, 30.0, FlightResult.new()) != null, "empty skeleton inputs remain supported")

func _check_mixed_and_extreme_results(report: TestReport) -> void:
	var result := _flight()
	result.reserve_delta_v_meters_per_second = 100.0
	var quests: Array[Dictionary] = [_quest("reserve_delta_v_at_least", 100.0), _quest("reserve_delta_v_at_least", 200.0)]
	var score := _score(result, 35.0, 40.0, quests)
	report.check_close(_points(score, "Within budget"), 25.0, 0.000001, "mixed quest results reclaim only the failed grant")
	report.check_close(_points(score, "Failure penalty"), -5.0, 0.000001, "one failed and one successful quest incur one failure penalty")
	report.check_close(score.total_points, 110.0, 0.000001, "mixed quest results include success bonus and failed grant repayment")
	result.final_elements.eccentricity = 0.025
	report.check_close(_points(_score(result), "Orbit shape"), 5.0, 0.000001, "half eccentricity tolerance earns half shape points")
	result.science_coverage_fraction = 2.0
	result.data_delivered_megabits = 10000.0
	score = _score(result)
	report.check_close(_points(score, "Coverage") + _points(score, "Data returned"), 12.0, 0.000001, "science progress is capped at its maximum")
	result.end_reason = FlightResult.EndReason.CRASHED
	result.did_reach_orbit = false
	result.final_elements = null
	result.working_instrument_count = 0
	result.science_coverage_fraction = 0.0
	result.data_delivered_megabits = 0.0
	result.reserve_delta_v_meters_per_second = 0.0
	quests.append(_quest("reserve_delta_v_at_least", 300.0))
	score = Scoring.compute_score(_mission, _science, quests, RocketDesign.new(), 100.0, 45.0, result)
	report.check_close(score.total_points, -55.0, 0.000001, "negative totals remain the sum of their components")
	report.check(score.band_name == "Failure", "negative totals use Failure band")

func _check_bands(report: TestReport) -> void:
	for example in [[-20.0, "Failure"], [49.999, "Failure"], [50.0, "Partial Success"], [69.999, "Partial Success"], [70.0, "Success"], [89.999, "Success"], [90.0, "Great Success"], [99.999, "Great Success"], [100.0, "Perfect"], [100.001, "Scientific Breakthrough"]]:
		report.check(Scoring.band_name_for_points(example[0]) == example[1], "band boundary %s" % example[0])

func _check_data_and_screens(report: TestReport) -> void:
	report.check(GameData.all_missions().size() >= 2, "catalogue offers at least two missions")
	for mission in GameData.all_missions():
		for required_key in ["id", "name", "briefing", "body_id", "launch_site", "launch_loss_meters_per_second", "target", "duration_seconds", "budget_million_usd", "display", "science_missions", "side_quests", "hazard_zones", "hazard_rates", "ground_stations"]:
			report.check(mission.has(required_key), "mission has required key " + required_key)
		report.check(not GameData.body(mission.get("body_id", "")).is_empty(), "mission body reference resolves")
		var has_minimum_reserve := false
		var has_maximum_reserve := false
		for quest: Dictionary in mission.get("side_quests", []):
			var condition_type: String = quest.get("condition", {}).get("type", "")
			has_minimum_reserve = has_minimum_reserve or condition_type == "reserve_delta_v_at_least"
			has_maximum_reserve = has_maximum_reserve or condition_type == "reserve_delta_v_at_most"
			report.check(condition_type in ["reserve_delta_v_at_least", "reserve_delta_v_at_most"], "quest uses supported condition")
		report.check(not (has_minimum_reserve and has_maximum_reserve), "incompatible reserve quests live on separate missions")
		for zone: Dictionary in mission.get("hazard_zones", []):
			for event_id: String in zone.get("event_type_ids", []):
				report.check(not GameData.event_type(event_id).is_empty(), "hazard event reference resolves")
		for science: Dictionary in mission.get("science_missions", []):
			var zone: Dictionary = science.get("zone", {})
			report.check(float(zone.get("inner_altitude_kilometers", 0.0)) < float(zone.get("outer_altitude_kilometers", 0.0)), "science band has ordered bounds")
	var screen: Control = load("res://scenes/MissionSelect.tscn").instantiate()
	GameState.add_child(screen)
	report.check(screen._accept_button.disabled, "acceptance requires explicit selection")
	screen._on_mission_chosen(GameData.all_missions()[0])
	for child in screen._details_contents.get_children():
		if child is CheckBox and not child.disabled:
			child.button_pressed = true
			break
	report.check(not screen._accept_button.disabled, "mission plus science enables acceptance")
	screen._on_quest_toggled(true, "keep_reserve_placeholder")
	screen._on_mission_chosen(GameData.all_missions()[1])
	for child in screen._details_contents.get_children():
		if child is CheckBox and child.text == "Space weather":
			report.check(not child.disabled, "space weather is available now that instruments are rated for it")
	# The same screen with no instrument rated for space weather (T09 changed this check:
	# the catalogue now rates two science parts for it, so the old fixture is made here).
	var saved_space_weather_ratings: Dictionary = {}
	for science_part: Dictionary in GameData.parts_in_category(GameData.CATEGORY_SCIENCE):
		saved_space_weather_ratings[science_part["id"]] = science_part["mission_fit"].get("space_weather", 0)
		science_part["mission_fit"]["space_weather"] = 0
	screen._on_mission_chosen(GameData.all_missions()[1])
	for child in screen._details_contents.get_children():
		if child is CheckBox and child.text == "Space weather":
			report.check(child.disabled, "unsupported science is visible and unavailable")
	for science_part: Dictionary in GameData.parts_in_category(GameData.CATEGORY_SCIENCE):
		science_part["mission_fit"]["space_weather"] = saved_space_weather_ratings[science_part["id"]]
	report.check(screen._chosen_science_id.is_empty() and screen._chosen_quest_ids.is_empty() and screen._accept_button.disabled, "changing mission clears dependent choices")
	report.check(GameState.mission.is_empty(), "selection preview does not commit game state")
	screen.free()
	var saved_score: ScoreReport = GameState.score
	var saved_result: FlightResult = GameState.flight_result
	var demo: Control = load("res://scenes/development/T04_demo.tscn").instantiate()
	GameState.add_child(demo)
	for scenario_index in 7:
		demo._show_scenario(scenario_index)
		report.check(demo.get_child_count() == 2, "demo scenario %d replaces its report and keeps selector" % scenario_index)
	demo.free()
	GameState.score = saved_score
	GameState.flight_result = saved_result


func _check_final_screen_portraits(report: TestReport) -> void:
	var expected_poses := {
		"Partial Success": "amit_explaining", "Success": "amit_happy", "Great Success": "amit_greatsuccess",
		"Perfect": "amit_greatsuccess", "Scientific Breakthrough": "amit_greatsuccess",
	}
	for band_name in expected_poses:
		for coin in [0, 1]:
			report.check(FINAL_SCREEN_SCRIPT.portrait_name(band_name, coin) == expected_poses[band_name], "%s uses %s" % [band_name, expected_poses[band_name]])
	report.check(FINAL_SCREEN_SCRIPT.portrait_name("Failure", 0) == "amit_concerned", "Failure coin heads uses amit_concerned")
	report.check(FINAL_SCREEN_SCRIPT.portrait_name("Failure", 1) == "amit_judging", "Failure coin tails uses amit_judging")
	var saved_score: ScoreReport = GameState.score
	for band_name in ["Failure", "Partial Success", "Success", "Great Success", "Perfect", "Scientific Breakthrough"]:
		var score := ScoreReport.new()
		score.band_name = band_name
		GameState.score = score
		var screen: Control = FINAL_SCREEN_SCENE.instantiate()
		GameState.add_child(screen)
		var portrait := FINAL_SCREEN_SCRIPT.portrait_texture(band_name)
		report.check(portrait.atlas != null and portrait.atlas.resource_path.begins_with("res://assets/art/portraits/amit_"), "%s portrait is Amit's art" % band_name)
		var background: TextureRect = screen.find_child("EndScreenBackground", true, false)
		var expected_background: String = "res://assets/art/screens/end/final_%s.png" % band_name.to_lower().replace(" ", "_")
		report.check(background != null and background.texture != null and background.texture.resource_path == expected_background,
				"%s final screen loads its own background %s" % [band_name, expected_background])
		var bubble: Control = screen.find_child("SpeechBubble", true, false)
		if bubble != null:
			report.check(FINAL_SCREEN_SCRIPT.AMIT_BOX_INSIDE.encloses(Rect2(bubble.position, bubble.size)), "%s speech bubble is inside the AMIT box" % band_name)
		var portrait_rect: TextureRect = screen.find_child("Portrait", true, false)
		report.check(portrait_rect != null and FINAL_SCREEN_SCRIPT.AMIT_BOX_INSIDE.encloses(Rect2(portrait_rect.position, portrait_rect.size)),
				"%s portrait is inside the AMIT box" % band_name)
		var bubble_label: Label = screen.find_child("SpeechBubbleLabel", true, false)
		if band_name == "Great Success":
			report.check(bubble_label != null and bubble_label.text == "Great Success!!", "Great Success final screen says Great Success!!")
		elif band_name == "Perfect":
			report.check(bubble_label != null and bubble_label.text == "I Like It - Perfect", "Perfect final screen says I Like It - Perfect")
		elif band_name == "Scientific Breakthrough":
			report.check(bubble_label != null and bubble_label.text == "I Like It - Breakthrough", "Scientific Breakthrough final screen says I Like It - Breakthrough")
		else:
			report.check(bubble_label == null, "%s final screen has no speech bubble" % band_name)
		var fireworks: Node = screen.find_child("Fireworks", true, false)
		if band_name == "Scientific Breakthrough":
			report.check(fireworks != null, "Scientific Breakthrough final screen shows fireworks")
		else:
			report.check(fireworks == null, "%s final screen has no fireworks" % band_name)
		GameState.remove_child(screen)
		screen.free()
	report.check(FINAL_SCREEN_SCRIPT.background_path("Unknown band") == "res://assets/art/screens/end/final_failure.png", "an unknown band falls back to the Failure background")
	GameState.score = saved_score
