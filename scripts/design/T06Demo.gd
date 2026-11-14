extends Control
## Development scene for T06: selects the first mission with its first science
## mission and shows PlanningConsole.tscn alone, without the console shell.
##
## Run it from the editor to try the planning screens by hand.
## For rendered pictures of every screen, run it with a window (not --headless):
##     godot res://scenes/development/T06_demo.tscn -- --capture-directory=<absolute folder>
## It saves one PNG per screen into the folder and exits.

const PLANNING_CONSOLE_SCENE := preload("res://scenes/PlanningConsole.tscn")
const LEFT_TO_RIGHT_LOCALE := "en"
const CAPTURE_ARGUMENT_PREFIX := "--capture-directory="
## A solid motor, a liquid engine without and then with a tank, and two payload parts.
const CAPTURE_ENGINE_PART_IDS: Array[String] = ["engine_solid_booster", "engine_liquid_small"]
const CAPTURE_TANK_PART_ID := "tank_aluminium_blowdown"
const CAPTURE_PAYLOAD_PART_IDS: Array[String] = ["telemetry_altimeter_basic", "science_camera_basic"]

var _planning_console: Control


func _ready() -> void:
	# Godot mirrors a Control that is placed before it enters the scene tree
	# when the language of the computer is written right to left, which leaves
	# every screen empty. Until project.godot fixes the layout direction
	# (requested in tasks/notes/T06.md), the demo runs in an English locale.
	TranslationServer.set_locale(LEFT_TO_RIGHT_LOCALE)
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	size = ScreenLayout.SCREEN_SIZE
	var first_mission: Dictionary = GameData.all_missions()[0]
	var science_missions: Array = first_mission.get("science_missions", [])
	var first_science_mission_id: String = ""
	if not science_missions.is_empty():
		first_science_mission_id = science_missions[0].get("id", "")
	var no_side_quest_ids: Array[String] = []

	GameState.start_new_game()
	GameState.select_mission(first_mission["id"], first_science_mission_id, no_side_quest_ids)

	_planning_console = PLANNING_CONSOLE_SCENE.instantiate()
	add_child(_planning_console)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(CAPTURE_ARGUMENT_PREFIX):
			_capture_screens.call_deferred(argument.trim_prefix(CAPTURE_ARGUMENT_PREFIX))


func _capture_screens(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	_planning_console.zoom_duration_seconds = 0.0
	var rocket_design_screen: Control = _planning_console.rocket_design_screen

	await _capture_image(directory.path_join("overview_empty.png"))

	_planning_console.zoom_into_rocket_design()
	await _capture_image(directory.path_join("rocket_design_empty.png"))

	for engine_part_id in CAPTURE_ENGINE_PART_IDS:
		rocket_design_screen.install_part(engine_part_id)
	await _capture_image(directory.path_join("rocket_design_missing_tank.png"))

	rocket_design_screen.install_part(CAPTURE_TANK_PART_ID)
	for payload_part_id in CAPTURE_PAYLOAD_PART_IDS:
		rocket_design_screen.install_part(payload_part_id)
	rocket_design_screen.show_category(GameData.CATEGORY_SCIENCE)
	await _capture_image(directory.path_join("rocket_design_built.png"))

	var science_card: PartCard = rocket_design_screen.find_part_card(CAPTURE_PAYLOAD_PART_IDS[1])
	science_card.card_hovered.emit(science_card.part_id)
	await _capture_image(directory.path_join("rocket_design_popup_science.png"))
	science_card.card_unhovered.emit()

	rocket_design_screen.show_category(GameData.CATEGORY_ENGINE)
	var engine_card: PartCard = rocket_design_screen.find_part_card(CAPTURE_ENGINE_PART_IDS[0])
	engine_card.card_hovered.emit(engine_card.part_id)
	await _capture_image(directory.path_join("rocket_design_popup_engine.png"))
	engine_card.card_unhovered.emit()

	_planning_console.zoom_back_to_overview()
	await _capture_image(directory.path_join("overview_built.png"))

	# Enough copies of the most expensive science part to go over budget.
	for copy_index in 4:
		rocket_design_screen.install_part("science_imaging_radar")
	await _capture_image(directory.path_join("overview_over_budget.png"))

	_planning_console._on_build_example_rocket_pressed()
	await _capture_image(directory.path_join("overview_example_rocket.png"))

	_planning_console.zoom_into_orbit_planning()
	await _capture_image(directory.path_join("orbit_planning.png"))

	print("T06 visual captures saved to ", directory)
	get_tree().quit()


func _capture_image(path: String) -> void:
	# Let containers finish sorting before the viewport is read.
	for frame_index in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save visual capture: " + path)
