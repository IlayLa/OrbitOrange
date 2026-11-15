extends Node
## Owns the live flight state. Execution screens consume TelemetryFrame snapshots.

## Emitted once per completed fixed step, with the tick length in seconds.
signal simulation_step(step_seconds: float)
## Emitted once per rendered frame during flight, including while paused.
signal telemetry_updated(frame: TelemetryFrame)
## Emitted for a planned pulse attempt, or a successful emergency pulse (index -1).
signal pulse_fired(pulse_index: int, outcome: BurnOutcome)
## Emitted after pausing for an alert.
signal alert_raised(alarm_code: String, message: String)
signal flight_started
signal flight_ended(result: FlightResult)

const SIMULATION_STEP_SECONDS := 5.0
const ALLOWED_TIME_SCALES: Array[float] = [0.0, 1.0, 10.0, 100.0, 1000.0]
const PULSE_SLOWDOWN_LEAD_SECONDS := 2.0 * SIMULATION_STEP_SECONDS
const LOW_FUEL_FRACTION := 0.1
const AMBIENT_TEMPERATURE_KELVIN := 300.0
const OVER_TEMPERATURE_KELVIN := 350.0
const HEATING_KELVIN_PER_SECOND := 2.0
const COOLING_KELVIN_PER_SECOND := 0.5
const HAZARD_RANGE_METERS := 10000.0
const TelemetryFeed = preload("res://scripts/flight/TelemetryFeed.gd")
const DataLink = preload("res://scripts/flight/DataLink.gd")

var is_flying: bool = false
var time_scale: float = 1.0
var simulation_time_seconds: float = 0.0
## True position and velocity for the flight and event modules.
var craft_state: OrbitState
var vehicle_state: VehicleState
var trajectory: Trajectory
var threats: Array[Threat] = []
var event_log: Array[Dictionary] = []

var _automatic_mission: Dictionary = {}
var _automatic_departure_requested_meters_per_second: float = 0.0
var _automatic_departure_delivered_meters_per_second: float = 0.0
var _automatic_stage_request_meters_per_second: float = 0.0
var _automatic_insertion_pending: bool = false
var _automatic_insertion_time_seconds: float = INF
var _readout_stages: Array[Dictionary] = []
var _last_source_stage_id: int = 0

var _body: Dictionary
var _plan: MissionPlan
var _burnout_state: OrbitState
var _coast_segment: TrajectorySegment
var _flight_number: int = 0
var _is_finalizing_physical_end: bool = false
var _next_pulse_index: int = 0
var _next_launch_stage_index: int = 0
var _launch_stage: Stage
var _launch_stage_ends_at_seconds: float = INF
var _launch_stage_start_mass_kilograms: float = 0.0
var _launch_stage_propellant_kilograms: float = 0.0
var _launch_stage_mass_flow_kilograms_per_second: float = 0.0
var _burn_thrust_newtons: float = 0.0
var _pulse_readout_ends_at_seconds: float = 0.0
var _pulse_initial_mass_kilograms: float = 0.0
var _pulse_propellant_used_kilograms: float = 0.0
var _pulse_start_time_seconds: float = 0.0
var _pulse_attitude_radians: float = 0.0
var _temperature_kelvin: float = AMBIENT_TEMPERATURE_KELVIN
var _mission_duration_seconds: float = 0.0
var _next_step_time_seconds: float = SIMULATION_STEP_SECONDS
var _seconds_not_yet_simulated: float = 0.0
var _has_reached_stable_orbit: bool = false
var _data_generated_megabits: float = 0.0
var _data_delivered_megabits: float = 0.0
var _science_inner_radius_meters: float = INF
var _science_outer_radius_meters: float = -INF
var _science_rates_by_instrument: Dictionary = {}
var _random := RandomNumberGenerator.new()
var _telemetry_feed: TelemetryFeed


