class_name TelemetryFrame
extends RefCounted
## Everything the execution console may display at one moment.
## FlightSimulation emits one of these with the telemetry_updated signal.
## Panels read only from this object and never from the true simulation state.

## Channel names used as keys of readings_by_channel, with the unit of each value.
const CHANNEL_ALTITUDE_METERS := "altitude_meters"
const CHANNEL_FUEL_KILOGRAMS := "fuel_kilograms"
const CHANNEL_ATTITUDE_RADIANS := "attitude_radians"
const CHANNEL_FLIGHT_PATH_ANGLE_RADIANS := "flight_path_angle_radians"
const CHANNEL_ACCELERATION_METERS_PER_SECOND_SQUARED := "acceleration_meters_per_second_squared"

var simulation_time_seconds: float = 0.0
## 0 means paused. Otherwise simulated seconds per real second.
var time_scale: float = 1.0
## Channel name -> TelemetryReading.
var readings_by_channel: Dictionary = {}
## One Dictionary per object the radar currently sees, with the keys
## "bearing_radians", "range_meters", "closing_speed_meters_per_second",
## "resolution_level" (0 blip, 1 distance and bearing, 2 shape and speed)
## and "event_type_id".
var radar_contacts: Array[Dictionary] = []
var is_radar_installed: bool = false
## Short codes of the warnings that are active, for example "LOW_FUEL".
var active_alarms: Array[String] = []
var delta_v_remaining_meters_per_second: float = 0.0
## Seconds until the next scheduled pulse, including automatic orbit insertion.
## INF when none is scheduled.
var seconds_until_next_pulse: float = INF
var data_generated_megabits: float = 0.0
var data_delivered_megabits: float = 0.0


## Returns an empty reading (no sensor) when the channel is missing.
func reading(channel_name: String) -> TelemetryReading:
	if readings_by_channel.has(channel_name):
		return readings_by_channel[channel_name]
	return TelemetryReading.new()
