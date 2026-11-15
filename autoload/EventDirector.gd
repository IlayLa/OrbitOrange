extends Node
## Rolls flight events on the fixed simulation clock and resolves encounters.

const EventRates = preload("res://scripts/events/EventRates.gd")
const EventFaults = preload("res://scripts/events/EventFaults.gd")
const ThreatModel = preload("res://scripts/events/ThreatModel.gd")
const EMERGENCY_OVERLAY_PATH := "res://scenes/events/EmergencyOverlay.tscn"
const FALLBACK_WARNING_SECONDS := 10.0
const COLLISION_RADII_METERS := {
	"satellite_conjunction": 100.0,
	"debris_shower": 25.0,
	"unknown_asteroid": 250.0,
}
const DEBRIS_FRAGMENT_COUNT := 3

## Empty unless an encounter is paused for player action.
var active_encounter: Dictionary = {}

var _flight: Node
var _configured_mission: Dictionary = {}
var _configured_quests: Array[Dictionary] = []
var _configured_seed: int = 0
var _rolls_enabled := true
var _overlay_enabled := true
var _mission: Dictionary = {}
var _body: Dictionary = {}
var _quests: Array[Dictionary] = []
var _deadline_seconds := 0.0
var _event_types: Array[Dictionary] = []
var _random := RandomNumberGenerator.new()
var _faults := EventFaults.new()
var _encounters: Array[Dictionary] = []
var _used_threat_ids: Dictionary = {}
var _next_threat_id := 1
var _next_encounter_id := 1
var _session_number := 0
var _is_session_active := false
var _needs_prediction_refresh := false
var _needs_flight_forecast_refresh := false
var _elapsed_trajectory: Trajectory
var _elapsed_trajectory_start_seconds := 0.0
var _flown_pieces: Array[Dictionary] = []
var _alert_layer: CanvasLayer
var _alert_scene: Node


func _ready() -> void:
	if _flight == null:
		_connect_flight(FlightSimulation)


## Connects a fresh director to an isolated flight before it starts.
## Tests can disable modal rendering while retaining alert and pause behavior.
func configure(
		flight: Node, mission: Dictionary, accepted_side_quests: Array[Dictionary], random_seed: int,
		rolls_enabled: bool = true, overlay_enabled: bool = true) -> void:
	assert(_flight == null, "Configure an isolated director before connecting to a flight.")
	_configured_mission = mission
	_configured_quests = accepted_side_quests
	_configured_seed = random_seed
	_rolls_enabled = rolls_enabled
	_overlay_enabled = overlay_enabled
	_connect_flight(flight)


## Triggers a catalogue event without a probability roll. Returns whether it was logged.
func force_event(event_type_id: String) -> bool:
	if not _is_session_active or not _can_start_event(_flight.simulation_time_seconds):
		return false
	var event_type := GameData.event_type(event_type_id)
	if event_type.is_empty():
		return false
	_apply_event(event_type, _flight.simulation_time_seconds)
	_faults.sync_interference(_flight, _flight.simulation_time_seconds)
	_refresh_flight_forecast()
	_refresh_predictions(_flight.simulation_time_seconds)
	return true


## Registers placed fixture objects through the normal encounter path.
## The target time is in seconds since launch. A zero object ID requests a new ID.
func force_encounter(event_type_id: String, threats: Array[Threat], target_time_seconds: float) -> bool:
	if not _is_session_active or not _can_start_event(_flight.simulation_time_seconds):
		return false
	return _register_encounter(
			GameData.event_type(event_type_id), threats, _flight.simulation_time_seconds, target_time_seconds)