## Starts a fresh flight from the launch pad and seeds its instrument sampling.
func start_flight(design: RocketDesign, plan: MissionPlan, mission: Dictionary, random_seed: int) -> void:
	_flight_number += 1
	_is_finalizing_physical_end = false
	var launch_design := design.duplicate_design()
	_plan = plan.duplicate_plan()
	_body = GameData.body(mission.get("body_id", "earth")).duplicate(true)
	_mission_duration_seconds = maxf(0.0, mission.get("duration_seconds", 0.0))
	vehicle_state = RocketModel.create_vehicle_state(launch_design)
	var resolved: ResolvedPlan = PlanResolver.resolve(launch_design, _plan, mission)
	trajectory = resolved.trajectory
	_automatic_mission = mission.duplicate(true)
	_automatic_departure_delivered_meters_per_second = 0.0
	_automatic_insertion_pending = _plan.planning_mode == MissionPlan.PlanningMode.AUTOMATIC
	_automatic_insertion_time_seconds = INF
	_readout_stages.clear()
	_last_source_stage_id = 0
	_automatic_departure_requested_meters_per_second = resolved.summary.ascent.departure.requested_delta_v_meters_per_second if resolved.summary.ascent != null else 0.0
	var first_segment: TrajectorySegment = null if trajectory.segments.is_empty() else trajectory.segments[0]
	_burnout_state = (
			OrbitModel.state_at_time(_body, trajectory, 0.0) if first_segment == null
			else first_segment.start_state.duplicate_state())
	_coast_segment = null
	_launch_stage = null
	_launch_stage_ends_at_seconds = INF
	_next_launch_stage_index = 0
	_next_pulse_index = 0
	_pulse_readout_ends_at_seconds = 0.0
	_temperature_kelvin = AMBIENT_TEMPERATURE_KELVIN
	_has_reached_stable_orbit = false
	threats = []
	event_log = []
	simulation_time_seconds = 0.0
	_next_step_time_seconds = SIMULATION_STEP_SECONDS
	_seconds_not_yet_simulated = 0.0
	time_scale = 1.0
	_configure_science(mission)
	_random.seed = random_seed
	_telemetry_feed = TelemetryFeed.new(vehicle_state, _random)
	var pad_radius_meters: float = _body["radius_meters"]
	var launch_angle_radians: float = _burnout_state.polar_angle_radians()
	craft_state = OrbitState.create(
			pad_radius_meters * cos(launch_angle_radians), pad_radius_meters * sin(launch_angle_radians), 0.0, 0.0)
	_begin_next_launch_stage()
	is_flying = true
	flight_started.emit()
	if resolved.summary.ascent != null and not resolved.summary.ascent.can_lift_off:
		end_flight(FlightResult.EndReason.LAUNCH_FAILURE)


## Sets simulated seconds per real second to one of the allowed scales.
func set_time_scale(new_time_scale: float) -> void:
	if ALLOWED_TIME_SCALES.has(new_time_scale):
		time_scale = new_time_scale
		if time_scale == 0.0:
			_seconds_not_yet_simulated = 0.0


## Pauses the simulation clock.
func pause() -> void:
	set_time_scale(0.0)


## Fires at the current orbital position and returns the actual engine outcome.
func apply_emergency_pulse(pulse: Pulse) -> BurnOutcome:
	if not is_flying or _launch_stage != null or _is_finalizing_physical_end:
		return BurnOutcome.new()
	var outcome := _apply_pulse(pulse)
	if outcome.did_fire:
		_rebuild_trajectory()
		pulse_fired.emit(-1, outcome)
	return outcome


## Registers a threat for telemetry and the event module.
func add_threat(threat: Threat) -> void:
	threats.append(threat)


## Removes the matching threat and its cached radar contact.
func remove_threat(threat_id: int) -> void:
	for threat_index in threats.size():
		if threats[threat_index].threat_id == threat_id:
			threats.remove_at(threat_index)
			if _telemetry_feed != null:
				_telemetry_feed.forget_threat(threat_id)
			return


## Records a copy of the supplied event for the final flight result.
func log_event(event_record: Dictionary) -> void:
	event_log.append(event_record.duplicate(true))


## Pauses the flight and emits the message for the control room.
func raise_alert(alarm_code: String, message: String) -> void:
	if _is_finalizing_physical_end:
		return
	pause()
	alert_raised.emit(alarm_code, message)


## Ends the active flight and emits its result once.
func end_flight(end_reason: FlightResult.EndReason) -> void:
	if not is_flying or _is_finalizing_physical_end:
		return
	is_flying = false
	_seconds_not_yet_simulated = 0.0
	flight_ended.emit(_create_flight_result(end_reason))


