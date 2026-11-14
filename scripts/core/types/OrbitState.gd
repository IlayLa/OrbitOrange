class_name OrbitState
extends RefCounted
## Where an object is and how fast it moves at one moment.
##
## The frame is inertial (it does not rotate) and centred on the central body.
## These five plain 64-bit numbers are the single source of truth for an orbit;
## orbital elements are always computed from them, never the other way round.
## Vector2 is deliberately not used: it stores 32-bit numbers, which is too
## coarse for metres at orbital distances.

var position_x_meters: float = 0.0
var position_y_meters: float = 0.0
var velocity_x_meters_per_second: float = 0.0
var velocity_y_meters_per_second: float = 0.0
## Seconds since launch.
var time_seconds: float = 0.0


static func create(
		new_position_x_meters: float,
		new_position_y_meters: float,
		new_velocity_x_meters_per_second: float,
		new_velocity_y_meters_per_second: float,
		new_time_seconds: float = 0.0) -> OrbitState:
	var state := OrbitState.new()
	state.position_x_meters = new_position_x_meters
	state.position_y_meters = new_position_y_meters
	state.velocity_x_meters_per_second = new_velocity_x_meters_per_second
	state.velocity_y_meters_per_second = new_velocity_y_meters_per_second
	state.time_seconds = new_time_seconds
	return state


func duplicate_state() -> OrbitState:
	return OrbitState.create(
			position_x_meters, position_y_meters,
			velocity_x_meters_per_second, velocity_y_meters_per_second,
			time_seconds)


## Distance from the centre of the central body.
func radius_meters() -> float:
	return sqrt(position_x_meters * position_x_meters + position_y_meters * position_y_meters)


func speed_meters_per_second() -> float:
	return sqrt(
			velocity_x_meters_per_second * velocity_x_meters_per_second
			+ velocity_y_meters_per_second * velocity_y_meters_per_second)


## Direction from the central body to the object, measured counter-clockwise
## from the +x axis, in the range -PI to PI.
func polar_angle_radians() -> float:
	return atan2(position_y_meters, position_x_meters)