## Acknowledges the current alert. A null pulse means Ignore.
## Returns the live burn outcome and leaves the alert open when a pulse fails.
func acknowledge_alert(pulse: Pulse = null) -> BurnOutcome:
	var outcome := BurnOutcome.new()
	if not _is_session_active or not _flight.is_flying or active_encounter.is_empty():
		return outcome
	var encounter := active_encounter
	if encounter["is_acknowledged"] or encounter["is_burn_in_progress"]:
		return outcome
	var session_number := _session_number
	if pulse != null:
		var requested_delta_v_meters_per_second := pulse.requested_delta_v_meters_per_second()
		if (not pulse.fires_immediately or not is_finite(requested_delta_v_meters_per_second)
				or requested_delta_v_meters_per_second <= 0.0
				or RocketModel.available_delta_v_meters_per_second(_flight.vehicle_state, pulse.stage_id) <= 0.0):
			return outcome
		encounter["is_burn_in_progress"] = true
		outcome = _flight.apply_emergency_pulse(pulse)
		encounter["is_burn_in_progress"] = false
		if not outcome.did_fire or session_number != _session_number:
			return outcome
		var row := _event_row(encounter)
		row["did_player_react"] = true
		row["delta_v_spent_meters_per_second"] += outcome.delta_v_delivered_meters_per_second
		_refresh_predictions(_flight.simulation_time_seconds)
	encounter["is_acknowledged"] = true
	if encounter["hit_count"] == 0:
		var reaction := "An emergency maneuver fired." if outcome.did_fire else "The player continued without a maneuver."
		_set_encounter_outcome(encounter, "Pending", reaction + " The encounter was still in progress.")
	_close_active_alert()
	_resume_after_alert()
	return outcome


func _connect_flight(flight: Node) -> void:
	_flight = flight
	_flight.flight_started.connect(_on_flight_started)
	_flight.simulation_step.connect(_on_simulation_step)
	_flight.pulse_fired.connect(_on_pulse_fired)
	_flight.flight_ended.connect(_on_flight_ended)


func _on_flight_started() -> void:
	_reset_runtime(false)
	if _flight == FlightSimulation:
		_mission = GameState.mission.duplicate(true)
		_quests = GameState.accepted_side_quests().duplicate(true)
		_random.randomize()
	else:
		_mission = _configured_mission.duplicate(true)
		_quests = _configured_quests.duplicate(true)
		_random.seed = _configured_seed
	_body = GameData.body(_mission.get("body_id", "earth")).duplicate(true)
	_deadline_seconds = maxf(0.0, float(_mission.get("duration_seconds", 0.0)))
	_event_types = GameData.all_event_types()
	_event_types.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return first["id"] < second["id"])
	_elapsed_trajectory = _flight.trajectory
	_is_session_active = not _body.is_empty()


func _on_flight_ended(_result: FlightResult) -> void:
	_reset_runtime(true)


func _reset_runtime(remove_contacts: bool) -> void:
	_is_session_active = false
	_session_number += 1
	_close_active_alert()
	if remove_contacts:
		for encounter in _encounters:
			for threat: Threat in encounter["threats"]:
				_flight.remove_threat(threat.threat_id)
	_encounters.clear()
	_used_threat_ids.clear()
	_next_threat_id = 1
	_next_encounter_id = 1
	_faults.reset(_flight)
	_needs_prediction_refresh = false
	_needs_flight_forecast_refresh = false
	_elapsed_trajectory = null
	_elapsed_trajectory_start_seconds = 0.0
	_flown_pieces.clear()


func _on_pulse_fired(_pulse_index: int, _outcome: BurnOutcome) -> void:
	if not _is_session_active:
		return
	var time_seconds: float = _flight.simulation_time_seconds
	# T03 has already replaced its forecast. The previous reference still
	# describes the coast flown up to this burn, even for a failed planned pulse.
	_keep_flown_piece_through(time_seconds)
	_elapsed_trajectory = _flight.trajectory
	_elapsed_trajectory_start_seconds = time_seconds
	_needs_prediction_refresh = true


func _keep_flown_piece_through(end_seconds: float) -> void:
	if not _encounters.is_empty() and _elapsed_trajectory != null and end_seconds > _elapsed_trajectory_start_seconds:
		_flown_pieces.append({
			"trajectory": _elapsed_trajectory,
			"start_seconds": _elapsed_trajectory_start_seconds,
			"end_seconds": end_seconds,
		})