## Advances by simulated seconds, accumulating any remainder between boundaries.
## A pause or automatic slowdown discards the unused budget from this call.
func advance_simulation(seconds: float) -> void:
	if not is_flying or _is_finalizing_physical_end or time_scale == 0.0:
		return
	if not is_finite(seconds) or seconds < 0.0:
		return
	_seconds_not_yet_simulated += seconds
	var flight_number := _flight_number
	while is_flying and time_scale > 0.0 and _flight_number == flight_number:
		var pulse_time_seconds: float = minf(_next_planned_pulse_time_seconds(), _automatic_insertion_time_seconds)
		var slowdown_time_seconds := INF
		if time_scale > 1.0 and is_finite(pulse_time_seconds):
			slowdown_time_seconds = maxf(simulation_time_seconds, pulse_time_seconds - PULSE_SLOWDOWN_LEAD_SECONDS)
		var boundary_time_seconds := minf(_next_step_time_seconds, _mission_duration_seconds)
		boundary_time_seconds = minf(boundary_time_seconds, _launch_stage_ends_at_seconds)
		boundary_time_seconds = minf(boundary_time_seconds, _terminal_boundary_time_seconds())
		boundary_time_seconds = minf(boundary_time_seconds, pulse_time_seconds)
		boundary_time_seconds = minf(boundary_time_seconds, _telemetry_feed.next_sample_time_seconds())
		boundary_time_seconds = minf(boundary_time_seconds, slowdown_time_seconds)
		boundary_time_seconds = _escape_crossing_time_seconds(boundary_time_seconds)
		var elapsed_seconds := boundary_time_seconds - simulation_time_seconds
		if elapsed_seconds > _seconds_not_yet_simulated + 1.0e-9:
			return
		_seconds_not_yet_simulated = maxf(0.0, _seconds_not_yet_simulated - elapsed_seconds)
		_advance_to(boundary_time_seconds)
		var did_slow_down := boundary_time_seconds == slowdown_time_seconds
		if did_slow_down:
			time_scale = 1.0
			_seconds_not_yet_simulated = 0.0
		if boundary_time_seconds == _launch_stage_ends_at_seconds:
			_finish_launch_stage()
		if _physical_end_reason() < 0 and simulation_time_seconds < _mission_duration_seconds:
			_fire_automatic_insertion()
			_fire_due_planned_pulses()
			if not is_flying or _flight_number != flight_number:
				return
		_sample_instruments()
		var terminal_reason := _physical_end_reason()
		if boundary_time_seconds == _next_step_time_seconds:
			_next_step_time_seconds += SIMULATION_STEP_SECONDS
			# A completed tick still emits before the result. Its listeners cannot
			# change an impact or escape already reached at this boundary.
			_is_finalizing_physical_end = terminal_reason >= 0
			simulation_step.emit(SIMULATION_STEP_SECONDS)
			if not is_flying or _flight_number != flight_number:
				return
			_is_finalizing_physical_end = false
			if terminal_reason < 0:
				terminal_reason = _physical_end_reason()
		if terminal_reason >= 0:
			end_flight(terminal_reason as FlightResult.EndReason)
		elif simulation_time_seconds >= _mission_duration_seconds:
			var reason := FlightResult.EndReason.MISSION_COMPLETED
			if not _has_reached_stable_orbit:
				var final_segment := trajectory.final_segment()
				if final_segment != null and final_segment.end_reason == TrajectorySegment.EndReason.IMPACT:
					reason = FlightResult.EndReason.LAUNCH_FAILURE
			end_flight(reason)
		if did_slow_down:
			return


func _process(real_seconds_since_last_frame: float) -> void:
	if not is_flying:
		return
	advance_simulation(real_seconds_since_last_frame * time_scale)
	if is_flying:
		telemetry_updated.emit(_create_telemetry_frame())


func _advance_to(time_seconds: float) -> void:
	var interval_seconds := time_seconds - simulation_time_seconds
	var heating_seconds := interval_seconds if _launch_stage != null else clampf(
			_pulse_readout_ends_at_seconds - simulation_time_seconds, 0.0, interval_seconds)
	_temperature_kelvin = maxf(AMBIENT_TEMPERATURE_KELVIN,
			_temperature_kelvin + heating_seconds * HEATING_KELVIN_PER_SECOND
			- (interval_seconds - heating_seconds) * COOLING_KELVIN_PER_SECOND)
	if _coast_segment != null and interval_seconds > 0.0:
		_collect_science(_state_on_coast(simulation_time_seconds + interval_seconds * 0.5), interval_seconds)
		craft_state = _state_on_coast(time_seconds)
	else:
		craft_state.time_seconds = time_seconds
	simulation_time_seconds = time_seconds


func _state_on_coast(time_seconds: float) -> OrbitState:
	return Kepler.propagate(
			_gravitational_parameter(), _coast_segment.start_state, time_seconds - _coast_segment.start_time_seconds)


func _begin_next_launch_stage() -> void:
	if _plan.planning_mode == MissionPlan.PlanningMode.AUTOMATIC:
		_begin_automatic_departure_stage()
		return
	while _next_launch_stage_index < _plan.launch_stage_ids.size():
		var stage_id := _plan.launch_stage_ids[_next_launch_stage_index]
		_next_launch_stage_index += 1
		var stage := vehicle_state.design.find_stage(stage_id)
		if stage == null or vehicle_state.is_jettisoned_by_stage.get(stage_id, true):
			continue
		if vehicle_state.has_failed_by_stage.get(stage_id, false):
			continue
		var engine_stats: Dictionary = GameData.part(stage.engine_part_id).get("stats", {})
		_burn_thrust_newtons = float(engine_stats.get("thrust_kilonewtons", 0.0)) * 1000.0
		var specific_impulse_seconds: float = (
				engine_stats.get("specific_impulse_seconds", 0.0)
				* vehicle_state.specific_impulse_factor_by_stage.get(stage_id, 1.0))
		_launch_stage_propellant_kilograms = vehicle_state.propellant_kilograms_by_stage.get(stage_id, 0.0)
		if _burn_thrust_newtons <= 0.0 or specific_impulse_seconds <= 0.0 or _launch_stage_propellant_kilograms <= 0.0:
			continue
		_launch_stage = stage
		_launch_stage_start_mass_kilograms = _mass_at_ignition_kilograms(stage_id)
		_launch_stage_mass_flow_kilograms_per_second = _burn_thrust_newtons / (
				specific_impulse_seconds * RocketModel.STANDARD_GRAVITY_METERS_PER_SECOND_SQUARED)
		_launch_stage_ends_at_seconds = (
				simulation_time_seconds + _launch_stage_propellant_kilograms / _launch_stage_mass_flow_kilograms_per_second)
		return
	_burnout_state.time_seconds = simulation_time_seconds
	craft_state = _burnout_state.duplicate_state()
	_rebuild_trajectory()


