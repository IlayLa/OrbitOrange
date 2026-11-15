extends Control
## Automatic ascent and pulse editor. Physics and mass are supplied by shared results.

var _orbit_view: OrbitView
var _overlay: Control
var _readouts: Label
var _hint: Label
var _launch_value: Label
var _launch_slider: HSlider
var _magnitude_slider: HSlider
var _magnitude_number: SpinBox
var _delete_button: Button
var _engine_rows: VBoxContainer
var _selected_pulse_id: int = 0
var _pending_plan_change: bool = false
var _drag_mode: String = ""
var _drag_snapshot: Trajectory
var _body: Dictionary = {}
var _add_button: Button
var _inspector_label: Label
var _is_placing_pulse: bool = false
var _hover_point_pixels := Vector2.ZERO
var _has_hover_point: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = PlanningStyle.create_theme()
	ScreenLayout.add_mockup_background(self, ScreenLayout.ORBIT_PLANNING_BACKGROUND_PATH, "AmitOrbitBackground")
	_orbit_view = OrbitView.new()
	_orbit_view.position = ScreenLayout.ORBIT_PLANNING_VIEW_SCREEN.position
	_orbit_view.size = ScreenLayout.ORBIT_PLANNING_VIEW_SCREEN.size
	add_child(_orbit_view)
	_overlay = Control.new()
	_overlay.position = _orbit_view.position
	_overlay.size = _orbit_view.size
	_overlay.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_overlay.clip_contents = true
	_overlay.draw.connect(_draw_overlay)
	_overlay.gui_input.connect(_on_view_input)
	_overlay.mouse_exited.connect(_clear_hover)
	add_child(_overlay)
	_readouts = _label(Vector2(48, 80), Vector2(449, 29), 9)
	_add_button = Button.new()
	_add_button.text = "+ Add pulse"
	_add_button.theme = theme
	_add_button.position = Vector2(40, 52)
	_add_button.size = Vector2(85, 21)
	_add_button.toggle_mode = true
	_add_button.toggled.connect(_on_add_toggled)
	add_child(_add_button)
	_hint = _label(Vector2(132, 54), Vector2(113, 20), 10)
	_inspector_label = _label(Vector2(48, 373), Vector2(175, 20), 10)
	_inspector_label.hide()
	var stage_heading: Label = _label(Vector2(535, 57), Vector2(85, 12), 10)
	stage_heading.text = ""
	_magnitude_slider = HSlider.new()
	_magnitude_slider.position = Vector2(250, 54)
	_magnitude_slider.size = Vector2(86, 18)
	_magnitude_slider.min_value = 0.0
	_magnitude_slider.step = 1.0
	_magnitude_slider.value_changed.connect(_on_magnitude_changed)
	add_child(_magnitude_slider)
	_magnitude_number = SpinBox.new()
	_magnitude_number.theme = theme
	_magnitude_number.position = Vector2(342, 51)
	_magnitude_number.size = Vector2(94, 22)
	_magnitude_number.suffix = "m/s"
	_magnitude_number.allow_greater = true
	_magnitude_number.step = 1.0
	_magnitude_number.add_theme_font_size_override("font_size", 10)
	_magnitude_number.value_changed.connect(_on_magnitude_changed)
	add_child(_magnitude_number)
	_delete_button = Button.new()
	_delete_button.theme = theme
	_delete_button.text = "Delete"
	_delete_button.position = Vector2(441, 52)
	_delete_button.size = Vector2(64, 21)
	_delete_button.add_theme_font_size_override("font_size", 10)
	_delete_button.pressed.connect(_delete_selected)
	add_child(_delete_button)
	var engine_backing := ColorRect.new()
	engine_backing.position = ScreenLayout.ORBIT_PLANNING_ENGINE_LIST.position
	engine_backing.size = ScreenLayout.ORBIT_PLANNING_ENGINE_LIST.size
	engine_backing.color = ScreenLayout.COLOR_LIST_GREY
	engine_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(engine_backing)
	var scroll := ScrollContainer.new()
	scroll.position = ScreenLayout.ORBIT_PLANNING_ENGINE_LIST.position
	scroll.size = ScreenLayout.ORBIT_PLANNING_ENGINE_LIST.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_engine_rows = VBoxContainer.new()
	_engine_rows.custom_minimum_size.x = 71.0
	_engine_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_engine_rows.add_theme_constant_override("separation", 7)
	scroll.add_child(_engine_rows)
	var launch_label: Label = _label(Vector2(44, 376), Vector2(96, 20), 10)
	launch_label.text = "Launch angle"
	_launch_slider = HSlider.new()
	_launch_slider.position = Vector2(146, 378)
	_launch_slider.size = Vector2(270, 18)
	_launch_slider.min_value = 0.0
	_launch_slider.max_value = 89.0
	_launch_slider.step = 0.1
	_launch_slider.value_changed.connect(_on_launch_angle_changed)
	add_child(_launch_slider)
	_launch_value = _label(Vector2(423, 376), Vector2(80, 20), 10)
	GameState.launch_requested.connect(_refresh)
	GameState.derived_changed.connect(_refresh)
	GameState.mission_changed.connect(_refresh)
	_refresh()


