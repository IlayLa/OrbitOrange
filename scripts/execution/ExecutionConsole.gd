extends Control
## The EXECUTION half of the console: the instrument wall, the mission clock
## with the time controls, and the objective list. It displays only what
## arrives in TelemetryFrame objects from FlightSimulation.telemetry_updated.
## Requirements: context/plan_draft.md, sections "EXECUTION half",
## "Execution instruments" and "Time controls".
##
## STUB(T08): shows the clock, the altitude and the time-scale buttons as plain
## text. T08 replaces this file.

var _readout_label: Label


func _ready() -> void:
	size = ScreenLayout.SCREEN_SIZE

	var background := ColorRect.new()
	background.color = ScreenLayout.COLOR_BEZEL_DARK
	background.size = ScreenLayout.SCREEN_SIZE
	add_child(background)

	_readout_label = Label.new()
	_readout_label.text = "EXECUTION (stub screen)\nWaiting for launch."
	_readout_label.position = Vector2(20, 20)
	add_child(_readout_label)

	var next_button_position_x_pixels := 20.0
	for time_scale in FlightSimulation.ALLOWED_TIME_SCALES:
		var time_scale_button := Button.new()
		time_scale_button.text = "PAUSE" if time_scale == 0.0 else "%dx" % int(time_scale)
		time_scale_button.position = Vector2(next_button_position_x_pixels, 120)
		time_scale_button.size = Vector2(70, 28)
		time_scale_button.pressed.connect(FlightSimulation.set_time_scale.bind(time_scale))
		add_child(time_scale_button)
		next_button_position_x_pixels += 76.0

	var end_flight_button := Button.new()
	end_flight_button.text = "End flight now"
	end_flight_button.position = Vector2(20, 160)
	end_flight_button.size = Vector2(150, 28)
	end_flight_button.pressed.connect(
			FlightSimulation.end_flight.bind(FlightResult.EndReason.ABORTED))
	add_child(end_flight_button)

	FlightSimulation.telemetry_updated.connect(_on_telemetry_updated)


func _on_telemetry_updated(frame: TelemetryFrame) -> void:
	var altitude_reading: TelemetryReading = frame.reading(TelemetryFrame.CHANNEL_ALTITUDE_METERS)
	var altitude_text := "NO SENSOR"
	if altitude_reading.is_sensor_installed:
		altitude_text = "%.0f km" % (altitude_reading.value / 1000.0)
	_readout_label.text = "EXECUTION (stub screen)\nMission time: %.0f s   Time scale: %sx\nAltitude: %s" % [
			frame.simulation_time_seconds, frame.time_scale, altitude_text]
