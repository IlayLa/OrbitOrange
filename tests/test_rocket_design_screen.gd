extends RefCounted
## Checks of the planning screens of T06: installing and removing parts through
## the rocket design screen, the stat chips, the Launch button and the zoom.
## The screens are added below GameState so that they are inside the scene
## tree; everything this file changes in GameState and GameData is put back.

const LIQUID_ENGINE_PART_ID := "engine_liquid_small"
const SECOND_LIQUID_ENGINE_PART_ID := "engine_liquid_basic"
const SOLID_ENGINE_PART_ID := "engine_solid_kick"
const TANK_PART_ID := "tank_aluminium_blowdown"
const SCIENCE_PART_ID := "science_camera_basic"
const TELEMETRY_PART_ID := "telemetry_altimeter_basic"
const COSTLY_PART_ID := "t06_test_costly_instrument"
const ROCKET_DESIGN_SCENE_PATH := "res://scenes/planning/RocketDesign.tscn"
const PLANNING_CONSOLE_SCENE_PATH := "res://scenes/PlanningConsole.tscn"
const DEMO_SCENE_PATH := "res://scenes/development/T06_demo.tscn"

## Godot mirrors a Control that is placed before it enters the scene tree when
## the language of the computer is written right to left. The test switches to
## this locale so that positions can be checked on any computer, and puts the
## old locale back. See tasks/notes/T06.md.
const LEFT_TO_RIGHT_LOCALE := "en"

var _saved_state: Dictionary = {}


func run_tests(report: TestReport) -> void:
	_save_game_state()
	_select_first_mission()
	_check_part_texts(report)
	_check_installing_parts(report)
	_check_removing_parts(report)
	_check_removing_a_stage_cleans_the_plan(report)
	_check_tank_rules(report)
	_check_launch_button_and_chips(report)
	_check_zoom(report)
	_check_demo_scene(report)
	_restore_game_state()


func _save_game_state() -> void:
	_saved_state = {
		"mission": GameState.mission,
		"science_mission_id": GameState.science_mission_id,
		"side_quest_ids": GameState.side_quest_ids,
		"budget_million_usd": GameState.budget_million_usd,
		"design": GameState.design,
		"plan": GameState.plan,
		"summary": GameState.summary,
		"trajectory": GameState.trajectory,
		"has_launched": GameState.has_launched,
		"random_seed": GameState.random_seed,
		"flight_result": GameState.flight_result,
		"score": GameState.score,
		"locale": TranslationServer.get_locale(),
	}
	TranslationServer.set_locale(LEFT_TO_RIGHT_LOCALE)


func _restore_game_state() -> void:
	GameState.mission = _saved_state["mission"]
	GameState.science_mission_id = _saved_state["science_mission_id"]
	GameState.side_quest_ids = _saved_state["side_quest_ids"]
	GameState.budget_million_usd = _saved_state["budget_million_usd"]
	GameState.design = _saved_state["design"]
	GameState.plan = _saved_state["plan"]
	GameState.summary = _saved_state["summary"]
	GameState.trajectory = _saved_state["trajectory"]
	GameState.has_launched = _saved_state["has_launched"]
	GameState.random_seed = _saved_state["random_seed"]
	GameState.flight_result = _saved_state["flight_result"]
	GameState.score = _saved_state["score"]
	TranslationServer.set_locale(_saved_state["locale"])


## Starts from an empty design and plan on the first mission of the catalogue.
func _select_first_mission() -> void:
	var first_mission: Dictionary = GameData.all_missions()[0]
	var first_science_mission_id: String = first_mission["science_missions"][0]["id"]
	var no_side_quest_ids: Array[String] = []
	GameState.design = RocketDesign.new()
	GameState.plan = MissionPlan.new()
	GameState.select_mission(first_mission["id"], first_science_mission_id, no_side_quest_ids)


func _create_screen(scene_path: String) -> Control:
	var packed_scene: PackedScene = load(scene_path)
	var screen: Control = packed_scene.instantiate()
	GameState.add_child(screen)
	return screen


