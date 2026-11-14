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
##   - A liquid engine delivers what is asked, or as much as its propellant allows.
##   - A burn asked for no velocity change does not fire: it has no direction.
##
## Every velocity change comes from the rocket equation (Tsiolkovsky). The mass
## flow of an engine is thrust / (specific impulse x standard gravity), the
## relation in NASA's GMAT Mathematical Specifications, section 11.6.

const STANDARD_GRAVITY_METERS_PER_SECOND_SQUARED := 9.80665
## A stage holding no more propellant than this counts as empty.
const EMPTY_PROPELLANT_KILOGRAMS := 0.000001
## A liquid pulse counts as delivered when it falls short by less than this.
const AFFORDABLE_TOLERANCE_METERS_PER_SECOND := 0.01
## Sentences of validate_design that start with this do not stop a launch.
const WARNING_PREFIX := "Warning:"


## The rocket equation: velocity change in meters per second from burning the
## rocket down from initial_mass_kilograms to final_mass_kilograms.
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


## Sum of the cost of every part in the design, in million USD.
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


## Current mass in kilograms: every part not yet dropped, plus the propellant
## still on board.
static func total_mass_kilograms(vehicle_state: VehicleState) -> float:
	var total_mass: float = 0.0
	for stage in vehicle_state.design.stages:
		if vehicle_state.is_jettisoned_by_stage.get(stage.stage_id, false):
			continue
		total_mass += _stage_mass_kilograms(vehicle_state, stage)
	for part_id in vehicle_state.design.payload_part_ids:
		var payload_mass: float = GameData.part(part_id).get("dry_mass_kilograms", 0.0)
		total_mass += payload_mass
	return total_mass


## Velocity change in meters per second the stage could deliver if it fired
## now and burned all its propellant, after dropping every stage below it.
## Zero when it cannot fire: unknown, failed, dropped or empty.
static func available_delta_v_meters_per_second(vehicle_state: VehicleState, stage_id: int) -> float:
	var stage_index: int = _stage_index(vehicle_state.design, stage_id)
	if stage_index < 0:
		return 0.0
	if vehicle_state.has_failed_by_stage.get(stage_id, false):
		return 0.0
	if vehicle_state.is_jettisoned_by_stage.get(stage_id, false):
		return 0.0
	var propellant_kilograms: float = vehicle_state.propellant_kilograms_by_stage.get(stage_id, 0.0)
	if propellant_kilograms <= EMPTY_PROPELLANT_KILOGRAMS:
		return 0.0
	var specific_impulse_seconds: float = _effective_specific_impulse_seconds(
			vehicle_state, vehicle_state.design.stages[stage_index])
	if specific_impulse_seconds <= 0.0:
		return 0.0
	var initial_mass_kilograms: float = _mass_when_stage_fires_kilograms(vehicle_state, stage_index)
	return delta_v_from_rocket_equation(
			specific_impulse_seconds, initial_mass_kilograms, initial_mass_kilograms - propellant_kilograms)


