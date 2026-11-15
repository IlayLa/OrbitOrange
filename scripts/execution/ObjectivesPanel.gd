class_name ObjectivesPanel
extends Control
## The light-grey screen of the left column: fuel left (from the fuel gauge;
## delta-v has its own panel on the instrument wall), science data generated
## and delivered, and the objective list (target orbit, the chosen
## science mission and the accepted side quests). Objectives come from
## GameState; the numbers come from the telemetry frame.

const FONT_SIZE := 10
const HEADING_FONT_SIZE := 11

var _fuel_label: Label
var _science_data_label: Label
var _objective_list: VBoxContainer


func _ready() -> void:
	var inner_rect := ExecutionLayout.inside_frame(ExecutionLayout.OBJECTIVES_SCREEN).grow(-3)
	position = inner_rect.position
	size = inner_rect.size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lines := VBoxContainer.new()
	lines.size = size
	lines.add_theme_constant_override("separation", 3)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lines)

	_fuel_label = _add_label(lines, "FUEL " + ReadingFormat.NO_DATA_TEXT, HEADING_FONT_SIZE)
	_science_data_label = _add_label(lines, "", FONT_SIZE)
	_set_science_data_text(0.0, 0.0)
	lines.add_child(HSeparator.new())
	_add_label(lines, "OBJECTIVES", HEADING_FONT_SIZE)
	_objective_list = VBoxContainer.new()
	_objective_list.add_theme_constant_override("separation", 3)
	_objective_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(_objective_list)
	refresh_objectives()


## Shows the fuel reading (or NO SENSOR / NO SIGNAL) and the science data.
func show_frame(frame: TelemetryFrame) -> void:
	var fuel_reading := frame.reading(TelemetryFrame.CHANNEL_FUEL_KILOGRAMS)
	_fuel_label.text = "FUEL " + ReadingFormat.reading_text(fuel_reading, func(value_kilograms: float) -> String:
		return "%.0f kg" % value_kilograms)
	_set_science_data_text(frame.data_generated_megabits, frame.data_delivered_megabits)


## Rebuilds the objective list from GameState.mission, the chosen science
## mission and the accepted side quests.
func refresh_objectives() -> void:
	for child in _objective_list.get_children():
		_objective_list.remove_child(child)
		child.queue_free()
	for objective_text in objective_texts():
		_add_label(_objective_list, objective_text, FONT_SIZE)


## Returns one line per objective, in display order.
static func objective_texts() -> Array[String]:
	var texts: Array[String] = []
	var target: Dictionary = GameState.mission.get("target", {})
	if target.is_empty():
		texts.append("No mission selected.")
		return texts
	texts.append("• Orbit %.0f ± %.0f km, eccentricity %.3f ± %.3f" % [
			float(target.get("altitude_kilometers", 0.0)),
			float(target.get("altitude_tolerance_kilometers", 0.0)),
			float(target.get("eccentricity", 0.0)),
			float(target.get("eccentricity_tolerance", 0.0))])
	var science_mission: Dictionary = GameState.science_mission()
	if not science_mission.is_empty():
		texts.append("• Science: %s, deliver %.0f Mb" % [
				science_mission.get("name", "?"),
				float(science_mission.get("required_data_megabits", 0.0))])
	for side_quest in GameState.accepted_side_quests():
		texts.append("• Side quest: %s" % side_quest.get("name", "?"))
	return texts


## Returns every line of the panel as shown, joined by newlines.
func shown_text() -> String:
	var lines: Array[String] = [_fuel_label.text, _science_data_label.text]
	for child in _objective_list.get_children():
		if child is Label and not child.is_queued_for_deletion():
			lines.append(child.text)
	return "\n".join(lines)


func _set_science_data_text(generated_megabits: float, delivered_megabits: float) -> void:
	_science_data_label.text = "Science data\n  %.1f Mb generated\n  %.1f Mb delivered" % [
			generated_megabits, delivered_megabits]


func _add_label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = size.x
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ExecutionLayout.COLOR_SCREEN_DARK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