func _label(position_pixels: Vector2, size_pixels: Vector2, font_size_pixels: int) -> Label:
	var label := Label.new()
	label.position = position_pixels
	label.size = size_pixels
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size_pixels)
	label.add_theme_color_override("font_color", Color("#e4eaf0"))
	add_child(label)
	return label


func _process(_elapsed_seconds: float) -> void:
	if _pending_plan_change:
		_pending_plan_change = false
		if not GameState.has_launched:
			GameState.notify_plan_changed()


func _input(event: InputEvent) -> void:
	if not _can_edit():
		_drag_mode = ""
		_drag_snapshot = null
		return
	if _drag_mode != "":
		if event is InputEventMouseMotion:
			_update_drag(_overlay.get_local_mouse_position())
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_drag_mode = ""
			_drag_snapshot = null
			_update_ghosts()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_DELETE and is_visible_in_tree():
		var focused: Control = get_viewport().gui_get_focus_owner()
		if not focused is LineEdit and not focused is TextEdit:
			_delete_selected()


func _on_view_input(event: InputEvent) -> void:
	if not _can_edit():
		return
	if event is InputEventMouseMotion:
		_overlay.tooltip_text = _tooltip_at(event.position)
		var hovered: Dictionary = _orbit_view.pick_path(event.position, 14.0)
		_has_hover_point = not hovered.is_empty() and (GameState.summary != null and GameState.summary.ascent != null and GameState.summary.ascent.did_reach_initial_orbit)
		if _has_hover_point:
			_hover_point_pixels = hovered["position_pixels"]
		_overlay.queue_redraw()
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	var hit: Dictionary = _pick_pulse(event.position)
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if not hit.is_empty():
			_selected_pulse_id = hit["pulse"].pulse_id
			_delete_selected()
		_overlay.accept_event()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if not hit.is_empty() and not event.shift_pressed and not _is_placing_pulse:
			_selected_pulse_id = hit["pulse"].pulse_id
			_drag_mode = hit["part"]
			_drag_snapshot = GameState.trajectory
			_refresh()
		else:
			_add_pulse(event.position)
		_overlay.accept_event()


