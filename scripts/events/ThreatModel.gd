class_name ThreatModel
extends RefCounted
## Shared Kepler geometry for threat creation, prediction, preview, and collision checks.

const SAMPLE_SPACING_SECONDS := 5.0
const TARGET_LEAD_MIN_SECONDS := 180.0
const TARGET_LEAD_MAX_SECONDS := 300.0
const EXPIRY_AFTER_TARGET_SECONDS := 60.0
const MAX_GENERATION_ATTEMPTS := 8
const MAX_REFINEMENT_STEPS := 6
const REFINEMENT_TIME_TOLERANCE_SECONDS := 1.0e-6


## The end of an impacting or escaping trajectory, or INF for a coasting orbit.
static func terminal_time_seconds(trajectory: Trajectory) -> float:
	if trajectory == null:
		return INF
	var segment := trajectory.final_segment()
	if segment != null and (segment.end_reason == TrajectorySegment.EndReason.IMPACT
			or segment.end_reason == TrajectorySegment.EndReason.ESCAPE):
		return segment.end_time_seconds
	return INF


## Projects the threat for the display without modifying its stored state.
static func threat_state_at_time(body: Dictionary, threat: Threat, time_seconds: float) -> OrbitState:
	return Kepler.propagate(body[OrbitModel.GRAVITATIONAL_PARAMETER_KEY],
			threat.state, time_seconds - threat.state.time_seconds)


## Returns time_seconds, distance_meters, craft_state and threat_state. An
## empty result means there is no time in the interval when both are present.
static func closest_approach(
		body: Dictionary, trajectory: Trajectory, threat: Threat,
		start_seconds: float, end_seconds: float) -> Dictionary:
	if trajectory == null or trajectory.segments.is_empty() or threat == null or threat.state == null:
		return {}
	var first_time_seconds := maxf(start_seconds, threat.state.time_seconds)
	var last_time_seconds := minf(end_seconds, terminal_time_seconds(trajectory))
	if not is_finite(first_time_seconds) or not is_finite(last_time_seconds) or first_time_seconds > last_time_seconds:
		return {}

	var gravitational_parameter: float = body[OrbitModel.GRAVITATIONAL_PARAMETER_KEY]
	var best: ApproachSample
	# Work inside each coast segment so even a burn between regular samples
	# is an endpoint. Position is continuous at a burn, but velocity changes.
	for segment in trajectory.segments:
		var segment_start_seconds := maxf(first_time_seconds, segment.start_time_seconds)
		var segment_end_seconds := minf(last_time_seconds, segment.end_time_seconds)
		if segment_start_seconds > segment_end_seconds:
			continue
		var sample_time_seconds := segment_start_seconds
		var left := ApproachSample.new(gravitational_parameter, segment, threat.state, sample_time_seconds)
		best = _earlier_minimum(best, left)
		while sample_time_seconds < segment_end_seconds:
			sample_time_seconds = minf(sample_time_seconds + SAMPLE_SPACING_SECONDS, segment_end_seconds)
			var right := ApproachSample.new(gravitational_parameter, segment, threat.state, sample_time_seconds)
			best = _earlier_minimum(best, right)
			best = _earlier_minimum(best, _refine_interval(gravitational_parameter, segment, threat.state, left, right))
			left = right
	if best == null:
		return {}
	return {
		"time_seconds": best.craft.time_seconds,
		"distance_meters": sqrt(best.distance_meters_squared),
		"craft_state": best.craft,
		"threat_state": best.object,
	}


## Builds one object on a close pass. Supply the first object's target time to
## generate more fragments in the same encounter. Empty means no valid pass.
static func generate_threat(
		body: Dictionary, trajectory: Trajectory, random: RandomNumberGenerator,
		spawn_time_seconds: float, deadline_seconds: float, collision_radius_meters: float,
		threat_id: int, event_type_id: String, target_time_seconds: float = INF) -> Dictionary:
	if trajectory == null or trajectory.segments.is_empty() or collision_radius_meters <= 0.0:
		return {}
	if spawn_time_seconds < trajectory.segments[0].start_time_seconds:
		return {}
	var horizon_seconds := minf(deadline_seconds, terminal_time_seconds(trajectory))
	var first_target_time_seconds := spawn_time_seconds + TARGET_LEAD_MIN_SECONDS
	var last_target_time_seconds := minf(spawn_time_seconds + TARGET_LEAD_MAX_SECONDS, horizon_seconds)
	if first_target_time_seconds >= horizon_seconds:
		return {}
	if is_finite(target_time_seconds) and (target_time_seconds < first_target_time_seconds
			or target_time_seconds > last_target_time_seconds or target_time_seconds >= horizon_seconds):
		return {}

	var gravitational_parameter: float = body[OrbitModel.GRAVITATIONAL_PARAMETER_KEY]
	for attempt in MAX_GENERATION_ATTEMPTS:
		var approach_target_seconds := target_time_seconds
		if not is_finite(approach_target_seconds):
			approach_target_seconds = random.randf_range(first_target_time_seconds, last_target_time_seconds)
		var craft := OrbitModel.state_at_time(body, trajectory, approach_target_seconds)
		# Transverse offsets straddle the hit threshold so a conjunction can
		# be a genuine intercept or a close pass the player may leave alone.
		var course_radians := random.randf_range(0.0, TAU)
		var relative_speed_meters_per_second := random.randf_range(180.0, 850.0)
		var offset_meters := collision_radius_meters * random.randf_range(0.2, 2.5)
		if random.randf() < 0.5:
			offset_meters = -offset_meters
		var at_target := OrbitState.create(
				craft.position_x_meters - offset_meters * sin(course_radians),
				craft.position_y_meters + offset_meters * cos(course_radians),
				craft.velocity_x_meters_per_second + relative_speed_meters_per_second * cos(course_radians),
				craft.velocity_y_meters_per_second + relative_speed_meters_per_second * sin(course_radians),
				approach_target_seconds)
		var object := Threat.new()
		object.threat_id = threat_id
		object.event_type_id = event_type_id
		object.collision_radius_meters = collision_radius_meters
		object.state = Kepler.propagate(gravitational_parameter, at_target, spawn_time_seconds - approach_target_seconds)

		if object.state.radius_meters() <= OrbitModel.impact_radius_meters(body):
			continue
		var object_horizon_seconds := spawn_time_seconds + minf(
				Kepler.seconds_until_impact(gravitational_parameter, object.state, OrbitModel.impact_radius_meters(body)),
				Kepler.seconds_until_escape(gravitational_parameter, object.state, OrbitModel.escape_radius_meters(body)))
		var expiry_seconds := minf(deadline_seconds, approach_target_seconds + EXPIRY_AFTER_TARGET_SECONDS)
		# It must survive until expiry even if a player extends the craft's path.
		if object_horizon_seconds < expiry_seconds:
			continue
		var search_end_seconds := minf(horizon_seconds, expiry_seconds)
		var approach := closest_approach(body, trajectory, object, spawn_time_seconds, search_end_seconds)
		if approach.is_empty() or approach.time_seconds >= horizon_seconds:
			continue
		if absf(approach.time_seconds - approach_target_seconds) > 2.0 * SAMPLE_SPACING_SECONDS:
			continue
		if approach.distance_meters > 3.0 * collision_radius_meters:
			continue
		object.closest_approach_time_seconds = approach.time_seconds
		object.miss_distance_meters = approach.distance_meters
		return {"threat": object, "target_time_seconds": approach_target_seconds}
	return {}


