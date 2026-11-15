class_name ExecutionDemoFrames
extends RefCounted
## Hand-made telemetry frames covering every panel state, used by the T08
## demo scene and the execution console tests. Static functions only.

const STATE_NAMES: Array[String] = [
	"1 nominal, active sensors, 1x",
	"2 every sensor missing",
	"3 sensors installed but failed",
	"4 three radar contacts, levels 0 1 2",
	"5 alarms active and an alert",
	"6 launch burn, 1000x",
	"7 paused, no pulse left",
	"8 threat approaching",
	"9 threat alert",
	"10 self-destruct",
	"11 live flight",
]
## What a person should see in each state, shown by the demo. One per state.
const CHECK_HINTS: Array[String] = [
	"Clock runs. Press II 1x 10x 100x 1000x: the lit button follows. Δv LEFT is bottom centre, FUEL is top of the left column.",
	"Every instrument, the radar and FUEL read NO SENSOR. Δv still shows: it needs no sensor.",
	"Installed instruments and FUEL read NO SIGNAL. The radar shows no contacts.",
	"Blip only (level 0); blip + km (level 1); ring + type, km and m/s (level 2). Ring 50 km.",
	"Lamp flashes, LOW FUEL and HAZARD NEAR listed, alert box until OK.",
	"ACC 2.50 g ENGINE ON, θ +30.0°, γ +25.0°, 1000x lit.",
	"II lit, Next pulse in none, Δv 0 m/s.",
	"A contact closes from 240 to 3 km. It moves steadily inward; the ring never shrinks.",
	"Paused with THREAT APPROACHING. Press 1x: the alert clears, as after T07's overlay.",
	"Press SELF DESTRUCT: SURE?, again: a joke. The flight is not affected.",
	"A real flight of the example rocket. Instruments read live telemetry; the green debug panel (F3) shows the truth.",
]
const STATE_NOMINAL := 0
const STATE_SENSORS_MISSING := 1
const STATE_SENSORS_FAILED := 2
const STATE_RADAR_CONTACTS := 3
const STATE_ALARMS := 4
const STATE_LAUNCH_BURN := 5
const STATE_PAUSED_NO_PULSE := 6
const STATE_THREAT_APPROACH := 7
const STATE_THREAT_ALERT := 8
const STATE_SELF_DESTRUCT := 9
## Not a hand-made frame: the demo flies the reference rocket for real.
const STATE_LIVE_FLIGHT := 10

const DEMO_ALERT_CODE := "HAZARD_NEAR"
const DEMO_ALERT_MESSAGE := "Debris closing at 7.4 km/s. Flight paused."
const THREAT_ALERT_CODE := "THREAT_APPROACH"
const THREAT_ALERT_MESSAGE := "Satellite conjunction"
## Range of the approaching contact in state 8 when the approach starts and
## when it starts over.
const APPROACH_START_RANGE_METERS := 240000.0
const APPROACH_END_RANGE_METERS := 3000.0


## Returns the frame of one demo state (an index into STATE_NAMES).
static func frame_for_state(state_index: int) -> TelemetryFrame:
	match state_index:
		STATE_SENSORS_MISSING:
			return _sensors_missing()
		STATE_SENSORS_FAILED:
			return _sensors_failed()
		STATE_RADAR_CONTACTS:
			return _radar_contacts()
		STATE_ALARMS:
			return _alarms()
		STATE_LAUNCH_BURN:
			return _launch_burn()
		STATE_PAUSED_NO_PULSE:
			return _paused_no_pulse()
		STATE_THREAT_APPROACH:
			return _threat_approach()
		STATE_THREAT_ALERT:
			return _threat_alert()
	return _nominal()


## Returns the level 2 contact of an approaching threat at the given range.
static func approaching_contact(range_meters: float) -> Dictionary:
	return {
		"bearing_radians": deg_to_rad(30.0), "range_meters": range_meters,
		"closing_speed_meters_per_second": 7400.0, "resolution_level": 2,
		"event_type_id": "satellite_conjunction",
	}


static func _threat_approach() -> TelemetryFrame:
	var frame := _nominal()
	frame.radar_contacts.append(approaching_contact(APPROACH_START_RANGE_METERS))
	return frame


static func _threat_alert() -> TelemetryFrame:
	var frame := _nominal()
	frame.time_scale = 0.0
	frame.active_alarms.append("HAZARD_NEAR")
	frame.radar_contacts.append(approaching_contact(8000.0))
	return frame


## Returns a reading with the given sensor state and value.
static func reading(is_installed: bool, is_working: bool, value: float, tier: int = 1) -> TelemetryReading:
	var result := TelemetryReading.new()
	result.is_sensor_installed = is_installed
	result.is_sensor_working = is_installed and is_working
	result.value = value if result.is_sensor_working else 0.0
	result.sensor_tier = tier if is_installed else 0
	return result


