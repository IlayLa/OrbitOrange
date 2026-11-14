class_name OrbitModel
extends RefCounted
## Builds the whole flight path from a launch state and a list of burns, and
## answers "where is the craft at time T". Everything that draws or flies an
## orbit goes through this class, so a different gravity model (for example
## one that includes the Moon) can replace it later without touching callers.

const GRAVITATIONAL_PARAMETER_KEY := "gravitational_parameter_cubic_meters_per_second_squared"
## An open path ends ("escapes") when it passes this many body radii.
const ESCAPE_RADIUS_IN_BODY_RADII := 20.0


## Distance from the body's centre at which the atmosphere starts: crossing it
## inward counts as an impact. Added by T01.
static func impact_radius_meters(body: Dictionary) -> float:
	var body_radius_meters: float = body["radius_meters"]
	var atmosphere_height_meters: float = body.get("atmosphere_height_meters", 0.0)
	return body_radius_meters + atmosphere_height_meters


## Distance from the body's centre at which an open path counts as escaped
## (and drawing stops). Added by T01.
static func escape_radius_meters(body: Dictionary) -> float:
	var body_radius_meters: float = body["radius_meters"]
	return ESCAPE_RADIUS_IN_BODY_RADII * body_radius_meters


## The flight path from launch burnout through every burn, in order.
## Each burn fires at the first crossing of its polar angle after the previous
## burn, plus its extra revolutions (or at once when fires_immediately is set).
## Stops early on impact, escape or a burn whose polar angle is never reached
## before the impact or escape (see Trajectory.Status). The status comes from
## how the final segment ends: IMPACT when it enters the atmosphere, ESCAPE
## when it leaves on an open path, otherwise REACHES_ORBIT.
static func build_trajectory(body: Dictionary, launch_state: OrbitState, resolved_burns: Array[ResolvedBurn]) -> Trajectory:
	var gravitational_parameter: float = body[GRAVITATIONAL_PARAMETER_KEY]
	var impact_radius: float = impact_radius_meters(body)
	var escape_radius: float = escape_radius_meters(body)
	var trajectory := Trajectory.new()
	var current_state: OrbitState = launch_state.duplicate_state()
	var starting_pulse_index: int = -1

	for burn in resolved_burns:
		var impact_seconds: float = Kepler.seconds_until_impact(gravitational_parameter, current_state, impact_radius)
		var escape_seconds: float = Kepler.seconds_until_escape(gravitational_parameter, current_state, escape_radius)
		var path_end_seconds: float = minf(impact_seconds, escape_seconds)
		var burn_seconds: float = 0.0
		if not burn.fires_immediately:
			burn_seconds = Kepler.seconds_until_polar_angle(
					gravitational_parameter, current_state, burn.polar_angle_radians, burn.extra_revolutions)

		if is_inf(burn_seconds) or burn_seconds > path_end_seconds:
			var end_reason: TrajectorySegment.EndReason = (
					TrajectorySegment.EndReason.IMPACT if impact_seconds <= escape_seconds
					else TrajectorySegment.EndReason.ESCAPE)
			trajectory.segments.append(_create_segment(
					gravitational_parameter, current_state,
					current_state.time_seconds + path_end_seconds, end_reason, starting_pulse_index))
			trajectory.status = Trajectory.Status.UNREACHABLE_PULSE
			trajectory.first_unreachable_pulse_index = burn.pulse_index
			return trajectory

		var burn_state: OrbitState = Kepler.propagate(gravitational_parameter, current_state, burn_seconds)
		trajectory.segments.append(_create_segment(
				gravitational_parameter, current_state, burn_state.time_seconds,
				TrajectorySegment.EndReason.NEXT_BURN, starting_pulse_index))
		current_state = Kepler.apply_pulse(
				burn_state,
				burn.delta_v_along_velocity_meters_per_second,
				burn.delta_v_outward_meters_per_second)
		starting_pulse_index = burn.pulse_index

	var final_impact_seconds: float = Kepler.seconds_until_impact(gravitational_parameter, current_state, impact_radius)
	var final_escape_seconds: float = Kepler.seconds_until_escape(gravitational_parameter, current_state, escape_radius)
	if not is_inf(final_impact_seconds) and final_impact_seconds <= final_escape_seconds:
		trajectory.segments.append(_create_segment(
				gravitational_parameter, current_state, current_state.time_seconds + final_impact_seconds,
				TrajectorySegment.EndReason.IMPACT, starting_pulse_index))
		trajectory.status = Trajectory.Status.IMPACT
	elif not is_inf(final_escape_seconds):
		trajectory.segments.append(_create_segment(
				gravitational_parameter, current_state, current_state.time_seconds + final_escape_seconds,
				TrajectorySegment.EndReason.ESCAPE, starting_pulse_index))
		trajectory.status = Trajectory.Status.ESCAPE
	else:
		trajectory.segments.append(_create_segment(
				gravitational_parameter, current_state, INF,
				TrajectorySegment.EndReason.NO_FURTHER_BURNS, starting_pulse_index))
		trajectory.status = Trajectory.Status.REACHES_ORBIT
	return trajectory


## Same as build_trajectory, but starts from any state in flight. Used to
## preview an emergency pulse: pass one burn with fires_immediately set.
static func build_trajectory_from_state(body: Dictionary, state: OrbitState, resolved_burns: Array[ResolvedBurn]) -> Trajectory:
	return build_trajectory(body, state, resolved_burns)


