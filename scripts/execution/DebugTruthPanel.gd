class_name DebugTruthPanel
extends Control
## DEBUG ONLY: the true flight state, read straight from FlightSimulation
## without any sensor, for developers comparing the instruments with reality.
##
## This deliberately breaks the T08 rule "read nothing but TelemetryFrame",
## so it is kept away from players: it exists only in debug builds
## (OS.is_debug_build()), starts hidden, and F3 toggles it. It covers the left
## column while shown.

const FONT_SIZE := 9
const TITLE := "DEBUG TRUTH  (F3 hides)"
const COLOR_DEBUG_TEXT := Color("65ff00")

var _label: Label


## True when the debug panel may be shown at all: only in debug builds.
static func is_available() -> bool:
	return OS.is_debug_build()


func _ready() -> void:
	var inner_rect := ExecutionLayout.inside_frame(ExecutionLayout.OBJECTIVES_SCREEN)
	position = inner_rect.position
	size = inner_rect.size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var background := ColorRect.new()
	background.color = ScreenLayout.COLOR_SPACE_BLACK
	background.size = size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_label = Label.new()
	_label.position = Vector2(3, 1)
	_label.size = size - Vector2(6, 2)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", COLOR_DEBUG_TEXT)
	_label.add_theme_constant_override("line_spacing", -1)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _process(_real_seconds_since_last_frame: float) -> void:
	if visible:
		_label.text = truth_text()


## Shows or hides the panel. Does nothing outside debug builds.
func set_shown(is_shown: bool) -> void:
	visible = is_shown and is_available()
	if visible:
		_label.text = truth_text()


## Returns the panel text: the true flight state, one value per line.
static func truth_text() -> String:
	var lines: Array[String] = [TITLE]
	if not FlightSimulation.is_flying or FlightSimulation.craft_state == null:
		lines.append("No flight running.")
		return "\n".join(lines)

	var state: OrbitState = FlightSimulation.craft_state
	var body: Dictionary = GameData.body(GameState.mission.get("body_id", "earth"))
	var body_radius_meters := float(body.get("radius_meters", 0.0))
	var gravitational_parameter := float(body.get("gravitational_parameter_cubic_meters_per_second_squared", 0.0))
	lines.append("T+ %.1f s   %s (%.0f s/s)" % [FlightSimulation.simulation_time_seconds,
			ReadingFormat.time_scale_label(FlightSimulation.time_scale), FlightSimulation.time_scale])
	lines.append("altitude   %.3f km" % (Kepler.altitude_meters(state, body) / 1000.0))
	lines.append("speed      %.1f m/s" % state.speed_meters_per_second())
	lines.append("path angle %+.2f°" % rad_to_deg(Kepler.flight_path_angle_radians(state)))
	lines.append("polar ang. %.2f°" % rad_to_deg(state.polar_angle_radians()))

	if gravitational_parameter > 0.0:
		var elements: OrbitElements = Kepler.elements_from_state(gravitational_parameter, state)
		lines.append("eccentric. %.5f" % elements.eccentricity)
		var periapsis_altitude_kilometers := (elements.periapsis_radius_meters - body_radius_meters) / 1000.0
		lines.append("periapsis  %.1f km%s" % [
				periapsis_altitude_kilometers, " (inside body)" if periapsis_altitude_kilometers < 0.0 else ""])
		if elements.is_open:
			lines.append("apoapsis   open orbit")
		else:
			lines.append("apoapsis   %.1f km" % ((elements.apoapsis_radius_meters - body_radius_meters) / 1000.0))
			lines.append("period     %.1f min" % (elements.period_seconds / 60.0))

	var vehicle: VehicleState = FlightSimulation.vehicle_state
	if vehicle != null:
		var attached_propellant_kilograms := 0.0
		var attached_stage_count := 0
		var failed_stage_count := 0
		for stage_id in vehicle.propellant_kilograms_by_stage:
			if not vehicle.is_jettisoned_by_stage.get(stage_id, true):
				attached_stage_count += 1
				attached_propellant_kilograms += float(vehicle.propellant_kilograms_by_stage[stage_id])
				if vehicle.has_failed_by_stage.get(stage_id, false):
					failed_stage_count += 1
		lines.append("mass       %.0f kg" % RocketModel.total_mass_kilograms(vehicle))
		lines.append("propellant %.0f kg" % attached_propellant_kilograms)
		lines.append("stages     %d attached, %d failed" % [attached_stage_count, failed_stage_count])
		lines.append("instrum.   %d working of %d" % [
				vehicle.working_instrument_count(), vehicle.is_working_by_instrument.size()])

	var nearest_threat_kilometers := INF
	var revealed_threat_count := 0
	for threat in FlightSimulation.threats:
		if threat.is_revealed:
			revealed_threat_count += 1
		if threat.state != null and gravitational_parameter > 0.0:
			var threat_state: OrbitState = threat.state
			if threat_state.time_seconds != state.time_seconds:
				threat_state = Kepler.propagate(
						gravitational_parameter, threat.state, state.time_seconds - threat.state.time_seconds)
			var difference_x_meters := threat_state.position_x_meters - state.position_x_meters
			var difference_y_meters := threat_state.position_y_meters - state.position_y_meters
			nearest_threat_kilometers = minf(nearest_threat_kilometers,
					sqrt(difference_x_meters * difference_x_meters + difference_y_meters * difference_y_meters) / 1000.0)
	var threat_line := "threats    %d (%d on radar)" % [FlightSimulation.threats.size(), revealed_threat_count]
	if is_finite(nearest_threat_kilometers):
		threat_line += ", nearest %.1f km" % nearest_threat_kilometers
	lines.append(threat_line)
	return "\n".join(lines)
