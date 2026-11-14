class_name Threat
extends RefCounted
## Another object in orbit that may hit the craft: a satellite, a piece of
## debris or an asteroid. EventDirector creates threats; FlightSimulation keeps
## the list; TelemetryFeed turns the ones the radar can see into radar contacts.

var threat_id: int = 0
## Id of the entry in data/event_types.json that produced this threat.
var event_type_id: String = ""
## The threat's own position and velocity. Propagate it with Kepler.propagate.
var state: OrbitState
## The craft is hit when it comes closer than this.
var collision_radius_meters: float = 0.0
var closest_approach_time_seconds: float = 0.0
## Predicted distance at closest approach on the craft's current path.
var miss_distance_meters: float = 0.0
## True once the radar has detected it.
var is_revealed: bool = false
