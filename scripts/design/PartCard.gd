class_name PartCard
extends Button
## One part in the list of the rocket design screen: icon, name, cost, and the
## one number that matters most for the part's category. Clicking the card
## installs the part; hovering it opens the details popup. The card only
## reports what happened; RocketDesign.gd decides what to do.

signal card_pressed(part_id: String)
signal card_hovered(part_id: String)
signal card_unhovered

const CARD_HEIGHT_PIXELS := 46.0
const ICON_SIZE_PIXELS := 20.0
const MARGIN_PIXELS := 3.0
const NAME_FONT_SIZE_PIXELS := 8
const NUMBER_FONT_SIZE_PIXELS := 8
const COLOR_CARD_TEXT := Color("ffffff")
const COLOR_COST_TEXT := Color("ffd27a")

const ENGINE_TYPE_SOLID := "solid"

var part_id: String = ""


## Fills the card from one entry of data/parts.json.
func configure(part: Dictionary, card_width_pixels: float) -> void:
	part_id = part.get("id", "")
	custom_minimum_size = Vector2(card_width_pixels, CARD_HEIGHT_PIXELS)
	size = custom_minimum_size
	clip_contents = true
	focus_mode = Control.FOCUS_NONE

	var icon_rect := TextureRect.new()
	icon_rect.position = Vector2(MARGIN_PIXELS, MARGIN_PIXELS)
	icon_rect.size = Vector2(ICON_SIZE_PIXELS, ICON_SIZE_PIXELS)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path: String = part.get("icon_path", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path)
	add_child(icon_rect)

	var name_left_pixels: float = ICON_SIZE_PIXELS + 2.0 * MARGIN_PIXELS
	var name_label := Label.new()
	name_label.position = Vector2(name_left_pixels, 1.0)
	name_label.size = Vector2(card_width_pixels - name_left_pixels - MARGIN_PIXELS, 24.0)
	name_label.text = part.get("name", part_id)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE_PIXELS)
	name_label.add_theme_color_override("font_color", COLOR_CARD_TEXT)
	name_label.add_theme_constant_override("line_spacing", -2)
	add_child(name_label)

	var number_line_top_pixels: float = CARD_HEIGHT_PIXELS - 20.0
	var cost_label := Label.new()
	cost_label.position = Vector2(MARGIN_PIXELS, number_line_top_pixels)
	cost_label.size = Vector2(card_width_pixels - 2.0 * MARGIN_PIXELS, 10.0)
	cost_label.text = cost_text(part)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.add_theme_font_size_override("font_size", NUMBER_FONT_SIZE_PIXELS)
	cost_label.add_theme_color_override("font_color", COLOR_COST_TEXT)
	add_child(cost_label)

	var key_number_label := Label.new()
	key_number_label.position = Vector2(MARGIN_PIXELS, number_line_top_pixels + 9.0)
	key_number_label.size = Vector2(card_width_pixels - 2.0 * MARGIN_PIXELS, 10.0)
	key_number_label.text = key_number_text(part)
	key_number_label.clip_text = true
	key_number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_number_label.add_theme_font_size_override("font_size", NUMBER_FONT_SIZE_PIXELS)
	key_number_label.add_theme_color_override("font_color", COLOR_CARD_TEXT)
	add_child(key_number_label)

	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


static func cost_text(part: Dictionary) -> String:
	var cost_million_usd: float = part.get("cost_million_usd", 0.0)
	return "$ %s M" % format_number(cost_million_usd)


## The one number that matters most for the part's category:
##   engine     specific impulse, marked SOLID or LIQUID
##   tank       propellant capacity
##   telemetry  range, or the update rate for sensors without a range
##   science    data rate
static func key_number_text(part: Dictionary) -> String:
	var stats: Dictionary = part.get("stats", {})
	match part.get("category", ""):
		GameData.CATEGORY_ENGINE:
			var specific_impulse_seconds: float = stats.get("specific_impulse_seconds", 0.0)
			var engine_type: String = stats.get("engine_type", "")
			var engine_type_mark := "SOLID" if engine_type == ENGINE_TYPE_SOLID else "LIQUID"
			return "Isp %s s  %s" % [format_number(specific_impulse_seconds), engine_type_mark]
		GameData.CATEGORY_TANK:
			var propellant_capacity_kilograms: float = stats.get("propellant_capacity_kilograms", 0.0)
			return "Fuel %s kg" % format_number(propellant_capacity_kilograms)
		GameData.CATEGORY_TELEMETRY:
			var range_kilometers: float = stats.get("range_kilometers", 0.0)
			if range_kilometers > 0.0:
				return "Range %s km" % format_number(range_kilometers)
			var updates_per_second: float = stats.get("updates_per_second", 0.0)
			return "%s updates/s" % format_number(updates_per_second)
		GameData.CATEGORY_SCIENCE:
			var data_rate_megabits_per_second: float = stats.get("data_rate_megabits_per_second", 0.0)
			return "Data %s Mb/s" % format_number(data_rate_megabits_per_second)
	return ""


## Whole numbers without decimals, other numbers with up to two decimals.
static func format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%.0f" % value
	if is_equal_approx(value * 10.0, roundf(value * 10.0)):
		return "%.1f" % value
	return "%.2f" % value


func _on_pressed() -> void:
	card_pressed.emit(part_id)


func _on_mouse_entered() -> void:
	card_hovered.emit(part_id)


func _on_mouse_exited() -> void:
	card_unhovered.emit()
