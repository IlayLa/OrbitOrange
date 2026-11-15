class_name AscentPlanner
extends RefCounted
## Automatic two-impulse ascent behind one shared result interface.
## Fixed losses and instantaneous manoeuvres are intentional game assumptions.

const SPEED_BISECTION_ITERATIONS := 60
const GRAVITATIONAL_PARAMETER_KEY := "gravitational_parameter_cubic_meters_per_second_squared"


## Returns automatic ascent, including actual fuel use, states in SI and failure reasons.
static func resolve(design: RocketDesign, mission: Dictionary, launch_angle_radians: float) -> AscentResult:
	var body: Dictionary = GameData.body(mission.get("body_id", "earth"))
	var vehicle: VehicleState = RocketModel.create_vehicle_state(design)
	var result := AscentResult.new()
	result.vehicle_state = vehicle
	var site_angle_radians: float = deg_to_rad(mission.get("launch_site", {}).get("polar_angle_degrees", 90.0))
	var safe_angle_radians: float = clampf(launch_angle_radians, 0.0, deg_to_rad(89.0))
	result.departure_state = Kepler.launch_state(body, site_angle_radians, 0.0, safe_angle_radians)
	var radius_meters: float = body["radius_meters"]
	var gravitational_parameter: float = body[GRAVITATIONAL_PARAMETER_KEY]
	var first_stage: Stage = SequentialPropulsion.current_stage(vehicle)
	var thrust_newtons: float = 0.0
	if first_stage != null:
		thrust_newtons = 1000.0 * float(GameData.part(first_stage.engine_part_id).get("stats", {}).get("thrust_kilonewtons", 0.0))
	var weight_newtons: float = RocketModel.total_mass_kilograms(vehicle) * gravitational_parameter / (radius_meters * radius_meters)
	if first_stage == null or thrust_newtons <= weight_newtons:
		result.can_lift_off = false
		result.failure_reason = "INSUFFICIENT LIFT-OFF THRUST"
		return _finish(body, result)
	var target_radius_meters: float = radius_meters + 1000.0 * float(mission.get("target", {}).get("altitude_kilometers", 400.0))
	if target_radius_meters <= OrbitModel.impact_radius_meters(body):
		result.failure_reason = "Initial orbit must be above the atmosphere."
		return _finish(body, result)
	var lower_speed_meters_per_second := 0.0
	var upper_speed_meters_per_second: float = sqrt(2.0 * gravitational_parameter / radius_meters)
	for iteration_index in SPEED_BISECTION_ITERATIONS:
		var speed_meters_per_second: float = 0.5 * (lower_speed_meters_per_second + upper_speed_meters_per_second)
		var candidate: OrbitState = Kepler.launch_state(body, site_angle_radians, speed_meters_per_second, safe_angle_radians)
		var elements: OrbitElements = Kepler.elements_from_state(gravitational_parameter, candidate)
		if elements.is_open or elements.apoapsis_radius_meters >= target_radius_meters:
			upper_speed_meters_per_second = speed_meters_per_second
		else:
			lower_speed_meters_per_second = speed_meters_per_second
	var required_speed_meters_per_second: float = 0.5 * (lower_speed_meters_per_second + upper_speed_meters_per_second)
	var loss_meters_per_second: float = mission.get("launch_loss_meters_per_second", 0.0)
	result.departure = SequentialPropulsion.apply_burn(vehicle, required_speed_meters_per_second + loss_meters_per_second)
	var actual_speed_meters_per_second: float = maxf(0.0, result.departure.outcome.delta_v_delivered_meters_per_second - loss_meters_per_second)
	var departure_state: OrbitState = Kepler.launch_state(body, site_angle_radians, actual_speed_meters_per_second, safe_angle_radians)
	departure_state.time_seconds = result.departure.outcome.burn_duration_seconds
	var completion: AscentResult = complete_from_departure(body, mission, departure_state, vehicle)
	completion.departure = result.departure
	completion.can_lift_off = result.can_lift_off
	if not result.departure.is_satisfied:
		completion.warnings.append("Departure delta-v fell short of the target.")
	if not completion.trajectory.segments.is_empty():
		completion.trajectory.segments[0].source_stage_id = result.departure.last_stage_id()
	return _finish(body, completion)


