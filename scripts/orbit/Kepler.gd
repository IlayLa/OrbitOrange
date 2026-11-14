class_name Kepler
extends RefCounted
## Two-body orbit mathematics in two dimensions. Orbits only: nothing in this
## file knows about rockets, money or the screen.
##
## Units: SI throughout. "gravitational_parameter" is always in cubic metres
## per second squared (for Earth about 3.986e14); it is the one name in the
## project that does not spell its unit out.
##
## Element conventions (GMAT Mathematical Specifications, section 4.1.2,
## Table 4.3, "equatorial" cases):
## - Eccentricity >= 1e-11: argument of periapsis is the angle from +x to the
##   eccentricity vector; true anomaly is the angle from the eccentricity
##   vector to the position.
## - Eccentricity < 1e-11 (circular): argument of periapsis is 0; true anomaly
##   is the angle from +x to the position.
## - Clockwise orbits: GMAT would call these inclined at 180 degrees, where its
##   forward conversion divides by zero (the node vector is zero). We use the
##   rule given by GMAT's own inverse conversion (equations 4.26 and 4.27 with
##   inclination 180 degrees and right ascension 0): x = r cos(w + v),
##   y = -r sin(w + v). So both angles are measured in the direction of motion,
##   which for a clockwise orbit is clockwise from +x:
##       polar angle = motion_sign * (argument_of_periapsis + true_anomaly)
##       periapsis direction = motion_sign * argument_of_periapsis
##   with motion_sign +1 for counter-clockwise and -1 for clockwise motion.
##   Internally every angle is computed in a frame mirrored by y -> -y, in
##   which the orbit is counter-clockwise.

## Below this eccentricity an orbit is treated as circular (GMAT threshold).
const CIRCULAR_ECCENTRICITY_THRESHOLD := 1.0e-11
## When |specific energy| * radius / gravitational_parameter is below this,
## the orbit is treated as parabolic by the solvers.
const PARABOLIC_ENERGY_TOLERANCE := 1.0e-10
## A path is radial (degenerate, no angular motion) when
## |angular momentum| <= this * radius * speed.
const RADIAL_ANGULAR_MOMENTUM_TOLERANCE := 1.0e-12
## Newton iterations stop when a step is below this share of the value.
const SOLVER_RELATIVE_TOLERANCE := 1.0e-14
const SOLVER_MAXIMUM_ITERATIONS := 100
const BRACKET_MAXIMUM_DOUBLINGS := 200
## A pulse whose angle is within this of the current direction fires now.
const SAME_ANGLE_TOLERANCE_RADIANS := 1.0e-9


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
## GMAT Mathematical Specifications eqs. 4.1-4.10, 4.15-4.17 and 4.21-4.23 in
## two dimensions; see the class comment for the clockwise rule. The angles use
## atan2, which equals GMAT's arccosine with its quadrant fixes (in a
## counter-clockwise frame sign(r . v) = sign(sin true_anomaly)) and is better
## conditioned near 0 and PI. A parabolic orbit (energy exactly 0) gets a
## semi-major axis of -INF, so every open orbit has a negative one.
static func elements_from_state(gravitational_parameter: float, state: OrbitState) -> OrbitElements:
	var motion_sign: float = _motion_sign(state)
	var position_x: float = state.position_x_meters
	var mirrored_position_y: float = motion_sign * state.position_y_meters
	var velocity_x: float = state.velocity_x_meters_per_second
	var mirrored_velocity_y: float = motion_sign * state.velocity_y_meters_per_second

	var radius_meters: float = state.radius_meters()
	var speed_squared: float = velocity_x * velocity_x + mirrored_velocity_y * mirrored_velocity_y
	var radius_dot_velocity: float = position_x * velocity_x + mirrored_position_y * mirrored_velocity_y
	var specific_energy: float = 0.5 * speed_squared - gravitational_parameter / radius_meters
	var angular_momentum: float = signed_angular_momentum(state)

	var radial_coefficient: float = speed_squared - gravitational_parameter / radius_meters
	var eccentricity_x: float = (radial_coefficient * position_x - radius_dot_velocity * velocity_x) / gravitational_parameter
	var mirrored_eccentricity_y: float = (
			(radial_coefficient * mirrored_position_y - radius_dot_velocity * mirrored_velocity_y)
			/ gravitational_parameter)
	var eccentricity: float = sqrt(eccentricity_x * eccentricity_x + mirrored_eccentricity_y * mirrored_eccentricity_y)
	var semi_latus_rectum_meters: float = angular_momentum * angular_momentum / gravitational_parameter

	var elements := OrbitElements.new()
	elements.eccentricity = eccentricity
	elements.specific_energy_joules_per_kilogram = specific_energy
	elements.is_open = specific_energy >= 0.0
	elements.is_circular = eccentricity < CIRCULAR_ECCENTRICITY_THRESHOLD
	elements.is_clockwise = angular_momentum < 0.0
	elements.periapsis_radius_meters = semi_latus_rectum_meters / (1.0 + eccentricity)
	if specific_energy == 0.0:
		elements.semi_major_axis_meters = -INF
	else:
		elements.semi_major_axis_meters = -gravitational_parameter / (2.0 * specific_energy)
	if elements.is_open:
		elements.apoapsis_radius_meters = INF
		elements.period_seconds = INF
	else:
		elements.apoapsis_radius_meters = elements.semi_major_axis_meters * (1.0 + eccentricity)
		elements.period_seconds = orbital_period_seconds(gravitational_parameter, elements.semi_major_axis_meters)

	if elements.is_circular:
		elements.argument_of_periapsis_radians = 0.0
		elements.true_anomaly_radians = fposmod(atan2(mirrored_position_y, position_x), TAU)
	else:
		elements.argument_of_periapsis_radians = fposmod(atan2(mirrored_eccentricity_y, eccentricity_x), TAU)
		var eccentricity_cross_position: float = eccentricity_x * mirrored_position_y - mirrored_eccentricity_y * position_x
		var eccentricity_dot_position: float = eccentricity_x * position_x + mirrored_eccentricity_y * mirrored_position_y
		elements.true_anomaly_radians = fposmod(atan2(eccentricity_cross_position, eccentricity_dot_position), TAU)
	return elements