## Fires one stage and changes vehicle_state accordingly: drops the stages
## below it, burns propellant, and drops the stage itself when it runs empty.
## A liquid engine delivers the requested velocity change or as much as its
## propellant allows. A solid motor ignores the size of the request and burns
## everything. In the returned BurnOutcome, mass_before_kilograms is the mass at
## ignition, after the lower stages have been dropped: the mass the engine
## really pushes. When the stage cannot fire, or any engine is asked for
## nothing (a burn with no direction), did_fire is false and vehicle_state is
## left unchanged.
static func apply_burn(
		vehicle_state: VehicleState,
		stage_id: int,
		requested_delta_v_meters_per_second: float) -> BurnOutcome:
	var outcome := BurnOutcome.new()
	outcome.mass_before_kilograms = total_mass_kilograms(vehicle_state)
	outcome.mass_after_kilograms = outcome.mass_before_kilograms
	if requested_delta_v_meters_per_second <= 0.0:
		return outcome
	if available_delta_v_meters_per_second(vehicle_state, stage_id) <= 0.0:
		return outcome

	var stage_index: int = _stage_index(vehicle_state.design, stage_id)
	var stage: Stage = vehicle_state.design.stages[stage_index]
	var is_solid_motor: bool = _is_solid(stage)

	for lower_stage_index in stage_index:
		var lower_stage_id: int = vehicle_state.design.stages[lower_stage_index].stage_id
		if not vehicle_state.is_jettisoned_by_stage.get(lower_stage_id, false):
			vehicle_state.is_jettisoned_by_stage[lower_stage_id] = true
			outcome.jettisoned_stage_ids.append(lower_stage_id)

	var specific_impulse_seconds: float = _effective_specific_impulse_seconds(vehicle_state, stage)
	var propellant_before_kilograms: float = vehicle_state.propellant_kilograms_by_stage[stage_id]
	var mass_at_ignition_kilograms: float = total_mass_kilograms(vehicle_state)
	var propellant_used_kilograms: float = propellant_before_kilograms
	if not is_solid_motor:
		propellant_used_kilograms = minf(
				propellant_before_kilograms,
				propellant_needed_for_delta_v(
						specific_impulse_seconds, mass_at_ignition_kilograms, requested_delta_v_meters_per_second))

	var propellant_left_kilograms: float = propellant_before_kilograms - propellant_used_kilograms
	if propellant_left_kilograms <= EMPTY_PROPELLANT_KILOGRAMS:
		propellant_left_kilograms = 0.0
		vehicle_state.is_jettisoned_by_stage[stage_id] = true
		outcome.jettisoned_stage_ids.append(stage_id)
	vehicle_state.propellant_kilograms_by_stage[stage_id] = propellant_left_kilograms

	outcome.did_fire = true
	outcome.propellant_used_kilograms = propellant_used_kilograms
	outcome.delta_v_delivered_meters_per_second = delta_v_from_rocket_equation(
			specific_impulse_seconds, mass_at_ignition_kilograms, mass_at_ignition_kilograms - propellant_used_kilograms)
	outcome.mass_before_kilograms = mass_at_ignition_kilograms
	outcome.mass_after_kilograms = total_mass_kilograms(vehicle_state)

	var engine_stats: Dictionary = GameData.part(stage.engine_part_id).get("stats", {})
	var thrust_newtons: float = engine_stats.get("thrust_kilonewtons", 0.0) * 1000.0
	if thrust_newtons > 0.0:
		var mass_flow_kilograms_per_second: float = thrust_newtons / (
				specific_impulse_seconds * STANDARD_GRAVITY_METERS_PER_SECOND_SQUARED)
		outcome.burn_duration_seconds = propellant_used_kilograms / mass_flow_kilograms_per_second
	return outcome