func _add_pulse(position_pixels: Vector2) -> void:
	if not _can_edit():
		return
	if GameState.summary == null or GameState.summary.ascent == null or not GameState.summary.ascent.did_reach_initial_orbit:
		_hint.text = "Reach the initial orbit first"
		return
	var hit: Dictionary = _orbit_view.pick_path(position_pixels, 14.0)
	if hit.is_empty():
		return
	var segment: TrajectorySegment = hit["segment"]
	var pulse := Pulse.new()
	pulse.pulse_id = GameState.plan.next_free_pulse_id()
	pulse.polar_angle_radians = _orbit_view.screen_to_polar_angle_radians(position_pixels)
	pulse.delta_v_along_velocity_meters_per_second = 100.0
	var insertion_index: int = clampi(segment.pulse_index + 1, 0, GameState.plan.pulses.size())
	GameState.plan.pulses.insert(insertion_index, pulse)
	_is_placing_pulse = false
	_add_button.set_pressed_no_signal(false)
	_selected_pulse_id = pulse.pulse_id
	_pending_plan_change = true


func _update_drag(position_pixels: Vector2) -> void:
	if not _can_edit():
		return
	var pulse: Pulse = _selected_pulse()
	if pulse == null:
		return
	if _drag_mode == "anchor":
		if position_pixels.distance_to(_orbit_view.size / 2.0) > 2.0:
			pulse.polar_angle_radians = _orbit_view.screen_to_polar_angle_radians(position_pixels)
	else:
		var allocation: BurnAllocation = _allocation_for(pulse.pulse_id)
		if allocation == null or allocation.before_state == null:
			return
		var anchor_pixels: Vector2 = _pulse_position(pulse, allocation)
		var direction_pixels: Vector2 = position_pixels - anchor_pixels
		var components: Vector2 = PulseGeometry.components_from_direction(_orbit_view, allocation.before_state, direction_pixels)
		var magnitude_meters_per_second: float = maxf(1.0, pulse.requested_delta_v_meters_per_second()) if allocation.starts_with_solid else PulseGeometry.magnitude_from_length(direction_pixels.length())
		pulse.delta_v_along_velocity_meters_per_second = components.x * magnitude_meters_per_second
		pulse.delta_v_outward_meters_per_second = components.y * magnitude_meters_per_second
	_pending_plan_change = true


func _on_launch_angle_changed(angle_degrees: float) -> void:
	if not _can_edit():
		return
	GameState.plan.launch_angle_radians = deg_to_rad(angle_degrees)
	_launch_value.text = "%.1f°" % angle_degrees
	_pending_plan_change = true


func _on_magnitude_changed(magnitude_meters_per_second: float) -> void:
	if not _can_edit():
		return
	var pulse: Pulse = _selected_pulse()
	if pulse == null or not is_finite(magnitude_meters_per_second):
		return
	var allocation: BurnAllocation = _allocation_for(pulse.pulse_id)
	if allocation != null and allocation.starts_with_solid:
		return
	var previous_magnitude: float = pulse.requested_delta_v_meters_per_second()
	var along_share: float = pulse.delta_v_along_velocity_meters_per_second / previous_magnitude if previous_magnitude > 0.0 else 1.0
	var outward_share: float = pulse.delta_v_outward_meters_per_second / previous_magnitude if previous_magnitude > 0.0 else 0.0
	pulse.delta_v_along_velocity_meters_per_second = along_share * magnitude_meters_per_second
	pulse.delta_v_outward_meters_per_second = outward_share * magnitude_meters_per_second
	_pending_plan_change = true


func _delete_selected() -> void:
	if not _can_edit():
		return
	for pulse_index in GameState.plan.pulses.size():
		if GameState.plan.pulses[pulse_index].pulse_id == _selected_pulse_id:
			GameState.plan.pulses.remove_at(pulse_index)
			_selected_pulse_id = 0
			_drag_mode = ""
			_drag_snapshot = null
			_pending_plan_change = true
			return


func _selected_pulse() -> Pulse:
	for pulse in GameState.plan.pulses:
		if pulse.pulse_id == _selected_pulse_id:
			return pulse
	return null


func _allocation_for(pulse_id: int) -> BurnAllocation:
	if GameState.summary == null:
		return null
	for pulse_index in GameState.plan.pulses.size():
		if GameState.plan.pulses[pulse_index].pulse_id == pulse_id and pulse_index < GameState.summary.pulse_allocations.size():
			return GameState.summary.pulse_allocations[pulse_index]
	return null