## Position and velocity from orbit elements. The inverse of elements_from_state.
## GMAT eqs. 4.24-4.30 with inclination 0, evaluated in the mirrored frame.
## Reads eccentricity, periapsis_radius_meters, argument_of_periapsis_radians,
## true_anomaly_radians and is_clockwise. The semi-latus rectum is taken as
## periapsis * (1 + eccentricity), which also works for a parabola. A radial
## path (periapsis 0) cannot be inverted.
static func state_from_elements(gravitational_parameter: float, elements: OrbitElements, time_seconds: float) -> OrbitState:
	var motion_sign: float = -1.0 if elements.is_clockwise else 1.0
	var eccentricity: float = elements.eccentricity
	var true_anomaly: float = elements.true_anomaly_radians
	var semi_latus_rectum_meters: float = elements.periapsis_radius_meters * (1.0 + eccentricity)
	var radius_meters: float = semi_latus_rectum_meters / (1.0 + eccentricity * cos(true_anomaly))
	var mirrored_polar_angle: float = elements.argument_of_periapsis_radians + true_anomaly
	var speed_scale: float = sqrt(gravitational_parameter / semi_latus_rectum_meters)
	var radial_speed: float = speed_scale * eccentricity * sin(true_anomaly)
	var transverse_speed: float = speed_scale * (1.0 + eccentricity * cos(true_anomaly))
	var angle_cosine: float = cos(mirrored_polar_angle)
	var angle_sine: float = sin(mirrored_polar_angle)
	return OrbitState.create(
			radius_meters * angle_cosine,
			motion_sign * radius_meters * angle_sine,
			radial_speed * angle_cosine - transverse_speed * angle_sine,
			motion_sign * (radial_speed * angle_sine + transverse_speed * angle_cosine),
			time_seconds)


