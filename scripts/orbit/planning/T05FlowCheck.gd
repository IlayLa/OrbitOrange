extends Node
## Runs the normal Console entry and pulse placement through real GUI mouse input.

var _failed := false


func _ready() -> void:
	GameState.start_new_game()
	var mission: Dictionary = GameData.all_missions()[0]
	GameState.select_mission(mission["id"], mission["science_missions"][0]["id"], [])
	var console: Control = load("res://scenes/Console.tscn").instantiate()
	add_child(console)
	await get_tree().process_frame
	await get_tree().process_frame
	var overview_artwork: TextureRect = console.find_child("AmitPlanningBackground", true, false)
	if not _check(overview_artwork != null and overview_artwork.texture.resource_path == ScreenLayout.PLANNING_OVERVIEW_BACKGROUND_PATH,
			"full-game overview uses Amit's supplied drawing"):
		return
	var example: Button = _find_button(console, "example")
	if not _check(example != null, "full game exposes the example rocket action"):
		return
	_click(example.get_global_transform_with_canvas() * (example.size / 2.0))
	await get_tree().process_frame
	if not _check(GameState.design.stages.size() == 2, "GUI example action builds the rocket"):
		return
	var monitor_center_pixels: Vector2 = ScreenLayout.OVERVIEW_ORBIT_MONITOR_SCREEN.get_center()
	_click(monitor_center_pixels)
	await get_tree().process_frame
	await get_tree().process_frame
	var editor: Control = _find_editor(console)
	if not _check(editor != null and editor.is_visible_in_tree(), "clicking the full-game orbit monitor opens the interactive pulse editor"):
		return
	var view: OrbitView = editor.get("_orbit_view")
	var entry: OrbitState = GameState.summary.ascent.orbit_entry_state
	var body: Dictionary = GameData.body("earth")
	var elements: OrbitElements = Kepler.elements_from_state(body[AscentPlanner.GRAVITATIONAL_PARAMETER_KEY], entry)
	var target: OrbitState = Kepler.propagate(body[AscentPlanner.GRAVITATIONAL_PARAMETER_KEY], entry, elements.period_seconds * 0.28)
	var local_pixels: Vector2 = view.world_to_screen(target.position_x_meters, target.position_y_meters)
	_click(view.get_global_transform_with_canvas() * local_pixels)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _check(GameState.plan.pulses.size() == 1, "clicking the orbit through the full-game GUI creates a pulse"):
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			var image: Image = get_viewport().get_texture().get_image()
			var result: Error = image.save_png(argument.trim_prefix("--capture="))
			_check(result == OK, "integrated planner screenshot saved")
	var back: Button = _find_button(console, "back")
	if not _check(back != null, "pulse editor exposes a back action"):
		return
	_click(back.get_global_transform_with_canvas() * (back.size / 2.0))
	await get_tree().process_frame
	if not _check(not editor.is_visible_in_tree(), "back returns to the planning overview"):
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-overview="):
			await RenderingServer.frame_post_draw
			var image: Image = get_viewport().get_texture().get_image()
			_check(image.save_png(argument.trim_prefix("--capture-overview=")) == OK, "planning overview screenshot saved")
	var plan_button: Button = _find_button(console, "plan flight")
	if not _check(plan_button != null, "overview provides a visible Plan flight button"):
		return
	_click(plan_button.get_global_transform_with_canvas() * (plan_button.size / 2.0))
	await get_tree().process_frame
	if not _check(editor.is_visible_in_tree() and GameState.plan.pulses.size() == 1, "Plan flight reopens the editor and preserves the existing pulse"):
		return
	var add_button: Button = _find_button(editor, "add pulse")
	if not _check(add_button != null and not add_button.disabled, "editor exposes an enabled Add pulse action"):
		return
	_click(add_button.get_global_transform_with_canvas() * (add_button.size / 2.0))
	_click(view.get_global_transform_with_canvas() * local_pixels)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _check(GameState.plan.pulses.size() == 2, "Add pulse allows choosing a burn point even at an existing pulse"):
		return

	if not _failed:
		print("T05_FLOW: all GUI checks passed")
		get_tree().quit(0)


func _click(position_pixels: Vector2) -> void:
	var screen_pixels: Vector2 = position_pixels
	var motion := InputEventMouseMotion.new()
	motion.position = screen_pixels
	motion.global_position = screen_pixels
	get_viewport().push_input(motion, true)
	for is_pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = screen_pixels
		event.global_position = screen_pixels
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = is_pressed
		get_viewport().push_input(event, true)


func _find_button(node: Node, fragment: String) -> Button:
	if node is Button and node.is_visible_in_tree() and fragment in node.text.to_lower():
		return node
	for child in node.get_children():
		var found: Button = _find_button(child, fragment)
		if found != null:
			return found
	return null


func _find_editor(node: Node) -> Control:
	if node is Control and node.get_script() != null and node.get_script().resource_path == "res://scripts/orbit/OrbitPlanning.gd":
		return node
	for child in node.get_children():
		var found: Control = _find_editor(child)
		if found != null:
			return found
	return null


func _check(condition: bool, description: String) -> bool:
	print("T05_FLOW ", "PASS " if condition else "FAIL ", description)
	if not condition:
		_failed = true
		push_error("T05 full-game regression: " + description)
		get_tree().quit(1)
	return condition
