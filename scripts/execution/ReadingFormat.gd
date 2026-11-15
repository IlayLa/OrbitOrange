class_name ReadingFormat
extends RefCounted
## Text formatting shared by the execution panels. Static functions only.

const STANDARD_GRAVITY_METERS_PER_SECOND_SQUARED := 9.80665
const NO_SENSOR_TEXT := "NO SENSOR"
const NO_SIGNAL_TEXT := "NO SIGNAL"
## Shown on every instrument before the first telemetry frame arrives.
const NO_DATA_TEXT := "--"
const PAUSE_LABEL := "II"
const SECONDS_PER_HOUR := 3600.0
const HOURS_PER_DAY := 24
const HOURS_PER_YEAR := 365 * HOURS_PER_DAY
## A twelfth of HOURS_PER_YEAR.
const HOURS_PER_MONTH := 730

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


## Returns the mission time stamp "Y M D H" (years, months, days and hours
## since launch), e.g. "0Y 01M 12D 05H". A year is 365 days and a month is a
## twelfth of a year (730 hours), so the stamp counts real elapsed time.
static func mission_time_text(elapsed_seconds: float) -> String:
	if not is_finite(elapsed_seconds):
		return NO_DATA_TEXT
	var total_hours := floori(maxf(elapsed_seconds, 0.0) / SECONDS_PER_HOUR)
	var years := floori(total_hours / float(HOURS_PER_YEAR))
	var hours_into_year := total_hours - years * HOURS_PER_YEAR
	var months := floori(hours_into_year / float(HOURS_PER_MONTH))
	var hours_into_month := hours_into_year - months * HOURS_PER_MONTH
	var days := floori(hours_into_month / float(HOURS_PER_DAY))
	var hours := hours_into_month - days * HOURS_PER_DAY
	return "%dY %02dM %02dD %02dH" % [years, months, days, hours]


## Returns a countdown as "D HH MM" (days, hours, minutes), e.g. "1D 05H 07M",
## or "none" for INF (nothing scheduled).
static func countdown_text(remaining_seconds: float) -> String:
	if not is_finite(remaining_seconds):
		return "none"
	var total_minutes := floori(maxf(remaining_seconds, 0.0) / 60.0)
	var days := floori(total_minutes / float(HOURS_PER_DAY * 60))
	var minutes_into_day := total_minutes - days * HOURS_PER_DAY * 60
	var hours := floori(minutes_into_day / 60.0)
	var minutes := minutes_into_day - hours * 60
	return "%dD %02dH %02dM" % [days, hours, minutes]


## Returns the button label of a time scale: "II" for pause, otherwise the
## speed relative to FlightSimulation.NORMAL_TIME_SCALE, e.g. "0.5x" or "4x".
static func time_scale_label(time_scale: float) -> String:
	if time_scale == 0.0:
		return PAUSE_LABEL
	var multiplier: float = time_scale / FlightSimulation.NORMAL_TIME_SCALE
	if is_equal_approx(multiplier, roundf(multiplier)):
		return "%dx" % roundi(multiplier)
	return "%sx" % String.num(multiplier, 2)


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