## The state after coasting for duration_seconds with no engine firing.
## Accepts negative durations and durations of many periods.
## Solves Kepler's equation in its "difference" form by Newton's method
## (elliptic for closed orbits, hyperbolic for open ones, the universal form
## with zero energy for parabolic ones), then applies the Lagrange f and g
## coefficients. This form needs no orbit angles, so circular and clockwise
## orbits need no special case.
static func propagate(gravitational_parameter: float, state: OrbitState, duration_seconds: float) -> OrbitState:
	var new_time_seconds: float = state.time_seconds + duration_seconds
	if duration_seconds == 0.0:
		var unchanged_state: OrbitState = state.duplicate_state()
		unchanged_state.time_seconds = new_time_seconds
		return unchanged_state

	var start_radius: float = state.radius_meters()
	var speed: float = state.speed_meters_per_second()
	var radius_dot_velocity: float = (
			state.position_x_meters * state.velocity_x_meters_per_second
			+ state.position_y_meters * state.velocity_y_meters_per_second)
	var square_root_gravitational_parameter: float = sqrt(gravitational_parameter)
	var radial_term: float = radius_dot_velocity / square_root_gravitational_parameter
	var specific_energy: float = 0.5 * speed * speed - gravitational_parameter / start_radius

	# Lagrange coefficients: new position = f r0 + g v0, new velocity = f_rate r0 + g_rate v0.
	var position_factor: float
	var velocity_factor_seconds: float
	var position_rate_factor: float
	var velocity_rate_factor: float

	if absf(specific_energy) * start_radius / gravitational_parameter < PARABOLIC_ENERGY_TOLERANCE:
		var parabolic_equation := func(universal_anomaly: float) -> PackedFloat64Array:
			var square: float = universal_anomaly * universal_anomaly
			return PackedFloat64Array([
					radial_term * square / 2.0 + square * universal_anomaly / 6.0 + start_radius * universal_anomaly
							- square_root_gravitational_parameter * duration_seconds,
					radial_term * universal_anomaly + square / 2.0 + start_radius])
		var parabolic_bracket: PackedFloat64Array = _find_bracket(parabolic_equation, duration_seconds > 0.0)
		var universal_anomaly: float = _solve_increasing_equation(
				parabolic_equation, parabolic_bracket[0], parabolic_bracket[1], 0.5 * (parabolic_bracket[0] + parabolic_bracket[1]))
		var anomaly_squared: float = universal_anomaly * universal_anomaly
		var end_radius: float = anomaly_squared / 2.0 + radial_term * universal_anomaly + start_radius
		position_factor = 1.0 - anomaly_squared / (2.0 * start_radius)
		velocity_factor_seconds = duration_seconds - anomaly_squared * universal_anomaly / (6.0 * square_root_gravitational_parameter)
		position_rate_factor = -square_root_gravitational_parameter * universal_anomaly / (end_radius * start_radius)
		velocity_rate_factor = 1.0 - anomaly_squared / (2.0 * end_radius)

	elif specific_energy < 0.0:
		var semi_major_axis: float = -gravitational_parameter / (2.0 * specific_energy)
		var square_root_semi_major_axis: float = sqrt(semi_major_axis)
		var mean_motion: float = sqrt(gravitational_parameter / pow(semi_major_axis, 3.0))
		var period_seconds: float = TAU / mean_motion
		var reduced_duration_seconds: float = fposmod(duration_seconds, period_seconds)
		var target_mean_anomaly_change: float = mean_motion * reduced_duration_seconds
		var cosine_coefficient: float = radial_term / square_root_semi_major_axis
		var sine_coefficient: float = 1.0 - start_radius / semi_major_axis
		var elliptic_equation := func(anomaly_change: float) -> PackedFloat64Array:
			var change_cosine: float = cos(anomaly_change)
			var change_sine: float = sin(anomaly_change)
			return PackedFloat64Array([
					anomaly_change + cosine_coefficient * (1.0 - change_cosine) - sine_coefficient * change_sine
							- target_mean_anomaly_change,
					1.0 + cosine_coefficient * change_sine - sine_coefficient * change_cosine])
		var eccentric_anomaly_change: float = _solve_increasing_equation(
				elliptic_equation, 0.0, TAU, target_mean_anomaly_change)
		var change_cosine: float = cos(eccentric_anomaly_change)
		var change_sine: float = sin(eccentric_anomaly_change)
		var end_radius: float = (
				semi_major_axis + (start_radius - semi_major_axis) * change_cosine
				+ radial_term * square_root_semi_major_axis * change_sine)
		position_factor = 1.0 - semi_major_axis / start_radius * (1.0 - change_cosine)
		velocity_factor_seconds = reduced_duration_seconds - (eccentric_anomaly_change - change_sine) / mean_motion
		position_rate_factor = -sqrt(gravitational_parameter * semi_major_axis) / (end_radius * start_radius) * change_sine
		velocity_rate_factor = 1.0 - semi_major_axis / end_radius * (1.0 - change_cosine)

	else:
		var negative_semi_major_axis: float = gravitational_parameter / (2.0 * specific_energy)
		var square_root_axis: float = sqrt(negative_semi_major_axis)
		var hyperbolic_mean_motion: float = sqrt(gravitational_parameter / pow(negative_semi_major_axis, 3.0))
		var target_mean_anomaly: float = hyperbolic_mean_motion * duration_seconds
		var cosh_coefficient: float = radial_term / square_root_axis
		var sinh_coefficient: float = 1.0 + start_radius / negative_semi_major_axis
		var hyperbolic_equation := func(anomaly_change: float) -> PackedFloat64Array:
			var change_cosh: float = cosh(anomaly_change)
			var change_sinh: float = sinh(anomaly_change)
			return PackedFloat64Array([
					cosh_coefficient * (change_cosh - 1.0) + sinh_coefficient * change_sinh - anomaly_change
							- target_mean_anomaly,
					cosh_coefficient * change_sinh + sinh_coefficient * change_cosh - 1.0])
		var hyperbolic_bracket: PackedFloat64Array = _find_bracket(hyperbolic_equation, duration_seconds > 0.0)
		var hyperbolic_anomaly_change: float = _solve_increasing_equation(
				hyperbolic_equation, hyperbolic_bracket[0], hyperbolic_bracket[1],
				_inverse_hyperbolic_sine(target_mean_anomaly / sinh_coefficient))
		var change_cosh: float = cosh(hyperbolic_anomaly_change)
		var change_sinh: float = sinh(hyperbolic_anomaly_change)
		var end_radius: float = (
				negative_semi_major_axis * (change_cosh - 1.0)
				+ radial_term * square_root_axis * change_sinh + start_radius * change_cosh)
		position_factor = 1.0 - negative_semi_major_axis / start_radius * (change_cosh - 1.0)
		velocity_factor_seconds = duration_seconds - (change_sinh - hyperbolic_anomaly_change) / hyperbolic_mean_motion
		position_rate_factor = -sqrt(gravitational_parameter * negative_semi_major_axis) / (end_radius * start_radius) * change_sinh
		velocity_rate_factor = 1.0 - negative_semi_major_axis / end_radius * (change_cosh - 1.0)

	return OrbitState.create(
			position_factor * state.position_x_meters + velocity_factor_seconds * state.velocity_x_meters_per_second,
			position_factor * state.position_y_meters + velocity_factor_seconds * state.velocity_y_meters_per_second,
			position_rate_factor * state.position_x_meters + velocity_rate_factor * state.velocity_x_meters_per_second,
			position_rate_factor * state.position_y_meters + velocity_rate_factor * state.velocity_y_meters_per_second,
			new_time_seconds)


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
## moving at burnout speed, launch_angle_radians above the local horizontal,
## counter-clockwise. Time 0. The craft starts inside the atmosphere.
static func launch_state(
		body: Dictionary,
		launch_site_angle_radians: float,
		burnout_speed_meters_per_second: float,
		launch_angle_radians: float) -> OrbitState:
	var body_radius_meters: float = body["radius_meters"]
	var outward_x: float = cos(launch_site_angle_radians)
	var outward_y: float = sin(launch_site_angle_radians)
	var horizontal_x: float = -outward_y
	var horizontal_y: float = outward_x
	var vertical_speed: float = burnout_speed_meters_per_second * sin(launch_angle_radians)
	var horizontal_speed: float = burnout_speed_meters_per_second * cos(launch_angle_radians)
	return OrbitState.create(
			body_radius_meters * outward_x,
			body_radius_meters * outward_y,
			vertical_speed * outward_x + horizontal_speed * horizontal_x,
			vertical_speed * outward_y + horizontal_speed * horizontal_y,
			0.0)


