class_name DeltaVPanel
extends InstrumentPanel
## Δv: the velocity change the rocket can still deliver, in m/s, from
## frame.delta_v_remaining_meters_per_second. It replaces the fuel panel of the
## design (team decision). The value is not a sensor channel, so it is always
## shown.


func _init() -> void:
	title_text = "Δv LEFT"


## Shows the delta-v remaining.
func show_frame(frame: TelemetryFrame) -> void:
	set_value_text(0, "%.0f m/s" % frame.delta_v_remaining_meters_per_second)