## Runs the whole mass chain: the launch stages burn completely, then each
## pulse fires in order. launch_loss_meters_per_second (gravity and drag) is
## subtracted from the launch stages' velocity change to give the burnout
## speed, which is never below zero. Returns a PlanSummary with every field
## filled; its warnings are validate_design plus the problems of the plan.
## Plan problems that start with "Warning:" are advice (see blocking_sentences).
static func summarize_plan(
		design: RocketDesign,
		plan: MissionPlan,
		launch_loss_meters_per_second: float) -> PlanSummary:
	var summary := PlanSummary.new()
	var vehicle_state: VehicleState = create_vehicle_state(design)
	summary.cost_million_usd = total_cost_million_usd(design)
	summary.wet_mass_kilograms = total_mass_kilograms(vehicle_state)
	var total_propellant_kilograms: float = 0.0
	for stage in design.stages:
		total_propellant_kilograms += full_propellant_kilograms(stage)
	summary.dry_mass_kilograms = summary.wet_mass_kilograms - total_propellant_kilograms
	summary.warnings = validate_design(design)

	var full_burn_state: VehicleState = vehicle_state.duplicate_vehicle_state()
	for stage in design.stages:
		summary.total_delta_v_meters_per_second += _burn_stage_completely(
				full_burn_state, stage.stage_id).delta_v_delivered_meters_per_second

	var thrust_warning: String = _launch_thrust_warning(vehicle_state, plan)
	if thrust_warning != "":
		summary.warnings.append(thrust_warning)

	var launch_delta_v_meters_per_second: float = 0.0
	var did_any_launch_stage_fire := false
	for launch_stage_id in plan.launch_stage_ids:
		var launch_outcome: BurnOutcome = _burn_stage_completely(vehicle_state, launch_stage_id)
		launch_delta_v_meters_per_second += launch_outcome.delta_v_delivered_meters_per_second
		did_any_launch_stage_fire = did_any_launch_stage_fire or launch_outcome.did_fire
		if not launch_outcome.did_fire:
			var launch_stage_index: int = _stage_index(design, launch_stage_id)
			if launch_stage_index < 0:
				summary.warnings.append("%s A stage set to fire at launch is not part of the rocket." % WARNING_PREFIX)
			else:
				summary.warnings.append(
						"%s Stage %d is set to fire at launch but is already dropped, empty or broken by then."
						% [WARNING_PREFIX, launch_stage_index + 1])
	summary.burnout_speed_meters_per_second = maxf(
			0.0, launch_delta_v_meters_per_second - launch_loss_meters_per_second)
	if not did_any_launch_stage_fire and not design.stages.is_empty():
		summary.warnings.append("No stage fires at launch.")

	for pulse_index in plan.pulses.size():
		var pulse: Pulse = plan.pulses[pulse_index]
		var requested_delta_v_meters_per_second: float = pulse.requested_delta_v_meters_per_second()
		var could_stage_fire: bool = available_delta_v_meters_per_second(vehicle_state, pulse.stage_id) > 0.0
		var pulse_outcome: BurnOutcome = apply_burn(
				vehicle_state, pulse.stage_id, requested_delta_v_meters_per_second)
		var is_solid_motor: bool = _is_solid(design.find_stage(pulse.stage_id))
		# A live stage asked for nothing does not fire, and that is fine.
		var is_affordable: bool = could_stage_fire and requested_delta_v_meters_per_second <= 0.0
		if pulse_outcome.did_fire:
			is_affordable = is_solid_motor or (
					pulse_outcome.delta_v_delivered_meters_per_second
					>= requested_delta_v_meters_per_second - AFFORDABLE_TOLERANCE_METERS_PER_SECOND)
		summary.delta_v_delivered_by_pulse.append(pulse_outcome.delta_v_delivered_meters_per_second)
		summary.is_pulse_affordable.append(is_affordable)
		if not could_stage_fire:
			summary.warnings.append(
					"%s Pulse %d uses a stage that is already dropped or empty." % [WARNING_PREFIX, pulse_index + 1])
		elif is_solid_motor and requested_delta_v_meters_per_second <= 0.0:
			summary.warnings.append(
					"%s Pulse %d has no direction, so its solid motor does not fire." % [WARNING_PREFIX, pulse_index + 1])

	for stage in design.stages:
		var remaining_delta_v_meters_per_second: float = available_delta_v_meters_per_second(
				vehicle_state, stage.stage_id)
		summary.delta_v_remaining_by_stage[stage.stage_id] = remaining_delta_v_meters_per_second
		summary.reserve_delta_v_meters_per_second += remaining_delta_v_meters_per_second
	return summary


## Problems with the design, one sentence each, for the player. Stages are
## named by position: "Stage 1" is the bottom stage. Every sentence here stops
## a launch. The thrust check needs the plan, so summarize_plan makes it.
static func validate_design(design: RocketDesign) -> Array[String]:
	var problems: Array[String] = []
	if design.stages.is_empty():
		problems.append("The rocket has no engine.")
	for stage_index in design.stages.size():
		var stage: Stage = design.stages[stage_index]
		var stage_name: String = "Stage %d" % (stage_index + 1)
		if stage.engine_part_id == "":
			problems.append("%s has no engine." % stage_name)
		elif GameData.part(stage.engine_part_id).get("category", "") != GameData.CATEGORY_ENGINE:
			problems.append("%s uses \"%s\", which is not an engine." % [stage_name, stage.engine_part_id])
		elif _is_solid(stage):
			if stage.tank_part_id != "":
				problems.append("%s has a tank, but a solid motor carries its own propellant." % stage_name)
		elif stage.tank_part_id == "":
			problems.append("%s has a liquid engine but no tank." % stage_name)
		elif GameData.part(stage.tank_part_id).get("category", "") != GameData.CATEGORY_TANK:
			problems.append("%s uses \"%s\", which is not a tank." % [stage_name, stage.tank_part_id])
	for part_id in design.payload_part_ids:
		var payload_category: String = GameData.part(part_id).get("category", "")
		if payload_category != GameData.CATEGORY_TELEMETRY and payload_category != GameData.CATEGORY_SCIENCE:
			problems.append("The payload part \"%s\" is not a telemetry or science part." % part_id)
	return problems


## The sentences of validate_design that stop the rocket from flying. An empty
## list means the design can be launched.
static func blocking_problems(design: RocketDesign) -> Array[String]:
	return blocking_sentences(validate_design(design))


