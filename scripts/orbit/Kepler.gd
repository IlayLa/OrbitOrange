class_name Kepler
extends RefCounted
## Two-body orbit mathematics in two dimensions. Orbits only: nothing in this
## file knows about rockets, money or the screen.
##
## STUB(T01): the signatures below are final, but most bodies assume a circular
## orbit so that the rest of the game can run before task T01 is done.
## T01 replaces every body marked STUB with the real mathematics.
##
## Units: SI throughout. "gravitational_parameter" is always in cubic metres
## per second squared (for Earth about 3.986e14); it is the one name in the
## project that does not spell its unit out.

## Below this eccentricity an orbit is treated as circular (GMAT threshold).
const CIRCULAR_ECCENTRICITY_THRESHOLD := 1.0e-11
const STUB_ORBIT_ALTITUDE_METERS := 400000.0


## Speed of a circular orbit at the given distance from the body's centre.
static func circular_speed_meters_per_second(gravitational_parameter: float, radius_meters: float) -> float:
	return sqrt(gravitational_parameter / radius_meters)


## Time for one revolution of a closed orbit.
static func orbital_period_seconds(gravitational_parameter: float, semi_major_axis_meters: float) -> float:
	return TAU * sqrt(pow(semi_major_axis_meters, 3.0) / gravitational_parameter)


## Height above the body's surface.
static func altitude_meters(state: OrbitState, body: Dictionary) -> float:
	var body_radius_meters: float = body["radius_meters"]
	return state.radius_meters() - body_radius_meters


## Angle of the velocity above the local horizontal. Positive while climbing.
static func flight_path_angle_radians(state: OrbitState) -> float:
	var radial_component: float = (
			state.position_x_meters * state.velocity_x_meters_per_second
			+ state.position_y_meters * state.velocity_y_meters_per_second)
	var angular_momentum: float = signed_angular_momentum(state)
	return atan2(radial_component, absf(angular_momentum))


## Position crossed with velocity. Positive for counter-clockwise motion.
static func signed_angular_momentum(state: OrbitState) -> float:
	return (
			state.position_x_meters * state.velocity_y_meters_per_second
			- state.position_y_meters * state.velocity_x_meters_per_second)


## Orbit shape and orientation from a position and velocity.
## STUB(T01): pretends every orbit is a circle through the current position.
static func elements_from_state(gravitational_parameter: float, state: OrbitState) -> OrbitElements:
	var radius_meters: float = state.radius_meters()
	var elements := OrbitElements.new()
	elements.semi_major_axis_meters = radius_meters
	elements.eccentricity = 0.0
	elements.argument_of_periapsis_radians = 0.0
	elements.true_anomaly_radians = fposmod(state.polar_angle_radians(), TAU)
	elements.periapsis_radius_meters = radius_meters
	elements.apoapsis_radius_meters = radius_meters
	elements.period_seconds = orbital_period_seconds(gravitational_parameter, radius_meters)
	elements.specific_energy_joules_per_kilogram = -gravitational_parameter / (2.0 * radius_meters)
	elements.is_open = false
	elements.is_circular = true
	elements.is_clockwise = signed_angular_momentum(state) < 0.0
	return elements


## Position and velocity from orbit elements. The inverse of elements_from_state.
## STUB(T01): treats the orbit as a circle of radius semi_major_axis_meters.
static func state_from_elements(gravitational_parameter: float, elements: OrbitElements, time_seconds: float) -> OrbitState:
	var radius_meters: float = elements.semi_major_axis_meters
	var speed: float = circular_speed_meters_per_second(gravitational_parameter, radius_meters)
	var polar_angle: float = elements.argument_of_periapsis_radians + elements.true_anomaly_radians
	var direction_sign: float = -1.0 if elements.is_clockwise else 1.0
	return OrbitState.create(
			radius_meters * cos(polar_angle),
			radius_meters * sin(polar_angle),
			-direction_sign * speed * sin(polar_angle),
			direction_sign * speed * cos(polar_angle),
			time_seconds)


