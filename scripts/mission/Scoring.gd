class_name Scoring
extends RefCounted
## Pure scoring rules; catalogue entries are read through GameData.

## Returns a score report; the supplied budget already includes accepted grants.
static func compute_score(mission: Dictionary, science_mission: Dictionary,
		side_quests: Array[Dictionary], design: RocketDesign,
		cost_million_usd: float, budget_million_usd: float,
		flight_result: FlightResult) -> ScoreReport:
	var report := ScoreReport.new()
	if flight_result.end_reason == FlightResult.EndReason.LAUNCH_FAILURE:
		report.is_launch_failure = true
		report.band_name = "Failure"
		return report
	var failed_count := 0
	var reclaimed_million_usd := 0.0
	var quest_lines: Array[ScoreLine] = []
	for quest in side_quests:
		var condition: Dictionary = quest.get("condition", {})
		var threshold_meters_per_second: float = condition.get("delta_v_meters_per_second", 0.0)
		var reserve_meters_per_second := flight_result.reserve_delta_v_meters_per_second
		var succeeded := false
		var requirement := "an unsupported condition"
		match condition.get("type", ""):
			"reserve_delta_v_at_least":
				succeeded = reserve_meters_per_second >= threshold_meters_per_second
				requirement = "at least %.2f m/s" % threshold_meters_per_second
			"reserve_delta_v_at_most":
				succeeded = reserve_meters_per_second <= threshold_meters_per_second
				requirement = "at most %.2f m/s" % threshold_meters_per_second
		if not succeeded:
			failed_count += 1
			reclaimed_million_usd += float(quest.get("grant_million_usd", 0.0))
		quest_lines.append(ScoreLine.create("Side quests", quest.get("name", "Quest"),
				20.0 if succeeded else 0.0, 20.0,
				"Reserve %.2f m/s %s the requirement of %s; grant %.2f million USD %s." % [
				reserve_meters_per_second, "meets" if succeeded else "fails", requirement,
				float(quest.get("grant_million_usd", 0.0)), "retained" if succeeded else "reclaimed"]))
	var elements := flight_result.final_elements
	var has_closed_elements := elements != null and not elements.is_open
	if has_closed_elements:
		has_closed_elements = is_finite(elements.semi_major_axis_meters) and elements.semi_major_axis_meters > 0.0
	var body := GameData.body(mission.get("body_id", ""))
	var target: Dictionary = mission.get("target", {})
	var altitude_points := 0.0
	var shape_points := 0.0
	var altitude_explanation := "Final closed-orbit altitude is unavailable; altitude accuracy earns 0 points."
	var shape_explanation := "Final closed-orbit eccentricity is unavailable; shape accuracy earns 0 points."
	if has_closed_elements and body.has("radius_meters") and not target.is_empty():
		var actual_altitude_kilometers: float = (elements.semi_major_axis_meters - float(body["radius_meters"])) / 1000.0
		var desired_altitude_kilometers: float = target.get("altitude_kilometers", 0.0)
		var tolerance_kilometers: float = target.get("altitude_tolerance_kilometers", 0.0)
		altitude_points = 15.0 * _accuracy_fraction(actual_altitude_kilometers, desired_altitude_kilometers, tolerance_kilometers)
		var desired_eccentricity: float = target.get("eccentricity", 0.0)
		var eccentricity_tolerance: float = target.get("eccentricity_tolerance", 0.0)
		shape_points = 10.0 * _accuracy_fraction(elements.eccentricity, desired_eccentricity, eccentricity_tolerance)
		altitude_explanation = "Semi-major-axis altitude %.2f km targets %.2f km with %.2f km tolerance." % [actual_altitude_kilometers, desired_altitude_kilometers, tolerance_kilometers]
		shape_explanation = "Eccentricity %.4f targets %.4f with %.4f tolerance." % [elements.eccentricity, desired_eccentricity, eccentricity_tolerance]
	var installed_instrument_count := maxi(0, flight_result.installed_instrument_count)
	var working_instrument_count := clampi(flight_result.working_instrument_count, 0, installed_instrument_count)
	var health_points := 5.0 if installed_instrument_count == 0 else 5.0 * float(working_instrument_count) / installed_instrument_count
	report.lines.append(ScoreLine.create("Mission", "Orbit achieved", 20.0 if flight_result.did_reach_orbit else 0.0, 20.0,
			"The final safe-orbit result is %s after %.1f seconds of flight." % ["achieved" if flight_result.did_reach_orbit else "unachieved", flight_result.flight_duration_seconds]))
	report.lines.append(ScoreLine.create("Mission", "Altitude accuracy", altitude_points, 15.0, altitude_explanation))
	report.lines.append(ScoreLine.create("Mission", "Orbit shape", shape_points, 10.0, shape_explanation))
	report.lines.append(ScoreLine.create("Mission", "Vehicle health", health_points, 5.0,
			"All 5 health points apply with 0 installed instruments." if installed_instrument_count == 0 else "%d of %d installed instruments are working." % [working_instrument_count, installed_instrument_count]))
	var effective_budget_million_usd := budget_million_usd - reclaimed_million_usd
	var components := _budget_components(cost_million_usd, effective_budget_million_usd)
	report.lines.append(ScoreLine.create("Budget", "Within budget", components[0], 25.0,
			"Cost %.2f million USD is compared with %.2f million USD after reclaiming %.2f million USD in failed grants." % [cost_million_usd, effective_budget_million_usd, reclaimed_million_usd]))
	report.lines.append(ScoreLine.create("Budget", "Margin", components[1], 5.0,
			"Unspent budget is %.2f million USD; full margin points require 10%% of the %.2f million USD budget." % [maxf(0.0, effective_budget_million_usd - cost_million_usd), effective_budget_million_usd]))
	var best_stars := 0.0
	if not science_mission.is_empty():
		for part_id in design.payload_part_ids:
			var part := GameData.part(part_id)
			if part.get("category", "") == GameData.CATEGORY_SCIENCE:
				var mission_fit: Dictionary = part.get("mission_fit", {})
				best_stars = maxf(best_stars, clampf(float(mission_fit.get(science_mission.get("id", ""), 0.0)), 0.0, 3.0))
	var coverage := clampf(flight_result.science_coverage_fraction, 0.0, 1.0) if has_closed_elements else 0.0
	var required_coverage: float = science_mission.get("required_coverage_fraction", 0.0)
	var required_data_megabits: float = science_mission.get("required_data_megabits", 0.0)
	var coverage_points := 0.0 if science_mission.is_empty() or not has_closed_elements else 8.0 * _completion_fraction(coverage, required_coverage)
	var data_points := 0.0 if science_mission.is_empty() else 4.0 * _completion_fraction(flight_result.data_delivered_megabits, required_data_megabits)
	report.lines.append(ScoreLine.create("Science", "Instrument fit", 8.0 * best_stars / 3.0, 8.0,
			"The best carried science instrument has %.1f of 3 fit stars for %s." % [best_stars, science_mission.get("name", "no selected science mission")]))
	report.lines.append(ScoreLine.create("Science", "Coverage", coverage_points, 8.0,
			"Final-orbit coverage is %.2f%% against %.2f%% required." % [100.0 * coverage, 100.0 * required_coverage]))
	report.lines.append(ScoreLine.create("Science", "Data returned", data_points, 4.0,
			"Delivered %.2f of %.2f required megabits; generated %.2f megabits." % [flight_result.data_delivered_megabits, required_data_megabits, flight_result.data_generated_megabits]))
	report.lines.append_array(quest_lines)
	if failed_count > 0:
		# Only penalties through three failures are defined; keep that ceiling.
		var penalties := [0.0, 5.0, 15.0, 30.0]
		var penalty: float = penalties[mini(failed_count, 3)]
		report.lines.append(ScoreLine.create("Side quests", "Failure penalty", -penalty, 0.0,
				"%d failed side quests incur %.0f penalty points in total." % [failed_count, penalty]))
	for line in report.lines:
		report.total_points += line.points
	report.band_name = band_name_for_points(report.total_points)
	return report