func _refresh() -> void:
	if _orbit_view == null:
		return
	_body = GameData.body(GameState.mission.get("body_id", "earth")) if not GameState.mission.is_empty() else {}
	_orbit_view.configure(_body, GameState.mission)
	_orbit_view.show_trajectory(GameState.trajectory)
	_launch_slider.set_value_no_signal(rad_to_deg(GameState.plan.launch_angle_radians))
	_launch_value.text = "%.1f°" % rad_to_deg(GameState.plan.launch_angle_radians)
	var pulse: Pulse = _selected_pulse()
	var allocation: BurnAllocation = _allocation_for(_selected_pulse_id)
	var can_set_magnitude: bool = pulse != null and allocation != null and not allocation.starts_with_solid
	_magnitude_number.visible = can_set_magnitude
	_magnitude_slider.visible = can_set_magnitude
	_delete_button.disabled = GameState.has_launched or pulse == null
	_hint.text = "Click the orbit" if _is_placing_pulse else ("Click path to add" if pulse == null else "Pulse %d · Δv" % pulse.pulse_id)
	_inspector_label.text = "Select a pulse to edit" if pulse == null else ("Solid motor · full burn" if allocation != null and allocation.starts_with_solid else "Requested change in velocity")
	_add_button.disabled = GameState.has_launched or GameState.summary == null or GameState.summary.ascent == null or not GameState.summary.ascent.did_reach_initial_orbit
	_launch_slider.editable = not GameState.has_launched
	_magnitude_slider.editable = not GameState.has_launched
	_magnitude_number.editable = not GameState.has_launched
	if GameState.has_launched:
		_hint.text = "Plan locked in flight"
	if can_set_magnitude:
		var requested_delta_v_meters_per_second: float = pulse.requested_delta_v_meters_per_second()
		_magnitude_slider.set_block_signals(true)
		_magnitude_number.set_block_signals(true)
		_magnitude_slider.max_value = maxf(1000.0, requested_delta_v_meters_per_second * 1.5)
		_magnitude_number.max_value = _magnitude_slider.max_value
		_magnitude_slider.set_value_no_signal(requested_delta_v_meters_per_second)
		_magnitude_number.set_value_no_signal(requested_delta_v_meters_per_second)
		_magnitude_slider.set_block_signals(false)
		_magnitude_number.set_block_signals(false)
	_update_readouts()
	_update_engine_rows()
	_update_ghosts()
	_orbit_view.show_craft(allocation.before_state if allocation != null and allocation.before_state != null else (
			GameState.summary.ascent.orbit_entry_state if GameState.summary != null and GameState.summary.ascent != null else null))
	_overlay.queue_redraw()


func _update_readouts() -> void:
	if GameState.summary == null or GameState.trajectory == null or GameState.trajectory.final_segment() == null:
		_readouts.text = "Select a mission and build a rocket."
		return
	var summary: PlanSummary = GameState.summary
	var elements: OrbitElements = GameState.trajectory.final_segment().elements
	var radius_meters: float = _body.get("radius_meters", 0.0)
	var mass_kilograms: float = summary.mass_after_ascent_kilograms
	var mass_label := "after ascent"
	for pulse_index in GameState.plan.pulses.size():
		if GameState.plan.pulses[pulse_index].pulse_id == _selected_pulse_id and pulse_index < summary.mass_after_pulse_kilograms.size():
			mass_kilograms = summary.mass_after_pulse_kilograms[pulse_index]
			mass_label = "after pulse %d" % (pulse_index + 1)
	var shape: String = "CIRCULAR" if elements.eccentricity < 0.001 else "ecc %.3f" % elements.eccentricity
	var apoapsis: String = "OPEN" if elements.is_open else "%.0f km" % ((elements.apoapsis_radius_meters - radius_meters) / 1000.0)
	var period: String = "—" if elements.is_open else "%.1f min" % (elements.period_seconds / 60.0)
	_readouts.text = "Apo %s  ·  Peri %.0f km  ·  %s  ·  Period %s\nReserve %.0f m/s  ·  Mass %s: %.1f kg" % [
			apoapsis, (elements.periapsis_radius_meters - radius_meters) / 1000.0, shape, period,
			summary.reserve_delta_v_meters_per_second, mass_label, mass_kilograms]
	var allocation: BurnAllocation = _allocation_for(_selected_pulse_id)
	if allocation != null and allocation.outcome.did_fire:
		_readouts.text += "  ·  Delivered %.0f m/s" % allocation.outcome.delta_v_delivered_meters_per_second
	if summary.ascent != null and summary.ascent.failure_reason != "":
		_readouts.text = summary.ascent.failure_reason + "\nMass after ascent: %.1f kg · Reserve %.0f m/s" % [mass_kilograms, summary.reserve_delta_v_meters_per_second]


