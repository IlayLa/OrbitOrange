class_name PartDetailsPopup
extends PanelContainer
## The details of one part, shown while the mouse is over its card: every stat
## with its unit, the engine type, the mission-fit stars for the chosen science
## mission, the trade-off sentence and the source of the numbers.
## The popup never takes the mouse, so it cannot make a card lose its hover.

const POPUP_WIDTH_PIXELS := 200.0
const SCREEN_MARGIN_PIXELS := 2.0
const TITLE_FONT_SIZE_PIXELS := 10
const BODY_FONT_SIZE_PIXELS := 8
const SOURCE_FONT_SIZE_PIXELS := 7
const MAXIMUM_MISSION_FIT_STARS := 3
const STAR_SIZE_PIXELS := 10.0
const COLOR_POPUP_BACKGROUND := Color("10182bf2")
const COLOR_POPUP_BORDER := Color("bed3fa")
const COLOR_TRADEOFF_TEXT := Color("ffd27a")
const COLOR_SOURCE_TEXT := Color("9fb0c8")
const COLOR_STAR_EMPTY := Color("4a5568")

const ENGINE_TYPE_KEY := "engine_type"

## Ending of a stat key -> unit shown after the number. The first ending that
## matches wins, so longer endings come before the shorter ones they contain.
const UNIT_BY_KEY_ENDING: Array[Array] = [
	["_megabits_per_second", "Mb/s"],
	["_per_second", "per second"],
	["_kilonewtons", "kN"],
	["_kilograms", "kg"],
	["_kilometers", "km"],
	["_seconds", "s"],
	["_watts", "W"],
]
## Endings of stat keys whose value is a share of one, shown as a percentage.
const PERCENT_KEY_ENDINGS: Array[String] = ["_fraction", "_probability"]

## Where the popup would like its top-left corner, before it is kept on screen.
var _wanted_position: Vector2 = Vector2.ZERO
var _contents: VBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(POPUP_WIDTH_PIXELS, 0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_POPUP_BACKGROUND
	panel_style.border_color = COLOR_POPUP_BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", panel_style)

	_contents = VBoxContainer.new()
	_contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contents.add_theme_constant_override("separation", 0)
	add_child(_contents)

	resized.connect(_keep_on_screen)
	hide()


## Fills the popup for one entry of data/parts.json and shows it with its
## top-left corner at wanted_position, moved as needed to stay on the screen.
## science_mission_id chooses which mission-fit rating the stars show.
func show_part(part: Dictionary, science_mission_id: String, wanted_position: Vector2) -> void:
	for existing_line in _contents.get_children():
		_contents.remove_child(existing_line)
		existing_line.queue_free()

	for line_text in detail_lines(part):
		_add_line(line_text, BODY_FONT_SIZE_PIXELS, ScreenLayout.COLOR_TEXT_LIGHT)
	# The first line is the part's name.
	var name_label: Label = _contents.get_child(0)
	name_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE_PIXELS)

	if part.get("category", "") == GameData.CATEGORY_SCIENCE:
		_add_mission_fit_row(part, science_mission_id)

	var tradeoff: String = part.get("tradeoff", "")
	if not tradeoff.is_empty():
		_add_line(tradeoff, BODY_FONT_SIZE_PIXELS, COLOR_TRADEOFF_TEXT)

	var source_text := source_line(part)
	if not source_text.is_empty():
		_add_line(source_text, SOURCE_FONT_SIZE_PIXELS, COLOR_SOURCE_TEXT)

	_wanted_position = wanted_position
	size = Vector2(POPUP_WIDTH_PIXELS, 0)
	show()
	_keep_on_screen()


