class_name VehicleState
extends RefCounted
## The rocket as it is right now during planning or flight: what is left of it
## and what still works. Created by RocketModel.create_vehicle_state and changed
## by RocketModel.apply_burn and by flight events.

## The design this state was created from.
var design: RocketDesign
## Stage id -> kilograms of propellant still on board.
var propellant_kilograms_by_stage: Dictionary = {}
## Stage id -> true once the stage has been dropped.
var is_jettisoned_by_stage: Dictionary = {}
## Stage id -> true once the engine can no longer fire (an event broke it).
var has_failed_by_stage: Dictionary = {}
## Stage id -> multiplier on the engine's specific impulse. 1.0 means healthy.
var specific_impulse_factor_by_stage: Dictionary = {}
## Payload part id -> true while the instrument works.
var is_working_by_instrument: Dictionary = {}


func duplicate_vehicle_state() -> VehicleState:
	var copy := VehicleState.new()
	copy.design = design
	copy.propellant_kilograms_by_stage = propellant_kilograms_by_stage.duplicate()
	copy.is_jettisoned_by_stage = is_jettisoned_by_stage.duplicate()
	copy.has_failed_by_stage = has_failed_by_stage.duplicate()
	copy.specific_impulse_factor_by_stage = specific_impulse_factor_by_stage.duplicate()
	copy.is_working_by_instrument = is_working_by_instrument.duplicate()
	return copy


func working_instrument_count() -> int:
	var working_count := 0
	for part_id in is_working_by_instrument:
		if is_working_by_instrument[part_id]:
			working_count += 1
	return working_count
