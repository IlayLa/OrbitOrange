extends Control
## Saves a PNG of each screen touched by the layout and readability fixes of
## the 15 November review, for before and after comparison. Not a test.
##
## Run with a window and an English locale (see capture_screens.gd):
##     godot --path <project> --language en res://tests/playtest/CaptureLayout.tscn -- --capture-directory=<absolute folder>

const CAPTURE_ARGUMENT_PREFIX := "--capture-directory="

var _directory: String = "user://layout_screens"
var _screen: Node


func _ready() -> void:
	TranslationServer.set_locale("en")
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	size = ScreenLayout.SCREEN_SIZE
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(CAPTURE_ARGUMENT_PREFIX):
			_directory = argument.trim_prefix(CAPTURE_ARGUMENT_PREFIX)
	_capture_all.call_deferred()


func _capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(_directory)
	var missions: Array = GameData.all_missions()

	# Mission select: the second mission (long names, two science entries),
	# then a $100M mission with its quest ticked (widest budget line).
	GameState.start_new_game()
	_show("res://scenes/MissionSelect.tscn")
	_screen._on_mission_chosen(missions[1])
	for card in _screen._details_contents.get_children():
		if card is ChoiceCard and not card.disabled:
			card.button_pressed = true
			break
	for card in _screen._quest_contents.get_children():
		if card is ChoiceCard:
			card.button_pressed = true
	await _capture("mission_select_second")
	var rich_mission: Dictionary = missions[0].duplicate(true)
	rich_mission["budget_million_usd"] = 100.0
	var extra_quest: Dictionary = rich_mission["side_quests"][0].duplicate(true)
	extra_quest["id"] = "extra_quest_for_capture"
	extra_quest["name"] = "A second quest with a long name"
	rich_mission["side_quests"].append(extra_quest)
	rich_mission["side_quests"].append(extra_quest.duplicate(true))
	rich_mission["side_quests"][2]["id"] = "third_quest_for_capture"
	rich_mission["science_missions"].append(missions[1]["science_missions"][1].duplicate(true))
	rich_mission["science_missions"].append(missions[1]["science_missions"][0].duplicate(true))
	_screen._on_mission_chosen(rich_mission)
	for card in _screen._quest_contents.get_children():
		if card is ChoiceCard:
			card.button_pressed = true
	await _capture("mission_select_overflow")

	# Planning: an empty rocket (empty preview, blocking message), then the
	# reference flight on the overview and in the orbit planning view.
	var no_quest_ids: Array[String] = []
	GameState.start_new_game()
	GameState.select_mission(missions[0]["id"], missions[0]["science_missions"][0]["id"], no_quest_ids)
	_show("res://scenes/PlanningConsole.tscn")
	var console: Control = _screen
	console.zoom_duration_seconds = 0.0
	await _capture("planning_empty")
	console.zoom_into_rocket_design()
	await _capture("rocket_design_empty")
	console.zoom_back_to_overview()
	ExampleFlight.fill_reference_flight(GameState.design, GameState.plan, GameState.mission)
	GameState.notify_design_changed()
	GameState.notify_plan_changed()
	await _capture("planning_reference")
	console.zoom_into_orbit_planning()
	await _capture("orbit_planning_reference")
	# Without the circularising pulse the orbit is elliptic: P and A labels.
	GameState.plan.pulses.clear()
	GameState.notify_plan_changed()
	await _capture("orbit_planning_elliptic")
	console.zoom_back_to_overview()

	_show("res://scenes/ExecutionConsole.tscn")
	await _capture("execution_console")

	# Final screen: a normal result, Breakthrough, and Failure with no flight data.
	_prepare_sample_result()
	_show("res://scenes/FinalScreen.tscn")
	await _capture("final_screen")
	GameState.score.band_name = "Scientific Breakthrough"
	_show("res://scenes/FinalScreen.tscn")
	for frame_index in 8:
		await get_tree().process_frame
	await _capture("final_screen_breakthrough")
	GameState.score.band_name = "Failure"
	GameState.flight_result = null
	_show("res://scenes/FinalScreen.tscn")
	await _capture("final_screen_failure_no_data")

	print("Screens saved to ", ProjectSettings.globalize_path(_directory))
	get_tree().quit()


func _prepare_sample_result() -> void:
	var mission: Dictionary = GameData.all_missions()[0]
	var science: Dictionary = mission["science_missions"][0]
	var quest_ids: Array[String] = [mission["side_quests"][0]["id"]]
	GameState.start_new_game()
	GameState.select_mission(mission["id"], science["id"], quest_ids)
	var body_radius_meters: float = GameData.body(mission["body_id"])["radius_meters"]
	var result := FlightResult.new()
	result.final_elements = OrbitElements.new()
	result.final_elements.semi_major_axis_meters = body_radius_meters + 1000.0 * (float(mission["target"]["altitude_kilometers"]) + 42.0)
	result.final_elements.eccentricity = 0.03
	result.final_elements.argument_of_periapsis_radians = 0.6
	result.final_elements.periapsis_radius_meters = result.final_elements.semi_major_axis_meters * 0.97
	result.final_elements.apoapsis_radius_meters = result.final_elements.semi_major_axis_meters * 1.03
	result.did_reach_orbit = true
	result.flight_duration_seconds = float(mission["duration_seconds"])
	result.science_coverage_fraction = 0.55
	result.data_delivered_megabits = 3100.0
	result.data_generated_megabits = 3600.0
	result.installed_instrument_count = 2
	result.working_instrument_count = 2
	result.reserve_delta_v_meters_per_second = 60.0
	result.event_log.append({"event_type_id": "satellite_conjunction", "time_seconds": 2600.0,
		"did_player_react": true, "delta_v_spent_meters_per_second": 3.0, "outcome": "Avoided",
		"explanation": "Sample event."})
	var design := RocketDesign.new()
	design.payload_part_ids.append("science_camera_basic")
	GameState.flight_result = result
	GameState.score = Scoring.compute_score(mission, science, GameState.accepted_side_quests(), design, 31.5,
			GameState.budget_million_usd, result)


func _show(scene_path: String) -> void:
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	_screen = load(scene_path).instantiate()
	add_child(_screen)


func _capture(file_name: String) -> void:
	for frame_index in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = _directory.path_join(file_name + ".png")
	if get_viewport().get_texture().get_image().save_png(path) != OK:
		push_error("Could not save capture: " + path)
