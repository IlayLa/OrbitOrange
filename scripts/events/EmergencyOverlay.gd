extends Control
## Keeps the flight paused while the player edits an immediate maneuver.

const MAX_ARROW_PIXELS := 74.0
const FIRST_PREVIEW_METERS_PER_SECOND := 8.0
const THREAT_COLOR := Color("ff8069")
const CANDIDATE_COLOR := Color("69e2c4")
const WARNING_COLOR := Color("ffc080")
const TEXT_COLOR := Color("e4eef8")
const TRACK_STEPS := 64

var _flight: Node
var _mission: Dictionary
var _body: Dictionary
var _threat: Threat
var _event_type_name: String
var _encounter_end_seconds: float
var _on_execute: Callable
var _on_ignore: Callable
var _craft: OrbitState
var _baseline: Dictionary
var _candidate: Dictionary
var _threat_points := PackedFloat64Array()
var _candidate_points := PackedFloat64Array()
var _selected_stage_id := -1
var _available_delta_v_meters_per_second := 0.0
var _is_solid := false
var _preview_pulse: Pulse
var _dragging := false
var _resolved := false
var _burn_failed := false

@onready var _view: OrbitView = %OrbitMap
@onready var _tracks: Control = %Tracks
@onready var _stage: OptionButton = %Stage
@onready var _angle: SpinBox = %Angle
@onready var _strength: SpinBox = %Strength
@onready var _execute: Button = %Execute
@onready var _ignore: Button = %Ignore


func open_alert(
		flight: Node, mission: Dictionary, body: Dictionary, event_type_name: String,
		threat: Threat, encounter_end_seconds: float, on_execute: Callable, on_ignore: Callable) -> void:
	_flight = flight
	_mission = mission
	_body = body
	_event_type_name = event_type_name
	_threat = threat
	_encounter_end_seconds = encounter_end_seconds
	_on_execute = on_execute
	_on_ignore = on_ignore


func _ready() -> void:
	if _flight == null:
		return
	%Title.text = _event_type_name
	if _threat.event_type_id == "debris_shower":
		%Title.text += " · selected fragment"
	%Threshold.text = "Collision threshold   %s" % _distance_text(_threat.collision_radius_meters)
	_tracks.draw.connect(_draw_tracks)
	_tracks.resized.connect(_tracks.queue_redraw)
	_tracks.gui_input.connect(_on_map_input)
	_stage.item_selected.connect(_on_stage_selected)
	_angle.value_changed.connect(_on_maneuver_changed)
	_strength.value_changed.connect(_on_maneuver_changed)
	_execute.pressed.connect(_execute_maneuver)
	_ignore.pressed.connect(_ignore_encounter)
	_refresh_baseline()
	_refresh_stages(FIRST_PREVIEW_METERS_PER_SECOND)
	if _stage.disabled:
		_ignore.grab_focus()
	else:
		_stage.grab_focus()


func _exit_tree() -> void:
	_resolved = true
	_on_execute = Callable()
	_on_ignore = Callable()


func _unhandled_input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func _refresh_baseline() -> void:
	_craft = _flight.craft_state
	var now_seconds := _craft.time_seconds
	var baseline_trajectory: Trajectory = _flight.trajectory
	_baseline = ThreatModel.closest_approach(_body, baseline_trajectory, _threat, now_seconds, _encounter_end_seconds)
	var approach_time_seconds: float = _baseline.get("time_seconds", INF)
	%Approach.text = "Closest approach   in %.1f s" % maxf(0.0, approach_time_seconds - now_seconds) if is_finite(
			approach_time_seconds) else "Closest approach   —"
	var current_miss_meters: float = _baseline.get("distance_meters", INF)
	%CurrentMiss.text = "Current miss          %s" % _distance_text(current_miss_meters)
	%CurrentMiss.modulate = WARNING_COLOR if current_miss_meters <= _threat.collision_radius_meters else TEXT_COLOR

	var view_mission := _mission.duplicate()
	var display: Dictionary = _mission.get("display", {}).duplicate()
	display["body_radius_pixels"] = 67.0
	var altitude_kilometers := (_craft.radius_meters() - float(_body["radius_meters"])) / 1000.0
	display["pixels_per_kilometer"] = minf(
			display.get("pixels_per_kilometer", 0.06), 37.0 / maxf(altitude_kilometers, 800.0))
	view_mission["display"] = display
	_view.configure(_body, view_mission)
	_view.show_trajectory(baseline_trajectory)
	_view.show_craft(_craft)

	var visible_threat := Threat.new()
	visible_threat.threat_id = _threat.threat_id
	visible_threat.event_type_id = _threat.event_type_id
	visible_threat.state = ThreatModel.threat_state_at_time(_body, _threat, now_seconds)
	visible_threat.is_revealed = true
	_view.show_threats([visible_threat])
	_threat_points.clear()
	var path_end_seconds := minf(_encounter_end_seconds, ThreatModel.terminal_time_seconds(baseline_trajectory))
	for index in range(TRACK_STEPS + 1):
		var sample_time := lerpf(now_seconds, path_end_seconds, float(index) / TRACK_STEPS)
		var state := ThreatModel.threat_state_at_time(_body, _threat, sample_time)
		if state != null:
			_threat_points.append(state.position_x_meters)
			_threat_points.append(state.position_y_meters)