func _press_card(rocket_design_screen: Control, category: String, part_id: String) -> bool:
	rocket_design_screen.show_category(category)
	var card: PartCard = rocket_design_screen.find_part_card(part_id)
	if card == null:
		return false
	card.pressed.emit()
	return true


func _check_part_texts(report: TestReport) -> void:
	var solid_engine: Dictionary = GameData.part(SOLID_ENGINE_PART_ID)
	report.check(PartCard.key_number_text(solid_engine) == "Isp 290 s  SOLID", "engine card shows specific impulse and engine type")
	report.check(PartCard.key_number_text(GameData.part(TANK_PART_ID)).begins_with("Fuel "), "tank card shows propellant capacity")
	report.check(PartCard.key_number_text(GameData.part(TELEMETRY_PART_ID)) == "1 updates/s", "telemetry card without a range shows its update rate")
	report.check(PartCard.key_number_text(GameData.part(SCIENCE_PART_ID)) == "Data 1 Mb/s", "science card shows its data rate")
	report.check(PartCard.cost_text(solid_engine) == "$ 1 M", "card shows the cost in million USD")

	report.check(PartDetailsPopup.stat_line("thrust_kilonewtons", 47.0) == "Thrust: 47 kN", "popup takes the unit from the key ending")
	report.check(PartDetailsPopup.stat_line("data_rate_megabits_per_second", 1.5) == "Data Rate: 1.5 Mb/s", "popup prefers the longest matching ending")
	report.check(PartDetailsPopup.stat_line("noise_fraction", 0.05) == "Noise: 5 %", "popup shows a fraction as a percentage")
	report.check(PartDetailsPopup.stat_line("pressurization", "regulated") == "Pressurization: regulated", "popup shows text stats unchanged")

	var solid_engine_lines: Array[String] = PartDetailsPopup.detail_lines(solid_engine)
	report.check(solid_engine_lines.has("Engine type: solid"), "popup names the engine type")
	var solid_engine_stats: Dictionary = solid_engine["stats"]
	# Name, engine type, cost and dry mass, then every stat except the engine type.
	report.check(solid_engine_lines.size() == 4 + solid_engine_stats.size() - 1, "popup lists every stat of the part")
	report.check(PartDetailsPopup.mission_fit_stars(GameData.part(SCIENCE_PART_ID), "earth_imaging") == 2, "popup reads the mission fit of the chosen science mission")
	report.check(PartDetailsPopup.mission_fit_stars(solid_engine, "earth_imaging") == 0, "a part without a rating has no stars")
	report.check(PartDetailsPopup.source_line(solid_engine).begins_with("Source (approximate): "), "popup marks approximate sources")


