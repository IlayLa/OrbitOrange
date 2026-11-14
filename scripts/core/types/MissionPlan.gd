class_name MissionPlan
extends RefCounted
## Everything the player decides on the orbit planning screen.

## Stages that fire at launch, in firing order. They burn all their propellant.
var launch_stage_ids: Array[int] = []
## Direction of the burnout velocity above the local horizontal.
var launch_angle_radians: float = 0.0
## Planned pulses, in the order they fire.
var pulses: Array[Pulse] = []


func duplicate_plan() -> MissionPlan:
	var copy := MissionPlan.new()
	copy.launch_stage_ids = launch_stage_ids.duplicate()
	copy.launch_angle_radians = launch_angle_radians
	for pulse in pulses:
		copy.pulses.append(pulse.duplicate_pulse())
	return copy


## Returns an id that no pulse in this plan uses yet.
func next_free_pulse_id() -> int:
	var highest_pulse_id := 0
	for pulse in pulses:
		highest_pulse_id = maxi(highest_pulse_id, pulse.pulse_id)
	return highest_pulse_id + 1
