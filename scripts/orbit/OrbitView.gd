class_name OrbitView
extends Control
## Read-only, size-independent orbit display. World physics remains in 64-bit SI floats.

const PATH_SAMPLE_POINT_COUNT := 160
const REFERENCE_SIZE_PIXELS := Vector2(465.0, 295.0)
const STAGE_COLORS: Array[Color] = [Color("#64d7fb"), Color("#ffc565"), Color("#b992ff"), Color("#77e9a0"), Color("#fda5c1")]

var body_radius_pixels: float = 90.0
var pixels_per_kilometer: float = 0.06
var _body: Dictionary = {}
var _mission: Dictionary = {}
var _trajectory: Trajectory
var _craft_state: OrbitState
var _threats: Array[Threat] = []
var _curves: Array[Dictionary] = []
var _earth_texture: AtlasTexture
var _ghost_before := PackedFloat64Array()
var _ghost_after := PackedFloat64Array()
var _drag_curves: Array[PackedFloat64Array] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_earth_texture = AtlasTexture.new()
	_earth_texture.atlas = preload("res://design/orbit_screen.png")
	_earth_texture.region = Rect2(37, 29, 33, 31)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(_resize_display)
	_resize_display()


## Sets the body and complete mission, including scale, rings, zones and launch site.
func configure(body: Dictionary, mission: Dictionary) -> void:
	_body = body
	_mission = mission
	_resize_display()


## Pass null to clear the path. Sampling happens only when the trajectory changes.
func show_trajectory(trajectory: Trajectory) -> void:
	_trajectory = trajectory
	_curves.clear()
	if _trajectory != null and not _body.is_empty():
		for segment in _trajectory.segments:
			_curves.append({"segment": segment, "world_points": _sample_segment(segment)})
	queue_redraw()


## Pass null to hide the craft.
func show_craft(craft_state: OrbitState) -> void:
	_craft_state = craft_state
	queue_redraw()


## Shows only threats whose is_revealed flag is true.
func show_threats(threats: Array[Threat]) -> void:
	_threats = threats
	queue_redraw()


## Where a true position in metres is drawn in control-local pixels.
func world_to_screen(position_x_meters: float, position_y_meters: float) -> Vector2:
	var radius_meters: float = sqrt(position_x_meters * position_x_meters + position_y_meters * position_y_meters)
	var angle_radians: float = atan2(position_y_meters, position_x_meters)
	var altitude_kilometers: float = (radius_meters - float(_body.get("radius_meters", 1.0))) / 1000.0
	var radius_pixels: float = body_radius_pixels + pixels_per_kilometer * altitude_kilometers
	return size / 2.0 + Vector2(cos(angle_radians), -sin(angle_radians)) * radius_pixels


## Inertial polar angle in radians for a control-local pixel position.
func screen_to_polar_angle_radians(screen_position: Vector2) -> float:
	var offset_pixels: Vector2 = screen_position - size / 2.0
	return atan2(-offset_pixels.y, offset_pixels.x)


## True radius in metres for a control-local pixel position.
func screen_to_radius_meters(screen_position: Vector2) -> float:
	var radius_pixels: float = (screen_position - size / 2.0).length()
	return float(_body.get("radius_meters", 1.0)) + 1000.0 * (radius_pixels - body_radius_pixels) / pixels_per_kilometer


## Sets selected-pulse full-orbit ghosts and a fixed drag-start trajectory.
func show_ghosts(before_state: OrbitState, after_state: OrbitState, drag_trajectory: Trajectory) -> void:
	_ghost_before = _sample_full(before_state)
	_ghost_after = _sample_full(after_state)
	_drag_curves.clear()
	if drag_trajectory != null:
		for segment in drag_trajectory.segments:
			_drag_curves.append(_sample_segment(segment))
	queue_redraw()


## Returns a manual coast segment near a local pixel position, or an empty Dictionary.
func pick_path(screen_position: Vector2, tolerance_pixels: float = 9.0) -> Dictionary:
	var result: Dictionary = {}
	var best_distance_pixels: float = tolerance_pixels
	for curve in _curves:
		var segment: TrajectorySegment = curve["segment"]
		if segment.is_automatic_ascent:
			continue
		var points: PackedFloat64Array = curve["world_points"]
		for point_index in range(0, points.size() - 2, 2):
			if not _is_visible_world_point(points[point_index], points[point_index + 1]) or not _is_visible_world_point(points[point_index + 2], points[point_index + 3]):
				continue
			var first_pixels: Vector2 = world_to_screen(points[point_index], points[point_index + 1])
			var second_pixels: Vector2 = world_to_screen(points[point_index + 2], points[point_index + 3])
			var closest_pixels: Vector2 = Geometry2D.get_closest_point_to_segment(screen_position, first_pixels, second_pixels)
			var distance_pixels: float = screen_position.distance_to(closest_pixels)
			if distance_pixels <= best_distance_pixels:
				best_distance_pixels = distance_pixels
				result = {"segment": segment, "position_pixels": closest_pixels}
	return result


