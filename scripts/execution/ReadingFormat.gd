class_name ReadingFormat
extends RefCounted
## Text formatting shared by the execution panels. Static functions only.

const STANDARD_GRAVITY_METERS_PER_SECOND_SQUARED := 9.80665
const NO_SENSOR_TEXT := "NO SENSOR"
const NO_SIGNAL_TEXT := "NO SIGNAL"
## Shown on every instrument before the first telemetry frame arrives.
const NO_DATA_TEXT := "--"
const PAUSE_LABEL := "II"

## Readable names for the alarm codes FlightSimulation puts in active_alarms.
const ALARM_TEXT_BY_CODE := {
	"LOW_FUEL": "LOW FUEL",
	"OVER_TEMPERATURE": "OVER TEMPERATURE",
	"HAZARD_NEAR": "HAZARD NEAR",
	# Raised by EventDirector (T07) through FlightSimulation.raise_alert.
	"THREAT_APPROACH": "THREAT APPROACHING",
}


## Returns "NO SENSOR" when no sensor is installed, "NO SIGNAL" when it has
## failed, and otherwise the value formatted by value_to_text (a Callable that
## takes the float value and returns a String).
static func reading_text(reading: TelemetryReading, value_to_text: Callable) -> String:
	if not reading.is_sensor_installed:
		return NO_SENSOR_TEXT
	if not reading.is_sensor_working:
		return NO_SIGNAL_TEXT
	return value_to_text.call(reading.value)


## Returns the acceleration in multiples of standard gravity (g).
static func acceleration_in_g(acceleration_meters_per_second_squared: float) -> float:
	return acceleration_meters_per_second_squared / STANDARD_GRAVITY_METERS_PER_SECOND_SQUARED


## Returns a duration as "h:mm:ss", or "none" for INF (nothing scheduled).
static func duration_text(duration_seconds: float) -> String:
	if not is_finite(duration_seconds):
		return "none"
	var whole_seconds := floori(maxf(duration_seconds, 0.0))
	var hours := floori(whole_seconds / 3600.0)
	var minutes := floori((whole_seconds % 3600) / 60.0)
	var seconds := whole_seconds % 60
	return "%d:%02d:%02d" % [hours, minutes, seconds]


## Returns the button label of a time scale: "II" for pause, otherwise "10x".
static func time_scale_label(time_scale: float) -> String:
	if time_scale == 0.0:
		return PAUSE_LABEL
	return "%dx" % int(time_scale)


## Returns the readable text of an alarm code; unknown codes are shown as they are.
static func alarm_text(alarm_code: String) -> String:
	return ALARM_TEXT_BY_CODE.get(alarm_code, alarm_code)


## Returns the radar scope range in metres: the largest contact range rounded
## up to 10, 25, 50, 100, 250, 500 or 1000 km, then whole thousands of km.
## Never below 10 km. The telemetry frame does not carry the radar's own range.
static func radar_scope_range_meters(largest_contact_range_meters: float) -> float:
	var scope_steps_kilometers: Array[float] = [10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0]
	var largest_kilometers := maxf(largest_contact_range_meters, 0.0) / 1000.0
	for step_kilometers in scope_steps_kilometers:
		if largest_kilometers <= step_kilometers:
			return step_kilometers * 1000.0
	return ceilf(largest_kilometers / 1000.0) * 1000.0 * 1000.0