## Seconds until the object next crosses the given direction from the body,
## after waiting extra_revolutions full orbits. Exact for any closed orbit.
## Returns INF when it never does: on an open orbit whose remaining path does
## not reach the direction (extra revolutions are then impossible), or on a
## radial path. A direction within SAME_ANGLE_TOLERANCE_RADIANS of the current
## one counts as reached now, so two pulses at one place fire together.
## This function has no body, so it cannot see the ground: it does not return
## INF for an impact. Compare the result with seconds_until_impact
## (OrbitModel.build_trajectory does).
static func seconds_until_polar_angle(
		gravitational_parameter: float,
		state: OrbitState,
		polar_angle_radians: float,
		extra_revolutions: int) -> float:
	if _is_radial(state):
		return INF
	var elements: OrbitElements = elements_from_state(gravitational_parameter, state)
	var motion_sign: float = -1.0 if elements.is_clockwise else 1.0
	var target_true_anomaly: float = fposmod(
			motion_sign * polar_angle_radians - elements.argument_of_periapsis_radians, TAU)
	var current_true_anomaly: float = elements.true_anomaly_radians

	if not elements.is_open:
		var angle_gap_radians: float = fposmod(target_true_anomaly - current_true_anomaly, TAU)
		var gap_seconds: float = 0.0
		if angle_gap_radians > SAME_ANGLE_TOLERANCE_RADIANS and angle_gap_radians < TAU - SAME_ANGLE_TOLERANCE_RADIANS:
			gap_seconds = _forward_seconds_between(
					gravitational_parameter, elements, current_true_anomaly, target_true_anomaly)
		return gap_seconds + maxi(extra_revolutions, 0) * elements.period_seconds

	if extra_revolutions > 0:
		return INF
	var asymptote_true_anomaly: float = acos(clampf(-1.0 / elements.eccentricity, -1.0, 1.0))
	var signed_current: float = _wrap_signed_angle(current_true_anomaly)
	var signed_target: float = _wrap_signed_angle(target_true_anomaly)
	if signed_target < signed_current - SAME_ANGLE_TOLERANCE_RADIANS or signed_target >= asymptote_true_anomaly:
		return INF
	return maxf(0.0, _forward_seconds_between(gravitational_parameter, elements, signed_current, signed_target))


