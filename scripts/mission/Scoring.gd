class_name Scoring
extends RefCounted
## Turns the result of a flight into points and an explanation per line.
## The rules are in context/plan_draft.md, section "Scoring".
##
## STUB(T04): the signatures are final. The bodies award a flat score so that
## the final screen has something to show before task T04 is done.

const STUB_ORBIT_POINTS := 50.0
const STUB_BUDGET_POINTS := 25.0


## The complete score for one flight.
## science_mission and side_quests are the chosen entries from the mission.
## budget_million_usd already includes the grants of the accepted side quests.
## STUB(T04): 50 points for reaching orbit plus the stub budget points.
static func compute_score(
		_mission: Dictionary,
		_science_mission: Dictionary,
		_side_quests: Array[Dictionary],
		_design: RocketDesign,
		cost_million_usd: float,
		budget_million_usd: float,
		flight_result: FlightResult) -> ScoreReport:
	var report := ScoreReport.new()
	if flight_result.end_reason == FlightResult.EndReason.LAUNCH_FAILURE:
		report.is_launch_failure = true
		report.total_points = 0.0
		report.band_name = "Failure"
		return report

	var orbit_points: float = STUB_ORBIT_POINTS if flight_result.did_reach_orbit else 0.0
	report.lines.append(ScoreLine.create(
			"Mission", "Orbit achieved", orbit_points, STUB_ORBIT_POINTS,
			"Stub scoring: full points for ending on a closed orbit."))
	var points_for_budget: float = budget_points(cost_million_usd, budget_million_usd)
	report.lines.append(ScoreLine.create(
			"Budget", "Within budget", points_for_budget, 30.0,
			"Stub scoring: a fixed number of points."))

	for line in report.lines:
		report.total_points += line.points
	report.band_name = band_name_for_points(report.total_points)
	return report


## Points for the budget part alone, so the cost chip can show the projected
## penalty while the player is still designing. Can be negative when over budget.
## STUB(T04): returns a fixed number.
static func budget_points(_cost_million_usd: float, _budget_million_usd: float) -> float:
	return STUB_BUDGET_POINTS


## The name of the score band that the given total falls in.
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