func _on_simulation_step(step_seconds: float) -> void:
	if not _is_session_active or not _flight.is_flying:
		return
	var time_seconds: float = _flight.simulation_time_seconds
	# T03 retains precedence when it has physically ended at this boundary.
	if _has_reached_physical_boundary(time_seconds):
		return
	var start_seconds := time_seconds - step_seconds
	_keep_flown_piece_through(time_seconds)
	_elapsed_trajectory = _flight.trajectory
	_elapsed_trajectory_start_seconds = time_seconds
	if _process_collisions():
		return
	_flown_pieces.clear()
	if _faults.drain_leaks(_flight.vehicle_state, start_seconds, time_seconds):
		_needs_flight_forecast_refresh = true
	_expire_encounters(time_seconds)
	if time_seconds >= _deadline_seconds:
		return
	if _rolls_enabled and _can_start_event(time_seconds):
		_roll_events(time_seconds, step_seconds)
	_faults.sync_interference(_flight, time_seconds)
	_refresh_flight_forecast()
	_refresh_predictions(time_seconds)
	if _can_start_event(time_seconds):
		_surface_alert(time_seconds)


func _can_start_event(time_seconds: float) -> bool:
	var state: OrbitState = _flight.craft_state
	var trajectory: Trajectory = _flight.trajectory
	return (_flight.is_flying and time_seconds < _deadline_seconds and state != null
			and state.speed_meters_per_second() > 0.0 and trajectory != null and not trajectory.segments.is_empty()
			and time_seconds >= trajectory.segments[0].start_time_seconds
			and not _has_reached_physical_boundary(time_seconds))


func _has_reached_physical_boundary(time_seconds: float) -> bool:
	var trajectory: Trajectory = _flight.trajectory
	if trajectory == null or trajectory.segments.is_empty():
		return false
	var segment := trajectory.segment_at_time(time_seconds)
	if segment.end_reason == TrajectorySegment.EndReason.IMPACT and time_seconds >= segment.end_time_seconds:
		return true
	var state: OrbitState = _flight.craft_state
	return (segment.elements != null and segment.elements.is_open and state != null
			and state.radius_meters() >= OrbitModel.escape_radius_meters(_body) - 1.0e-6)


func _roll_events(time_seconds: float, step_seconds: float) -> void:
	var altitude_kilometers := Kepler.altitude_meters(_flight.craft_state, _body) / 1000.0
	for event_type in _event_types:
		var events_per_hour := EventRates.effective_rate_events_per_hour(
				event_type, _mission, _quests, altitude_kilometers, time_seconds)
		if events_per_hour <= 0.0:
			continue
		var probability := 1.0 - exp(-events_per_hour * step_seconds / 3600.0)
		if _random.randf() < probability:
			_apply_event(event_type, time_seconds)


func _apply_event(event_type: Dictionary, time_seconds: float) -> void:
	var event_type_id: String = event_type["id"]
	if COLLISION_RADII_METERS.has(event_type_id):
		_spawn_encounter(event_type, time_seconds)
		return
	var result := _faults.apply_event(event_type_id, _flight.vehicle_state, _random, time_seconds)
	_needs_flight_forecast_refresh = _needs_flight_forecast_refresh or result["did_change_burn_capability"]
	if event_type_id == "solar_flare" and not _flight.has_method("set_telemetry_interference"):
		result["explanation"] = "A solar flare occurred. Telemetry interference is unavailable on this flight."
	_log_event(event_type_id, time_seconds, result["outcome"], result["explanation"])


func _spawn_encounter(event_type: Dictionary, time_seconds: float) -> void:
	var event_type_id: String = event_type["id"]
	var collision_radius_meters: float = COLLISION_RADII_METERS[event_type_id]
	var object_count := DEBRIS_FRAGMENT_COUNT if event_type_id == "debris_shower" else 1
	var threats: Array[Threat] = []
	var target_time_seconds := INF
	for object_index in object_count:
		var candidate := ThreatModel.generate_threat(
				_body, _flight.trajectory, _random, time_seconds, _deadline_seconds,
				collision_radius_meters, _next_threat_id + object_index, event_type_id, target_time_seconds)
		if candidate.is_empty():
			break
		threats.append(candidate["threat"])
		target_time_seconds = candidate["target_time_seconds"]
	if threats.size() == object_count and _register_encounter(event_type, threats, time_seconds, target_time_seconds):
		return
	_log_event(event_type_id, time_seconds, "Skipped", "A close pass could not be placed before this flight's projected end.")