func _check_installing_parts(report: TestReport) -> void:
	_select_first_mission()
	var screen: Control = _create_screen(ROCKET_DESIGN_SCENE_PATH)
	var chips := StatChips.new()
	chips.configure(ScreenLayout.OVERVIEW_STAT_CHIP_SCREENS, false)
	GameState.add_child(chips)
	chips.refresh(GameState.summary, GameState.budget_million_usd)
	var cost_text_when_empty: String = chips.cost_value_label.text

	report.check(screen.find_part_card(LIQUID_ENGINE_PART_ID) != null, "the engine tab is listed first")
	report.check(
			screen._card_list.get_child_count() == GameData.parts_in_category(GameData.CATEGORY_ENGINE).size(),
			"one card per engine in the catalogue")

	report.check(_press_card(screen, GameData.CATEGORY_ENGINE, LIQUID_ENGINE_PART_ID), "the liquid engine has a card")
	var stages: Array[Stage] = GameState.design.stages
	report.check(stages.size() == 1 and stages[0].engine_part_id == LIQUID_ENGINE_PART_ID, "clicking an engine card adds a stage")
	report.check(screen.selected_stage_id == stages[0].stage_id, "a new liquid stage is selected for the next tank")
	chips.refresh(GameState.summary, GameState.budget_million_usd)
	report.check(chips.cost_value_label.text != cost_text_when_empty, "the cost chip changes when a part is added")
	var weight_text_without_tank: String = chips.weight_value_label.text
	var delta_v_text_without_tank: String = chips.delta_v_value_label.text

	_press_card(screen, GameData.CATEGORY_TANK, TANK_PART_ID)
	report.check(stages[0].tank_part_id == TANK_PART_ID, "clicking a tank card attaches it to the selected liquid stage")
	chips.refresh(GameState.summary, GameState.budget_million_usd)
	report.check(chips.weight_value_label.text != weight_text_without_tank, "the weight chip changes when a tank is added")
	report.check(chips.delta_v_value_label.text != delta_v_text_without_tank, "the delta-v chip changes when a tank is added")
	report.check(
			chips.weight_value_label.text == "%.0f" % GameState.summary.wet_mass_kilograms
			and chips.weight_detail_label.text == "empty %.0f" % GameState.summary.dry_mass_kilograms,
			"the weight chip shows the total and the empty mass of the summary")

	_press_card(screen, GameData.CATEGORY_SCIENCE, SCIENCE_PART_ID)
	_press_card(screen, GameData.CATEGORY_TELEMETRY, TELEMETRY_PART_ID)
	var expected_payload_part_ids: Array[String] = [SCIENCE_PART_ID, TELEMETRY_PART_ID]
	report.check(
			GameState.design.payload_part_ids == expected_payload_part_ids,
			"science and telemetry cards add payload parts")

	var preview: RocketStackPreview = screen.stack_preview
	report.check(preview.blocks_of_kind(RocketStackPreview.BlockKind.ENGINE).size() == 1, "the preview draws the engine")
	report.check(preview.blocks_of_kind(RocketStackPreview.BlockKind.TANK).size() == 1, "the preview draws the tank")
	var payload_blocks: Array[Dictionary] = preview.blocks_of_kind(RocketStackPreview.BlockKind.PAYLOAD)
	report.check(payload_blocks.size() == 2, "the preview draws every payload part")
	var engine_rect: Rect2 = preview.blocks_of_kind(RocketStackPreview.BlockKind.ENGINE)[0]["rect"]
	var tank_rect: Rect2 = preview.blocks_of_kind(RocketStackPreview.BlockKind.TANK)[0]["rect"]
	var payload_rect: Rect2 = payload_blocks[0]["rect"]
	report.check(
			engine_rect.position.y > tank_rect.position.y and tank_rect.position.y > payload_rect.position.y,
			"the preview stacks the engine at the bottom and the payload on top")
	report.check(Rect2(Vector2.ZERO, preview.size).encloses(engine_rect), "the stack stays inside the preview")

	chips.free()
	screen.free()


func _check_removing_parts(report: TestReport) -> void:
	_select_first_mission()
	var screen: Control = _create_screen(ROCKET_DESIGN_SCENE_PATH)
	var preview: RocketStackPreview = screen.stack_preview
	_press_card(screen, GameData.CATEGORY_ENGINE, LIQUID_ENGINE_PART_ID)
	_press_card(screen, GameData.CATEGORY_TANK, TANK_PART_ID)
	_press_card(screen, GameData.CATEGORY_SCIENCE, SCIENCE_PART_ID)
	_press_card(screen, GameData.CATEGORY_TELEMETRY, TELEMETRY_PART_ID)
	var stage_id: int = GameState.design.stages[0].stage_id

	preview.payload_clicked.emit(0)
	var remaining_payload_part_ids: Array[String] = [TELEMETRY_PART_ID]
	report.check(
			GameState.design.payload_part_ids == remaining_payload_part_ids,
			"clicking a payload part in the preview removes that part only")
	preview.tank_clicked.emit(stage_id)
	report.check(
			GameState.design.stages.size() == 1 and GameState.design.stages[0].tank_part_id.is_empty(),
			"clicking a tank in the preview removes the tank and keeps the stage")
	report.check(
			preview.blocks_of_kind(RocketStackPreview.BlockKind.MISSING_TANK).size() == 1,
			"the preview marks a liquid stage without a tank")
	preview.engine_clicked.emit(stage_id)
	report.check(GameState.design.stages.is_empty(), "clicking an engine in the preview removes its stage")
	report.check(screen.selected_stage_id == 0, "removing the selected stage clears the selection")
	screen.free()


