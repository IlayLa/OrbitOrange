extends Node
## Selectable feature scenarios; use --scenario=<id> and optionally --capture=<absolute.png>.

const Scenarios = preload("res://scripts/orbit/planning/T05Scenarios.gd")

var _screen: Control
var _picker: OptionButton
var _guide: AcceptDialog
var _caption: Label


func _ready() -> void:
	_build_controls()
	var chosen := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scenario="):
			var scenario_id := argument.trim_prefix("--scenario=")
			for index in Scenarios.CASES.size():
				if Scenarios.CASES[index]["id"] == scenario_id:
					chosen = index
	_picker.select(chosen)
	_load_scenario(chosen)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_capture_after_draw(argument.trim_prefix("--capture="))
			break


func _build_controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var controls := Control.new()
	controls.theme = PlanningStyle.create_theme()
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(controls)
	_picker = OptionButton.new()
	_picker.name = "ScenarioPicker"
	_picker.position = Vector2(40, 3)
	_picker.size = Vector2(336, 25)
	_picker.add_theme_font_size_override("font_size", 11)
	for scenario in Scenarios.CASES:
		_picker.add_item(scenario["title"])
	_picker.item_selected.connect(_load_scenario)
	controls.add_child(_picker)
	var reset := Button.new()
	reset.text = "Reset"
	reset.position = Vector2(382, 3)
	reset.size = Vector2(60, 25)
	reset.pressed.connect(func() -> void: _load_scenario(_picker.selected))
	controls.add_child(reset)
	var help := Button.new()
	help.text = "Scenario guide"
	help.position = Vector2(448, 3)
	help.size = Vector2(172, 25)
	help.pressed.connect(func() -> void: _guide.popup_centered(Vector2i(520, 220)))
	controls.add_child(help)
	_caption = Label.new()
	_caption.position = Vector2(40, 30)
	_caption.size = Vector2(580, 17)
	_caption.add_theme_font_size_override("font_size", 10)
	controls.add_child(_caption)
	_guide = AcceptDialog.new()
	_guide.dialog_autowrap = true
	controls.add_child(_guide)


func _load_scenario(index: int) -> void:
	if _screen != null:
		_screen.free()
	GameState.start_new_game()
	var mission: Dictionary = GameData.all_missions()[0]
	var science: Array = mission.get("science_missions", [])
	var science_id: String = science[0].get("id", "") if not science.is_empty() else ""
	GameState.select_mission(mission["id"], science_id, [])
	var scenario: Dictionary = Scenarios.CASES[index]
	var fixture: Dictionary = Scenarios.create(scenario["id"], mission)
	GameState.design = fixture["design"]
	GameState.plan = fixture["plan"]
	GameState.notify_design_changed()
	_screen = load("res://scenes/planning/OrbitPlanning.tscn").instantiate()
	add_child(_screen)
	_screen.set("_selected_pulse_id", fixture["selected_pulse_id"])
	_screen.call("_refresh")
	_guide.title = scenario["title"]
	_guide.dialog_text = scenario["guide"]
	_caption.text = "T05 · catalogue parts · Scenario guide explains what to inspect"
	print("T05_SCENARIO ", scenario["id"], " status=", Trajectory.Status.keys()[GameState.trajectory.status])


func _capture_after_draw(output_path: String) -> void:
	for frame_index in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	var result: Error = screenshot.save_png(output_path)
	print("T05_CAPTURE ", output_path, " result=", result)
	get_tree().quit(0 if result == OK else 1)
