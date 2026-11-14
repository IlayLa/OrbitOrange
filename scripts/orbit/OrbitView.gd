class_name OrbitView
extends Control
## A display of the central body, a flight path, the craft and any threats.
## It only shows things: it has no buttons and changes no game state, so the
## planning overview, the orbit planning screen and the emergency overlay can
## all use it at any size.
##
## Altitude is exaggerated so that a low orbit is visible. A point at true
## distance radius_meters from the body's centre is drawn at
##     body_radius_pixels + pixels_per_kilometer * altitude in kilometres
## from the centre of this control, in the same direction. Because of this
## stretch the paths are drawn as lines through sampled points, never as ellipses.
##
## STUB(T05): the public functions are final. The drawing is minimal (body,
## path, craft, threats). T05 adds altitude rings, zones, pulse arrows and colours.

const PATH_SAMPLE_POINT_COUNT := 96

var body_radius_pixels: float = 90.0
var pixels_per_kilometer: float = 0.06

var _body: Dictionary = {}
var _trajectory: Trajectory
var _craft_state: OrbitState
var _threats: Array[Threat] = []


## Sets the body to draw and the display scale, from the mission's "display" entry.
func configure(body: Dictionary, mission: Dictionary) -> void:
	_body = body
	var display_settings: Dictionary = mission.get("display", {})
	body_radius_pixels = display_settings.get("body_radius_pixels", body_radius_pixels)
	pixels_per_kilometer = display_settings.get("pixels_per_kilometer", pixels_per_kilometer)
	queue_redraw()


## Pass null to clear the path.
func show_trajectory(trajectory: Trajectory) -> void:
	_trajectory = trajectory
	queue_redraw()


## Pass null to hide the craft.
func show_craft(craft_state: OrbitState) -> void:
	_craft_state = craft_state
	queue_redraw()


func show_threats(threats: Array[Threat]) -> void:
	_threats = threats
	queue_redraw()


## Where a true position (metres from the body's centre) is drawn in this control.
func world_to_screen(position_x_meters: float, position_y_meters: float) -> Vector2:
	var radius_meters: float = sqrt(position_x_meters * position_x_meters + position_y_meters * position_y_meters)
	var polar_angle_radians: float = atan2(position_y_meters, position_x_meters)
	var body_radius_meters: float = _body.get("radius_meters", 1.0)
	var altitude_kilometers: float = (radius_meters - body_radius_meters) / 1000.0
	var drawn_radius_pixels: float = body_radius_pixels + pixels_per_kilometer * altitude_kilometers
	# The screen's y axis points down, so the sine is negated to keep
	# counter-clockwise orbits counter-clockwise on screen.
	return size / 2.0 + Vector2(cos(polar_angle_radians), -sin(polar_angle_radians)) * drawn_radius_pixels


## The inertial direction from the body that a point in this control lies in.
func screen_to_polar_angle_radians(screen_position: Vector2) -> float:
	var offset_from_center: Vector2 = screen_position - size / 2.0
	return atan2(-offset_from_center.y, offset_from_center.x)


## The true distance from the body's centre that a point in this control stands for.
func screen_to_radius_meters(screen_position: Vector2) -> float:
	var drawn_radius_pixels: float = (screen_position - size / 2.0).length()
	var altitude_kilometers: float = (drawn_radius_pixels - body_radius_pixels) / pixels_per_kilometer
	var body_radius_meters: float = _body.get("radius_meters", 1.0)
	return body_radius_meters + altitude_kilometers * 1000.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ScreenLayout.COLOR_SPACE_BLACK)
	if _body.is_empty():
		return
	draw_circle(size / 2.0, body_radius_pixels, ScreenLayout.COLOR_EARTH_OCEAN)

	if _trajectory != null:
		for segment in _trajectory.segments:
			_draw_segment(segment)

	for threat in _threats:
		if threat.is_revealed:
			var threat_screen_position: Vector2 = world_to_screen(
					threat.state.position_x_meters, threat.state.position_y_meters)
			draw_circle(threat_screen_position, 2.0, ScreenLayout.COLOR_WARNING_RED)

	if _craft_state != null:
		var craft_screen_position: Vector2 = world_to_screen(
				_craft_state.position_x_meters, _craft_state.position_y_meters)
		draw_circle(craft_screen_position, 3.0, ScreenLayout.COLOR_ACCENT_ORANGE)


func _draw_segment(segment: TrajectorySegment) -> void:
	var world_points: PackedFloat64Array = OrbitModel.sample_segment_points(
			_body, segment, PATH_SAMPLE_POINT_COUNT)
	var screen_points := PackedVector2Array()
	for point_index in range(0, world_points.size(), 2):
		screen_points.append(world_to_screen(world_points[point_index], world_points[point_index + 1]))
	if screen_points.size() >= 2:
		draw_polyline(screen_points, ScreenLayout.COLOR_TEXT_LIGHT, 1.0)
