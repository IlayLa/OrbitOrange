extends Control
## Saves a PNG of every screen changed by the "minimize text walls" redesign,
## for a visual review. Not a test: TestRunner only runs tests/test_*.gd, and
## check_project only runs the scenes in scenes/.
##
## Run with a window (not --headless) and an English locale; on a computer
## whose language is written right to left, Godot otherwise mirrors the
## screens and they render empty:
##     godot --path <project> --language en res://tests/playtest/CaptureScreens.tscn -- --capture-directory=<absolute folder>
## It writes the PNGs into the folder and quits.

const CAPTURE_ARGUMENT_PREFIX := "--capture-directory="
## With this argument only the final screen is captured, once per band.
const ONLY_FINAL_ARGUMENT := "--only-final"
const BAND_NAMES := ["Failure", "Partial Success", "Success", "Great Success", "Perfect", "Scientific Breakthrough"]
const DEFAULT_DIRECTORY := "user://screens"
const LEFT_TO_RIGHT_LOCALE := "en"

var _directory: String = DEFAULT_DIRECTORY
var _screen: Node
var _is_only_final: bool = false


func _ready() -> void:
	TranslationServer.set_locale(LEFT_TO_RIGHT_LOCALE)
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	size = ScreenLayout.SCREEN_SIZE
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(CAPTURE_ARGUMENT_PREFIX):
			_directory = argument.trim_prefix(CAPTURE_ARGUMENT_PREFIX)
		elif argument == ONLY_FINAL_ARGUMENT:
			_is_only_final = true
	_capture_all.call_deferred()


func _capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(_directory)
	if _is_only_final:
		await _capture_final_bands()
		print("Screens saved to ", ProjectSettings.globalize_path(_directory))
		get_tree().quit()
		return

	# Main menu, and the Data Sources codex opened from it.
	_show("res://scenes/MainMenu.tscn")
	await _capture("main_menu")
	_find_codex(_screen).open_at()
	await _capture("main_menu_codex")

	# Mission select: empty, then a mission with its science and a quest.
	GameState.start_new_game()
	_show("res://scenes/MissionSelect.tscn")
	await _capture("mission_select_empty")
	var first_mission: Dictionary = GameData.all_missions()[0]
	_screen._on_mission_chosen(first_mission)
	for card in _screen._details_contents.get_children():
		if card is ChoiceCard and not card.disabled:
			card.button_pressed = true
			break
	for card in _screen._quest_contents.get_children():
		if card is ChoiceCard:
			card.button_pressed = true
	await _capture("mission_select_first")
	_screen._on_mission_chosen(GameData.all_missions()[1])
	for card in _screen._details_contents.get_children():
		if card is ChoiceCard and not card.disabled:
			card.button_pressed = true
			break
	await _capture("mission_select_second")

	# The planning console with the example rocket plus a third, tankless
	# liquid stage: one blocking lamp, and the thrust advice if any.
	var no_quest_ids: Array[String] = []
	GameState.start_new_game()
	GameState.select_mission(first_mission["id"], first_mission["science_missions"][0]["id"], no_quest_ids)
	_show("res://scenes/PlanningConsole.tscn")
	var console: Control = _screen
	console.zoom_duration_seconds = 0.0
	var rocket_design_screen: Control = console.rocket_design_screen
	console.zoom_into_rocket_design()
	await _capture("rocket_design_legend")

	console._on_build_example_rocket_pressed()
	rocket_design_screen.install_part("engine_liquid_hydrogen")
	# Advice from the plan: a pulse that uses a stage that does not exist yet.
	var stray_pulse := Pulse.new()
	stray_pulse.stage_id = 9999
	stray_pulse.delta_v_along_velocity_meters_per_second = 50.0
	GameState.plan.pulses.append(stray_pulse)
	GameState.notify_plan_changed()
	var second_stage: Stage = GameState.design.stages[1]
	rocket_design_screen.select_stage(second_stage.stage_id)
	rocket_design_screen.show_category(GameData.CATEGORY_ENGINE)
	var engine_card: PartCard = rocket_design_screen.find_part_card("engine_liquid_hydrogen")
	engine_card.card_hovered.emit(engine_card.part_id)
	await _capture("rocket_design_popup_engine")
	engine_card.card_unhovered.emit()

	rocket_design_screen.show_category(GameData.CATEGORY_SCIENCE)
	var science_card: PartCard = rocket_design_screen.find_part_card("science_camera_high_resolution")
	science_card.card_hovered.emit(science_card.part_id)
	await _capture("rocket_design_popup_science")
	science_card.card_unhovered.emit()

	var stack_preview: RocketStackPreview = rocket_design_screen.stack_preview
	var lamp_spots: Array[Dictionary] = stack_preview.lamp_spots()
	var blocked_lamp_index := 0
	for lamp_index in lamp_spots.size():
		if lamp_spots[lamp_index]["severity"] == WarningLamps.Severity.BLOCKING:
			blocked_lamp_index = lamp_index
	stack_preview.hover_lamp(blocked_lamp_index)
	rocket_design_screen.toggle_legend()
	await _capture("rocket_design_lamp_and_legend")
	stack_preview.hover_lamp(-1)
	rocket_design_screen.toggle_legend()

	rocket_design_screen.install_part("tank_aluminium_blowdown")
	for extra_payload_index in 12:
		rocket_design_screen.install_part("telemetry_altimeter_basic")
	await _capture("rocket_design_message")

	rocket_design_screen.open_data_sources("engine_liquid_hydrogen")
	await _capture("rocket_design_codex")
	rocket_design_screen._codex.hide()

	console.zoom_back_to_overview()
	GameState.design.stages[2].tank_part_id = ""
	GameState.notify_design_changed()
	await _capture("planning_console_lamps")
	console._lamp_bar.toggle_pin(1)
	await _capture("planning_console_lamp_pinned")

	# Final screen with sample score data, then a launch failure.
	_prepare_sample_result(false)
	_show("res://scenes/FinalScreen.tscn")
	await _capture("final_screen")
	_screen.select_group(0)
	_screen.hover_event(2)
	await _capture("final_screen_bar_detail")
	_screen.hover_event(-1)
	_screen.select_event(4)
	await _capture("final_screen_event_detail")
	_prepare_sample_result(true)
	_show("res://scenes/FinalScreen.tscn")
	await _capture("final_screen_launch_failure")
	await _capture_final_bands()

	print("Screens saved to ", ProjectSettings.globalize_path(_directory))
	get_tree().quit()