func _finish_launch_stage() -> void:
	if _plan.planning_mode == MissionPlan.PlanningMode.AUTOMATIC:
		var allocation: BurnAllocation = SequentialPropulsion.apply_burn(vehicle_state, _automatic_stage_request_meters_per_second)
		_automatic_departure_delivered_meters_per_second += allocation.outcome.delta_v_delivered_meters_per_second
		_record_allocation_readout(allocation, craft_state, "Automatic departure")
		_launch_stage = null
		_launch_stage_ends_at_seconds = INF
		_begin_automatic_departure_stage()
		return
	var stage_id := _launch_stage.stage_id
	var available_delta_v_meters_per_second := RocketModel.available_delta_v_meters_per_second(vehicle_state, stage_id)
	if available_delta_v_meters_per_second > 0.0:
		RocketModel.apply_burn(vehicle_state, stage_id, available_delta_v_meters_per_second)
	_launch_stage = null
	_launch_stage_ends_at_seconds = INF
	_begin_next_launch_stage()


func _mass_at_ignition_kilograms(stage_id: int) -> float:
	var mass_state := vehicle_state.duplicate_vehicle_state()
	for lower_stage in mass_state.design.stages:
		if lower_stage.stage_id == stage_id:
			break
		mass_state.is_jettisoned_by_stage[lower_stage.stage_id] = true
	return RocketModel.total_mass_kilograms(mass_state)


func _rebuild_trajectory() -> void:
	if _plan.planning_mode == MissionPlan.PlanningMode.AUTOMATIC:
		_rebuild_automatic_trajectory()
		return
	var remaining_burns: Array[ResolvedBurn] = []
	var projected_vehicle := vehicle_state.duplicate_vehicle_state()
	for pulse_index in range(_next_pulse_index, _plan.pulses.size()):
		var pulse := _plan.pulses[pulse_index]
		var requested_delta_v_meters_per_second := pulse.requested_delta_v_meters_per_second()
		var outcome := BurnOutcome.new()
		if requested_delta_v_meters_per_second > 0.0:
			outcome = RocketModel.apply_burn(projected_vehicle, pulse.stage_id, requested_delta_v_meters_per_second)
		var delivered_fraction := _delivered_fraction(pulse, outcome)
		var burn := ResolvedBurn.new()
		burn.pulse_index = pulse_index
		burn.polar_angle_radians = pulse.polar_angle_radians
		burn.extra_revolutions = pulse.extra_revolutions
		burn.fires_immediately = pulse.fires_immediately
		burn.delta_v_along_velocity_meters_per_second = pulse.delta_v_along_velocity_meters_per_second * delivered_fraction
		burn.delta_v_outward_meters_per_second = pulse.delta_v_outward_meters_per_second * delivered_fraction
		remaining_burns.append(burn)
	trajectory = OrbitModel.build_trajectory_from_state(_body, craft_state, remaining_burns)
	_coast_segment = null if trajectory.segments.is_empty() else trajectory.segments[0]
	_has_reached_stable_orbit = _has_reached_stable_orbit or _is_stable_orbit(_final_elements())


func _next_planned_pulse_time_seconds() -> float:
	if _automatic_insertion_pending:
		return INF
	if _coast_segment != null and _coast_segment.end_reason == TrajectorySegment.EndReason.NEXT_BURN:
		if _next_pulse_index < _plan.pulses.size():
			return _coast_segment.end_time_seconds
	return INF


func _fire_due_planned_pulses() -> void:
	var flight_number := _flight_number
	while _next_planned_pulse_time_seconds() <= simulation_time_seconds:
		var pulse_index := _next_pulse_index
		var outcome := _apply_pulse(_plan.pulses[pulse_index])
		_next_pulse_index += 1
		_rebuild_trajectory()
		pulse_fired.emit(pulse_index, outcome)
		if not is_flying or time_scale == 0.0 or _flight_number != flight_number:
			return


