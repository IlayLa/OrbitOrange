class_name ResolvedBurn
extends RefCounted
## A pulse after the mass bookkeeping: where it fires and the velocity change
## the rocket can really deliver there. PlanResolver creates these from the
## player's Pulse list and RocketModel's PlanSummary; OrbitModel consumes them.
## OrbitModel therefore never needs to know anything about rockets.

## Index of the Pulse in MissionPlan.pulses that this burn came from.
var pulse_index: int = 0
var polar_angle_radians: float = 0.0
var extra_revolutions: int = 0
var fires_immediately: bool = false
var delta_v_along_velocity_meters_per_second: float = 0.0
var delta_v_outward_meters_per_second: float = 0.0
