extends Control
## Visual fixture: choose a scenario without launching or changing catalogue data.
const SCENARIOS := ["Normal result", "Fractional score", "Failed grants", "Launch failure", "Long event log", "Orbit lost", "Unscored"]
var _screen: Control
var _selector: OptionButton

func _ready() -> void:
	theme = MissionPresentation.create_theme()
	_show_scenario(0)
	_selector = OptionButton.new()
	_selector.position = Vector2(12, 354)
	_selector.size = Vector2(380, 34)
	for scenario in SCENARIOS:
		_selector.add_item("DEMO / " + scenario)
	_selector.item_selected.connect(_show_scenario)
	add_child(_selector)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-directory="):
			_capture_scenarios.call_deferred(argument.trim_prefix("--capture-directory="))

func _show_scenario(scenario_index: int) -> void:
	if _selector != null:
		_selector.select(scenario_index)
	if _screen != null:
		remove_child(_screen)
		_screen.queue_free()
	var mission: Dictionary = GameData.all_missions()[0]
	var science: Dictionary = mission["science_missions"][0]
	var design := RocketDesign.new()
	design.payload_part_ids.append("science_camera_basic")
	var result := FlightResult.new()
	result.final_elements = OrbitElements.new()
	result.final_elements.semi_major_axis_meters = float(GameData.body(mission["body_id"])["radius_meters"]) + 1000.0 * float(mission["target"]["altitude_kilometers"])
	result.final_elements.periapsis_radius_meters = result.final_elements.semi_major_axis_meters
	result.did_reach_orbit = true
	result.flight_duration_seconds = float(mission["duration_seconds"])
	result.science_coverage_fraction = 1.0
	result.data_delivered_megabits = 5000.0
	result.data_generated_megabits = 5000.0
	result.installed_instrument_count = 1
	result.working_instrument_count = 1
	result.reserve_delta_v_meters_per_second = 150.0
	var quests: Array[Dictionary] = []
	var cost_million_usd := 27.0
	var budget_million_usd := 30.0
	match scenario_index:
		1:
			result.final_elements.semi_major_axis_meters += 50000.0
			result.science_coverage_fraction = 0.35
			result.data_delivered_megabits = 1234.0
		2:
			result.reserve_delta_v_meters_per_second = 0.0
			quests.append(mission["side_quests"][0].duplicate(true))
			var second_quest: Dictionary = quests[0].duplicate(true)
			second_quest["id"] = "demo_second_reserve"
			second_quest["name"] = "Demo / larger reserve"
			second_quest["condition"]["delta_v_meters_per_second"] = 200.0
			quests.append(second_quest)
			cost_million_usd = 35.0
			budget_million_usd = 40.0
		3:
			result.end_reason = FlightResult.EndReason.LAUNCH_FAILURE
			result.final_elements = null
			result.did_reach_orbit = false
		4:
			for event_index in 30:
				result.event_log.append({"event_type_id": "satellite_conjunction", "time_seconds": 600.0 + event_index * 120.0,
					"did_player_react": event_index % 2 == 0, "delta_v_spent_meters_per_second": 2.5 if event_index % 2 == 0 else 0.0,
					"outcome": "Avoided" if event_index % 2 == 0 else "Passed safely",
					"explanation": "Demo event %d: the basic radar provided 40 seconds of warning; this entry demonstrates wrapping and log scrolling." % (event_index + 1)})
		5:
			result.end_reason = FlightResult.EndReason.CRASHED
			result.did_reach_orbit = false
			result.final_elements.eccentricity = 0.2
	GameState.flight_result = result
	GameState.score = Scoring.compute_score(mission, science, quests, design, cost_million_usd, budget_million_usd, result)
	if scenario_index == 6:
		GameState.score = null
		GameState.flight_result = null
	_screen = load("res://scenes/FinalScreen.tscn").instantiate()
	add_child(_screen)
	move_child(_screen, 0)

func _capture_scenarios(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	for scenario_index in SCENARIOS.size():
		_show_scenario(scenario_index)
		await _capture_image(directory.path_join("result_%d.png" % scenario_index))
		if scenario_index == 4:
			_screen._score_contents.get_parent().get_parent().hide()
			_screen._event_contents.get_parent().get_parent().show()
			await _capture_image(directory.path_join("events.png"))
			_screen._event_contents.get_parent().scroll_vertical = 100000
			await _capture_image(directory.path_join("events_bottom.png"))
	remove_child(_screen)
	_screen.queue_free()
	_screen = load("res://scenes/MissionSelect.tscn").instantiate()
	add_child(_screen)
	await _capture_image(directory.path_join("mission_empty.png"))
	for mission_index in GameData.all_missions().size():
		_screen._on_mission_chosen(GameData.all_missions()[mission_index])
		for child in _screen._details_contents.get_children():
			if child is CheckBox and not child.disabled:
				child.button_pressed = true
				break
		await _capture_image(directory.path_join("mission_%d.png" % mission_index))
		_screen._details_contents.get_parent().scroll_vertical = 100000
		await _capture_image(directory.path_join("mission_%d_bottom.png" % mission_index))
	print("T04 visual captures saved to ", directory)
	get_tree().quit()

func _capture_image(path: String) -> void:
	# Let containers finish sorting before inspecting the rendered viewport.
	for frame_index in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save visual capture: " + path)
