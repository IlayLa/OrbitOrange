extends Node
## Standalone automatic-ascent demo. Optional --capture=absolute.png for visual QA.


func _ready() -> void:
	GameState.start_new_game()
	var mission: Dictionary = GameData.all_missions()[0]
	var science: Array = mission.get("science_missions", [])
	var science_id: String = science[0].get("id", "") if not science.is_empty() else ""
	GameState.select_mission(mission["id"], science_id, [])
	ExampleFlight.fill_automatic_flight(GameState.design, GameState.plan)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("--scenario=impact"):
		GameState.design.stages.clear()
		GameState.design.add_stage("engine_solid_basic")
		GameState.design.payload_part_ids.assign(["science_camera_basic"])
	GameState.notify_design_changed()
	if arguments.has("--scenario=escape") or arguments.has("--scenario=selected"):
		var pulse := Pulse.new()
		pulse.pulse_id = 1
		pulse.polar_angle_radians = GameState.summary.ascent.orbit_entry_state.polar_angle_radians() + PI / 2.0
		pulse.delta_v_along_velocity_meters_per_second = 100000.0 if arguments.has("--scenario=escape") else 100.0
		GameState.plan.pulses.append(pulse)
		GameState.notify_plan_changed()
	var screen: Control = load("res://scenes/planning/OrbitPlanning.tscn").instantiate()
	add_child(screen)
	if arguments.has("--scenario=selected") or arguments.has("--scenario=escape"):
		screen.set("_selected_pulse_id", 1)
		screen.call("_refresh")
	for argument in arguments:
		if argument.begins_with("--capture="):
			_capture_after_draw(argument.trim_prefix("--capture="))
			break


func _capture_after_draw(output_path: String) -> void:
	for frame_index in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	var result: Error = screenshot.save_png(output_path)
	print("T05_CAPTURE ", output_path, " result=", result)
	get_tree().quit(0 if result == OK else 1)