## Seconds until the object is at or below impact_radius_meters while moving
## inward (entering the atmosphere). 0 when it already is; INF when it never
## is. A craft that starts below the radius and climbs (a launch) impacts when
## it comes back down through the radius. When the whole closed orbit lies
## below the radius, the impact is at the next apoapsis. A radial path returns
## 0. Added by T01.
static func seconds_until_impact(gravitational_parameter: float, state: OrbitState, impact_radius_meters: float) -> float:
	if _is_radial(state):
		return 0.0
	var elements: OrbitElements = elements_from_state(gravitational_parameter, state)
	if elements.periapsis_radius_meters >= impact_radius_meters:
		return INF
	var current_true_anomaly: float = elements.true_anomaly_radians

	if not elements.is_open:
		if elements.is_circular:
			return 0.0
		if elements.apoapsis_radius_meters <= impact_radius_meters:
			if current_true_anomaly >= PI:
				return 0.0
			return _forward_seconds_between(gravitational_parameter, elements, current_true_anomaly, PI)
		var descending_true_anomaly: float = TAU - _true_anomaly_at_radius(elements, impact_radius_meters)
		if current_true_anomaly >= descending_true_anomaly:
			return 0.0
		return _forward_seconds_between(gravitational_parameter, elements, current_true_anomaly, descending_true_anomaly)

	var crossing_true_anomaly: float = _true_anomaly_at_radius(elements, impact_radius_meters)
	var signed_current: float = _wrap_signed_angle(current_true_anomaly)
	if signed_current < -crossing_true_anomaly:
		return _forward_seconds_between(gravitational_parameter, elements, signed_current, -crossing_true_anomaly)
	if signed_current < 0.0:
		return 0.0
	return INF


## Seconds until an object on an open orbit passes outward through
## escape_radius_meters. 0 when it is already beyond it and moving outward.
## INF for a closed orbit or a radial path. Added by T01.
static func seconds_until_escape(gravitational_parameter: float, state: OrbitState, escape_radius_meters: float) -> float:
	if _is_radial(state):
		return INF
	var elements: OrbitElements = elements_from_state(gravitational_parameter, state)
	if not elements.is_open:
		return INF
	var crossing_true_anomaly: float = _true_anomaly_at_radius(elements, escape_radius_meters)
	var signed_current: float = _wrap_signed_angle(elements.true_anomaly_radians)
	if signed_current >= crossing_true_anomaly:
		return 0.0
	return _forward_seconds_between(gravitational_parameter, elements, signed_current, crossing_true_anomaly)


