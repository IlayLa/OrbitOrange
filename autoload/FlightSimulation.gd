extends Node
## Flies the planned mission and tells the control room what its instruments
## see. This node owns the true state of the craft during EXECUTION; screens
## only ever receive TelemetryFrame objects.
##
## STUB(T03): the signals and public functions are final. The body flies the
## trajectory that was planned, fires no pulses, degrades no telemetry and
## ends when the mission duration runs out. T03 replaces it.

## Emitted once per fixed step of simulated time (SIMULATION_STEP_SECONDS), no
## matter how fast time is running. EventDirector rolls for events here.
signal simulation_step(step_seconds: float)
## Emitted once per drawn frame with what the instruments currently show.
signal telemetry_updated(frame: TelemetryFrame)
## Emitted when a planned or emergency pulse has fired.
signal pulse_fired(pulse_index: int, outcome: BurnOutcome)
## Emitted when something needs the player's attention. Time is paused first.
signal alert_raised(alarm_code: String, message: String)
signal flight_started
signal flight_ended(result: FlightResult)

const SIMULATION_STEP_SECONDS := 5.0
## 0 means paused. The other values are simulated seconds per real second.
const ALLOWED_TIME_SCALES: Array[float] = [0.0, 1.0, 10.0, 100.0, 1000.0]

var is_flying: bool = false
var time_scale: float = 1.0
var simulation_time_seconds: float = 0.0
## The true position and velocity of the craft. Screens must not read this.
var craft_state: OrbitState
var vehicle_state: VehicleState
var trajectory: Trajectory
var threats: Array[Threat] = []
var event_log: Array[Dictionary] = []

var _mission: Dictionary = {}
var _body: Dictionary = {}
var _seconds_not_yet_simulated: float = 0.0


## Starts a flight from the launch pad. random_seed makes every random roll
## repeatable, so the same seed gives the same flight.
func start_flight(design: RocketDesign, plan: MissionPlan, mission: Dictionary, _random_seed: int) -> void:
	_mission = mission
	_body = GameData.body(mission.get("body_id", "earth"))
	vehicle_state = RocketModel.create_vehicle_state(design)
	trajectory = PlanResolver.resolve(design, plan, mission).trajectory
	threats = []
	event_log = []
	simulation_time_seconds = 0.0
	_seconds_not_yet_simulated = 0.0
	time_scale = 1.0
	craft_state = OrbitModel.state_at_time(_body, trajectory, 0.0)
	is_flying = true
	flight_started.emit()


## Sets how fast time runs. Use one of ALLOWED_TIME_SCALES.
func set_time_scale(new_time_scale: float) -> void:
	if ALLOWED_TIME_SCALES.has(new_time_scale):
		time_scale = new_time_scale


func pause() -> void:
	time_scale = 0.0


## Fires a pulse right now at the craft's current position and re-plans the
## rest of the flight from the new orbit.
## STUB(T03): does nothing and reports that the engine did not fire.
func apply_emergency_pulse(_pulse: Pulse) -> BurnOutcome:
	return BurnOutcome.new()


func add_threat(threat: Threat) -> void:
	threats.append(threat)


func remove_threat(threat_id: int) -> void:
	for threat_index in threats.size():
		if threats[threat_index].threat_id == threat_id:
			threats.remove_at(threat_index)
			return


## Adds one entry to the event log shown on the final screen.
## See FlightResult.event_log for the keys.
func log_event(event_record: Dictionary) -> void:
	event_log.append(event_record)


## Pauses time and tells the control room that something needs attention.
func raise_alert(alarm_code: String, message: String) -> void:
	pause()
	alert_raised.emit(alarm_code, message)


## Ends the flight now and reports the result.
func end_flight(end_reason: FlightResult.EndReason) -> void:
	if not is_flying:
		return
	is_flying = false
	flight_ended.emit(_create_flight_result(end_reason))


func _process(real_seconds_since_last_frame: float) -> void:
	if not is_flying or time_scale == 0.0:
		return

	_seconds_not_yet_simulated += real_seconds_since_last_frame * time_scale
	while _seconds_not_yet_simulated >= SIMULATION_STEP_SECONDS and is_flying:
		_seconds_not_yet_simulated -= SIMULATION_STEP_SECONDS
		simulation_time_seconds += SIMULATION_STEP_SECONDS
		craft_state = OrbitModel.state_at_time(_body, trajectory, simulation_time_seconds)
		simulation_step.emit(SIMULATION_STEP_SECONDS)
		var mission_duration_seconds: float = _mission.get("duration_seconds", 0.0)
		if simulation_time_seconds >= mission_duration_seconds:
			end_flight(FlightResult.EndReason.MISSION_COMPLETED)

	if is_flying:
		telemetry_updated.emit(_create_telemetry_frame())


## STUB(T03): reports the true altitude with no sensor model.
func _create_telemetry_frame() -> TelemetryFrame:
	var frame := TelemetryFrame.new()
	frame.simulation_time_seconds = simulation_time_seconds
	frame.time_scale = time_scale
	var altitude_reading := TelemetryReading.new()
	altitude_reading.is_sensor_installed = true
	altitude_reading.is_sensor_working = true
	altitude_reading.sensor_tier = 1
	altitude_reading.value = Kepler.altitude_meters(craft_state, _body)
	frame.readings_by_channel[TelemetryFrame.CHANNEL_ALTITUDE_METERS] = altitude_reading
	return frame


func _create_flight_result(end_reason: FlightResult.EndReason) -> FlightResult:
	var gravitational_parameter: float = _body["gravitational_parameter_cubic_meters_per_second_squared"]
	var result := FlightResult.new()
	result.end_reason = end_reason
	result.final_elements = Kepler.elements_from_state(gravitational_parameter, craft_state)
	result.did_reach_orbit = trajectory.status == Trajectory.Status.REACHES_ORBIT
	result.flight_duration_seconds = simulation_time_seconds
	result.installed_instrument_count = vehicle_state.is_working_by_instrument.size()
	result.working_instrument_count = vehicle_state.working_instrument_count()
	result.event_log = event_log.duplicate()
	return result