## Stable stage colour shared with engine rows and pulse markers.
static func stage_color(stage_id: int) -> Color:
	return Color.WHITE if stage_id <= 0 else STAGE_COLORS[(stage_id - 1) % STAGE_COLORS.size()]


func _resize_display() -> void:
	var scale_factor: float = maxf(0.001, minf(size.x / REFERENCE_SIZE_PIXELS.x, size.y / REFERENCE_SIZE_PIXELS.y))
	var display: Dictionary = _mission.get("display", {})
	body_radius_pixels = maxf(1.0, float(display.get("body_radius_pixels", 90.0)) * scale_factor)
	pixels_per_kilometer = maxf(0.000001, float(display.get("pixels_per_kilometer", 0.06)) * scale_factor)
	queue_redraw()


func _sample_segment(segment: TrajectorySegment) -> PackedFloat64Array:
	if segment.start_state == null or segment.start_state.speed_meters_per_second() <= 0.0:
		return PackedFloat64Array()
	if segment.elements != null and segment.elements.periapsis_radius_meters <= 0.0:
		return PackedFloat64Array()
	return OrbitModel.sample_segment_points(_body, segment, PATH_SAMPLE_POINT_COUNT)


func _sample_full(state: OrbitState) -> PackedFloat64Array:
	if state == null or _body.is_empty() or state.speed_meters_per_second() <= 0.0:
		return PackedFloat64Array()
	var elements: OrbitElements = Kepler.elements_from_state(_body[AscentPlanner.GRAVITATIONAL_PARAMETER_KEY], state)
	if elements.periapsis_radius_meters <= 0.0:
		return PackedFloat64Array()
	return OrbitModel.sample_full_orbit_points(_body, state, PATH_SAMPLE_POINT_COUNT)


func _is_visible_world_point(position_x_meters: float, position_y_meters: float) -> bool:
	return is_finite(position_x_meters) and is_finite(position_y_meters) and sqrt(
			position_x_meters * position_x_meters + position_y_meters * position_y_meters) >= float(_body.get("radius_meters", 1.0)) - 0.01


func _draw_curve(points: PackedFloat64Array, color: Color, width_pixels: float, is_dashed: bool = false) -> void:
	var previous_pixels := Vector2.ZERO
	var has_previous := false
	for point_index in range(0, points.size(), 2):
		if not _is_visible_world_point(points[point_index], points[point_index + 1]):
			has_previous = false
			continue
		var pixels: Vector2 = world_to_screen(points[point_index], points[point_index + 1])
		if has_previous and (not is_dashed or (point_index / 2) % 3 != 0):
			draw_line(previous_pixels, pixels, color, width_pixels, true)
		previous_pixels = pixels
		has_previous = true


