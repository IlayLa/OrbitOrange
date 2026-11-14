extends RefCounted
## Checks OrbitModel: trajectories through burns, their statuses, the state at
## a time and the sampled drawing points. T01.

const LAUNCH_SITE_ANGLE_RADIANS := PI / 2.0

var earth: Dictionary = {}
var gravitational_parameter: float = 0.0
var body_radius_meters: float = 0.0


func run_tests(report: TestReport) -> void:
	earth = GameData.body("earth")
	gravitational_parameter = earth["gravitational_parameter_cubic_meters_per_second_squared"]
	body_radius_meters = earth["radius_meters"]

	_check_horizontal_launch_impacts(report)
	_check_circularising_pulse_reaches_orbit(report)
	_check_pulse_behind_impact_is_unreachable(report)
	_check_large_pulse_escapes(report)
	_check_immediate_pulse_from_state(report)
	_check_state_after_impact_is_frozen(report)


func _check_horizontal_launch_impacts(report: TestReport) -> void:
	var launch: OrbitState = Kepler.launch_state(earth, LAUNCH_SITE_ANGLE_RADIANS, 7000.0, 0.0)
	var trajectory: Trajectory = OrbitModel.build_trajectory(earth, launch, _no_burns())
	report.check(trajectory.status == Trajectory.Status.IMPACT, "a horizontal launch at 7000 m/s ends in IMPACT")
	report.check(trajectory.segments.size() == 1, "a launch with no burns has one segment")
	report.check(trajectory.final_segment().end_reason == TrajectorySegment.EndReason.IMPACT,
			"the only segment ends by impact")


func _check_circularising_pulse_reaches_orbit(report: TestReport) -> void:
	var launch: OrbitState = Kepler.launch_state(earth, LAUNCH_SITE_ANGLE_RADIANS, 7800.0, deg_to_rad(10.0))
	var launch_elements: OrbitElements = Kepler.elements_from_state(gravitational_parameter, launch)
	var apoapsis_radius: float = launch_elements.apoapsis_radius_meters
	var apoapsis_angle: float = launch_elements.argument_of_periapsis_radians + PI
	var apoapsis_speed: float = absf(Kepler.signed_angular_momentum(launch)) / apoapsis_radius
	var circularising_pulse: float = Kepler.circular_speed_meters_per_second(gravitational_parameter, apoapsis_radius) - apoapsis_speed

	var burns: Array[ResolvedBurn] = [_burn(0, apoapsis_angle, circularising_pulse)]
	var trajectory: Trajectory = OrbitModel.build_trajectory(earth, launch, burns)
	report.check(trajectory.status == Trajectory.Status.REACHES_ORBIT, "a prograde pulse at apoapsis that circularises reaches orbit")
	report.check(trajectory.segments.size() == 2, "one burn gives two segments")
	if trajectory.segments.size() != 2:
		return
	var climb_segment: TrajectorySegment = trajectory.segments[0]
	var orbit_segment: TrajectorySegment = trajectory.segments[1]
	report.check(climb_segment.end_reason == TrajectorySegment.EndReason.NEXT_BURN, "the climb ends at the next burn")
	report.check(climb_segment.pulse_index == -1 and orbit_segment.pulse_index == 0, "segments record the pulse that started them")
	report.check(orbit_segment.end_reason == TrajectorySegment.EndReason.NO_FURTHER_BURNS, "the final orbit never ends")
	report.check(orbit_segment.elements.eccentricity < 1.0e-6,
			"the final orbit is circular (eccentricity %s)" % orbit_segment.elements.eccentricity)
	report.check_close(orbit_segment.start_state.radius_meters(), apoapsis_radius, 1.0e-3, "the burn fires at the apoapsis")

	var state_before_burn: OrbitState = Kepler.propagate(
			gravitational_parameter, climb_segment.start_state, climb_segment.end_time_seconds - climb_segment.start_time_seconds)
	var state_at_burn: OrbitState = OrbitModel.state_at_time(earth, trajectory, climb_segment.end_time_seconds)
	report.check_close(state_at_burn.position_x_meters, state_before_burn.position_x_meters, 1.0e-6,
			"the path is continuous across the burn (x)")
	report.check_close(state_at_burn.position_y_meters, state_before_burn.position_y_meters, 1.0e-6,
			"the path is continuous across the burn (y)")

	var climb_points: PackedFloat64Array = OrbitModel.sample_segment_points(earth, climb_segment, 64)
	report.check(climb_points.size() == 2 * 65, "sampling 64 intervals gives 65 points")
	report.check_close(climb_points[0], launch.position_x_meters, 1.0e-3, "the sampled climb starts at the launch site (x)")
	report.check_close(climb_points[1], launch.position_y_meters, 1.0e-3, "the sampled climb starts at the launch site (y)")
	report.check_close(climb_points[climb_points.size() - 2], state_before_burn.position_x_meters, 1.0e-3,
			"the sampled climb ends at the burn (x)")
	report.check_close(climb_points[climb_points.size() - 1], state_before_burn.position_y_meters, 1.0e-3,
			"the sampled climb ends at the burn (y)")

	var orbit_points: PackedFloat64Array = OrbitModel.sample_segment_points(earth, orbit_segment, 64)
	report.check_close(orbit_points[0], orbit_points[orbit_points.size() - 2], 1.0e-3, "a never-ending orbit is sampled as a closed loop (x)")
	report.check_close(orbit_points[1], orbit_points[orbit_points.size() - 1], 1.0e-3, "a never-ending orbit is sampled as a closed loop (y)")