## Share of one orbital period spent between two distances from the body's
## centre, 0 to 1. Used for science coverage. Zero for an open orbit.
## With r = a (1 - e cos E) and mean anomaly M = E - e sin E:
##     E_x = arccos(clamp((1 - r_x / a) / e, -1, 1)),  f = (M(E_outer) - M(E_inner)) / PI
## A circular orbit gives 1 when its radius is inside the band, otherwise 0.
static func fraction_of_period_inside_band(
		elements: OrbitElements,
		inner_radius_meters: float,
		outer_radius_meters: float) -> float:
	if elements.is_open or inner_radius_meters >= outer_radius_meters:
		return 0.0
	var semi_major_axis: float = elements.semi_major_axis_meters
	var eccentricity: float = elements.eccentricity
	if elements.is_circular:
		if semi_major_axis >= inner_radius_meters and semi_major_axis <= outer_radius_meters:
			return 1.0
		return 0.0
	var inner_eccentric_anomaly: float = acos(clampf((1.0 - inner_radius_meters / semi_major_axis) / eccentricity, -1.0, 1.0))
	var outer_eccentric_anomaly: float = acos(clampf((1.0 - outer_radius_meters / semi_major_axis) / eccentricity, -1.0, 1.0))
	var inner_mean_anomaly: float = inner_eccentric_anomaly - eccentricity * sin(inner_eccentric_anomaly)
	var outer_mean_anomaly: float = outer_eccentric_anomaly - eccentricity * sin(outer_eccentric_anomaly)
	return clampf((outer_mean_anomaly - inner_mean_anomaly) / PI, 0.0, 1.0)


## +1 for counter-clockwise motion (or none), -1 for clockwise.
static func _motion_sign(state: OrbitState) -> float:
	return -1.0 if signed_angular_momentum(state) < 0.0 else 1.0


static func _is_radial(state: OrbitState) -> bool:
	var speed: float = state.speed_meters_per_second()
	if speed == 0.0:
		return true
	return absf(signed_angular_momentum(state)) <= RADIAL_ANGULAR_MOMENTUM_TOLERANCE * state.radius_meters() * speed


static func _is_parabolic(gravitational_parameter: float, elements: OrbitElements) -> bool:
	return (
			absf(elements.specific_energy_joules_per_kilogram) * elements.periapsis_radius_meters / gravitational_parameter
			< PARABOLIC_ENERGY_TOLERANCE)


## The angle in -PI (inclusive) to PI (exclusive).
static func _wrap_signed_angle(angle_radians: float) -> float:
	return angle_radians - TAU * floor((angle_radians + PI) / TAU)


static func _inverse_hyperbolic_sine(value: float) -> float:
	if value < 0.0:
		return -_inverse_hyperbolic_sine(-value)
	return log(value + sqrt(value * value + 1.0))


## True anomaly (0 to PI, outbound side) at which the conic reaches the radius.
static func _true_anomaly_at_radius(elements: OrbitElements, radius_meters: float) -> float:
	var eccentricity: float = elements.eccentricity
	var semi_latus_rectum_meters: float = elements.periapsis_radius_meters * (1.0 + eccentricity)
	if eccentricity < CIRCULAR_ECCENTRICITY_THRESHOLD:
		return 0.0
	return acos(clampf((semi_latus_rectum_meters / radius_meters - 1.0) / eccentricity, -1.0, 1.0))