static func _nominal() -> TelemetryFrame:
	var frame := TelemetryFrame.new()
	frame.simulation_time_seconds = 1800.0
	frame.time_scale = 1.0
	frame.delta_v_remaining_meters_per_second = 4440.0
	frame.seconds_until_next_pulse = 1234.0
	frame.data_generated_megabits = 3.2
	frame.data_delivered_megabits = 3.2
	frame.is_radar_installed = true
	_set_all_readings(frame, true, true, {
		TelemetryFrame.CHANNEL_ALTITUDE_METERS: 412300.0,
		TelemetryFrame.CHANNEL_FUEL_KILOGRAMS: 1830.0,
		TelemetryFrame.CHANNEL_ATTITUDE_RADIANS: deg_to_rad(1.5),
		TelemetryFrame.CHANNEL_FLIGHT_PATH_ANGLE_RADIANS: deg_to_rad(0.4),
	})
	return frame


static func _sensors_missing() -> TelemetryFrame:
	var frame := _nominal()
	frame.is_radar_installed = false
	_set_all_readings(frame, false, false, {})
	return frame


static func _sensors_failed() -> TelemetryFrame:
	var frame := _nominal()
	_set_all_readings(frame, true, false, {})
	return frame


static func _radar_contacts() -> TelemetryFrame:
	var frame := _nominal()
	frame.time_scale = 10.0
	frame.radar_contacts.append({
		"bearing_radians": deg_to_rad(45.0), "range_meters": 18000.0,
		"closing_speed_meters_per_second": 0.0, "resolution_level": 0, "event_type_id": "",
	})
	frame.radar_contacts.append({
		"bearing_radians": deg_to_rad(150.0), "range_meters": 31000.0,
		"closing_speed_meters_per_second": 0.0, "resolution_level": 1, "event_type_id": "",
	})
	frame.radar_contacts.append({
		"bearing_radians": deg_to_rad(-70.0), "range_meters": 42000.0,
		"closing_speed_meters_per_second": 7400.0, "resolution_level": 2,
		"event_type_id": "satellite_conjunction",
	})
	return frame


static func _alarms() -> TelemetryFrame:
	var frame := _nominal()
	frame.time_scale = 0.0
	frame.active_alarms.append("LOW_FUEL")
	frame.active_alarms.append("HAZARD_NEAR")
	frame.readings_by_channel[TelemetryFrame.CHANNEL_FUEL_KILOGRAMS] = reading(true, true, 90.0)
	return frame


static func _launch_burn() -> TelemetryFrame:
	var frame := _nominal()
	frame.simulation_time_seconds = 40.0
	frame.time_scale = 1000.0
	frame.delta_v_remaining_meters_per_second = 7900.0
	frame.seconds_until_next_pulse = 2650.0
	frame.data_generated_megabits = 0.0
	frame.data_delivered_megabits = 0.0
	frame.readings_by_channel[TelemetryFrame.CHANNEL_ALTITUDE_METERS] = reading(true, true, 12000.0)
	frame.readings_by_channel[TelemetryFrame.CHANNEL_ATTITUDE_RADIANS] = reading(true, true, deg_to_rad(30.0))
	frame.readings_by_channel[TelemetryFrame.CHANNEL_FLIGHT_PATH_ANGLE_RADIANS] = reading(
			true, true, deg_to_rad(25.0))
	frame.readings_by_channel[TelemetryFrame.CHANNEL_ACCELERATION_METERS_PER_SECOND_SQUARED] = reading(
			true, true, 2.5 * ReadingFormat.STANDARD_GRAVITY_METERS_PER_SECOND_SQUARED)
	return frame


static func _paused_no_pulse() -> TelemetryFrame:
	var frame := _nominal()
	frame.simulation_time_seconds = 5400.0
	frame.time_scale = 0.0
	frame.seconds_until_next_pulse = INF
	frame.delta_v_remaining_meters_per_second = 0.0
	frame.data_generated_megabits = 14.5
	frame.data_delivered_megabits = 12.0
	return frame


## Fills every instrument channel. The acceleration channel needs no part, so
## it is always installed and working (0 in free flight).
static func _set_all_readings(
		frame: TelemetryFrame, is_installed: bool, is_working: bool, values_by_channel: Dictionary) -> void:
	for channel_name: String in [
			TelemetryFrame.CHANNEL_ALTITUDE_METERS, TelemetryFrame.CHANNEL_FUEL_KILOGRAMS,
			TelemetryFrame.CHANNEL_ATTITUDE_RADIANS, TelemetryFrame.CHANNEL_FLIGHT_PATH_ANGLE_RADIANS]:
		frame.readings_by_channel[channel_name] = reading(
				is_installed, is_working, float(values_by_channel.get(channel_name, 0.0)), 2)
	frame.readings_by_channel[TelemetryFrame.CHANNEL_ACCELERATION_METERS_PER_SECOND_SQUARED] = reading(
			true, true, 0.0)