func _register_encounter(
		event_type: Dictionary, threats: Array[Threat], start_seconds: float, target_time_seconds: float) -> bool:
	if event_type.is_empty() or event_type.get("kind", "") != "threat" or threats.is_empty():
		return false
	var terminal_time_seconds := ThreatModel.terminal_time_seconds(_flight.trajectory)
	if (not is_finite(target_time_seconds) or target_time_seconds < start_seconds
			or target_time_seconds >= minf(_deadline_seconds, terminal_time_seconds)):
		return false
	var claimed_ids: Dictionary = {}
	var claimed_objects: Dictionary = {}
	var current_threats: Array[Threat] = _flight.threats
	for contact in current_threats:
		claimed_ids[contact.threat_id] = true
	var event_type_id: String = event_type["id"]
	for threat in threats:
		if threat == null or threat.state == null or threat.collision_radius_meters <= 0.0 or claimed_objects.has(threat):
			return false
		claimed_objects[threat] = true
		if threat.threat_id != 0:
			if claimed_ids.has(threat.threat_id) or _used_threat_ids.has(threat.threat_id):
				return false
			claimed_ids[threat.threat_id] = true
	var expires_at_seconds := minf(_deadline_seconds, target_time_seconds + ThreatModel.EXPIRY_AFTER_TARGET_SECONDS)
	var encounter := {
		"id": _next_encounter_id,
		"event_type_id": event_type_id,
		"event_name": event_type.get("name", event_type_id),
		"start_seconds": start_seconds,
		"expires_at_seconds": expires_at_seconds,
		"threats": threats.duplicate(),
		"is_alerted": false,
		"is_acknowledged": false,
		"is_burn_in_progress": false,
		"hit_count": 0,
		"damaged_instruments": [],
		"warning": "",
		"log_index": _log_event(event_type_id, start_seconds, "Pending", "A close pass was predicted and the encounter was still in progress."),
	}
	_next_encounter_id += 1
	for threat in threats:
		if threat.threat_id == 0:
			while claimed_ids.has(_next_threat_id) or _used_threat_ids.has(_next_threat_id):
				_next_threat_id += 1
			threat.threat_id = _next_threat_id
		_next_threat_id = maxi(_next_threat_id, threat.threat_id + 1)
		_used_threat_ids[threat.threat_id] = true
		threat.event_type_id = event_type_id
		_flight.add_threat(threat)
	_encounters.append(encounter)
	_needs_prediction_refresh = true
	return true


func _process_collisions() -> bool:
	var impacts: Array[Dictionary] = []
	for encounter in _encounters:
		for threat: Threat in encounter["threats"]:
			var hit_time_seconds := _hit_time_seconds(encounter, threat)
			if is_finite(hit_time_seconds):
				impacts.append({"encounter": encounter, "threat": threat, "time_seconds": hit_time_seconds})
	impacts.sort_custom(_impact_is_earlier)
	for impact in impacts:
		var encounter: Dictionary = impact["encounter"]
		var threat: Threat = impact["threat"]
		_remove_contact(encounter, threat)
		if encounter["event_type_id"] != "debris_shower":
			_set_encounter_outcome(encounter, "Collision", "The spacecraft collided with the approaching object.")
			_flight.end_flight(FlightResult.EndReason.COLLISION)
			return true
		encounter["hit_count"] += 1
		var instrument_name := _faults.damage_instrument(_flight.vehicle_state, _random)
		if not instrument_name.is_empty():
			encounter["damaged_instruments"].append(instrument_name)
		_report_debris_damage(encounter)
	return false


func _hit_time_seconds(encounter: Dictionary, threat: Threat) -> float:
	for piece in _flown_pieces:
		var start_seconds := maxf(piece["start_seconds"], encounter["start_seconds"])
		var end_seconds := minf(piece["end_seconds"], encounter["expires_at_seconds"])
		if start_seconds > end_seconds or encounter["start_seconds"] >= piece["end_seconds"]:
			continue
		var approach := ThreatModel.closest_approach(_body, piece["trajectory"], threat, start_seconds, end_seconds)
		if not approach.is_empty() and float(approach["distance_meters"]) <= threat.collision_radius_meters:
			return approach["time_seconds"]
	return INF