## The state after coasting for duration_seconds with no engine firing.
## STUB(T01): rotates the state around the body, which is exact only for a circle.
static func propagate(gravitational_parameter: float, state: OrbitState, duration_seconds: float) -> OrbitState:
	var radius_meters: float = state.radius_meters()
	var angular_rate_radians_per_second: float = signed_angular_momentum(state) / (radius_meters * radius_meters)
	var rotation_radians: float = angular_rate_radians_per_second * duration_seconds
	var rotation_cosine: float = cos(rotation_radians)
	var rotation_sine: float = sin(rotation_radians)
	return OrbitState.create(
			state.position_x_meters * rotation_cosine - state.position_y_meters * rotation_sine,
			state.position_x_meters * rotation_sine + state.position_y_meters * rotation_cosine,
			state.velocity_x_meters_per_second * rotation_cosine - state.velocity_y_meters_per_second * rotation_sine,
			state.velocity_x_meters_per_second * rotation_sine + state.velocity_y_meters_per_second * rotation_cosine,
			state.time_seconds + duration_seconds)


## An instant change of velocity. "Along velocity" speeds the craft up;
## "outward" is perpendicular to the motion, pointing away from the body
## (GMAT's V and B directions).
static func apply_pulse(
		state: OrbitState,
		delta_v_along_velocity_meters_per_second: float,
		delta_v_outward_meters_per_second: float) -> OrbitState:
	var new_state: OrbitState = state.duplicate_state()
	var speed: float = state.speed_meters_per_second()
	if speed == 0.0:
		return new_state
	var along_x: float = state.velocity_x_meters_per_second / speed
	var along_y: float = state.velocity_y_meters_per_second / speed
	var direction_sign: float = -1.0 if signed_angular_momentum(state) < 0.0 else 1.0
	var outward_x: float = direction_sign * along_y
	var outward_y: float = -direction_sign * along_x
	new_state.velocity_x_meters_per_second += (
			delta_v_along_velocity_meters_per_second * along_x
			+ delta_v_outward_meters_per_second * outward_x)
	new_state.velocity_y_meters_per_second += (
			delta_v_along_velocity_meters_per_second * along_y
			+ delta_v_outward_meters_per_second * outward_y)
	return new_state


## The state at the end of the launch burn: at the launch site on the surface,
## moving at burnout speed, launch_angle_radians above the local horizontal.
## STUB(T01): ignores the speed and angle and returns a 400 km circular orbit
## above the launch site, so that the stub flight always reaches orbit.
static func launch_state(
		body: Dictionary,
		launch_site_angle_radians: float,
		_burnout_speed_meters_per_second: float,
		_launch_angle_radians: float) -> OrbitState:
	var gravitational_parameter: float = body["gravitational_parameter_cubic_meters_per_second_squared"]
	var body_radius_meters: float = body["radius_meters"]
	var orbit_radius_meters: float = body_radius_meters + STUB_ORBIT_ALTITUDE_METERS
	var speed: float = circular_speed_meters_per_second(gravitational_parameter, orbit_radius_meters)
	return OrbitState.create(
			orbit_radius_meters * cos(launch_site_angle_radians),
			orbit_radius_meters * sin(launch_site_angle_radians),
			-speed * sin(launch_site_angle_radians),
			speed * cos(launch_site_angle_radians),
			0.0)


## Seconds until the object next crosses the given direction from the body,
## after waiting extra_revolutions full orbits. Returns INF when it never does
## (it hits the surface or escapes first).
## STUB(T01): assumes a circular orbit.
static func seconds_until_polar_angle(
		_gravitational_parameter: float,
		state: OrbitState,
		polar_angle_radians: float,
		extra_revolutions: int) -> float:
	var radius_meters: float = state.radius_meters()
	var angular_rate_radians_per_second: float = signed_angular_momentum(state) / (radius_meters * radius_meters)
	if angular_rate_radians_per_second == 0.0:
		return INF
	var angular_speed_radians_per_second: float = absf(angular_rate_radians_per_second)
	var angle_to_travel_radians: float = fposmod(
			(polar_angle_radians - state.polar_angle_radians()) * signf(angular_rate_radians_per_second), TAU)
	var period_seconds: float = TAU / angular_speed_radians_per_second
	return angle_to_travel_radians / angular_speed_radians_per_second + extra_revolutions * period_seconds


## Share of one orbital period spent between two distances from the body's
## centre, 0 to 1. Used for science coverage. Zero for an open orbit.
## STUB(T01): 1 when the circular orbit is inside the band, otherwise 0.
static func fraction_of_period_inside_band(
		elements: OrbitElements,
		inner_radius_meters: float,
		outer_radius_meters: float) -> float:
	if elements.is_open:
		return 0.0
	var orbit_radius_meters: float = elements.semi_major_axis_meters
	if orbit_radius_meters >= inner_radius_meters and orbit_radius_meters <= outer_radius_meters:
		return 1.0
	return 0.0