## The sentences that stop a launch, without the "Warning:" ones. Pass it
## PlanSummary.warnings to decide whether the Launch button is enabled.
static func blocking_sentences(sentences: Array[String]) -> Array[String]:
	var blocking: Array[String] = []
	for sentence in sentences:
		if not sentence.begins_with(WARNING_PREFIX):
			blocking.append(sentence)
	return blocking


## A warning when the first stage that really fires at launch pushes with less
## than the weight it lifts, or "" when it is strong enough. Stages that cannot
## fire are skipped, and a stage that is not a proper engine is left to
## validate_design.
static func _launch_thrust_warning(vehicle_state: VehicleState, plan: MissionPlan) -> String:
	for launch_stage_id in plan.launch_stage_ids:
		if available_delta_v_meters_per_second(vehicle_state, launch_stage_id) <= 0.0:
			continue
		var stage_index: int = _stage_index(vehicle_state.design, launch_stage_id)
		var engine_part: Dictionary = GameData.part(vehicle_state.design.stages[stage_index].engine_part_id)
		if engine_part.get("category", "") != GameData.CATEGORY_ENGINE:
			return ""
		var thrust_kilonewtons: float = engine_part.get("stats", {}).get("thrust_kilonewtons", 0.0)
		var weight_kilonewtons: float = (
				_mass_when_stage_fires_kilograms(vehicle_state, stage_index)
				* STANDARD_GRAVITY_METERS_PER_SECOND_SQUARED / 1000.0)
		if thrust_kilonewtons >= weight_kilonewtons:
			return ""
		return "%s Stage %d fires first at launch with %.1f kilonewtons, less than the weight it lifts (%.1f kilonewtons)." % [
				WARNING_PREFIX, stage_index + 1, thrust_kilonewtons, weight_kilonewtons]
	return ""


## Fires a stage until it is empty, whatever its engine type.
static func _burn_stage_completely(vehicle_state: VehicleState, stage_id: int) -> BurnOutcome:
	# Asking for more than the stage holds makes a liquid engine use all of it.
	var more_than_available_meters_per_second: float = (
			available_delta_v_meters_per_second(vehicle_state, stage_id) + 1.0)
	return apply_burn(vehicle_state, stage_id, more_than_available_meters_per_second)


## Position of the stage in design.stages (0 is the bottom), or -1 when unknown.
static func _stage_index(design: RocketDesign, stage_id: int) -> int:
	for stage_index in design.stages.size():
		if design.stages[stage_index].stage_id == stage_id:
			return stage_index
	return -1


## The engine's specific impulse in seconds, times the stage's health factor.
static func _effective_specific_impulse_seconds(vehicle_state: VehicleState, stage: Stage) -> float:
	var engine_stats: Dictionary = GameData.part(stage.engine_part_id).get("stats", {})
	var specific_impulse_seconds: float = engine_stats.get("specific_impulse_seconds", 0.0)
	var specific_impulse_factor: float = vehicle_state.specific_impulse_factor_by_stage.get(stage.stage_id, 1.0)
	return specific_impulse_seconds * specific_impulse_factor


## Kilograms of one stage: engine, tank and the propellant it still holds.
static func _stage_mass_kilograms(vehicle_state: VehicleState, stage: Stage) -> float:
	var engine_dry_mass: float = GameData.part(stage.engine_part_id).get("dry_mass_kilograms", 0.0)
	var tank_dry_mass: float = GameData.part(stage.tank_part_id).get("dry_mass_kilograms", 0.0)
	var propellant_mass: float = vehicle_state.propellant_kilograms_by_stage.get(stage.stage_id, 0.0)
	return engine_dry_mass + tank_dry_mass + propellant_mass


## Kilograms the stage pushes when it ignites: the payload, the stage itself
## and every stage above it that is still attached. Lower stages are gone.
static func _mass_when_stage_fires_kilograms(vehicle_state: VehicleState, stage_index: int) -> float:
	var mass_kilograms: float = total_mass_kilograms(vehicle_state)
	for lower_stage_index in stage_index:
		var lower_stage: Stage = vehicle_state.design.stages[lower_stage_index]
		if not vehicle_state.is_jettisoned_by_stage.get(lower_stage.stage_id, false):
			mass_kilograms -= _stage_mass_kilograms(vehicle_state, lower_stage)
	return mass_kilograms


static func _is_solid(stage: Stage) -> bool:
	if stage == null:
		return false
	var engine_stats: Dictionary = GameData.part(stage.engine_part_id).get("stats", {})
	return engine_stats.get("engine_type", "") == "solid"