func _update_engine_rows() -> void:
	for child in _engine_rows.get_children():
		_engine_rows.remove_child(child)
		child.queue_free()
	for stage_index in GameState.design.stages.size():
		var stage: Stage = GameState.design.stages[stage_index]
		var engine: Dictionary = GameData.part(stage.engine_part_id)
		var used_kilograms := 0.0
		var left_kilograms: float = RocketModel.full_propellant_kilograms(stage)
		var reserve_meters_per_second := 0.0
		var is_separated := false
		var has_shortfall := false
		var is_selected := false
		if GameState.summary != null:
			reserve_meters_per_second = GameState.summary.delta_v_remaining_by_stage.get(stage.stage_id, 0.0)
			if GameState.summary.ascent != null:
				var ascent: AscentResult = GameState.summary.ascent
				used_kilograms = ascent.propellant_used_by_stage_kilograms.get(stage.stage_id, 0.0)
				left_kilograms = ascent.propellant_remaining_by_stage_kilograms.get(stage.stage_id, 0.0)
				is_separated = ascent.vehicle_state.is_jettisoned_by_stage.get(stage.stage_id, false)
			for allocation in GameState.summary.pulse_allocations:
				if allocation != null and allocation.stage_ids.has(stage.stage_id) and not allocation.is_satisfied:
					has_shortfall = true
		var selected: BurnAllocation = _allocation_for(_selected_pulse_id)
		is_selected = selected != null and selected.stage_ids.has(stage.stage_id)
		var color: Color = ScreenLayout.COLOR_WARNING_RED if has_shortfall else OrbitView.stage_color(stage.stage_id)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card_style: StyleBoxFlat = PlanningStyle.panel_style(ScreenLayout.COLOR_PANEL_DARK_BLUE, color if is_selected else ScreenLayout.COLOR_MONITOR_FRAME)
		card_style.border_width_left = 3 if is_selected else 1
		card.add_theme_stylebox_override("panel", card_style)
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 2)
		card.add_child(lines)
		var title: String = "%d %s" % [stage_index + 1, str(engine.get("name", "Missing engine")).split("(")[0].strip_edges().replace(" engine", "").replace(" motor", "")]
		_stage_line(lines, title, color, 10)
		_stage_line(lines, ("SOLID" if SequentialPropulsion.is_solid(stage) else "LIQUID") + ("\nSEPARATED" if is_separated else ""), Color("#d2dce7"), 9)
		var capacity_kilograms: float = RocketModel.full_propellant_kilograms(stage)
		var used_percent: float = 100.0 * used_kilograms / capacity_kilograms if capacity_kilograms > 0.0 else 0.0
		_stage_line(lines, "Ascent %.0f%%\n%.0f kg used" % [used_percent, used_kilograms], Color("#e4eaf0"), 9)
		_stage_line(lines, "%.0f kg left" % left_kilograms, Color("#e4eaf0"), 9)
		_stage_line(lines, "%.0f m/s" % reserve_meters_per_second, color, 10)
		card.tooltip_text = str(engine.get("name", "Engine")) + "\nFuel left is after ascent. Reserve accounts for all reachable planned pulses. Stages fire in order."
		_engine_rows.add_child(card)


