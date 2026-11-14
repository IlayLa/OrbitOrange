class_name OrbitElements
extends RefCounted
## The shape and orientation of an orbit, computed from an OrbitState.
##
## Conventions follow the GMAT Mathematical Specifications, section 4.1.2
## (see tasks/CONTRACTS.md, "Orbit conventions").

## Negative for an open (escape) orbit.
var semi_major_axis_meters: float = 0.0
var eccentricity: float = 0.0
## Angle from the +x axis to the periapsis direction, measured in the direction
## of motion (clockwise for a clockwise orbit). Zero for a circular orbit.
var argument_of_periapsis_radians: float = 0.0
## Angle from the periapsis direction to the object.
## For a circular orbit: angle from the +x axis to the object.
var true_anomaly_radians: float = 0.0
## Closest distance to the centre of the central body.
var periapsis_radius_meters: float = 0.0
## Farthest distance. INF for an open orbit.
var apoapsis_radius_meters: float = 0.0
## Time for one revolution. INF for an open orbit.
var period_seconds: float = 0.0
## Kinetic plus potential energy per kilogram. Zero or positive means the orbit is open.
var specific_energy_joules_per_kilogram: float = 0.0
## True when the object escapes the central body (eccentricity >= 1).
var is_open: bool = false
## True when eccentricity is below 1e-11 (the GMAT threshold).
var is_circular: bool = false
## True when the object moves clockwise around the central body.
var is_clockwise: bool = false
