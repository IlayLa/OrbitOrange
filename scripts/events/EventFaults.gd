extends RefCounted
## Equipment faults and simulated-time effects owned by EventDirector.

const LEAK_CAPACITY_FRACTION_PER_MINUTE := 0.01
const FLARE_DURATION_SECONDS := 120.0
const FLARE_NOISE_FRACTION_ADDITION := 0.20
const FLARE_DROPOUT_PROBABILITY_ADDITION := 0.15

var _leaks_by_stage: Dictionary = {}
var _flare_expires_at_seconds := -INF
var _interference_strength := 0.0


## Clears timers and the live telemetry interference for a fresh session.
func reset(flight: Node) -> void:
	_leaks_by_stage.clear()
	_flare_expires_at_seconds = -INF
	_set_interference(flight, 0.0)


## Drains existing leaks over the elapsed interval. Returns whether fuel changed.
func drain_leaks(vehicle: VehicleState, start_seconds: float, end_seconds: float) -> bool:
	var did_change := false
	for stage_id: int in _leaks_by_stage.keys():
		var remaining_kilograms: float = vehicle.propellant_kilograms_by_stage[stage_id]
		if vehicle.is_jettisoned_by_stage[stage_id] or remaining_kilograms <= 0.0:
			_leaks_by_stage.erase(stage_id)
			continue
		var leak: Dictionary = _leaks_by_stage[stage_id]
		var elapsed_seconds := maxf(0.0, end_seconds - maxf(start_seconds, leak["start_seconds"]))
		var drained_kilograms: float = leak["capacity_kilograms"] * LEAK_CAPACITY_FRACTION_PER_MINUTE * elapsed_seconds / 60.0
		var new_remaining_kilograms := maxf(0.0, remaining_kilograms - drained_kilograms)
		vehicle.propellant_kilograms_by_stage[stage_id] = new_remaining_kilograms
		did_change = did_change or new_remaining_kilograms < remaining_kilograms
		if new_remaining_kilograms == 0.0:
			_leaks_by_stage.erase(stage_id)
	return did_change


## Updates the effective flare after expiry, overlap or changes to computer health.
func sync_interference(flight: Node, time_seconds: float) -> void:
	var strength := 0.0
	if time_seconds < _flare_expires_at_seconds:
		strength = _computer_protection_factor(flight.vehicle_state)
	if strength != _interference_strength:
		_set_interference(flight, strength)


## Applies one equipment or environment event and returns its log details.
func apply_event(
		event_type_id: String, vehicle: VehicleState, random: RandomNumberGenerator, time_seconds: float) -> Dictionary:
	match event_type_id:
		"engine_malfunction":
			return _malfunction_engine(vehicle, random)
		"propellant_leak":
			return _start_leak(vehicle, random, time_seconds)
		"sensor_failure":
			var sensor_name := damage_instrument(vehicle, random, true)
			if sensor_name.is_empty():
				return _result("Skipped", "No working telemetry sensor was available.")
			return _result("Sensor failed", "%s stopped working." % sensor_name)
		"solar_flare":
			_flare_expires_at_seconds = maxf(_flare_expires_at_seconds, time_seconds + FLARE_DURATION_SECONDS)
			return _result("Interference", "A solar flare disrupted telemetry for 120 simulated seconds.")
	return _result("Skipped", "This event has no configured flight effect.")


## Fails one sorted, randomly selected working instrument and returns its name.
## Returns an empty string when no instrument was eligible.
func damage_instrument(vehicle: VehicleState, random: RandomNumberGenerator, sensors_only: bool = false) -> String:
	var eligible_ids: Array[String] = []
	for part_id: String in vehicle.is_working_by_instrument:
		if not vehicle.is_working_by_instrument[part_id]:
			continue
		var part := GameData.part(part_id)
		var stats: Dictionary = part.get("stats", {})
		if not sensors_only or (part.get("category", "") == "telemetry" and stats.get("channel", "") != "computer"):
			eligible_ids.append(part_id)
	if eligible_ids.is_empty():
		return ""
	eligible_ids.sort()
	var selected_id := eligible_ids[random.randi_range(0, eligible_ids.size() - 1)]
	vehicle.is_working_by_instrument[selected_id] = false
	return GameData.part(selected_id).get("name", selected_id)