func _stage_line(parent: VBoxContainer, caption: String, color: Color, font_size_pixels: int) -> void:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size_pixels)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)


func _update_ghosts() -> void:
	var allocation: BurnAllocation = _allocation_for(_selected_pulse_id)
	_orbit_view.show_ghosts(allocation.before_state if allocation != null else null,
			allocation.after_state if allocation != null else null, _drag_snapshot)


func _pulse_position(pulse: Pulse, allocation: BurnAllocation) -> Vector2:
	if allocation != null and allocation.before_state != null:
		return _orbit_view.world_to_screen(allocation.before_state.position_x_meters, allocation.before_state.position_y_meters)
	var radius_pixels: float = minf(_orbit_view.body_radius_pixels + 24.0, _orbit_view.size.y / 2.0 - 15.0)
	return _orbit_view.size / 2.0 + Vector2(cos(pulse.polar_angle_radians), -sin(pulse.polar_angle_radians)) * radius_pixels


func _arrow_end(pulse: Pulse, allocation: BurnAllocation) -> Vector2:
	var magnitude_meters_per_second: float = allocation.outcome.delta_v_delivered_meters_per_second if allocation != null and allocation.outcome.did_fire else pulse.requested_delta_v_meters_per_second()
	return _pulse_position(pulse, allocation) + PulseGeometry.arrow_direction(
			_orbit_view, allocation.before_state if allocation != null else null, pulse) * PulseGeometry.arrow_length_pixels(magnitude_meters_per_second)


func _pick_pulse(position_pixels: Vector2) -> Dictionary:
	for pulse in GameState.plan.pulses:
		var allocation: BurnAllocation = _allocation_for(pulse.pulse_id)
		if position_pixels.distance_to(_arrow_end(pulse, allocation)) <= 8.0:
			return {"pulse": pulse, "part": "arrow"}
		if position_pixels.distance_to(_pulse_position(pulse, allocation)) <= 9.0:
			return {"pulse": pulse, "part": "anchor"}
	return {}


func _draw_overlay() -> void:
	var font: Font = ThemeDB.fallback_font
	if _has_hover_point:
		_overlay.draw_arc(_hover_point_pixels, 6.0, 0.0, TAU, 24, Color("#8be7e6"), 1.0, true)
	for pulse_index in GameState.plan.pulses.size():
		var pulse: Pulse = GameState.plan.pulses[pulse_index]
		var allocation: BurnAllocation = _allocation_for(pulse.pulse_id)
		var anchor_pixels: Vector2 = _pulse_position(pulse, allocation)
		var end_pixels: Vector2 = _arrow_end(pulse, allocation)
		var color: Color = OrbitView.stage_color(allocation.last_stage_id()) if allocation != null else Color.WHITE
		if allocation == null or allocation.before_state == null or not allocation.is_satisfied:
			color = ScreenLayout.COLOR_WARNING_RED
		_overlay.draw_line(anchor_pixels, end_pixels, color, 2.0, true)
		var arrow_direction: Vector2 = (end_pixels - anchor_pixels).normalized()
		_overlay.draw_line(end_pixels, end_pixels - arrow_direction.rotated(0.5) * 6.0, color, 2.0, true)
		_overlay.draw_line(end_pixels, end_pixels - arrow_direction.rotated(-0.5) * 6.0, color, 2.0, true)
		_overlay.draw_circle(anchor_pixels, 4.0, color)
		if pulse.pulse_id == _selected_pulse_id:
			_overlay.draw_arc(anchor_pixels, 8.0, 0.0, TAU, 24, Color.WHITE, 1.5, true)
		var chain: String = allocation.stage_chain(GameState.design) if allocation != null else ""
		_overlay.draw_string(font, anchor_pixels + Vector2(7, -8), "%d · %s" % [pulse_index + 1, chain if chain != "" else "UNREACHED"],
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, color)
	if GameState.summary != null and GameState.summary.ascent != null:
		var ascent: AscentResult = GameState.summary.ascent
		_draw_ascent_marker(ascent.departure_state, ascent.departure, "DEPART", font, Vector2(7, 13))
		_draw_ascent_marker(ascent.insertion.before_state, ascent.insertion, "INSERT", font, Vector2(-85, 21))


