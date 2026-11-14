class_name FlightResult
extends RefCounted
## How the flight ended and what it achieved. FlightSimulation creates it;
## Scoring turns it into points.

enum EndReason {
	MISSION_COMPLETED, ## The planned mission duration ran out.
	LAUNCH_FAILURE,    ## The craft never reached orbit.
	CRASHED,           ## It re-entered the atmosphere after having been in orbit.
	ESCAPED,           ## It left the central body on an open orbit.
	COLLISION,         ## It was destroyed by a threat.
	ABORTED,           ## The player ended the flight early.
}

var end_reason: EndReason = EndReason.MISSION_COMPLETED
## Orbit at the end of the flight. Null after a launch failure.
var final_elements: OrbitElements
## True when the craft ends on a closed orbit with its periapsis above the atmosphere.
var did_reach_orbit: bool = false
var flight_duration_seconds: float = 0.0
var reserve_delta_v_meters_per_second: float = 0.0
## Share of the final orbit's period spent inside the science zone, 0 to 1.
var science_coverage_fraction: float = 0.0
var data_generated_megabits: float = 0.0
var data_delivered_megabits: float = 0.0
var installed_instrument_count: int = 0
var working_instrument_count: int = 0
## One Dictionary per event, with the keys "event_type_id", "time_seconds",
## "did_player_react", "delta_v_spent_meters_per_second", "outcome" and "explanation".
var event_log: Array[Dictionary] = []