static func _earlier_minimum(best: ApproachSample, sample: ApproachSample) -> ApproachSample:
	if sample == null:
		return best
	if best == null or sample.distance_meters_squared < best.distance_meters_squared:
		return sample
	if sample.distance_meters_squared == best.distance_meters_squared and sample.craft.time_seconds < best.craft.time_seconds:
		return sample
	return best


static func _refine_interval(
		gravitational_parameter: float, segment: TrajectorySegment, object_start: OrbitState,
		left: ApproachSample, right: ApproachSample) -> ApproachSample:
	var change_x_meters := right.relative_x_meters - left.relative_x_meters
	var change_y_meters := right.relative_y_meters - left.relative_y_meters
	var change_meters_squared := change_x_meters * change_x_meters + change_y_meters * change_y_meters
	if change_meters_squared == 0.0:
		return null
	# The nearest point on the relative-position chord is a first guess.
	# Relative velocity gives the slope of squared range on the actual orbits.
	var chord_fraction := -(left.relative_x_meters * change_x_meters + left.relative_y_meters * change_y_meters) / change_meters_squared
	var bracketed := left.range_slope_meters_squared_per_second < 0.0 and right.range_slope_meters_squared_per_second > 0.0
	if not bracketed and (chord_fraction <= 0.0 or chord_fraction >= 1.0):
		return null
	var left_time_seconds := left.craft.time_seconds
	var right_time_seconds := right.craft.time_seconds
	var left_slope_meters_squared_per_second := left.range_slope_meters_squared_per_second
	var right_slope_meters_squared_per_second := right.range_slope_meters_squared_per_second
	var sample_time_seconds := lerpf(left_time_seconds, right_time_seconds, clampf(chord_fraction, 0.0, 1.0))
	var best := ApproachSample.new(gravitational_parameter, segment, object_start, sample_time_seconds)
	if not bracketed:
		return best

	var sample := best
	for refinement in MAX_REFINEMENT_STEPS:
		if sample.range_slope_meters_squared_per_second < 0.0:
			left_time_seconds = sample_time_seconds
			left_slope_meters_squared_per_second = sample.range_slope_meters_squared_per_second
		else:
			right_time_seconds = sample_time_seconds
			right_slope_meters_squared_per_second = sample.range_slope_meters_squared_per_second
		var next_time_seconds := lerpf(left_time_seconds, right_time_seconds, -left_slope_meters_squared_per_second / (right_slope_meters_squared_per_second - left_slope_meters_squared_per_second))
		if absf(next_time_seconds - sample_time_seconds) <= REFINEMENT_TIME_TOLERANCE_SECONDS:
			break
		sample_time_seconds = next_time_seconds
		sample = ApproachSample.new(gravitational_parameter, segment, object_start, sample_time_seconds)
		best = _earlier_minimum(best, sample)
	return best


class ApproachSample:
	var craft: OrbitState
	var object: OrbitState
	var relative_x_meters: float
	var relative_y_meters: float
	var distance_meters_squared: float
	var range_slope_meters_squared_per_second: float

	func _init(gravitational_parameter: float, segment: TrajectorySegment, object_start: OrbitState, time_seconds: float) -> void:
		craft = Kepler.propagate(gravitational_parameter, segment.start_state, time_seconds - segment.start_time_seconds)
		object = Kepler.propagate(gravitational_parameter, object_start, time_seconds - object_start.time_seconds)
		relative_x_meters = object.position_x_meters - craft.position_x_meters
		relative_y_meters = object.position_y_meters - craft.position_y_meters
		distance_meters_squared = relative_x_meters * relative_x_meters + relative_y_meters * relative_y_meters
		range_slope_meters_squared_per_second = (relative_x_meters * (object.velocity_x_meters_per_second - craft.velocity_x_meters_per_second)
				+ relative_y_meters * (object.velocity_y_meters_per_second - craft.velocity_y_meters_per_second))
