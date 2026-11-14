extends Node
## Throws random events at the flight: threats on a collision course, engine
## faults, sensor failures, solar flares. It listens to FlightSimulation and
## no other module calls it.
##
## STUB(T07): connects to the flight and does nothing. T07 replaces it.


func _ready() -> void:
	FlightSimulation.flight_started.connect(_on_flight_started)
	FlightSimulation.simulation_step.connect(_on_simulation_step)


func _on_flight_started() -> void:
	pass


## Called once per fixed step of simulated time. This is where T07 rolls for
## events, using the event rates of the altitude the craft is at.
func _on_simulation_step(_step_seconds: float) -> void:
	pass