func _check_pulse_behind_impact_is_unreachable(report: TestReport) -> void:
	var launch: OrbitState = Kepler.launch_state(earth, LAUNCH_SITE_ANGLE_RADIANS, 7000.0, deg_to_rad(20.0))
	var arc: Trajectory = OrbitModel.build_trajectory(earth, launch, _no_burns())
	var impact_state: OrbitState = OrbitModel.state_at_time(earth, arc, arc.final_segment().end_time_seconds)
	var beyond_impact_angle: float = impact_state.polar_angle_radians() + 0.2

	var burns: Array[ResolvedBurn] = [_burn(0, beyond_impact_angle, 100.0)]
	var trajectory: Trajectory = OrbitModel.build_trajectory(earth, launch, burns)
	report.check(trajectory.status == Trajectory.Status.UNREACHABLE_PULSE, "a pulse placed beyond the impact point is unreachable")
	report.check(trajectory.first_unreachable_pulse_index == 0, "the unreachable pulse is reported by index")
	report.check(trajectory.final_segment().end_reason == TrajectorySegment.EndReason.IMPACT,
			"the path before an unreachable pulse ends by impact")


func _check_large_pulse_escapes(report: TestReport) -> void:
	var orbit_radius: float = body_radius_meters + 400000.0
	var orbit_speed: float = Kepler.circular_speed_meters_per_second(gravitational_parameter, orbit_radius)
	var orbit_state := OrbitState.create(orbit_radius, 0.0, 0.0, orbit_speed, 100.0)
	var burns: Array[ResolvedBurn] = [_burn(0, PI, 4000.0)]
	var trajectory: Trajectory = OrbitModel.build_trajectory_from_state(earth, orbit_state, burns)
	report.check(trajectory.status == Trajectory.Status.ESCAPE, "a 4 km/s prograde pulse from low orbit escapes")
	var escape_segment: TrajectorySegment = trajectory.final_segment()
	report.check(escape_segment.end_reason == TrajectorySegment.EndReason.ESCAPE and not is_inf(escape_segment.end_time_seconds),
			"the escaping segment ends at a finite time")
	var escape_radius: float = OrbitModel.escape_radius_meters(earth)
	var end_state: OrbitState = OrbitModel.state_at_time(earth, trajectory, escape_segment.end_time_seconds)
	report.check_close(end_state.radius_meters(), escape_radius, 1.0e-6 * escape_radius, "the escaping segment ends at 20 body radii")

	var escape_points: PackedFloat64Array = OrbitModel.sample_segment_points(earth, escape_segment, 64)
	var largest_radius: float = 0.0
	for point_index in range(0, escape_points.size(), 2):
		largest_radius = maxf(largest_radius, sqrt(pow(escape_points[point_index], 2.0) + pow(escape_points[point_index + 1], 2.0)))
	report.check(largest_radius <= escape_radius * (1.0 + 1.0e-9), "the sampled escape stops at 20 body radii")


func _check_immediate_pulse_from_state(report: TestReport) -> void:
	var orbit_radius: float = body_radius_meters + 600000.0
	var orbit_speed: float = Kepler.circular_speed_meters_per_second(gravitational_parameter, orbit_radius)
	var flight_state := OrbitState.create(0.0, orbit_radius, -orbit_speed, 0.0, 1000.0)
	var emergency_burn: ResolvedBurn = _burn(3, 0.0, 50.0)
	emergency_burn.fires_immediately = true
	var burns: Array[ResolvedBurn] = [emergency_burn]
	var trajectory: Trajectory = OrbitModel.build_trajectory_from_state(earth, flight_state, burns)
	report.check(trajectory.segments.size() == 2, "an immediate pulse gives two segments")
	report.check_close(trajectory.segments[0].end_time_seconds, 1000.0, 0.0, "an immediate pulse fires at the current time")
	var expected_state: OrbitState = Kepler.apply_pulse(flight_state, 50.0, 0.0)
	report.check_close(trajectory.final_segment().start_state.velocity_x_meters_per_second,
			expected_state.velocity_x_meters_per_second, 1.0e-9, "the immediate pulse changes the velocity at once")
	report.check(trajectory.final_segment().pulse_index == 3, "the segment after the immediate pulse records its index")
	report.check(trajectory.status == Trajectory.Status.REACHES_ORBIT, "a small prograde emergency pulse stays in orbit")


func _check_state_after_impact_is_frozen(report: TestReport) -> void:
	var launch: OrbitState = Kepler.launch_state(earth, LAUNCH_SITE_ANGLE_RADIANS, 6000.0, deg_to_rad(40.0))
	var trajectory: Trajectory = OrbitModel.build_trajectory(earth, launch, _no_burns())
	var impact_time: float = trajectory.final_segment().end_time_seconds
	var at_impact: OrbitState = OrbitModel.state_at_time(earth, trajectory, impact_time)
	var long_after: OrbitState = OrbitModel.state_at_time(earth, trajectory, impact_time + 5000.0)
	report.check_close(long_after.position_x_meters, at_impact.position_x_meters, 1.0e-6, "after an impact the craft stays put (x)")
	report.check_close(long_after.position_y_meters, at_impact.position_y_meters, 1.0e-6, "after an impact the craft stays put (y)")
	report.check_close(at_impact.radius_meters(), OrbitModel.impact_radius_meters(earth), 1.0e-2,
			"the impact point is at the top of the atmosphere")


func _no_burns() -> Array[ResolvedBurn]:
	var burns: Array[ResolvedBurn] = []
	return burns


func _burn(pulse_index: int, polar_angle_radians: float, delta_v_along_velocity_meters_per_second: float) -> ResolvedBurn:
	var burn := ResolvedBurn.new()
	burn.pulse_index = pulse_index
	burn.polar_angle_radians = polar_angle_radians
	burn.delta_v_along_velocity_meters_per_second = delta_v_along_velocity_meters_per_second
	return burn