func _impact_is_earlier(first: Dictionary, second: Dictionary) -> bool:
	if first["time_seconds"] != second["time_seconds"]:
		return first["time_seconds"] < second["time_seconds"]
	return first["threat"].threat_id < second["threat"].threat_id


func _report_debris_damage(encounter: Dictionary) -> void:
	var hit_count: int = encounter["hit_count"]
	var instrument_names: Array = encounter["damaged_instruments"]
	var explanation := "%d debris fragments hit the spacecraft." % hit_count
	if hit_count == 1:
		explanation = "One debris fragment hit the spacecraft."
	if not instrument_names.is_empty():
		explanation += " The impacts disabled %s." % ", ".join(instrument_names)
	if hit_count > instrument_names.size():
		explanation += " At least one impact left the instruments unchanged because none were working."
	_set_encounter_outcome(encounter, "Damage", explanation)


func _remove_contact(encounter: Dictionary, threat: Threat) -> void:
	_flight.remove_threat(threat.threat_id)
	encounter["threats"].erase(threat)


func _expire_encounters(time_seconds: float) -> void:
	for encounter in _encounters.duplicate():
		var threats: Array[Threat] = encounter["threats"]
		if time_seconds < float(encounter["expires_at_seconds"]) and not threats.is_empty():
			continue
		for threat: Threat in threats.duplicate():
			_remove_contact(encounter, threat)
		if encounter["hit_count"] == 0:
			_set_encounter_outcome(encounter, "Threat avoided", "The spacecraft passed clear of the approaching objects.")
		_encounters.erase(encounter)


func _refresh_flight_forecast() -> void:
	if not _needs_flight_forecast_refresh:
		return
	_needs_flight_forecast_refresh = false
	if _flight.has_method("refresh_flight_forecast"):
		var time_seconds: float = _flight.simulation_time_seconds
		_keep_flown_piece_through(time_seconds)
		_flight.refresh_flight_forecast()
		_elapsed_trajectory = _flight.trajectory
		_elapsed_trajectory_start_seconds = time_seconds
		_needs_prediction_refresh = true


func _refresh_predictions(time_seconds: float) -> void:
	if not _needs_prediction_refresh:
		return
	_needs_prediction_refresh = false
	for encounter in _encounters:
		for threat: Threat in encounter["threats"]:
			var approach := ThreatModel.closest_approach(
					_body, _flight.trajectory, threat, time_seconds, encounter["expires_at_seconds"])
			threat.closest_approach_time_seconds = approach.get("time_seconds", INF)
			threat.miss_distance_meters = approach.get("distance_meters", INF)


func _surface_alert(time_seconds: float) -> void:
	if not active_encounter.is_empty():
		return
	var has_working_radar := _has_working_selected_radar(_flight.vehicle_state)
	var first_encounter: Dictionary = {}
	var first_threat: Threat
	for encounter in _encounters:
		if encounter["is_alerted"] or encounter["is_acknowledged"]:
			continue
		for threat: Threat in encounter["threats"]:
			var approach_time_seconds := threat.closest_approach_time_seconds
			if not is_finite(approach_time_seconds):
				continue
			var seconds_until_approach := approach_time_seconds - time_seconds
			if seconds_until_approach < 0.0:
				continue
			var is_late_warning := not has_working_radar and seconds_until_approach <= FALLBACK_WARNING_SECONDS
			if not threat.is_revealed and not is_late_warning:
				continue
			if (first_threat == null or approach_time_seconds < first_threat.closest_approach_time_seconds
					or (approach_time_seconds == first_threat.closest_approach_time_seconds
					and encounter["event_type_id"] < first_encounter["event_type_id"])):
				first_threat = threat
				first_encounter = encounter
	if first_threat == null:
		return
	active_encounter = first_encounter
	active_encounter["is_alerted"] = true
	var warning_seconds := maxf(0.0, first_threat.closest_approach_time_seconds - time_seconds)
	var source := "Radar" if first_threat.is_revealed else "The fallback warning"
	active_encounter["warning"] = "%s gave %.0f seconds of warning." % [source, warning_seconds]
	_set_encounter_outcome(active_encounter, _event_row(active_encounter)["outcome"],
			_event_row(active_encounter)["explanation"])
	if _overlay_enabled and is_inside_tree():
		_open_overlay(first_threat)
	_flight.raise_alert("THREAT_APPROACH", active_encounter["event_name"])


