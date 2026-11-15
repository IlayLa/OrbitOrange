class_name RadarPanel
extends Control
## RADAR: the black scope with green rings is the mock-up background itself.
## This panel draws each entry of frame.radar_contacts on it, at its bearing
## and range, with the detail its resolution_level allows:
##   0  a blip
##   1  a blip and the distance
##   2  an outline, the distance, the closing speed and the object type
## Bearings are inertial (0 = +x, counter-clockwise), the frame of the
## telemetry; the frame carries no craft orientation. The scope range grows to
## fit the farthest contact (ReadingFormat.radar_scope_range_meters), because
## the frame does not carry the radar's own range. It never shrinks during a
## flight: a shrinking scope would make an approaching object jump outward.
##
## The contact marks are plain shapes; replace them with sprites when art exists.

const LABEL_FONT_SIZE := 8
const BLIP_RADIUS_PIXELS := 2.0
const OUTLINE_RADIUS_PIXELS := 5.0

var _is_radar_installed: bool = false
var _has_frame: bool = false
var _contacts: Array[Dictionary] = []
var _scope_range_meters: float = ReadingFormat.radar_scope_range_meters(0.0)


func _ready() -> void:
	position = ExecutionLayout.RADAR_SCREEN.position
	size = ExecutionLayout.RADAR_SCREEN.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Stores the frame's radar contacts and redraws the scope.
func show_frame(frame: TelemetryFrame) -> void:
	_has_frame = true
	_is_radar_installed = frame.is_radar_installed
	_contacts = frame.radar_contacts.duplicate(true)
	var largest_range_meters := 0.0
	for contact in _contacts:
		largest_range_meters = maxf(largest_range_meters, float(contact.get("range_meters", 0.0)))
	_scope_range_meters = maxf(
			_scope_range_meters, ReadingFormat.radar_scope_range_meters(largest_range_meters))
	queue_redraw()


## Shrinks the scope back to its smallest range. The console is rebuilt for
## every game, so a flight never needs this; the demo uses it between states.
func reset_scope() -> void:
	_scope_range_meters = ReadingFormat.radar_scope_range_meters(0.0)
	queue_redraw()


## Returns the scope range in metres: the distance shown at the outer ring.
func scope_range_meters() -> float:
	return _scope_range_meters


## Returns the texts drawn on the scope, one per line. Used by the tests.
func shown_texts() -> Array[String]:
	var texts: Array[String] = []
	if not _has_frame:
		return texts
	if not _is_radar_installed:
		texts.append(ReadingFormat.NO_SENSOR_TEXT)
		return texts
	texts.append(_scope_range_text())
	for contact in _contacts:
		var contact_text := _contact_text(contact)
		if contact_text != "":
			texts.append(contact_text)
	return texts


## Returns where a contact is drawn, relative to the panel's top-left corner.
func contact_position_pixels(contact: Dictionary) -> Vector2:
	var bearing_radians := float(contact.get("bearing_radians", 0.0))
	var range_fraction := clampf(float(contact.get("range_meters", 0.0)) / _scope_range_meters, 0.0, 1.0)
	var distance_pixels := range_fraction * ExecutionLayout.RADAR_OUTER_RING_RADIUS_PIXELS
	return ExecutionLayout.RADAR_CENTER_IN_SCREEN + Vector2(
			cos(bearing_radians), -sin(bearing_radians)) * distance_pixels


func _draw() -> void:
	if not _has_frame:
		return
	var font := get_theme_default_font()
	var center := ExecutionLayout.RADAR_CENTER_IN_SCREEN
	if not _is_radar_installed:
		_draw_centered_text(font, ReadingFormat.NO_SENSOR_TEXT, center, ScreenLayout.COLOR_TEXT_LIGHT)
		return
	_draw_text_on_black(font, _scope_range_text(), Vector2(8, size.y - 16),
			ExecutionLayout.COLOR_RADAR_SWEEP_GREEN)
	for contact in _contacts:
		var contact_position := contact_position_pixels(contact)
		var resolution_level := int(contact.get("resolution_level", 0))
		if resolution_level >= 2:
			draw_arc(contact_position, OUTLINE_RADIUS_PIXELS, 0.0, TAU, 16, ScreenLayout.COLOR_SPACE_BLACK, 3.0)
			draw_arc(contact_position, OUTLINE_RADIUS_PIXELS, 0.0, TAU, 16, ScreenLayout.COLOR_TEXT_LIGHT, 1.0)
		draw_circle(contact_position, BLIP_RADIUS_PIXELS + 1.0, ScreenLayout.COLOR_SPACE_BLACK)
		draw_circle(contact_position, BLIP_RADIUS_PIXELS, ScreenLayout.COLOR_TEXT_LIGHT)
		var contact_text := _contact_text(contact)
		if contact_text != "":
			_draw_text_on_black(font, contact_text,
					contact_position + Vector2(OUTLINE_RADIUS_PIXELS + 2, -4), ScreenLayout.COLOR_TEXT_LIGHT)


func _scope_range_text() -> String:
	return "ring %.0f km" % (_scope_range_meters / 1000.0)


func _contact_text(contact: Dictionary) -> String:
	var resolution_level := int(contact.get("resolution_level", 0))
	if resolution_level <= 0:
		return ""
	var distance_text := "%.1f km" % (float(contact.get("range_meters", 0.0)) / 1000.0)
	if resolution_level == 1:
		return distance_text
	var type_text := String(contact.get("event_type_id", ""))
	var closing_text := "%+.0f m/s" % float(contact.get("closing_speed_meters_per_second", 0.0))
	return "%s\n%s %s" % [type_text if type_text != "" else "object", distance_text, closing_text]


## Draws text (one or more lines) with its top-left corner at top_left, on a
## black rectangle so it stays readable over the green rings. The text is
## kept inside the panel.
func _draw_text_on_black(font: Font, text: String, top_left: Vector2, color: Color) -> void:
	var text_size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	var origin := top_left.clamp(Vector2(6, 6), size - text_size - Vector2(6, 6))
	draw_rect(Rect2(origin - Vector2(1, 0), text_size + Vector2(2, 1)), ScreenLayout.COLOR_SPACE_BLACK)
	draw_multiline_string(font, origin + Vector2(0, font.get_ascent(LABEL_FONT_SIZE)), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, -1, color)


func _draw_centered_text(font: Font, text: String, center: Vector2, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE + 3)
	var outline_rect := Rect2(center - text_size / 2.0 - Vector2(3, 2), text_size + Vector2(6, 4))
	draw_rect(outline_rect, ScreenLayout.COLOR_SPACE_BLACK)
	draw_string(font, Vector2(center.x - text_size.x / 2.0, center.y + text_size.y / 4.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE + 3, color)
