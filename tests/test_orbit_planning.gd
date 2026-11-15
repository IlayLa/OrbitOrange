extends RefCounted
## Display geometry and controller interaction checks through observable state.

const PlanningScene = preload("res://scenes/planning/OrbitPlanning.tscn")


func run_tests(report: TestReport) -> void:
	_check_mapping_and_arrows(report)
	_check_editing(report)


func _check_mapping_and_arrows(report: TestReport) -> void:
	var body: Dictionary = GameData.body("earth")
	var mission: Dictionary = GameData.all_missions()[0]
	for size_pixels: Vector2 in [Vector2(465, 295), Vector2(245, 175), Vector2(930, 590)]:
		var view := OrbitView.new()
		view.size = size_pixels
		view.configure(body, mission)
		for angle_radians in [0.2, 1.7, -2.3]:
			var radius_meters: float = float(body["radius_meters"]) + 400000.0
			var screen_position: Vector2 = view.world_to_screen(radius_meters * cos(angle_radians), radius_meters * sin(angle_radians))
			report.check_close(view.screen_to_radius_meters(screen_position), radius_meters, 3.0, "display radius round-trip works at each widget size")
			report.check_close(angle_difference(view.screen_to_polar_angle_radians(screen_position), angle_radians), 0.0, 0.000001,
					"display angle round-trip preserves inertial direction")
		for motion_sign in [-1.0, 1.0]:
			var radius_meters: float = float(body["radius_meters"]) + 400000.0
			var speed_meters_per_second: float = Kepler.circular_speed_meters_per_second(body[AscentPlanner.GRAVITATIONAL_PARAMETER_KEY], radius_meters)
			var state: OrbitState = OrbitState.create(radius_meters, 0.0, 0.0, motion_sign * speed_meters_per_second)
			var pulse := Pulse.new()
			pulse.delta_v_along_velocity_meters_per_second = 300.0
			pulse.delta_v_outward_meters_per_second = 100.0
			var direction: Vector2 = PulseGeometry.arrow_direction(view, state, pulse)
			var components: Vector2 = PulseGeometry.components_from_direction(view, state, direction)
			report.check(components.distance_to(Vector2(300, 100).normalized()) < 0.000001,
					"arrow projection and picking preserve V/B components in both orbital directions")
		view.free()


