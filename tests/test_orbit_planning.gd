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
	var engine_rows: VBoxContainer = screen.get("_engine_rows")
	var stage_card: Control = engine_rows.get_child(0) if engine_rows.get_child_count() > 0 else null
	report.check(stage_card != null and stage_card.mouse_filter == Control.MOUSE_FILTER_PASS and not stage_card.tooltip_text.is_empty(),
			"a stage card takes hover, so its tooltip can show, and passes the wheel on to its list")
	if stage_card != null:
		var stage_tooltip: Label = stage_card._make_custom_tooltip(stage_card.tooltip_text)
		report.check(stage_tooltip != null and stage_tooltip.text.contains("\n"), "a stage card's tooltip is wrapped")
		if stage_tooltip != null:
			stage_tooltip.free()
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
		_check_typed_direction(report, screen)
		_check_launch_angle_field(report, screen)
		_check_slingshot_placement(report, screen, view, body, state, elements)
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
		var original_direction_degrees: float = GameState.plan.pulses[0].direction_angle_degrees()
		screen.call("_on_magnitude_changed", 999.0)
		screen.call("_on_direction_angle_changed", original_direction_degrees + 45.0)
		report.check_close(GameState.plan.pulses[0].direction_angle_degrees(), original_direction_degrees, 0.000001,
				"the typed burn direction respects the launched-plan lock")
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


## The angle field: 0° along the motion, +90° outward, magnitude kept.
func _check_typed_direction(report: TestReport, screen: Control) -> void:
	var pulse: Pulse = GameState.plan.pulses[0]
	var magnitude_meters_per_second: float = pulse.requested_delta_v_meters_per_second()
	screen.call("_on_direction_angle_changed", 90.0)
	screen.call("_process", 0.0)
	report.check_close(pulse.delta_v_along_velocity_meters_per_second, 0.0, 0.000001, "a typed 90° burn has no along-motion part")
	report.check_close(pulse.delta_v_outward_meters_per_second, magnitude_meters_per_second, 0.000001,
			"a typed 90° burn points outward and keeps its magnitude")
	screen.call("_on_magnitude_changed", 250.0)
	screen.call("_process", 0.0)
	report.check_close(pulse.direction_angle_degrees(), 90.0, 0.000001, "a typed magnitude keeps the typed direction")
	screen.call("_on_direction_angle_changed", -135.0)
	screen.call("_process", 0.0)
	var field: SpinBox = screen.get("_direction_number")
	report.check(field.visible, "the direction field shows for a selected pulse")
	report.check_close(field.value, -135.0, 0.05, "the direction field shows the pulse's angle from the motion")
	report.check_close(pulse.requested_delta_v_meters_per_second(), 250.0, 0.000001, "a typed direction keeps the magnitude")


## The launch angle field and slider set the plan and follow each other.
func _check_launch_angle_field(report: TestReport, screen: Control) -> void:
	var original_angle_radians: float = GameState.plan.launch_angle_radians
	var field: SpinBox = screen.get("_launch_number")
	var slider: HSlider = screen.get("_launch_slider")
	field.value = 42.5
	report.check_close(GameState.plan.launch_angle_radians, deg_to_rad(42.5), 0.000001, "typing a launch angle sets the plan")
	report.check_close(slider.value, 42.5, 0.000001, "the launch slider follows the typed angle")
	slider.value = 30.0
	report.check_close(field.value, 30.0, 0.000001, "the launch field follows the slider")
	GameState.plan.launch_angle_radians = original_angle_radians
	screen.call("_refresh")
	screen.call("_process", 0.0)


## Press on the path, pull back: the arrow points opposite the pull, as long as the pull.
func _check_slingshot_placement(report: TestReport, screen: Control, view: OrbitView, body: Dictionary,
		state: OrbitState, elements: OrbitElements) -> void:
	var gravitational_parameter: float = body[AscentPlanner.GRAVITATIONAL_PARAMETER_KEY]
	var press_state: OrbitState = Kepler.propagate(gravitational_parameter, state, elements.period_seconds * 0.2)
	var press_pixels: Vector2 = view.world_to_screen(press_state.position_x_meters, press_state.position_y_meters)
	var first_pulse_id: int = GameState.plan.pulses[0].pulse_id
	var pulse_count: int = GameState.plan.pulses.size()
	screen.call("_begin_placement", press_pixels)
	report.check(GameState.plan.pulses.size() == pulse_count + 1 and screen.get("_drag_mode") == "place",
			"pressing the path adds a pulse and starts aiming it")
	screen.call("_process", 0.0)
	var placed: Pulse = screen.call("_selected_pulse")
	if placed == null:
		report.check(false, "the pressed pulse is selected")
		return
	screen.call("_update_drag", press_pixels + Vector2(3, 0))
	screen.call("_process", 0.0)
	report.check(placed.delta_v_along_velocity_meters_per_second == 100.0 and placed.delta_v_outward_meters_per_second == 0.0,
			"a press that barely moves keeps the 100 m/s forward default")
	var allocation: BurnAllocation = screen.call("_allocation_for", placed.pulse_id)
	if allocation == null or allocation.before_state == null:
		report.check(false, "the pressed pulse is reachable")
		return
	var probe := Pulse.new()
	probe.delta_v_along_velocity_meters_per_second = 300.0
	probe.delta_v_outward_meters_per_second = 100.0
	var anchor_pixels: Vector2 = view.world_to_screen(allocation.before_state.position_x_meters, allocation.before_state.position_y_meters)
	var forward_pixels: Vector2 = PulseGeometry.arrow_direction(view, allocation.before_state, probe)
	screen.call("_update_drag", anchor_pixels - forward_pixels * PulseGeometry.arrow_length_pixels(500.0))
	screen.call("_process", 0.0)
	report.check_close(placed.requested_delta_v_meters_per_second(), 500.0, 0.01, "the pull length sets the burn size")
	report.check(placed.delta_v_along_velocity_meters_per_second > 0.0 and placed.delta_v_outward_meters_per_second > 0.0,
			"pulling backwards and inward aims the burn forwards and outward")
	report.check_close(placed.direction_angle_degrees(), probe.direction_angle_degrees(), 0.01, "the burn points exactly opposite the pull")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	screen.call("_input", release)
	report.check(screen.get("_drag_mode") == "" and GameState.plan.pulses.size() == pulse_count + 1,
			"releasing the pull keeps the aimed pulse")
	report.check(screen.get("_selected_pulse_id") == 0 and not (screen.get("_direction_number") as SpinBox).visible,
			"a finished placement leaves no pulse selected")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = anchor_pixels
	screen.call("_on_view_input", press)
	screen.call("_input", release)
	report.check(screen.get("_selected_pulse_id") == placed.pulse_id and GameState.plan.pulses.size() == pulse_count + 1,
			"clicking an existing pulse selects it without adding another")
	report.check((screen.get("_direction_number") as SpinBox).visible, "selecting a pulse shows its fields")
	screen.call("_delete_selected")
	screen.call("_process", 0.0)
	screen.call("_begin_placement", press_pixels)
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	screen.call("_input", escape)
	screen.call("_process", 0.0)
	report.check(GameState.plan.pulses.size() == pulse_count and screen.get("_drag_mode") == "",
			"Escape while placing removes the new pulse")
	screen.set("_selected_pulse_id", first_pulse_id)
	screen.call("_refresh")