func _apply_pulse(pulse: Pulse) -> BurnOutcome:
	if _plan.planning_mode == MissionPlan.PlanningMode.AUTOMATIC:
		return _apply_automatic_pulse(pulse)
	var requested_delta_v_meters_per_second := pulse.requested_delta_v_meters_per_second()
	if requested_delta_v_meters_per_second <= 0.0:
		return BurnOutcome.new()
	var outcome := RocketModel.apply_burn(vehicle_state, pulse.stage_id, requested_delta_v_meters_per_second)
	if not outcome.did_fire:
		return outcome
	var delivered_fraction := _delivered_fraction(pulse, outcome)
	var post_burn_state := Kepler.apply_pulse(
			craft_state, pulse.delta_v_along_velocity_meters_per_second * delivered_fraction,
			pulse.delta_v_outward_meters_per_second * delivered_fraction)
	var thrust_direction := OrbitState.create(
			craft_state.position_x_meters, craft_state.position_y_meters,
			post_burn_state.velocity_x_meters_per_second - craft_state.velocity_x_meters_per_second,
			post_burn_state.velocity_y_meters_per_second - craft_state.velocity_y_meters_per_second)
	var tangent_direction := -1.0 if Kepler.signed_angular_momentum(craft_state) < 0.0 else 1.0
	var radial_projection := (
			craft_state.position_x_meters * thrust_direction.velocity_x_meters_per_second
			+ craft_state.position_y_meters * thrust_direction.velocity_y_meters_per_second)
	_pulse_attitude_radians = atan2(radial_projection, tangent_direction * Kepler.signed_angular_momentum(thrust_direction))
	craft_state = post_burn_state
	var stage := vehicle_state.design.find_stage(pulse.stage_id)
	var stats: Dictionary = GameData.part(stage.engine_part_id).get("stats", {})
	_burn_thrust_newtons = float(stats.get("thrust_kilonewtons", 0.0)) * 1000.0
	_pulse_start_time_seconds = simulation_time_seconds
	_pulse_readout_ends_at_seconds = simulation_time_seconds + outcome.burn_duration_seconds
	_pulse_initial_mass_kilograms = outcome.mass_before_kilograms
	_pulse_propellant_used_kilograms = outcome.propellant_used_kilograms
	return outcome


func _delivered_fraction(pulse: Pulse, outcome: BurnOutcome) -> float:
	var requested_delta_v_meters_per_second := pulse.requested_delta_v_meters_per_second()
	if not outcome.did_fire or requested_delta_v_meters_per_second <= 0.0:
		return 0.0
	return outcome.delta_v_delivered_meters_per_second / requested_delta_v_meters_per_second


func _terminal_boundary_time_seconds() -> float:
	if _coast_segment == null:
		return INF
	if _coast_segment.end_reason == TrajectorySegment.EndReason.IMPACT:
		return _coast_segment.end_time_seconds
	if _coast_segment.end_reason == TrajectorySegment.EndReason.ESCAPE:
		var escape_time_seconds := _coast_segment.end_time_seconds
		if is_finite(escape_time_seconds) and _has_escaped(_state_on_coast(escape_time_seconds)):
			return escape_time_seconds
	return INF


func _escape_crossing_time_seconds(upper_time_seconds: float) -> float:
	if _coast_segment == null or _coast_segment.elements == null or not _coast_segment.elements.is_open:
		return upper_time_seconds
	if _has_escaped(craft_state):
		return simulation_time_seconds
	if not _has_escaped(_state_on_coast(upper_time_seconds)):
		return upper_time_seconds
	var lower_time_seconds := simulation_time_seconds
	while upper_time_seconds - lower_time_seconds > 1.0e-6:
		var midpoint_seconds := (lower_time_seconds + upper_time_seconds) * 0.5
		if _has_escaped(_state_on_coast(midpoint_seconds)):
			upper_time_seconds = midpoint_seconds
		else:
			lower_time_seconds = midpoint_seconds
	return upper_time_seconds


func _physical_end_reason() -> int:
	if _coast_segment == null:
		return -1
	if _coast_segment.end_reason == TrajectorySegment.EndReason.IMPACT:
		if simulation_time_seconds >= _coast_segment.end_time_seconds:
			return FlightResult.EndReason.CRASHED if _has_reached_stable_orbit else FlightResult.EndReason.LAUNCH_FAILURE
	if _has_escaped(craft_state):
		return FlightResult.EndReason.ESCAPED
	return -1


func _has_escaped(state: OrbitState) -> bool:
	return (_coast_segment.elements != null and _coast_segment.elements.is_open
			and state.radius_meters() >= OrbitModel.escape_radius_meters(_body) - 1.0e-6)


func _is_stable_orbit(elements: OrbitElements) -> bool:
	return (elements != null and not elements.is_open
			and elements.periapsis_radius_meters > OrbitModel.impact_radius_meters(_body))


func _gravitational_parameter() -> float:
	return _body["gravitational_parameter_cubic_meters_per_second_squared"]


func _fuel_kilograms() -> float:
	var fuel_kilograms := 0.0
	for stage_id in vehicle_state.propellant_kilograms_by_stage:
		if not vehicle_state.is_jettisoned_by_stage.get(stage_id, true):
			fuel_kilograms += vehicle_state.propellant_kilograms_by_stage[stage_id]
	return fuel_kilograms


## Full propellant capacity of the stages not yet dropped, in kilograms. The
## low-fuel alarm compares the propellant on board with this, so it does not
## stay on after a stage separation.
func _attached_propellant_capacity_kilograms() -> float:
	var capacity_kilograms := 0.0
	for stage in vehicle_state.design.stages:
		if not vehicle_state.is_jettisoned_by_stage.get(stage.stage_id, true):
			capacity_kilograms += RocketModel.full_propellant_kilograms(stage)
	return capacity_kilograms


func _remaining_delta_v_meters_per_second() -> float:
	if _plan.planning_mode == MissionPlan.PlanningMode.AUTOMATIC:
		return SequentialPropulsion.apply_burn(vehicle_state.duplicate_vehicle_state(), INF).outcome.delta_v_delivered_meters_per_second
	var remaining_delta_v_meters_per_second := 0.0
	for stage in vehicle_state.design.stages:
		remaining_delta_v_meters_per_second += RocketModel.available_delta_v_meters_per_second(
				vehicle_state, stage.stage_id)
	return remaining_delta_v_meters_per_second


