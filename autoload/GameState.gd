extends Node
## The one place that holds what the player has chosen so far, and the only
## way screens talk to each other.
##
## How to use it from a screen:
##   1. Change GameState.design or GameState.plan directly.
##   2. Call notify_design_changed() or notify_plan_changed().
##   3. Listen to derived_changed and redraw from GameState.summary and
##      GameState.trajectory.
## Owned by the integrator.

## A mission, science mission or side quest was chosen.
signal mission_changed
## summary and trajectory were recomputed. Redraw anything that shows them.
signal derived_changed
## The player pressed Launch. Console starts the flight.
signal launch_requested
## The flight is over and the score is ready.
signal flight_finished(score: ScoreReport)

const MAIN_MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"
const MISSION_SELECT_SCENE_PATH := "res://scenes/MissionSelect.tscn"
const CONSOLE_SCENE_PATH := "res://scenes/Console.tscn"
const FINAL_SCREEN_SCENE_PATH := "res://scenes/FinalScreen.tscn"

## The chosen entry of data/missions.json. Empty until a mission is selected.
var mission: Dictionary = {}
var science_mission_id: String = ""
var side_quest_ids: Array[String] = []
## The mission's budget plus the grants of the accepted side quests.
var budget_million_usd: float = 0.0
var design: RocketDesign = RocketDesign.new()
var plan: MissionPlan = MissionPlan.new()
## Recomputed by recompute_derived. Null until a mission is selected.
var summary: PlanSummary
var trajectory: Trajectory
var has_launched: bool = false
var flight_result: FlightResult
var score: ScoreReport
## Seed for all random events, so that a flight can be repeated exactly.
var random_seed: int = 0


func start_new_game() -> void:
	mission = {}
	science_mission_id = ""
	side_quest_ids = []
	budget_million_usd = 0.0
	design = RocketDesign.new()
	plan = MissionPlan.new()
	summary = null
	trajectory = null
	has_launched = false
	flight_result = null
	score = null
	random_seed = randi()


func select_mission(
		mission_id: String,
		chosen_science_mission_id: String,
		chosen_side_quest_ids: Array[String]) -> void:
	mission = GameData.mission(mission_id)
	science_mission_id = chosen_science_mission_id
	side_quest_ids = chosen_side_quest_ids.duplicate()

	budget_million_usd = mission.get("budget_million_usd", 0.0)
	for side_quest in accepted_side_quests():
		var grant_million_usd: float = side_quest.get("grant_million_usd", 0.0)
		budget_million_usd += grant_million_usd

	mission_changed.emit()
	recompute_derived()


## The chosen entry of the mission's "science_missions" list, or an empty Dictionary.
func science_mission() -> Dictionary:
	var science_missions: Array = mission.get("science_missions", [])
	for candidate: Dictionary in science_missions:
		if candidate.get("id", "") == science_mission_id:
			return candidate
	return {}


## The accepted entries of the mission's "side_quests" list.
func accepted_side_quests() -> Array[Dictionary]:
	var accepted: Array[Dictionary] = []
	var all_side_quests: Array = mission.get("side_quests", [])
	for candidate: Dictionary in all_side_quests:
		if side_quest_ids.has(candidate.get("id", "")):
			accepted.append(candidate)
	return accepted


## Call after changing GameState.design.
func notify_design_changed() -> void:
	recompute_derived()


## Call after changing GameState.plan.
func notify_plan_changed() -> void:
	recompute_derived()


func recompute_derived() -> void:
	if mission.is_empty():
		return
	var resolved_plan: ResolvedPlan = PlanResolver.resolve(design, plan, mission)
	summary = resolved_plan.summary
	trajectory = resolved_plan.trajectory
	derived_changed.emit()


## Call when the player presses Launch.
func request_launch() -> void:
	has_launched = true
	launch_requested.emit()


## Called by Console when FlightSimulation reports the end of the flight.
func finish_flight(result: FlightResult) -> void:
	flight_result = result
	var cost_million_usd: float = 0.0
	if summary != null:
		cost_million_usd = summary.cost_million_usd
	score = Scoring.compute_score(
			mission,
			science_mission(),
			accepted_side_quests(),
			design,
			cost_million_usd,
			budget_million_usd,
			result)
	flight_finished.emit(score)


## Switches to another top-level scene at the end of the current frame.
func go_to_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(scene_path)