func _refresh_stages(preferred_strength_meters_per_second: float) -> void:
	_stage.clear()
	var vehicle: VehicleState = _flight.vehicle_state
	var selected_index := 0
	for index in vehicle.design.stages.size():
		var stage := vehicle.design.stages[index]
		var reserve_meters_per_second := RocketModel.available_delta_v_meters_per_second(vehicle, stage.stage_id)
		if reserve_meters_per_second <= 0.0:
			continue
		if stage.stage_id == _selected_stage_id:
			selected_index = _stage.item_count
		var engine_type: String = GameData.part(stage.engine_part_id).get("stats", {}).get("engine_type", "")
		_stage.add_item("Stage %d  ·  %s  ·  %.1f m/s" % [index + 1, engine_type, reserve_meters_per_second], stage.stage_id)
	_stage.disabled = _stage.item_count == 0
	if _stage.disabled:
		_stage.add_item("No stage available", -1)
	_stage.select(selected_index)
	_set_stage(preferred_strength_meters_per_second)


func _set_stage(preferred_strength_meters_per_second: float) -> void:
	_selected_stage_id = -1 if _stage.disabled else _stage.get_selected_id()
	_available_delta_v_meters_per_second = 0.0
	_is_solid = false
	%StageWarning.text = ""
	if _selected_stage_id >= 0:
		var vehicle: VehicleState = _flight.vehicle_state
		_available_delta_v_meters_per_second = RocketModel.available_delta_v_meters_per_second(vehicle, _selected_stage_id)
		var lower_stages := PackedStringArray()
		for index in vehicle.design.stages.size():
			var stage := vehicle.design.stages[index]
			if stage.stage_id == _selected_stage_id:
				var stats: Dictionary = GameData.part(stage.engine_part_id).get("stats", {})
				_is_solid = stats.get("engine_type", "") == "solid"
				break
			if not vehicle.is_jettisoned_by_stage.get(stage.stage_id, false):
				lower_stages.append(str(index + 1))
		if lower_stages.size() == 1:
			%StageWarning.text = "Firing drops stage %s." % lower_stages[0]
		elif lower_stages.size() > 1:
			%StageWarning.text = "Firing drops stages %s." % ", ".join(lower_stages)
	_angle.editable = _selected_stage_id >= 0
	_strength.editable = _selected_stage_id >= 0 and not _is_solid
	_strength.max_value = _available_delta_v_meters_per_second
	_strength.set_value_no_signal(_available_delta_v_meters_per_second if _is_solid else preferred_strength_meters_per_second)
	_rebuild_preview()
	_set_focus_order()


func _set_focus_order() -> void:
	var fields: Array[Control] = [_ignore]
	if not _stage.disabled:
		fields.append(_stage)
		fields.append(_angle.get_line_edit())
		if not _is_solid:
			fields.append(_strength.get_line_edit())
	if not _execute.disabled:
		fields.append(_execute)
	for index in fields.size():
		var previous := fields[posmod(index - 1, fields.size())]
		var next := fields[(index + 1) % fields.size()]
		var field := fields[index]
		field.focus_previous = field.get_path_to(previous)
		field.focus_next = field.get_path_to(next)
		field.focus_neighbor_left = field.focus_previous
		field.focus_neighbor_top = field.focus_previous
		field.focus_neighbor_right = field.focus_next
		field.focus_neighbor_bottom = field.focus_next


