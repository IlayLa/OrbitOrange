class_name TrajectorySegment
extends RefCounted
## One piece of the flight path: the free flight between two burns.

enum EndReason {
	NEXT_BURN,        ## The next pulse fires at end_time_seconds.
	IMPACT,           ## The craft enters the atmosphere or hits the surface.
	ESCAPE,           ## The craft is on an open orbit and leaves.
	NO_FURTHER_BURNS, ## Last segment of a closed orbit; it repeats forever.
}

## State immediately after the burn that starts this segment.
var start_state: OrbitState
var elements: OrbitElements
var start_time_seconds: float = 0.0
## INF when the segment never ends (NO_FURTHER_BURNS).
var end_time_seconds: float = INF
var end_reason: EndReason = EndReason.NO_FURTHER_BURNS
## Index in MissionPlan.pulses of the pulse that started this segment.
## -1 for the first segment, which starts at launch burnout.
var pulse_index: int = -1

## Rendering metadata; pulse_index continues to refer only to manual pulses.
var source_stage_id: int = 0
var is_automatic_ascent: bool = false
