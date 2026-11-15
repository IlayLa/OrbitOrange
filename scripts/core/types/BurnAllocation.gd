class_name BurnAllocation
extends RefCounted
## A manoeuvre's stage-by-stage fuel use and aggregate physical outcome.

var stage_ids: Array[int] = []
var stage_outcomes: Array[BurnOutcome] = []
var outcome: BurnOutcome = BurnOutcome.new()
var requested_delta_v_meters_per_second: float = 0.0
var is_satisfied: bool = false
var starts_with_solid: bool = false
var blocking_reason: String = ""
var before_state: OrbitState
var after_state: OrbitState


## The id of the last stage that actually fired, or zero.
func last_stage_id() -> int:
	return 0 if stage_ids.is_empty() else stage_ids.back()


## A readable list of stage numbers in rocket order.
func stage_chain(design: RocketDesign) -> String:
	var names := PackedStringArray()
	for stage_id in stage_ids:
		for stage_index in design.stages.size():
			if design.stages[stage_index].stage_id == stage_id:
				names.append(str(stage_index + 1))
	return " → ".join(names)