func _check_removing_a_stage_cleans_the_plan(report: TestReport) -> void:
	_select_first_mission()
	var screen: Control = _create_screen(ROCKET_DESIGN_SCENE_PATH)
	ExampleFlight.fill_reference_flight(GameState.design, GameState.plan, GameState.mission)
	var extra_pulse: Pulse = GameState.plan.pulses[0].duplicate_pulse()
	extra_pulse.pulse_id = GameState.plan.next_free_pulse_id()
	extra_pulse.stage_id = GameState.design.stages[0].stage_id
	GameState.plan.pulses.append(extra_pulse)
	GameState.notify_design_changed()
	GameState.notify_plan_changed()

	var first_stage_id: int = GameState.design.stages[0].stage_id
	var second_stage_id: int = GameState.design.stages[1].stage_id
	report.check(GameState.plan.launch_stage_ids.has(first_stage_id), "fixture: the first stage fires at launch")
	report.check(GameState.plan.pulses.size() == 2, "fixture: one pulse per stage")

	var derived_changed_count: Array[int] = [0]
	var count_derived_changed := func() -> void: derived_changed_count[0] += 1
	GameState.derived_changed.connect(count_derived_changed)
	screen.stack_preview.engine_clicked.emit(first_stage_id)
	GameState.derived_changed.disconnect(count_derived_changed)

	report.check(GameState.design.find_stage(first_stage_id) == null, "the stage leaves the design")
	report.check(not GameState.plan.launch_stage_ids.has(first_stage_id), "removing a stage removes its id from the launch stages")
	report.check(
			GameState.plan.pulses.size() == 1 and GameState.plan.pulses[0].stage_id == second_stage_id,
			"removing a stage deletes its pulses and keeps the others")
	report.check(derived_changed_count[0] == 2, "removing a stage notifies the design and the plan")
	report.check(
			GameState.summary.blocking_problems.has("No stage fires at launch."),
			"without launch stages the summary blocks the launch")
	screen.free()


func _check_tank_rules(report: TestReport) -> void:
	_select_first_mission()
	var screen: Control = _create_screen(ROCKET_DESIGN_SCENE_PATH)

	_press_card(screen, GameData.CATEGORY_TANK, TANK_PART_ID)
	report.check(GameState.design.stages.is_empty(), "a tank without a liquid stage is not installed")
	report.check(screen._hint_label.text.contains("liquid engine"), "the screen says why the tank was not installed")

	_press_card(screen, GameData.CATEGORY_ENGINE, SOLID_ENGINE_PART_ID)
	report.check(screen.selected_stage_id == 0, "a solid motor is not selected for a tank")
	_press_card(screen, GameData.CATEGORY_TANK, TANK_PART_ID)
	report.check(GameState.design.stages[0].tank_part_id.is_empty(), "a solid motor never receives a tank")

	_press_card(screen, GameData.CATEGORY_ENGINE, LIQUID_ENGINE_PART_ID)
	_press_card(screen, GameData.CATEGORY_ENGINE, SECOND_LIQUID_ENGINE_PART_ID)
	var lower_liquid_stage: Stage = GameState.design.stages[1]
	var upper_liquid_stage: Stage = GameState.design.stages[2]
	report.check(screen.selected_stage_id == upper_liquid_stage.stage_id, "the newest liquid stage is selected")

	screen.stack_preview.stage_tag_clicked.emit(lower_liquid_stage.stage_id)
	_press_card(screen, GameData.CATEGORY_TANK, TANK_PART_ID)
	report.check(
			lower_liquid_stage.tank_part_id == TANK_PART_ID and upper_liquid_stage.tank_part_id.is_empty(),
			"a tank goes to the stage chosen by its tag")

	screen.stack_preview.stage_tag_clicked.emit(GameState.design.stages[0].stage_id)
	report.check(screen.selected_stage_id == lower_liquid_stage.stage_id, "clicking the tag of a solid motor keeps the selection")

	screen.selected_stage_id = 0
	_press_card(screen, GameData.CATEGORY_TANK, TANK_PART_ID)
	report.check(
			upper_liquid_stage.tank_part_id == TANK_PART_ID,
			"with no selection a tank goes to the highest liquid stage without one")
	screen.free()


