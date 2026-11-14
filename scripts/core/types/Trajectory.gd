class_name Trajectory
extends RefCounted
## The whole predicted flight path: a chain of segments separated by burns.
## Built by OrbitModel.build_trajectory.

enum Status {
	REACHES_ORBIT,     ## Ends on a closed orbit that stays above the atmosphere.
	IMPACT,            ## Enters the atmosphere or hits the surface.
	ESCAPE,            ## Leaves the central body on an open orbit.
	UNREACHABLE_PULSE, ## A pulse's polar angle is never reached; see first_unreachable_pulse_index.
}

var segments: Array[TrajectorySegment] = []
var status: Status = Status.REACHES_ORBIT
## Index in MissionPlan.pulses, or -1 when every pulse can fire.
var first_unreachable_pulse_index: int = -1


## The segment that is being flown at the given time. Null when the trajectory is empty.
func segment_at_time(time_seconds: float) -> TrajectorySegment:
	var found_segment: TrajectorySegment = null
	for segment in segments:
		if time_seconds >= segment.start_time_seconds:
			found_segment = segment
	if found_segment == null and not segments.is_empty():
		found_segment = segments[0]
	return found_segment


func final_segment() -> TrajectorySegment:
	if segments.is_empty():
		return null
	return segments[segments.size() - 1]
