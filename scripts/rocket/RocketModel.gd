class_name RocketModel
extends RefCounted
## The rocket as numbers: what it costs, what it weighs and how much velocity
## change each stage can deliver. Rockets only: nothing in this file knows
## about orbits or the screen. It reads part data through GameData.
##
## Rules (see tasks/CONTRACTS.md, "Rocket rules"):
##   - A liquid engine's propellant is in its tank; a solid motor carries its own.
##   - Stages fire bottom to top. Firing a stage drops every stage below it.
##   - A solid motor always burns all its propellant in one burn.
##
## STUB(T02): the signatures are final. Bodies marked STUB return fixed
## numbers so that the rest of the game can run before task T02 is done.

const STANDARD_GRAVITY_METERS_PER_SECOND_SQUARED := 9.80665
const STUB_BURNOUT_SPEED_METERS_PER_SECOND := 7672.6
const STUB_AVAILABLE_DELTA_V_METERS_PER_SECOND := 4000.0
const STUB_RESERVE_DELTA_V_METERS_PER_SECOND := 500.0


## The rocket equation: velocity change from burning the rocket down from
## initial_mass_kilograms to final_mass_kilograms.
static func delta_v_from_rocket_equation(
		specific_impulse_seconds: float,
		initial_mass_kilograms: float,
		final_mass_kilograms: float) -> float:
	var exhaust_speed_meters_per_second: float = specific_impulse_seconds * STANDARD_GRAVITY_METERS_PER_SECOND_SQUARED
	return exhaust_speed_meters_per_second * log(initial_mass_kilograms / final_mass_kilograms)


## The rocket equation solved for propellant: kilograms that must be burned to
## change the velocity of a rocket of initial_mass_kilograms by the given amount.
static func propellant_needed_for_delta_v(
		specific_impulse_seconds: float,
		initial_mass_kilograms: float,
		delta_v_meters_per_second: float) -> float:
	var exhaust_speed_meters_per_second: float = specific_impulse_seconds * STANDARD_GRAVITY_METERS_PER_SECOND_SQUARED
	return initial_mass_kilograms * (1.0 - exp(-delta_v_meters_per_second / exhaust_speed_meters_per_second))


## Sum of the cost of every part in the design.
static func total_cost_million_usd(design: RocketDesign) -> float:
	var total_cost: float = 0.0
	for part_id in all_part_ids(design):
		var part_cost: float = GameData.part(part_id).get("cost_million_usd", 0.0)
		total_cost += part_cost
	return total_cost


## Every part id used by the design: engines, tanks and payload.
static func all_part_ids(design: RocketDesign) -> Array[String]:
	var part_ids: Array[String] = []
	for stage in design.stages:
		part_ids.append(stage.engine_part_id)
		if stage.tank_part_id != "":
			part_ids.append(stage.tank_part_id)
	part_ids.append_array(design.payload_part_ids)
	return part_ids


## Kilograms of propellant a full stage carries: the tank's capacity for a
## liquid engine, the motor's own propellant for a solid one.
static func full_propellant_kilograms(stage: Stage) -> float:
	var engine_stats: Dictionary = GameData.part(stage.engine_part_id).get("stats", {})
	if engine_stats.get("engine_type", "") == "solid":
		return engine_stats.get("propellant_kilograms", 0.0)
	var tank_stats: Dictionary = GameData.part(stage.tank_part_id).get("stats", {})
	return tank_stats.get("propellant_capacity_kilograms", 0.0)


## A fresh rocket on the pad: every stage full, nothing dropped, everything working.
static func create_vehicle_state(design: RocketDesign) -> VehicleState:
	var vehicle_state := VehicleState.new()
	vehicle_state.design = design
	for stage in design.stages:
		vehicle_state.propellant_kilograms_by_stage[stage.stage_id] = full_propellant_kilograms(stage)
		vehicle_state.is_jettisoned_by_stage[stage.stage_id] = false
		vehicle_state.has_failed_by_stage[stage.stage_id] = false
		vehicle_state.specific_impulse_factor_by_stage[stage.stage_id] = 1.0
	for part_id in design.payload_part_ids:
		vehicle_state.is_working_by_instrument[part_id] = true
	return vehicle_state