func _check_launch_button_and_chips(report: TestReport) -> void:
	_select_first_mission()
	var console: Control = _create_screen(PLANNING_CONSOLE_SCENE_PATH)
	console.zoom_duration_seconds = 0.0
	var launch_button: Button = console.launch_button
	var chips: StatChips = console.overview_stat_chips
	var rocket_design_screen: Control = console.rocket_design_screen

	report.check(launch_button.disabled, "Launch is disabled for an empty rocket")
	report.check(not launch_button.tooltip_text.is_empty(), "the disabled Launch button gives a reason")
	report.check(console._message_label.text.contains("no engine"), "the blocking problem is shown")

	_press_card(rocket_design_screen, GameData.CATEGORY_ENGINE, LIQUID_ENGINE_PART_ID)
	_press_card(rocket_design_screen, GameData.CATEGORY_TANK, TANK_PART_ID)
	# Decision recorded in tasks/notes/T06.md: T06 never chooses the launch
	# stages; that is the tick box of the orbit planning screen (T05).
	report.check(GameState.plan.launch_stage_ids.is_empty(), "building a stage does not choose launch stages")
	report.check(
			launch_button.disabled == (not GameState.summary.blocking_problems.is_empty()),
			"Launch follows blocking_problems after a stage is built")

	console._on_build_example_rocket_pressed()
	report.check(GameState.summary.blocking_problems.is_empty(), "fixture: the example rocket has no blocking problem")
	report.check(not launch_button.disabled, "Launch is enabled when nothing blocks it")
	report.check(not chips.is_cost_over_budget, "the example rocket is within the budget")
	report.check(
			chips.cost_value_label.text == "16.5 / %s" % PartCard.format_number(GameState.budget_million_usd),
			"the cost chip shows the cost against the budget")
	report.check(
			chips.delta_v_value_label.text == "%.0f" % GameState.summary.total_delta_v_meters_per_second,
			"the delta-v chip shows the total delta-v of the summary")

	# A warning that is only advice must not block the launch.
	var has_advice := false
	for warning in GameState.summary.warnings:
		has_advice = has_advice or warning.begins_with(RocketModel.WARNING_PREFIX)
	if has_advice:
		report.check(not launch_button.disabled, "advice in warnings does not disable Launch")

	var previous_costly_part: Dictionary = GameData.part(COSTLY_PART_ID)
	GameData.register_part({
		"id": COSTLY_PART_ID,
		"category": GameData.CATEGORY_SCIENCE,
		"name": "Test instrument that breaks the budget",
		"tier": 9,
		"cost_million_usd": GameState.budget_million_usd,
		"dry_mass_kilograms": 1.0,
		"mission_fit": {},
		"stats": {"power_watts": 1.0, "data_rate_megabits_per_second": 1.0, "science_value": 1.0},
	})
	_press_card(rocket_design_screen, GameData.CATEGORY_SCIENCE, COSTLY_PART_ID)
	report.check(GameState.summary.cost_million_usd > GameState.budget_million_usd, "fixture: the rocket is over budget")
	report.check(chips.is_cost_over_budget, "the cost chip knows the rocket is over budget")
	report.check(
			chips.cost_value_label.get_theme_color("font_color") == ScreenLayout.COLOR_WARNING_RED,
			"the cost chip turns red over budget")
	var expected_penalty_points: float = (
			Scoring.budget_points(GameState.budget_million_usd, GameState.budget_million_usd)
			- Scoring.budget_points(GameState.summary.cost_million_usd, GameState.budget_million_usd))
	report.check_close(
			chips.projected_budget_penalty_points, expected_penalty_points, 0.000001,
			"the cost chip shows the penalty from Scoring.budget_points")
	report.check(chips.cost_detail_label.text == "-%.1f pts" % expected_penalty_points, "the penalty is written on the chip")
	report.check(not launch_button.disabled, "going over budget does not disable Launch")

	rocket_design_screen.remove_payload_part(GameState.design.payload_part_ids.size() - 1)
	report.check(
			chips.cost_value_label.get_theme_color("font_color") == ScreenLayout.COLOR_TEXT_LIGHT,
			"the cost chip is light again within the budget")
	if previous_costly_part.is_empty():
		GameData.parts_by_id.erase(COSTLY_PART_ID)
	else:
		GameData.register_part(previous_costly_part)

	var launch_requested_count: Array[int] = [0]
	var count_launch_requested := func() -> void: launch_requested_count[0] += 1
	GameState.launch_requested.connect(count_launch_requested)
	launch_button.pressed.emit()
	GameState.launch_requested.disconnect(count_launch_requested)
	report.check(launch_requested_count[0] == 1, "pressing Launch calls GameState.request_launch")
	console.free()