func _acceleration_meters_per_second_squared() -> float:
	if _launch_stage != null:
		var burn_remaining_seconds := _launch_stage_ends_at_seconds - simulation_time_seconds
		var mass_kilograms := _launch_stage_start_mass_kilograms - _launch_stage_propellant_kilograms
		mass_kilograms += burn_remaining_seconds * _launch_stage_mass_flow_kilograms_per_second
		return _burn_thrust_newtons / mass_kilograms if mass_kilograms > 0.0 else 0.0
	if _plan.planning_mode == MissionPlan.PlanningMode.AUTOMATIC:
		for readout in _readout_stages:
			var elapsed_seconds: float = simulation_time_seconds - float(readout["start_seconds"])
			var duration_seconds: float = readout["duration_seconds"]
			if elapsed_seconds >= 0.0 and elapsed_seconds < duration_seconds:
				var mass_kilograms: float = float(readout["mass_kilograms"]) - float(readout["propellant_kilograms"]) * elapsed_seconds / duration_seconds
				return float(readout["thrust_newtons"]) / mass_kilograms if mass_kilograms > 0.0 else 0.0
		return 0.0
	if simulation_time_seconds < _pulse_readout_ends_at_seconds:
		var elapsed_fraction := ((simulation_time_seconds - _pulse_start_time_seconds)
				/ (_pulse_readout_ends_at_seconds - _pulse_start_time_seconds))
		var mass_kilograms := _pulse_initial_mass_kilograms - elapsed_fraction * _pulse_propellant_used_kilograms
		return _burn_thrust_newtons / mass_kilograms if mass_kilograms > 0.0 else 0.0
	return 0.0


func _sample_instruments() -> void:
	var flight_path_angle_radians := Kepler.flight_path_angle_radians(craft_state)
	var attitude_radians := flight_path_angle_radians
	if _launch_stage != null:
		attitude_radians = _plan.launch_angle_radians
	elif simulation_time_seconds < _pulse_readout_ends_at_seconds:
		attitude_radians = _pulse_attitude_radians
	var values_by_channel := {
		TelemetryFrame.CHANNEL_ALTITUDE_METERS: Kepler.altitude_meters(craft_state, _body),
		TelemetryFrame.CHANNEL_FUEL_KILOGRAMS: _fuel_kilograms(),
		TelemetryFrame.CHANNEL_ATTITUDE_RADIANS: attitude_radians,
		TelemetryFrame.CHANNEL_FLIGHT_PATH_ANGLE_RADIANS: flight_path_angle_radians,
		TelemetryFrame.CHANNEL_TEMPERATURE_KELVIN: _temperature_kelvin,
	}
	_telemetry_feed.sample(values_by_channel, craft_state, vehicle_state, threats, _gravitational_parameter())


func _create_telemetry_frame() -> TelemetryFrame:
	var frame := TelemetryFrame.new()
	frame.simulation_time_seconds = simulation_time_seconds
	frame.time_scale = time_scale
	frame.delta_v_remaining_meters_per_second = _remaining_delta_v_meters_per_second()
	frame.seconds_until_next_pulse = _next_planned_pulse_time_seconds() - simulation_time_seconds
	frame.data_generated_megabits = _data_generated_megabits
	frame.data_delivered_megabits = _data_delivered_megabits
	_telemetry_feed.fill_frame(frame, craft_state, vehicle_state, threats, _gravitational_parameter())
	var acceleration := TelemetryReading.new()
	acceleration.is_sensor_installed = true
	acceleration.is_sensor_working = true
	acceleration.value = _acceleration_meters_per_second_squared()
	frame.readings_by_channel[TelemetryFrame.CHANNEL_ACCELERATION_METERS_PER_SECOND_SQUARED] = acceleration
	var attached_capacity_kilograms := _attached_propellant_capacity_kilograms()
	if attached_capacity_kilograms > 0.0 and _fuel_kilograms() <= attached_capacity_kilograms * LOW_FUEL_FRACTION:
		frame.active_alarms.append("LOW_FUEL")
	if _temperature_kelvin >= OVER_TEMPERATURE_KELVIN:
		frame.active_alarms.append("OVER_TEMPERATURE")
	if TelemetryFeed.nearest_threat_range_meters(craft_state, threats, _gravitational_parameter()) <= HAZARD_RANGE_METERS:
		frame.active_alarms.append("HAZARD_NEAR")
	return frame