## Where the craft is at the given time since launch. After an impact the
## craft stays where it entered the atmosphere.
static func state_at_time(body: Dictionary, trajectory: Trajectory, time_seconds: float) -> OrbitState:
	var gravitational_parameter: float = body[GRAVITATIONAL_PARAMETER_KEY]
	var segment: TrajectorySegment = trajectory.segment_at_time(time_seconds)
	if segment == null:
		return OrbitState.new()
	var target_time_seconds: float = time_seconds
	if segment.end_reason == TrajectorySegment.EndReason.IMPACT and time_seconds > segment.end_time_seconds:
		target_time_seconds = segment.end_time_seconds
	var seconds_into_segment: float = target_time_seconds - segment.start_time_seconds
	return Kepler.propagate(gravitational_parameter, segment.start_state, seconds_into_segment)


## Points along one segment for drawing, in true coordinates (metres), as
## x0, y0, x1, y1, ... The segment is sampled from its start to its end, or
## over one full revolution when it never ends (or lasts a period or more).
## Points are spaced evenly in true anomaly, not in time, so arcs near
## periapsis stay smooth. Impacting segments stop at the atmosphere and open
## ones at the escape radius, because that is where they end.
static func sample_segment_points(body: Dictionary, segment: TrajectorySegment, point_count: int) -> PackedFloat64Array:
	if point_count < 2:
		return PackedFloat64Array()
	var gravitational_parameter: float = body[GRAVITATIONAL_PARAMETER_KEY]
	var elements: OrbitElements = segment.elements
	if elements == null:
		elements = Kepler.elements_from_state(gravitational_parameter, segment.start_state)
	var start_true_anomaly: float = elements.true_anomaly_radians

	var end_state: OrbitState
	if is_inf(segment.end_time_seconds):
		if not elements.is_open:
			return _sample_by_true_anomaly(elements, start_true_anomaly, TAU, point_count)
		var escape_seconds: float = Kepler.seconds_until_escape(
				gravitational_parameter, segment.start_state, escape_radius_meters(body))
		end_state = Kepler.propagate(gravitational_parameter, segment.start_state, escape_seconds)
	else:
		var duration_seconds: float = segment.end_time_seconds - segment.start_time_seconds
		if not elements.is_open and duration_seconds >= elements.period_seconds:
			return _sample_by_true_anomaly(elements, start_true_anomaly, TAU, point_count)
		end_state = Kepler.propagate(gravitational_parameter, segment.start_state, duration_seconds)

	# The end anomaly is measured in the start's frame, so a near-circular
	# orbit cannot switch conventions between the two ends.
	var motion_sign: float = -1.0 if elements.is_clockwise else 1.0
	var end_true_anomaly: float = motion_sign * end_state.polar_angle_radians() - elements.argument_of_periapsis_radians
	var sweep_radians: float
	if elements.is_open:
		sweep_radians = _wrap_signed_angle(end_true_anomaly) - _wrap_signed_angle(start_true_anomaly)
		start_true_anomaly = _wrap_signed_angle(start_true_anomaly)
	else:
		sweep_radians = fposmod(end_true_anomaly - start_true_anomaly, TAU)
		var duration_seconds: float = end_state.time_seconds - segment.start_state.time_seconds
		if sweep_radians < Kepler.SAME_ANGLE_TOLERANCE_RADIANS and duration_seconds > 0.5 * elements.period_seconds:
			sweep_radians = TAU
	return _sample_by_true_anomaly(elements, start_true_anomaly, sweep_radians, point_count)


## Points along the complete closed orbit through the given state, as
## x0, y0, x1, y1, ... in metres. The first point is repeated at the end.
## Empty for an open orbit.
static func sample_full_orbit_points(body: Dictionary, state: OrbitState, point_count: int) -> PackedFloat64Array:
	var gravitational_parameter: float = body[GRAVITATIONAL_PARAMETER_KEY]
	var elements: OrbitElements = Kepler.elements_from_state(gravitational_parameter, state)
	if elements.is_open or point_count < 2:
		return PackedFloat64Array()
	return _sample_by_true_anomaly(elements, elements.true_anomaly_radians, TAU, point_count)


## The angle in -PI (inclusive) to PI (exclusive).
static func _wrap_signed_angle(angle_radians: float) -> float:
	return angle_radians - TAU * floor((angle_radians + PI) / TAU)


static func _create_segment(
		gravitational_parameter: float,
		start_state: OrbitState,
		end_time_seconds: float,
		end_reason: TrajectorySegment.EndReason,
		pulse_index: int) -> TrajectorySegment:
	var segment := TrajectorySegment.new()
	segment.start_state = start_state.duplicate_state()
	segment.elements = Kepler.elements_from_state(gravitational_parameter, start_state)
	segment.start_time_seconds = start_state.time_seconds
	segment.end_time_seconds = end_time_seconds
	segment.end_reason = end_reason
	segment.pulse_index = pulse_index
	return segment


## point_count + 1 points on the conic, from start_true_anomaly over
## sweep_radians, using r = p / (1 + e cos v) and
## polar angle = motion_sign * (argument_of_periapsis + v).
static func _sample_by_true_anomaly(
		elements: OrbitElements,
		start_true_anomaly: float,
		sweep_radians: float,
		point_count: int) -> PackedFloat64Array:
	var motion_sign: float = -1.0 if elements.is_clockwise else 1.0
	var eccentricity: float = elements.eccentricity
	var semi_latus_rectum_meters: float = elements.periapsis_radius_meters * (1.0 + eccentricity)
	var points := PackedFloat64Array()
	for point_index in point_count + 1:
		var true_anomaly: float = start_true_anomaly + sweep_radians * float(point_index) / float(point_count)
		var radius_meters: float = semi_latus_rectum_meters / (1.0 + eccentricity * cos(true_anomaly))
		var polar_angle: float = motion_sign * (elements.argument_of_periapsis_radians + true_anomaly)
		points.append(radius_meters * cos(polar_angle))
		points.append(radius_meters * sin(polar_angle))
	return points