## The final screen once per band, from the same sample flight.
func _capture_final_bands() -> void:
	for band_name in BAND_NAMES:
		_prepare_sample_result(false)
		GameState.score.band_name = band_name
		_show("res://scenes/FinalScreen.tscn")
		await _capture("final_band_" + band_name.to_lower().replace(" ", "_"))
	_screen.show_flight_log(true)
	_screen.select_event(3)
	await _capture("final_flight_log")


## A scored flight a little off target, with a failed quest and five events.
func _prepare_sample_result(is_launch_failure: bool) -> void:
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
	var outcomes: Array[Array] = [
		[900.0, true, "Avoided"], [2600.0, false, "Passed safely"], [5200.0, true, "Avoided"],
		[9100.0, false, "Collision damage"], [13000.0, false, "Passed safely"]]
	for outcome in outcomes:
		result.event_log.append({"event_type_id": "satellite_conjunction", "time_seconds": outcome[0],
			"did_player_react": outcome[1], "delta_v_spent_meters_per_second": 3.0 if outcome[1] else 0.0,
			"outcome": outcome[2], "explanation": "Sample event: the basic radar gave 40 seconds of warning."})
	if is_launch_failure:
		result.end_reason = FlightResult.EndReason.LAUNCH_FAILURE
		result.final_elements = null
		result.did_reach_orbit = false
		result.event_log.clear()
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


func _find_codex(parent: Node) -> DataSourcesCodex:
	for child in parent.get_children():
		if child is DataSourcesCodex:
			return child
	return null


func _capture(file_name: String) -> void:
	# Let containers sort and deferred sizes apply before the viewport is read.
	for frame_index in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = _directory.path_join(file_name + ".png")
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save capture: " + path)
