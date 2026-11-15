class_name PlanResolver
extends RefCounted
## Turns a rocket design and a mission plan into the two things every screen
## needs: the mass bookkeeping (PlanSummary) and the flight path (Trajectory).
##
## This is the only place where RocketModel and OrbitModel meet. RocketModel
## decides how much velocity change each pulse can really deliver; OrbitModel
## then flies those delivered burns. Owned by the integrator.


static func resolve(design: RocketDesign, plan: MissionPlan, mission: Dictionary) -> ResolvedPlan:
	if plan.planning_mode == MissionPlan.PlanningMode.AUTOMATIC:
		var automatic_body: Dictionary = GameData.body(mission.get("body_id", "earth"))
		var ascent: AscentResult = AscentPlanner.resolve(design, mission, plan.launch_angle_radians)
		var mission_end_seconds: float = maxf(0.0, mission.get("duration_seconds", INF))
		return _resolve_after_ascent(automatic_body, plan, ascent, 0, mission_end_seconds)
	var body_id: String = mission.get("body_id", "earth")
	var body: Dictionary = GameData.body(body_id)
	var launch_loss_meters_per_second: float = mission.get("launch_loss_meters_per_second", 0.0)

	var summary: PlanSummary = RocketModel.summarize_plan(design, plan, launch_loss_meters_per_second)

	var launch_site: Dictionary = mission.get("launch_site", {})
	var launch_site_angle_degrees: float = launch_site.get("polar_angle_degrees", 90.0)
	var launch_state: OrbitState = Kepler.launch_state(
			body,
			deg_to_rad(launch_site_angle_degrees),
			summary.burnout_speed_meters_per_second,
			plan.launch_angle_radians)

	var resolved_burns: Array[ResolvedBurn] = create_resolved_burns(plan, summary)

	var resolved_plan := ResolvedPlan.new()
	resolved_plan.summary = summary
	resolved_plan.trajectory = OrbitModel.build_trajectory(body, launch_state, resolved_burns)
	return resolved_plan


## Scales each pulse to the velocity change the rocket can really deliver.
## The player's two components give the direction; PlanSummary gives the size.
static func create_resolved_burns(plan: MissionPlan, summary: PlanSummary) -> Array[ResolvedBurn]:
	var resolved_burns: Array[ResolvedBurn] = []
	for pulse_index in plan.pulses.size():
		var pulse: Pulse = plan.pulses[pulse_index]
		var requested_delta_v: float = pulse.requested_delta_v_meters_per_second()
		var delivered_delta_v: float = 0.0
		if pulse_index < summary.delta_v_delivered_by_pulse.size():
			delivered_delta_v = summary.delta_v_delivered_by_pulse[pulse_index]

		var delivered_share: float = 0.0
		if requested_delta_v > 0.0:
			delivered_share = delivered_delta_v / requested_delta_v

		var burn := ResolvedBurn.new()
		burn.pulse_index = pulse_index
		burn.polar_angle_radians = pulse.polar_angle_radians
		burn.extra_revolutions = pulse.extra_revolutions
		burn.fires_immediately = pulse.fires_immediately
		burn.delta_v_along_velocity_meters_per_second = pulse.delta_v_along_velocity_meters_per_second * delivered_share
		burn.delta_v_outward_meters_per_second = pulse.delta_v_outward_meters_per_second * delivered_share
		resolved_burns.append(burn)
	return resolved_burns


## Projects reachable manual pulses from a copy of a supplied vehicle and orbital state.
## Array indices remain the original MissionPlan pulse indices, including blocked entries.
static func resolve_remaining(body: Dictionary, state: OrbitState, vehicle: VehicleState, plan: MissionPlan, first_pulse_index: int = 0, initial_stage_id: int = 0) -> ResolvedPlan:
	return _resolve_remaining(body, state, vehicle, plan, first_pulse_index, initial_stage_id, INF)


