class_name SequentialPropulsion
extends RefCounted
## Mass-only sequential propulsion. No orbit geometry or game state.
## An attached stage with usable propellant is never silently discarded.

const DELTA_V_TOLERANCE_METERS_PER_SECOND := 0.000001


## The lowest attached stage, including a failed stage that blocks progression.
static func current_stage(vehicle_state: VehicleState) -> Stage:
	for stage in vehicle_state.design.stages:
		if not vehicle_state.is_jettisoned_by_stage.get(stage.stage_id, false):
			if vehicle_state.propellant_kilograms_by_stage.get(stage.stage_id, 0.0) > RocketModel.EMPTY_PROPELLANT_KILOGRAMS:
				return stage
	return null


## True when the engine in this stage is a solid motor.
static func is_solid(stage: Stage) -> bool:
	return stage != null and GameData.part(stage.engine_part_id).get("stats", {}).get("engine_type", "") == "solid"


## Changes vehicle_state and returns stage outcomes, delta-v in m/s and mass in kg.
## A direction-only pulse beginning on a solid burns exactly that motor.
## Other demands continue through stages, accepting full-solid overshoot.
static func apply_burn(vehicle_state: VehicleState, requested_delta_v_meters_per_second: float, is_direction_only_solid: bool = false) -> BurnAllocation:
	var allocation := BurnAllocation.new()
	allocation.requested_delta_v_meters_per_second = requested_delta_v_meters_per_second
	allocation.outcome.mass_before_kilograms = RocketModel.total_mass_kilograms(vehicle_state)
	allocation.outcome.mass_after_kilograms = allocation.outcome.mass_before_kilograms
	if is_nan(requested_delta_v_meters_per_second) or requested_delta_v_meters_per_second <= 0.0:
		allocation.is_satisfied = requested_delta_v_meters_per_second == 0.0
		return allocation
	var first_stage: Stage = current_stage(vehicle_state)
	allocation.starts_with_solid = is_solid(first_stage)
	var effective_request: float = requested_delta_v_meters_per_second
	if is_direction_only_solid and allocation.starts_with_solid:
		effective_request = RocketModel.available_delta_v_meters_per_second(vehicle_state, first_stage.stage_id)
		if effective_request <= DELTA_V_TOLERANCE_METERS_PER_SECOND:
			allocation.blocking_reason = "The current solid stage cannot fire."
			return allocation
	var remaining_delta_v_meters_per_second: float = effective_request
	while remaining_delta_v_meters_per_second > DELTA_V_TOLERANCE_METERS_PER_SECOND:
		var stage: Stage = current_stage(vehicle_state)
		if stage == null:
			allocation.blocking_reason = "No propellant remains."
			break
		if vehicle_state.has_failed_by_stage.get(stage.stage_id, false):
			allocation.blocking_reason = "The current stage has failed; upper stages remain attached."
			break
		var capacity_meters_per_second: float = RocketModel.available_delta_v_meters_per_second(vehicle_state, stage.stage_id)
		if capacity_meters_per_second <= DELTA_V_TOLERANCE_METERS_PER_SECOND:
			allocation.blocking_reason = "The current stage cannot fire."
			break
		var stage_outcome: BurnOutcome = RocketModel.apply_burn(
				vehicle_state, stage.stage_id, minf(remaining_delta_v_meters_per_second, capacity_meters_per_second))
		if not stage_outcome.did_fire:
			allocation.blocking_reason = "The current stage cannot fire."
			break
		allocation.stage_ids.append(stage.stage_id)
		allocation.stage_outcomes.append(stage_outcome)
		allocation.outcome.did_fire = true
		allocation.outcome.delta_v_delivered_meters_per_second += stage_outcome.delta_v_delivered_meters_per_second
		allocation.outcome.propellant_used_kilograms += stage_outcome.propellant_used_kilograms
		allocation.outcome.burn_duration_seconds += stage_outcome.burn_duration_seconds
		allocation.outcome.jettisoned_stage_ids.append_array(stage_outcome.jettisoned_stage_ids)
		if is_finite(remaining_delta_v_meters_per_second):
			remaining_delta_v_meters_per_second -= stage_outcome.delta_v_delivered_meters_per_second
		if is_direction_only_solid and allocation.starts_with_solid:
			break
		if not vehicle_state.is_jettisoned_by_stage.get(stage.stage_id, false):
			break
	allocation.outcome.mass_after_kilograms = RocketModel.total_mass_kilograms(vehicle_state)
	allocation.is_satisfied = allocation.outcome.delta_v_delivered_meters_per_second >= effective_request - DELTA_V_TOLERANCE_METERS_PER_SECOND
	return allocation


## A fresh design summary. All mass values are kg and delta-v values are m/s.
static func base_summary(design: RocketDesign) -> PlanSummary:
	var summary := PlanSummary.new()
	var full_vehicle: VehicleState = RocketModel.create_vehicle_state(design)
	summary.cost_million_usd = RocketModel.total_cost_million_usd(design)
	summary.wet_mass_kilograms = RocketModel.total_mass_kilograms(full_vehicle)
	var propellant_kilograms := 0.0
	for stage in design.stages:
		propellant_kilograms += RocketModel.full_propellant_kilograms(stage)
	summary.dry_mass_kilograms = summary.wet_mass_kilograms - propellant_kilograms
	summary.blocking_problems = RocketModel.validate_design(design)
	summary.warnings = summary.blocking_problems.duplicate()
	summary.total_delta_v_meters_per_second = apply_burn(full_vehicle, INF).outcome.delta_v_delivered_meters_per_second
	return summary


## Fills the remaining sequential stage capacities in m/s without changing the vehicle.
static func fill_reserve(summary: PlanSummary, vehicle_state: VehicleState) -> void:
	summary.delta_v_remaining_by_stage.clear()
	summary.reserve_delta_v_meters_per_second = 0.0
	for stage in vehicle_state.design.stages:
		summary.delta_v_remaining_by_stage[stage.stage_id] = 0.0
	var reserve: BurnAllocation = apply_burn(vehicle_state.duplicate_vehicle_state(), INF)
	for stage_index in reserve.stage_ids.size():
		var delivered_meters_per_second: float = reserve.stage_outcomes[stage_index].delta_v_delivered_meters_per_second
		summary.delta_v_remaining_by_stage[reserve.stage_ids[stage_index]] = delivered_meters_per_second
		summary.reserve_delta_v_meters_per_second += delivered_meters_per_second


## One-based position in the current design, or zero when the stage is absent.
static func stage_number(design: RocketDesign, stage_id: int) -> int:
	for stage_index in design.stages.size():
		if design.stages[stage_index].stage_id == stage_id:
			return stage_index + 1
	return 0
