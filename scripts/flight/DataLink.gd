extends RefCounted
## Delivers the science data generated in a simulation interval.


## Returns the megabits delivered to the ground by the instant link.
static func deliver(generated_megabits: float, _state: OrbitState, _step_seconds: float) -> float:
	return generated_megabits
