extends Control
## Runs one repeatable conjunction against the reference flight with a working radar.

const MISSION_ID := "low_earth_orbit_placeholder"
const RANDOM_SEED := 7
const POST_CIRCULARIZATION_DELAY_SECONDS := 15.0
const STARTUP_SIMULATION_LIMIT_SECONDS := 1200.0
const ENCOUNTER_LEAD_SECONDS := 240.0
const SATELLITE_OUTWARD_SPEED_METERS_PER_SECOND := 120.0
const SATELLITE_OFFSET_METERS := 20.0
const SATELLITE_RADIUS_METERS := 100.0
const FLIGHT_SCRIPT := preload("res://autoload/FlightSimulation.gd")
const DIRECTOR_SCRIPT := preload("res://autoload/EventDirector.gd")

var _flight: Node = FLIGHT_SCRIPT.new()
var _director: Node = DIRECTOR_SCRIPT.new()
var _mission: Dictionary
var _body: Dictionary
var _force_at_seconds := INF
var _reserve_before_burn_meters_per_second := 0.0


func _ready() -> void:
	_mission = GameData.mission(MISSION_ID)
	_body = GameData.body(_mission["body_id"])
	%OrbitMap.configure(_body, _mission)
	add_child(_flight)
	var accepted_side_quests: Array[Dictionary] = []
	_director.configure(_flight, _mission, accepted_side_quests, RANDOM_SEED, false)
	add_child(_director)
	_flight.pulse_fired.connect(_on_pulse_fired)
	_flight.simulation_step.connect(_on_simulation_step)
	_flight.telemetry_updated.connect(_on_telemetry_updated)
	_flight.flight_ended.connect(_on_flight_ended)
	%Restart.pressed.connect(_start_demo)
	%FastForward.pressed.connect(_flight.set_time_scale.bind(8.0 * FlightSimulation.NORMAL_TIME_SCALE))
	_start_demo.call_deferred()


func _start_demo() -> void:
	_force_at_seconds = INF
	_reserve_before_burn_meters_per_second = 0.0
	%Status.text = "Flying to circularization"
	%Outcome.text = ""
	%FastForward.disabled = false
	var design := RocketDesign.new()
	var plan := MissionPlan.new()
	ExampleFlight.fill_reference_rocket(design, plan)
	design.payload_part_ids.append("telemetry_radar_standard")
	plan.launch_angle_radians = ExampleFlight.find_launch_angle_radians(design, plan, _mission)
	plan.pulses.append(ExampleFlight.create_circularizing_pulse(design, plan, _mission))
	_flight.start_flight(design, plan, _mission, RANDOM_SEED)
	# Follow the actual burnout and pulse signals rather than the planning clock.
	while (_flight.is_flying and _flight.time_scale > 0.0
			and _flight.simulation_time_seconds < STARTUP_SIMULATION_LIMIT_SECONDS):
		_flight.advance_simulation(FlightSimulation.SIMULATION_STEP_SECONDS)
	if _director.active_encounter.is_empty() and _flight.is_flying:
		%Status.text = "The demo could not create its conjunction."


func _on_pulse_fired(pulse_index: int, outcome: BurnOutcome) -> void:
	if not outcome.did_fire:
		return
	if pulse_index >= 0:
		_force_at_seconds = _flight.simulation_time_seconds + POST_CIRCULARIZATION_DELAY_SECONDS
		%Status.text = "Orbit established"
	else:
		%Status.text = "Maneuver executed   Δv %.2f m/s" % outcome.delta_v_delivered_meters_per_second
		%OrbitMap.show_trajectory(_flight.trajectory)


func _on_simulation_step(_step_seconds: float) -> void:
	if _flight.simulation_time_seconds < _force_at_seconds:
		return
	_force_at_seconds = INF
	var now_seconds: float = _flight.simulation_time_seconds
	var approach_seconds := now_seconds + ENCOUNTER_LEAD_SECONDS
	var projected_craft := OrbitModel.state_at_time(_body, _flight.trajectory, approach_seconds)
	if projected_craft == null:
		return
	var intercept := Kepler.apply_pulse(projected_craft, 0.0, SATELLITE_OUTWARD_SPEED_METERS_PER_SECOND)
	var speed_meters_per_second := projected_craft.speed_meters_per_second()
	intercept.position_x_meters += (
			SATELLITE_OFFSET_METERS * projected_craft.velocity_x_meters_per_second / speed_meters_per_second)
	intercept.position_y_meters += (
			SATELLITE_OFFSET_METERS * projected_craft.velocity_y_meters_per_second / speed_meters_per_second)
	var threat := Threat.new()
	threat.event_type_id = "satellite_conjunction"
	threat.collision_radius_meters = SATELLITE_RADIUS_METERS
	threat.state = Kepler.propagate(
			_body[OrbitModel.GRAVITATIONAL_PARAMETER_KEY], intercept, now_seconds - approach_seconds)
	var threats: Array[Threat] = [threat]
	if _director.force_encounter(threat.event_type_id, threats, approach_seconds):
		_reserve_before_burn_meters_per_second = _remaining_delta_v_meters_per_second()
		%Status.text = "Conjunction detected"


func _remaining_delta_v_meters_per_second() -> float:
	var reserve_meters_per_second := 0.0
	var vehicle: VehicleState = _flight.vehicle_state
	for stage in vehicle.design.stages:
		reserve_meters_per_second += RocketModel.available_delta_v_meters_per_second(vehicle, stage.stage_id)
	return reserve_meters_per_second


func _on_telemetry_updated(frame: TelemetryFrame) -> void:
	%Clock.text = "Mission time   T+ %s  ·  %s" % [ReadingFormat.mission_time_text(frame.simulation_time_seconds),
			ReadingFormat.time_scale_label(frame.time_scale)]
	%Reserve.text = "Reserve   %.2f m/s" % frame.delta_v_remaining_meters_per_second
	if frame.delta_v_remaining_meters_per_second < _reserve_before_burn_meters_per_second - 0.001:
		%Reserve.text += "   (was %.2f m/s)" % _reserve_before_burn_meters_per_second
	%OrbitMap.show_trajectory(_flight.trajectory)
	%OrbitMap.show_craft(_flight.craft_state)
	if not _flight.event_log.is_empty():
		var outcome: String = _flight.event_log[0].get("outcome", "")
		if outcome == "Threat avoided":
			%Outcome.text = outcome
			_flight.pause()
			%FastForward.disabled = true


func _on_flight_ended(result: FlightResult) -> void:
	%FastForward.disabled = true
	match result.end_reason:
		FlightResult.EndReason.COLLISION:
			%Outcome.text = "Collision"
		FlightResult.EndReason.ESCAPED:
			%Outcome.text = "Escape"
		FlightResult.EndReason.CRASHED, FlightResult.EndReason.LAUNCH_FAILURE:
			%Outcome.text = "Atmosphere impact"
		_:
			%Outcome.text = "Flight complete"