func _has_working_selected_radar(vehicle: VehicleState) -> bool:
	var selected_id := ""
	var selected_tier := 0
	for part_id: String in vehicle.design.payload_part_ids:
		var part := GameData.part(part_id)
		var stats: Dictionary = part.get("stats", {})
		if part.get("category", "") == "telemetry" and stats.get("channel", "") == "radar":
			var tier := int(part.get("tier", 0))
			if selected_id.is_empty() or tier > selected_tier:
				selected_tier = tier
				selected_id = part_id
	return vehicle.is_working_by_instrument.get(selected_id, false)


func _open_overlay(threat: Threat) -> void:
	var overlay_scene := load(EMERGENCY_OVERLAY_PATH) as PackedScene
	var overlay := overlay_scene.instantiate()
	var session_number := _session_number
	var encounter_id: int = active_encounter["id"]
	var on_execute := func(pulse: Pulse) -> bool:
		if not _alert_matches(session_number, encounter_id):
			return false
		return acknowledge_alert(pulse).did_fire
	var on_ignore := func() -> void:
		if _alert_matches(session_number, encounter_id):
			acknowledge_alert()
	_alert_layer = CanvasLayer.new()
	_alert_layer.name = "EmergencyAlert"
	_alert_layer.layer = 20
	_alert_scene = get_tree().current_scene
	if _alert_scene != null:
		_alert_scene.tree_exiting.connect(_on_alert_scene_exiting)
	add_child(_alert_layer)
	overlay.open_alert(_flight, _mission, _body, active_encounter["event_name"], threat,
			active_encounter["expires_at_seconds"], on_execute, on_ignore)
	_alert_layer.add_child(overlay)


func _alert_matches(session_number: int, encounter_id: int) -> bool:
	return session_number == _session_number and active_encounter.get("id", -1) == encounter_id


func _close_active_alert() -> void:
	active_encounter = {}
	if is_instance_valid(_alert_scene):
		_alert_scene.tree_exiting.disconnect(_on_alert_scene_exiting)
	_alert_scene = null
	if is_instance_valid(_alert_layer):
		_alert_layer.hide()
		_alert_layer.queue_free()
	_alert_layer = null


func _on_alert_scene_exiting() -> void:
	# The child may still hold the callbacks until the end of the frame.
	# Clearing the current encounter invalidates both callbacks immediately.
	_close_active_alert()
	if _is_session_active and _flight.is_flying:
		_flight.set_time_scale(1.0)


func _resume_after_alert() -> void:
	var time_seconds: float = _flight.simulation_time_seconds
	if _can_start_event(time_seconds):
		_surface_alert(time_seconds)
	if active_encounter.is_empty() and _flight.is_flying:
		_flight.set_time_scale(1.0)


func _log_event(event_type_id: String, time_seconds: float, outcome: String, explanation: String) -> int:
	var index: int = _flight.event_log.size()
	_flight.log_event({
		"event_type_id": event_type_id,
		"time_seconds": time_seconds,
		"did_player_react": false,
		"delta_v_spent_meters_per_second": 0.0,
		"outcome": outcome,
		"explanation": explanation,
	})
	return index


func _event_row(encounter: Dictionary) -> Dictionary:
	return _flight.event_log[encounter["log_index"]]


func _set_encounter_outcome(encounter: Dictionary, outcome: String, explanation: String) -> void:
	var row := _event_row(encounter)
	row["outcome"] = outcome
	row["explanation"] = explanation
	if not encounter["warning"].is_empty():
		row["explanation"] += " " + encounter["warning"]
