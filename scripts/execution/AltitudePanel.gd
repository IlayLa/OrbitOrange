class_name AltitudePanel
extends InstrumentPanel
## ALTITUDE above the surface in kilometres, from the altimeter channel.


func _init() -> void:
	title_text = "ALTITUDE"


## Shows the altitude reading, or NO SENSOR / NO SIGNAL.
func show_frame(frame: TelemetryFrame) -> void:
	var reading := frame.reading(TelemetryFrame.CHANNEL_ALTITUDE_METERS)
	set_value_text(0, ReadingFormat.reading_text(reading, func(value_meters: float) -> String:
		return "%.1f km" % (value_meters / 1000.0)))
