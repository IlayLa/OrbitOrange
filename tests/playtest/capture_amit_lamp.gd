extends Control
## Saves PNGs of the planning overview (inside the full console) with Amit's portrait beside the lamp
## bar: no lamp active, a blocking lamp pinned, a warning lamp pinned. Not a test.
##
## Run with a window and an English locale (see capture_screens.gd):
##     godot --path <project> --language en res://tests/playtest/CaptureAmitLamp.tscn -- --capture-directory=<absolute folder>

const CAPTURE_ARGUMENT_PREFIX := "--capture-directory="

var _directory: String = "user://amit_lamp_screens"


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
	var no_quest_ids: Array[String] = []
	GameState.start_new_game()
	GameState.select_mission(missions[0]["id"], missions[0]["science_missions"][0]["id"], no_quest_ids)
	var console: Control = load("res://scenes/Console.tscn").instantiate()
	add_child(console)
	await _capture("amit_none")
	var lamp_bar: LampBar = _find_lamp_bar(console)
	for severity in [WarningLamps.Severity.BLOCKING, WarningLamps.Severity.WARNING]:
		var entries: Array[Dictionary] = lamp_bar.entries()
		for entry_index in entries.size():
			if entries[entry_index]["severity"] == severity:
				lamp_bar.toggle_pin(entry_index)
				await _capture("amit_blocking" if severity == WarningLamps.Severity.BLOCKING else "amit_warning")
				lamp_bar.toggle_pin(entry_index)
				break
	print("Screens saved to ", ProjectSettings.globalize_path(_directory))
	get_tree().quit()


func _find_lamp_bar(node: Node) -> LampBar:
	if node is LampBar:
		return node
	for child in node.get_children():
		var found: LampBar = _find_lamp_bar(child)
		if found != null:
			return found
	return null


func _capture(file_name: String) -> void:
	for frame_index in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = _directory.path_join(file_name + ".png")
	if get_viewport().get_texture().get_image().save_png(path) != OK:
		push_error("Could not save capture: " + path)
