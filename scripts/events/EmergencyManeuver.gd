class_name EmergencyManeuver
extends RefCounted
## Builds a hypothetical coast using the real engine and orbital models.


## Creates a pulse whose reference directions match Kepler.apply_pulse.
static func create_pulse(stage_id: int, angle_degrees: float, delta_v_meters_per_second: float) -> Pulse:
	var pulse := Pulse.new()
	pulse.stage_id = stage_id
	pulse.fires_immediately = true
	var angle_radians := deg_to_rad(angle_degrees)
	pulse.delta_v_along_velocity_meters_per_second = cos(angle_radians) * delta_v_meters_per_second
	pulse.delta_v_outward_meters_per_second = sin(angle_radians) * delta_v_meters_per_second
	return pulse


## Applies the burn to a vehicle copy and returns the unpowered trajectory that follows.
static func preview_trajectory(
		body: Dictionary, craft_state: OrbitState, vehicle_state: VehicleState, pulse: Pulse) -> Trajectory:
	if craft_state == null or vehicle_state == null or pulse == null:
		return null
	var requested_delta_v_meters_per_second := pulse.requested_delta_v_meters_per_second()
	if requested_delta_v_meters_per_second <= 0.0:
		return null
	var outcome := RocketModel.apply_burn(
			vehicle_state.duplicate_vehicle_state(), pulse.stage_id, requested_delta_v_meters_per_second)
	return _trajectory_after_burn(body, craft_state, pulse, outcome)


## Uses the same sequential allocation as an automatic live flight.
static func preview_automatic_trajectory(
		body: Dictionary, craft_state: OrbitState, vehicle_state: VehicleState, pulse: Pulse) -> Trajectory:
	if craft_state == null or vehicle_state == null or pulse == null or pulse.requested_delta_v_meters_per_second() <= 0.0:
		return null
	var allocation := SequentialPropulsion.apply_burn(
			vehicle_state.duplicate_vehicle_state(), pulse.requested_delta_v_meters_per_second(), true)
	return _trajectory_after_burn(body, craft_state, pulse, allocation.outcome)


static func _trajectory_after_burn(
		body: Dictionary, craft_state: OrbitState, pulse: Pulse, outcome: BurnOutcome) -> Trajectory:
	var requested_delta_v_meters_per_second := pulse.requested_delta_v_meters_per_second()
	if not outcome.did_fire or outcome.delta_v_delivered_meters_per_second <= 0.0:
		return null
	var delivered_fraction := outcome.delta_v_delivered_meters_per_second / requested_delta_v_meters_per_second
	var burn := ResolvedBurn.new()
	burn.fires_immediately = true
	burn.delta_v_along_velocity_meters_per_second = (
			pulse.delta_v_along_velocity_meters_per_second * delivered_fraction)
	burn.delta_v_outward_meters_per_second = (
			pulse.delta_v_outward_meters_per_second * delivered_fraction)
	return OrbitModel.build_trajectory_from_state(body, craft_state, [burn])
