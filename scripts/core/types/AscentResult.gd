class_name AscentResult
extends RefCounted
## The shared prediction for automatic departure and orbit insertion.

var departure: BurnAllocation = BurnAllocation.new()
var insertion: BurnAllocation = BurnAllocation.new()
var departure_state: OrbitState
var orbit_entry_state: OrbitState
var vehicle_state: VehicleState
var trajectory: Trajectory
var propellant_used_by_stage_kilograms: Dictionary = {}
var propellant_remaining_by_stage_kilograms: Dictionary = {}
var did_reach_initial_orbit: bool = false
var can_lift_off: bool = true
var failure_reason: String = ""
## Measured details when the rocket is unable to lift off.
var lift_off_failure_details: String = ""
var warnings: Array[String] = []
