class_name Pulse
extends RefCounted
## One planned engine firing: an instant change of velocity.
##
## A pulse is anchored to a place, not a time. It fires at the first moment
## after the previous burn when the craft crosses the direction
## polar_angle_radians (seen from the centre of the central body), after
## waiting extra_revolutions full orbits.

## Unique within one MissionPlan.
var pulse_id: int = 0
## The Stage whose engine fires.
var stage_id: int = 0
## Inertial direction from the central body at which the pulse fires.
var polar_angle_radians: float = 0.0
## Full revolutions to wait before firing at polar_angle_radians.
var extra_revolutions: int = 0
## Velocity change along the direction of motion (positive speeds the craft up).
var delta_v_along_velocity_meters_per_second: float = 0.0
## Velocity change perpendicular to the motion, pointing away from the central body.
var delta_v_outward_meters_per_second: float = 0.0
## True for an emergency pulse: it fires at the craft's current position and
## ignores polar_angle_radians and extra_revolutions.
var fires_immediately: bool = false


func duplicate_pulse() -> Pulse:
	var copy := Pulse.new()
	copy.pulse_id = pulse_id
	copy.stage_id = stage_id
	copy.polar_angle_radians = polar_angle_radians
	copy.extra_revolutions = extra_revolutions
	copy.delta_v_along_velocity_meters_per_second = delta_v_along_velocity_meters_per_second
	copy.delta_v_outward_meters_per_second = delta_v_outward_meters_per_second
	copy.fires_immediately = fires_immediately
	return copy


## Direction of the requested velocity change: 0° along the motion, +90°
## outward, ±180° against the motion. Zero when no change is requested.
func direction_angle_degrees() -> float:
	return rad_to_deg(atan2(delta_v_outward_meters_per_second, delta_v_along_velocity_meters_per_second))


## Sets both components from a direction (as in direction_angle_degrees) and a size.
func set_delta_v_from_angle(angle_degrees: float, delta_v_meters_per_second: float) -> void:
	var angle_radians := deg_to_rad(angle_degrees)
	delta_v_along_velocity_meters_per_second = cos(angle_radians) * delta_v_meters_per_second
	delta_v_outward_meters_per_second = sin(angle_radians) * delta_v_meters_per_second


## Size of the requested velocity change. For a solid motor only the direction
## of the two components matters; the size comes from RocketModel.
func requested_delta_v_meters_per_second() -> float:
	return sqrt(
			delta_v_along_velocity_meters_per_second * delta_v_along_velocity_meters_per_second
			+ delta_v_outward_meters_per_second * delta_v_outward_meters_per_second)