## Current mass: every part not yet dropped, plus the propellant still on board.
static func total_mass_kilograms(vehicle_state: VehicleState) -> float:
	var total_mass: float = 0.0
	for stage in vehicle_state.design.stages:
		if vehicle_state.is_jettisoned_by_stage.get(stage.stage_id, false):
			continue
		var engine_dry_mass: float = GameData.part(stage.engine_part_id).get("dry_mass_kilograms", 0.0)
		var tank_dry_mass: float = GameData.part(stage.tank_part_id).get("dry_mass_kilograms", 0.0)
		var propellant_mass: float = vehicle_state.propellant_kilograms_by_stage.get(stage.stage_id, 0.0)
		total_mass += engine_dry_mass + tank_dry_mass + propellant_mass
	for part_id in vehicle_state.design.payload_part_ids:
		var payload_mass: float = GameData.part(part_id).get("dry_mass_kilograms", 0.0)
		total_mass += payload_mass
	return total_mass


## Velocity change the stage could deliver if it fired now and burned all its
## propellant, after dropping every stage below it. Zero when it cannot fire.
## STUB(T02): returns a fixed number.
static func available_delta_v_meters_per_second(vehicle_state: VehicleState, stage_id: int) -> float:
	if vehicle_state.has_failed_by_stage.get(stage_id, false):
		return 0.0
	if vehicle_state.is_jettisoned_by_stage.get(stage_id, true):
		return 0.0
	return STUB_AVAILABLE_DELTA_V_METERS_PER_SECOND


## Fires one stage and changes vehicle_state accordingly: drops the stages
## below it, burns propellant, and drops the stage itself when it runs empty.
## A liquid engine delivers the requested velocity change or as much as its
## propellant allows. A solid motor ignores the request and burns everything.
## STUB(T02): delivers exactly what is requested and changes nothing.
static func apply_burn(
		vehicle_state: VehicleState,
		stage_id: int,
		requested_delta_v_meters_per_second: float) -> BurnOutcome:
	var outcome := BurnOutcome.new()
	outcome.mass_before_kilograms = total_mass_kilograms(vehicle_state)
	outcome.mass_after_kilograms = outcome.mass_before_kilograms
	outcome.did_fire = available_delta_v_meters_per_second(vehicle_state, stage_id) > 0.0
	if outcome.did_fire:
		outcome.delta_v_delivered_meters_per_second = requested_delta_v_meters_per_second
	return outcome


## Runs the whole mass chain: the launch stages burn completely, then each
## pulse fires in order. launch_loss_meters_per_second (gravity and drag) is
## subtracted from the launch stages' velocity change to give the burnout speed.
## STUB(T02): real cost and masses, fixed burnout speed, every pulse affordable.
static func summarize_plan(
		design: RocketDesign,
		plan: MissionPlan,
		_launch_loss_meters_per_second: float) -> PlanSummary:
	var summary := PlanSummary.new()
	var vehicle_state: VehicleState = create_vehicle_state(design)
	summary.cost_million_usd = total_cost_million_usd(design)
	summary.wet_mass_kilograms = total_mass_kilograms(vehicle_state)
	var total_propellant_kilograms: float = 0.0
	for stage in design.stages:
		total_propellant_kilograms += full_propellant_kilograms(stage)
	summary.dry_mass_kilograms = summary.wet_mass_kilograms - total_propellant_kilograms

	summary.burnout_speed_meters_per_second = STUB_BURNOUT_SPEED_METERS_PER_SECOND
	summary.total_delta_v_meters_per_second = STUB_AVAILABLE_DELTA_V_METERS_PER_SECOND * design.stages.size()
	for pulse in plan.pulses:
		summary.delta_v_delivered_by_pulse.append(pulse.requested_delta_v_meters_per_second())
		summary.is_pulse_affordable.append(true)
	for stage in design.stages:
		summary.delta_v_remaining_by_stage[stage.stage_id] = STUB_RESERVE_DELTA_V_METERS_PER_SECOND
	summary.reserve_delta_v_meters_per_second = STUB_RESERVE_DELTA_V_METERS_PER_SECOND * design.stages.size()
	summary.warnings = validate_design(design)
	return summary


## Problems that stop the rocket from flying, as sentences for the player.
## An empty list means the design can be launched.
static func validate_design(design: RocketDesign) -> Array[String]:
	var problems: Array[String] = []
	if design.stages.is_empty():
		problems.append("The rocket has no engine.")
	for stage in design.stages:
		var engine_stats: Dictionary = GameData.part(stage.engine_part_id).get("stats", {})
		if engine_stats.get("engine_type", "") == "liquid" and stage.tank_part_id == "":
			problems.append("A liquid engine has no tank.")
	return problems
