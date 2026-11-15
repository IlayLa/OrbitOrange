class_name TemperaturePanel
extends InstrumentPanel
## TEMP: engine and tank temperature in kelvin, from the temperature channel.


func _init() -> void:
	title_text = "TEMP"


## Shows the temperature reading, or NO SENSOR / NO SIGNAL.
func show_frame(frame: TelemetryFrame) -> void:
	var reading := frame.reading(TelemetryFrame.CHANNEL_TEMPERATURE_KELVIN)
	set_value_text(0, ReadingFormat.reading_text(reading, func(value_kelvin: float) -> String:
		return "%.0f K" % value_kelvin))