func _malfunction_engine(vehicle: VehicleState, random: RandomNumberGenerator) -> Dictionary:
	var eligible_stages: Array[Stage] = []
	for stage in vehicle.design.stages:
		if RocketModel.available_delta_v_meters_per_second(vehicle, stage.stage_id) > 0.0:
			eligible_stages.append(stage)
	if eligible_stages.is_empty():
		return _result("Skipped", "No attached engine could still fire.")
	var selected_stage := _select_stage(eligible_stages, random)
	var stage_id := selected_stage.stage_id
	if _is_liquid(selected_stage) and vehicle.specific_impulse_factor_by_stage[stage_id] >= 1.0:
		vehicle.specific_impulse_factor_by_stage[stage_id] = 0.75
		return _result("Engine weakened", "Stage %d now delivers 75%% of its usual specific impulse." % stage_id, true)
	vehicle.has_failed_by_stage[stage_id] = true
	return _result("Engine failed", "Stage %d can no longer fire." % stage_id, true)


func _start_leak(vehicle: VehicleState, random: RandomNumberGenerator, time_seconds: float) -> Dictionary:
	var eligible_stages: Array[Stage] = []
	for stage in vehicle.design.stages:
		var stage_id := stage.stage_id
		if (_is_liquid(stage) and not vehicle.is_jettisoned_by_stage[stage_id]
				and vehicle.propellant_kilograms_by_stage[stage_id] > 0.0 and not _leaks_by_stage.has(stage_id)):
			eligible_stages.append(stage)
	if eligible_stages.is_empty():
		return _result("Skipped", "No attached liquid stage with fuel could start a new leak.")
	var selected_stage := _select_stage(eligible_stages, random)
	_leaks_by_stage[selected_stage.stage_id] = {
		"start_seconds": time_seconds,
		"capacity_kilograms": RocketModel.full_propellant_kilograms(selected_stage),
	}
	return _result("Leak started", "Stage %d is leaking 1%% of its full fuel capacity per minute." % selected_stage.stage_id)


func _set_interference(flight: Node, strength: float) -> void:
	_interference_strength = strength
	if is_instance_valid(flight) and flight.has_method("set_telemetry_interference"):
		flight.set_telemetry_interference(
				FLARE_NOISE_FRACTION_ADDITION * strength, FLARE_DROPOUT_PROBABILITY_ADDITION * strength)


func _computer_protection_factor(vehicle: VehicleState) -> float:
	var best_tier := 0
	for part_id: String in vehicle.design.payload_part_ids:
		if not vehicle.is_working_by_instrument.get(part_id, false):
			continue
		var part := GameData.part(part_id)
		var stats: Dictionary = part.get("stats", {})
		if part.get("category", "") == "telemetry" and stats.get("channel", "") == "computer":
			best_tier = maxi(best_tier, int(part.get("tier", 0)))
	if best_tier >= 3:
		return 0.25
	return 0.5 if best_tier > 0 else 1.0


func _is_liquid(stage: Stage) -> bool:
	var stats: Dictionary = GameData.part(stage.engine_part_id).get("stats", {})
	return stats.get("engine_type", "") == "liquid"


func _select_stage(stages: Array[Stage], random: RandomNumberGenerator) -> Stage:
	return stages[random.randi_range(0, stages.size() - 1)]


func _result(outcome: String, explanation: String, did_change_burn_capability: bool = false) -> Dictionary:
	return {
		"outcome": outcome,
		"explanation": explanation,
		"did_change_burn_capability": did_change_burn_capability,
	}