func _draw_ascent_marker(state: OrbitState, allocation: BurnAllocation, caption: String, font: Font, offset_pixels: Vector2) -> void:
	if state == null or allocation.stage_ids.is_empty():
		return
	var position_pixels: Vector2 = _orbit_view.world_to_screen(state.position_x_meters, state.position_y_meters)
	var color: Color = OrbitView.stage_color(allocation.last_stage_id())
	_overlay.draw_rect(Rect2(position_pixels - Vector2(3, 3), Vector2(6, 6)), color, false, 1.0)
	_overlay.draw_string(font, position_pixels + offset_pixels, caption + " " + allocation.stage_chain(GameState.design), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, color)


func _tooltip_at(position_pixels: Vector2) -> String:
	var hit: Dictionary = _pick_pulse(position_pixels)
	if not hit.is_empty():
		var pulse: Pulse = hit["pulse"]
		var allocation: BurnAllocation = _allocation_for(pulse.pulse_id)
		return "Drag the point to move; drag the arrow to steer. Right-click to delete. Shift-click adds a coincident pulse.\n" + _describe_allocation("Pulse", allocation)
	if GameState.summary != null and GameState.summary.ascent != null:
		var ascent: AscentResult = GameState.summary.ascent
		for marker: Dictionary in [{"state": ascent.departure_state, "allocation": ascent.departure, "name": "Departure"},
				{"state": ascent.insertion.before_state, "allocation": ascent.insertion, "name": "Insertion"}]:
			var state: OrbitState = marker["state"]
			if state != null and position_pixels.distance_to(_orbit_view.world_to_screen(state.position_x_meters, state.position_y_meters)) < 15.0:
				return _describe_allocation(marker["name"], marker["allocation"])
	return ""


func _describe_allocation(caption: String, allocation: BurnAllocation) -> String:
	if allocation == null:
		return caption + ": unreachable"
	var text: String = "%s: requested %.1f m/s; delivered %.1f m/s" % [
			caption, allocation.requested_delta_v_meters_per_second, allocation.outcome.delta_v_delivered_meters_per_second]
	if allocation.starts_with_solid:
		text = "%s: complete solid motor; delivered %.1f m/s" % [caption, allocation.outcome.delta_v_delivered_meters_per_second]
	for stage_index in allocation.stage_ids.size():
		var outcome: BurnOutcome = allocation.stage_outcomes[stage_index]
		text += "\nStage %d: %.1f kg, %.1f m/s" % [SequentialPropulsion.stage_number(GameState.design, allocation.stage_ids[stage_index]), outcome.propellant_used_kilograms, outcome.delta_v_delivered_meters_per_second]
	if allocation.blocking_reason != "":
		text += "\n" + allocation.blocking_reason
	return text


func _on_add_toggled(is_pressed: bool) -> void:
	if not _can_edit():
		return
	_is_placing_pulse = is_pressed
	_hint.text = "Click the orbit" if is_pressed else "Click path to add"


func _clear_hover() -> void:
	_has_hover_point = false
	_overlay.queue_redraw()


func _can_edit() -> bool:
	return not GameState.has_launched and is_visible_in_tree() and get_global_rect().intersects(get_viewport_rect())
