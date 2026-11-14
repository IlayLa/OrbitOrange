class_name OrbitModel
extends RefCounted
## Builds the whole flight path from a launch state and a list of burns, and
## answers "where is the craft at time T". Everything that draws or flies an
## orbit goes through this class, so a different gravity model (for example
## one that includes the Moon) can replace it later without touching callers.
##
## STUB(T01): the signatures are final. The bodies ignore the burns and return
## one never-ending segment. T01 replaces them.

const GRAVITATIONAL_PARAMETER_KEY := "gravitational_parameter_cubic_meters_per_second_squared"


## The flight path from launch burnout through every burn, in order.
## Each burn fires at the first crossing of its polar angle after the previous
## burn, plus its extra revolutions. Stops early on impact, escape or a burn
## whose polar angle is never reached (see Trajectory.Status).
## STUB(T01): ignores the burns.
static func build_trajectory(body: Dictionary, launch_state: OrbitState, _resolved_burns: Array[ResolvedBurn]) -> Trajectory:
	var gravitational_parameter: float = body[GRAVITATIONAL_PARAMETER_KEY]
	var segment := TrajectorySegment.new()
	segment.start_state = launch_state.duplicate_state()
	segment.elements = Kepler.elements_from_state(gravitational_parameter, launch_state)
	segment.start_time_seconds = launch_state.time_seconds
	segment.end_time_seconds = INF
	segment.end_reason = TrajectorySegment.EndReason.NO_FURTHER_BURNS
	segment.pulse_index = -1

	var trajectory := Trajectory.new()
	trajectory.segments.append(segment)
	trajectory.status = Trajectory.Status.REACHES_ORBIT
	return trajectory


## Same as build_trajectory, but starts from any state in flight. Used to
## preview an emergency pulse: pass one burn with fires_immediately set.
## STUB(T01): ignores the burns.
static func build_trajectory_from_state(body: Dictionary, state: OrbitState, resolved_burns: Array[ResolvedBurn]) -> Trajectory:
	return build_trajectory(body, state, resolved_burns)


## Where the craft is at the given time since launch.
static func state_at_time(body: Dictionary, trajectory: Trajectory, time_seconds: float) -> OrbitState:
	var gravitational_parameter: float = body[GRAVITATIONAL_PARAMETER_KEY]
	var segment: TrajectorySegment = trajectory.segment_at_time(time_seconds)
	if segment == null:
		return OrbitState.new()
	var seconds_into_segment: float = time_seconds - segment.start_time_seconds
	return Kepler.propagate(gravitational_parameter, segment.start_state, seconds_into_segment)


## Points along one segment for drawing, in true coordinates (metres), as
## x0, y0, x1, y1, ... The segment is sampled from its start to its end, or
## over one full revolution when it never ends.
## STUB(T01): always samples one full revolution.
static func sample_segment_points(body: Dictionary, segment: TrajectorySegment, point_count: int) -> PackedFloat64Array:
	return sample_full_orbit_points(body, segment.start_state, point_count)


## Points along the complete closed orbit through the given state, as
## x0, y0, x1, y1, ... in metres. The first point is repeated at the end.
static func sample_full_orbit_points(body: Dictionary, state: OrbitState, point_count: int) -> PackedFloat64Array:
	var gravitational_parameter: float = body[GRAVITATIONAL_PARAMETER_KEY]
	var elements: OrbitElements = Kepler.elements_from_state(gravitational_parameter, state)
	var points := PackedFloat64Array()
	if elements.is_open or point_count < 2:
		return points
	for point_index in point_count + 1:
		var seconds_from_start: float = elements.period_seconds * point_index / point_count
		var sampled_state: OrbitState = Kepler.propagate(gravitational_parameter, state, seconds_from_start)
		points.append(sampled_state.position_x_meters)
		points.append(sampled_state.position_y_meters)
	return points
