class_name PulseGeometry
extends RefCounted
## Drawing/picking conversions for the locally stretched display and V/B arrows.


## A normalized control-local screen direction for a pulse at its pre-burn state.
static func arrow_direction(view: OrbitView, state: OrbitState, pulse: Pulse) -> Vector2:
	if state == null or state.speed_meters_per_second() <= 0.0:
		return Vector2.RIGHT
	var along := Vector2(state.velocity_x_meters_per_second, state.velocity_y_meters_per_second).normalized()
	var motion_sign: float = -1.0 if Kepler.signed_angular_momentum(state) < 0.0 else 1.0
	var outward := Vector2(along.y, -along.x) * motion_sign
	var world_direction: Vector2 = along * pulse.delta_v_along_velocity_meters_per_second + outward * pulse.delta_v_outward_meters_per_second
	return _project(view, state, world_direction, false).normalized()


## Unit V/B components corresponding to a dragged screen direction.
static func components_from_direction(view: OrbitView, state: OrbitState, direction_pixels: Vector2) -> Vector2:
	if state == null or state.speed_meters_per_second() <= 0.0:
		return Vector2.RIGHT
	var world_direction: Vector2 = _project(view, state, direction_pixels, true).normalized()
	var along := Vector2(state.velocity_x_meters_per_second, state.velocity_y_meters_per_second).normalized()
	var motion_sign: float = -1.0 if Kepler.signed_angular_momentum(state) < 0.0 else 1.0
	var outward := Vector2(along.y, -along.x) * motion_sign
	return Vector2(world_direction.dot(along), world_direction.dot(outward))


## Arrow length in pixels, with logarithmic magnitude compression and no fuel cap.
static func arrow_length_pixels(delta_v_meters_per_second: float) -> float:
	return 10.0 + 13.0 * log(1.0 + maxf(0.0, delta_v_meters_per_second) / 100.0)


## Requested delta-v in m/s corresponding to a dragged arrow length.
static func magnitude_from_length(length_pixels: float) -> float:
	return 100.0 * (exp(clampf((length_pixels - 10.0) / 13.0, 0.0, 50.0)) - 1.0)


static func _project(view: OrbitView, state: OrbitState, vector: Vector2, is_inverse: bool) -> Vector2:
	var radial := Vector2(state.position_x_meters / state.radius_meters(), state.position_y_meters / state.radius_meters())
	var tangent := Vector2(-radial.y, radial.x)
	var radius_pixels: float = view.world_to_screen(state.position_x_meters, state.position_y_meters).distance_to(view.size / 2.0)
	var radial_scale: float = view.pixels_per_kilometer / 1000.0
	var tangent_scale: float = maxf(0.000000001, radius_pixels / state.radius_meters())
	if is_inverse:
		var world_screen := Vector2(vector.x, -vector.y)
		return radial * (world_screen.dot(radial) / radial_scale) + tangent * (world_screen.dot(tangent) / tangent_scale)
	var transformed: Vector2 = radial * vector.dot(radial) * radial_scale + tangent * vector.dot(tangent) * tangent_scale
	return Vector2(transformed.x, -transformed.y)