## Returns budget points alone, including the saving margin; may be negative.
static func budget_points(cost_million_usd: float, budget_million_usd: float) -> float:
	var components := _budget_components(cost_million_usd, budget_million_usd)
	return components[0] + components[1]

## Returns the band name for the unrounded point total, including negative totals.
static func band_name_for_points(total_points: float) -> String:
	if total_points > 100.0:
		return "Scientific Breakthrough"
	if total_points >= 100.0:
		return "Perfect"
	if total_points >= 90.0:
		return "Great Success"
	if total_points >= 70.0:
		return "Success"
	if total_points >= 50.0:
		return "Partial Success"
	return "Failure"

static func _budget_components(cost_million_usd: float, budget_million_usd: float) -> Array[float]:
	if budget_million_usd <= 0.0:
		return [25.0 if cost_million_usd <= 0.0 else -25.0, 0.0]
	var saving_fraction := (budget_million_usd - cost_million_usd) / budget_million_usd
	return [maxf(-25.0, 25.0 + 100.0 * minf(0.0, saving_fraction)),
			5.0 * clampf(saving_fraction / 0.1, 0.0, 1.0)]

static func _accuracy_fraction(actual: float, desired: float, tolerance: float) -> float:
	if tolerance <= 0.0:
		return 1.0 if actual == desired else 0.0
	return clampf(1.0 - absf(actual - desired) / tolerance, 0.0, 1.0)

static func _completion_fraction(actual: float, required: float) -> float:
	return 1.0 if required <= 0.0 else clampf(actual / required, 0.0, 1.0)