## The name, the category, the cost, the dry mass and one line per stat.
static func detail_lines(part: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var part_id: String = part.get("id", "")
	lines.append(part.get("name", part_id))

	var stats: Dictionary = part.get("stats", {})
	var category: String = part.get("category", "")
	if stats.has(ENGINE_TYPE_KEY):
		lines.append("Engine type: %s" % stats[ENGINE_TYPE_KEY])
	else:
		lines.append("Category: %s" % category)

	var cost_million_usd: float = part.get("cost_million_usd", 0.0)
	lines.append("Cost: %s million USD" % PartCard.format_number(cost_million_usd))
	var dry_mass_kilograms: float = part.get("dry_mass_kilograms", 0.0)
	lines.append("Dry mass: %s kg" % PartCard.format_number(dry_mass_kilograms))

	for stat_key: String in stats:
		if stat_key == ENGINE_TYPE_KEY:
			continue
		lines.append(stat_line(stat_key, stats[stat_key]))
	return lines


## One stat as "Readable name: value unit". The unit comes from the ending of
## the key, for example "thrust_kilonewtons" -> "Thrust: 47 kN".
static func stat_line(stat_key: String, stat_value: Variant) -> String:
	if not (stat_value is float or stat_value is int):
		var text_value: String = str(stat_value).replace("_", " ")
		return "%s: %s" % [_readable_name(stat_key), text_value]

	var number_value: float = stat_value
	for percent_key_ending in PERCENT_KEY_ENDINGS:
		if stat_key.ends_with(percent_key_ending):
			return "%s: %s %%" % [
					_readable_name(stat_key.trim_suffix(percent_key_ending)),
					PartCard.format_number(100.0 * number_value)]

	for ending_and_unit in UNIT_BY_KEY_ENDING:
		var key_ending: String = ending_and_unit[0]
		var unit: String = ending_and_unit[1]
		if stat_key.ends_with(key_ending):
			return "%s: %s %s" % [
					_readable_name(stat_key.trim_suffix(key_ending)),
					PartCard.format_number(number_value),
					unit]

	return "%s: %s" % [_readable_name(stat_key), PartCard.format_number(number_value)]


## The mission-fit rating of the part for one science mission, from 0 to 3.
static func mission_fit_stars(part: Dictionary, science_mission_id: String) -> int:
	var mission_fit: Dictionary = part.get("mission_fit", {})
	var rating: float = mission_fit.get(science_mission_id, 0)
	return clampi(roundi(rating), 0, MAXIMUM_MISSION_FIT_STARS)


static func source_line(part: Dictionary) -> String:
	var source: String = part.get("source", "")
	if source.is_empty():
		return ""
	var is_approximate: bool = part.get("is_approximate", false)
	if is_approximate:
		return "Source (approximate): " + source
	return "Source: " + source


static func _readable_name(key_text: String) -> String:
	return key_text.replace("_", " ").capitalize()


func _add_line(line_text: String, font_size_pixels: int, text_color: Color) -> void:
	var line_label := Label.new()
	line_label.text = line_text
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.custom_minimum_size = Vector2(POPUP_WIDTH_PIXELS - 10.0, 0)
	line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_label.add_theme_font_size_override("font_size", font_size_pixels)
	line_label.add_theme_color_override("font_color", text_color)
	line_label.add_theme_constant_override("line_spacing", -1)
	_contents.add_child(line_label)


func _add_mission_fit_row(part: Dictionary, science_mission_id: String) -> void:
	if science_mission_id.is_empty():
		_add_line("Mission fit: no science mission chosen", BODY_FONT_SIZE_PIXELS, ScreenLayout.COLOR_TEXT_LIGHT)
		return

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	_contents.add_child(row)

	var caption_label := Label.new()
	caption_label.text = "Mission fit:"
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE_PIXELS)
	caption_label.add_theme_color_override("font_color", ScreenLayout.COLOR_TEXT_LIGHT)
	row.add_child(caption_label)

	var star_count: int = mission_fit_stars(part, science_mission_id)
	for star_index in MAXIMUM_MISSION_FIT_STARS:
		var star := Polygon2D.new()
		star.polygon = _star_outline(STAR_SIZE_PIXELS)
		star.color = ScreenLayout.COLOR_ACCENT_ORANGE if star_index < star_count else COLOR_STAR_EMPTY
		var star_holder := Control.new()
		star_holder.custom_minimum_size = Vector2(STAR_SIZE_PIXELS, STAR_SIZE_PIXELS)
		star_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star_holder.add_child(star)
		row.add_child(star_holder)


## The ten corners of a five-pointed star that fits a square of the given size.
func _star_outline(star_size_pixels: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	var center := Vector2(star_size_pixels, star_size_pixels) * 0.5
	var outer_radius_pixels: float = star_size_pixels * 0.5
	var inner_radius_pixels: float = outer_radius_pixels * 0.42
	for corner_index in 10:
		var corner_radius_pixels: float = outer_radius_pixels if corner_index % 2 == 0 else inner_radius_pixels
		var corner_angle_radians: float = -PI / 2.0 + corner_index * PI / 5.0
		corners.append(center + Vector2.from_angle(corner_angle_radians) * corner_radius_pixels)
	return corners


func _keep_on_screen() -> void:
	var highest_left_pixels: float = ScreenLayout.SCREEN_SIZE.x - size.x - SCREEN_MARGIN_PIXELS
	var highest_top_pixels: float = ScreenLayout.SCREEN_SIZE.y - size.y - SCREEN_MARGIN_PIXELS
	position = Vector2(
			clampf(_wanted_position.x, SCREEN_MARGIN_PIXELS, maxf(SCREEN_MARGIN_PIXELS, highest_left_pixels)),
			clampf(_wanted_position.y, SCREEN_MARGIN_PIXELS, maxf(SCREEN_MARGIN_PIXELS, highest_top_pixels)))