## Seconds since periapsis at the given true anomaly (negative before
## periapsis). Ellipse: in -period/2 to period/2.
static func _seconds_from_periapsis(gravitational_parameter: float, elements: OrbitElements, true_anomaly_radians: float) -> float:
	var eccentricity: float = elements.eccentricity
	if _is_parabolic(gravitational_parameter, elements):
		var semi_latus_rectum_meters: float = elements.periapsis_radius_meters * (1.0 + eccentricity)
		var half_angle_tangent: float = tan(true_anomaly_radians / 2.0)
		return (0.5 * sqrt(pow(semi_latus_rectum_meters, 3.0) / gravitational_parameter)
				* (half_angle_tangent + pow(half_angle_tangent, 3.0) / 3.0))
	if not elements.is_open:
		var eccentric_anomaly: float = atan2(
				sqrt(maxf(0.0, 1.0 - eccentricity * eccentricity)) * sin(true_anomaly_radians),
				eccentricity + cos(true_anomaly_radians))
		var mean_anomaly: float = eccentric_anomaly - eccentricity * sin(eccentric_anomaly)
		var mean_motion: float = sqrt(gravitational_parameter / pow(elements.semi_major_axis_meters, 3.0))
		return mean_anomaly / mean_motion
	var hyperbolic_anomaly: float = _inverse_hyperbolic_sine(
			sqrt(maxf(0.0, eccentricity * eccentricity - 1.0)) * sin(true_anomaly_radians)
			/ (1.0 + eccentricity * cos(true_anomaly_radians)))
	var hyperbolic_mean_anomaly: float = eccentricity * sinh(hyperbolic_anomaly) - hyperbolic_anomaly
	var hyperbolic_mean_motion: float = sqrt(gravitational_parameter / pow(-elements.semi_major_axis_meters, 3.0))
	return hyperbolic_mean_anomaly / hyperbolic_mean_motion


## Time to fly from one true anomaly to another along the motion. Closed orbit:
## the forward time, 0 to one period. Open orbit: the signed difference (the
## anomalies must lie on the path, between the asymptotes).
static func _forward_seconds_between(
		gravitational_parameter: float,
		elements: OrbitElements,
		from_true_anomaly_radians: float,
		to_true_anomaly_radians: float) -> float:
	var difference_seconds: float = (
			_seconds_from_periapsis(gravitational_parameter, elements, to_true_anomaly_radians)
			- _seconds_from_periapsis(gravitational_parameter, elements, from_true_anomaly_radians))
	if elements.is_open:
		return difference_seconds
	return fposmod(difference_seconds, elements.period_seconds)


## Lower and upper bound around the root of an increasing equation whose value
## at 0 is negative when the root is positive (and positive otherwise).
static func _find_bracket(equation: Callable, is_root_positive: bool) -> PackedFloat64Array:
	var lower_bound: float = 0.0
	var upper_bound: float = 0.0
	if is_root_positive:
		upper_bound = 1.0
		for _doubling_index in BRACKET_MAXIMUM_DOUBLINGS:
			var upper_values: PackedFloat64Array = equation.call(upper_bound)
			if upper_values[0] >= 0.0:
				break
			lower_bound = upper_bound
			upper_bound *= 2.0
	else:
		lower_bound = -1.0
		for _doubling_index in BRACKET_MAXIMUM_DOUBLINGS:
			var lower_values: PackedFloat64Array = equation.call(lower_bound)
			if lower_values[0] <= 0.0:
				break
			upper_bound = lower_bound
			lower_bound *= 2.0
	return PackedFloat64Array([lower_bound, upper_bound])


## Root of an increasing equation inside [lower_bound, upper_bound]. The
## equation returns [value, slope]. Newton steps, with a bisection step
## whenever Newton would leave the bracket.
static func _solve_increasing_equation(
		equation: Callable,
		lower_bound: float,
		upper_bound: float,
		initial_guess: float) -> float:
	var current_value: float = clampf(initial_guess, lower_bound, upper_bound)
	for _iteration_index in SOLVER_MAXIMUM_ITERATIONS:
		var value_and_slope: PackedFloat64Array = equation.call(current_value)
		var residual: float = value_and_slope[0]
		var slope: float = value_and_slope[1]
		if residual == 0.0:
			return current_value
		if residual > 0.0:
			upper_bound = current_value
		else:
			lower_bound = current_value
		var next_value: float = 0.5 * (lower_bound + upper_bound)
		if slope > 0.0:
			var newton_value: float = current_value - residual / slope
			if newton_value > lower_bound and newton_value < upper_bound:
				next_value = newton_value
		if absf(next_value - current_value) <= SOLVER_RELATIVE_TOLERANCE * maxf(1.0, absf(next_value)):
			return next_value
		current_value = next_value
	return current_value
