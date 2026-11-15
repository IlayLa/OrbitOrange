class_name AccelerationPanel
extends InstrumentPanel
## ACC: acceleration in g (standard gravity). The channel needs no part. It is
## active during the launch burn and during pulses and reads 0 in free flight.

const VALUE_ROW := 0
const STATUS_ROW := 1


func _init() -> void:
	title_text = "ACC"
	row_captions = ["", ""]


## Shows the acceleration and whether an engine is burning.
func show_frame(frame: TelemetryFrame) -> void:
	var reading := frame.reading(TelemetryFrame.CHANNEL_ACCELERATION_METERS_PER_SECOND_SQUARED)
	set_value_text(VALUE_ROW, ReadingFormat.reading_text(reading, func(value: float) -> String:
		return "%.2f g" % ReadingFormat.acceleration_in_g(value)))
	var is_burning := reading.is_sensor_installed and reading.is_sensor_working and reading.value > 0.0
	set_value_text(STATUS_ROW, "ENGINE ON" if is_burning else "coasting")