## Projects insertion from an actual departure/coast state and a copy of live fuel.
static func complete_from_departure(body: Dictionary, mission: Dictionary, state: OrbitState, vehicle: VehicleState) -> AscentResult:
	var result := AscentResult.new()
	result.departure_state = state.duplicate_state()
	result.vehicle_state = vehicle.duplicate_vehicle_state()
	var gravitational_parameter: float = body[GRAVITATIONAL_PARAMETER_KEY]
	var elements: OrbitElements = Kepler.elements_from_state(gravitational_parameter, state)
	if elements.is_open or elements.periapsis_radius_meters <= 0.0:
		result.failure_reason = "Ascent has no reachable orbit-insertion point."
		return _finish(body, result)
	var motion_sign: float = -1.0 if elements.is_clockwise else 1.0
	var apoapsis_angle_radians: float = motion_sign * elements.argument_of_periapsis_radians + PI
	var arrival_seconds: float = Kepler.seconds_until_polar_angle(gravitational_parameter, state, apoapsis_angle_radians, 0)
	var terminal_seconds: float = minf(
			Kepler.seconds_until_impact(gravitational_parameter, state, OrbitModel.impact_radius_meters(body)),
			Kepler.seconds_until_escape(gravitational_parameter, state, OrbitModel.escape_radius_meters(body)))
	if not is_finite(arrival_seconds) or arrival_seconds > terminal_seconds or elements.apoapsis_radius_meters <= OrbitModel.impact_radius_meters(body):
		result.failure_reason = "Ascent ends before a safe orbit insertion."
		return _finish(body, result)
	var insertion_state: OrbitState = Kepler.propagate(gravitational_parameter, state, arrival_seconds)
	var requested_delta_v_meters_per_second: float = maxf(0.0,
			Kepler.circular_speed_meters_per_second(gravitational_parameter, insertion_state.radius_meters()) - insertion_state.speed_meters_per_second())
	result.insertion = SequentialPropulsion.apply_burn(result.vehicle_state, requested_delta_v_meters_per_second)
	result.insertion.before_state = insertion_state
	result.orbit_entry_state = Kepler.apply_pulse(insertion_state, result.insertion.outcome.delta_v_delivered_meters_per_second, 0.0)
	result.insertion.after_state = result.orbit_entry_state
	var burn := ResolvedBurn.new()
	burn.pulse_index = -1
	burn.polar_angle_radians = apoapsis_angle_radians
	burn.delta_v_along_velocity_meters_per_second = result.insertion.outcome.delta_v_delivered_meters_per_second
	var burns: Array[ResolvedBurn] = [burn]
	result.trajectory = OrbitModel.build_trajectory_from_state(body, state, burns)
	if not result.trajectory.segments.is_empty():
		result.trajectory.segments[0].is_automatic_ascent = true
		result.trajectory.segments.back().source_stage_id = result.insertion.last_stage_id()
	var final_elements: OrbitElements = Kepler.elements_from_state(gravitational_parameter, result.orbit_entry_state)
	result.did_reach_initial_orbit = not final_elements.is_open and final_elements.periapsis_radius_meters > OrbitModel.impact_radius_meters(body)
	if not result.did_reach_initial_orbit:
		result.failure_reason = "Automatic insertion did not reach a closed orbit above the atmosphere."
	elif absf((final_elements.semi_major_axis_meters - float(body["radius_meters"])) / 1000.0 - float(mission.get("target", {}).get("altitude_kilometers", 400.0))) > float(mission.get("target", {}).get("altitude_tolerance_kilometers", 100.0)):
		result.warnings.append("Solid-motor overshoot changed the initial orbit altitude.")
	return _finish(body, result)


static func _finish(body: Dictionary, result: AscentResult) -> AscentResult:
	if result.trajectory == null:
		var no_burns: Array[ResolvedBurn] = []
		result.trajectory = OrbitModel.build_trajectory_from_state(body, result.departure_state, no_burns)
	for stage in result.vehicle_state.design.stages:
		result.propellant_used_by_stage_kilograms[stage.stage_id] = 0.0
		result.propellant_remaining_by_stage_kilograms[stage.stage_id] = result.vehicle_state.propellant_kilograms_by_stage.get(stage.stage_id, 0.0)
	for allocation: BurnAllocation in [result.departure, result.insertion]:
		for stage_index in allocation.stage_ids.size():
			var stage_id: int = allocation.stage_ids[stage_index]
			result.propellant_used_by_stage_kilograms[stage_id] += allocation.stage_outcomes[stage_index].propellant_used_kilograms
	return result