func _on_stage_selected(_index: int) -> void:
	var previous_strength_meters_per_second := FIRST_PREVIEW_METERS_PER_SECOND if _is_solid else _strength.value
	_burn_failed = false
	_set_stage(previous_strength_meters_per_second)


func _on_maneuver_changed(_value: float) -> void:
	_burn_failed = false
	_rebuild_preview()
	_set_focus_order()


func _rebuild_preview() -> void:
	_preview_pulse = null
	_candidate = {}
	_candidate_points.clear()
	var candidate_trajectory: Trajectory
	if _selected_stage_id >= 0:
		var magnitude_meters_per_second := _available_delta_v_meters_per_second if _is_solid else _strength.value
		if magnitude_meters_per_second > 0.0:
			_preview_pulse = EmergencyManeuver.create_pulse(_selected_stage_id, _angle.value, magnitude_meters_per_second)
			candidate_trajectory = EmergencyManeuver.preview_trajectory(
					_body, _craft, _flight.vehicle_state, _preview_pulse)
	_execute.disabled = candidate_trajectory == null or _resolved
	%CandidateMiss.text = "Preview miss         —"
	%CandidateMiss.modulate = TEXT_COLOR
	var terminal_message := ""
	if candidate_trajectory != null:
		var segment := candidate_trajectory.final_segment()
		_candidate_points = OrbitModel.sample_segment_points(_body, segment, 160)
		var boundary_seconds := ThreatModel.terminal_time_seconds(candidate_trajectory)
		if is_finite(boundary_seconds):
			var terminal_name := "Atmosphere impact" if segment.end_reason == TrajectorySegment.EndReason.IMPACT else "Escape"
			terminal_message = "%s in %.0f s." % [terminal_name, boundary_seconds - _craft.time_seconds]
		var known_approach_time_seconds: float = _baseline.get("time_seconds", _encounter_end_seconds)
		if boundary_seconds >= known_approach_time_seconds:
			_candidate = ThreatModel.closest_approach(
					_body, candidate_trajectory, _threat, _craft.time_seconds, _encounter_end_seconds)
			var distance_meters: float = _candidate.get("distance_meters", INF)
			%CandidateMiss.text = "Preview miss         %s" % _distance_text(distance_meters)
			%CandidateMiss.modulate = WARNING_COLOR if distance_meters <= _threat.collision_radius_meters else CANDIDATE_COLOR
	var notice := terminal_message
	if _burn_failed:
		notice = "Burn unavailable. Check the stage."
	elif _stage.disabled:
		notice = "No working stage has propellant."
	elif _planned_burn_precedes_encounter():
		notice = "A planned burn may occur before the pass." if notice.is_empty() else notice + " Planned burn pending."
	%Notice.text = notice
	_tracks.queue_redraw()


func _planned_burn_precedes_encounter() -> bool:
	var approach_time_seconds: float = _baseline.get("time_seconds", _encounter_end_seconds)
	for segment: TrajectorySegment in _flight.trajectory.segments:
		if (segment.end_reason == TrajectorySegment.EndReason.NEXT_BURN
				and _craft.time_seconds < segment.end_time_seconds
				and segment.end_time_seconds <= approach_time_seconds):
			return true
	return false


func _execute_maneuver() -> void:
	if _resolved or _preview_pulse == null or not _on_execute.is_valid():
		return
	var current_reserve_meters_per_second := RocketModel.available_delta_v_meters_per_second(
			_flight.vehicle_state, _preview_pulse.stage_id)
	if current_reserve_meters_per_second > 0.0:
		_resolved = true
		if _on_execute.call(_preview_pulse):
			hide()
			return
		_resolved = false
	_burn_failed = true
	_refresh_baseline()
	_refresh_stages(_strength.value)


func _ignore_encounter() -> void:
	if _resolved or not _on_ignore.is_valid():
		return
	_resolved = true
	_on_ignore.call()
	hide()


func _on_map_input(event: InputEvent) -> void:
	if _resolved or _selected_stage_id < 0:
		return
	var origin := _screen_position(_craft)
	var direction := _arrow_vector()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = (event.position.distance_to(origin) <= 17.0
					or event.position.distance_to(origin + direction) <= 14.0)
		else:
			_dragging = false
		_tracks.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_update_drag(event.position - origin)
		_tracks.accept_event()