func _check_zoom(report: TestReport) -> void:
	_select_first_mission()
	var console: Control = _create_screen(PLANNING_CONSOLE_SCENE_PATH)
	console.zoom_duration_seconds = 0.0
	var screen_type: Dictionary = console.Screen

	report.check(console.current_screen == screen_type["OVERVIEW"], "the console starts on the overview")
	report.check(not console.back_button.visible, "the overview has no back button")
	report.check(not console.rocket_design_screen.is_visible_in_tree(), "the rocket design screen starts hidden")

	console.zoom_into_rocket_design()
	report.check(console.current_screen == screen_type["ROCKET_DESIGN"], "the rocket monitor zooms into the rocket design screen")
	report.check(console.rocket_design_screen.is_visible_in_tree(), "the rocket design screen is shown after the zoom")
	report.check(console.back_button.visible, "a zoomed screen has a back button")
	report.check(
			Rect2(console.back_button.position, console.back_button.size) == ScreenLayout.BACK_BUTTON_RECT,
			"the back button sits in BACK_BUTTON_RECT")
	console.zoom_into_orbit_planning()
	report.check(console.current_screen == screen_type["ROCKET_DESIGN"], "a second zoom needs a return to the overview first")

	console.back_button.pressed.emit()
	report.check(console.current_screen == screen_type["OVERVIEW"], "the back button returns to the overview")
	report.check(not console.rocket_design_screen.is_visible_in_tree(), "the rocket design screen is hidden again")
	report.check(not console.back_button.visible, "the back button leaves with the detail screen")

	console.zoom_into_orbit_planning()
	report.check(console.current_screen == screen_type["ORBIT_PLANNING"], "the orbit monitor zooms into the orbit planning screen")
	report.check(console.orbit_planning_screen.is_visible_in_tree(), "the orbit planning screen is shown after the zoom")
	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	console._unhandled_input(cancel_event)
	report.check(console.current_screen == screen_type["OVERVIEW"], "Esc returns to the overview")

	var full_screen_rect := Rect2(Vector2.ZERO, ScreenLayout.SCREEN_SIZE)
	for chip_rect in console.ROCKET_DESIGN_STAT_CHIP_RECTS:
		report.check(
				full_screen_rect.encloses(chip_rect) and not chip_rect.intersects(ScreenLayout.CONSOLE_SWITCH_RECT),
				"a rocket design chip is on screen and clear of the console switch")
	report.check(
			ZoomTransition.scale_on_monitor(Rect2(0, 0, 320, 100)) == Vector2(0.5, 0.25),
			"the zoom starts at the scale that fits the monitor")
	console.free()


func _check_demo_scene(report: TestReport) -> void:
	var demo: Control = _create_screen(DEMO_SCENE_PATH)
	report.check(not GameState.mission.is_empty(), "the demo selects a mission")
	report.check(not GameState.science_mission_id.is_empty(), "the demo selects a science mission")
	report.check(demo.get_child_count() == 1, "the demo shows the planning console alone")
	demo.free()
