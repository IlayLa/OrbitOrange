class_name RocketDesign
extends RefCounted
## Everything the player decides on the rocket design screen.

## Index 0 is the bottom stage and fires first.
var stages: Array[Stage] = []
## Ids of the telemetry and science parts carried by the top stage.
var payload_part_ids: Array[String] = []

var _next_stage_id: int = 1


func add_stage(engine_part_id: String, tank_part_id: String = "") -> Stage:
	var stage := Stage.new()
	stage.stage_id = _next_stage_id
	_next_stage_id += 1
	stage.engine_part_id = engine_part_id
	stage.tank_part_id = tank_part_id
	stages.append(stage)
	return stage


func remove_stage(stage_id: int) -> void:
	for stage_index in stages.size():
		if stages[stage_index].stage_id == stage_id:
			stages.remove_at(stage_index)
			return


## Returns null when no stage has this id.
func find_stage(stage_id: int) -> Stage:
	for stage in stages:
		if stage.stage_id == stage_id:
			return stage
	return null


func duplicate_design() -> RocketDesign:
	var copy := RocketDesign.new()
	for stage in stages:
		var stage_copy := Stage.new()
		stage_copy.stage_id = stage.stage_id
		stage_copy.engine_part_id = stage.engine_part_id
		stage_copy.tank_part_id = stage.tank_part_id
		copy.stages.append(stage_copy)
	copy.payload_part_ids = payload_part_ids.duplicate()
	copy._next_stage_id = _next_stage_id
	return copy