func _update_drag(offset: Vector2) -> void:
	var along_axis := _projected_axis(1.0, 0.0)
	var outward_axis := _projected_axis(0.0, 1.0)
	var determinant := along_axis.cross(outward_axis)
	if not is_zero_approx(determinant) and offset.length() > 1.0:
		var along := offset.cross(outward_axis) / determinant
		var outward := along_axis.cross(offset) / determinant
		_angle.set_value_no_signal(rad_to_deg(atan2(outward, along)))
	if not _is_solid:
		var pull := clampf(offset.length() / MAX_ARROW_PIXELS, 0.0, 1.0)
		_strength.set_value_no_signal(pull * pull * _available_delta_v_meters_per_second)
	_on_maneuver_changed(0.0)


func _projected_axis(along: float, outward: float) -> Vector2:
	var rotated := Kepler.apply_pulse(_craft, along, outward)
	var velocity_change_x_meters_per_second := rotated.velocity_x_meters_per_second - _craft.velocity_x_meters_per_second
	var velocity_change_y_meters_per_second := rotated.velocity_y_meters_per_second - _craft.velocity_y_meters_per_second
	# A centred difference measures the local radial stretch in OrbitView.
	var plus := _view.world_to_screen(
			_craft.position_x_meters + 1000.0 * velocity_change_x_meters_per_second, _craft.position_y_meters + 1000.0 * velocity_change_y_meters_per_second)
	var minus := _view.world_to_screen(
			_craft.position_x_meters - 1000.0 * velocity_change_x_meters_per_second, _craft.position_y_meters - 1000.0 * velocity_change_y_meters_per_second)
	return plus - minus


func _arrow_vector() -> Vector2:
	if _preview_pulse == null or _available_delta_v_meters_per_second <= 0.0:
		return Vector2.ZERO
	var magnitude_meters_per_second := _preview_pulse.requested_delta_v_meters_per_second()
	var direction := _projected_axis(
			_preview_pulse.delta_v_along_velocity_meters_per_second / magnitude_meters_per_second,
			_preview_pulse.delta_v_outward_meters_per_second / magnitude_meters_per_second)
	return direction.normalized() * MAX_ARROW_PIXELS * sqrt(clampf(magnitude_meters_per_second / _available_delta_v_meters_per_second, 0.0, 1.0))


func _screen_position(state: OrbitState) -> Vector2:
	return _view.world_to_screen(state.position_x_meters, state.position_y_meters)


func _draw_tracks() -> void:
	if _craft == null:
		return
	_draw_path(_threat_points, THREAT_COLOR)
	_draw_path(_candidate_points, CANDIDATE_COLOR)
	_draw_approach(_baseline, THREAT_COLOR, 7.0)
	_draw_approach(_candidate, CANDIDATE_COLOR, 4.0)
	var start := _screen_position(_craft)
	_tracks.draw_circle(start, 7.0, Color("ffffff90"), false, 1.0, true)
	var arrow := _arrow_vector()
	if arrow.length() < 1.0:
		return
	var tip := start + arrow
	var backward := -arrow.normalized() * minf(8.0, arrow.length())
	_tracks.draw_line(start, tip, CANDIDATE_COLOR, 2.0, true)
	_tracks.draw_line(tip, tip + backward.rotated(0.5), CANDIDATE_COLOR, 2.0, true)
	_tracks.draw_line(tip, tip + backward.rotated(-0.5), CANDIDATE_COLOR, 2.0, true)


func _draw_path(world_points: PackedFloat64Array, color: Color) -> void:
	var screen_points := PackedVector2Array()
	for index in range(0, world_points.size(), 2):
		screen_points.append(_view.world_to_screen(world_points[index], world_points[index + 1]))
	if screen_points.size() >= 2:
		_tracks.draw_polyline(screen_points, color, 1.5, true)


func _draw_approach(approach: Dictionary, color: Color, marker_radius: float) -> void:
	if approach.is_empty():
		return
	var craft_position := _screen_position(approach["craft_state"])
	var threat_position := _screen_position(approach["threat_state"])
	_tracks.draw_line(craft_position, threat_position, color, 1.0, true)
	_tracks.draw_circle(threat_position, marker_radius, color, false, 1.25, true)


static func _distance_text(distance_meters: float) -> String:
	if not is_finite(distance_meters):
		return "—"
	if distance_meters >= 1000.0:
		return "%.2f km" % (distance_meters / 1000.0)
	return "%.1f m" % distance_meters