func _configure_science(mission: Dictionary) -> void:
	_science_inner_radius_meters = INF
	_science_outer_radius_meters = -INF
	_science_rates_by_instrument.clear()
	_data_generated_megabits = 0.0
	_data_delivered_megabits = 0.0
	var chosen_science_id := GameState.science_mission_id
	if mission.get("id", "") != GameState.mission.get("id", ""):
		return
	for science_mission: Dictionary in mission.get("science_missions", []):
		if science_mission.get("id", "") != chosen_science_id:
			continue
		var zone: Dictionary = science_mission.get("zone", {})
		if zone.get("type", "") == "altitude_band":
			var body_radius_meters: float = _body["radius_meters"]
			_science_inner_radius_meters = body_radius_meters + 1000.0 * float(zone["inner_altitude_kilometers"])
			_science_outer_radius_meters = body_radius_meters + 1000.0 * float(zone["outer_altitude_kilometers"])
		break
	for part_id in vehicle_state.design.payload_part_ids:
		var part: Dictionary = GameData.part(part_id)
		var mission_fit: Dictionary = part.get("mission_fit", {})
		var fit_rating: float = float(mission_fit.get(chosen_science_id, 0.0))
		if part.get("category", "") == "science" and fit_rating > 0.0:
			var rate: float = part["stats"].get("data_rate_megabits_per_second", 0.0)
			_science_rates_by_instrument[part_id] = _science_rates_by_instrument.get(part_id, 0.0) + rate


func _collect_science(state: OrbitState, interval_seconds: float) -> void:
	var radius_meters := state.radius_meters()
	if radius_meters < _science_inner_radius_meters or radius_meters > _science_outer_radius_meters:
		return
	var data_rate_megabits_per_second := 0.0
	for part_id in _science_rates_by_instrument:
		if vehicle_state.is_working_by_instrument.get(part_id, false):
			data_rate_megabits_per_second += _science_rates_by_instrument[part_id]
	var generated_megabits := data_rate_megabits_per_second * interval_seconds
	_data_generated_megabits += generated_megabits
	_data_delivered_megabits += DataLink.deliver(generated_megabits, state, interval_seconds)


func _final_elements() -> OrbitElements:
	if _coast_segment == null or craft_state.radius_meters() <= 0.0:
		return null
	return Kepler.elements_from_state(_gravitational_parameter(), craft_state)


func _create_flight_result(end_reason: FlightResult.EndReason) -> FlightResult:
	var result := FlightResult.new()
	result.end_reason = end_reason
	if end_reason != FlightResult.EndReason.LAUNCH_FAILURE:
		result.final_elements = _final_elements()
	result.did_reach_orbit = _is_stable_orbit(result.final_elements)
	result.flight_duration_seconds = simulation_time_seconds
	result.reserve_delta_v_meters_per_second = _remaining_delta_v_meters_per_second()
	result.data_generated_megabits = _data_generated_megabits
	result.data_delivered_megabits = _data_delivered_megabits
	if result.final_elements != null and not result.final_elements.is_open:
		if _science_inner_radius_meters <= _science_outer_radius_meters:
			result.science_coverage_fraction = Kepler.fraction_of_period_inside_band(
					result.final_elements, _science_inner_radius_meters, _science_outer_radius_meters)
	result.installed_instrument_count = vehicle_state.is_working_by_instrument.size()
	result.working_instrument_count = vehicle_state.working_instrument_count()
	result.event_log = event_log.duplicate(true)
	return result


func _begin_automatic_departure_stage() -> void:
	var remaining_meters_per_second: float = _automatic_departure_requested_meters_per_second - _automatic_departure_delivered_meters_per_second
	var preview: BurnAllocation = SequentialPropulsion.apply_burn(vehicle_state.duplicate_vehicle_state(), remaining_meters_per_second)
	if preview.stage_ids.is_empty() or remaining_meters_per_second <= SequentialPropulsion.DELTA_V_TOLERANCE_METERS_PER_SECOND:
		_launch_stage = null
		_launch_stage_ends_at_seconds = INF
		var site_angle_radians: float = deg_to_rad(_automatic_mission.get("launch_site", {}).get("polar_angle_degrees", 90.0))
		var loss_meters_per_second: float = _automatic_mission.get("launch_loss_meters_per_second", 0.0)
		_burnout_state = Kepler.launch_state(_body, site_angle_radians,
				maxf(0.0, _automatic_departure_delivered_meters_per_second - loss_meters_per_second), _plan.launch_angle_radians)
		_burnout_state.time_seconds = simulation_time_seconds
		craft_state = _burnout_state.duplicate_state()
		_rebuild_trajectory()
		return
	var stage_id: int = preview.stage_ids[0]
	var outcome: BurnOutcome = preview.stage_outcomes[0]
	_launch_stage = vehicle_state.design.find_stage(stage_id)
	_automatic_stage_request_meters_per_second = outcome.delta_v_delivered_meters_per_second
	var stats: Dictionary = GameData.part(_launch_stage.engine_part_id).get("stats", {})
	_burn_thrust_newtons = float(stats.get("thrust_kilonewtons", 0.0)) * 1000.0 * float(vehicle_state.specific_impulse_factor_by_stage.get(stage_id, 1.0))
	_launch_stage_start_mass_kilograms = outcome.mass_before_kilograms
	_launch_stage_propellant_kilograms = outcome.propellant_used_kilograms
	_launch_stage_mass_flow_kilograms_per_second = outcome.propellant_used_kilograms / outcome.burn_duration_seconds if outcome.burn_duration_seconds > 0.0 else 0.0
	_launch_stage_ends_at_seconds = simulation_time_seconds + maxf(0.000001, outcome.burn_duration_seconds)