func _check_editing(report: TestReport) -> void:
	var saved_has_launched: bool = GameState.has_launched
	GameState.has_launched = false
	var saved_mission: Dictionary = GameState.mission
	var saved_design: RocketDesign = GameState.design
	var saved_plan: MissionPlan = GameState.plan
	var saved_summary: PlanSummary = GameState.summary
	var saved_trajectory: Trajectory = GameState.trajectory
	GameState.mission = GameData.all_missions()[0]
	GameState.design = RocketDesign.new()
	GameState.plan = MissionPlan.new()
	ExampleFlight.fill_automatic_flight(GameState.design, GameState.plan)
	GameState.notify_design_changed()
	var root: Node = GameState
	var screen: Control = PlanningScene.instantiate()
	root.add_child(screen)
	var artwork: TextureRect = screen.get_node_or_null("AmitOrbitBackground")
	report.check(artwork != null and artwork.texture.resource_path == ScreenLayout.ORBIT_PLANNING_BACKGROUND_PATH,
			"orbit editor uses Amit's supplied background directly")
	var artwork_view: OrbitView = screen.get("_orbit_view")
	var earth_texture: AtlasTexture = artwork_view.get("_earth_texture")
	report.check(earth_texture != null and earth_texture.atlas.resource_path == ScreenLayout.ORBIT_PLANNING_BACKGROUND_PATH,
			"dynamic Earth reuses Amit's supplied sprite")
	var state: OrbitState = GameState.summary.ascent.orbit_entry_state
	var body: Dictionary = GameData.body("earth")
	var elements: OrbitElements = Kepler.elements_from_state(body[AscentPlanner.GRAVITATIONAL_PARAMETER_KEY], state)
	var target: OrbitState = Kepler.propagate(body[AscentPlanner.GRAVITATIONAL_PARAMETER_KEY], state, elements.period_seconds * 0.25)
	var view: OrbitView = screen.get("_orbit_view")
	var point_pixels: Vector2 = view.world_to_screen(target.position_x_meters, target.position_y_meters)
	screen.call("_add_pulse", point_pixels)
	screen.call("_process", 0.0)
	report.check(GameState.plan.pulses.size() == 1, "clicking the displayed path adds a pulse without choosing a stage")
	if GameState.plan.pulses.size() == 1:
		report.check(GameState.plan.pulses[0].extra_revolutions == 0, "new UI pulses use the first subsequent crossing")
		report.check(GameState.summary.pulse_allocations[0].stage_ids == [GameState.design.stages[1].stage_id],
				"the editor automatically uses the partially consumed upper stage")
		var notifications: Array[int] = []
		var listener := func() -> void: notifications.append(1)
		GameState.derived_changed.connect(listener)
		screen.call("_on_magnitude_changed", 150.0)
		screen.call("_on_magnitude_changed", 175.0)
		screen.call("_on_magnitude_changed", 200.0)
		report.check(notifications.is_empty(), "intermediate drag edits wait for the next process frame")
		screen.call("_process", 0.0)
		report.check(notifications.size() == 1, "multiple edits produce one derived refresh per frame")
		GameState.derived_changed.disconnect(listener)
		report.check_close(GameState.plan.pulses[0].requested_delta_v_meters_per_second(), 200.0, 0.000001,
				"the coalesced edit retains the latest requested magnitude")
		var original_trajectory: Trajectory = GameState.trajectory
		screen.set("_drag_snapshot", original_trajectory)
		screen.set("_drag_mode", "anchor")
		var moved_state: OrbitState = Kepler.propagate(body[AscentPlanner.GRAVITATIONAL_PARAMETER_KEY], state, elements.period_seconds * 0.4)
		screen.call("_update_drag", view.world_to_screen(moved_state.position_x_meters, moved_state.position_y_meters))
		screen.call("_process", 0.0)
		report.check(screen.get("_drag_snapshot") == original_trajectory and GameState.trajectory != original_trajectory,
				"moving a pulse updates the trajectory while preserving the drag-start ghost")
		var allocation: BurnAllocation = GameState.summary.pulse_allocations[0]
		var probe := Pulse.new()
		probe.delta_v_along_velocity_meters_per_second = 300.0
		probe.delta_v_outward_meters_per_second = 100.0
		var anchor_pixels: Vector2 = view.world_to_screen(allocation.before_state.position_x_meters, allocation.before_state.position_y_meters)
		var direction_pixels: Vector2 = PulseGeometry.arrow_direction(view, allocation.before_state, probe)
		screen.set("_drag_mode", "arrow")
		screen.call("_update_drag", anchor_pixels + direction_pixels * PulseGeometry.arrow_length_pixels(500.0))
		screen.call("_process", 0.0)
		report.check_close(GameState.plan.pulses[0].requested_delta_v_meters_per_second(), 500.0, 0.01,
				"dragging the arrow changes its physical requested magnitude")
		report.check(GameState.plan.pulses[0].delta_v_outward_meters_per_second > 0.0,
				"arrow dragging preserves an outward velocity component")
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		screen.call("_input", release)
		report.check(screen.get("_drag_snapshot") == null, "releasing the mouse clears the fixed drag ghost")
		var number: SpinBox = screen.get("_magnitude_number")
		number.get_line_edit().grab_focus()
		var delete_key := InputEventKey.new()
		delete_key.pressed = true
		delete_key.keycode = KEY_DELETE
		screen.call("_input", delete_key)
		report.check(GameState.plan.pulses.size() == 1, "Delete inside the numeric editor does not delete the selected pulse")
		number.get_line_edit().release_focus()
		GameState.has_launched = true
		screen.call("_refresh")
		var original_request_meters_per_second: float = GameState.plan.pulses[0].requested_delta_v_meters_per_second()
		var original_angle_radians: float = GameState.plan.launch_angle_radians
		screen.call("_on_magnitude_changed", 999.0)
		screen.call("_on_launch_angle_changed", 45.0)
		screen.call("_delete_selected")
		screen.call("_add_pulse", point_pixels)
		report.check(GameState.plan.pulses.size() == 1 and GameState.plan.pulses[0].requested_delta_v_meters_per_second() == original_request_meters_per_second
				and GameState.plan.launch_angle_radians == original_angle_radians, "orbit edits respect T06's launched-plan lock")
		report.check(screen.get("_add_button").disabled and screen.get("_delete_button").disabled,
				"pulse editing controls are disabled after launch")
		GameState.has_launched = false
		screen.call("_refresh")
		screen.call("_delete_selected")
		screen.call("_process", 0.0)
		report.check(GameState.plan.pulses.is_empty(), "the delete control removes the selected pulse")
	root.remove_child(screen)
	screen.free()
	GameState.has_launched = saved_has_launched
	GameState.mission = saved_mission
	GameState.design = saved_design
	GameState.plan = saved_plan
	GameState.summary = saved_summary
	GameState.trajectory = saved_trajectory
