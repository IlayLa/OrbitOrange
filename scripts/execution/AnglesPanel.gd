class_name AnglesPanel
extends InstrumentPanel
## ANGLES, both measured from the local horizontal, in degrees:
## θ attitude (where the nose points) and γ flight-path angle (where the
## velocity points).

const ATTITUDE_ROW := 0
const FLIGHT_PATH_ANGLE_ROW := 1


func _init() -> void:
	title_text = "θ NOSE   γ PATH"
	row_captions = ["θ", "γ"]


## Shows both angle readings, each with its own sensor state.
func show_frame(frame: TelemetryFrame) -> void:
	var degrees_text := func(value_radians: float) -> String:
		return "%+.1f°" % rad_to_deg(value_radians)
	set_value_text(ATTITUDE_ROW, ReadingFormat.reading_text(
			frame.reading(TelemetryFrame.CHANNEL_ATTITUDE_RADIANS), degrees_text))
	set_value_text(FLIGHT_PATH_ANGLE_ROW, ReadingFormat.reading_text(
			frame.reading(TelemetryFrame.CHANNEL_FLIGHT_PATH_ANGLE_RADIANS), degrees_text))