static func _resolve_remaining(
		body: Dictionary, state: OrbitState, vehicle: VehicleState, plan: MissionPlan,
		first_pulse_index: int, initial_stage_id: int, mission_end_seconds: float) -> ResolvedPlan:
	var result := ResolvedPlan.new()
	var summary: PlanSummary = SequentialPropulsion.base_summary(vehicle.design)
	var projected_vehicle: VehicleState = vehicle.duplicate_vehicle_state()
	var current_state: OrbitState = state.duplicate_state()
	var trajectory := Trajectory.new()
	var gravitational_parameter: float = body["gravitational_parameter_cubic_meters_per_second_squared"]
	var source_stage_id: int = initial_stage_id
	var previous_pulse_index: int = first_pulse_index - 1
	for pulse_index in plan.pulses.size():
		summary.pulse_allocations.append(BurnAllocation.new())
		summary.delta_v_delivered_by_pulse.append(0.0)
		summary.is_pulse_affordable.append(false)
		summary.mass_after_pulse_kilograms.append(RocketModel.total_mass_kilograms(projected_vehicle))
	for pulse_index in range(first_pulse_index, plan.pulses.size()):
		var pulse: Pulse = plan.pulses[pulse_index]
		var arrival_seconds: float = 0.0 if pulse.fires_immediately else Kepler.seconds_until_polar_angle(
				gravitational_parameter, current_state, pulse.polar_angle_radians, pulse.extra_revolutions)
		var terminal_seconds: float = minf(
				Kepler.seconds_until_impact(gravitational_parameter, current_state, OrbitModel.impact_radius_meters(body)),
				Kepler.seconds_until_escape(gravitational_parameter, current_state, OrbitModel.escape_radius_meters(body)))
		if not is_finite(arrival_seconds) or arrival_seconds > terminal_seconds:
			trajectory.first_unreachable_pulse_index = pulse_index
			summary.warnings.append("Warning: Pulse %d cannot be reached; subsequent pulses do not fire." % (pulse_index + 1))
			break
		if current_state.time_seconds + arrival_seconds >= mission_end_seconds:
			summary.first_pulse_at_or_after_mission_end_index = pulse_index
			for late_pulse_index in range(pulse_index, plan.pulses.size()):
				summary.warnings.append("Warning: Pulse %d cannot fire before the mission ends." % (late_pulse_index + 1))
			break
		var before_state: OrbitState = Kepler.propagate(gravitational_parameter, current_state, arrival_seconds)
		var requested_delta_v_meters_per_second: float = pulse.requested_delta_v_meters_per_second()
		var allocation: BurnAllocation = SequentialPropulsion.apply_burn(projected_vehicle, requested_delta_v_meters_per_second, true)
		allocation.before_state = before_state
		var delivered_share: float = allocation.outcome.delta_v_delivered_meters_per_second / requested_delta_v_meters_per_second if requested_delta_v_meters_per_second > 0.0 else 0.0
		var burn := ResolvedBurn.new()
		burn.pulse_index = pulse_index
		burn.polar_angle_radians = pulse.polar_angle_radians
		burn.extra_revolutions = pulse.extra_revolutions
		burn.fires_immediately = pulse.fires_immediately
		burn.delta_v_along_velocity_meters_per_second = pulse.delta_v_along_velocity_meters_per_second * delivered_share
		burn.delta_v_outward_meters_per_second = pulse.delta_v_outward_meters_per_second * delivered_share
		var burns: Array[ResolvedBurn] = [burn]
		var step: Trajectory = OrbitModel.build_trajectory_from_state(body, current_state, burns)
		var coast: TrajectorySegment = step.segments[0]
		coast.source_stage_id = source_stage_id
		coast.pulse_index = previous_pulse_index
		trajectory.segments.append(coast)
		current_state = step.final_segment().start_state.duplicate_state()
		allocation.after_state = current_state.duplicate_state()
		previous_pulse_index = pulse_index
		if allocation.last_stage_id() != 0:
			source_stage_id = allocation.last_stage_id()
		summary.pulse_allocations[pulse_index] = allocation
		summary.delta_v_delivered_by_pulse[pulse_index] = allocation.outcome.delta_v_delivered_meters_per_second
		summary.is_pulse_affordable[pulse_index] = allocation.is_satisfied
		summary.mass_after_pulse_kilograms[pulse_index] = RocketModel.total_mass_kilograms(projected_vehicle)
		if not allocation.is_satisfied:
			summary.warnings.append("Warning: Pulse %d: %s" % [pulse_index + 1, allocation.blocking_reason])
	var no_burns: Array[ResolvedBurn] = []
	var tail: Trajectory = OrbitModel.build_trajectory_from_state(body, current_state, no_burns)
	for segment in tail.segments:
		segment.source_stage_id = source_stage_id
		segment.pulse_index = previous_pulse_index
		trajectory.segments.append(segment)
	trajectory.status = (Trajectory.Status.UNREACHABLE_PULSE if trajectory.first_unreachable_pulse_index >= 0
			else tail.status)
	var final_mass_kilograms: float = RocketModel.total_mass_kilograms(projected_vehicle)
	for blocked_index in range(previous_pulse_index + 1, plan.pulses.size()):
		summary.mass_after_pulse_kilograms[blocked_index] = final_mass_kilograms
	SequentialPropulsion.fill_reserve(summary, projected_vehicle)
	result.summary = summary
	result.trajectory = trajectory
	return result


## Combines the read-only ascent prefix with the reachable manual pulse chain.
static func resolve_after_ascent(body: Dictionary, plan: MissionPlan, ascent: AscentResult, first_pulse_index: int = 0) -> ResolvedPlan:
	return _resolve_after_ascent(body, plan, ascent, first_pulse_index, INF)


static func _resolve_after_ascent(
		body: Dictionary, plan: MissionPlan, ascent: AscentResult,
		first_pulse_index: int, mission_end_seconds: float) -> ResolvedPlan:
	var result: ResolvedPlan
	if ascent.did_reach_initial_orbit:
		result = _resolve_remaining(body, ascent.orbit_entry_state, ascent.vehicle_state, plan,
				first_pulse_index, ascent.insertion.last_stage_id(), mission_end_seconds)
		var prefix: Array[TrajectorySegment] = []
		for segment in ascent.trajectory.segments:
			if segment.is_automatic_ascent:
				prefix.append(segment)
		prefix.append_array(result.trajectory.segments)
		result.trajectory.segments = prefix
	else:
		result = ResolvedPlan.new()
		result.summary = SequentialPropulsion.base_summary(ascent.vehicle_state.design)
		result.trajectory = ascent.trajectory
		for pulse_index in plan.pulses.size():
			result.summary.pulse_allocations.append(BurnAllocation.new())
			result.summary.delta_v_delivered_by_pulse.append(0.0)
			result.summary.is_pulse_affordable.append(false)
			result.summary.mass_after_pulse_kilograms.append(RocketModel.total_mass_kilograms(ascent.vehicle_state))
		SequentialPropulsion.fill_reserve(result.summary, ascent.vehicle_state)
	result.summary.ascent = ascent
	result.summary.mass_after_ascent_kilograms = RocketModel.total_mass_kilograms(ascent.vehicle_state)
	result.summary.burnout_speed_meters_per_second = ascent.departure_state.speed_meters_per_second()
	for warning in ascent.warnings:
		result.summary.warnings.append("Warning: " + warning)
	if ascent.failure_reason != "":
		result.summary.warnings.append("Warning: " + ascent.failure_reason)
	return result