func _draw_zone(zone: Dictionary, is_hazard: bool) -> void:
	if zone.get("type", "") != "altitude_band":
		return
	var inner_pixels: float = body_radius_pixels + pixels_per_kilometer * float(zone.get("inner_altitude_kilometers", 0.0))
	var outer_pixels: float = body_radius_pixels + pixels_per_kilometer * float(zone.get("outer_altitude_kilometers", 0.0))
	if outer_pixels <= inner_pixels:
		return
	var color := Color(0.95, 0.2, 0.12, 0.045) if is_hazard else Color(0.3, 0.85, 0.65, 0.07)
	draw_arc(size / 2.0, (inner_pixels + outer_pixels) * 0.5, 0.0, TAU, 128, color, outer_pixels - inner_pixels, true)
	var edge_color := Color(0.9, 0.3, 0.2, 0.24) if is_hazard else Color(0.3, 0.8, 0.65, 0.4)
	draw_arc(size / 2.0, inner_pixels, 0.0, TAU, 128, edge_color, 1.0, true)
	draw_arc(size / 2.0, outer_pixels, 0.0, TAU, 128, edge_color, 1.0, true)
	if is_hazard:
		for hatch_index in 64:
			var angle_radians: float = TAU * float(hatch_index) / 64.0
			draw_line(size / 2.0 + Vector2(cos(angle_radians), sin(angle_radians)) * inner_pixels,
					size / 2.0 + Vector2(cos(angle_radians + 0.08), sin(angle_radians + 0.08)) * outer_pixels, edge_color, 1.0, true)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ScreenLayout.COLOR_SPACE_BLACK)
	if _body.is_empty():
		return
	if _earth_texture != null:
		draw_texture_rect(_earth_texture, Rect2(size / 2.0 - Vector2.ONE * body_radius_pixels, Vector2.ONE * body_radius_pixels * 2.0), false)
	var font: Font = ThemeDB.fallback_font
	for science: Dictionary in _mission.get("science_missions", []):
		_draw_zone(science.get("zone", {}), false)
	for hazard: Dictionary in _mission.get("hazard_zones", []):
		_draw_zone(hazard, true)
	var ring_index := 0
	for altitude_kilometers in _mission.get("display", {}).get("altitude_ring_kilometers", []):
		var radius_pixels: float = body_radius_pixels + pixels_per_kilometer * float(altitude_kilometers)
		draw_arc(size / 2.0, radius_pixels, 0.0, TAU, 128, Color(0.4, 0.6, 0.75, 0.3), 1.0, true)
		var label_angle_radians: float = -0.45 + float(ring_index) * 0.45
		ring_index += 1
		draw_string(font, size / 2.0 + Vector2(cos(label_angle_radians), sin(label_angle_radians)) * radius_pixels + Vector2(4, 3), "%d km" % altitude_kilometers,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#8aa5b6"))
	for ghost in _drag_curves:
		_draw_curve(ghost, Color(0.8, 0.85, 1.0, 0.2), 1.0)
	_draw_curve(_ghost_before, Color(0.9, 0.9, 1.0, 0.25), 1.0, true)
	_draw_curve(_ghost_after, Color(0.9, 0.9, 1.0, 0.65), 1.0, true)
	for curve_index in _curves.size():
		var curve: Dictionary = _curves[curve_index]
		var segment: TrajectorySegment = curve["segment"]
		var color: Color = stage_color(segment.source_stage_id)
		if _trajectory.status in [Trajectory.Status.IMPACT, Trajectory.Status.ESCAPE] or (
				_trajectory.status == Trajectory.Status.UNREACHABLE_PULSE and curve_index == _curves.size() - 1):
			color = ScreenLayout.COLOR_WARNING_RED
		elif curve_index < _curves.size() - 1:
			color = color.darkened(0.4)
		_draw_curve(curve["world_points"], color, 2.0 if curve_index == _curves.size() - 1 else 1.4)
	var launch_angle_radians: float = deg_to_rad(_mission.get("launch_site", {}).get("polar_angle_degrees", 90.0))
	var launch_pixels: Vector2 = size / 2.0 + Vector2(cos(launch_angle_radians), -sin(launch_angle_radians)) * body_radius_pixels
	draw_circle(launch_pixels, 3.0, Color("#ffd78d"))
	draw_string(font, launch_pixels + Vector2(6, -5), "LAUNCH", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#ffd78d"))
	if _trajectory != null and _trajectory.final_segment() != null:
		_draw_apsides(_trajectory.final_segment().elements, font)
	for threat in _threats:
		if threat.is_revealed and threat.state != null:
			draw_circle(world_to_screen(threat.state.position_x_meters, threat.state.position_y_meters), 3.0, ScreenLayout.COLOR_WARNING_RED)
	if _craft_state != null:
		var craft_pixels: Vector2 = world_to_screen(_craft_state.position_x_meters, _craft_state.position_y_meters)
		draw_circle(craft_pixels, 3.5, Color.WHITE)
	var warning := ""
	if _trajectory != null:
		match _trajectory.status:
			Trajectory.Status.IMPACT:
				warning = "ATMOSPHERIC IMPACT"
			Trajectory.Status.ESCAPE:
				warning = "YOU ARE LEAVING EARTH ORBIT"
			Trajectory.Status.UNREACHABLE_PULSE:
				warning = "PULSE %d UNREACHABLE" % (_trajectory.first_unreachable_pulse_index + 1)
	if warning != "":
		draw_string(font, Vector2(8, size.y - 10.0), warning, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, 11, ScreenLayout.COLOR_WARNING_RED)


func _draw_apsides(elements: OrbitElements, font: Font) -> void:
	if elements == null or elements.eccentricity < 0.001 or elements.periapsis_radius_meters <= 0.0:
		return
	var sign_of_motion: float = -1.0 if elements.is_clockwise else 1.0
	var periapsis_angle_radians: float = sign_of_motion * elements.argument_of_periapsis_radians
	for is_apoapsis in [false, true]:
		if is_apoapsis and elements.is_open:
			continue
		var angle_radians: float = periapsis_angle_radians + (PI if is_apoapsis else 0.0)
		var radius_meters: float = elements.apoapsis_radius_meters if is_apoapsis else elements.periapsis_radius_meters
		if radius_meters < float(_body["radius_meters"]):
			continue
		var position_pixels: Vector2 = world_to_screen(radius_meters * cos(angle_radians), radius_meters * sin(angle_radians))
		draw_circle(position_pixels, 2.5, Color("#e2e5eb"))
		draw_string(font, position_pixels + Vector2(5, -4), "A" if is_apoapsis else "P", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#e2e5eb"))