func _rebuild_automatic_trajectory() -> void:
	if _automatic_insertion_pending:
		var completion: AscentResult = AscentPlanner.complete_from_departure(_body, _automatic_mission, craft_state, vehicle_state)
		if completion.orbit_entry_state != null:
			_automatic_insertion_time_seconds = completion.orbit_entry_state.time_seconds
		else:
			_automatic_insertion_pending = false
			_automatic_insertion_time_seconds = INF
		if not completion.trajectory.segments.is_empty():
			completion.trajectory.segments[0].source_stage_id = _last_source_stage_id
		trajectory = PlanResolver.resolve_after_ascent(_body, _plan, completion, _next_pulse_index).trajectory
	else:
		trajectory = PlanResolver.resolve_remaining(_body, craft_state, vehicle_state, _plan, _next_pulse_index, _last_source_stage_id).trajectory
	_coast_segment = null if trajectory.segments.is_empty() else trajectory.segments[0]
	_has_reached_stable_orbit = _has_reached_stable_orbit or _is_stable_orbit(_final_elements())


func _fire_automatic_insertion() -> void:
	if not _automatic_insertion_pending or simulation_time_seconds < _automatic_insertion_time_seconds:
		return
	var before_state: OrbitState = craft_state.duplicate_state()
	var request_meters_per_second: float = maxf(0.0, Kepler.circular_speed_meters_per_second(
			_gravitational_parameter(), craft_state.radius_meters()) - craft_state.speed_meters_per_second())
	var allocation: BurnAllocation = SequentialPropulsion.apply_burn(vehicle_state, request_meters_per_second)
	craft_state = Kepler.apply_pulse(craft_state, allocation.outcome.delta_v_delivered_meters_per_second, 0.0)
	_automatic_insertion_pending = false
	_automatic_insertion_time_seconds = INF
	_record_allocation_readout(allocation, before_state, "Automatic orbit insertion")
	_rebuild_trajectory()


func _apply_automatic_pulse(pulse: Pulse) -> BurnOutcome:
	var before_state: OrbitState = craft_state.duplicate_state()
	var requested_meters_per_second: float = pulse.requested_delta_v_meters_per_second()
	var allocation: BurnAllocation = SequentialPropulsion.apply_burn(vehicle_state, requested_meters_per_second, true)
	if allocation.outcome.did_fire:
		var delivered_share: float = allocation.outcome.delta_v_delivered_meters_per_second / requested_meters_per_second
		craft_state = Kepler.apply_pulse(craft_state,
				pulse.delta_v_along_velocity_meters_per_second * delivered_share,
				pulse.delta_v_outward_meters_per_second * delivered_share)
		_record_allocation_readout(allocation, before_state, "Pulse")
	return allocation.outcome


func _record_allocation_readout(allocation: BurnAllocation, before_state: OrbitState, description: String) -> void:
	if allocation.last_stage_id() != 0:
		_last_source_stage_id = allocation.last_stage_id()
	_readout_stages.clear()
	var start_seconds: float = simulation_time_seconds
	for stage_index in allocation.stage_ids.size():
		var stage_id: int = allocation.stage_ids[stage_index]
		var outcome: BurnOutcome = allocation.stage_outcomes[stage_index]
		var stage: Stage = vehicle_state.design.find_stage(stage_id)
		var stats: Dictionary = GameData.part(stage.engine_part_id).get("stats", {})
		_readout_stages.append({
			"start_seconds": start_seconds, "duration_seconds": outcome.burn_duration_seconds,
			"mass_kilograms": outcome.mass_before_kilograms, "propellant_kilograms": outcome.propellant_used_kilograms,
			"thrust_newtons": float(stats.get("thrust_kilonewtons", 0.0)) * 1000.0 * float(vehicle_state.specific_impulse_factor_by_stage.get(stage_id, 1.0)),
		})
		start_seconds += outcome.burn_duration_seconds
		log_event({"time_seconds": simulation_time_seconds, "event_type_id": "automatic_staging",
			"description": "%s: stage %d delivered %.1f m/s, consumed %.1f kg." % [description, SequentialPropulsion.stage_number(vehicle_state.design, stage_id),
				outcome.delta_v_delivered_meters_per_second, outcome.propellant_used_kilograms],
			"stage_id": stage_id, "delta_v_meters_per_second": outcome.delta_v_delivered_meters_per_second,
			"propellant_used_kilograms": outcome.propellant_used_kilograms})
	_pulse_start_time_seconds = simulation_time_seconds
	_pulse_readout_ends_at_seconds = start_seconds
	var thrust_direction: OrbitState = OrbitState.create(before_state.position_x_meters, before_state.position_y_meters,
			craft_state.velocity_x_meters_per_second - before_state.velocity_x_meters_per_second,
			craft_state.velocity_y_meters_per_second - before_state.velocity_y_meters_per_second)
	_pulse_attitude_radians = Kepler.flight_path_angle_radians(thrust_direction)
